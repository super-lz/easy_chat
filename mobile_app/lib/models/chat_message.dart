import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.meta,
    this.isSystem = false,
    this.bytes,
    this.mimeType,
    this.progress,
    this.savedPath,
  });

  final String id;
  final String sender;
  final String text;
  final String? meta;
  final bool isSystem;
  final Uint8List? bytes;
  final String? mimeType;
  final double? progress;
  final String? savedPath;

  ChatMessage copyWith({
    String? id,
    String? sender,
    String? text,
    String? meta,
    bool? isSystem,
    Uint8List? bytes,
    String? mimeType,
    double? progress,
    String? savedPath,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      meta: meta ?? this.meta,
      isSystem: isSystem ?? this.isSystem,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      progress: progress ?? this.progress,
      savedPath: savedPath ?? this.savedPath,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sender,
        text,
        meta,
        isSystem,
        bytes,
        mimeType,
        progress,
        savedPath,
      ];
}
