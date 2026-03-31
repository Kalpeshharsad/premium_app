import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import '../models/tv_device.dart';

class DiscoveryService {
  MDnsClient? _client;
  final StreamController<List<TvDevice>> _devicesController = StreamController<List<TvDevice>>.broadcast();
  final List<TvDevice> _discoveredDevices = [];

  Stream<List<TvDevice>> get devicesStream => _devicesController.stream;

  void startDiscovery() async {
    _discoveredDevices.clear();
    _devicesController.add(_discoveredDevices);
    
    _client = MDnsClient();
    await _client?.start();

    // Scan for ADB service and Android TV Remote service
    const String adbServiceName = '_adb._tcp.local';
    const String wifiServiceName = '_androidtvremote2._tcp.local';
    
    _discoverByServiceName(adbServiceName, isAdb: true);
    _discoverByServiceName(wifiServiceName, isWifi: true);
  }

  void _discoverByServiceName(String serviceName, {bool isAdb = false, bool isWifi = false}) async {
    try {
      await for (final PtrResourceRecord ptr in _client!.lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(serviceName))) {
        
        await for (final SrvResourceRecord srv in _client!.lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName))) {
          
          await for (final IPAddressResourceRecord ip in _client!.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target))) {
            
            String deviceName = ptr.domainName
                .replaceAll('.$serviceName', '')
                .replaceAll('._tcp.local', '');
            
            if (deviceName.isEmpty) {
               deviceName = 'Android TV';
            }

            final ipStr = ip.address.address;
            
            // Check if we already have this IP
            final existingIndex = _discoveredDevices.indexWhere((d) => d.ipAddress == ipStr);
            
            if (existingIndex != -1) {
              final existing = _discoveredDevices[existingIndex];
              _discoveredDevices[existingIndex] = existing.copyWith(
                isAdbCapable: existing.isAdbCapable || isAdb,
                isWifiCapable: existing.isWifiCapable || isWifi,
              );
            } else {
              _discoveredDevices.add(TvDevice(
                ipAddress: ipStr,
                name: deviceName,
                isAdbCapable: isAdb,
                isWifiCapable: isWifi,
              ));
            }
            _devicesController.add(_discoveredDevices);
          }
        }
      }
    } catch (e) {
      debugPrint('mDNS Discovery Error ($serviceName): $e');
    }
  }

  void stopDiscovery() {
    _client?.stop();
    _client = null;
  }
}
