import 'package:flutter/material.dart';

import '../chat_colors.dart';

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
    final isPanelActive = hasEmojiPanel || hasAttachmentPanel;

    return Container(
      decoration: BoxDecoration(
        color: isPanelActive
            ? ChatColors.inputBackgroundActive
            : ChatColors.inputBackground,
        borderRadius: BorderRadius.circular(22),
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
                  vertical: 15,
                ),
                hintStyle: const TextStyle(
                  color: ChatColors.inputHint,
                  fontSize: 15,
                ),
              ),
              style: const TextStyle(
                color: ChatColors.inputText,
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
          _ComposerTrailingButton(
            icon: Icons.mood_rounded,
            isActive: hasEmojiPanel,
            activeColor: ChatColors.inputEmojiAction,
            idleColor: ChatColors.inputEmojiIdle,
            activeBackgroundColor: ChatColors.inputEmojiActionBackground,
            onPressed: onTapEmoji,
          ),
          _ComposerTrailingButton(
            icon: Icons.add_circle_outline_rounded,
            isActive: hasAttachmentPanel,
            activeColor: ChatColors.inputAttachmentAction,
            idleColor: ChatColors.inputAttachmentIdle,
            activeBackgroundColor: ChatColors.inputAttachmentActionBackground,
            onPressed: onTapAttachment,
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _ComposerTrailingButton extends StatelessWidget {
  const _ComposerTrailingButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.idleColor,
    required this.activeBackgroundColor,
    required this.onPressed,
  });

  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final Color idleColor;
  final Color activeBackgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: isActive ? activeColor : idleColor, size: 24),
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        splashFactory: NoSplash.splashFactory,
        backgroundColor: isActive ? activeBackgroundColor : Colors.transparent,
      ),
    );
  }
}
