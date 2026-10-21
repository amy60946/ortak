-- Klinik ekibi + kullanıcı takibi (migrations/20261021100000_clinic_team_tracking.sql)
\set ON_ERROR_STOP on

create schema if not exists tst;
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
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

-- d1 sahip (Mavi Klinik), d2 ekip koduyla kayıt, d3 yanlışlıkla kendi kliniğini açmış, d4 dolu kliniği olan uzman, a1 ebeveyn
insert into auth.users (id, is_anonymous, raw_user_meta_data, email) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece","title":"Psikolog"}', 'ece@ornek.test'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Kliniğim","name":"Can"}', 'can@ornek.test'),
  ('00000000-0000-0000-0000-0000000000d4', false, '{"account":"clinician","clinic_name":"Dolu Klinik","name":"Deniz"}', 'deniz@ornek.test'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne","name":"Ayşe"}', 'ayse@ornek.test');
insert into tst.kv select 'k1', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into tst.kv select 'k3', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d3';
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi'),
         ('00000000-0000-0000-0000-00000000c002', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Efe', 'kedi');

set role authenticated;

-- ---------------------------------------------------------------- ekip kodu ile kayıt → davet eden görünür
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team1', code from (select public.clinic_create_invite('clinician', '') ->> 'code' as code) x;
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false,
   jsonb_build_object('account', 'clinician', 'name', 'Mert', 'title', 'Ergoterapist', 'team_code', (select v from tst.kv where k = 'team1')));
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(public.clinician_me() ->> 'clinic' = 'Mavi Klinik', 'üye klinik adını görür');
select tst.check(public.clinician_me() ->> 'role' = 'member', 'üye rolü');
select tst.check(public.clinician_me() ->> 'invited_by_name' = 'Dr. Ece', 'davet eden görünür');
select tst.check(public.clinician_me() ->> 'owner_name' = 'Dr. Ece', 'klinik sahibi görünür');
select tst.check((public.clinician_me() ->> 'clinic_id') = (select v from tst.kv where k = 'k1'), 'üye ile sahip aynı klinikte');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinician_me() ->> 'invited_by_name' is null, 'kurucunun davet edeni yok');

-- ---------------------------------------------------------------- giriş yapmış uzman sonradan katılır
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team2', code from (select public.clinic_create_invite('clinician', '') ->> 'code' as code) x;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.rejects($$select public.clinic_join_team((select v from tst.kv where k = 'team2'))$$, 'ebeveyn hesabı ekibe katılamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.rejects($$select public.clinic_join_team('ZZZZZZ')$$, 'geçersiz kod');
select public.clinic_join_team((select v from tst.kv where k = 'team2'));
select tst.check(public.clinician_me() ->> 'clinic' = 'Mavi Klinik', 'katılan yeni kliniği görür');
select tst.check(public.clinician_me() ->> 'role' = 'member', 'katılan üye olur');
select tst.check(public.clinician_me() ->> 'invited_by_name' = 'Dr. Ece', 'katılanın davet edeni');
reset role;
select tst.check(not exists (select 1 from public.clinics where id = (select v::uuid from tst.kv where k = 'k3')), 'boş eski klinik silindi');
select tst.check(exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'team_joined'
                          and title like 'Can%'), 'sahibe "ekibe katıldı" bildirimi');
set role authenticated;
select tst.rejects($$select public.clinic_join_team((select v from tst.kv where k = 'team2'))$$, 'kullanılmış kod ikinci kez kullanılamaz');

-- dolu kliniği olan uzman katılamaz (veri kaybı olmasın)
select tst.as_user('00000000-0000-0000-0000-0000000000d4');
insert into tst.kv select 'fam', code from (select public.clinic_create_invite('family', 'Deneme') ->> 'code' as code) x;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.redeem_clinic_invite((select v from tst.kv where k = 'fam'), '00000000-0000-0000-0000-00000000c001');
-- aynı uzmana ikinci çocuk kodsuz eklenir → uzmana yine bildirim (ParentApp "çocuk ekle")
select public.clinic_share_child((select clinic_id from public.family_clinic_links() limit 1), '00000000-0000-0000-0000-00000000c002');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d4' and kind = 'clinic_shared') = 2,
  'ikinci çocuk eklenince uzmana bildirim');
select tst.check((select title from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d4' and kind = 'clinic_shared'
                  order by id desc limit 1) = 'Yeni paylaşım: Efe', 'bildirim ikinci çocuğun adını taşır');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team3', code from (select public.clinic_create_invite('clinician', '') ->> 'code' as code) x;
select tst.as_user('00000000-0000-0000-0000-0000000000d4');
select tst.rejects($$select public.clinic_join_team((select v from tst.kv where k = 'team3'))$$, 'danışanı olan klinik bırakılamaz');
select tst.check(public.clinician_me() ->> 'clinic' = 'Dolu Klinik', 'dolu klinikte kalır');

