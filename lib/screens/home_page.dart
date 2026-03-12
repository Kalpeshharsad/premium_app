import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import '../services/adb_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ADBService _adbService = ADBService();
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.21');
  final TextEditingController _textController = TextEditingController();
  bool _isConnecting = false;
  double _brightness = 127;

  @override
  void initState() {
    super.initState();
    // Auto-connect on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleConnect();
    });
  }

  void _handleConnect() async {
    setState(() => _isConnecting = true);
    final success = await _adbService.connect(_ipController.text);
    if (!mounted) return;
    setState(() => _isConnecting = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to TV')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection failed. Check IP and Developer Options.')),
      );
    }
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
                    _adbService.sendText(val);
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
                        _adbService.sendText(_textController.text);
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
                  const SizedBox(height: 40),
                  _buildChannelControls(),
                  const SizedBox(height: 40),
                  _buildBrightnessControl(),
                  const SizedBox(height: 40),
                ],
              ),
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
          _adbService.isConnected ? Icons.connected_tv_rounded : Icons.tv_off_rounded,
          color: _adbService.isConnected ? AppTheme.accentColor : Colors.white24,
          size: 32,
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.keyboard_outlined, color: Colors.white70),
          onPressed: _showKeyboardDialog,
        ),
      ],
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
                decoration: const InputDecoration(
                  hintText: 'TV IP Address',
                  border: InputBorder.none,
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
                    onPressed: _handleConnect,
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
                  onTap: () => _adbService.sendKeyEvent(ADBService.KEYCODE_ENTER),
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
        onPressed: () => _adbService.sendKeyEvent(keyCode),
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
                IconButton(icon: const Icon(Icons.volume_down_rounded), onPressed: () => _adbService.sendKeyEvent(ADBService.KEYCODE_VOLUME_DOWN)),
                IconButton(icon: const Icon(Icons.volume_off_rounded, size: 20, color: Colors.white24), onPressed: () => _adbService.sendKeyEvent(ADBService.KEYCODE_MUTE)),
                IconButton(icon: const Icon(Icons.volume_up_rounded), onPressed: () => _adbService.sendKeyEvent(ADBService.KEYCODE_VOLUME_UP)),
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
                IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded), onPressed: () => _adbService.sendKeyEvent(ADBService.KEYCODE_CHANNEL_DOWN)),
                const Icon(Icons.swap_vert_rounded, size: 20, color: Colors.white24),
                IconButton(icon: const Icon(Icons.keyboard_arrow_up_rounded), onPressed: () => _adbService.sendKeyEvent(ADBService.KEYCODE_CHANNEL_UP)),
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
                  _adbService.setBrightness(val.toInt());
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
          onTap: () => _adbService.sendKeyEvent(keyCode),
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
