-- =====================================================================
-- Moyo Mercek üyelik fiyatları (kullanıcı kararı 20 Kasım 2026; sozlesme/ekonomi.md 9)
--   Bireysel 1.199,99 TL / ay · 11.999,99 TL / yıl; Klinik (10 uzmana kadar) 3.999,99 TL / ay · 39.999,99 TL / yıl.
--   Yıllık = aylığın 10 katı (12 ay kullanılır, 10 ay ödenir; indirim %16,67). KDV dahil.
--   billing_plans yalnız web panelinde gösterilen fiyattır; iOS'ta fiyat App Store'dan okunur (App Store Connect'teki
--   fiyat aynı girilir: CANLIYA_ALMA 1.8 A 4). Moyo Premium (349,99 / 3.499,99) yalnız App Store'da; sunucuda tablo yok.
--   Önceki değerler (taslak, 22 Ekim 2026): 749,99 / 7.499,99 / 2.999,99 / 29.999,99.
-- Tekrar çalıştırılabilir.
-- =====================================================================
update public.billing_plans p
   set price_try = v.price
  from (values ('solo_monthly', 1199.99), ('solo_yearly', 11999.99),
               ('clinic_monthly', 3999.99), ('clinic_yearly', 39999.99)) as v(id, price)
 where p.id = v.id and p.price_try is distinct from v.price;
