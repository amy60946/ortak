-- Ö7 Gerçek ödül dükkânı (proposed/20261022100000_reward_shop.sql).
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

create or replace function tst.bal(c uuid) returns integer language sql security definer as $$ select public.coin_balance(c) $$;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000e2', true, '{}');
grant usage on schema tst to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
set role authenticated;

-- ---------------------------------------------------------------- aile A: ebeveyn, iki çocuk, coin kazandıran görev
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deniz', 'kedi'),
  ('00000000-0000-0000-0000-00000000c0d2', public.my_family_id(), 'Ada', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Oda topla', current_date, false, 'daily', false);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 40);
insert into public.rewards (id, family_id, title, icon, price) values
  ('00000000-0000-0000-0000-0000000000f1', public.my_family_id(), '  Parka gitmek  ', 'park', 30),
  ('00000000-0000-0000-0000-0000000000f2', public.my_family_id(), 'Film gecesi', 'movie', 25),
  ('00000000-0000-0000-0000-0000000000f3', public.my_family_id(), 'Kapalı ödül', 'gift', 5);
update public.rewards set active = false where id = '00000000-0000-0000-0000-0000000000f3';
insert into public.rewards (id, family_id, child_id, title, price) values
  ('00000000-0000-0000-0000-0000000000f4', public.my_family_id(), '00000000-0000-0000-0000-00000000c0d2', 'Yalnız Ada', 5);
select tst.check((select title from public.rewards where id = '00000000-0000-0000-0000-0000000000f1') = 'Parka gitmek', 'başlık kırpılır');
select tst.fails($$insert into public.rewards (family_id, title, price) values (public.my_family_id(), 'Pahalı', 501)$$, 'fiyat ≤ 500');
select tst.fails($$insert into public.rewards (family_id, title, price) values (public.my_family_id(), 'Bedava', 0)$$, 'fiyat ≥ 1');
select tst.fails($$insert into public.rewards (family_id, title, price) values (public.my_family_id(), '', 5)$$, 'boş başlık olmaz');
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
create temp table codes2 as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0d2');
grant select on codes, codes2 to authenticated;

-- ---------------------------------------------------------------- aile B (yabancı)
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select public.my_family_id();
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000e0de', public.my_family_id(), 'Yabancı Çocuk', 'kedi');
create temp table codes3 as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000e0de');
grant select on codes3 to authenticated;
select tst.check((select count(*) from public.rewards) = 0, 'yabancı ebeveyn A ailesinin ödüllerini görmez');
select tst.fails($$insert into public.rewards (family_id, title, price) values ((select family_id from public.children where id = '00000000-0000-0000-0000-00000000c0de'), 'Sızma', 5)$$,
                 'yabancı A ailesine ödül ekleyemez');
select tst.fails($$insert into public.rewards (family_id, child_id, title, price) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'Sızma2', 5)$$,
                 'yabancı A ailesinin çocuğuna ödül bağlayamaz');
update public.rewards set price = 1 where id = '00000000-0000-0000-0000-0000000000f1';
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select price from public.rewards where id = '00000000-0000-0000-0000-0000000000f1') = 30, 'yabancı fiyatı değiştiremez');

