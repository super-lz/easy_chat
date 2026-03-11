import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../common/app_constants.dart';
import '../models/chat_message.dart';
import '../models/connection_cache.dart';
import '../models/initial_messages.dart';
import '../models/pairing_payload.dart';
import '../service/connection_persistence.dart';
import '../service/local_chat_server.dart';
import '../service/pairing_api_service.dart';
import '../utils/network_tools.dart';

class ChatSessionPProvider extends ChangeNotifier {
  ChatSessionPProvider({
    ConnectionPersistence? persistence,
    LocalChatServer? chatServer,
    PairingApiService? pairingApiService,
  })  : _persistence = persistence ?? ConnectionPersistence(),
        _pairingApiService = pairingApiService ?? const PairingApiService(),
        _chatServer = chatServer ??
            LocalChatServer(
              onBrowserMessage: (_) {},
              onFileReceived: (_) {},
              onFileProgress: (_, _) {},
              onFileDelivered: (_) {},
              onStatusChanged: (_) {},
            ) {
    _bindServerCallbacks();
  }

  final TextEditingController messageController = TextEditingController();
  final TextEditingController pairingController = TextEditingController();
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController =
      TextEditingController(text: '${AppConstants.defaultDirectPort}');
  final TextEditingController wifiController = TextEditingController();
  final TextEditingController deviceController =
      TextEditingController(text: '我的手机');
  final List<ChatMessage> _messages = List<ChatMessage>.from(initialMessages);
  final ConnectionPersistence _persistence;
  final PairingApiService _pairingApiService;
  final LocalChatServer _chatServer;

  PairingPayload? _pairingPayload;
  String? _registrationError;
  String _serverStatus = '未启动';
  String? _directToken;
  bool _isRegistering = false;
  bool _hasCachedConnection = false;
  bool _disposed = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  PairingPayload? get pairingPayload => _pairingPayload;
  String? get registrationError => _registrationError;
  String get serverStatus => _serverStatus;
  String? get directToken => _directToken;
  bool get isRegistering => _isRegistering;
  bool get hasCachedConnection => _hasCachedConnection;
  String get deviceName => deviceController.text.trim().isEmpty
      ? '我的手机'
      : deviceController.text.trim();
  String get wifiName => wifiController.text.trim();

