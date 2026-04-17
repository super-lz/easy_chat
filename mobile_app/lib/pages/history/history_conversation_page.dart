import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/chat_history_models.dart';
import '../../service/chat_history_store.dart';
import '../chat/chat_colors.dart';
import '../chat/components/chat_message_tile.dart';

class HistoryConversationPage extends StatefulWidget {
  const HistoryConversationPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<HistoryConversationPage> createState() =>
      _HistoryConversationPageState();
}

class _HistoryConversationPageState extends State<HistoryConversationPage> {
  late Future<ChatHistoryConversation?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ChatHistoryConversation?> _load() {
    return context.read<ChatHistoryStore>().loadConversation(
      widget.conversationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ChatColors.pageBackground,
      body: FutureBuilder<ChatHistoryConversation?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversation = snapshot.data;
          if (conversation == null) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(42, 42),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF314054),
                        elevation: 0,
                        side: BorderSide.none,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Center(
                        child: _HistoryConversationStateCard(
                          title: '会话不存在',
                          description: '这条聊天记录可能已经被清理，或还没有完成落盘。',
                          actionLabel: '返回',
                          onAction: () => context.pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final messages = conversation.messages
              .map((message) => message.toChatMessage())
              .toList(growable: false);
          final renderItems = buildChatRenderItems(messages).reversed.toList();

          return Column(
            children: [
              _HistoryHeader(summary: conversation.summary),
              Expanded(
                child: Stack(
                  children: [
                    ListView.separated(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                      itemBuilder: (context, index) {
                        return ChatMessageTile(item: renderItems[index]);
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemCount: renderItems.length,
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14 + MediaQuery.of(context).padding.bottom,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 18,
                                color: Color(0xFF607086),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '历史记录为只读模式，文件仍支持预览、分享和导出。',
                                  style: TextStyle(
                                    color: Color(0xFF607086),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.summary});

  final ChatHistoryConversationSummary summary;

  @override
  Widget build(BuildContext context) {
    final title = summary.title.trim().isEmpty ? '未命名会话' : summary.title.trim();
    final secondary = [
      if (summary.peerName?.trim().isNotEmpty == true) summary.peerName!.trim(),
      '${summary.messageCount} 条消息',
    ].join(' · ');

    return DecoratedBox(
      decoration: const BoxDecoration(color: ChatColors.headerBackground),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(42, 42),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF314054),
                    elevation: 0,
                    side: BorderSide.none,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ChatColors.headerTitle,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ChatColors.headerMetaLabel,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: ChatColors.statusWaitingBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: ChatColors.statusWaitingText,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '历史记录',
                        style: TextStyle(
                          color: ChatColors.statusWaitingText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryConversationStateCard extends StatelessWidget {
  const _HistoryConversationStateCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 34,
            color: Color(0xFF8B95A1),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF151B26),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8B95A1),
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF169AF3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
