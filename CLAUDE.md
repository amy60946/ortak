# ortak — üç uygulamanın tek doğruluk kaynağı

Bu depo kod değil, **sözleşme** tutar. Üç uygulama aynı Supabase projesine (`https://uhelhxqgpcjemadhsifx.supabase.co`) bağlıdır ve burada yazanlara uyar:

| Ürün | Kim | Depo | Pencere |
|---|---|---|---|
| GameApp | Çocuk | `amy60946/game-app` (Unity, C#) | "Oyun" |
| ParentApp | Ebeveyn | `amy60946/parent-app` (Expo / React Native) | "Ebeveyn" |
| ClinicApp | Uzman | `amy60946/clinic-app` (Expo: web + iPad) | "Klinik" |
| Koordinatör (bütün depolar; yönetim paneli + ortak + lansman takibi) | Ekip (admin) | `amy60946/admin-panel` (React web, Cloudflare Workers) + `ortak`; öteki depoları **okur** | "Koordinatör" (kullanıcı kararı 10 Kasım 2026; önceki adı "GameApp2"): yönetim paneli, ortak, SQL önerileri, Cloudflare ve lansman takibi bu pencerede; uygulama kodunu (parent-app, clinic-app, game-app, marketing içeriği) yazmaz, okur, doğrular, koordine eder |
| Pazarlama | Ekip | `amy60946/marketing` (özel depo: strateji, kampanya, içerik) | "Marketing" (ortak + marketing; ürünleri ortaktan **okur**, ürün kodu/SQL/yasal metin yazmaz; kurallar `hukuk/45-pazarlama-kurallari.md`; kullanıcı isteği 28 Ekim 2026; **spiker sesi üretimi de bu pencerede**, 29 Ekim 2026) |

Claude'da bütün pencereler **Island Game** projesinin altında açılır (GitHub'daki takip panosunun adı da Island Game). Yeni pencere açarken depolar: Oyun = `game-app` + `ortak`, Ebeveyn = `parent-app` + `ortak`, Klinik = `clinic-app` + `ortak`, koordinatör (yönetim paneli / ortak işler / lansman takibi) = `ortak` + `admin-panel` (+ öteki depolar yalnız okumak için), pazarlama = `ortak` + `marketing`. İlk iş: bu dosya + `DURUM.md`.

**Marketing penceresi için:** ürün bilgisi `hukuk/00-olgular.md` (ne var, ne toplanıyor), `sozlesme/akislar.md` (özellikler), `sozlesme/ekonomi.md` (coin, abonelik), `sozlesme/admin.md` (KPI tanımları), `DURUM.md` (son kararlar), iş modeli kanvası (Referanslar). Pazarlama metni ve kampanya `hukuk/45-pazarlama-kurallari.md`'ye uyar (sağlık iddiası yok, çocuğa doğrudan çağrı yok, izleme yalnız onayla, İYS). Strateji, bütçe ve rakip notları **herkese açık bu depoya değil** `marketing` özel deposuna yazılır. Sosyal medya paylaşımı `sozlesme/paylasim.md`: Marketing paketi taslak olarak gönderir, yayın yalnız panelde owner onayıyla (§8). Ortakta değişmesi gereken bir şey görürse ilgili pencereye iletir (kural 6).

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
| `sozlesme/paylasim.md` | Sosyal medya paylaşımı: Marketing paketi → panelde owner onayı → paylaşım servisi (Zernio). |
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
7. **Benchmark alışkanlığı (kullanıcı isteği 2 Kasım 2026, bütün pencereler):** her yeni özellik, özellik çıkarma ve iyileştirmede (akış/senaryo, tasarım, metin, arayüz, iş kuralı) önce aynı işi yapan, başarılı olmuş global uygulama ve platformlar araştırılır. En iyi örnekler artı ve eksileriyle değerlendirilir, ürünün amacına (çocuk / ebeveyn / uzman, Türkiye) uyanlar seçilir, kullanıcıya seçenek ve öneri olarak sunulur. Kaynaklar yazılır, başka ürünün içeriği, karakteri, metni kopyalanmaz (yalnız işleyiş referansı).

