-- Destek formu kaynak sınırı ve davet e-postası gönderim sınırları (proposed/20261121110000_support_invite_limits.sql)
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
  begin execute sql; exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return; end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
create or replace function tst.sr(e text, src text, topic text default 'bug') returns jsonb language sql as $$
  select public.support_request_create('parent', topic, e, '', 'Uygulama açılmıyor, yardım lütfen', src) $$;
create or replace function tst.take(c text, u text) returns jsonb language sql as $$
  select public.clinic_invite_email_take(c, u::uuid) $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- =====================================================================
-- 1. Destek
-- =====================================================================
-- yetki ve RLS
set role anon;
select tst.fails($$select public.support_request_create('parent', 'bug', 'a@b.co', '', 'Uygulama açılmıyor lütfen', '1.2.3.4')$$, 'anon 6 parametreli işlevi çağıramaz');
select tst.fails($$select public.support_source_hash('1.2.3.4')$$, 'anon özet işlevini çağıramaz');
select tst.fails($$select count(*) from public.support_source_salts$$, 'anon tuzu okuyamaz');
reset role;
set role authenticated;
select tst.fails($$select public.support_request_create('parent', 'bug', 'a@b.co', '', 'Uygulama açılmıyor lütfen', '1.2.3.4')$$, 'kullanıcı doğrudan talep açamaz');
select tst.fails($$select count(*) from public.support_source_salts$$, 'kullanıcı tuzu okuyamaz');
select tst.fails($$select count(*) from public.invite_email_sends$$, 'kullanıcı gönderim kaydını okuyamaz');
reset role;
select tst.check((select relrowsecurity from pg_class where oid = 'public.support_source_salts'::regclass), 'tuz tablosunda RLS');
select tst.check((select relrowsecurity from pg_class where oid = 'public.invite_email_sends'::regclass), 'gönderim kaydında RLS');

set role service_role;
-- adres düz saklanmaz; IPv6 /64 tek kaynak
select tst.check(tst.sr('k1@example.com', '203.0.113.7') ? 'ref', 'kaynaklı talep');
reset role;
select tst.check((select source_hash ~ '^[0-9a-f]{64}$' and source_hash <> '203.0.113.7' from public.support_requests where email = 'k1@example.com'), 'kaynak özet olarak saklanır');
select tst.check(not exists (select 1 from public.support_requests where support_requests::text like '%203.0.113.7%'), 'adres düz yazılmaz');
select tst.check(public.support_source_hash('2001:db8:1:2::1') = public.support_source_hash('2001:db8:1:2:ffff::9'), 'IPv6 aynı /64 ağı tek kaynak');
select tst.check(public.support_source_hash('2001:db8:1:2::1') <> public.support_source_hash('2001:db8:1:3::1'), 'başka /64 ayrı kaynak');
select tst.check(public.support_source_hash('') is null and public.support_source_hash(null) is null, 'adres yoksa özet yok');

-- tek kaynaktan sel: saatte 5; başka kaynak etkilenmez
set role service_role;
select tst.sr('k' || g || '@example.com', '203.0.113.7') from generate_series(2, 5) g;
select tst.check(tst.sr('k6@example.com', '203.0.113.7') ->> 'error' = 'too_many_source', 'aynı kaynaktan saatte 5');
select tst.check(tst.sr('k7@example.com', '198.51.100.9') ? 'ref', 'başka kaynak etkilenmez');
reset role;
-- günde 15: saatlik pencere dışına itilmiş 14 kayıt + 1
update public.support_requests set created_at = now() - interval '2 hours' where email like 'k%@example.com' and email <> 'k7@example.com';
insert into public.support_requests (ref, app, topic, email, message, created_at, source_hash)
select 'D-G' || lpad(g::text, 5, '0'), 'other', 'other', 'gun' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '3 hours',
       public.support_source_hash('203.0.113.7')
  from generate_series(1, 9) g;
set role service_role;
select tst.check(tst.sr('g15@example.com', '203.0.113.7') ? 'ref', 'günün 15. talebi');
select tst.check(tst.sr('g16@example.com', '203.0.113.7') ->> 'error' = 'too_many_source', 'aynı kaynaktan günde 15');
reset role;
delete from public.support_requests;

