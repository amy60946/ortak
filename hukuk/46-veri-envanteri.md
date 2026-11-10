# Kişisel Veri Envanteri
| Anahtar | iç belge | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | İşletme içi. VERBİS kaydı gerekirse kayıt bu tablodan doldurulur (veri kategorisi, amaç, hukuki sebep, kişi grubu, alıcı grubu, yurt dışı aktarım, süre, tedbir) | Dayanak | KVKK md. 4, 5, 6, 8, 9, 10, 12, 16; Veri Sorumluları Sicili Hakkında Yönetmelik; benzeri GDPR md. 30 (işleme faaliyetleri kaydı) |

## Kısaca

- Sistemde kişisel veri tutan **her tablo** aşağıdaki kategorilerden (K1–K15) birine bağlıdır (Ek A). Yeni tablo eklenince bu dosyaya satır eklenmezse `supabase/test/run.sh` hata verir (`tools/veri_envanteri_kontrol.py`).
- Saklama süreleri ve imha yöntemi ayrı belgede: `42-saklama-imha-politikasi.md` (§4 satır numaraları). Alıcıların ayrıntısı: `41-alt-isleyenler.md`. Olgular: `00-olgular.md`.
- Köşeli parantezli alanlar avukat ve kullanıcı kararıyla dolar (`[SUPABASE BÖLGESİ]`, hukuki sebep "avukat" yazan satırlar).
- Hazırlanış: 2 Kasım 2026, şemadan (göçler + öneriler) üretildi; olgu değişirse önce `00-olgular.md`, sonra burası.

## 1. Kategoriler

