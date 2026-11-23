-- Moyo Mercek 23 Kasım güncellemeleri (proposed/20261123100000_mercek_updates.sql):
--   1 seans ücreti (yazma, kapsam, geçersiz değer; aile hiçbir yoldan görmez)
--   2 çoklu kayıt türü (log_type ↔ log_types iki yönlü; olay formu seçili her türün alanını ister; olayda türlerin kopyası)
--   3 raporu aileye gönder (bildirim, uzman listesi, aile arşivi ve sayfa, içerik biçimi, boyut, günlük sınır, ret yolları, RLS)
--   4 ebeveyn eğitimi bayrağı: bildirim motorunun eğitim kuralları bayrak kapalıyken göndermez
--   5 paylaşım biter / silinir: rapor ailede kalır; aile ya da çocuk silinince rapor da silinir
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
-- Hatanın ipucu (hint; yoksa iletisi); hata yoksa 'NO_ERROR'
create or replace function tst.err(sql text) returns text language plpgsql as $$
declare h text; m text;
begin
  begin
    execute sql;
  exception when others then
    get stacked diagnostics h = pg_exception_hint, m = message_text;
    return coalesce(nullif(h, ''), m);
  end;
  return 'NO_ERROR';
end $$;
create or replace function tst.expect(sql text, want text, msg text) returns void language plpgsql as $$
declare got text := tst.err(sql);
begin
  if got is distinct from want then raise exception 'TEST BAŞARISIZ: % (beklenen %, gelen %)', msg, want, got; end if;
  raise notice 'ok: % → %', msg, got;
end $$;
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.v(key text) returns text language sql stable as $$ select v from tst.kv where k = key $$;
create or replace function tst.id(key text) returns uuid language sql stable as $$ select v::uuid from tst.kv where k = key $$;
create or replace function tst.u(x text) returns uuid language sql immutable as $$ select ('00000000-0000-0000-0000-0000000000' || x)::uuid $$;
-- Örnek rapor içeriği (geçerli v1)
create or replace function tst.content() returns jsonb language sql immutable as $$
  select '{"v": 1, "child": {"name": "Mira"}, "period": {"start": "2026-10-26", "end": "2026-11-22"},
           "footer": "Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir.",
           "sections": [
             {"type": "text", "title": "Özet", "body": "Dört haftalık kayıtlar."},
             {"type": "kv", "title": "Göstergeler", "rows": [["Tamamlama", "%72"], ["Tam gün", "%40"]]},
             {"type": "table", "title": "Haftalık rutin kartı", "columns": ["Hafta", "Onay/plan", "Oran"],
              "rows": [["26.10 – 01.11", "10/14", "%71"], ["02.11 – 08.11", "11/14", "%79"]]},
             {"type": "list", "title": "Adımlar", "items": ["Sabah rutini", "Diş fırçalama"]},
             {"type": "text", "body": "Başlıksız bölüm."}]}'::jsonb
$$;
-- İçeriği değiştirip paylaşmayı dener (uzman d1, paylaşım L1)
create or replace function tst.share_sql(c jsonb) returns text language sql stable as $$
  select format('select public.clinic_report_share(%L, %L, %L, %L, %L::jsonb)', tst.id('L1'), 'Rapor', '2026-10-26', '2026-11-22', c::text)
$$;
grant usage on schema tst to anon, authenticated;
grant all on tst.kv to anon, authenticated;
grant execute on all functions in schema tst to anon, authenticated;

