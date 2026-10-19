-- =====================================================================
-- Yaş bantları: iki bant (19 Ekim 2026; kullanıcı kararı; uygulandı)
--   A: 6–8 yaş · B: 9–12 yaş. C bandı (13–15) kaldırılır.
--   - Var olan 'C' kayıtları 'B' yapılır (en büyük bant).
--   - Doğum gününden öneri: <9 → A, 9+ → B. Doğum günü yoksa en güvenli bant A.
-- Tekrar çalıştırılabilir.
-- =====================================================================

update public.children set age_band = 'B' where age_band = 'C';

alter table public.children drop constraint if exists children_age_band_check;
alter table public.children add constraint children_age_band_check check (age_band in ('A', 'B'));

create or replace function public.suggest_age_band(p_birthday date)
returns text language sql stable set search_path = '' as $$
  select case
    when p_birthday is null then 'A'
    when extract(year from age(current_date, p_birthday)) < 9 then 'A'
    else 'B'
  end
$$;

create or replace function public.set_child_age_band(p_child_id uuid, p_band text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_band is not null and p_band not in ('A', 'B') then
    raise exception 'Geçersiz yaş bandı';
  end if;
  update public.children set age_band = p_band where id = p_child_id and family_id = public.my_family_id();
  if not found then
    raise exception 'Çocuk bulunamadı' using errcode = '42501';
  end if;
end $$;
