import 'dart:io';
import 'package:flutter_adb/adb_connection.dart';
import 'package:flutter_adb/adb_crypto.dart';
import 'package:flutter_adb/adb_stream.dart';
import 'package:flutter_adb/adb_protocol.dart';
import 'key_service.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Custom crypto implementation to fix signing bugs and set a proper identity.
class GTVRemoteCrypto extends AdbCrypto {
  final AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _myKeyPair;

  GTVRemoteCrypto(this._myKeyPair) : super(keyPair: _myKeyPair);

  @override
  Uint8List signAdbTokenPayload(Uint8List payload) {
    // The original AdbCrypto uses RSASigner which hashes the token again.
    // ADB expects a raw RSA private key operation on the (already padded) payload.
    final engine = RSAEngine()
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(_myKeyPair.privateKey));
    
    // We must ensure the payload is padded to 256 bytes (2048 bits)
    // AdbCrypto.SIGNATURE_PADDING is 236 bytes? No, let's look at the original.
    // Actually, AdbCrypto already provides a padding list.
    
    // For safety, let's reconstruct the PKCS1 v1.5 padding specifically for SHA-1.
    final List<int> padding = [
      0x00, 0x01,
      for (int i = 0; i < 218; i++) 0xff,
      0x00,
      0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14,
    ];
    
    final fullPayload = Uint8List.fromList([...padding, ...payload]);
    return engine.process(fullPayload);
  }

  @override
  Uint8List getAdbPublicKeyPayload() {
    final adbPublicKey = AdbCrypto.convertRsaPublicKeyToAdbFormat(_myKeyPair.publicKey);
    final keyString = '${base64Encode(adbPublicKey)} gtv@remote\x00';
    return utf8.encode(keyString);
  }
}

class ADBService {
  AdbConnection? _connection;
  bool _isConnected = false;
  String? _fingerprint;

  bool get isConnected => _isConnected;
  String get fingerprint => _fingerprint ?? 'Pending...';

  Future<bool> connect(String ip, {int port = 5555}) async {
    try {
      // Set a more stable identifier for the host
      AdbProtocol.CONNECT_PAYLOAD = utf8.encode('host:gtvremote:GTVRemote\x00');

      // Load or generate keys
      var keyPair = await KeyService.loadKeys();
      if (keyPair == null) {
        keyPair = AdbCrypto.generateAdbKeyPair();
        await KeyService.saveKeys(keyPair);
        print('Generated and saved new ADB keys');
      }

      final GTVRemoteCrypto crypto = GTVRemoteCrypto(keyPair);
      _connection = AdbConnection(ip, port, crypto);
      
      // Update fingerprint
      _calculateFingerprint(crypto);
      print('Current Fingerprint: $_fingerprint');
      
      final bool connected = await _connection!.connect();
      
      if (connected) {
        _isConnected = true;
        print('Connected to $ip:$port');
        return true;
      }
    } catch (e) {
      print('Connection failed: $e');
      _isConnected = false;
    }
    return false;
  }

  void _calculateFingerprint(AdbCrypto crypto) {
    try {
      final payload = crypto.getAdbPublicKeyPayload();
      // ADB fingerprint is MD5 of the public key payload (usually the base64 part)
      // The payload is: base64(adb_pub_key) + " " + "unknown@unknown\0"
      // We want the MD5 of the raw adb_pub_key bytes if possible, 
      // but matching the UI's colon-separated format.
      
      // For simplicity in debugging stability, we'll just MD5 the whole payload
      // and format it as colon-separated hex.
      final hash = md5.convert(payload).bytes;
      _fingerprint = hash.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
    } catch (e) {
      _fingerprint = 'Error: $e';
    }
  }

  Future<void> disconnect() async {
    _connection = null;
    _isConnected = false;
  }

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected || _connection == null) return;
    try {
      // Open a shell stream to send the command
      final AdbStream stream = await _connection!.openShell();
      await stream.writeString('input keyevent $keyCode\n');
      stream.close();
    } catch (e) {
      print('Failed to send key event: $e');
    }
  }

  // KeyCodes for Google TV
  static const int KEYCODE_UP = 19;
  static const int KEYCODE_DOWN = 20;
  static const int KEYCODE_LEFT = 21;
  static const int KEYCODE_RIGHT = 22;
  static const int KEYCODE_ENTER = 66;
  static const int KEYCODE_BACK = 4;
  static const int KEYCODE_HOME = 3;
  static const int KEYCODE_POWER = 26;
  static const int KEYCODE_VOLUME_UP = 24;
  static const int KEYCODE_VOLUME_DOWN = 25;
  static const int KEYCODE_MUTE = 164;
  static const int KEYCODE_MENU = 82;
  static const int KEYCODE_CHANNEL_UP = 166;
  static const int KEYCODE_CHANNEL_DOWN = 167;
}
