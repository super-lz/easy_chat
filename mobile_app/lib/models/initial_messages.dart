import 'chat_message.dart';

const initialMessages = <ChatMessage>[
  ChatMessage(
    id: 'system-ready',
    sender: 'system',
    text: '扫描网页二维码后即可开始直连。',
    isSystem: true,
  ),
];
