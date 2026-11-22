# Kişisel Veri Envanteri
| Anahtar | iç belge | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | İşletme içi. VERBİS kaydı gerekirse kayıt bu tablodan doldurulur (veri kategorisi, amaç, hukuki sebep, kişi grubu, alıcı grubu, yurt dışı aktarım, süre, tedbir) | Dayanak | KVKK md. 4, 5, 6, 8, 9, 10, 12, 16; Veri Sorumluları Sicili Hakkında Yönetmelik; benzeri GDPR md. 30 (işleme faaliyetleri kaydı) |

> İç not — 20 Kasım 2026: 14 Kasım kararları, çekirdek maddeler, Moyo adları, deneme 14 gün (sürüm v1 kaldı). Ürün adları: Moyo Ebeveyn (ParentApp), Moyo Oyun (GameApp / Pofi Adası), Moyo Mercek (ClinicApp). Veri sorumlusu gerçek kişi `[AD SOYAD]` (`00-olgular.md` §1). Terim: "özel nitelikli veri içerebilecek kayıtlar" (`hukuk_notlari.md` M.2); kesin "sağlık verisi" nitelendirmesi yapılmaz.
> 20 Kasım 2026 (ikinci tur): kullanıcının konumu (A.2): kayıtlar ebeveynin uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır, Moyo özel nitelikli veri toplamaz; K6/K7 başlıklarındaki terim koruma ağını (ek koruma, uzmanla paylaşımda açık rıza) gösterdiği için kaldı. K7 veri sorumlusu kararı (A.4) ve K9 (belge yükleme kullanılmıyor, B.7) işlendi; saklama süreleri `42`'de dolduruldu. Tablo listesi değişmedi.

## Kısaca

- Sistemde kişisel veri tutan **her tablo** aşağıdaki kategorilerden (K1–K15) birine bağlıdır (Ek A). Yeni tablo eklenince bu dosyaya satır eklenmezse `supabase/test/run.sh` hata verir (`tools/veri_envanteri_kontrol.py`).
- Saklama süreleri ve imha yöntemi ayrı belgede: `42-saklama-imha-politikasi.md` (§4 satır numaraları). Alıcıların ayrıntısı: `41-alt-isleyenler.md`. Olgular: `00-olgular.md`.
- Köşeli parantezli alanlar avukat ve kullanıcı kararıyla dolar (hukuki sebep "avukat" yazan satırlar). Supabase bölgesi 10 Kasım 2026'da dolduruldu: Frankfurt, Almanya (`hukuk_notlari.md` soru 29).
- Hazırlanış: 2 Kasım 2026, şemadan (göçler + öneriler) üretildi; olgu değişirse önce `00-olgular.md`, sonra burası.

## 1. Kategoriler

