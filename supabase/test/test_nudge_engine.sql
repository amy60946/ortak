-- Sunucu bildirim motoru (migrations/20261120230000_nudge_engine.sql): bayrak kapalıyken hiçbir şey; kurallar; sessiz saat
-- (Moyo 21–08, Mercek hafta içi 08:30–19:00); günde 1, 7 günde 2, o gün açıldıysa yok, 3 yanıtsız → 14 gün ara;
-- %10 karşılaştırma grubu (Mercek'in cihaz içi özetiyle aynı); tercih (tips); hesap bilgisi sınır dışı; açılma, dönüşüm,
-- panel istatistiği, kural aç / kapat, metinde ad / yer tutucu yok, yetki.
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
create table tst.res (k text primary key, j jsonb);
create or replace function tst.r(key text) returns jsonb language sql as $$ select j from tst.res where k = key $$;
create or replace function tst.u(x text) returns uuid language sql immutable as $$ select ('00000000-0000-0000-0000-0000000000' || x)::uuid $$;
create or replace function tst.fam(x text) returns uuid language sql security definer as $$ select family_id from public.profiles where id = tst.u(x) $$;
-- W = önümüzdeki çarşamba (Türkiye günü, yarından sonra); tst.at(gün farkı, 'SS:DD') Türkiye saatiyle an
insert into tst.kv select 'w', (d + ((3 - extract(isodow from d)::int + 7) % 7))::text from (select public.tr_today() + 1 as d) x;
create or replace function tst.at(off integer, hm text) returns timestamptz language sql stable as $$
  select ((select v::date from tst.kv where k = 'w') + off + hm::time) at time zone 'Europe/Istanbul' $$;
create or replace function tst.t0() returns timestamptz language sql stable as $$ select tst.at(0, '12:00') $$;
create or replace function tst.rule(k text) returns public.nudge_rules language sql security definer as $$
  select r from public.nudge_rules r where r.key = $1 $$;
create or replace function tst.log(u text, rule text, rf text default '') returns public.nudge_log language sql security definer as $$
  select * from public.nudge_log l where l.user_id = tst.u(u) and l.rule_key = rule and l.ref = rf order by l.id desc limit 1 $$;
create or replace function tst.nudges(u text) returns bigint language sql security definer as $$
  select count(*) from public.notifications where user_id = tst.u(u) and kind = 'nudge' $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv, tst.res to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- Hesaplar (kimliğin FNV-1a özeti % 10: a4, d1 = 0 → karşılaştırma grubu; ötekiler değil)
-- a1 P1 çocuk yok · a3 P2 yeni kayıt · a4 P3 holdout · a5 P4 tercih kapalı · a6 P5 bayat · a7 P6 bugün açtı · a8 sınır birimi
-- a9 onay bekliyor + gün bildirimi gitti · b2 onay bekliyor · b3 / b8 / b9 ara kuralı · b4 7 gündür yok · b5 deneme bitiyor
-- b6 uzmana bağlı aile · b7 bugün başka bildirim aldı · d1 holdout uzman · d2 ilk davet yok · d3 davet doluyor
-- d4 eğitim yok · d5 taslak eğitim · d6 Mercek sınır birimi · d7 Mercek deneme · f1 owner · f2 destek · f3 izleyici
insert into auth.users (id, is_anonymous, raw_user_meta_data)
select tst.u(x), false, jsonb_build_object('nickname', 'Ebeveyn ' || x)
  from unnest(array['a1', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8', 'b9', 'f1', 'f2', 'f3']) x;
insert into auth.users (id, is_anonymous, raw_user_meta_data)
select tst.u(x), false, jsonb_build_object('account', 'clinician', 'clinic_name', 'Klinik ' || x, 'name', 'Dr. ' || x)
  from unnest(array['d1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd7']) x;
insert into public.admin_users (user_id, role) values (tst.u('f1'), 'owner'), (tst.u('f2'), 'support'), (tst.u('f3'), 'viewer');

-- ---------------------------------------------------------------- özet ve karşılaştırma grubu (Mercek nudgeCore.ts ile aynı)
select tst.check(public.nudge_hash(tst.u('d1')) = 3049836370 and public.nudge_hash(tst.u('a1')) = 3116108203
             and public.nudge_hash(tst.u('b1')) = 700675520, 'FNV-1a özeti JavaScript inHoldout ile aynı (node ile hesaplanan değerler)');
select tst.check(public.nudge_holdout(tst.u('a4')) and public.nudge_holdout(tst.u('d1')) and not public.nudge_holdout(tst.u('a1'))
             and not public.nudge_holdout(tst.u('d2')), 'karşılaştırma grubu: özet % 10 = 0');
select tst.check(public.nudge_clinic_trial_day('2026-11-24 15:00+03') = '2026-11-20'
             and public.nudge_clinic_trial_day('2026-11-25 15:00+03') = '2026-11-20'
             and public.nudge_clinic_trial_day('2026-11-26 15:00+03') = '2026-11-23', 'Mercek deneme günü: bitiş −3, hafta sonuysa önceki cuma');

-- ---------------------------------------------------------------- metinler
select tst.check((select count(*) from public.nudge_rules) = 14
             and (select count(*) from public.nudge_rules where product = 'parent') = 8, '14 kural (Moyo 8, Moyo Mercek 6)');
select tst.check(not exists (select 1 from public.nudge_rules
                              where title ~ '[{}<>$%]' or body ~ '[{}<>$%]' or body ~* '(indirim|kampanya|ücretsiz ay|fırsat|TL\M)'),
                 'kural metinlerinde yer tutucu, ad alanı, indirim / kampanya yok');
select tst.check(not exists (select 1 from public.nudge_rules where (product = 'parent' and title <> 'Moyo') or (product = 'clinic' and title <> 'Moyo Mercek')),
                 'başlık ürün adı');
select tst.check(not exists (select 1 from public.nudge_rules where body ~* 'görev'), 'aile ve uzman metninde "rutin" / "adım" (görev yok)');

-- ---------------------------------------------------------------- veri (bütün zamanlar W'ye göre)
update public.families set created_at = tst.at(-100, '12:00'), trial_started_at = null;
update public.clinicians set created_at = tst.at(-100, '12:00');
update public.clinics set trial_ends_at = tst.at(30, '12:00');
-- adım kuralları
update public.families set created_at = tst.at(0, '12:00') - interval '25 hours' where id in (tst.fam('a1'), tst.fam('a4'), tst.fam('a5'), tst.fam('a7'));
update public.families set created_at = tst.at(0, '12:00') - interval '10 hours' where id = tst.fam('a3');
update public.families set created_at = tst.at(-20, '12:00') where id = tst.fam('a6');
insert into public.user_activity (user_id, app, first_seen_at, last_seen_at, last_active_date)
  values (tst.u('a7'), 'parent', tst.at(0, '11:00') - interval '25 hours', tst.at(0, '11:00'), current_date);
update public.clinicians set created_at = tst.t0() - interval '25 hours' where id in (tst.u('d1'), tst.u('d2'));
-- onay bekleyen "Yaptım": a9'a gün bildirimi telefona gitti (atlanır), b2'ye gitmedi
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c0a9', tst.fam('a9'), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c0b2', tst.fam('b2'), 'Efe', 'kedi'),
  ('00000000-0000-0000-0000-00000000c0b6', tst.fam('b6'), 'Deniz', 'kedi');
insert into public.tasks (id, family_id, title, start_date, created_at) values
  ('00000000-0000-0000-0000-0000000007a9', tst.fam('a9'), 'Dişlerini fırçala', current_date, tst.at(-100, '12:00')),
  ('00000000-0000-0000-0000-0000000007b2', tst.fam('b2'), 'Dişlerini fırçala', current_date, tst.at(-100, '12:00')),
  ('00000000-0000-0000-0000-0000000007b4', tst.fam('b4'), 'Kitap oku', current_date, tst.at(-100, '12:00'));
insert into public.completions (family_id, task_id, child_id, date, status, child_done_at, created_at) values
  (tst.fam('a9'), '00000000-0000-0000-0000-0000000007a9', '00000000-0000-0000-0000-00000000c0a9', current_date, 'pending',
   tst.t0() - interval '25 hours', tst.t0() - interval '25 hours'),
  (tst.fam('b2'), '00000000-0000-0000-0000-0000000007b2', '00000000-0000-0000-0000-00000000c0b2', current_date, 'pending',
   tst.t0() - interval '25 hours', tst.t0() - interval '25 hours');
insert into public.notifications (user_id, app, kind, title, body, data, family_id, created_at)
  values (tst.u('a9'), 'parent', 'day_complete', 'Gün tamam', '', '{}', tst.fam('a9'), tst.t0() - interval '20 hours');
-- b4 sekiz gündür açmadı; b5'in denemesi 3 gün sonra bitiyor
insert into public.user_activity (user_id, app, first_seen_at, last_seen_at, last_active_date)
  values (tst.u('b4'), 'parent', tst.at(-30, '12:00'), tst.at(-8, '12:00'), current_date - 8);
update public.families set trial_started_at = tst.at(3, '15:00') - interval '14 days' where id = tst.fam('b5');
-- Mercek: d3'ün davetinin süresi 20 saatte doluyor; d4'e aile 49 saat önce bağlandı; d5'in eğitimi 73 saattir taslak; d7 deneme
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, created_at, expires_at)
  select 'NDG003', clinic_id, id, 'family', tst.t0() - interval '52 hours', tst.t0() + interval '20 hours' from public.clinicians where id = tst.u('d3');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by, created_at)
  select '00000000-0000-0000-0000-0000000011d4', clinic_id, id, tst.fam('b6'), '00000000-0000-0000-0000-00000000c0b6', tst.u('b6'),
         tst.t0() - interval '49 hours' from public.clinicians where id = tst.u('d4');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by, created_at)
  select '00000000-0000-0000-0000-0000000011d5', clinic_id, id, tst.fam('b6'), '00000000-0000-0000-0000-00000000c0b6', tst.u('b6'),
         tst.at(-10, '12:00') from public.clinicians where id = tst.u('d5');
