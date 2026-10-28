-- Ad kararı (kullanıcı, 28 Ekim 2026; akislar.md 5.5) devamı, ParentApp penceresinin isteği: ücretsiz aile sınırının
-- hata metni "Bu özellik Premium üyelikte: zor an kaydı" → "…: davranış kaydı". Yalnız metin; yetki ve tetikleyici
-- değişmez (create or replace, mevcut tetikleyici aynı fonksiyonu çağırır). Tekrar çalıştırılabilir.
-- Önkoşul: migrations/20261022110000_subscriptions.sql (require_full_access).

create or replace function public.abc_events_free_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_full_access(new.family_id, 'davranış kaydı');
  return new;
end $$;
revoke execute on function public.abc_events_free_limit() from public, anon, authenticated;
