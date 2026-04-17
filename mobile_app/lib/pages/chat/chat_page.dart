import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../provider/chat_session_provider.dart';
import '../../route/route_paths.dart';
import 'chat_colors.dart';
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ChatColors.pageBackground,
      body: Column(
        children: [
          ChatHeaderSection(
            deviceName: viewData.targetDeviceName,
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
                _HeaderOverlay(
                  isVisible: _isHeaderExpanded,
                  deviceName: viewData.deviceName,
                  browserName: viewData.browserPeerName,
                  browserDeviceInfo: viewData.browserPeerDeviceInfo,
                  serverStatus: viewData.serverStatus,
                  onDismiss: _collapseHeader,
                  onDisconnect: () => _confirmAndDisconnect(context),
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

  Future<void> _confirmAndDisconnect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: ChatColors.overlayMask,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: ChatColors.confirmDialogBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '断开连接？',
                  style: TextStyle(
                    color: ChatColors.confirmDialogTitle,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '断开后将清空当前直连状态，并返回扫码页重新建立连接',
                  style: TextStyle(
                    color: ChatColors.confirmDialogText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              ChatColors.confirmDialogCancelForeground,
                          side: BorderSide.none,
                          elevation: 0,
                          backgroundColor:
                              ChatColors.confirmDialogCancelBackground,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                              ChatColors.confirmDialogConfirmBackground,
                          foregroundColor:
                              ChatColors.confirmDialogConfirmForeground,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('断开'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    await _disconnect(context);
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
}

class _HeaderOverlay extends StatelessWidget {
  const _HeaderOverlay({
    required this.isVisible,
    required this.deviceName,
    required this.browserName,
    required this.browserDeviceInfo,
    required this.serverStatus,
    required this.onDismiss,
    required this.onDisconnect,
  });

  final bool isVisible;
  final String deviceName;
  final String browserName;
  final String browserDeviceInfo;
  final String serverStatus;
  final VoidCallback onDismiss;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !isVisible,
        child: GestureDetector(
          onTap: onDismiss,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: isVisible ? 1 : 0,
            child: ColoredBox(
              color: ChatColors.overlayMask,
              child: Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    offset: isVisible ? Offset.zero : const Offset(0, -0.08),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity: isVisible ? 1 : 0,
                      child: ChatHeaderOverlayPanel(
                        deviceName: deviceName,
                        browserName: browserName,
                        browserDeviceInfo: browserDeviceInfo,
                        serverStatus: serverStatus,
                        onDisconnect: onDisconnect,
                      ),
                    ),
                  ),
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
    required this.targetDeviceName,
    required this.serverStatus,
    required this.browserPeerName,
    required this.browserPeerDeviceInfo,
  });

  final bool hasCachedConnection;
  final List<ChatMessage> messages;
  final String deviceName;
  final String targetDeviceName;
  final String serverStatus;
  final String browserPeerName;
  final String browserPeerDeviceInfo;

  static _ChatPageViewData select(BuildContext context) {
    return context.select<ChatSessionProvider, _ChatPageViewData>(
      (provider) => _ChatPageViewData(
        hasCachedConnection: provider.hasCachedConnection,
        messages: provider.messages,
        deviceName: provider.deviceName,
        targetDeviceName: _resolveTargetDeviceName(provider),
        serverStatus: provider.serverStatus,
        browserPeerName: provider.browserPeerName,
        browserPeerDeviceInfo: provider.browserPeerDeviceInfo,
      ),
    );
  }

  static String _resolveTargetDeviceName(ChatSessionProvider provider) {
    final browserDeviceInfo = provider.browserPeerDeviceInfo.trim();
    if (browserDeviceInfo.isNotEmpty && browserDeviceInfo != '等待浏览器同步') {
      return browserDeviceInfo;
    }

    final browserName = provider.browserPeerName.trim();
    if (browserName.isNotEmpty && browserName != '等待浏览器同步') {
      return browserName;
    }

    return '等待目标设备同步';
  }

  @override
  bool operator ==(Object other) {
    return other is _ChatPageViewData &&
        other.hasCachedConnection == hasCachedConnection &&
        identical(other.messages, messages) &&
        other.deviceName == deviceName &&
        other.targetDeviceName == targetDeviceName &&
        other.serverStatus == serverStatus &&
        other.browserPeerName == browserPeerName &&
        other.browserPeerDeviceInfo == browserPeerDeviceInfo;
  }

  @override
  int get hashCode => Object.hash(
    hasCachedConnection,
    messages,
    deviceName,
    targetDeviceName,
    serverStatus,
    browserPeerName,
    browserPeerDeviceInfo,
  );
}