-- 60 farklı e-posta tek kaynaktan: yalnız ilk 5'i girer, öteki kaynaklar ve genel sınır etkilenmez
set role service_role;
insert into tst.kv select 'flood', count(*) filter (where r ? 'ref')::text
  from (select tst.sr('sel' || g || '@example.com', '192.0.2.66') r from generate_series(1, 60) g) x;
select tst.check(tst.v('flood') = '5', '60 e-postalık selden 5 talep');
select tst.check(tst.sr('baska@example.com', '192.0.2.77') ? 'ref', 'selden sonra başka kişi talep açar');
reset role;
delete from public.support_requests;

-- genel sınır: 300 (istenmeyen sayılmaz); KVKK ayrı paydan
insert into public.support_requests (ref, app, topic, email, message, created_at, status)
select 'D-S' || lpad(g::text, 5, '0'), 'other', 'other', 'spam' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes', 'spam'
  from generate_series(1, 400) g;
set role service_role;
select tst.check(tst.sr('a1@example.com', '192.0.2.1') ? 'ref', 'istenmeyen işaretlenenler genel sınıra sayılmaz');
reset role;
insert into public.support_requests (ref, app, topic, email, message, created_at)
select 'D-T' || lpad(g::text, 5, '0'), 'other', 'other', 'top' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes'
  from generate_series(1, 300) g;
set role service_role;
select tst.check(tst.sr('a2@example.com', '192.0.2.2') ->> 'error' = 'busy', 'genel sınır 300 (son çare)');
select tst.check(tst.sr('a3@example.com', '192.0.2.3', 'privacy') ? 'ref', 'KVKK talebi genel sınır dolsa da kabul');
reset role;
insert into public.support_requests (ref, app, topic, email, message, created_at)
select 'D-P' || lpad(g::text, 5, '0'), 'other', 'privacy', 'kvkk' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes'
  from generate_series(1, 99) g;
set role service_role;
select tst.check(tst.sr('a4@example.com', '192.0.2.4', 'privacy') ->> 'error' = 'busy', 'KVKK payı saatte 100');
reset role;
delete from public.support_requests;