insert into public.parent_trainings (id, clinic_id, link_id, title, status, created_by, created_at)
  select '00000000-0000-0000-0000-0000000070d5', clinic_id, '00000000-0000-0000-0000-0000000011d5', 'Taslak', 'draft', id,
         tst.t0() - interval '73 hours' from public.clinicians where id = tst.u('d5');
update public.clinics set trial_ends_at = tst.at(3, '15:00') where created_by = tst.u('d7');
-- a5 ipuçlarını kapatır (RPC yeni anahtarı kabul eder)
set role authenticated;
select tst.as_user(tst.u('a5'));
select tst.check(public.parent_notification_prefs_set('tips', false)::jsonb = '{"step_done": false, "day_complete": true, "tips": false}',
                 'Moyo tercihi: tips anahtarı (varsayılan açık)');
select tst.as_user(tst.u('a1'));
select tst.check(public.parent_notification_prefs()::jsonb ->> 'tips' = 'true', 'tips varsayılan açık');
select tst.fails($$select public.clinician_notification_prefs()$$, 'ebeveyn uzman tercihini okuyamaz');
select tst.as_user(tst.u('d6'));
select tst.check(public.clinician_notification_prefs()::jsonb = '{"tips": true}', 'Mercek tercihi varsayılan açık');
select tst.fails($$select public.clinician_notification_prefs_set('step_done', false)$$, 'Mercek: bilinmeyen anahtar');
select tst.fails($$select public.parent_notification_prefs()$$, 'uzman ebeveyn tercihini okuyamaz');
reset role;
select tst.as_user(null);

