import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'key_service.dart';

// ─────────────────────────────────────────────
// Pre-generated client certificate (RSA 2048)
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

// client modulus/exp for secret computation
final _kClientMod = base64Decode('ox7SuxAXe+u40V18ulKGWIscl0XQlQvWPTe90K6wBcW7B7KDtLZSOaTH1Hc+D10pOYRaPItHPVuZ9OJmn1ocx3FgePpixxqZ/R4LHg6/mat24zRxCNdFDbuztvGBIeGmvQygpgEfzBUimKDyXz5bRJAOPSXCx45Zsl+aW1dTfWf+v1gjMUhZXHvRCBw2BcclM2Jq6skMDcg3ypNttTLrUNMoazVxM0pZihQPZpDlYAeH258rup4eWN+rZrMKKk8376NMmso3ujVHTBtDkyfsm8DZeNxb8hdE9uhL3Bb8rV90ozz/2TMi+zeD0JWSMhz4WSGI/nxa8tFufJqa0D/emw==');
final _kClientExp = Uint8List.fromList([0x01, 0x00, 0x01]);

// ─────────────────────────────────────────────
// Protobuf helpers
// ─────────────────────────────────────────────

Uint8List _varint(int v) {
  final out = <int>[];
  if (v == 0) return Uint8List.fromList([0]);
  while (v > 0x7F) { out.add((v & 0x7F) | 0x80); v >>= 7; }
  out.add(v);
  return Uint8List.fromList(out);
}

Uint8List _fv(int f, int v) => Uint8List.fromList([..._varint(f << 3), ..._varint(v)]);
Uint8List _fb(int f, Uint8List d) => Uint8List.fromList([..._varint((f << 3) | 2), ..._varint(d.length), ...d]);
Uint8List _fs(int f, String s) => _fb(f, Uint8List.fromList(utf8.encode(s)));

// V2 Framing: [Length Varint] [Payload]
Uint8List _frame(Uint8List msg) => Uint8List.fromList([..._varint(msg.length), ...msg]);

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

Uint8List _secret(Uint8List alpha) => _outer(_fb(40, _fb(1, alpha)));

// ─────────────────────────────────────────────
// Remote Control Protocol (V2) - Port 6466
// ─────────────────────────────────────────────

Uint8List _remoteConfigure() {
  final deviceInfo = Uint8List.fromList([
    ..._fv(3, 1),
    ..._fs(4, "1"),
    ..._fs(5, "atvremote"),
    ..._fs(6, "1.0.0"),
  ]);
  return _frame(Uint8List.fromList([
    ..._fb(1, Uint8List.fromList([
      ..._fv(1, 639), // Features: PING|KEY|IME|VOICE|UNKNOWN_1|POWER|VOLUME|APP_LINK
      ..._fb(2, deviceInfo),
    ])),
  ]));
}

Uint8List _remoteSetActive(int active) => _frame(_fb(2, _fv(1, active)));
Uint8List _remotePingResponse(int val1) => _frame(_fb(9, _fv(1, val1)));

Uint8List _remoteKeyInject(int keyCode, int direction) {
  final inject = Uint8List.fromList([
    ..._fv(1, keyCode),
    ..._fv(2, direction),
  ]);
  return _frame(_fb(10, inject));
}

// ─────────────────────────────────────────────
// Framed message reader
// ─────────────────────────────────────────────

class _MsgReader {
  final _buf = <int>[];
  final _ctrl = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get stream => _ctrl.stream;

  void feed(List<int> data) {
    _buf.addAll(data);
    while (_buf.isNotEmpty) {
      int i = 0, len = 0, shift = 0;
      while (i < _buf.length) {
        final b = _buf[i++];
        len |= (b & 0x7F) << shift;
        if (b & 0x80 == 0) break;
        shift += 7;
      }
      if (_buf.length < i + len) break;
      _ctrl.add(Uint8List.fromList(_buf.sublist(i, i + len)));
      _buf.removeRange(0, i + len);
    }
  }

