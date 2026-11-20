-- Huni analitiği, abonelik sağlığı, kıyas tabloları (proposed/20261120220000_funnel_analytics.sql)
-- Yetki (her admin okur; kişi listesi yalnız owner / support; yazma yalnız owner), RLS, adım sayıları ve yüzdeler (kümülatif),
-- medyan süre, çıkış ekranları, iptal nedenleri, kpis {value, n}, abonelik sağlığı, kıyas ve App Store verisi.
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
create or replace function tst.v(key text) returns uuid language sql as $$ select v::uuid from tst.kv where k = key $$;
create table tst.res (k text primary key, j jsonb);
create or replace function tst.r(key text) returns jsonb language sql as $$ select j from tst.res where k = key $$;
-- adım (anahtarla) ve düşüş
create or replace function tst.step(key text, step text) returns jsonb language sql as $$
  select s from jsonb_array_elements(tst.r(key) -> 'steps') s where s ->> 'key' = step $$;
create or replace function tst.drop_(key text, step text) returns jsonb language sql as $$
  select s from jsonb_array_elements(tst.r(key) -> 'drops') s where s ->> 'after' = step $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv, tst.res to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- f1 owner, f2 destek, f3 izleyici, f4 finans; a1, a2, a3, a5 aileler A, B, C, D (kohort); a6, a7, a8 aileler E, F, G (abonelik);
