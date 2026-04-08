import 'package:flutter/material.dart';

import '../chat_colors.dart';

class ChatHeaderSection extends StatelessWidget {
  const ChatHeaderSection({
    super.key,
    required this.deviceName,
    required this.serverStatus,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final String deviceName;
  final String serverStatus;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(serverStatus);
    return DecoratedBox(
      decoration: const BoxDecoration(color: ChatColors.headerBackground),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          deviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ChatColors.headerTitle,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusTag(presentation: status),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onToggleExpanded,
                  icon: AnimatedRotation(
                    duration: const Duration(milliseconds: 160),
                    turns: isExpanded ? 0.5 : 0,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(42, 42),
                    backgroundColor: ChatColors.headerExpandButtonBackground,
                    foregroundColor: ChatColors.headerExpandButtonForeground,
                    side: BorderSide.none,
                    elevation: 0,
                  ),
                  tooltip: isExpanded ? '收起详情' : '展开详情',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatHeaderOverlayPanel extends StatelessWidget {
  const ChatHeaderOverlayPanel({
    super.key,
    required this.deviceName,
    required this.browserName,
    required this.browserDeviceInfo,
    required this.phoneAddress,
    required this.browserAddress,
    required this.serverStatus,
    required this.onDisconnect,
  });

  final String deviceName;
  final String browserName;
  final String browserDeviceInfo;
  final String phoneAddress;
  final String browserAddress;
  final String serverStatus;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(serverStatus);
    final warningText = _statusWarning(status.kind);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: ChatColors.headerOverlayBackground,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - 140,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(label: '手机', value: deviceName),
              _InfoRow(label: '浏览器设备', value: browserDeviceInfo),
              _InfoRow(label: '浏览器', value: browserName),
              _InfoRow(
                label: '手机地址',
                value: phoneAddress,
                compactValue: true,
                multilineValue: true,
              ),
              _InfoRow(
                label: '浏览器地址',
                value: browserAddress,
                compactValue: true,
                multilineValue: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Text(
                      '状态',
                      style: TextStyle(
                        color: ChatColors.headerSectionLabel,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    _StatusTag(presentation: status),
                  ],
                ),
              ),
              if (warningText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _WarningBlock(text: warningText),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onDisconnect,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ChatColors.headerActionForeground,
                      side: BorderSide.none,
                      elevation: 0,
                      backgroundColor: ChatColors.headerActionBackground,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('断开连接'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.compactValue = false,
    this.multilineValue = false,
  });

  final String label;
  final String value;
  final bool compactValue;
  final bool multilineValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: multilineValue
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ChatColors.headerMetaLabel,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: multilineValue ? 2 : 1,
                softWrap: multilineValue,
                overflow: multilineValue
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: ChatColors.headerMetaValue,
                  fontSize: compactValue ? 15.5 : 17.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: compactValue ? 0 : 0.2,
                  height: compactValue ? 1.25 : 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.presentation});

  final _StatusPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: presentation.dot,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            presentation.label,
            style: TextStyle(
              color: presentation.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBlock extends StatelessWidget {
  const _WarningBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: ChatColors.warningBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '错误',
            style: TextStyle(
              color: ChatColors.warningTitle,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: ChatColors.warningText,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StatusKind { connected, reconnecting, waiting, offline, unknown }

class _StatusPresentation {
  const _StatusPresentation({
    required this.kind,
    required this.label,
    required this.text,
    required this.dot,
    required this.background,
    required this.border,
  });

  final _StatusKind kind;
  final String label;
  final Color text;
  final Color dot;
  final Color background;
  final Color border;
}

_StatusPresentation _statusPresentation(String status) {
  if (status.contains('电脑已接入')) {
    return const _StatusPresentation(
      kind: _StatusKind.connected,
      label: '已连接',
      text: ChatColors.statusConnectedText,
      dot: ChatColors.statusConnectedDot,
      background: ChatColors.statusConnectedBackground,
      border: ChatColors.statusConnectedBackground,
    );
  }
  if (status.contains('等待电脑重连')) {
    return const _StatusPresentation(
      kind: _StatusKind.reconnecting,
      label: '重连中',
      text: ChatColors.statusReconnectingText,
      dot: ChatColors.statusReconnectingDot,
      background: ChatColors.statusReconnectingBackground,
      border: ChatColors.statusReconnectingBackground,
    );
  }
  if (status.contains('监听中')) {
    return const _StatusPresentation(
      kind: _StatusKind.waiting,
      label: '等待接入',
      text: ChatColors.statusWaitingText,
      dot: ChatColors.statusWaitingDot,
      background: ChatColors.statusWaitingBackground,
      border: ChatColors.statusWaitingBackground,
    );
  }
  if (status.contains('未启动')) {
    return const _StatusPresentation(
      kind: _StatusKind.offline,
      label: '未启动',
      text: ChatColors.statusOfflineText,
      dot: ChatColors.statusOfflineDot,
      background: ChatColors.statusOfflineBackground,
      border: ChatColors.statusOfflineBackground,
    );
  }

  return const _StatusPresentation(
    kind: _StatusKind.unknown,
    label: '状态未知',
    text: ChatColors.statusUnknownText,
    dot: ChatColors.statusUnknownDot,
    background: ChatColors.statusUnknownBackground,
    border: ChatColors.statusUnknownBackground,
  );
}

String? _statusWarning(_StatusKind kind) {
  return switch (kind) {
    _StatusKind.reconnecting => '连接已断开，重连中，请确保 App 保留在前台',
    _StatusKind.offline => '本地服务未启动，请返回重新建立直连',
    _StatusKind.waiting => '本地服务已启动，等待浏览器接入',
    _ => null,
  };
}
