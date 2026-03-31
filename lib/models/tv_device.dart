import 'dart:convert';

class TvDevice {
  final String ipAddress;
  final String name;
  final DateTime? lastConnected;
  final bool isAdbCapable;
  final bool isWifiCapable;

  TvDevice({
    required this.ipAddress,
    required this.name,
    this.lastConnected,
    this.isAdbCapable = true,
    this.isWifiCapable = false,
  });

  TvDevice copyWith({
    String? ipAddress,
    String? name,
    DateTime? lastConnected,
    bool? isAdbCapable,
    bool? isWifiCapable,
  }) {
    return TvDevice(
      ipAddress: ipAddress ?? this.ipAddress,
      name: name ?? this.name,
      lastConnected: lastConnected ?? this.lastConnected,
      isAdbCapable: isAdbCapable ?? this.isAdbCapable,
      isWifiCapable: isWifiCapable ?? this.isWifiCapable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ipAddress': ipAddress,
      'name': name,
      'lastConnected': lastConnected?.millisecondsSinceEpoch,
      'isAdbCapable': isAdbCapable,
      'isWifiCapable': isWifiCapable,
    };
  }

  factory TvDevice.fromMap(Map<String, dynamic> map) {
    return TvDevice(
      ipAddress: map['ipAddress'] ?? '',
      name: map['name'] ?? '',
      lastConnected: map['lastConnected'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastConnected'])
          : null,
      isAdbCapable: map['isAdbCapable'] ?? true,
      isWifiCapable: map['isWifiCapable'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory TvDevice.fromJson(String source) =>
      TvDevice.fromMap(json.decode(source));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TvDevice &&
        other.ipAddress == ipAddress &&
        other.name == name;
  }

  @override
  int get hashCode => ipAddress.hashCode ^ name.hashCode;

  @override
  String toString() => 'TvDevice(ipAddress: $ipAddress, name: $name, lastConnected: $lastConnected)';
}
