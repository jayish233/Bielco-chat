# Milestone 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A runnable Relay app on Android, iOS and web where a person can sign up (name, username, email, password),
sign in, edit their profile and sign out, against a local Supabase stack whose full v1 schema and RLS are tested.

**Architecture:** Supabase local stack (`supabase/`) holds migrations, RLS and pgTAP tests. Flutter app is feature-first
(`lib/core`, `lib/features/<feature>/{data,domain,ui}`), Riverpod (no codegen) for DI/state, go_router with an
auth-driven redirect. Repositories are interfaces with a Supabase implementation; widget tests use fakes; a separate
`test_integration/` suite runs the Supabase implementations against the local stack.

**Tech Stack:** Flutter 3.47 / Dart ^3.13, supabase_flutter, flutter_riverpod, go_router, Supabase CLI + Docker, pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-06-group-chat-design.md` (read the "Decisions after the UI handoff" section),
visual spec `CLAUDE.md` + `tokens.json` + `screens/{Web,iOS,Android}{SignIn,SignUp}.dc.html`.

## Global Constraints

- App name only via `appName` in `lib/core/constants.dart` (value `'Relay'`); no other hard-coded "Relay" in Dart.
- All colors/sizes/radii come from `lib/core/theme/tokens.dart`, which mirrors `tokens.json` exactly. No raw hex in widgets.
- Fonts: Geist 400/500/600 and Geist Mono 400/500, bundled as static TTFs in `assets/fonts/` (no runtime font fetching).
- Accessibility: every icon-only button has a `tooltip` (which provides its semantics label); touch targets ≥44px on iOS/Android; text colors ≥4.5:1 against their background in both themes.
- Usernames: lowercase `^[a-z0-9_]{3,20}$`, unique. Display names: 1–50 chars after trim. Passwords: ≥8 chars with ≥1 letter and ≥1 digit.
- Message body ≤4000 chars. Attachment types `image | file | audio`.
- UI never calls Supabase directly — only through repositories in `features/*/data/`.
- Secrets: `env/*.json` is gitignored except `env/example.json`.
- Out of scope here (later milestones per the spec): the RPCs `get_or_create_dm`, `create_group`, `mark_read`, `get_conversation_list`, `join_via_invite`, the realtime publication, storage buckets, password reset, avatar upload.
- Work on branch `m1-foundation`; commit after each task with the attribution trailer from the session.

## Review Focus

1. **Username taken at submit time** (case variant like `Priya` vs `priya`, or a race after the live check said "available") → sign-up shows "That username is taken." on the username field, not a generic error. *Pinned in Task 5 (integration) and Task 8 (widget).*
2. **Server unreachable during sign-in/sign-up** → a readable network message appears and the button becomes tappable again. *Pinned in Task 7.*
3. **Double-tap on the primary button** → exactly one auth request. *Pinned in Task 7.*
4. **Session ends elsewhere** (sign-out on another tab, refresh-token expiry) while on `/profile` → app lands on `/sign-in` without a stale screen. *Pinned in Task 6.*
5. **Email typed with spaces/uppercase** (`  Priya@Example.com `) → submitted trimmed; sign-in still works. *Pinned in Task 7.*

---

## Prerequisites (person running the plan, once)

- [ ] Install a Docker runtime and start it (Docker Desktop or OrbStack). Check: `docker info` exits 0.
- [ ] `brew install supabase/tap/supabase`. Check: `supabase --version` prints ≥2.x.
- [ ] `git checkout -b m1-foundation`, then commit the untracked design handoff as-is: `git add CLAUDE.md tokens.css tokens.json screens docs && git commit -m "docs: add Relay design handoff, decisions and M1 plan"`.

---

### Task 1: Supabase stack + v1 schema, triggers, helpers

**Files:**
- Create: `supabase/` via `supabase init` (commit `config.toml`, `migrations/`, `tests/`; `.gitignore` the CLI's `.branches`/`.temp`)
- Create: `supabase/migrations/20261006000001_schema.sql`
- Test: `supabase/tests/01_schema_test.sql`

**Interfaces:**
- Produces (SQL, used by Task 2, Task 5 and later milestones):
  tables `public.profiles, conversations, conversation_members, messages, message_reactions, device_tokens`;
  functions `public.is_member(conv uuid) returns boolean`, `public.is_admin(conv uuid) returns boolean`,
  `public.username_available(name text) returns boolean` (granted to `anon, authenticated`).
  Sign-up metadata keys read by the profile trigger: `username`, `display_name`.

- [ ] **Step 1: `supabase init`, then edit `supabase/config.toml`**

`[auth]`: `site_url = "http://localhost:3000"`, `minimum_password_length = 8`, `password_requirements = "letters_digits"`.
`[auth.email]`: `enable_confirmations = false` (local only). Run `supabase start` and note the API URL and anon key it prints.

- [ ] **Step 2: Write the failing pgTAP test `supabase/tests/01_schema_test.sql`**

Wrap in `begin; select plan(N); … select * from finish(); rollback;`. Create users with
`insert into auth.users (id, email, raw_user_meta_data) values (…, '{"username":"…","display_name":"…"}')`.
Assertions (one pgTAP call each):

```sql
-- profile trigger
select is((select username from profiles where id = :'u1'), 'priya', 'profile created from signup metadata');
select is((select display_name from profiles where id = :'u1'), 'Priya Sharma', 'display name copied');
select is((select username from profiles where id = :'u_meta_upper'), 'aisha', 'username lowercased by trigger');
select matches((select username from profiles where id = :'u_nometa'), '^user_[0-9a-f]{8}$', 'fallback username when metadata missing');
-- constraints
select throws_ok($$update profiles set username = 'Bad Name' where id = '…u1…'$$, '23514', null, 'username format enforced');
select throws_ok($$insert into auth.users (id, email, raw_user_meta_data) values (gen_random_uuid(), 'x@x.com', '{"username":"priya"}')$$, '23505', null, 'duplicate username rejected');
-- username_available
select is(username_available('priya'), false);
select is(username_available('Priya'), false, 'case-insensitive');
select is(username_available('free_name'), true);
select is(username_available('ab'), false, 'invalid format is never available');
-- messages
select throws_ok($$insert into messages (conversation_id, sender_id, body) values (:conv, :u1, '   ')$$, '23514', null, 'blank message without attachment rejected');
select throws_ok($$insert into messages (conversation_id, sender_id, body) values (:conv, :u1, repeat('a', 4001))$$, '23514');
select ok((select last_message_at from conversations where id = :conv) = (select max(created_at) from messages where conversation_id = :conv), 'insert bumps last_message_at');
select isnt((select edited_at from messages where id = :m1), null, 'body update stamps edited_at');  -- after an update of body
```
(Use real UUID literals or `\set` variables; the `:'name'` shorthand above is illustrative.)

- [ ] **Step 3: Run test to verify it fails**

Run: `supabase test db` — Expected: FAIL (relations do not exist).

- [ ] **Step 4: Write `supabase/migrations/20261006000001_schema.sql`**

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 50),
  avatar_url text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('direct','group')),
  name text check (name is null or char_length(btrim(name)) between 1 and 80),
  avatar_url text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  last_message_at timestamptz
);
create table public.conversation_members (
  conversation_id uuid references public.conversations(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create table public.messages (
  id uuid primary key default gen_random_uuid(),      -- client may supply (optimistic send)
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles(id),
  body text check (body is null or char_length(body) <= 4000),
  reply_to_id uuid references public.messages(id) on delete set null,
  attachment_path text,
  attachment_type text check (attachment_type in ('image','file','audio')),
  attachment_name text,
  attachment_size bigint,
  attachment_meta jsonb,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  check (deleted_at is not null or char_length(btrim(coalesce(body,''))) > 0 or attachment_path is not null)
);
create table public.message_reactions (
  message_id uuid references public.messages(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);
create table public.device_tokens (
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text primary key,
  platform text not null check (platform in ('android','ios','web')),
  updated_at timestamptz not null default now()
);
create index messages_conv_created_idx on public.messages (conversation_id, created_at desc);
create index conversation_members_user_idx on public.conversation_members (user_id);
```

Then, in the same file:
- `is_member` / `is_admin`: `language sql stable security definer set search_path = ''`, `exists(...)` on `conversation_members` for `auth.uid()` (admin also checks `role = 'admin'`).
- `username_available(name)`: returns `lower(name) ~ '^[a-z0-9_]{3,20}$' and not exists (… where username = lower(name))`; security definer; `grant execute … to anon, authenticated`.
- `handle_new_user()` trigger `after insert on auth.users`: username = `lower(meta->>'username')`, falling back to `'user_' || left(replace(new.id::text,'-',''), 8)`; display_name = `coalesce(nullif(btrim(meta->>'display_name'),''), username)`. Security definer, `set search_path = ''`.
- `bump_last_message_at()` trigger `after insert on messages`: `update conversations set last_message_at = new.created_at where id = new.conversation_id`. Security definer.
- `stamp_edited_at()` trigger `before update on messages`: when `new.body is distinct from old.body` set `new.edited_at = now()`.

- [ ] **Step 5: Run test to verify it passes**

Run: `supabase db reset && supabase test db` — Expected: `01_schema_test.sql .. ok`, `All tests successful.`

- [ ] **Step 6: Commit** — `git add supabase .gitignore && git commit -m "feat(db): v1 schema, profile trigger and helpers"`

---

### Task 2: Row-level security + column privileges

**Files:**
- Create: `supabase/migrations/20261006000002_rls.sql`
- Test: `supabase/tests/02_rls_test.sql`

**Interfaces:**
- Consumes: Task 1 tables and `is_member` / `is_admin`.
- Produces: the access rules every later milestone relies on (no client INSERT on `conversations` — Milestone 2 RPCs `create_group` / `get_or_create_dm` are security definer).

- [ ] **Step 1: Write the failing test `supabase/tests/02_rls_test.sql`**

Setup as superuser: users A (group admin), B (group member), C (outsider); a group G with A admin + B member; a DM D
between A and C; message mA in G by A; a message in D. Switch identity with
`set local role authenticated; select set_config('request.jwt.claims', json_build_object('sub', <uuid>, 'role', 'authenticated')::text, true);`
and `reset role` between users. Assertions:

```sql
-- as C (outsider of G)
select is((select count(*) from messages where conversation_id = :G), 0::bigint, 'non-member cannot read messages');
select throws_ok($$insert into messages (conversation_id, body) values (:G, 'hi')$$, '42501', null, 'non-member cannot post');
select is((select count(*) from conversations where id = :G), 0::bigint, 'non-member cannot see conversation');
-- as B (member)
select lives_ok($$insert into messages (conversation_id, body) values (:G, 'hi')$$, 'member can post');
select throws_ok($$insert into messages (conversation_id, sender_id, body) values (:G, :A, 'spoof')$$, '42501', null, 'cannot post as someone else');
select throws_ok($$insert into messages (conversation_id, body, created_at) values (:G, 'x', now() - interval '1 day')$$, '42501', null, 'cannot backdate');
select throws_ok($$insert into messages (conversation_id, body, reply_to_id) values (:G, 'x', :msg_in_D)$$, '42501', null, 'reply_to must be same conversation');
select is((with u as (update messages set body = 'hacked' where id = :mA returning 1) select count(*) from u), 0::bigint, 'non-sender cannot edit');
select throws_ok($$update messages set conversation_id = :D where id = :mB$$, '42501', null, 'cannot move a message');
select throws_ok($$insert into conversation_members (conversation_id, user_id) values (:G, :C)$$, '42501', null, 'non-admin cannot add members');
select throws_ok($$update conversation_members set role = 'admin' where user_id = :B$$, '42501', null, 'cannot self-promote');
select is((with d as (delete from conversation_members where conversation_id = :G and user_id = :A returning 1) select count(*) from d), 0::bigint, 'member cannot remove others');
select is((with u as (update profiles set display_name = 'x' where id = :A returning 1) select count(*) from u), 0::bigint, 'cannot edit others profile');
select is((select count(*) from device_tokens where user_id = :A), 0::bigint, 'cannot read others device tokens');
select is((select count(*) from profiles), 3::bigint, 'authenticated users read all profiles');
select throws_ok($$insert into message_reactions (message_id, user_id, emoji) values (:msg_in_D, :B, '👍')$$, '42501', null, 'cannot react outside your conversations');
-- as A (sender/admin)
select lives_ok($$update messages set body = 'edited' where id = :mA$$);
select lives_ok($$update messages set deleted_at = now(), body = null where id = :mA$$, 'sender can soft-delete');
select is((with u as (update messages set body = 'undelete' where id = :mA returning 1) select count(*) from u), 0::bigint, 'deleted message cannot be edited');
select lives_ok($$insert into conversation_members (conversation_id, user_id) values (:G, :C)$$, 'admin adds member to group');
select throws_ok($$insert into conversation_members (conversation_id, user_id) values (:D, :B)$$, '42501', null, 'nobody adds members to a DM');
select is((with d as (delete from conversation_members where conversation_id = :D and user_id = :A returning 1) select count(*) from d), 0::bigint, 'cannot leave a DM');
-- as B again
select is((with d as (delete from conversation_members where conversation_id = :G and user_id = :B returning 1) select count(*) from d), 1::bigint, 'member can leave group');
-- as anon
select is((select count(*) from profiles), 0::bigint, 'anon reads nothing');
```

- [ ] **Step 2: Run** `supabase test db` — Expected: FAIL in `02_rls_test.sql`.

- [ ] **Step 3: Write `supabase/migrations/20261006000002_rls.sql`**

`alter table … enable row level security` on all six tables. Then, from `anon, authenticated`, revoke `insert, update`
on all six and grant back only these columns to `authenticated`:

| table | INSERT columns | UPDATE columns |
|---|---|---|
| profiles | — | `username, display_name, avatar_url, last_seen_at` |
| conversations | — | `name, avatar_url` |
| conversation_members | `conversation_id, user_id` | — |
| messages | `id, conversation_id, sender_id, body, reply_to_id, attachment_path, attachment_type, attachment_name, attachment_size, attachment_meta` | `body, deleted_at` |
| message_reactions | `message_id, user_id, emoji` | — |
| device_tokens | `user_id, token, platform` | `user_id, platform, updated_at` |

Policies (all `to authenticated`):

| table | command | rule |
|---|---|---|
| profiles | select | `true` |
| profiles | update | using/check `id = auth.uid()` |
| conversations | select | `is_member(id)` |
| conversations | update | `type = 'group' and is_admin(id)` |
| conversation_members | select | `is_member(conversation_id)` |
| conversation_members | insert | `role = 'member' and is_admin(conversation_id) and exists(select 1 from conversations c where c.id = conversation_id and c.type = 'group')` |
| conversation_members | delete | conversation is `group` and (`user_id = auth.uid()` or `is_admin(conversation_id)`) |
| messages | select | `is_member(conversation_id)` |
| messages | insert | `sender_id = auth.uid() and is_member(conversation_id) and (reply_to_id is null or exists(select 1 from messages r where r.id = reply_to_id and r.conversation_id = messages.conversation_id))` |
| messages | update | using `sender_id = auth.uid() and deleted_at is null`; check `sender_id = auth.uid()` |
| message_reactions | select | `exists(select 1 from messages m where m.id = message_id and is_member(m.conversation_id))` |
| message_reactions | insert | `user_id = auth.uid()` and same membership check |
| message_reactions | delete | `user_id = auth.uid()` |
| device_tokens | all | using/check `user_id = auth.uid()` |

- [ ] **Step 4: Run** `supabase db reset && supabase test db` — Expected: `All tests successful.`

- [ ] **Step 5: Commit** — `git commit -am "feat(db): row-level security and column privileges"` (add new files first).

---

### Task 3: Flutter foundation — deps, env, tokens, theme

**Files:**
- Modify: `pubspec.yaml`, `.gitignore` (add `env/*.json`, `!env/example.json`), `android/app/src/debug/AndroidManifest.xml` (`android:usesCleartextTraffic="true"` on `<application>`), `ios/Runner/Info.plist` (`NSAppTransportSecurity` → `NSAllowsLocalNetworking = true`)
- Create: `env/example.json`, `env/local.json`, `env/local.android.json`, `assets/fonts/*.ttf`
- Create: `lib/core/constants.dart`, `lib/core/env.dart`, `lib/core/theme/tokens.dart`, `lib/core/theme/relay_palette.dart`, `lib/core/theme/relay_metrics.dart`, `lib/core/theme/app_theme.dart`
- Delete: `test/widget_test.dart` (template counter test)
- Test: `test/core/env_test.dart`, `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces:
  - `const String appName = 'Relay';`
  - `abstract final class Env { static const String supabaseUrl; static const String supabaseAnonKey; }` (from `String.fromEnvironment('SUPABASE_URL')` / `'SUPABASE_ANON_KEY'`) and `void checkEnv({required String url, required String anonKey})` that throws `StateError`.
  - `abstract final class RelayColors` (every `tokens.json` color as `static const Color`, `avatarTints: List<Color>` of 5), `RelaySpace` (`s1`=4 … `s14`=56), `RelayRadius` (`sm`=6, `md`=10, `lg`=12, `xl`=14, `xxl`=16, `bubble`=20, `pill`=999), `RelayFonts` (`sans = 'Geist'`, `mono = 'GeistMono'`).
  - `class RelayPalette extends ThemeExtension<RelayPalette>` with fields `background, surface, surfaceAlt, ink, onInk, textSecondary, textMuted, textSubtle, placeholder, border, borderStrong, hairline, fillMuted, accent, accentStrong, accentSoft, online, away, danger, dangerText` and `static const light`, `static const dark`.
  - `class RelayMetrics extends ThemeExtension<RelayMetrics>` with `controlHeight, controlRadius, iconButtonSize, bool circularAvatars`, and `factory RelayMetrics.forPlatform(TargetPlatform platform, {required bool isWeb})`.
  - `ThemeData buildRelayTheme(Brightness brightness, {required TargetPlatform platform, required bool isWeb})`.
  - `extension RelayThemeX on BuildContext { RelayPalette get palette; RelayMetrics get metrics; }`.

- [ ] **Step 1: Dependencies and assets**

`flutter pub add supabase_flutter flutter_riverpod go_router` and remove `cupertino_icons`. Download static TTFs from
the latest `vercel/geist-font` GitHub release into `assets/fonts/`: `Geist-Regular/Medium/SemiBold.ttf`,
`GeistMono-Regular/Medium.ttf`; declare families `Geist` (400/500/600) and `GeistMono` (400/500) in `pubspec.yaml`.
`env/local.json` = `{"SUPABASE_URL":"http://127.0.0.1:54321","SUPABASE_ANON_KEY":"<from supabase start>"}`;
`local.android.json` is the same with `http://10.0.2.2:54321`; `example.json` has placeholder values.

- [ ] **Step 2: Write failing tests**

```dart
// test/core/env_test.dart
test('checkEnv throws a helpful error when values are missing', () {
  expect(() => checkEnv(url: '', anonKey: 'k'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('--dart-define-from-file=env/local.json'))));
});
test('checkEnv accepts configured values', () => checkEnv(url: 'http://127.0.0.1:54321', anonKey: 'k'));

// test/core/theme/app_theme_test.dart
test('light palette mirrors tokens', () {
  final t = buildRelayTheme(Brightness.light, platform: TargetPlatform.iOS, isWeb: false);
  final p = t.extension<RelayPalette>()!;
  expect(p.ink, const Color(0xFF0B0B0C));
  expect(p.accent, const Color(0xFF2B50F5));
  expect(t.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
  expect(t.textTheme.bodyMedium!.fontFamily, 'Geist');
});
test('dark palette inverts ground and keeps cobalt', () {
  final p = buildRelayTheme(Brightness.dark, platform: TargetPlatform.android, isWeb: false).extension<RelayPalette>()!;
  expect(p.background, const Color(0xFF0B0B0C));
  expect(p.surface, const Color(0xFF17171A));
  expect(p.accent, const Color(0xFF2B50F5));
});
test('metrics per platform', () {
  expect(RelayMetrics.forPlatform(TargetPlatform.iOS, isWeb: true).controlHeight, 48); // web wins
  expect(RelayMetrics.forPlatform(TargetPlatform.iOS, isWeb: false), hasMetrics(54, 14, 44, false));
  expect(RelayMetrics.forPlatform(TargetPlatform.android, isWeb: false), hasMetrics(56, 999, 48, true));
});
for (final b in Brightness.values) {
  test('text colors meet 4.5:1 on background and surface ($b)', () {
    final p = buildRelayTheme(b, platform: TargetPlatform.iOS, isWeb: false).extension<RelayPalette>()!;
    for (final fg in [p.ink, p.textSecondary, p.textMuted, p.textSubtle, p.dangerText, p.accentStrong]) {
      expect(contrastRatio(fg, p.background), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(fg, p.surface), greaterThanOrEqualTo(4.5));
    }
  });
}
```
`hasMetrics` and `contrastRatio` (WCAG relative-luminance formula via `Color.computeLuminance()`) live in `test/support/theme_matchers.dart`.

- [ ] **Step 3: Run** `flutter test test/core` — Expected: FAIL (undefined names).

- [ ] **Step 4: Implement the produces-list above**

Dark palette values: `background #0B0B0C, surface #17171A, surfaceAlt #111113, ink #F4F4F5, onInk #0B0B0C, textSecondary #D4D4D8,
textMuted #B4B4BB, textSubtle #A1A1A8, placeholder #8A8A91, border #2A2A2F, borderStrong #3A3A40, hairline #24242A,
fillMuted #1F1F23, accentSoft #1A2250, accentStrong #8FA6FF, dangerText #F28B82` (others unchanged). Light: `background = surface = #FFFFFF`, `onInk #FFFFFF`.
Metrics: web 48/12/40/false · iOS 54/14/44/false · Android 56/999/48/true · other desktop = web.
Text theme (`fontFamily: 'Geist'`, letter spacing is em × size): `displayLarge` 52/600/−0.035em/h1.05 ·
`headlineLarge` 32/600/−0.03em · `titleMedium` 17/600/−0.02em · `bodyLarge` 16/400/h1.5 · `bodyMedium` 15/400/h1.5 ·
`bodySmall` 13/400/h1.45 · `labelLarge` 14/500 · `labelSmall` 12/500/+0.04em. Colors from the palette (`ink`, muted = `textMuted`).
`ColorScheme`: `primary = ink`, `onPrimary = onInk`, `secondary = accent`, `error = danger`, `surface = background`.

- [ ] **Step 5: Run** `flutter test test/core && flutter analyze` — Expected: all pass, `No issues found!`

- [ ] **Step 6: Commit** — `git commit -m "feat(app): dependencies, env config, Relay tokens and theme"`

---

### Task 4: UI primitives

**Files:**
- Create: `lib/core/ui/relay_button.dart`, `lib/core/ui/relay_text_field.dart`, `lib/core/ui/relay_avatar.dart`, `lib/core/ui/relay_logo.dart`, `lib/core/ui/form_error_banner.dart`
- Test: `test/core/ui/primitives_test.dart`, `test/support/pump.dart`

**Interfaces:**
- Consumes: Task 3 theme, `context.palette`, `context.metrics`.
- Produces:
  - `enum RelayButtonVariant { primary, secondary }`; `RelayButton({required String label, required VoidCallback? onPressed, RelayButtonVariant variant = primary, bool loading = false})` — full width, height `metrics.controlHeight`, radius `metrics.controlRadius`; primary = `ink` fill / `onInk` 600 text; secondary = surface fill, 1px `border` (Android: `placeholder` #8A8A91). `loading` shows a 20px spinner, ignores taps, keeps `label` as the semantics label.
  - `RelayTextField({required String label, TextEditingController? controller, String? hintText, String? errorText, String? helperText, Widget? prefix, bool obscure = false, TextInputType? keyboardType, Iterable<String>? autofillHints, TextInputAction? textInputAction, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, bool enabled = true, bool readOnly = false})` — label above (labelLarge), input height `metrics.controlHeight`, radius 12, 1px `borderStrong`; focused = 1px `ink` border inside a 2px `accent` ring; error = `danger` border + `dangerText` message below with a leading error icon. When `obscure`, a trailing icon button (min size `metrics.iconButtonSize`, tooltip `'Show password'` / `'Hide password'`) toggles visibility.
  - `RelayAvatar({required String name, required String seed, double size = 36})`; top-level `String initialsFor(String name)` and `Color avatarTintFor(String seed)` (index = sum of `seed.codeUnits` % 5). Radius `size * 0.3`, or circle when `metrics.circularAvatars`. Initials 600 weight, `ink` text (`#0B0B0C` in both themes, since tints are light).
  - `RelayLogo({double size = 44, bool inverted = false})` — CustomPainter of the handoff SVG (32-unit box: rounded rect rx 9, strokes `M9.5 12h13`, `M9.5 17h8` width 2.4 round caps, cobalt dot r 2.6 at (22,21)); `inverted` swaps the ink/white fills for the dark brand panel.
  - `FormErrorBanner({required String message})` — `dangerText` text on a soft danger tint, `Semantics(liveRegion: true)`.
  - Test helper `Future<void> pumpRelay(WidgetTester t, Widget child, {TargetPlatform platform = TargetPlatform.iOS, bool isWeb = false, Brightness brightness = Brightness.light, List<Override> overrides = const []})` wrapping in `ProviderScope` + `MaterialApp(theme: buildRelayTheme(...))`.

- [ ] **Step 1: Write failing tests** (`test/core/ui/primitives_test.dart`)

```dart
testWidgets('primary button uses platform control height', (t) async {
  await pumpRelay(t, RelayButton(label: 'Sign in', onPressed: () {}), platform: TargetPlatform.iOS);
  expect(t.getSize(find.byType(RelayButton)).height, 54);
  await pumpRelay(t, RelayButton(label: 'Sign in', onPressed: () {}), platform: TargetPlatform.android);
  expect(t.getSize(find.byType(RelayButton)).height, 56);
});
testWidgets('loading button ignores taps and keeps its label for screen readers', (t) async {
  var taps = 0;
  await pumpRelay(t, RelayButton(label: 'Sign in', onPressed: () => taps++, loading: true));
  await t.tap(find.byType(RelayButton));
  expect(taps, 0);
  expect(find.bySemanticsLabel('Sign in'), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
testWidgets('password field toggles visibility with labelled 44px button', (t) async {
  await pumpRelay(t, const RelayTextField(label: 'Password', obscure: true));
  expect(t.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
  expect(t.getSize(find.byTooltip('Show password')).width, greaterThanOrEqualTo(44));
  await t.tap(find.byTooltip('Show password'));
  await t.pump();
  expect(t.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
  expect(find.byTooltip('Hide password'), findsOneWidget);
});
testWidgets('error text renders under the field', (t) async {
  await pumpRelay(t, const RelayTextField(label: 'Email', errorText: 'Enter your email.'));
  expect(find.text('Enter your email.'), findsOneWidget);
});
test('initials', () {
  expect(initialsFor('Aisha Khan'), 'AK');
  expect(initialsFor('priya'), 'P');
  expect(initialsFor('Mary Jane Watson'), 'MJ');
  expect(initialsFor('   '), '?');
});
test('avatar tint is stable and from the 5 token tints', () {
  expect(avatarTintFor('user-1'), avatarTintFor('user-1'));
  expect(RelayColors.avatarTints, contains(avatarTintFor('anything')));
});
testWidgets('avatar is a circle on Android, rounded square elsewhere', (t) async { /* inspect the ClipRRect/BoxDecoration shape */ });
```

- [ ] **Step 2: Run** `flutter test test/core/ui` — Expected: FAIL.
- [ ] **Step 3: Implement the produces-list above.**
- [ ] **Step 4: Run** `flutter test && flutter analyze` — Expected: all pass, no issues.
- [ ] **Step 5: Commit** — `git commit -m "feat(ui): Relay button, text field, avatar, logo primitives"`

---

### Task 5: Domain + repositories (auth, profile)

**Files:**
- Create: `lib/features/auth/domain/validators.dart`, `lib/features/auth/domain/auth_failure.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/data/supabase_auth_repository.dart`, `lib/features/profile/domain/profile.dart`, `lib/features/profile/data/profile_repository.dart`, `lib/features/profile/data/supabase_profile_repository.dart`, `lib/core/providers.dart`
- Test: `test/features/auth/validators_test.dart`, `test/support/fakes.dart`, `test_integration/supabase_repositories_test.dart`

**Interfaces:**
- Produces:
  - Validators (return `null` when valid, else the exact message):
    `String? validateEmail(String)` → `'Enter your email.'` / `'Enter a valid email address.'` (regex `^[^@\s]+@[^@\s]+\.[^@\s]+$` on trimmed input);
    `String? validatePassword(String)` → `'Use 8+ characters with a letter and a number.'`;
    `int passwordStrength(String)` → 0–4, one point each for: length ≥8, a digit, both upper and lower case, a non-alphanumeric char or length ≥12 (empty → 0);
    `String normalizeUsername(String)` → trim, strip one leading `@`, lowercase;
    `String? validateUsername(String)` (on normalized) → `'Use 3–20 letters, numbers or underscores.'`;
    `String? validateDisplayName(String)` → `'Enter your name.'` / `'Keep it under 50 characters.'`.
  - `enum AuthFailureCode { invalidCredentials, emailTaken, usernameTaken, weakPassword, emailNotConfirmed, network, unknown }`;
    `class AuthFailure implements Exception { final AuthFailureCode code; String get message; }` with messages:
    `'Email or password is incorrect.'`, `'An account with this email already exists.'`, `'That username is taken.'`,
    `'Use 8+ characters with a letter and a number.'`, `'Confirm your email first — check your inbox.'`,
    `'Can’t reach the server. Check your connection and try again.'`, `'Something went wrong. Please try again.'`.
    Same class reused for profile failures.
  - `enum AuthStatus { signedIn, signedOut }`; `class SignUpResult { final bool needsEmailConfirmation; }`
  - `abstract interface class AuthRepository { AuthStatus get currentStatus; String? get currentUserId; String? get currentEmail; Stream<AuthStatus> statusChanges(); Future<void> signIn({required String email, required String password}); Future<SignUpResult> signUp({required String email, required String password, required String username, required String displayName}); Future<void> signOut(); }`
  - `class Profile { final String id, username, displayName; final String? avatarUrl; factory Profile.fromJson(Map<String, dynamic>); }`
  - `abstract interface class ProfileRepository { Future<Profile> fetchMyProfile(); Future<Profile> updateMyProfile({String? displayName, String? username}); Future<bool> isUsernameAvailable(String username); }`
  - `lib/core/providers.dart`: `supabaseClientProvider`, `authRepositoryProvider`, `profileRepositoryProvider` (`Provider`), `authStatusProvider` (`StreamProvider<AuthStatus>`), `myProfileProvider` (`FutureProvider<Profile>` that `ref.watch(authStatusProvider)` so it refetches on auth change).
  - `test/support/fakes.dart`: `FakeAuthRepository` (in-memory; `StreamController.broadcast` for status; public `signInCalls` / `signUpCalls` records, `int signOutCalls`; settable `Object? nextError`, `Completer<void>? signInGate` that `signIn` awaits when set, `SignUpResult signUpResult`; `emit(AuthStatus)`), `FakeProfileRepository` (settable `Profile? profile` and `Object? loadError`, `Set<String> takenUsernames`, `nextError`, `updateCalls` records of `(displayName, username)`).

- [ ] **Step 1: Write failing validator tests** — one `expect` per rule above, e.g.

```dart
expect(validateEmail('  priya@example.com '), isNull);
expect(validateEmail('priya@'), 'Enter a valid email address.');
expect(validatePassword('password'), 'Use 8+ characters with a letter and a number.');
expect(validatePassword('12345678'), 'Use 8+ characters with a letter and a number.');
expect(validatePassword('relaypass24'), isNull);
expect([passwordStrength(''), passwordStrength('relaypass'), passwordStrength('relaypass24'), passwordStrength('Relaypass24'), passwordStrength('Relaypass24!')], [0, 1, 2, 3, 4]);
expect(normalizeUsername(' @Priya_S '), 'priya_s');
expect(validateUsername('pr'), 'Use 3–20 letters, numbers or underscores.');
expect(validateUsername('priya.s'), 'Use 3–20 letters, numbers or underscores.');
expect(validateDisplayName('  '), 'Enter your name.');
```

- [ ] **Step 2: Run** `flutter test test/features/auth/validators_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement validators, failures, models, interfaces, fakes and providers.**
- [ ] **Step 4: Run** — Expected: PASS.

