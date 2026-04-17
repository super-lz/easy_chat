import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/chat_message.dart';
import '../../provider/chat_session_provider.dart';
import '../../utils/app_error_formatter.dart';
import 'chat_colors.dart';

class FilePreviewPage extends StatefulWidget {
  const FilePreviewPage({super.key, required this.message});

  final ChatMessage message;

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  String? _resolvedPath;
  String? _resolvedText;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _immersivePreview = false;

  bool get _isImage => (widget.message.mimeType ?? '').startsWith('image/');
  bool get _isVideo => (widget.message.mimeType ?? '').startsWith('video/');

  @override
  void initState() {
    super.initState();
    _preparePreview();
  }

  Future<void> _preparePreview() async {
    try {
      final path = await context
          .read<ChatSessionProvider>()
          .ensureMessageFilePath(widget.message);
      if (!mounted) return;
      _resolvedPath = path;

      if (_isTextLike(widget.message)) {
        _resolvedText = await _tryReadTextFromPath(path);
      }

      if (_isVideo) {
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        await controller.setLooping(true);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _videoController = controller;
        _videoReady = true;
      }

      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_immersivePreview) {
      _restoreSystemUi();
    }
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final darkPreview = _isImage || _isVideo;

    return Scaffold(
      backgroundColor: darkPreview
          ? const Color(0xFF0E1318)
          : const Color(0xFFF4F6F8),
      appBar: _immersivePreview
          ? null
          : AppBar(
              backgroundColor: darkPreview
                  ? const Color(0x14000000)
                  : Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: darkPreview
                  ? Colors.white
                  : ChatColors.headerTitle,
              titleSpacing: 0,
              title: Text(
                message.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: darkPreview ? Colors.white : ChatColors.headerTitle,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () => _showPreviewActions(context, message),
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: '更多操作',
                ),
                const SizedBox(width: 6),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  darkPreview ? 0 : 18,
                  _immersivePreview ? 0 : (darkPreview ? 0 : 8),
                  darkPreview ? 0 : 18,
                  12,
                ),
                child: Center(
                  child: _PreviewBody(
                    message: message,
                    resolvedPath: _resolvedPath,
                    resolvedText: _resolvedText,
                    videoController: _videoController,
                    videoReady: _videoReady,
                    immersivePreview: _immersivePreview,
                    onToggleFullscreen: _isVideo ? _toggleFullscreen : null,
                  ),
                ),
              ),
            ),
          ),
          if (!_immersivePreview)
            _PreviewBottomBar(
              message: message,
              onPrimaryAction: () => _handlePrimaryAction(context, message),
              onSecondaryAction: () => _handleSecondaryAction(context, message),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleFullscreen() async {
    final nextValue = !_immersivePreview;
    setState(() {
      _immersivePreview = nextValue;
    });
    if (nextValue) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await _restoreSystemUi();
    }
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({
    required this.message,
    required this.resolvedPath,
    required this.resolvedText,
    required this.videoController,
    required this.videoReady,
    required this.immersivePreview,
    required this.onToggleFullscreen,
  });

  final ChatMessage message;
  final String? resolvedPath;
  final String? resolvedText;
  final VideoPlayerController? videoController;
  final bool videoReady;
  final bool immersivePreview;
  final Future<void> Function()? onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final mimeType = message.mimeType ?? '';
    if (mimeType.startsWith('image/')) {
      if (resolvedPath == null) {
        return const _PreviewLoadingCard(label: '正在准备图片预览…');
      }
      return _ImagePreviewCard(
        imagePath: resolvedPath!,
        immersivePreview: immersivePreview,
      );
    }

    if (mimeType.startsWith('video/')) {
      if (!videoReady || videoController == null) {
        return const _PreviewLoadingCard(label: '正在准备视频预览…');
      }
      return _VideoPreviewCard(
        controller: videoController!,
        immersivePreview: immersivePreview,
        onToggleFullscreen: onToggleFullscreen,
      );
    }

    final textPreview = resolvedText ?? _tryDecodeText(message);
    if (textPreview != null) {
      return _TextPreviewCard(text: textPreview, fileName: message.text);
    }

    return _UnsupportedPreviewCard(
      message: message,
      resolvedPath: resolvedPath,
    );
  }
}

class _ImagePreviewCard extends StatefulWidget {
  const _ImagePreviewCard({
    required this.imagePath,
    required this.immersivePreview,
  });

