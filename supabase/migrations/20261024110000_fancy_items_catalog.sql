-- =====================================================================
-- Komik eşyalar sunucu kataloğunda (öneri, 24 Ekim 2026; ekonomi.md E9)
--
-- Oyunun dükkânına 23 Ekim 2026'da 19 "komik eşya" eklendi (game-app Resources/Data/items.json, "fancy": true;
-- F1–F17). Sunucunun fiyat listesinde (game_items) yoktular: gerçek sunucuda çocuk bunlardan birini alınca
-- spend_coins 'unknown_item' döner, oyun eşyayı envanterden geri alır.
-- Bu öneri 19 eşyayı items.json'daki fiyat ve seviyeyle game_items'a ekler. Fiyatı yine sunucu belirler
-- (spend_coins fiyatı buradan okur); seviye kilidi (min_level) sunucuda da denetlenir (level_locked).
-- Var olan 48 eşyaya dokunulmaz. Yeni tablo, sütun ya da fonksiyon yok.
--
-- Uygulama: Supabase → SQL Editor → bu dosyanın tamamı → Run. Tekrar çalıştırılabilir (on conflict … do update).
-- Test: supabase/test/test_fancy_items.sql, test_items_catalog.sql (bash supabase/test/run.sh).
-- =====================================================================

insert into public.game_items (item_id, price, min_level) values
  ('hat_bucket', 25, 1),
  ('hat_propeller', 30, 2), ('hat_watermelon', 30, 2), ('glasses_heart', 25, 2), ('socks_arm', 25, 2),
  ('hat_cake', 35, 3), ('hat_banana', 35, 3), ('glasses_nose', 30, 3), ('pompom', 30, 3),
  ('glasses_snorkel', 40, 4), ('mask_hero', 30, 4), ('float_flamingo', 50, 4),
  ('hat_crown_tilt', 45, 5), ('outfit_hula', 45, 5),
  ('hat_fishbowl', 60, 6), ('backpack_rocket', 70, 6),
  ('hat_shark', 70, 7),
  ('outfit_burger', 80, 8), ('outfit_chicken', 80, 8)
on conflict (item_id) do update set price = excluded.price, min_level = excluded.min_level;
