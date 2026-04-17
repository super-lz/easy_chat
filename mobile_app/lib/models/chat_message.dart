import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    int? createdAtMs,
    this.type = 'text',
    this.compositionId,
    this.batchId,
    this.batchTotal,
    this.meta,
    this.isSystem = false,
    this.bytes,
    this.mimeType,
    this.progress,
    this.savedPath,
  }) : createdAtMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  final String sender;
  final String text;
  final int createdAtMs;
  final String type;
  final String? compositionId;
  final String? batchId;
  final int? batchTotal;
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
    int? createdAtMs,
    String? type,
    String? compositionId,
    String? batchId,
    int? batchTotal,
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
      createdAtMs: createdAtMs ?? this.createdAtMs,
      type: type ?? this.type,
      compositionId: compositionId ?? this.compositionId,
      batchId: batchId ?? this.batchId,
      batchTotal: batchTotal ?? this.batchTotal,
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
    createdAtMs,
    type,
    compositionId,
    batchId,
    batchTotal,
    meta,
    isSystem,
    bytes,
    mimeType,
    progress,
    savedPath,
  ];
}