- [ ] **Step 5: Write failing integration tests** `test_integration/supabase_repositories_test.dart`

Build the client with `SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey, authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit))`
(PKCE needs storage that plain tests lack). Unique emails `m1-<microseconds>@example.com`. Tests:
- `signUp` → `currentStatus == signedIn`, `needsEmailConfirmation == false`, and `fetchMyProfile()` returns the given username and display name.
- `signUp` with an existing email → `AuthFailure(emailTaken)`.
- `signUp` with username `'Priya_X<n>'` after `'priya_x<n>'` exists → `AuthFailure(usernameTaken)` (repository lowercases before sending).
- `signIn` with a wrong password → `AuthFailure(invalidCredentials)`; with `'  ${email.toUpperCase()} '` and the right password → signed in.
- `isUsernameAvailable` is `false` for a taken name and `true` for a fresh one, while signed **out**.
- `updateMyProfile(username: <taken>)` → `AuthFailure(usernameTaken)`.
- `statusChanges()` emits `signedOut` after `signOut()`.
- Client pointed at `http://127.0.0.1:1` → `signIn` throws `AuthFailure(network)`.

- [ ] **Step 6: Run** `flutter test test_integration --dart-define-from-file=env/local.json` (stack running) — Expected: FAIL.

- [ ] **Step 7: Implement `SupabaseAuthRepository` and `SupabaseProfileRepository`**

