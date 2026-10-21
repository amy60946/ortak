-- ClinicApp üyeliği (proposed/20261022000000_clinic_billing.sql)
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

-- d1 sahip, d2 ekip üyesi, d3 başka klinik, a1 ebeveyn (Nazlı d1'in kliniğiyle paylaşılmış)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Can"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
insert into tst.kv select 'k1', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into tst.kv select 'k3', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d3';
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi');
insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id, label, consent_by)
  select (select v::uuid from tst.kv where k = 'k1'), '00000000-0000-0000-0000-0000000000d1',
         family_id, '00000000-0000-0000-0000-00000000c001', '', '00000000-0000-0000-0000-0000000000a1'
    from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.abc_events (family_id, child_id, antecedent, behavior, consequence)
  select family_id, '00000000-0000-0000-0000-00000000c001', 'a', 'b', 'c' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';

-- ---------------------------------------------------------------- yeni klinik: 7 gün deneme, 10 koltuk
select tst.check((select trial_ends_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute'
                    from public.clinics where id = (select v::uuid from tst.kv where k = 'k1')), 'deneme 7 gün');
select tst.check((select seat_limit from public.clinics where id = (select v::uuid from tst.kv where k = 'k1')) = 10, 'denemede 10 koltuk');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinician_me() ->> 'status' = 'trial', 'durum: deneme');
select tst.check((public.clinician_me() ->> 'access')::boolean, 'denemede erişim var');
select tst.check(tst.cnt('public.abc_events') = 1, 'denemede zor an görünür');
select tst.check((select count(*) from public.clinic_clients()) = 1, 'denemede danışan listesi');
select tst.check(tst.cnt('public.billing_plans') = 4, 'uzman paketleri okur');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false,
   jsonb_build_object('account', 'clinician', 'name', 'Mert', 'team_code', (select v from tst.kv where k = 'team')));
set role authenticated;

-- ---------------------------------------------------------------- istemci planı/süreyi yazamaz, kayıtları okuyamaz
select tst.fails($$update public.clinics set plan = 'clinic', period_end = now() + interval '1 year'$$, 'uzman planı değiştiremez');
select tst.fails($$update public.clinics set trial_ends_at = now() + interval '1 year'$$, 'uzman denemeyi uzatamaz');
select tst.fails($$select public.billing_apply('manual', 'x', null, 'clinic_yearly', 'active', now() + interval '1 year', true)$$, 'uzman billing_apply çağıramaz');
select tst.fails($$select public.billing_recompute(null)$$, 'uzman billing_recompute çağıramaz');
select tst.fails($$insert into public.billing_plans (id, package, period, seat_limit, price_try) values ('bedava', 'clinic', 'yearly', 1000, 1)$$, 'paket eklenemez');
select tst.fails($$update public.billing_plans set price_try = 1$$, 'fiyat değiştirilemez');
select tst.check(tst.cnt('public.billing_subscriptions') = 0, 'abonelik kayıtları okunamaz');
select tst.check(tst.cnt('public.billing_events') = 0, 'ödeme günlüğü okunamaz');
select tst.check(tst.cnt('public.billing_checkouts') = 0, 'ödeme oturumları okunamaz');
select tst.fails($$insert into public.billing_subscriptions (clinic_id, source, external_id, plan_id, status) values ((select v::uuid from tst.kv where k = 'k1'), 'manual', 'x', 'clinic_yearly', 'active')$$, 'abonelik yazılamaz');
set role anon;
select tst.fails($$select * from public.billing_plans$$, 'girişsiz paketleri okuyamaz');
select tst.fails($$select public.clinician_access()$$, 'girişsiz erişim soramaz');
reset role;

-- ---------------------------------------------------------------- deneme biter → erişim kapanır
update public.clinics set trial_ends_at = now() - interval '1 minute' where id = (select v::uuid from tst.kv where k = 'k1');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinician_me() ->> 'status' = 'expired', 'durum: süresi doldu');
select tst.check(not (public.clinician_me() ->> 'access')::boolean, 'erişim kapandı');
select tst.check(tst.cnt('public.abc_events') = 0, 'süresi dolunca zor an görünmez');
select tst.check(tst.cnt('public.children') = 0, 'süresi dolunca çocuk görünmez');
select tst.check((select count(*) from public.clinic_clients()) = 0, 'süresi dolunca danışan listesi boş');
select tst.fails($$select public.clinic_create_invite('family', '')$$, 'süresi dolunca davet üretilemez');
select tst.fails($$insert into public.clinic_notes (clinic_id, link_id, author_id, body) select clinic_id, id, auth.uid(), 'x' from public.clinic_links limit 1$$, 'süresi dolunca not yazılamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(tst.cnt('public.clinic_links') = 1, 'ailenin paylaşımı silinmez (rıza sürer)');
reset role;

-- ---------------------------------------------------------------- sunucu doğrulanmış ödemeyi yazar (Edge Function rolü)
set role service_role;
select tst.check((public.billing_apply('app_store', '2000000111', (select v::uuid from tst.kv where k = 'k1'), 'solo_monthly',
                  'active', now() + interval '30 days', true, 'Sandbox', '{"productId":"com.clinicapp.uzman.solo.monthly"}') ->> 'active')::boolean,
                 'App Store aboneliği kliniği açar');
reset role;
select tst.check((select plan = 'solo' and seat_limit = 1 and billing_period = 'monthly' and billing_source = 'app_store' and auto_renew
                    from public.clinics where id = (select v::uuid from tst.kv where k = 'k1')), 'Bireysel aylık yazıldı');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinician_me() ->> 'status' = 'active', 'durum: etkin');