-- d1, d2 uzman; c1 A ailesinin çocuk cihazı
insert into auth.users (id, is_anonymous, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', now(), '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', now(), '{"nickname":"Destek"}'),
  ('00000000-0000-0000-0000-0000000000f3', false, 'izleyici@example.com', now(), '{"nickname":"İzleyici"}'),
  ('00000000-0000-0000-0000-0000000000f4', false, 'finans@example.com', now(), '{"nickname":"Finans"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'a@example.com', now(), '{"nickname":"Anne A"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, 'b@example.com', now(), '{"nickname":"Anne B"}'),
  ('00000000-0000-0000-0000-0000000000a3', false, 'c@example.com', now(), '{"nickname":"Anne C"}'),
  ('00000000-0000-0000-0000-0000000000a5', false, 'd@example.com', null, '{"nickname":"Anne D"}'),
  ('00000000-0000-0000-0000-0000000000a6', false, 'e@example.com', now(), '{"nickname":"Anne E"}'),
  ('00000000-0000-0000-0000-0000000000a7', false, 'f@example.com', now(), '{"nickname":"Anne F"}'),
  ('00000000-0000-0000-0000-0000000000a8', false, 'g@example.com', now(), '{"nickname":"Anne G"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'uzman1@example.com', now(), '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, 'uzman2@example.com', now(), '{"account":"clinician","clinic_name":"Yeşil Klinik","name":"Dr. Can"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, null, null, '{}');
insert into public.admin_users (user_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'owner'), ('00000000-0000-0000-0000-0000000000f2', 'support'),
  ('00000000-0000-0000-0000-0000000000f3', 'viewer'), ('00000000-0000-0000-0000-0000000000f4', 'finance');
insert into tst.kv select 'f' || right(id::text, 1), family_id::text from public.profiles
 where id in ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000a3',
              '00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-0000000000a6', '00000000-0000-0000-0000-0000000000a7',
              '00000000-0000-0000-0000-0000000000a8');
insert into tst.kv select 'k1', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into tst.kv values ('now', now()::text);
create or replace function tst.n() returns timestamptz language sql as $$ select v::timestamptz from tst.kv where k = 'now' $$;

-- ---------------------------------------------------------------- veri (sunucu yazar gibi; satır güvenliğini aşar)
select tst.as_user(null);
-- yönetim ve uzman hesapları kohorta karışmasın: yalnız A, B, C, D son 30 günde
update public.families set created_at = tst.n() - interval '400 days', trial_started_at = null
 where id not in (tst.v('f1'), tst.v('f2'), tst.v('f3'), tst.v('f5'));
-- A: bütün adımlar ücretliye kadar
update public.families set created_at = tst.n() - interval '20 days', trial_started_at = tst.n() - interval '20 days' + interval '2 hours' where id = tst.v('f1');
update auth.users set email_confirmed_at = tst.n() - interval '20 days' + interval '2 hours' where id = '00000000-0000-0000-0000-0000000000a1';
update auth.users set created_at = tst.n() - interval '20 days' + interval '5 hours' where id = '00000000-0000-0000-0000-0000000000c1';
insert into public.children (id, family_id, name, avatar, user_id, created_at) values
  ('00000000-0000-0000-0000-00000000c0a1', tst.v('f1'), 'Nazlı', 'kedi', '00000000-0000-0000-0000-0000000000c1', tst.n() - interval '20 days' + interval '3 hours');
insert into public.tasks (id, family_id, title, start_date, created_at)
  values ('00000000-0000-0000-0000-0000000007a1', tst.v('f1'), 'Dişlerini fırçala', current_date - 20, tst.n() - interval '20 days' + interval '6 hours');
insert into public.completions (family_id, task_id, child_id, date, status, child_done_at, reviewed_at, reviewed_by, created_at)
  values (tst.v('f1'), '00000000-0000-0000-0000-0000000007a1', '00000000-0000-0000-0000-00000000c0a1', current_date - 19, 'approved',
          tst.n() - interval '19 days', tst.n() - interval '18 days', '00000000-0000-0000-0000-0000000000a1', tst.n() - interval '19 days');
insert into public.activity_days (user_id, app, day)
  values ('00000000-0000-0000-0000-0000000000a1', 'parent', (tst.n() - interval '20 days')::date + 8);
insert into public.family_subscriptions (family_id, plan, source, billing, status, started_at, period_end, updated_at)
  values (tst.v('f1'), 'premium', 'store', 'monthly', 'active', tst.n() - interval '5 days', tst.n() - interval '5 days' + interval '1 month', tst.n() - interval '5 days');
-- B: çocuk ekledi, cihaz yok
update public.families set created_at = tst.n() - interval '20 days', trial_started_at = tst.n() - interval '20 days' + interval '4 hours' where id = tst.v('f2');
update auth.users set email_confirmed_at = tst.n() - interval '20 days' + interval '4 hours' where id = '00000000-0000-0000-0000-0000000000a2';
insert into public.children (id, family_id, name, avatar, created_at)
  values ('00000000-0000-0000-0000-00000000c0b1', tst.v('f2'), 'Efe', 'kedi', tst.n() - interval '19 days');
-- C: yalnız e-posta onayı (3 gün önce)
update public.families set created_at = tst.n() - interval '3 days', trial_started_at = tst.n() - interval '3 days' + interval '6 hours' where id = tst.v('f3');
update auth.users set email_confirmed_at = tst.n() - interval '3 days' + interval '6 hours' where id = '00000000-0000-0000-0000-0000000000a3';
-- D: e-posta onaylanmadı
update public.families set created_at = tst.n() - interval '20 days', trial_started_at = null where id = tst.v('f5');
-- E: yıllık, bir kez yenilenmiş (dönem sonu başlangıç + 2 yıl), şimdi ödeme sorunu (grace)
update public.families set trial_started_at = tst.n() - interval '400 days' where id = tst.v('f6');
insert into public.family_subscriptions (family_id, plan, source, billing, status, started_at, period_end, updated_at)
  values (tst.v('f6'), 'premium', 'store', 'yearly', 'grace', tst.n() - interval '380 days', tst.n() - interval '380 days' + interval '2 years', tst.n() - interval '2 days');
-- F: aylık, ilk dönemden sonra bitti (10 gün önce)
update public.families set trial_started_at = tst.n() - interval '60 days' where id = tst.v('f7');
insert into public.family_subscriptions (family_id, plan, source, billing, status, started_at, period_end, updated_at)
  values (tst.v('f7'), 'free', 'store', 'monthly', 'expired', tst.n() - interval '50 days', tst.n() - interval '50 days' + interval '1 month', tst.n() - interval '10 days');
-- G: 8 gün önce aldı, 6 gün önce iade
update public.families set trial_started_at = tst.n() - interval '100 days' where id = tst.v('f8');
insert into public.family_subscriptions (family_id, plan, source, billing, status, started_at, period_end, updated_at)
  values (tst.v('f8'), 'free', 'store', 'monthly', 'refunded', tst.n() - interval '8 days', tst.n() - interval '8 days' + interval '1 month', tst.n() - interval '6 days');
-- olaylar (çıkış ekranları ve iptal nedenleri)
insert into public.app_events (user_id, app, event, props, occurred_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'parent', 'screen.paywall', '{}', tst.n() - interval '5 days'),
  ('00000000-0000-0000-0000-0000000000a2', 'parent', 'child.add', '{}', tst.n() - interval '19 days'),
  ('00000000-0000-0000-0000-0000000000a2', 'parent', 'screen.family', '{}', tst.n() - interval '18 days'),
  ('00000000-0000-0000-0000-0000000000a2', 'parent', 'app.open', '{}', tst.n() - interval '17 days'),
  ('00000000-0000-0000-0000-0000000000d1', 'clinic', 'membership.cancel_reason', '{"reason":"expensive"}', tst.n() - interval '2 days'),
  ('00000000-0000-0000-0000-0000000000d1', 'clinic', 'membership.cancel_reason', '{"reason":"expensive"}', tst.n() - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000d2', 'clinic', 'membership.cancel_reason', '{"reason":"expensive"}', tst.n() - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000d2', 'clinic', 'membership.cancel_reason', '{"reason":"few_clients"}', tst.n() - interval '1 day');
insert into public.user_activity (user_id, app, first_seen_at, last_seen_at, last_active_date)
  values ('00000000-0000-0000-0000-0000000000a2', 'parent', tst.n() - interval '20 days', tst.n() - interval '17 days', current_date - 17);

-- Moyo Mercek: d1 bütün adımlar ücretliye kadar, d2 yalnız kayıt
update public.clinicians set created_at = tst.n() - interval '400 days' where id not in ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d2');
update public.clinicians set created_at = tst.n() - interval '20 days' where id = '00000000-0000-0000-0000-0000000000d1';
update public.clinicians set created_at = tst.n() - interval '10 days' where id = '00000000-0000-0000-0000-0000000000d2';
update public.clinics set trial_ends_at = tst.n() - interval '6 days' where created_by = '00000000-0000-0000-0000-0000000000d1';
insert into public.clinician_surveys (clinician_id, profession, created_at)
  values ('00000000-0000-0000-0000-0000000000d1', 'psychologist', tst.n() - interval '20 days' + interval '1 hour');
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, created_at, expires_at)
  values ('FUN001', tst.v('k1'), '00000000-0000-0000-0000-0000000000d1', 'family', tst.n() - interval '19 days', tst.n() - interval '16 days');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by, created_at)
  values ('00000000-0000-0000-0000-0000000011f1', tst.v('k1'), '00000000-0000-0000-0000-0000000000d1', tst.v('f1'),
          '00000000-0000-0000-0000-00000000c0a1', '00000000-0000-0000-0000-0000000000a1', tst.n() - interval '18 days');
