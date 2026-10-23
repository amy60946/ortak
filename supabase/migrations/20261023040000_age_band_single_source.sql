-- =====================================================================
-- Yaş grubu tek kaynak (öneri, 23 Ekim 2026; kullanıcı: "yaş grupları üç uygulamada doğru hizalansın,
-- ileride arka uçta ve ayrıntılı analizlerde sorun olmasın").
--   K: 5 ve altı · A: 6–8 · B: 9–12 · C: 13 ve üstü (sozlesme/durumlar.md §4).
--   1) Sınırların tek yeri: public.age_band(doğum günü, gün). Gün verilmezse Türkiye'nin bugünü (uygulamalarla aynı gün;
--      sunucunun UTC günü gece 00–03 arası bir gün geride kalıyordu). Doğum günü yoksa A.
--   2) suggest_age_band ve child_age_band bunu kullanır. children.age_band yalnız ebeveynin bilerek seçtiği gruptur;
--      null = otomatik (çocuk büyüdükçe grup kendiliğinden değişir). Giriş kodu, child_me ve seviye kilidi aynı sonucu verir.
--   3) Seviye düşmez: grup büyüyünce (ör. 9. doğum günü) aynı XP daha düşük seviyeye denk gelebiliyordu. child_level artık
--      ulaşılan en yüksek seviyeyi korur (oyun kaydındaki Xp.BestLevel; aynı XP ile en düşük eşikli K tablosunun
--      verebileceğinden yüksek olamaz, yani kayıttaki TotalXp'den daha fazla güven gerektirmez).
--   4) Analiz için age_years(doğum günü, gün): raporlar ve ayrıntılı analizler olay günündeki gerçek yaşı kullanır,
--      kaydedilmiş gruba (değişebilir, geçmişi yok) bakmaz.
-- Tekrar çalıştırılabilir.
-- =====================================================================

create or replace function public.age_years(p_birthday date, p_on date default null)
returns integer language sql stable set search_path = '' as $$
  select case when p_birthday is null then null
    else extract(year from age(coalesce(p_on, (now() at time zone 'Europe/Istanbul')::date), p_birthday))::integer end
$$;

create or replace function public.age_band(p_birthday date, p_on date default null)
returns text language sql stable set search_path = '' as $$
  select case
    when p_birthday is null then 'A'
    when public.age_years(p_birthday, p_on) < 6 then 'K'
    when public.age_years(p_birthday, p_on) < 9 then 'A'
    when public.age_years(p_birthday, p_on) < 13 then 'B'
    else 'C'
  end
$$;

create or replace function public.suggest_age_band(p_birthday date)
returns text language sql stable set search_path = '' as $$
  select public.age_band(p_birthday, null)
$$;

create or replace function public.child_age_band(p_child_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(c.age_band, public.age_band(c.birthday, null)) from public.children c where c.id = p_child_id
$$;

create or replace function public.child_level(p_child_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  with xp as (
    select coalesce((
      select case when jsonb_typeof(s.data -> 'Xp' -> 'TotalXp') = 'number' then (s.data -> 'Xp' ->> 'TotalXp')::numeric end
      from public.game_saves s where s.child_id = p_child_id), 0) as total,
    coalesce((
      select case when jsonb_typeof(s.data -> 'Xp' -> 'BestLevel') = 'number' then (s.data -> 'Xp' ->> 'BestLevel')::numeric end
      from public.game_saves s where s.child_id = p_child_id), 1) as best
  ), now_lv as (
    select coalesce(
      (select max(l.level) from public.game_level_bands l, xp where l.band = public.child_age_band(p_child_id) and l.total_xp <= xp.total),
      (select max(l.level) from public.game_levels l, xp where l.total_xp <= xp.total),
      1) as lv
  ), cap as (
    select coalesce((select max(l.level) from public.game_level_bands l, xp where l.band = 'K' and l.total_xp <= xp.total), 1) as lv
  )
  select greatest(now_lv.lv, least(floor(xp.best)::integer, cap.lv), 1) from xp, now_lv, cap
$$;

revoke execute on function public.age_years(date, date) from public, anon;
grant execute on function public.age_years(date, date) to authenticated;
revoke execute on function public.age_band(date, date) from public, anon;
grant execute on function public.age_band(date, date) to authenticated;
revoke execute on function public.suggest_age_band(date) from public, anon;
grant execute on function public.suggest_age_band(date) to authenticated;
revoke execute on function public.child_age_band(uuid) from public, anon, authenticated;
revoke execute on function public.child_level(uuid) from public, anon, authenticated;
