import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../blog/presentation/widgets/audio_player_widget.dart';
import '../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat.jm().format(message.createdAt);

    final bg = isMe
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe && message.senderName != null) ...[
                Text(
                  message.senderName!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (message.deletedForEveryone)
                Text(
                  '🚫 This message was deleted',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: fg.withAlpha(153),
                  ),
                )
              else ...[
                if (message.type == 'image' && message.mediaPath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: message.mediaPath!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (message.type == 'audio' && message.mediaPath != null) ...[
                  AudioPlayerWidget(audioUrl: message.mediaPath!),
                  const SizedBox(height: 6),
                ],
                if (message.body.isNotEmpty)
                  Text(
                    message.body,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                  ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: fg.withAlpha(179),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.isRead ? Colors.blue : fg.withAlpha(179),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
