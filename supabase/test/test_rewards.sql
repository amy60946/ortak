-- Güneş Taşı ile ödüller ve taş düşme (20261022130000_sun_stones_rewards.sql).
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

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}');
create or replace function tst.n(u uuid, k text) returns bigint language sql security definer as
  $$ select count(*) from public.notifications where user_id = u and kind = k $$;
grant execute on function tst.n(uuid, text) to authenticated;
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('fid', public.my_family_id()::text);
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'Efe', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Oda', current_date - 3, true, true),
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Diş', current_date - 3, true, true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'hard', 10),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'easy', 5);
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
insert into tst.kv select 'k2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c002');
insert into tst.kv select 'p', code from public.create_invite_code('parent', null);
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family(tst.v('p'));
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k1'));
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code(tst.v('k2'));

-- görev onayı taş verir (zor 3, kolay 1); geri alınca düşer
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', d::date, 'approved')
  from generate_series(current_date - 2, current_date, interval '1 day') d;
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', current_date, 'approved');
select tst.check(public.sun_stones_spendable('00000000-0000-0000-0000-00000000c001') = 10, 'zor ×3 + kolay = 10 taş');
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', current_date, 'pending');
select tst.check(public.sun_stones_spendable('00000000-0000-0000-0000-00000000c001') = 9, 'onay geri alınınca taş düşer');
reset role;
select tst.check(public.sun_stone_balance('00000000-0000-0000-0000-00000000c001') = 9, 'kazanılan (ada) = harcanabilir, henüz harcama yok');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c001') = 30, 'coin ayrı işler (3 × 10)');
select tst.fails($$insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 100, 'adjust', 'x')$$, 'defter doğrudan yazılamaz');

-- ödüller
insert into public.rewards (id, family_id, title, cost) values ('00000000-0000-0000-0000-0000000000b1', public.my_family_id(), '  Parkta 30 dakika ', 5);
insert into public.rewards (id, family_id, title, cost, child_ids) values ('00000000-0000-0000-0000-0000000000b2', public.my_family_id(), 'Film gecesi', 20, array['00000000-0000-0000-0000-00000000c001'::uuid]);
insert into public.rewards (id, family_id, title, cost) values ('00000000-0000-0000-0000-0000000000b4', public.my_family_id(), 'Dondurma', 3);
insert into public.rewards (id, family_id, title, cost, child_ids) values ('00000000-0000-0000-0000-0000000000b3', public.my_family_id(), 'Efe için bisiklet turu', 2, array['00000000-0000-0000-0000-00000000c002'::uuid]);
insert into public.rewards (id, family_id, title, kind, cost, unit, unit_amount, icon) values ('00000000-0000-0000-0000-0000000000b5', public.my_family_id(), 'Ekran süresi', 'exchange', 1, 'minute', 10, 'phone-portrait');
select tst.fails($$insert into public.rewards (family_id, title, kind, cost) values (public.my_family_id(), 'Eksik değişim', 'exchange', 1)$$, 'değişim ödülünde birim ve miktar zorunlu');
select tst.fails($$insert into public.rewards (family_id, title, cost, child_ids) values (public.my_family_id(), 'Yabancı çocuk', 1, array[gen_random_uuid()])$$, 'başka ailenin çocuğu seçilemez');
select tst.fails($$insert into public.rewards (family_id, title, cost, icon) values (public.my_family_id(), 'Simge', 1, '<script>')$$, 'simge anahtarı yalnız harf/tire');
select tst.check((select title from public.rewards where id = '00000000-0000-0000-0000-0000000000b1') = 'Parkta 30 dakika', 'başlık kırpılır');
select tst.check((select created_by from public.rewards limit 1) = auth.uid(), 'ekleyen sunucuda yazılır');
select tst.fails($$insert into public.rewards (family_id, title, cost) values (public.my_family_id(), 'Pahalı', 501)$$, 'fiyat 1–500');
select tst.fails($$update public.rewards set family_id = gen_random_uuid()$$, 'aile değiştirilemez');

-- doğrudan ver
select tst.check((public.give_reward('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000b1') ->> 'balance')::int = 4, 'ödül verildi, 5 taş düştü');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'reward_given') = 1, 'çocuğa ödül bildirimi');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a2', 'reward_given') = 1, 'diğer ebeveyne bilgi');
select tst.check(tst.err($$select public.give_reward('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000b2')$$) like 'Yeterli Güneş Taşı yok%', 'bakiye yetmezse verilmez');
select tst.fails($$select public.give_reward('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000b3')$$, 'başka çocuğa özel ödül verilemez');

