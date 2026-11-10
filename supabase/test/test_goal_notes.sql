-- Hedefe bağlı uzman notu (proposed/20261103100000_goal_notes.sql): bağlanır, başka danışanın hedefine bağlanamaz,
-- hedef silinince not kalır (bağ boşalır), ebeveyn görmez; değerlendirme notu goal_ratings.note'a yazılır.
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

-- ebeveyn a1 (iki çocuk), klinik sahibi d1
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}');
insert into public.children (id, family_id, name, avatar)
  select x.id::uuid, family_id, x.n, 'tavşan' from public.profiles,
    (values ('00000000-0000-0000-0000-00000000c0de', 'Mira'), ('00000000-0000-0000-0000-00000000c0df', 'Can')) as x(id, n)
  where profiles.id = '00000000-0000-0000-0000-0000000000a1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select x.l::uuid, m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c,
    (values ('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-00000000c0de'),
            ('00000000-0000-0000-0000-0000000011a2', '00000000-0000-0000-0000-00000000c0df')) as x(l, ch)
  where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = x.ch::uuid;

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_goals (id, link_id, clinic_id, title) values
  ('00000000-0000-0000-0000-0000000060a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Sabah rutini'),
  ('00000000-0000-0000-0000-0000000060b1', '00000000-0000-0000-0000-0000000011a2', public.my_clinic_id(), 'Ödev odağı');

-- 1. hedefe not
insert into public.clinic_notes (id, link_id, clinic_id, author_id, body, goal_id) values
  ('00000000-0000-0000-0000-00000000e0a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), auth.uid(),
   'Çizelge buzdolabında; hatırlatma 2''ye indi.', '00000000-0000-0000-0000-0000000060a1');
select tst.check((select count(*) from public.clinic_notes where goal_id = '00000000-0000-0000-0000-0000000060a1') = 1, 'not hedefe bağlandı');

-- 2. başka danışanın hedefine bağlanamaz
do $$ begin
  insert into public.clinic_notes (link_id, clinic_id, author_id, body, goal_id) values
    ('00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), auth.uid(), 'yanlış', '00000000-0000-0000-0000-0000000060b1');
  raise exception 'TEST BAŞARISIZ: başka danışanın hedefine not bağlandı';
exception when check_violation then raise notice 'ok: başka danışanın hedefine bağlanamaz';
end $$;

-- 3. hedefsiz not eskisi gibi
insert into public.clinic_notes (link_id, clinic_id, author_id, body) values
  ('00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), auth.uid(), 'Görüşme notu');
select tst.check((select count(*) from public.clinic_notes where link_id = '00000000-0000-0000-0000-0000000011a1') = 2, 'hedefsiz not da yazılır');

-- 4. değerlendirme notu (goal_ratings.note)
insert into public.goal_ratings (goal_id, clinic_id, week, rating, note, rated_by) values
  ('00000000-0000-0000-0000-0000000060a1', public.my_clinic_id(), date_trunc('week', current_date)::date, 1, 'Çizelge tutarlı.', auth.uid());
select tst.check((select note from public.goal_ratings where goal_id = '00000000-0000-0000-0000-0000000060a1') = 'Çizelge tutarlı.', 'değerlendirme notu yazıldı');

-- 5. ebeveyn notları ve değerlendirmeyi görmez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_notes) = 0, 'ebeveyn uzman notunu görmez');
select tst.check((select count(*) from public.goal_ratings) = 0, 'ebeveyn değerlendirmeyi görmez');

-- 6. hedef silinince not kalır, bağ boşalır
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
delete from public.clinic_goals where id = '00000000-0000-0000-0000-0000000060a1';
select tst.check((select goal_id is null from public.clinic_notes where id = '00000000-0000-0000-0000-00000000e0a1'), 'hedef silinince not kalır, bağ boşalır');
reset role;
