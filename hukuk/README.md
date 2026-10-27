# Hukuk arşivi (Pofi Adası · ParentApp · ClinicApp)

> **Canlıya almadan önce kullanıcıya hatırlat** (kullanıcı isteği 27 Ekim 2026; `CLAUDE.md`, `CANLIYA_ALMA.md` 1.5). Bu klasördeki bütün metinler **TASLAK**tır: hukuki görüş değildir, avukat onayından geçmeden yayımlanmaz. Karar notları ve avukata sorular: `sozlesme/hukuk_notlari.md`.

## Nasıl çalışır

1. Metinler bu klasörde Markdown; başlıktaki künyede **anahtar** ve **sürüm** yazar.
2. `python3 tools/legal_seed.py` → `supabase/proposed/20261027210000_legal_seed.sql`: taslaklar veritabanına (`legal_documents`) yüklenir. İç notlar ("Avukata notlar") ve künye herkese açık metne girmez.
3. Uygulamalar metni herkese açık adresten gösterir: Edge Function `legal` (`…/functions/v1/legal?doc=<anahtar>`); alan adı alınınca kendi adresimize taşınır. Taslakların üstünde "TASLAK" bandı çıkar.
4. Onay isteyen metinler (koşullar, sözleşme, aydınlatma okundu) kayıtta ve sürüm değişince uygulama açılışında onaylatılır: `legal_pending(app)` → `legal_accept(app, [{key, version}])`; kayıt `legal_acceptances`.
5. Avukat onayı gelince yönetim paneli › Hukuk › Yayımla (yalnız sahip). Yayındaki metin değişmez; düzeltme = yeni sürüm (dosyada `Sürüm` artırılır, seed yeniden üretilir).
6. KVKK başvuruları: uygulama içi `kvkk_request_create` ya da `kvkk@` e-postası → panel › Hukuk › KVKK başvuruları (30 gün sayacı).

## Dizin

| Dosya | Anahtar | Kim görür | Onay | Durum |
|---|---|---|---|---|
| `00-olgular.md` | — | metin yazarları (tek kaynak) | — | iç |
| `02-ornekler-ve-turk-hukuku.md` | — | örnek alınan ilkeler + Türk hukuku eşlemesi | — | iç |
| `01-gizlilik-politikasi.md` | `gizlilik` | herkes; mağaza bağlantısı | — | taslak |
| `10-aydinlatma-ebeveyn.md` | `aydinlatma-ebeveyn` | ParentApp | okundu | taslak |
| `11-aydinlatma-cocuk-ve-veli.md` | `aydinlatma-cocuk` | veli (ParentApp, çocuk bağlarken) + oyun içi kısa not | okundu (veli) | taslak |
| `12-aydinlatma-uzman.md` | `aydinlatma-uzman` | ClinicApp | okundu | taslak |
| `20-kullanim-kosullari-parentapp.md` | `kosullar-parentapp` | ParentApp | kabul | taslak |
| `21-kullanim-kosullari-gameapp.md` | `kosullar-gameapp` | veli (çocuk bağlarken) | kabul (veli) | taslak |
| `22-uzman-hizmet-sozlesmesi.md` | `sozlesme-uzman` | ClinicApp | kabul | taslak |
| `23-veri-isleme-eki.md` | `veri-isleme-eki` | ClinicApp | kabul | taslak |
| `30-acik-riza-metinleri.md` | `acik-riza-metinleri` (+ her rızanın sürümü) | ParentApp ilgili ekranlar | ayrı rıza kutuları | taslak |
| `40-cerez-politikasi.md` | `cerez-clinicapp-web` | ClinicApp web | — | taslak |
| `41-alt-isleyenler.md` | `alt-isleyenler` | herkes | — | taslak |
| `42-saklama-imha-politikasi.md` | — | iç politika | — | taslak |
| `43-veri-ihlali-proseduru.md` | — | iç prosedür | — | taslak |
| `44-kvkk-basvuru-usulu.md` | `kvkk-basvuru` | herkes | — | taslak |
| `50-uygulama-ici-metinler.md` | — | yazılımcılar: ekran ekran kısa metinler | — | taslak |

## Fonksiyon → hukuki dokunuş haritası

