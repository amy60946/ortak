-- Sonsuz tarih koruması iki yeni tabloya da takılır (ortak CLAUDE.md kural 4; 22 Kasım 2026, GameApp penceresi).
-- Neden: migrations/20261102200000_child_push.sql (child_push_settings) ve migrations/20261110200000_review_child_code.sql
-- (review_child_codes) canlıya 22 Kasım'da, finite_time_guard_attach() çağıran 20261121100000_security_audit_fixes.sql'den
-- SONRA uygulandı; bu iki tabloda finite_time_guard tetikleyicisi yok. Boş kurulumda göç sırası bunu zaten kapatır.
-- Tekrar çalıştırılabilir: korumalı tabloya dokunmaz, eksik olanlara takar (dönen sayı = takılan tablo).
select public.finite_time_guard_attach();
