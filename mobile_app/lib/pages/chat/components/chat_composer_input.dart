import 'package:flutter/material.dart';

class ChatComposerInputShell extends StatelessWidget {
  const ChatComposerInputShell({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasEmojiPanel,
    required this.hasAttachmentPanel,
    required this.hasPendingAttachments,
    required this.onTapInput,
    required this.onTapEmoji,
    required this.onTapAttachment,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasEmojiPanel;
  final bool hasAttachmentPanel;
  final bool hasPendingAttachments;
  final VoidCallback onTapInput;
  final VoidCallback onTapEmoji;
  final VoidCallback onTapAttachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onTap: onTapInput,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hasPendingAttachments ? '继续输入文字，与文件一起发送' : '输入消息',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF98A4B5),
                  fontSize: 15,
                ),
              ),
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
          _ComposerTrailingButton(
            icon: Icons.mood_rounded,
            isActive: hasEmojiPanel,
            onPressed: onTapEmoji,
          ),
          _ComposerTrailingButton(
            icon: Icons.add_circle_outline_rounded,
            isActive: hasAttachmentPanel,
            onPressed: onTapAttachment,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ComposerTrailingButton extends StatelessWidget {
  const _ComposerTrailingButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? const Color(0xFF111827) : const Color(0xFF778397),
        size: 26,
      ),
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        splashFactory: NoSplash.splashFactory,
        backgroundColor: isActive
            ? const Color(0xFFE8EDF5)
            : Colors.transparent,
      ),
    );
  }
}
