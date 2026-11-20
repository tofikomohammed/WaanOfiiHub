import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

class ChatRepository {
  final SupabaseClient? _client;

  ChatRepository(this._client);

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<List<Conversation>> getConversations() async {
    if (_client == null || currentUserId == null) return [];

    final res = await _client
        .from('conversation_members')
        .select('conversation:conversations(*)')
        .eq('user_id', currentUserId!)
        .order('joined_at', ascending: false);

    final List<Map<String, dynamic>> convJsons = [];
    final otherUserIds = <String>{};

    for (final item in (res as List)) {
      final convJson = item['conversation'] as Map<String, dynamic>?;
      if (convJson != null) {
        convJsons.add(convJson);
        if (convJson['type'] == 'direct') {
          final u1 = convJson['direct_user1'] as String?;
          final u2 = convJson['direct_user2'] as String?;
          final otherId = (u1 == currentUserId) ? u2 : u1;
          if (otherId != null && otherId.isNotEmpty) {
            otherUserIds.add(otherId);
          }
        }
      }
    }

    final Map<String, Map<String, dynamic>> profilesMap = {};
    if (otherUserIds.isNotEmpty) {
      try {
        final profilesRes = await _client
            .from('profiles')
            .select('id, display_name, avatar_url')
            .filter('id', 'in', otherUserIds.toList());
        for (final p in (profilesRes as List)) {
          profilesMap[p['id'] as String] = p as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    final List<Conversation> list = [];
    for (final convJson in convJsons) {
      if (convJson['type'] == 'direct') {
        final u1 = convJson['direct_user1'] as String?;
        final u2 = convJson['direct_user2'] as String?;
        final otherId = (u1 == currentUserId) ? u2 : u1;
        if (otherId != null && profilesMap.containsKey(otherId)) {
          convJson['other_user'] = profilesMap[otherId];
        }
      }
      list.add(Conversation.fromJson(convJson, currentUserId: currentUserId));
    }
    return list;
  }

  Future<Conversation?> getConversation(String conversationId) async {
    if (_client == null || currentUserId == null) return null;
    try {
      final res = await _client
          .from('conversations')
          .select('*')
          .eq('id', conversationId)
          .maybeSingle();
      if (res == null) return null;
      final convJson = Map<String, dynamic>.from(res);
      if (convJson['type'] == 'direct') {
        final u1 = convJson['direct_user1'] as String?;
        final u2 = convJson['direct_user2'] as String?;
        final otherId = (u1 == currentUserId) ? u2 : u1;
        if (otherId != null) {
          final profile = await _client
              .from('profiles')
              .select('id, display_name, avatar_url')
              .eq('id', otherId)
              .maybeSingle();
          if (profile != null) {
            convJson['other_user'] = profile;
          }
        }
      }
      return Conversation.fromJson(convJson, currentUserId: currentUserId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> startDirectChat(String targetUserId) async {
    if (_client == null) return null;
    final res = await _client.rpc(
      'start_direct_conversation',
      params: {'target_user_id': targetUserId},
    );
    return res as String?;
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    if (_client == null) return [];
    final res = await _client
        .from('messages')
        .select('*, profiles:sender_id(display_name, avatar_url)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (res as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Stream<List<ChatMessage>> streamMessages(String conversationId) async* {
    if (_client == null) return;

    // 1. Immediately yield messages from database so user sees chat without websocket latency
    List<ChatMessage> currentList = [];
    try {
      currentList = await getMessages(conversationId);
      yield currentList;
    } catch (_) {}

    // 2. Subscribe to Realtime postgres_changes stream
    bool realtimeActive = false;
    try {
      final stream = _client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      await for (final rawList in stream) {
        realtimeActive = true;
        currentList = rawList.map((e) => ChatMessage.fromJson(e)).toList();
        yield currentList;
      }
    } catch (_) {
      // Realtime publication not configured or disconnected
    }

    // 3. Fallback polling loop if Realtime is unavailable
    if (!realtimeActive) {
      while (true) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          final fresh = await getMessages(conversationId);
          yield fresh;
        } catch (_) {}
      }
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
    String type = 'text',
    String? mediaUrl,
    int? durationSeconds,
  }) async {
    if (_client == null) return;
    await _client.rpc(
      'send_chat_message',
      params: {
        'conv_id': conversationId,
        'msg_type': type,
        'msg_body': body,
        'media_url': mediaUrl,
        'media_dur': durationSeconds,
      },
    );
  }

  Future<void> createGroup({
    required String title,
    required List<String> memberIds,
    bool isCommunity = false,
  }) async {
    if (_client == null || currentUserId == null) return;

    final convRes = await _client
        .from('conversations')
        .insert({
          'type': isCommunity ? 'community' : 'group',
          'title': title,
          'created_by': currentUserId,
        })
        .select()
        .single();

    final convId = convRes['id'] as String;

    final members = [
      {'conversation_id': convId, 'user_id': currentUserId, 'role': 'owner'},
      ...memberIds.map(
        (uid) => {'conversation_id': convId, 'user_id': uid, 'role': 'member'},
      ),
    ];

    await _client.from('conversation_members').insert(members);
  }

  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String reportedUserId,
    required String reason,
  }) async {
    if (_client == null || currentUserId == null) return;
    await _client.from('reports').insert({
      'reporter_id': currentUserId,
      'conversation_id': conversationId,
      'message_id': messageId,
      'reported_user_id': reportedUserId,
      'reason': reason,
    });
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = isSupabaseInitialized
      ? ref.watch(supabaseClientProvider)
      : null;
  return ChatRepository(client);
});

final conversationsListProvider = FutureProvider<List<Conversation>>((
  ref,
) async {
  return ref.watch(chatRepositoryProvider).getConversations();
});