Kişi grupları: **E** ebeveyn · **Ç** çocuk · **U** uzman · **D** davet edilen ebeveyn (henüz hesabı yok) · **T** ekip (yönetim paneli).
Alıcılar (hepsinde Supabase, `41` satır 1): **A** Apple (abonelik, anlık bildirim metni) · **X** Expo (yedek bildirim yolu) · **R** RevenueCat · **M** Resend (e-posta) · **C** Cloudflare (panel) · **Uz** ebeveynin açık rızasıyla paylaştığı uzman.
Yurt dışı: Supabase Frankfurt, Almanya (AB; Türkiye dışı); A, X, R, M ABD (ve/veya AB); C küresel. KVKK md. 9 (standart sözleşme + Kurul'a bildirim) avukatta.

| # | Kategori | Kişi | Veri | Amaç | Hukuki sebep (öneri) | Alıcı | Saklama (`42` §4) |
|---|---|---|---|---|---|---|---|
| K1 | Kimlik ve iletişim | E, U, T | ad, takma ad, simge, e-posta, şifre özeti (yalnız kimlik sağlayıcıda), unvan | Hesap açma, giriş, iletişim | md. 5/2-c sözleşmenin kurulması ve ifası | M, C | 1, 8 |
| K2 | Aile ve çocuk profili | E, Ç | aile adı, çocuğun adı/takma adı, simgesi, isteğe bağlı cinsiyet ve doğum günü, yaş grubu, aile/çocuk kodları, cihaz bağlantısı | Ailenin ve çocuğun uygulamayı kullanması | md. 5/2-c; veli beyanı (çocuk verisi veliden) | Uz (rızayla), C | 2 |
| K3 | Rutin ve adım, onay, ödül, sanal değer | E, Ç | rutinler ve adımlar (`tasks`; oyunda "macera"), tekrarlar, "Yaptım", onay/ret ve notu, ödüller, istekler, coin ve Güneş Taşı defterleri, haftalık hedef, ebeveynin ders kayıtları (başladığı/öğrendiği ders, uygulama günleri) | Ürünün temel işlevi | md. 5/2-c | Uz (rızayla), C | 2 |
| K4 | Oyun kaydı | Ç | seviye, XP, eşyalar, ada düzeni | Oyunun sürmesi, cihaz değişince geri yükleme | md. 5/2-c | — | 2, 30 |
| K5 | Aile içi iletişim içeriği | E, Ç | mesaj yazısı, fotoğraf, sesli mesaj, çıkartma, okundu | Ebeveyn ile çocuk arasında mesajlaşma | md. 5/2-c | — | 3 |
| K6 | Davranış kayıtları ve davranış olayları (özel nitelikli veri içerebilecek kayıtlar) | E, Ç | davranış kaydı: öncül–davranış–sonuç, şiddet, ses kaydı, zaman; davranış olayı (uzmanın hedef davranışına ebeveynin bildirimi): zaman, sayı/süre, öncesi–sonrası, denenen strateji, çocuğun tepkisi (1–5, ebeveyn gözlemi) | Ebeveynin gözlem günlüğü; rızayla uzmanla paylaşım | md. 5/2-c; uzmanla paylaşım **açık rıza** `uzman-paylasim-v1`; kayıt md. 6 kapsamına girerse ebeveynin kendi kaydının dayanağı avukatta (`hukuk_notlari.md`) | Uz (rızayla) | 4 (davranış kaydı), 9 (davranış olayı) |
| K7 | Uzmanla paylaşım ve uzmanın aile kayıtları (özel nitelikli veri içerebilecek kayıtlar) | Ç, E, U | paylaşım ve rıza sürümü, uzman notları (aile görmez), hedefler, değerlendirmeler, rutin ve adım önerileri, takip planı ve ev programı kayıtları (takip planı lansmanda bayrakla kapalı), uzmanın önerdiği ebeveyn dersi ve ebeveynin o dersteki uygulama günleri (öneriden sonrası), ebeveyn eğitimi (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar; uzmanın gözlem verisi aile görmez), hedef davranışlar ve stratejiler, seans randevuları ve seans kayıtları (psikolog/terapistle randevunun varlığı özel nitelikli veri içerebilir, md. 6) | Uzmanın aileyle çalışması | Paylaşım: **açık rıza** `uzman-paylasim-v1`, geçiş `uzman-gecis-v1`; uzman kayıtlarında veri sorumlusu uzman (klinik), Moyo veri işleyen (kullanıcı kararı 20 Kasım 2026; avukat teyidi) | Uz, C | 7, 9, 9a |
| K8 | Klinik, ekip ve davet | U, D | klinik adı, ekip rolü, koltuk; davette ebeveyn adı/e-postası, çocuğun adı ve yaş grubu, davet kanalı; uzmanın rutin ve şablon kütüphanesi | Klinik hesabı ve aile daveti | md. 5/2-c (uzman); D için uzmanın beyanı + md. 5/2-f — avukat | M (davet e-postası) | 8, 10 |
| K9 | Mesleki belge incelemesi (**özellik kullanılmıyor**, kullanıcı 20 Kasım 2026; `clinician_verifications` tablosu durur, yeniden açılırsa önce metinler) | U | belge dosyası (karar anında silinir), özet (üniversite, bölüm, derece, yıl), barkod, BACB no, karar | Rozet: ailelere "Uzman diploma belgesini yükledi", uzmana "Belge yüklendi: <meslek>" (Moyo doğrulama ya da yetki beyanı vermez; özellik lansmanda kapalı, bayrak `clinician_verification`) | md. 5/2-c (uzmanın talebi); T.C. kimlik no saklanmaz | — | 11, 12 |
| K10 | Uzman karşılama anketi | U | meslek, zorluklar, yararlı özellikler, geliş nedeni | Ürün geliştirme | md. 5/2-f meşru menfaat (28 Ekim 2026'dan beri atlanamaz; ölçülülük sorusu `README.md` sorun 16) | — | 13 |
| K11 | Abonelik ve ödeme | E, U | plan, durum, bitiş, mağaza işlem kimliği, ödeme olayları, deneme geçmişi (e-posta özeti SHA-256) | Aboneliğin yürütülmesi, deneme suistimalini önleme | md. 5/2-c; vergi kaydı md. 5/2-ç; deneme geçmişi md. 5/2-f | A, R | 14, 15, 16 |
| K12 | Kullanım, cihaz ve bildirim | E, Ç, U | uygulama açma günleri, oturum sayısı, sürüm, platform, ekran/olay adları (içerik yok), bildirim jetonu, uygulama içi bildirimler | Hizmetin işletilmesi, ürün ölçümü, bildirim gönderimi | md. 5/2-f meşru menfaat (üçüncü taraf analiz yok); bildirim md. 5/2-c | A, X (bildirim metni) | 18, 19, 20 |
| K13 | Güvenlik ve ekip işlemleri | E, Ç, U, T | kod denemeleri, ekip rolü, ekip işlemleri denetim kaydı (gerekçe, önce/sonra), kişiye özel ayar istisnaları | Kötüye kullanımı önleme, hesap verebilirlik | md. 5/2-f; md. 12 (güvenlik) | C | 17, 22 |
| K14 | Hukuki işlemler | E, U, (Ç veli eliyle) | yasal metin onay kaydı (rastgele kimlikle), KVKK başvuruları (yanıt e-postası dahil) | İspat, başvuruların yanıtlanması | md. 5/2-ç hukuki yükümlülük; md. 5/2-e hakkın tesisi | C | 23, 24 |
| K15 | Destek talepleri | E, U (yetişkin beyanıyla) | e-posta, isteğe bağlı ad, uygulama, konu, mesaj, ekibin iç notu | Talebin yanıtlanması | md. 5/2-c (kullanıcıysa) / md. 5/2-f; KVKK başvurusu niteliğindeyse md. 5/2-ç | C (form sayfası) | 25 |
| — | Kişisel veri içermeyenler | — | katalog ve ayarlar, anonim günlük kullanım toplamları, imha kaydı (yalnız sayı) | İşletme | — | — | 27 |

## 2. Teknik ve idari tedbirler (md. 12)

Satır düzeyi güvenlik (herkes yalnız kendi ailesini/kliniğini görür; her yeni tabloda zorunlu ve testli), girişsiz rolün hiçbir işleve erişememesi (`test_security.sql`), TLS, özel dosya kovaları ve kısa süreli imzalı bağlantı, ekip panelinde iki adımlı doğrulama + rol + gerekçe + silinemez denetim kaydı, panelden dışa aktarmanın gerekçeyle kayda geçmesi, zamanlanmış imha işi ve imha kaydı, sistem sağlığı izleme ve alarm (`sozlesme/admin.md`), veri ihlali prosedürü (`43`), şifre/anahtarın depo dışında tutulması.

## 3. İlgili kişinin hakları (md. 11)

"Verimi indir" (`my_data_export`; Moyo Ebeveyn ve Moyo Mercek ayarlarında) ve panelden destek rolüyle dışa aktarma (`admin_user_export`): hesabın ve velisi olunan çocukların kayıtları; diğer ebeveynin yazdıkları ayıklanır. Silme: uygulama içi "Hesabımı sil". Başvuru: `44-kvkk-basvuru-usulu.md`.

## Ek A. Tablo → kategori

Denetim: `tools/veri_envanteri_kontrol.py` göçlerdeki ve önerilerdeki her `create table public.<ad>` için bu tabloda satır arar.

| Tablo | Kategori | Not |
|---|---|---|
| `profiles` | K1 | ebeveyn profili (auth.users: e-posta, şifre özeti, son giriş) |
| `clinicians` | K1 | uzman adı, unvanı, rolü |
| `admin_users` | K13 | ekip rolü |
| `families` | K2 | |
| `children` | K2 | `user_id`: çocuk cihazının anonim oturumu |
| `invite_codes` | K2 | 15 dakikalık aile/çocuk kodları |
| `child_goal_settings` | K3 | |
| `tasks` | K3 | rutin ve adımlar (aile ve uzman arayüzünde "rutin / adım", oyunda "macera") |
| `task_assignments` | K3 | |
| `task_boosts` | K3 | |
| `completions` | K3 | ebeveyn notu ve ret nedeni |
| `weekly_goal_claims` | K3 | |
| `rewards` | K3 | |
| `reward_requests` | K3 | |
| `coin_ledger` | K3 | |
| `sun_stone_ledger` | K3 | taş düşürme nedeni (`note`) |
| `saved_templates` | K3 | ailenin kaydettiği görev şablonları |
| `game_saves` | K4 | |
| `messages` | K5 | medya `mail` kovasında |
| `abc_events` | K6 | ses `abc` kovasında; isteğe bağlı uzman hedefi (`goal_id`, 3 Kasım 2026) |
| `intake_answers` | K2, K6 | tanışma yanıtları (aile ve çocuk; hazır seçenek anahtarları, serbest metin yok): hedefler, düzen, çalışılan uzmanlar, haftalık gözlem soruları (günlük davranış maddeleri dahil); özel nitelikli veri içerebilir. Tanı/ilaç soruları ve açık rıza `saglik-yanit-v1` 14 Kasım 2026'da kalktı, var olan yanıtlar silindi; `consent_version` sütunu doldurulmuyor. Kişi bazlı yanıtları panelde yalnız owner görür (`admin_intake`), toplamlar kimliksiz |
| `parent_assignments` | K3 | ebeveynin kendi görevleri (kime, zorluk) |
| `parent_completions` | K3 | ebeveynin "Yaptım" işaretleri |
| `parent_stone_ledger` | K3 | ebeveynin Güneş Taşı defteri (görev, hediye, ders uygulaması) |
| `parent_lessons` | — | ebeveyn eğitimi ders kataloğu (sistem içeriği) |
| `parent_lesson_progress` | K3 | ebeveynin başladığı / öğrendiği dersler, ilk açılış; uzmanın önerdiği derste K7 (öneriden sonrası, rızayla) |
| `parent_lesson_practice` | K3 | ebeveynin "Bugün uyguladım" günleri; uzmanın önerdiği derste öneriden sonraki günler K7 (rızayla) |
| `parent_lesson_assignments` | K7 | uzmanın aileye önerdiği ders ve kısa notu |
| `child_gifts` | K3 | ebeveynin çocuğa hediyesi (eşya, kısa not, gönderenin adı) |
| `gift_items` | — | hediye kataloğu (fiyat, sıra) |
| `guest_passes` | K11 | aile davet kodu (önce hediye kartı): kod, davet eden ve kullanan aile, tarihler, ödül işareti |
| `referral_rewards` | K11 | davet ödülü: davet eden aile, kod, durum, ücretsiz süre sonu, Apple teklif kodu (davet edilenin kimliği yok) |
| `clinic_links` | K7 | rıza sürümü ve zamanı |
| `clinic_link_access` | K7 | |
| `clinic_link_history` | K7 | |
| `clinic_link_labels` | K7 | uzmanın etiketleri |
| `clinic_notes` | K7 | aile görmez |
| `clinic_goals` | K7 | |
| `goal_ratings` | K7 | |
| `clinic_task_suggestions` | K7 | |
| `care_modules` | K7 | takip planı modülleri |
| `care_module_goals` | K7 | |
| `care_module_logs` | K7 | ebeveynin ev programı kayıtları |
| `parent_trainings` | K7 | uzmanın ebeveyne verdiği eğitim (9 Kasım 2026 önerisi; ebeveyn adı, ustalık ölçütü); aile ve çocuk kimliği (`family_id`, `child_id`) ve `detached_at`: paylaşım ya da klinik silinince aileye açılmış eğitim ailenin salt okunur kopyası olur, ölçüt ve uzman alanları silinir (öneri `20261120200000`, karar 3A; saklama `42` satır 9) |
| `parent_training_modules` | K7 | ebeveynin modül tamamlaması, test yanıtları ve açık uçlu yanıtları (çocuğuna dair metin olabilir) |
| `parent_training_tasks` | K7 | uzmanın yazdığı uygulama görevi |
| `parent_training_logs` | K7 | ebeveynin uygulama kaydı ve düşüncesi |
| `parent_training_todos` | K7 | hızlı yapılacaklar, ebeveynin işareti |
| `parent_training_data` | K7 | uzmanın gözlem verisi (aile görmez; paylaşım ya da klinik silinince silinir) |
| `clinic_target_behaviors` | K7 | uzmanın tanımladığı hedef davranış ve stratejiler (9 Kasım 2026 önerisi) |
| `behavior_incidents` | K6 | ebeveynin bildirdiği davranış olayı: zaman, süre/sayı, öncesi-sonrası, strateji, çocuğun tepkisi (özel nitelikli veri içerebilir; paylaşım kaydına bağlı, saklama `42` satır 9); `behavior_title` hedef davranışın adı; paylaşım ya da klinik silinince olay ailede kalır, `link_id` boşalır (öneri `20261120200000`, karar 3A) |
| `clinic_sessions` | K7 | seans randevusu (tarih, saat, tür, yer, durum, ailenin yanıtı); aile yalnız "aileye göster" açıkken tarih/saat/yer görür |
| `clinic_session_records` | K7 | seans kaydı: katılanlar, gözlem, çalışılan, sonraki adım, gündem; aile görmez |
| `clinic_session_packages` | K7 | seans paketi (seans sayısı; ödeme yok) |
| `clinic_waitlist` | K7 | bekleme listesi ve uygun gün notu |
| `clinic_external_events` | K7 | uzmanın dış takviminden okunan etkinlik (başlık, saat); yalnız uzmanın kendisi görür |
| `clinics` | K8 | |
| `clinic_invites` | K8 | ebeveyn adı/e-postası 30 gün sonra boşaltılır (imha işi) |
| `clinic_routines` | K8 | uzmanın rutin kütüphanesi |
| `clinic_plan_templates` | K8 | uzmanın plan şablonları |
| `clinic_rooms` | K8 | oda ve şube adı |
| `clinic_members` | K8 | uzmanın hangi klinik alanlarında ve hangi rolle çalıştığı, katılma/ayrılma tarihi, ekleyen |
| `clinic_member_requests` | K8 | kliniğin uzmanı ekibe ekleme isteği ve sonucu |
| `clinician_codes` | K1 | uzmanın kalıcı kişisel kodu (yalnız kendisi görür) |
| `clinic_session_settings` | K8 | geç iptal süresi, hatırlatma dakikaları, randevu alma ayarı |
| `clinic_availability` | K8 | uzmanın çalışma saatleri |
| `clinic_calendar_feeds` | K8 | takvim aboneliği belirteci (uzmanın kendisi) |
| `clinic_calendar_sources` | K8 | uzmanın dış takvim adresi (gizli iCal bağlantısı) |
| `clinician_verifications` | K9 | dosya `verify` kovasında, karar anında silinir; özellik kullanılmıyor (kullanıcı 20 Kasım 2026), tablo durur |
| `clinician_surveys` | K10 | |
| `family_subscriptions` | K11 | |
| `billing_subscriptions` | K11 | |
| `billing_events` | K11 | |
| `billing_checkouts` | K11 | |
| `trial_history` | K11 | yalnız e-posta özeti |
| `app_events` | K12 | |
| `activity_days` | K12 | |
| `user_activity` | K12 | |
| `push_tokens` | K12 | |
| `notifications` | K12 | |
| `parent_notification_prefs` | K12 | ebeveynin anlık bildirim tercihi (adım bildirimi, gün tamam); uygulandı 22 Kasım 2026, `migrations/20261120210000` |
| `clinician_notification_prefs` | K12 | uzmanın "Hatırlatmalar ve ipuçları" tercihi (`tips`); uygulandı 22 Kasım 2026, `migrations/20261120230000` |
| `nudge_log` | K12 | otomatik hatırlatma kararı: kime, hangi kural, ne zaman, sonuç (gönderildi / atlandı / karşılaştırma grubu), açıldı mı, 72 saatte hedef adıma geçti mi; metin ve içerik yok. Saklama kullanım kaydıyla aynı olmalı (`42` §4; imha işine eklenmedi). uygulandı 22 Kasım 2026, `migrations/20261120230000` |
| `nudge_pauses` | K12 | üç yanıtsız hatırlatmadan sonraki 14 günlük ara (kişi, bitiş); uygulandı 22 Kasım 2026, `migrations/20261120230000` |
| `notification_push_log` | K12 | anlık bildirim sınırı için gönderim kaydı: gönderen, alıcı, bildirim türü, zaman; içerik yok. Gönderen her yeni bildirimde 1 günden eski satırlarını siler; hesap silinince zincirleme silinir. uygulandı 22 Kasım 2026, `migrations/20261121100000` |
| `referral_paid_transactions` | K11 | davet ödülü üretmiş mağaza işlem kimliği (App Store original transaction id), aile, davet kodu, tarih; bir satın almanın ikinci kez ödül üretmemesi için. Aile silinince aile bağı boşalır, işlem kimliği kalır (yalnız kötüye kullanımı önlemek için; başka veriyle eşlenmez). Yalnız sunucu. uygulandı 22 Kasım 2026, `migrations/20261121100000` |
| `support_source_salts` | — | destek formu kaynak sınırı için günlük rastgele tuz; kişisel veri yok. 2 gün sonra silinir. uygulandı 22 Kasım 2026, `migrations/20261121110000_support_invite_limits.sql` |
| `invite_email_sends` | K12 | davet e-postası gönderim sınırı kaydı: gönderen uzman, davet kodu, alıcı adresin özeti (adresin kendisi yok; Gmail takma adları tek özet), pay (yerleşik / yeni hesap), zaman; içerik yok. Gönderilemeyen e-posta kayıttan düşer; 8 günden eski satırlar her gönderimde silinir. Uzman hesabı silinince satır 8 günlük saklama dolana kadar kalır, uzman bağı boşalır (geriye yalnız özet ve zaman; kişiye bağlanmaz), silip yeniden kaydolmak sınırı sıfırlamasın diye. uygulandı 22 Kasım 2026, `migrations/20261121110000_support_invite_limits.sql` |
| `code_attempts` | K13 | |
| `admin_audit` | K13 | |
| `user_flags` | K13 | |
| `legal_acceptances` | K14 | rastgele kimlik, e-posta/ad yok |
| `kvkk_requests` | K14 | |
| `support_requests` | K15 | /destek formu; kapanan 2 yıl, istenmeyen 30 gün (imha işi). Kötüye kullanım sınırı için gönderen adresin (IPv6 /64) ve geniş ağının (IPv4 /24, IPv6 /48) günlük tuzlu özetleri (`source_hash`, `source_wide_hash`; adres ve ağ düz yazılmaz, panelde gösterilmez), 2 gün sonra boşaltılır, tuz da 2 gün sonra silinir. uygulandı 22 Kasım 2026, `migrations/20261121110000_support_invite_limits.sql` |
| `usage_daily_totals` | — | anonim günlük toplamlar |
| `retention_runs` | — | imha kaydı, yalnız sayı |
| `offer_code_pool` | — | davet ödülü Apple teklif kodu havuzu: kod, ürün, son tarih, atanma zamanı (aileye bağ yok; atanan kod `referral_rewards`te) |
| `storage_trash` | — | silinecek dosya yolları (geçici; yol aile kimliği içerir) |
| `app_config` | — | ayarlar |
| `feature_flags` | — | |
| `nudge_rules` | — | otomatik hatırlatma kuralları ve sabit metinleri (kişiye bağ yok); uygulandı 22 Kasım 2026, `migrations/20261120230000` |
| `store_funnel_daily` | — | App Store Connect günlük toplamları (gösterim, ürün sayfası, indirme; kişi yok); uygulandı 22 Kasım 2026, `migrations/20261120220000` |
| `kpi_benchmarks` | — | iç karşılaştırma için kıyas değerleri ve kaynakları; uygulandı 22 Kasım 2026, `migrations/20261120220000` |
| `legal_documents` | — | yasal metinler |
| `billing_plans` | — | |
| `task_templates` | — | |
| `game_items` | — | |
| `game_levels` | — | |
| `game_level_bands` | — | |
| `one_time_jobs` | — | |

## Avukata notlar

1. **K6 davranış kayıtları / olayları ve K7 uzman kayıtları** metinlerde "özel nitelikli veri içerebilecek kayıtlar" olarak anlatılıyor (14 Kasım 2026 kararı); md. 6 kapsamına girip girmedikleri, ebeveynin kendi kaydı için dayanak, açık rıza metni ve VERBİS beyanı avukatta. Kullanıcının konumu (20 Kasım 2026, A.2): özel nitelik barındırmazlar, ebeveynin uygulamayı kullanma alışkanlığına ilişkin kayıtlardır; public metinlerde bu konum cümlesi yazıldı. Konumumuz bu; md. 6 kapsamının teyidi avukatta. K2/K6 tanışma yanıtlarındaki "çocuk bir uzmanla çalışıyor mu" ve davranış sıklığı soruları için de aynı soru (`README.md` sorun 2).
2. **K8 davet edilen ebeveyn (D):** hesabı olmayan kişinin adı/e-postası uzmanın beyanıyla işleniyor; hukuki sebep ve aydınlatmanın davet e-postasında yapılması yeterli mi.
3. **Yurt dışı aktarım:** Supabase bölgesi Frankfurt (AB; Türkiye dışı); KVKK md. 9 (standart sözleşme + Kurul'a bildirim) avukatta; bölge değişirse bu tablo ve `41` güncellenir.
4. **VERBİS:** kayıt gerekiyorsa bu tablo kayıt formunun kaynağıdır. Kullanıcı görüşü (20 Kasım 2026, A.5): gerekmez (veri sorumlusu gerçek kişi; ana faaliyet özel nitelikli veri işleme değil); avukat teyidi.
