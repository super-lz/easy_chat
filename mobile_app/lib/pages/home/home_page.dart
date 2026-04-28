import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/chat_session_provider.dart';
import '../../route/route_paths.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final activeSession = _ActiveSessionViewData.select(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EasyChat',
                style: TextStyle(
                  color: Color(0xFF151B26),
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '扫描网页上的二维码，在手机和电脑之间建立本地直连',
                style: TextStyle(
                  color: Color(0xFF8B95A1),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              if (activeSession.hasCachedConnection) ...[
                _EntryCard(
                  icon: Icons.chat_bubble_rounded,
                  iconBackground: const Color(0xFFE8FBF1),
                  iconColor: const Color(0xFF2F9E67),
                  title: '当前会话',
                  subtitle: activeSession.subtitle,
                  onTap: () => context.go(RoutePaths.chat),
                ),
                const SizedBox(height: 12),
              ],
              _EntryCard(
                icon: Icons.history_rounded,
                iconBackground: const Color(0xFFE8F4FB),
                iconColor: const Color(0xFF169AF3),
                title: '聊天记录',
                subtitle: '查看已经缓存到本机的历史会话和文件',
                onTap: () => context.push(RoutePaths.history),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(RoutePaths.scan),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF169AF3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    '扫码',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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

class _ActiveSessionViewData {
  const _ActiveSessionViewData({
    required this.hasCachedConnection,
    required this.subtitle,
  });

  final bool hasCachedConnection;
  final String subtitle;

  static _ActiveSessionViewData select(BuildContext context) {
    return context.select<ChatSessionProvider, _ActiveSessionViewData>(
      (provider) => _ActiveSessionViewData(
        hasCachedConnection: provider.hasCachedConnection,
        subtitle: _buildSubtitle(provider),
      ),
    );
  }

  static String _buildSubtitle(ChatSessionProvider provider) {
    final target = _resolveTargetName(provider);
    final status = provider.serverStatus.trim();
    if (status.isEmpty) {
      return target;
    }
    return '$target · $status';
  }

  static String _resolveTargetName(ChatSessionProvider provider) {
    final deviceInfo = provider.browserPeerDeviceInfo.trim();
    if (deviceInfo.isNotEmpty && deviceInfo != '等待浏览器同步') {
      return deviceInfo;
    }

    final browserName = provider.browserPeerName.trim();
    if (browserName.isNotEmpty && browserName != '等待浏览器同步') {
      return browserName;
    }

    return '等待目标设备同步';
  }

  @override
  bool operator ==(Object other) {
    return other is _ActiveSessionViewData &&
        other.hasCachedConnection == hasCachedConnection &&
        other.subtitle == subtitle;
  }

  @override
  int get hashCode => Object.hash(hasCachedConnection, subtitle);
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF151B26),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8B95A1),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF93A0AE),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
