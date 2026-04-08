import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keyboard_height_plugin/keyboard_height_plugin.dart';

import '../chat_colors.dart';
import '../../../provider/chat_session_provider.dart';
import 'chat_composer_input.dart';
import 'chat_composer_panels.dart';
import 'chat_composer_pending_attachments.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, required this.provider});

  final ChatSessionProvider provider;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with SingleTickerProviderStateMixin {
  static const double panelMaxHeight = 300;

  double get _paddingBottom => MediaQuery.of(context).viewPadding.bottom;

  final FocusNode _focusNode = FocusNode();
  final KeyboardHeightPlugin _keyboardHeightPlugin = KeyboardHeightPlugin();

  double _currentHeight = 0;

  ChatComposerPanelType _panelType = ChatComposerPanelType.none;

  late AnimationController _controller;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _keyboardHeightPlugin.onKeyboardHeightChanged(_handleKeyboardHeightChanged);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _heightAnimation = AlwaysStoppedAnimation(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyboardHeightChanged(double height) {
    if (!mounted) {
      return;
    }

    if (_panelType != ChatComposerPanelType.none) {
      return;
    }
    _animateHeight(height);
  }

  void _animateHeight(double targetHeight) {
    _controller.stop();
    final double target = targetHeight < 0 ? 0 : targetHeight;

    _heightAnimation = Tween<double>(
      begin: _currentHeight,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _currentHeight = target;
    _controller
      ..reset()
      ..forward();
  }

  void _setPanelType(ChatComposerPanelType value) {
    if (_panelType == value) {
      return;
    }
    setState(() {
      _panelType = value;
    });
  }

  void _handleKeyboardTap() {
    _setPanelType(ChatComposerPanelType.none);
    _focus();
  }

  void _handleEmojiTap() {
    _togglePanel(ChatComposerPanelType.emojis);
  }

  void _handleAttachmentTap() {
    _togglePanel(ChatComposerPanelType.attachments);
  }

  void _togglePanel(ChatComposerPanelType panelType) {
    if (panelType != _panelType) {
      _setPanelType(panelType);
      _animateHeight(panelMaxHeight);
      _unfocus();
    } else {
      _setPanelType(ChatComposerPanelType.none);
      _focus();
    }
  }

  void _handleTapOutside(PointerDownEvent event) {
    if (_panelType != ChatComposerPanelType.none) {
      _animateHeight(0);
    }
    _setPanelType(ChatComposerPanelType.none);
    _unfocus();
  }

  void _focus() {
    _focusNode.requestFocus();
  }

  void _unfocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: _handleTapOutside,
      child: ColoredBox(
        color: ChatColors.composerSurface,
        child: Padding(
          padding: EdgeInsets.only(bottom: _paddingBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.provider.pendingAttachments.isNotEmpty) ...[
                ChatComposerPendingAttachmentsRow(provider: widget.provider),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: const BoxDecoration(
                  color: ChatColors.composerSurface,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ChatComposerInputShell(
                        controller: widget.provider.messageController,
                        focusNode: _focusNode,
                        hasEmojiPanel:
                            _panelType == ChatComposerPanelType.emojis,
                        hasAttachmentPanel:
                            _panelType == ChatComposerPanelType.attachments,
                        hasPendingAttachments:
                            widget.provider.pendingAttachments.isNotEmpty,
                        onTapInput: _handleKeyboardTap,
                        onTapEmoji: _handleEmojiTap,
                        onTapAttachment: _handleAttachmentTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: FilledButton(
                        onPressed: widget.provider.canSend
                            ? () => unawaited(widget.provider.sendDraft())
                            : null,
                        style: ButtonStyle(
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.zero,
                          ),
                          elevation: const WidgetStatePropertyAll(0),
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.disabled)) {
                              return ChatColors.sendButtonDisabledBackground;
                            }
                            return ChatColors.sendButtonEnabledBackground;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.disabled)) {
                              return ChatColors.sendButtonDisabledForeground;
                            }
                            return ChatColors.sendButtonForeground;
                          }),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return ClipRect(
                    child: Container(
                      height: _heightAnimation.value,
                      decoration: const BoxDecoration(
                        color: ChatColors.composerPanelSurface,
                      ),
                      child: child,
                    ),
                  );
                },
                child: ChatComposerPanelHost(
                  panelType: _panelType,
                  onEmojiTap: (emoji) =>
                      _insertEmoji(widget.provider.messageController, emoji),
                  onCameraTap: () {
                    unawaited(widget.provider.capturePendingImage());
                  },
                  onGalleryTap: () {
                    unawaited(widget.provider.pickPendingImagesFromGallery());
                  },
                  onFileTap: () {
                    unawaited(widget.provider.pickPendingFiles());
                  },
                ),
              ),
            ],
          ),
        ),
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
