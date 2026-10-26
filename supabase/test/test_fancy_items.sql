-- Komik eşyalar sunucu kataloğunda (migrations/20261024110000_fancy_items_catalog.sql; ekonomi.md E9).
-- Beklenen değerler oyunun Resources/Data/items.json dosyasındaki "fancy": true eşyalardır (24 Ekim 2026).
-- Oyun verisiyle canlı karşılaştırma ayrıca test_items_catalog.sql'de.
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
-- satır sayısı; yetki yoksa 0 (anon tabloyu hiç okuyamıyorsa da görmüyor sayılır)
create or replace function tst.rows_or_zero(sql text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute sql into n;
  return n;
exception when insufficient_privilege then
  return 0;
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

-- ---------------------------------------------------------------- katalog: 19 komik eşya, fiyat ve seviye
create table tst.fancy (item_id text primary key, price integer not null, min_level integer not null);
insert into tst.fancy values
  ('hat_bucket', 25, 1),
  ('hat_propeller', 30, 2), ('hat_watermelon', 30, 2), ('glasses_heart', 25, 2), ('socks_arm', 25, 2),
  ('hat_cake', 35, 3), ('hat_banana', 35, 3), ('glasses_nose', 30, 3), ('pompom', 30, 3),
  ('glasses_snorkel', 40, 4), ('mask_hero', 30, 4), ('float_flamingo', 50, 4),
  ('hat_crown_tilt', 45, 5), ('outfit_hula', 45, 5),
  ('hat_fishbowl', 60, 6), ('backpack_rocket', 70, 6),
  ('hat_shark', 70, 7),
  ('outfit_burger', 80, 8), ('outfit_chicken', 80, 8);
grant select on tst.fancy to authenticated;

select tst.check((select count(*) from tst.fancy) = 19, 'beklenen liste 19 eşya');
select tst.check(not exists (select 1 from tst.fancy f left join public.game_items g using (item_id) where g.item_id is null),
                 'her komik eşya game_items''ta var');
select tst.check(not exists (select 1 from tst.fancy f join public.game_items g using (item_id)
                             where g.price <> f.price or g.min_level <> f.min_level),
                 'her komik eşyanın fiyatı ve seviyesi items.json ile aynı');
select tst.check((select count(*) from public.game_items) = 76, 'katalog 48 + 19 komik + 9 uzay = 76 eşya (katalog büyürse bu sayı ve ekonomi.md §4 güncellenir)');
select tst.check((select count(*) from public.game_items where price <= 0) = 0, 'sıfır ya da eksi fiyat yok');
-- var olan 48 eşyaya dokunulmadı (örnekler)
select tst.check((select price from public.game_items where item_id = 'glasses_round') = 15
                 and (select min_level from public.game_items where item_id = 'set_star_cape') = 14,
                 'eski eşyalar değişmedi');

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c9', true, '{}');

-- ---------------------------------------------------------------- aile: çocuk, 50 coinlik günlük görev, bağlama kodu
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Oda', current_date - 3, true, 'daily', true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'hard', 50);
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k1'));

-- seviye eşikleri: 9–12 (B) tablosu (Sv 2 = 100 XP, Sv 4 = 417 XP)
reset role;
update public.children set age_band = 'B' where id = '00000000-0000-0000-0000-00000000c001';
set role authenticated;

-- ---------------------------------------------------------------- çocuk katalogu okur, yazamaz
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select count(*) from public.game_items g join tst.fancy f using (item_id)) = 19, 'çocuk komik eşyaların fiyatını okur');
select tst.fails($$update public.game_items set price = 1 where item_id = 'hat_bucket'$$, 'çocuk fiyatı değiştiremez');
select tst.fails($$insert into public.game_items (item_id, price, min_level) values ('hat_free', 1, 1)$$, 'çocuk eşya ekleyemez');
select tst.fails($$delete from public.game_items where item_id = 'hat_bucket'$$, 'çocuk eşya silemez');

-- coin yokken
select tst.check((public.spend_coins('tx-fancy-0000', 'hat_bucket', 1) ->> 'error') = 'not_enough_coins', 'bakiye 0: not_enough_coins (unknown_item değil)');

