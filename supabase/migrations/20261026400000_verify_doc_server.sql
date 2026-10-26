-- =====================================================================
-- Uzman belgesine yönetici erişimi yalnız sunucudan (öneri, 26 Ekim 2026; DURUM "DENETİM DÜZELTMELERİ" 4a, kullanıcı onayı)
--   Önce: support/owner + iki adımlı yönetici `verify` kovasını doğrudan okuyup silebiliyordu (panel dışından açarsa
--   denetim kaydı düşmüyordu). Şimdi: kova yöneticiye kapalı; belgeyi Edge Function `verify-doc` verir
--   (admin_verification_open → denetim kaydı → 2 dk imzalı bağlantı), karar sonrası dosyaları da o siler (storage_trash).
-- Önkoşul: proposed/20261026300000_review_fixes.sql (storage_trash). Sıra: review_fixes → bu dosya → verify-doc yayını.
-- Tekrar çalıştırılabilir.
-- =====================================================================

drop policy if exists "doğrulama belgesi: yönetici okur" on storage.objects;
drop policy if exists "doğrulama belgesi: yönetici siler" on storage.objects;
-- admin_can_review() kalır: verify-doc silme yetkisini onunla denetler.
