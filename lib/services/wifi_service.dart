import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'key_service.dart';

// ─────────────────────────────────────────────
// Pre-generated client certificate (RSA 2048)
// Generated with: openssl req -x509 -newkey rsa:2048 -days 7300 -nodes
// The TV uses this to identify the remote app.
// ─────────────────────────────────────────────

const _kClientKey = '''-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCjHtK7EBd767jR
XXy6UoZYixyXRdCVC9Y9N73QrrAFxbsHsoO0tlI5pMfUdz4PXSk5hFo8i0c9W5n0
4mafWhzHcWB4+mLHGpn9HgseDr+Zq3bjNHEI10UNu7O28YEh4aa9DKCmAR/MFSKY
oPJfPltEkA49JcLHjlmyX5pbV1N9Z/6/WCMxSFlce9EIHDYFxyUzYmrqyQwNyDfK
k221MutQ0yhrNXEzSlmKFA9mkOVgB4fbnyu6nh5Y36tmswoqTzfvo0yayje6NUdM
G0OTJ+ybwNl43FvyF0T26EvcFvytX3SjPP/ZMyL7N4PQlZIyHPhZIYj+fFry0W58
mprQP96bAgMBAAECggEAUD77G1R8wRVDHBg6Im0zsz5oZ9DMHm6uy/nukslFRemy
q0Q6P74LsFjsh4zLxoIlpCqEu9Em0DwOfqacJpuNmd4gQBOpYVqoU5mijXxi7KWp
/HcRfnBsg6eJ7x9a0ACy5sDeDRxzeJITLXPMGGfUPWQC5Tj82/AfFz2p8XKB26hx
xzUFhzmaQxM2F5bFYpcpEFTMgvlTXkisBZoeP+N2It999wI4rP/mQPyLUIQeXu7t
nl2oBGSS8Ls+qFU+0wYA6eb1sjep27RHrUd5aMA+eukos153XINoAvFIDhVKdjfw
QougFvP0FpJ6/yexxfZo2RSYbn9dtY12QzVcNtR5DQKBgQDixZ3dCNbwRR5ipAy7
zFfybDIEYCfqF+NGo1vuT7qKkEIwEwEGzrW7rtKI0GotvhDf4ygaMrj9AP5Ht4PB
3eStB8O6x26zQ9nJ2aLHqzNooZJRkvqxuThDVr0PjbKfjs6AVHvu2X4W0tNLLZNw
gSZtVjmzto38amcHEK+H5F9sLwKBgQC4JQMNnfBcSkE0vN26QJOKPKGqorSt1BWG
wzkicF7gnNJoV8I0WWt4ybiq+wODyTG7UqEX9ESP9iM2KnFvm+FdttKuhD3ApaYb
L2fMxcNMsQjONJGb16bSB1G+ACU1xF91X64MWme8d+7h726zQYj41ogTorbmhwZU
YBYRQaJ9VQKBgQCW5l1n6ivs8nGHvhZjGVUkke6ujrXAxmiMZsQTzqYY8mm4x8yV
FRRFcc3TEKy3B5T/Bo927229nd2XJ3zbkqZKpbIPJgp565qPAO2a5EdvRqSw95cu
kEvqM1vXb7j/B+5N4uodREjtMxk7G3bTFH3Xn9sBxWayIrOwNeA4EzWULQKBgQCs
DSDiKyx1/ocYMFL2//kaUvY2SVmJhLwsMuGCNP3g3YWWKlDwuo+4xrk9P9UT3/sQ
a+7KQ9d/rtlNdbCROFMETZphpntQMTWW9t8EK88DK/HvQJy/wGlEmcQdQ2OA7h7G
uwQS1LFSHbjb7us+nz/MSB3SQtijYYtfcHuN2gZpFQKBgBROVNgQjoTjSq9Dinz1
4Jj6t6xzhOub0yYJoUg30ng5FubAJK6YXO+gx3v0Ol5D4HWEHVY/2CdTINsGm8/R
+R5dnrqiaaIMxPABxHrRBRPsX6qvYRXhfySNlP+7DpkqsK9OH3LV5vEeTufZPmJE
ETtKeUWhtzCb1v6A5jyeiayS
-----END PRIVATE KEY-----''';

