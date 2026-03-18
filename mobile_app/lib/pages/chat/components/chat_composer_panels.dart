import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

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
        height: 300,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ComposerActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: '拍摄',
                    onTap: onCameraTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ComposerActionButton(
                    icon: Icons.photo_library_rounded,
                    label: '相册',
                    onTap: onGalleryTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ComposerActionButton(
                    icon: Icons.insert_drive_file_rounded,
                    label: '文件',
                    onTap: onFileTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerEmojiPanel extends StatelessWidget {
  const _ComposerEmojiPanel({required this.height, required this.onEmojiTap});

  final double height;
  final ValueChanged<String> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => onEmojiTap(emoji.emoji),
          onBackspacePressed: () {},
          textEditingController: null,
          config: Config(
            height: height,
            checkPlatformCompatibility: false,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: 26,
              columns: 8,
              verticalSpacing: 4,
              horizontalSpacing: 4,
              gridPadding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              noRecents: const Text(
                '暂无最近表情',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
            skinToneConfig: const SkinToneConfig(enabled: false),
            categoryViewConfig: const CategoryViewConfig(
              initCategory: Category.SMILEYS,
              backgroundColor: Colors.transparent,
              iconColor: Color(0xFF94A3B8),
              iconColorSelected: Color(0xFF111827),
              indicatorColor: Color(0xFF111827),
              dividerColor: Colors.transparent,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Colors.transparent,
              buttonIconColor: const Color(0xFF94A3B8),
              hintText: '搜索表情',
              hintTextStyle: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF475467)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475467),
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
