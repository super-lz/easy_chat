import 'package:flutter/material.dart';

/// 聊天页专用颜色配置。
///
/// 规则：
/// - 所有聊天页及其子组件颜色统一从这里取值。
/// - 每个颜色都带中文注释，便于后续快速调整。
class ChatColors {
  ChatColors._();

  // 页面与分层

  /// 聊天消息流所在的大页面背景色。
  static const Color pageBackground = Color.fromARGB(255, 240, 240, 242);

  /// 顶部 header 的背景色。
  static const Color headerBackground = Color.fromARGB(255, 246, 246, 246);

  /// 顶部连接信息 overlay 的背景色。
  static const Color headerOverlayBackground = Color.fromARGB(
    255,
    246,
    246,
    246,
  );

  /// 顶部 overlay 弹出时的遮罩颜色。
  static const Color overlayMask = Color(0x3D101828);

  /// 输入框外层区域背景色，用来和消息流区分。
  static const Color composerSurface = Color.fromARGB(255, 246, 246, 246);

  /// 底部展开功能面板背景色，用来和输入栏再区分一层。
  static const Color composerPanelSurface = Color.fromARGB(255, 246, 246, 246);

  // 顶部文字与按钮

  /// 顶部设备名文字颜色。
  static const Color headerTitle = Color(0xFF151B26);

  /// 顶部展开按钮背景色。
  static const Color headerExpandButtonBackground = Color(0xFFF6F7F8);

  /// 顶部展开按钮图标颜色。
  static const Color headerExpandButtonForeground = Color(0xFF5B6470);

  /// 连接详情面板中标签类文字颜色。
  static const Color headerMetaLabel = Color(0xFF86909C);

  /// 连接详情面板中正文文字颜色。
  static const Color headerMetaValue = Color(0xFF24303A);

  /// 连接详情面板中“状态”标题文字颜色。
  static const Color headerSectionLabel = Color(0xFF7B8591);

  /// 连接详情面板中“断开连接”按钮背景色。
  static const Color headerActionBackground = Color.fromARGB(
    255,
    255,
    255,
    255,
  );

  /// 连接详情面板中“断开连接”按钮文字颜色。
  static const Color headerActionForeground = Color(0xFF425466);

  // 二次确认弹窗

  /// 二次确认弹窗背景色。
  static const Color confirmDialogBackground = Color(0xFFFFFFFF);

  /// 二次确认弹窗标题颜色。
  static const Color confirmDialogTitle = Color(0xFF151B26);

  /// 二次确认弹窗正文颜色。
  static const Color confirmDialogText = Color(0xFF66717D);

  /// 二次确认弹窗取消按钮背景色。
  static const Color confirmDialogCancelBackground = Color(0xFFF3F5F7);

  /// 二次确认弹窗取消按钮文字颜色。
  static const Color confirmDialogCancelForeground = Color(0xFF5B6470);

  /// 二次确认弹窗确认按钮背景色。
  static const Color confirmDialogConfirmBackground = Color(0xFF169AF3);

  /// 二次确认弹窗确认按钮文字颜色。
  static const Color confirmDialogConfirmForeground = Color(0xFFFFFFFF);

  // 状态胶囊

  /// 已连接状态文字颜色。
  static const Color statusConnectedText = Color(0xFF2F9E67);

  /// 已连接状态圆点颜色。
  static const Color statusConnectedDot = Color(0xFF35D07F);

  /// 已连接状态胶囊背景色。
  static const Color statusConnectedBackground = Color(0xFFE8FBF1);

  /// 重连中状态文字颜色。
  static const Color statusReconnectingText = Color(0xFF9A7B50);

  /// 重连中状态圆点颜色。
  static const Color statusReconnectingDot = Color(0xFFC3A06F);

  /// 重连中状态胶囊背景色。
  static const Color statusReconnectingBackground = Color(0xFFF7F1E6);

  /// 等待接入状态文字颜色。
  static const Color statusWaitingText = Color(0xFF6E7E8E);

  /// 等待接入状态圆点颜色。
  static const Color statusWaitingDot = Color(0xFF8FA0B0);

  /// 等待接入状态胶囊背景色。
  static const Color statusWaitingBackground = Color(0xFFF0F3F6);

  /// 未启动状态文字颜色。
  static const Color statusOfflineText = Color(0xFF946E63);

  /// 未启动状态圆点颜色。
  static const Color statusOfflineDot = Color(0xFFBB8D81);

  /// 未启动状态胶囊背景色。
  static const Color statusOfflineBackground = Color(0xFFF8EEEB);

  /// 未知状态文字颜色。
  static const Color statusUnknownText = Color(0xFF727B84);

  /// 未知状态圆点颜色。
  static const Color statusUnknownDot = Color(0xFF98A1AB);

  /// 未知状态胶囊背景色。
  static const Color statusUnknownBackground = Color(0xFFF1F3F5);

  // 警告块

  /// 警告块背景色。
  static const Color warningBackground = Color(0xFFFFF4F1);

  /// 警告块标题颜色。
  static const Color warningTitle = Color(0xFF9C5C4A);

  /// 警告块正文颜色。
  static const Color warningText = Color(0xFF7A5045);

  // 输入区

  /// 输入框本体背景色。
  static const Color inputBackground = Color(0xFFFEFEFF);

  /// 输入框激活面板时的背景色。
  static const Color inputBackgroundActive = Color(0xFFFFFFFF);

  /// 输入框提示文字颜色。
  static const Color inputHint = Color(0xFFACB3BD);

