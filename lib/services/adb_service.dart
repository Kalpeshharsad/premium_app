import 'dart:io';
import 'package:flutter_adb/flutter_adb.dart';

class ADBService {
  AdbClient? _client;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<bool> connect(String ip, {int port = 5555}) async {
    try {
      // Connect to the device
      _client = await AdbClient.connect(ip, port: port);
      
      // Check if authentication is needed
      if (_client != null) {
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

  Future<void> disconnect() async {
    // AdbClient doesn't have an explicit disconnect in some versions, 
    // but we can null it out.
    _client = null;
    _isConnected = false;
  }

  Future<void> sendKeyEvent(int keyCode) async {
    if (!_isConnected || _client == null) return;
    try {
      await _client!.shell('input keyevent $keyCode');
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
}
