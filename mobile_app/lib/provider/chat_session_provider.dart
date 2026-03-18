import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../common/app_constants.dart';
import '../models/chat_message.dart';
import '../models/connection_cache.dart';
import '../models/initial_messages.dart';
import '../models/pending_attachment.dart';
import '../models/pairing_payload.dart';
import '../service/connection_persistence.dart';
import '../service/local_chat_server.dart';
import '../service/pairing_api_service.dart';
import '../utils/network_tools.dart';

class ChatSessionProvider extends ChangeNotifier {
  ChatSessionProvider({
    ConnectionPersistence? persistence,
    LocalChatServer? chatServer,
    PairingApiService? pairingApiService,
  }) : _persistence = persistence ?? ConnectionPersistence(),
       _pairingApiService = pairingApiService ?? const PairingApiService(),
       _chatServer =
           chatServer ??
           LocalChatServer(
             onBrowserMessage: (_) {},
             onPeerMeta: (_) {},
             onFileReceived: (_) {},
             onFileProgress: (_, _) {},
             onFileDelivered: (_) {},
             onStatusChanged: (_) {},
             onRemoteDisconnect: () {},
           ) {
    _bindServerCallbacks();
    messageController.addListener(_safeNotify);
  }

  final TextEditingController messageController = TextEditingController();
  final TextEditingController pairingController = TextEditingController();
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController(
    text: '${AppConstants.defaultDirectPort}',
  );
  final TextEditingController deviceController = TextEditingController(
    text: '我的手机',
  );
  final List<ChatMessage> _messages = List<ChatMessage>.from(initialMessages);
  final List<PendingAttachment> _pendingAttachments = [];
  final ConnectionPersistence _persistence;
  final PairingApiService _pairingApiService;
  final LocalChatServer _chatServer;

  PairingPayload? _pairingPayload;
  String? _registrationError;
  String _serverStatus = '未启动';
  String? _directToken;
  bool _isRegistering = false;
  bool _hasCachedConnection = false;
  String? _browserPeerName;
  String? _browserPeerAddress;
  bool _disposed = false;
  int _registrationAttemptId = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<PendingAttachment> get pendingAttachments =>
      List.unmodifiable(_pendingAttachments);
  PairingPayload? get pairingPayload => _pairingPayload;
  String? get registrationError => _registrationError;
  String get serverStatus => _serverStatus;
  String? get directToken => _directToken;
  bool get isRegistering => _isRegistering;
  bool get hasCachedConnection => _hasCachedConnection;
  String get browserPeerName => _browserPeerName ?? '等待浏览器同步';
  String get browserPeerAddress => _browserPeerAddress ?? '等待浏览器同步';
  bool get canSend =>
      messageController.text.trim().isNotEmpty ||
      _pendingAttachments.isNotEmpty;
  String get deviceName => deviceController.text.trim().isEmpty
      ? '我的手机'
      : deviceController.text.trim();

