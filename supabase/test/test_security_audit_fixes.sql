-- Güvenlik denetimi düzeltmeleri (proposed/20261121100000_security_audit_fixes.sql): her bulgu için açık artık çalışmıyor,
-- meşru kullanım çalışıyor. Bulgular: paylaşım bitince eski uzman, mail kovasında kardeş çocuk, sonsuz zaman damgası, ücretsiz plan
-- güncelleme açığı, üyelik bitince takvim, anonim KVKK başvurusu, Gmail özeti, sağlamlaştırma, bildirim seli.
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', '{"aal":"aal1"}', false);
end $$;
create or replace function tst.as_mfa(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', '{"aal":"aal2"}', false);
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
    if sqlerrm like 'TEST%' then raise; end if;
    raise notice 'ok (beklenen hata): % → %', msg, sqlerrm;
    return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
-- etkilenen satır sayısı
create or replace function tst.rows(sql text) returns bigint language plpgsql as $$
declare n bigint;
begin execute sql; get diagnostics n = row_count; return n; end $$;
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.u(key text) returns uuid language sql as $$ select v::uuid from tst.kv where k = key $$;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant usage on schema tst to anon, authenticated;
grant all on tst.kv to anon, authenticated;
grant execute on all functions in schema tst to anon, authenticated;

-- =====================================================================
-- 1. Paylaşım bitince eski uzman
-- =====================================================================
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, 'baba@example.com', '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'ece@example.com', '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}');
update public.profiles set family_id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1')
 where id = '00000000-0000-0000-0000-0000000000a2';
insert into tst.kv select 'F', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into tst.kv select 'D', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', tst.u('F'), 'Mira', 'tavşan'),
  ('00000000-0000-0000-0000-00000000c002', tst.u('F'), 'Efe', 'tavşan');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by) values
  ('00000000-0000-0000-0000-0000000011a1', tst.u('D'), '00000000-0000-0000-0000-0000000000d1', tst.u('F'),
   '00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('L', '00000000-0000-0000-0000-0000000011a1');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.care_modules (id, clinic_id, link_id, title, status) values
  ('00000000-0000-0000-0000-0000000005d1', tst.u('D'), tst.u('L'), 'Program', 'active'),
  ('00000000-0000-0000-0000-0000000005d2', tst.u('D'), tst.u('L'), 'Boş program', 'active'),
  ('00000000-0000-0000-0000-0000000005d3', tst.u('D'), tst.u('L'), 'Silinecek', 'planned');
insert into public.clinic_goals (id, clinic_id, link_id, title, shared) values
  ('00000000-0000-0000-0000-0000000005e1', tst.u('D'), tst.u('L'), 'Hedef', true),
  ('00000000-0000-0000-0000-0000000005e2', tst.u('D'), tst.u('L'), 'Silinecek hedef', true);
insert into public.clinic_task_suggestions (id, clinic_id, link_id, child_id, family_id, title, status, created_by) values
  ('00000000-0000-0000-0000-0000000005b1', tst.u('D'), tst.u('L'), '00000000-0000-0000-0000-00000000c001', tst.u('F'), 'Öneri', 'pending', auth.uid()),
  ('00000000-0000-0000-0000-0000000005b2', tst.u('D'), tst.u('L'), '00000000-0000-0000-0000-00000000c001', tst.u('F'), 'Öneri 2', 'pending', auth.uid());
insert into public.clinic_notes (link_id, clinic_id, author_id, body) values (tst.u('L'), tst.u('D'), auth.uid(), 'Kendi notum');
select public.care_plan_publish(tst.u('L'));
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.care_module_logs (module_id, family_id, practiced) values ('00000000-0000-0000-0000-0000000005d1', tst.u('F'), true);
-- etkin paylaşımda: uzman kendi planını yönetir
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.rows($$delete from public.care_modules where id = '00000000-0000-0000-0000-0000000005d3'$$) = 1, '1: etkin paylaşımda uzman kaydı olmayan programı siler');
select tst.check(tst.rows($$delete from public.clinic_goals where id = '00000000-0000-0000-0000-0000000005e2'$$) = 1, '1: etkin paylaşımda uzman hedefini siler');
select tst.fails($$delete from public.care_modules where id = '00000000-0000-0000-0000-0000000005d1'$$, '1: ailenin uygulama kaydı olan program silinmez');
select tst.check(tst.rows($$update public.care_modules set status = 'done' where id = '00000000-0000-0000-0000-0000000005d1'$$) = 1, '1: kayıtlı program Tamamlandı yapılır');
select tst.check((select count(*) from public.clinic_task_suggestions) = 2, '1: etkin paylaşımda öneriler görünür');
-- ebeveyn birini karara bağlar: uzmana bildirim gider
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
update public.clinic_task_suggestions set status = 'declined', decided_at = now() where id = '00000000-0000-0000-0000-0000000005b2';
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'suggestion_decided') = 1,
  '1: etkin paylaşımda öneri kararı uzmana bildirilir');