-- KVKK talebi kaynak sınırına tabidir
set role service_role;
select tst.sr('p' || g || '@example.com', '192.0.2.5', 'privacy') from generate_series(1, 5) g;
select tst.check(tst.sr('p6@example.com', '192.0.2.5', 'privacy') ->> 'error' = 'too_many_source', 'KVKK talebi de kaynak sınırında');
-- eski imza (kaynaksız) çalışır; e-posta sınırı sürer
select tst.check(public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep') ? 'ref', 'eski 5 parametreli imza');
reset role;
select tst.check((select source_hash is null from public.support_requests where email = 'eski@example.com'), 'eski imzada kaynak yok');
set role service_role;
select public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep 2');
select public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep 3');
select tst.check(public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep 4') ->> 'error' = 'too_many', 'e-posta başına 24 saatte 3 sürüyor');
reset role;
-- 2 günden eski özet boşaltılır
update public.support_requests set created_at = now() - interval '3 days' where email like 'p%@example.com';
set role service_role;
select tst.sr('yeni@example.com', '192.0.2.9');
reset role;
select tst.check(not exists (select 1 from public.support_requests where email like 'p%@example.com' and source_hash is not null), 'eski özet boşaltıldı');
delete from public.support_requests;

-- =====================================================================
-- 2. Davet e-postası
-- =====================================================================
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Can"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Mor","name":"Ali"}');
-- d1 ve d2 eski hesap; d3 yeni (ilk 24 saat)
update public.clinicians set created_at = now() - interval '10 days' where id in ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d2');

create or replace function tst.inv(u text, e text) returns text language plpgsql as $$
declare c text;
begin
  perform tst.as_user(u::uuid);
  set local role authenticated;
  c := public.clinic_create_invite('family', '', '', e) ->> 'code';
  reset role;
  return c;
end $$;

-- aynı alıcıya iki klinikten: günde 2
insert into tst.kv values ('i1', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
insert into tst.kv values ('i2', tst.inv('00000000-0000-0000-0000-0000000000d2', 'Hedef@Example.com'));
insert into tst.kv values ('i3', tst.inv('00000000-0000-0000-0000-0000000000d2', 'hedef@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i1'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'alıcıya 1. e-posta');
select tst.check(tst.take(tst.v('i2'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'alıcıya 2. e-posta (başka klinik)');
select tst.check(tst.take(tst.v('i3'), '00000000-0000-0000-0000-0000000000d2') ->> 'error' = 'rate_recipient', 'aynı alıcıya günde en çok 2 (kliniklerden bağımsız)');
-- gönderilemeyen sayılmaz
select public.clinic_invite_email_done(tst.v('i2'), false);
select tst.check(tst.take(tst.v('i3'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'gönderilemeyen e-posta alıcı sınırına sayılmaz');
select public.clinic_invite_email_done(tst.v('i3'), true);
reset role;
select tst.check(not exists (select 1 from public.invite_email_sends where to_hash like '%hedef%'), 'alıcı adres düz yazılmaz');
-- haftada 4: günlük pencere dışına itilmiş 2 gönderim + 2
update public.invite_email_sends set at = now() - interval '3 days';
insert into tst.kv values ('i4', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
insert into tst.kv values ('i5', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
insert into tst.kv values ('i6', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
update public.invite_email_sends set at = now() - interval '2 days' where at > now() - interval '1 day';
set role service_role;
select tst.check(tst.take(tst.v('i4'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'haftanın 3. e-postası');
reset role;
update public.invite_email_sends set at = now() - interval '2 days' where at > now() - interval '1 day';
set role service_role;
select tst.check(tst.take(tst.v('i5'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'haftanın 4. e-postası');
reset role;
update public.invite_email_sends set at = now() - interval '2 days' where at > now() - interval '1 day';
set role service_role;
select tst.check(tst.take(tst.v('i6'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'rate_recipient', 'aynı alıcıya haftada en çok 4');
reset role;
delete from public.invite_email_sends;

-- uzman başına günde 20 (eski hesap)
insert into public.invite_email_sends (clinician_id, code, to_hash)
select '00000000-0000-0000-0000-0000000000d1', 'X', md5(g::text) from generate_series(1, 20) g;
insert into tst.kv values ('i7', tst.inv('00000000-0000-0000-0000-0000000000d1', 'u7@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i7'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'rate_clinician', 'uzman başına günde 20 e-posta');
reset role;
delete from public.invite_email_sends;

-- yeni hesap ilk 24 saatte 5
insert into public.invite_email_sends (clinician_id, code, to_hash)
select '00000000-0000-0000-0000-0000000000d3', 'X', md5(g::text) from generate_series(1, 4) g;
insert into tst.kv values ('i8', tst.inv('00000000-0000-0000-0000-0000000000d3', 'u8@example.com'));
insert into tst.kv values ('i9', tst.inv('00000000-0000-0000-0000-0000000000d3', 'u9@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i8'), '00000000-0000-0000-0000-0000000000d3') ? 'to', 'yeni hesabın 5. e-postası');
select tst.check(tst.take(tst.v('i9'), '00000000-0000-0000-0000-0000000000d3') ->> 'error' = 'rate_clinician', 'yeni hesap ilk 24 saatte en çok 5');
reset role;
delete from public.invite_email_sends;

-- sistem genelinde saatte 200
insert into public.invite_email_sends (clinician_id, code, to_hash)
select null, 'X', md5(g::text) from generate_series(1, 200) g;
insert into tst.kv values ('i10', tst.inv('00000000-0000-0000-0000-0000000000d2', 'u10@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i10'), '00000000-0000-0000-0000-0000000000d2') ->> 'error' = 'rate_global', 'sistem genelinde saatte 200');
reset role;
-- 8 günden eski kayıt silinir
update public.invite_email_sends set at = now() - interval '9 days';
set role service_role;
select tst.check(tst.take(tst.v('i10'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'eski kayıt sayılmaz');
reset role;
select tst.check((select count(*) from public.invite_email_sends) = 1, '8 günden eski kayıt silindi');
