-- =====================================================================
-- Dört yaş grubu (XP takibi S1; kullanıcı kararı 22 Ekim 2026: "5 ve altı · 6–8 · 9–12 · 13 ve üstü"; ÖNERİ)
--   K: 5 ve altı · A: 6–8 · B: 9–12 · C: 13 ve üstü (C 19 Ekim'de kaldırılmıştı, yeni anlamıyla geri gelir).
--   - Kısıt ve set_child_age_band dört değeri kabul eder; doğum gününden öneri: <6 K, <9 A, <13 B, 13+ C.
--     Var olan kayıtlara dokunulmaz (A/B aynı anlamda kalır). Doğum günü yoksa öneri yine A.
--   - Seviye eşikleri gruba göre (oyunun levels.json "xpToNextByBand" ile aynı): küçük yaşta seviye daha az XP ister.
--     Sunucunun harcama seviye kilidi (child_level) çocuğun grubunun tablosunu kullanır; aksi hâlde küçük çocuk oyunda
--     açılan eşyayı alamazdı. B tablosu bugünküyle aynıdır (oyuncuların seviyesi değişmez).
-- Geriye uyum: eski oyun sürümü bilmediği 'K'yı A sayar (AgeBandProfile.Parse), 'C'yi zaten tanır.
-- Tekrar çalıştırılabilir.
-- =====================================================================

alter table public.children drop constraint if exists children_age_band_check;
alter table public.children add constraint children_age_band_check check (age_band in ('K', 'A', 'B', 'C'));

create or replace function public.suggest_age_band(p_birthday date)
returns text language sql stable set search_path = '' as $$
  select case
    when p_birthday is null then 'A'
    when extract(year from age(current_date, p_birthday)) < 6 then 'K'
    when extract(year from age(current_date, p_birthday)) < 9 then 'A'
    when extract(year from age(current_date, p_birthday)) < 13 then 'B'
    else 'C'
  end
$$;

create or replace function public.set_child_age_band(p_child_id uuid, p_band text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_band is not null and p_band not in ('K', 'A', 'B', 'C') then
    raise exception 'Geçersiz yaş bandı';
  end if;
  update public.children set age_band = p_band where id = p_child_id and family_id = public.my_family_id();
  if not found then
    raise exception 'Çocuk bulunamadı' using errcode = '42501';
  end if;
end $$;
revoke execute on function public.suggest_age_band(date) from public, anon;
grant execute on function public.suggest_age_band(date) to authenticated;
revoke execute on function public.set_child_age_band(uuid, text) from public, anon;
grant execute on function public.set_child_age_band(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- Gruba göre seviye eşikleri (Sv n için gereken toplam XP)
-- ---------------------------------------------------------------------
create table if not exists public.game_level_bands (
  band      text not null check (band in ('K', 'A', 'B', 'C')),
  level     integer not null check (level >= 1),
  total_xp  integer not null check (total_xp >= 0),
  primary key (band, level)
);
alter table public.game_level_bands enable row level security;
drop policy if exists "seviye bandı: herkes okur" on public.game_level_bands;
create policy "seviye bandı: herkes okur" on public.game_level_bands for select to authenticated using (true);
revoke insert, update, delete, truncate on public.game_level_bands from anon, authenticated;

-- xpToNext: K 70 95 125 170 230 315 425 570 770 1040 1405 1900 2565 3460 · A 85 115 155 210 280 380 515 695 940 1265 1710 2305 3115 4205
--           B (bugünkü) 100 135 182 246 332 448 605 817 1103 1489 2010 2714 3664 4946 · C 115 155 210 285 380 515 695 940 1270 1710 2310 3120 4215 5690
insert into public.game_level_bands (band, level, total_xp)
select b.band, s.lv, s.total
from (values
  ('K', array[70, 95, 125, 170, 230, 315, 425, 570, 770, 1040, 1405, 1900, 2565, 3460]),
  ('A', array[85, 115, 155, 210, 280, 380, 515, 695, 940, 1265, 1710, 2305, 3115, 4205]),
  ('B', array[100, 135, 182, 246, 332, 448, 605, 817, 1103, 1489, 2010, 2714, 3664, 4946]),
  ('C', array[115, 155, 210, 285, 380, 515, 695, 940, 1270, 1710, 2310, 3120, 4215, 5690])
) as b(band, steps)
cross join lateral (
  select g.lv, coalesce((select sum(x) from unnest(b.steps[1:g.lv - 1]) as x), 0)::integer as total
  from generate_series(1, 15) as g(lv)
) s
on conflict (band, level) do update set total_xp = excluded.total_xp;

create or replace function public.child_level(p_child_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  with c as (
    select coalesce(ch.age_band, public.suggest_age_band(ch.birthday)) as band from public.children ch where ch.id = p_child_id
  ), xp as (
    select coalesce((
      select case when jsonb_typeof(s.data -> 'Xp' -> 'TotalXp') = 'number' then (s.data -> 'Xp' ->> 'TotalXp')::numeric end
      from public.game_saves s where s.child_id = p_child_id), 0) as total
  )
  select coalesce(
    (select max(l.level) from public.game_level_bands l, c, xp where l.band = c.band and l.total_xp <= xp.total),
    (select max(l.level) from public.game_levels l, xp where l.total_xp <= xp.total),
    1)
$$;
revoke execute on function public.child_level(uuid) from public, anon, authenticated;
