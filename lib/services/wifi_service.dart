import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'key_service.dart';

// ─────────────────────────────────────────────
// Minimal hand-rolled protobuf helpers
// ─────────────────────────────────────────────

/// Encode a protobuf varint.
Uint8List _encodeVarint(int value) {
  final out = <int>[];
  while (value > 0x7F) {
    out.add((value & 0x7F) | 0x80);
    value >>= 7;
  }
  out.add(value);
  return Uint8List.fromList(out);
}

/// Encode a string field: tag (field<<3|2), length, utf8 bytes.
Uint8List _encodeStringField(int fieldNumber, String value) {
  final bytes = utf8.encode(value);
  final tag = _encodeVarint((fieldNumber << 3) | 2);
  return Uint8List.fromList([...tag, ...(_encodeVarint(bytes.length)), ...bytes]);
}

/// Encode an int32 field: tag (field<<3|0), varint.
Uint8List _encodeVarintField(int fieldNumber, int value) {
  final tag = _encodeVarint((fieldNumber << 3) | 0);
  return Uint8List.fromList([...tag, ...(_encodeVarint(value))]);
}

/// Encode a bytes/embedded-message field.
Uint8List _encodeBytesField(int fieldNumber, Uint8List data) {
  final tag = _encodeVarint((fieldNumber << 3) | 2);
  return Uint8List.fromList([...tag, ...(_encodeVarint(data.length)), ...data]);
}

/// Prefix a message with a 4-byte big-endian length header.
Uint8List _wrapWithLength(Uint8List msg) {
  final len = ByteData(4)..setUint32(0, msg.length, Endian.big);
  return Uint8List.fromList([...len.buffer.asUint8List(), ...msg]);
}

// ─────────────────────────────────────────────
// OuterMessage builder (polo.proto subset)
// ─────────────────────────────────────────────
//
// OuterMessage:
//   field 1: protocol_version (int32)
//   field 2: status           (int32, STATUS_OK = 200)
//   field 10: pairing_request (PairingRequest)
//   field 12: secret          (Secret)
//
// PairingRequest:
//   field 1: service_name (string)
//   field 2: client_name  (string)
//
// Secret:
//   field 3: secret (bytes)

Uint8List _buildPairingRequestMessage() {
  final pairingRequest = Uint8List.fromList([
    ..._encodeStringField(1, 'atvremote'),
    ..._encodeStringField(2, 'Antigravity Remote'),
  ]);

  final outer = Uint8List.fromList([
    ..._encodeVarintField(1, 2),        // protocol_version = 2
    ..._encodeVarintField(2, 200),      // status = STATUS_OK
    ..._encodeBytesField(10, pairingRequest),
  ]);

  return _wrapWithLength(outer);
}