-- ---------------------------------------------------------------- veri
-- a1, a2 aynı ailenin ebeveynleri (Mira, Efe); b1 başka aile (Deniz); d1 uzman (Mavi), e1 başka klinik, d2 bildirim motoru uzmanı
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  (tst.u('a1'), false, '{"nickname":"Anne"}'),
  (tst.u('a2'), false, '{"nickname":"Baba"}'),
  (tst.u('b1'), false, '{"nickname":"Komşu"}'),
  (tst.u('d1'), false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  (tst.u('e1'), false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can"}'),
  (tst.u('d2'), false, '{"account":"clinician","clinic_name":"Mor","name":"Dr. Nur"}');
update public.profiles set name = 'Ayşe' where id = tst.u('a1');
update public.profiles set family_id = (select family_id from public.profiles where id = tst.u('a1')) where id = tst.u('a2');
update public.clinicians set title = 'Klinik Psikolog' where id = tst.u('d1');
insert into tst.kv values
  ('famA', (select family_id::text from public.profiles where id = tst.u('a1'))),
  ('famB', (select family_id::text from public.profiles where id = tst.u('b1'))),
  ('mira', '00000000-0000-0000-0000-00000000c001'), ('efe', '00000000-0000-0000-0000-00000000c002'),
  ('deniz', '00000000-0000-0000-0000-00000000c003'),
  ('L1', '00000000-0000-0000-0000-0000000011a1'), ('L2', '00000000-0000-0000-0000-0000000011a2'),
  ('L3', '00000000-0000-0000-0000-0000000011b1'), ('L4', '00000000-0000-0000-0000-0000000011d2');
insert into public.children (id, family_id, name, avatar) values
  (tst.id('mira'), tst.id('famA'), 'Mira', 'tavşan'), (tst.id('efe'), tst.id('famA'), 'Efe', 'kedi'),
  (tst.id('deniz'), tst.id('famB'), 'Deniz', 'kedi');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
select x.link, m.clinic_id, m.id, x.fam, x.child, x.by
  from public.clinicians m,
       (values (tst.id('L1'), tst.id('famA'), tst.id('mira'), tst.u('a1')), (tst.id('L2'), tst.id('famA'), tst.id('efe'), tst.u('a1')),
               (tst.id('L3'), tst.id('famB'), tst.id('deniz'), tst.u('b1'))) x(link, fam, child, by)
 where m.id = tst.u('d1');

-- ---------------------------------------------------------------- 0. yetki ve tablo
select tst.check((select relrowsecurity from pg_class where oid = 'public.clinic_shared_reports'::regclass), 'rapor tablosunda RLS açık');
select tst.check(not has_table_privilege('authenticated', 'public.clinic_shared_reports', 'select')
             and not has_table_privilege('authenticated', 'public.clinic_shared_reports', 'insert')
             and not has_table_privilege('authenticated', 'public.clinic_shared_reports', 'update')
             and not has_table_privilege('authenticated', 'public.clinic_shared_reports', 'delete')
             and not has_table_privilege('anon', 'public.clinic_shared_reports', 'select'), 'rapor tablosu istemciye kapalı (okuma ve yazma yalnız işlevlerle)');
select tst.check(has_function_privilege('authenticated', 'public.clinic_report_share(uuid, text, date, date, jsonb)', 'execute')
             and has_function_privilege('authenticated', 'public.clinic_reports_sent(uuid)', 'execute')
             and has_function_privilege('authenticated', 'public.family_reports(uuid)', 'execute')
             and has_function_privilege('authenticated', 'public.family_report(uuid)', 'execute'), 'dört rapor işlevi giriş yapana açık');
select tst.check(not has_function_privilege('anon', 'public.clinic_report_share(uuid, text, date, date, jsonb)', 'execute')
             and not has_function_privilege('anon', 'public.clinic_reports_sent(uuid)', 'execute')
             and not has_function_privilege('anon', 'public.family_reports(uuid)', 'execute')
             and not has_function_privilege('anon', 'public.family_report(uuid)', 'execute'), 'anon rapor işlevlerini çağıramaz');
select tst.check(not has_function_privilege('authenticated', 'public.report_content_check(jsonb)', 'execute')
             and not has_function_privilege('authenticated', 'public.report_content_fail(text)', 'execute')
             and not has_function_privilege('authenticated', 'public.report_str_ok(jsonb, integer)', 'execute')
             and not has_function_privilege('authenticated', 'public.report_strs_ok(jsonb, integer, integer)', 'execute')
             and not has_function_privilege('authenticated', 'public.report_keys_ok(jsonb, text[])', 'execute')
             and not has_function_privilege('authenticated', 'public.session_fee_of(jsonb)', 'execute')
             and not has_function_privilege('authenticated', 'public.behavior_log_types_norm(text[])', 'execute')
             and not has_function_privilege('authenticated', 'public.clinic_target_behaviors_log_types()', 'execute')
             and not has_function_privilege('authenticated', 'public.nudge_try(uuid, public.nudge_rules, text, jsonb, timestamptz)', 'execute'),
                 'iç yardımcılar istemciye kapalı');
select tst.check(not public.notification_push_exempt('report_shared'), 'report_shared olağan anlık bildirim sınırına tabi (gönderen uzman)');

-- ---------------------------------------------------------------- 1. seans ücreti
set role authenticated;
select tst.as_user(tst.u('d1'));
insert into tst.kv select 's1', (public.clinic_session_create(jsonb_build_object('link_id', tst.id('L1'), 'starts_at', now() + interval '3 days',
  'visible_to_family', true, 'fee', '450.50'))::jsonb -> 'ids' ->> 0);
select tst.check((select fee from public.clinic_sessions where id = tst.id('s1')) = 450.50, 'ücret yazılır (metin "450.50")');
insert into tst.kv select 'ser', public.clinic_session_create(jsonb_build_object('link_id', tst.id('L1'), 'starts_at', now() + interval '4 days',
  'repeat', 'weekly', 'count', 3, 'visible_to_family', true, 'fee', 300))::jsonb ->> 'ids';
insert into tst.kv select 'ser' || i, (tst.v('ser')::jsonb ->> i) from generate_series(0, 2) i;
select tst.check((select count(*) from public.clinic_sessions where id in (tst.id('ser0'), tst.id('ser1'), tst.id('ser2')) and fee = 300) = 3,
                 'tekrarlayan seansın her birine aynı ücret (sayı 300)');
insert into tst.kv select 'nofee', (public.clinic_session_create(jsonb_build_object('link_id', tst.id('L1'), 'starts_at', now() + interval '5 days'))::jsonb -> 'ids' ->> 0);
insert into tst.kv select 'emptyfee', (public.clinic_session_create(jsonb_build_object('link_id', tst.id('L1'), 'starts_at', now() + interval '5 days',
  'fee', ''))::jsonb -> 'ids' ->> 0);
insert into tst.kv select 'nullfee', (public.clinic_session_create('{"fee": null, "title": "Toplantı"}'::jsonb || jsonb_build_object('starts_at', now() + interval '6 days'))::jsonb -> 'ids' ->> 0);
select tst.check((select count(*) from public.clinic_sessions where id in (tst.id('nofee'), tst.id('emptyfee'), tst.id('nullfee')) and fee is null) = 3,
                 'ücret yok / boş / null → boş (danışansız blokta da)');
insert into tst.kv select 'maxfee', (public.clinic_session_create(jsonb_build_object('link_id', tst.id('L1'), 'starts_at', now() + interval '7 days',
  'fee', 1000000))::jsonb -> 'ids' ->> 0);
insert into tst.kv select 'zerofee', (public.clinic_session_create(jsonb_build_object('link_id', tst.id('L1'), 'starts_at', now() + interval '8 days',
  'fee', '0'))::jsonb -> 'ids' ->> 0);
select tst.check((select fee from public.clinic_sessions where id = tst.id('maxfee')) = 1000000
             and (select fee from public.clinic_sessions where id = tst.id('zerofee')) = 0, 'sınırlar: 0 ve 1.000.000');
select tst.expect(format('select public.clinic_session_create(%L::jsonb)', jsonb_build_object('link_id', tst.id('L1'), 'starts_at', now() + interval '3 days', 'fee', v)),
                  'fee_invalid', 'geçersiz ücret reddedilir: ' || v::text)
  from (values ('-1'::jsonb), ('"-5"'), ('1000000.01'), ('"abc"'), ('"450,50"'), ('450.555'), ('true'), ('"1 000"')) x(v);

-- düzeltme: yalnız bu / bu ve sonrakiler / anahtar yoksa değişmez / boş siler
select public.clinic_session_update(tst.id('ser0'), '{"fee": 500}', 'one');
select tst.check((select fee from public.clinic_sessions where id = tst.id('ser0')) = 500
             and (select fee from public.clinic_sessions where id = tst.id('ser1')) = 300, 'yalnız bu seansın ücreti değişir');
select public.clinic_session_update(tst.id('ser1'), '{"fee": "350"}', 'following');
select tst.check((select fee from public.clinic_sessions where id = tst.id('ser0')) = 500
             and (select fee from public.clinic_sessions where id = tst.id('ser1')) = 350
             and (select fee from public.clinic_sessions where id = tst.id('ser2')) = 350, 'bu ve sonraki planlı seanslar');
select public.clinic_session_update(tst.id('ser2'), '{"duration_min": 50}', 'one');
select tst.check((select fee from public.clinic_sessions where id = tst.id('ser2')) = 350
             and (select duration_min from public.clinic_sessions where id = tst.id('ser2')) = 50, 'ücret anahtarı yoksa ücret değişmez');
select public.clinic_session_update(tst.id('ser2'), '{"fee": ""}', 'one');
select tst.check((select fee from public.clinic_sessions where id = tst.id('ser2')) is null, 'boş ücret siler');
select tst.expect(format('select public.clinic_session_update(%L, %L::jsonb, %L)', tst.id('ser1'), '{"fee": "x"}', 'one'), 'fee_invalid', 'düzeltmede geçersiz ücret');
select tst.check((select fee from public.clinic_sessions where id = tst.id('ser1')) = 350, 'reddedilen düzeltme ücreti değiştirmez');

-- aile ücreti hiçbir yoldan görmez
select tst.as_user(tst.u('a1'));
select tst.check(json_array_length(public.family_sessions()) >= 4, 'aile görünür randevuları görür');
select tst.check(not exists (select 1 from json_array_elements(public.family_sessions()) e where e::jsonb ? 'fee')
             and not exists (select 1 from json_array_elements(public.family_sessions()) e, jsonb_each(e::jsonb) kv
                              where kv.value in ('450.5'::jsonb, '450.50'::jsonb, '"450.50"'::jsonb, '300'::jsonb, '350'::jsonb)),
                 'family_sessions ücret döndürmez (anahtar da değer de yok)');
select tst.check((select count(*) from public.clinic_sessions) = 0 and (select count(fee) from public.clinic_sessions) = 0,
                 'aile seans tablosundan satır (ücret) okuyamaz');
select tst.as_user(tst.u('e1'));
select tst.check((select count(*) from public.clinic_sessions) = 0, 'başka klinik seansları ve ücreti görmez');
reset role;
select tst.check(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                              where n.nspname = 'public' and (p.proname like 'family\_%' or p.proname in ('session_notify_family', 'calendar_feed_events'))
                                and p.prosrc ~ '\mfee\M'), 'aileye ve takvim beslemesine giden işlevlerin hiçbiri fee okumaz');
select tst.check(exists (select 1 from public.notifications where kind = 'session_scheduled')
             and not exists (select 1 from public.notifications where kind like 'session%' and (data ? 'fee' or body ~* '(TL|ücret)')),
                 'randevu bildiriminde ücret yok');

-- ---------------------------------------------------------------- 2. çoklu kayıt türü
set role authenticated;
select tst.as_user(tst.u('d1'));
-- eski uygulama yalnız log_type yazar
insert into public.clinic_target_behaviors (id, clinic_id, link_id, title, log_type)
  values ('00000000-0000-0000-0000-0000000080b1', public.my_clinic_id(), tst.id('L1'), 'Ağlama', 'abc');
-- yeni uygulama yalnız log_types yazar (sıra sabitlenir, tekrar düşer)
insert into public.clinic_target_behaviors (id, clinic_id, link_id, title, log_types) values
  ('00000000-0000-0000-0000-0000000080b2', public.my_clinic_id(), tst.id('L1'), 'Vurma', '{duration,frequency}'),
  ('00000000-0000-0000-0000-0000000080b3', public.my_clinic_id(), tst.id('L1'), 'Bağırma', '{abc,duration,abc}'),
  ('00000000-0000-0000-0000-0000000080b4', public.my_clinic_id(), tst.id('L1'), 'Yatma saati', '{duration,abc,frequency}');
select tst.check((select log_types from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b1') = '{abc}',
                 'eski uygulama: log_type → log_types {abc}');
insert into public.clinic_target_behaviors (id, clinic_id, link_id, title)
  values ('00000000-0000-0000-0000-0000000080b5', public.my_clinic_id(), tst.id('L1'), 'Varsayılan');
select tst.check((select (log_types, log_type) from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b5')
                   = ('{frequency}'::text[], 'frequency'::text), 'tür verilmezse varsayılan {frequency}');
select tst.check((select (log_types, log_type) from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b2')
                   = ('{frequency,duration}'::text[], 'frequency'::text), 'yeni uygulama: sabit sıra, log_type = ilk tür');
select tst.check((select (log_types, log_type) from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b3')
                   = ('{abc,duration}'::text[], 'abc'::text), 'tekrarlanan tür bir kez');
select tst.check((select log_types from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b4') = '{frequency,abc,duration}',
                 'üç tür birden');
do $$ begin
  insert into public.clinic_target_behaviors (clinic_id, link_id, title, log_types) values (public.my_clinic_id(), tst.id('L1'), 'Boş', '{}');
  raise exception 'TEST BAŞARISIZ: boş kayıt türü kabul edildi';
exception when check_violation then raise notice 'ok: kayıt türü en az bir'; end $$;
do $$ begin
  insert into public.clinic_target_behaviors (clinic_id, link_id, title, log_types) values (public.my_clinic_id(), tst.id('L1'), 'Yanlış', '{video}');
  raise exception 'TEST BAŞARISIZ: bilinmeyen kayıt türü kabul edildi';
exception when check_violation then raise notice 'ok: bilinmeyen kayıt türü reddedilir'; end $$;
do $$ begin
  insert into public.clinic_target_behaviors (clinic_id, link_id, title, log_types) values (public.my_clinic_id(), tst.id('L1'), 'Boşluklu', array['abc', null]);
  raise exception 'TEST BAŞARISIZ: boş öge kabul edildi';
exception when check_violation then raise notice 'ok: boş öge reddedilir'; end $$;
-- güncelleme: eski uygulama yalnız log_type değiştirir → tek tür; yeni uygulama log_types → log_type ilk tür
update public.clinic_target_behaviors set log_type = 'abc' where id = '00000000-0000-0000-0000-0000000080b2';
select tst.check((select (log_types, log_type) from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b2')
                   = ('{abc}'::text[], 'abc'::text), 'eski uygulama log_type değiştirince log_types = {log_type}');
update public.clinic_target_behaviors set log_types = '{duration,frequency}' where id = '00000000-0000-0000-0000-0000000080b2';
select tst.check((select (log_types, log_type) from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b2')
                   = ('{frequency,duration}'::text[], 'frequency'::text), 'yeni uygulama log_types değiştirince log_type = ilk tür');
update public.clinic_target_behaviors set title = 'Kardeşine vurma', log_type = 'frequency' where id = '00000000-0000-0000-0000-0000000080b2';
select tst.check((select log_types from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b2') = '{frequency,duration}',
                 'eski uygulama aynı log_type ile kaydedince türler korunur');
update public.clinic_target_behaviors set log_types = null where id = '00000000-0000-0000-0000-0000000080b3';
select tst.check((select log_types from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b3') = '{abc}',
                 'log_types boşaltılırsa log_type''tan dolar');

-- aile türleri görür
select tst.as_user(tst.u('a1'));
select tst.check((select b -> 'log_types' from jsonb_array_elements(public.family_target_behaviors()) l, jsonb_array_elements(l -> 'behaviors') b
                   where b ->> 'id' = '00000000-0000-0000-0000-0000000080b4') = '["frequency", "abc", "duration"]'
             and (select b ->> 'log_type' from jsonb_array_elements(public.family_target_behaviors()) l, jsonb_array_elements(l -> 'behaviors') b
                   where b ->> 'id' = '00000000-0000-0000-0000-0000000080b4') = 'frequency', 'family_target_behaviors log_types (ve log_type) döndürür');
select tst.check((select log_types from public.clinic_target_behaviors where id = '00000000-0000-0000-0000-0000000080b4') = '{frequency,abc,duration}',
                 'aile tablodan da türleri okur (RLS "hedef davranış: aile okur")');

-- olay: seçili her türün alanı zorunlu
select tst.expect(format('select public.family_incident_report(%L, %L, null, null, 10, %L, %L, %L, 3)', tst.id('L1'), '00000000-0000-0000-0000-0000000080b4',
                         'Önce', 'Sonra', ''), 'count_required', 'üç tür: sayı zorunlu');
select tst.expect(format('select public.family_incident_report(%L, %L, null, 2, 10, %L, %L, %L, 3)', tst.id('L1'), '00000000-0000-0000-0000-0000000080b4',
                         'Önce', '', ''), 'abc_required', 'üç tür: öncül ve sonuç zorunlu');
select tst.expect(format('select public.family_incident_report(%L, %L, null, 2, null, %L, %L, %L, 3)', tst.id('L1'), '00000000-0000-0000-0000-0000000080b4',
                         'Önce', 'Sonra', ''), 'duration_required', 'üç tür: süre zorunlu');
insert into tst.kv select 'i1', public.family_incident_report(tst.id('L1'), '00000000-0000-0000-0000-0000000080b4', now() - interval '1 hour',
  2, 15, 'Ekran kapandı', 'Sarıldık', 'Önce uyarı', 4);
select tst.check((select (count, duration_min, antecedent, consequence, log_types, log_type) from public.behavior_incidents where id = tst.id('i1'))
                   = (2, 15, 'Ekran kapandı'::text, 'Sarıldık'::text, '{frequency,abc,duration}'::text[], 'frequency'::text),
                 'üç türün alanları ve türlerin kopyası yazıldı');
-- {frequency, duration}: öncül / sonuç yazılmaz
insert into tst.kv select 'i2', public.family_incident_report(tst.id('L1'), '00000000-0000-0000-0000-0000000080b2', null, 3, 5, 'Önce', 'Sonra', '', 2);
select tst.check((select (count, duration_min, antecedent, consequence, log_types) from public.behavior_incidents where id = tst.id('i2'))
                   = (3, 5, ''::text, ''::text, '{frequency,duration}'::text[]), 'seçili olmayan türün alanı yazılmaz');
-- {abc}: sayı ve süre yazılmaz (eski tek tür davranışı)
insert into tst.kv select 'i3', public.family_incident_report(tst.id('L1'), '00000000-0000-0000-0000-0000000080b1', null, 4, 9, 'Önce', 'Sonra', '', 2);
select tst.check((select (count, duration_min, log_types, log_type) from public.behavior_incidents where id = tst.id('i3'))
                   = (null::int, null::int, '{abc}'::text[], 'abc'::text), 'tek tür (ABC) eskisi gibi');
-- diğer olay değişmedi
insert into tst.kv select 'i4', public.family_incident_report(tst.id('L1'), null, null, 1, 10, 'Önce', 'Sonra', '', 3, 'Kavga');
select tst.check((select (count, duration_min, antecedent, log_types, log_type) from public.behavior_incidents where id = tst.id('i4'))
                   = (1, 10, 'Önce'::text, null::text[], null::text), 'diğer olay: bütün alanlar, tür yok');
-- uzman türleri değiştirince eski olayın kopyası kalır; yeni olay yeni türe göre
select tst.as_user(tst.u('d1'));
update public.clinic_target_behaviors set log_types = '{duration}' where id = '00000000-0000-0000-0000-0000000080b4';
select tst.check((select log_types from public.behavior_incidents where id = tst.id('i1')) = '{frequency,abc,duration}', 'olaydaki türler bildirim anının kopyası');
select tst.check((select log_types from public.behavior_incidents where id = tst.id('i2')) = '{frequency,duration}', 'uzman olaydaki türleri okur');
select tst.as_user(tst.u('a1'));
select tst.expect(format('select public.family_incident_report(%L, %L, null, null, 20)', tst.id('L1'), '00000000-0000-0000-0000-0000000080b4'),
                  'NO_ERROR', 'tür değişince olay yeni türe göre (yalnız süre)');
reset role;
-- sunucunun doğrudan yazdığı eski biçimli olay (yalnız log_type) türlerle dolar
insert into public.behavior_incidents (id, link_id, family_id, child_id, behavior_id, log_type, count, reporter_id)
  values ('00000000-0000-0000-0000-0000000090a5', tst.id('L1'), tst.id('famA'), tst.id('mira'), '00000000-0000-0000-0000-0000000080b1', 'duration', null, tst.u('a1'));
select tst.check((select log_types from public.behavior_incidents where id = '00000000-0000-0000-0000-0000000090a5') = '{duration}',
                 'yalnız log_type yazılan olayda log_types dolar');

-- ---------------------------------------------------------------- 3. raporu aileye gönder
set role authenticated;
select tst.as_user(tst.u('d1'));
insert into tst.kv select 'r1', public.clinic_report_share(tst.id('L1'), '  Ev rutini gözlem raporu  ', '2026-10-26', '2026-11-22', tst.content());
reset role;
select tst.check((select (title, clinician_name, family_id, child_id, link_id, sent_by, period_start, period_end, content = tst.content(), seen_at is null)
                    from public.clinic_shared_reports where id = tst.id('r1'))
                   = ('Ev rutini gözlem raporu'::text, 'Dr. Ece, Klinik Psikolog'::text, tst.id('famA'), tst.id('mira'), tst.id('L1'), tst.u('d1'),
                      '2026-10-26'::date, '2026-11-22'::date, true, true),
                 'rapor yazıldı: başlık kırpıldı, uzman adı + unvan kopyası, aile, çocuk, dönem, içerik');
select tst.check((select count(*) from public.notifications where kind = 'report_shared') = 2
             and (select bool_and(app = 'parent' and title = 'Uzmanınızdan yeni rapor'
                                  and body = 'Uzmanınız bir rapor paylaştı. Moyo''da açabilirsiniz.'
                                  and data = jsonb_build_object('report_id', tst.id('r1'), 'link_id', tst.id('L1'))
                                  and child_id = tst.id('mira') and family_id = tst.id('famA'))
                    from public.notifications where kind = 'report_shared')
             and (select array_agg(user_id order by user_id) from public.notifications where kind = 'report_shared') = array[tst.u('a1'), tst.u('a2')],
                 'ailenin iki ebeveynine report_shared: sabit metin, data {report_id, link_id}, child_id');
select tst.check(not exists (select 1 from public.notifications where kind = 'report_shared' and (title || body) ~ '(Mira|Ece|rutin)'),
                 'bildirimde çocuk adı, uzman adı ve klinik ayrıntı yok');

set role authenticated;
select tst.as_user(tst.u('d1'));
select tst.check(jsonb_array_length(public.clinic_reports_sent(tst.id('L1'))) = 1
             and public.clinic_reports_sent(tst.id('L1')) -> 0 ->> 'seen_at' is null
             and (public.clinic_reports_sent(tst.id('L1')) -> 0 ->> 'mine')::boolean
             and not (public.clinic_reports_sent(tst.id('L1')) -> 0 ? 'content'), 'uzman gönderdiğini listeler (içeriksiz, henüz açılmadı)');
select tst.check(public.clinic_reports_sent(tst.id('L2')) = '[]', 'başka paylaşımın listesi boş');
select tst.fails($$select count(*) from public.clinic_shared_reports$$, 'uzman rapor tablosunu doğrudan okuyamaz');
select tst.fails($$insert into public.clinic_shared_reports (family_id, child_id, title, content)
                   values ((select v::uuid from tst.kv where k = 'famA'), (select v::uuid from tst.kv where k = 'mira'), 'x', '{}')$$,
                 'uzman rapor tablosuna doğrudan yazamaz');

select tst.as_user(tst.u('a1'));
select tst.check(jsonb_array_length(public.family_reports()) = 1
             and public.family_reports() -> 0 ->> 'child_name' = 'Mira'
             and public.family_reports() -> 0 ->> 'clinician_name' = 'Dr. Ece, Klinik Psikolog'
             and not (public.family_reports() -> 0 ? 'content'), 'aile arşivi: liste (içeriksiz)');
select tst.check(public.family_reports(tst.id('efe')) = '[]' and jsonb_array_length(public.family_reports(tst.id('mira'))) = 1, 'arşiv çocuğa göre süzülür');
select tst.check(public.family_report(tst.id('r1')) -> 'content' = tst.content()
             and public.family_report(tst.id('r1')) ->> 'seen_at' is not null
             and not (public.family_report(tst.id('r1')) ?| array['sent_by', 'family_id', 'clinic_id']), 'aile raporu içeriğiyle açar; açılış yazılır');
insert into tst.kv select 'seen1', public.family_report(tst.id('r1')) ->> 'seen_at';
select tst.fails($$select count(*) from public.clinic_shared_reports$$, 'ebeveyn rapor tablosunu doğrudan okuyamaz');
select tst.fails($$update public.clinic_shared_reports set seen_at = null$$, 'ebeveyn rapor tablosuna yazamaz');
select tst.as_user(tst.u('a2'));
select tst.check(public.family_report(tst.id('r1')) ->> 'seen_at' = tst.v('seen1'), 'öteki ebeveyn de açar; ilk açılış zamanı değişmez');
select tst.as_user(tst.u('d1'));
select tst.check(public.clinic_reports_sent(tst.id('L1')) -> 0 ->> 'seen_at' is not null, 'uzman açıldığını görür');

-- ret yolları
select tst.as_user(tst.u('e1'));
select tst.expect(format('select public.clinic_report_share(%L, %L, null, null, %L::jsonb)', tst.id('L1'), 'Rapor', tst.content()::text),
                  'link_not_visible', 'başka klinik bu paylaşıma gönderemez');
select tst.expect(format('select public.clinic_reports_sent(%L)', tst.id('L1')), 'link_not_visible', 'başka klinik listeyi göremez');
select tst.check(public.family_reports() = '[]', 'uzmanın ailesi yok: arşiv boş');
select tst.as_user(tst.u('d1'));
select tst.expect(format('select public.clinic_report_share(%L, %L, null, null, %L::jsonb)', gen_random_uuid(), 'Rapor', tst.content()::text),
                  'link_not_visible', 'rızası (paylaşımı) olmayan aileye gönderilemez');
select tst.expect(format('select public.clinic_report_share(null, %L, null, null, %L::jsonb)', 'Rapor', tst.content()::text),
                  'link_not_visible', 'paylaşımsız gönderilemez');
select tst.expect(format('select public.family_report(%L)', tst.id('r1')), 'report_not_found', 'uzman ailenin rapor sayfasını açamaz');
select tst.as_user(tst.u('b1'));
select tst.expect(format('select public.family_report(%L)', tst.id('r1')), 'report_not_found', 'başka aile raporu açamaz');
select tst.check(public.family_reports() = '[]', 'başka ailenin arşivi boş');
select tst.as_user(tst.u('a1'));
select tst.expect(format('select public.clinic_report_share(%L, %L, null, null, %L::jsonb)', tst.id('L1'), 'Rapor', tst.content()::text),
                  'no_access', 'ebeveyn rapor gönderemez');
select tst.expect(format('select public.clinic_reports_sent(%L)', tst.id('L1')), 'no_access', 'ebeveyn uzman listesini çağıramaz');
select tst.as_user(null);
select tst.expect(format('select public.family_report(%L)', tst.id('r1')), 'report_not_found', 'oturumsuz rapor açılmaz');
reset role;
set role anon;
select tst.fails(format('select public.family_report(%L)', tst.id('r1')), 'anon rapor açamaz');
select tst.fails($$select public.family_reports()$$, 'anon arşivi okuyamaz');
select tst.fails(format('select public.clinic_report_share(%L, %L, null, null, %L::jsonb)', tst.id('L1'), 'Rapor', tst.content()::text), 'anon gönderemez');
reset role;

-- başlık, dönem, içerik biçimi
set role authenticated;
select tst.as_user(tst.u('d1'));
select tst.expect(format('select public.clinic_report_share(%L, %L, null, null, %L::jsonb)', tst.id('L1'), '   ', tst.content()::text), 'title_invalid', 'boş başlık');
select tst.expect(format('select public.clinic_report_share(%L, %L, null, null, %L::jsonb)', tst.id('L1'), repeat('a', 121), tst.content()::text), 'title_invalid', '121 karakter başlık');
select tst.expect(format('select public.clinic_report_share(%L, %L, %L, %L, %L::jsonb)', tst.id('L1'), 'R', '2026-11-22', '2026-10-26', tst.content()::text),
                  'period_invalid', 'dönem başlangıcı bitişten sonra');
select tst.expect(format('select public.clinic_report_share(%L, %L, %L, null, %L::jsonb)', tst.id('L1'), 'R', '2026-11-22', tst.content()::text),
                  'period_invalid', 'dönemin yalnız başlangıcı');
select tst.expect(tst.share_sql(c), 'content_invalid', 'biçimsiz içerik: ' || why)
  from (values
    ('[]'::jsonb, 'nesne değil'),
    ('"rapor"', 'metin'),
    (tst.content() - 'v', 'v yok'),
    (jsonb_set(tst.content(), '{v}', '2'), 'v = 2'),
    (jsonb_set(tst.content(), '{v}', '"1"'), 'v metin'),
    (tst.content() || '{"html": "<b>x</b>"}', 'bilinmeyen üst anahtar'),
    (jsonb_set(tst.content(), '{sections}', '[]'), 'bölüm yok'),
    (jsonb_set(tst.content(), '{sections}', '{"type": "text"}'), 'sections nesne'),
    (jsonb_set(tst.content(), '{sections}', (select jsonb_agg('{"type": "text", "body": "x"}'::jsonb) from generate_series(1, 41))), '41 bölüm'),
    (jsonb_set(tst.content(), '{sections}', '["metin"]'), 'bölüm metin'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "image", "url": "x"}]'), 'bilinmeyen tür'),
    (jsonb_set(tst.content(), '{sections}', '[{"body": "x"}]'), 'türsüz bölüm'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "text", "body": "x", "html": "y"}]'), 'bölümde bilinmeyen anahtar'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "text", "body": "x", "rows": []}]'), 'metin bölümünde rows'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "text"}]'), 'metinsiz bölüm'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "text", "body": 5}]'), 'metin yerine sayı'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'text', 'body', repeat('x', 8001)))), '8001 karakter metin'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'text', 'title', repeat('x', 201), 'body', 'x'))), '201 karakter başlık'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "text", "title": 3, "body": "x"}]'), 'başlık sayı'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "kv", "rows": [["a", "b", "c"]]}]'), 'kv üç ögeli satır'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "kv", "rows": [["a"]]}]'), 'kv tek ögeli satır'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "kv", "rows": [["a", 1]]}]'), 'kv değer sayı'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "kv", "rows": {"a": "b"}}]'), 'kv rows nesne'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'kv', 'rows',
       (select jsonb_agg('["a", "b"]'::jsonb) from generate_series(1, 61))))), 'kv 61 satır'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'kv', 'rows', jsonb_build_array(jsonb_build_array('a', repeat('x', 301)))))), 'kv 301 karakter'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'table', 'columns',
       (select jsonb_agg('k'::text) from generate_series(1, 13)), 'rows', '[]'::jsonb))), 'tablo 13 sütun'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'table', 'columns', '["a"]'::jsonb, 'rows',
       (select jsonb_agg('["x"]'::jsonb) from generate_series(1, 201))))), 'tablo 201 satır'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'table', 'columns', '["a"]'::jsonb, 'rows',
       jsonb_build_array((select jsonb_agg('x'::text) from generate_series(1, 13)))))), 'tablo 13 hücreli satır'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "table", "columns": ["a"], "rows": [[{"b": 1}]]}]'), 'tablo hücresi nesne'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "table", "columns": ["a"], "rows": ["x"]}]'), 'tablo satırı dizi değil'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "table", "rows": [["x"]]}]'), 'tablo sütunsuz'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'list', 'items',
       (select jsonb_agg('x'::text) from generate_series(1, 61))))), 'liste 61 öge'),
    (jsonb_set(tst.content(), '{sections}', jsonb_build_array(jsonb_build_object('type', 'list', 'items', jsonb_build_array(repeat('x', 501))))), 'liste 501 karakter'),
    (jsonb_set(tst.content(), '{sections}', '[{"type": "list", "items": "x"}]'), 'liste dizi değil'),
    (jsonb_set(tst.content(), '{child}', '{"name": 5}'), 'çocuk adı sayı'),
    (jsonb_set(tst.content(), '{child}', '{"name": "Mira", "age": "9"}'), 'çocukta bilinmeyen anahtar'),
    (jsonb_set(tst.content(), '{child}', '"Mira"'), 'çocuk nesne değil'),
    (jsonb_set(tst.content(), '{child,name}', to_jsonb(repeat('x', 121))), 'çocuk adı 121'),
    (jsonb_set(tst.content(), '{period}', '{"start": "2026-13-40", "end": "2026-11-01"}'), 'geçersiz tarih'),
    (jsonb_set(tst.content(), '{period}', '{"start": "2026/10/01", "end": "2026/11/01"}'), 'tarih biçimi'),
    (jsonb_set(tst.content(), '{period}', '{"start": "2026-11-22", "end": "2026-10-26"}'), 'dönem ters'),
    (jsonb_set(tst.content(), '{period}', '{"start": "2026-10-26"}'), 'dönem bitişsiz'),
    (jsonb_set(tst.content(), '{period}', '{"start": "2026-10-26", "end": "2026-11-22", "tz": "x"}'), 'dönemde bilinmeyen anahtar'),
    (jsonb_set(tst.content(), '{footer}', to_jsonb(repeat('x', 501))), '501 karakter alt satır'),
    (jsonb_set(tst.content(), '{footer}', 'null'), 'alt satır boş değer')
  ) x(c, why);