| Fonksiyon (uygulama) | Hukuki konu | Metin | Sistem |
|---|---|---|---|
| Ebeveyn kaydı (ParentApp) | Aydınlatma, koşulların kabulü, veli beyanı | aydinlatma-ebeveyn, kosullar-parentapp | `legal_accept('parent', …)` |
| Çocuk profili, oyunu bağlama (ParentApp → GameApp) | Çocuk verisi veli adına; GameApp koşulları veli kabulü | aydinlatma-cocuk, kosullar-gameapp | `legal_accept('child', …)` QR/kod göstermeden önce |
| Görev, onay, coin, Güneş Taşı, ödüller | Sanal değer para değildir; ödül ebeveyn–çocuk arasında | kosullar-parentapp, kosullar-gameapp | — |
| Ebeveyn ↔ çocuk mesajları (foto, ses) | Aile içi içerik; saklama; mikrofon/foto izin metni | aydinlatma-ebeveyn, uygulama içi metinler | `mail` kovası |
| Zor an (ABC) kaydı, ses | Davranış verisi → sağlık verisi olabilir (md. 6) | aydinlatma-ebeveyn, avukat sorusu | `abc` kovası |
| Tanışma soruları (sağlık: tanı, ilaç) | Özel nitelikli veri, açık rıza `saglik-yanit-v1`; ekip erişimi gerekçeli | acik-riza (saglik), aydinlatma-ebeveyn | `intake_answers`, `admin_intake` |
| Uzman daveti (e-posta, çocuk adı önerisi) | Uzmanın beyanı, ilk iletişimde aydınlatma, ticari ileti değil | sozlesme-uzman, aydinlatma-ebeveyn | `invite-email` |
| Uzmanla paylaşım | Açık rıza `uzman-paylasim-v1`, "uzmanı tanıyorum, veliyim" | acik-riza (paylaşım), kosullar-parentapp | `clinic_links.consent_version` |
| Uzman değişiminde kayıt aktarımı | Açık rıza `uzman-gecis-v1` + uzmanın önceden izni; kimlik gizleme | acik-riza (geçiş), sozlesme-uzman | `clinic_link_history` |
| Uzman notları, hedefler, takip planı | Veri sorumlusu/işleyen rolleri, gizlilik, sona ermede silme | sozlesme-uzman, veri-isleme-eki | — |
| Uzman belge incelemesi | Kimlik no içeren belge; yalnız inceleme; karar sonrası silme; "Belgesi incelendi" ifadesinin sınırı | aydinlatma-uzman, sozlesme-uzman | `verify-doc` |
| Uzman karşılama anketi | Ürün geliştirme, kimliksiz toplam | aydinlatma-uzman | `admin_kpi_clinician_survey` |
| Abonelik (ParentApp, ClinicApp) | Otomatik yenileme, iptal, cayma istisnası, Apple satıcı | kosullar-parentapp, sozlesme-uzman, uygulama içi metinler | RevenueCat |
| Bildirimler | İzin, içerikte hassas veri yok | uygulama içi metinler | `push-apns` |
| Kullanım ölçümü | Meşru menfaat; içerik yok; üçüncü taraf yok | gizlilik, aydinlatmalar | `track_session`, `track_events` |
| Yönetim paneli erişimi | Yetkili ekip erişimi, gerekçe, kayıt | gizlilik, hukuk_notlari 3I3 | `admin_audit` |
| Hesap silme | Silme hakkı, abonelik iptali uyarısı | gizlilik, uygulama içi metinler | `delete_account()` |
| KVKK başvurusu | md. 11, 13, 30 gün | kvkk-basvuru | `kvkk_requests` |
| Veri ihlali | md. 12/5, 72 saat | ihlal prosedürü (iç) | panel acil işlemleri |
| Saklama ve imha | Yönetmelik, periyodik imha | saklama-imha (iç) | **yapılacak:** zamanlanmış imha işi |
| ClinicApp web | Çerez/yerel depolama | cerez-clinicapp-web | — |

## Yazım sırasında bulunan sorunlar (27 Ekim 2026; ürün ya da avukat kararı bekler)

