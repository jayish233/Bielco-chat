import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'presence_service.dart';

class SupabasePresenceService implements PresenceService {
  SupabasePresenceService(this._client);

  final SupabaseClient _client;

  @override
  Stream<Set<String>> watchOnline() {
    late final RealtimeChannel channel;
    late final StreamController<Set<String>> controller;
    controller = StreamController<Set<String>>(
      onListen: () {
        final uid = _client.auth.currentUser?.id;
        channel = _client.channel(
          'online',
          opts: RealtimeChannelConfig(key: uid ?? ''),
        );
        void sync() {
          if (controller.isClosed) return;
          controller.add({
            for (final s in channel.presenceState())
              for (final p in s.presences)
                if (p.payload['user_id'] case final String id) id,
          });
        }

        channel
            .onPresenceSync((_) => sync())
            .onPresenceJoin((_) => sync())
            .onPresenceLeave((_) => sync())
            .subscribe((status, [_]) async {
              if (status == RealtimeSubscribeStatus.subscribed && uid != null) {
                await channel.track({'user_id': uid});
              }
            });
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }

  @override
  Stream<bool> watchConnection() async* {
    var last = true;
    var downFor = 0;
    yield true;
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 2))) {
      final up = _client.realtime.isConnected;
      downFor = up ? 0 : downFor + 1;
      final next = up || downFor < 2;
      if (next != last) {
        last = next;
        yield next;
      }
    }
  }

  @override
  TypingSession openTyping(String conversationId) =>
      _SupabaseTypingSession(_client, conversationId);
}

class _SupabaseTypingSession implements TypingSession {
  _SupabaseTypingSession(this._client, String conversationId)
    : _me = _client.auth.currentUser?.id ?? '' {
    _channel = _client
        .channel('typing:$conversationId')
        .onBroadcast(event: 'typing', callback: _onTyping)
        .subscribe();
  }

  static const _expiry = Duration(seconds: 5);
  static const _throttle = Duration(seconds: 2);

  final SupabaseClient _client;
  final String _me;
  late final RealtimeChannel _channel;
  final _typers = <String, Timer>{};
  final _controller = StreamController<Set<String>>.broadcast();
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<Set<String>> get typers => _controller.stream;

  void _onTyping(Map<String, dynamic> message) {
    final data = message['payload'] is Map
        ? (message['payload'] as Map).cast<String, dynamic>()
        : message;
    final id = data['user_id'] as String?;
    if (id == null || id == _me) return;
    _typers.remove(id)?.cancel();
    if (data['typing'] == true) {
      _typers[id] = Timer(_expiry, () {
        _typers.remove(id);
        _emit();
      });
    }
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(_typers.keys.toSet());
  }

  void _send(bool typing) {
    _channel
        .sendBroadcastMessage(
          event: 'typing',
          payload: {'user_id': _me, 'typing': typing},
        )
        .ignore();
  }

  @override
  void typing() {
    final now = DateTime.now();
    if (now.difference(_lastSent) < _throttle) return;
    _lastSent = now;
    _send(true);
  }

  @override
  void stopped() {
    if (_lastSent.millisecondsSinceEpoch == 0) return;
    _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
    _send(false);
  }

  @override
  Future<void> close() async {
    for (final t in _typers.values) {
      t.cancel();
    }
    await _controller.close();
    await _client.removeChannel(_channel);
  }
}
