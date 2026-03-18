import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/common_widgets.dart';
import '../../provider/chat_session_provider.dart';
import '../../route/route_paths.dart';
import '../../utils/network_tools.dart';

class ConfirmPage extends StatelessWidget {
  const ConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionProvider>();
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
      child: EasyChatPageScaffold(
        bottomBar: BottomActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => unawaited(_handleBack(context, provider)),
                  child: Text(provider.isRegistering ? '中断连接' : '返回扫码'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: provider.isRegistering
                      ? null
                      : () => unawaited(_approve(context)),
                  child: Text(provider.isRegistering ? '连接中…' : '进入聊天'),
                ),
              ),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '确认本机直连地址',
                subtitle: '建立局域网会话',
                leading: AppBackButton(
                  onPressed: () => unawaited(_handleBack(context, provider)),
                ),
              ),
              const GlassSurface(
                radius: 28,
                padding: EdgeInsets.all(20),
                child: _ConfirmIntro(),
              ),
              const SizedBox(height: 14),
              InfoTile(label: '会话', value: pairingPayload?.sessionId ?? '不可用'),
              const SizedBox(height: 12),
              InfoTile(
                label: '电脑地址',
                value: pairingPayload?.serverUrl ?? '不可用',
              ),
              const SizedBox(height: 12),
              InfoTile(label: '当前状态', value: provider.serverStatus),
              const SizedBox(height: 16),
              LabeledField(
                label: '设备名称',
                controller: provider.deviceController,
              ),
              const SizedBox(height: 12),
              LabeledField(label: '本机 IP', controller: provider.ipController),
              if (subnetWarning != null) ...[
                const SizedBox(height: 8),
                Text(
                  subnetWarning,
                  style: const TextStyle(
                    color: Color(0xFFBE715D),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LabeledField(label: '本机端口', controller: provider.portController),
              if (provider.registrationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  provider.registrationError!,
                  style: const TextStyle(color: Color(0xFFBE715D)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    final success = await context.read<ChatSessionProvider>().registerPhone();
    if (!context.mounted) return;
    if (success) {
      context.go(RoutePaths.chat);
    }
  }

  Future<void> _handleBack(
    BuildContext context,
    ChatSessionProvider provider,
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
    ChatSessionProvider provider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('中断连接'),
          content: Text(
            provider.isRegistering ? '当前正在连接中，确定要中断并返回上一页吗？' : '确定返回上一页吗？',
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

class _ConfirmIntro extends StatelessWidget {
  const _ConfirmIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '检查设备名称、局域网 IP 和端口是否正确。确认后手机会启动本地服务，并把可连接地址回传给 web 端。',
          style: TextStyle(color: Color(0xFF68778C), height: 1.55),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MiniStatus(label: '1', text: '校验配对信息'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MiniStatus(label: '2', text: '启动本地服务'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MiniStatus(label: '3', text: '进入聊天'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E0EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF253243),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF607086),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