| # | Sorun | Kimin işi |
|---|---|---|
| 1 | ParentApp'te "Önceki uzmanın kayıtlarını da paylaş" seçeneği **varsayılan açık** (`akislar.md` 11 #2). Açık rıza önceden işaretli olamaz; varsayılan kapalı olmalı. | ParentApp penceresi |
| 2 | Tanışma sorularında "çocuk bir uzmanla (psikolog vb.) çalışıyor mu" ve davranış sıklığı soruları (öfke nöbeti, endişe…) sağlık sorusu olarak işaretli değil; rızasız alınıyor. Sağlık verisi sayılırsa `saglik-yanit` kapsamına alınmalı. | Avukat → ParentApp |
| 3 | `uzman-paylasim-v1` bugün yalnız uyarı + veli beyanını kayıt ediyor; taslak rıza cümlesi ve kısa aydınlatma eklendiği için yayında `uzman-paylasim-v2` olmalı; v1 onaylarının yeterliliği avukata. | Avukat → ParentApp |
| 4 | Aile ya da çocuk silinince uzmanın o danışana ait notları ve hedefleri de siliniyor; uzmanın kayıt saklama yükümlülüğüyle çatışabilir. | Avukat + ürün (ortak) |
| 5 | Tek bir çocuk profilini ya da yalnız oyun kaydını silmenin yolu yok (KVKK md. 7, Apple 5.1.1(v)). | Avukat → ParentApp/GameApp |
| 6 | `CANLIYA_ALMA.md` 4'te ParentApp için Sentry/PostHog planı var; eklenirse "üçüncü taraf analiz yok" cümleleri, aydınlatmalar ve alt işleyenler değişir. | Kullanıcı kararı |
| 7 | Tanı/ilaç yanıtlarının uygulamada somut amacı yazılı değil (KVKK md. 4 amaçla sınırlılık); kullanılmıyorsa soru kaldırılmalı. | Ürün + avukat |
| 8 | Ön kontrolün kendiliğinden reddettiği belge başvurularına itiraz yolu yok (md. 11/1-g). | ClinicApp + panel |
| 9 | ClinicApp üyeliği bitince erişim tümüyle kapanıyor ve veri süresiz kalıyor; sözleşme sona erme/dışa aktarma süresi öneriyor (`[SÜRE]`). | Avukat + ürün |
| 10 | Uzmanlar için toplu dışa aktarma ve KVKK "kopya" talebi için veri dışa aktarma yok (bugün yalnız yazdırılabilir rapor). | ortak + uygulamalar |
| 11 | `akislar.md` 1.1 ve 2'de kod süresi "24 saat" yazıyor; sistem 15 dakika. | ortak (belge düzeltmesi) |
| 12 | ClinicApp ödeme yolları metinlerde eksik/yanlış (Klinik penceresi, 27 Ekim 2026): **web'de iyzico** (`functions/clinic-billing`, iyzico ödeme formu; kart bilgisi bize gelmez; üyelik canlıda kapalı) hiçbir metinde ve alt işleyen listesinde yok; iPad'de ClinicApp **RevenueCat kullanmıyor**, App Store Server API'yi doğrudan sorguluyor. Güncellenecek: `00-olgular.md` §3 (Abonelik) ve §5, `41-alt-isleyenler.md` (iyzico satırı + 3.x; RevenueCat yalnız ParentApp), `12-aydinlatma-uzman.md`, `22-uzman-hizmet-sozlesmesi.md` (ödeme/iade). iyzico'nun rolü (bağımsız veri sorumlusu ödeme kuruluşu mu, alt işleyen mi) avukata. Çerez politikasına (3. bölüm) eklendi. | GameApp2 (metin) + avukat |

## Canlıdan önce yapılacaklar (hukuk)

1. Avukatla bu klasör + `sozlesme/hukuk_notlari.md` 5. bölüm (sorular) gözden geçirilir; yer tutucular (`[ŞİRKET UNVANI]`, `[ADRES]`, `[ALAN ADI]`, `[SUPABASE BÖLGESİ]`, `[SÜRE]`) doldurulur.
2. VERBİS, yurt dışı aktarım (standart sözleşme + Kurul bildirimi), saklama süreleri kararları.
3. Onaylanan metinler panelden yayımlanır; mağaza sayfalarına `gizlilik` adresi girilir.
4. Uygulamalarda: kayıt/yeniden onay ekranı, Ayarlar › Yasal metinler, KVKK başvurusu, hesap silme uyarıları (`50-uygulama-ici-metinler.md`).