  void _bindServerCallbacks() {
    _chatServer.onBrowserMessage = (text) {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'browser',
          text: text,
        ),
      );
      _safeNotify();
    };

    _chatServer.onFileReceived = (file) {
      unawaited(_handleReceivedFile(file));
    };

    _chatServer.onFileProgress = (transferId, progress) {
      _replaceTransferProgress(transferId, progress);
      _safeNotify();
    };

    _chatServer.onFileDelivered = (transferId) {
      final index = _messages.indexWhere((message) => message.id == transferId);
      if (index == -1) return;
      final existing = _messages[index];
      final sizePart = existing.meta?.split('•').first.trim() ?? '';
      _messages[index] = existing.copyWith(
        meta: '$sizePart • 已发送',
        progress: 1,
      );
      _safeNotify();
    };

    _chatServer.onStatusChanged = (status) {
      _serverStatus = _localizeServerStatus(status);
      _safeNotify();
    };
  }

  Future<bool> restoreConnectionIfNeeded() async {
    final cached = await _persistence.restore();
    final localIp = await NetworkTools.detectBestLocalIp();

    if (localIp != null) {
      ipController.text = localIp;
    }

    if (cached == null) {
      _hasCachedConnection = false;
      _safeNotify();
      return false;
    }

    deviceController.text = cached.deviceName;
    wifiController.text = cached.wifiName;
    ipController.text = localIp ?? cached.phoneIp;
    portController.text = cached.phonePort.toString();
    _directToken = cached.token;

    try {
      await _chatServer.start(port: cached.phonePort, token: cached.token);
      _hasCachedConnection = true;
      _messages
        ..clear()
        ..addAll(initialMessages)
        ..add(
          ChatMessage(
            id: 'system-resume',
            sender: 'system',
            text: '已恢复本地直连服务，等待电脑重新连接。',
            isSystem: true,
          ),
        );
      _safeNotify();
      return true;
    } catch (_) {
      await _persistence.clear();
      _hasCachedConnection = false;
      _safeNotify();
      return false;
    }
  }

  bool applyPairingInput() {
    final nextPayload = _parsePairingPayload(pairingController.text.trim());
    _registrationError = null;
    _pairingPayload = nextPayload;
    if (nextPayload == null) {
      _registrationError = '二维码内容无效，请重新扫描。';
      _safeNotify();
      return false;
    }

    _safeNotify();
    return true;
  }

  Future<bool> registerPhone() async {
    final pairingPayload = _pairingPayload;
    if (pairingPayload == null) return false;

    _isRegistering = true;
    _registrationError = null;
    _safeNotify();

    final port =
        int.tryParse(portController.text.trim()) ?? AppConstants.defaultDirectPort;
    final token = 'token-${DateTime.now().millisecondsSinceEpoch}';
    final localIp = await NetworkTools.detectBestLocalIp(
      preferredPeerIp: NetworkTools.extractHostIp(pairingPayload.serverUrl),
    );
    final phoneIp = (localIp ?? ipController.text.trim()).trim();
    if (!NetworkTools.isUsableIpv4(phoneIp)) {
      _registrationError = '无法获取本机局域网 IP，请手动确认后重试。';
      _isRegistering = false;
      _safeNotify();
      return false;
    }
    ipController.text = phoneIp;

    try {
      await _chatServer.start(port: port, token: token);

      await _pairingApiService.registerPhone(
        PairingRegisterRequest(
          serverUrl: pairingPayload.serverUrl,
          sessionId: pairingPayload.sessionId,
          challenge: pairingPayload.challenge,
          deviceName: deviceController.text.trim(),
          wifiName: wifiController.text.trim(),
          phoneIp: phoneIp,
          phonePort: port,
          token: token,
        ),
      );

      final cache = ConnectionCache(
        deviceName: deviceController.text.trim(),
        wifiName: wifiController.text.trim(),
        phoneIp: phoneIp,
        phonePort: port,
        token: token,
      );
      await _persistence.save(cache);

      _directToken = token;
      _hasCachedConnection = true;
      _messages
        ..clear()
        ..addAll(initialMessages)
        ..add(
          ChatMessage(
            id: 'system-direct-started',
            sender: 'system',
            text: '本地直连服务已启动。',
            isSystem: true,
          ),
        );
      _safeNotify();
      return true;
    } catch (error) {
      await _chatServer.stop();
      _registrationError = error.toString();
      _safeNotify();
      return false;
    } finally {
      _isRegistering = false;
      _safeNotify();
    }
  }

  Future<void> disconnectAndClear() async {
    await _chatServer.stop();
    await _persistence.clear();
    _hasCachedConnection = false;
    _directToken = null;
    _pairingPayload = null;
    pairingController.clear();
    _registrationError = null;
    _messages
      ..clear()
      ..addAll(initialMessages);
    _safeNotify();
  }

  Future<void> sendDraft() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    _messages.add(
      ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        sender: 'phone',
        text: text,
      ),
    );
    messageController.clear();
    _chatServer.sendPhoneMessage(text);
    _safeNotify();
  }

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    final files = result?.files.where((file) => file.bytes != null).toList() ?? [];
    if (files.isEmpty) return;

    final batchId = files.length > 1
        ? 'batch-${DateTime.now().millisecondsSinceEpoch}'
        : null;

    for (final file in files) {
      final bytes = file.bytes!;
      final mimeType = file.extension == null
          ? 'application/octet-stream'
          : 'application/${file.extension}';
      final transferId =
          'outgoing-${DateTime.now().millisecondsSinceEpoch}-${file.name.hashCode}';

      _messages.add(
        ChatMessage(
          id: transferId,
          sender: 'phone',
          text: file.name,
          meta: '${_formatBytes(bytes.length)} • 0%',
          bytes: bytes,
          mimeType: mimeType,
          progress: 0,
        ),
      );

      _chatServer.sendPhoneFile(
        transferId: transferId,
        name: file.name,
        mimeType: mimeType,
        bytes: bytes,
        batchId: batchId,
        batchTotal: files.length > 1 ? files.length : null,
      );
    }

    _safeNotify();
  }

  PairingPayload? _parsePairingPayload(String input) {
    if (input.isEmpty) return null;
    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    final sessionId = uri.queryParameters['sessionId'];
    final challenge = uri.queryParameters['challenge'];
    final serverUrl = uri.queryParameters['serverUrl'];
    if (sessionId == null || challenge == null || serverUrl == null) {
      return null;
    }

    return PairingPayload(
      sessionId: sessionId,
      challenge: challenge,
      serverUrl: serverUrl,
    );
  }

  void _replaceTransferProgress(String transferId, double progress) {
    final index = _messages.indexWhere((message) => message.id == transferId);
    if (index == -1) return;

    final existing = _messages[index];
    final sizePart = existing.meta?.split('•').first.trim() ?? '';
    _messages[index] = existing.copyWith(
      meta: '$sizePart • ${(progress * 100).round()}%',
      progress: progress,
    );
  }

  Future<void> _handleReceivedFile(DirectFilePayload file) async {
    final savedPath = await _saveReceivedFile(file);
    _replaceTransferProgress(file.transferId, 1);
    _messages.add(
      ChatMessage(
        id: 'received-${file.transferId}',
        sender: 'browser',
        text: file.name,
        meta: '${_formatBytes(file.size)} • 已保存',
        bytes: file.bytes,
        mimeType: file.mimeType,
        progress: 1,
        savedPath: savedPath,
      ),
    );
    _safeNotify();
  }

  Future<String?> _saveReceivedFile(DirectFilePayload file) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final incomingDir = Directory('${directory.path}/incoming');
      if (!incomingDir.existsSync()) {
        incomingDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = file.name.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '_');
      final path = '${incomingDir.path}/$timestamp-$safeName';
      final output = File(path);
      await output.writeAsBytes(file.bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }

  String _localizeServerStatus(String status) {
    return switch (status) {
      'Direct server offline' => '未启动',
      'Listening on port ${AppConstants.defaultDirectPort}' => '监听中',
      'Browser connected directly' => '电脑已接入',
      'Waiting for browser reconnect' => '等待电脑重连',
      _ => status,
    };
  }

  String _formatBytes(int size) {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    messageController.dispose();
    pairingController.dispose();
    ipController.dispose();
    portController.dispose();
    wifiController.dispose();
    deviceController.dispose();
    unawaited(_chatServer.stop());
    super.dispose();
  }
}