insert into public.parent_trainings (id, clinic_id, link_id, title, status, activated_at, created_by, created_at)
  values ('00000000-0000-0000-0000-0000000070f1', tst.v('k1'), '00000000-0000-0000-0000-0000000011f1', 'Rutin eğitimi', 'active',
          tst.n() - interval '17 days', '00000000-0000-0000-0000-0000000000d1', tst.n() - interval '17 days');
insert into public.activity_days (user_id, app, day)
  values ('00000000-0000-0000-0000-0000000000d1', 'clinic', (tst.n() - interval '20 days')::date + 9);
insert into public.billing_subscriptions (clinic_id, source, external_id, plan_id, status, period_end, auto_renew, created_at, updated_at)
  values (tst.v('k1'), 'revenuecat', '00000000-0000-0000-0000-0000000000d1:com.clinicapp.uzman.solo.monthly', 'solo_monthly', 'active',
          tst.n() + interval '25 days', true, tst.n() - interval '5 days', tst.n() - interval '5 days');

-- ---------------------------------------------------------------- tablolar istemciye kapalı, fiyat
select tst.check((select relrowsecurity from pg_class where oid = 'public.store_funnel_daily'::regclass)
             and (select relrowsecurity from pg_class where oid = 'public.kpi_benchmarks'::regclass), 'iki yeni tabloda RLS açık');
select tst.check((select value ->> 'parent_monthly_try' from public.app_config where key = 'kpi') = '349.99'
             and (select value ->> 'parent_yearly_try' from public.app_config where key = 'kpi') = '3499.99', 'Moyo Premium fiyatı app_config.kpi''de');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select count(*) from public.store_funnel_daily$$, 'ebeveyn App Store tablosunu okuyamaz');