-- ebeveyn paylaşımı sonlandırır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link(tst.u('L'));
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.care_modules) + (select count(*) from public.clinic_goals)
                 + (select count(*) from public.clinic_task_suggestions) + (select count(*) from public.goal_ratings)
                 + (select count(*) from public.care_module_goals) = 0, '1: bitmiş paylaşımda plan, hedef, öneri okunmaz');
select tst.check(tst.rows($$delete from public.care_modules where id in ('00000000-0000-0000-0000-0000000005d1', '00000000-0000-0000-0000-0000000005d2')$$) = 0,
  '1: bitmiş paylaşımda program silinmez');
select tst.check(tst.rows($$delete from public.clinic_goals where id = '00000000-0000-0000-0000-0000000005e1'$$) = 0, '1: bitmiş paylaşımda hedef silinmez');
select tst.check(tst.rows($$delete from public.clinic_task_suggestions where id = '00000000-0000-0000-0000-0000000005b1'$$) = 0, '1: bitmiş paylaşımda öneri silinmez');
select tst.check((select count(*) from public.clinic_notes) = 1, '1: uzmanın kendi notu klinikte kalır (ürün kararı)');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
update public.clinic_task_suggestions set status = 'declined', decided_at = now() where id = '00000000-0000-0000-0000-0000000005b1';
reset role;
select tst.check((select count(*) from public.care_module_logs where family_id = tst.u('F')) = 1, '1: ailenin uygulama kaydı duruyor');
select tst.check((select count(*) from public.care_modules where link_id = tst.u('L')) = 2, '1: programlar klinikte duruyor (önceki uzman kaydı)');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'suggestion_decided') = 1,
  '1: bitmiş paylaşımda öneri kararı uzmana bildirilmez');
-- zincirleme silme (paylaşım kaydı silinirken) engellenmez
begin;
delete from public.clinic_links where id = tst.u('L');
select tst.check((select count(*) from public.care_modules where link_id = tst.u('L')) = 0, '1: paylaşım silinince programlar zincirleme silinir');
rollback;

-- =====================================================================
-- 2. mail kovası: kardeş çocuk dosyayı göremez
-- =====================================================================
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
insert into tst.kv select 'k2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c002');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k1'));
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code(tst.v('k2'));
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('p', tst.v('F') || '/' || gen_random_uuid()::text || '.m4a'),
                          ('av', tst.v('F') || '/avatars/' || gen_random_uuid()::text || '.jpg'),
                          ('px', tst.v('F') || '/' || gen_random_uuid()::text || '.jpg');
insert into storage.objects (bucket_id, name) values ('mail', tst.v('p')), ('mail', tst.v('av')), ('mail', tst.v('px'));
insert into public.messages (family_id, child_id, sender, sender_id, kind, media_path, duration_ms)
  values (tst.u('F'), '00000000-0000-0000-0000-00000000c001', 'parent', auth.uid(), 'audio', tst.v('p'), 1000);
