# Group Chat App — Flutter + Supabase: Design & Build Plan

## Context
The user is building a chat app for their group, solo, using Flutter + Supabase. The repo at
`/Users/jayish/Chat-app/chatapp` is a fresh `flutter create` template (default `lib/main.dart`,
only `cupertino_icons` dependency, Dart SDK ^3.13.5, not a git repo, Supabase CLI not installed).
Goal of this plan: lock the product scope and technical architecture so the next step — UI design —
starts from an agreed foundation.

### Brief (confirmed with user)
- WhatsApp-style: **group chats + 1:1 DMs**.
- v1 features: text, **image/file sharing**, **push notifications**, **read receipts + typing + online**,
  **reactions, reply-to, edit/delete**.
- Auth: **email + password, open signup**; find people by username.
- Platforms: **Android + iOS + Web**.
- Solo developer → Riverpod, feature-first structure.
- Assumptions: small user base (tens of users); Supabase free tier + free Firebase project (FCM only);
  success = the group uses it daily on their phones.

## Architecture (Supabase-native — chosen)
```
Flutter (Riverpod, go_router, supabase_flutter, firebase_messaging)
  └─► Supabase: Auth · Postgres+RLS · Realtime (postgres_changes + Presence) · Storage · Edge Functions
                                                     DB webhook on messages INSERT ─► send-push ─► FCM v1 ─► devices
```

## Data model (`supabase/migrations/`)
| table | key columns |
|---|---|
| `profiles` | `id` (=auth.users.id), `username` unique, `display_name`, `avatar_url`, `last_seen_at` |
| `conversations` | `id`, `type` ('direct'\|'group'), `name`, `avatar_url`, `created_by`, `created_at`, `last_message_at` |
| `conversation_members` | PK(`conversation_id`,`user_id`), `role` ('admin'\|'member'), `last_read_at`, `joined_at` |
| `messages` | `id`, `conversation_id`, `sender_id`, `body`, `reply_to_id`→messages, `attachment_path/type/name/size`, `created_at`, `edited_at`, `deleted_at` (soft delete) |
| `message_reactions` | PK(`message_id`,`user_id`,`emoji`) |
| `device_tokens` | `user_id`, `token` unique, `platform`, `updated_at` |

Indexes: `messages(conversation_id, created_at desc)`, `conversation_members(user_id)`.

**RLS**: `is_member(conv_id)` SECURITY DEFINER helper gates conversations/members/messages/reactions.
Only the sender may update (edit/soft-delete) a message. Only admins may add or remove members and rename
the group. Users may leave a group (delete their own member row). `profiles` are readable by any
authenticated user; each user writes only their own profile. `device_tokens` are owner-only.

**RPCs**: `get_or_create_dm(other_user_id)` (dedupes DMs), `create_group(name, member_ids[])`,
`mark_read(conv_id)`, `get_conversation_list()` (last message + unread count, ordered by `last_message_at`).

**Triggers**: on `auth.users` insert → create profile (username from signup metadata);
on `messages` insert → bump `conversations.last_message_at`.

**Read receipts** = compare `messages.created_at` with each member's `last_read_at`, which gives ✓✓ in DMs
and "Seen by N" in groups.

**Storage**: private bucket `attachments`, path `{conversation_id}/{uuid}.{ext}`; storage RLS checks
`is_member((storage.foldername(name))[1]::uuid)`; the client shows files via signed URLs. Avatars go in a public `avatars` bucket.

## Realtime
- Chat screen: `postgres_changes` on `messages` filtered `conversation_id=eq.<id>` (insert/update), plus `message_reactions`.
  Add `messages`, `message_reactions` and `conversation_members` to the `supabase_realtime` publication.
- Chat list: subscribe to own `conversation_members` changes and new messages, then refetch `get_conversation_list()`.
- Typing/online: Realtime **Presence** + broadcast on channel `conv:<id>`; never persisted. `last_seen_at`
  is updated on app pause.