-- ---------------------------------------------------------------- yetki ve tablolar
select tst.check((select bool_and(relrowsecurity) from pg_class where oid in ('public.nudge_rules'::regclass, 'public.nudge_log'::regclass,
                   'public.nudge_pauses'::regclass, 'public.clinician_notification_prefs'::regclass)), 'yeni tablolarda RLS açık');
select tst.check(not has_function_privilege('authenticated', 'public.nudge_run(timestamptz)', 'execute')
             and not has_function_privilege('anon', 'public.nudge_run(timestamptz)', 'execute')
             and has_function_privilege('service_role', 'public.nudge_run(timestamptz)', 'execute')
             and not has_function_privilege('authenticated', 'public.nudge_try(uuid, public.nudge_rules, text, jsonb, timestamptz)', 'execute')
             and not has_function_privilege('authenticated', 'public.nudge_candidates(timestamptz, boolean, boolean)', 'execute')
             and not has_function_privilege('anon', 'public.admin_nudge_stats(text, date, date)', 'execute')
             and not has_function_privilege('anon', 'public.clinician_notification_prefs_set(text, boolean)', 'execute'),
                 'nudge_run yalnız servis / zamanlayıcı; iç işlevler istemciye kapalı');
set role authenticated;
select tst.as_user(tst.u('a1'));
select tst.fails($$select public.nudge_run()$$, 'giriş yapmış kullanıcı motoru çalıştıramaz');
select tst.fails($$select count(*) from public.nudge_log$$, 'kişi kendi gönderim kaydını da okuyamaz');
select tst.fails($$select count(*) from public.nudge_rules$$, 'kurallar istemciye kapalı');
select tst.fails($$select count(*) from public.nudge_pauses$$, 'ara tablosu istemciye kapalı');
select tst.fails($$select public.admin_nudge_stats('parent', current_date, current_date + 30)$$, 'admin olmayan istatistiği göremez');
reset role;
set role anon;
select tst.fails($$select public.nudge_run()$$, 'anon motoru çalıştıramaz');
reset role;