  final String imagePath;
  final bool immersivePreview;

  @override
  State<_ImagePreviewCard> createState() => _ImagePreviewCardState();
}

class _ImagePreviewCardState extends State<_ImagePreviewCard> {
  late final TransformationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _controller.value = Matrix4.identity();
      return;
    }

    _controller.value = Matrix4.identity()..scaleByDouble(2.4, 2.4, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.immersivePreview ? 0 : 26),
      child: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 0.8,
          maxScale: 4,
          child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _PreviewBottomBar extends StatelessWidget {
  const _PreviewBottomBar({
    required this.message,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  final ChatMessage message;
  final Future<void> Function() onPrimaryAction;
  final Future<void> Function() onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final isGalleryAsset = _isGalleryAsset(message);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F1720),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSecondaryAction,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('分享'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide.none,
                    backgroundColor: const Color(0xFFF3F6FA),
                    foregroundColor: ChatColors.messageText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPrimaryAction,
                  icon: Icon(
                    isGalleryAsset
                        ? Icons.photo_library_outlined
                        : Icons.download_rounded,
                    size: 18,
                  ),
                  label: Text(isGalleryAsset ? '保存到相册' : '另存为'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: ChatColors.confirmDialogConfirmBackground,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPreviewCard extends StatefulWidget {
  const _VideoPreviewCard({
    required this.controller,
    required this.immersivePreview,
    required this.onToggleFullscreen,
  });

  final VideoPlayerController controller;
  final bool immersivePreview;
  final Future<void> Function()? onToggleFullscreen;

  @override
  State<_VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<_VideoPreviewCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isPlaying = controller.value.isPlaying;
    final durationMs = controller.value.duration.inMilliseconds;
    final positionMs = controller.value.position.inMilliseconds.clamp(
      0,
      durationMs == 0 ? 0 : durationMs,
    );
    final isMuted = controller.value.volume == 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.immersivePreview ? 0 : 26),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio == 0
                ? 16 / 9
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                child: Center(
                  child: AnimatedOpacity(
                    opacity: isPlaying ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x5A000000),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: durationMs == 0
                          ? 0
                          : positionMs.toDouble().clamp(
                              0,
                              durationMs.toDouble(),
                            ),
                      max: durationMs == 0 ? 1 : durationMs.toDouble(),
                      activeColor: Colors.white,
                      inactiveColor: const Color(0x40FFFFFF),
                      onChanged: (value) async {
                        await controller.seekTo(
                          Duration(milliseconds: value.round()),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (isPlaying) {
                            await controller.pause();
                          } else {
                            await controller.play();
                          }
                        },
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await controller.setVolume(isMuted ? 1 : 0);
                        },
                        icon: Icon(
                          isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: widget.onToggleFullscreen,
                        icon: Icon(
                          widget.immersivePreview
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextPreviewCard extends StatelessWidget {
  const _TextPreviewCard({required this.text, required this.fileName});

  final String text;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 760),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '文本预览',
                  style: TextStyle(
                    color: ChatColors.headerTitle,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  _showPreviewFeedback(context, '已复制全文');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('复制全文'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    color: ChatColors.messageText,
                    fontSize: 14.5,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedPreviewCard extends StatelessWidget {
  const _UnsupportedPreviewCard({
    required this.message,
    required this.resolvedPath,
  });

  final ChatMessage message;
  final String? resolvedPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              _fileKindLabel(message.text),
              style: const TextStyle(
                color: ChatColors.messageText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂不支持直接预览该文件',
            style: TextStyle(
              color: ChatColors.headerTitle,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '该文件会显示基本信息，你仍然可以通过底部或右上角进行分享和保存。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ChatColors.headerMetaLabel,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          _InfoLine(label: '文件名', value: message.text),
          _InfoLine(label: '类型', value: message.mimeType ?? '未知'),
          _InfoLine(
            label: '大小',
            value: _displayFileSize(message, resolvedPath),
          ),
          if (message.meta != null)
            _InfoLine(label: '状态', value: message.meta!),
        ],
      ),
    );
  }
}

class _PreviewLoadingCard extends StatelessWidget {
  const _PreviewLoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: ChatColors.headerMetaLabel,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                color: ChatColors.headerMetaLabel,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ChatColors.messageText,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _tryDecodeText(ChatMessage message) {
  final mimeType = message.mimeType ?? '';
  final isTextLike =
      mimeType.startsWith('text/') ||
      mimeType == 'application/json' ||
      mimeType == 'application/xml' ||
      mimeType == 'text/markdown';
  if (!isTextLike || message.bytes == null) {
    return null;
  }
  try {
    return utf8.decode(message.bytes!);
  } catch (_) {
    return null;
  }
}

bool _isTextLike(ChatMessage message) {
  final mimeType = message.mimeType ?? '';
  return mimeType.startsWith('text/') ||
      mimeType == 'application/json' ||
      mimeType == 'application/xml' ||
      mimeType == 'text/markdown';
}

Future<String?> _tryReadTextFromPath(String path) async {
  try {
    return await File(path).readAsString();
  } catch (_) {
    return null;
  }
}

String _displayFileSize(ChatMessage message, String? resolvedPath) {
  if (message.bytes != null) {
    return _formatBytes(message.bytes!.length);
  }
  if (resolvedPath != null) {
    final file = File(resolvedPath);
    if (file.existsSync()) {
      return _formatBytes(file.lengthSync());
    }
  }
  return '未知';
}

String _formatBytes(int size) {
  if (size >= 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (size >= 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }
  return '$size B';
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _fileKindLabel(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1
      ? 'FILE'
      : fileName.substring(dot + 1).toUpperCase();
  return extension.substring(0, math.min(extension.length, 4));
}

Future<void> _handlePrimaryAction(
  BuildContext context,
  ChatMessage message,
) async {
  final provider = context.read<ChatSessionProvider>();
  try {
    _showPreviewFeedback(context, '正在处理文件…');
    final result = _isGalleryAsset(message)
        ? await provider.saveFileMessageToGallery(message)
        : await provider.exportFileMessage(message);
    if (!context.mounted) return;
    _showPreviewFeedback(context, result);
  } catch (error) {
    if (!context.mounted) return;
    _showPreviewFeedback(
      context,
      AppErrorFormatter.message(error),
      isError: true,
    );
  }
}

Future<void> _handleSecondaryAction(
  BuildContext context,
  ChatMessage message,
) async {
  final provider = context.read<ChatSessionProvider>();
  try {
    _showPreviewFeedback(context, '正在打开分享…');
    final result = await provider.shareFileMessage(message);
    if (!context.mounted) return;
    _showPreviewFeedback(context, result);
  } catch (error) {
    if (!context.mounted) return;
    _showPreviewFeedback(
      context,
      AppErrorFormatter.message(error),
      isError: true,
    );
  }
}

Future<void> _showPreviewActions(
  BuildContext context,
  ChatMessage message,
) async {
  final provider = context.read<ChatSessionProvider>();
  final isGalleryAsset = _isGalleryAsset(message);

  Future<void> runAction(Future<String> Function() action) async {
    Navigator.of(context).pop();
    _showPreviewFeedback(context, '正在处理文件…');
    try {
      final result = await action();
      if (!context.mounted) return;
      _showPreviewFeedback(context, result);
    } catch (error) {
      if (!context.mounted) return;
      _showPreviewFeedback(
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
              const SizedBox(height: 16),
              _PreviewActionTile(
                icon: Icons.ios_share_rounded,
                title: '分享文件',
                subtitle: '发送到其他 App 或系统分享面板',
                onTap: () =>
                    runAction(() => provider.shareFileMessage(message)),
              ),
              if (isGalleryAsset)
                _PreviewActionTile(
                  icon: Icons.photo_library_outlined,
                  title: '保存到相册',
                  subtitle: '适用于图片和视频',
                  onTap: () => runAction(
                    () => provider.saveFileMessageToGallery(message),
                  ),
                ),
              _PreviewActionTile(
                icon: Icons.folder_open_rounded,
                title: '另存为',
                subtitle: '选择一个你方便访问的位置',
                onTap: () =>
                    runAction(() => provider.exportFileMessage(message)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool _isGalleryAsset(ChatMessage message) {
  final mimeType = message.mimeType ?? '';
  return mimeType.startsWith('image/') || mimeType.startsWith('video/');
}

void _showPreviewFeedback(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: isError
            ? const Color(0xFF7B4C42)
            : const Color(0xFF22313F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
}

class _PreviewActionTile extends StatelessWidget {
  const _PreviewActionTile({
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