select tst.fails($$select count(*) from public.kpi_benchmarks$$, 'ebeveyn kıyas tablosunu okuyamaz');
select tst.fails($$select public.admin_funnel('parent', current_date - 30, current_date)$$, 'admin olmayan huniyi göremez');
select tst.fails($$select public.admin_subscription_health('parent', current_date - 30, current_date)$$, 'admin olmayan abonelik sağlığını göremez');
select tst.fails($$select public.admin_benchmarks()$$, 'admin olmayan kıyası göremez');
select tst.fails($$select public.funnel_parent_steps(tst.v('f1'))$$, 'iç yardımcı istemciye kapalı');
select tst.fails($$select * from public.funnel_cohort('parent', current_date - 30, current_date)$$, 'kohort işlevi istemciye kapalı');
select tst.as_user('00000000-0000-0000-0000-0000000000f1');
select tst.fails($$select public.admin_funnel('parent', current_date - 30, current_date)$$, 'owner iki adımlı doğrulama olmadan göremez');
reset role;
set role anon;
select tst.fails($$select public.admin_funnel('parent', current_date - 30, current_date)$$, 'anon çağıramaz');
reset role;
select tst.check(not has_function_privilege('anon', 'public.admin_funnel(text, date, date)', 'execute')
             and not has_function_privilege('anon', 'public.admin_funnel_people(text, text, date, date, integer)', 'execute')
             and not has_function_privilege('anon', 'public.admin_subscription_health(text, date, date)', 'execute')
             and not has_function_privilege('anon', 'public.admin_benchmark_set(text, text, numeric, numeric, numeric, text, text, text, text, text)', 'execute')
             and not has_function_privilege('authenticated', 'public.funnel_cohort(text, date, date, timestamptz)', 'execute')
             and not has_function_privilege('authenticated', 'public.funnel_person_trace(text, uuid)', 'execute'), 'yetkiler: anon hiçbirini, istemci iç yardımcıları çağıramaz');

-- ---------------------------------------------------------------- huni (izleyici okur)
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f3');
select tst.fails($$select public.admin_funnel('game', current_date - 30, current_date)$$, 'geçersiz ürün');
select tst.fails($$select public.admin_funnel('parent', current_date, current_date - 1)$$, 'ters tarih aralığı');
select tst.fails($$select public.admin_funnel('parent', current_date - 400, current_date)$$, 'en çok 1 yıl');
insert into tst.res values ('p0', public.admin_funnel('parent', current_date - 30, current_date)::jsonb);
select tst.check((tst.r('p0') ->> 'cohort_size')::int = 4, 'kohort: son 30 günde açılan 4 aile');
select tst.check(tst.r('p0') -> 'store' = 'null'::jsonb, 'App Store verisi yokken store null');
select tst.check(tst.step('p0', 'store_impression') -> 'count' = 'null'::jsonb and tst.step('p0', 'store_impression') ? 'note',
                 'verisi olmayan adım: count null + not');
select tst.check(jsonb_array_length(tst.r('p0') -> 'steps') = 14
             and (select string_agg(s ->> 'key', ',') from jsonb_array_elements(tst.r('p0') -> 'steps') s)
                 = 'store_impression,store_page_view,store_download,signup,email_verified,child_added,game_linked,first_routine,first_done,first_approved,active_d7,trial_end,paid,renewed',
                 'Moyo adım anahtarları sözleşmedeki sırayla');
select tst.check((select string_agg(s ->> 'count', ',') from jsonb_array_elements(tst.r('p0') -> 'steps') s where (s ->> 'count') is not null)
                 = '4,3,2,1,1,1,1,1,1,1,0', 'kümülatif sayılar: 4 → 3 → 2 → 1 … ücretli 1, yenileme 0 (B''nin denemesi bitti ama sayılmaz)');
select tst.check((tst.step('p0', 'signup') ->> 'pct_of_first')::numeric = 100 and (tst.step('p0', 'email_verified') ->> 'pct_of_first')::numeric = 75.0
             and (tst.step('p0', 'child_added') ->> 'pct_of_prev')::numeric = 66.7 and (tst.step('p0', 'game_linked') ->> 'pct_of_prev')::numeric = 50.0
             and (tst.step('p0', 'renewed') ->> 'pct_of_prev')::numeric = 0, 'yüzdeler 0–100 (ilk adıma ve öncekine göre)');