Trim email and `normalizeUsername` before sending; signup `data: {'username': …, 'display_name': …}`. Map errors:
`AuthException.code` `invalid_credentials` → invalidCredentials; `user_already_exists`/`email_exists` → emailTaken;
`weak_password` → weakPassword; `email_not_confirmed` → emailNotConfirmed; message containing `'Database error saving new user'` → usernameTaken
(the profile trigger hit the unique index); `AuthRetryableFetchException`, `SocketException`, `ClientException` → network; else unknown.
`PostgrestException.code == '23505'` → usernameTaken. `signUp` pre-checks `username_available` and throws usernameTaken early.
`needsEmailConfirmation = response.session == null`.

- [ ] **Step 8: Run** unit + integration suites — Expected: PASS.
- [ ] **Step 9: Commit** — `git commit -m "feat(auth): validators, auth and profile repositories"`

---

### Task 6: App shell, router and auth redirect

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/app.dart`, `lib/core/router.dart`, `lib/features/home/ui/home_screen.dart`
- Test: `test/core/router_test.dart`, `test/app_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider`, `AuthStatus`, `buildRelayTheme`, `checkEnv`.
- Produces:
  - `abstract final class Routes { static const signIn = '/sign-in', signUp = '/sign-up', home = '/', profile = '/profile'; }`
  - `String? authRedirect({required AuthStatus status, required String location})` — signed out and not on an auth route → `Routes.signIn`; signed in and on an auth route → `Routes.home`; otherwise `null`.
  - `final routerProvider = Provider<GoRouter>` using `refreshListenable: StreamListenable(auth.statusChanges())` (a small `ChangeNotifier` in `router.dart`, disposed with the provider).
  - `class RelayApp extends ConsumerWidget` — `MaterialApp.router(title: appName, theme/darkTheme: buildRelayTheme(…, platform: defaultTargetPlatform, isWeb: kIsWeb), themeMode: ThemeMode.system)`.
  - `HomeScreen` (Milestone 2 replaces its body with the chat list): app bar with `appName` title and a `RelayAvatar` button (tooltip `'Your profile'`) → `Routes.profile`; empty state headline `'No conversations yet'`, body `'Chats with your group will show up here.'`.
  - `main()`: `checkEnv(...)`, `await Supabase.initialize(url:, anonKey:)`, `runApp(const ProviderScope(child: RelayApp()))`.

- [ ] **Step 1: Write failing tests**

```dart
// router_test.dart
expect(authRedirect(status: AuthStatus.signedOut, location: '/'), Routes.signIn);
expect(authRedirect(status: AuthStatus.signedOut, location: '/profile'), Routes.signIn);
expect(authRedirect(status: AuthStatus.signedOut, location: '/sign-up'), isNull);
expect(authRedirect(status: AuthStatus.signedIn, location: '/sign-in'), Routes.home);
expect(authRedirect(status: AuthStatus.signedIn, location: '/profile'), isNull);

