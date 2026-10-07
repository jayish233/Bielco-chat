/// Live, never-persisted signals: who is online and who is typing.
abstract interface class PresenceService {
  /// Ids of signed-in people with the app open (including me). Listening
  /// announces me as online until the subscription is cancelled.
  Stream<Set<String>> watchOnline();

  /// Whether the realtime connection is up. Starts `true`; only reports
  /// `false` after the connection has been down for a few seconds.
  Stream<bool> watchConnection();

  /// Typing in one conversation.
  TypingSession openTyping(String conversationId);
}

abstract interface class TypingSession {
  /// Ids of other people currently typing.
  Stream<Set<String>> get typers;

  /// Call on each keystroke; throttled internally.
  void typing();

  /// Call when the draft is sent or cleared.
  void stopped();

  Future<void> close();
}
