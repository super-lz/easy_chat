import 'package:equatable/equatable.dart';

class ConnectionCache extends Equatable {
  const ConnectionCache({
    required this.deviceName,
    required this.wifiName,
    required this.phoneIp,
    required this.phonePort,
    required this.token,
  });

  final String deviceName;
  final String wifiName;
  final String phoneIp;
  final int phonePort;
  final String token;

  ConnectionCache copyWith({
    String? deviceName,
    String? wifiName,
    String? phoneIp,
    int? phonePort,
    String? token,
  }) {
    return ConnectionCache(
      deviceName: deviceName ?? this.deviceName,
      wifiName: wifiName ?? this.wifiName,
      phoneIp: phoneIp ?? this.phoneIp,
      phonePort: phonePort ?? this.phonePort,
      token: token ?? this.token,
    );
  }

  Map<String, Object> toJson() {
    return {
      'deviceName': deviceName,
      'wifiName': wifiName,
      'phoneIp': phoneIp,
      'phonePort': phonePort,
      'token': token,
    };
  }

  factory ConnectionCache.fromJson(Map<String, dynamic> json) {
    return ConnectionCache(
      deviceName: json['deviceName']?.toString() ?? '我的手机',
      wifiName: json['wifiName']?.toString() ?? '',
      phoneIp: json['phoneIp']?.toString() ?? '',
      phonePort: json['phonePort'] is int
          ? json['phonePort'] as int
          : int.parse(json['phonePort'].toString()),
      token: json['token']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [
        deviceName,
        wifiName,
        phoneIp,
        phonePort,
        token,
      ];
}
