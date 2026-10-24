-- Hoş geldin coini (migrations/20261024100000_welcome_coins_first_reward.sql).
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
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c9', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}');

-- fiyat güvencesi: 20 coin en ucuz Sv1 giyilebilir eşyaya (aksesuar/kıyafet) yetmeli
select tst.check((select min(price) from public.game_items
                   where min_level = 1 and item_id !~ '^(food|clean|seed|home|decor)_') <= 20,
                 'en ucuz Sv1 giyilebilir eşya 20 coin ya da daha ucuz');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'Efe', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Oda', current_date - 3, true, true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'easy', 5);
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
insert into tst.kv select 'k2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c002');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k1'));
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code(tst.v('k2'));

-- ilk çağrı 20 coin yazar
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.child_me() ->> 'balance')::int = 0, 'başta bakiye 0');
insert into tst.kv select 'w1', public.claim_welcome_coins()::text;
select tst.check((tst.v('w1')::jsonb ->> 'ok')::boolean, 'ilk çağrı ok');
select tst.check((tst.v('w1')::jsonb ->> 'coins')::int = 20, 'ilk çağrı 20 coin');
select tst.check((tst.v('w1')::jsonb ->> 'balance')::int = 20, 'yanıttaki bakiye 20');
select tst.check(tst.v('w1')::jsonb -> 'error' = 'null'::jsonb, 'hata yok (null)');
select tst.check((public.child_me() ->> 'balance')::int = 20, 'child_me bakiyesi hoş geldin coinini içerir');
select tst.check((select count(*) from public.coin_ledger where reason = 'welcome') = 1
                 and (select amount from public.coin_ledger where reason = 'welcome') = 20, 'çocuk kendi defterinde tek welcome satırını görür');

-- ikinci çağrı yazmaz
insert into tst.kv select 'w2', public.claim_welcome_coins()::text;
select tst.check(not (tst.v('w2')::jsonb ->> 'ok')::boolean, 'ikinci çağrı ok=false');
select tst.check(tst.v('w2')::jsonb ->> 'error' = 'already_claimed', 'ikinci çağrı already_claimed');
select tst.check((tst.v('w2')::jsonb ->> 'coins')::int = 0, 'ikinci çağrıda coin 0');
select tst.check((tst.v('w2')::jsonb ->> 'balance')::int = 20, 'ikinci çağrıda bakiye değişmez');
select tst.check((public.claim_welcome_coins() ->> 'error') = 'already_claimed', 'üçüncü çağrı da yazmaz');
select tst.check((public.child_me() ->> 'balance')::int = 20, 'bakiye hâlâ 20');

-- çocuk defteri doğrudan yazamaz
select tst.fails($$insert into public.coin_ledger (family_id, child_id, amount, reason, ref) values (public.my_any_family_id(), public.my_child_id(), 20, 'welcome', 'x')$$, 'çocuk welcome satırını doğrudan yazamaz');

-- hoş geldin coini Sv1 aksesuarına yeter (glasses_round 15)
select tst.check((public.spend_coins('tx-welcome-0001', 'glasses_round', 1) ->> 'ok')::boolean, 'ilk aksesuar alındı');
select tst.check((public.child_me() ->> 'balance')::int = 5, 'kalan 5 coin');

-- görev onayı ve geri alma yalnız görev coinini etkiler
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c001') = 10, 'ebeveyn: 20 + 5 − 15 = 10');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date, 'pending');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c001') = 5, 'onay geri alınınca yalnız görevin 5 coini düşer');
select tst.check((select amount from public.coin_ledger where reason = 'task_undo') = -5, 'geri alma tutarı yalnız görev (welcome sayılmaz)');
select tst.check((select count(*) from public.coin_ledger where reason = 'welcome' and child_id = '00000000-0000-0000-0000-00000000c001') = 1, 'ebeveyn welcome satırını görür (aile okur)');

-- ebeveyn çocuk adına alamaz
select tst.fails($$select public.claim_welcome_coins()$$, 'ebeveyn hoş geldin coini alamaz');
select tst.check((select count(*) from public.coin_ledger where reason = 'welcome') = 1, 'ebeveyn çağrısı yazmadı');

-- kardeş ayrı: kendi 20 coini
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check((public.claim_welcome_coins() ->> 'coins')::int = 20, 'kardeş kendi hoş geldin coinini alır');
select tst.check((public.child_me() ->> 'balance')::int = 20, 'kardeşin bakiyesi 20');
select tst.check((select count(*) from public.coin_ledger) = 1, 'kardeş yalnız kendi satırını görür');

-- bağlı çocuğu olmayan oturum ve yabancı ebeveyn
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.fails($$select public.claim_welcome_coins()$$, 'bağlı olmayan anonim oturum alamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$select public.claim_welcome_coins()$$, 'yabancı ebeveyn alamaz');
select tst.check((select count(*) from public.coin_ledger) = 0, 'yabancı defteri görmez');

-- bağlantı kaldırılıp yeniden kurulunca da ikinci kez verilmez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.unlink_child_device('00000000-0000-0000-0000-00000000c001');
insert into tst.kv select 'k3', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select public.redeem_child_code(tst.v('k3'));
select tst.check((public.claim_welcome_coins() ->> 'error') = 'already_claimed', 'yeni cihazda aynı çocuk tekrar alamaz');

-- girişsiz (anon) çağıramaz
reset role;
select tst.check(not has_function_privilege('anon', 'public.claim_welcome_coins()', 'execute'), 'anon yetkisi yok');
select tst.check(has_function_privilege('authenticated', 'public.claim_welcome_coins()', 'execute'), 'giriş yapan çağırabilir');
set role anon;
select tst.fails($$select public.claim_welcome_coins()$$, 'anon çağıramaz');
reset role;

-- veritabanı düzeyinde de çocuk başına tek satır (ref farklı olsa bile)
select tst.fails($$insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
                   select family_id, id, 20, 'welcome', 'baska' from public.children where id = '00000000-0000-0000-0000-00000000c002'$$,
                 'ikinci welcome satırı benzersizlik kuralına takılır');
select tst.fails($$insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
                   select family_id, id, 20, 'gift', 'x' from public.children where id = '00000000-0000-0000-0000-00000000c002'$$,
                 'bilinmeyen neden yazılamaz');

select 'HOŞ GELDİN COİNİ TESTLERİ GEÇTİ' as sonuc;