-- boyut: 256 KB üstü ayrı anahtarla; altındaki büyük ama geçerli rapor geçer
select tst.expect(tst.share_sql(jsonb_build_object('v', 1, 'sections', jsonb_build_array(jsonb_build_object('type', 'table', 'columns', '["a"]'::jsonb,
                    'rows', (select jsonb_agg((select jsonb_agg(repeat('x', 120)) from generate_series(1, 12))) from generate_series(1, 200)))))),
                  'content_too_large', '256 KB üstü içerik');
select tst.expect(tst.share_sql(jsonb_build_object('v', 1, 'sections', jsonb_build_array(jsonb_build_object('type', 'table', 'title', 'Büyük',
                    'columns', (select jsonb_agg('Sütun'::text) from generate_series(1, 12)),
                    'rows', (select jsonb_agg((select jsonb_agg(repeat('y', 80)) from generate_series(1, 12))) from generate_series(1, 200)))))),
                  'NO_ERROR', 'büyük ama sınırdaki rapor (≈ 200 KB, 200 satır × 12 sütun) geçer');
select tst.check(jsonb_array_length(public.clinic_reports_sent(tst.id('L1'))) = 2, 'reddedilen denemeler yazılmadı (iki rapor)');

-- günlük sınır: paylaşım başına kayan 24 saatte 20
reset role;
insert into public.clinic_shared_reports (link_id, clinic_id, family_id, child_id, sent_by, title, content)
  select l.id, l.clinic_id, l.family_id, l.child_id, tst.u('d1'), 'Eski ' || g, tst.content()
    from public.clinic_links l, generate_series(1, 18) g where l.id = tst.id('L1');
