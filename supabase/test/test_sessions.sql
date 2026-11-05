-- Seans planlama (proposed/20261105100000_sessions.sql): görünürlük (sahip, ekip üyesi, başka klinik, aile), yazma yalnız
-- işlevlerle, tekrarlayan seans + tek bildirim, geç iptal, aile yanıtı, uygun saatten randevu, bekleme listesi teklifi,
-- paket, kayıt aileye kapalı, paylaşım bitince iptal, takvim aboneliği ve dış takvim.
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
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- d1 sahip (Mavi), d9 başka klinik; a1 ailesi (Nazlı), a9 ailesi (Ece)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a9', false, '{"nickname":"Baba"}');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c009', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a9'), 'Ece', 'kedi');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select x.l::uuid, m.clinic_id, m.id, c.family_id, c.id, x.p::uuid
  from public.clinicians m, public.children c,
    (values ('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000a1'),
            ('00000000-0000-0000-0000-0000000011a9', '00000000-0000-0000-0000-00000000c009', '00000000-0000-0000-0000-0000000000a9')) as x(l, ch, p)
  where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = x.ch::uuid;

-- ekip üyesi d2 (sahibin koduyla)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false, jsonb_build_object('account', 'clinician', 'name', 'Mert', 'team_code', (select v from tst.kv where k = 'team')));
select tst.check((select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2')
                 = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1'), 'd2 aynı klinikte');

-- ---------------------------------------------------------------------
-- A/B: tekrarlayan seans, tek bildirim, aile görür
-- ---------------------------------------------------------------------
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'series', public.clinic_session_create(jsonb_build_object(
  'link_id', '00000000-0000-0000-0000-0000000011a1', 'starts_at', date_trunc('hour', now()) + interval '3 days',
  'duration_min', 45, 'repeat', 'weekly', 'count', 4, 'visible_to_family', true, 'kind', 'individual'))::text;
select tst.check(json_array_length((select v::json -> 'ids' from tst.kv where k = 'series')) = 4, 'her hafta 4 seans oluştu');
insert into tst.kv select 's1', (select v::json -> 'ids' ->> 0 from tst.kv where k = 'series');
insert into tst.kv select 'hidden', public.clinic_session_create(jsonb_build_object(
  'link_id', '00000000-0000-0000-0000-0000000011a9', 'starts_at', date_trunc('hour', now()) + interval '2 days' + interval '2 hours'))::json -> 'ids' ->> 0;
select tst.check(tst.cnt('public.clinic_sessions') = 5, 'sahip 5 seansı görür');
select tst.fails($$insert into public.clinic_sessions (clinic_id, starts_at) values (public.my_clinic_id(), now())$$, 'tabloya doğrudan yazılmaz');
select tst.fails($$update public.clinic_sessions set status = 'done'$$, 'tabloda doğrudan güncelleme yok');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000a1'
                  and kind = 'session_scheduled') = 1, 'seri için aileye tek bildirim');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000a9'
                  and kind like 'session_%') = 0, 'aileye gösterilmeyen seans bildirim göndermez');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(json_array_length(public.family_sessions()) = 4, 'aile kendi 4 randevusunu görür');
select tst.check(tst.cnt('public.clinic_sessions') = 0, 'aile tabloyu doğrudan okumaz');
select tst.check((public.family_sessions() -> 0 -> 'reminders' ->> 0)::int = 1440 and json_array_length(public.family_sessions() -> 0 -> 'reminders') = 2,
                 'hatırlatma dakikaları aileye gider');
select tst.as_user('00000000-0000-0000-0000-0000000000a9');
select tst.check(json_array_length(public.family_sessions()) = 0, 'diğer aile gizli seansı görmez');

