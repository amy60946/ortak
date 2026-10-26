-- Uzman doğrulama (migrations/20261026050000_clinician_verification.sql) + aile yanıtlarındaki rozet (20261026100000)
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
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- d1 uzman (Ayşe Nur Yılmaz), d2 başka klinik uzmanı, s1 destek (admin), a1 ebeveyn
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, 'ayse@example.com', '{"account":"clinician","clinic_name":"Mavi","name":"Ayşe Nur Yılmaz"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, 'can@example.com', '{"account":"clinician","clinic_name":"Yeşil","name":"Can Demir"}'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', '{"nickname":"Destek"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f2', 'support');

-- 0. bayrak kapalıyken (ilk sürüm): başvuru yok, rozet dönmez
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(not (public.clinician_verification_me() ->> 'enabled')::boolean, 'bayrak ilk sürümde kapalı');
select tst.fails($$select public.clinician_verification_start('psikolog')$$, 'kapalıyken başvuru yok');
reset role;
update public.clinicians set verified_profession = 'psikolog', verified_at = now() where id = '00000000-0000-0000-0000-0000000000d2';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'i0', public.clinic_create_invite('family', '') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.clinic_invite_preview(tst.v('i0')) ->> 'verified_as' is null, 'kapalıyken aileye rozet dönmez');
reset role;
update public.clinicians set verified_profession = null, verified_at = null where id = '00000000-0000-0000-0000-0000000000d2';
-- kişiye istisnayla denenebilir, sonra herkese açılır
insert into public.user_flags (user_id, key, enabled, reason) values ('00000000-0000-0000-0000-0000000000d1', 'clinician_verification', true, 'deneme');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((public.clinician_verification_me() ->> 'enabled')::boolean, 'kişiye istisna açar');
reset role;
delete from public.user_flags where key = 'clinician_verification';
update public.feature_flags set enabled = true where key = 'clinician_verification';

set role authenticated;
-- ---------------------------------------------------------------- 1. başvuru + yükleme
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.clinician_verification_start('astrolog')$$, 'bilinmeyen meslek');
select tst.fails($$select public.clinician_verification_start('bcba')$$, 'BCBA sicil no zorunlu');
insert into tst.kv select 'V1', public.clinician_verification_start('klinik_psikolog')::text;
insert into tst.kv values ('v1', (tst.v('V1')::json) ->> 'id'), ('p1', (tst.v('V1')::json) ->> 'upload_path');
select tst.check(tst.v('p1') = '00000000-0000-0000-0000-0000000000d1/' || tst.v('v1') || '.pdf', 'yükleme yolu kendi klasöründe');
select tst.fails($$select public.clinician_verification_submit(tst.v('v1')::uuid)$$, 'belge yüklenmeden gönderilmez');
-- kova kuralları: kendi klasörüne yükler, başkasınınkine yükleyemez, okuyamaz
insert into storage.objects (bucket_id, name, owner) values ('verify', tst.v('p1'), auth.uid());
select tst.fails($$insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000d2/x.pdf')$$, 'başkasının klasörüne yükleyemez');
select tst.check((select count(*) from storage.objects where bucket_id = 'verify') = 0, 'uzman belgeleri okuyamaz (yalnız yönetici)');
select public.clinician_verification_submit(tst.v('v1')::uuid);
select tst.check((public.clinician_verification_me() -> 'last' ->> 'status') = 'pending'
                 and (public.clinician_verification_me() -> 'last' ->> 'submitted')::boolean, 'durum: incelemede');
select tst.check(public.clinician_verification_me() ->> 'verified_at' is null, 'rozet yok');
select tst.fails($$select * from public.clinician_verifications$$, 'tablo istemciye kapalı');
select tst.fails($$update public.clinicians set verified_at = now(), verified_profession = 'psikolog' where id = auth.uid()$$, 'uzman rozeti kendine yazamaz');
-- ebeveyn yükleyemez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('verify', '00000000-0000-0000-0000-0000000000a1/x.pdf')$$, 'ebeveyn belge kovasına yükleyemez');

