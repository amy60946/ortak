-- "Aileye gönder" seçerek gönderim (migrations/20261102500000_plan_publish_selected.sql, uygulandı 2 Kasım 2026): bekletilen hedef/program/öneri
-- ailede eski hâlinde kalır, gerisi tek bildirimle gider; değişiklik yoksa bildirim gitmez; yetki.
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false); end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
create or replace function tst.fails(sql text, msg text) returns void language plpgsql as $$
begin
  begin execute sql;
  exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
-- RLS'siz okuyucular (test için)
create or replace function tst.nc(u uuid) returns integer language sql security definer as $$
  select count(*)::integer from public.notifications where user_id = u and kind in ('care_plan_shared', 'clinic_suggestion') $$;
create or replace function tst.gpub(g uuid) returns jsonb language sql security definer as $$
  select pub from public.clinic_goals where id = g $$;
create or replace function tst.mpub(m uuid) returns jsonb language sql security definer as $$
  select pub from public.care_modules where id = m $$;
create or replace function tst.st(t text) returns text language sql security definer as $$
  select string_agg(distinct status, ',') from public.clinic_task_suggestions where title = t $$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

-- ebeveyn a1, klinik sahibi d1, başka klinik d9
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Başka","name":"Dr. Can"}');
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Mira', 'tavşan' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
-- iki aileye açık hedef, iki hedefe bağlı bir program, bir rutin paketi (2 görev) ve bir tek görev taslağı
insert into public.clinic_goals (id, link_id, clinic_id, title, shared) values
  ('00000000-0000-0000-0000-0000000060a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Sabah rutini', true),
  ('00000000-0000-0000-0000-0000000060a2', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Ödev odağı', true);
insert into public.care_modules (id, link_id, clinic_id, title, status) values
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Övgü', 'active');
insert into public.care_module_goals (module_id, goal_id) values
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000060a1'),
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000060a2');
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, emoji, status, routine_group, routine_title, routine_position, goal_id, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, x.t, '⭐', 'draft', '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', x.p,
         '00000000-0000-0000-0000-0000000060a1', auth.uid()
  from public.clinic_links l, (values ('Yatağını topla', 0), ('Dişlerini fırçala', 1)) as x(t, p)
  where l.id = '00000000-0000-0000-0000-0000000011a1';
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, emoji, status, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'Çantanı hazırla', '🎒', 'draft', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1';

-- ------------------------------------------------ 1. yetki
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.fails($$select public.care_plan_publish_selected('00000000-0000-0000-0000-0000000011a1', '{}')$$, 'başka klinik gönderemez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.care_plan_publish_selected('00000000-0000-0000-0000-0000000011a1', '{}')$$, 'ebeveyn gönderemez');
select tst.fails($$select public.care_plan_snapshot_hold('00000000-0000-0000-0000-0000000011a1', '{}')$$, 'iç işlev doğrudan çağrılamaz');

-- ------------------------------------------------ 2. bekletilen hedef ve tek görev kalır, gerisi gider
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.care_plan_publish_selected('00000000-0000-0000-0000-0000000011a1', array[
  '00000000-0000-0000-0000-0000000060a2'::uuid,
  (select id from public.clinic_task_suggestions where title = 'Çantanı hazırla')]);
select tst.check(tst.gpub('00000000-0000-0000-0000-0000000060a1') ->> 'title' = 'Sabah rutini', 'seçilen hedef aileye gider');
select tst.check(tst.gpub('00000000-0000-0000-0000-0000000060a2') is null, 'bekletilen hedef ailede yok');
select tst.check(tst.mpub('00000000-0000-0000-0000-0000000070a1') -> 'goal_ids' = '["00000000-0000-0000-0000-0000000060a1"]'::jsonb,
  'program yalnız aileye gönderilmiş hedefi anar');
select tst.check(tst.st('Yatağını topla') = 'pending' and tst.st('Dişlerini fırçala') = 'pending', 'rutin paketi gider');
select tst.check(tst.st('Çantanı hazırla') = 'draft', 'bekletilen görev taslak kalır');
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1') = 1, 'tek bildirim');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_task_suggestions) = 2, 'aile bekletilen taslağı görmez');
select tst.check(json_array_length(public.family_care_plan('00000000-0000-0000-0000-0000000011a1') -> 'goals') = 1, 'ailenin planında tek hedef');

-- ------------------------------------------------ 3. değişiklik yoksa bildirim yok, hata yok
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.care_plan_publish_selected('00000000-0000-0000-0000-0000000011a1', array[
  '00000000-0000-0000-0000-0000000060a2'::uuid,
  (select id from public.clinic_task_suggestions where title = 'Çantanı hazırla')]);
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1') = 1, 'yeni bir şey yoksa bildirim gitmez');

-- ------------------------------------------------ 4. bekletilen hedefin değişikliği: eski gönderilmiş sürüm kalır
update public.clinic_goals set title = 'Sabah rutini (yeni ad)' where id = '00000000-0000-0000-0000-0000000060a1';
select public.care_plan_publish_selected('00000000-0000-0000-0000-0000000011a1', array['00000000-0000-0000-0000-0000000060a1'::uuid,
  '00000000-0000-0000-0000-0000000060a2'::uuid, (select id from public.clinic_task_suggestions where title = 'Çantanı hazırla')]);
select tst.check(tst.gpub('00000000-0000-0000-0000-0000000060a1') ->> 'title' = 'Sabah rutini', 'bekletilen değişiklik ailede eski hâliyle');
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1') = 1, 'hepsi bekletilince bildirim yok');

-- ------------------------------------------------ 5. boş bekletme listesi: hepsi gider, tek bildirim
select public.care_plan_publish_selected('00000000-0000-0000-0000-0000000011a1', null);
select tst.check(tst.gpub('00000000-0000-0000-0000-0000000060a1') ->> 'title' = 'Sabah rutini (yeni ad)', 'değişiklik gider');
select tst.check(tst.gpub('00000000-0000-0000-0000-0000000060a2') is not null, 'bekletilen hedef sonra gider');
select tst.check(jsonb_array_length(tst.mpub('00000000-0000-0000-0000-0000000070a1') -> 'goal_ids') = 2, 'program iki hedefi anar');
select tst.check(tst.st('Çantanı hazırla') = 'pending', 'bekletilen görev sonra gider');
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1') = 2, 'ikinci gönderim tek bildirim');
reset role;
select tst.check((select body from public.notifications where kind = 'care_plan_shared' order by created_at desc limit 1) like '%1 görev önerisi%',
  'bildirim metni plan ve öneriyi söyler');
set role authenticated;

-- ------------------------------------------------ 6. eski işlev aynı çalışır
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.clinic_goals set shared = false where id = '00000000-0000-0000-0000-0000000060a2';
select public.care_plan_publish('00000000-0000-0000-0000-0000000011a1');
select tst.check(tst.gpub('00000000-0000-0000-0000-0000000060a2') is null, 'eski işlev: gizlenen hedef ailede kalkar');
select tst.check(tst.mpub('00000000-0000-0000-0000-0000000070a1') -> 'goal_ids' = '["00000000-0000-0000-0000-0000000060a1"]'::jsonb,
  'eski işlev: program gizlenen hedefi anmaz');
