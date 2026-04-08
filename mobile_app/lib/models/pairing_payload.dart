import 'package:equatable/equatable.dart';

class PairingPayload extends Equatable {
  const PairingPayload({
    required this.sessionId,
    required this.challenge,
    required this.serverUrl,
    this.browserName,
    this.deviceInfo,
    this.verificationCode,
  });

  final String sessionId;
  final String challenge;
  final String serverUrl;
  final String? browserName;
  final String? deviceInfo;
  final String? verificationCode;

  PairingPayload copyWith({
    String? sessionId,
    String? challenge,
    String? serverUrl,
    String? browserName,
    String? deviceInfo,
    String? verificationCode,
  }) {
    return PairingPayload(
      sessionId: sessionId ?? this.sessionId,
      challenge: challenge ?? this.challenge,
      serverUrl: serverUrl ?? this.serverUrl,
      browserName: browserName ?? this.browserName,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      verificationCode: verificationCode ?? this.verificationCode,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    challenge,
    serverUrl,
    browserName,
    deviceInfo,
    verificationCode,
  ];
}
