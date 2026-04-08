import 'package:flutter/material.dart';

import '../chat_colors.dart';
import '../../../models/pending_attachment.dart';
import '../../../provider/chat_session_provider.dart';

class ChatComposerPendingAttachmentsRow extends StatelessWidget {
  const ChatComposerPendingAttachmentsRow({super.key, required this.provider});

  final ChatSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: ChatColors.pendingBarBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '已选 ${provider.pendingAttachments.length} 个文件',
                style: const TextStyle(
                  color: ChatColors.pendingBarTitle,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: provider.clearPendingAttachments,
                style: TextButton.styleFrom(
                  foregroundColor: ChatColors.pendingBarClear,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('清空'),
              ),
            ],
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: provider.pendingAttachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final attachment = provider.pendingAttachments[index];
                return _PendingAttachmentCard(
                  attachment: attachment,
                  onRemove: () =>
                      provider.removePendingAttachment(attachment.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentCard extends StatelessWidget {
  const _PendingAttachmentCard({
    required this.attachment,
    required this.onRemove,
  });

  final PendingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Stack(
        children: [
          Container(
            width: 160,
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            decoration: BoxDecoration(
              color: ChatColors.pendingCardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (attachment.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      attachment.bytes,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ChatColors.pendingCardFileTypeBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _fileKindLabel(attachment.name),
                      style: const TextStyle(
                        color: ChatColors.pendingCardFileTypeText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ChatColors.pendingCardFileName,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatAttachmentSize(attachment.size),
                        style: const TextStyle(
                          color: ChatColors.pendingCardFileMeta,
                          fontSize: 11,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: ChatColors.pendingCardRemoveBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAttachmentSize(int size) {
  if (size >= 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (size >= 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }
  return '$size B';
}

String _fileKindLabel(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1
      ? 'FILE'
      : fileName.substring(dot + 1).toUpperCase();
  return extension.substring(0, extension.length > 4 ? 4 : extension.length);
}
