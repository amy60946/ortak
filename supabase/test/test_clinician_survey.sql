-- Uzman karşılama anketi (migrations/20261027100000_clinician_survey.sql, uygulandı 27 Ekim 2026)
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
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'ece@example.com', '{"account":"clinician","clinic_name":"Mavi","name":"Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, 'can@example.com', '{"account":"clinician","clinic_name":"Yeşil","name":"Can"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f1', 'viewer');

-- ---------------------------------------------------------------- 1. ilk giriş: cevap yok
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinician_survey_me() is null, 'cevap yokken null (anket gösterilir)');

-- ---------------------------------------------------------------- 2. kaydet, tekilleştir, güncelle
select public.clinician_survey_save('klinik_psikolog', array['home_data', 'home_followthrough', 'home_data'],
                                    array['plan_templates', 'progress_report'], 'trial');
select tst.check((public.clinician_survey_me() ->> 'profession') = 'klinik_psikolog', 'meslek kaydedildi');
select tst.check((public.clinician_survey_me() -> 'challenges') = '["home_data", "home_followthrough"]'::jsonb, 'tekrarlar tekilleşir, sıralı');
select tst.check((public.clinician_survey_me() ->> 'skipped')::boolean = false, 'geçilmedi');
select public.clinician_survey_save('oyun_terapisti', '{}', array['report_export'], 'family');
select tst.check((public.clinician_survey_me() ->> 'intent') = 'family' and (public.clinician_survey_me() -> 'challenges') = '[]'::jsonb, 'güncelleme üzerine yazar');

-- ---------------------------------------------------------------- 3. geçersiz anahtarlar
select tst.fails($$select public.clinician_survey_save('astronot')$$, 'bilinmeyen meslek');
select tst.fails($$select public.clinician_survey_save(null, array['uydurma'])$$, 'bilinmeyen zorluk');
select tst.fails($$select public.clinician_survey_save(null, '{}', array['uydurma'])$$, 'bilinmeyen özellik');
select tst.fails($$select public.clinician_survey_save(null, '{}', '{}', 'uydurma')$$, 'bilinmeyen neden');

-- ---------------------------------------------------------------- 4. "Şimdilik geç"
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select public.clinician_survey_save(null, '{}', '{}', null, true);
select tst.check((public.clinician_survey_me() ->> 'skipped')::boolean, 'geçmek de kayıt (bir daha sorulmaz)');

-- ---------------------------------------------------------------- 5. yetki ve gizlilik
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.clinician_survey_save('psikolog')$$, 'ebeveyn hesabı kaydedemez');
select tst.check(public.clinician_survey_me() is null, 'ebeveyn kimsenin cevabını görmez');
select tst.fails($$select count(*) from public.clinician_surveys$$, 'tabloya doğrudan erişim yok');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((public.clinician_survey_me() ->> 'profession') is null, 'uzman yalnız kendi cevabını görür');
reset role;
set role anon;
select tst.fails($$select public.clinician_survey_me()$$, 'anon çağıramaz');
select tst.fails($$select public.clinician_survey_save('psikolog')$$, 'anon kaydedemez');
reset role;

-- ---------------------------------------------------------------- 6. yönetim paneli: yalnız toplamlar
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1', 'aal2');
select tst.fails($$select public.admin_kpi_clinician_survey(90)$$, 'admin olmayan göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal1');
select tst.fails($$select public.admin_kpi_clinician_survey(90)$$, 'iki adımlı doğrulama gerekli');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
select tst.check((public.admin_kpi_clinician_survey(90) ->> 'answered')::int = 1, 'cevaplayan 1');
select tst.check((public.admin_kpi_clinician_survey(90) ->> 'skipped')::int = 1, 'geçen 1');
select tst.check((public.admin_kpi_clinician_survey(90) -> 'profession' ->> 'oyun_terapisti')::int = 1, 'meslek sayısı');
select tst.check((public.admin_kpi_clinician_survey(90) -> 'features' ->> 'report_export')::int = 1, 'özellik sayısı');
select tst.check((public.admin_kpi_clinician_survey(90) -> 'intent' ->> 'family')::int = 1, 'neden sayısı');
select tst.check(public.admin_kpi_clinician_survey(90)::text not like '%0000-0000%', 'kişi kimliği dönmez');
reset role;

-- ---------------------------------------------------------------- 7. hesap silinince cevap da silinir
delete from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2';
select tst.check(not exists (select 1 from public.clinician_surveys where clinician_id = '00000000-0000-0000-0000-0000000000d2'), 'uzman silinince cevap silinir');