- Pagination: keyset on `created_at`, 50 per page. Optimistic send with a client-generated UUID → states `sending` / `failed` (with retry).

## Push
- `firebase_messaging` + `flutterfire configure` (Android, iOS, Web). Upsert token into `device_tokens`
  on login and on token refresh; delete it on logout.
- Database webhook (messages INSERT) → Edge Function `supabase/functions/send-push` (Deno):
  fetch member tokens excluding the sender → FCM HTTP v1 (service-account JSON stored as a Supabase secret) →
  prune tokens FCM reports as invalid. Payload carries `conversation_id` so a tap opens the right chat (go_router).
- Web: `web/firebase-messaging-sw.js` + VAPID key. iOS: APNs key in Firebase, Push + Background
  Modes capabilities; test on a real device (needs a paid Apple Developer account).

## Flutter structure (`lib/`)
```
main.dart, app.dart (MaterialApp.router, theme)
core/      supabase_client.dart, router.dart, env.dart (--dart-define SUPABASE_URL/ANON_KEY), utils
features/
  auth/           data/auth_repository.dart, providers, ui/{sign_in,sign_up}_screen.dart
  profile/        data/profile_repository.dart, ui/profile_screen.dart, user_search
  conversations/  data/conversation_repository.dart, ui/{chat_list,new_dm,new_group,group_info}_screen.dart
  chat/           data/message_repository.dart, presence_service.dart, ui/chat_screen.dart, widgets/{bubble,composer,reply_preview,reaction_bar,attachment_view}
  notifications/  push_service.dart
```
Packages: `supabase_flutter`, `flutter_riverpod` (+ `riverpod_annotation`/generator), `go_router`,
`firebase_core`, `firebase_messaging`, `image_picker`, `file_picker`, `cached_network_image`,
`flutter_image_compress` (mobile only), `intl`, `uuid`. Repositories return typed models; UI never calls Supabase directly.
On web, `file_picker` returns bytes instead of file paths, so uploads use `uploadBinary`.

## Milestones (each ends with a runnable app)
1. **Foundation**: install Supabase CLI, `supabase init`, local stack, migrations + RLS + triggers + pgTAP
   RLS tests; Flutter deps, env config, theme, router with auth redirect, sign-up/in/out, profile edit.
2. **Core chat**: user search, DM creation, group creation and member management, chat list, realtime
   text messaging, pagination, optimistic send.
3. **Media**: image and file pick/compress/upload on all platforms, inline previews, full-screen image viewer, file download.
4. **Interactions**: reply-to, edit/delete, reactions, read receipts, unread badges, typing + online presence.
5. **Push**: Firebase project, tokens, `send-push` Edge Function + webhook, open the chat on notification tap. Order: Android → Web → iOS.

## Immediate next steps after approval
1. `git init` in the repo (with the user's OK) and save this design as
   `docs/superpowers/specs/2026-10-06-group-chat-design.md`; the user reviews it.
2. **UI design phase** (what the user asked for next): screen list = sign-in, sign-up, chat list, new DM,
   new group, chat (bubbles, composer, reply/reaction states, attachments), group info, profile.
   Decide on visual style/tool (e.g. Figma or in-code mockups) with the user.
3. Then the writing-plans skill → a detailed task-by-task implementation plan for Milestone 1.

## Verification
- `supabase start` + `supabase db reset` applies migrations cleanly; `supabase test db` passes the pgTAP RLS tests
  (non-member can't read/insert messages; non-sender can't edit; non-admin can't add members).
- `flutter analyze` clean; `flutter test` (repository unit tests with mocked client, widget tests for key screens).
- Manual end-to-end per milestone: two accounts on two devices/emulators (+ a Chrome tab): DM and group
  messaging appears live, attachments open, receipts/typing update, push arrives with the app in the background and opens the right chat.