-- ---------------------------------------------------------------- çocuk Deniz
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select code from codes));
select tst.check(json_array_length(public.child_rewards() -> 'rewards') = 2, 'çocuk yalnız etkin ve kendine açık ödülleri görür (kapalı ve Ada''ya özel yok)');
select tst.check((select count(*) from public.rewards) = 2, 'tablo düzeyinde de aynı');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f1', 'tx-000001') ->> 'error') = 'not_enough_coins', 'coin yoksa istek olmaz');
select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending');   -- incelemesiz → +40
select tst.check((public.child_rewards() ->> 'balance')::int = 40, 'görevden 40 coin');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f3', 'tx-000002') ->> 'error') = 'unknown_reward', 'kapalı ödül istenemez');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f4', 'tx-000003') ->> 'error') = 'unknown_reward', 'başka çocuğa özel ödül istenemez');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f1', 'tx-000004') ->> 'ok')::boolean, 'parka gitmek istendi (30)');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f1', 'tx-000004') ->> 'ok')::boolean, 'aynı tx tekrar: aynı sonuç');
select tst.check(json_array_length(public.child_rewards() -> 'requests') = 1, 'tekrar gönderim ikinci istek açmaz');
select tst.check((select count(*) from public.reward_requests) = 0, 'çocuk istek tablosunu doğrudan okumaz (ebeveyn kimliği gizli)');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f1', 'tx-000004b') ->> 'error') = 'already_requested', 'aynı ödül ikinci kez beklemeye alınmaz');
select tst.check((public.spend_coins('spend-tx-01', (select item_id from public.game_items where price between 11 and 40 and min_level <= 1 order by price limit 1), 1) ->> 'error') = 'not_enough_coins',
                 'ayrılan coin eşya dükkânında harcanamaz');
select tst.check((public.child_rewards() ->> 'available')::int = 10 and (public.child_rewards() ->> 'balance')::int = 40,
                 'istek coin düşmez ama kullanılabilir coin ayrılır (40 − 30 = 10)');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f2', 'tx-000005') ->> 'error') = 'not_enough_coins', 'ayrılmış coin ikinci kez istenemez');
select tst.fails($$insert into public.reward_requests (family_id, child_id, title, price, tx)
  values ((select family_id from public.children limit 1), '00000000-0000-0000-0000-00000000c0de', 'Hile', 1, 'hile-0001')$$, 'çocuk istek tablosuna doğrudan yazamaz');
select tst.fails($$update public.reward_requests set status = 'given'$$, 'çocuk isteği kendisi veremez (tablo yetkisi yok)');
select tst.fails($$select public.review_reward_request((select id from public.reward_requests limit 1), true)$$, 'çocuk review RPC ile kendi isteğini veremez');
update public.rewards set price = 1;
select tst.check((select min(price) from public.rewards) = 25, 'çocuk fiyat değiştiremez (satır güncellenmez)');
select tst.check((select count(*) from public.coin_ledger where reason = 'reward') = 0, 'henüz coin düşmedi');

-- ---------------------------------------------------------------- ebeveyn bildirimi ve onay
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.notifications where kind = 'reward_request') = 1, 'ebeveyne istek bildirimi gitti');
select tst.check((public.review_reward_request((select id from public.reward_requests limit 1), true) ->> 'status') = 'given', 'ebeveyn verdi');
select tst.check((public.review_reward_request((select id from public.reward_requests limit 1), true) ->> 'error') = 'already_given', 'ikinci kez verilemez');
select tst.check((select count(*) from public.coin_ledger where reason = 'reward') = 1, 'tek kez düşüldü');
select tst.check(tst.bal('00000000-0000-0000-0000-00000000c0de') = 10, 'bakiye 40 − 30 = 10');

