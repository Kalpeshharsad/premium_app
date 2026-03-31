import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'key_service.dart';

// ─────────────────────────────────────────────
// Protobuf helpers (no full protobuf dependency)
// ─────────────────────────────────────────────

Uint8List _varint(int value) {
  final out = <int>[];
  while (value > 0x7F) {
    out.add((value & 0x7F) | 0x80);
    value >>= 7;
  }
  out.add(value);
  return Uint8List.fromList(out);
}

Uint8List _fieldVarint(int field, int value) =>
    Uint8List.fromList([..._varint(field << 3), ..._varint(value)]);

Uint8List _fieldBytes(int field, Uint8List data) =>
    Uint8List.fromList([..._varint((field << 3) | 2), ..._varint(data.length), ...data]);

Uint8List _fieldString(int field, String s) => _fieldBytes(field, Uint8List.fromList(utf8.encode(s)));

// Wrap with 4-byte BE length header
Uint8List _frame(Uint8List msg) {
  final len = ByteData(4)..setUint32(0, msg.length, Endian.big);
  return Uint8List.fromList([...len.buffer.asUint8List(), ...msg]);
}

// Build an OuterMessage with fields pre-encoded inside `inner`
Uint8List _outer(Uint8List inner) {
  final body = Uint8List.fromList([
    ..._fieldVarint(1, 2),   // protocol_version = 2
    ..._fieldVarint(2, 200), // status = STATUS_OK
    ...inner,
  ]);
  return _frame(body);
}

// ─────────────────────────────────────────────
// Message structs
// ─────────────────────────────────────────────

// PairingRequest (field 10): service_name, client_name
Uint8List _pairingRequest() {
  final inner = Uint8List.fromList([
    ..._fieldString(1, 'atvremote'),
    ..._fieldString(2, 'Antigravity Remote'),
  ]);
  return _outer(_fieldBytes(10, inner));
}

// Options (field 20):
//   preferred_role = ROLE_TYPE_INPUT (1)
//   input_encodings: HEXADECIMAL (type=3), symbol_length=6
//   output_encodings: HEXADECIMAL (type=3), symbol_length=6
Uint8List _options() {
  final hexEncoding = Uint8List.fromList([
    ..._fieldVarint(1, 3), // type = HEXADECIMAL
    ..._fieldVarint(2, 6), // symbol_length = 6
  ]);
  final inner = Uint8List.fromList([
    ..._fieldBytes(1, hexEncoding), // input_encodings
    ..._fieldBytes(2, hexEncoding), // output_encodings
    ..._fieldVarint(3, 1),          // preferred_role = ROLE_TYPE_INPUT
  ]);
  return _outer(_fieldBytes(20, inner));
}

// Configuration (field 30):
//   encoding: HEXADECIMAL (type=3), symbol_length=6
//   client_role = ROLE_TYPE_INPUT (1)
Uint8List _configuration() {
  final hexEncoding = Uint8List.fromList([
    ..._fieldVarint(1, 3), // type = HEXADECIMAL
    ..._fieldVarint(2, 6), // symbol_length = 6
  ]);
  final inner = Uint8List.fromList([
    ..._fieldBytes(1, hexEncoding), // encoding
    ..._fieldVarint(2, 1),          // client_role = ROLE_TYPE_INPUT
  ]);
  return _outer(_fieldBytes(30, inner));
}

// Secret (field 40): field 3 = secret bytes
Uint8List _secret(Uint8List secretBytes) {
  final inner = _fieldBytes(3, secretBytes);
  return _outer(_fieldBytes(40, inner));
}

// ─────────────────────────────────────────────
// Framed-message reader
// ─────────────────────────────────────────────

class _MessageStream {
  final _buffer = <int>[];
  final _controller = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get messages => _controller.stream;

  void add(List<int> data) {
    _buffer.addAll(data);
    _tryEmit();
  }

  void _tryEmit() {
    while (_buffer.length >= 4) {
      final msgLen = ByteData.sublistView(Uint8List.fromList(_buffer.sublist(0, 4)))
          .getUint32(0, Endian.big);
      if (_buffer.length < 4 + msgLen) break;
      final msg = Uint8List.fromList(_buffer.sublist(4, 4 + msgLen));
      _buffer.removeRange(0, 4 + msgLen);
      _controller.add(msg);
    }
  }

  void close() => _controller.close();
}

