# Relay

Relay is a team group-chat app for web, iOS and Android, built with Flutter and Supabase. "Relay" is a working name.

- Specs and plans: `docs/superpowers/`
- Design handoff: `CLAUDE.md`, `tokens.json` / `tokens.css`, `screens/`

## Prerequisites

- Flutter 3.47 or newer
- A Docker runtime (Docker Desktop, OrbStack or Colima)
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)

## Local backend

```sh
supabase start        # start the local stack
supabase db reset     # re-apply migrations from supabase/migrations
supabase test db      # run the pgTAP tests in supabase/tests
```

The API port is set to **54331** in `supabase/config.toml` (`[api] port`) instead of the default 54321, because 54321 can be taken by another local Supabase project. If yours is free, you can change it back, but then update the URLs in your env files. `supabase status` shows all URLs and keys.

## Env files

The app reads its Supabase settings from `--dart-define-from-file`. Copy the template and fill in the API URL and anon key from `supabase status`:

```sh
cp env/example.json env/local.json           # web, iOS simulator: http://127.0.0.1:54331
cp env/example.json env/local.android.json   # Android emulator:   http://10.0.2.2:54331
```

`env/local*.json` are gitignored. Never commit keys.

## Run

```sh
# Debug: a plain flutter run uses the local stack (127.0.0.1:54331;
# Android emulator uses 10.0.2.2:54331). Release still needs the env file.

# Web (port 3000 matches site_url in supabase/config.toml)
flutter run -d chrome --web-port 3000

# iOS simulator
open -a Simulator
flutter run -d <simulator id>

# Android emulator
flutter run -d <emulator id>
```

`flutter devices` lists available device ids.

**Release / a hosted project:** pass `--dart-define-from-file=env/local.json` (or
`env/local.android.json`). In Cursor / VS Code, the Run configurations in `.vscode/launch.json`
already do that. To run a **release** build from Xcode, first run
`flutter build ios --simulator --dart-define-from-file=env/local.json` (or `flutter build macos …`)
so Xcode picks up the defines. A debug `flutter run` without the flag is fine; it no longer shows
the "Relay isn't configured" screen.

**Physical Android device over USB:** `adb reverse tcp:54331 tcp:54331`, then run with `env/local.json`
(127.0.0.1 now reaches your Mac).

**Invite links** are built from `APP_URL` in the env file (default `http://localhost:3000`), as
`APP_URL/#/join/<token>`. On phones, paste a link in New chat → "Join with a link".

## Company allowlist (who can use Relay)

Relay is company-only. Only emails in `public.allowed_emails` can sign up or sign in. Two Supabase Auth hooks
(`supabase/migrations/20261007000002_company_allowlist.sql`, enabled in `supabase/config.toml`) enforce it on the
server: one rejects sign-ups, the other refuses tokens. Someone removed from the list is signed out the next time the
app opens or comes back to the foreground, and in any case within one token lifetime (1 hour).

- **The list lives in `supabase/allowlist.sql`** (gitignored, because it holds coworkers' emails). Copy
  `supabase/allowlist.example.sql` to start. `supabase db reset` applies it automatically.
- **Apply changes without a reset:**
  `docker exec -i supabase_db_chatapp psql -U postgres < supabase/allowlist.sql`
- **Add or remove one person** (Studio → SQL editor at http://127.0.0.1:54323, or psql):
  ```sql
  insert into public.allowed_emails (email, note) values ('name@company.com', 'Name');
  delete from public.allowed_emails where email = 'name@company.com';
  ```
  Removing someone blocks sign-in but keeps their old messages. To delete their account too, use Studio →
  Authentication → Users.
- **Hosted project:** after `supabase db push`, turn on both hooks in the dashboard (Authentication → Hooks:
  "Before User Created" → `public.hook_before_user_created`, "Customize Access Token" →
  `public.hook_custom_access_token`) and run `allowlist.sql` in the SQL editor.

## Tests

```sh
flutter analyze
flutter test
supabase test db

# Against the local stack. env/test.json holds the local service_role key (copy env/test.example.json and paste it
# from `supabase status`); the tests use it to allowlist their throwaway @example.com accounts and delete them after.
flutter test test_integration --dart-define-from-file=env/local.json --dart-define-from-file=env/test.json

# Whole app on a device or desktop (signs in, chats, checks realtime):
flutter test integration_test -d macos --dart-define-from-file=env/local.json --dart-define-from-file=env/test.json
```
