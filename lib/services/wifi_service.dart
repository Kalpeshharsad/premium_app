import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'key_service.dart';

// ─────────────────────────────────────────────
// Minimal hand-rolled protobuf helpers
// (avoids adding a full protobuf dependency)
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

/// Encode a bytes field: tag (field<<3|2), length, data.
Uint8List _encodeBytesField(int fieldNumber, Uint8List data) {
  final tag = _encodeVarint((fieldNumber << 3) | 2);
  return Uint8List.fromList([...tag, ...(_encodeVarint(data.length)), ...data]);
}

/// Encode an embedded message field.
Uint8List _encodeMessageField(int fieldNumber, Uint8List inner) {
  return _encodeBytesField(fieldNumber, inner);
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
  // PairingRequest inner message
  final pairingRequest = Uint8List.fromList([
    ..._encodeStringField(1, 'atvremote'),
    ..._encodeStringField(2, 'Antigravity Remote'),
  ]);

  // OuterMessage wrapper
  final outer = Uint8List.fromList([
    ..._encodeVarintField(1, 2),        // protocol_version = 2
    ..._encodeVarintField(2, 200),      // status = STATUS_OK
    ..._encodeMessageField(10, pairingRequest), // pairing_request field
  ]);

  return _wrapWithLength(outer);
}

Uint8List _buildSecretMessage(Uint8List secretBytes) {
  // Secret inner message: field 3 = secret bytes
  final secretMsg = _encodeBytesField(3, secretBytes);

  // OuterMessage wrapper
  final outer = Uint8List.fromList([
    ..._encodeVarintField(1, 2),   // protocol_version = 2
    ..._encodeVarintField(2, 200), // status = STATUS_OK
    ..._encodeMessageField(12, Uint8List.fromList(secretMsg)),
  ]);

  return _wrapWithLength(outer);
}