// ─────────────────────────────────────────────
// WifiService
// ─────────────────────────────────────────────

class WifiService {
  bool _isConnected = false;
  bool _isPairing = false;
  String? _pairedIp;
  SecureSocket? _pairingSocket;
  SecureSocket? _controlSocket;
  _MessageStream? _msgStream;

  bool get isConnected => _isConnected;
  bool get isPairing => _isPairing;

  // ── Connect (post-pairing) ───────────────────────────────────────────────

  Future<bool> connect(String ip) async {
    debugPrint('WifiService: connect($ip)');

    final paired = await KeyService.isWifiPaired();
    if (!paired) {
      debugPrint('WifiService: Not paired yet.');
      _isPairing = true;
      return false;
    }

    try {
      _controlSocket = await SecureSocket.connect(
        ip, 6466,
        onBadCertificate: (cert) => true,
        timeout: const Duration(seconds: 5),
      );
      _isConnected = true;
      _pairedIp = ip;
      _controlSocket!.listen(
        (data) => debugPrint('WifiService: control data ${data.length}b'),
        onDone: disconnect,
        onError: (_) => disconnect(),
      );
      return true;
    } catch (e) {
      debugPrint('WifiService: connect failed: $e');
      _isConnected = false;
      return false;
    }
  }

  // ── Pairing step 1: connect + handshake → TV shows PIN ──────────────────

  Future<bool> startPairing(String ip) async {
    debugPrint('WifiService: startPairing($ip)...');

    try {
      _pairingSocket = await SecureSocket.connect(
        ip, 6467,
        onBadCertificate: (cert) => true,
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('WifiService: port 6467 failed ($e), trying 6466...');
      try {
        _pairingSocket = await SecureSocket.connect(
          ip, 6466,
          onBadCertificate: (cert) => true,
          timeout: const Duration(seconds: 5),
        );
      } catch (e2) {
        debugPrint('WifiService: all ports failed: $e2');
        return false;
      }
    }

    debugPrint('WifiService: socket connected, starting handshake...');

    // Set up framed-message reader
    _msgStream = _MessageStream();
    _pairingSocket!.listen(
      (data) {
        debugPrint('WifiService: raw data ${data.length}b hex=${data.take(8).map((b) => b.toRadixString(16).padLeft(2,"0")).join(" ")}');
        _msgStream?.add(data);
      },
      onError: (e) => debugPrint('WifiService: socket error $e'),
      onDone: () {
        debugPrint('WifiService: pairing socket closed');
        _msgStream?.close();
      },
    );

    // 1. Send PairingRequest
    _pairingSocket!.add(_pairingRequest());
    await _pairingSocket!.flush();
    debugPrint('WifiService: → PairingRequest sent');

    // 2. Wait for PairingRequestAck (field 11 present) then send Options
    // 3. Wait for server Options (field 20) then send Configuration
    // 4. Wait for ConfigurationAck (field 31) → TV shows PIN

    final handshakeDone = Completer<bool>();

    int step = 0; // 0=awaiting ack, 1=awaiting server options, 2=awaiting config ack

    final sub = _msgStream!.messages.listen((msg) {
      debugPrint('WifiService: ← message step=$step payload=${msg.take(8).map((b)=>b.toRadixString(16).padLeft(2,"0")).join(" ")}');

      // Quick field presence check: scan message for known field tags
      // field 11 → PairingRequestAck tag = 11<<3|2 = 0x5A
      // field 20 → Options tag = 20<<3|2 = 0xA2 0x01
      // field 31 → ConfigurationAck tag = 31<<3|2 = 0xFA 0x01

      final hasField11 = _hasField(msg, 11);
      final hasField20 = _hasField(msg, 20);
      final hasField31 = _hasField(msg, 31);

      debugPrint('WifiService: hasField11=$hasField11 hasField20=$hasField20 hasField31=$hasField31');

      if (step == 0 && hasField11) {
        // Got PairingRequestAck → send Options
        _pairingSocket?.add(_options());
        _pairingSocket?.flush();
        debugPrint('WifiService: → Options sent');
        step = 1;
      } else if (step == 1 && hasField20) {
        // Got server Options → send Configuration
        _pairingSocket?.add(_configuration());
        _pairingSocket?.flush();
        debugPrint('WifiService: → Configuration sent');
        step = 2;
      } else if (step == 2 && hasField31) {
        // Got ConfigurationAck → TV should now show PIN
        debugPrint('WifiService: handshake complete — TV showing PIN!');
        if (!handshakeDone.isCompleted) handshakeDone.complete(true);
      }
    });

    final success = await handshakeDone.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('WifiService: handshake timed out at step=$step');
        return false;
      },
    );