update public.children set avatar = 'photo:' || tst.v('av') where id = '00000000-0000-0000-0000-00000000c002';
select tst.check((select count(*) from storage.objects where bucket_id = 'mail') = 3, '2: ebeveyn aile önekinin tamamını görür');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check((select count(*) from storage.objects where bucket_id = 'mail') = 3, '2: öteki ebeveyn de görür');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select array_agg(name) from storage.objects where bucket_id = 'mail') = array[tst.v('p')], '2: çocuk cihazı yalnız kendi mesajının dosyasını görür');
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check(not exists (select 1 from storage.objects where bucket_id = 'mail' and name = tst.v('p')), '2: kardeşin ses dosyası görünmez (liste dahil)');
select tst.check((select array_agg(name) from storage.objects where bucket_id = 'mail') = array[tst.v('av')], '2: çocuk kendi fotoğrafını görür, ebeveynin öteki dosyasını görmez');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('mail', tst.v('F') || '/cocuk.jpg')$$, '2: çocuk cihazı kovaya yükleyemez');
select tst.check(tst.rows($$delete from storage.objects where bucket_id = 'mail'$$) = 0, '2: çocuk silemez (silme yalnız ebeveyn)');
reset role;
select tst.check((select count(*) from storage.objects where bucket_id = 'mail') = 3, '2: çocuk hiçbir dosyayı silemedi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into storage.objects (bucket_id, name) values ('mail', tst.v('F') || '/yeni.jpg');
select tst.check(tst.rows($$delete from storage.objects where name = tst.v('F') || '/yeni.jpg'$$) = 1, '2: ebeveyn yükler ve siler');
reset role;

-- =====================================================================
-- 3. İstemcinin yazdığı zaman alanları; KPI medyanı
-- =====================================================================
insert into auth.users (id, is_anonymous, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', now(), '{"nickname":"Owner"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f1', 'viewer');
insert into public.tasks (id, family_id, title, start_date) values ('00000000-0000-0000-0000-0000000088a1', tst.u('F'), 'Yatak', current_date - 3);
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$insert into public.completions (family_id, task_id, child_id, date, status, reviewed_at, reviewed_by)
  values (tst.u('F'), '00000000-0000-0000-0000-0000000088a1', '00000000-0000-0000-0000-00000000c001', current_date, 'approved', 'infinity', auth.uid())$$,
  '3: reviewed_at = infinity yazılamaz');
select tst.fails($$insert into public.completions (family_id, task_id, child_id, date, status, created_at)
  values (tst.u('F'), '00000000-0000-0000-0000-0000000088a1', '00000000-0000-0000-0000-00000000c001', current_date, 'pending', '1900-01-01')$$,
  '3: created_at aralık dışı yazılamaz');
-- meşru: ebeveyn adımı onaylar
insert into public.completions (family_id, task_id, child_id, date, status, child_done_at)
  values (tst.u('F'), '00000000-0000-0000-0000-0000000088a1', '00000000-0000-0000-0000-00000000c001', current_date, 'pending', now() - interval '2 hours');
select tst.check(tst.rows($$update public.completions set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid()
  where task_id = '00000000-0000-0000-0000-0000000088a1'$$) = 1, '3: ebeveyn adımı onaylar');
select tst.fails($$update public.completions set reviewed_at = '-infinity' where task_id = '00000000-0000-0000-0000-0000000088a1'$$, '3: reviewed_at = -infinity yazılamaz');
select tst.fails($$update public.completions set child_done_at = now() + interval '3 days' where task_id = '00000000-0000-0000-0000-0000000088a1'$$, '3: gelecekteki olay zamanı yazılamaz');
select tst.fails($$update public.tasks set end_date = 'infinity' where id = '00000000-0000-0000-0000-0000000088a1'$$, '3: tasks.end_date = infinity yazılamaz');
select tst.check(tst.rows($$update public.tasks set end_date = current_date + 365 where id = '00000000-0000-0000-0000-0000000088a1'$$) = 1, '3: bir yıl sonraki bitiş tarihi yazılır');
update public.tasks set end_date = null where id = '00000000-0000-0000-0000-0000000088a1';
select tst.fails($$update public.clinic_task_suggestions set decided_at = 'infinity' where id = '00000000-0000-0000-0000-0000000005b1'$$, '3: öneri decided_at = infinity yazılamaz');
reset role;
-- eski bozuk satır (sunucu yazmış gibi) KPI'yı bozmaz
insert into public.completions (family_id, task_id, child_id, date, status, reviewed_at)
  values (tst.u('F'), '00000000-0000-0000-0000-0000000088a1', '00000000-0000-0000-0000-00000000c002', current_date, 'approved', 'infinity');
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select tst.check(public.admin_kpi_summary(30) is not null, '3: admin_kpi_summary sonsuz değerle çalışır');
select tst.check(public.admin_kpi_apps(30) is not null, '3: admin_kpi_apps sonsuz değerle çalışır');
reset role;
delete from public.completions where reviewed_at = 'infinity';

-- =====================================================================
-- 4. Ücretsiz plan adım sınırı güncellemede de
-- =====================================================================
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b7', false, '{"nickname":"Veli"}'),
  ('00000000-0000-0000-0000-0000000000b8', false, '{"nickname":"Deneme"}');
update public.families set trial_started_at = now() - interval '60 days'
 where id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b7');
update public.families set trial_started_at = now()
 where id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b8');
update public.app_config set value = value || '{"enforce": true}' where key = 'billing';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000b7');
select tst.check(not (public.family_access() ->> 'full')::boolean, '4: ücretsiz plan');
insert into public.tasks (family_id, title, start_date, recurring, end_date)
  select public.my_family_id(), 'Z' || x, current_date - 3, false, current_date - 1 from generate_series(1, 4) x;
insert into public.tasks (family_id, title, start_date, recurring) select public.my_family_id(), 'A' || x, current_date, true from generate_series(1, 3) x;
select tst.fails($$insert into public.tasks (family_id, title, start_date, recurring) values (public.my_family_id(), 'A4', current_date, true)$$, '4: 4. etkin adım eklenmez');
select tst.fails($$update public.tasks set start_date = current_date + 1, end_date = null where title = 'Z1'$$, '4: biten adım ileri tarihle etkinleşmez');
select tst.fails($$update public.tasks set recurring = true, end_date = null where title = 'Z3'$$, '4: biten adım tekrarlı yapılarak etkinleşmez');
select tst.check(tst.rows($$update public.tasks set title = 'A1 yeni', start_date = current_date where title = 'A1'$$) = 1, '4: etkin adım düzenlenir');
select tst.check(tst.rows($$update public.tasks set end_date = current_date - 1, recurring = false, start_date = current_date - 2 where title = 'A1 yeni'$$) = 1, '4: etkin adım bitirilir');
select tst.check(tst.rows($$update public.tasks set recurring = true, end_date = null where title = 'Z3'$$) = 1, '4: yer açılınca biten adım yeniden etkinleşir');
select tst.check((select count(*) from public.tasks t where t.family_id = public.my_family_id()
   and (t.end_date is null or t.end_date >= current_date) and (t.recurring or t.start_date >= current_date)) = 3, '4: etkin adım 3');
select tst.as_user('00000000-0000-0000-0000-0000000000b8');
insert into public.tasks (family_id, title, start_date, recurring) select public.my_family_id(), 'P' || x, current_date, true from generate_series(1, 5) x;
insert into public.tasks (family_id, title, start_date, recurring, end_date) values (public.my_family_id(), 'PZ', current_date - 3, false, current_date - 1);
select tst.check(tst.rows($$update public.tasks set recurring = true, end_date = null where title = 'PZ'$$) = 1, '4: tam erişimli aile 3ten fazla etkin adım yapar');
reset role;
update public.app_config set value = value || '{"enforce": false}' where key = 'billing';

-- =====================================================================
-- 5. Klinik üyeliği bitince takvim
-- =====================================================================
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', false, '{"account":"clinician","clinic_name":"Kirmizi","name":"Dr. Owner"}');
insert into tst.kv select 'K', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000e1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e2', false, jsonb_build_object('account', 'clinician', 'name', 'Üye', 'team_code', tst.v('team')));
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
insert into tst.kv select 'team2', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e3', false, jsonb_build_object('account', 'clinician', 'name', 'Kalan', 'team_code', tst.v('team2')));
select tst.check((select count(*) from public.clinic_members where clinic_id = tst.u('K') and status = 'active') = 3, '5: iki üye klinikte');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by) values
  ('00000000-0000-0000-0000-0000000022b1', tst.u('K'), '00000000-0000-0000-0000-0000000000e2', tst.u('F'),
   '00000000-0000-0000-0000-00000000c002', '00000000-0000-0000-0000-0000000000a1');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e2');
insert into tst.kv select 'feed', public.clinic_calendar_feed('set', true) ->> 'token';
insert into tst.kv select 'src', public.clinic_calendar_source_save('https://outlook.office365.com/owa/calendar/abc/reachcalendar.ics', 'o')::text;
select public.clinic_session_create(jsonb_build_object('link_id', '00000000-0000-0000-0000-0000000022b1', 'starts_at', date_trunc('hour', now()) - interval '3 days'));
select tst.as_user('00000000-0000-0000-0000-0000000000e3');
insert into tst.kv select 'feed3', public.clinic_calendar_feed('set', false) ->> 'token';
insert into tst.kv select 'src3', public.clinic_calendar_source_save('https://outlook.office365.com/owa/calendar/def/reachcalendar.ics', 'o')::text;
select public.clinic_session_create(jsonb_build_object('starts_at', date_trunc('hour', now()) + interval '2 days', 'title', 'Blok'));
reset role;
select public.calendar_import_store(tst.u('src'),
  jsonb_build_array(jsonb_build_object('uid', 'x1', 'start', (date_trunc('hour', now()) + interval '4 days')::text,
                                       'end', (date_trunc('hour', now()) + interval '4 days 1 hour')::text, 'summary', 'Dış')),
  now(), now() + interval '30 days');
select public.calendar_import_store(tst.u('src3'),
  jsonb_build_array(jsonb_build_object('uid', 'y1', 'start', (date_trunc('hour', now()) + interval '5 days')::text,
                                       'end', (date_trunc('hour', now()) + interval '5 days 1 hour')::text, 'summary', 'Dış 3')),
  now(), now() + interval '30 days');
select tst.check(json_array_length(public.calendar_feed_events(tst.v('feed'))) = 1, '5: üyeyken besleme seansı verir');
-- üye ayrılır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e2');
insert into tst.kv select 'ev', id::text from public.clinic_external_events where uid = 'x1';
select public.clinic_leave();
select tst.fails($$select public.clinic_external_event_mark(tst.u('ev'), null, 'individual', 'in_person', false)$$, '5: eski klinikte dış etkinlik seansa çevrilmez');
reset role;
select tst.check(not exists (select 1 from public.clinic_calendar_feeds where clinician_id = '00000000-0000-0000-0000-0000000000e2'), '5: besleme belirteci silindi');
select tst.check(not exists (select 1 from public.clinic_calendar_sources where clinician_id = '00000000-0000-0000-0000-0000000000e2')
             and not exists (select 1 from public.clinic_external_events where clinician_id = '00000000-0000-0000-0000-0000000000e2'), '5: dış kaynak ve etkinlikler silindi');
select tst.check(json_array_length(public.calendar_feed_events(tst.v('feed'))) = 0, '5: eski belirteç seans vermez');
select tst.check(not exists (select 1 from public.clinic_sessions where clinic_id = tst.u('K') and external_uid = 'x1'), '5: eski klinikte seans açılmadı');
-- belirteç elde kalmış olsa bile (eski hâl) besleme üyeliğe bakar
insert into public.clinic_calendar_feeds (clinician_id, clinic_id, token) values ('00000000-0000-0000-0000-0000000000e2', tst.u('K'), tst.v('feed'));
select tst.check(json_array_length(public.calendar_feed_events(tst.v('feed'))) = 0, '5: üyeliği biten uzmanın beslemesi eski kliniği vermez');
delete from public.clinic_calendar_feeds where clinician_id = '00000000-0000-0000-0000-0000000000e2';
-- kalan üye: besleme ve dönüştürme çalışır
select tst.check(json_array_length(public.calendar_feed_events(tst.v('feed3'))) = 1, '5: üye olan uzmanın beslemesi çalışır');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e3');
select tst.check(public.clinic_external_event_mark((select id from public.clinic_external_events where uid = 'y1'), null, 'individual', 'in_person', false) is not null,
  '5: üye olan uzman dış etkinliği seansa çevirir');
reset role;

-- =====================================================================
-- 6. KVKK başvurusu
-- =====================================================================
insert into auth.users (id, is_anonymous, raw_user_meta_data) values ('00000000-0000-0000-0000-0000000000c9', true, '{}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.fails($$select public.kvkk_request_create('child', 'info', 'bilgi istiyorum')$$, '6: bağlı olmayan anonim oturum başvuramaz');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.fails($$select public.kvkk_request_create('child', 'info', 'bilgi istiyorum')$$, '6: çocuk cihazı başvuramaz (veli başvurur, hukuk/44)');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.kvkk_request_create('parent', 'access', 'verilerimi istiyorum') ->> 'status' = 'received', '6: e-postalı ebeveyn başvurur');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.kvkk_request_create('clinic', 'info', '') ->> 'status' = 'received', '6: uzman başvurur');
reset role;
insert into public.kvkk_requests (user_id, app, kind, detail) select null, 'parent', 'info', 'sel' from generate_series(1, 120);
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.fails($$select public.kvkk_request_create('parent', 'access', 'verilerimi istiyorum')$$, '6: saatlik genel üst sınır seli keser');
reset role;
update public.kvkk_requests set received_at = now() - interval '2 hours' where detail = 'sel';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(public.kvkk_request_create('parent', 'access', 'verilerimi istiyorum') ->> 'status' = 'received', '6: sel geçince başvuru alınır');
reset role;
delete from public.kvkk_requests where detail = 'sel';

-- =====================================================================
-- 7. Gmail nokta ve googlemail.com
-- =====================================================================
select tst.check(public.email_hash('AB+x@gmail.com') = public.email_hash('ab@gmail.com'), '7: +etiket ve büyük harf aynı');
select tst.check(public.email_hash('a.b@gmail.com') = public.email_hash('ab@gmail.com'), '7: Gmail noktası aynı adres');
select tst.check(public.email_hash('A.b+z@GoogleMail.com') = public.email_hash('ab@gmail.com'), '7: googlemail.com aynı adres');
select tst.check(public.email_hash('a.b@example.com') <> public.email_hash('ab@example.com'), '7: başka alanda nokta korunur');
select tst.check(public.email_hash('ab@gmail.com') = public.email_hash_legacy('ab@gmail.com'), '7: düz Gmail adresinin özeti değişmedi');
insert into public.trial_history (email_hash, started_at) values (public.email_hash_legacy('ab@gmail.com'), now() - interval '20 days');
insert into public.trial_history (email_hash, started_at) values (public.email_hash_legacy('eski.ad@example.com'), now() - interval '30 days');
insert into auth.users (id, is_anonymous, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000071', false, 'a.b@googlemail.com', now(), '{"nickname":"Tekrar"}'),
  ('00000000-0000-0000-0000-000000000072', false, 'Eski.Ad+x@example.com', now(), '{"nickname":"Eski"}'),
  ('00000000-0000-0000-0000-000000000073', false, 'yeni@gmail.com', now(), '{"nickname":"Yeni"}');
select tst.check((select f.trial_started_at < now() - interval '19 days' from public.families f join public.profiles p on p.family_id = f.id
                  where p.id = '00000000-0000-0000-0000-000000000071'), '7: nokta / googlemail biçimi yeni deneme almaz');
select tst.check((select f.trial_started_at < now() - interval '29 days' from public.families f join public.profiles p on p.family_id = f.id
                  where p.id = '00000000-0000-0000-0000-000000000072'), '7: eski özetli kayıt yine eşleşir');
select tst.check((select f.trial_started_at > now() - interval '1 hour' from public.families f join public.profiles p on p.family_id = f.id
                  where p.id = '00000000-0000-0000-0000-000000000073'), '7: yeni adres yeni deneme alır');

-- =====================================================================
-- 8. Sağlamlaştırma
-- =====================================================================
select tst.check(position('delete from public.code_attempts' in pg_get_functiondef('public.redeem_guest_pass(text)'::regprocedure)) = 0,
  '8a: redeem_guest_pass deneme sayaçlarını silmez');
select tst.check(not exists (select 1 from information_schema.role_table_grants where grantee = 'anon' and table_schema = 'public'),
  '8b: anon rolünün public tablolarda yetkisi yok');
select tst.check((select proconfig from pg_proc where oid = 'public.clinic_notes_goal_check()'::regprocedure) = array['search_path=""'],
  '8c: clinic_notes_goal_check arama yolu boş');
-- 8c sonrası hedef notu yine çalışır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e2');
reset role;

-- =====================================================================
-- 9. Bildirim seli
-- =====================================================================
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000081', false, '{"nickname":"Hale"}'),
  ('00000000-0000-0000-0000-000000000082', false, '{"nickname":"Hakan"}'),
  ('00000000-0000-0000-0000-000000000089', false, '{"account":"clinician","clinic_name":"Sarı","name":"Dr. Su"}');
update public.profiles set family_id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-000000000081')
 where id = '00000000-0000-0000-0000-000000000082';
insert into tst.kv select 'H', family_id::text from public.profiles where id = '00000000-0000-0000-0000-000000000081';
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', tst.u('H'), 'Ada', 'x');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000033a1', m.clinic_id, m.id, tst.u('H'), '00000000-0000-0000-0000-00000000c0de', '00000000-0000-0000-0000-000000000081'
  from public.clinicians m where m.id = '00000000-0000-0000-0000-000000000089';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-000000000081');
do $$ begin for i in 1..25 loop
  perform public.family_incident_report('00000000-0000-0000-0000-0000000033a1', null, null, 1, null, '', '', '', null, 'x' || i);
end loop; end $$;
reset role;
select tst.check((select count(*) from public.behavior_incidents where link_id = '00000000-0000-0000-0000-0000000033a1') = 25, '9: 25 olay kaydı duruyor');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-000000000089' and kind = 'behavior_incident') = 25,
  '9: 25 bildirim uygulama içinde');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-000000000089' and kind = 'behavior_incident' and push) = 6,
  '9: saatte en çok 6 anlık bildirim');
-- farklı gönderen etkilenmez
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-000000000082');
select public.family_incident_report('00000000-0000-0000-0000-0000000033a1', null, null, 1, null, '', '', '', null, 'öteki');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-000000000089' and kind = 'behavior_incident' and push) = 7,
  '9: öteki ebeveynin bildirimi anlık gider');