-- ekip üyesi atanmadığı danışanın seansını görmez; kendi bloğunu görür
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(tst.cnt('public.clinic_sessions') = 0, 'ekip üyesi atanmadığı danışanın seansını görmez');
select tst.fails($$select public.clinic_session_create(jsonb_build_object('link_id', '00000000-0000-0000-0000-0000000011a1', 'starts_at', now() + interval '1 day'))$$,
                 'ekip üyesi görmediği danışana seans açamaz');
select tst.fails($$select public.clinic_session_create(jsonb_build_object('clinician_id', '00000000-0000-0000-0000-0000000000d1', 'starts_at', now() + interval '1 day'))$$,
                 'ekip üyesi başkasına seans atayamaz');
select public.clinic_session_create(jsonb_build_object('title', 'Ekip toplantısı', 'starts_at', date_trunc('hour', now()) + interval '1 day', 'kind', 'other'));
select tst.check(tst.cnt('public.clinic_sessions') = 1, 'ekip üyesi kendi bloğunu görür');
select tst.check((select count(*) from public.clinic_busy(now(), now() + interval '40 days')) = 6, 'dolu saatler bütün klinikten, danışansız');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check(tst.cnt('public.clinic_sessions') = 0, 'başka klinik görmez');
select tst.check((select count(*) from public.clinic_busy(now(), now() + interval '40 days')) = 0, 'başka klinik dolu saatleri görmez');

-- ---------------------------------------------------------------------
-- C: seans kaydı yalnız klinikte
-- ---------------------------------------------------------------------
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_session_record_save((select v::uuid from tst.kv where k = 's1'),
  '{"attendees":["Nazlı","Anne"],"observation":"Sabah rutini daha kolay","agenda":[{"text":"Ekran geçişi","done":true}],"homework":[{"kind":"suggestion","id":"x","title":"Kıyafet"}]}');
select tst.check(tst.cnt('public.clinic_session_records') = 1, 'kayıt klinikte');
select tst.check((select observation from public.clinic_session_records) = 'Sabah rutini daha kolay', 'kayıt yazıldı');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(tst.cnt('public.clinic_session_records') = 0, 'aile kaydı görmez');
select tst.check(position('Sabah rutini' in public.family_sessions()::text) = 0, 'aile işlevinde kayıt yok');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(tst.cnt('public.clinic_session_records') = 0, 'atanmamış ekip üyesi kaydı görmez');

-- ---------------------------------------------------------------------
-- Durum: geç iptal, ertelenmiş, başlamamış seans "yapıldı" olmaz; aile yanıtı
-- ---------------------------------------------------------------------
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.clinic_session_set_status((select v::uuid from tst.kv where k = 's1'), 'done')$$, 'gelecekteki seans yapıldı sayılmaz');
insert into tst.kv select 'soon', public.clinic_session_create(jsonb_build_object(
  'link_id', '00000000-0000-0000-0000-0000000011a9', 'starts_at', date_trunc('hour', now()) + interval '5 hours'))::json -> 'ids' ->> 0;
select tst.check(public.clinic_session_set_status((select v::uuid from tst.kv where k = 'hidden'), 'cancelled', 'Hasta') = 'cancelled',
                 '24 saatten önce iptal iptaldir');
select tst.check(public.clinic_session_set_status((select v::uuid from tst.kv where k = 'soon'), 'cancelled', 'Hasta') = 'late_cancel',
                 '24 saatten kısa sürede iptal geç iptal olur');
select tst.check(public.clinic_session_set_status((select v::uuid from tst.kv where k = 'soon'), 'cancelled', 'Hasta', true) = 'cancelled',
                 'uzman geç iptali affedebilir');
select tst.check(public.clinic_session_set_status((select v::uuid from tst.kv where k = 'hidden'), 'planned') = 'planned', 'yeniden planlanır');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.family_session_respond((select v::uuid from tst.kv where k = 's1'), 'unavailable', 'Okul gezisi var');
select tst.fails($$select public.family_session_respond((select v::uuid from tst.kv where k = 'hidden'), 'ok')$$, 'aile başka ailenin seansını yanıtlayamaz');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1'
                  and kind = 'session_family_response') = 1, 'uzmana "gelemiyor" bildirimi');
