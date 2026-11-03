-- Aile davet et: davet kodu (+7 gün) ve ödemeye bağlı davet ödülü (migrations/20261028120000_guest_pass.sql)
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

-- A: veren aile · B: yeni aile · C: eski aile (deneme 20 gün önce) · D: ikinci yeni aile · E, F: ödül senaryoları için yeni aileler
insert into auth.users (id, is_anonymous, raw_user_meta_data, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}', 'a@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000b1', false, '{"nickname":"Yeni"}', 'b@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000c1', false, '{"nickname":"Eski"}', 'c@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"nickname":"İkinci"}', 'd@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Üçüncü"}', 'e@ornek.com', now()),
  ('00000000-0000-0000-0000-0000000000f1', false, '{"nickname":"Dördüncü"}', 'f@ornek.com', now());
update public.families set trial_started_at = now() - interval '20 days' where created_by = '00000000-0000-0000-0000-0000000000c1';
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'code', public.create_guest_pass() ->> 'code';
select tst.check((select v from tst.kv where k = 'code') ~ '^[A-Z2-9]{8}$', 'kart kodu 8 karakter');
select tst.check(public.create_guest_pass() ->> 'code' = (select v from tst.kv where k = 'code'), 'kullanılmamış kart yeniden istenince aynı kod döner');
select tst.check((public.create_guest_pass() ->> 'new')::boolean = false, 'aynı kart: new=false');
select tst.check((select count(*) from public.guest_passes) = 1, 'aile kendi kartını görür');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code')) ->> 'error') = 'own', 'kendi kartını kullanamaz');
select tst.fails($$insert into public.guest_passes (code, family_id, created_by) values ('ABCDEFGH', public.my_family_id(), auth.uid())$$, 'kart doğrudan yazılamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code')) ->> 'error') = 'not_new', 'eski aile kullanamaz');
select tst.check((select count(*) from public.guest_passes) = 0, 'başka ailenin kartları görünmez');

select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check((public.family_access() ->> 'trial_days')::int = 7, 'yeni aile: 7 günlük deneme');
select tst.check((public.redeem_guest_pass('ZZZZZZZZ') ->> 'error') = 'not_found', 'olmayan kod');
select tst.check((public.redeem_guest_pass(lower((select v from tst.kv where k = 'code'))) ->> 'ok')::boolean, 'yeni aile kartı kullanır (küçük harf de olur)');
select tst.check((public.family_access() ->> 'trial_days')::int = 14, 'deneme 7 + 7 = 14 gün');
select tst.check((public.family_access() ->> 'guest_pass')::boolean, 'erişimde davet işareti');
select tst.check((public.family_access() ->> 'days_left')::int between 13 and 14, 'kalan gün ~14');
select tst.check(public.family_access() ->> 'state' = 'trial', 'durum deneme');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select redeemed_at is not null from public.guest_passes where code = (select v from tst.kv where k = 'code')), 'veren aile kullanıldığını görür');
select tst.check((select count(*) from public.notifications where kind = 'guest_pass_used') = 1, 'verene bildirim');
select tst.check((public.my_referrals() ->> 'joined')::int = 1 and (public.my_referrals() ->> 'paid')::int = 0, 'özet: 1 aile katıldı, abone yok');
select tst.fails($$select * from public.referral_rewards$$, 'ödül tablosu doğrudan okunamaz');
insert into tst.kv select 'code2', public.create_guest_pass() ->> 'code';
select tst.check((select v from tst.kv where k = 'code2') <> (select v from tst.kv where k = 'code'), 'kullanılan kartın yerine yeni kart');

select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code2')) ->> 'error') = 'already', 'bir aile ikinci kartı kullanamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code')) ->> 'error') = 'used', 'kullanılmış kart');
reset role;
update public.guest_passes set expires_at = now() - interval '1 minute' where code = (select v from tst.kv where k = 'code2');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code2')) ->> 'error') = 'expired', 'süresi dolmuş kart');
reset role;
select tst.check(not has_function_privilege('anon', 'public.create_guest_pass()', 'execute'), 'anon kart oluşturamaz');
select tst.check(not has_function_privilege('anon', 'public.redeem_guest_pass(text)', 'execute'), 'anon kart kullanamaz');

-- ---------- Davet ödülü: davet edilen aile ücretli aboneliğe geçince davet edene 1 ay ----------
insert into tst.kv select 'famA', id::text from public.families where created_by = '00000000-0000-0000-0000-0000000000a1';
insert into tst.kv select 'famB', id::text from public.families where created_by = '00000000-0000-0000-0000-0000000000b1';
insert into tst.kv select 'famE', id::text from public.families where created_by = '00000000-0000-0000-0000-0000000000e1';
insert into tst.kv select 'famF', id::text from public.families where created_by = '00000000-0000-0000-0000-0000000000f1';
-- B mağazadan abone olur (webhook yazar): A abone değil → A'nın ücretsiz süresine 30 gün
select public.set_family_subscription((select v from tst.kv where k = 'famB')::uuid, 'premium', 'monthly', 'active', now() + interval '30 days', true, 'parentapp.premium.monthly', 'tx-b1');
select tst.check((select count(*) from public.referral_rewards where family_id = (select v from tst.kv where k = 'famA')::uuid and status = 'applied') = 1, 'davet edene ödül yazıldı (uygulandı)');
select tst.check((select bonus_until from public.families where id = (select v from tst.kv where k = 'famA')::uuid) > now() + interval '36 days', 'A: deneme sonu (7 gün) + 30 gün');
select tst.check((select count(*) from public.notifications n join public.profiles p on p.id = n.user_id
                   where n.kind = 'referral_reward' and p.family_id = (select v from tst.kv where k = 'famA')::uuid) = 1, 'davet edene ödül bildirimi');
