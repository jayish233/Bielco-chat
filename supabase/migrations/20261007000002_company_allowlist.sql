-- Company-only access: only emails on public.allowed_emails can sign up or sign in.
-- Manage the list with SQL (Studio → SQL editor) or supabase/allowlist.sql; see README.

create table public.allowed_emails (
  email text primary key
    check (email = lower(btrim(email)) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  note text,
  added_at timestamptz not null default now()
);
alter table public.allowed_emails enable row level security;
-- No policies and no grants: clients can't read (no probing for coworkers) or write it.
revoke all on public.allowed_emails from anon, authenticated;

create function public.email_is_allowed(addr text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.allowed_emails where email = lower(btrim(coalesce(addr, '')))
  );
$$;

-- Auth hook: runs before GoTrue creates a user (sign-up). Rejects other emails.
create function public.hook_before_user_created(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if public.email_is_allowed(event->'user'->>'email') then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', 'email_not_allowed: This email isn''t on the company list. Ask your admin to add it.'
  ));
end;
$$;

-- Auth hook: runs whenever a token is issued (sign-in and every refresh), so
-- removing someone from the list locks them out within one token lifetime.
create function public.hook_custom_access_token(event jsonb) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  addr text;
begin
  select u.email into addr from auth.users u where u.id = (event->>'user_id')::uuid;
  if public.email_is_allowed(addr) then
    return jsonb_build_object('claims', event->'claims');
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', 'email_not_allowed: This account no longer has access. Ask your admin.'
  ));
end;
$$;

revoke execute on function
  public.email_is_allowed(text),
  public.hook_before_user_created(jsonb),
  public.hook_custom_access_token(jsonb)
from public, anon, authenticated;
grant usage on schema public to supabase_auth_admin;
grant execute on function
  public.hook_before_user_created(jsonb),
  public.hook_custom_access_token(jsonb)
to supabase_auth_admin;
