begin;
select plan(10);

insert into public.allowed_emails (email) values ('in@company.test');
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'in@company.test', '{"username":"inside"}'),
  ('00000000-0000-0000-0000-0000000000a2', 'gone@company.test', '{"username":"gone"}');

select is(public.hook_before_user_created('{"user":{"email":"in@company.test"}}'), '{}'::jsonb,
  'listed email may sign up');
select is(public.hook_before_user_created('{"user":{"email":"  IN@Company.test "}}'), '{}'::jsonb,
  'match ignores case and spaces');
select is((public.hook_before_user_created('{"user":{"email":"out@else.test"}}')->'error'->>'http_code')::int, 403,
  'other emails are rejected');
select ok(public.hook_before_user_created('{"user":{"email":"out@else.test"}}')->'error'->>'message' like 'email_not_allowed:%',
  'rejection carries the tag the app maps');
select is(public.hook_custom_access_token(
  '{"user_id":"00000000-0000-0000-0000-0000000000a1","claims":{"role":"authenticated"}}')->'claims'->>'role',
  'authenticated', 'listed user gets their token');
select is((public.hook_custom_access_token(
  '{"user_id":"00000000-0000-0000-0000-0000000000a2","claims":{}}')->'error'->>'http_code')::int, 403,
  'unlisted user gets no token');
select throws_ok($$insert into public.allowed_emails (email) values ('Not Lower@x.test')$$, '23514', null,
  'emails are stored trimmed and lowercase');

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000000a1', 'role', 'authenticated')::text, true);
select throws_ok($$select count(*) from public.allowed_emails$$, '42501', null, 'members cannot read the list');
select throws_ok($$select public.email_is_allowed('in@company.test')$$, '42501', null, 'members cannot probe the list');
reset role;
set local role anon;
select throws_ok($$select count(*) from public.allowed_emails$$, '42501', null, 'anon cannot read the list');

reset role;
select * from finish();
rollback;