-- ebeveyn onaylar → 50 coin
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c001') = 50, 'onay +50');

-- ---------------------------------------------------------------- satın alma: kova şapka (25, Sv 1)
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
insert into tst.kv select 'b1', public.spend_coins('tx-fancy-0001', 'hat_bucket', 1)::text;
select tst.check((tst.v('b1')::jsonb ->> 'ok')::boolean, 'hat_bucket alındı (unknown_item değil)');
select tst.check(tst.v('b1')::jsonb -> 'error' = 'null'::jsonb, 'hata yok');
select tst.check((tst.v('b1')::jsonb ->> 'balance')::int = 25, 'yanıttaki bakiye 50 − 25 = 25');
select tst.check((public.child_me() ->> 'balance')::int = 25, 'child_me bakiyesi 25');
-- fiyat sunucudan: istemci fiyat göndermez, defterdeki tutar game_items.price
select tst.check((select amount from public.coin_ledger where reason = 'spend' and ref = 'tx-fancy-0001') =
                 -(select price from public.game_items where item_id = 'hat_bucket'), 'düşülen tutar sunucu fiyatı (25)');
select tst.check((select item_id || '×' || quantity from public.coin_ledger where reason = 'spend' and ref = 'tx-fancy-0001') = 'hat_bucket×1',
                 'defterde eşya ve adet');
-- aynı işlem ikinci kez düşülmez
select tst.check((public.spend_coins('tx-fancy-0001', 'hat_bucket', 1) ->> 'balance')::int = 25, 'aynı p_tx tekrar: bakiye değişmez');
select tst.check((select count(*) from public.coin_ledger where reason = 'spend') = 1, 'tek harcama satırı');

-- ---------------------------------------------------------------- seviye kilidi ve bakiye
select tst.check((public.spend_coins('tx-fancy-0002', 'glasses_heart', 1) ->> 'error') = 'level_locked', 'Sv 1: kalp gözlük (Sv 2) kilitli');
select tst.check((public.spend_coins('tx-fancy-0003', 'hat_shark', 1) ->> 'error') = 'level_locked', 'Sv 1: köpekbalığı kapüşonu (Sv 7) kilitli');
select public.game_save_put('{"Xp": {"TotalXp": 100}}');
select tst.check((public.spend_coins('tx-fancy-0004', 'glasses_heart', 1) ->> 'ok')::boolean, 'Sv 2: kalp gözlük alındı');
select tst.check((public.child_me() ->> 'balance')::int = 0, 'bakiye 25 − 25 = 0');
select tst.check((public.spend_coins('tx-fancy-0005', 'socks_arm', 1) ->> 'error') = 'not_enough_coins', 'bakiye 0: kol çorabı alınamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date - 1, 'approved');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.spend_coins('tx-fancy-0006', 'float_flamingo', 1) ->> 'error') = 'level_locked', 'Sv 2: flamingo simidi (Sv 4) kilitli');
select public.game_save_put('{"Xp": {"TotalXp": 417}}');
select tst.check((public.spend_coins('tx-fancy-0007', 'float_flamingo', 1) ->> 'ok')::boolean, 'Sv 4: flamingo simidi (50) alındı');
select tst.check((public.child_me() ->> 'balance')::int = 0, 'bakiye 50 − 50 = 0');
select tst.check((select coalesce(sum(-amount), 0) from public.coin_ledger where reason = 'spend') = 25 + 25 + 50, 'toplam harcama 100');

-- bağlı olmayan oturum alamaz
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.fails($$select public.spend_coins('tx-fancy-0099', 'hat_bucket', 1)$$, 'bağlı olmayan oturum harcayamaz');

-- girişsiz (anon) katalogu okuyamaz, harcayamaz
reset role;
set role anon;
select tst.check(tst.rows_or_zero('select count(*) from public.game_items') = 0, 'anon katalogu görmez');
select tst.fails($$select public.spend_coins('tx-fancy-0098', 'hat_bucket', 1)$$, 'anon harcayamaz');
reset role;

select 'KOMİK EŞYA KATALOĞU TESTLERİ GEÇTİ' as sonuc;
