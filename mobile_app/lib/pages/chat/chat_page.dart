import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../provider/chat_session_provider.dart';
import '../../route/route_paths.dart';
import 'components/chat_composer.dart';
import 'components/chat_header_section.dart';
import 'components/chat_message_tile.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isHeaderExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final viewData = _ChatPageViewData.select(context);

    _redirectToScannerIfDisconnected(viewData.hasCachedConnection);

    final renderItems = buildChatRenderItems(
      viewData.messages,
    ).reversed.toList();
    final phoneAddress = _buildPhoneAddress(provider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color.fromARGB(255, 244, 244, 244),
      body: Column(
        children: [
          ChatHeaderSection(
            deviceName: viewData.deviceName,
            serverStatus: viewData.serverStatus,
            isExpanded: _isHeaderExpanded,
            onToggleExpanded: _toggleHeaderExpanded,
          ),
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {},
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                          itemBuilder: (context, index) {
                            return ChatMessageTile(item: renderItems[index]);
                          },
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemCount: renderItems.length,
                        ),
                      ),
                      ChatComposer(provider: provider),
                    ],
                  ),
                ),
                if (_isHeaderExpanded)
                  _HeaderOverlay(
                    deviceName: viewData.deviceName,
                    browserName: viewData.browserPeerName,
                    phoneAddress: phoneAddress,
                    browserAddress: viewData.browserPeerAddress,
                    serverStatus: viewData.serverStatus,
                    onDismiss: _collapseHeader,
                    onDisconnect: () => _disconnect(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ChatSessionProvider get _provider {
    return context.read<ChatSessionProvider>();
  }

  Future<void> _disconnect(BuildContext context) async {
    await context.read<ChatSessionProvider>().disconnectAndClear();
    if (!context.mounted) return;
    context.go(RoutePaths.scan);
  }

  void _redirectToScannerIfDisconnected(bool hasCachedConnection) {
    if (hasCachedConnection) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.go(RoutePaths.scan);
      }
    });
  }

  void _toggleHeaderExpanded() {
    setState(() {
      _isHeaderExpanded = !_isHeaderExpanded;
    });
  }

  void _collapseHeader() {
    setState(() {
      _isHeaderExpanded = false;
    });
  }

  String _buildPhoneAddress(ChatSessionProvider provider) {
    final ip = provider.ipController.text.trim();
    final port = provider.portController.text.trim();
    if (ip.isEmpty || port.isEmpty) {
      return '未知';
    }
    return '$ip:$port';
  }
}

class _HeaderOverlay extends StatelessWidget {
  const _HeaderOverlay({
    required this.deviceName,
    required this.browserName,
    required this.phoneAddress,
    required this.browserAddress,
    required this.serverStatus,
    required this.onDismiss,
    required this.onDisconnect,
  });

  final String deviceName;
  final String browserName;
  final String phoneAddress;
  final String browserAddress;
  final String serverStatus;
  final VoidCallback onDismiss;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.08),
          child: Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ChatHeaderOverlayPanel(
                  deviceName: deviceName,
                  browserName: browserName,
                  phoneAddress: phoneAddress,
                  browserAddress: browserAddress,
                  serverStatus: serverStatus,
                  onDisconnect: onDisconnect,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatPageViewData {
  const _ChatPageViewData({
    required this.hasCachedConnection,
    required this.messages,
    required this.deviceName,
    required this.serverStatus,
    required this.browserPeerName,
    required this.browserPeerAddress,
  });

  final bool hasCachedConnection;
  final List<ChatMessage> messages;
  final String deviceName;
  final String serverStatus;
  final String browserPeerName;
  final String browserPeerAddress;

  static _ChatPageViewData select(BuildContext context) {
    return context.select<ChatSessionProvider, _ChatPageViewData>(
      (provider) => _ChatPageViewData(
        hasCachedConnection: provider.hasCachedConnection,
        messages: provider.messages,
        deviceName: provider.deviceName,
        serverStatus: provider.serverStatus,
        browserPeerName: provider.browserPeerName,
        browserPeerAddress: provider.browserPeerAddress,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ChatPageViewData &&
        other.hasCachedConnection == hasCachedConnection &&
        identical(other.messages, messages) &&
        other.deviceName == deviceName &&
        other.serverStatus == serverStatus &&
        other.browserPeerName == browserPeerName &&
        other.browserPeerAddress == browserPeerAddress;
  }

  @override
  int get hashCode => Object.hash(
    hasCachedConnection,
    messages,
    deviceName,
    serverStatus,
    browserPeerName,
    browserPeerAddress,
  );
}
