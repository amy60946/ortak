-- Davet ödülü kod havuzu (migrations/20261103200000_referral_codes.sql) + sağlık denetimi (20261102200000_kvkk_ops.sql)
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
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;
create or replace function tst.fam(u text) returns uuid language sql as $$
  select id from public.families where created_by = ('00000000-0000-0000-0000-0000000000' || u)::uuid $$;
-- Davet: veren aile kodu üretir, yeni aile kullanır, sonra mağazadan abone olur (tetik ödülü yazar)
create or replace function tst.invite(giver text, taker text) returns void language plpgsql as $$
declare c text;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000' || giver, false);
  c := public.create_guest_pass() ->> 'code';
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000' || taker, false);
  if not (public.redeem_guest_pass(c) ->> 'ok')::boolean then raise exception 'davet kodu kullanılamadı'; end if;
  perform public.set_family_subscription(tst.fam(taker), 'premium', 'monthly', 'active', now() + interval '1 month', true,
                                         'parentapp.premium.monthly', 'tx-' || taker);
end $$;

insert into auth.users (id, is_anonymous, email, raw_user_meta_data, email_confirmed_at) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}', now()),
  ('00000000-0000-0000-0000-0000000000f2', false, 'finans@example.com', '{"nickname":"Finans"}', now()),
  ('00000000-0000-0000-0000-0000000000f3', false, 'izleyici@example.com', '{"nickname":"İzleyici"}', now()),
  ('00000000-0000-0000-0000-0000000000f4', false, 'destek@example.com', '{"nickname":"Destek"}', now()),
  ('00000000-0000-0000-0000-0000000000a1', false, 'a@example.com', '{"nickname":"A"}', now()),
  ('00000000-0000-0000-0000-0000000000b1', false, 'b@example.com', '{"nickname":"B"}', now()),
  ('00000000-0000-0000-0000-0000000000c1', false, 'c@example.com', '{"nickname":"C"}', now()),
  ('00000000-0000-0000-0000-0000000000d1', false, 'd@example.com', '{"nickname":"D"}', now()),
  ('00000000-0000-0000-0000-0000000000e1', false, 'e@example.com', '{"nickname":"E"}', now()),
  ('00000000-0000-0000-0000-0000000000e2', false, 'e2@example.com', '{"nickname":"E2"}', now());
insert into public.admin_users (user_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'owner'), ('00000000-0000-0000-0000-0000000000f2', 'finance'),
  ('00000000-0000-0000-0000-0000000000f3', 'viewer'), ('00000000-0000-0000-0000-0000000000f4', 'support');

-- A (aylık) ve C (yıllık) App Store'dan ödüyor
select public.set_family_subscription(tst.fam('a1'), 'premium', 'monthly', 'active', now() + interval '1 month', true, 'parentapp.premium.monthly', 'tx-a1');
select public.set_family_subscription(tst.fam('c1'), 'premium', 'yearly', 'active', now() + interval '1 year', true, 'parentapp.premium.yearly', 'tx-c1');

-- 1) Havuz boş: ödül kod bekler, ebeveyne "birkaç gün içinde" bildirimi
select tst.invite('a1', 'b1');
select tst.check((select status from public.referral_rewards where family_id = tst.fam('a1')) = 'code_pending', 'havuz boş: A ödülü kod bekliyor');
select tst.check((select count(*) from public.notifications where kind = 'referral_reward' and family_id = tst.fam('a1') and body like '%birkaç gün%') = 1,
                 'A: bekleme bildirimi (tek)');
select tst.check((public.ops_health() -> 'checks') @> '[{"key":"referral","level":"warn"}]', 'sağlık: kod bekleyen ödül uyarı verir');

-- 2) Yetki: ebeveyn ve izleyici kod ekleyemez; iki adımlı doğrulama şart; tablo ve iç işlevler kapalı
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select count(*) from public.offer_code_pool$$, 'ebeveyn havuzu okuyamaz');
select tst.fails($$select public.referral_assign('00000000-0000-0000-0000-000000000000', 'XYZ12345', true)$$, 'ebeveyn kod atayamaz (iç işlev)');
select tst.fails($$select public.referral_assign_pending()$$, 'iç toplu atama kapalı');
select tst.fails($$select public.admin_referral_overview()$$, 'ebeveyn özet göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal1');
select tst.fails($$select public.admin_referral_overview()$$, 'iki adımlı doğrulama olmadan olmaz');
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
select tst.check((public.admin_referral_overview() -> 'rewards' ->> 'code_pending')::int = 1, 'izleyici: 1 ödül kod bekliyor');
select tst.check(jsonb_array_length(public.admin_referral_overview() -> 'pending') = 1
                 and public.admin_referral_overview() -> 'pending' -> 0 ->> 'billing' = 'monthly', 'bekleyen listesi: aile + aylık');