set role authenticated;
select tst.as_user(tst.u('d1'));
select tst.expect(tst.share_sql(tst.content()), 'too_many_reports', '24 saatte 20 rapordan sonra 21. reddedilir');
insert into tst.kv select 'r2', public.clinic_report_share(tst.id('L2'), 'Efe raporu', null, null, tst.content());
select tst.check(tst.id('r2') is not null, 'sınır paylaşım başına: aynı ailenin öteki çocuğuna gönderilir');
reset role;
update public.clinic_shared_reports set created_at = now() - interval '25 hours' where id = (select id from public.clinic_shared_reports where title = 'Eski 1');
set role authenticated;
select tst.as_user(tst.u('d1'));
select tst.expect(tst.share_sql(tst.content()), 'NO_ERROR', '24 saati geçen rapor sayılmaz');
select tst.expect(tst.share_sql(tst.content()), 'too_many_reports', 'yeniden 20');
reset role;
-- anlık bildirim sınırı: aynı uzmandan aynı ebeveyne saatte en çok 6 report_shared telefona gider (satır her zaman yazılır)
select tst.check((select count(*) from public.notifications where kind = 'report_shared' and user_id = tst.u('a1')) = 4
             and (select count(*) from public.notifications where kind = 'report_shared' and user_id = tst.u('a1') and push) = 4,
                 'dört gönderim: a1''e dört bildirim, hepsi telefona (sınır 6 / saat)');

