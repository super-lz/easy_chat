import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat_colors.dart';
import '../file_preview_page.dart';
import '../../../models/chat_message.dart';
import '../../../provider/chat_session_provider.dart';
import '../../../utils/app_error_formatter.dart';

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
            color: ChatColors.systemBubbleBackground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: ChatColors.systemBubbleText,
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
                ? ChatColors.outgoingBubbleBackground
                : ChatColors.incomingBubbleBackground,
            borderRadius: BorderRadius.circular(22),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${files.length} 个文件',
                              style: TextStyle(
                                color: isPhone
                                    ? ChatColors.outgoingMetaText
                                    : ChatColors.incomingMetaText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _BatchSaveActionsButton(files: files),
                        ],
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
                          ? ChatColors.outgoingDivider
                          : ChatColors.incomingDivider,
                    ),
                  ),
                if (texts.isNotEmpty)
                  Text(
                    texts.map((message) => message.text).join('\n'),
                    style: TextStyle(
                      color: isPhone ? Colors.white : ChatColors.messageText,
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

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FilePreviewPage(message: message),
          ),
        );
      },
      onLongPress: () => _showSingleFileActions(context, message),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: isPhone
              ? ChatColors.outgoingFileCardBackground
              : ChatColors.incomingFileCardBackground,
          borderRadius: BorderRadius.circular(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isPhone
                        ? ChatColors.outgoingFileTypeBackground
                        : ChatColors.incomingFileTypeBackground,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _fileKindLabel(message.text),
                    style: TextStyle(
                      color: isPhone
                          ? Colors.white
                          : ChatColors.incomingFileTypeText,
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
                      color: isPhone ? Colors.white : ChatColors.messageText,
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
                color: isPhone ? Colors.white : ChatColors.messageText,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (message.meta != null) ...[
            const SizedBox(height: 6),
            Text(
              message.meta!,
              style: TextStyle(
                color: isPhone
                    ? ChatColors.outgoingMetaText
                    : ChatColors.incomingMetaText,
                fontSize: 11.5,
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
                    ? ChatColors.outgoingProgressBackground
                    : ChatColors.incomingProgressBackground,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPhone
                      ? ChatColors.outgoingProgressValue
                      : ChatColors.incomingProgressValue,
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }
}

class _BatchSaveActionsButton extends StatelessWidget {
  const _BatchSaveActionsButton({required this.files});

  final List<ChatMessage> files;

  @override
  Widget build(BuildContext context) {
    return _ActionMenuButton.batch(files: files);
  }
}

class _ActionMenuButton extends StatelessWidget {
  const _ActionMenuButton.batch({required this.files})
    : message = null;

  final ChatMessage? message;
  final List<ChatMessage>? files;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openActions(context),
        child: Ink(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            size: 18,
            color: ChatColors.messageText,
          ),
        ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    final provider = context.read<ChatSessionProvider>();
    final targetFiles = files ?? [message!];
    final allGalleryAssets = targetFiles.every(_isGallerySavable);

    Future<void> runAction(Future<String> Function() action) async {
      Navigator.of(context).pop();
      _showActionFeedback(context, '正在处理文件…');
      try {
        final result = await action();
        if (!context.mounted) return;
        _showActionFeedback(context, result, isError: false);
      } catch (error) {
        if (!context.mounted) return;
        _showActionFeedback(
          context,
          AppErrorFormatter.message(error),
          isError: true,
        );
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: ChatColors.headerOverlayBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2D8E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  targetFiles.length == 1 ? targetFiles.first.text : '文件操作',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ChatColors.headerTitle,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  targetFiles.length == 1
                      ? '选择你希望的保存方式'
                      : '共 ${targetFiles.length} 个文件，选择导出方式',
                  style: const TextStyle(
                    color: ChatColors.headerMetaLabel,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                if (allGalleryAssets)
                  _SheetActionTile(
                    icon: Icons.photo_library_outlined,
                    title: targetFiles.length == 1 ? '保存到相册' : '全部保存到相册',
                    subtitle: targetFiles.length == 1 ? '适用于图片和视频' : '将图片和视频批量保存到系统相册',
                    onTap: () => runAction(
                      () => targetFiles.length == 1
                          ? provider.saveFileMessageToGallery(targetFiles.first)
                          : provider.saveFileMessagesToGallery(targetFiles),
                    ),
                  ),
                _SheetActionTile(
                  icon: Icons.folder_open_rounded,
                  title: targetFiles.length == 1 ? '另存为' : '批量保存到文件夹',
                  subtitle: targetFiles.length == 1 ? '选择一个你方便访问的位置' : '选择目录后逐个导出文件',
                  onTap: () => runAction(
                    () => targetFiles.length == 1
                        ? provider.exportFileMessage(targetFiles.first)
                        : provider.exportFileMessages(targetFiles),
                  ),
                ),
                if (targetFiles.length > 1)
                  _SheetActionTile(
                    icon: Icons.archive_outlined,
                    title: '压缩保存',
                    subtitle: '打包成一个 ZIP 文件后再导出',
                    onTap: () => runAction(() => provider.saveFileMessagesAsZip(targetFiles)),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showSingleFileActions(BuildContext context, ChatMessage message) async {
  final provider = context.read<ChatSessionProvider>();
  final isGalleryAsset = _isGallerySavable(message);

  Future<void> runAction(Future<String> Function() action) async {
    Navigator.of(context).pop();
    _showActionFeedback(context, '正在处理文件…');
    try {
      final result = await action();
      if (!context.mounted) return;
      _showActionFeedback(context, result, isError: false);
    } catch (error) {
      if (!context.mounted) return;
      _showActionFeedback(
        context,
        AppErrorFormatter.message(error),
        isError: true,
      );
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        decoration: const BoxDecoration(
          color: ChatColors.headerOverlayBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2D8E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ChatColors.headerTitle,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '选择你希望的操作方式',
                style: TextStyle(
                  color: ChatColors.headerMetaLabel,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              _SheetActionTile(
                icon: Icons.ios_share_rounded,
                title: '分享文件',
                subtitle: '发送到其他 App 或系统分享面板',
                onTap: () => runAction(() => provider.shareFileMessage(message)),
              ),
              if (isGalleryAsset)
                _SheetActionTile(
                  icon: Icons.photo_library_outlined,
                  title: '保存到相册',
                  subtitle: '适用于图片和视频',
                  onTap: () => runAction(() => provider.saveFileMessageToGallery(message)),
                ),
              _SheetActionTile(
                icon: Icons.folder_open_rounded,
                title: '另存为',
                subtitle: '选择一个你方便访问的位置',
                onTap: () => runAction(() => provider.exportFileMessage(message)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

bool _isGallerySavable(ChatMessage message) {
  final mimeType = message.mimeType ?? '';
  return mimeType.startsWith('image/') || mimeType.startsWith('video/');
}

void _showActionFeedback(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: isError ? const Color(0xFF7B4C42) : const Color(0xFF22313F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(milliseconds: isError ? 2800 : 1800),
      ),
    );
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: ChatColors.messageText, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ChatColors.headerTitle,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ChatColors.headerMetaLabel,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ChatColors.headerMetaLabel,
                ),
              ],
            ),
          ),
        ),
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
