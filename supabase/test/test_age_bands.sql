-- Yaş grupları: K ≤5 · A 6–8 · B 9–12 · C 13+ (20261022220000_age_bands_four + 20261023040000_age_band_single_source).
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
select tst.check(public.suggest_age_band(((now() at time zone 'Europe/Istanbul')::date - interval '5 years')::date) = 'K', '5 yaş → K (5 ve altı)');
select tst.check(public.suggest_age_band(((now() at time zone 'Europe/Istanbul')::date - interval '6 years')::date) = 'A', '6 yaş → A');
select tst.check(public.suggest_age_band(((now() at time zone 'Europe/Istanbul')::date - interval '9 years' + interval '1 day')::date) = 'A', '9 yaşına bir gün var → A');
select tst.check(public.suggest_age_band(((now() at time zone 'Europe/Istanbul')::date - interval '9 years')::date) = 'B', '9 yaş → B');
select tst.check(public.suggest_age_band(((now() at time zone 'Europe/Istanbul')::date - interval '12 years')::date) = 'B', '12 yaş → B');
select tst.check(public.suggest_age_band(((now() at time zone 'Europe/Istanbul')::date - interval '13 years')::date) = 'C', '13 yaş → C (13 ve üstü)');

-- tek kaynak: age_band(doğum günü, gün) ve age_years; gün verilirse o günün yaşı (analiz: olay günü)
select tst.check(public.age_band('2020-03-10', '2026-03-09') = 'K', '6. doğum gününden bir gün önce K');
select tst.check(public.age_band('2020-03-10', '2026-03-10') = 'A', '6. doğum günü A');
select tst.check(public.age_band('2017-03-10', '2026-03-10') = 'B', '9. doğum günü B');
select tst.check(public.age_band('2013-03-10', '2026-03-09') = 'B', '13 yaşına bir gün var B');
select tst.check(public.age_band('2013-03-10', '2026-03-10') = 'C', '13. doğum günü C');
select tst.check(public.age_band(null, '2026-03-10') = 'A', 'doğum günü yoksa A');
select tst.check(public.age_years('2015-10-23', '2026-10-22') = 10 and public.age_years('2015-10-23', '2026-10-23') = 11, 'age_years doğum gününde artar');
select tst.check(public.age_years(null) is null, 'doğum günü yoksa yaş yok');
select tst.check(public.suggest_age_band('2015-01-01') = public.age_band('2015-01-01'), 'öneri = tek kaynak');

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
-- seviye düşmez: K'de 170 XP → Sv3; grup A olunca aynı XP Sv2'ye denk gelir, kayıttaki en yüksek seviye (3) korunur
update public.children set age_band = 'K' where id = '00000000-0000-0000-0000-00000000c0de';
update public.game_saves set data = '{"Xp": {"TotalXp": 170, "BestLevel": 3}}' where child_id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 3, 'K: 170 XP → Sv3');
update public.children set age_band = 'A' where id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 3, 'grup A olunca seviye düşmez (en yüksek 3)');
update public.game_saves set data = '{"Xp": {"TotalXp": 170}}' where child_id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 2, 'en yüksek seviye kaydı yoksa A tablosu (Sv2)');
update public.game_saves set data = '{"Xp": {"TotalXp": 170, "BestLevel": 9}}' where child_id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 3, 'kayıttaki en yüksek seviye XP''nin verebileceğini aşamaz (K tablosu: 3)');
update public.game_saves set data = '{"Xp": {"TotalXp": 170, "BestLevel": "x"}}' where child_id = '00000000-0000-0000-0000-00000000c0de';
select tst.check(public.child_level('00000000-0000-0000-0000-00000000c0de') = 2, 'bozuk en yüksek seviye yok sayılır');
delete from public.game_saves where child_id = '00000000-0000-0000-0000-00000000c0de';
update public.children set age_band = null where id = '00000000-0000-0000-0000-00000000c0de';

reset role;
-- eski iki bant göçü canlıda yeniden çalıştırılsa bile bir şey bozmaz (dört grup kurulu: atlanır)
update public.children set age_band = 'C' where id = '00000000-0000-0000-0000-00000000c0de';
\ir ../migrations/20261019110000_age_bands.sql
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'C', 'eski göç C kaydını bozmaz');
select tst.check(public.child_age_band('00000000-0000-0000-0000-00000000c0de') = 'C', 'child_age_band C');
select tst.check(public.suggest_age_band('2020-01-01') in ('K', 'A'), 'öneri dört grupla kalır');
update public.children set age_band = 'K' where id = '00000000-0000-0000-0000-00000000c0de';
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'K', 'kısıt dört grubu kabul etmeye devam eder');

-- tek seferlik "Otomatik"e çevirme (20261023050000): elle kayıtlı grup silinir; dosya yeniden çalışırsa yeni seçim korunur
delete from public.one_time_jobs where key = 'age_band_reset_auto_20261023';
update public.children set age_band = 'C' where id = '00000000-0000-0000-0000-00000000c0de';
\ir ../proposed/20261023050000_age_band_reset_auto.sql
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') is null, 'elle kayıtlı grup Otomatik''e döndü');
select tst.check(public.child_age_band('00000000-0000-0000-0000-00000000c0de') = public.age_band((select birthday from public.children where id = '00000000-0000-0000-0000-00000000c0de')), 'grup doğum gününden');
update public.children set age_band = 'B' where id = '00000000-0000-0000-0000-00000000c0de';
\ir ../proposed/20261023050000_age_band_reset_auto.sql
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'B', 'yeniden çalışınca ebeveynin yeni seçimi korunur');
select tst.check((select relrowsecurity from pg_class where oid = 'public.one_time_jobs'::regclass), 'one_time_jobs RLS açık');
set role authenticated;
select tst.fails($$select * from public.one_time_jobs$$, 'uygulama tek seferlik işler tablosunu okuyamaz');
reset role;

select 'TÜM YAŞ BANDI TESTLERİ GEÇTİ' as sonuc;
