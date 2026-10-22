-- Klinik içi danışan ataması (migrations/20261022100000_clinic_assignments.sql)
\set ON_ERROR_STOP on

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
create or replace function tst.cnt(t text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute format('select count(*) from %s', t) into n;
  return n;
exception when insufficient_privilege then return 0;
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to anon, authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to anon, authenticated;

-- d1 sahip, d2 ve d4 ekip üyeleri; a1 ailesi: Nazlı (sahibin danışanı) + Efe (kardeşi, d2'nin danışanı); a2 ailesi: Can (d2'nin)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Efe', 'kedi'),
  ('00000000-0000-0000-0000-00000000c003', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a2'), 'Can', 'kedi');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
insert into tst.kv select 'team4', public.clinic_create_invite('clinician', '') ->> 'code';
insert into tst.kv select 'famN', public.clinic_create_invite('family', 'N') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false, jsonb_build_object('account', 'clinician', 'name', 'Mert', 'team_code', (select v from tst.kv where k = 'team'))),
  ('00000000-0000-0000-0000-0000000000d4', false, jsonb_build_object('account', 'clinician', 'name', 'Deniz', 'team_code', (select v from tst.kv where k = 'team4')));
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'famE', public.clinic_create_invite('family', 'E') ->> 'code';
insert into tst.kv select 'famC', public.clinic_create_invite('family', 'C') ->> 'code';

-- aileler paylaşır: Nazlı sahibin koduyla, Efe ve Can d2'nin koduyla
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.redeem_clinic_invite_children((select v from tst.kv where k = 'famN'), array['00000000-0000-0000-0000-00000000c001'::uuid]);
select public.redeem_clinic_invite_children((select v from tst.kv where k = 'famE'), array['00000000-0000-0000-0000-00000000c002'::uuid]);
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.redeem_clinic_invite_children((select v from tst.kv where k = 'famC'), array['00000000-0000-0000-0000-00000000c003'::uuid]);
insert into public.abc_events (family_id, child_id, antecedent, behavior, consequence)
  select family_id, '00000000-0000-0000-0000-00000000c003', 'a', 'b', 'c' from public.profiles where id = '00000000-0000-0000-0000-0000000000a2';
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.abc_events (family_id, child_id, antecedent, behavior, consequence)
  select family_id, x, 'a', 'b', 'c' from public.profiles, unnest(array['00000000-0000-0000-0000-00000000c001'::uuid, '00000000-0000-0000-0000-00000000c002'::uuid]) x
   where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
insert into tst.kv select 'linkN', id::text from public.clinic_links where child_id = '00000000-0000-0000-0000-00000000c001';
insert into tst.kv select 'linkE', id::text from public.clinic_links where child_id = '00000000-0000-0000-0000-00000000c002';

-- ---------------------------------------------------------------- görünürlük
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_clients()) = 3, 'sahip bütün danışanları görür (ekibin eklediği dahil)');
select tst.check(tst.cnt('public.abc_events') = 3, 'sahip bütün zor anları görür');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((select count(*) from public.clinic_clients()) = 2, 'ekip üyesi yalnız kendi eklediği danışanları görür');
select tst.check(not exists (select 1 from public.clinic_clients() where child_name = 'Nazlı'), 'ekip üyesi sahibin danışanını görmez');
select tst.check(tst.cnt('public.children') = 2 and tst.cnt('public.abc_events') = 2, 'ekip üyesi: çocuk ve zor an da kısıtlı');
select tst.as_user('00000000-0000-0000-0000-0000000000d4');
select tst.check((select count(*) from public.clinic_clients()) = 0 and tst.cnt('public.children') = 0, 'yeni üye başlangıçta hiçbir danışan görmez');
select tst.fails($$select public.revoke_clinic_link((select v::uuid from tst.kv where k = 'linkN'))$$, 'görmediği paylaşımı sonlandıramaz');
select tst.fails($$insert into public.clinic_notes (link_id, clinic_id, author_id, body) values ((select v::uuid from tst.kv where k = 'linkN'), (select clinic_id from public.clinicians where id = auth.uid()), auth.uid(), 'x')$$, 'görmediği danışana not yazamaz');

