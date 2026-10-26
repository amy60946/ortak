-- Güvenlik sıkılaştırma (20261021120000_security_hardening.sql).
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
grant usage on schema tst to anon;
grant execute on all functions in schema tst to anon;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}');
insert into tst.kv select 'fid', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.family_subscriptions (family_id, plan) values ((select v::uuid from tst.kv where k = 'fid'), 'premium');

-- girişsiz (anon) hiçbir uygulama fonksiyonunu çağıramaz
reset role;
select tst.check(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')), 'anon hiçbir public fonksiyonu çalıştıramaz');
select tst.check(has_function_privilege('authenticated', 'public.join_family(text)', 'execute'), 'giriş yapan join_family çağırabilir');
select tst.check(has_function_privilege('authenticated', 'public.clinic_create_invite(text, text, text, text)', 'execute'), 'giriş yapan uzman davet üretebilir');
select tst.check(has_function_privilege('authenticated', 'public.register_push_token(text, text, text)', 'execute'), 'push kaydı çalışır');
select tst.check(not has_function_privilege('authenticated', 'public.notify(uuid, text, text, text, text, jsonb, uuid, uuid)', 'execute'), 'iç fonksiyon kapalı kalır');
select tst.check(not exists (select 1 from information_schema.role_table_grants where grantee in ('anon', 'authenticated') and table_schema = 'public' and privilege_type = 'TRUNCATE'), 'TRUNCATE yetkisi yok');

set role anon;
select tst.rejects($$select public.clinic_invite_preview('ABCDEF')$$, 'anon kod önizleyemez');
select tst.fails($$select public.family_premium()$$, 'anon premium soramaz');
reset role;

-- family_premium: kendi ailesi evet, başka aile hayır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.family_premium(), 'kendi ailesi premium');
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check(not public.family_premium((select v::uuid from tst.kv where k = 'fid')), 'başka ailenin durumu sızmaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(not public.family_premium((select v::uuid from tst.kv where k = 'fid')), 'bağlantısız uzman soramaz');

reset role;
select 'TÜM GÜVENLİK TESTLERİ GEÇTİ' as sonuc;