-- ---------------------------------------------------------------- takip
select tst.as_user(null);
select tst.fails($$select public.track_session('clinic', 'ios', '1.0')$$, 'girişsiz oturum yazılamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.track_session('clinic', 'ios', '1.0.0');
select public.track_session('clinic', 'ios', '1.0.0');    -- dakika içinde ikinci açılış sayılmaz
select tst.fails($$select public.track_session('admin', 'ios', '1.0')$$, 'tanımsız uygulama');
select tst.check(public.track_events('clinic', '[{"event":"screen.client","props":{"tab":"abc"}},{"event":"report.print"}]', 'ios', '1.0.0') = 2, 'iki olay yazıldı');
select tst.fails($$select public.track_events('clinic', '[{"event":"Kötü Ad"}]')$$, 'olay adı biçimi');
select tst.fails($$select public.track_events('clinic', '{"event":"x"}')$$, 'dizi olmalı');
select tst.fails($$select public.track_events('clinic', (select jsonb_agg(jsonb_build_object('event', 'screen.home')) from generate_series(1, 51)))$$, 'en çok 50 olay');
select tst.fails($$select public.track_events('clinic', jsonb_build_array(jsonb_build_object('event', 'x.big', 'props', jsonb_build_object('t', repeat('a', 1200)))))$$, 'büyük props reddedilir');
select tst.fails($$select count(*) from public.app_events$$, 'istemci olayları okuyamaz');
select tst.fails($$select count(*) from public.user_activity$$, 'istemci etkinliği okuyamaz');
select tst.fails($$insert into public.app_events (user_id, app, event) values (auth.uid(), 'clinic', 'sahte')$$, 'istemci doğrudan yazamaz');
select tst.fails($$select count(*) from analytics.accounts$$, 'iş görünümleri istemciye kapalı');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.track_session('parent', 'ios', '2.0');

reset role;
select tst.check((select sessions from public.user_activity where user_id = '00000000-0000-0000-0000-0000000000d1' and app = 'clinic') = 1, 'aynı dakikada tek oturum');
select tst.check((select app_version from public.user_activity where user_id = '00000000-0000-0000-0000-0000000000d1') = '1.0.0', 'sürüm kaydı');
select tst.check((select count(*) from public.app_events where user_id = '00000000-0000-0000-0000-0000000000d1') = 2, 'olaylar sunucuda');
-- ertesi gün açılış: aktif gün artar
update public.user_activity set last_active_date = current_date - 1, last_seen_at = now() - interval '1 day'
  where user_id = '00000000-0000-0000-0000-0000000000d1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.track_session('clinic', 'ios', '1.0.1');
reset role;
select tst.check((select active_days from public.user_activity where user_id = '00000000-0000-0000-0000-0000000000d1') = 2, 'ertesi gün aktif gün sayılır');
select tst.check((select sessions from public.user_activity where user_id = '00000000-0000-0000-0000-0000000000d1') = 2, 'ertesi gün yeni oturum');

-- günlük sınır
insert into public.app_events (user_id, app, event) select '00000000-0000-0000-0000-0000000000a1', 'parent', 'screen.home' from generate_series(1, 1999);
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.track_events('parent', '[{"event":"a.b"},{"event":"a.c"}]') = 1, 'günlük 2000 sınırı');
reset role;

-- iş görünümleri
select tst.check((select kind from analytics.accounts where user_id = '00000000-0000-0000-0000-0000000000d2') = 'clinician', 'hesap türü: uzman');
select tst.check((select kind from analytics.accounts where user_id = '00000000-0000-0000-0000-0000000000a1') = 'parent', 'hesap türü: ebeveyn');
select tst.check((select email from analytics.accounts where user_id = '00000000-0000-0000-0000-0000000000a1') = 'ayse@ornek.test', 'e-posta görünümde');
select tst.check((select clinicians from analytics.clinics_overview where name = 'Mavi Klinik') = 3, 'klinik özeti: 3 uzman');
select tst.check((select active_clients from analytics.clinics_overview where name = 'Dolu Klinik') = 2, 'klinik özeti: etkin danışan');
select tst.check((select children from analytics.families_overview limit 1) >= 0, 'aile özeti çalışır');
select tst.check((select sum(signups) from analytics.signups_daily) = 5, 'kayıt sayısı');
select tst.check(exists (select 1 from analytics.daily_active where app = 'clinic'), 'günlük aktif');
select tst.check(exists (select 1 from analytics.events_daily where event = 'report.print'), 'olay sayıları');

select 'TÜM EKİP + TAKİP TESTLERİ GEÇTİ' as sonuc;
