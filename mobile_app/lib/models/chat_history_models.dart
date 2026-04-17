import 'chat_message.dart';

class ChatHistoryConversationSummary {
  const ChatHistoryConversationSummary({
    required this.id,
    required this.title,
    required this.localDeviceName,
    this.localAddress,
    this.peerName,
    this.peerDeviceInfo,
    required this.startedAtMs,
    required this.updatedAtMs,
    required this.messageCount,
  });

  final String id;
  final String title;
  final String localDeviceName;
  final String? localAddress;
  final String? peerName;
  final String? peerDeviceInfo;
  final int startedAtMs;
  final int updatedAtMs;
  final int messageCount;

  ChatHistoryConversationSummary copyWith({
    String? id,
    String? title,
    String? localDeviceName,
    String? localAddress,
    String? peerName,
    String? peerDeviceInfo,
    int? startedAtMs,
    int? updatedAtMs,
    int? messageCount,
  }) {
    return ChatHistoryConversationSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      localDeviceName: localDeviceName ?? this.localDeviceName,
      localAddress: localAddress ?? this.localAddress,
      peerName: peerName ?? this.peerName,
      peerDeviceInfo: peerDeviceInfo ?? this.peerDeviceInfo,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'localDeviceName': localDeviceName,
      'localAddress': localAddress,
      'peerName': peerName,
      'peerDeviceInfo': peerDeviceInfo,
      'startedAtMs': startedAtMs,
      'updatedAtMs': updatedAtMs,
      'messageCount': messageCount,
    };
  }

  factory ChatHistoryConversationSummary.fromJson(Map<String, dynamic> json) {
    return ChatHistoryConversationSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名会话',
      localDeviceName: json['localDeviceName']?.toString() ?? '我的手机',
      localAddress: json['localAddress']?.toString(),
      peerName: json['peerName']?.toString(),
      peerDeviceInfo: json['peerDeviceInfo']?.toString(),
      startedAtMs: _readInt(json['startedAtMs']),
      updatedAtMs: _readInt(json['updatedAtMs']),
      messageCount: _readInt(json['messageCount']),
    );
  }
}

class ChatHistoryMessageRecord {
  const ChatHistoryMessageRecord({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAtMs,
    this.type = 'text',
    this.compositionId,
    this.batchId,
    this.batchTotal,
    this.meta,
    this.isSystem = false,
    this.mimeType,
    this.progress,
    this.savedPath,
  });

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
  final String? mimeType;
  final double? progress;
  final String? savedPath;

  ChatHistoryMessageRecord copyWith({
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
    String? mimeType,
    double? progress,
    String? savedPath,
  }) {
    return ChatHistoryMessageRecord(
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
      mimeType: mimeType ?? this.mimeType,
      progress: progress ?? this.progress,
      savedPath: savedPath ?? this.savedPath,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'createdAtMs': createdAtMs,
      'type': type,
      'compositionId': compositionId,
      'batchId': batchId,
      'batchTotal': batchTotal,
      'meta': meta,
      'isSystem': isSystem,
      'mimeType': mimeType,
      'progress': progress,
      'savedPath': savedPath,
    };
  }

  factory ChatHistoryMessageRecord.fromJson(Map<String, dynamic> json) {
    return ChatHistoryMessageRecord(
      id: json['id']?.toString() ?? '',
      sender: json['sender']?.toString() ?? 'system',
      text: json['text']?.toString() ?? '',
      createdAtMs: _readInt(json['createdAtMs']),
      type: json['type']?.toString() ?? 'text',
      compositionId: json['compositionId']?.toString(),
      batchId: json['batchId']?.toString(),
      batchTotal: json['batchTotal'] == null
          ? null
          : _readInt(json['batchTotal']),
      meta: json['meta']?.toString(),
      isSystem: json['isSystem'] == true,
      mimeType: json['mimeType']?.toString(),
      progress: _readDouble(json['progress']),
      savedPath: json['savedPath']?.toString(),
    );
  }

  factory ChatHistoryMessageRecord.fromChatMessage(ChatMessage message) {
    return ChatHistoryMessageRecord(
      id: message.id,
      sender: message.sender,
      text: message.text,
      createdAtMs: message.createdAtMs,
      type: message.type,
      compositionId: message.compositionId,
      batchId: message.batchId,
      batchTotal: message.batchTotal,
      meta: message.meta,
      isSystem: message.isSystem,
      mimeType: message.mimeType,
      progress: message.progress,
      savedPath: message.savedPath,
    );
  }

  ChatMessage toChatMessage() {
    return ChatMessage(
      id: id,
      sender: sender,
      text: text,
      createdAtMs: createdAtMs,
      type: type,
      compositionId: compositionId,
      batchId: batchId,
      batchTotal: batchTotal,
      meta: meta,
      isSystem: isSystem,
      mimeType: mimeType,
      progress: progress,
      savedPath: savedPath,
    );
  }
}

class ChatHistoryConversation {
  const ChatHistoryConversation({
    required this.summary,
    required this.messages,
  });

  final ChatHistoryConversationSummary summary;
  final List<ChatHistoryMessageRecord> messages;

  ChatHistoryConversation copyWith({
    ChatHistoryConversationSummary? summary,
    List<ChatHistoryMessageRecord>? messages,
  }) {
    return ChatHistoryConversation(
      summary: summary ?? this.summary,
      messages: messages ?? this.messages,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'summary': summary.toJson(),
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  factory ChatHistoryConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatHistoryMessageRecord.fromJson)
        .toList(growable: false);
    return ChatHistoryConversation(
      summary: ChatHistoryConversationSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      messages: rawMessages,
    );
  }
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _readDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}