-- ---------------------------------------------------------------- bayrak kapalıyken hiçbir şey
insert into tst.res values ('off', public.nudge_run(tst.t0()));
select tst.check(tst.r('off') = '{"ran": false, "reason": "flag_off"}' and (select count(*) from public.nudge_log) = 0
             and (select count(*) from public.notifications where kind = 'nudge') = 0, 'bayrak yokken motor hiçbir şey yazmaz');
select tst.check(public.nudge_try(tst.u('a1'), tst.rule('parent_child_none'), '', '{}', tst.t0()) = 'flag_off', 'kişi düzeyinde de kapalı');

-- ---------------------------------------------------------------- bayrak açık: tek çalışma
insert into public.feature_flags (key, enabled, rollout_pct) values ('nudges_server', true, 100);
insert into tst.res values ('run1', public.nudge_run(tst.t0()));
select tst.check(tst.r('run1') -> 'results' = '{"sent": 9, "holdout": 2, "skipped_pref": 1, "skipped_limit": 1}',
                 'çalışma: 9 gönderim, 2 karşılaştırma, 1 tercih, 1 sınır');
select tst.check((tst.log('a1', 'parent_child_none')).result = 'sent' and tst.nudges('a1') = 1, 'P1: kayıttan 24 saat sonra çocuk yok → gönderildi');
select tst.check((select count(*) from public.nudge_log where user_id = tst.u('a3')) = 0, 'P2: 24 saat dolmadı');
select tst.check((tst.log('a4', 'parent_child_none')).result = 'holdout' and (tst.log('a4', 'parent_child_none')).notification_id is null
             and tst.nudges('a4') = 0, 'P3 karşılaştırma grubunda: yalnız kayıt, bildirim yok');
select tst.check((tst.log('a5', 'parent_child_none')).result = 'skipped_pref' and tst.nudges('a5') = 0, 'P4: ipuçları kapalı');
select tst.check((select count(*) from public.nudge_log where user_id = tst.u('a6')) = 0, 'P5: 14 günden eski durum (bayat) atlanır');
select tst.check((tst.log('a7', 'parent_child_none')).result = 'skipped_limit' and (tst.log('a7', 'parent_child_none')).detail = 'opened_today',
                 'P6: bugün uygulamayı açtı');
