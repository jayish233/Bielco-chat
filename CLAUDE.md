# Relay — Design Handoff for Claude Code

> **Build decisions override parts of this handoff.** The app is built in **Flutter + Supabase** (not Next.js/Expo), with
> a reduced scope and one adaptive UI. See `docs/superpowers/specs/2026-10-06-group-chat-design.md` →
> "Decisions after the UI handoff", and the milestone plans in `docs/superpowers/plans/`.

## Where the build stands (2026-10-07)

Read this before the design handoff below. Branch `main`. Milestone 1 is committed (`fa03349`). **Milestones 2–4
(chat, groups, people, invite links, photos/files/voice notes, reactions, reply, edit/delete, read receipts,
typing, presence) are implemented but not committed yet.** What was built and how it's verified:
`docs/superpowers/plans/2026-10-07-m2-m4-chat.md`. The app name in Dart is `appName` in `lib/core/constants.dart`.

- **"iOS/macOS app not opening" is fixed.** `main()` no longer throws before `runApp`. A debug
  `flutter run` without `--dart-define-from-file` uses the local stack (`127.0.0.1:54331`, or
  `10.0.2.2:54331` on the Android emulator). Release/profile still show `ConfigErrorApp` if the
  defines are missing. Cursor/VS Code Run configs in `.vscode/launch.json` pass the env file.
- **Geist looked doubled on iOS** ("Relayout", "Missinging"). Two fixes: name tables now use
  one family per face, and `pubspec.yaml` registers Regular/Medium/SemiBold as separate families
  (`Geist`, `GeistMedium`, `GeistSemiBold`) so Impeller cannot paint two faces on one run of
  text. Do not treat leftover garbled copy as a string bug.
- **Company-only access (2026-10-07):** only emails in `public.allowed_emails` can sign up / sign in (Auth hooks;
  list in gitignored `supabase/allowlist.sql`; README "Company allowlist"). The fake test contacts were deleted;
  the local DB now holds only the owner's account (`krishma939@gmail.com`, username `jayish`). Test suites
  allowlist their own `@example.com` accounts and delete them afterwards (needs `env/test.json`).
- **Backend is the local Supabase stack only** (Docker via Colima, API on `127.0.0.1:54331`). Start it with
  `colima start && supabase start`. No hosted project is linked yet.
- Checks: `flutter analyze` clean · `flutter test` 107 · `supabase test db` 95 · `test_integration` 22 ·
  `integration_test` e2e passes on macOS and the iOS simulator.

### Still open

- **Coworker emails:** the user is sending the list → add to `supabase/allowlist.sql` and apply it.
- **Milestone 5 (push)** — needs the user's Firebase project + Apple Developer account. See the M2–M4 doc.
- **Commit** the M2–M4 work (nothing from 2026-10-07 is committed).
- **Hosted Supabase** (`supabase link`, `supabase db push`) and a real `APP_URL` for invite links.
- Manual pass on web (voice notes, file pick in the browser) and Android (camera, voice).
- Remaining M1 follow-ups: `docs/superpowers/m1-followups.md`.

This folder is the design spec for **Relay**, a team chat app for **web, iOS and Android**.
Build the UI to match it exactly. "Relay" is a working name — rename everywhere via the `APP_NAME` constant.

- `tokens.json` / `tokens.css` — the single source of truth for color, type, spacing, radii.
- `screens/*.dc.html` — reference markup for every screen (inline styles = exact values). Open in a browser to view; ignore the `<x-dc>`, `<helmet>` and `data-dc-script` wrappers — they're design-tool scaffolding, not app code.
- This file — components, screens, flows and platform rules.

## Suggested stack (change if you prefer)

| Platform | Stack |
|---|---|
| Web | Next.js (App Router) + TypeScript + Tailwind (map `tokens.css` vars into `tailwind.config`) |
| iOS + Android | Expo / React Native + TypeScript, sharing tokens and business logic with web |
| Realtime | WebSocket layer behind a `ChatService` interface; mock it first with fixture data |

Build order: tokens → primitives → auth screens → chat → team → wire navigation → realtime.

## Design principles

1. **Monochrome first.** Ink `#0B0B0C` on white does almost all the work. Primary actions are solid ink.
2. **One accent, used for signal only.** Cobalt `#2B50F5` = unread counts, "New" divider, mentions, read receipts, links on hover. Never for large fills.
3. **Presence colors:** online `#12A150`, away `#E5A50A`, offline = hollow grey ring.
4. **Calm density.** 15–16px body, generous line-height (1.45–1.55), 8-pt spacing.
5. **Accessible by default.** Real `<button>`/`<a>`/`<input>`+`<label>`; `aria-label` on every icon-only button; ≥44px touch targets; text ≥4.5:1 contrast.

## Typography

- UI: **Geist** 400 / 500 / 600 (Google Fonts). Fallback `ui-sans-serif, system-ui`.
- Metadata (timestamps, file sizes, URLs, `#` glyph): **Geist Mono** 400/500.
- Display headings use negative tracking: −0.035em at 32–52px, −0.02em at 17–24px.

| Role | Web | iOS | Android |
|---|---|---|---|
| Hero / page title | 52 / 32px 600 | 34px 600 (large title) | 28–32px 600 |
| Section / nav title | 17px 600 | 16–17px 600 | 20–24px 500–600 |
| Body / message | 15px 400 | 16px | 15–16px |
| Caption / meta | 12–13px | 12–13px | 12–14px |
| Overline labels | 12px 500 uppercase, +0.04em | 13px | 13px 600 |

## Components

