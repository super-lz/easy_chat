import 'package:flutter/material.dart';

import '../../../models/chat_message.dart';

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    super.key,
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isPhone = message.sender == 'phone';
    final isImage = message.mimeType?.startsWith('image/') ?? false;

    if (message.isSystem) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            message.text,
            style: const TextStyle(color: Color(0xFF6C675E)),
          ),
        ),
      );
    }

    return Align(
      alignment: isPhone ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPhone ? const Color(0xFF1D1D1F) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: isPhone ? null : Border.all(color: const Color(0xFFDEDAD2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage && message.bytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  message.bytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: isPhone ? Colors.white : const Color(0xFF1E1E1A),
                fontWeight:
                    message.bytes != null ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (message.meta != null) ...[
              const SizedBox(height: 6),
              Text(
                message.meta!,
                style: TextStyle(
                  color: isPhone ? Colors.white70 : const Color(0xFF6C675E),
                  fontSize: 12,
                ),
              ),
            ],
            if (message.savedPath != null) ...[
              const SizedBox(height: 6),
              Text(
                message.savedPath!,
                style: TextStyle(
                  color: isPhone ? Colors.white70 : const Color(0xFF6C675E),
                  fontSize: 11,
                ),
              ),
            ],
            if (message.progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: message.progress,
                  minHeight: 6,
                  backgroundColor:
                      isPhone ? Colors.white24 : const Color(0x1A1E1E1A),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPhone ? Colors.white : const Color(0xFF1D1D1F),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