select tst.check((select family_note from public.clinic_sessions where id = (select v::uuid from tst.kv where k = 's1')) = 'Okul gezisi var', 'aile notu yazıldı');

-- bu ve sonrakiler bir saat ileri: aile yanıtı sıfırlanır, aileye bir "değişti" bildirimi
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((public.clinic_session_update((select v::uuid from tst.kv where k = 's1'),
  jsonb_build_object('starts_at', (select starts_at + interval '1 hour' from public.clinic_sessions where id = (select v::uuid from tst.kv where k = 's1'))),
  'following') ->> 'updated')::int = 4, 'bu ve sonraki 3 seans kaydı');
select tst.check((select family_response is null from public.clinic_sessions where id = (select v::uuid from tst.kv where k = 's1')), 'saat değişince aile yanıtı sıfırlanır');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000a1' and kind = 'session_changed') = 1,
                 'aileye tek "değişti" bildirimi');

-- ---------------------------------------------------------------------
-- D: paket, uygun saatten randevu, bekleme listesi teklifi
-- ---------------------------------------------------------------------
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'pkg', public.clinic_package_save(null, '00000000-0000-0000-0000-0000000011a1', '10 seans', 10)::text;
select public.clinic_session_update((select v::uuid from tst.kv where k = 's1'), jsonb_build_object('package_id', (select v from tst.kv where k = 'pkg')));
select tst.fails($$select public.clinic_session_update((select v::uuid from tst.kv where k = 'hidden'), jsonb_build_object('package_id', (select v from tst.kv where k = 'pkg')))$$,
                 'başka danışanın paketi bağlanamaz');
select tst.check(tst.cnt('public.clinic_session_packages') = 1, 'paket klinikte');
insert into tst.kv select 'room', public.clinic_room_save(null, 'Oda 1', 'Kadıköy')::text;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.fails($$select public.clinic_room_save(null, 'Oda 2')$$, 'odayı yalnız sahip ekler');
select tst.fails($$select public.clinic_session_settings_save('{"booking_enabled":true}')$$, 'ayarı yalnız sahip değiştirir');
select tst.fails($$insert into public.clinic_availability (clinic_id, clinician_id, weekday, start_time, end_time)
                   values (public.my_clinic_id(), '00000000-0000-0000-0000-0000000000d1', 1, '09:00', '12:00')$$, 'ekip üyesi başkasının saatini yazamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(json_array_length(public.family_booking_slots('00000000-0000-0000-0000-0000000011a1')) = 0, 'randevu kapalıyken saat yok');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_session_settings_save('{"booking_enabled":true,"booking_notice_hours":24,"slot_minutes":45}');
insert into public.clinic_availability (clinic_id, clinician_id, weekday, start_time, end_time, room_id, bookable)
  select public.my_clinic_id(), auth.uid(), d, '09:00', '12:00', (select v::uuid from tst.kv where k = 'room'), true from generate_series(1, 7) d;
select tst.check((public.clinic_session_settings() ->> 'booking_enabled')::boolean, 'ayar kaydedildi');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'slot', public.family_booking_slots('00000000-0000-0000-0000-0000000011a1') -> 0 ->> 'starts_at';
select tst.check((select v from tst.kv where k = 'slot') is not null, 'aile uygun saat görür');
select tst.check((select v::timestamptz from tst.kv where k = 'slot') > now() + interval '24 hours', 'bildirim süresinden önce saat yok');
insert into tst.kv select 'booked', public.family_book_slot('00000000-0000-0000-0000-0000000011a1', (select v::timestamptz from tst.kv where k = 'slot'))::text;
select tst.check(json_array_length(public.family_sessions()) = 5, 'alınan randevu ailede görünür');
select tst.check(not exists (select 1 from json_array_elements(public.family_booking_slots('00000000-0000-0000-0000-0000000011a1')) e
                             where (e ->> 'starts_at')::timestamptz = (select v::timestamptz from tst.kv where k = 'slot')), 'alınan saat listeden düşer');
select tst.fails($$select public.family_book_slot('00000000-0000-0000-0000-0000000011a1', now() + interval '1 hour')$$, 'listede olmayan saat alınamaz');
select public.family_book_slot('00000000-0000-0000-0000-0000000011a1',
  (public.family_booking_slots('00000000-0000-0000-0000-0000000011a1') -> 0 ->> 'starts_at')::timestamptz);
select tst.fails($$select public.family_book_slot('00000000-0000-0000-0000-0000000011a1',
  (public.family_booking_slots('00000000-0000-0000-0000-0000000011a1') -> 0 ->> 'starts_at')::timestamptz)$$, 'en çok 2 aile randevusu');
select tst.as_user('00000000-0000-0000-0000-0000000000a9');
select tst.fails($$select public.family_book_slot('00000000-0000-0000-0000-0000000011a1', now() + interval '3 days')$$, 'başka ailenin paylaşımından randevu alınmaz');
reset role;
select tst.check((select booked_by from public.clinic_sessions where id = (select v::uuid from tst.kv where k = 'booked')) = 'family', 'aile randevusu işaretli');
select tst.check((select room_id from public.clinic_sessions where id = (select v::uuid from tst.kv where k = 'booked')) = (select v::uuid from tst.kv where k = 'room'),
                 'aile randevusu çalışma saatinin odasını alır');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'session_booked') = 2,
                 'uzmana "aile randevu aldı" bildirimi');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'wait', public.clinic_waitlist_save('00000000-0000-0000-0000-0000000011a9', 'Salı öğleden sonra')::text;
