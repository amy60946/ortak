-- 26 Ekim 2026 denetimi düzeltmeleri (proposed/20261026300000_review_fixes.sql)
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
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- d1 uzman (Mavi, sahip), d2 ekip üyesi (Mavi), d3 başka klinik; a1, a2 aileler; f2 destek, f3 izleyici
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, 'ece@example.com', '{"account":"clinician","clinic_name":"Mavi","name":"Ece Kaya"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, 'can@example.com', '{"account":"clinician","clinic_name":"Yeşil","name":"Can Demir"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, 'baba@example.com', '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', '{"nickname":"Destek"}'),
  ('00000000-0000-0000-0000-0000000000f3', false, 'izleyici@example.com', '{"nickname":"İzleyici"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f2', 'support'), ('00000000-0000-0000-0000-0000000000f3', 'viewer');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Deniz', 'kedi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false, jsonb_build_object('account', 'clinician', 'name', 'Mert Ak', 'team_code', tst.v('team')));

-- ---------------------------------------------------------------- A1. deneme sayacı bağlı davetle sıfırlanmaz (W2-1)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'own', public.clinic_create_invite('family', 'özel not: dikkat', '', null, 'Nazlı', 'A') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.claim_clinic_invite(tst.v('own'));
select public.claim_clinic_invite('ZZZZZ' || n) from generate_series(1, 9) n;
select tst.check(public.claim_clinic_invite(tst.v('own')) ->> 'code' = tst.v('own'), 'kendi bağladığı davet yeniden açılır');
select public.claim_clinic_invite('ZZZZZZ');
select tst.check(public.claim_clinic_invite('ZZZZZY') ->> 'error' = 'too_many_attempts', 'bağlı davet sayacı sıfırlamaz: 10 hatadan sonra durur');
reset role;
delete from public.code_attempts;

-- ---------------------------------------------------------------- A3. ret yalnız daveti bağlayan aile
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'open', public.clinic_create_invite('family', '') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.fails($$select public.family_decline_invite(tst.v('open'))$$, 'bağlanmamış başkasının davetini kimse kapatamaz');
reset role;
select tst.check((select declined_at is null from public.clinic_invites where code = tst.v('open')), 'davet açık kalır');

-- ---------------------------------------------------------------- A6/A8. paylaşım, taslak plan yalnız önerilen çocuğa, uzmanın notu
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_goals (invite_code, clinic_id, title, shared) values (tst.v('own'), public.my_clinic_id(), 'Taslak hedef', true);
insert into public.care_modules (invite_code, clinic_id, title, status) values (tst.v('own'), public.my_clinic_id(), 'Taslak modül', 'active');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'acc', public.family_accept_invite(tst.v('own'), '{"name":"Nazlı Su","age_group":"A"}',
                                                            array['00000000-0000-0000-0000-00000000c002'::uuid], false, 'uzman-paylasim-v1')::text;
select tst.check(json_array_length(tst.v('acc')::json -> 'link_ids') = 2, 'önerilen çocuk + kardeş paylaşıldı');
insert into tst.kv select 'Lnew', l.link_id::text from public.family_clinic_links() l join public.children c on c.id = l.child_id where c.name = 'Nazlı Su';
insert into tst.kv select 'Lsib', l.link_id::text from public.family_clinic_links() l where l.child_id = '00000000-0000-0000-0000-00000000c002';
select tst.check(json_array_length(public.family_care_plan(tst.v('Lnew')::uuid) -> 'goals') = 1
                 and json_array_length(public.family_care_plan(tst.v('Lnew')::uuid) -> 'modules') = 1, 'taslak plan önerilen çocukta, kendiliğinden gönderildi');
select tst.check(json_array_length(public.family_care_plan(tst.v('Lsib')::uuid) -> 'goals') = 0, 'taslak plan kardeşe kopyalanmaz');
select tst.check(exists (select 1 from public.clinic_links where id = tst.v('Lnew')::uuid) and
                 (select label from public.clinic_links where id = tst.v('Lnew')::uuid) = '', 'aile uzmanın notunu bağlantıda göremez');
