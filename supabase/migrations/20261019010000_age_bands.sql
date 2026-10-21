-- Yaş bantları yeni sınırlar (karar: 19 Ekim 2026, kullanıcı; "oyun omurgası analizi" önerisi).
--   A 6–8 · B 9–12 · C 13–15   (eski: A 6–9 · B 10–12 · C 13–15)
-- Yalnız doğum gününden yapılan öneri değişir. Ebeveynin elle seçtiği bant (children.age_band) olduğu gibi kalır.
-- Bant yalnız oyunun zorluk/arayüz ayarıdır; raporlar ve analizler çocuğun gerçek yaşını (children.birthday) kullanır.
-- Tekrar çalıştırılabilir (create or replace).

create or replace function public.suggest_age_band(p_birthday date)
returns text language sql stable set search_path = '' as $$
  select case
    when p_birthday is null then 'A'
    when extract(year from age(current_date, p_birthday)) < 9 then 'A'
    when extract(year from age(current_date, p_birthday)) < 13 then 'B'
    else 'C'
  end
$$;

revoke execute on function public.suggest_age_band(date) from public, anon;
grant execute on function public.suggest_age_band(date) to authenticated;
