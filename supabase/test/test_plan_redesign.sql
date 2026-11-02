-- Takip planı yeniden tasarımı (proposed/20261102100000_plan_redesign.sql): program ↔ hedef, Şablonlarım,
-- öneri taslağı + tek gönderim, değişiklik önerisi, hedefe göre gruplu aile planı
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
-- bildirim sayısı (RLS'siz, test için)
create or replace function tst.nc(u uuid, k text) returns integer language sql security definer as $$
  select count(*)::integer from public.notifications where user_id = u and kind = k $$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

-- ebeveyn a1, başka aile e1, klinik sahibi d1, ekip üyesi d2, başka klinik d9
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, '{"account":"clinician","clinic_name":"Geçici","name":"Mert"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Başka","name":"Dr. Can"}');
update public.clinicians set role = 'member',
  clinic_id = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1')
  where id = '00000000-0000-0000-0000-0000000000d2';
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Mira', 'tavşan' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0e1', family_id, 'Efe', 'kedi' from public.profiles where id = '00000000-0000-0000-0000-0000000000e1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011e1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000e1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0e1';

set role authenticated;

-- ------------------------------------------------ 1. program ↔ hedef (çoklu)
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_goals (id, link_id, clinic_id, title, shared) values
  ('00000000-0000-0000-0000-0000000060a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Sabah rutinini hatırlatmasız bitirir', true),
  ('00000000-0000-0000-0000-0000000060a2', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Uzmanın kendine tuttuğu hedef', false),
  ('00000000-0000-0000-0000-0000000060e1', '00000000-0000-0000-0000-0000000011e1', public.my_clinic_id(), 'Başka çocuğun hedefi', true);
insert into public.care_modules (id, link_id, clinic_id, title, status, template_key) values
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Övgü ve olumlu pekiştirme', 'active', 'm_praise'),
  ('00000000-0000-0000-0000-0000000070a2', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Geçişlere hazırlık', 'planned', 'm_transitions');
insert into public.care_module_goals (module_id, goal_id) values
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000060a1'),
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000060a2'),
  ('00000000-0000-0000-0000-0000000070a2', '00000000-0000-0000-0000-0000000060a1');
select tst.check((select count(*) from public.care_module_goals where module_id = '00000000-0000-0000-0000-0000000070a1') = 2,
  'bir program iki hedefi destekler');
select tst.check((select bool_and(clinic_id = public.my_clinic_id()) from public.care_module_goals), 'klinik programdan yazılır');
select tst.fails($$insert into public.care_module_goals (module_id, goal_id) values
  ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000060e1')$$, 'başka çocuğun hedefine bağlanamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check((select count(*) from public.care_module_goals) = 0, 'başka klinik bağları görmez');
delete from public.care_module_goals;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.care_module_goals) = 3, 'başka klinik bağ silemez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.care_module_goals) = 0, 'aile bağ tablosunu doğrudan okumaz');

-- ------------------------------------------------ 3. taslak öneri: aile görmez, bildirim yok
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, emoji, status, reminder, repeat_kind, repeat_days,
    routine_group, routine_title, routine_icon, routine_position, routine_key, goal_id, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, x.t, x.e, 'draft', x.r, 'weekly', '{1,2,3,4,5}',
    '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', 'sunny-outline', x.p, 'morning', '00000000-0000-0000-0000-0000000060a1', auth.uid()
  from public.clinic_links l,
    (values ('Yatağını topla', '🛏️', '07:05', 0), ('Dişlerini fırçala', '🪥', '07:15', 1)) as x(t, e, r, p)
  where l.id = '00000000-0000-0000-0000-0000000011a1';
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1', 'clinic_suggestion') = 0, 'taslak bildirim üretmez');
select public.clinic_update_suggestion((select id from public.clinic_task_suggestions where title = 'Yatağını topla'), '{"reminder":"07:20"}');
select tst.check((select reminder from public.clinic_task_suggestions where title = 'Yatağını topla') = '07:20', 'uzman taslağı düzenler');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_task_suggestions) = 0, 'aile taslağı görmez');
update public.clinic_task_suggestions set status = 'accepted' where status = 'draft';
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_task_suggestions where status = 'draft') = 2, 'taslak ailenin güncellemesinden etkilenmez');

-- ------------------------------------------------ tek gönderim: plan + taslaklar, tek bildirim
select public.care_plan_publish('00000000-0000-0000-0000-0000000011a1');
select tst.check((select count(*) from public.clinic_task_suggestions where link_id = '00000000-0000-0000-0000-0000000011a1' and status = 'pending') = 2,
  'gönderim taslakları bekleyen yapar');
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1', 'care_plan_shared') = 1
  and tst.nc('00000000-0000-0000-0000-0000000000a1', 'clinic_suggestion') = 0, 'plan + öneriler için tek bildirim');
