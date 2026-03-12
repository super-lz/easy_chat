import 'dart:convert';

import 'package:http/http.dart' as http;

class PairingRegisterRequest {
  const PairingRegisterRequest({
    required this.serverUrl,
    required this.sessionId,
    required this.challenge,
    required this.deviceName,
    required this.phoneIp,
    required this.phonePort,
    required this.token,
    this.protocolVersion = 1,
  });

  final String serverUrl;
  final String sessionId;
  final String challenge;
  final String deviceName;
  final String phoneIp;
  final int phonePort;
  final String token;
  final int protocolVersion;
}

class PairingApiService {
  const PairingApiService();

  Future<void> registerPhone(PairingRegisterRequest request) async {
    final uri = Uri.parse(
      '${request.serverUrl}/api/pairings/${request.sessionId}/register',
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'challenge': request.challenge,
        'deviceName': request.deviceName,
        'phoneIp': request.phoneIp,
        'phonePort': request.phonePort,
        'token': request.token,
        'protocolVersion': request.protocolVersion,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('注册失败 (${response.statusCode})');
    }
  }
}