**Button**
- Primary: bg ink, text white, weight 600. Web 48px h / radius 12. iOS 54px / radius 14. Android 56px / radius 999 (pill).
- Secondary: white bg, 1px `#E4E4E7` border (Android outlined: `#8A8A91`), ink text.
- Icon button: 40×40 (web), 44×44 (iOS), 48×48 circle (Android); `aria-label` required.

**Text field**
- Web: label above (14px 500), 48px input, radius 12, border `#D4D4D8`, focus = 2px cobalt outline + ink border.
- iOS: grouped inset card (radius 14) with stacked fields, label inside each row (12px) — see `iOSSignIn`.
- Android: Material 3 outlined field, 56px, radius 8, floating label notched into border; focused border 2px ink; error border/text `#C4281C`/`#B02418` with leading icon + helper text.

**Avatar** — initials on a soft tint. Radius: web/iOS = rounded square (≈30% of size), Android = circle. Tints: `#DDE6F7` `#E3EFE6` `#E8E4DC` `#F4E3DA` `#ECE3F3`. Presence dot bottom-right with a 2–3px ring in the surface color.

**Unread badge** — cobalt pill, white 12–13px 600 text, min-width 20–22px.

**Role pill** — Owner: solid ink. Admin: 1px ink outline. Member: `#F1F1F3` fill. Guest: 1px dashed `#A1A1A8`. Pending: `#EEF1FF` fill / `#1F3FD1` text.

**Message**
- Web: Slack-style rows — 36px avatar, name 15px 600 + mono timestamp, body 15px. Grouped follow-ups indent with no avatar. Reactions are 28px pills (active reaction = ink border + `#F1F1F3`). Thread link in cobalt with stacked mini avatars.
- iOS: bubbles. Incoming white w/ `#ECECEE` border, radius 20 with 6px tail corner bottom-left; outgoing ink w/ white text, tail bottom-right. Consecutive bubbles flatten the joining corner.
- Android: bubbles with sender name inside (colored by avatar tint, darkened for contrast), timestamp bottom-right inside bubble, tail corner top-left (incoming) / top-right (outgoing).
- Attachments: file card (40px tile + name + mono "PDF · 2.4 MB"), image preview, voice note (play button + waveform bars + duration).
- Mentions: `#EEF1FF` background, `#1F3FD1` text, radius 6.
- "New messages" divider: 1px cobalt line + "New" label. Date divider: hairline + centered pill.
- Typing indicator: three dots in descending greys.

**Composer**
- Web: card with 16px radius + soft shadow; textarea on top, toolbar below (attach, bold, mention, emoji) and an ink "Send" button. Hint "Shift + Enter for a new line".
- iOS: round + button, pill input with emoji, ink circular mic/send button (mic when empty, send when typing).
- Android: filled pill input (`#F1F1F3`) with emoji + attach inside, separate 52px ink send FAB-circle.

## Screens

### Auth (web: `WebSignIn`, `WebSignUp`; iOS: `iOSSignIn`, `iOSSignUp`; Android: `AndroidSignIn`, `AndroidSignUp`)
- Web is a split layout: black brand panel (headline + live-chat preview on sign-in; 3-step onboarding stepper on sign-up) and a centered 400–420px form. Brand panel hides below 900px.
- Sign in: Google + passkey SSO, divider, email, password with show toggle, "Keep me signed in", Forgot password, primary CTA, link to sign-up.
- Sign up = step 1 of 3 (account → workspace name → invite team). Shows password strength (4 segments), live workspace URL preview `relay.app/<slug>`, terms checkbox.
- Mobile: step progress (iOS: 3 segments; Android: linear progress bar), primary CTA pinned to bottom.

### Chat (`WebChat`, `iOSChats` + `iOSThread`, `AndroidChats` + `AndroidThread`)
- Web is 4 panes: 72px black nav rail → 296px sidebar (workspace switcher, ⌘K search, Channels, Direct messages) → thread → 300px details panel (About, Members, Pinned, Files).
  Responsive: hide details <1240px, sidebar <820px, rail <560px.
- Thread header: channel name, topic, stacked member avatars, call / video / details buttons.
- iOS list: large title, search, filter pills (All / Unread / Channels / DMs), rows with 52px avatar, bold name + cobalt time when unread, preview, badge; read receipts on your own last message. Tab bar: Chats, Team, Activity, You.
- Android list: M3 search bar with avatar, filter chips, rows, extended FAB "New chat", navigation bar with pill indicator: Chats, Team, Activity, Settings.

### Team (`WebTeam`, `iOSTeam`, `AndroidTeam`)
- Web: title + "New group" / "Invite people"; members table with tabs (All / Admins / Guests / Pending), search, columns Member · Role · Groups · Status · actions (table scrolls horizontally on narrow screens). Right column: black "Invite teammates" card (email chips, role select, send, copyable invite link) and Groups list.
- iOS: large title, search, 3 group cards, grouped member list with role pills, black "Invite with a link" card.
- Android: top app bar, tabs (People / Groups / Pending), tonal invite card, sectioned list (Admins / Members) with message shortcut, FAB to invite.

## Navigation flows (as prototyped)

```
Sign in ──► Chat ◄──► Team
   ▲  │
   │  ▼
 Sign up ──► Chat
Chats list ──► Conversation ──back──► Chats list
```

## States to implement beyond the mockups

Empty chat list, empty channel ("Say hi 👋" with invite CTA), loading skeletons (rows + bubbles), offline banner, failed-to-send message (retry), upload progress on attachments, search results, dark mode (invert ground to `#0B0B0C`, surfaces `#17171A`, keep cobalt).

## Placeholders to replace

`[FREE PLAN LIMIT]` on the sign-up brand panel; `relay.app` domain; sample people and messages are fixtures only.
