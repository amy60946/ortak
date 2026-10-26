# ortak — üç uygulamanın tek doğruluk kaynağı

Bu depo kod değil, **sözleşme** tutar. Üç uygulama aynı Supabase projesine (`https://uhelhxqgpcjemadhsifx.supabase.co`) bağlıdır ve burada yazanlara uyar:

| Ürün | Kim | Depo | Pencere |
|---|---|---|---|
| GameApp | Çocuk | `amy60946/game-app` (Unity, C#) | "Oyun" |
| ParentApp | Ebeveyn | `amy60946/parent-app` (Expo / React Native) | "Ebeveyn" |
| ClinicApp | Uzman | `amy60946/clinic-app` (Expo: web + iPad) | "Klinik" |
| Yönetim paneli | Ekip (admin) | `amy60946/admin-panel` (React web, Cloudflare Workers) | "GameApp2" (ortak + admin-panel; yönetim paneli işlerinin hepsi bu pencerede, kullanıcı kararı 26 Ekim 2026) |

Claude'da bütün pencereler **Island Game** projesinin altında açılır (GitHub'daki takip panosunun adı da Island Game). Yeni pencere açarken depolar: Oyun = `game-app` + `ortak`, Ebeveyn = `parent-app` + `ortak`, Klinik = `clinic-app` + `ortak`, yönetim paneli / ortak işler = `ortak` + `admin-panel`. İlk iş: bu dosya + `DURUM.md`.

## İçerik

| Yol | Ne |
|---|---|
| `supabase/migrations/` | Supabase'e **uygulanmış** SQL göçleri, sırayla. Canlı veritabanının tarifi budur. |
| `supabase/proposed/` | Henüz **uygulanmamış** öneriler. Kullanıcı onayı + test olmadan uygulanmaz. |
| `supabase/test/` | Yerel PostgreSQL testleri (`run.sh`): her test temiz veritabanında; göçler + öneriler (iki kez) + test. |
| `sozlesme/veritabani.md` | Tablolar, RPC'ler, hangi uygulama neyi okur/yazar, satır düzeyi güvenlik. |
| `sozlesme/durumlar.md` | Durum adları ve sabit değerler (tam yazımlarıyla). |
| `sozlesme/ekonomi.md` | Coin, XP, seviye, gösterge düşüşü ve fiyatlar. |
| `sozlesme/akislar.md` | Uygulamalar arası akışlar (bağlama kodu, görev → onay → coin, posta, uzman rızası). |
| `sozlesme/admin.md` | Admin paneli (roller, işlemler, güvenlik) ve KPI tanımları. |
| `DURUM.md` | Ortak karar ve değişiklik günlüğü (en yeni üstte). |

> Sözleşme dosyalarındaki "Kaynak:" satırları özgün kod yollarını gösterir (`parent-app/...`, `game-app/...`); SQL artık bu depodaki `supabase/` altındadır.

## Kurallar (üç pencere için de)

1. **Önce oku:** Her işe başlamadan önce bu dosyayı, `DURUM.md`'nin son kayıtlarını ve işle ilgili `sozlesme/` dosyasını oku.
2. **Önce ortak, sonra uygulama:** Ortak bir şey değişecekse (yeni tablo/alan/RPC, yeni durum, coin/XP/seviye kuralı, rıza kuralı) önce burada değiştir: SQL'i `proposed/`'a yaz, testini ekle, `sozlesme/`'yi güncelle, `DURUM.md`'ye satır ekle. Uygulamalar ancak ondan sonra buna göre değişir. Uygulama depolarında ayrı şema kopyası tutulmaz.
3. **Uygulama:** Bir öneri Supabase'e uygulanınca dosya `proposed/`'dan `migrations/`'a taşınır ve `DURUM.md`'ye "uygulandı" yazılır. Uygulamayı kullanıcı yapar (Supabase → SQL Editor) ya da onaylı bir iş akışı. Göçler tekrar çalıştırılabilir yazılır (`if not exists`, `create or replace`).
   **Kullanıcıya SQL'i her seferinde doğrudan kodu açan bağlantıyla ver** (kullanıcı kararı 26 Ekim 2026): dosya ana dala alındıktan sonra `https://raw.githubusercontent.com/amy60946/ortak/main/supabase/proposed/<dosya>.sql` (Edge Function için `.../supabase/functions/<ad>/index.ts`). Birden çok dosya varsa sırasıyla numaralı liste; her birinin yanında "SQL Editor → New query → tümünü yapıştır → Run" ve varsa ayar (ör. Verify JWT açık/kapalı).
4. **Test:** SQL değişikliğinden sonra `bash supabase/test/run.sh` (yerel psql) geçmeli. Her yeni tabloda satır düzeyi güvenlik (RLS) zorunlu ve testli. Her yeni fonksiyonda `revoke execute … from public, anon` (+ gerekiyorsa `grant … to authenticated`); `test_security.sql` anon'un çağırabildiği fonksiyon kalmadığını denetler.
5. **Günlük:** Her oturum sonunda `DURUM.md`'ye bir satır: tarih · ürün · ne değişti · diğer ürünleri etkiliyor mu · kim ne yapmalı.
6. **Başka ürünün koduna** yalnız okumak için bakılır. Yazmak gerekiyorsa o ürünün penceresi yapar; kullanıcıya söylenir.

## Kullanıcı ve güvenlik

- Kullanıcı yazılımcı değil: Türkçe, sade, adım adım; nereye tıklayacağını söyle. Belirsiz kararda kısa soru sor; kapsam dışına çıkma.
- **SQL Editor'de çalıştırılacak her dosya için GitHub bağlantısı verilir** (kullanıcı, 25 Ekim 2026: "her seferinde böyle ilet"): düz metin `https://raw.githubusercontent.com/amy60946/ortak/<dal>/supabase/proposed/<dosya>.sql` (Ctrl+A ile tümünü kopyala) + sayfa `https://github.com/amy60946/ortak/blob/<dal>/supabase/proposed/<dosya>.sql` ("Copy raw file" düğmesi). Dal, dosyanın gönderildiği dal; vermeden önce bağlantının açıldığı denenir.
- Şifre/anahtar sohbete ya da depoya **asla** yazılmaz; GitHub Secrets'a eklenir. Uygulamalara yalnız Supabase **publishable** anahtarı girer; `sb_secret_` / `service_role` asla.
- Bu depo herkese açıktır: içine kişisel veri, gerçek kullanıcı bilgisi ya da anahtar konmaz.
- Adlandırma: "Fidan" ve eski oyun adı kullanılmaz. Ürünler: GameApp (depo `game-app`), ParentApp, ClinicApp.
- Klinik sınır: hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir; uzman verisi yalnız ebeveyn rızasıyla ve geri alınabilir şekilde paylaşılır.

## Referanslar

- İş modeli kararı ve üç ürün: Joon iş modeli kanvası https://claude.ai/code/artifact/df7eafa7-1e1e-4014-8a5f-7d88cb985485
- Oyun omurgası, raporlar, kademeli açılış: https://claude.ai/code/artifact/3c82704c-e120-4d73-ba9f-a7ffdc75eeac
