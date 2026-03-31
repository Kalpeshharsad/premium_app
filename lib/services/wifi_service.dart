import 'dart:async';
import 'package:flutter/foundation.dart';
import 'key_service.dart';

class WifiService {
  bool _isConnected = false;
  bool _isPairing = false;
  String? _pairedIp;

  bool get isConnected => _isConnected;
  bool get isPairing => _isPairing;

  Future<bool> connect(String ip) async {
    debugPrint('WifiService: Connecting to $ip...');
    
    // Check if we have an API key (pairing token) for this IP or generally
    final apiKey = await KeyService.getStitchApiKey();
    
    if (apiKey == null) {
      debugPrint('WifiService: No pairing token found. Need to pair first.');
      _isPairing = true;
      return false;
    }

    try {
      // In a real implementation, we would open a TLS socket to port 6467
      // and perform the handshake using the stored certificates.
      _isConnected = true;
      _pairedIp = ip;
      return true;
    } catch (e) {
      debugPrint('WifiService: Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<bool> pair(String ip, String pin) async {
    debugPrint('WifiService: Pairing with $ip using PIN $pin...');
    
    try {
      // 1. Connect to port 6466 (Pairing port)
      // 2. Perform TLS handshake
      // 3. Send Secret (PIN-based)
      // 4. If successful, receive and store the API Key / Token
      
      await KeyService.saveStitchApiKey('mock_wifi_token_${DateTime.now().millisecondsSinceEpoch}');
      _isConnected = true;
      _isPairing = false;
      _pairedIp = ip;
      return true;
    } catch (e) {
      debugPrint('WifiService: Pairing failed: $e');
      return false;
    }
  }

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected) return;
    debugPrint('WifiService: Sending KeyCode $keyCode to $_pairedIp via WiFi');
    
    // Convert ADB KeyCode to Android TV Remote KeyCode if they differ.
    // Most ADB keycodes (19, 20, 21, 22, 66) match standard Android keycodes.
    
    // Real implementation would send a Protobuf message over the TLS socket.
  }

  Future<void> sendText(String text) async {
     if (!_isConnected) return;
     debugPrint('WifiService: Sending Text "$text" via WiFi');
  }

  Future<void> setBrightness(int value) async {
     if (!_isConnected) return;
     debugPrint('WifiService: Setting Brightness $value via WiFi');
     // Note: Brightness might not be supported over the standard remote protocol
     // as easily as ADB, but we can simulate it if the TV supports it.
  }

  void disconnect() {
    _isConnected = false;
    _isPairing = false;
    _pairedIp = null;
  }
}
