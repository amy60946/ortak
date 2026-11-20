-- Anket meslek seçenekleri genişledi (migrations/20261114100000_survey_professions.sql, uygulandı 14 Kasım 2026): yeni meslekler kaydedilir,
-- eski anahtarlar geçerli kalır, liste veri/uzman_anketi.json ile aynı (28 anahtar).
\set ON_ERROR_STOP on
create schema if not exists tst;
create or replace function tst.as_user(u uuid, aal text default 'aal1') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', json_build_object('aal', aal)::text, false);
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
grant usage on schema tst to anon, authenticated;
grant execute on all functions in schema tst to anon, authenticated;

insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, 'ece@example.com', '{"account":"clinician","clinic_name":"Mavi","name":"Ece"}');

select tst.check(cardinality(public.clinician_survey_keys('profession')) = 28, '28 meslek anahtarı');
select tst.check(public.clinician_survey_keys('profession') @> array['psikolog', 'klinik_psikolog', 'pdr', 'ergoterapist', 'dil_konusma',
  'ozel_egitim', 'cocuk_gelisimi', 'bcba', 'hekim', 'oyun_terapisti', 'sanat_terapisti', 'aile_danismani', 'okul_rehber', 'ogrenci', 'diger'],
  'eski anahtarların hepsi geçerli');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinician_survey_save('cocuk_terapisti', '{}', '{}', 'trial');
select tst.check((public.clinician_survey_me() ->> 'profession') = 'cocuk_terapisti', 'Çocuk ve ergen terapisti kaydedilir');
select public.clinician_survey_save('davranis_teknisyeni', '{}', '{}', 'trial');
select tst.check((public.clinician_survey_me() ->> 'profession') = 'davranis_teknisyeni', 'yeni meslek kaydedilir');
select public.clinician_survey_save('doktora_ogrencisi', '{}', '{}', 'trial');
select tst.check((public.clinician_survey_me() ->> 'profession') = 'doktora_ogrencisi', 'doktora öğrencisi kaydedilir');
select tst.fails($$select public.clinician_survey_save('astronot')$$, 'bilinmeyen meslek yine reddedilir');
reset role;