select tst.check((tst.step('p0', 'email_verified') ->> 'median_hours_from_prev')::numeric = 4.0
             and (tst.step('p0', 'child_added') ->> 'median_hours_from_prev')::numeric = 10.5
             and tst.step('p0', 'signup') -> 'median_hours_from_prev' = 'null'::jsonb, 'medyan süre (saat): 2/4/6 → 4; 1 ve 20 → 10,5');
select tst.check((tst.drop_('p0', 'signup') ->> 'lost')::int = 1 and tst.drop_('p0', 'signup') -> 'top_exits' = '[{"screen": "(olay yok)", "count": 1}]',
                 'kayıtta kalan D: olayı yok');
select tst.check((tst.drop_('p0', 'child_added') ->> 'lost')::int = 1 and tst.drop_('p0', 'child_added') -> 'top_exits' = '[{"screen": "screen.family", "count": 1}]',
                 'çocuk ekleyip bağlamayan B: son ekran screen.family (app.open sayılmaz)');
select tst.check((tst.drop_('p0', 'paid') ->> 'lost')::int = 1 and tst.drop_('p0', 'paid') -> 'top_exits' -> 0 ->> 'screen' = 'screen.paywall',
                 'ücretli olup yenilemeyen A');
select tst.check((tst.drop_('p0', 'game_linked') ->> 'lost')::int = 0 and tst.drop_('p0', 'renewed') is null, 'son adımda düşüş yok');
select tst.check(tst.r('p0') -> 'kpis' -> 'signup_to_activation' = '{"value": 33.3, "n": 3}'::jsonb,
                 'kayıt → etkinleşme: 7 günü dolan 3 aileden 1''i 7 günde onayladı (küçük örnek: n = 3)');
select tst.check(tst.r('p0') -> 'kpis' -> 'store_tap_through' = '{"value": null, "n": 0}'::jsonb, 'App Store verisi yokken kpi değeri null, n 0');
select tst.check(tst.r('p0') -> 'cancel_reasons' = '[]'::jsonb, 'Moyo''da iptal nedeni olayı yok');

-- ---------------------------------------------------------------- App Store verisi (yalnız owner) ve yüzdeler
select tst.fails($$select public.admin_store_funnel_set('parent', current_date - 1, 1000, 200, 40, 'App Store Connect')$$, 'izleyici yazamaz');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
select tst.fails($$select public.admin_store_funnel_set('parent', current_date - 1, 1000, 200, 40, 'App Store Connect')$$, 'destek yazamaz');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select tst.fails($$select public.admin_store_funnel_set('parent', current_date + 1, 1, 1, 1, 'gelecek gün')$$, 'gelecek gün reddedilir');
select tst.fails($$select public.admin_store_funnel_set('parent', current_date - 1, -1, 1, 1, 'negatif')$$, 'negatif reddedilir');
select tst.fails($$select public.admin_store_funnel_set('parent', current_date - 1, 1, 1, 1, '')$$, 'gerekçesiz reddedilir');
select public.admin_store_funnel_set('parent', current_date - 1, 900, 100, 10, 'App Store Connect');
select public.admin_store_funnel_set('parent', current_date - 1, 1000, 200, 40, 'App Store Connect düzeltme');   -- üzerine yazar
insert into tst.res values ('p1', public.admin_funnel('parent', current_date - 30, current_date)::jsonb);
select tst.check(tst.r('p1') -> 'store' = '{"impressions": 1000, "page_views": 200, "downloads": 40}'::jsonb, 'aynı gün üzerine yazıldı (upsert)');
select tst.check((tst.step('p1', 'store_page_view') ->> 'pct_of_first')::numeric = 20.0 and (tst.step('p1', 'signup') ->> 'pct_of_first')::numeric = 0.4
             and (tst.step('p1', 'signup') ->> 'pct_of_prev')::numeric = 10.0 and not tst.step('p1', 'store_impression') ? 'note',
                 'App Store adımlarıyla yüzdeler gösterimden');
select tst.check(tst.r('p1') -> 'kpis' -> 'store_tap_through' = '{"value": 20.0, "n": 1000}'::jsonb
             and tst.r('p1') -> 'kpis' -> 'store_page_conversion' = '{"value": 20.0, "n": 200}'::jsonb
             and tst.r('p1') -> 'kpis' -> 'download_to_signup' = '{"value": 10.0, "n": 40}'::jsonb, 'App Store kpi''ları {value, n}');
