import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_failure.dart';
import '../domain/conversation.dart';
import 'conversation_repository.dart';

class SupabaseConversationRepository implements ConversationRepository {
  SupabaseConversationRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<List<ConversationSummary>> fetchConversations() => guard(() async {
    final rows = await _client.rpc('get_conversation_list') as List<dynamic>;
    return [
      for (final r in rows)
        ConversationSummary.fromJson(r as Map<String, dynamic>),
    ];
  });

  @override
  Stream<void> listChanges() {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    void ping([Object? _]) {
      if (!controller.isClosed) controller.add(null);
    }

    controller = StreamController<void>(
      onListen: () {
        final uid = _uid;
        channel = _client
            .channel('chat-list:$uid:${DateTime.now().microsecondsSinceEpoch}')
            // RLS limits these to conversations I'm in.
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'messages',
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'conversation_members',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: uid,
              ),
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'conversations',
              callback: ping,
            )
            .subscribe((status, [error]) {
              // Catch up on anything missed while (re)connecting.
              if (status == RealtimeSubscribeStatus.subscribed) ping();
            });
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }

  @override
  Future<String> getOrCreateDm(String otherUserId) => guard(() async {
    return await _client.rpc(
      'get_or_create_dm',
      params: {'other_user_id': otherUserId},
    ) as String;
  });

  @override
  Future<String> createGroup(String name, List<String> memberIds) =>
      guard(() async {
        return await _client.rpc(
          'create_group',
          params: {'group_name': name.trim(), 'member_ids': memberIds},
        ) as String;
      });

  @override
  Future<List<ConversationMember>> fetchMembers(String conversationId) =>
      guard(() async {
        final rows = await _client
            .from('conversation_members')
            .select('*, profile:profiles(*)')
            .eq('conversation_id', conversationId)
            .order('joined_at');
        return [for (final r in rows) ConversationMember.fromJson(r)];
      });

  @override
  Future<void> renameGroup(String conversationId, String name) =>
      guard(() async {
        await _client
            .from('conversations')
            .update({'name': name.trim()})
            .eq('id', conversationId);
      });

  @override
  Future<void> addMembers(String conversationId, List<String> userIds) =>
      guard(() async {
        if (userIds.isEmpty) return;
        await _client.from('conversation_members').upsert([
          for (final id in userIds)
            {'conversation_id': conversationId, 'user_id': id},
        ], ignoreDuplicates: true);
      });

  @override
  Future<void> removeMember(String conversationId, String userId) =>
      guard(() async {
        await _client
            .from('conversation_members')
            .delete()
            .eq('conversation_id', conversationId)
            .eq('user_id', userId);
      });

  @override
  Future<void> setRole(String conversationId, String userId, MemberRole role) =>
      guard(() async {
        await _client.rpc(
          'set_member_role',
          params: {
            'conv': conversationId,
            'member': userId,
            'new_role': role.name,
          },
        );
      });

  @override
  Future<void> markRead(String conversationId) => guard(() async {
    await _client.rpc('mark_read', params: {'conv': conversationId});
  });

  @override
  Future<String> createInvite(String conversationId) => guard(() async {
    return await _client.rpc('create_invite', params: {'conv': conversationId})
        as String;
  });

  @override
  Future<void> revokeInvites(String conversationId) => guard(() async {
    await _client.rpc('revoke_invites', params: {'conv': conversationId});
  });

  @override
  Future<InvitePreview?> getInvite(String token) => guard(() async {
    final rows = await _client.rpc(
      'get_invite',
      params: {'invite_token': token},
    ) as List<dynamic>;
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    return InvitePreview(
      conversationId: r['conversation_id'] as String,
      name: r['name'] as String? ?? 'Group',
      memberCount: (r['member_count'] as num).toInt(),
      isMember: r['is_member'] as bool,
    );
  });

  @override
  Future<String> joinViaInvite(String token) => guard(() async {
    return await _client.rpc('join_via_invite', params: {'invite_token': token})
        as String;
  });
}
