import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../common/app_constants.dart';
import '../../components/common_widgets.dart';
import '../../provider/chat_session_pprovider.dart';
import '../../route/route_paths.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionPProvider>();

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
                const SmartisanTag(text: AppConstants.appName),
                const SizedBox(height: 20),
                Text(
                  '同一 Wi‑Fi，\n直接传输。',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                    color: const Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '扫码建立连接后，消息和文件会直接在手机与电脑之间传输。',
                  style: TextStyle(
                    color: Color(0xFF6C675E),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SmartisanFeatureCard(
                  title: provider.hasCachedConnection ? '恢复连接' : '连接电脑',
                  subtitle: provider.hasCachedConnection
                      ? '继续使用上次的本地直连配置。'
                      : '扫描网页二维码，建立本地直连。',
                  actionLabel: provider.hasCachedConnection ? '继续' : '开始',
                  onTap: provider.hasCachedConnection
                      ? () => unawaited(_resume(context))
                      : () => context.push(RoutePaths.scan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resume(BuildContext context) async {
    final restored = await context.read<ChatSessionPProvider>().restoreConnectionIfNeeded();
    if (!context.mounted) return;
    if (restored) {
      context.go(RoutePaths.chat);
      return;
    }
    context.go(RoutePaths.scan);
  }
}
