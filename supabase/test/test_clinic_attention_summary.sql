-- Dikkat panosu özeti (proposed/20261102600000_clinic_attention_summary.sql): sayılar, son olay, gönderilmemiş plan,
-- değerlendirme zamanı; yalnız görebildiği paylaşım (ekip üyesi, başka klinik, ebeveyn görmez).
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false); end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

-- ebeveyn a1, klinik sahibi d1, aynı klinikte ekip üyesi d2 (davet etmedi, atanmadı), başka klinik d9
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, '{"account":"clinician","clinic_name":"Geçici","name":"Mert"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Başka","name":"Dr. Can"}');
update public.clinicians set role = 'member',
  clinic_id = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1')
  where id = '00000000-0000-0000-0000-0000000000d2';
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Mira', 'tavşan' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';
-- ailenin kayıtları: görev günleri (biri bugün "yaptım", biri 20 gün önce), davranış kayıtları (2 yeni, 1 eski)
insert into public.tasks (id, family_id, title, start_date)
  select '00000000-0000-0000-0000-0000000088a1', family_id, 'Yatağını topla', current_date - 30 from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  select '00000000-0000-0000-0000-0000000088a1', '00000000-0000-0000-0000-00000000c0de', family_id, 'easy', 5 from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.completions (family_id, task_id, child_id, date, status, created_at, child_done_at)
  select family_id, '00000000-0000-0000-0000-0000000088a1', '00000000-0000-0000-0000-00000000c0de', x.d, 'pending', x.t, x.t
  from public.profiles, (values (current_date, now() - interval '1 hour'), (current_date - 20, now() - interval '20 days')) as x(d, t)
  where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.abc_events (family_id, child_id, behavior, created_at, occurred_at)
  select family_id, '00000000-0000-0000-0000-00000000c0de', x.b, x.t, x.t
  from public.profiles, (values ('Bağırdı', now() - interval '2 hours'), ('Kapıyı çarptı', now() - interval '3 days'),
                                ('Ağladı', now() - interval '20 days')) as x(b, t)
  where id = '00000000-0000-0000-0000-0000000000a1';

set role authenticated;
-- ------------------------------------------------ 1. plan: iki hedef, bir program; gönderilince plan_unsent 0
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_goals (id, link_id, clinic_id, title, shared, weeks) values
  ('00000000-0000-0000-0000-0000000060a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Sabah rutini', true, 6),
  ('00000000-0000-0000-0000-0000000060a2', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Ödev odağı', true, 6);
insert into public.care_modules (id, link_id, clinic_id, title, status) values
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Övgü', 'active');
insert into public.care_module_goals (module_id, goal_id) values ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000060a1');
select tst.check((select plan_unsent from public.clinic_attention_summary()) = 3, 'gönderilmemiş plan: 2 hedef + 1 program');
select public.care_plan_publish('00000000-0000-0000-0000-0000000011a1');
select tst.check((select plan_unsent from public.clinic_attention_summary()) = 0, 'gönderilince plan_unsent 0');
update public.clinic_goals set target = '7 günün 5''i' where id = '00000000-0000-0000-0000-0000000060a2';
select tst.check((select plan_unsent from public.clinic_attention_summary()) = 1, 'değişen hedef sayılır');

-- ------------------------------------------------ 2. değerlendirme zamanı: eklenişten 28 gün ya da süre sonu
reset role;
update public.clinic_goals set created_at = now() - interval '50 days' where id = '00000000-0000-0000-0000-0000000060a1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select goals_active from public.clinic_attention_summary()) = 2, 'süren hedef sayısı');
select tst.check((select review_due from public.clinic_attention_summary()) = 1, 'eklenişten 50 gün, değerlendirme yok: zamanı geldi');
insert into public.goal_ratings (goal_id, clinic_id, week, rating)
  values ('00000000-0000-0000-0000-0000000060a1', public.my_clinic_id(), date_trunc('week', now() - interval '20 days')::date, 0);
select tst.check((select review_due from public.clinic_attention_summary()) = 1, 'süre doldu (6 hafta), son haftasında değerlendirilmedi');
insert into public.goal_ratings (goal_id, clinic_id, week, rating)
  values ('00000000-0000-0000-0000-0000000060a1', public.my_clinic_id(), date_trunc('week', now())::date, 1);
select tst.check((select review_due from public.clinic_attention_summary()) = 0, 'bu hafta değerlendirildi');

-- ------------------------------------------------ 3. öneriler: taslak paket + tek taslak, bekleyen, kararlar
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, emoji, status, routine_group, routine_title, routine_position, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, x.t, '⭐', 'draft', '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', x.p, auth.uid()
  from public.clinic_links l, (values ('Dişlerini fırçala', 0), ('Giyin', 1)) as x(t, p) where l.id = '00000000-0000-0000-0000-0000000011a1';
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, emoji, status, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, x.t, '⭐', x.s, auth.uid()
  from public.clinic_links l, (values ('Çantanı hazırla', 'draft'), ('Kitap oku', 'pending'), ('Masanı topla', 'pending'), ('Su iç', 'pending'))
    as x(t, s) where l.id = '00000000-0000-0000-0000-0000000011a1';
reset role;
update public.clinic_task_suggestions set status = 'declined', decided_at = now() - interval '2 days' where title = 'Masanı topla';
update public.clinic_task_suggestions set status = 'accepted', decided_at = now() - interval '30 days' where title = 'Su iç';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select drafts from public.clinic_attention_summary()) = 2, 'taslak: rutin paketi tek sayılır + tek görev');
select tst.check((select pending from public.clinic_attention_summary()) = 1, 'ebeveyn kararı bekleyen');
select tst.check((select decided_7d from public.clinic_attention_summary()) = 1, 'son 7 günde karar');
select tst.check((select decided_last_at > now() - interval '3 days' from public.clinic_attention_summary()), 'son karar zamanı');

-- ------------------------------------------------ 4. aileden: görev günü, davranış kaydı, program uygulaması, son kayıt
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.care_module_logs (module_id, day, practiced) values ('00000000-0000-0000-0000-0000000070a1', (now() at time zone 'Europe/Istanbul')::date, true);
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select done_7d from public.clinic_attention_summary()) = 1, 'son 7 günde görev günü');
select tst.check((select abc_7d from public.clinic_attention_summary()) = 2, 'son 7 günde davranış kaydı');
select tst.check((select logs_7d from public.clinic_attention_summary()) = 1, 'son 7 günde program uygulaması');
select tst.check((select last_family_at > now() - interval '5 minutes' from public.clinic_attention_summary()), 'ailenin son kaydı (program uygulaması az önce)');
select tst.check((select plan_published_at is not null from public.clinic_attention_summary()), 'plan gönderim zamanı');

-- ------------------------------------------------ 5. kim görür
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((select count(*) from public.clinic_attention_summary()) = 0, 'atanmamış ekip üyesi görmez');
reset role;
insert into public.clinic_link_access (link_id, clinician_id, clinic_id)
  select '00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000000d2', clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2';
set role authenticated;
select tst.check((select count(*) from public.clinic_attention_summary()) = 1, 'sahip açınca ekip üyesi görür');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check((select count(*) from public.clinic_attention_summary()) = 0, 'başka klinik görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_attention_summary()) = 0, 'ebeveyn görmez');
-- paylaşım bitince satır yok
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
reset role;
update public.clinic_links set status = 'revoked' where id = '00000000-0000-0000-0000-0000000011a1';
set role authenticated;
select tst.check((select count(*) from public.clinic_attention_summary()) = 0, 'paylaşım bitince satır yok');
