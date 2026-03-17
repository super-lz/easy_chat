import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../provider/chat_session_pprovider.dart';
import 'chat_composer_input.dart';
import 'chat_composer_panels.dart';
import 'chat_composer_pending_attachments.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key, required this.provider});

  final ChatSessionPProvider provider;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const double panelMaxHeight = 400;
  final FocusNode _focusNode = FocusNode();
  static const double nullVal = -1;
  double _bottomInsetMaxHeight = nullVal;
  double _aimHeight = nullVal;

  ChatComposerPanelType _panelType = ChatComposerPanelType.none;

  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  double _currentHeight = 0;

  double get _paddingBottom => MediaQuery.of(context).viewPadding.bottom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _focusNode.addListener(_onFocusChanged);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // _controller.addListener(() {
    //   if (_controller.isCompleted) {
    //     if (_aimHeight != nullVal) {
    //       _aimHeight = nullVal;
    //     }
    //   }
    // });

    _heightAnimation = AlwaysStoppedAnimation(0);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = PlatformDispatcher.instance.views.first;
    final bottom = view.viewInsets.bottom / view.devicePixelRatio;
    if (bottom > _bottomInsetMaxHeight) {
      _bottomInsetMaxHeight = bottom;
    }
    print('xxxx $_aimHeight $_panelType');
    if (_aimHeight == nullVal && _panelType == ChatComposerPanelType.none) {
      _updateHeight(bottom, isAim: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {}

  void _updateHeight(double targetHeight, {bool isAim = true}) {
    _controller.stop();
    final double target = targetHeight < 0 ? 0 : targetHeight;
    if (isAim) {
      _aimHeight = target;
    }

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

  void _handleKeyboardTap() async {
    final panelType = _panelType;
    _setPanelType(ChatComposerPanelType.none);
    if (panelType != ChatComposerPanelType.none &&
        _bottomInsetMaxHeight != nullVal) {
      _updateHeight(_bottomInsetMaxHeight);
    }
    if (panelType == ChatComposerPanelType.none) {
      _aimHeight = nullVal;
    }
  }

  void _handleEmojiTap() {
    if (_panelType == ChatComposerPanelType.emojis) {
      _setPanelType(ChatComposerPanelType.none);
      if (_bottomInsetMaxHeight != nullVal) {
        _updateHeight(_bottomInsetMaxHeight);
      }
      _focusNode.requestFocus();
    } else {
      _setPanelType(ChatComposerPanelType.emojis);
      _updateHeight(panelMaxHeight);
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  void _handleAttachmentTap() {
    if (_panelType == ChatComposerPanelType.attachments) {
      _setPanelType(ChatComposerPanelType.none);
      if (_bottomInsetMaxHeight != nullVal) {
        _updateHeight(_bottomInsetMaxHeight);
      }
      _focusNode.requestFocus();
    } else {
      _setPanelType(ChatComposerPanelType.attachments);
      _updateHeight(panelMaxHeight);
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  void _handleTapOutside(PointerDownEvent event) {
    final panelType = _panelType;
    _setPanelType(ChatComposerPanelType.none);
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    if (panelType != ChatComposerPanelType.none) {
      _updateHeight(0);
    }
  }

  void _focus() {
    _aimHeight = nullVal;
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: _handleTapOutside,
      child: ColoredBox(
        color: Colors.white,
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
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
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
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return ColoredBox(
                    color: Colors.black,
                    child: SizedBox(
                      height: _heightAnimation.value,
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
