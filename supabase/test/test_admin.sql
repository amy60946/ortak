-- Admin paneli + KPI (proposed/20261023000000_admin.sql)
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', '{"aal":"aal1"}', false);
end $$;
-- iki adımlı doğrulamalı oturum
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
create or replace function tst.v(key text) returns uuid language sql as $$ select v::uuid from tst.kv where k = key $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- o1 owner, s1 destek, v1 izleyici, a1 ebeveyn (Anne), a2 ebeveyn (başka aile), d1 klinik sahibi, c1 çocuk cihazı
insert into auth.users (id, is_anonymous, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', now(), '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', now(), '{"nickname":"Destek"}'),
  ('00000000-0000-0000-0000-0000000000f3', false, 'izleyici@example.com', now(), '{"nickname":"İzleyici"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', now(), '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, 'baba@example.com', now(), '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'uzman@example.com', now(), '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, null, null, '{}');
insert into public.admin_users (user_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'owner'),
  ('00000000-0000-0000-0000-0000000000f2', 'support'),
  ('00000000-0000-0000-0000-0000000000f3', 'viewer');
insert into tst.kv select 'fa', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into tst.kv select 'fb', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a2';
insert into tst.kv select 'k1', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into public.children (id, family_id, name, avatar, user_id)
  values ('00000000-0000-0000-0000-00000000c001', tst.v('fa'), 'Nazlı', 'kedi', '00000000-0000-0000-0000-0000000000c1');
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c002', tst.v('fa'), 'Deniz', 'kopek');

-- ---------------------------------------------------------------- yetki
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.admin_me() is null, 'admin olmayana admin_me boş');
select tst.fails($$select * from public.admin_search('anne')$$, 'admin olmayan arayamaz');
select tst.fails($$select public.admin_kpi_summary(30)$$, 'admin olmayan KPI göremez');
select tst.fails($$select * from public.admin_users$$, 'admin tablosu istemciye kapalı');
select tst.fails($$select * from public.admin_audit$$, 'denetim kaydı istemciye kapalı');
select tst.fails($$select public.admin_require()$$, 'iç yardımcı istemciye kapalı');
select tst.fails($$select public.flag_on(auth.uid(), 'x')$$, 'bayrak hesabı istemciye kapalı');
select tst.fails($$select public.account_delete_of('00000000-0000-0000-0000-0000000000a2')$$, 'başkasının hesabı silinemez');

select tst.as_user('00000000-0000-0000-0000-0000000000f1');
select tst.check(public.admin_me() ->> 'role' = 'owner' and not (public.admin_me() ->> 'mfa')::boolean, 'owner, iki adım yok');
select tst.fails($$select * from public.admin_search('anne')$$, 'iki adımlı doğrulama olmadan arama yok');

select tst.as_mfa('00000000-0000-0000-0000-0000000000f3');
select tst.check((select count(*) from public.admin_search('anne@')) = 1, 'izleyici arar');
select tst.check(public.admin_user('00000000-0000-0000-0000-0000000000a1') -> 'account' ->> 'email' = 'anne@example.com', 'izleyici kullanıcı kartını görür');
select tst.fails($$select public.admin_extend_trial(tst.v('fa'), 3, 'deneme')$$, 'izleyici değiştiremez');
select tst.fails($$select public.admin_notify('00000000-0000-0000-0000-0000000000a1', 'Merhaba', '', 'deneme')$$, 'izleyici bildirim gönderemez');

-- ---------------------------------------------------------------- arama ve kartlar
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select tst.check((select count(*) from public.admin_search('Nazl') where kind = 'child') = 1, 'çocuk adıyla bulunur');
select tst.check((select count(*) from public.admin_search('Deniz') where kind = 'child' and user_id is null) = 1, 'bağlanmamış çocuk da bulunur');
select tst.check((select count(*) from public.admin_search('Mavi') where kind = 'clinic') = 1, 'klinik adıyla bulunur');
select tst.check((select count(*) from public.admin_search(tst.v('fa')::text)) >= 3, 'aile kimliğiyle ebeveyn ve çocuklar bulunur');
select tst.check((select count(*) from public.admin_search('%')) = 0, 'joker karakter kaçırılır');
select tst.check((select count(*) from public.admin_search('a')) = 0, 'tek harf aranmaz');
select tst.check(json_array_length(public.admin_family(tst.v('fa')) -> 'children') = 2, 'aile kartında iki çocuk');
select tst.check(public.admin_user('00000000-0000-0000-0000-0000000000c1') ->> 'kind' = 'child', 'çocuk hesabı türü');
select tst.check(public.admin_clinic(tst.v('k1')) -> 'clinic' ->> 'name' = 'Mavi Klinik', 'klinik kartı');

-- ---------------------------------------------------------------- destek işlemleri
select tst.fails($$select public.admin_extend_trial(tst.v('fa'), 3, '')$$, 'gerekçesiz işlem yok');
select tst.fails($$select public.admin_extend_trial(tst.v('fa'), 200, 'çok uzun')$$, 'en çok 90 gün');
select tst.check((public.admin_extend_trial(tst.v('fa'), 5, 'destek talebi #12') ->> 'days_left')::int = 12, 'deneme 7+5 gün');
select tst.check((public.admin_clinic_extend_trial(tst.v('k1'), 10, 'pilot görüşme') ->> 'active')::boolean, 'klinik denemesi uzadı');
select tst.check(public.admin_notify('00000000-0000-0000-0000-0000000000a1', 'Merhaba', 'Sorununuz çözüldü', 'destek talebi #12') > 0, 'kişiye bildirim');
select tst.check(public.admin_notify('00000000-0000-0000-0000-0000000000c1', 'Pofi seni bekliyor', '', 'deneme') > 0, 'çocuğa bildirim');
select tst.fails($$select public.admin_grant_premium(tst.v('fa'), now() + interval '30 days', 'hediye')$$, 'destek premium veremez');
select tst.fails($$select public.admin_suspend('00000000-0000-0000-0000-0000000000a2', null, 'kural ihlali')$$, 'destek askıya alamaz');
select public.admin_set_user_flag('00000000-0000-0000-0000-0000000000a1', 'new_home', true, now() + interval '7 days', 'beta deneyici');
select public.admin_signout('00000000-0000-0000-0000-0000000000a1', 'cihaz kaybı');
select public.admin_log_client('user.password_reset_email', '00000000-0000-0000-0000-0000000000a1', 'kullanıcı istedi');
select tst.fails($$select public.admin_log_client('user.delete', '00000000-0000-0000-0000-0000000000a1', 'x x x')$$, 'istemci kaydı yalnız izinli işlem');
reset role;
select tst.check((select count(*) from public.notifications where kind = 'admin_message') = 2, 'bildirimler yazıldı');
select tst.check((select app from public.notifications where kind = 'admin_message' and user_id = '00000000-0000-0000-0000-0000000000c1') = 'child', 'çocuğa oyun bildirimi');
select tst.check((select count(*) from public.admin_audit where admin_id = '00000000-0000-0000-0000-0000000000f2') = 7, 'her işlem denetim kaydında');
select tst.fails($$update public.admin_audit set reason = 'değişti'$$, 'denetim kaydı değiştirilemez (sunucu bile)');
select tst.fails($$delete from public.admin_audit$$, 'denetim kaydı silinemez');

-- ---------------------------------------------------------------- bayraklar ve uygulama ayarı
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select public.admin_set_flag('new_home', false, 100, 'Yeni ana ekran', 'hazır değil');
select public.admin_set_flag('rewards_v2', true, 100, '', 'herkese açık');
select public.admin_set_app_config('parent', '1.2.0', false, 'Yeni sürüm yayında', 'zorunlu güncelleme');
select tst.fails($$select public.admin_set_app_config('parent', 'bir', false, '', 'yanlış')$$, 'sürüm biçimi denetlenir');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.client_config('parent') -> 'flags' ->> 'new_home')::boolean, 'kişiye istisna genel kapalıyı açar');
select tst.check((public.client_config('parent') -> 'flags' ->> 'rewards_v2')::boolean, 'genel bayrak açık');
select tst.check(public.client_config('parent') -> 'app' ->> 'min_version' = '1.2.0', 'en düşük sürüm okunur');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(not (public.client_config('parent') -> 'flags' ->> 'new_home')::boolean, 'istisnası olmayana kapalı');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.client_config('child') -> 'app')::jsonb = '{}'::jsonb, 'çocuk uygulamasında ayar yoksa boş');