select tst.check(public.clinic_waitlist_save('00000000-0000-0000-0000-0000000011a9', 'Salı ya da çarşamba')::text = (select v from tst.kv where k = 'wait'),
                 'bekleme listesinde tek satır');
insert into tst.kv select 'offer', public.clinic_waitlist_offer((select v::uuid from tst.kv where k = 'wait'), date_trunc('hour', now()) + interval '5 days', 45, null, 12)::text;
select tst.as_user('00000000-0000-0000-0000-0000000000a9');
select tst.check((public.family_sessions() -> 0 ->> 'status') = 'offered', 'aile teklifi görür');
select tst.check(public.family_offer_respond((select v::uuid from tst.kv where k = 'offer'), true) = 'planned', 'aile teklifi kabul eder');
select tst.fails($$select public.family_offer_respond((select v::uuid from tst.kv where k = 'offer'), true)$$, 'teklif bir kez yanıtlanır');
reset role;
select tst.check((select status from public.clinic_waitlist where id = (select v::uuid from tst.kv where k = 'wait')) = 'booked', 'bekleme kaydı randevuya döndü');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000a9' and kind = 'session_offer') = 1, 'aileye teklif bildirimi');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'session_offer_answered') = 1, 'uzmana yanıt bildirimi');

-- ---------------------------------------------------------------------
-- Silme: kaydı olan silinmez; bu ve sonrakiler
-- ---------------------------------------------------------------------
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.clinic_session_delete((select v::uuid from tst.kv where k = 's1'))$$, 'kaydı olan seans silinmez');
select tst.check(public.clinic_session_delete((select v::json -> 'ids' ->> 1 from tst.kv where k = 'series')::uuid, 'following') = 3,
                 'serinin kalan 3 seansı silindi');

