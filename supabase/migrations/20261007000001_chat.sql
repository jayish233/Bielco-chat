-- Milestones 2–4: chat RPCs, invite links, realtime, storage.
-- Every new table/function repeats the M1 grant pattern (see m1-followups.md).

-- Helpers -------------------------------------------------------------------
create function public.try_uuid(t text) returns uuid
language plpgsql immutable set search_path = '' as $$
begin
  return t::uuid;
exception when others then
  return null;
end;
$$;

-- Profile trigger: a blank "" username falls back like a missing one.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  uname text;
begin
  uname := coalesce(
    nullif(lower(btrim(new.raw_user_meta_data->>'username')), ''),
    'user_' || left(replace(new.id::text, '-', ''), 8)
  );
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    uname,
    coalesce(nullif(btrim(new.raw_user_meta_data->>'display_name'), ''), uname)
  );
  return new;
end;
$$;

-- Messages: attachments must live under their conversation's folder ---------
alter table public.messages add constraint messages_attachment_path_in_conversation
  check (attachment_path is null or attachment_path like conversation_id::text || '/%');

-- Edits after a soft delete are blocked by RLS; deleting must not stamp edited_at.
create or replace function public.stamp_edited_at() returns trigger
language plpgsql as $$
begin
  if new.deleted_at is null and new.body is distinct from old.body then
    new.edited_at = now();
  end if;
  return new;
end;
$$;

-- Soft delete scrubs content (body, attachment) and drops reactions.
create function public.scrub_deleted_message() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.body := null;
    new.attachment_path := null;
    new.attachment_type := null;
    new.attachment_name := null;
    new.attachment_size := null;
    new.attachment_meta := null;
    delete from public.message_reactions where message_id = new.id;
  end if;
  return new;
end;
$$;
create trigger on_message_soft_deleted
  before update on public.messages
  for each row execute function public.scrub_deleted_message();

-- Last admin: when a group loses its last admin, promote the longest-standing member.
create function public.keep_group_admin() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.conversations where id = old.conversation_id and type = 'group')
     and not exists (
       select 1 from public.conversation_members
       where conversation_id = old.conversation_id and role = 'admin')
  then
    update public.conversation_members set role = 'admin'
    where (conversation_id, user_id) = (
      select conversation_id, user_id from public.conversation_members
      where conversation_id = old.conversation_id
      order by joined_at, user_id
      limit 1
    );
  end if;
  return null;
end;
$$;
create trigger on_member_removed
  after delete on public.conversation_members
  for each row execute function public.keep_group_admin();

-- Invite links --------------------------------------------------------------
create table public.conversation_invites (
  token text primary key default replace(gen_random_uuid()::text, '-', ''),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz
);
create index conversation_invites_conv_idx on public.conversation_invites (conversation_id);
alter table public.conversation_invites enable row level security;
revoke insert, update, delete, truncate, references, trigger
  on public.conversation_invites from anon, authenticated;
revoke select on public.conversation_invites from anon;
create policy invites_select on public.conversation_invites for select to authenticated
  using (public.is_admin(conversation_id));

-- RPCs ----------------------------------------------------------------------
create function public.get_or_create_dm(other_user_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  conv uuid;
begin
  if me is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if other_user_id is null or other_user_id = me then
    raise exception 'cannot start a chat with yourself' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = other_user_id) then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  -- Two people opening a DM with each other at once must get one conversation.
  perform pg_advisory_xact_lock(
    hashtextextended(least(me, other_user_id)::text || greatest(me, other_user_id)::text, 0));
  select c.id into conv
  from public.conversations c
  where c.type = 'direct'
    and exists (select 1 from public.conversation_members m
                where m.conversation_id = c.id and m.user_id = me)
    and exists (select 1 from public.conversation_members m
                where m.conversation_id = c.id and m.user_id = other_user_id)
  limit 1;
  if conv is null then
    insert into public.conversations (type, created_by) values ('direct', me)
      returning id into conv;
    insert into public.conversation_members (conversation_id, user_id, role)
      values (conv, me, 'member'), (conv, other_user_id, 'member');
  end if;
  return conv;
end;
$$;

create function public.create_group(group_name text, member_ids uuid[]) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  conv uuid;
begin
  if me is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  insert into public.conversations (type, name, created_by)
    values ('group', btrim(group_name), me)
    returning id into conv;
  insert into public.conversation_members (conversation_id, user_id, role)
    values (conv, me, 'admin');
  insert into public.conversation_members (conversation_id, user_id, role)
    select conv, p.id, 'member' from public.profiles p
    where p.id = any(coalesce(member_ids, '{}')) and p.id <> me;
  return conv;
end;
$$;