select tst.check((select count(*) from public.nudge_log where user_id = tst.u('a9')) = 0, 'onay bekliyor ama gün bildirimi telefona gitti: atlandı');
select tst.check((tst.log('b2', 'parent_review_waiting', (select id::text from public.completions where family_id = tst.fam('b2')))).result = 'sent',
                 'onay bekleyen "Yaptım" 24 saat: gönderildi (ref = en eski bekleyen)');
select tst.check((tst.log('b4', 'parent_inactive_7d', to_char(tst.at(-8, '12:00') at time zone 'Europe/Istanbul', 'YYYY-MM-DD'))).result = 'sent',
                 '7 gündür açmayan aile');
select tst.check((tst.log('b5', 'parent_trial_ending', ((select v from tst.kv where k = 'w')::date + 3)::text)).result = 'sent',
                 'deneme bitişinden 3 gün önce (hesap bilgisi)');
select tst.check((tst.log('d1', 'clinic_invite_none_1')).result = 'holdout' and (tst.log('d2', 'clinic_invite_none_1')).result = 'sent'
             and (select count(*) from public.nudge_log where rule_key = 'clinic_invite_none_2') = 0, 'Mercek ilk davet: d2 gönderildi, d1 karşılaştırma; 5. gün henüz değil');
select tst.check((tst.log('d3', 'clinic_invite_expiring', 'NDG003')).result = 'sent'
             and (select data ->> 'code' from public.notifications where user_id = tst.u('d3') and kind = 'nudge') = 'NDG003'
             and (select data ? 'clinic_id' from public.notifications where user_id = tst.u('d3') and kind = 'nudge'),
                 'süresi dolan davet: data.code + çalışma alanı (clinic_id)');
select tst.check((tst.log('d4', 'clinic_training_none', '00000000-0000-0000-0000-0000000011d4')).result = 'sent'
             and (select data ->> 'nudge' from public.notifications where user_id = tst.u('d4') and kind = 'nudge') = 'training_none',
                 'aile 48 saat önce bağlandı, eğitim yok (data.nudge Mercek cihaz türüyle aynı)');
select tst.check((tst.log('d5', 'clinic_training_draft', '00000000-0000-0000-0000-0000000070d5')).result = 'sent', 'eğitim 72 saattir taslakta');
select tst.check((tst.log('d7', 'clinic_trial_ending', ((select v from tst.kv where k = 'w')::date + 3)::text)).result = 'sent', 'Mercek deneme bitişi');
select tst.check((select bool_and(n.title = r.title and n.body = r.body and n.app = r.product
                                   and n.data ->> 'nudge' = r.route and n.data ->> 'rule' = r.key)
                    from public.notifications n join public.nudge_rules r on r.key = n.data ->> 'rule' where n.kind = 'nudge'),
                 'gönderilen metin kuralın sabit metni (kişiye göre doldurulmaz)');
select tst.check(not exists (select 1 from public.notifications where kind = 'nudge'
                              and (title || body || data::text) ~ '(Nazlı|Efe|Deniz|Ebeveyn [ab][0-9]|Dr\. d[0-9]|Klinik d[0-9])'), 'bildirimde çocuk, ebeveyn, uzman adı yok');

insert into tst.res values ('run2', public.nudge_run(tst.t0()));
select tst.check(tst.r('run2') -> 'results' = '{"done": 11, "skipped_pref": 1, "skipped_limit": 1}'
             and (select count(*) from public.notifications where kind = 'nudge') = 9
             and (select count(*) from public.nudge_log) = 13, 'yeniden çalışma: tekrar gönderim yok, atlama kaydı günde bir');

-- ---------------------------------------------------------------- sessiz saat ve sınırlar (Moyo)
select tst.check(public.nudge_try(tst.u('a8'), tst.rule('parent_review_waiting'), 'q1', '{}', tst.at(0, '21:00')) = 'skipped_quiet'
             and public.nudge_try(tst.u('a8'), tst.rule('parent_review_waiting'), 'q1', '{}', tst.at(1, '07:59')) = 'skipped_quiet',
                 'Moyo 21:00–08:00 sessiz');