const _kClientCert = '''-----BEGIN CERTIFICATE-----
MIIDGzCCAgOgAwIBAgIUNkaholgpK8J9vtb8Rw7cQpTmwC4wDQYJKoZIhvcNAQEL
BQAwHTEbMBkGA1UEAwwSQW50aWdyYXZpdHkgUmVtb3RlMB4XDTI2MDMzMTIwNDU0
OFoXDTQ2MDMyNjIwNDU0OFowHTEbMBkGA1UEAwwSQW50aWdyYXZpdHkgUmVtb3Rl
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAox7SuxAXe+u40V18ulKG
WIscl0XQlQvWPTe90K6wBcW7B7KDtLZSOaTH1Hc+D10pOYRaPItHPVuZ9OJmn1oc
x3FgePpixxqZ/R4LHg6/mat24zRxCNdFDbuztvGBIeGmvQygpgEfzBUimKDyXz5b
RJAOPSXCx45Zsl+aW1dTfWf+v1gjMUhZXHvRCBw2BcclM2Jq6skMDcg3ypNttTLr
UNMoazVxM0pZihQPZpDlYAeH258rup4eWN+rZrMKKk8376NMmso3ujVHTBtDkyfs
m8DZeNxb8hdE9uhL3Bb8rV90ozz/2TMi+zeD0JWSMhz4WSGI/nxa8tFufJqa0D/e
mwIDAQABo1MwUTAdBgNVHQ4EFgQUKmy99mLsSKuwRIRxo2czfp5R5NQwHwYDVR0j
BBgwFoAUKmy99mLsSKuwRIRxo2czfp5R5NQwDwYDVR0TAQH/BAUwAwEB/zANBgkq
hkiG9w0BAQsFAAOCAQEAWNDTx1OEqmfBQQpAMB0yTmgRI6+TQxmbJJEPjUd/Q9rf
wHk2Mk/GIHns0+23dmQnyoL8pggukxsZsFVSkRNKShEkWLvDwUI3ZUZOxuh/flDB
P8NRfw6SaG6Tw2Fp1PCMyhgA2aA2vb6XNwzlT7jcMgnevytrLWaJzO+zXz2UQ7bY
zc/93hR60fP1b7/iHbVlzMo3f4ARibywBn9E3Qg/e7U3173lSDsuTNAQ1tt3b7s/
HvHyzBohmWvHZvtx6kEa8SP++xOxu7Z2EFdom+gwaXn2NZHGdzL28wbn9N7HD5lP
yHf5+yjm+LbZYYk2XnCQEb2yRFXzSA8J2u98hyJiKQ==
-----END CERTIFICATE-----''';

// ─────────────────────────────────────────────
// Protobuf helpers
// ─────────────────────────────────────────────

Uint8List _varint(int v) {
  final out = <int>[];
  while (v > 0x7F) { out.add((v & 0x7F) | 0x80); v >>= 7; }
  out.add(v);
  return Uint8List.fromList(out);
}

Uint8List _fv(int f, int v) => Uint8List.fromList([..._varint(f << 3), ..._varint(v)]);
Uint8List _fb(int f, Uint8List d) => Uint8List.fromList([..._varint((f << 3) | 2), ..._varint(d.length), ...d]);
Uint8List _fs(int f, String s) => _fb(f, Uint8List.fromList(utf8.encode(s)));

Uint8List _frame(Uint8List msg) {
  final hdr = ByteData(4)..setUint32(0, msg.length, Endian.big);
  return Uint8List.fromList([...hdr.buffer.asUint8List(), ...msg]);
}

Uint8List _outer(Uint8List payload) => _frame(Uint8List.fromList([
  ..._fv(1, 2),   // protocol_version = 2
  ..._fv(2, 200), // status = STATUS_OK
  ...payload,
]));

// Messages
Uint8List _pairingRequest() => _outer(_fb(10, Uint8List.fromList([
  ..._fs(1, 'atvremote'),
  ..._fs(2, 'Antigravity Remote'),
])));