    await sub.cancel();
    return success;
  }

  // ── Pairing step 2: send PIN → TV confirms ───────────────────────────────

  Future<bool> pair(String ip, String pin) async {
    debugPrint('WifiService: pair PIN=$pin');

    if (_pairingSocket == null) {
      debugPrint('WifiService: no pairing socket');
      return false;
    }

    try {
      // PIN is a 6-hex-char string; convert to 3-byte array
      final secretBytes = Uint8List.fromList(
        List.generate(pin.length ~/ 2, (i) =>
            int.parse(pin.substring(i * 2, i * 2 + 2), radix: 16)),
      );

      final completer = Completer<bool>();

      _msgStream ??= _MessageStream();

      final sub = _msgStream!.messages.listen((msg) {
        debugPrint('WifiService: SecretAck? ${msg.take(8).map((b)=>b.toRadixString(16).padLeft(2,"0")).join(" ")}');
        // field 41 = SecretAck (tag = 41<<3|2 = 0xCA 0x02)
        final hasSecretAck = _hasField(msg, 41);
        if (!completer.isCompleted) completer.complete(hasSecretAck);
      });

      _pairingSocket!.add(_secret(secretBytes));
      await _pairingSocket!.flush();
      debugPrint('WifiService: → Secret sent');

      final gotAck = await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );

      await sub.cancel();

      if (gotAck) {
        await KeyService.setWifiPaired(true);
        _isPairing = false;
        _pairingSocket?.destroy();
        _pairingSocket = null;
        _msgStream = null;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('WifiService: pair error $e');
      return false;
    }
  }

  // ── Controls ─────────────────────────────────────────────────────────────

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected || _controlSocket == null) return;
    for (final dir in [0, 1]) {
      final keyEvent = Uint8List.fromList([
        ..._fieldVarint(2, keyCode),
        ..._fieldVarint(4, dir),
      ]);
      final remoteMsg = Uint8List.fromList([
        ..._fieldVarint(1, 2),
        ..._fieldVarint(2, 200),
        ..._fieldBytes(6, keyEvent),
      ]);
      _controlSocket!.add(_frame(remoteMsg));
    }
    await _controlSocket!.flush();
  }

  Future<void> sendText(String text) async {
    if (!_isConnected || _controlSocket == null) return;
    final inner = Uint8List.fromList([
      ..._fieldVarint(1, 2),
      ..._fieldVarint(2, 200),
      ..._fieldBytes(8, _fieldString(1, text)),
    ]);
    _controlSocket!.add(_frame(inner));
    await _controlSocket!.flush();
  }

  Future<void> setBrightness(int value) async {
    debugPrint('WifiService: setBrightness not supported via Remote v2');
  }

  void disconnect() {
    _isConnected = false;
    _isPairing = false;
    _pairedIp = null;
    _pairingSocket?.destroy();
    _controlSocket?.destroy();
    _pairingSocket = null;
    _controlSocket = null;
    _msgStream?.close();
    _msgStream = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Check if `msg` contains a field with the given number.
  /// Works for wire types 0 (varint) and 2 (length-delimited).
  bool _hasField(Uint8List msg, int fieldNumber) {
    try {
      int i = 0;
      while (i < msg.length) {
        // Read tag (varint)
        int tag = 0, shift = 0;
        while (i < msg.length) {
          final b = msg[i++];
          tag |= (b & 0x7F) << shift;
          if (b & 0x80 == 0) break;
          shift += 7;
        }
        final fn = tag >> 3;
        final wt = tag & 7;
        if (fn == fieldNumber) return true;
        // Skip value based on wire type
        switch (wt) {
          case 0: // varint
            while (i < msg.length && msg[i++] & 0x80 != 0) {}
            break;
          case 2: // length-delimited
            int len = 0; shift = 0;
            while (i < msg.length) {
              final b = msg[i++];
              len |= (b & 0x7F) << shift;
              if (b & 0x80 == 0) break;
              shift += 7;
            }
            i += len;
            break;
          case 5: i += 4; break; // 32-bit
          case 1: i += 8; break; // 64-bit
          default: return false;
        }
      }
    } catch (_) {}
    return false;
  }
}
