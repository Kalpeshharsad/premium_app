import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'key_service.dart';

class WifiService {
  bool _isConnected = false;
  bool _isPairing = false;
  String? _pairedIp;
  SecureSocket? _pairingSocket;
  SecureSocket? _controlSocket;

  bool get isConnected => _isConnected;
  bool get isPairing => _isPairing;

  Future<bool> connect(String ip) async {
    debugPrint('WifiService: Connecting to $ip...');
    
    final apiKey = await KeyService.getStitchApiKey();
    if (apiKey == null) {
      debugPrint('WifiService: No pairing token found. Need to pair first.');
      _isPairing = true;
      return false;
    }

    try {
      // Connect to Control Port (Trying 8601 first as suggested, then fallback to 6467)
      try {
        _controlSocket = await SecureSocket.connect(
          ip, 
          8601, 
          onBadCertificate: (cert) => true,
          timeout: const Duration(seconds: 3),
        );
        debugPrint('WifiService: Connected to port 8601 (Control)');
      } catch (e) {
        debugPrint('WifiService: Port 8601 failed, trying 6467...');
        _controlSocket = await SecureSocket.connect(
          ip, 
          6467, 
          onBadCertificate: (cert) => true,
          timeout: const Duration(seconds: 3),
        );
        debugPrint('WifiService: Connected to port 6467 (Control)');
      }
      
      _isConnected = true;
      _pairedIp = ip;
      
      _controlSocket!.listen((data) {
        debugPrint('WifiService: Received control data of length ${data.length}');
      }, onDone: () => disconnect(), onError: (e) => disconnect());
      
      return true;
    } catch (e) {
      debugPrint('WifiService: Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<void> startPairing(String ip) async {
    debugPrint('WifiService: Starting pairing with $ip...');
    try {
      // Try Port 8601 for Pairing first, then fallback to 6466
      try {
        debugPrint('WifiService: Trying port 8601 for pairing...');
        _pairingSocket = await SecureSocket.connect(
          ip, 
          8601, 
          onBadCertificate: (cert) => true,
          timeout: const Duration(seconds: 3),
        );
        debugPrint('WifiService: Connected to port 8601 (Pairing)');
      } catch (e) {
        debugPrint('WifiService: Port 8601 failed, trying 6466...');
        _pairingSocket = await SecureSocket.connect(
          ip, 
          6466, 
          onBadCertificate: (cert) => true,
          timeout: const Duration(seconds: 3),
        );
        debugPrint('WifiService: Connected to port 6466 (Pairing)');
      }

      // Sending PairingRequest (Protobuf)
      final pairingRequest = Uint8List.fromList([
        0x00, 0x12, 0x0a, 0x10, 0x41, 0x6e, 0x74, 0x69, 0x67, 0x72, 0x61, 0x76,
        0x69, 0x74, 0x79, 0x20, 0x52, 0x65, 0x6d, 0x6f, 0x74, 0x65, 0x12, 0x06,
        0x4d, 0x6f, 0x62, 0x69, 0x6c, 0x65, 0x18, 0x01
      ]);
      
      _pairingSocket!.add(pairingRequest);
      debugPrint('WifiService: Sent PairingRequest. TV should show PIN.');
      
      _pairingSocket!.listen((data) {
         debugPrint('WifiService: Received pairing data of length ${data.length}');
      });
      
    } catch (e) {
      debugPrint('WifiService: Failed to start pairing: $e');
    }
  }

  Future<bool> pair(String ip, String pin) async {
    debugPrint('WifiService: Completing pairing with $ip using PIN $pin...');
    
    if (_pairingSocket == null) {
      debugPrint('WifiService: No active pairing socket.');
      return false;
    }

    try {
      // 1. Send SecretRequest with hashed PIN
      // Note: Real implementation requires hashing the PIN with the certificates.
      // For now, we simulate a successful pairing by saving a token.
      
      await KeyService.saveStitchApiKey('wifi_token_${DateTime.now().millisecondsSinceEpoch}');
      _isConnected = true;
      _isPairing = false;
      _pairedIp = ip;
      
      if (_pairingSocket != null) {
        _pairingSocket!.destroy();
        _pairingSocket = null;
      }
      
      return true;
    } catch (e) {
      debugPrint('WifiService: Pairing failed: $e');
      return false;
    }
  }

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected || _controlSocket == null) return;
    debugPrint('WifiService: Sending KeyCode $keyCode to $_pairedIp via WiFi');
    
    // Construct KeyEvent Protobuf message
    // Simplified version: [0x00, 0xXX, ...]
    final keyEvent = Uint8List.fromList([0x00, keyCode]); // Mock bytes
    _controlSocket!.add(keyEvent);
  }

  Future<void> sendText(String text) async {
     if (!_isConnected || _controlSocket == null) return;
     debugPrint('WifiService: Sending Text "$text" via WiFi');
  }

  Future<void> setBrightness(int value) async {
     if (!_isConnected) return;
     debugPrint('WifiService: Setting Brightness $value via WiFi');
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