select tst.check(public.nudge_try(tst.u('a8'), tst.rule('parent_review_waiting'), 'q1', '{}', tst.at(1, '08:00')) = 'sent', '08:00 gönderilir');
select tst.check(public.nudge_try(tst.u('a8'), tst.rule('parent_review_waiting'), 'q2', '{}', tst.at(1, '15:00')) = 'skipped_limit'
             and (tst.log('a8', 'parent_review_waiting', 'q2')).detail = 'daily', 'günde en çok 1');
select tst.check(public.nudge_try(tst.u('a8'), tst.rule('parent_review_waiting'), 'q2', '{}', tst.at(2, '10:00')) = 'sent', 'ertesi gün ikinci');
select tst.check(public.nudge_try(tst.u('a8'), tst.rule('parent_review_waiting'), 'q3', '{}', tst.at(4, '10:00')) = 'skipped_limit'
             and (tst.log('a8', 'parent_review_waiting', 'q3')).detail = 'weekly', 'kayan 7 günde en çok 2');
select tst.check(public.nudge_try(tst.u('a8'), tst.rule('parent_review_waiting'), 'q3', '{}', tst.at(8, '09:00')) = 'sent', '7 gün dolunca yeniden');
insert into public.notifications (user_id, app, kind, title, body, data, family_id, created_at)
  values (tst.u('b7'), 'parent', 'day_complete', 'Gün tamam', '', '{}', tst.fam('b7'), tst.at(0, '09:00'));
select tst.check(public.nudge_try(tst.u('b7'), tst.rule('parent_review_waiting'), 'o1', '{}', tst.at(0, '12:00')) = 'skipped_limit'
             and (tst.log('b7', 'parent_review_waiting', 'o1')).detail = 'daily', 'Moyo: o gün telefona başka bildirim gittiyse ipucu yok');
-- hesap bilgisi: karşılaştırma grubu, günlük sınır ve "bugün açtı" dışında; en erken 10:00
select tst.check(public.nudge_try(tst.u('a4'), tst.rule('parent_trial_ending'), 't1', '{}', tst.at(0, '09:30')) = 'wait'
             and public.nudge_try(tst.u('a4'), tst.rule('parent_trial_ending'), 't1', '{}', tst.at(0, '10:30')) = 'sent',
                 'deneme hatırlatması karşılaştırma grubuna da gider, 10:00''dan önce değil');
select tst.check(public.nudge_try(tst.u('a7'), tst.rule('parent_trial_ending'), 't1', '{}', tst.at(0, '12:00')) = 'sent',
                 'deneme hatırlatması uygulama açılan günde de gider');

-- ---------------------------------------------------------------- Moyo Mercek: hafta içi 08:30–19:00, tercih
select tst.check(public.nudge_try(tst.u('d6'), tst.rule('clinic_training_draft'), 'm1', '{}', tst.at(3, '12:00')) = 'skipped_quiet'
             and public.nudge_try(tst.u('d6'), tst.rule('clinic_training_draft'), 'm1', '{}', tst.at(0, '08:29')) = 'skipped_quiet'
             and public.nudge_try(tst.u('d6'), tst.rule('clinic_training_draft'), 'm1', '{}', tst.at(0, '19:01')) = 'skipped_quiet',
                 'Mercek: hafta sonu (cumartesi), 08:30 öncesi ve 19:00 sonrası sessiz');
select tst.check(public.nudge_try(tst.u('d6'), tst.rule('clinic_training_draft'), 'm1', '{}', tst.at(0, '08:30')) = 'sent', 'Mercek 08:30 gönderilir');
set role authenticated;
select tst.as_user(tst.u('d6'));
select tst.check(public.clinician_notification_prefs_set('tips', false)::jsonb = '{"tips": false}', 'uzman ipuçlarını kapatır');
select tst.check((select count(*) from public.clinician_notification_prefs) = 1, 'uzman kendi tercih satırını görür');
select tst.as_user(tst.u('d5'));
select tst.check((select count(*) from public.clinician_notification_prefs) = 0, 'başka uzmanın tercihi görünmez');
reset role;
select tst.as_user(null);
select tst.check(public.nudge_try(tst.u('d6'), tst.rule('clinic_training_draft'), 'm2', '{}', tst.at(1, '10:00')) = 'skipped_pref', 'Mercek tercihi kapalı');