  void _bindServerCallbacks() {
    _chatServer.onBrowserMessage = (payload) {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'browser',
          text: payload.text,
          compositionId: payload.compositionId,
        ),
      );
      _safeNotify();
    };

    _chatServer.onFileReceived = (file) {
      unawaited(_handleReceivedFile(file));
    };

    _chatServer.onPeerMeta = (payload) {
      if (payload.role == 'browser') {
        _browserPeerName = payload.name;
        _browserPeerAddress = payload.address;
        _safeNotify();
      }
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
      if (status == 'Browser connected directly') {
        _syncPhonePeerMeta();
      }
      _safeNotify();
    };

    _chatServer.onRemoteDisconnect = () {
      unawaited(disconnectAndClear(notifyPeer: false));
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

  Future<void> restoreServerOnForeground() async {
    if (_disposed || _chatServer.isRunning) {
      return;
    }

    final cached = await _persistence.restore();
    if (cached == null) {
      _hasCachedConnection = false;
      _safeNotify();
      return;
    }

    try {
      await _chatServer.start(port: cached.phonePort, token: cached.token);
      _directToken = cached.token;
      _hasCachedConnection = true;
      _serverStatus = _localizeServerStatus(
        'Listening on port ${cached.phonePort}',
      );
      _safeNotify();
    } catch (_) {
      _hasCachedConnection = false;
      _safeNotify();
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
    final attemptId = ++_registrationAttemptId;

    _isRegistering = true;
    _registrationError = null;
    _safeNotify();

    final port =
        int.tryParse(portController.text.trim()) ??
        AppConstants.defaultDirectPort;
    final token = 'token-${DateTime.now().millisecondsSinceEpoch}';
    final localIp = await NetworkTools.detectBestLocalIp(
      preferredPeerIp: NetworkTools.extractHostIp(pairingPayload.serverUrl),
    );
    if (!_isActiveRegistrationAttempt(attemptId)) {
      return false;
    }
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
      if (!_isActiveRegistrationAttempt(attemptId)) {
        await _chatServer.stop();
        return false;
      }

      await _pairingApiService.registerPhone(
        PairingRegisterRequest(
          serverUrl: pairingPayload.serverUrl,
          sessionId: pairingPayload.sessionId,
          challenge: pairingPayload.challenge,
          deviceName: deviceController.text.trim(),
          phoneIp: phoneIp,
          phonePort: port,
          token: token,
        ),
      );
      if (!_isActiveRegistrationAttempt(attemptId)) {
        await _chatServer.stop();
        return false;
      }

      final cache = ConnectionCache(
        deviceName: deviceController.text.trim(),
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
      if (_isActiveRegistrationAttempt(attemptId)) {
        _registrationError = error.toString();
        _safeNotify();
      }
      return false;
    } finally {
      if (_registrationAttemptId == attemptId) {
        _isRegistering = false;
        _safeNotify();
      }
    }
  }

  Future<void> abortConnecting() async {
    if (!_isRegistering) {
      return;
    }

    _registrationAttemptId += 1;
    _isRegistering = false;
    _registrationError = null;
    _directToken = null;
    _hasCachedConnection = false;
    _browserPeerName = null;
    _browserPeerAddress = null;
    _pairingPayload = null;
    _pendingAttachments.clear();
    await _chatServer.stop();
    _messages
      ..clear()
      ..addAll(initialMessages);
    _safeNotify();
  }

  Future<void> disconnectAndClear({bool notifyPeer = true}) async {
    if (notifyPeer) {
      _chatServer.sendDisconnectNotice();
    }
    await _chatServer.stop();
    await _persistence.clear();
    _hasCachedConnection = false;
    _directToken = null;
    _browserPeerName = null;
    _browserPeerAddress = null;
    _pairingPayload = null;
    pairingController.clear();
    _registrationError = null;
    _pendingAttachments.clear();
    _messages
      ..clear()
      ..addAll(initialMessages);
    _safeNotify();
  }

  Future<void> sendDraft() async {
    final text = messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final compositionId = _pendingAttachments.isNotEmpty
        ? 'compose-${DateTime.now().millisecondsSinceEpoch}'
        : null;
    final batchId = _pendingAttachments.length > 1
        ? 'batch-${DateTime.now().millisecondsSinceEpoch}'
        : null;

    if (_pendingAttachments.isNotEmpty) {
      for (final attachment in _pendingAttachments) {
        final transferId =
            'outgoing-${DateTime.now().millisecondsSinceEpoch}-${attachment.name.hashCode}';
        final batchTotal = _pendingAttachments.length > 1
            ? _pendingAttachments.length
            : null;

        _messages.add(
          ChatMessage(
            id: transferId,
            sender: 'phone',
            text: attachment.name,
            type: 'file',
            compositionId: compositionId,
            batchId: batchId,
            batchTotal: batchTotal,
            meta: '${_formatBytes(attachment.size)} • 0%',
            bytes: attachment.bytes,
            mimeType: attachment.mimeType,
            progress: 0,
          ),
        );

        _chatServer.sendPhoneFile(
          transferId: transferId,
          name: attachment.name,
          mimeType: attachment.mimeType,
          bytes: attachment.bytes,
          compositionId: compositionId,
          batchId: batchId,
          batchTotal: batchTotal,
        );
      }
      _pendingAttachments.clear();
    }

    if (text.isNotEmpty) {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'phone',
          text: text,
          compositionId: compositionId,
        ),
      );
      _chatServer.sendPhoneMessage(text, compositionId: compositionId);
    }

    messageController.clear();
    _safeNotify();
  }

  Future<void> pickPendingFiles() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    final files =
        result?.files.where((file) => file.bytes != null).toList() ?? [];
    if (files.isEmpty) return;

    for (final file in files) {
      final bytes = file.bytes!;
      _appendPendingAttachment(
        name: file.name,
        bytes: bytes,
        mimeType: _inferMimeType(file.extension),
      );
    }

    _safeNotify();
  }

  Future<void> pickPendingImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;

      for (final image in images) {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) continue;
        _appendPendingAttachment(
          name: image.name,
          bytes: bytes,
          mimeType: _inferMimeType(_extensionOf(image.name)),
        );
      }
      _safeNotify();
    } catch (_) {
      // Ignore picker cancellation and platform errors.
    }
  }

  Future<void> capturePendingImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) return;

      _appendPendingAttachment(
        name: image.name,
        bytes: bytes,
        mimeType: _inferMimeType(_extensionOf(image.name)),
      );
      _safeNotify();
    } catch (_) {
      // Ignore picker cancellation and platform errors.
    }
  }

  void removePendingAttachment(String id) {
    _pendingAttachments.removeWhere((attachment) => attachment.id == id);
    _safeNotify();
  }

  void clearPendingAttachments() {
    if (_pendingAttachments.isEmpty) return;
    _pendingAttachments.clear();
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
        type: 'file',
        compositionId: file.compositionId,
        batchId: file.batchId,
        batchTotal: file.batchTotal,
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

  String _inferMimeType(String? extension) {
    final normalized = extension?.toLowerCase();
    return switch (normalized) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'md' => 'text/markdown',
      _ => 'application/octet-stream',
    };
  }

  void _appendPendingAttachment({
    required String name,
    required List<int> bytes,
    required String mimeType,
  }) {
    _pendingAttachments.add(
      PendingAttachment(
        id: 'pending-${DateTime.now().microsecondsSinceEpoch}-${name.hashCode}',
        name: name,
        size: bytes.length,
        mimeType: mimeType,
        bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      ),
    );
  }

  String? _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot >= fileName.length - 1) {
      return null;
    }
    return fileName.substring(dot + 1);
  }

  void _syncPhonePeerMeta() {
    final name = deviceName;
    final ip = ipController.text.trim();
    final port = portController.text.trim();
    final address = ip.isNotEmpty && port.isNotEmpty ? '$ip:$port' : '未知';
    _chatServer.sendPhonePeerMeta(name: name, address: address);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  bool _isActiveRegistrationAttempt(int attemptId) {
    return !_disposed && _registrationAttemptId == attemptId;
  }

  @override
  void dispose() {
    _disposed = true;
    messageController.dispose();
    pairingController.dispose();
    ipController.dispose();
    portController.dispose();
    deviceController.dispose();
    unawaited(_chatServer.stop());
    super.dispose();
  }
}
