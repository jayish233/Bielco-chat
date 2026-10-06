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

-- Helpers -------------------------------------------------------------------
create function public.is_member(conv uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv and user_id = auth.uid()
  );
$$;

create function public.is_admin(conv uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv and user_id = auth.uid() and role = 'admin'
  );
$$;

create function public.username_available(name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select lower(name) ~ '^[a-z0-9_]{3,20}$'
    and not exists (select 1 from public.profiles where username = lower(name));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- Triggers ------------------------------------------------------------------
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  uname text;
begin
  uname := coalesce(
    lower(new.raw_user_meta_data->>'username'),
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
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.bump_last_message_at() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;
create trigger on_message_inserted
  after insert on public.messages
  for each row execute function public.bump_last_message_at();

create function public.stamp_edited_at() returns trigger
language plpgsql as $$
begin
  if new.body is distinct from old.body then
    new.edited_at = now();
  end if;
  return new;
end;
$$;
create trigger on_message_body_updated
  before update on public.messages
  for each row execute function public.stamp_edited_at();
