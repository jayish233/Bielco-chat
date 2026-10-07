begin;
select plan(43);

create function public.t_rows_affected(stmt text) returns bigint
language plpgsql as $$
declare n bigint;
begin
  execute stmt;
  get diagnostics n = row_count;
  return n;
end;
$$;
grant execute on function public.t_rows_affected(text) to authenticated;

-- Runs the rest of the statement as a given user (or reset to superuser with null).
create function public.t_as(uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
end;
$$;
grant execute on function public.t_as(uuid) to authenticated;

-- A, B, C, D
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000001', 'a@example.com', '{"username":"user_a","display_name":"A"}'),
  ('00000000-0000-0000-0000-000000000002', 'b@example.com', '{"username":"user_b","display_name":"B"}'),
  ('00000000-0000-0000-0000-000000000003', 'c@example.com', '{"username":"user_c","display_name":"C"}'),
  ('00000000-0000-0000-0000-000000000004', 'd@example.com', '{"username":"  ","display_name":"D"}');

select ok((select username like 'user\_%' from profiles where id = '00000000-0000-0000-0000-000000000004'),
  'blank username falls back to user_<id>');

create temp table t_ids (k text primary key, v uuid);
grant all on t_ids to authenticated;

-- DMs ---------------------------------------------------------------------------
set local role authenticated;
select public.t_as('00000000-0000-0000-0000-000000000001');

insert into t_ids values ('dm', public.get_or_create_dm('00000000-0000-0000-0000-000000000002'));
select isnt((select v from t_ids where k = 'dm'), null, 'get_or_create_dm returns an id');
select is(public.get_or_create_dm('00000000-0000-0000-0000-000000000002'), (select v from t_ids where k = 'dm'),
  'get_or_create_dm is idempotent');
select throws_ok($$select public.get_or_create_dm('00000000-0000-0000-0000-000000000001')$$, '22023', null,
  'cannot DM yourself');
select throws_ok($$select public.get_or_create_dm('00000000-0000-0000-0000-0000000000ff')$$, 'P0002', null,
  'cannot DM an unknown user');
select is((select type from conversations where id = (select v from t_ids where k = 'dm')), 'direct', 'DM is direct');
select is((select count(*) from conversation_members where conversation_id = (select v from t_ids where k = 'dm')),
  2::bigint, 'DM has both people');

select public.t_as('00000000-0000-0000-0000-000000000002');
select is(public.get_or_create_dm('00000000-0000-0000-0000-000000000001'), (select v from t_ids where k = 'dm'),
  'the other person gets the same DM');
select throws_ok($$select public.create_invite((select v from t_ids where k = 'dm'))$$, '42501', null,
  'no invites for DMs');
select throws_ok($$select public.set_member_role((select v from t_ids where k = 'dm'), '00000000-0000-0000-0000-000000000001', 'member')$$,
  '42501', null, 'no roles in DMs');

-- Groups ------------------------------------------------------------------------
select public.t_as('00000000-0000-0000-0000-000000000001');
insert into t_ids values ('g', public.create_group('  Friends ',
  array['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000ff']::uuid[]));
select is((select name from conversations where id = (select v from t_ids where k = 'g')), 'Friends', 'group name trimmed');
select is((select role from conversation_members where conversation_id = (select v from t_ids where k = 'g')
           and user_id = '00000000-0000-0000-0000-000000000001'), 'admin', 'creator is admin');
select is((select count(*) from conversation_members where conversation_id = (select v from t_ids where k = 'g')),
  2::bigint, 'creator + valid members only (no duplicates, unknown ids skipped)');
select throws_ok($$select public.create_group('   ', '{}')$$, '23514', null, 'blank group name rejected');

-- messages + list
insert into messages (conversation_id, body) values ((select v from t_ids where k = 'g'), 'hello group');
select is((select last_message_body from get_conversation_list() where id = (select v from t_ids where k = 'g')),
  'hello group', 'list shows last message');
select is((select unread_count from get_conversation_list() where id = (select v from t_ids where k = 'g')),
  0, 'own messages are not unread');
select is((select count(*) from get_conversation_list()), 2::bigint, 'A sees DM + group');

select public.t_as('00000000-0000-0000-0000-000000000002');
select is((select unread_count from get_conversation_list() where id = (select v from t_ids where k = 'g')),
  1, 'B has one unread');
select is((select other_username from get_conversation_list() where id = (select v from t_ids where k = 'dm')),
  'user_a', 'DM row names the other person');
select lives_ok($$select public.mark_read((select v from t_ids where k = 'g'))$$, 'mark_read');
select is((select unread_count from get_conversation_list() where id = (select v from t_ids where k = 'g')),
  0, 'mark_read clears unread');
select throws_ok($$select public.set_member_role((select v from t_ids where k = 'g'), '00000000-0000-0000-0000-000000000002', 'admin')$$,
  '42501', null, 'member cannot promote');
select throws_ok($$select public.create_invite((select v from t_ids where k = 'g'))$$, '42501', null,
  'member cannot create invites');

select public.t_as('00000000-0000-0000-0000-000000000003');
select is((select count(*) from get_conversation_list()), 0::bigint, 'outsider sees no conversations');
select lives_ok($$select public.mark_read((select v from t_ids where k = 'g'))$$, 'mark_read as outsider is a no-op');

-- Invites -----------------------------------------------------------------------
select public.t_as('00000000-0000-0000-0000-000000000001');
create temp table t_tok (k text primary key, v text);
grant all on t_tok to authenticated;
insert into t_tok values ('inv', public.create_invite((select v from t_ids where k = 'g')));
select is(public.create_invite((select v from t_ids where k = 'g')), (select v from t_tok where k = 'inv'),
  'create_invite reuses the active link');
select is((select count(*) from conversation_invites), 1::bigint, 'admin can read invites');

select public.t_as('00000000-0000-0000-0000-000000000003');
select is((select count(*) from conversation_invites), 0::bigint, 'non-admin cannot read invites');
select is((select name from get_invite((select v from t_tok where k = 'inv'))), 'Friends', 'invite preview shows group name');
select is((select count(*) from get_invite('nope')), 0::bigint, 'unknown token previews nothing');
select throws_ok($$select public.join_via_invite('nope')$$, 'P0002', null, 'unknown token cannot join');
select is(public.join_via_invite((select v from t_tok where k = 'inv')), (select v from t_ids where k = 'g'),
  'join_via_invite joins the group');
select is(public.join_via_invite((select v from t_tok where k = 'inv')), (select v from t_ids where k = 'g'),
  'joining twice is harmless');
select is((select role from conversation_members where conversation_id = (select v from t_ids where k = 'g')
           and user_id = '00000000-0000-0000-0000-000000000003'), 'member', 'joined as member');

select public.t_as('00000000-0000-0000-0000-000000000001');
select lives_ok($$select public.revoke_invites((select v from t_ids where k = 'g'))$$, 'admin revokes links');
select public.t_as('00000000-0000-0000-0000-000000000004');
select throws_ok($$select public.join_via_invite((select v from t_tok where k = 'inv'))$$, 'P0002', null,
  'revoked link no longer works');

-- Roles + last admin ------------------------------------------------------------
select public.t_as('00000000-0000-0000-0000-000000000001');
select throws_ok($$select public.set_member_role((select v from t_ids where k = 'g'), '00000000-0000-0000-0000-000000000001', 'member')$$,
  '22023', null, 'last admin cannot demote themselves');
select is(public.t_rows_affected($q$delete from conversation_members where conversation_id = (select v from t_ids where k = 'g') and user_id = '00000000-0000-0000-0000-000000000001'$q$),
  1::bigint, 'last admin can leave');
select public.t_as('00000000-0000-0000-0000-000000000002');
select is((select role from conversation_members where conversation_id = (select v from t_ids where k = 'g')
           and user_id = '00000000-0000-0000-0000-000000000002'), 'admin', 'longest-standing member is promoted');

-- Soft delete scrubs content ----------------------------------------------------
insert into messages (id, conversation_id, body) values
  ('00000000-0000-0000-0000-0000000000a9', (select v from t_ids where k = 'g'), 'secret');
insert into message_reactions (message_id, user_id, emoji) values
  ('00000000-0000-0000-0000-0000000000a9', '00000000-0000-0000-0000-000000000002', '👍');
update messages set deleted_at = now() where id = '00000000-0000-0000-0000-0000000000a9';
select is((select body from messages where id = '00000000-0000-0000-0000-0000000000a9'), null, 'deleted body is scrubbed');
select is((select edited_at from messages where id = '00000000-0000-0000-0000-0000000000a9'), null, 'deleting is not editing');
select is((select count(*) from message_reactions where message_id = '00000000-0000-0000-0000-0000000000a9'),
  0::bigint, 'deleted message loses reactions');

-- Attachments must live under their conversation folder -------------------------
select throws_ok($$insert into messages (conversation_id, attachment_path, attachment_type)
  values ((select v from t_ids where k = 'g'), (select v from t_ids where k = 'dm')::text || '/x.png', 'image')$$,
  '23514', null, 'attachment path must match the conversation');

reset role;
select * from finish();
rollback;
