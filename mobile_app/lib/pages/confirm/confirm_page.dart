import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/common_widgets.dart';
import '../../provider/chat_session_pprovider.dart';
import '../../route/route_paths.dart';
import '../../utils/network_tools.dart';

class ConfirmPage extends StatelessWidget {
  const ConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionPProvider>();
    final pairingPayload = provider.pairingPayload;
    final subnetWarning = NetworkTools.buildSubnetWarning(
      pairingPayload?.serverUrl,
      provider.ipController.text.trim(),
    );

    return PopScope(
      canPop: !provider.isRegistering,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !context.mounted) return;
        final shouldAbort = await _confirmAbort(context, provider);
        if (!context.mounted || !shouldAbort) return;
        await provider.abortConnecting();
        if (!context.mounted) return;
        _leavePage(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartisanTag(text: '连接信息'),
                const SizedBox(height: 24),
                const Text(
                  '确认本机直连地址',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 14),
                InfoTile(
                  label: '会话',
                  value: pairingPayload?.sessionId ?? '不可用',
                ),
                const SizedBox(height: 12),
                InfoTile(
                  label: '电脑地址',
                  value: pairingPayload?.serverUrl ?? '不可用',
                ),
                const SizedBox(height: 12),
                InfoTile(label: '当前状态', value: provider.serverStatus),
                const SizedBox(height: 16),
                LabeledField(label: '设备名称', controller: provider.deviceController),
                const SizedBox(height: 12),
                LabeledField(label: '本机 IP', controller: provider.ipController),
                if (subnetWarning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subnetWarning,
                    style: const TextStyle(
                      color: Color(0xFFB84C3A),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                LabeledField(label: '本机端口', controller: provider.portController),
                if (provider.registrationError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    provider.registrationError!,
                    style: const TextStyle(color: Color(0xFFB84C3A)),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => unawaited(_handleBack(context, provider)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(provider.isRegistering ? '中断连接' : '返回扫码'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        onPressed: provider.isRegistering
                            ? null
                            : () => unawaited(_approve(context)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1D1D1F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(provider.isRegistering ? '连接中…' : '进入聊天'),
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

  Future<void> _approve(BuildContext context) async {
    final success = await context.read<ChatSessionPProvider>().registerPhone();
    if (!context.mounted) return;
    if (success) {
      context.go(RoutePaths.chat);
    }
  }

  Future<void> _handleBack(
    BuildContext context,
    ChatSessionPProvider provider,
  ) async {
    if (!provider.isRegistering) {
      _leavePage(context);
      return;
    }

    final shouldAbort = await _confirmAbort(context, provider);
    if (!context.mounted || !shouldAbort) return;
    await provider.abortConnecting();
    if (!context.mounted) return;
    _leavePage(context);
  }

  Future<bool> _confirmAbort(
    BuildContext context,
    ChatSessionPProvider provider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('中断连接'),
          content: Text(
            provider.isRegistering ? '当前正在连接中，确定要中断并返回上一页吗' : '确定返回上一页吗',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('继续等待'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('中断返回'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _leavePage(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.scan);
  }
}
