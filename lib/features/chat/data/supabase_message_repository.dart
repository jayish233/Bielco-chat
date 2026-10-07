import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app_failure.dart';
import '../domain/message.dart';
import 'message_repository.dart';

class SupabaseMessageRepository implements MessageRepository {
  SupabaseMessageRepository(this._client);

  final SupabaseClient _client;
  final _urls = <String, ({String url, DateTime expires})>{};

  StorageFileApi get _bucket => _client.storage.from('attachments');

  @override
  Future<List<Message>> fetchPage(String conversationId, {DateTime? before}) =>
      guard(() async {
        var q = _client
            .from('messages')
            .select(Message.select)
            .eq('conversation_id', conversationId);
        if (before != null) {
          q = q.lt('created_at', before.toUtc().toIso8601String());
        }
        final rows = await q
            .order('created_at', ascending: false)
            .limit(MessageRepository.pageSize);
        return [for (final r in rows) Message.fromJson(r)];
      });

  @override
  Future<Message?> fetchMessage(String messageId) => guard(() async {
    final row = await _client
        .from('messages')
        .select(Message.select)
        .eq('id', messageId)
        .maybeSingle();
    return row == null ? null : Message.fromJson(row);
  });

  @override
  Future<Message> send(OutgoingMessage m) => guard(() async {
    final a = m.attachment;
    String? path;
    if (a != null) {
      path = '${m.conversationId}/${const Uuid().v4()}.${a.extension}';
      await _bucket.uploadBinary(
        path,
        a.bytes,
        fileOptions: FileOptions(contentType: a.contentType),
      );
    }
    final attachment = a == null
        ? null
        : Attachment(
            path: path!,
            kind: a.kind,
            durationMs: a.durationMs,
            waveform: a.waveform,
            width: a.width,
            height: a.height,
          );
    final body = m.body?.trim();
    try {
      final row = await _client
          .from('messages')
          .insert({
            'id': m.id,
            'conversation_id': m.conversationId,
            if (body != null && body.isNotEmpty) 'body': body,
            'reply_to_id': ?m.replyToId,
            if (a != null) ...{
              'attachment_path': path,
              'attachment_type': a.kind.name,
              'attachment_name': a.name,
              'attachment_size': a.bytes.length,
              'attachment_meta': attachment!.metaJson,
            },
          })
          .select(Message.select)
          .single();
      return Message.fromJson(row);
    } on PostgrestException catch (e) {
      // A retry after a lost response: the row is already there.
      if (e.code == '23505') {
        final existing = await fetchMessage(m.id);
        if (existing != null) return existing;
      }
      if (path != null) unawaited(_removeQuietly(path));
      rethrow;
    }
  });

  Future<void> _removeQuietly(String path) async {
    try {
      await _bucket.remove([path]);
    } catch (_) {}
  }

  @override
  Future<void> edit(String messageId, String body) => guard(() async {
    await _client
        .from('messages')
        .update({'body': body.trim()})
        .eq('id', messageId);
  });

  @override
  Future<void> delete(Message message) => guard(() async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', message.id);
    final path = message.attachment?.path;
    if (path != null) await _removeQuietly(path);
  });

  @override
  Future<List<Reaction>> fetchReactions(List<String> messageIds) =>
      guard(() async {
        if (messageIds.isEmpty) return const [];
        final rows = await _client
            .from('message_reactions')
            .select('message_id, user_id, emoji')
            .inFilter('message_id', messageIds)
            .order('created_at');
        return [for (final r in rows) Reaction.fromJson(r)];
      });

  @override
  Future<void> addReaction(String messageId, String emoji) => guard(() async {
    await _client.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': _client.auth.currentUser!.id,
      'emoji': emoji,
    }, ignoreDuplicates: true);
  });

  @override
  Future<void> removeReaction(String messageId, String emoji) =>
      guard(() async {
        await _client
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', _client.auth.currentUser!.id)
            .eq('emoji', emoji);
      });

  @override
  Future<String> attachmentUrl(String path) => guard(() async {
    final cached = _urls[path];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.url;
    }
    final url = await _bucket.createSignedUrl(path, 60 * 60);
    _urls[path] = (
      url: url,
      expires: DateTime.now().add(const Duration(minutes: 50)),
    );
    return url;
  });

  @override
  Stream<ChatEvent> watch(String conversationId) {
    late final RealtimeChannel channel;
    late final StreamController<ChatEvent> controller;
    void emit(ChatEvent e) {
      if (!controller.isClosed) controller.add(e);
    }

    final byConversation = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: conversationId,
    );
    controller = StreamController<ChatEvent>(
      onListen: () {
        var subscribedOnce = false;
        channel = _client
            .channel(
              'chat:$conversationId:${DateTime.now().microsecondsSinceEpoch}',
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: byConversation,
              callback: (p) {
                final id = (p.newRecord['id'] ?? p.oldRecord['id']) as String?;
                if (id != null) emit(MessageChanged(id));
              },
            )
            // Reactions can't be filtered by conversation; the controller
            // ignores ones for messages it doesn't have.
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'message_reactions',
              callback: (p) =>
                  emit(ReactionAdded(Reaction.fromJson(p.newRecord))),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'message_reactions',
              callback: (p) {
                final r = p.oldRecord;
                if (r['message_id'] != null && r['emoji'] != null) {
                  emit(ReactionRemoved(Reaction.fromJson(r)));
                }
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'conversation_members',
              filter: byConversation,
              callback: (_) => emit(const MembersChanged()),
            )
            .subscribe((status, [error]) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                if (subscribedOnce) emit(const Resubscribed());
                subscribedOnce = true;
              }
            });
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }
}
