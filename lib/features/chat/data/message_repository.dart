import '../domain/message.dart';

/// Something that changed in an open conversation.
sealed class ChatEvent {
  const ChatEvent();
}

/// A message was inserted or updated (edited, deleted); refetch it by id.
class MessageChanged extends ChatEvent {
  const MessageChanged(this.messageId);
  final String messageId;
}

class ReactionAdded extends ChatEvent {
  const ReactionAdded(this.reaction);
  final Reaction reaction;
}

class ReactionRemoved extends ChatEvent {
  const ReactionRemoved(this.reaction);
  final Reaction reaction;
}

/// Someone joined, left, changed role or read up to a new point.
class MembersChanged extends ChatEvent {
  const MembersChanged();
}

/// The realtime channel (re)connected; refetch the newest page to catch up.
class Resubscribed extends ChatEvent {
  const Resubscribed();
}

abstract interface class MessageRepository {
  static const pageSize = 50;

  /// Newest-first page of messages older than [before] (or the newest page).
  Future<List<Message>> fetchPage(String conversationId, {DateTime? before});

  Future<Message?> fetchMessage(String messageId);

  /// Uploads the attachment (if any), then inserts the message.
  Future<Message> send(OutgoingMessage message);

  Future<void> edit(String messageId, String body);

  /// Soft-deletes and removes the attachment object, if any.
  Future<void> delete(Message message);

  Future<List<Reaction>> fetchReactions(List<String> messageIds);
  Future<void> addReaction(String messageId, String emoji);
  Future<void> removeReaction(String messageId, String emoji);

  /// A short-lived URL for a private attachment.
  Future<String> attachmentUrl(String path);

  /// Live changes for one conversation.
  Stream<ChatEvent> watch(String conversationId);
}