-- ---------------------------------------------------------------- üç yanıtsız ipucu → 14 gün ara
insert into public.nudge_log (user_id, product, rule_key, ref, result, day, at, opened_at, converted_at)
select tst.u(u), 'parent', 'parent_review_waiting', 'p' || i, 'sent', (tst.at(o, '10:00') at time zone 'Europe/Istanbul')::date, tst.at(o, '10:00'),
       case when u = 'b8' and i = 2 then tst.at(o, '11:00') end, case when u = 'b9' and i = 3 then tst.at(o, '12:00') end
  from unnest(array['b3', 'b8', 'b9']) u, (values (1, -20), (2, -15), (3, -9)) v(i, o);
select tst.check(public.nudge_try(tst.u('b3'), tst.rule('parent_review_waiting'), 'p4', '{}', tst.at(0, '12:00')) = 'skipped_limit'
             and (tst.log('b3', 'parent_review_waiting', 'p4')).detail = 'pause', 'son üç ipucu yanıtsız: ara');
select tst.check((select paused_until from public.nudge_pauses where user_id = tst.u('b3')) = tst.at(-9, '10:00') + interval '14 days',
                 'ara en sonuncusundan 14 gün');
select tst.check(public.nudge_try(tst.u('b3'), tst.rule('parent_review_waiting'), 'p4', '{}', tst.at(4, '12:00')) = 'skipped_limit', 'ara sürüyor');
select tst.check(public.nudge_try(tst.u('b3'), tst.rule('parent_review_waiting'), 'p4', '{}', tst.at(6, '12:00')) = 'sent',
                 'ara bitince yeniden (önceki üç yeniden sayılmaz)');
select tst.check(public.nudge_try(tst.u('b8'), tst.rule('parent_review_waiting'), 'p4', '{}', tst.at(0, '12:00')) = 'sent', 'biri açıldıysa ara yok');
select tst.check(public.nudge_try(tst.u('b9'), tst.rule('parent_review_waiting'), 'p4', '{}', tst.at(0, '12:00')) = 'sent', 'biri 24 saatte hedefe ulaştıysa ara yok');

-- ---------------------------------------------------------------- bayrak: kişiye istisna ve ürüne özel anahtar
insert into public.user_flags (user_id, key, enabled, reason) values (tst.u('a1'), 'nudges_server', false, 'deneme dışı');
select tst.check(public.nudge_try(tst.u('a1'), tst.rule('parent_review_waiting'), 'f1', '{}', tst.at(1, '12:00')) = 'flag_off', 'kişiye istisna: kapalı');
delete from public.user_flags where user_id = tst.u('a1');
insert into public.feature_flags (key, enabled, rollout_pct) values ('nudges_server_clinic', false, 100);
select tst.check(not public.nudge_flag_on(tst.u('d2'), 'clinic') and public.nudge_flag_on(tst.u('a1'), 'parent'),
                 'ürüne özel anahtar (nudges_server_clinic) genel bayrağı o ürün için geçersiz kılar');
delete from public.feature_flags where key = 'nudges_server_clinic';

-- ---------------------------------------------------------------- açılma ve dönüşüm
set role authenticated;
select tst.as_user(tst.u('a1'));
select tst.check(public.mark_notifications_read() >= 1, 'ebeveyn bildirimleri okudu');
reset role;
select tst.as_user(null);
select tst.check((tst.log('a1', 'parent_child_none')).opened_at is not null, 'okundu → opened_at');
insert into public.children (id, family_id, name, avatar, created_at)
  values ('00000000-0000-0000-0000-00000000c0a1', tst.fam('a1'), 'Nazlı', 'kedi', tst.t0() + interval '30 minutes');
insert into public.children (id, family_id, name, avatar, created_at)
  values ('00000000-0000-0000-0000-00000000c0a5', tst.fam('a5'), 'Efe', 'kedi', tst.t0() + interval '30 minutes');
