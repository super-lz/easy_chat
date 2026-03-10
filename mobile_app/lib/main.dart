import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'local_chat_server.dart';

void main() {
  runApp(const EasyChatApp());
}

class EasyChatApp extends StatelessWidget {
  const EasyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F8F5B);

    return MaterialApp(
      title: 'Easy Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFFFFDF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F4EE),
        useMaterial3: true,
      ),
      home: const EasyChatHome(),
    );
  }
}

enum AppScreen { home, scanner, confirm, chat }

class ChatMessage {
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
    String? meta,
    Uint8List? bytes,
    double? progress,
    String? savedPath,
  }) {
    return ChatMessage(
      id: id,
      sender: sender,
      text: text,
      meta: meta ?? this.meta,
      isSystem: isSystem,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType,
      progress: progress ?? this.progress,
      savedPath: savedPath ?? this.savedPath,
    );
  }
}

class PairingPayload {
  const PairingPayload({
    required this.sessionId,
    required this.challenge,
    required this.serverUrl,
  });

  final String sessionId;
  final String challenge;
  final String serverUrl;
}

class EasyChatHome extends StatefulWidget {
  const EasyChatHome({super.key});

  @override
  State<EasyChatHome> createState() => _EasyChatHomeState();
}

class _EasyChatHomeState extends State<EasyChatHome> {
  AppScreen _screen = AppScreen.home;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _pairingController = TextEditingController();
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.1.23',
  );
  final TextEditingController _portController = TextEditingController(
    text: '9763',
  );
  final TextEditingController _wifiController = TextEditingController(
    text: 'Leazer Home 5G',
  );
  final TextEditingController _deviceController = TextEditingController(
    text: 'Leazer Phone',
  );
  final List<ChatMessage> _messages = const [
    ChatMessage(
      id: 'system-ready',
      sender: 'system',
      text:
          'Phone app ready. Pair from the browser, then switch to a direct local socket.',
      isSystem: true,
    ),
  ].toList();

  late final LocalChatServer _chatServer;
  PairingPayload? _pairingPayload;
  String? _registrationError;
  String _serverStatus = 'Direct server offline';
  String? _directToken;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _chatServer = LocalChatServer(
      onBrowserMessage: (text) {
        if (!mounted) {
          return;
        }

        setState(() {
          _messages.add(
            ChatMessage(
              id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
              sender: 'browser',
              text: text,
            ),
          );
        });
      },
      onFileReceived: (file) {
        if (!mounted) {
          return;
        }

        _handleReceivedFile(file);
      },
      onFileProgress: (transferId, progress) {
        if (!mounted) {
          return;
        }

        setState(() {
          _replaceTransferProgress(transferId, progress);
        });
      },
      onFileDelivered: (transferId) {
        if (!mounted) {
          return;
        }

        setState(() {
          final index = _messages.indexWhere(
            (message) => message.id == transferId,
          );
          if (index == -1) {
            return;
          }

          final existing = _messages[index];
          final sizePart = existing.meta?.split('•').first.trim() ?? '';
          _messages[index] = existing.copyWith(
            meta: '$sizePart • sent file',
            progress: 1,
          );
        });
      },
      onStatusChanged: (status) {
        if (!mounted) {
          return;
        }

        setState(() {
          _serverStatus = status;
        });
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pairingController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _wifiController.dispose();
    _deviceController.dispose();
    _chatServer.stop();
    super.dispose();
  }

  void _sendDraft() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(
        ChatMessage(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          sender: 'phone',
          text: text,
        ),
      );
      _controller.clear();
    });
    _chatServer.sendPhoneMessage(text);
  }

  void _replaceTransferProgress(String transferId, double progress) {
    final index = _messages.indexWhere((message) => message.id == transferId);
    if (index == -1) {
      return;
    }

    final existing = _messages[index];
    final sizePart = existing.meta?.split('•').first.trim() ?? '';
    _messages[index] = existing.copyWith(
      meta: '$sizePart • ${(progress * 100).round()}%',
      progress: progress,
    );
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    final files = result?.files.where((file) => file.bytes != null).toList() ?? [];
    if (files.isEmpty) {
      return;
    }

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
      setState(() {
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
      });

      _chatServer.sendPhoneFile(
        transferId: transferId,
        name: file.name,
        mimeType: mimeType,
        bytes: bytes,
        batchId: batchId,
        batchTotal: files.length > 1 ? files.length : null,
      );
    }
  }

  Future<void> _handleReceivedFile(DirectFilePayload file) async {
    final savedPath = await _saveReceivedFile(file);
    if (!mounted) {
      return;
    }

    setState(() {
      _replaceTransferProgress(file.transferId, 1);
      _messages.add(
        ChatMessage(
          id: 'received-${file.transferId}',
          sender: 'browser',
          text: file.name,
          meta: '${_formatBytes(file.size)} • saved locally',
          bytes: file.bytes,
          mimeType: file.mimeType,
          progress: 1,
          savedPath: savedPath,
        ),
      );
    });
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

  void _applyPairingInput() {
    final nextPayload = _parsePairingPayload(_pairingController.text.trim());

    setState(() {
      _registrationError = null;
      _pairingPayload = nextPayload;
      _screen = nextPayload == null ? AppScreen.scanner : AppScreen.confirm;
      if (nextPayload == null) {
        _registrationError =
            'Invalid pairing link. It should include sessionId, challenge, and serverUrl.';
      }
    });
  }

  Future<void> _registerPhone() async {
    final pairingPayload = _pairingPayload;
    if (pairingPayload == null) {
      return;
    }

    setState(() {
      _isRegistering = true;
      _registrationError = null;
    });

    final port = int.tryParse(_portController.text.trim()) ?? 9763;
    final token = 'token-${DateTime.now().millisecondsSinceEpoch}';
    final localIp = await _detectLocalIp();
    if (localIp != null) {
      _ipController.text = localIp;
    }

    try {
      await _chatServer.start(port: port, token: token);

      final uri = Uri.parse(
        '${pairingPayload.serverUrl}/api/pairings/${pairingPayload.sessionId}/register',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'challenge': pairingPayload.challenge,
          'deviceName': _deviceController.text.trim(),
          'wifiName': _wifiController.text.trim(),
          'phoneIp': _ipController.text.trim(),
          'phonePort': port,
          'token': token,
          'protocolVersion': 1,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Register failed (${response.statusCode})');
      }

      setState(() {
        _directToken = token;
        _messages.add(
          ChatMessage(
            id: 'system-direct-started',
            sender: 'system',
            text:
                'Direct server started at ${_ipController.text.trim()}:$port.',
            isSystem: true,
          ),
        );
        _screen = AppScreen.chat;
      });
    } catch (error) {
      await _chatServer.stop();
      setState(() {
        _registrationError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  PairingPayload? _parsePairingPayload(String input) {
    if (input.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(input);
    if (uri == null) {
      return null;
    }

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

  String _formatBytes(int size) {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }

  Future<String?> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final value = address.address;
          if (value.startsWith('192.168.') ||
              value.startsWith('10.') ||
              value.startsWith('172.')) {
            return value;
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_screen) {
      AppScreen.home => _HomeScreen(
        onStart: () => setState(() => _screen = AppScreen.scanner),
      ),
      AppScreen.scanner => _ScannerScreen(
        pairingController: _pairingController,
        errorText: _registrationError,
        onBack: () => setState(() => _screen = AppScreen.home),
        onApply: _applyPairingInput,
        onUseSample: () {
          _pairingController.text =
              'easychat://pair?sessionId=demo-session&challenge=demo-challenge&serverUrl=http%3A%2F%2Flocalhost%3A8787';
          _applyPairingInput();
        },
      ),
      AppScreen.confirm => _ConfirmScreen(
        pairingPayload: _pairingPayload,
        deviceController: _deviceController,
        ipController: _ipController,
        portController: _portController,
        wifiController: _wifiController,
        isSubmitting: _isRegistering,
        serverStatus: _serverStatus,
        errorText: _registrationError,
        onCancel: () => setState(() => _screen = AppScreen.home),
        onApprove: _registerPhone,
      ),
      AppScreen.chat => _ChatScreen(
        messages: _messages,
        controller: _controller,
        deviceName: _deviceController.text.trim(),
        wifiName: _wifiController.text.trim(),
        serverStatus: _serverStatus,
        token: _directToken,
        onPickFile: _pickAndSendFile,
        onBack: () => setState(() => _screen = AppScreen.home),
        onSend: _sendDraft,
      ),
    };
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tag(text: 'Easy Chat'),
                const SizedBox(height: 20),
                Text(
                  'Same Wi-Fi,\ndirect transfer.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Open the app, scan the browser QR code, then send notes and files without a desktop install.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF676457),
                  ),
                ),
                const SizedBox(height: 28),
                _FeatureCard(
                  title: 'Connect to Computer',
                  subtitle:
                      'Scan or paste the pairing link, then expose a local direct socket.',
                  actionLabel: 'Start',
                  onTap: onStart,
                ),
                const SizedBox(height: 14),
                const _FeatureCard(
                  title: 'Recent History',
                  subtitle:
                      'Keep the latest transfers available on this device.',
                  actionLabel: 'Soon',
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFDDD6C8)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.wifi_tethering_rounded,
                        color: Color(0xFF2F8F5B),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Keep the app open while the browser is connected.',
                          style: TextStyle(color: Color(0xFF676457)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen({
    required this.pairingController,
    required this.errorText,
    required this.onBack,
    required this.onApply,
    required this.onUseSample,
  });

  final TextEditingController pairingController;
  final String? errorText;
  final VoidCallback onBack;
  final VoidCallback onApply;
  final VoidCallback onUseSample;

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _hasScanned = false;

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) {
      return;
    }

    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) {
      return;
    }

    _hasScanned = true;
    widget.pairingController.text = value;
    widget.onApply();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Spacer(),
                  const Text('Scan Browser QR'),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          color: const Color(0xFF161614),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              MobileScanner(onDetect: _handleBarcode),
                              IgnorePointer(
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white70,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 28,
                                left: 24,
                                right: 24,
                                child: Text(
                                  'Point the camera at the QR code shown in the browser. Manual paste is still available below.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: widget.pairingController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Pairing link',
                          hintText:
                              'easychat://pair?sessionId=...&challenge=...&serverUrl=...',
                          errorText: widget.errorText,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFFDDD6C8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFFDDD6C8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onUseSample,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text('Use Sample'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onApply,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2F8F5B),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmScreen extends StatelessWidget {
  const _ConfirmScreen({
    required this.pairingPayload,
    required this.deviceController,
    required this.ipController,
    required this.portController,
    required this.wifiController,
    required this.isSubmitting,
    required this.serverStatus,
    required this.errorText,
    required this.onCancel,
    required this.onApprove,
  });

  final PairingPayload? pairingPayload;
  final TextEditingController deviceController;
  final TextEditingController ipController;
  final TextEditingController portController;
  final TextEditingController wifiController;
  final bool isSubmitting;
  final String serverStatus;
  final String? errorText;
  final VoidCallback onCancel;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tag(text: 'Pairing'),
                const SizedBox(height: 24),
                Text(
                  'Register this phone endpoint?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'This step starts a local WebSocket server on the phone, then posts that address back to the pairing service.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF676457),
                  ),
                ),
                const SizedBox(height: 24),
                _InfoTile(
                  label: 'Session',
                  value: pairingPayload?.sessionId ?? 'Unavailable',
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  label: 'Server',
                  value: pairingPayload?.serverUrl ?? 'Unavailable',
                ),
                const SizedBox(height: 12),
                _InfoTile(label: 'Direct status', value: serverStatus),
                const SizedBox(height: 16),
                _LabeledField(
                  label: 'Device name',
                  controller: deviceController,
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Local IP',
                  controller: ipController,
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                _LabeledField(label: 'Local port', controller: portController),
                const SizedBox(height: 12),
                _LabeledField(label: 'Wi-Fi name', controller: wifiController),
                if (errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Color(0xFFB84C3A)),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: isSubmitting ? null : onApprove,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2F8F5B),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          isSubmitting ? 'Registering…' : 'Start Direct Server',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatScreen extends StatelessWidget {
  const _ChatScreen({
    required this.messages,
    required this.controller,
    required this.deviceName,
    required this.wifiName,
    required this.serverStatus,
    required this.token,
    required this.onPickFile,
    required this.onBack,
    required this.onSend,
  });

  final List<ChatMessage> messages;
  final TextEditingController controller;
  final String deviceName;
  final String wifiName;
  final String serverStatus;
  final String? token;
  final Future<void> Function() onPickFile;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Direct server on $wifiName',
                          style: const TextStyle(color: Color(0xFF676457)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1A2F8F5B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Listening',
                      style: TextStyle(
                        color: Color(0xFF256F47),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _InlineStatus(label: 'Socket', value: serverStatus),
                  const SizedBox(height: 8),
                  _InlineStatus(label: 'Token', value: token ?? 'Unavailable'),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFDF9F0), Color(0xFFF4EEE2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isPhone = message.sender == 'phone';
                    final isImage =
                        message.mimeType?.startsWith('image/') ?? false;

                    if (message.isSystem) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            message.text,
                            style: const TextStyle(color: Color(0xFF676457)),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: isPhone
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isPhone
                              ? const Color(0xFF2F8F5B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: isPhone
                              ? null
                              : Border.all(color: const Color(0xFFDDD6C8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isImage && message.bytes != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  message.bytes!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              message.text,
                              style: TextStyle(
                                color: isPhone
                                    ? Colors.white
                                    : const Color(0xFF1E1E1A),
                                fontWeight: message.bytes != null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            if (message.meta != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                message.meta!,
                                style: TextStyle(
                                  color: isPhone
                                      ? Colors.white70
                                      : const Color(0xFF676457),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (message.savedPath != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                message.savedPath!,
                                style: TextStyle(
                                  color: isPhone
                                      ? Colors.white70
                                      : const Color(0xFF676457),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (message.progress != null) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: message.progress,
                                  minHeight: 6,
                                  backgroundColor: isPhone
                                      ? Colors.white24
                                      : const Color(0x1A1E1E1A),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isPhone
                                        ? Colors.white
                                        : const Color(0xFF2F8F5B),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemCount: messages.length,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async => onPickFile(),
                    icon: const Icon(Icons.attach_file_rounded),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText:
                            'Type a message. Browser messages will appear here live.',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD6C8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD6C8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F8F5B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1A2F8F5B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF256F47),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDD6C8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF676457), height: 1.4),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: onTap == null
                  ? const Color(0xFFBEB6A5)
                  : const Color(0xFF2F8F5B),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDD6C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF676457),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDD6C8)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF676457),
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDDD6C8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDDD6C8)),
        ),
      ),
    );
  }
}