-- ---------------------------------------------------------------------
-- E: takvim aboneliği ve dış takvim
-- ---------------------------------------------------------------------
insert into tst.kv select 'token', public.clinic_calendar_feed('get') ->> 'token';
select tst.check(char_length((select v from tst.kv where k = 'token')) = 48, 'belirteç oluştu');
select tst.check(public.clinic_calendar_feed('get') ->> 'token' = (select v from tst.kv where k = 'token'), 'aynı belirteç döner');
select tst.fails($$select public.calendar_feed_events((select v from tst.kv where k = 'token'))$$, 'besleme işlevi uygulamaya kapalı');
select tst.fails($$select public.clinic_calendar_source_save('https://evil.example.com/a.ics')$$, 'izinli olmayan takvim adresi reddedilir');
insert into tst.kv select 'src', public.clinic_calendar_source_save('webcal://p52-caldav.icloud.com/published/2/abc', 'iCloud')::text;
select tst.check((select url from public.clinic_calendar_sources) like 'https://p52-caldav.icloud.com/%', 'webcal https olur');
reset role;
set role service_role;
select tst.check(json_array_length(public.calendar_feed_events((select v from tst.kv where k = 'token'))) >= 3, 'besleme uzmanın seanslarını verir');
select tst.check(position('Nazlı' in public.calendar_feed_events((select v from tst.kv where k = 'token'))::text) = 0, 'beslemede çocuk adı yok');
select tst.check(json_array_length(public.calendar_feed_events('kısa')) = 0, 'geçersiz belirteç boş');
select tst.check(public.calendar_import_store((select v::uuid from tst.kv where k = 'src'),
  jsonb_build_array(jsonb_build_object('uid', 'e1', 'start', now() + interval '6 days', 'end', now() + interval '6 days 50 minutes', 'summary', 'Nazlı seans'),
                    jsonb_build_object('uid', 'e2', 'start', now() + interval '7 days', 'end', now() + interval '7 days 1 hour', 'summary', 'Diş hekimi')),
  now() - interval '14 days', now() + interval '60 days') = 2, 'dış etkinlikler yazıldı');
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.clinic_external_events') = 2, 'uzman kendi dış etkinliklerini görür');
insert into tst.kv select 'ext', public.clinic_external_event_mark((select id from public.clinic_external_events where uid = 'e1'),
  '00000000-0000-0000-0000-0000000011a1')::text;
select tst.check((select duration_min from public.clinic_sessions where id = (select v::uuid from tst.kv where k = 'ext')) = 50, 'dış etkinlik seansa çevrildi');
select public.clinic_external_event_mark((select id from public.clinic_external_events where uid = 'e2'), null, null, null, true);
select tst.check((select ignored from public.clinic_external_events where uid = 'e2'), 'yok sayıldı');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(tst.cnt('public.clinic_external_events') = 0, 'başkasının dış takvimi görünmez');
select tst.check(tst.cnt('public.clinic_calendar_feeds') = 0, 'başkasının belirteci görünmez');
reset role;
set role service_role;
select tst.check(public.calendar_import_store((select v::uuid from tst.kv where k = 'src'), '[]'::jsonb,
  now() - interval '14 days', now() + interval '60 days') = 0, 'boş eşitleme');
reset role;
select tst.check((select count(*) from public.clinic_external_events) = 1, 'seansa çevrilen dış etkinlik eşitlemede kalır');

-- ---------------------------------------------------------------------
-- Paylaşım bitince: gelecekteki seanslar iptal, aile görmez
-- ---------------------------------------------------------------------
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link('00000000-0000-0000-0000-0000000011a1');
select tst.check(json_array_length(public.family_sessions()) = 0, 'paylaşım bitince aile randevu görmez');
reset role;
select tst.check(not exists (select 1 from public.clinic_sessions where link_id = '00000000-0000-0000-0000-0000000011a1'
                             and status = 'planned' and starts_at > now()), 'gelecekteki seanslar iptal oldu');
select tst.check((select count(*) from public.clinic_session_records) = 1, 'uzmanın kaydı kalır');

-- anon hiçbir seans işlevini çağıramaz
set role anon;
select tst.fails($$select public.family_sessions()$$, 'anon aile işlevini çağıramaz');
select tst.fails($$select public.clinic_session_create('{}')$$, 'anon seans açamaz');
reset role;