select tst.check((public.admin_referral_overview() -> 'invites' ->> 'paid')::int = 1, 'KPI: 1 davet abone oldu');
select tst.fails($$select public.admin_offer_codes_add(array['ABCDEF12'], 'monthly', current_date + 90, null, 'deneme kodları')$$, 'izleyici kod yükleyemez');
select tst.as_user('00000000-0000-0000-0000-0000000000f4', 'aal2');
select tst.fails($$select public.admin_offer_codes_add(array['ABCDEF12'], 'monthly', current_date + 90, null, 'deneme kodları')$$, 'destek kod yükleyemez');

-- 3) Kod yükle (finans): geçersiz ve tekrar edenler atlanır, bekleyen ödüle kendiliğinden atanır
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.fails($$select public.admin_offer_codes_add(array['ABCDEF12'], 'weekly', current_date + 90, null, 'deneme kodları')$$, 'ürün aylık/yıllık');
select tst.fails($$select public.admin_offer_codes_add(array['ABCDEF12'], 'monthly', current_date + 10, null, 'deneme kodları')$$, 'son tarih çok yakın');
select tst.fails($$select public.admin_offer_codes_add(array['ABCDEF12'], 'monthly', current_date + 200, null, 'deneme kodları')$$, 'son tarih 6 aydan uzak');
select tst.fails($$select public.admin_offer_codes_add('{}'::text[], 'monthly', current_date + 90, null, 'deneme kodları')$$, 'boş dosya');
select tst.fails($$select public.admin_offer_codes_add(array['ABCDEF12'], 'monthly', current_date + 90, null, '')$$, 'gerekçe zorunlu');
insert into tst.kv values ('add1', public.admin_offer_codes_add(array['abcd 2345 efgh', 'BAD!', 'AAAA22', 'AAAA22', 'MONTH777', 'x'],
                                                               'monthly', current_date + 90, 'Kasım aylık', 'ilk kod partisi'));
select tst.check((select v ->> 'added' from tst.kv where k = 'add1')::int = 3, 'yükleme: 3 kod eklendi');
select tst.check((select v ->> 'invalid' from tst.kv where k = 'add1')::int = 2, 'yükleme: 2 geçersiz');
select tst.check((select v ->> 'duplicate' from tst.kv where k = 'add1')::int = 1, 'yükleme: 1 tekrar');
select tst.check((select v ->> 'assigned' from tst.kv where k = 'add1')::int = 1, 'yükleme: bekleyen 1 ödüle kod atandı');
reset role;
select tst.check((select status = 'code_sent' and offer_code in ('ABCD2345EFGH', 'AAAA22', 'MONTH777') and code_sent_at is not null
                    from public.referral_rewards where family_id = tst.fam('a1')), 'A: kod gönderildi (boşluksuz, büyük harf)');
select tst.check((select count(*) from public.offer_code_pool where assigned_at is not null) = 1, 'havuzda 1 kod atanmış');
select tst.check((select count(*) from public.notifications where kind = 'referral_reward' and family_id = tst.fam('a1') and title = 'Hediye kodun hazır') = 1,
                 'A: "kod hazır" bildirimi');
select tst.check(not exists (select 1 from public.admin_audit where action like 'referral.%'
                               and (coalesce(after::text, '') ~ 'ABCD2345EFGH|AAAA22|MONTH777')), 'denetim kaydında kod yok');
insert into tst.kv select 'codeA', to_jsonb(offer_code) from public.referral_rewards where family_id = tst.fam('a1');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.my_referrals() -> 'codes' -> 0 ->> 'code' = (select v #>> '{}' from tst.kv where k = 'codeA')
                 and (public.my_referrals() ->> 'pending_codes')::int = 0, 'A davet sayfasında kodu görür');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.check((public.admin_offer_codes_add(array['AAAA22', 'MONTH777', 'ABCD2345EFGH'], 'monthly', current_date + 90, null, 'tekrar yükleme') ->> 'duplicate')::int = 3,
                 'aynı dosya ikinci kez: hepsi tekrar');
