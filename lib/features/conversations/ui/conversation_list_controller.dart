import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/conversation.dart';

/// The chat list, kept live: any relevant realtime change triggers a
/// (debounced) refetch of `get_conversation_list()`.
class ConversationListController
    extends AsyncNotifier<List<ConversationSummary>> {
  Timer? _debounce;

  @override
  Future<List<ConversationSummary>> build() async {
    if (ref.watch(myUserIdProvider) == null) return const [];
    final repo = ref.watch(conversationRepositoryProvider);
    final sub = repo.listChanges().listen((_) => _scheduleRefresh());
    ref.onDispose(() {
      sub.cancel();
      _debounce?.cancel();
    });
    return repo.fetchConversations();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), refresh);
  }

  /// Refetches without dropping the current list (errors keep the old data).
  Future<void> refresh() async {
    try {
      final list = await ref
          .read(conversationRepositoryProvider)
          .fetchConversations();
      if (ref.mounted) state = AsyncData(list);
    } catch (e, st) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    }
  }

  /// Clears a badge right away while `mark_read` is in flight.
  void markReadLocally(String conversationId) {
    final list = state.asData?.value;
    if (list == null) return;
    state = AsyncData([
      for (final c in list)
        c.id == conversationId && c.unreadCount > 0
            ? c.copyWith(unreadCount: 0)
            : c,
    ]);
  }
}

final conversationListProvider =
    AsyncNotifierProvider<
      ConversationListController,
      List<ConversationSummary>
    >(ConversationListController.new);

/// One conversation from the list, or null while loading / if not a member.
final conversationProvider = Provider.family<ConversationSummary?, String>((
  ref,
  id,
) {
  final list = ref.watch(conversationListProvider).asData?.value;
  if (list == null) return null;
  for (final c in list) {
    if (c.id == id) return c;
  }
  return null;
});

final totalUnreadProvider = Provider<int>((ref) {
  final list = ref.watch(conversationListProvider).asData?.value ?? const [];
  return list.fold(0, (sum, c) => sum + c.unreadCount);
});
