import 'dart:io';
import 'package:flutter_adb/adb_connection.dart';
import 'package:flutter_adb/adb_crypto.dart';
import 'package:flutter_adb/adb_stream.dart';

class ADBService {
  AdbConnection? _connection;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<bool> connect(String ip, {int port = 5555}) async {
    try {
      // Connect to the device using AdbConnection
      final AdbCrypto crypto = AdbCrypto(); // Automatically generates keys if needed
      _connection = AdbConnection(ip, port, crypto);
      
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