select tst.check((select count(*) from public.admin_audit_list('config', 'store_funnel:parent:' || (current_date - 1)::text, 10)) = 2, 'iki yazım denetim kaydında');
select public.admin_store_funnel_set('parent', current_date - 1, null, null, null, 'yanlış gün, sil');
select tst.check(public.admin_funnel('parent', current_date - 30, current_date)::jsonb -> 'store' = 'null'::jsonb, 'üç değer boşsa gün silinir');
select public.admin_store_funnel_set('parent', current_date - 1, 1000, 200, 40, 'App Store Connect');

-- ---------------------------------------------------------------- Moyo Mercek hunisi
insert into tst.res values ('c0', public.admin_funnel('clinic', current_date - 30, current_date)::jsonb);
select tst.check((tst.r('c0') ->> 'cohort_size')::int = 2
             and (select string_agg(s ->> 'key' || '=' || coalesce(s ->> 'count', '-'), ',') from jsonb_array_elements(tst.r('c0') -> 'steps') s)
                 = 'store_impression=-,store_page_view=-,store_download=-,signup=2,survey_done=1,first_invite=1,family_linked=1,first_training=1,active_w2=1,trial_end=1,paid=1,renewed=0',
                 'Mercek adımları ve kümülatif sayılar');
select tst.check(tst.r('c0') -> 'cancel_reasons' = '[{"reason": "expensive", "count": 2}, {"reason": "few_clients", "count": 1}]'::jsonb,
                 'iptal nedeni: membership.cancel_reason, kişi başına');
select tst.check(tst.r('c0') -> 'kpis' -> 'signup_to_activation' = '{"value": 100.0, "n": 1}'::jsonb, 'Mercek etkinleşme: 14 günde aile bağlandı');

-- ---------------------------------------------------------------- kişi listesi (yalnız owner / support; ad, e-posta, çocuk adı yok)
select tst.as_mfa('00000000-0000-0000-0000-0000000000f3');
select tst.fails($$select public.admin_funnel_people('parent', 'child_added', current_date - 30, current_date)$$, 'izleyici kişi listesini göremez');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f4');
select tst.fails($$select public.admin_funnel_people('parent', 'child_added', current_date - 30, current_date)$$, 'finans kişi listesini göremez');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f2');
insert into tst.res values ('pp', public.admin_funnel_people('parent', 'child_added', current_date - 30, current_date)::jsonb);
select tst.check(jsonb_array_length(tst.r('pp')) = 1 and tst.r('pp') -> 0 ->> 'id' = tst.v('f2')::text
             and tst.r('pp') -> 0 ->> 'id_short' = left(tst.v('f2')::text, 8) and tst.r('pp') -> 0 ->> 'kind' = 'family',
                 'destek: çocuk ekleyip kalan aile B (id = aile kimliği, kind family)');
select tst.check(tst.r('pp') -> 0 ->> 'last_screen' = 'screen.family' and tst.r('pp') -> 0 ->> 'state' = 'expired'
             and (tst.r('pp') -> 0 ->> 'reached')::timestamptz = tst.n() - interval '19 days', 'son ekran, durum (müşteri ekranı adları), ulaştığı an');
select tst.check(not (tst.r('pp') -> 0 ?| array['email', 'name', 'nickname', 'child_name', 'children', 'parents'])
             and tst.r('pp')::text not like '%example.com%' and tst.r('pp')::text not like '%Efe%' and tst.r('pp')::text not like '%Anne%',
                 'kişi listesinde e-posta, ad, çocuk adı yok');
select tst.check(public.admin_funnel_people('parent', 'store_download', current_date - 30, current_date)::jsonb = '[]'::jsonb, 'App Store adımı kişi bazında değil');
select tst.check(jsonb_array_length(public.admin_funnel_people('parent', 'paid', current_date - 30, current_date)::jsonb) = 1
             and jsonb_array_length(public.admin_funnel_people('parent', 'renewed', current_date - 30, current_date)::jsonb) = 0, 'ücretli kalan A, yenileyen yok');
