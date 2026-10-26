-- Uzay kıyafetleri sunucu kataloğunda (proposed/20261026100000_space_items_catalog.sql).
-- Beklenen değerler oyunun Resources/Data/items.json dosyasındaki "space": true eşyalardır (26 Ekim 2026).
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

-- ---------------------------------------------------------------- katalog: 9 uzay eşyası, fiyat ve seviye
create table tst.space (item_id text primary key, price integer not null, min_level integer not null);
insert into tst.space values
  ('outfit_astro', 80, 3), ('outfit_pilot', 80, 3), ('outfit_star', 80, 3),
  ('hat_astro_helmet', 40, 3), ('hat_pilot_goggles', 40, 3), ('hat_star_antenna', 40, 3),
  ('back_astro_pack', 45, 3), ('back_pilot_jetpack', 45, 3), ('back_star_cape', 45, 3);
grant select on tst.space to authenticated;

select tst.check(not exists (select 1 from tst.space s left join public.game_items g using (item_id) where g.item_id is null),
                 'her uzay eşyası game_items''ta var');
select tst.check(not exists (select 1 from tst.space s join public.game_items g using (item_id)
                             where g.price <> s.price or g.min_level <> s.min_level),
                 'her uzay eşyasının fiyatı ve seviyesi items.json ile aynı');
select tst.check((select count(*) from public.game_items) = 76, 'katalog 67 + 9 = 76 eşya');
select tst.check((select price from public.game_items where item_id = 'outfit_chicken') = 80
                 and (select min_level from public.game_items where item_id = 'hat_bucket') = 1, 'eski eşyalar değişmedi');

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Deniz', 'kedi');
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k1'));

-- çocuk okur, yazamaz; seviye 1'de kilitli (Sv 3)
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select count(*) from public.game_items g join tst.space s using (item_id)) = 9, 'çocuk uzay eşyalarının fiyatını okur');
select tst.fails($$update public.game_items set price = 1 where item_id = 'outfit_astro'$$, 'çocuk fiyatı değiştiremez');
insert into tst.kv select 'b1', coalesce(public.spend_coins('tx-space-0001', 'outfit_astro', 1) ->> 'error', 'ok');
select tst.check(tst.v('b1') in ('level_locked', 'not_enough_coins'), 'astronot takımı sunucuda bilinen eşya (unknown_item değil): ' || tst.v('b1'));