Uint8List _buildSecretMessage(Uint8List secretBytes) {
  final secretMsg = _encodeBytesField(3, secretBytes);

  final outer = Uint8List.fromList([
    ..._encodeVarintField(1, 2),
    ..._encodeVarintField(2, 200),
    ..._encodeBytesField(12, Uint8List.fromList(secretMsg)),
  ]);

  return _wrapWithLength(outer);
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

  bool get isConnected => _isConnected;
  bool get isPairing => _isPairing;

  // ── Step 1: Try to connect (needs prior pairing token) ──────────────────

  Future<bool> connect(String ip) async {
    debugPrint('WifiService: Connecting to $ip...');

    final paired = await KeyService.isWifiPaired();
    if (!paired) {
      debugPrint('WifiService: Not paired yet.');
      _isPairing = true;
      return false;
    }

    try {
      _controlSocket = await SecureSocket.connect(
        ip,
        6466,
        onBadCertificate: (cert) => true,
        timeout: const Duration(seconds: 5),
      );

      _isConnected = true;
      _pairedIp = ip;

      _controlSocket!.listen(
        (data) => debugPrint('WifiService: control data len=${data.length}'),
        onDone: () => disconnect(),
        onError: (_) => disconnect(),
      );

      return true;
    } catch (e) {
      debugPrint('WifiService: Connection on 6466 failed: $e');
      _isConnected = false;
      return false;
    }
  }

  // ── Step 2: Start pairing ────────────────────────────────────────────────
  //
  // NOTE: We connect WITHOUT a client certificate first.
  // iOS SecureSocket still performs a TLS handshake and accepts the TV's
  // self-signed cert via onBadCertificate. The TV then displays the PIN
  // when it receives the PairingRequest protobuf message.

  Future<bool> startPairing(String ip) async {
    debugPrint('WifiService: Connecting to $ip:6467 for pairing...');

    try {
      _pairingSocket = await SecureSocket.connect(
        ip,
        6467,
        onBadCertificate: (cert) => true,
        timeout: const Duration(seconds: 5),
      );

      debugPrint('WifiService: Socket connected. Sending PairingRequest...');
      _pairingSocket!.add(_buildPairingRequestMessage());
      await _pairingSocket!.flush();
      debugPrint('WifiService: PairingRequest sent. TV should now show PIN.');

      _pairingSocket!.listen(
        (data) => debugPrint('WifiService: pairing data len=${data.length} hex=${data.take(8).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}'),
        onError: (e) => debugPrint('WifiService: pairing socket error: $e'),
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      debugPrint('WifiService: startPairing failed: $e');

      // Try port 6466 as some firmware versions use same port
      try {
        debugPrint('WifiService: Retrying on port 6466...');
        _pairingSocket = await SecureSocket.connect(
          ip,
          6466,
          onBadCertificate: (cert) => true,
          timeout: const Duration(seconds: 5),
        );
        _pairingSocket!.add(_buildPairingRequestMessage());
        await _pairingSocket!.flush();
        debugPrint('WifiService: PairingRequest sent on 6466.');
        return true;
      } catch (e2) {
        debugPrint('WifiService: All pairing attempts failed: $e2');
        return false;
      }
    }
  }

  // ── Step 3: Finish pairing with PIN ─────────────────────────────────────

  Future<bool> pair(String ip, String pin) async {
    debugPrint('WifiService: Finishing pairing with PIN=$pin...');

    if (_pairingSocket == null) {
      debugPrint('WifiService: No active pairing socket.');
      return false;
    }

    try {
      // The PIN shown on TV is hex-encoded. Convert to bytes.
      final pinBytes = Uint8List.fromList(
        List.generate(pin.length ~/ 2, (i) => int.parse(pin.substring(i * 2, i * 2 + 2), radix: 16)),
      );

      final completer = Completer<bool>();

      _pairingSocket!.listen(
        (data) {
          debugPrint('WifiService: SecretResponse len=${data.length}');
          // Any non-empty response means the TV accepted the secret
          if (!completer.isCompleted) completer.complete(data.isNotEmpty);
        },
        onError: (e) { if (!completer.isCompleted) completer.complete(false); },
        onDone: ()  { if (!completer.isCompleted) completer.complete(false); },
        cancelOnError: true,
      );

      _pairingSocket!.add(_buildSecretMessage(pinBytes));
      await _pairingSocket!.flush();

      final gotSuccess = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (gotSuccess) {
        await KeyService.setWifiPaired(true);
        _isPairing = false;
        _pairingSocket?.destroy();
        _pairingSocket = null;
        return true;
      } else {
        debugPrint('WifiService: Pairing rejected or timed out.');
        return false;
      }
    } catch (e) {
      debugPrint('WifiService: pair error: $e');
      return false;
    }
  }

  // ── Key events & text ────────────────────────────────────────────────────

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected || _controlSocket == null) return;
    debugPrint('WifiService: sendKeyEvent $keyCode');

    for (final dir in [0, 1]) { // Key down, then key up
      final keyEvent = Uint8List.fromList([
        ..._encodeVarintField(2, keyCode),
        ..._encodeVarintField(4, dir),
      ]);
      final remoteMsg = Uint8List.fromList([
        ..._encodeVarintField(1, 2),
        ..._encodeVarintField(2, 200),
        ..._encodeBytesField(6, keyEvent),
      ]);
      _controlSocket!.add(_wrapWithLength(remoteMsg));
    }
    await _controlSocket!.flush();
  }

  Future<void> sendText(String text) async {
    if (!_isConnected || _controlSocket == null) return;
    debugPrint('WifiService: sendText "$text"');

    final textInput = _encodeStringField(1, text);
    final remoteMsg = Uint8List.fromList([
      ..._encodeVarintField(1, 2),
      ..._encodeVarintField(2, 200),
      ..._encodeBytesField(8, Uint8List.fromList(textInput)),
    ]);
    _controlSocket!.add(_wrapWithLength(remoteMsg));
    await _controlSocket!.flush();
  }

  Future<void> setBrightness(int value) async {
    debugPrint('WifiService: setBrightness not supported via Remote v2 protocol');
  }

  void disconnect() {
    _isConnected = false;
    _isPairing = false;
    _pairedIp = null;
    _pairingSocket?.destroy();
    _controlSocket?.destroy();
    _pairingSocket = null;
    _controlSocket = null;
  }
}
