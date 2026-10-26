-- =====================================================================
-- Yaş bantları: iki bant (19 Ekim 2026; kullanıcı kararı; uygulandı) — SONRADAN DEĞİŞTİ:
--   22 Ekim 2026'dan beri dört grup (20261022220000_age_bands_four.sql), 23 Ekim'den beri tek kaynak
--   (20261023040000_age_band_single_source.sql). Bu dosya yalnız sıradaki göçlerin temiz kurulumda doğru çalışması için durur.
--   O günkü hâli: A 6–8 · B 9–12; var olan 'C' kayıtları 'B' yapılırdı; öneri <9 → A, 9+ → B.
-- Güvenli: dört grup kurulmuşsa (game_level_bands var) hiçbir şey yapmaz; canlıda yeniden çalıştırmak C/K kayıtlarını bozmaz.
-- =====================================================================

do $migration$
begin
  if to_regclass('public.game_level_bands') is not null then
    raise notice 'dört yaş grubu kurulu: eski iki bant göçü atlandı';
    return;
  end if;

  update public.children set age_band = 'B' where age_band = 'C';

  alter table public.children drop constraint if exists children_age_band_check;
  alter table public.children add constraint children_age_band_check check (age_band in ('A', 'B'));

  execute $f$
    create or replace function public.suggest_age_band(p_birthday date)
    returns text language sql stable set search_path = '' as $b$
      select case
        when p_birthday is null then 'A'
        when extract(year from age(current_date, p_birthday)) < 9 then 'A'
        else 'B'
      end
    $b$
  $f$;

  execute $f$
    create or replace function public.set_child_age_band(p_child_id uuid, p_band text)
    returns void language plpgsql security definer set search_path = '' as $b$
    begin
      if p_band is not null and p_band not in ('A', 'B') then
        raise exception 'Geçersiz yaş bandı';
      end if;
      update public.children set age_band = p_band where id = p_child_id and family_id = public.my_family_id();
      if not found then
        raise exception 'Çocuk bulunamadı' using errcode = '42501';
      end if;
    end $b$
  $f$;
end $migration$;