-- ---------------------------------------------------------------- 2. ön kontrol (Edge Function, service_role)
select tst.fails($$select public.clinician_verification_autocheck(tst.v('v1')::uuid, '{}', 'YOK-1A2B-3C4D-5E6F', null)$$, 'ön kontrol istemciye kapalı');
reset role;
select tst.as_user(null);
set role service_role;
select tst.check((public.clinician_verification_for_check(tst.v('v1')::uuid, '00000000-0000-0000-0000-0000000000d1') ->> 'name') = 'Ayşe Nur Yılmaz', 'işlev başvuruyu okur');
select tst.check(public.clinician_verification_for_check(tst.v('v1')::uuid, '00000000-0000-0000-0000-0000000000d2') is null, 'başkasının başvurusu okunmaz');
select tst.check(public.clinician_verification_autocheck(tst.v('v1')::uuid,
  '{"checks":{"name":"ok","program":"ok","degree":"ok"},"extracted":{"university":"ÖRNEK ÜNİVERSİTESİ"}}', 'YOK-1A2B-3C4D-5E6F', null) = 'pending',
  'ön kontrol yazılır, karar kişide kalır');
reset role;
-- aynı barkod başka uzmanın BEKLEYEN başvurusunda: ret değil uyarı (20261026300000; onaylıdaysa ret, aşağıda)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'v2', public.clinician_verification_start('psikolog') ->> 'id';
insert into storage.objects (bucket_id, name, owner) values ('verify', '00000000-0000-0000-0000-0000000000d2/' || tst.v('v2') || '.pdf', auth.uid());
select public.clinician_verification_submit(tst.v('v2')::uuid);
reset role;
select tst.as_user(null);   -- Edge Function sunucu anahtarıyla çağırır: oturumdaki kullanıcı yok
set role service_role;
select tst.check(public.clinician_verification_autocheck(tst.v('v2')::uuid, '{}', 'YOK-1A2B-3C4D-5E6F', null) = 'pending', 'bekleyen başvurudaki barkod: ret değil');
select tst.check(public.clinician_verification_autocheck(tst.v('v2')::uuid, '{}', 'YOK-1A2B-3C4D-5E6F', null) = 'skipped', 'her başvuru bir kez kontrol edilir');
reset role;
select tst.check((select auto -> 'checks' ->> 'duplicate' from public.clinician_verifications where id = tst.v('v2')::uuid) = 'warn', 'çakışma uyarı olarak yazılır');

-- ---------------------------------------------------------------- 3. yönetici kararı
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2');
select tst.fails($$select * from public.admin_verifications('pending', 50)$$, 'iki adımlı doğrulama olmadan liste yok');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select tst.check((select count(*) from public.admin_verifications('pending', 50)) = 2, 'bekleyen başvurular listede');
select tst.check((select a.auto -> 'checks' ->> 'name' from public.admin_verifications('pending', 50) a where a.id = tst.v('v1')::uuid) = 'ok', 'ön kontrol panelde');
select tst.check(public.admin_verification_open(tst.v('v1')::uuid) = tst.v('p1'), 'belge yolu döner');
select tst.check((select count(*) from storage.objects where bucket_id = 'verify') = 0, 'yönetici kovayı doğrudan okuyamaz (belge yalnız verify-doc ile, 20261026400000)');
select tst.check(public.admin_can_review(), 'verify-doc için yetki denetimi: support + iki adımlı');
reset role;
select tst.check(exists (select 1 from public.admin_audit where action = 'verification.view'), 'görüntüleme denetim kaydında');
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select tst.fails($$select public.admin_verification_decide(tst.v('v1')::uuid, false, null, '', null, null, 'kontrol')$$, 'ret nedeni zorunlu');
select tst.check(public.admin_verification_decide(tst.v('v1')::uuid, true, null, null, null,
  '{"university":"ÖRNEK ÜNİVERSİTESİ","program":"Klinik Psikoloji","degree":"Yüksek lisans","graduation_year":"2021","tc":"1234"}',
  'barkod e-Devlet''te doğrulandı') = tst.v('p1'), 'onay: silinecek belge yolu döner');