select tst.check((select body from public.notifications where kind = 'care_plan_shared' limit 1) is null, 'uzman ailenin bildirimini görmez');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_task_suggestions) = 2, 'aile gönderilen önerileri görür');
-- aile planı: program yalnız aileye açık hedefi taşır; planlandı programı yok
select tst.check((public.family_care_plan('00000000-0000-0000-0000-0000000011a1') -> 'modules' -> 0 -> 'goal_ids')::jsonb
  = '["00000000-0000-0000-0000-0000000060a1"]'::jsonb, 'program aileye yalnız açık hedefiyle gider');
select tst.check(json_array_length(public.family_care_plan('00000000-0000-0000-0000-0000000011a1') -> 'modules') = 1, 'planlandı programı aileye gitmez');
-- aile "Hepsini ekle": görevler rutinine bağlı, öneriler kabul
reset role;
insert into public.tasks (id, family_id, title, emoji, start_date, recurring, reminder, routine_id, routine_title, routine_position)
  select x.id, (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), x.t, x.e, current_date, true, x.r,
         '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', x.p
  from (values ('00000000-0000-0000-0000-0000000088a1'::uuid, 'Yatağını topla', '🛏️', '07:20', 0),
               ('00000000-0000-0000-0000-0000000088a2'::uuid, 'Dişlerini fırçala', '🪥', '07:15', 1)) as x(id, t, e, r, p);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  select t.id, '00000000-0000-0000-0000-00000000c0de', t.family_id, 'easy', 5 from public.tasks t where t.routine_id = '00000000-0000-0000-0000-0000000077a1';
-- başka ailenin görevi (değişiklik önerisi hedefi olamaz)
insert into public.tasks (id, family_id, title, start_date)
  select '00000000-0000-0000-0000-0000000088e1', family_id, 'Başka görev', current_date from public.profiles where id = '00000000-0000-0000-0000-0000000000e1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
update public.clinic_task_suggestions set status = 'accepted', decided_at = now(),
  task_id = case title when 'Yatağını topla' then '00000000-0000-0000-0000-0000000088a1'::uuid else '00000000-0000-0000-0000-0000000088a2'::uuid end
  where link_id = '00000000-0000-0000-0000-0000000011a1';
select tst.check((public.family_care_plan('00000000-0000-0000-0000-0000000011a1') -> 'routines' -> 0 ->> 'goal_id') = '00000000-0000-0000-0000-0000000060a1'
  and json_array_length(public.family_care_plan('00000000-0000-0000-0000-0000000011a1') -> 'routines' -> 0 -> 'task_ids') = 2
  and (public.family_care_plan('00000000-0000-0000-0000-0000000011a1') -> 'routines' -> 0 ->> 'title') = 'Güne hazır sabah',
  'aile planı: kabul edilen rutin hedefiyle ve görevleriyle');

-- ------------------------------------------------ 4. değişiklik önerisi
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, emoji, status, kind, target_task_id, reminder,
    routine_group, routine_title, routine_position, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'Yatağını topla', '🛏️', 'draft', 'change', '00000000-0000-0000-0000-0000000088a1', '07:35',
    '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', 0, auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1';
select tst.check((select count(*) from public.clinic_task_suggestions where kind = 'change') = 1, 'uzman ailedeki göreve değişiklik önerir (taslak)');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, status, kind, target_task_id, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'Yatağını topla', 'draft', 'change', '00000000-0000-0000-0000-0000000088a1', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'aynı göreve ikinci açık değişiklik önerisi olmaz');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, status, kind, target_task_id, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', 'draft', 'change', '00000000-0000-0000-0000-0000000088e1', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'başka ailenin görevine değişiklik önerilemez');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, status, kind, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', 'draft', 'change', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'değişiklik önerisi hedef görevsiz olmaz');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, status, kind, target_task_id, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', 'draft', 'new', '00000000-0000-0000-0000-0000000088a2', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'yeni öneride hedef görev olmaz');
select public.clinic_update_suggestion((select id from public.clinic_task_suggestions where kind = 'change'), '{"change_remove":true}');
select tst.check((select change_remove from public.clinic_task_suggestions where kind = 'change'), 'değişiklik önerisi: görevi bitir');
select public.care_plan_publish('00000000-0000-0000-0000-0000000011a1');
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1', 'care_plan_shared') = 2, 'değişiklik önerisi tek bildirimle gider');
reset role;
select tst.check((select body from public.notifications where kind = 'care_plan_shared' order by created_at desc limit 1) like '%1 değişiklik önerisi%',
  'bildirim metni değişiklik önerisini söyler');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select kind = 'change' and target_task_id = '00000000-0000-0000-0000-0000000088a1' and change_remove
  from public.clinic_task_suggestions where status = 'pending'), 'aile değişiklik önerisini ve hedef görevi görür');
