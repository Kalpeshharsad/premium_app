import 'package:shared_preferences/shared_preferences.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter/foundation.dart';

class KeyService {
  static const String _publicKeyModulusKey = 'adb_public_key_modulus';
  static const String _publicKeyExponentKey = 'adb_public_key_exponent';
  static const String _privateKeyModulusKey = 'adb_private_key_modulus';
  static const String _privateKeyExponentKey = 'adb_private_key_exponent';
  static const String _privateKeyPKey = 'adb_private_key_p';
  static const String _privateKeyQKey = 'adb_private_key_q';
  static const String _stitchApiKey = 'stitch_api_key';

  static Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>?> loadKeys() async {
    debugPrint('KeyService: Loading keys...');
    final prefs = await SharedPreferences.getInstance();
    
    final pubMod = prefs.getString(_publicKeyModulusKey);
    final pubExp = prefs.getString(_publicKeyExponentKey);
    final privMod = prefs.getString(_privateKeyModulusKey);
    final privExp = prefs.getString(_privateKeyExponentKey);
    final privP = prefs.getString(_privateKeyPKey);
    final privQ = prefs.getString(_privateKeyQKey);

    if (pubMod == null || pubExp == null || privMod == null || privExp == null || privP == null || privQ == null) {
      debugPrint('KeyService: No keys found in storage.');
      return null;
    }

    try {
      final publicKey = RSAPublicKey(
        BigInt.parse(pubMod, radix: 16),
        BigInt.parse(pubExp, radix: 16),
      );

      final privateKey = RSAPrivateKey(
        BigInt.parse(privMod, radix: 16),
        BigInt.parse(privExp, radix: 16),
        BigInt.parse(privP, radix: 16),
        BigInt.parse(privQ, radix: 16),
      );

      debugPrint('KeyService: Keys loaded successfully.');
      return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey);
    } catch (e) {
      debugPrint('KeyService: Error parsing keys: $e');
      return null;
    }
  }

  static Future<void> saveKeys(AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> keyPair) async {
    debugPrint('KeyService: Saving keys...');
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_publicKeyModulusKey, keyPair.publicKey.modulus!.toRadixString(16));
    await prefs.setString(_publicKeyExponentKey, keyPair.publicKey.publicExponent!.toRadixString(16));
    await prefs.setString(_privateKeyModulusKey, keyPair.privateKey.modulus!.toRadixString(16));
    await prefs.setString(_privateKeyExponentKey, keyPair.privateKey.privateExponent!.toRadixString(16));
    await prefs.setString(_privateKeyPKey, keyPair.privateKey.p!.toRadixString(16));
    await prefs.setString(_privateKeyQKey, keyPair.privateKey.q!.toRadixString(16));
    debugPrint('KeyService: Keys saved.');
  }
  static Future<String?> getStitchApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_stitchApiKey);
  }

  static Future<void> saveStitchApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stitchApiKey, key);
  }
}