select tst.check(tst.cnt('public.clinic_link_labels') = 0, 'aile not tablosunu okuyamaz');
-- aynı uzmana zaten paylaşılan çocukla davet harcanmaz
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'again', public.clinic_create_invite('family', '') ->> 'code';
select tst.check((select label from public.clinic_clients() where link_id = tst.v('Lnew')::uuid) = 'özel not: dikkat', 'uzman notunu danışan listesinde görür');
update public.clinic_links set label = 'yeni not' where id = tst.v('Lnew')::uuid;
select tst.check((select label from public.clinic_clients() where link_id = tst.v('Lnew')::uuid) = 'yeni not', 'eski uygulamalar etiketi aynı yolla günceller');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.redeem_clinic_invite_children(tst.v('again'), array['00000000-0000-0000-0000-00000000c002'::uuid])$$, 'zaten paylaşılan çocukla davet hata verir');
reset role;
select tst.check((select used_at is null from public.clinic_invites where code = tst.v('again')), 'davet harcanmadı');
select tst.check((select label from public.clinic_links where id = tst.v('Lnew')::uuid) = '', 'not sütunu boş kalır');
select tst.check((select count(*) from public.notifications where kind = 'care_plan_shared') = 0, 'paylaşan ebeveyn kendine plan bildirimi almaz');

-- ---------------------------------------------------------------- C1. plan aileye "gönder" ile görünür
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_goals (link_id, clinic_id, title, shared) values (tst.v('Lsib')::uuid, public.my_clinic_id(), 'Yeni hedef', true);
insert into public.care_modules (link_id, clinic_id, title, status) values (tst.v('Lsib')::uuid, public.my_clinic_id(), 'Planlı modül', 'planned');
update public.clinic_goals set pub = '{"title":"sahte"}' where link_id = tst.v('Lsib')::uuid;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(json_array_length(public.family_care_plan(tst.v('Lsib')::uuid) -> 'goals') = 0, 'gönderilmeden aile görmez (istemci pub yazamaz)');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
reset role;
update public.clinic_goals set shared = false where link_id = tst.v('Lsib')::uuid;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.care_plan_publish(tst.v('Lsib')::uuid)$$, 'boş plan gönderilmez');
update public.clinic_goals set shared = true where link_id = tst.v('Lsib')::uuid;
update public.care_modules set status = 'active' where link_id = tst.v('Lsib')::uuid;
select public.care_plan_publish(tst.v('Lsib')::uuid);
select public.care_plan_publish(tst.v('Lsib')::uuid);
reset role;
select tst.check((select count(*) from public.notifications where kind = 'care_plan_shared' and data ->> 'link_id' = tst.v('Lsib')) = 1, '10 dakikada tek bildirim');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'G', public.family_care_plan(tst.v('Lsib')::uuid)::text;
select tst.check(tst.v('G')::json -> 'goals' -> 0 ->> 'title' = 'Yeni hedef' and json_array_length(tst.v('G')::json -> 'modules') = 1, 'gönderince aile görür');
select tst.check(tst.cnt('public.clinic_goals') = 0 and tst.cnt('public.care_modules') = 0, 'aile tablolara doğrudan bakmaz');
-- gönderildikten sonraki düzenleme yeniden gönderilene kadar görünmez
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.clinic_goals set title = 'Taslak düzeltme' where link_id = tst.v('Lsib')::uuid;
update public.care_modules set status = 'planned' where link_id = tst.v('Lsib')::uuid;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.family_care_plan(tst.v('Lsib')::uuid) -> 'goals' -> 0 ->> 'title' = 'Yeni hedef', 'gönderilmemiş düzenleme ailede görünmez');
insert into tst.kv select 'Msib', (public.family_care_plan(tst.v('Lsib')::uuid) -> 'modules') -> 0 ->> 'id';
insert into public.care_module_logs (module_id) values (tst.v('Msib')::uuid);
select tst.check((select count(*) from public.care_module_logs) = 1, 'gönderilmiş etkin modüle kayıt');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.care_plan_publish(tst.v('Lsib')::uuid);
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(json_array_length(public.family_care_plan(tst.v('Lsib')::uuid) -> 'modules') = 0, 'planlıya alınan modül gönderilince ailede kalkar');
select tst.fails($$insert into public.care_module_logs (module_id, day) values (tst.v('Msib')::uuid, current_date - 1)$$, 'gönderilmemiş modüle kayıt yok');