-- Yenileme ve durum güncellemesi ikinci ödül yazmaz
select public.set_family_subscription((select v from tst.kv where k = 'famB')::uuid, 'premium', 'monthly', 'active', now() + interval '60 days', true, 'parentapp.premium.monthly', 'tx-b2');
select public.set_family_subscription((select v from tst.kv where k = 'famB')::uuid, 'premium', 'monthly', 'grace', now() + interval '60 days', true, 'parentapp.premium.monthly', 'tx-b2');
select tst.check((select count(*) from public.referral_rewards) = 1, 'aynı aile için ödül bir kez');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.family_access() ->> 'days_left')::int between 36 and 37, 'A: kalan ücretsiz gün ~37');
select tst.check(public.family_access() ->> 'state' = 'trial', 'A: durum deneme (ödüllü)');
select tst.check((public.my_referrals() ->> 'paid')::int = 1 and (public.my_referrals() ->> 'months')::int = 1 and (public.my_referrals() ->> 'year_left')::int = 11, 'özet: 1 abone, 1 ay, 11 hak');
-- B (davet edilen) kimin davet ettiğini görmez; A kimin abone olduğunu görmez
select tst.check((select count(*) from public.guest_passes where redeemed_family is not null) = 1, 'A kendi kartını görür');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check((select count(*) from public.guest_passes) = 0, 'davet edilen aile kartı görmez');
select tst.check((public.my_referrals() ->> 'months')::int = 0, 'B: ödül yok');
reset role;

-- A artık App Store'dan ödüyor: yeni davetle gelen E abone olunca ödül "kod bekliyor" (sunucu Apple aboneliğini uzatamaz)
select public.set_family_subscription((select v from tst.kv where k = 'famA')::uuid, 'premium', 'yearly', 'active', now() + interval '1 year', true, 'parentapp.premium.yearly', 'tx-a1');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'code3', public.create_guest_pass() ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code3')) ->> 'ok')::boolean, 'E davet kodunu kullanır');
reset role;
select public.set_family_subscription((select v from tst.kv where k = 'famE')::uuid, 'premium', 'yearly', 'active', now() + interval '1 year', true, 'parentapp.premium.yearly', 'tx-e1');
select tst.check((select status from public.referral_rewards where pass_code = (select v from tst.kv where k = 'code3')) = 'code_pending', 'ödeyen davet edene: Apple kodu bekliyor');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.my_referrals() ->> 'pending_codes')::int = 1 and (public.my_referrals() ->> 'months')::int = 2, 'özet: 1 kod bekliyor, toplam 2 ay');
reset role;

-- Yıllık sınır: son 365 günde 12 ödül varsa yenisi 'capped' (uygulanmaz)
insert into public.guest_passes (code, family_id, created_by, redeemed_at)
  select 'CAPQ' || chr(65 + i) || 'XYZ', (select v from tst.kv where k = 'famA')::uuid, '00000000-0000-0000-0000-0000000000a1', now()
  from generate_series(2, 11) i;
insert into public.referral_rewards (family_id, pass_code, status)
  select family_id, code, 'applied' from public.guest_passes where code like 'CAP%';
select tst.check((select count(*) from public.referral_rewards where family_id = (select v from tst.kv where k = 'famA')::uuid) = 12, '12 ödül');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'code4', public.create_guest_pass() ->> 'code';
select tst.check((public.my_referrals() ->> 'year_left')::int = 0, 'yıllık hak bitti');
select tst.as_user('00000000-0000-0000-0000-0000000000f1');
select tst.check((public.redeem_guest_pass((select v from tst.kv where k = 'code4')) ->> 'ok')::boolean, 'F davet kodunu kullanır');
reset role;
select public.set_family_subscription((select v from tst.kv where k = 'famF')::uuid, 'premium', 'monthly', 'active', now() + interval '30 days', true, 'parentapp.premium.monthly', 'tx-f1');
select tst.check((select status from public.referral_rewards where pass_code = (select v from tst.kv where k = 'code4')) = 'capped', 'sınır aşıldı: ödül uygulanmaz');
select tst.check(not has_function_privilege('anon', 'public.my_referrals()', 'execute'), 'anon özet okuyamaz');
select tst.check(not has_function_privilege('authenticated', 'public.referral_on_paid()', 'execute'), 'tetikleyici işlevi çağrılamaz');
