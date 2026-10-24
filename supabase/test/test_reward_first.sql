-- İlk ödül talebi bilgisi (proposed/20261024100000_welcome_coins_first_reward.sql).
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
create or replace function tst.fails(sql text, msg text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    raise notice 'ok (beklenen hata): % → %', msg, sqlerrm;
    return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}');
-- ebeveyn bildirimleri (kind reward_request): toplam / first=true olanlar / son bildirimin başlığı
create or replace function tst.req_n(u uuid) returns bigint language sql security definer as
  $$ select count(*) from public.notifications where user_id = u and kind = 'reward_request' $$;
create or replace function tst.req_first_n(u uuid) returns bigint language sql security definer as
  $$ select count(*) from public.notifications where user_id = u and kind = 'reward_request' and (data ->> 'first')::boolean is true $$;
create or replace function tst.req_last(u uuid) returns public.notifications language sql security definer as
  $$ select * from public.notifications where user_id = u and kind = 'reward_request' order by id desc limit 1 $$;
grant execute on function tst.req_n(uuid), tst.req_first_n(uuid), tst.req_last(uuid) to authenticated;
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'Efe', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Oda', current_date - 5, true, true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'hard', 0),
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'hard', 0);
insert into public.rewards (id, family_id, title, cost) values
  ('00000000-0000-0000-0000-0000000000b1', public.my_family_id(), 'Dondurma', 1),
  ('00000000-0000-0000-0000-0000000000b2', public.my_family_id(), 'Parkta 30 dakika', 1),
  ('00000000-0000-0000-0000-0000000000b3', public.my_family_id(), 'Film gecesi', 1);
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
insert into tst.kv select 'k2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c002');
insert into tst.kv select 'p', code from public.create_invite_code('parent', null);
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family(tst.v('p'));
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k1'));
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code(tst.v('k2'));

-- taş: her çocuğa 4 onay × 3 = 12 taş
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', c::uuid, d::date, 'approved')
  from generate_series(current_date - 3, current_date, interval '1 day') d,
       unnest(array['00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-00000000c002']) c;
-- ebeveynin doğrudan verdiği ödül çocuğun talebi sayılmaz
select public.give_reward('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000b3');

-- ilk talep: işaretli
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
insert into tst.kv select 'r1', public.request_reward('00000000-0000-0000-0000-0000000000b1')::text;
select tst.check((tst.v('r1')::jsonb ->> 'first')::boolean, 'ilk talepte yanıt first=true');
select tst.check(tst.req_n('00000000-0000-0000-0000-0000000000a1') = 1 and tst.req_n('00000000-0000-0000-0000-0000000000a2') = 1, 'iki ebeveyne istek bildirimi');
select tst.check(tst.req_first_n('00000000-0000-0000-0000-0000000000a1') = 1 and tst.req_first_n('00000000-0000-0000-0000-0000000000a2') = 1, 'ilk talep bildirimi first=true');
select tst.check((tst.req_last('00000000-0000-0000-0000-0000000000a1')).title = 'İlk ödül talebi: Nazlı bir ödül istiyor', 'ilk talep başlığı');
select tst.check((tst.req_last('00000000-0000-0000-0000-0000000000a1')).data ->> 'request_id' = tst.v('r1')::jsonb ->> 'request_id', 'bildirimde istek kimliği');

-- aynı ödülü yeniden isteme: yeni istek yok, yeni bildirim yok
select tst.check((public.request_reward('00000000-0000-0000-0000-0000000000b1') ->> 'first')::boolean = false, 'bekleyen isteği tekrar istemek first=false');
select tst.check(tst.req_n('00000000-0000-0000-0000-0000000000a1') = 1, 'tekrar istemek yeni bildirim üretmez');

-- ikinci talep: işaretsiz, eski başlık
select tst.check((public.request_reward('00000000-0000-0000-0000-0000000000b2') ->> 'first')::boolean = false, 'ikinci talepte first=false');
select tst.check(tst.req_n('00000000-0000-0000-0000-0000000000a1') = 2, 'ikinci talep de bildirilir');
select tst.check(tst.req_first_n('00000000-0000-0000-0000-0000000000a1') = 1, 'yalnız ilk talep işaretli');
select tst.check(not ((tst.req_last('00000000-0000-0000-0000-0000000000a1')).data ? 'first'), 'ikinci bildirimin verisinde first yok');
select tst.check((tst.req_last('00000000-0000-0000-0000-0000000000a1')).title = 'Nazlı bir ödül istiyor', 'ikinci talep başlığı eskisi gibi');

-- karar verilen / geri çekilen istekten sonra da işaret gelmez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.decide_reward_request((tst.v('r1')::jsonb ->> 'request_id')::uuid, false);
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.cancel_reward_request(id) from public.reward_requests where status = 'pending';
select tst.check((public.request_reward('00000000-0000-0000-0000-0000000000b1') ->> 'first')::boolean = false, 'reddedilen/geri çekilen istekten sonra first=false');
select tst.check(tst.req_first_n('00000000-0000-0000-0000-0000000000a2') = 1, 'ilk talep bilgisi bir kez');

-- kardeşin ilk talebi ayrı sayılır; geri çekip yeniden isteyince işaret yok
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
insert into tst.kv select 'r2', public.request_reward('00000000-0000-0000-0000-0000000000b2')::text;
select tst.check((tst.v('r2')::jsonb ->> 'first')::boolean, 'kardeşin ilk talebi first=true');
select tst.check(tst.req_first_n('00000000-0000-0000-0000-0000000000a1') = 2, 'ebeveyne kardeşin ilk talebi de işaretli');
select tst.check((tst.req_last('00000000-0000-0000-0000-0000000000a1')).title = 'İlk ödül talebi: Efe bir ödül istiyor', 'kardeşin ilk talep başlığı');
select tst.check((tst.req_last('00000000-0000-0000-0000-0000000000a1')).child_id = '00000000-0000-0000-0000-00000000c002', 'bildirim çocuğa bağlı');
select public.cancel_reward_request((tst.v('r2')::jsonb ->> 'request_id')::uuid);
select tst.check((public.request_reward('00000000-0000-0000-0000-0000000000b2') ->> 'first')::boolean = false, 'geri çekip yeniden isteyince first=false');
select tst.check(tst.req_first_n('00000000-0000-0000-0000-0000000000a1') = 2, 'işaretli bildirim sayısı değişmedi');

-- çocuk bildirim tablosuna yazamaz; anon çağıramaz
select tst.fails($$insert into public.notifications (user_id, app, kind, title, data) values ('00000000-0000-0000-0000-0000000000a1', 'parent', 'reward_request', 'x', '{"first": true}')$$, 'çocuk sahte ilk talep bildirimi yazamaz');
reset role;
select tst.check(not has_function_privilege('anon', 'public.request_reward(uuid, integer)', 'execute'), 'anon request_reward çağıramaz');

select 'İLK ÖDÜL TALEBİ TESTLERİ GEÇTİ' as sonuc;