-- ---------------------------------------------------------------- 4. ebeveyn eğitimi bayrağı ve bildirim motoru
select tst.check((select bool_and(feature_flag = 'parent_training') from public.nudge_rules where trigger in ('training_none', 'training_draft'))
             and (select count(*) from public.nudge_rules where trigger in ('training_none', 'training_draft')) = 2
             and not exists (select 1 from public.nudge_rules where trigger not in ('training_none', 'training_draft') and feature_flag is not null),
                 'yalnız eğitim kuralları parent_training bayrağına bağlı');
select tst.check((select prosrc from pg_proc where oid = 'public.admin_nudge_rules()'::regprocedure) like '%feature_flag%', 'panel kural listesi bayrağı gösterir');
select tst.check(not exists (select 1 from public.feature_flags where key = 'parent_training') and not public.flag_on(tst.u('d2'), 'parent_training'),
                 'parent_training satırı yok = kapalı');
-- W = önümüzdeki çarşamba (Türkiye günü, yarından sonra) 12:00
insert into tst.kv select 'w', (d + ((3 - extract(isodow from d)::int + 7) % 7))::text from (select public.tr_today() + 1 as d) x;
create or replace function tst.t0() returns timestamptz language sql stable as $$
  select ((select v::date from tst.kv where k = 'w') + time '12:00') at time zone 'Europe/Istanbul' $$;