select tst.check(tst.cnt('public.abc_events') = 1, 'sahip yeniden görür');
select tst.fails($$select public.clinic_create_invite('clinician', '')$$, 'Bireysel pakette ekip daveti yok');
select tst.check(public.clinic_create_invite('family', '') ->> 'code' is not null, 'Bireysel pakette aile daveti var');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(not (public.clinician_me() ->> 'access')::boolean, 'Bireysel pakette ekip üyesinin erişimi yok');
select tst.check(tst.cnt('public.abc_events') = 0, 'Bireysel pakette üye zor an görmez');
reset role;

-- aynı makbuz başka kliniğe bağlanamaz
set role service_role;
select tst.fails($$select public.billing_apply('app_store', '2000000111', (select v::uuid from tst.kv where k = 'k3'), 'clinic_yearly', 'active', now() + interval '1 year', true)$$, 'makbuz başka kliniğe taşınamaz');
reset role;
select tst.check((select plan from public.clinics where id = (select v::uuid from tst.kv where k = 'k3')) = 'trial', 'başka klinik değişmedi');

-- Klinik yıllığa geçiş (web, iyzico) → ekip üyesi de görür
set role service_role;
select public.billing_apply('iyzico', 'sub-ref-1', (select v::uuid from tst.kv where k = 'k1'), 'clinic_yearly', 'active', now() + interval '365 days', true);
reset role;
select tst.check((select plan = 'clinic' and seat_limit = 10 and billing_period = 'yearly' and billing_source = 'iyzico'
                    from public.clinics where id = (select v::uuid from tst.kv where k = 'k1')), 'en geniş etkin paket seçilir');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((public.clinician_me() ->> 'access')::boolean, 'Klinik pakette üye erişir');
select tst.check(tst.cnt('public.abc_events') = 1, 'Klinik pakette üye zor an görür');
select tst.check((public.clinician_me() ->> 'member_count')::int = 2, 'üye sayısı');
reset role;

-- iptal: süre sonuna kadar açık, yenileme kapalı; iade/bitiş: kapanır
set role service_role;
select public.billing_apply('iyzico', 'sub-ref-1', null, 'clinic_yearly', 'canceled', now() + interval '365 days', false);
reset role;
select tst.check((select plan = 'clinic' and not auto_renew from public.clinics where id = (select v::uuid from tst.kv where k = 'k1')), 'iptal: dönem sonuna kadar Klinik');
set role service_role;
select public.billing_apply('iyzico', 'sub-ref-1', null, 'clinic_yearly', 'refunded', now() + interval '365 days', false);
reset role;
select tst.check((select plan = 'solo' from public.clinics where id = (select v::uuid from tst.kv where k = 'k1')), 'iade: kalan etkin aboneliğe (Bireysel) düşer');
set role service_role;
select public.billing_apply('app_store', '2000000111', null, 'solo_monthly', 'expired', now() - interval '1 day', false);
reset role;
select tst.check((select plan = 'solo' and period_end <= now() and not auto_renew from public.clinics where id = (select v::uuid from tst.kv where k = 'k1')), 'hepsi bitti: süresi geçmiş Bireysel');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinician_me() ->> 'status' = 'expired', 'abonelik bitince erişim kapanır');
select tst.check(tst.cnt('public.abc_events') = 0, 'abonelik bitince zor an görünmez');
reset role;

-- aile premium'u da klinik üyeliğine bağlı
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(not public.family_premium(), 'süresi dolmuş klinik aileye premium vermez');
reset role;
set role service_role;
select public.billing_apply('manual', 'pilot-1', (select v::uuid from tst.kv where k = 'k1'), 'clinic_yearly', 'active', now() + interval '90 days', false);
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.family_premium(), 'elle verilen pilot üyelik aileye premium verir');
reset role;

-- iş özeti istemciye kapalı
set role authenticated;
select tst.fails($$select * from analytics.clinic_billing$$, 'analytics.clinic_billing istemciye kapalı');
reset role;
select tst.check((select count(*) from analytics.clinic_billing) = 2, 'SQL Editor iş özetini görür');

select 'TÜM ÜYELİK TESTLERİ GEÇTİ' as sonuc;
