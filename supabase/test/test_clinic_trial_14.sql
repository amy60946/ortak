-- ClinicApp denemesi 14 gün (proposed/20261110130000_clinic_trial_14.sql)
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
grant usage on schema tst to anon, authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- ---------------------------------------------------------------- yeni kayıt: 14 gün
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Can"}');
select tst.check((select bool_and(trial_ends_at between now() + interval '13 days 23 hours' and now() + interval '14 days 1 minute')
                    from public.clinics where created_by = '00000000-0000-0000-0000-0000000000d1'), 'yeni klinik 14 gün dener');

-- ---------------------------------------------------------------- yeni alan: deneme ortak, yeni deneme vermez
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_workspace_create('Ece Danışmanlık');
reset role;
select tst.check((select count(distinct trial_ends_at) = 1 and count(*) >= 2
                    from public.clinics where created_by = '00000000-0000-0000-0000-0000000000d1'), 'yeni klinik alanı aynı deneme sonunu alır');

-- ---------------------------------------------------------------- süren 7 günlük deneme 14 güne tamamlanır
-- d2: 3 gün önce açılmış, eski kurala göre 7 gün. d1'e 20 gün önce açılmış, panelden 30 güne uzatılmış bir klinik eklenir.
update public.clinics set created_at = now() - interval '3 days', trial_ends_at = now() + interval '4 days'
 where created_by = '00000000-0000-0000-0000-0000000000d2';
insert into public.clinics (name, created_by, created_at, trial_ends_at)
values ('Uzatılmış', '00000000-0000-0000-0000-0000000000d1', now() - interval '20 days', now() + interval '30 days');
-- d1'in ilk açılışı artık 20 gün önce → 14 günü geçmiş; süren denemeleri kısalmaz, uzamaz
\ir ../proposed/20261110130000_clinic_trial_14.sql
select tst.check((select bool_and(trial_ends_at between now() + interval '10 days 23 hours' and now() + interval '11 days 1 minute')
                    from public.clinics where created_by = '00000000-0000-0000-0000-0000000000d2'), 'süren deneme açılıştan 14 güne tamamlandı (3 gün geçti, 11 gün kaldı)');
select tst.check((select trial_ends_at > now() + interval '29 days' from public.clinics where name = 'Uzatılmış'), 'panelden uzatılmış deneme kısalmadı');
select tst.check((select count(*) = 0 from public.clinics where created_by = '00000000-0000-0000-0000-0000000000d1'
                    and name <> 'Uzatılmış' and trial_ends_at > now() + interval '14 days 1 minute'), 'ilk açılışı 14 günü geçmiş uzmanın denemesi uzamadı');
\ir ../proposed/20261110130000_clinic_trial_14.sql
select tst.check((select bool_and(trial_ends_at between now() + interval '10 days 23 hours' and now() + interval '11 days 1 minute')
                    from public.clinics where created_by = '00000000-0000-0000-0000-0000000000d2'), 'ikinci çalıştırma değiştirmez');

-- ---------------------------------------------------------------- erişim
select tst.check(not has_function_privilege('anon', 'public.clinic_workspace_create(text)', 'execute'), 'anon klinik alanı açamaz');
select tst.check(not has_function_privilege('authenticated', 'public.clinician_personal_workspace_for(uuid)', 'execute'), 'iç işlev uygulamaya kapalı');
