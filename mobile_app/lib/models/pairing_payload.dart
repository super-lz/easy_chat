import 'package:equatable/equatable.dart';

class PairingPayload extends Equatable {
  const PairingPayload({
    required this.sessionId,
    required this.challenge,
    required this.serverUrl,
  });

  final String sessionId;
  final String challenge;
  final String serverUrl;

  PairingPayload copyWith({
    String? sessionId,
    String? challenge,
    String? serverUrl,
  }) {
    return PairingPayload(
      sessionId: sessionId ?? this.sessionId,
      challenge: challenge ?? this.challenge,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }

  @override
  List<Object?> get props => [sessionId, challenge, serverUrl];
}
