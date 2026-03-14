import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/pending_attachment.dart';
import '../../provider/chat_session_pprovider.dart';
import '../../route/route_paths.dart';
import 'components/chat_header_section.dart';
import 'components/chat_message_tile.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  bool _isHeaderExpanded = false;
  final FocusNode _composerFocusNode = FocusNode();
  _ComposerPanelType _composerPanelType = _ComposerPanelType.none;
  double _lastKeyboardHeight = 290;
  double _keyboardOpeningHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final keyboardInset = _keyboardInset;
    if (keyboardInset > 0) {
      _lastKeyboardHeight = keyboardInset;
      if (_keyboardOpeningHeight != 0) {
        setState(() {
          _keyboardOpeningHeight = 0;
        });
      }
    } else if (_keyboardOpeningHeight != 0 && !_composerFocusNode.hasFocus) {
      setState(() {
        _keyboardOpeningHeight = 0;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSessionPProvider>();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    if (!provider.hasCachedConnection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(RoutePaths.scan);
        }
      });
    }

    final renderItems = buildChatRenderItems(
      provider.messages,
    ).reversed.toList();
    final phoneAddress = _buildPhoneAddress(provider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEF5),
          gradient: const LinearGradient(
            colors: [Color(0xFFF2F6FB), Color(0xFFE7EDF5), Color(0xFFEAEFF6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.45),
              blurRadius: 80,
              offset: const Offset(0, -20),
            ),
          ],
        ),
        child: Column(
          children: [
            ChatHeaderSection(
              deviceName: provider.deviceName,
              serverStatus: provider.serverStatus,
              isExpanded: _isHeaderExpanded,
              onToggleExpanded: () {
                setState(() {
                  _isHeaderExpanded = !_isHeaderExpanded;
                });
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _dismissComposerPanelsAndKeyboard,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                20,
                                14,
                                16,
                              ),
                              itemBuilder: (context, index) {
                                return ChatMessageTile(
                                  item: renderItems[index],
                                );
                              },
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemCount: renderItems.length,
                            ),
                          ),
                          _ChatComposer(
                            provider: provider,
                            focusNode: _composerFocusNode,
                            panelType: _composerPanelType,
                            keyboardHeight: keyboardInset,
                            keyboardOpeningHeight: _keyboardOpeningHeight,
                            preferredKeyboardHeight: _preferredPanelHeight,
                            onToggleAttachments: () => _toggleComposerPanel(
                              _ComposerPanelType.attachments,
                            ),
                            onToggleEmojis: () =>
                                _toggleComposerPanel(_ComposerPanelType.emojis),
                            onClosePanels: _closeComposerPanelsOnly,
                            onRequestKeyboard: _focusComposerInput,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isHeaderExpanded)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isHeaderExpanded = false;
                          });
                        },
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.08),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                child: ChatHeaderOverlayPanel(
                                  deviceName: provider.deviceName,
                                  browserName: provider.browserPeerName,
                                  phoneAddress: phoneAddress,
                                  browserAddress: provider.browserPeerAddress,
                                  serverStatus: provider.serverStatus,
                                  onDisconnect: () => _disconnect(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

  String _buildPhoneAddress(ChatSessionPProvider provider) {
    final ip = provider.ipController.text.trim();
    final port = provider.portController.text.trim();
    if (ip.isEmpty || port.isEmpty) {
      return '未知';
    }
    return '$ip:$port';
  }

  void _toggleComposerPanel(_ComposerPanelType type) {
    final nextType = _composerPanelType == type
        ? _ComposerPanelType.none
        : type;

    if (_composerPanelType != nextType) {
      setState(() {
        _composerPanelType = nextType;
      });
    }

    if (nextType == _ComposerPanelType.none) {
      if (_keyboardOpeningHeight != 0) {
        setState(() {
          _keyboardOpeningHeight = 0;
        });
      }
      FocusScope.of(context).unfocus();
      return;
    }

    if (_isKeyboardVisible || _composerFocusNode.hasFocus) {
      FocusScope.of(context).unfocus();
    }
  }

  void _closeComposerPanelsOnly() {
    if (_composerPanelType == _ComposerPanelType.none) return;
    setState(() {
      _composerPanelType = _ComposerPanelType.none;
    });
  }

  void _dismissComposerPanelsAndKeyboard() {
    FocusScope.of(context).unfocus();
    if (_keyboardOpeningHeight != 0) {
      setState(() {
        _keyboardOpeningHeight = 0;
      });
    }
    _closeComposerPanelsOnly();
  }

  void _focusComposerInput() {
    if (_composerPanelType != _ComposerPanelType.none) {
      setState(() {
        _composerPanelType = _ComposerPanelType.none;
      });
    }
    if (!_composerFocusNode.hasFocus) {
      setState(() {
        _keyboardOpeningHeight = _preferredPanelHeight;
      });
      _composerFocusNode.requestFocus();
    }
  }

  bool get _isKeyboardVisible {
    return _keyboardInset > 0;
  }

  double get _keyboardInset {
    final view = View.maybeOf(context);
    if (view != null) {
      return MediaQueryData.fromView(view).viewInsets.bottom;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return 0;
    }
    return MediaQueryData.fromView(views.first).viewInsets.bottom;
  }

  double get _preferredPanelHeight {
    return _lastKeyboardHeight.clamp(260.0, 360.0);
  }
}

enum _ComposerPanelType { none, attachments, emojis }

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    required this.provider,
    required this.focusNode,
    required this.panelType,
    required this.keyboardHeight,
    required this.keyboardOpeningHeight,
    required this.preferredKeyboardHeight,
    required this.onToggleAttachments,
    required this.onToggleEmojis,
    required this.onClosePanels,
    required this.onRequestKeyboard,
  });

  final ChatSessionPProvider provider;
  final FocusNode focusNode;
  final _ComposerPanelType panelType;
  final double keyboardHeight;
  final double keyboardOpeningHeight;
  final double preferredKeyboardHeight;
  final VoidCallback onToggleAttachments;
  final VoidCallback onToggleEmojis;
  final VoidCallback onClosePanels;
  final VoidCallback onRequestKeyboard;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  static const Duration panelAnimationDuration = Duration(milliseconds: 240);
  static const Duration _panelSwitchDuration = Duration(milliseconds: 180);

  double _panelHeightFor(_ComposerPanelType type) {
    return switch (type) {
      _ComposerPanelType.attachments => widget.preferredKeyboardHeight,
      _ComposerPanelType.emojis => widget.preferredKeyboardHeight,
      _ComposerPanelType.none => 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachmentPanel =
        widget.panelType == _ComposerPanelType.attachments;
    final hasEmojiPanel = widget.panelType == _ComposerPanelType.emojis;
    final panelHeight = _panelHeightFor(widget.panelType);
    final isPanelVisible = widget.panelType != _ComposerPanelType.none;
    final targetPanelRevealHeight = isPanelVisible ? panelHeight : 0.0;
    final keyboardTargetHeight = widget.keyboardHeight > 0
        ? widget.keyboardHeight
        : widget.keyboardOpeningHeight;
    final targetOccupiedHeight = isPanelVisible
        ? widget.preferredKeyboardHeight
        : keyboardTargetHeight;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF334155).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: targetOccupiedHeight),
        duration: panelAnimationDuration,
        curve: Curves.easeOutCubic,
        child: _ComposerPanelHost(
          panelType: widget.panelType,
          panelHeight: panelHeight,
          onEmojiTap: (emoji) =>
              _insertEmoji(widget.provider.messageController, emoji),
          onCameraTap: () {
            widget.onClosePanels();
            unawaited(widget.provider.capturePendingImage());
          },
          onGalleryTap: () {
            widget.onClosePanels();
            unawaited(widget.provider.pickPendingImagesFromGallery());
          },
          onFileTap: () {
            widget.onClosePanels();
            unawaited(widget.provider.pickPendingFiles());
          },
        ),
        builder: (context, occupiedHeight, panelChild) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: targetPanelRevealHeight),
            duration: panelAnimationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, panelRevealHeight, _) {
              final revealProgress = panelHeight <= 0
                  ? 0.0
                  : (panelRevealHeight / panelHeight).clamp(0.0, 1.0);
              final hiddenOffset = panelHeight * (1 - revealProgress);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.provider.pendingAttachments.isNotEmpty) ...[
                    _PendingAttachmentsRow(provider: widget.provider),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _ComposerInputShell(
                          controller: widget.provider.messageController,
                          focusNode: widget.focusNode,
                          hasEmojiPanel: hasEmojiPanel,
                          hasAttachmentPanel: hasAttachmentPanel,
                          hasPendingAttachments:
                              widget.provider.pendingAttachments.isNotEmpty,
                          onTapInput: widget.onRequestKeyboard,
                          onTapEmoji: widget.onToggleEmojis,
                          onTapAttachment: widget.onToggleAttachments,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: widget.provider.canSend
                            ? () => unawaited(widget.provider.sendDraft())
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFF111827),
                          disabledBackgroundColor: const Color(0xFFD3DBE6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: occupiedHeight,
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -hiddenOffset,
                            height: panelHeight,
                            child: AnimatedOpacity(
                              duration: _panelSwitchDuration,
                              curve: Curves.easeOutCubic,
                              opacity: revealProgress,
                              child: IgnorePointer(
                                ignoring: !isPanelVisible,
                                child: panelChild,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ComposerPanelHost extends StatelessWidget {
  const _ComposerPanelHost({
    required this.panelType,
    required this.panelHeight,
    required this.onEmojiTap,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onFileTap,
  });

  final _ComposerPanelType panelType;
  final double panelHeight;
  final ValueChanged<String> onEmojiTap;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onFileTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: panelHeight,
      child: AnimatedSwitcher(
        duration: _ChatComposerState._panelSwitchDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: switch (panelType) {
          _ComposerPanelType.attachments => _ComposerAttachmentPanel(
            key: const ValueKey('attachments-panel'),
            height: panelHeight,
            onCameraTap: onCameraTap,
            onGalleryTap: onGalleryTap,
            onFileTap: onFileTap,
          ),
          _ComposerPanelType.emojis => _ComposerEmojiPanel(
            key: const ValueKey('emoji-panel'),
            height: panelHeight,
            onEmojiTap: onEmojiTap,
          ),
          _ComposerPanelType.none => const SizedBox.shrink(
            key: ValueKey('empty-panel'),
          ),
        },
      ),
    );
  }
}

class _ComposerInputShell extends StatelessWidget {
  const _ComposerInputShell({
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
  final VoidCallback onPressed;

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

class _ComposerAttachmentPanel extends StatelessWidget {
  const _ComposerAttachmentPanel({
    super.key,
    required this.height,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onFileTap,
  });

  final double height;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onFileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
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
          const Spacer(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ComposerEmojiPanel extends StatelessWidget {
  const _ComposerEmojiPanel({
    super.key,
    required this.height,
    required this.onEmojiTap,
  });

  final double height;
  final ValueChanged<String> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(24),
        ),
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
              backgroundColor: Color(0xFFF7F9FC),
              iconColor: Color(0xFF94A3B8),
              iconColorSelected: Color(0xFF111827),
              indicatorColor: Color(0xFF111827),
              dividerColor: Colors.transparent,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(
              backgroundColor: const Color(0xFFF7F9FC),
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

class _PendingAttachmentsRow extends StatelessWidget {
  const _PendingAttachmentsRow({required this.provider});

  final ChatSessionPProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '已选 ${provider.pendingAttachments.length} 个文件',
                style: const TextStyle(
                  color: Color(0xFF607086),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: provider.clearPendingAttachments,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5E66),
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
              color: const Color(0xFFFFFFFF),
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
                      color: const Color(0xFFF1F5FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _fileKindLabel(attachment.name),
                      style: const TextStyle(
                        color: Color(0xFF445368),
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
                          color: Color(0xFF1C2530),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatAttachmentSize(attachment.size),
                        style: const TextStyle(
                          color: Color(0xFF7C8899),
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
                  color: const Color(0xFF1F2937),
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

void _insertEmoji(TextEditingController controller, String emoji) {
  final text = controller.text;
  final selection = controller.selection;
  final isInvalid = selection.start < 0 || selection.end < 0;
  final start = isInvalid ? text.length : selection.start;
  final end = isInvalid ? text.length : selection.end;
  final nextText = text.replaceRange(start, end, emoji);
  final cursor = start + emoji.length;
  controller.value = TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: cursor),
  );
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
