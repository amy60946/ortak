-- 30 günlük misafir kartı (proposed/20261028120000_guest_pass.sql)
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
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

-- A: veren aile · B: yeni aile · C: eski aile (deneme 20 gün önce) · D: ikinci yeni aile
insert into auth.users (id, is_anonymous, raw_user_meta_data, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}', 'a@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000b1', false, '{"nickname":"Yeni"}', 'b@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000c1', false, '{"nickname":"Eski"}', 'c@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"nickname":"İkinci"}', 'd@ornek.com', now());
update public.families set trial_started_at = now() - interval '20 days' where created_by = '00000000-0000-0000-0000-0000000000c1';
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'code', public.create_guest_pass() ->> 'code';
select tst.check((select v from tst.kv where k = 'code') ~ '^[A-Z2-9]{8}$', 'kart kodu 8 karakter');
select tst.check(public.create_guest_pass() ->> 'code' = (select v from tst.kv where k = 'code'), 'kullanılmamış kart yeniden istenince aynı kod döner');
select tst.check((public.create_guest_pass() ->> 'new')::boolean = false, 'aynı kart: new=false');
select tst.check((select count(*) from public.guest_passes) = 1, 'aile kendi kartını görür');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code')) ->> 'error') = 'own', 'kendi kartını kullanamaz');
select tst.fails($$insert into public.guest_passes (code, family_id, created_by) values ('ABCDEFGH', public.my_family_id(), auth.uid())$$, 'kart doğrudan yazılamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code')) ->> 'error') = 'not_new', 'eski aile kullanamaz');
select tst.check((select count(*) from public.guest_passes) = 0, 'başka ailenin kartları görünmez');

select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check((public.family_access() ->> 'trial_days')::int = 7, 'yeni aile: 7 günlük deneme');
select tst.check((public.redeem_guest_pass('ZZZZZZZZ') ->> 'error') = 'not_found', 'olmayan kod');
select tst.check((public.redeem_guest_pass(lower((select v from tst.kv where k = 'code'))) ->> 'ok')::boolean, 'yeni aile kartı kullanır (küçük harf de olur)');
select tst.check((public.family_access() ->> 'trial_days')::int = 30, 'deneme 30 gün');
select tst.check((public.family_access() ->> 'guest_pass')::boolean, 'erişimde misafir kartı işareti');
select tst.check((public.family_access() ->> 'days_left')::int between 29 and 30, 'kalan gün ~30');
select tst.check(public.family_access() ->> 'state' = 'trial', 'durum deneme');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select redeemed_at is not null from public.guest_passes where code = (select v from tst.kv where k = 'code')), 'veren aile kullanıldığını görür');
select tst.check((select count(*) from public.notifications where kind = 'guest_pass_used') = 1, 'verene bildirim');
insert into tst.kv select 'code2', public.create_guest_pass() ->> 'code';
select tst.check((select v from tst.kv where k = 'code2') <> (select v from tst.kv where k = 'code'), 'kullanılan kartın yerine yeni kart');

select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code2')) ->> 'error') = 'already', 'bir aile ikinci kartı kullanamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code')) ->> 'error') = 'used', 'kullanılmış kart');
reset role;
update public.guest_passes set expires_at = now() - interval '1 minute' where code = (select v from tst.kv where k = 'code2');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code2')) ->> 'error') = 'expired', 'süresi dolmuş kart');
reset role;
select tst.check(not has_function_privilege('anon', 'public.create_guest_pass()', 'execute'), 'anon kart oluşturamaz');
select tst.check(not has_function_privilege('anon', 'public.redeem_guest_pass(text)', 'execute'), 'anon kart kullanamaz');
