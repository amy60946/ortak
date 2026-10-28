-- Günlük rutin v2 (migrations/20261028200000_routines_v2.sql): paket öneri + hedef bağı, görevin rutini, uzmanın kendi rutinleri
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
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

-- ebeveyn a1, başka aile e1, klinik sahibi d1, ekip üyesi d2 (d1'in kliniğinde), başka klinik d9
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
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Nazlı', 'flamingo' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0e1', family_id, 'Efe', 'kedi' from public.profiles where id = '00000000-0000-0000-0000-0000000000e1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011e1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000e1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0e1';
insert into public.clinic_goals (id, link_id, clinic_id, title) values
  ('00000000-0000-0000-0000-0000000060a1', '00000000-0000-0000-0000-0000000011a1',
   (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1'), 'Sabah rutinini hatırlatmasız bitirir'),
  ('00000000-0000-0000-0000-0000000060e1', '00000000-0000-0000-0000-0000000011e1',
   (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1'), 'Başka çocuğun hedefi');

set role authenticated;

-- ------------------------------------------------ B + D: rutin paketi, hedef bağı
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, emoji, difficulty, reminder, repeat_kind, repeat_days,
    routine_group, routine_title, routine_icon, routine_position, routine_key, goal_id, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, x.t, x.e, 'easy', x.r, 'weekly', '{1,2,3,4,5}',
    '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', 'sunny-outline', x.p, 'morning', '00000000-0000-0000-0000-0000000060a1', auth.uid()
  from public.clinic_links l,
    (values ('Yatağını topla', '🛏️', '07:05', 0), ('Dişlerini fırçala', '🪥', '07:15', 1), ('Kahvaltını yap', '🥣', '07:30', 2)) as x(t, e, r, p)
  where l.id = '00000000-0000-0000-0000-0000000011a1';
select tst.check((select count(*) from public.clinic_task_suggestions where routine_group = '00000000-0000-0000-0000-0000000077a1') = 3,
  'rutin paketi: üç ayrı öneri aynı grupta');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, routine_group, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', gen_random_uuid(), auth.uid() from public.clinic_links l
  where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'grupta rutin adı ve sırası zorunlu');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, goal_id, created_by)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', '00000000-0000-0000-0000-0000000060e1', auth.uid() from public.clinic_links l
  where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'başka çocuğun hedefi bağlanamaz');
select tst.check((select count(*) from public.clinic_task_suggestions where goal_id = '00000000-0000-0000-0000-0000000060a1') = 3,
  'paket hedefe bağlı');

-- ebeveyn paketi görür, rutin alanlarını değiştiremez, görev görev karar verir
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(distinct routine_group) = 1 and min(routine_title) = 'Güne hazır sabah'
  from public.clinic_task_suggestions where child_id = '00000000-0000-0000-0000-00000000c0de'), 'aile paketi tek grup olarak okur');
select tst.fails($$update public.clinic_task_suggestions set routine_title = 'Başka' where child_id = '00000000-0000-0000-0000-00000000c0de'$$,
  'aile rutin adını değiştiremez');
-- "Hepsini ekle" (biri çıkarıldı): iki görev oluşur, biri reddedilir; görevler rutinine bağlı
insert into public.tasks (id, family_id, title, emoji, start_date, routine_id, routine_title, routine_icon, routine_position)
  select '00000000-0000-0000-0000-0000000088a1', family_id, 'Yatağını topla', '🛏️', current_date, '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', 'sunny-outline', 0
  from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.tasks (id, family_id, title, emoji, start_date, routine_id, routine_title, routine_position)
  select '00000000-0000-0000-0000-0000000088a2', family_id, 'Dişlerini fırçala', '🪥', current_date, '00000000-0000-0000-0000-0000000077a1', 'Güne hazır sabah', 1
  from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
update public.clinic_task_suggestions set status = 'accepted', decided_at = now(),
  task_id = case title when 'Yatağını topla' then '00000000-0000-0000-0000-0000000088a1'::uuid else '00000000-0000-0000-0000-0000000088a2'::uuid end
  where routine_group = '00000000-0000-0000-0000-0000000077a1' and title in ('Yatağını topla', 'Dişlerini fırçala');
update public.clinic_task_suggestions set status = 'declined', decided_at = now()
  where routine_group = '00000000-0000-0000-0000-0000000077a1' and title = 'Kahvaltını yap';
select tst.check((select count(*) from public.tasks where routine_id = '00000000-0000-0000-0000-0000000077a1') = 2,
  'kabul edilen her görev ayrı görev, aynı rutine bağlı');