  /// 输入框正文颜色。
  static const Color inputText = Color(0xFF1F2937);

  /// 表情按钮主色。
  static const Color inputEmojiAction = Color(0xFFF3B34F);

  /// 附件按钮主色。
  static const Color inputAttachmentAction = Color(0xFF5BB8E8);

  /// 功能按钮未激活时的表情图标颜色。
  static const Color inputEmojiIdle = Color(0xFFD9A75A);

  /// 功能按钮未激活时的附件图标颜色。
  static const Color inputAttachmentIdle = Color(0xFF79C6ED);

  /// 表情按钮激活时的浅色底。
  static const Color inputEmojiActionBackground = Color(0x1FF3B34F);

  /// 附件按钮激活时的浅色底。
  static const Color inputAttachmentActionBackground = Color(0x1F5BB8E8);

  /// 发送按钮未输入时的背景色。
  static const Color sendButtonDisabledBackground = Color(0xFF8FD3FF);

  /// 发送按钮输入后可发送时的背景色。
  static const Color sendButtonEnabledBackground = Color(0xFF169AF3);

  /// 发送按钮图标和文字颜色。
  static const Color sendButtonForeground = Color(0xFFFFFFFF);

  /// 发送按钮未输入时的图标和文字颜色。
  static const Color sendButtonDisabledForeground = Color(0xB8FFFFFF);

  // 附件面板

  /// 附件面板卡片背景色。
  static const Color attachmentPanelCardBackground = Color(0xFFFFFFFF);

  /// 附件面板卡片标题颜色。
  static const Color attachmentPanelCardText = Color(0xFF4B5563);

  /// 拍摄按钮功能色。
  static const Color attachmentCameraTint = Color(0xFFE18A55);

  /// 相册按钮功能色。
  static const Color attachmentGalleryTint = Color(0xFF5CA3E6);

  /// 文件按钮功能色。
  static const Color attachmentFileTint = Color(0xFF63B37C);

  /// 附件面板功能图标浅色底。
  static const Color attachmentActionTintBackground = Color(0x1FFFFFFF);

  // 待发送附件条

  /// 待发送附件区域背景色。
  static const Color pendingBarBackground = Color(0xFFF7F9FC);

  /// 待发送附件数量文字颜色。
  static const Color pendingBarTitle = Color(0xFF607086);

  /// 待发送附件“清空”按钮文字颜色。
  static const Color pendingBarClear = Color(0xFF8B5E66);

  /// 待发送附件卡片背景色。
  static const Color pendingCardBackground = Color(0xFFFFFFFF);

  /// 待发送附件文件类型图标底色。
  static const Color pendingCardFileTypeBackground = Color(0xFFF1F5FA);

  /// 待发送附件文件类型图标文字颜色。
  static const Color pendingCardFileTypeText = Color(0xFF445368);

  /// 待发送附件文件名颜色。
  static const Color pendingCardFileName = Color(0xFF1C2530);

  /// 待发送附件文件大小颜色。
  static const Color pendingCardFileMeta = Color(0xFF7C8899);

  /// 待发送附件删除按钮背景色。
  static const Color pendingCardRemoveBackground = Color(0xFF1F2937);

  // 消息流

  /// 系统提示消息气泡背景色。
  static const Color systemBubbleBackground = Color.fromARGB(
    255,
    247,
    247,
    249,
  );

  /// 系统提示消息文字颜色。
  static const Color systemBubbleText = Color(0xFF8A93A0);

  /// 自己发送的消息气泡背景色。
  static const Color outgoingBubbleBackground = Color(0xFF169AF3);

  /// 对方发送的消息气泡背景色。
  static const Color incomingBubbleBackground = Color(0xFFFFFFFF);

  /// 普通消息正文颜色。
  static const Color messageText = Color(0xFF262B31);

  /// 自己消息中的辅助文字颜色。
  static const Color outgoingMetaText = Color(0xB3FFFFFF);

  /// 自己消息中的次级辅助文字颜色。
  static const Color outgoingMetaTextSecondary = Color(0x99FFFFFF);

  /// 对方消息中的辅助文字颜色。
  static const Color incomingMetaText = Color(0xFF8E97A3);

  /// 对方消息中的次级辅助文字颜色。
  static const Color incomingMetaTextSecondary = Color(0xFFA9B1BB);

  /// 对方消息中的分隔线颜色。
  static const Color incomingDivider = Color(0xFFEAEEF3);

  /// 自己消息中的分隔线颜色。
  static const Color outgoingDivider = Color(0x24FFFFFF);

  /// 对方文件卡片背景色。
  static const Color incomingFileCardBackground = Color(0xFFF4F7FB);

  /// 自己文件卡片背景色。
  static const Color outgoingFileCardBackground = Color(0x29FFFFFF);

  /// 对方文件类型图标底色。
  static const Color incomingFileTypeBackground = Color(0xFFFFFFFF);

  /// 自己文件类型图标底色。
  static const Color outgoingFileTypeBackground = Color(0x3DFFFFFF);

  /// 对方文件类型图标文字颜色。
  static const Color incomingFileTypeText = Color(0xFF68727E);

  /// 对方进度条底色。
  static const Color incomingProgressBackground = Color(0xFFE7EBF0);

  /// 对方进度条前景色。
  static const Color incomingProgressValue = Color(0xFF169AF3);

  /// 自己进度条底色。
  static const Color outgoingProgressBackground = Color(0x2EFFFFFF);

  /// 自己进度条前景色。
  static const Color outgoingProgressValue = Color(0xFFFFFFFF);
}