// app_test.dart (ProviderScope overrides with FakeAuthRepository / FakeProfileRepository)
testWidgets('signed out starts on sign-in; signing in shows home', …);           // find.text('Welcome back') → emit(signedIn) → find.text('No conversations yet')
testWidgets('session ending on /profile returns to sign-in', …);                  // start signedIn, tap 'Your profile', emit(signedOut), pumpAndSettle → find.text('Welcome back')
```
(Sign-in screen text comes from Task 7; until then a placeholder `SignInScreen` showing `'Welcome back'` is acceptable and gets replaced.)

- [ ] **Step 2: Run** `flutter test test/core/router_test.dart test/app_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test && flutter analyze`, then smoke: `flutter run -d chrome --web-port 3000 --dart-define-from-file=env/local.json` shows the sign-in route. Expected: tests pass; app boots without errors.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): router with auth redirect and home shell"`

---

### Task 7: Sign-in screen

**Files:**
- Create: `lib/features/auth/ui/sign_in_screen.dart`, `lib/features/auth/ui/auth_layout.dart`, `lib/features/auth/ui/auth_form_controller.dart`
- Test: `test/features/auth/sign_in_screen_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider`, validators, `AuthFailure`, primitives, `Routes`.
- Produces:
  - `AuthLayout({required Widget form})` — at width ≥900 a `Row` of a brand panel (`Key('brand-panel')`, flex 1, `ink` background, 48/56 padding: inverted `RelayLogo` + `appName` 20/600, headline `'Every conversation, in one calm place.'` displayLarge white, sub `'Groups and direct messages for your people — on the web, iOS and Android.'` 18px `#B4B4BB`) and the form column; below 900, the form only. Form column: centered, `maxWidth: 400`, padding 24, scrollable, `SafeArea`.
  - `class AuthFormController extends Notifier<AuthFormState>` exposed as `authFormControllerProvider = NotifierProvider.autoDispose(AuthFormController.new)` with `AuthFormState { bool submitting; String? formError; }` and `Future<void> run(Future<void> Function() action)` — ignores calls while `submitting`, maps `AuthFailure` → `formError = failure.message`. Also used by Tasks 8 and 9.
  - `SignInScreen`: `RelayLogo`, `'Welcome back'` (headlineLarge), `'Pick up your conversations where you left off.'` (bodyMedium, textMuted), `FormErrorBanner` when `formError != null`, fields Email (`AutofillHints.email`, email keyboard, next) and Password (`obscure`, `AutofillHints.password`, done → submit), primary `'Sign in'`, footer `'New to $appName? '` + link `'Create account'` → `Routes.signUp`. Fields wrapped in `AutofillGroup`. Field errors appear only after the first submit.

