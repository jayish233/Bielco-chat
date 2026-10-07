begin;
select plan(28);

-- Test helper (invoker rights, so RLS applies): rows affected by a DML statement.
-- Data-modifying CTEs are not allowed inside a subselect, hence this wrapper.
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

-- Fixtures (superuser) ---------------------------------------------------------
-- A = ...01 (group admin), B = ...02 (member), C = ...03 (outsider)
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000001', 'a@example.com', '{"username":"user_a","display_name":"A"}'),
  ('00000000-0000-0000-0000-000000000002', 'b@example.com', '{"username":"user_b","display_name":"B"}'),
  ('00000000-0000-0000-0000-000000000003', 'c@example.com', '{"username":"user_c","display_name":"C"}');

insert into public.conversations (id, type, name, created_by) values
  ('00000000-0000-0000-0000-0000000000c1', 'group', 'G', '00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-0000000000d1', 'direct', null, '00000000-0000-0000-0000-000000000001');

insert into public.conversation_members (conversation_id, user_id, role) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'admin'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000002', 'member'),
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000001', 'admin'),
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000003', 'member');

insert into public.messages (id, conversation_id, sender_id, body) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'from A'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000002', 'from B'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000001', 'in DM');

insert into public.device_tokens (user_id, token, platform) values
  ('00000000-0000-0000-0000-000000000001', 'tok-a', 'android');

-- as C (outsider of G) ----------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);

select is((select count(*) from messages where conversation_id = '00000000-0000-0000-0000-0000000000c1'), 0::bigint, 'non-member cannot read messages');
select throws_ok($$insert into messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c1', 'hi')$$, '42501', null, 'non-member cannot post');
select is((select count(*) from conversations where id = '00000000-0000-0000-0000-0000000000c1'), 0::bigint, 'non-member cannot see conversation');

-- as B (member) -----------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);

select lives_ok($$insert into messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c1', 'hi')$$, 'member can post');
select throws_ok($$insert into messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'spoof')$$, '42501', null, 'cannot post as someone else');
select throws_ok($$insert into messages (conversation_id, body, created_at) values ('00000000-0000-0000-0000-0000000000c1', 'x', now() - interval '1 day')$$, '42501', null, 'cannot backdate');
select is(public.t_rows_affected($q$update messages set body = 'hacked' where id = '00000000-0000-0000-0000-0000000000a1'$q$), 0::bigint, 'non-sender cannot edit');
select throws_ok($$update messages set conversation_id = '00000000-0000-0000-0000-0000000000d1' where id = '00000000-0000-0000-0000-0000000000a2'$$, '42501', null, 'cannot move a message');
select throws_ok($$insert into conversation_members (conversation_id, user_id) values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000003')$$, '42501', null, 'non-admin cannot add members');
select throws_ok($$update conversation_members set role = 'admin' where user_id = '00000000-0000-0000-0000-000000000002'$$, '42501', null, 'cannot self-promote');
select is(public.t_rows_affected($q$delete from conversation_members where conversation_id = '00000000-0000-0000-0000-0000000000c1' and user_id = '00000000-0000-0000-0000-000000000001'$q$), 0::bigint, 'member cannot remove others');
select is(public.t_rows_affected($q$update profiles set display_name = 'x' where id = '00000000-0000-0000-0000-000000000001'$q$), 0::bigint, 'cannot edit others profile');
select is((select count(*) from device_tokens where user_id = '00000000-0000-0000-0000-000000000001'), 0::bigint, 'cannot read others device tokens');
select is((select count(*) from profiles where id in (
  '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003')),
  3::bigint, 'authenticated users read all profiles');
select throws_ok($$insert into message_reactions (message_id, user_id, emoji) values ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-000000000002', '👍')$$, '42501', null, 'cannot react outside your conversations');

-- as A (sender/admin) -----------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

select lives_ok($$insert into messages (id, conversation_id, body, reply_to_id) values ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000c1', 'reply', '00000000-0000-0000-0000-0000000000a2')$$, 'member can reply in same conversation');
select is((select count(*) from messages where id = '00000000-0000-0000-0000-0000000000a4' and reply_to_id = '00000000-0000-0000-0000-0000000000a2'), 1::bigint, 'reply row stored');
select throws_ok($$insert into messages (conversation_id, body, reply_to_id) values ('00000000-0000-0000-0000-0000000000c1', 'x', '00000000-0000-0000-0000-0000000000a3')$$, '42501', null, 'reply_to must be same conversation');
select ok(not has_table_privilege('authenticated', 'public.messages', 'TRUNCATE'), 'authenticated cannot TRUNCATE messages');
select is(public.t_rows_affected($q$update messages set body = 'edited' where id = '00000000-0000-0000-0000-0000000000a1'$q$), 1::bigint, 'sender can edit');
select is(public.t_rows_affected($q$update messages set deleted_at = now(), body = null where id = '00000000-0000-0000-0000-0000000000a1'$q$), 1::bigint, 'sender can soft-delete');
select is(public.t_rows_affected($q$update messages set body = 'undelete' where id = '00000000-0000-0000-0000-0000000000a1'$q$), 0::bigint, 'deleted message cannot be edited');
select lives_ok($$insert into conversation_members (conversation_id, user_id) values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000003')$$, 'admin adds member to group');
select throws_ok($$insert into conversation_members (conversation_id, user_id) values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000002')$$, '42501', null, 'nobody adds members to a DM');
select is(public.t_rows_affected($q$delete from conversation_members where conversation_id = '00000000-0000-0000-0000-0000000000d1' and user_id = '00000000-0000-0000-0000-000000000001'$q$), 0::bigint, 'cannot leave a DM');

-- as B again --------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);

select is(public.t_rows_affected($q$delete from conversation_members where conversation_id = '00000000-0000-0000-0000-0000000000c1' and user_id = '00000000-0000-0000-0000-000000000002'$q$), 1::bigint, 'member can leave group');
select is(public.t_rows_affected($q$update messages set body = 'late edit' where id = '00000000-0000-0000-0000-0000000000a2'$q$), 0::bigint, 'ex-member cannot edit own old message');

-- as anon -----------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is((select count(*) from profiles), 0::bigint, 'anon reads nothing');

reset role;
select * from finish();
rollback;
