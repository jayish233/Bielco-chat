import '../domain/conversation.dart';

abstract interface class ConversationRepository {
  /// Every conversation I'm in, most recent first.
  Future<List<ConversationSummary>> fetchConversations();

  /// Emits whenever something that changes the chat list happens (a new
  /// message, joining/leaving, a rename). Listening opens a realtime channel.
  Stream<void> listChanges();

  Future<String> getOrCreateDm(String otherUserId);
  Future<String> createGroup(String name, List<String> memberIds);

  Future<List<ConversationMember>> fetchMembers(String conversationId);
  Future<void> renameGroup(String conversationId, String name);
  Future<void> addMembers(String conversationId, List<String> userIds);
  Future<void> removeMember(String conversationId, String userId);
  Future<void> setRole(String conversationId, String userId, MemberRole role);

  Future<void> markRead(String conversationId);

  /// Returns the group's active invite token, creating one if needed.
  Future<String> createInvite(String conversationId);
  Future<void> revokeInvites(String conversationId);

  /// Null when the token is unknown, revoked or expired.
  Future<InvitePreview?> getInvite(String token);

  /// Joins and returns the conversation id.
  Future<String> joinViaInvite(String token);
}
