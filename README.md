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
# Web (port 3000 matches site_url in supabase/config.toml)
flutter run -d chrome --web-port 3000 --dart-define-from-file=env/local.json

# iOS simulator
open -a Simulator
flutter run -d <simulator id> --dart-define-from-file=env/local.json

# Android emulator (10.0.2.2 is the emulator's alias for the host machine)
flutter run -d <emulator id> --dart-define-from-file=env/local.android.json
```

`flutter devices` lists available device ids.

## Tests

```sh
flutter analyze
flutter test
flutter test test_integration --dart-define-from-file=env/local.json   # needs the local stack running
```
