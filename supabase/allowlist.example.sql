-- Copy to supabase/allowlist.sql (gitignored) and list every coworker.
-- Applied on `supabase db reset`; for a hosted project, run it in the SQL editor.
insert into public.allowed_emails (email, note) values
  ('you@yourcompany.com', 'Owner'),
  ('coworker@yourcompany.com', null)
on conflict (email) do update set note = excluded.note;
