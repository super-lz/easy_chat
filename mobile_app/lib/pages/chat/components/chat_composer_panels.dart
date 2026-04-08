import 'package:flutter/material.dart';

import '../chat_colors.dart';

enum ChatComposerPanelType { none, attachments, emojis }

class ChatComposerPanelHost extends StatelessWidget {
  const ChatComposerPanelHost({
    super.key,
    required this.panelType,
    required this.onEmojiTap,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onFileTap,
  });

  final ChatComposerPanelType panelType;
  final ValueChanged<String> onEmojiTap;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onFileTap;

  @override
  Widget build(BuildContext context) {
    return switch (panelType) {
      ChatComposerPanelType.attachments => _ComposerAttachmentPanel(
        onCameraTap: onCameraTap,
        onGalleryTap: onGalleryTap,
        onFileTap: onFileTap,
      ),
      ChatComposerPanelType.emojis => _ComposerEmojiPanel(
        onEmojiTap: onEmojiTap,
      ),
      ChatComposerPanelType.none => const SizedBox.shrink(),
    };
  }
}

class _ComposerAttachmentPanel extends StatelessWidget {
  const _ComposerAttachmentPanel({
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onFileTap,
  });

  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onFileTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _ComposerActionButton(
              icon: Icons.camera_alt_rounded,
              label: '拍摄',
              tint: ChatColors.attachmentCameraTint,
              onTap: onCameraTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ComposerActionButton(
              icon: Icons.photo_library_rounded,
              label: '相册',
              tint: ChatColors.attachmentGalleryTint,
              onTap: onGalleryTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ComposerActionButton(
              icon: Icons.insert_drive_file_rounded,
              label: '文件',
              tint: ChatColors.attachmentFileTint,
              onTap: onFileTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerEmojiPanel extends StatelessWidget {
  static const List<String> _emojis = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥰',
    '😘',
    '🤔',
    '😎',
    '🥳',
    '😭',
    '😡',
    '😴',
    '🙌',
    '👏',
    '👍',
    '👎',
    '💪',
    '🙏',
    '🤝',
    '👀',
    '💯',
    '✅',
    '❌',
    '⌛',
    '🎉',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '💔',
    '💤',
    '💢',
    '❗',
    '❓',
    '🔥',
    '✨',
    '⭐',
    '🌈',
    '🌚',
    '🌝',
    '☀️',
    '⛅',
    '🌧️',
    '⛈️',
    '❄️',
    '🌊',
    '🍻',
    '☕',
    '🍵',
    '🥤',
    '🍕',
    '🍔',
    '🍟',
    '🍗',
    '🍉',
    '🍓',
    '🎮',
    '⚽',
    '🏀',
    '🎵',
    '🎬',
    '📷',
    '💻',
    '📱',
    '🚀',
    '🚗',
    '✈️',
    '🎁',
    '💰',
    '🐶',
    '🐱',
    '🐼',
    '🦊',
  ];

  const _ComposerEmojiPanel({required this.onEmojiTap});

  final ValueChanged<String> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 8,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: _emojis.length,
      itemBuilder: (context, index) {
        final emoji = _emojis[index];
        return InkWell(
          onTap: () => onEmojiTap(emoji),
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 28, height: 1)),
          ),
        );
      },
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 108,
        decoration: BoxDecoration(
          color: ChatColors.attachmentPanelCardBackground,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ChatColors.attachmentActionTintBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: tint),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: ChatColors.attachmentPanelCardText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