-- ---------------------------------------------------------------- C2. paylaşım bitince uzman ailenin kaydını görmez
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.care_module_logs') = 1, 'uzman etkin paylaşımda kaydı görür');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link(tst.v('Lsib')::uuid);
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.care_module_logs') = 0, 'paylaşım bitince kayıt görünmez');

-- ---------------------------------------------------------------- D1. çocuğun hâlâ gördüğü uzman "önceki uzman" sayılmaz
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
insert into tst.kv select 'y', public.clinic_create_invite('family', '') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'Ly', (public.redeem_clinic_invite_children(tst.v('y'), (select array[c.id] from public.children c where c.name = 'Nazlı Su'), true, 'uzman-gecis-v1') -> 'link_ids') ->> 0;
select tst.check((select not history_available from public.family_clinic_links() where link_id = tst.v('Ly')::uuid), 'etkin başka uzman aktarılabilir sayılmaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(jsonb_array_length(public.clinic_inherited_records(tst.v('Ly')::uuid)) = 0, 'çocuğun gördüğü uzmanın notları aktarılmaz');

-- ---------------------------------------------------------------- C4. silinen ekip üyesinin yazar kimliği boşalır
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
reset role;
insert into public.care_modules (link_id, clinic_id, title, status, created_by)
  values (tst.v('Lnew')::uuid, (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2'), 'Üyenin modülü', 'planned',
          '00000000-0000-0000-0000-0000000000d2');
delete from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2';
select tst.check((select created_by is null from public.care_modules where title = 'Üyenin modülü'), 'silinen uzmanın kimliği kalmaz');

-- ---------------------------------------------------------------- E. belge incelemesi
update public.feature_flags set enabled = true where key = 'clinician_verification';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d1/rastgele.pdf')$$, 'başvurusuz yükleme yok');
insert into tst.kv select 'w1', public.clinician_verification_start('psikolog') ->> 'id';
insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d1/' || tst.v('w1') || '.pdf');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d1/' || tst.v('w1') || '-2.pdf')$$, 'yalnız başvurunun tek yolu');
-- yeniden başlatınca eski başvurunun belgesi silinme kuyruğuna
insert into tst.kv select 'w2', public.clinician_verification_start('psikolog') ->> 'id';
reset role;
select tst.check(exists (select 1 from public.storage_trash where path = '00000000-0000-0000-0000-0000000000d1/' || tst.v('w1') || '.pdf'), 'geri çekilen başvurunun belgesi kuyrukta');
update public.feature_flags set enabled = false where key = 'clinician_verification';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d1/' || tst.v('w2') || '.pdf')$$, 'bayrak kapalıyken yükleme yok');
select tst.fails($$select public.clinician_verification_submit(tst.v('w2')::uuid)$$, 'bayrak kapalıyken gönderim yok');
reset role;
update public.feature_flags set enabled = true where key = 'clinician_verification';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d1/' || tst.v('w2') || '.pdf');
select public.clinician_verification_submit(tst.v('w2')::uuid);
select tst.fails($$insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d1/' || tst.v('w2') || '.pdf')$$, 'gönderilen başvuruya yeni dosya yok');
reset role;
select tst.as_user(null);
set role service_role;
select tst.check(public.clinician_verification_autocheck(tst.v('w2')::uuid, '{}', null, 'unreadable') = 'unreadable', 'okunamayan belge kendiliğinden ret');
select tst.check((select count(*) from public.storage_trash_take('verify', 50)) = 2, 'kendiliğinden reddedilen belge de kuyrukta');
select public.storage_trash_done(array(select id from public.storage_trash_take('verify', 50)));
select tst.check((select count(*) from public.storage_trash) = 0, 'kuyruk boşalır');
reset role;
select tst.check((select file_path is null from public.clinician_verifications where id = tst.v('w2')::uuid), 'reddedilen başvuruda belge yolu kalmaz');
-- elle incelenen meslek kendiliğinden reddedilmez; başvurudan sonra ad değişirse onay yok
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'w3', public.clinician_verification_start('diger') ->> 'id';
insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d1/' || tst.v('w3') || '.pdf');
select public.clinician_verification_submit(tst.v('w3')::uuid);
reset role;
select tst.as_user(null);
set role service_role;
select tst.check(public.clinician_verification_autocheck(tst.v('w3')::uuid, '{}', null, 'unreadable') = 'pending', 'elle incelenen meslek kendiliğinden reddedilmez');
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.clinicians set name = 'Başka Biri' where id = auth.uid();
select tst.as_user('00000000-0000-0000-0000-0000000000f3');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f3');
select tst.fails($$select * from public.admin_verifications('pending', 50)$$, 'izleyici rolü belge listesini görmez');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select tst.fails($$select public.admin_verification_decide(tst.v('w3')::uuid, null, null, null, null, null, 'x')$$, 'karar boş olamaz');
select tst.fails($$select public.admin_verification_decide(tst.v('w3')::uuid, true, null, null, null, null, 'x')$$, 'başvurudan sonra ad değiştiyse onay yok');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.clinicians set name = 'Ece Kaya' where id = auth.uid();
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select public.admin_verification_decide(tst.v('w3')::uuid, true, null, null, 'YOK-1A2B-3C4D-5E6F', null, 'elle bakıldı');
reset role;
select tst.check((select auto ? 'extracted' from public.clinician_verifications where id = tst.v('w3')::uuid) is not true, 'karar sonrası ön kontrol ayrıntısı silinir');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.clinician_badge('00000000-0000-0000-0000-0000000000d1')$$, 'rozet işlevi istemciye kapalı');
reset role;
select tst.check(public.clinician_badge('00000000-0000-0000-0000-0000000000d1') = 'Uzman', '"Diğer" meslekte rozet "Uzman"');
-- yalnız büyük/küçük harf değişikliği rozeti düşürmez
update public.clinicians set name = 'ECE KAYA' where id = '00000000-0000-0000-0000-0000000000d1';
select tst.check((select verified_at is not null from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1'), 'harf büyüklüğü değişince rozet kalır');
-- kişiye istisna: bayrak uzmana göre
update public.feature_flags set enabled = false where key = 'clinician_verification';
insert into public.user_flags (user_id, key, enabled, reason) values ('00000000-0000-0000-0000-0000000000d1', 'clinician_verification', true, 'deneme');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.clinician_badge('00000000-0000-0000-0000-0000000000d1') = 'Uzman', 'uzmana açılan istisnada aile de rozeti görür');
-- hesap silinince bekleyen belge kuyruğa
select tst.as_user(null);
update public.feature_flags set enabled = true where key = 'clinician_verification';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
insert into tst.kv select 'w4', public.clinician_verification_start('psikolog') ->> 'id';
reset role;
delete from public.clinicians where id = '00000000-0000-0000-0000-0000000000d3';
select tst.check(exists (select 1 from public.storage_trash where path like '00000000-0000-0000-0000-0000000000d3/%'), 'silinen hesabın belgesi kuyrukta');
set role authenticated;
select tst.fails($$select * from public.storage_trash_take('verify', 10)$$, 'kuyruk istemciye kapalı');
reset role;

select 'DENETİM DÜZELTMELERİ TESTLERİ GEÇTİ' as sonuc;