Uint8List _options() {
  final enc = Uint8List.fromList([..._fv(1, 3), ..._fv(2, 6)]); // HEXADECIMAL, len=6
  return _outer(_fb(20, Uint8List.fromList([
    ..._fb(1, enc), // input_encodings
    ..._fb(2, enc), // output_encodings
    ..._fv(3, 1),   // preferred_role = ROLE_TYPE_INPUT
  ])));
}

Uint8List _configuration() {
  final enc = Uint8List.fromList([..._fv(1, 3), ..._fv(2, 6)]);
  return _outer(_fb(30, Uint8List.fromList([
    ..._fb(1, enc), // encoding
    ..._fv(2, 1),   // client_role = ROLE_TYPE_INPUT
  ])));
}

Uint8List _secret(Uint8List secretBytes) => _outer(_fb(40, _fb(3, secretBytes)));

// ─────────────────────────────────────────────
// Framed message reader
// ─────────────────────────────────────────────

class _MsgReader {
  final _buf = <int>[];
  final _ctrl = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get stream => _ctrl.stream;

  void feed(List<int> data) {
    _buf.addAll(data);
    while (_buf.length >= 4) {
      final len = ByteData.sublistView(Uint8List.fromList(_buf.sublist(0, 4))).getUint32(0, Endian.big);
      if (_buf.length < 4 + len) break;
      _ctrl.add(Uint8List.fromList(_buf.sublist(4, 4 + len)));
      _buf.removeRange(0, 4 + len);
    }
  }

  void close() => _ctrl.close();
}