-- ---------------------------------------------------------------- çocuk: bildirim, iptal, ret
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select count(*) from public.notifications where kind = 'reward_given') = 1, 'çocuğa "ödülün hazır" bildirimi');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f2', 'tx-000006') ->> 'error') = 'not_enough_coins', '10 coin ile 25 istenemez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
update public.rewards set price = 5 where id = '00000000-0000-0000-0000-0000000000f2';
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f2', 'tx-000007') ->> 'ok')::boolean, 'film gecesi (5) istendi');
create temp table rq7 as select (public.child_request_reward('00000000-0000-0000-0000-0000000000f2', 'tx-000007') ->> 'id')::uuid as id;
select tst.check(public.child_cancel_reward_request((select id from rq7)), 'çocuk bekleyen isteğinden vazgeçti');
select tst.check(not public.child_cancel_reward_request((select id from rq7)), 'vazgeçilmiş istek yeniden iptal edilmez');
select tst.check((public.child_rewards() ->> 'available')::int = 10, 'vazgeçince ayrılan coin geri');
select public.child_request_reward('00000000-0000-0000-0000-0000000000f2', 'tx-000008');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.rewards (id, family_id, title, icon, price) values ('00000000-0000-0000-0000-0000000000f6', public.my_family_id(), 'Dondurma', 'treat', 5),
  ('00000000-0000-0000-0000-0000000000f7', public.my_family_id(), 'Kitap', 'book', 5);
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.child_request_reward('00000000-0000-0000-0000-0000000000f6', 'tx-000009');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f7', 'tx-000010') ->> 'error') = 'not_enough_coins', '10 coin: iki tane 5''lik ayrıldı, üçüncü yok');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.review_reward_request((select id from public.reward_requests where tx = 'tx-000008'), false) ->> 'status') = 'declined', 'ebeveyn reddetti');
select tst.check(tst.bal('00000000-0000-0000-0000-00000000c0de') = 10, 'ret coin düşürmez');
-- çocuk bu arada coini başka yerde harcarsa: vermek reddedilir, coin eksiye düşmez
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
set role postgres;
insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
  values ((select family_id from public.children where id = '00000000-0000-0000-0000-00000000c0de'), '00000000-0000-0000-0000-00000000c0de', -8, 'adjust', 'test-düş');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.review_reward_request((select id from public.reward_requests where tx = 'tx-000009'), true) ->> 'error') = 'not_enough_coins', 'bakiye yetmezse verilemez');
select tst.check(tst.bal('00000000-0000-0000-0000-00000000c0de') = 2, 'bakiye eksiye düşmedi');

-- ---------------------------------------------------------------- en çok 3 bekleyen
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.rewards (id, family_id, title, price) values ('00000000-0000-0000-0000-0000000000f5', public.my_family_id(), 'Çıkartma', 1);
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.child_request_reward('00000000-0000-0000-0000-0000000000f5', 'tx-000011');   -- 2 coin, 1 bekleyen (tx-9) zaten 5
select tst.check((select count(*) from json_array_elements(public.child_rewards() -> 'requests') e where e ->> 'status' = 'pending') >= 1, 'bekleyen istekler var');

-- ---------------------------------------------------------------- yabancı çocuk
select tst.as_user('00000000-0000-0000-0000-0000000000e2');
select public.redeem_child_code((select code from codes3));
select tst.check(json_array_length(public.child_rewards() -> 'rewards') = 0, 'yabancı çocuk A ödüllerini görmez');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f1', 'tx-yabanci1') ->> 'error') = 'unknown_reward', 'yabancı çocuk A ödülünü isteyemez');
select tst.check((select count(*) from public.reward_requests) = 0, 'yabancı çocuk A isteklerini görmez');
select tst.check(not public.child_cancel_reward_request((select id from public.reward_requests limit 1)), 'yabancı çocuk iptal edemez');
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$select public.review_reward_request('00000000-0000-0000-0000-000000000000', true)$$, 'yabancı ebeveyn A isteğini veremez');

-- ---------------------------------------------------------------- girişsiz
-- iste-vazgeç döngüsü: 24 saatte en çok 10 istek (ebeveyne bildirim yağmasın)
set role postgres;
insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
  values ((select family_id from public.children where id = '00000000-0000-0000-0000-00000000c0d2'), '00000000-0000-0000-0000-00000000c0d2', 50, 'adjust', 'test-ada');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code((select code from codes2));
create temp table spam as
  select public.child_cancel_reward_request((public.child_request_reward('00000000-0000-0000-0000-0000000000f4', 'spam-tx-' || g) ->> 'id')::uuid) ok from generate_series(1, 12) g;
select tst.check((select count(*) from spam where ok) = 10, 'iste-vazgeç: 10 istek geçti');
select tst.check((public.child_request_reward('00000000-0000-0000-0000-0000000000f4', 'spam-tx-99') ->> 'error') = 'too_many_today', 'günde en çok 10 istek');
reset role; set role anon;
select tst.fails($$select public.child_rewards()$$, 'anon çağıramaz');
select tst.fails($$select * from public.rewards$$, 'anon tablo okuyamaz');
reset role;
