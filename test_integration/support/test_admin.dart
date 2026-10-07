import 'package:chatapp/core/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service-role helper for tests against the local stack: puts test emails on
/// the company allowlist and removes everything the tests created.
///
/// Needs `--dart-define-from-file=env/test.json` (service_role key from
/// `supabase status`). Never use this key in the app.
class TestAdmin {
  TestAdmin()
    : _client = SupabaseClient(
        resolveEnv().url,
        _serviceKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ) {
    if (_serviceKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_SERVICE_ROLE_KEY. Run the tests with '
        '--dart-define-from-file=env/local.json '
        '--dart-define-from-file=env/test.json',
      );
    }
  }

  static const _serviceKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
  );

  final SupabaseClient _client;
  final _emails = <String>{};

  /// A fresh `@example.com` address that is allowed to sign up.
  Future<String> allowedEmail(String prefix) async {
    final n = DateTime.now().microsecondsSinceEpoch;
    final email = '$prefix-$n@example.com';
    await allow(email);
    return email;
  }

  Future<void> allow(String email) async {
    final e = email.trim().toLowerCase();
    _emails.add(e);
    await _client.from('allowed_emails').upsert({'email': e, 'note': 'test'});
  }

  Future<void> disallow(String email) => _client
      .from('allowed_emails')
      .delete()
      .eq('email', email.trim().toLowerCase());

  /// Removes test accounts (`@example.com`) left by an earlier, interrupted
  /// run. Real accounts never use that domain.
  Future<void> sweepLeftovers() async {
    final users = await _client.auth.admin.listUsers(perPage: 1000);
    for (final u in users) {
      final e = u.email?.toLowerCase();
      if (e != null && e.endsWith('@example.com')) _emails.add(e);
    }
    final listed = await _client.from('allowed_emails').select('email');
    for (final r in listed) {
      final e = r['email'] as String;
      if (e.endsWith('@example.com')) _emails.add(e);
    }
    await cleanUp();
  }

  /// Deletes the test users (and their chats, files, list entries).
  Future<void> cleanUp() async {
    if (_emails.isEmpty) return;
    final users = await _client.auth.admin.listUsers(perPage: 1000);
    final ids = [
      for (final u in users)
        if (_emails.contains(u.email?.toLowerCase())) u.id,
    ];
    if (ids.isNotEmpty) {
      final memberRows = await _client
          .from('conversation_members')
          .select('conversation_id')
          .inFilter('user_id', ids);
      final created = await _client
          .from('conversations')
          .select('id')
          .inFilter('created_by', ids);
      final convs = {
        for (final r in [...memberRows]) r['conversation_id'] as String,
        for (final r in created) r['id'] as String,
      }.toList();
      for (final c in convs) {
        await _removeFolder('attachments', c);
      }
      if (convs.isNotEmpty) {
        await _client.from('conversations').delete().inFilter('id', convs);
      }
      await _client.from('messages').delete().inFilter('sender_id', ids);
      for (final id in ids) {
        await _removeFolder('avatars', id);
        await _client.auth.admin.deleteUser(id);
      }
    }
    await _client
        .from('allowed_emails')
        .delete()
        .inFilter('email', _emails.toList());
    _emails.clear();
  }

  Future<void> _removeFolder(String bucket, String folder) async {
    final files = await _client.storage.from(bucket).list(path: folder);
    if (files.isEmpty) return;
    await _client.storage.from(bucket).remove([
      for (final f in files) '$folder/${f.name}',
    ]);
  }

  Future<void> dispose() => _client.dispose();
}