8. **Kota tasarrufu (kullanıcı isteği 2 Kasım 2026, bütün pencereler).** Ölçüm (2 Kasım): uzun pencerelerde her adımda 600–700 bin token'lık geçmiş yeniden okunuyor (GameApp, Marketing, yönetim paneli); kotayı yiyen budur, araç ya da arama değil.
   - **Konu bitince yeni pencere:** bir iş paketi bitince (ya da geçmiş çok uzayınca) yeni pencere açılır. Süreklilik `CLAUDE.md` + `DURUM.md` + depolardan gelir; eski pencere kapanmadan önce `DURUM.md`'ye satırını yazar ve yeni pencerenin ilk mesajını (bekleyen işler, abonelikler) kullanıcıya hazırlar.
   - **Pencereler arası mesaj az:** yalnız karşı tarafın şimdi bir şey yapması gerekiyorsa gönderilir, tek mesajda toplanır; bilgi notu `DURUM.md`'ye yazılır (her mesaj karşı pencerenin bütün geçmişini yeniden okutur).
   - **Görsel/video kare incelemesi alt ajanda:** ekran görüntüsü ve video kareleri ana pencereye değil, alt ajana baktırılır, yalnız sonucu döner (görseller geçmişte kalıcı yer kaplar).
   - **Uzun çıktı yok:** günlük, JSON, dosya dökümleri `head`/`grep` ile kısaltılır; tekrar tekrar yoklama (polling) yapılmaz, olay ya da bildirim beklenir.
   - **Biten abonelik ve zamanlayıcılar kapatılır** (birleşen PR, biten derleme denemesi).

9. **Takip sayfası (kullanıcı kararı 10 Kasım 2026):** süreç işleri tek takip sayfasında: "Canlıya Alma: Adım Adım ve Pencere İşleri" https://claude.ai/artifact/LdikjQHgM6Wgmv3QE7A8qd (Docs araçlarıyla okunur ve yazılır). Her pencere işi bitince ya da tıkanınca kendi satırını günceller (durum, engel, tarih, bağlantı), DURUM satırıyla aynı anda; koordinatör doğrular ve özetler. Ürün pencereleri bunun için koordinatöre mesaj atmaz; koordinatör bir pencereye yalnız o pencerenin şimdi bir şey yapması gerektiğinde tek, toplu mesaj gönderir. `CANLIYA_ALMA.md` ikinci bir liste değildir, yalnız bu sayfaya bağlantı ve "nasıl yapılır" anlatımı verir.

## Kullanıcı ve güvenlik

- Kullanıcı yazılımcı değil: Türkçe, sade, adım adım; nereye tıklayacağını söyle. Belirsiz kararda kısa soru sor; kapsam dışına çıkma.
- **SQL Editor'de çalıştırılacak her dosya için GitHub bağlantısı verilir** (kullanıcı, 25 Ekim 2026: "her seferinde böyle ilet"): düz metin `https://raw.githubusercontent.com/amy60946/ortak/<dal>/supabase/proposed/<dosya>.sql` (Ctrl+A ile tümünü kopyala) + sayfa `https://github.com/amy60946/ortak/blob/<dal>/supabase/proposed/<dosya>.sql` ("Copy raw file" düğmesi). Dal, dosyanın gönderildiği dal; vermeden önce bağlantının açıldığı denenir.
- Şifre/anahtar sohbete ya da depoya **asla** yazılmaz; GitHub Secrets'a eklenir. Uygulamalara yalnız Supabase **publishable** anahtarı girer; `sb_secret_` / `service_role` asla.
- Bu depo herkese açıktır: içine kişisel veri, gerçek kullanıcı bilgisi ya da anahtar konmaz.
- Adlandırma: "Fidan" ve eski oyun adı kullanılmaz. Ürünler: GameApp (depo `game-app`), ParentApp, ClinicApp.
- **Canlıya alma: elle yayın (kullanıcı kararı 2 Kasım 2026, üç ürün):** App Store Connect'te "Manually release this version" seçilir; Apple onayından sonra sürüm kullanıcı onayıyla yayına alınır, otomatik yayın yok. Durum takip sayfasında (kural 9); adımların anlatımı `CANLIYA_ALMA.md`.
- **Hukuk arşivi (kullanıcı isteği 27 Ekim 2026):** hukuki her karar/madde `sozlesme/hukuk_notlari.md`'ye yazılır (avukata sorular dahil). Canlıya alma süreci yeniden başlarken ve herhangi bir ürün canlıya alınmadan önce kullanıcıya bu arşivi hatırlat (`CANLIYA_ALMA.md` 1.5).
- Klinik sınır: hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir; uzman verisi yalnız ebeveyn rızasıyla ve geri alınabilir şekilde paylaşılır.

## Referanslar

- İş modeli kararı ve üç ürün: Joon iş modeli kanvası https://claude.ai/code/artifact/df7eafa7-1e1e-4014-8a5f-7d88cb985485
- Oyun omurgası, raporlar, kademeli açılış: https://claude.ai/code/artifact/3c82704c-e120-4d73-ba9f-a7ffdc75eeac
