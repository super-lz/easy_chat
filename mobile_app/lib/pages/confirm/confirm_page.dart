import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/pairing_payload.dart';
import '../../provider/chat_session_provider.dart';
import '../../route/route_paths.dart';

class ConfirmPage extends StatelessWidget {
  const ConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionProvider>();
    final pairingPayload = provider.pairingPayload;
    final targetDevice = _targetDeviceLabel(pairingPayload);
    final targetBrowser = _targetBrowserLabel(pairingPayload);
    final verificationCode = _verificationCodeLabel(pairingPayload);
    final targetCaption = _targetClientCaption(pairingPayload?.serverUrl);

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
        backgroundColor: const Color(0xFFF3F4F7),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ConfirmHeader(
                        onBack: () => unawaited(_handleBack(context, provider)),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '确认连接',
                        style: TextStyle(
                          color: Color(0xFF151B26),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '确认当前手机与目标客户端无误后继续',
                        style: TextStyle(
                          color: Color(0xFF8B95A1),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ConfirmInfoCard(
                        title: '本端信息',
                        value: provider.deviceName,
                        caption: '当前手机',
                      ),
                      const SizedBox(height: 12),
                      _ConfirmInfoCard(
                        title: '目标设备',
                        value: targetDevice,
                        caption: targetCaption,
                      ),
                      const SizedBox(height: 12),
                      _ConfirmInfoCard(
                        title: '浏览器',
                        value: targetBrowser,
                        caption: '来自网页端识别信息',
                      ),
                      const SizedBox(height: 12),
                      _ConfirmInfoCard(
                        title: '识别码',
                        value: verificationCode,
                        caption: '请和电脑上的二维码页核对',
                      ),
                      if (provider.registrationError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4F1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            provider.registrationError!,
                            style: const TextStyle(
                              color: Color(0xFFBE715D),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                color: const Color(0xFFF7F8FA),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            unawaited(_handleBack(context, provider)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5B6470),
                          side: BorderSide.none,
                          elevation: 0,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(provider.isRegistering ? '中断' : '返回'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: provider.isRegistering
                            ? null
                            : () => unawaited(_approve(context)),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF169AF3),
                          disabledBackgroundColor: const Color(0xFF8FD3FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(provider.isRegistering ? '连接中' : '确认连接'),
                      ),
                    ),
                  ],
                ),
              ),
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
      barrierColor: const Color(0x3D101828),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '中断连接？',
                  style: TextStyle(
                    color: Color(0xFF151B26),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  provider.isRegistering ? '当前正在连接中，确定要中断并返回' : '确定返回上一页',
                  style: const TextStyle(
                    color: Color(0xFF66717D),
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
                          foregroundColor: const Color(0xFF5B6470),
                          side: BorderSide.none,
                          elevation: 0,
                          backgroundColor: const Color(0xFFF3F5F7),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('继续'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF169AF3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('中断'),
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

class _ConfirmHeader extends StatelessWidget {
  const _ConfirmHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(
            minimumSize: const Size(42, 42),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF314054),
            elevation: 0,
            side: BorderSide.none,
          ),
        ),
      ],
    );
  }
}

class _ConfirmInfoCard extends StatelessWidget {
  const _ConfirmInfoCard({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8B95A1),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF151B26),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
              color: Color(0xFFA1A9B3),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

String _targetDeviceLabel(PairingPayload? pairingPayload) {
  final deviceInfo = pairingPayload?.deviceInfo?.trim();
  if (deviceInfo != null && deviceInfo.isNotEmpty) {
    return deviceInfo;
  }

  final serverUrl = pairingPayload?.serverUrl;
  if (serverUrl == null || serverUrl.isEmpty) {
    return '当前设备';
  }

  final uri = Uri.tryParse(serverUrl);
  if (uri == null) {
    return '当前设备';
  }

  return uri.host.isEmpty ? '当前设备' : uri.host;
}

String _targetBrowserLabel(PairingPayload? pairingPayload) {
  final browserName = pairingPayload?.browserName?.trim();
  if (browserName != null && browserName.isNotEmpty) {
    return browserName;
  }
  return '当前浏览器';
}

String _verificationCodeLabel(PairingPayload? pairingPayload) {
  final verificationCode = pairingPayload?.verificationCode?.trim();
  if (verificationCode != null && verificationCode.isNotEmpty) {
    return verificationCode;
  }
  return '----';
}

String _targetClientCaption(String? serverUrl) {
  if (serverUrl == null || serverUrl.isEmpty) {
    return '来自网页二维码';
  }

  final uri = Uri.tryParse(serverUrl);
  if (uri == null || uri.host.isEmpty) {
    return '来自网页二维码';
  }

  final port = uri.hasPort ? ':${uri.port}' : '';
  return '网页地址 ${uri.host}$port';
}