select tst.fails($$select public.admin_funnel_people('parent', 'survey_done', current_date - 30, current_date)$$, 'öteki ürünün adımı reddedilir');
select tst.check(public.admin_funnel_people('clinic', 'signup', current_date - 30, current_date)::jsonb -> 0 ->> 'kind' = 'user'
             and public.admin_funnel_people('clinic', 'signup', current_date - 30, current_date)::jsonb -> 0 ->> 'id' = '00000000-0000-0000-0000-0000000000d2'
             and public.admin_funnel_people('clinic', 'signup', current_date - 30, current_date)::jsonb -> 0 ->> 'state' = 'trial',
                 'Mercek: kayıtta kalan uzman (kind user, durum trial)');
select tst.check(jsonb_array_length(public.admin_funnel_people('parent', 'signup', current_date - 30, current_date, 1)::jsonb) = 1, 'limit');

-- ---------------------------------------------------------------- abonelik sağlığı
select tst.as_mfa('00000000-0000-0000-0000-0000000000f3');
insert into tst.res values ('h', public.admin_subscription_health('parent', current_date - 30, current_date)::jsonb);
select tst.check((tst.r('h') ->> 'active_paid')::int = 2 and (tst.r('h') ->> 'in_trial')::int = 1 and (tst.r('h') ->> 'trials_started')::int = 3
             and (tst.r('h') ->> 'trials_ended')::int = 2 and (tst.r('h') ->> 'trial_to_paid_pct')::numeric = 50.0,
                 'Moyo: 2 aktif ücretli (A aylık, E yıllık ek sürede), 1 denemede (C), deneme biten 2''den 1''i ücretli');
select tst.check((tst.r('h') ->> 'new_paid')::int = 2 and (tst.r('h') ->> 'churned')::int = 2 and (tst.r('h') ->> 'renewals')::int = 1
             and (tst.r('h') ->> 'refunds')::int = 1 and (tst.r('h') ->> 'billing_issues')::int = 1, 'yeni 2 (A, G), kayıp 2 (F, G), yenileme 1 (E), iade 1, ödeme sorunu 1');
select tst.check((tst.r('h') ->> 'mrr_try')::numeric = 641.66 and (tst.r('h') ->> 'arpu_try')::numeric = 320.83
             and tst.r('h') -> 'by_plan' = '[{"plan": "premium_monthly", "active": 1, "mrr_try": 349.99}, {"plan": "premium_yearly", "active": 1, "mrr_try": 291.67}]'::jsonb,
                 'MRR aylık eşdeğer: 349,99 + 3.499,99 / 12');
select tst.check(tst.r('h') -> 'kpis' = '{"trial_to_paid": {"value": 50.0, "n": 2}, "monthly_churn": {"value": 50.0, "n": 2},
                   "monthly_renewal_m1": {"value": 0.0, "n": 1}, "annual_renewal": {"value": 100.0, "n": 1}, "annual_share": {"value": 50.0, "n": 2},
                   "refund_rate": {"value": 33.3, "n": 3}, "billing_issue_rate": {"value": 50.0, "n": 2}}'::jsonb, 'abonelik kpi''ları {value, n}');
select tst.check((select bool_and(extract(isodow from (w ->> 'week')::date) = 1 and (w ->> 'week') ~ '^\d{4}-\d{2}-\d{2}$')
                    from jsonb_array_elements(tst.r('h') -> 'weekly') w)
             and (select sum((w ->> 'paid')::int) from jsonb_array_elements(tst.r('h') -> 'weekly') w) = 2
             and (select sum((w ->> 'churned')::int) from jsonb_array_elements(tst.r('h') -> 'weekly') w) = 2, 'haftalar pazartesi (YYYY-MM-DD), toplamlar tutarlı');
insert into tst.res values ('hc', public.admin_subscription_health('clinic', current_date - 30, current_date)::jsonb);
select tst.check((tst.r('hc') ->> 'active_paid')::int = 1 and (tst.r('hc') ->> 'mrr_try')::numeric = 1199.99 and (tst.r('hc') ->> 'in_trial')::int = 1
             and tst.r('hc') -> 'kpis' -> 'trial_to_paid' = '{"value": 100.0, "n": 1}'::jsonb
             and (select (p ->> 'active')::int from jsonb_array_elements(tst.r('hc') -> 'by_plan') p where p ->> 'plan' = 'solo_monthly') = 1,
                 'Mercek: Bireysel aylık 1.199,99, d2 denemede, d1 denemeden ücretliye');

