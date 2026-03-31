import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import '../services/adb_service.dart';
import '../services/wifi_service.dart';
import '../services/discovery_service.dart';
import '../services/storage_service.dart';
import '../models/tv_device.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ADBService _adbService = ADBService();
  final WifiService _wifiService = WifiService();
  final DiscoveryService _discoveryService = DiscoveryService();
  final StorageService _storageService = StorageService();
  
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  
  bool _isConnecting = false;
  bool _isWifiMode = true; // Default to WiFi mode
  double _brightness = 127;
  
  List<TvDevice> _savedDevices = [];
  List<TvDevice> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // New combined method for loading and auto-connecting
    _discoveryService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() => _discoveredDevices = devices);
      }
    });
    _discoveryService.startDiscovery();
  }

  Future<void> _loadInitialData() async {
    await _loadSavedDevices();
    if (_savedDevices.isNotEmpty) {
      // Auto-connect to the most recent device after a short delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_adbService.isConnected && !_wifiService.isConnected) {
          _handleConnect(_savedDevices.first.ipAddress);
        }
      });
    }
  }

  @override
  void dispose() {
    _discoveryService.stopDiscovery();
    _ipController.dispose();
    _textController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _storageService.getSavedDevices();
    setState(() {
      _savedDevices = devices;
      if (devices.isNotEmpty && _ipController.text.isEmpty) {
        _ipController.text = devices.first.ipAddress;
      }
    });
  }

  void _handleConnect([String? ip]) async {
    final ipToConnect = ip ?? _ipController.text;
    if (ipToConnect.isEmpty) return;

    if (ip != null) {
      _ipController.text = ip;
    }

    setState(() => _isConnecting = true);
    
    bool success = false;
    if (_isWifiMode) {
      success = await _wifiService.connect(ipToConnect);
      if (_wifiService.isPairing) {
        final pairingStarted = await _wifiService.startPairing(ipToConnect);
        setState(() => _isConnecting = false);
        
        if (pairingStarted) {
          _showPairingDialog(ipToConnect);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_wifiService.lastError ?? 'Could not reach TV. Check IP and Network.')),
          );
        }
        return;
      }
    } else {
      success = await _adbService.connect(ipToConnect);
    }

    if (!mounted) return;
    setState(() => _isConnecting = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to TV')),
      );
      // Save the connected device
      String name = 'Android TV ($ipToConnect)';
      // Try to find a better name if it was discovered
      try {
        final discovered = _discoveredDevices.firstWhere((d) => d.ipAddress == ipToConnect);
        name = discovered.name;
      } catch (_) {}
      
      await _storageService.saveDevice(TvDevice(ipAddress: ipToConnect, name: name));
      _loadSavedDevices();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection failed. Check IP and Developer Options.')),
      );
    }
  }

  void _showDevicesBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('TV Devices', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_discoveredDevices.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('DISCOVERED ON NETWORK', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    ..._discoveredDevices.map((device) => _buildDeviceItem(device, Icons.wifi_rounded)),
                    const SizedBox(height: 16),
                  ],
                  if (_savedDevices.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('SAVED DEVICES', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    ..._savedDevices.map((device) => _buildDeviceItem(device, Icons.tv_rounded, isSaved: true)),
                  ],
                  if (_discoveredDevices.isEmpty && _savedDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('No devices found or saved.\nMake sure your TV is on the same Wi-Fi network.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(TvDevice device, IconData icon, {bool isSaved = false}) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(device.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(device.ipAddress, style: const TextStyle(color: Colors.white54)),
        trailing: isSaved ? IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white30),
          onPressed: () {
             _storageService.removeDevice(device.ipAddress);
             _loadSavedDevices();
             Navigator.pop(context);
          },
        ) : null,
        onTap: () {
          Navigator.pop(context);
          _handleConnect(device.ipAddress);
        },
      ),
    );
  }

  void _showKeyboardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('TV Keyboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Type something...',
                    fillColor: Colors.white10,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (val) {
                    if (_isWifiMode) {
                      _wifiService.sendText(val);
                    } else {
                      _adbService.sendText(val);
                    }
                    _textController.clear();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_isWifiMode) {
                          _wifiService.sendText(_textController.text);
                        } else {
                          _adbService.sendText(_textController.text);
                        }
                        _textController.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            color: AppTheme.backgroundColor,
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildConnectionCard(),
                  const SizedBox(height: 40),
                  _buildDPad(),
                  const SizedBox(height: 40),
                  _buildMainControls(),
                  const SizedBox(height: 40),
                  _buildVolumeControls(),
                  const SizedBox(height: 20),
                  _buildChannelControls(),
                  const SizedBox(height: 40),
                  _buildBrightnessControl(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Debug Overlay
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ValueListenableBuilder<String>(
              valueListenable: WifiService.logNotifier,
              builder: (context, log, _) {
                if (log == 'WiFi Service Ready' || log.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    log,
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GTV Remote', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28)),
            const Text('Remote Control', style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 4),
            Text('ID: ${_adbService.fingerprint}', style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace')),
          ],
        ),
        Icon(
          (_isWifiMode ? _wifiService.isConnected : _adbService.isConnected) 
              ? Icons.connected_tv_rounded 
              : Icons.tv_off_rounded,
          color: (_isWifiMode ? _wifiService.isConnected : _adbService.isConnected) 
              ? AppTheme.accentColor 
              : Colors.white24,
          size: 32,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            _isWifiMode ? Icons.wifi_rounded : Icons.developer_mode_rounded,
            color: _isWifiMode ? Colors.blue : Colors.orange,
            size: 24,
          ),
          onPressed: () {
            setState(() {
              _isWifiMode = !_isWifiMode;
              if (_isWifiMode) {
                _adbService.disconnect();
              } else {
                _wifiService.disconnect();
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Switched to ${_isWifiMode ? "WiFi" : "ADB"} Mode')),
            );
          },
          tooltip: 'Switch to ${_isWifiMode ? "ADB" : "WiFi"} Mode',
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_outlined, color: Colors.white70),
          onPressed: _showKeyboardDialog,
        ),
      ],
    );
  }

  void _showPairingDialog(String ip) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_remote_rounded, color: Colors.blue, size: 48),
                const SizedBox(height: 16),
                const Text('Pairing Required', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Enter the 6-digit PIN shown on your TV ($ip)', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(
                    counterText: '',
                    fillColor: Colors.white10,
                    filled: true,
                    border: OutlineInputBorder(),
                    hintText: 'A1B2C3',
                    hintStyle: TextStyle(color: Colors.white24),
                    helperText: 'Enter the hex code shown on your TV',
                    helperStyle: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final pin = _pinController.text;
                          if (pin.length == 6) {
                            Navigator.pop(context);
                            setState(() => _isConnecting = true);
                            final success = await _wifiService.pair(ip, pin);
                            setState(() => _isConnecting = false);
                            if (success) {
                              _handleConnect(ip);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_wifiService.lastError ?? 'Pairing failed. Try again.'),
                                  duration: const Duration(seconds: 10), // Give them time to copy it
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Pair'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  hintText: 'TV IP Address',
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.white30),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.white54),
                    onPressed: _showDevicesBottomSheet,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: () => _handleConnect(),
                    icon: Icon(Icons.sync_rounded, color: AppTheme.primaryColor),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDPad() {
    return Center(
      child: GlassCard(
        borderRadius: 100,
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            children: [
              _buildDPadButton(Alignment.topCenter, Icons.keyboard_arrow_up, ADBService.KEYCODE_UP),
              _buildDPadButton(Alignment.bottomCenter, Icons.keyboard_arrow_down, ADBService.KEYCODE_DOWN),
              _buildDPadButton(Alignment.centerLeft, Icons.keyboard_arrow_left, ADBService.KEYCODE_LEFT),
              _buildDPadButton(Alignment.centerRight, Icons.keyboard_arrow_right, ADBService.KEYCODE_RIGHT),
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (_isWifiMode) {
                      _wifiService.sendKeyEvent(ADBService.KEYCODE_ENTER);
                    } else {
                      _adbService.sendKeyEvent(ADBService.KEYCODE_ENTER);
                    }
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Center(child: Text('OK', style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDPadButton(Alignment alignment, IconData icon, int keyCode) {
    return Align(
      alignment: alignment,
      child: IconButton(
        iconSize: 40,
        icon: Icon(icon, color: Colors.white70),
        onPressed: () {
          if (_isWifiMode) {
            _wifiService.sendKeyEvent(keyCode);
          } else {
            _adbService.sendKeyEvent(keyCode);
          }
        },
      ),
    );
  }

  Widget _buildMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircularButton(Icons.arrow_back_rounded, 'Back', ADBService.KEYCODE_BACK),
        _buildCircularButton(Icons.menu_rounded, 'Menu', ADBService.KEYCODE_MENU),
        _buildCircularButton(Icons.home_rounded, 'Home', ADBService.KEYCODE_HOME, color: AppTheme.primaryColor),
        _buildCircularButton(Icons.power_settings_new_rounded, 'Power', ADBService.KEYCODE_POWER, color: AppTheme.secondaryColor),
      ],
    );
  }

  Widget _buildVolumeControls() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text('VOLUME', style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.volume_down_rounded), onPressed: () {
                  if (_isWifiMode) {
                    _wifiService.sendKeyEvent(ADBService.KEYCODE_VOLUME_DOWN);
                  } else {
                    _adbService.sendKeyEvent(ADBService.KEYCODE_VOLUME_DOWN);
                  }
                }),
                IconButton(icon: const Icon(Icons.volume_off_rounded, size: 20, color: Colors.white24), onPressed: () {
                  if (_isWifiMode) {
                    _wifiService.sendKeyEvent(ADBService.KEYCODE_MUTE);
                  } else {
                    _adbService.sendKeyEvent(ADBService.KEYCODE_MUTE);
                  }
                }),
                IconButton(icon: const Icon(Icons.volume_up_rounded), onPressed: () {
                  if (_isWifiMode) {
                    _wifiService.sendKeyEvent(ADBService.KEYCODE_VOLUME_UP);
                  } else {
                    _adbService.sendKeyEvent(ADBService.KEYCODE_VOLUME_UP);
                  }
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelControls() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text('CHANNEL', style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded), onPressed: () {
                  if (_isWifiMode) {
                    _wifiService.sendKeyEvent(ADBService.KEYCODE_CHANNEL_DOWN);
                  } else {
                    _adbService.sendKeyEvent(ADBService.KEYCODE_CHANNEL_DOWN);
                  }
                }),
                const Icon(Icons.swap_vert_rounded, size: 20, color: Colors.white24),
                IconButton(icon: const Icon(Icons.keyboard_arrow_up_rounded), onPressed: () {
                  if (_isWifiMode) {
                    _wifiService.sendKeyEvent(ADBService.KEYCODE_CHANNEL_UP);
                  } else {
                    _adbService.sendKeyEvent(ADBService.KEYCODE_CHANNEL_UP);
                  }
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrightnessControl() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.brightness_low_rounded, size: 16, color: Colors.white24),
            const Text('BRIGHTNESS', style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Icon(Icons.brightness_high_rounded, size: 16, color: Colors.white24),
          ],
        ),
        const SizedBox(height: 8),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _brightness,
                min: 0,
                max: 255,
                onChanged: (val) {
                  setState(() => _brightness = val);
                },
                onChangeEnd: (val) {
                  if (_isWifiMode) {
                    _wifiService.setBrightness(val.toInt());
                  } else {
                    _adbService.setBrightness(val.toInt());
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularButton(IconData icon, String label, int keyCode, {Color color = Colors.white10}) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (_isWifiMode) {
              _wifiService.sendKeyEvent(keyCode);
            } else {
              _adbService.sendKeyEvent(keyCode);
            }
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color == Colors.white10 ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.2),
              border: Border.all(color: color == Colors.white10 ? Colors.white10 : color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color == Colors.white10 ? Colors.white : color),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ],
    );
  }
}
