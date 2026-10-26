-- =====================================================================
-- Uzay kıyafetleri sunucu kataloğunda (UYGULANDI 26 Ekim 2026, kullanıcı Supabase SQL Editor; öneri 26 Ekim 2026; kullanıcı onayı: "kıyafetleri dükkânda da sat")
--
-- Gezegen Koşusu için yapılan üç uzay takımı (klasik astronot, roket pilotu, yıldız kaşifi) ve her birinin kask/başlık ve
-- sırt parçası oyunun dükkânına eklendi (game-app Resources/Data/items.json, "space": true; 9 eşya, Sv 3).
-- Sunucunun fiyat listesinde (game_items) olmazlarsa gerçek sunucuda çocuk bunlardan birini alınca spend_coins 'unknown_item'
-- döner. Bu öneri 9 eşyayı items.json'daki fiyat ve seviyeyle game_items'a ekler. Fiyatı yine sunucu belirler; seviye kilidi
-- (min_level) sunucuda da denetlenir. Var olan 67 eşyaya dokunulmaz. Yeni tablo, sütun ya da fonksiyon yok.
-- Koşu başında çocuğun ücretsiz seçtiği takım yalnız koşuda giyilir (oyun içi, satın alma değil): sunucuya gitmez.
--
-- Uygulama: Supabase → SQL Editor → bu dosyanın tamamı → Run. Tekrar çalıştırılabilir (on conflict … do update).
-- Test: supabase/test/test_space_items.sql, test_items_catalog.sql (bash supabase/test/run.sh).
-- =====================================================================

insert into public.game_items (item_id, price, min_level) values
  ('outfit_astro', 80, 3), ('outfit_pilot', 80, 3), ('outfit_star', 80, 3),
  ('hat_astro_helmet', 40, 3), ('hat_pilot_goggles', 40, 3), ('hat_star_antenna', 40, 3),
  ('back_astro_pack', 45, 3), ('back_pilot_jetpack', 45, 3), ('back_star_cape', 45, 3)
on conflict (item_id) do update set price = excluded.price, min_level = excluded.min_level;