  void close() => _ctrl.close();
}

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
  String? lastError;
  SecureSocket? _pairingSocket;
  SecureSocket? _controlSocket;
  _MsgReader? _reader;
  X509Certificate? _serverCert;

  bool get isConnected => _isConnected;
  bool get isPairing => _isPairing;

  SecurityContext _makeContext() {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(_kClientCert));
    ctx.usePrivateKeyBytes(utf8.encode(_kClientKey));
    return ctx;
  }

  Future<bool> connect(String ip) async {
    final paired = await KeyService.isWifiPaired();
    if (!paired) { _isPairing = true; return false; }
    try {
      _controlSocket = await SecureSocket.connect(ip, 6466, context: _makeContext(), onBadCertificate: (c) => true, timeout: const Duration(seconds: 5));
      _isConnected = true;
      
      final controlReader = _MsgReader();
      _controlSocket!.listen((d) => controlReader.feed(d), onDone: disconnect, onError: (_) => disconnect());
      
      final ready = Completer<bool>();
      controlReader.stream.listen((msg) {
        debugPrint('WifiService: Recv Control Msg: ${msg.map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');
        if (_hasField(msg, 1)) { // remote_configure
          debugPrint('WifiService: Responding to Configure');
          _controlSocket?.add(_remoteConfigure());
          _controlSocket?.flush();
        } else if (_hasField(msg, 2)) { // remote_set_active
          debugPrint('WifiService: Responding to SetActive');
          _controlSocket?.add(_remoteSetActive(639));
          _controlSocket?.flush();
        } else if (_hasField(msg, 8)) { // remote_ping_request
          _controlSocket?.add(_remotePingResponse(0));
          _controlSocket?.flush();
        } else if (_hasField(msg, 40)) { // remote_start
          debugPrint('WifiService: Remote session STARTED');
          if (!ready.isCompleted) ready.complete(true);
        } else if (_hasField(msg, 3)) { // remote_error
          debugPrint('WifiService: TV ERROR received in control stream!');
        }
      });

      return await ready.future.timeout(const Duration(seconds: 5), onTimeout: () => true);
    } catch (e) {
      lastError = 'Connect failed: $e';
      _isConnected = false;
      return false;
    }
  }

  Future<bool> startPairing(String ip) async {
    try {
      _pairingSocket = await SecureSocket.connect(ip, 6467, context: _makeContext(), onBadCertificate: (c) { _serverCert = c; return true; }, timeout: const Duration(seconds: 10));
    } catch (e) {
      try {
        _pairingSocket = await SecureSocket.connect(ip, 6466, context: _makeContext(), onBadCertificate: (c) { _serverCert = c; return true; }, timeout: const Duration(seconds: 10));
      } catch (e2) {
        lastError = 'Socket failed: $e2';
        return false;
      }
    }

    _reader = _MsgReader();
    _pairingSocket!.listen((d) => _reader?.feed(d), onError: (e) => debugPrint('Skt error: $e'), onDone: () => _reader?.close());

    _pairingSocket!.add(_pairingRequest());
    await _pairingSocket!.flush();

    final done = Completer<bool>();
    int step = 0;

    final sub = _reader!.stream.listen((msg) {
      if (done.isCompleted) return;
      if (step == 0 && _hasField(msg, 11)) {
        _pairingSocket?.add(_options());
        _pairingSocket?.flush();
        step = 1;
      } else if (step == 1 && _hasField(msg, 20)) {
        _pairingSocket?.add(_configuration());
        _pairingSocket?.flush();
        step = 2;
      } else if (step == 2 && _hasField(msg, 31)) {
        done.complete(true);
      }
    });

    final ok = await done.future.timeout(const Duration(seconds: 12), onTimeout: () => false);
    await sub.cancel();
    return ok;
  }

  Future<bool> pair(String ip, String pin) async {
    if (_pairingSocket == null || _serverCert == null) return false;
    try {
      // 1. Extract TV modulus/exp
      final tvMod = _extractModulus(_serverCert!.der);
      final tvExp = _extractExponent(_serverCert!.der);
      if (tvMod == null || tvExp == null) { lastError = 'Failed to extract TV key'; return false; }

      // 2. Compute Alpha (Secret) matches AndroidTVRemote2 Python Integer Hex algorithm perfectly
      final clientModBytes = _toHexBytes(_kClientMod);
      final clientExpBytes = _toHexBytes(_kClientExp, prependZero: true);
      final serverModBytes = _toHexBytes(tvMod);
      final serverExpBytes = _toHexBytes(tvExp, prependZero: true);

      final n1 = int.parse(pin.substring(2, 4), radix: 16);
      final n2 = int.parse(pin.substring(4, 6), radix: 16);
      final nonce = Uint8List.fromList([n1, n2]);
      
      final payload = <int>[...clientModBytes, ...clientExpBytes, ...serverModBytes, ...serverExpBytes, ...nonce];
      final alpha = Uint8List.fromList(sha256.convert(payload).bytes);

      // --- DIAGNOSTIC: Google TV Verify Hash Checksum ---
      final expectedPrefix = int.parse(pin.substring(0, 2), radix: 16);
      if (alpha[0] != expectedPrefix) {
        lastError = 'Hash mismatch! Expected ${expectedPrefix.toRadixString(16).padLeft(2, '0').toUpperCase()}, got ${alpha[0].toRadixString(16).padLeft(2, '0').toUpperCase()}. Mod(C: ${_kClientMod.length}, T: ${tvMod.length}) Exp(C: ${_kClientExp.length}, T: ${tvExp.length})';
        return false;
      }
      // -------------------------------------------------


      _reader ??= _MsgReader();
      final c = Completer<bool>();
      final sub = _reader!.stream.listen((msg) { 
        if (!c.isCompleted && _hasField(msg, 41)) c.complete(true); // Field 41 is SecretAck
      });

      _pairingSocket!.add(_secret(alpha));
      await _pairingSocket!.flush();

      final ack = await c.future.timeout(const Duration(seconds: 6), onTimeout: () => false);
      await sub.cancel();

      if (ack) {
        await KeyService.setWifiPaired(true);
        _isPairing = false;
        _pairingSocket?.destroy();
        _pairingSocket = null;
      }
      return ack;
    } catch (e) {
      lastError = 'Pair error: $e';
      return false;
    }
  }

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected || _controlSocket == null) {
      debugPrint('WifiService: Cannot send key $keyCode - Not Connected');
      return;
    }
    
    // Map keycodes for better Google TV WiFi compatibility
    int finalCode = keyCode;
    if (keyCode == 66) finalCode = 23;  // ENTER -> DPAD_CENTER
    
    // Many TCL/Google TVs use SETTINGS (176) instead of MENU (82)
    if (keyCode == 82) {
       debugPrint('WifiService: Sending MENU as SETTINGS (176)');
       finalCode = 176; 
    }
    
    debugPrint('WifiService: Sending KeyCode $finalCode (original: $keyCode)');
    
    // Direction 3 = SHORT press
    _controlSocket!.add(_remoteKeyInject(finalCode, 3));
    await _controlSocket!.flush();
  }

  Future<void> sendText(String text) async {
    if (!_isConnected || _controlSocket == null) return;
    final val = text.length - 1;
    final imeObj = Uint8List.fromList([..._fv(1, val), ..._fv(2, val), ..._fs(3, text)]);
    final editInfo = _fb(3, Uint8List.fromList([
      ..._fv(1, 1), // insert = 1
      ..._fb(2, imeObj),
    ]));
    final batchEdit = Uint8List.fromList([
      ..._fv(1, 0), // ime_counter
      ..._fv(2, 0), // field_counter
      ...editInfo,
    ]);
    _controlSocket!.add(_frame(_fb(21, batchEdit)));
    await _controlSocket!.flush();
  }

  Future<void> setBrightness(int value) async {
    debugPrint('WifiService: setBrightness not supported via Remote v2');
  }

  void disconnect() {
    _isConnected = false; _isPairing = false;
    _pairingSocket?.destroy(); _controlSocket?.destroy();
    _pairingSocket = null; _controlSocket = null;
  }

  // ── ASN.1 extraction helpers ─────────────────────────────────────────────

  Uint8List? _extractModulus(Uint8List der) {
    try {
      int i = 0;
      while (i < der.length - 64) {
        if (der[i] == 0x02) {
          int len = 0;
          int start = 0;
          if (der[i+1] == 0x81) {
            len = der[i+2]; start = i+3;
          } else if (der[i+1] == 0x82) {
            len = (der[i+2] << 8) | der[i+3]; start = i+4;
          } else if (der[i+1] < 0x80) {
            len = der[i+1]; start = i+2;
          }
          if (len >= 128) {
            if (der[start] == 0x00) { start++; len--; }
            return der.sublist(start, start + len);
          }
        }
        i++;
      }
    } catch (_) {}
    return null;
  }

  Uint8List? _extractExponent(Uint8List der) {
    try {
      final mod = _extractModulus(der);
      if (mod == null) return null;
      
      // Find the modulus in the DER, then the next INTEGER is the exponent
      int i = 0;
      while (i < der.length - mod.length) {
        bool match = true;
        for (int j = 0; j < mod.length; j++) if (der[i+j] != mod[j]) { match = false; break; }
        if (match) {
          int expIdx = i + mod.length;
          while (expIdx < der.length - 2) {
            if (der[expIdx] == 0x02 && der[expIdx+1] < 5) {
              return der.sublist(expIdx + 2, expIdx + 2 + der[expIdx+1]);
            }
            expIdx++;
          }
        }
        i++;
      }
    } catch (_) {}
    return Uint8List.fromList([0x01, 0x00, 0x01]);
  }

  // Exact Python mathematical integer hex-string encoding logic
  Uint8List _toHexBytes(Uint8List data, {bool prependZero = false}) {
    String hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
    int idx = 0;
    while (idx < hex.length - 1 && hex[idx] == '0') {
      idx++;
    }
    hex = hex.substring(idx);
    
    if (prependZero) {
      hex = '0' + hex;
    } else if (hex.length % 2 != 0) {
      hex = '0' + hex;
    }
    
    final out = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}