// Check if a raw protobuf message contains a given field number
bool _hasField(Uint8List msg, int field) {
  try {
    int i = 0;
    while (i < msg.length) {
      int tag = 0, s = 0;
      while (i < msg.length) { final b = msg[i++]; tag |= (b & 0x7F) << s; if (b & 0x80 == 0) break; s += 7; }
      if (tag >> 3 == field) return true;
      switch (tag & 7) {
        case 0: while (i < msg.length && msg[i++] & 0x80 != 0) {} break;
        case 2: int l = 0, ls = 0; while (i < msg.length) { final b = msg[i++]; l |= (b & 0x7F) << ls; if (b & 0x80 == 0) break; ls += 7; } i += l; break;
        case 5: i += 4; break;
        case 1: i += 8; break;
        default: return false;
      }
    }
  } catch (_) {}
  return false;
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
  _MsgReader? _reader;

  bool get isConnected => _isConnected;
  bool get isPairing => _isPairing;

  SecurityContext _makeContext() {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(_kClientCert));
    ctx.usePrivateKeyBytes(utf8.encode(_kClientKey));
    return ctx;
  }

  // ── Connect (post-pairing) ───────────────────────────────────────────────

  Future<bool> connect(String ip) async {
    debugPrint('WifiService: connect($ip)');
    final paired = await KeyService.isWifiPaired();
    if (!paired) { _isPairing = true; return false; }

    try {
      _controlSocket = await SecureSocket.connect(
        ip, 6466,
        context: _makeContext(),
        onBadCertificate: (c) => true,
        timeout: const Duration(seconds: 5),
      );
      _isConnected = true;
      _pairedIp = ip;
      _controlSocket!.listen((_) {}, onDone: disconnect, onError: (_) => disconnect());
      return true;
    } catch (e) {
      debugPrint('WifiService: connect failed: $e');
      _isConnected = false;
      return false;
    }
  }

  // ── Pairing step 1: full handshake so TV shows PIN ───────────────────────

  Future<bool> startPairing(String ip) async {
    debugPrint('WifiService: startPairing($ip)');

    // Try port 6467 with mutual TLS
    try {
      _pairingSocket = await SecureSocket.connect(
        ip, 6467,
        context: _makeContext(),
        onBadCertificate: (c) => true,
        timeout: const Duration(seconds: 5),
      );
      debugPrint('WifiService: connected on 6467 with client cert');
    } catch (e) {
      debugPrint('WifiService: 6467 failed ($e), trying 6466...');
      try {
        _pairingSocket = await SecureSocket.connect(
          ip, 6466,
          context: _makeContext(),
          onBadCertificate: (c) => true,
          timeout: const Duration(seconds: 5),
        );
        debugPrint('WifiService: connected on 6466 with client cert');
      } catch (e2) {
        debugPrint('WifiService: all ports failed: $e2');
        return false;
      }
    }

    _reader = _MsgReader();
    _pairingSocket!.listen(
      (d) { debugPrint('WifiService: raw ${d.length}b'); _reader?.feed(d); },
      onError: (e) => debugPrint('WifiService: socket error $e'),
      onDone: () { debugPrint('WifiService: socket closed'); _reader?.close(); },
    );

    // Send PairingRequest
    _pairingSocket!.add(_pairingRequest());
    await _pairingSocket!.flush();
    debugPrint('WifiService: → PairingRequest');

    final done = Completer<bool>();
    int step = 0;

    final sub = _reader!.stream.listen((msg) {
      final f11 = _hasField(msg, 11), f20 = _hasField(msg, 20), f31 = _hasField(msg, 31);
      debugPrint('WifiService: ← msg step=$step f11=$f11 f20=$f20 f31=$f31');

      if (!done.isCompleted) {
        if (step == 0 && f11) {
          _pairingSocket?.add(_options());
          _pairingSocket?.flush();
          debugPrint('WifiService: → Options');
          step = 1;
        } else if (step == 1 && f20) {
          _pairingSocket?.add(_configuration());
          _pairingSocket?.flush();
          debugPrint('WifiService: → Configuration');
          step = 2;
        } else if (step == 2 && f31) {
          debugPrint('WifiService: handshake done — TV showing PIN');
          done.complete(true);
        }
      }
    });

    final ok = await done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () { debugPrint('WifiService: handshake timeout at step=$step'); return false; },
    );
    await sub.cancel();
    return ok;
  }

  // ── Pairing step 2: send PIN ─────────────────────────────────────────────

  Future<bool> pair(String ip, String pin) async {
    debugPrint('WifiService: pair PIN=$pin');
    if (_pairingSocket == null) return false;

    try {
      // PIN is 6 hex chars → 3 bytes
      final secretBytes = Uint8List.fromList(
        List.generate(pin.length ~/ 2, (i) => int.parse(pin.substring(i * 2, i * 2 + 2), radix: 16)),
      );

      _reader ??= _MsgReader();
      final c = Completer<bool>();

      final sub = _reader!.stream.listen((msg) {
        if (!c.isCompleted) c.complete(_hasField(msg, 41)); // SecretAck
      });

      _pairingSocket!.add(_secret(secretBytes));
      await _pairingSocket!.flush();
      debugPrint('WifiService: → Secret');

      final ok = await c.future.timeout(const Duration(seconds: 6), onTimeout: () => false);
      await sub.cancel();

      if (ok) {
        await KeyService.setWifiPaired(true);
        _isPairing = false;
        _pairingSocket?.destroy();
        _pairingSocket = null;
        _reader = null;
      }
      return ok;
    } catch (e) {
      debugPrint('WifiService: pair error $e');
      return false;
    }
  }

  // ── Controls ─────────────────────────────────────────────────────────────

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected || _controlSocket == null) return;
    for (final dir in [0, 1]) {
      final keyEvent = Uint8List.fromList([..._fv(2, keyCode), ..._fv(4, dir)]);
      _controlSocket!.add(_frame(Uint8List.fromList([
        ..._fv(1, 2), ..._fv(2, 200), ..._fb(6, keyEvent),
      ])));
    }
    await _controlSocket!.flush();
  }

  Future<void> sendText(String text) async {
    if (!_isConnected || _controlSocket == null) return;
    _controlSocket!.add(_frame(Uint8List.fromList([
      ..._fv(1, 2), ..._fv(2, 200), ..._fb(8, _fs(1, text)),
    ])));
    await _controlSocket!.flush();
  }

  Future<void> setBrightness(int value) async {}

  void disconnect() {
    _isConnected = false;
    _isPairing = false;
    _pairedIp = null;
    _pairingSocket?.destroy();
    _controlSocket?.destroy();
    _pairingSocket = null;
    _controlSocket = null;
    _reader?.close();
    _reader = null;
  }
}
