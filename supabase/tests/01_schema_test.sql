begin;
select plan(14);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000001', 'priya@example.com', '{"username":"priya","display_name":"Priya Sharma"}'),
  ('00000000-0000-0000-0000-000000000002', 'aisha@example.com', '{"username":"AISHA","display_name":"Aisha"}'),
  ('00000000-0000-0000-0000-000000000003', 'nometa@example.com', '{}');

insert into public.conversations (id, type, name, created_by) values
  ('00000000-0000-0000-0000-0000000000c1', 'group', 'Team', '00000000-0000-0000-0000-000000000001');

insert into public.messages (id, conversation_id, sender_id, body) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'hello');

select is((select username from profiles where id = '00000000-0000-0000-0000-000000000001'), 'priya', 'profile created from signup metadata');
select is((select display_name from profiles where id = '00000000-0000-0000-0000-000000000001'), 'Priya Sharma', 'display name copied');
select is((select username from profiles where id = '00000000-0000-0000-0000-000000000002'), 'aisha', 'username lowercased by trigger');
select matches((select username from profiles where id = '00000000-0000-0000-0000-000000000003'), '^user_[0-9a-f]{8}$', 'fallback username when metadata missing');

select throws_ok($$update profiles set username = 'Bad Name' where id = '00000000-0000-0000-0000-000000000001'$$, '23514', null, 'username format enforced');
select throws_ok($$insert into auth.users (id, email, raw_user_meta_data) values (gen_random_uuid(), 'x@x.com', '{"username":"priya"}')$$, '23505', null, 'duplicate username rejected');

select is(username_available('priya'), false, 'taken username unavailable');
select is(username_available('Priya'), false, 'case-insensitive');
select is(username_available('free_name'), true, 'free username available');
select is(username_available('ab'), false, 'invalid format is never available');

select throws_ok($$insert into messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', '   ')$$, '23514', null, 'blank message without attachment rejected');
select throws_ok($$insert into messages (conversation_id, sender_id, body) values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', repeat('a', 4001))$$, '23514', null, 'over-long body rejected');
select ok((select last_message_at from conversations where id = '00000000-0000-0000-0000-0000000000c1') = (select max(created_at) from messages where conversation_id = '00000000-0000-0000-0000-0000000000c1'), 'insert bumps last_message_at');

update public.messages set body = 'hello edited' where id = '00000000-0000-0000-0000-0000000000a1';
select isnt((select edited_at from messages where id = '00000000-0000-0000-0000-0000000000a1'), null, 'body update stamps edited_at');

select * from finish();
rollback;