select tst.check(public.nudge_convert(tst.at(0, '14:00')) >= 1, 'dönüşüm hesaplandı');
select tst.check((tst.log('a1', 'parent_child_none')).converted_at = tst.t0() + interval '30 minutes', '72 saatte hedef adıma geçti (çocuk eklendi)');
select tst.check((tst.log('a4', 'parent_child_none')).converted_at is null, 'karşılaştırma grubu geçmedi');
select tst.check((tst.log('a5', 'parent_child_none')).converted_at is null, 'atlanan kayıt dönüşüm sayılmaz');

-- ---------------------------------------------------------------- panel
set role authenticated;
select tst.as_mfa(tst.u('f3'));
insert into tst.res values ('st', public.admin_nudge_stats('parent', current_date, current_date + 30)::jsonb);
select tst.check(jsonb_array_length(tst.r('st')) = 8, 'Moyo: 8 kural satırı');
select tst.check((select s - 'label' - 'category' from jsonb_array_elements(tst.r('st')) s where s ->> 'rule' = 'parent_child_none')
                 = '{"rule": "parent_child_none", "enabled": true, "sent": 1, "opened": 1, "converted": 1, "holdout": 1, "holdout_converted": 0,
                     "lift_pct": 100.0, "skipped": {"limit": 1, "quiet": 0, "pref": 1}}'::jsonb,
                 'istatistik: gönderilen 1, açılan 1, geçen 1, karşılaştırma 1 (0 geçti) → fark 100 puan');
select tst.check((select s -> 'lift_pct' from jsonb_array_elements(tst.r('st')) s where s ->> 'rule' = 'parent_inactive_7d') = 'null'::jsonb,
                 'karşılaştırma grubu yoksa fark null');
select tst.check((select (s ->> 'sent')::int from jsonb_array_elements(public.admin_nudge_stats('clinic', current_date, current_date + 30)::jsonb) s
                   where s ->> 'rule' = 'clinic_invite_none_1') = 1, 'Moyo Mercek istatistiği');
select tst.check(jsonb_array_length(public.admin_nudge_rules()::jsonb) = 14, 'izleyici kural listesini görür');
select tst.fails($$select public.admin_nudge_rule_set('parent_child_none', false, 'deneme')$$, 'izleyici kuralı kapatamaz');
select tst.as_mfa(tst.u('f2'));
select tst.fails($$select public.admin_nudge_rule_set('parent_child_none', false, 'deneme')$$, 'destek kuralı kapatamaz');
select tst.as_mfa(tst.u('f1'));
select tst.fails($$select public.admin_nudge_rule_set('yok_boyle', false, 'deneme')$$, 'bilinmeyen kural');
select tst.fails($$select public.admin_nudge_rule_set('parent_child_none', false, '')$$, 'gerekçe zorunlu');
select tst.check(public.admin_nudge_rule_set('parent_child_none', false, 'metin gözden geçiriliyor')::jsonb = '{"key": "parent_child_none", "enabled": false}',
                 'owner kuralı kapatır');
select tst.check((select count(*) from public.admin_audit_list('config', 'nudge:parent_child_none', 10)) = 1, 'denetim kaydında');
reset role;
select tst.check(not exists (select 1 from public.nudge_candidates(tst.t0(), true, true) where rule_key = 'parent_child_none'),
                 'kapalı kural aday üretmez');
update public.nudge_rules set enabled = true where key = 'parent_child_none';
select tst.check((select count(*) from public.nudge_candidates(tst.t0(), true, true) where rule_key = 'parent_child_none') >= 1, 'açılınca yeniden');
-- yeniden çalıştırınca owner'ın seçimi korunur
update public.nudge_rules set enabled = false where key = 'parent_inactive_7d';
\ir ../migrations/20261120230000_nudge_engine.sql
select tst.check(not (select enabled from public.nudge_rules where key = 'parent_inactive_7d'), 'öneri yeniden çalışınca kapalı kural kapalı kalır');

select 'BİLDİRİM MOTORU TESTLERİ GEÇTİ' as sonuc;