- [ ] **Step 1: Write failing tests** (pump with `FakeAuthRepository`)

```dart
testWidgets('empty submit shows field errors and does not call auth', …);          // 'Enter your email.', password message; fake.signInCalls isEmpty
testWidgets('submits trimmed email', …);                                            // enter '  Priya@Example.com ' → signInCalls.single.email == 'Priya@Example.com'
testWidgets('wrong password shows banner', …);                                     // nextError = AuthFailure(invalidCredentials) → 'Email or password is incorrect.'
testWidgets('network failure shows message and re-enables button', …);             // nextError = AuthFailure(network) → message; second tap triggers a 2nd call
testWidgets('double tap sends one request', …);                                    // fake signIn awaits a Completer; tap twice; signInCalls.length == 1
testWidgets('brand panel only at ≥900px', …);                                      // t.view.physicalSize = Size(1200, 800) / Size(600, 900), devicePixelRatio 1
testWidgets('create account link goes to sign-up', …);
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test && flutter analyze` — Expected: PASS / no issues.
- [ ] **Step 5: Commit** — `git commit -m "feat(auth): sign-in screen"`

---

### Task 8: Sign-up screen

**Files:**
- Create: `lib/features/auth/ui/sign_up_screen.dart`, `lib/features/auth/ui/widgets/password_strength_meter.dart`, `lib/features/auth/ui/username_field.dart`
- Test: `test/features/auth/sign_up_screen_test.dart`

