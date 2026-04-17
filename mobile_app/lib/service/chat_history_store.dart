import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/chat_history_models.dart';
import '../models/chat_message.dart';

class ChatHistoryStore {
  static const MethodChannel _channel = MethodChannel(
    'easychat/managed_file_store',
  );

  ChatHistoryConversation? _activeConversation;

  Future<String> createConversation({
    required String localDeviceName,
    String? localAddress,
    String? peerName,
    String? peerDeviceInfo,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'conv-$now-${Random().nextInt(1 << 32)}';
    final summary = ChatHistoryConversationSummary(
      id: id,
      title: _buildTitle(peerName: peerName, peerDeviceInfo: peerDeviceInfo),
      localDeviceName: localDeviceName,
      localAddress: localAddress,
      peerName: peerName,
      peerDeviceInfo: peerDeviceInfo,
      startedAtMs: now,
      updatedAtMs: now,
      messageCount: 0,
    );
    _activeConversation = ChatHistoryConversation(
      summary: summary,
      messages: [],
    );
    await _persistActiveConversation();
    return id;
  }

  Future<void> openConversation(String conversationId) async {
    _activeConversation = await loadConversation(conversationId);
  }

  Future<void> closeActiveConversation() async {
    _activeConversation = null;
  }

  String? get activeConversationId => _activeConversation?.summary.id;

  Future<void> updateActiveConversationMeta({
    String? localDeviceName,
    String? localAddress,
    String? peerName,
    String? peerDeviceInfo,
  }) async {
    final active = _activeConversation;
    if (active == null) {
      return;
    }

    final nextSummary = active.summary.copyWith(
      title: _buildTitle(
        peerName: peerName ?? active.summary.peerName,
        peerDeviceInfo: peerDeviceInfo ?? active.summary.peerDeviceInfo,
      ),
      localDeviceName: localDeviceName ?? active.summary.localDeviceName,
      localAddress: localAddress ?? active.summary.localAddress,
      peerName: peerName ?? active.summary.peerName,
      peerDeviceInfo: peerDeviceInfo ?? active.summary.peerDeviceInfo,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _activeConversation = active.copyWith(summary: nextSummary);
    await _persistActiveConversation();
  }

  Future<void> appendMessage(ChatMessage message) async {
    final active = _activeConversation;
    if (active == null) {
      return;
    }
    final nextMessages = List<ChatHistoryMessageRecord>.from(active.messages)
      ..add(ChatHistoryMessageRecord.fromChatMessage(message));
    _activeConversation = active.copyWith(
      summary: active.summary.copyWith(
        updatedAtMs: message.createdAtMs,
        messageCount: nextMessages.length,
      ),
      messages: nextMessages,
    );
    await _persistActiveConversation();
  }

  Future<void> upsertMessage(ChatMessage message) async {
    final active = _activeConversation;
    if (active == null) {
      return;
    }
    final nextMessages = List<ChatHistoryMessageRecord>.from(active.messages);
    final nextRecord = ChatHistoryMessageRecord.fromChatMessage(message);
    final index = nextMessages.indexWhere((item) => item.id == message.id);
    if (index == -1) {
      nextMessages.add(nextRecord);
    } else {
      nextMessages[index] = nextRecord;
    }
    _activeConversation = active.copyWith(
      summary: active.summary.copyWith(
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        messageCount: nextMessages.length,
      ),
      messages: nextMessages,
    );
    await _persistActiveConversation();
  }

  Future<List<ChatHistoryConversationSummary>> listConversations() async {
    final indexFile = await _indexFile();
    if (!await indexFile.exists()) {
      return const [];
    }

    try {
      final raw = jsonDecode(await indexFile.readAsString()) as List<dynamic>;
      final summaries = raw
          .whereType<Map<String, dynamic>>()
          .map(ChatHistoryConversationSummary.fromJson)
          .toList(growable: false);
      summaries.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return summaries;
    } catch (_) {
      return const [];
    }
  }

  Future<ChatHistoryConversation?> loadConversation(
    String conversationId,
  ) async {
    final file = await _conversationFile(conversationId);
    if (!await file.exists()) {
      return null;
    }

    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ChatHistoryConversation.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<List<ChatMessage>> loadRecentMessages(
    String conversationId, {
    int? limit,
  }) async {
    final conversation = await loadConversation(conversationId);
    if (conversation == null) {
      return const [];
    }
    final messages = conversation.messages
        .map((message) => message.toChatMessage())
        .toList(growable: false);
    if (limit == null || messages.length <= limit) {
      return messages;
    }
    return messages.sublist(messages.length - limit);
  }

  Future<void> deleteConversation(String conversationId) async {
    final directory = await _conversationDirectory(conversationId);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }

    final summaries = await listConversations();
    final next = summaries
        .where((summary) => summary.id != conversationId)
        .toList(growable: false);
    await _writeIndex(next);

    if (_activeConversation?.summary.id == conversationId) {
      _activeConversation = null;
    }
  }

  Future<void> clearAll() async {
    final root = await _rootDirectory();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    _activeConversation = null;
  }

  Future<void> _persistActiveConversation() async {
    final active = _activeConversation;
    if (active == null) {
      return;
    }
    final file = await _conversationFile(active.summary.id);
    await file.writeAsString(jsonEncode(active.toJson()), flush: true);
    await _excludeFromBackup(file.path);

    final summaries = await listConversations();
    final nextSummaries = [
      active.summary,
      ...summaries.where((summary) => summary.id != active.summary.id),
    ]..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    await _writeIndex(nextSummaries);
  }

  Future<void> _writeIndex(
    List<ChatHistoryConversationSummary> summaries,
  ) async {
    final file = await _indexFile();
    final payload = summaries.map((summary) => summary.toJson()).toList();
    await file.writeAsString(jsonEncode(payload), flush: true);
    await _excludeFromBackup(file.path);
  }

  Future<Directory> _rootDirectory() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(path.join(support.path, 'easychat_history'));
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    await _excludeFromBackup(root.path);
    return root;
  }

  Future<File> _indexFile() async {
    final root = await _rootDirectory();
    return File(path.join(root.path, 'conversations_index.json'));
  }

  Future<Directory> _conversationDirectory(String conversationId) async {
    final root = await _rootDirectory();
    final directory = Directory(
      path.join(root.path, 'conversations', conversationId),
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    await _excludeFromBackup(directory.path);
    return directory;
  }

  Future<File> _conversationFile(String conversationId) async {
    final directory = await _conversationDirectory(conversationId);
    return File(path.join(directory.path, 'conversation.json'));
  }

  Future<void> _excludeFromBackup(String targetPath) async {
    if (!Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod('excludeFromBackup', {'path': targetPath});
    } catch (_) {
      // Ignore backup flag failures and keep the history readable.
    }
  }

  static String _buildTitle({String? peerName, String? peerDeviceInfo}) {
    final cleanedDevice = peerDeviceInfo?.trim();
    if (cleanedDevice != null && cleanedDevice.isNotEmpty) {
      return cleanedDevice;
    }
    final cleanedName = peerName?.trim();
    if (cleanedName != null && cleanedName.isNotEmpty) {
      return cleanedName;
    }
    return '未命名会话';
  }
}