select tst.fails($$insert into public.tasks (family_id, title, start_date, routine_id)
  select family_id, 'x', current_date, gen_random_uuid() from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'$$, 'görevde rutin adı zorunlu');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) filter (where status = 'accepted') = 2 and count(*) filter (where status = 'declined') = 1
  from public.clinic_task_suggestions where routine_group = '00000000-0000-0000-0000-0000000077a1'), 'uzman paketin 2/3 eklendiğini görür');

-- ------------------------------------------------ C: uzmanın kendi rutinleri
insert into public.clinic_routines (id, clinic_id, title, icon, repeat, ages, items) values
  ('00000000-0000-0000-0000-0000000099a1', '00000000-0000-0000-0000-000000000000', 'Uyku öncesi sakinleşme', 'moon-outline', 'daily', '{A,B}',
   '[{"title":"Ekranları kapat","emoji":"📵","difficulty":"hard","time":"20:00"},{"key":"gs_mind_005","title":"5 kez derin nefes al","emoji":"🌬️","difficulty":"easy","coins":5,"time":"20:10"}]');
select tst.check((select clinic_id = public.my_clinic_id() and created_by = auth.uid() from public.clinic_routines
  where id = '00000000-0000-0000-0000-0000000099a1'), 'klinik ve oluşturan sunucuda yazılır (uydurulan klinik yok sayılır)');
select tst.fails($$insert into public.clinic_routines (title, items) values ('Boş', '[]')$$, 'görevsiz rutin olmaz');
select tst.fails($$insert into public.clinic_routines (title, items) values ('x', '[{"title":"a","time":"25:00"}]')$$, 'geçersiz saat');
select tst.fails($$insert into public.clinic_routines (title, items) values ('x', '[{"title":"a","coins":99}]')$$, 'ödül 50 üstü olamaz');
select tst.fails($$insert into public.clinic_routines (title, items) values ('x', '[{"title":"a","hack":true}]')$$, 'bilinmeyen alan');
select tst.fails($$insert into public.clinic_routines (title, items) values ('x', '[{"title":"a","days":[8]}]')$$, 'geçersiz gün');
select tst.fails($$insert into public.clinic_routines (title, ages, items) values ('x', '{Z}', '[{"title":"a"}]')$$, 'geçersiz yaş grubu');
select tst.fails($$insert into public.clinic_routines (title, items)
  select 'x', jsonb_agg(jsonb_build_object('title', 'g' || i)) from generate_series(1, 13) i$$, 'en çok 12 görev');
update public.clinic_routines set created_by = '00000000-0000-0000-0000-0000000000d9', title = 'Uyku öncesi'
  where id = '00000000-0000-0000-0000-0000000099a1';
select tst.check((select created_by = auth.uid() and title = 'Uyku öncesi' from public.clinic_routines where id = '00000000-0000-0000-0000-0000000099a1'),
  'oluşturan değiştirilemez');

-- ekip üyesi: kendi rutinini kurar; sahibin paylaşılmamış rutinini görmez, paylaşılınca görür ama düzenleyemez
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into public.clinic_routines (id, title, items) values ('00000000-0000-0000-0000-0000000099a2', 'Ödev öncesi', '[{"title":"Masanı düzenle"}]');
select tst.check((select count(*) from public.clinic_routines) = 1, 'üye yalnız kendi rutinini görür');
reset role;
update public.clinic_routines set shared = true where id = '00000000-0000-0000-0000-0000000099a1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((select count(*) from public.clinic_routines) = 2, 'ekibe açılan rutin üyeye görünür');
update public.clinic_routines set title = 'Değişti' where id = '00000000-0000-0000-0000-0000000099a1';
delete from public.clinic_routines where id = '00000000-0000-0000-0000-0000000099a1';
select tst.check((select title from public.clinic_routines where id = '00000000-0000-0000-0000-0000000099a1') = 'Uyku öncesi',
  'üye sahibin rutinini değiştiremez ve silemez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_routines) = 2, 'klinik sahibi ekibin bütün rutinlerini görür');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check((select count(*) from public.clinic_routines) = 0, 'başka klinik görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_routines) = 0, 'ebeveyn uzman rutinlerini görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
delete from public.clinic_routines where id = '00000000-0000-0000-0000-0000000099a2';
select tst.check((select count(*) from public.clinic_routines) = 1, 'klinik sahibi üyenin rutinini silebilir');
reset role;