-- ---------------------------------------------------------------- finans ve owner işlemleri
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select tst.check(public.admin_grant_premium(tst.v('fb'), now() + interval '30 days', 'pilot aile') ->> 'state' = 'premium', 'elle premium');
select tst.check(public.admin_revoke_premium(tst.v('fb'), 'pilot bitti') ->> 'state' <> 'premium', 'elle premium kaldırıldı');
select tst.fails($$select public.admin_revoke_premium(tst.v('fb'), 'tekrar')$$, 'elle premium yokken kaldırılamaz');
reset role;
select public.set_family_subscription(tst.v('fa'), 'premium', 'monthly', 'active', now() + interval '20 days', true, 'parentapp.premium.monthly', 't1', 'store');
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select tst.fails($$select public.admin_grant_premium(tst.v('fa'), now() + interval '30 days', 'hediye')$$, 'mağaza aboneliği ezilmez');
select tst.check((public.admin_clinic_grant(tst.v('k1'), 'clinic_yearly', now() + interval '90 days', 'pilot klinik') ->> 'active')::boolean, 'kliniğe elle üyelik');
select tst.check((public.admin_clinic_revoke(tst.v('k1'), 'pilot bitti') ->> 'revoked')::int = 1, 'klinik elle üyelik kaldırıldı');
select tst.fails($$select public.admin_suspend('00000000-0000-0000-0000-0000000000f1', null, 'kendim')$$, 'kendini askıya alamaz');
select tst.fails($$select public.admin_suspend('00000000-0000-0000-0000-0000000000f2', null, 'admin')$$, 'admini askıya alamaz');
select public.admin_suspend('00000000-0000-0000-0000-0000000000a2', null, 'kural ihlali');
reset role;
select tst.check((select banned_until > now() + interval '50 years' from auth.users where id = '00000000-0000-0000-0000-0000000000a2'), 'askıya alındı');
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select public.admin_unsuspend('00000000-0000-0000-0000-0000000000a2', 'itiraz kabul');
select tst.fails($$select public.admin_set_admin('owner@example.com', 'viewer', 'kendimi düşür')$$, 'son owner düşürülemez');
select public.admin_set_admin('baba@example.com', 'viewer', 'yeni ekip üyesi');
select tst.check((select count(*) from public.admin_list_admins()) = 4, 'admin eklendi');
select public.admin_set_admin('baba@example.com', null, 'ayrıldı');
select tst.fails($$select public.admin_delete_user('00000000-0000-0000-0000-0000000000f2', 'admin silme')$$, 'admin silinemez');
select public.admin_delete_user('00000000-0000-0000-0000-0000000000a2', 'KVKK silme talebi #3');
reset role;
select tst.check(not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000000a2'), 'hesap silindi');
select tst.check(not exists (select 1 from public.families where id = tst.v('fb')), 'tek ebeveynli aile silindi');
select tst.check(exists (select 1 from public.admin_audit where action = 'user.delete'
                           and target_id = '00000000-0000-0000-0000-0000000000a2' and before ->> 'kind' = 'parent'), 'silme kaydı kaldı (e-postasız)');
select tst.check(not exists (select 1 from public.admin_audit where before::text like '%baba@example.com%'), 'denetim kaydında silinenin e-postası yok');

-- delete_account eskisi gibi çalışır (ortak gövde)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.delete_account();
reset role;
select tst.check(not exists (select 1 from public.clinics where id = tst.v('k1')), 'tek kişilik klinik kendi hesabını silince klinik silindi');

-- ---------------------------------------------------------------- KPI
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.track_session('parent', 'ios', '1.2.0');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.track_session('child', 'ios', '1.0.0');
reset role;
insert into public.activity_days (user_id, app, day) values ('00000000-0000-0000-0000-0000000000a1', 'parent', current_date - 1),
  ('00000000-0000-0000-0000-0000000000a1', 'parent', current_date - 10);
update public.user_activity set first_seen_at = now() - interval '11 days' where user_id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f3');
select tst.check((public.admin_kpi_summary(30) -> 'active' -> 'parent' ->> 'dau')::int = 1, 'günlük aktif ebeveyn');
select tst.check((public.admin_kpi_summary(30) -> 'active' -> 'parent' ->> 'mau')::int = 1, 'aylık aktif ebeveyn');
select tst.check((public.admin_kpi_summary(30) -> 'active' -> 'child' ->> 'dau')::int = 1, 'günlük aktif çocuk');
select tst.check((public.admin_kpi_summary(30) -> 'revenue' ->> 'parent_monthly')::int = 1, 'aylık abone sayısı');
select tst.check((public.admin_kpi_summary(30) -> 'totals' ->> 'children_linked')::int = 1, 'bağlı çocuk sayısı');
select tst.check((select count(*) from public.admin_kpi_daily(current_date - 6, current_date)) = 21, 'günlük seri 7 gün × 3 uygulama');
select tst.check((select active_users from public.admin_kpi_daily(current_date, current_date) where app = 'parent') = 1, 'bugün 1 aktif ebeveyn');
select tst.check((select d1 from public.admin_kpi_retention(8) where app = 'parent') = 1, 'ebeveyn G1 geri döndü');
select tst.check((select count from public.admin_kpi_funnel('parent', current_date - 1, current_date) where step = 3) = 1, 'huni: çocuk eklendi');
select tst.check((select count from public.admin_kpi_funnel('child', current_date - 1, current_date) where step = 2) = 1, 'huni: cihaz bağlandı');
select tst.fails($$select * from public.admin_kpi_funnel('baska', current_date, current_date)$$, 'bilinmeyen huni');
select tst.fails($$select * from public.admin_kpi_daily(current_date - 400, current_date)$$, 'en çok 1 yıl');
select tst.fails($$select public.admin_set_kpi_config('{"parent_monthly_try": 99}', 'fiyat')$$, 'izleyici fiyat değiştiremez');

-- uygulama bazında göstergeler (proposed/20261024000000_admin_fixes.sql)
select tst.check((public.admin_kpi_apps(30) -> 'parent' ->> 'subscribers_monthly')::int = 1, 'ParentApp: aylık abone');
select tst.check((public.admin_kpi_apps(30) -> 'child' ->> 'linked')::int = 1, 'GameApp: bağlı çocuk');
select tst.check((public.admin_kpi_apps(30) -> 'child' ->> 'active')::int = 1, 'GameApp: aktif çocuk');
select tst.check((public.admin_kpi_apps(30) -> 'clinic' ->> 'clinics')::int = 0, 'ClinicApp: klinik sayısı (silindi)');
select tst.check((public.admin_kpi_apps(30) -> 'total' ->> 'mrr_gross_try')::numeric = 0, 'fiyat yokken toplam gelir 0');
select tst.check((select count(*) from public.admin_search('example.com')) >= 3, 'e-postayla arama (varchar e-posta)');
select tst.check((select email from public.admin_search('owner@') limit 1) = 'owner@example.com', 'arama e-postayı döner');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select public.admin_set_kpi_config('{"parent_monthly_try": 100}', 'ParentApp aylık fiyatı');
select tst.check((public.admin_kpi_summary(30) -> 'revenue' ->> 'mrr_gross_try')::numeric = 100, 'brüt aylık gelir');
select tst.check((public.admin_kpi_summary(30) -> 'revenue' ->> 'mrr_net_try')::numeric = 84.15, 'net: Apple %15 ve RevenueCat %1 sonrası');
select tst.check((public.admin_kpi_apps(30) -> 'parent' ->> 'mrr_net_try')::numeric = 84.15, 'ParentApp net gelir');
reset role;

select 'TÜM ADMİN TESTLERİ GEÇTİ' as sonuc;