reset role;
select tst.check((select verified_profession = 'klinik_psikolog' and verified_at is not null from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1'), 'rozet yazıldı');
select tst.check((select file_path is null and summary ->> 'tc' is null and summary ->> 'program' = 'Klinik Psikoloji'
                   from public.clinician_verifications where id = tst.v('v1')::uuid), 'belge yolu silindi, özette kimlik yok');
select tst.check(exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'verification_approved'), 'uzmana onay bildirimi');
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select tst.fails($$select public.admin_verification_decide(tst.v('v1')::uuid, true, null, null, null, null, 'tekrar')$$, 'karar verilmiş başvuru yeniden kararlanmaz');
-- aynı barkod artık onaylı: ikinci başvuru onaylanamaz (barkod karar anında verilmese de başvurudaki barkod denetlenir)
select tst.fails($$select public.admin_verification_decide(tst.v('v2')::uuid, true, null, null, null, null, 'deneme')$$, 'onaylı barkod ikinci uzmana onaylanmaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinician_verification_me() ->> 'verified_label' = 'Klinik psikolog', 'uzman rozetini görür');
select tst.fails($$select * from public.admin_verifications('pending', 50)$$, 'uzman paneli çağıramaz');

-- ---------------------------------------------------------------- 4. rozet aileye görünür
insert into tst.kv select 'i1', public.clinic_create_invite('family', '', '', null, 'Efe', 'A')::text;
reset role;
set role service_role;
select tst.check(public.clinic_invite_open((tst.v('i1')::json) ->> 'token') ->> 'verified_as' = 'Klinik psikolog', 'açılış sayfasında rozet');
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.claim_clinic_invite((tst.v('i1')::json) ->> 'code') ->> 'verified_as' = 'Klinik psikolog', 'davet kabulünde rozet');
select tst.check((select verified_as from public.family_pending_invites()) = 'Klinik psikolog', 'bekleyen davette rozet');
select public.family_accept_invite((tst.v('i1')::json) ->> 'code', '{"name":"Efe","age_group":"A"}', null, false, 'uzman-paylasim-v1');
select tst.check((select verified_as from public.family_clinic_links()) = 'Klinik psikolog', 'Uzmanım listesinde rozet');
-- rozetsiz uzman: null
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'i2', public.clinic_create_invite('family', '') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.claim_clinic_invite(tst.v('i2')) ->> 'verified_as' is null, 'rozetsiz uzmanda boş');

-- ---------------------------------------------------------------- 5. ad değişince rozet düşer; askıya alma
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.clinicians set title = 'Uzm. Klinik Psikolog' where id = auth.uid();
select tst.check(public.clinician_verification_me() ->> 'verified_at' is not null, 'unvan değişince rozet kalır');
update public.clinicians set name = 'Mehmet Başka' where id = auth.uid();
select tst.check(public.clinician_verification_me() ->> 'verified_at' is null
                 and (public.clinician_verification_me() -> 'last' ->> 'reason') = 'name_changed', 'ad değişince rozet düşer');
reset role;
update public.clinicians set verified_profession = 'psikolog', verified_at = now() where id = '00000000-0000-0000-0000-0000000000d2';
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select public.admin_verification_suspend('00000000-0000-0000-0000-0000000000d2', 'Şikâyet inceleniyor', 'aile şikâyeti');
reset role;
select tst.check((select verified_at is null from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2'), 'askıya alınan rozet düşer');
select tst.check(exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d2' and kind = 'verification_suspended'), 'askı bildirimi');

-- anon
set role anon;
select tst.fails($$select public.clinician_verification_start('psikolog')$$, 'anon başvuramaz');
select tst.fails($$select public.clinician_verification_me()$$, 'anon durum okuyamaz');
reset role;
select 'UZMAN DOĞRULAMA TESTLERİ GEÇTİ' as sonuc;
