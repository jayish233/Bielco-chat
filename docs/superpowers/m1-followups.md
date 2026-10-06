# Milestone 1 — follow-ups for Milestone 2+

Deferred during M1 review (all triaged "can wait" by the final whole-branch review). Pick these up while planning M2.

## Do early in M2
- **Default grants:** every new table/function must repeat the M1 revoke pattern (`revoke insert, update, truncate, references, trigger … from anon, authenticated`; `revoke execute … from public, anon` on SECURITY DEFINER RPCs). Optionally revoke DELETE on profiles/conversations/messages too.
- **pgTAP gaps:** anon access to every table, device_tokens CRUD and upsert-hijack, group rename (admin / member / DM), admin removes member, own-profile update, reactions read and hidden-after-leave.
- **Device tokens:** re-binding a token to a different user on the same device needs a SECURITY DEFINER RPC (RLS blocks the upsert today).
- **Last admin:** an admin can leave or remove the other admins, leaving a group with no admin. Decide the rule in the M2 RPCs.
- **Soft delete:** setting `deleted_at` doesn't null `body`. Enforce it in the delete path or RPC.
- **Auth form state:** `authFormControllerProvider` is shared across screens and reset on mount, which can flash the previous error for one frame. Move it to per-screen (`.family`) state.
- **Theme:** map the M3 `surfaceContainer*`, `outline` and `outlineVariant` roles before adding dialogs and menus (dark mode).

## Later
- **Error mapping:** narrow the `'23505'` / `'Database error saving new user'` mapping (match `profiles_username_key` first).
- **M3 storage:** never trust `messages.attachment_path` for access. Storage RLS must check the object path.
- **Profile trigger:** a blank `""` username isn't caught by the trigger's fallback (use `nullif(btrim(…),'')`).
- **UX polish:**
  - Disabling fields while submitting drops focus.
  - Use the `AutofillHints.username` hint on edit-profile.
  - Show a 404 page (errorBuilder) for unknown routes.
  - Add the live-chat preview to the brand panel.
  - Don't show the "Couldn't load your profile" error during a sign-out redirect.
- **Test gaps:**
  - Post-save profile reload.
  - A failed sign-out showing an error.
  - Narrow-phone and on-screen-keyboard layouts.
  - Every dark palette field.
  - The secondary button and focus-ring styles.
- **Housekeeping:** done. `dart format` has been run, the leftover Cupertino Icons comment is gone from `pubspec.yaml`, and `RelayPalette` implements `==` and `hashCode`.