-- ebeveyn uygular: ParentApp görevi günceller (bitiş tarihi), öneriyi kabul eder
update public.tasks set end_date = current_date where id = '00000000-0000-0000-0000-0000000088a1';
update public.clinic_task_suggestions set status = 'accepted', decided_at = now() where kind = 'change';
reset role;
select tst.check((select count(*) from public.notifications where kind = 'suggestion_decided' and title like 'Değişiklik uygulandı:%') = 1,
  'uzmana "Değişiklik uygulandı" bildirimi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.clinic_update_suggestion((select id from public.clinic_task_suggestions where kind = 'change'), '{"reminder":"08:00"}')$$,
  'karar verilmiş değişiklik önerisi düzenlenemez');

-- ------------------------------------------------ 2. Şablonlarım
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_plan_templates (title, shared, content, clinic_id, created_by) values
  ('Sabah seti · 6–8 yaş', true, '{"goal":{"title":"Sabah rutinini görsel çizelgeyle bitirir","template_key":"g_morning_routine","weeks":6},
    "modules":[{"template_key":"m_routine","title":"Rutin ve görsel çizelge","checklist":["a","b"]}],"routines":[{"key":"morning","title":"Güne hazır sabah"}]}',
   '00000000-0000-0000-0000-00000000dead', '00000000-0000-0000-0000-0000000000e1');
select tst.check((select clinic_id = public.my_clinic_id() and created_by = auth.uid() from public.clinic_plan_templates where title like 'Sabah seti%'),
  'şablonun kliniği ve yazarı sunucuda belirlenir');
select tst.fails($$insert into public.clinic_plan_templates (title, content) values ('x', '{"goal":{"title":""}}')$$, 'hedefsiz şablon olmaz');
select tst.fails($$insert into public.clinic_plan_templates (title, content) values ('x',
  jsonb_build_object('goal', '{"title":"t"}'::jsonb, 'modules', (select jsonb_agg('{"title":"m"}'::jsonb) from generate_series(1, 13))))$$, 'en çok 12 program');
select tst.fails($$insert into public.clinic_plan_templates (title, content) values ('x', '{"goal":{"title":"t"},"routines":[{"key":"morning"}]}')$$,
  'rutin adı zorunlu');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into public.clinic_plan_templates (title, shared, content) values ('Mert özel', false, '{"goal":{"title":"Ödeve başlar"}}');
select tst.check((select count(*) from public.clinic_plan_templates) = 2, 'ekip üyesi ekibe açılanı ve kendini görür');
update public.clinic_plan_templates set title = 'Değişti' where title like 'Sabah seti%';
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(exists (select 1 from public.clinic_plan_templates where title = 'Sabah seti · 6–8 yaş'), 'ekip üyesi başkasının şablonunu değiştiremez');
select tst.check((select count(*) from public.clinic_plan_templates) = 2, 'klinik sahibi hepsini görür');
update public.clinic_plan_templates set shared = false where title like 'Sabah seti%';
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((select count(*) from public.clinic_plan_templates) = 1, 'yalnız ben seçilince ekip görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check((select count(*) from public.clinic_plan_templates) = 0, 'başka klinik şablon görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_plan_templates) = 0, 'aile şablon görmez');

-- ------------------------------------------------ paylaşım bitince taslaklar silinir
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, status, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'Gönderilmemiş taslak', 'draft', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011e1';
reset role;
update public.clinic_links set status = 'revoked', revoked_at = now() where id = '00000000-0000-0000-0000-0000000011e1';
select tst.check(not exists (select 1 from public.clinic_task_suggestions where title = 'Gönderilmemiş taslak'), 'paylaşım bitince taslak silinir');

-- eski istemci: doğrudan bekleyen öneri eskisi gibi bildirir
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'Eski sürüm önerisi', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1';
select tst.check(tst.nc('00000000-0000-0000-0000-0000000000a1', 'clinic_suggestion') = 1, 'eski istemcinin önerisi hemen bildirir');