**Interfaces:**
- Consumes: `AuthLayout`, `AuthFormController`, `authRepositoryProvider`, `profileRepositoryProvider.isUsernameAvailable`, validators.
- Produces:
  - `PasswordStrengthMeter({required int score})` — 4 equal segments, 4px tall, gap 4, radius pill; filled = `ink`, empty = `fillMuted`; `Semantics(label: 'Password strength ${['none','weak','fair','good','strong'][score]}')`.
  - `UsernameField({required TextEditingController controller, String? submitError})` — `RelayTextField(label: 'Username', prefix: Text('@'))`; 400ms after typing stops, if `validateUsername` passes, calls `isUsernameAvailable`; helper `'@<name> is available'` (textMuted with a check icon) or error `'That username is taken.'`. A stale response for an older value is ignored.
  - `SignUpScreen`: `'Create your account'`, `'Pick a username so your friends can find you.'`, fields Name (`AutofillHints.name`), Username, Email, Password (`AutofillHints.newPassword`) + meter + helper `'8+ characters with a letter and a number'`; primary `'Create account'`; footer `'Have an account? '` + `'Sign in'`. If `needsEmailConfirmation`, replace the form with `'Check your inbox'` / `'Confirm your email, then sign in.'` + secondary `'Back to sign in'`. `AuthFailure(usernameTaken)` shows on the username field, not the banner.

