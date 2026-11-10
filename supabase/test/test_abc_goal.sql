-- Davranış kaydı ↔ uzmanın hedefi (migrations/20261103120000_abc_goal.sql): yalnız aynı çocuğun, aileye gönderilmiş hedefi;
-- başka çocuğun / gönderilmemiş hedef reddedilir; hedef silinince bağ boşalır; uzman bağı okur.
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

-- ebeveyn a1 (çocuklar Mira, Can), uzman d1; yalnız Mira paylaşılıyor
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}');
insert into public.children (id, family_id, name, avatar)
  select x.id::uuid, family_id, x.n, 'tavşan' from public.profiles,
    (values ('00000000-0000-0000-0000-00000000c0de', 'Mira'), ('00000000-0000-0000-0000-00000000c0df', 'Can')) as x(id, n)
  where profiles.id = '00000000-0000-0000-0000-0000000000a1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_goals (id, link_id, clinic_id, title, shared) values
  ('00000000-0000-0000-0000-0000000060a1', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Öfke anında sakinleşme', true),
  ('00000000-0000-0000-0000-0000000060a2', '00000000-0000-0000-0000-0000000011a1', public.my_clinic_id(), 'Taslak hedef', true);
-- yalnız ilk hedef aileye gönderilir
select public.care_plan_publish_selected('00000000-0000-0000-0000-0000000011a1', array['00000000-0000-0000-0000-0000000060a2'::uuid]);

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.abc_events (id, family_id, child_id, behavior, goal_id)
  values ('00000000-0000-0000-0000-00000000abc1', public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'Bağırdı', '00000000-0000-0000-0000-0000000060a1');
select tst.check((select goal_id from public.abc_events where id = '00000000-0000-0000-0000-00000000abc1') = '00000000-0000-0000-0000-0000000060a1', 'gönderilmiş hedefe bağlı kayıt');
insert into public.abc_events (family_id, child_id, behavior) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'Hedefsiz kayıt');
select tst.check((select count(*) from public.abc_events where goal_id is null) = 1, 'hedef isteğe bağlı');
select tst.fails($$insert into public.abc_events (family_id, child_id, behavior, goal_id)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0df', 'Başka çocuk', '00000000-0000-0000-0000-0000000060a1')$$, 'başka çocuğun hedefi bağlanamaz');
select tst.fails($$insert into public.abc_events (family_id, child_id, behavior, goal_id)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'Taslak', '00000000-0000-0000-0000-0000000060a2')$$, 'aileye gönderilmemiş hedef bağlanamaz');
select tst.fails($$update public.abc_events set child_id = '00000000-0000-0000-0000-00000000c0df' where id = '00000000-0000-0000-0000-00000000abc1'$$, 'hedefli kayıt başka çocuğa taşınamaz');
update public.abc_events set goal_id = null where id = '00000000-0000-0000-0000-00000000abc1';
update public.abc_events set goal_id = '00000000-0000-0000-0000-0000000060a1' where id = '00000000-0000-0000-0000-00000000abc1';
select tst.check((select goal_id is not null from public.abc_events where id = '00000000-0000-0000-0000-00000000abc1'), 'ebeveyn bağı değiştirebilir');

select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.abc_events where goal_id = '00000000-0000-0000-0000-0000000060a1') = 1, 'uzman hedefe bağlı kaydı görür');
delete from public.clinic_goals where id = '00000000-0000-0000-0000-0000000060a1';
reset role;
select tst.check((select goal_id from public.abc_events where id = '00000000-0000-0000-0000-00000000abc1') is null, 'hedef silinince bağ boşalır');
select tst.check(not has_function_privilege('authenticated', 'public.abc_events_goal_guard()', 'execute'), 'koruma işlevi çağrılamaz');