create function public.set_member_role(conv uuid, member uuid, new_role text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if new_role not in ('admin', 'member') then
    raise exception 'invalid role' using errcode = '22023';
  end if;
  if not public.is_admin(conv)
     or not exists (select 1 from public.conversations where id = conv and type = 'group') then
    raise exception 'only group admins can change roles' using errcode = '42501';
  end if;
  if new_role = 'member' and not exists (
    select 1 from public.conversation_members
    where conversation_id = conv and role = 'admin' and user_id <> member) then
    raise exception 'a group needs at least one admin' using errcode = '22023';
  end if;
  update public.conversation_members set role = new_role
  where conversation_id = conv and user_id = member;
end;
$$;

create function public.mark_read(conv uuid) returns void
language sql security definer set search_path = '' as $$
  update public.conversation_members
  set last_read_at = greatest(coalesce(last_read_at, '-infinity'::timestamptz), now())
  where conversation_id = conv and user_id = auth.uid();
$$;

create function public.get_conversation_list()
returns table (
  id uuid,
  type text,
  name text,
  avatar_url text,
  created_at timestamptz,
  last_message_at timestamptz,
  my_role text,
  last_read_at timestamptz,
  member_count int,
  unread_count int,
  other_user_id uuid,
  other_username text,
  other_display_name text,
  other_avatar_url text,
  last_message_id uuid,
  last_message_sender_id uuid,
  last_message_sender_name text,
  last_message_body text,
  last_message_attachment_type text,
  last_message_deleted boolean,
  last_message_created_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select
    c.id, c.type, c.name, c.avatar_url, c.created_at, c.last_message_at,
    me.role, me.last_read_at,
    (select count(*)::int from public.conversation_members m where m.conversation_id = c.id),
    (select count(*)::int from public.messages x
       where x.conversation_id = c.id
         and x.sender_id <> auth.uid()
         and x.deleted_at is null
         and (me.last_read_at is null or x.created_at > me.last_read_at)),
    o.id, o.username, o.display_name, o.avatar_url,
    lm.id, lm.sender_id, sp.display_name, lm.body, lm.attachment_type,
    lm.deleted_at is not null, lm.created_at
  from public.conversation_members me
  join public.conversations c on c.id = me.conversation_id
  left join lateral (
    select p.id, p.username, p.display_name, p.avatar_url
    from public.conversation_members om
    join public.profiles p on p.id = om.user_id
    where c.type = 'direct' and om.conversation_id = c.id and om.user_id <> auth.uid()
    limit 1
  ) o on true
  left join lateral (
    select m.id, m.sender_id, m.body, m.attachment_type, m.deleted_at, m.created_at
    from public.messages m
    where m.conversation_id = c.id
    order by m.created_at desc
    limit 1
  ) lm on true
  left join public.profiles sp on sp.id = lm.sender_id
  where me.user_id = auth.uid()
  order by coalesce(c.last_message_at, c.created_at) desc;
$$;

-- Returns the active invite for a group, creating one if needed. Admins only.
create function public.create_invite(conv uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  tok text;
begin
  if not public.is_admin(conv)
     or not exists (select 1 from public.conversations where id = conv and type = 'group') then
    raise exception 'only group admins can create invites' using errcode = '42501';
  end if;
  select token into tok from public.conversation_invites
  where conversation_id = conv and revoked_at is null
    and (expires_at is null or expires_at > now())
  order by created_at desc
  limit 1;
  if tok is null then
    insert into public.conversation_invites (conversation_id, created_by)
      values (conv, auth.uid())
      returning token into tok;
  end if;
  return tok;
end;
$$;

create function public.revoke_invites(conv uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin(conv) then
    raise exception 'only group admins can revoke invites' using errcode = '42501';
  end if;
  update public.conversation_invites set revoked_at = now()
  where conversation_id = conv and revoked_at is null;
end;
$$;

-- What a person sees before joining. Empty when the token is unknown or dead.
create function public.get_invite(invite_token text)
returns table (conversation_id uuid, name text, member_count int, is_member boolean)
language sql stable security definer set search_path = '' as $$
  select c.id, c.name,
    (select count(*)::int from public.conversation_members m where m.conversation_id = c.id),
    public.is_member(c.id)
  from public.conversation_invites i
  join public.conversations c on c.id = i.conversation_id
  where i.token = invite_token and i.revoked_at is null
    and (i.expires_at is null or i.expires_at > now());
$$;

create function public.join_via_invite(invite_token text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  conv uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  select i.conversation_id into conv from public.conversation_invites i
  where i.token = invite_token and i.revoked_at is null
    and (i.expires_at is null or i.expires_at > now());
  if conv is null then
    raise exception 'invite not found' using errcode = 'P0002';
  end if;
  insert into public.conversation_members (conversation_id, user_id, role)
    values (conv, auth.uid(), 'member')
    on conflict do nothing;
  return conv;
end;
$$;

revoke execute on function
  public.try_uuid(text),
  public.get_or_create_dm(uuid),
  public.create_group(text, uuid[]),
  public.set_member_role(uuid, uuid, text),
  public.mark_read(uuid),
  public.get_conversation_list(),
  public.create_invite(uuid),
  public.revoke_invites(uuid),
  public.get_invite(text),
  public.join_via_invite(text)
from public, anon;
grant execute on function
  public.try_uuid(text),
  public.get_or_create_dm(uuid),
  public.create_group(text, uuid[]),
  public.set_member_role(uuid, uuid, text),
  public.mark_read(uuid),
  public.get_conversation_list(),
  public.create_invite(uuid),
  public.revoke_invites(uuid),
  public.get_invite(text),
  public.join_via_invite(text)
to authenticated;

-- Trigger-only and internal helpers are not callable by clients.
revoke execute on function
  public.scrub_deleted_message(),
  public.keep_group_admin()
from public, anon, authenticated;

-- Realtime ------------------------------------------------------------------
alter publication supabase_realtime add table
  public.messages, public.message_reactions, public.conversation_members, public.conversations;

-- Storage -------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('attachments', 'attachments', false, 52428800),
  ('avatars', 'avatars', true, 5242880)
on conflict (id) do nothing;

-- attachments/{conversation_id}/{uuid}.{ext}: members only, checked on the object path.
create policy attachments_select on storage.objects for select to authenticated
  using (bucket_id = 'attachments'
         and public.is_member(public.try_uuid((storage.foldername(name))[1])));
create policy attachments_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments'
              and public.is_member(public.try_uuid((storage.foldername(name))[1])));
create policy attachments_delete on storage.objects for delete to authenticated
  using (bucket_id = 'attachments' and owner_id = (select auth.uid()::text));

-- avatars/{user_id}/{file}: public read via public URL; owners write their folder.
create policy avatars_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));