-- ---------------------------------------------------------------- kıyas (owner yazar, herkes okur)
select tst.fails($$select public.admin_benchmark_set('monthly_churn', 'parent', 5, 3, 8, 'Kaynak', 'https://example.com/a', '2025', 'kıyas')$$, 'izleyici kıyas yazamaz');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f4');
select tst.fails($$select public.admin_benchmark_set('monthly_churn', 'parent', 5, 3, 8, 'Kaynak', 'https://example.com/a', '2025', 'kıyas')$$, 'finans kıyas yazamaz');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select tst.fails($$select public.admin_benchmark_set('made_up', 'parent', 5, 3, 8, 'Kaynak', null, '2025', 'kıyas')$$, 'bilinmeyen anahtar');
select tst.fails($$select public.admin_benchmark_set('monthly_churn', 'parent', 150, 3, 8, 'Kaynak', null, '2025', 'kıyas')$$, 'yüzde 100''ü aşamaz');
select tst.fails($$select public.admin_benchmark_set('monthly_churn', 'parent', 5, 9, 8, 'Kaynak', null, '2025', 'kıyas')$$, 'alt sınır üst sınırdan büyük olamaz');
select tst.fails($$select public.admin_benchmark_set('monthly_churn', 'parent', 5, 3, 8, 'Kaynak', 'http://example.com', '2025', 'kıyas')$$, 'bağlantı https');
select tst.fails($$select public.admin_benchmark_set('monthly_churn', 'parent', 5, 3, 8, 'Kaynak', null, '2025', '')$$, 'gerekçe zorunlu');
insert into tst.res values ('b1', public.admin_benchmark_set('monthly_churn', 'parent', 5, 3, 8, 'Örnek rapor', 'https://example.com/a', '2025', 'kıyas girişi', 'aylık plan')::jsonb);
select tst.check(tst.r('b1') ->> 'label' = 'Aylık kayıp (30 gün)' and tst.r('b1') ->> 'better' = 'low' and tst.r('b1') ->> 'unit' = '%'
             and tst.r('b1') ->> 'note' = 'aylık plan', 'ad, birim ve yön anahtardan (kayıpta küçük iyi)');
select public.admin_benchmark_set('monthly_churn', 'parent', 6, 3, 9, 'Örnek rapor', 'https://example.com/a', '2025', 'düzeltme');
select public.admin_benchmark_set('trial_to_paid', 'clinic', 20, 10, 30, 'Örnek', null, '2025-Q3', 'kıyas girişi');
reset role;
insert into public.kpi_benchmarks (key, product, value, low, high) values ('refund_rate', 'parent', 2, 1, 4);   -- seed gibi: ad ve yön verilmeden
set role authenticated;
select tst.as_mfa('00000000-0000-0000-0000-0000000000f3');
insert into tst.res values ('bl', public.admin_benchmarks()::jsonb);
select tst.check(jsonb_array_length(tst.r('bl')) = 3
             and (select b ->> 'value' from jsonb_array_elements(tst.r('bl')) b where b ->> 'key' = 'monthly_churn') = '6'
             and (select b ->> 'better' from jsonb_array_elements(tst.r('bl')) b where b ->> 'key' = 'refund_rate') = 'low'
             and (select b ->> 'label' from jsonb_array_elements(tst.r('bl')) b where b ->> 'key' = 'refund_rate') = 'İade oranı'
             and (select b ->> 'better' from jsonb_array_elements(tst.r('bl')) b where b ->> 'key' = 'trial_to_paid') = 'high'
             and (select bool_and(b ?& array['key', 'product', 'label', 'value', 'unit', 'better', 'low', 'high', 'source', 'source_url', 'as_of'])
                    from jsonb_array_elements(tst.r('bl')) b), 'izleyici kıyasları okur; seed satırında ad ve yön eşlemeden');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select tst.check((select count(*) from public.admin_audit_list('config', 'benchmark:parent:monthly_churn', 10)) = 2, 'kıyas yazımları denetim kaydında');
select public.admin_benchmark_set('trial_to_paid', 'clinic', null, null, null, null, null, null, 'kaldır');
select tst.check(jsonb_array_length(public.admin_benchmarks()::jsonb) = 2, 'üç değer boşsa satır silinir');
reset role;

select 'HUNİ ANALİTİĞİ TESTLERİ GEÇTİ' as sonuc;
