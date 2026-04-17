import 'package:equatable/equatable.dart';

class ConnectionCache extends Equatable {
  const ConnectionCache({
    required this.deviceName,
    required this.phoneIp,
    required this.phonePort,
    required this.token,
    this.conversationId,
  });

  final String deviceName;
  final String phoneIp;
  final int phonePort;
  final String token;
  final String? conversationId;

  ConnectionCache copyWith({
    String? deviceName,
    String? phoneIp,
    int? phonePort,
    String? token,
    String? conversationId,
  }) {
    return ConnectionCache(
      deviceName: deviceName ?? this.deviceName,
      phoneIp: phoneIp ?? this.phoneIp,
      phonePort: phonePort ?? this.phonePort,
      token: token ?? this.token,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'deviceName': deviceName,
      'phoneIp': phoneIp,
      'phonePort': phonePort,
      'token': token,
      'conversationId': conversationId,
    };
  }

  factory ConnectionCache.fromJson(Map<String, dynamic> json) {
    return ConnectionCache(
      deviceName: json['deviceName']?.toString() ?? '我的手机',
      phoneIp: json['phoneIp']?.toString() ?? '',
      phonePort: json['phonePort'] is int
          ? json['phonePort'] as int
          : int.parse(json['phonePort'].toString()),
      token: json['token']?.toString() ?? '',
      conversationId: json['conversationId']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    deviceName,
    phoneIp,
    phonePort,
    token,
    conversationId,
  ];
}
