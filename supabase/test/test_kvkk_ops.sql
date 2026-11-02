-- KVKK işletme: imha işi, "Verimi indir", sistem sağlığı, CSV kaydı (proposed/20261102200000_kvkk_ops.sql)
\set ON_ERROR_STOP on
create schema if not exists tst;
create or replace function tst.as_user(u uuid, aal text default 'aal1') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', json_build_object('aal', aal)::text, false);
end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
create or replace function tst.fails(sql text, msg text) returns void language plpgsql as $$
begin
  begin execute sql; exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return; end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
create table if not exists tst.kv (k text primary key, v jsonb);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated, anon;

-- f1 owner, f2 destek, f3 izleyici, a1 anne, a2 baba (aynı aile), c9 Efe'nin cihazı, c8 bağlanmamış eski cihaz,
-- c7 bağlanmamış yeni cihaz, d1 uzman (tek kişilik klinik)
insert into auth.users (id, is_anonymous, email, raw_user_meta_data, created_at, last_sign_in_at) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', '{"nickname":"Destek"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000f3', false, 'izleyici@example.com', '{"nickname":"İzleyici"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000a2', false, 'baba@example.com', '{"nickname":"Baba"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000c9', true, null, '{}', now() - interval '400 days', now() - interval '90 days'),
  ('00000000-0000-0000-0000-0000000000c8', true, null, '{}', now() - interval '60 days', now() - interval '45 days'),
  ('00000000-0000-0000-0000-0000000000c7', true, null, '{}', now() - interval '60 days', now() - interval '2 days'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'uzman@example.com', '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}', now(), now());
insert into public.admin_users (user_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'owner'), ('00000000-0000-0000-0000-0000000000f2', 'support'),
  ('00000000-0000-0000-0000-0000000000f3', 'viewer');
-- baba annenin ailesine katılır
update public.profiles set family_id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1')
 where id = '00000000-0000-0000-0000-0000000000a2';
insert into tst.kv values ('fam', to_jsonb((select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1')));
create or replace function tst.fam() returns uuid language sql as $$ select (v #>> '{}')::uuid from tst.kv where k = 'fam' $$;
grant execute on function tst.fam() to authenticated;

insert into public.children (id, family_id, name, avatar, user_id)
values ('00000000-0000-0000-0000-00000000c001', tst.fam(), 'Efe', 'bear', '00000000-0000-0000-0000-0000000000c9');
insert into public.messages (family_id, child_id, sender, sender_id, kind, body, media_path) values
  (tst.fam(), '00000000-0000-0000-0000-00000000c001', 'parent', '00000000-0000-0000-0000-0000000000a1', 'text', 'Annenin mesajı', null),
  (tst.fam(), '00000000-0000-0000-0000-00000000c001', 'parent', '00000000-0000-0000-0000-0000000000a2', 'text', 'Babanın mesajı', null),
  (tst.fam(), '00000000-0000-0000-0000-00000000c001', 'child', '00000000-0000-0000-0000-0000000000c9', 'sticker', 'heart', null);
insert into public.messages (family_id, child_id, sender, sender_id, kind, media_path, duration_ms)
select tst.fam(), '00000000-0000-0000-0000-00000000c001', 'parent', '00000000-0000-0000-0000-0000000000a1', 'audio', tst.fam() || '/ses1.m4a', 3000;
insert into public.abc_events (family_id, child_id, behavior, created_by) values
  (tst.fam(), '00000000-0000-0000-0000-00000000c001', 'Annenin kaydı', '00000000-0000-0000-0000-0000000000a1'),
  (tst.fam(), '00000000-0000-0000-0000-00000000c001', 'Babanın kaydı', '00000000-0000-0000-0000-0000000000a2');

-- imha verisi: eski + yeni satırlar
insert into public.trial_history values ('eski', now() - interval '800 days'), ('yeni', now() - interval '10 days');
insert into public.code_attempts (user_id, at) values
  ('00000000-0000-0000-0000-0000000000c7', now() - interval '30 hours'), ('00000000-0000-0000-0000-0000000000c7', now());
insert into public.notifications (user_id, app, kind, title, created_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'parent', 'test', 'Eski bildirim', now() - interval '400 days'),
  ('00000000-0000-0000-0000-0000000000a1', 'parent', 'test', 'Yeni bildirim', now());
insert into public.activity_days (user_id, app, day) values
  ('00000000-0000-0000-0000-0000000000a1', 'parent', current_date - 800),
  ('00000000-0000-0000-0000-0000000000a2', 'parent', current_date - 800),
  ('00000000-0000-0000-0000-0000000000a1', 'parent', current_date);
insert into public.app_events (user_id, app, event, occurred_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'parent', 'task.create', now() - interval '800 days'),
  ('00000000-0000-0000-0000-0000000000a1', 'parent', 'task.create', now() - interval '800 days'),
  ('00000000-0000-0000-0000-0000000000a2', 'parent', 'task.create', now() - interval '800 days'),
  ('00000000-0000-0000-0000-0000000000a1', 'parent', 'task.create', now());
insert into public.admin_audit (at, admin_id, action, target_type, target_id, reason) values
  (now() - interval '2000 days', '00000000-0000-0000-0000-0000000000f1', 'user.signout', 'user', '00000000-0000-0000-0000-0000000000a1', 'eski kayıt'),
  (now() - interval '10 days', '00000000-0000-0000-0000-0000000000f1', 'user.signout', 'user', '00000000-0000-0000-0000-0000000000a1', 'yeni kayıt');
insert into public.kvkk_requests (user_id, email, app, kind, status, received_at, due_at, answered_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'anne@example.com', 'parent', 'access', 'answered', now() - interval '1200 days', now() - interval '1170 days', now() - interval '1180 days'),
  ('00000000-0000-0000-0000-0000000000a1', 'anne@example.com', 'parent', 'info', 'received', now() - interval '5 days', now() + interval '25 days', null);
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, parent_name, parent_email, expires_at, used_at)
select 'ESKI01', clinic_id, id, 'family', 'Ayşe', 'ayse@example.com', now() - interval '60 days', now() - interval '59 days'
  from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, parent_name, parent_email, expires_at)
select 'YENI01', clinic_id, id, 'family', 'Zeynep', 'zeynep@example.com', now() + interval '2 days'
  from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';

-- --- yetkiler ---------------------------------------------------------------------------------------------------
set role anon;
select tst.fails($$select public.my_data_export()$$, 'anon dışa aktaramaz');
select tst.fails($$select public.admin_health()$$, 'anon sağlık durumunu göremez');
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.retention_run('cron')$$, 'kullanıcı imha işini çalıştıramaz');
select tst.fails($$select public.ops_health()$$, 'kullanıcı iç sağlık işlevini çağıramaz');
select tst.fails($$select public.data_export_of('00000000-0000-0000-0000-0000000000a2')$$, 'iç dışa aktarma işlevi kapalı (başkasının verisi)');
select tst.fails($$select count(*) from public.retention_runs$$, 'imha kaydı tablosu doğrudan okunamaz');
select tst.fails($$select count(*) from public.usage_daily_totals$$, 'toplam tablosu doğrudan okunamaz');
select tst.fails($$select public.admin_health()$$, 'admin olmayan sağlık durumunu göremez');
select tst.fails($$select public.admin_user_export('00000000-0000-0000-0000-0000000000a2', 'kvkk başvurusu')$$, 'admin olmayan başkasını dışa aktaramaz');

-- --- imha: kuru çalıştırma yalnız sayar --------------------------------------------------------------------------
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
select tst.check((public.admin_retention_status() -> 'config' ->> 'live')::boolean = false, 'varsayılan: kuru çalıştırma');
select tst.fails($$select public.admin_retention_dry_run('deneme')$$, 'izleyici kuru çalıştıramaz');
select tst.fails($$select public.admin_set_retention_config('{"live":true}', 'avukat onayı')$$, 'izleyici ayarı değiştiremez');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal1');
select tst.fails($$select public.admin_retention_dry_run('deneme')$$, 'iki adımlı doğrulama şart');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
insert into tst.kv values ('dry', public.admin_retention_dry_run('ilk kuru çalıştırma'));
select tst.check((select (v -> 'dry')::boolean from tst.kv where k = 'dry'), 'panelden yalnız kuru');
select tst.check((select (v -> 'results' ->> '16_trial_history')::int from tst.kv where k = 'dry') = 1, 'kuru: 1 eski deneme geçmişi sayıldı');
select tst.check((select (v -> 'results' ->> '19_notifications')::int from tst.kv where k = 'dry') = 1, 'kuru: 1 eski bildirim');
select tst.check((select (v -> 'results' ->> '20_usage')::int from tst.kv where k = 'dry') = 5, 'kuru: 2 eski gün + 3 eski olay');
select tst.check((select (v -> 'results' ->> '21_anon_orphans')::int from tst.kv where k = 'dry') = 1, 'kuru: yalnız bağlanmamış ve 30 gün girişsiz cihaz');
select tst.check((select (v -> 'results' ->> '22_admin_audit')::int from tst.kv where k = 'dry') = 1, 'kuru: 5 yıldan eski denetim satırı');
select tst.check((select (v -> 'results' ->> '24_kvkk_requests')::int from tst.kv where k = 'dry') = 1, 'kuru: 3 yıldan eski kapanmış başvuru');
select tst.check((select (v -> 'results' ->> '10_invite_parent_fields')::int from tst.kv where k = 'dry') = 1, 'kuru: 30 günden eski biten davet');
select tst.check((select jsonb_array_length(v -> 'errors') from tst.kv where k = 'dry') = 0, 'kuru: hata yok');
select tst.check(exists (select 1 from public.admin_audit_list('system', 'retention', 10) a where a.action = 'retention.dry_run'), 'kuru çalıştırma denetim kaydında');
reset role;
select tst.check((select count(*) from public.trial_history) = 2 and (select count(*) from public.notifications where kind = 'test') = 2
                 and (select count(*) from auth.users where id = '00000000-0000-0000-0000-0000000000c8') = 1, 'kuru çalıştırma hiçbir şey silmedi');

-- --- ayar doğrulama ----------------------------------------------------------------------------------------------
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
select tst.fails($$select public.admin_set_retention_config('{"bilinmeyen":1}', 'deneme')$$, 'bilinmeyen anahtar reddedilir');
select tst.fails($$select public.admin_set_retention_config('{"runs_days":30}', 'deneme')$$, 'imha kaydı 3 yıldan kısa olamaz');
select tst.fails($$select public.admin_set_retention_config('{"audit_days":100}', 'deneme')$$, 'denetim kaydı 1 yıldan kısa olamaz');
select tst.fails($$select public.admin_set_retention_config('{"live":"evet"}', 'deneme')$$, 'live doğru/yanlış olmalı');
select tst.fails($$select public.admin_set_retention_config('{"notifications_days":30.5}', 'deneme')$$, 'gün tam sayı olmalı');
select tst.fails($$select public.admin_set_retention_config('{"live":true}', '')$$, 'gerekçesiz değişmez');
select tst.check((public.admin_set_retention_config('{"live":true}', 'avukat süreleri onayladı') ->> 'live')::boolean, 'owner live açar');
select tst.check(exists (select 1 from public.admin_audit_list('config', 'retention', 10) a where a.action = 'config.retention'), 'ayar değişikliği denetim kaydında');

-- --- imha: gerçek çalışma (gece işi) -----------------------------------------------------------------------------
reset role;
select tst.fails($$delete from public.admin_audit where reason = 'eski kayıt'$$, 'denetim kaydı elle silinemez (eski olsa da)');
select tst.fails($$select set_config('ortak.audit_purge_before', (now() - interval '10 days')::text, false);
                   delete from public.admin_audit where reason = 'yeni kayıt'$$, '1 yıldan yakın kesimle silinemez');
select set_config('ortak.audit_purge_before', '', false);
insert into tst.kv values ('live', public.retention_run('cron'));
select tst.check((select (v -> 'dry')::boolean = false and jsonb_array_length(v -> 'errors') = 0 from tst.kv where k = 'live'), 'gece işi gerçek ve hatasız');
select tst.check((select array_agg(email_hash order by 1) from public.trial_history) = '{yeni}', 'eski deneme geçmişi silindi, yenisi kaldı');
select tst.check((select count(*) from public.code_attempts) = 1, 'eski kod denemesi silindi');
select tst.check((select array_agg(title) from public.notifications where kind = 'test') = '{"Yeni bildirim"}', 'eski bildirim silindi');
select tst.check((select count(*) from public.activity_days) = 1 and (select count(*) from public.app_events where event = 'task.create') = 1, 'eski kullanım satırları silindi');
select tst.check((select users from public.usage_daily_totals where metric = 'active') = 2, 'eski aktif gün toplamı: 2 kişi');
select tst.check((select users = 2 and events = 3 from public.usage_daily_totals where metric = 'event:task.create'), 'eski olay toplamı: 2 kişi, 3 olay');
select tst.check(not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000c8'), 'bağlanmamış eski cihaz oturumu silindi');
select tst.check(exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000c9'), 'çocuğa bağlı cihaz kaldı (90 gün girişsiz olsa da)');
select tst.check(exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000c7'), 'yakında giriş yapan bağlanmamış cihaz kaldı');
select tst.check((select array_agg(reason) from public.admin_audit where action = 'user.signout') = '{"yeni kayıt"}', 'eski denetim satırı yalnız imha işiyle silindi');
select tst.check(current_setting('ortak.audit_purge_before', true) = '', 'denetim kesimi işlemden sonra kapalı');
select tst.fails($$delete from public.admin_audit where reason = 'yeni kayıt'$$, 'imhadan sonra da denetim kaydı elle silinemez');
select tst.check((select array_agg(kind) from public.kvkk_requests) = '{info}', 'eski kapanmış başvuru silindi, açık başvuru kaldı');
select tst.check((select parent_name = '' and parent_email is null from public.clinic_invites where code = 'ESKI01'), 'eski davette ebeveyn adı/e-postası boşaldı');
select tst.check((select parent_name = 'Zeynep' from public.clinic_invites where code = 'YENI01'), 'süren davete dokunulmadı');
select tst.check((select count(*) from public.retention_runs where ok) = 2, 'iki çalışma imha kaydında');
insert into tst.kv values ('again', public.retention_run('cron'));
select tst.check((select (select sum(x::text::int) from jsonb_each(v -> 'results') e(k2, x)) = 0 from tst.kv where k = 'again'), 'ikinci gece: silinecek bir şey kalmadı');

-- --- Verimi indir ------------------------------------------------------------------------------------------------
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('exp', public.my_data_export());
select tst.check((select v -> 'hesap' ->> 'eposta' from tst.kv where k = 'exp') = 'anne@example.com', 'hesap bilgisi');
select tst.check((select jsonb_array_length(v -> 'cocuklar') from tst.kv where k = 'exp') = 1, 'çocuk dahil');
select tst.check((select (v -> 'cocuklar' -> 0 ->> 'oyun_cihazi_bagli')::boolean and not (v -> 'cocuklar' -> 0 ? 'user_id') from tst.kv where k = 'exp'), 'cihaz kimliği yerine yalnız "bağlı"');
select tst.check((select jsonb_array_length(v -> 'mesajlar') from tst.kv where k = 'exp') = 3, 'kendi mesajları + çocuğun mesajı');
select tst.check((select not (v -> 'mesajlar')::text like '%Babanın%' from tst.kv where k = 'exp'), 'diğer ebeveynin mesajı ayıklandı');
select tst.check((select (v -> 'ayiklanan' ->> 'diger_ebeveynin_mesajlari')::int = 1
                         and (v -> 'ayiklanan' ->> 'diger_ebeveynin_davranis_kayitlari')::int = 1 from tst.kv where k = 'exp'), 'ayıklananların sayısı yazılı');
select tst.check((select jsonb_array_length(v -> 'davranis_kayitlari') from tst.kv where k = 'exp') = 1, 'yalnız kendi davranış kaydı');
select tst.check((select jsonb_array_length(v -> 'dosyalar') = 1 and v -> 'dosyalar' -> 0 ->> 'kova' = 'mail' from tst.kv where k = 'exp'), 'ses dosyası yol olarak listelendi');
select tst.check((select (v -> 'aile' ->> 'diger_ebeveyn_sayisi')::int = 1 and not (v::text like '%baba@example.com%') from tst.kv where k = 'exp'), 'diğer ebeveynin e-postası yok');
select tst.check((select jsonb_array_length(v -> 'ekip_islemleri') from tst.kv where k = 'exp') = 1, 'hesabındaki ekip işlemleri (kim olduğu ve gerekçe yazılmadan)');
select tst.check((select not (v -> 'ekip_islemleri')::text like '%kayıt%' from tst.kv where k = 'exp'), 'ekip gerekçesi dökümde yok');
select tst.check((select jsonb_array_length(v -> 'kvkk_basvurulari') from tst.kv where k = 'exp') = 1, 'kendi KVKK başvurusu');
reset role;
select tst.check((select count(*) from public.app_events where event = 'kvkk.data_export') = 1, 'indirme kullanım kaydına yazıldı');
set role authenticated;
select public.my_data_export(); select public.my_data_export(); select public.my_data_export(); select public.my_data_export();
select tst.fails($$select public.my_data_export()$$, 'günde en çok 5 indirme');
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.fails($$select public.my_data_export()$$, 'çocuk cihazı (anonim) dışa aktaramaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('dexp', public.my_data_export());
select tst.check((select v -> 'uzman' -> 'klinik' ->> 'ad' = 'Mavi Klinik' and (v -> 'uzman' -> 'klinik' ->> 'sahibi_benim')::boolean from tst.kv where k = 'dexp'), 'uzman: kendi kliniği');
select tst.check((select not (v ? 'cocuklar') and v ? 'danisan_kayitlari_notu' from tst.kv where k = 'dexp'), 'uzman dökümünde danışan kaydı yok');
select tst.check((select not (v::text like '%Ayşe%') and not (v::text like '%Zeynep%') from tst.kv where k = 'dexp'), 'davet edilen ebeveynlerin bilgisi yok');

-- panel: destek KVKK başvurusu için alır, izleyici alamaz
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
select tst.fails($$select public.admin_user_export('00000000-0000-0000-0000-0000000000a1', 'kvkk başvurusu')$$, 'izleyici dışa aktaramaz');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.fails($$select public.admin_user_export('00000000-0000-0000-0000-0000000000a1', '')$$, 'gerekçesiz dışa aktarılmaz');
select tst.fails($$select public.admin_user_export('00000000-0000-0000-0000-0000000000c9', 'kvkk başvurusu')$$, 'anonim cihaz dışa aktarılmaz');
select tst.check(public.admin_user_export('00000000-0000-0000-0000-0000000000a1', 'KVKK erişim başvurusu') -> 'hesap' ->> 'eposta' = 'anne@example.com', 'destek dışa aktarır');
select tst.check(exists (select 1 from public.admin_audit_list('user', '00000000-0000-0000-0000-0000000000a1', 10) a where a.action = 'user.data_export'), 'dışa aktarma denetim kaydında');
select public.admin_log_export('customers.parent', 120, 'aylık rapor');
select tst.fails($$select public.admin_log_export('Müşteri; drop', 1, 'x yz')$$, 'geçersiz dışa aktarma adı');
select tst.check(exists (select 1 from public.admin_audit_list('system', 'customers.parent', 10) a where a.action = 'export.csv' and (a.after ->> 'rows')::int = 120), 'CSV indirme denetim kaydında');

-- --- sağlık ------------------------------------------------------------------------------------------------------
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
insert into tst.kv values ('h1', public.admin_health());
select tst.check((select v ->> 'status' in ('ok', 'info', 'warn') from tst.kv where k = 'h1'), 'izleyici sağlık durumunu görür, kırmızı yok');
select tst.check((select c ->> 'level' from tst.kv, jsonb_array_elements(v -> 'checks') c where k = 'h1' and c ->> 'key' = 'retention') = 'ok', 'gece işi çalıştı: imha yeşil');
select tst.check((select c ->> 'level' from tst.kv, jsonb_array_elements(v -> 'checks') c where k = 'h1' and c ->> 'key' = 'kvkk') = 'ok', 'süresi yakın başvuru yok');
reset role;
update public.kvkk_requests set due_at = now() - interval '1 day' where kind = 'info';
insert into public.clinician_verifications (clinician_id, profession, status, submitted_at)
values ('00000000-0000-0000-0000-0000000000d1', 'psikolog', 'pending', now() - interval '5 days');
update public.clinics set plan = 'trial', trial_ends_at = now() + interval '1 day';
insert into public.retention_runs (trigger, dry, ok, errors, started_at, finished_at)
values ('cron', true, false, '[{"step":"x","error":"y"}]', now(), now());
set role authenticated;
insert into tst.kv values ('h2', public.admin_health());
select tst.check((select v ->> 'status' from tst.kv where k = 'h2') = 'fail', 'süresi geçen başvuru ya da hatalı imha → kırmızı');
select tst.check((select c ->> 'level' from tst.kv, jsonb_array_elements(v -> 'checks') c where k = 'h2' and c ->> 'key' = 'kvkk') = 'fail', 'KVKK süresi geçti');
select tst.check((select c ->> 'level' from tst.kv, jsonb_array_elements(v -> 'checks') c where k = 'h2' and c ->> 'key' = 'retention') = 'fail', 'imha hatası');
select tst.check((select c ->> 'level' from tst.kv, jsonb_array_elements(v -> 'checks') c where k = 'h2' and c ->> 'key' = 'verifications') = 'warn', 'eski belge bekliyor');
select tst.check((select c ->> 'level' from tst.kv, jsonb_array_elements(v -> 'checks') c where k = 'h2' and c ->> 'key' = 'clinic_trials') = 'warn', 'deneme bitiyor');
select tst.check((select not (v::text like '%@%') from tst.kv where k = 'h2'), 'sağlık çıktısında kişisel veri yok');
reset role;
