-- 15 dakikalık kodlar + nedenli ret + IP sınırı (20261022100000_codes_15min.sql; deneme sınırı 20261021300000_security_pentest.sql).
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
-- Hata metnini döndürür (hata yoksa null)
create or replace function tst.err(sql text) returns text language plpgsql as $$
begin
  execute sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
-- SQL'i çalıştırır, PostgREST'e verilecek HTTP durumunu döndürür (aynı işlem içinde)
create or replace function tst.status(sql text) returns text language plpgsql as $$
begin
  execute sql;
  return current_setting('response.status', true);
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

-- a1 anne, a2 baba (davet edilir), c1/c2 çocuk cihazları (anonim), d1 uzman (klinik sahibi)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}');
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi');

-- 15 dakika
insert into tst.kv select 'child1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.check((select expires_at from public.invite_codes where code = tst.v('child1')) between now() + interval '14 minutes' and now() + interval '15 minutes', 'çocuk kodu 15 dakika geçerli');
insert into tst.kv select 'parent1', code from public.create_invite_code('parent', null);
select tst.check((select expires_at - created_at from public.invite_codes where code = tst.v('parent1')) <= interval '15 minutes', 'davet kodu 15 dakika geçerli');

-- yeni kod eskisini geçersiz kılar: eskisi "süresi doldu" der
insert into tst.kv select 'child2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(public.redeem_child_code(tst.v('child1')) ->> 'reason' = 'expired', 'eski kod: süresi doldu');
select tst.check(tst.status($$select public.redeem_child_code('YYYYYY')$$) = '400', 'hata yanıtı HTTP 400');
select tst.check(public.redeem_child_code(tst.v('child1')) ->> 'message' like 'Kodun süresi doldu%', 'Türkçe metin message alanında');
select tst.check(public.redeem_child_code('ZZZZZZ') ->> 'reason' = 'not_found', 'olmayan kod: bulunamadı');
select tst.fails($$select count(*) from public.code_attempts$$, 'istemci deneme tablosunu okuyamaz');
select tst.check(public.redeem_child_code('ZZZZZZ') ->> 'error' = 'invalid_code', 'hata kodu geriye uyumlu (invalid_code)');
reset role;
select tst.check((select count(*) from public.code_attempts where user_id = '00000000-0000-0000-0000-0000000000c1') = 5, 'beş hatalı deneme kaydedildi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
-- yeni kod çalışır
select tst.check(public.redeem_child_code(lower(tst.v('child2'))) ->> 'child_id' = '00000000-0000-0000-0000-00000000c001', 'yeni kod çalışır');
select tst.check(public.redeem_child_code(tst.v('child2')) ->> 'reason' = 'used', 'kullanılmış kod: daha önce kullanıldı');

-- süresi dolan davet kodu
reset role;
update public.invite_codes set expires_at = now() - interval '1 second' where code = tst.v('parent1');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(public.join_family(tst.v('parent1')) ->> 'reason' = 'expired', 'süresi dolan davet kodu');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'parent2', code from public.create_invite_code('parent', null);
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(public.join_family(tst.v('parent2')) ->> 'family_id' is not null, 'yeni davet koduyla katılım (json family_id)');
select tst.check(public.my_family_id() = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'baba aynı ailede');

-- deneme sınırı: oturum başına 15 dakikada 10 hata
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code('AAAAA' || x) from generate_series(1, 9) x;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'child3', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check(public.redeem_child_code('BBBBBB') ->> 'reason' = 'not_found', '10. hata hâlâ normal');
select tst.check(public.redeem_child_code(tst.v('child3')) ->> 'error' = 'too_many_attempts', '10 hatadan sonra doğru kod da engellenir');
select tst.check(tst.status($$select public.redeem_child_code(tst.v('child3'))$$) = '429', 'engel HTTP 429');
reset role;
select tst.check((select count(*) from public.code_attempts where user_id = '00000000-0000-0000-0000-0000000000c2') = 10, 'engel yanıtı deneme sayısını büyütmez');
update public.code_attempts set at = now() - interval '16 minutes' where user_id = '00000000-0000-0000-0000-0000000000c2';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check(public.redeem_child_code(tst.v('child3')) ->> 'child_id' is not null, '15 dakika sonra yeniden denenebilir');

-- IP sınırı: aynı IP'den farklı oturumlar toplam 30 hata
reset role;
delete from public.code_attempts;
insert into public.code_attempts (user_id, ip) select gen_random_uuid(), '203.0.113.7' from generate_series(1, 30);
set role authenticated;
select set_config('request.headers', '{"cf-connecting-ip":"203.0.113.7"}', false);
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(public.redeem_child_code('ZZZZZZ') ->> 'error' = 'too_many_attempts', 'aynı IP 30 hatadan sonra engelli');
select set_config('request.headers', '{"cf-connecting-ip":"198.51.100.1"}', false);
select tst.check(public.redeem_child_code('ZZZZZZ') ->> 'reason' = 'not_found', 'başka IP engelli değil');
select set_config('request.headers', '', false);

-- uzman kodları
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'fam', public.clinic_create_invite('family', 'Nazlı') ->> 'code';
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
select tst.check((select expires_at - created_at from public.clinic_invites where code = tst.v('fam')) between interval '47 hours 59 minutes' and interval '48 hours 1 minute', 'uzman aile daveti 48 saat (20261026100000)');
select tst.check((select expires_at - created_at from public.clinic_invites where code = tst.v('team')) <= interval '15 minutes', 'ekip kodu 15 dakika');
select tst.fails($$select public.redeem_child_code('ABCDEF')$$, 'uzman hesabı çocuk kodu kullanamaz (L7)');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.clinic_invite_preview(tst.v('fam')) ->> 'clinician' = 'Dr. Ece', 'geçerli kod önizlenir');
reset role;
update public.clinic_invites set expires_at = now() - interval '1 minute' where code = tst.v('fam');
set role authenticated;
select tst.check(public.clinic_invite_preview(tst.v('fam')) ->> 'reason' = 'expired', 'süresi dolan uzman kodu önizlenemez');
select tst.check(public.redeem_clinic_invite_children(tst.v('fam'), array['00000000-0000-0000-0000-00000000c001'::uuid]) ->> 'reason' = 'expired', 'süresi dolan uzman kodu paylaşım açmaz');
select tst.check(not exists (select 1 from public.clinic_links), 'paylaşım oluşmadı');

-- ekip kodu (giriş yapmış uzman clinic_join_team ile katılır)
reset role;
insert into auth.users (id, raw_user_meta_data) values ('00000000-0000-0000-0000-0000000000d2', '{"account":"clinician","name":"Dr. Can"}');
update public.clinic_invites set expires_at = now() - interval '1 minute' where code = tst.v('team');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(public.clinic_join_team(tst.v('team')) ->> 'reason' = 'expired', 'süresi dolan ekip kodu: süresi doldu');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team2', public.clinic_create_invite('clinician', '') ->> 'code';
select tst.check(char_length(tst.v('team2')) = 8, 'ekip kodu 8 karakter');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(public.clinic_join_team(tst.v('team2')) ->> 'clinic_id' is not null, 'yeni ekip koduyla katılım');
reset role;

select 'KOD TESTLERİ GEÇTİ' as sonuc;
