# ortak — üç uygulamanın tek doğruluk kaynağı

Bu depo kod değil, **sözleşme** tutar. Üç uygulama aynı Supabase projesine (`https://uhelhxqgpcjemadhsifx.supabase.co`) bağlıdır ve burada yazanlara uyar:

| Ürün | Kim | Depo | Pencere |
|---|---|---|---|
| Pofi Adası (GameApp) | Çocuk | `amy60946/pofi-adasi` (Unity, C#) | "Oyun" |
| ParentApp | Ebeveyn | `amy60946/parent-app` (Expo / React Native) | "Ebeveyn" |
| ClinicApp | Uzman | `amy60946/clinic-app` (web + iPad; teknoloji kararı bekliyor) | "Klinik" |

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
| `DURUM.md` | Ortak karar ve değişiklik günlüğü (en yeni üstte). |

> Sözleşme dosyalarındaki "Kaynak:" satırları özgün kod yollarını gösterir (`parent-app/...`, `pofi-adasi/...`); SQL artık bu depodaki `supabase/` altındadır.

## Kurallar (üç pencere için de)

1. **Önce oku:** Her işe başlamadan önce bu dosyayı, `DURUM.md`'nin son kayıtlarını ve işle ilgili `sozlesme/` dosyasını oku.
2. **Önce ortak, sonra uygulama:** Ortak bir şey değişecekse (yeni tablo/alan/RPC, yeni durum, coin/XP/seviye kuralı, rıza kuralı) önce burada değiştir: SQL'i `proposed/`'a yaz, testini ekle, `sozlesme/`'yi güncelle, `DURUM.md`'ye satır ekle. Uygulamalar ancak ondan sonra buna göre değişir. Uygulama depolarında ayrı şema kopyası tutulmaz.
3. **Uygulama:** Bir öneri Supabase'e uygulanınca dosya `proposed/`'dan `migrations/`'a taşınır ve `DURUM.md`'ye "uygulandı" yazılır. Uygulamayı kullanıcı yapar (Supabase → SQL Editor) ya da onaylı bir iş akışı. Göçler tekrar çalıştırılabilir yazılır (`if not exists`, `create or replace`).
4. **Test:** SQL değişikliğinden sonra `bash supabase/test/run.sh` (yerel psql) geçmeli. Her yeni tabloda satır düzeyi güvenlik (RLS) zorunlu ve testli.
5. **Günlük:** Her oturum sonunda `DURUM.md`'ye bir satır: tarih · ürün · ne değişti · diğer ürünleri etkiliyor mu · kim ne yapmalı.
6. **Başka ürünün koduna** yalnız okumak için bakılır. Yazmak gerekiyorsa o ürünün penceresi yapar; kullanıcıya söylenir.

## Kullanıcı ve güvenlik

- Kullanıcı yazılımcı değil: Türkçe, sade, adım adım; nereye tıklayacağını söyle. Belirsiz kararda kısa soru sor; kapsam dışına çıkma.
- Şifre/anahtar sohbete ya da depoya **asla** yazılmaz; GitHub Secrets'a eklenir. Uygulamalara yalnız Supabase **publishable** anahtarı girer; `sb_secret_` / `service_role` asla.
- Bu depo herkese açıktır: içine kişisel veri, gerçek kullanıcı bilgisi ya da anahtar konmaz.
- Adlandırma: "Fidan" adı kullanılmaz. Ürünler: Pofi Adası (GameApp), ParentApp, ClinicApp.
- Klinik sınır: hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir; uzman verisi yalnız ebeveyn rızasıyla ve geri alınabilir şekilde paylaşılır.

## Referanslar

- İş modeli kararı ve üç ürün: Joon iş modeli kanvası https://claude.ai/code/artifact/df7eafa7-1e1e-4014-8a5f-7d88cb985485
- Oyun omurgası, raporlar, kademeli açılış: https://claude.ai/code/artifact/3c82704c-e120-4d73-ba9f-a7ffdc75eeac
