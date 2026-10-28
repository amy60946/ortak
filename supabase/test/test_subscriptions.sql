-- Abonelik: 7 günlük deneme, planlar, ücretsiz plan sınırları (20261021140000_subscriptions.sql).
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
-- Hata metnini döndürür (hata yoksa null)
create or replace function tst.err(sql text) returns text language plpgsql as $$
begin
  execute sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

-- a1 anne (e-posta doğrulanmamış kayıt), a2 baba (kayıtta doğrulanmış), c1 çocuk cihazı
insert into auth.users (id, is_anonymous, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', null, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, 'baba@example.com', now(), '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, null, null, '{}');
set role authenticated;

-- deneme e-posta doğrulanınca başlar
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('fid', public.my_family_id()::text);
select tst.check(public.family_access() ->> 'state' = 'pending', 'doğrulamadan önce deneme başlamaz');
select tst.check((public.family_access() ->> 'full')::boolean, 'beklerken tam erişim');
reset role;
update auth.users set email_confirmed_at = now() where id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select tst.check(public.family_access() ->> 'state' = 'trial', 'doğrulayınca deneme başladı');
select tst.check((public.family_access() ->> 'days_left')::int = 7, '7 gün kaldı');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(public.family_access() ->> 'state' = 'trial', 'kayıtta doğrulanmış hesapta deneme hemen başlar');
select tst.fails($$select public.set_family_subscription(public.my_family_id(), 'premium', 'yearly', 'active', now() + interval '1 year', true, 'p', 't')$$, 'istemci aboneliği kendisi yazamaz');
select tst.fails($$insert into public.family_subscriptions (family_id, plan) values (public.my_family_id(), 'premium')$$, 'tabloya doğrudan yazılamaz');
select tst.fails($$update public.app_config set value = '{"enforce": false}'$$, 'ayar değiştirilemez');
select tst.check(not exists (select 1 from public.app_config) or (select count(*) from public.app_config) = 1, 'ayar okunur');
select tst.fails($$select * from public.trial_history$$, 'deneme geçmişi okunamaz');

-- deneme biter; uygulama anahtarı kapalıyken kimse kısıtlanmaz
reset role;
update public.families set trial_started_at = now() - interval '8 days' where id = tst.v('fid')::uuid;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.family_access() ->> 'state' = 'expired', 'deneme bitti');
select tst.check((public.family_access() ->> 'full')::boolean and not (public.family_access() ->> 'enforced')::boolean, 'anahtar kapalı: yine tam erişim');
select tst.check(not public.family_premium(), 'deneme bitince premium değil');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'Efe', 'kedi');

-- anahtar açık: ücretsiz plan sınırları
reset role;
update public.app_config set value = value || '{"enforce": true}' where key = 'billing';
set role authenticated;
select tst.check(not (public.family_access() ->> 'full')::boolean, 'anahtar açık: ücretsiz plan');
select tst.check(tst.err($$insert into public.children (family_id, name, avatar) values (public.my_family_id(), 'Ali', 'kedi')$$) like 'Ücretsiz planda en çok 1 çocuk%', 'ücretsiz planda yeni çocuk eklenmez');
insert into public.tasks (id, family_id, title, start_date, recurring) select gen_random_uuid(), public.my_family_id(), 'G' || x, current_date, true from generate_series(1, 3) x;
select tst.check(tst.err($$insert into public.tasks (family_id, title, start_date) values (public.my_family_id(), 'Dördüncü', current_date)$$) like 'Ücretsiz planda en çok 3 etkin görev%', '4. görev eklenmez');
select tst.check(tst.err($$insert into public.abc_events (family_id, child_id, behavior, intensity) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'x', 2)$$) = 'Bu özellik Premium üyelikte: davranış kaydı', 'davranış kaydı kapalı');
select tst.check(tst.err($$insert into public.messages (family_id, child_id, sender, sender_id, kind, body) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'parent', auth.uid(), 'text', 'Merhaba')$$) like 'Bu özellik Premium%', 'ebeveyn mesajı kapalı');
-- çocuk yine yazabilir, ebeveyn yine onaylayabilir
insert into tst.kv select 'code', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  select id, '00000000-0000-0000-0000-00000000c001', family_id, 'easy', 5 from public.tasks where title = 'G1';
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('code'));
select public.child_send_message('sticker', 'heart');
select public.child_set_status((select id from public.tasks where title = 'G1'), current_date, 'pending');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion((select id from public.tasks where title = 'G1'), '00000000-0000-0000-0000-00000000c001', current_date, 'approved');
select tst.check((select status from public.completions limit 1) = 'approved', 'ücretsiz planda onay çalışır');
select tst.check((select count(*) from public.messages where sender = 'child') = 1, 'ücretsiz planda çocuk mesajı gelir');

-- ödeme: yıllık plan → premium, süre bitince ücretsiz
reset role;
select public.set_family_subscription(tst.v('fid')::uuid, 'premium', 'yearly', 'active', now() + interval '1 year', true, 'parentapp.premium.yearly', 'tx1');
set role authenticated;
select tst.check(public.family_access() ->> 'state' = 'premium' and public.family_access() ->> 'plan' = 'yearly', 'yıllık premium');
select tst.check((public.family_access() ->> 'full')::boolean, 'premium tam erişim');
insert into public.tasks (family_id, title, start_date) values (public.my_family_id(), 'Dördüncü', current_date);
select tst.check(public.family_premium(), 'family_premium premium der');
reset role;
select public.set_family_subscription(tst.v('fid')::uuid, 'premium', 'monthly', 'canceled', now() + interval '3 days', false, 'parentapp.premium.monthly', null);
set role authenticated;
select tst.check(public.family_access() ->> 'state' = 'premium' and public.family_access() ->> 'auto_renew' = 'false', 'iptal edilen abonelik dönem sonuna kadar sürer');
reset role;
update public.family_subscriptions set period_end = now() - interval '1 minute';
set role authenticated;
select tst.check(public.family_access() ->> 'state' = 'expired', 'dönem bitince ücretsiz plan');

-- aynı e-postayla (etiketle) silip yeniden kayıt: yeni deneme yok
reset role;
update public.families set trial_started_at = now() - interval '30 days' where id = tst.v('fid')::uuid;
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a9', 'Anne+yeni@example.com', now(), '{}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a9');
select tst.check(public.family_access() ->> 'state' = 'trial', 'ilk deneme tarihi korunur (anne ilk kayıt bugün: hâlâ deneme)');
reset role;
update public.trial_history set started_at = now() - interval '20 days';
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000aa', 'anne@example.com', now(), '{}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000aa');
select tst.check(public.family_access() ->> 'state' = 'expired', 'aynı e-postayla yeniden kayıt yeni deneme almaz');

-- anon erişemez
set role anon;
select tst.fails($$select public.family_access()$$, 'anon abonelik soramaz');
reset role;
select 'ABONELİK TESTLERİ GEÇTİ' as sonuc;