create or replace function tst.rule(k text) returns public.nudge_rules language sql security definer as $$
  select r from public.nudge_rules r where r.key = $1 $$;
select tst.check(not public.nudge_holdout(tst.u('d2')), 'd2 karşılaştırma grubunda değil');
update public.clinicians set created_at = tst.t0() - interval '100 days' where id = tst.u('d2');
update public.clinics set trial_ends_at = tst.t0() + interval '30 days' where created_by = tst.u('d2');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by, created_at)
  select tst.id('L4'), clinic_id, id, tst.id('famB'), tst.id('deniz'), tst.u('b1'), tst.t0() - interval '49 hours'
    from public.clinicians where id = tst.u('d2');
insert into public.feature_flags (key, enabled, rollout_pct) values ('nudges_server_clinic', true, 100);
insert into tst.kv select 'run_off', public.nudge_run(tst.t0())::text;
select tst.check((tst.v('run_off')::jsonb ->> 'ran')::boolean and (tst.v('run_off')::jsonb -> 'results' ->> 'flag_off')::int >= 1,
                 'motor çalıştı; eğitim kuralı bayrak kapalı (flag_off)');
select tst.check(not exists (select 1 from public.nudge_log where rule_key in ('clinic_training_none', 'clinic_training_draft'))
             and not exists (select 1 from public.notifications where kind = 'nudge' and data ->> 'nudge' in ('training_none', 'training_draft')),
                 'parent_training kapalıyken eğitim hatırlatması gitmez, kayıt da yazılmaz');