-- taş düşme (ceza)
select tst.check((public.deduct_sun_stones('00000000-0000-0000-0000-00000000c001', 1, 'Kardeşine vurdu') ->> 'balance')::int = 3, '1 taş düşüldü');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'stones_deducted') = 1, 'çocuğa düşme bildirimi');
select tst.fails($$select public.deduct_sun_stones('00000000-0000-0000-0000-00000000c001', 4)$$, 'bakiyeden fazla düşülemez');
select tst.fails($$select public.deduct_sun_stones('00000000-0000-0000-0000-00000000c001', 0)$$, 'en az 1');
select tst.fails($$select public.deduct_sun_stones('00000000-0000-0000-0000-00000000c001', 101)$$, 'en çok 100');
select tst.check((select note from public.sun_stone_ledger where reason = 'penalty') = 'Kardeşine vurdu', 'neden kayıtta');
reset role;
select tst.check(public.sun_stone_balance('00000000-0000-0000-0000-00000000c001') = 9, 'ödül ve ceza adadaki kazanılan taşı değiştirmez');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.give_reward('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000b5', 2) ->> 'balance')::int = 1, 'değişim: 2 kez ekran süresi = 2 taş');
select tst.check((select amount from public.reward_requests where reward_id = '00000000-0000-0000-0000-0000000000b5') = 20, '20 dakika kaydedildi');
select tst.check((select note from public.sun_stone_ledger where reason = 'reward' order by id desc limit 1) = 'Ekran süresi · 20 dakika', 'hareket notunda miktar');
select tst.fails($$select public.give_reward('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000b1', 2)$$, 'eşya ödülü tek adet verilir');
-- bakiyeyi geri getir: iki görev onayı (+2)
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', current_date - 2, 'approved');
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', current_date - 3, 'approved');

-- çocuk ister, ebeveyn karar verir
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select count(*) from public.rewards) = 4, 'çocuk kendine açık ödülleri görür (kardeşe özel görünmez)');
select tst.check(public.sun_stones_spendable('00000000-0000-0000-0000-00000000c001') = 3, 'çocuk bakiyesini görür');
select tst.check((public.child_me() ->> 'sun_stones_spendable')::int = 3 and (public.child_me() ->> 'sun_stones')::int = 11, 'child_me iki sayıyı verir (ada 11, harcanabilir 3)');
select tst.fails($$select public.sun_stones_spendable('00000000-0000-0000-0000-00000000c002')$$, 'çocuk kardeşinin bakiyesini göremez');
select tst.check(tst.err($$select public.request_reward('00000000-0000-0000-0000-0000000000b2')$$) like 'Yeterli Güneş Taşı yok%', 'yetmeyen ödül istenemez');
select tst.fails($$select public.give_reward('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000000b1')$$, 'çocuk kendine ödül veremez');
select tst.fails($$select public.deduct_sun_stones('00000000-0000-0000-0000-00000000c002', 1)$$, 'çocuk kardeşinden taş düşemez');
select tst.fails($$insert into public.rewards (family_id, title, cost) values (public.my_any_family_id(), 'Bedava', 1)$$, 'çocuk ödül ekleyemez');
insert into tst.kv select 'rq', public.request_reward('00000000-0000-0000-0000-0000000000b4') ->> 'request_id';
select tst.check(public.request_reward('00000000-0000-0000-0000-0000000000b4') ->> 'request_id' = tst.v('rq'), 'aynı ödül için tek bekleyen istek');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'reward_request') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'reward_request') = 1, 'iki ebeveyne istek bildirimi');
select tst.check(public.sun_stones_spendable('00000000-0000-0000-0000-00000000c001') = 3, 'istek taşı hemen düşmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.deduct_sun_stones('00000000-0000-0000-0000-00000000c001', 1);
select tst.check(tst.err($$select public.decide_reward_request(tst.v('rq')::uuid, true)$$) like 'Yeterli Güneş Taşı yok%', 'onay anında bakiye yine denetlenir');
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', current_date, 'approved');
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', current_date - 1, 'approved');
select tst.check((public.decide_reward_request(tst.v('rq')::uuid, true) ->> 'balance')::int = 1, 'onaylandı, 3 taş düştü');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'reward_decided') = 1, 'çocuğa karar bildirimi');
select tst.fails($$select public.decide_reward_request(tst.v('rq')::uuid, true)$$, 'iki kez onaylanamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select status from public.reward_requests where id = tst.v('rq')::uuid) = 'approved', 'çocuk kararı görür');
select tst.check((select count(*) from public.sun_stone_ledger) = (select count(*) from public.sun_stone_ledger where child_id = public.my_child_id()), 'çocuk yalnız kendi defterini görür');

-- yabancı
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.rewards) + (select count(*) from public.reward_requests) + (select count(*) from public.sun_stone_ledger) = 0, 'yabancı hiçbir şey görmez');
select tst.fails($$select public.deduct_sun_stones('00000000-0000-0000-0000-00000000c001', 1)$$, 'yabancı taş düşemez');
select tst.fails($$select public.sun_stones_spendable('00000000-0000-0000-0000-00000000c001')$$, 'yabancı bakiyeyi göremez');

-- ücretsiz plan (anahtar açık + deneme bitti): ödül ekleme, verme, düşme kapalı; karar açık
reset role;
update public.app_config set value = value || '{"enforce": true}' where key = 'billing';
update public.families set trial_started_at = now() - interval '10 days' where id = tst.v('fid')::uuid;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(tst.err($$insert into public.rewards (family_id, title, cost) values (public.my_family_id(), 'Yeni', 1)$$) like 'Bu özellik Premium%', 'ücretsiz planda ödül eklenmez');
select tst.check(tst.err($$select public.deduct_sun_stones('00000000-0000-0000-0000-00000000c001', 1)$$) like 'Bu özellik Premium%', 'ücretsiz planda taş düşülmez');

set role anon;
select tst.fails($$select public.sun_stones_spendable('00000000-0000-0000-0000-00000000c001')$$, 'anon çağıramaz');
reset role;
select 'GÜNEŞ TAŞI TESTLERİ GEÇTİ' as sonuc;