select tst.check(public.admin_referral_overview()::text !~ 'ABCD2345EFGH|MONTH777|"AAAA22"', 'özet tam kodu göstermez');
select tst.check(public.admin_referral_overview() -> 'sent' -> 0 ->> 'code_tail' = right((select v #>> '{}' from tst.kv where k = 'codeA'), 4), 'gönderilende son 4 karakter');
select tst.check((public.admin_referral_overview() -> 'pool' ->> 'monthly')::int = 2, 'havuz: 2 aylık kod kaldı');

-- 4) Yıllık abone C: aylık kod atanmaz; yıllık kod yüklenince atanır
reset role;
select tst.invite('c1', 'd1');
select tst.check((select status from public.referral_rewards where family_id = tst.fam('c1')) = 'code_pending', 'C yıllık: aylık kod atanmadı');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.check((public.admin_offer_codes_add(array['YEAR0001', 'YEAR0002'], 'yearly', current_date + 120, null, 'yıllık kodlar') ->> 'assigned')::int = 1,
                 'yıllık kod yüklenince C''ye atandı');
reset role;
select tst.check((select offer_code from public.referral_rewards where family_id = tst.fam('c1')) like 'YEAR%', 'C yıllık kod aldı');

-- 5) Süresi 14 günden az kalan kod atanmaz; elle giriş (yedek yol); havuz silme
update public.offer_code_pool set expires_at = now() + interval '10 days' where billing = 'monthly' and assigned_at is null;
select public.set_family_subscription(tst.fam('e1'), 'premium', 'monthly', 'active', now() + interval '1 month', true, 'parentapp.premium.monthly', 'tx-e1');
select tst.invite('e1', 'e2');
select tst.check((select status from public.referral_rewards where family_id = tst.fam('e1')) = 'code_pending', 'süresi yakın kod atanmaz');
select tst.check((public.ops_health() -> 'checks') @> '[{"key":"referral","level":"warn"}]', 'sağlık: bekleyen ödül → uyarı');
insert into tst.kv select 'rwE', to_jsonb(id::text) from public.referral_rewards where family_id = tst.fam('e1');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f4', 'aal2');
select tst.fails($$select public.admin_referral_send_code((select v #>> '{}' from tst.kv where k = 'rwE')::uuid, null, 'havuzdan dene')$$, 'havuzda uygun kod yok → hata');
select tst.fails($$select public.admin_referral_send_code((select v #>> '{}' from tst.kv where k = 'rwE')::uuid, 'YEAR0001', 'elle kod')$$, 'başka aileye giden kod elle verilemez');
select tst.fails($$select public.admin_referral_send_code((select v #>> '{}' from tst.kv where k = 'rwE')::uuid, 'kod-1!', 'elle kod')$$, 'elle kod: yalnız harf/rakam');
select tst.check((public.admin_referral_send_code((select v #>> '{}' from tst.kv where k = 'rwE')::uuid, ' manual 01 ', 'App Store Connect özel kod') ->> 'code_tail') = 'AL01',
                 'destek elle kod gönderir');
select tst.fails($$select public.admin_referral_send_code((select v #>> '{}' from tst.kv where k = 'rwE')::uuid, 'MANUAL02', 'yine')$$, 'kod gönderilmiş ödüle ikinci kod olmaz');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.check(public.admin_offer_codes_remove('Kasım aylık', 'yanlış dosya') = 2, 'partideki atanmamış 2 kod silindi');
select tst.check((public.admin_referral_overview() -> 'pool' ->> 'assigned')::int = 2, 'atanmış kodlar duruyor');
reset role;
select tst.check((select count(*) from public.offer_code_pool where batch = 'Kasım aylık') = 1, 'atanmış kod silinmez');
select tst.check((select count(*) from public.admin_audit where action = 'referral.send_code' and target_type = 'family' and target_id = tst.fam('e1')::text) = 1,
                 'elle gönderim denetim kaydında (aile)');
select tst.check(exists (select 1 from public.admin_audit where action = 'referral.codes_remove'), 'silme denetim kaydında');
select tst.check((public.ops_health() -> 'checks') @> '[{"key":"referral","level":"warn"}]', 'sağlık: aylık kod azaldı → uyarı');
select tst.check(exists (select 1 from jsonb_array_elements(public.ops_health() -> 'checks') c
                           where c ->> 'key' = 'referral' and c ->> 'detail' like 'Aylık ürün için 0 kod%'), 'sağlık: ayrıntı kalan aylık kod');