select tst.check(public.nudge_try(tst.u('d2'), tst.rule('clinic_training_none'), tst.v('L4'), '{}', tst.t0()) = 'flag_off',
                 'nudge_try: kuralın bayrağı kapalı → flag_off');
insert into public.feature_flags (key, enabled, rollout_pct) values ('parent_training', true, 100);
insert into tst.kv select 'run_on', public.nudge_run(tst.t0())::text;
select tst.check((select result from public.nudge_log where user_id = tst.u('d2') and rule_key = 'clinic_training_none' and ref = tst.v('L4')) = 'sent'
             and exists (select 1 from public.notifications where user_id = tst.u('d2') and kind = 'nudge' and data ->> 'nudge' = 'training_none'),
                 'bayrak açılınca aynı kural gönderilir');
insert into public.user_flags (user_id, key, enabled, reason) values (tst.u('d2'), 'parent_training', false, 'kişiye kapalı deneme');
select tst.check(public.nudge_try(tst.u('d2'), tst.rule('clinic_training_draft'), 'tr1', '{}', tst.t0() + interval '1 day') = 'flag_off',
                 'kişiye istisna (kapalı) genel bayrağı ezer');
delete from public.user_flags where user_id = tst.u('d2') and key = 'parent_training';
select tst.check(public.nudge_try(tst.u('d2'), tst.rule('clinic_training_draft'), 'tr1', '{}', tst.t0() + interval '1 day') = 'sent',
                 'istisna kalkınca gönderilir');