-- 1 saat sonra yeniden gider
update public.notification_push_log set at = at - interval '61 minutes' where sender_id = '00000000-0000-0000-0000-000000000081';
update public.notifications set created_at = created_at - interval '61 minutes' where user_id = '00000000-0000-0000-0000-000000000089';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-000000000081');
select public.family_incident_report('00000000-0000-0000-0000-0000000033a1', null, null, 1, null, '', '', '', null, 'sonra');
reset role;
select tst.check((select push from public.notifications where user_id = '00000000-0000-0000-0000-000000000089' and kind = 'behavior_incident'
                  order by id desc limit 1), '9: bir saat sonra yeniden anlık gider');
-- aynı kayıt için 10 dakikada yinelenen bildirim push'suz
select tst.as_user('00000000-0000-0000-0000-000000000081');
select public.notify('00000000-0000-0000-0000-000000000089', 'clinic', 'abc_event', 'Yeni kayıt', '', '{"abc_id":"1"}');
select public.notify('00000000-0000-0000-0000-000000000089', 'clinic', 'abc_event', 'Yeni kayıt', '', '{"abc_id":"1"}');
select public.notify('00000000-0000-0000-0000-000000000089', 'clinic', 'abc_event', 'Yeni kayıt', '', '{"abc_id":"2"}');
select tst.check((select array_agg(push order by id) from public.notifications where user_id = '00000000-0000-0000-0000-000000000089' and kind = 'abc_event')
                 = array[true, false, true], '9: aynı kayıt için yinelenen bildirim push''suz, başka kayıt gider');
-- hesap / güvenlik türü ve sunucu kaynaklı bildirim sınırsız
do $$ begin for i in 1..8 loop
  perform public.notify('00000000-0000-0000-0000-000000000089', 'clinic', 'team_request', 'İstek ' || i, '', jsonb_build_object('i', i));
end loop; end $$;
select tst.as_user(null);
do $$ begin for i in 1..8 loop
  perform public.notify('00000000-0000-0000-0000-000000000089', 'clinic', 'abc_event', 'Sunucu ' || i, '', jsonb_build_object('s', i));
end loop; end $$;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-000000000089' and kind = 'team_request' and push) = 8,
  '9: hesap / ekip türü sınırın dışında');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-000000000089' and kind = 'abc_event' and push and title like 'Sunucu%') = 8,
  '9: sunucu kaynaklı bildirim sınırın dışında');
-- günlük tablo istemciye kapalı
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-000000000089');
select tst.fails($$select count(*) from public.notification_push_log$$, '9: gönderim günlüğü istemciye kapalı');
reset role;