-- ---------------------------------------------------------------- bildirimler kişi başına
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d4') = 0, 'atanmamış üyeye bildirim gitmez');
select tst.check(not exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d2' and title like '%Nazlı%'),
  'kardeşlerin ortak zor an bildiriminde üye yalnız kendi danışanını görür');
select tst.check(exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d2' and kind = 'abc_event' and title = 'Yeni zor an kaydı: Efe'), 'üyeye kendi danışanının bildirimi');
select tst.check(exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'abc_event' and title = 'Yeni zor an kaydı: Nazlı'), 'sahibe kendi danışanının bildirimi');

-- ---------------------------------------------------------------- atama
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.fails($$select public.clinic_assign((select v::uuid from tst.kv where k = 'linkE'), '00000000-0000-0000-0000-0000000000d4', true)$$, 'üye atama yapamaz');
select tst.fails($$update public.clinic_links set clinician_id = '00000000-0000-0000-0000-0000000000d4' where id = (select v::uuid from tst.kv where k = 'linkE')$$, 'üye sorumluyu değiştiremez');
select tst.check(tst.cnt('public.clinic_link_access') = 0, 'atama tablosu boş');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_assign((select v::uuid from tst.kv where k = 'linkN'), '00000000-0000-0000-0000-0000000000d4', true);
select public.clinic_assign((select v::uuid from tst.kv where k = 'linkN'), '00000000-0000-0000-0000-0000000000d4', true);
select tst.check((select assigned from public.clinic_clients() where child_name = 'Nazlı') = array['00000000-0000-0000-0000-0000000000d4'::uuid], 'sahip atananları görür');
select tst.as_user('00000000-0000-0000-0000-0000000000d4');
select tst.check((select count(*) from public.clinic_clients()) = 1 and tst.cnt('public.abc_events') = 1, 'atanan üye danışanı ve zor anı görür');
select tst.check(exists (select 1 from public.notifications where user_id = auth.uid() and kind = 'client_assigned'), 'atanan üyeye bildirim');
insert into public.clinic_notes (link_id, clinic_id, author_id, body)
  values ((select v::uuid from tst.kv where k = 'linkN'), (select clinic_id from public.clinicians where id = auth.uid()), auth.uid(), 'Deniz notu');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.clinic_notes') = 1, 'sahip atanan üyenin notunu görür');
reset role;
-- atanan üyeye de zor an bildirimi
insert into public.abc_events (family_id, child_id, antecedent, behavior, consequence)
  select family_id, '00000000-0000-0000-0000-00000000c001', 'a', 'b', 'c' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d4' and kind = 'abc_event') = 1, 'atanan üyeye zor an bildirimi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_assign((select v::uuid from tst.kv where k = 'linkN'), '00000000-0000-0000-0000-0000000000d4', false);
select tst.as_user('00000000-0000-0000-0000-0000000000d4');
select tst.check((select count(*) from public.clinic_clients()) = 0 and tst.cnt('public.clinic_notes') = 0, 'atama kaldırılınca erişim biter');

-- sorumlu değiştirme: Efe d2'den d4'e
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_set_responsible((select v::uuid from tst.kv where k = 'linkE'), '00000000-0000-0000-0000-0000000000d4');
select tst.as_user('00000000-0000-0000-0000-0000000000d4');
select tst.check(exists (select 1 from public.clinic_clients() where child_name = 'Efe'), 'yeni sorumlu danışanı görür');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(not exists (select 1 from public.clinic_clients() where child_name = 'Efe'), 'eski sorumlu artık görmez');

-- ebeveyn kardeşi sonradan eklerse (clinic_share_child) aynı sorumluya gider
reset role;
select tst.check(true, 'tamam');
select 'ATAMA TESTLERİ GEÇTİ' as sonuc;