delete from public.feature_flags where key in ('nudges_server_clinic', 'parent_training');

-- ---------------------------------------------------------------- 5. paylaşım biter / silinir: rapor ailede kalır
-- L3: aile B'ye rapor; ebeveyn paylaşım bittikten sonra açar → uzman listesinde açılış görünmez
set role authenticated;
select tst.as_user(tst.u('d1'));
insert into tst.kv select 'r3', public.clinic_report_share(tst.id('L3'), 'Deniz raporu', '2026-11-01', '2026-11-22', tst.content());
reset role;
update public.clinic_links set status = 'revoked', revoked_at = now(), revoked_by = tst.u('b1') where id = tst.id('L3');
set role authenticated;
select tst.as_user(tst.u('d1'));
select tst.expect(format('select public.clinic_report_share(%L, %L, null, null, %L::jsonb)', tst.id('L3'), 'Rapor', tst.content()::text),
                  'link_not_visible', 'paylaşım bitince rapor gönderilemez');
select tst.as_user(tst.u('b1'));
select tst.check(jsonb_array_length(public.family_reports()) = 1 and public.family_report(tst.id('r3')) ->> 'title' = 'Deniz raporu',
                 'paylaşım bitince aile raporu arşivde görür ve açar');
select tst.as_user(tst.u('d1'));
select tst.check(jsonb_array_length(public.clinic_reports_sent(tst.id('L3'))) = 1
             and public.clinic_reports_sent(tst.id('L3')) -> 0 ->> 'seen_at' is null, 'paylaşım bittikten sonraki açılış uzmana gösterilmez');
reset role;
select tst.check((select seen_at is not null from public.clinic_shared_reports where id = tst.id('r3')), '(açılış ailede yazılı)');
-- L1 biter: bitmeden önceki açılış uzmana görünür kalır
update public.clinic_links set status = 'revoked', revoked_at = now(), revoked_by = tst.u('a1') where id = tst.id('L1');
set role authenticated;
select tst.as_user(tst.u('d1'));
select tst.check((select count(*) from jsonb_array_elements(public.clinic_reports_sent(tst.id('L1'))) e
                   where e ->> 'id' = tst.v('r1') and e ->> 'seen_at' is not null) = 1, 'bitmeden önce açılan rapor uzman listesinde açılmış görünür');
select tst.as_user(tst.u('a1'));
select tst.check(jsonb_array_length(public.family_reports(tst.id('mira'))) = 21, 'aile Mira''nın bütün raporlarını görür (paylaşım bitti)');
reset role;
-- paylaşım kaydı silinir (uzman hesabı / klinik silinmesi yolu): rapor kalır, bağ boşalır
delete from public.clinic_links where id = tst.id('L2');
select tst.check((select link_id is null and family_id = tst.id('famA') from public.clinic_shared_reports where id = tst.id('r2')),
                 'paylaşım kaydı silinince rapor kalır (link_id boş)');
set role authenticated;
select tst.as_user(tst.u('a1'));
select tst.check(public.family_report(tst.id('r2')) ->> 'title' = 'Efe raporu' and public.family_report(tst.id('r2')) ->> 'link_id' is null,
                 'aile silinen paylaşımın raporunu açar');
select tst.as_user(tst.u('d1'));
select tst.expect(format('select public.clinic_reports_sent(%L)', tst.id('L2')), 'link_not_visible', 'silinen paylaşımın listesi uzmana kapalı');
reset role;
-- klinik silinince de rapor ailede (clinic_id ve link_id boş)
delete from public.clinics where id = (select clinic_id from public.clinicians where id = tst.u('d1'));
select tst.check((select count(*) from public.clinic_shared_reports where family_id = tst.id('famA')) = 22
             and not exists (select 1 from public.clinic_shared_reports where clinic_id is not null and family_id = tst.id('famA')),
                 'klinik silinince raporlar ailede kalır');
-- çocuk silinince o çocuğun raporları, aile silinince ailenin raporları silinir
delete from public.children where id = tst.id('efe');
select tst.check(not exists (select 1 from public.clinic_shared_reports where child_id = tst.id('efe'))
             and (select count(*) from public.clinic_shared_reports where family_id = tst.id('famA')) = 21, 'çocuk silinince raporları silinir');
delete from public.families where id = tst.id('famB');
select tst.check(not exists (select 1 from public.clinic_shared_reports where family_id = tst.id('famB')), 'aile silinince raporları silinir');
