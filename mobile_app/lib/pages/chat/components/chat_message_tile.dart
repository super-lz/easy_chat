import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/chat_message.dart';

sealed class ChatRenderItem {
  const ChatRenderItem();
}

class ChatSingleItem extends ChatRenderItem {
  const ChatSingleItem(this.message);

  final ChatMessage message;
}

class ChatGroupItem extends ChatRenderItem {
  const ChatGroupItem({
    required this.groupId,
    required this.sender,
    required this.files,
    required this.texts,
  });

  final String groupId;
  final String sender;
  final List<ChatMessage> files;
  final List<ChatMessage> texts;
}

List<ChatRenderItem> buildChatRenderItems(List<ChatMessage> messages) {
  final items = <ChatRenderItem>[];

  for (final message in messages) {
    final groupingKey =
        message.compositionId ??
        (message.type == 'file' && message.batchId != null
            ? 'batch:${message.batchId}'
            : null);
    final lastItem = items.isEmpty ? null : items.last;

    if (groupingKey != null &&
        lastItem is ChatGroupItem &&
        lastItem.groupId == groupingKey &&
        lastItem.sender == message.sender) {
      if (message.type == 'file') {
        lastItem.files.add(message);
      } else {
        lastItem.texts.add(message);
      }
      continue;
    }

    if (groupingKey != null) {
      items.add(
        ChatGroupItem(
          groupId: groupingKey,
          sender: message.sender,
          files: message.type == 'file' ? [message] : <ChatMessage>[],
          texts: message.type == 'text' ? [message] : <ChatMessage>[],
        ),
      );
      continue;
    }

    items.add(ChatSingleItem(message));
  }

  return items;
}

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({super.key, required this.item});

  final ChatRenderItem item;

  @override
  Widget build(BuildContext context) {
    final singleItem = item is ChatSingleItem ? item as ChatSingleItem : null;
    final groupItem = item is ChatGroupItem ? item as ChatGroupItem : null;

    if (singleItem != null && singleItem.message.isSystem) {
      final message = singleItem.message;
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDCE4EF)),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Color(0xFF75849A),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final sender = singleItem?.message.sender ?? groupItem!.sender;
    final isPhone = sender == 'phone';
    final texts = singleItem != null
        ? (singleItem.message.type == 'text'
              ? [singleItem.message]
              : <ChatMessage>[])
        : groupItem!.texts;
    final files = singleItem != null
        ? (singleItem.message.type == 'file'
              ? [singleItem.message]
              : <ChatMessage>[])
        : groupItem!.files;
    final bubbleMaxWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.78,
      320.0,
    );

    return Align(
      alignment: isPhone ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isPhone
                ? const Color(0xFF1E293B)
                : Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(22),
            border: isPhone ? null : Border.all(color: const Color(0xFFD9E1EC)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF41506A).withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (files.isNotEmpty) ...[
                  if (files.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${files.length} 个文件',
                        style: TextStyle(
                          color: isPhone
                              ? Colors.white70
                              : const Color(0xFF607086),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ...[
                    for (var index = 0; index < files.length; index++) ...[
                      _FileCard(message: files[index], isPhone: isPhone),
                      if (index != files.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ],
                if (files.isNotEmpty && texts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      height: 1,
                      color: isPhone
                          ? Colors.white.withValues(alpha: 0.14)
                          : const Color(0xFFE4EAF3),
                    ),
                  ),
                if (texts.isNotEmpty)
                  Text(
                    texts.map((message) => message.text).join('\n'),
                    style: TextStyle(
                      color: isPhone ? Colors.white : const Color(0xFF1C2530),
                      fontSize: 16,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
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

class _FileCard extends StatelessWidget {
  const _FileCard({required this.message, required this.isPhone});

  final ChatMessage message;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    final isImage = message.mimeType?.startsWith('image/') ?? false;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: isPhone
            ? Colors.white.withValues(alpha: 0.09)
            : const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPhone
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFDCE4EF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage && message.bytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                message.bytes!,
                height: 156,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!isImage || message.bytes == null)
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isPhone
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _fileKindLabel(message.text),
                    style: TextStyle(
                      color: isPhone ? Colors.white : const Color(0xFF445368),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPhone ? Colors.white : const Color(0xFF1C2530),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              message.text,
              style: TextStyle(
                color: isPhone ? Colors.white : const Color(0xFF1C2530),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (message.meta != null) ...[
            const SizedBox(height: 6),
            Text(
              message.meta!,
              style: TextStyle(
                color: isPhone ? Colors.white70 : const Color(0xFF6D7A8D),
                fontSize: 11.5,
              ),
            ),
          ],
          if (message.savedPath != null) ...[
            const SizedBox(height: 4),
            Text(
              message.savedPath!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPhone ? Colors.white60 : const Color(0xFF8A97A8),
                fontSize: 10.5,
              ),
            ),
          ],
          if (message.progress != null && message.progress! < 1) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: message.progress,
                minHeight: 6,
                backgroundColor: isPhone
                    ? Colors.white.withValues(alpha: 0.14)
                    : const Color(0xFFDCE4F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPhone ? Colors.white : const Color(0xFF2C3C52),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _fileKindLabel(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1
      ? 'FILE'
      : fileName.substring(dot + 1).toUpperCase();
  return extension.substring(0, math.min(extension.length, 4));
}
