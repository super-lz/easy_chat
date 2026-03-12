import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/chat_session_pprovider.dart';
import '../../route/route_paths.dart';
import 'components/chat_header_section.dart';
import 'components/chat_message_tile.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionPProvider>();

    if (!provider.hasCachedConnection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(RoutePaths.scan);
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ChatHeaderSection(
              deviceName: provider.deviceName,
              serverStatus: provider.serverStatus,
              token: provider.directToken,
              onDisconnect: () => _disconnect(context),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF7F6F3), Color(0xFFF0EEEA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  itemBuilder: (context, index) {
                    final message = provider.messages[index];
                    return ChatMessageTile(message: message);
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemCount: provider.messages.length,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => unawaited(provider.pickAndSendFile()),
                    icon: const Icon(Icons.attach_file_rounded),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: provider.messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFDEDAD2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFDEDAD2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => unawaited(provider.sendDraft()),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1D1D1F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    child: const Text('发送'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context) async {
    await context.read<ChatSessionPProvider>().disconnectAndClear();
    if (!context.mounted) return;
    context.go(RoutePaths.scan);
  }
}
