-- Yaş bantları (20261019110000_age_bands.sql): A 6–8, B 9–12; C yok.
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

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

-- öneri kuralı (sınırlar) — dört grup (migrations/20261022220000_age_bands_four.sql)
select tst.check(public.suggest_age_band(null) = 'A', 'doğum günü yok → A');
select tst.check(public.suggest_age_band((current_date - interval '5 years')::date) = 'K', '5 yaş → K (5 ve altı)');
select tst.check(public.suggest_age_band((current_date - interval '6 years')::date) = 'A', '6 yaş → A');
select tst.check(public.suggest_age_band((current_date - interval '9 years' + interval '1 day')::date) = 'A', '9 yaşına bir gün var → A');
select tst.check(public.suggest_age_band((current_date - interval '9 years')::date) = 'B', '9 yaş → B');
select tst.check(public.suggest_age_band((current_date - interval '12 years')::date) = 'B', '12 yaş → B');
select tst.check(public.suggest_age_band((current_date - interval '13 years')::date) = 'C', '13 yaş → C (13 ve üstü)');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar, birthday)
  values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Nazlı', 'flamingo', current_date - interval '7 years');
select tst.fails($$update public.children set age_band = 'X' where id = '00000000-0000-0000-0000-00000000c0de'$$, 'bilinmeyen bant yazılamaz');
select tst.fails($$select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', 'D')$$, 'set_child_age_band bilinmeyeni reddeder');
select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', 'K');
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'K', 'K yazılır');
select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', 'C');
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'C', 'C yazılır');
select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', 'B');
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'B', 'B yazılır');
select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', null);
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') is null, 'boşaltılabilir (doğum gününden önerilir)');

-- seviye eşikleri gruba göre (harcama seviye kilidi)
reset role;
insert into public.game_saves (child_id, family_id, data)
  select id, family_id, '{"Xp": {"TotalXp": 120}}'::jsonb from public.children where id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 2, '7 yaş (A, öneri): 120 XP → Sv2 (A eşiği 85)');
update public.children set age_band = 'K' where id = '00000000-0000-0000-0000-00000000c0de';
update public.game_saves set data = '{"Xp": {"TotalXp": 170}}' where child_id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 3, 'K: 170 XP → Sv3 (70 + 95 = 165)');
update public.children set age_band = 'B' where id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 2, 'B: 170 XP → Sv2 (bugünkü tablo, 235 gerekir)');
update public.children set age_band = 'C' where id = '00000000-0000-0000-0000-00000000c0de';
update public.game_saves set data = '{"Xp": {"TotalXp": 114}}' where child_id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 1, 'C: 114 XP → Sv1 (115 gerekir)');
select tst.check((select total_xp from public.game_level_bands where band = 'B' and level = 15) = 18791, 'B tablosu bugünküyle aynı');
select tst.check((select count(*) from public.game_level_bands) = 60, '4 grup × 15 seviye');
delete from public.game_saves where child_id = '00000000-0000-0000-0000-00000000c0de';
update public.children set age_band = null where id = '00000000-0000-0000-0000-00000000c0de';

reset role;
-- var olan C kaydı göçle B olur (göç ikinci kez çalıştırılınca da)
alter table public.children drop constraint children_age_band_check;
update public.children set age_band = 'C' where id = '00000000-0000-0000-0000-00000000c0de';
\ir ../migrations/20261019110000_age_bands.sql
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'B', 'eski C kaydı B olur');
select tst.check(public.child_age_band('00000000-0000-0000-0000-00000000c0de') = 'B', 'child_age_band B');

select 'TÜM YAŞ BANDI TESTLERİ GEÇTİ' as sonuc;