Kişi grupları: **E** ebeveyn · **Ç** çocuk · **U** uzman · **D** davet edilen ebeveyn (henüz hesabı yok) · **T** ekip (yönetim paneli).
Alıcılar (hepsinde Supabase, `41` satır 1): **A** Apple (abonelik, anlık bildirim metni) · **X** Expo (yedek bildirim yolu) · **R** RevenueCat · **M** Resend (e-posta) · **C** Cloudflare (panel) · **Uz** ebeveynin açık rızasıyla paylaştığı uzman.
Yurt dışı: Supabase `[SUPABASE BÖLGESİ]`; A, X, R, M ABD (ve/veya AB); C küresel. KVKK md. 9 (standart sözleşme + Kurul'a bildirim) avukatta.

| # | Kategori | Kişi | Veri | Amaç | Hukuki sebep (öneri) | Alıcı | Saklama (`42` §4) |
|---|---|---|---|---|---|---|---|
| K1 | Kimlik ve iletişim | E, U, T | ad, takma ad, simge, e-posta, şifre özeti (yalnız kimlik sağlayıcıda), unvan | Hesap açma, giriş, iletişim | md. 5/2-c sözleşmenin kurulması ve ifası | M, C | 1, 8 |
| K2 | Aile ve çocuk profili | E, Ç | aile adı, çocuğun adı/takma adı, simgesi, isteğe bağlı cinsiyet ve doğum günü, yaş grubu, aile/çocuk kodları, cihaz bağlantısı | Ailenin ve çocuğun uygulamayı kullanması | md. 5/2-c; veli beyanı (çocuk verisi veliden) | Uz (rızayla), C | 2 |
| K3 | Görev, onay, ödül, sanal değer | E, Ç | görevler, tekrarlar, "Yaptım", onay/ret ve notu, ödüller, istekler, coin ve Güneş Taşı defterleri, haftalık hedef, ebeveynin ders kayıtları (başladığı/öğrendiği ders, uygulama günleri) | Ürünün temel işlevi | md. 5/2-c | Uz (rızayla), C | 2 |
| K4 | Oyun kaydı | Ç | seviye, XP, eşyalar, ada düzeni | Oyunun sürmesi, cihaz değişince geri yükleme | md. 5/2-c | — | 2, 30 |
| K5 | Aile içi iletişim içeriği | E, Ç | mesaj yazısı, fotoğraf, sesli mesaj, çıkartma, okundu | Ebeveyn ile çocuk arasında mesajlaşma | md. 5/2-c | — | 3 |
| K6 | Davranış kayıtları | E, Ç | öncül–davranış–sonuç, şiddet, ses kaydı, zaman | Ebeveynin gözlem günlüğü; rızayla uzmanla paylaşım | md. 5/2-c; **sağlık verisi sayılırsa md. 6/3 açık rıza** — avukat (`hukuk_notlari.md`) | Uz (rızayla) | 4 |
| K7 | Uzmanla paylaşım ve danışan kayıtları | Ç, E, U | paylaşım ve rıza sürümü, uzman notları (aile görmez), hedefler, haftalık değerlendirme, görev önerileri, takip planı ve ev programı kayıtları, uzmanın önerdiği ebeveyn dersi ve ebeveynin o dersteki uygulama günleri (öneriden sonrası), seans randevuları ve seans kayıtları (psikolog/terapistle randevunun varlığı sağlık verisi sayılabilir, md. 6) | Uzmanın aileyle çalışması | Paylaşım: **açık rıza** `uzman-paylasim-v1`, geçiş `uzman-gecis-v1`; uzman kayıtlarında veri sorumlusu (klinik mi platform mu) avukatta | Uz, C | 7, 9, 9a |
| K8 | Klinik, ekip ve davet | U, D | klinik adı, ekip rolü, koltuk; davette ebeveyn adı/e-postası, çocuğun adı ve yaş grubu, davet kanalı; uzmanın rutin ve şablon kütüphanesi | Klinik hesabı ve aile daveti | md. 5/2-c (uzman); D için uzmanın beyanı + md. 5/2-f — avukat | M (davet e-postası) | 8, 10 |
| K9 | Mesleki belge incelemesi | U | belge dosyası (karar anında silinir), özet (üniversite, bölüm, derece, yıl), barkod, BACB no, karar | Ailelere "Belgesi incelendi" rozeti | md. 5/2-c (uzmanın talebi); T.C. kimlik no saklanmaz | — | 11, 12 |
| K10 | Uzman karşılama anketi | U | meslek, zorluklar, yararlı özellikler, geliş nedeni | Ürün geliştirme | md. 5/2-f meşru menfaat (isteğe bağlı, atlanabilir) | — | 13 |
| K11 | Abonelik ve ödeme | E, U | plan, durum, bitiş, mağaza işlem kimliği, ödeme olayları, deneme geçmişi (e-posta özeti SHA-256) | Aboneliğin yürütülmesi, deneme suistimalini önleme | md. 5/2-c; vergi kaydı md. 5/2-ç; deneme geçmişi md. 5/2-f | A, R | 14, 15, 16 |
| K12 | Kullanım, cihaz ve bildirim | E, Ç, U | uygulama açma günleri, oturum sayısı, sürüm, platform, ekran/olay adları (içerik yok), bildirim jetonu, uygulama içi bildirimler | Hizmetin işletilmesi, ürün ölçümü, bildirim gönderimi | md. 5/2-f meşru menfaat (üçüncü taraf analiz yok); bildirim md. 5/2-c | A, X (bildirim metni) | 18, 19, 20 |
| K13 | Güvenlik ve ekip işlemleri | E, Ç, U, T | kod denemeleri, ekip rolü, ekip işlemleri denetim kaydı (gerekçe, önce/sonra), kişiye özel ayar istisnaları | Kötüye kullanımı önleme, hesap verebilirlik | md. 5/2-f; md. 12 (güvenlik) | C | 17, 22 |
| K14 | Hukuki işlemler | E, U, (Ç veli eliyle) | yasal metin onay kaydı (rastgele kimlikle), KVKK başvuruları (yanıt e-postası dahil) | İspat, başvuruların yanıtlanması | md. 5/2-ç hukuki yükümlülük; md. 5/2-e hakkın tesisi | C | 23, 24 |
| K15 | Destek talepleri | E, U (yetişkin beyanıyla) | e-posta, isteğe bağlı ad, uygulama, konu, mesaj, ekibin iç notu | Talebin yanıtlanması | md. 5/2-c (kullanıcıysa) / md. 5/2-f; KVKK başvurusu niteliğindeyse md. 5/2-ç | C (form sayfası) | 25 |
| — | Kişisel veri içermeyenler | — | katalog ve ayarlar, anonim günlük kullanım toplamları, imha kaydı (yalnız sayı) | İşletme | — | — | 27 |

## 2. Teknik ve idari tedbirler (md. 12)

Satır düzeyi güvenlik (herkes yalnız kendi ailesini/kliniğini görür; her yeni tabloda zorunlu ve testli), girişsiz rolün hiçbir işleve erişememesi (`test_security.sql`), TLS, özel dosya kovaları ve kısa süreli imzalı bağlantı, ekip panelinde iki adımlı doğrulama + rol + gerekçe + silinemez denetim kaydı, panelden dışa aktarmanın gerekçeyle kayda geçmesi, zamanlanmış imha işi ve imha kaydı, sistem sağlığı izleme ve alarm (`sozlesme/admin.md`), veri ihlali prosedürü (`43`), şifre/anahtarın depo dışında tutulması.

## 3. İlgili kişinin hakları (md. 11)

"Verimi indir" (`my_data_export`; ParentApp ve ClinicApp ayarlarında) ve panelden destek rolüyle dışa aktarma (`admin_user_export`): hesabın ve velisi olunan çocukların kayıtları; diğer ebeveynin yazdıkları ayıklanır. Silme: uygulama içi "Hesabımı sil". Başvuru: `44-kvkk-basvuru-usulu.md`.

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
| `review_child_codes` | K2 | App Review için kalıcı inceleme kodu (yalnız inceleme ailesinin çocuğu; kullanım sayısı + son kullanım; SQL Editor'den açılır/kapanır) |
| `child_goal_settings` | K3 | |
| `tasks` | K3 | |
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
| `intake_answers` | K2, K6 | tanışma yanıtları (aile ve çocuk); tanı/ilaç yanıtları isteğe bağlı, açık rıza `saglik-yanit-v1` (sağlık verisi) |
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
| `parent_trainings` | K7 | uzmanın ebeveyne verdiği eğitim (9 Kasım 2026 önerisi; ebeveyn adı, ustalık ölçütü) |
| `parent_training_modules` | K7 | ebeveynin modül tamamlaması, test yanıtları ve açık uçlu yanıtları (çocuğuna dair metin olabilir) |
| `parent_training_tasks` | K7 | uzmanın yazdığı uygulama görevi |
| `parent_training_logs` | K7 | ebeveynin uygulama kaydı ve düşüncesi |
| `parent_training_todos` | K7 | hızlı yapılacaklar, ebeveynin işareti |
| `parent_training_data` | K7 | uzmanın gözlem verisi (aile görmez) |
| `clinic_target_behaviors` | K7 | uzmanın tanımladığı hedef davranış ve stratejiler (9 Kasım 2026 önerisi) |
| `behavior_incidents` | K6 | ebeveynin bildirdiği davranış olayı: zaman, süre/sayı, öncesi-sonrası, strateji, çocuğun tepkisi (sağlık verisi sayılabilir) |
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
| `clinician_verifications` | K9 | dosya `verify` kovasında, karar anında silinir |
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
| `child_push_settings` | K12 | çocuğa anlık bildirim ayarı (ebeveyn açar/kapatır, sessiz saatler; K7 B) |
| `notifications` | K12 | |
| `code_attempts` | K13 | |
| `admin_audit` | K13 | |
| `user_flags` | K13 | |
| `legal_acceptances` | K14 | rastgele kimlik, e-posta/ad yok |
| `kvkk_requests` | K14 | |
| `support_requests` | K15 | /destek formu; kapanan 2 yıl, istenmeyen 30 gün (imha işi) |
| `usage_daily_totals` | — | anonim günlük toplamlar |
| `retention_runs` | — | imha kaydı, yalnız sayı |
| `offer_code_pool` | — | davet ödülü Apple teklif kodu havuzu: kod, ürün, son tarih, atanma zamanı (aileye bağ yok; atanan kod `referral_rewards`te) |
| `storage_trash` | — | silinecek dosya yolları (geçici; yol aile kimliği içerir) |
| `app_config` | — | ayarlar |
| `feature_flags` | — | |
| `legal_documents` | — | yasal metinler |
| `billing_plans` | — | |
| `task_templates` | — | |
| `game_items` | — | |
| `game_levels` | — | |
| `game_level_bands` | — | |
| `one_time_jobs` | — | |

## Avukata notlar

1. **K6 davranış kayıtları ve K7 uzman kayıtları** sağlık verisi (md. 6) sayılır mı; sayılırsa açık rıza metni ve VERBİS beyanı buna göre.
2. **K8 davet edilen ebeveyn (D):** hesabı olmayan kişinin adı/e-postası uzmanın beyanıyla işleniyor; hukuki sebep ve aydınlatmanın davet e-postasında yapılması yeterli mi.
3. **Yurt dışı aktarım:** Supabase bölgesi seçilince bu tablo ve `41` güncellenir.
4. **VERBİS:** kayıt gerekiyorsa bu tablo kayıt formunun kaynağıdır.
