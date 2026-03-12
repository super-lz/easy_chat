import 'package:flutter/material.dart';

import '../../../components/common_widgets.dart';

class ChatHeaderSection extends StatelessWidget {
  const ChatHeaderSection({
    super.key,
    required this.deviceName,
    required this.serverStatus,
    required this.token,
    required this.onDisconnect,
  });

  final String deviceName;
  final String serverStatus;
  final String? token;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onDisconnect,
                child: const Text('断开连接'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              InlineStatus(label: '本地服务', value: serverStatus),
              const SizedBox(height: 8),
              InlineStatus(label: '连接凭证', value: token ?? '不可用'),
            ],
          ),
        ),
      ],
    );
  }
}