- [ ] **Step 1: Write failing tests**

```dart
testWidgets('strength meter follows the password', …);                  // type 'Relaypass24' → semantics 'Password strength good'
testWidgets('username shows availability after debounce', …);            // type 'Priya' → pump(400ms) → '@priya is available'
testWidgets('taken username shows field error', …);                      // takenUsernames = {'priya'} → 'That username is taken.'
testWidgets('server-side username race lands on the username field', …); // nextError = AuthFailure(usernameTaken) on signUp → field error, no FormErrorBanner
testWidgets('valid form calls signUp with normalized values', …);        // username ' @Priya ' → 'priya', email trimmed
testWidgets('email confirmation state', …);                              // fake returns needsEmailConfirmation: true → 'Check your inbox'
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test && flutter analyze` — Expected: PASS / no issues.
- [ ] **Step 5: Commit** — `git commit -m "feat(auth): sign-up with username check and password strength"`

---

### Task 9: Profile screen + sign out

**Files:**
- Create: `lib/features/profile/ui/profile_screen.dart`
- Modify: `lib/core/router.dart` (route `Routes.profile` → `ProfileScreen`)
- Test: `test/features/profile/profile_screen_test.dart`

**Interfaces:**
- Consumes: `myProfileProvider`, `profileRepositoryProvider`, `authRepositoryProvider.currentEmail` / `signOut`, `UsernameField`, `AuthFormController`.
- Produces: `ProfileScreen` — back button (tooltip `'Back'`), title `'Profile'`; `RelayAvatar(size: 72)`; fields Name, Username (`UsernameField`, availability skipped when unchanged), Email (`readOnly`); primary `'Save changes'` (disabled until something changes); secondary `'Sign out'`. Saving success shows a `SnackBar('Profile updated')` and invalidates `myProfileProvider`. Loading state: skeleton blocks in `fillMuted`; load error: `'Couldn’t load your profile.'` + `'Try again'`.

