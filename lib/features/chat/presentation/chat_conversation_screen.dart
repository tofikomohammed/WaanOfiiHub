import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/loading_indicator.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'widgets/message_bubble.dart';
import 'widgets/voice_recorder_widget.dart';

final chatMessagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, convId) {
      return ref.watch(chatRepositoryProvider).streamMessages(convId);
    });

final conversationDetailsProvider =
    FutureProvider.family<Conversation?, String>((ref, convId) {
      return ref.watch(chatRepositoryProvider).getConversation(convId);
    });

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(conversationId: widget.conversationId, body: text);
      ref.invalidate(chatMessagesStreamProvider(widget.conversationId));
      ref.invalidate(conversationsListProvider);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      chatMessagesStreamProvider(widget.conversationId),
    );
    final convAsync = ref.watch(
      conversationDetailsProvider(widget.conversationId),
    );
    final convTitle = convAsync.valueOrNull?.title ?? 'Chat';
    final currentUserId = ref.watch(chatRepositoryProvider).currentUserId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(convTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(chatMessagesStreamProvider(widget.conversationId));
              ref.invalidate(
                conversationDetailsProvider(widget.conversationId),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const LoadingIndicator(message: 'Loading conversation...'),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Connecting to chat...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        onPressed: () => ref.invalidate(
                          chatMessagesStreamProvider(widget.conversationId),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Say hello! No messages sent yet.'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return MessageBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  VoiceRecorderWidget(
                    onRecordingComplete: (path) async {
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .sendMessage(
                              conversationId: widget.conversationId,
                              body: '🎵 Voice Message',
                              type: 'audio',
                              mediaUrl: path,
                            );
                        ref.invalidate(
                          chatMessagesStreamProvider(widget.conversationId),
                        );
                        ref.invalidate(conversationsListProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send voice note: $e'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSendText(),
                    ),
                  ),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    onPressed: _isSending ? null : _handleSendText,
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
