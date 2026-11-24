-- Hesap silmeden önce şifreyle yeni giriş şartı (proposed/20261124100000_delete_recent_login.sql): bayrak kapalıyken eskisi gibi; açıkken
-- oturumda son 10 dakikada şifreyle giriş yoksa delete_account reddeder (ipucu recent_login_required); anonim hesap denetimin dışında.
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid, amr jsonb default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', case when amr is null then '{}' else jsonb_build_object('amr', amr)::text end, false);
end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
create or replace function tst.hint(sql text) returns text language plpgsql as $$
declare h text;
begin
  begin execute sql; exception when others then get stacked diagnostics h = pg_exception_hint; return coalesce(nullif(h, ''), sqlerrm); end;
  return 'NO_ERROR';
end $$;
create or replace function tst.amr(method text, ago interval) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('method', method, 'timestamp', extract(epoch from now() - ago)::bigint))
$$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000a3', false, '{"nickname":"Teyze"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}');

-- 1. bayrak yok: eski davranış (yeni giriş aranmaz)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a3');
select tst.check(not public.recent_password_login(), 'amr yok: yakın şifre girişi yok');
select public.delete_account();
reset role;
select tst.check(not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a3'), 'bayrak kapalı: hesap eskisi gibi silinir');

-- 2. bayrak açık
insert into public.feature_flags (key, enabled, rollout_pct) values ('delete_recent_login', true, 100)
  on conflict (key) do update set enabled = true, rollout_pct = 100;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(tst.hint('select public.delete_account()') = 'recent_login_required', 'amr yok: reddedilir');
select tst.as_user('00000000-0000-0000-0000-0000000000a1', tst.amr('password', interval '25 minutes'));
select tst.check(not public.recent_password_login() and tst.hint('select public.delete_account()') = 'recent_login_required', '25 dakika önceki şifre girişi yetmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1', tst.amr('otp', interval '1 minute'));
select tst.check(tst.hint('select public.delete_account()') = 'recent_login_required', 'e-posta bağlantısıyla açılan oturum yetmez (şifre girilmedi)');
select tst.as_user('00000000-0000-0000-0000-0000000000a1', '[{"method":"password","timestamp":"yarın"}, "password", {"method":"password"}]'::jsonb);
select tst.check(tst.hint('select public.delete_account()') = 'recent_login_required', 'bozuk amr kayıtları sayılmaz');
select tst.as_user('00000000-0000-0000-0000-0000000000a1', tst.amr('password', interval '-1 hour'));
select tst.check(tst.hint('select public.delete_account()') = 'recent_login_required', 'ileri tarihli kayıt sayılmaz');
reset role;
select tst.check(exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a1'), 'reddedilen denemelerde hesap duruyor');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1', tst.amr('otp', interval '3 hours') || tst.amr('password', interval '2 minutes'));
select tst.check(public.recent_password_login(), 'iki dakika önce şifreyle giriş: yakın');
select public.delete_account();
reset role;
select tst.check(not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a1'), 'şifreyle yeni girişten sonra hesap silinir');

-- 3. uzman hesabı da aynı kurala tabi
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.hint('select public.delete_account()') = 'recent_login_required', 'uzman: yeni giriş yoksa reddedilir');
select tst.as_user('00000000-0000-0000-0000-0000000000d1', tst.amr('password', interval '30 seconds'));
select public.delete_account();
reset role;
select tst.check(not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000d1'), 'uzman: şifreyle girişten sonra silinir');

-- 4. kişiye özel kapatma ve anonim hesap
insert into public.user_flags (user_id, key, enabled, reason) values ('00000000-0000-0000-0000-0000000000a2', 'delete_recent_login', false, 'deneme');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.delete_account();
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(tst.hint('select public.delete_account()') <> 'recent_login_required', 'anonim hesap (şifresi yok) bu denetime takılmaz');
reset role;
select tst.check(not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a2'), 'kişiye kapalıyken eski davranış');
select tst.check(not has_function_privilege('anon', 'public.delete_account()', 'execute')
             and not has_function_privilege('anon', 'public.recent_password_login(integer)', 'execute'), 'anon çağıramaz');
