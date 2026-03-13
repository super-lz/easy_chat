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

    return EasyChatPageScaffold(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SmartisanTag(text: AppConstants.appName),
            const SizedBox(height: 18),
            Text(
              '同一 Wi‑Fi\n直接传输',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontSize: 42, height: 0.98),
            ),
            const SizedBox(height: 14),
            const Text('页面体验以简洁、平静、可靠为先。扫码后消息与文件都直接在手机和电脑之间完成传输，不经过中转。'),
            const SizedBox(height: 26),
            const GlassSurface(
              radius: 30,
              padding: EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: _HomeHeroPanel(),
            ),
            const SizedBox(height: 16),
            SmartisanFeatureCard(
              title: provider.hasCachedConnection ? '恢复上次会话' : '开始连接电脑',
              subtitle: provider.hasCachedConnection
                  ? '沿用上一次保存的局域网直连配置，直接回到聊天页。'
                  : '扫描网页上的二维码，建立手机与电脑之间的本地直连。',
              actionLabel: provider.hasCachedConnection ? '继续' : '开始',
              onTap: provider.hasCachedConnection
                  ? () => unawaited(_resume(context))
                  : () => context.push(RoutePaths.scan),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resume(BuildContext context) async {
    final restored = await context
        .read<ChatSessionPProvider>()
        .restoreConnectionIfNeeded();
    if (!context.mounted) return;
    if (restored) {
      context.go(RoutePaths.chat);
      return;
    }
    context.go(RoutePaths.scan);
  }
}

class _HomeHeroPanel extends StatelessWidget {
  const _HomeHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _SpecBadge(label: '局域网直连'),
            SizedBox(width: 8),
            _SpecBadge(label: '消息与文件'),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFFFDFEFF), Color(0xFFF3F7FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFD8E1EC)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 18,
                top: 22,
                child: _MiniSurface(
                  width: 108,
                  height: 126,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _MiniLine(width: 52),
                      SizedBox(height: 10),
                      _MiniBubble(),
                      SizedBox(height: 8),
                      _MiniBubble(isDark: true),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 32,
                child: _MiniSurface(
                  width: 140,
                  height: 110,
                  child: Column(
                    children: const [
                      _MiniLine(width: 90),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _MiniAttachment()),
                          SizedBox(width: 8),
                          Expanded(child: _MiniAttachment(isImage: true)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 24,
                bottom: 18,
                right: 24,
                child: Text(
                  '把 web 端的安静层次、轻描边和准拟物表面收进移动端，而不是做成另一套风格。',
                  style: TextStyle(color: Color(0xFF667589), height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecBadge extends StatelessWidget {
  const _SpecBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E0EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF607086),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniSurface extends StatelessWidget {
  const _MiniSurface({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E2ED)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF41506A).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF6),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _MiniBubble extends StatelessWidget {
  const _MiniBubble({this.isDark = false});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: isDark ? 56 : 64,
        height: 30,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF263344) : const Color(0xFFF2F6FB),
          borderRadius: BorderRadius.circular(14),
          border: isDark ? null : Border.all(color: const Color(0xFFD7E0EB)),
        ),
      ),
    );
  }
}

class _MiniAttachment extends StatelessWidget {
  const _MiniAttachment({this.isImage = false});

  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isImage ? const Color(0xFFD9E4F1) : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E0EB)),
      ),
    );
  }
}