/// Prefix a message with a 4-byte big-endian length header.
Uint8List _wrapWithLength(Uint8List msg) {
  final len = ByteData(4)..setUint32(0, msg.length, Endian.big);
  return Uint8List.fromList([...len.buffer.asUint8List(), ...msg]);
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

  // Store server cert bytes received during pairing TLS handshake
  X509Certificate? _serverCert;

  bool get isConnected => _isConnected;
  bool get isPairing => _isPairing;

  // ── Step 1: Try to connect (needs prior pairing token) ──────────────────

  Future<bool> connect(String ip) async {
    debugPrint('WifiService: Connecting to $ip...');

    final paired = await KeyService.isWifiPaired();
    if (!paired) {
      debugPrint('WifiService: Not paired yet, need to pair first.');
      _isPairing = true;
      return false;
    }

    try {
      final ctx = await _buildSecurityContext();
      _controlSocket = await SecureSocket.connect(
        ip,
        6466, // Control port
        context: ctx,
        onBadCertificate: (cert) {
          _serverCert = cert;
          return true; // Accept self-signed TV cert
        },
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
      debugPrint('WifiService: Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  // ── Step 2: Start pairing — connects on port 6467, sends PairingRequest ─

  Future<bool> startPairing(String ip) async {
    debugPrint('WifiService: Starting pairing with $ip on port 6467...');

    // Ensure we have RSA keys; generate if needed
    await _ensureKeys();

    try {
      final ctx = await _buildSecurityContext();
      _pairingSocket = await SecureSocket.connect(
        ip,
        6467, // Pairing port
        context: ctx,
        onBadCertificate: (cert) {
          _serverCert = cert;
          return true;
        },
        timeout: const Duration(seconds: 5),
      );

      debugPrint('WifiService: Pairing socket connected. Sending PairingRequest...');

      // Send PairingRequest protobuf
      _pairingSocket!.add(_buildPairingRequestMessage());
      await _pairingSocket!.flush();

      debugPrint('WifiService: PairingRequest sent. TV should now show PIN.');

      // Listen but don't block — response comes when TV shows PIN
      _pairingSocket!.listen(
        (data) => debugPrint('WifiService: pairing data len=${data.length} bytes=${data.take(8).toList()}'),
        onError: (e) => debugPrint('WifiService: pairing socket error: $e'),
      );

      return true;
    } catch (e) {
      debugPrint('WifiService: startPairing failed: $e');
      return false;
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
      // Compute secret: SHA-256 over (clientModulus, clientExponent, serverModulus, serverExponent, lastTwoHexOfPin)
      final secretBytes = await _computePairingSecret(pin);
      if (secretBytes == null) {
        debugPrint('WifiService: Failed to compute pairing secret.');
        return false;
      }

      final completer = Completer<bool>();

      _pairingSocket!.listen(
        (data) {
          debugPrint('WifiService: SecretResponse len=${data.length} bytes=${data.take(8).toList()}');
          // Outer status field indicates success.
          // Field 2 (status) with value 200 indicates STATUS_OK.
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (e) { if (!completer.isCompleted) completer.complete(false); },
        onDone: ()  { if (!completer.isCompleted) completer.complete(false); },
        cancelOnError: true,
      );

      _pairingSocket!.add(_buildSecretMessage(secretBytes));
      await _pairingSocket!.flush();

      final gotSuccess = await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );

      if (gotSuccess) {
        await KeyService.setWifiPaired(true);
        _isPairing = false;
        _isConnected = false; // Will reconnect on control port
        _pairingSocket?.destroy();
        _pairingSocket = null;
        debugPrint('WifiService: Pairing successful!');
        return true;
      } else {
        debugPrint('WifiService: Pairing secret rejected or timed out.');
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
    debugPrint('WifiService: sendKeyEvent $keyCode to $_pairedIp');

    // RemoteMessage.key_event: field 6 = KeyEvent, which has field 2 = key_code (varint)
    // and field 4 = direction (0=DOWN, 1=UP)
    for (final dir in [0, 1]) { // Send key down then key up
      final keyEvent = Uint8List.fromList([
        ..._encodeVarintField(2, keyCode),
        ..._encodeVarintField(4, dir),
      ]);
      final remoteMsg = Uint8List.fromList([
        ..._encodeVarintField(1, 2),
        ..._encodeVarintField(2, 200),
        ..._encodeMessageField(6, keyEvent),
      ]);
      _controlSocket!.add(_wrapWithLength(remoteMsg));
    }
    await _controlSocket!.flush();
  }

  Future<void> sendText(String text) async {
    if (!_isConnected || _controlSocket == null) return;
    debugPrint('WifiService: sendText "$text"');

    // TextInput message: field 1 = text (string)
    final textInput = _encodeStringField(1, text);
    final remoteMsg = Uint8List.fromList([
      ..._encodeVarintField(1, 2),
      ..._encodeVarintField(2, 200),
      ..._encodeMessageField(8, Uint8List.fromList(textInput)),
    ]);
    _controlSocket!.add(_wrapWithLength(remoteMsg));
    await _controlSocket!.flush();
  }

  Future<void> setBrightness(int value) async {
    if (!_isConnected) return;
    debugPrint('WifiService: setBrightness $value (not supported via Remote v2 protocol)');
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

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Build a SecurityContext with the client RSA key and a minimal self-signed cert.
  Future<SecurityContext> _buildSecurityContext() async {
    final certPem = await KeyService.getWifiCertPem();
    final keyPem = await KeyService.getWifiKeyPem();

    if (certPem == null || keyPem == null) {
      throw StateError('WifiService: Missing client certificate/key.');
    }

    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(utf8.encode(certPem));
    ctx.usePrivateKeyBytes(utf8.encode(keyPem));

    return ctx;
  }

  /// Ensure RSA key pair exists, generate if needed, and build PEM cert.
  Future<void> _ensureKeys() async {
    var certPem = await KeyService.getWifiCertPem();
    if (certPem != null) return; // Already have keys

    debugPrint('WifiService: Generating RSA key pair for WiFi pairing...');

    // Generate 2048-bit RSA key pair using pointycastle
    final secureRandom = FortunaRandom();
    final seed = Uint8List(32);
    final rng = Random.secure();
    for (var i = 0; i < 32; i++) seed[i] = rng.nextInt(256);
    secureRandom.seed(KeyParameter(seed));

    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    // Build minimal self-signed certificate DER bytes
    final certDer = _buildSelfSignedCert(publicKey, privateKey);

    // Convert to PEM
    final certPemStr = _toPem('CERTIFICATE', certDer);
    final keyPemStr = _buildPrivateKeyPem(privateKey);

    await KeyService.saveWifiCertPem(certPemStr);
    await KeyService.saveWifiKeyPem(keyPemStr);

    debugPrint('WifiService: Generated and saved WiFi RSA key pair + cert.');
  }

  /// Compute pairing secret: SHA-256(clientMod + clientExp + serverMod + serverExp + pin[2..])
  Future<Uint8List?> _computePairingSecret(String pin) async {
    if (pin.length != 6) return null;

    final certPem = await KeyService.getWifiCertPem();
    if (certPem == null) return null;

    // Parse client RSA public key modulus and exponent from stored PEM cert
    // (simplified: we re-read from KeyService which stored the raw numbers)
    final clientMod = await KeyService.getWifiModulus();
    final clientExp = BigInt.from(65537);

    if (clientMod == null) {
      debugPrint('WifiService: Cannot compute secret — client modulus missing');
      return null;
    }

    // Server cert modulus and exponent (from TLS handshake via _serverCert)
    // For now we use a simplified approach: derive from the connection
    // The real protocol computes hash over big-endian bytes of all four numbers
    BigInt serverMod;
    BigInt serverExp;

    if (_serverCert != null) {
      // Extract from DER bytes — parse the SubjectPublicKeyInfo manually
      final parsed = _parseServerCertPublicKey(_serverCert!.der);
      serverMod = parsed.$1;
      serverExp = parsed.$2;
    } else {
      debugPrint('WifiService: No server cert captured, cannot compute secret');
      return null;
    }

    // Helper: strip leading zeros and convert BigInt to big-endian bytes
    Uint8List bigIntToBytes(BigInt n) {
      final hex = n.toRadixString(16).padLeft((n.toRadixString(16).length + 1) & ~1, '0');
      final bytes = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
      return Uint8List.fromList(bytes);
    }

    try {
      final pinData = Uint8List.fromList([ int.parse(pin.substring(4), radix: 16) ]);
      final h = sha256.convert([
        ...bigIntToBytes(clientMod),
        ...bigIntToBytes(clientExp),
        ...bigIntToBytes(serverMod),
        ...bigIntToBytes(serverExp),
        ...pinData,
      ]);
      return Uint8List.fromList(h.bytes);
    } catch (e) {
      debugPrint('WifiService: Secret computation failed: $e');
      return null;
    }
  }

  // ── Certificate generation helpers ──────────────────────────────────────

  /// Build a minimal ASN1 self-signed X.509v3 DER certificate.
  Uint8List _buildSelfSignedCert(RSAPublicKey pub, RSAPrivateKey priv) {
    // TBSCertificate fields (simplified, no extensions)
    final version = _asn1ContextConstructed(0, _asn1Integer([2]));
    final serial = _asn1Integer([1]);
    final algId = _rsaSha256AlgId();
    final issuer = _buildName('Antigravity Remote');
    final validity = _buildValidity();
    final subject = _buildName('Antigravity Remote');
    final spki = _buildSPKI(pub);

    final tbs = _asn1Sequence([
      ...version, ...serial, ...algId,
      ...issuer, ...validity, ...subject, ...spki,
    ]);

    // Sign TBS with RSA-SHA256
    final sig = _signWithRsa(Uint8List.fromList(tbs), priv);
    final sigBitString = _asn1BitString(Uint8List.fromList(sig));

    return Uint8List.fromList(_asn1Sequence([...tbs, ...algId, ...sigBitString]));
  }

  Uint8List _signWithRsa(Uint8List data, RSAPrivateKey priv) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(priv));
    final sig = signer.generateSignature(data) as RSASignature;
    return Uint8List.fromList(sig.bytes);
  }

  Uint8List _buildSPKI(RSAPublicKey pub) {
    final modBytes = _bigIntToAsn1Bytes(pub.modulus!);
    final expBytes = _bigIntToAsn1Bytes(pub.publicExponent!);
    final inner = Uint8List.fromList(_asn1Sequence([..._asn1Integer(modBytes), ..._asn1Integer(expBytes)]));
    final bitStr = Uint8List.fromList([0x00, ...inner]);
    return Uint8List.fromList(_asn1Sequence([..._rsaSha256AlgId(), ..._asn1BitString(bitStr)]));
  }

  List<int> _bigIntToAsn1Bytes(BigInt n) {
    final hex = n.toRadixString(16).padLeft((n.toRadixString(16).length + 1) & ~1, '0');
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    if (bytes.first & 0x80 != 0) return [0x00, ...bytes];
    return bytes;
  }

  List<int> _asn1Integer(List<int> bytes) => [0x02, ...(_length(bytes.length)), ...bytes];
  List<int> _asn1BitString(Uint8List bytes) => [0x03, ...(_length(bytes.length)), ...bytes];
  List<int> _asn1Sequence(List<int> content) => [0x30, ...(_length(content.length)), ...content];
  List<int> _asn1ContextConstructed(int tag, List<int> content) => [0xA0 | tag, ...(_length(content.length)), ...content];

  List<int> _length(int len) {
    if (len < 128) return [len];
    if (len < 256) return [0x81, len];
    return [0x82, len >> 8, len & 0xFF];
  }

  List<int> _rsaSha256AlgId() {
    // SEQUENCE { OID rsaEncryption, NULL }
    return _asn1Sequence([
      0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00
    ]);
  }

  List<int> _buildName(String cn) {
    final cnBytes = utf8.encode(cn);
    final utf8Str = [0x0C, ...(_length(cnBytes.length)), ...cnBytes];
    final atv = _asn1Sequence([
      0x06, 0x03, 0x55, 0x04, 0x03, // OID commonName
      ...utf8Str,
    ]);
    return _asn1Sequence([..._asn1Sequence([...atv])]);
  }

  List<int> _buildValidity() {
    // 20 year validity from fixed date (simplified)
    const notBefore = '240101000000Z'; // GeneralizedTime 2024-01-01
    const notAfter  = '440101000000Z'; // GeneralizedTime 2044-01-01
    final nb = notBefore.codeUnits;
    final na = notAfter.codeUnits;
    return _asn1Sequence([
      0x18, nb.length, ...nb,
      0x18, na.length, ...na,
    ]);
  }

  String _toPem(String label, Uint8List der) {
    final b64 = base64.encode(der);
    final lines = RegExp(r'.{1,64}').allMatches(b64).map((m) => m.group(0)!).join('\n');
    return '-----BEGIN $label-----\n$lines\n-----END $label-----\n';
  }

  String _buildPrivateKeyPem(RSAPrivateKey key) {
    // Build minimal PKCS#1 RSA private key DER
    final ver = _asn1Integer([0]);
    final n   = _asn1Integer(_bigIntToAsn1Bytes(key.modulus!));
    final e   = _asn1Integer(_bigIntToAsn1Bytes(key.publicExponent!));
    final d   = _asn1Integer(_bigIntToAsn1Bytes(key.privateExponent!));
    final p   = _asn1Integer(_bigIntToAsn1Bytes(key.p!));
    final q   = _asn1Integer(_bigIntToAsn1Bytes(key.q!));
    // dp, dq, qInv (required in PKCS#1 format)
    final dp  = _asn1Integer(_bigIntToAsn1Bytes(key.privateExponent! % (key.p! - BigInt.one)));
    final dq  = _asn1Integer(_bigIntToAsn1Bytes(key.privateExponent! % (key.q! - BigInt.one)));
    final qi  = _asn1Integer(_bigIntToAsn1Bytes(key.q!.modInverse(key.p!)));
    final der = Uint8List.fromList(_asn1Sequence([...ver, ...n, ...e, ...d, ...p, ...q, ...dp, ...dq, ...qi]));
    return _toPem('RSA PRIVATE KEY', der);
  }

  /// Parse server certificate DER to extract RSA public key modulus and exponent.
  (BigInt, BigInt) _parseServerCertPublicKey(Uint8List der) {
    // Walk ASN.1 DER to find SubjectPublicKeyInfo
    // This is a best-effort parser for standard X.509 RSA certs
    try {
      int i = 0;
      int readLen() {
        if (der[i] & 0x80 == 0) return der[i++];
        final numBytes = der[i++] & 0x7F;
        int l = 0;
        for (var k = 0; k < numBytes; k++) l = (l << 8) | der[i++];
        return l;
      }

      // Skip outer SEQUENCE tag
      i++; readLen();
      // Skip TBSCertificate SEQUENCE tag
      i++; readLen(); // tbsCertificate sequence - length consumed, position advanced
      
      // Skip version [0] if present
      if (der[i] == 0xA0) { i++; final l = readLen(); i += l; }
      // Skip serial integer
      i++; final slen = readLen(); i += slen;
      // Skip signature alg SEQUENCE
      i++; final alen = readLen(); i += alen;
      // Skip issuer SEQUENCE
      i++; final ilen = readLen(); i += ilen;
      // Skip validity SEQUENCE
      i++; final vlen = readLen(); i += vlen;
      // Skip subject SEQUENCE
      i++; final sjlen = readLen(); i += sjlen;
      // Now at SubjectPublicKeyInfo SEQUENCE
      i++; readLen(); // spki sequence
      // Skip alg id SEQUENCE
      i++; final spkiAlen = readLen(); i += spkiAlen;
      // BIT STRING
      i++; readLen(); i++; // skip unused bits byte
      // RSAPublicKey SEQUENCE
      i++; readLen();
      // modulus INTEGER
      i++; final modLen = readLen();
      final modStart = i; i += modLen;
      // exponent INTEGER
      i++; final expLen = readLen();

      BigInt bytesToBigInt(int start, int len) {
        var result = BigInt.zero;
        for (var k = start; k < start + len; k++) result = (result << 8) | BigInt.from(der[k]);
        return result;
      }

      final modulus = bytesToBigInt(modStart + (der[modStart] == 0 ? 1 : 0), modLen - (der[modStart] == 0 ? 1 : 0));
      final exponent = bytesToBigInt(i, expLen);
      return (modulus, exponent);
    } catch (e) {
      debugPrint('WifiService: Failed to parse server cert: $e');
      return (BigInt.one, BigInt.one);
    }
  }
}