- [ ] **Step 1: Write failing tests**

```dart
testWidgets('shows current profile values', …);                   // display name, username, email from fakes
testWidgets('save disabled until a change', …);
testWidgets('saves display name', …);                             // fake records updateMyProfile(displayName: 'New Name') → 'Profile updated'
testWidgets('taken username error on save', …);                   // nextError = AuthFailure(usernameTaken) → field error
testWidgets('sign out calls repository', …);                      // fake.signOutCalls == 1
testWidgets('load error offers retry', …);
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test && flutter analyze` — Expected: PASS / no issues.
- [ ] **Step 5: Commit** — `git commit -m "feat(profile): edit profile and sign out"`

---

### Task 10: End-to-end verification + README

**Files:**
- Modify: `README.md` (replace template text: prerequisites, `supabase start`, run commands per platform with the right env file, test commands)

- [ ] **Step 1: Full automated run**

`supabase db reset && supabase test db && flutter analyze && flutter test && flutter test test_integration --dart-define-from-file=env/local.json`
Expected: every suite green, `No issues found!`.

- [ ] **Step 2: Manual run on three targets** — web (`flutter run -d chrome --web-port 3000 --dart-define-from-file=env/local.json`), Android emulator (`--dart-define-from-file=env/local.android.json`), iOS simulator (`env/local.json`). On each: sign up a new user → home; profile shows values; edit name → saved; sign out → sign-in; sign back in. Check dark mode once (system setting) and the web brand panel at ≥900 / <900px. Expected: all steps work and no console errors.

- [ ] **Step 3: Commit** — `git commit -m "docs: README for local setup and running Relay"`
