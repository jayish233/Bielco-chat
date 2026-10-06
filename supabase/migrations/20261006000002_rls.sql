-- Row-level security + column privileges ------------------------------------
alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.device_tokens enable row level security;

-- Column privileges: revoke table-level insert/update, grant back only listed columns.
revoke insert, update on
  public.profiles, public.conversations, public.conversation_members,
  public.messages, public.message_reactions, public.device_tokens
from anon, authenticated;

grant update (username, display_name, avatar_url, last_seen_at) on public.profiles to authenticated;
grant update (name, avatar_url) on public.conversations to authenticated;
grant insert (conversation_id, user_id) on public.conversation_members to authenticated;
grant insert (id, conversation_id, sender_id, body, reply_to_id, attachment_path,
              attachment_type, attachment_name, attachment_size, attachment_meta)
  on public.messages to authenticated;
grant update (body, deleted_at) on public.messages to authenticated;
grant insert (message_id, user_id, emoji) on public.message_reactions to authenticated;
grant insert (user_id, token, platform) on public.device_tokens to authenticated;
grant update (user_id, platform, updated_at) on public.device_tokens to authenticated;

revoke truncate, references, trigger on
  public.profiles, public.conversations, public.conversation_members,
  public.messages, public.message_reactions, public.device_tokens
from anon, authenticated;

-- profiles
create policy profiles_select on public.profiles for select to authenticated using (true);
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- conversations (no client INSERT: created via security definer RPCs)
create policy conversations_select on public.conversations for select to authenticated
  using (public.is_member(id));
create policy conversations_update on public.conversations for update to authenticated
  using (type = 'group' and public.is_admin(id))
  with check (type = 'group' and public.is_admin(id));

-- conversation_members
create policy members_select on public.conversation_members for select to authenticated
  using (public.is_member(conversation_id));
create policy members_insert on public.conversation_members for insert to authenticated
  with check (
    role = 'member' and public.is_admin(conversation_id)
    and exists (select 1 from public.conversations c where c.id = conversation_id and c.type = 'group')
  );
create policy members_delete on public.conversation_members for delete to authenticated
  using (
    exists (select 1 from public.conversations c where c.id = conversation_id and c.type = 'group')
    and (user_id = auth.uid() or public.is_admin(conversation_id))
  );

-- messages
create policy messages_select on public.messages for select to authenticated
  using (public.is_member(conversation_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid() and public.is_member(conversation_id)
    and (reply_to_id is null or exists (
      select 1 from public.messages r
      where r.id = messages.reply_to_id and r.conversation_id = messages.conversation_id))
  );
create policy messages_update on public.messages for update to authenticated
  using (sender_id = auth.uid() and deleted_at is null and public.is_member(conversation_id))
  with check (sender_id = auth.uid());

-- message_reactions
create policy reactions_select on public.message_reactions for select to authenticated
  using (exists (select 1 from public.messages m where m.id = message_id and public.is_member(m.conversation_id)));
create policy reactions_insert on public.message_reactions for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.messages m where m.id = message_id and public.is_member(m.conversation_id))
  );
create policy reactions_delete on public.message_reactions for delete to authenticated
  using (user_id = auth.uid());

-- device_tokens
create policy device_tokens_all on public.device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
