# Canlıya alma listesi (üç uygulama)

Ayrıntılı plan, gerekçeler ve öneriler: **Canlıya Alma Planı** belgesi https://claude.ai/artifact/7DAFNbjtvLMLTwKiG7DRv7
Adım adım yol haritası (7 aşama, 4 kapı), pencere başına iş listesi, Apple'ın istediği alanlar ve App Store pazarlaması 0→100: **Canlıya Alma: Adım Adım ve Pencere İşleri** https://claude.ai/artifact/LdikjQHgM6Wgmv3QE7A8qd (2 Kasım 2026, kullanıcı isteği GB20-19; her pencere kendi başlığındaki kutuları alır)
Bu dosya pencerelerin ortak takip listesidir; bir madde bitince `[x]` yapılır ve `DURUM.md`'ye satır yazılır.
Kim: **Siz** = kullanıcı (hesap, ödeme, imza, karar) · **Claude** = kod/SQL/metin · **Hukuk/MM** = avukat / mali müşavir.


> **Durum (23 Ekim 2026): BEKLEMEDE.** Kullanıcı "devam edelim" deyince **1.2 Alan adı** maddesinden sürer (ayrıntı `DURUM.md` → Açık işler → BEKLEMEDE).
## 1. Ortak altyapı (bitmeden hiçbir uygulama mağazaya çıkmaz)

### 1.1 Şirket ve hesaplar
- [ ] (Siz) Şirket/vergi kaydı, faturayı kesecek tüzel kişi
- [x] Apple Developer hesabı: **kişisel** (22 Ekim; ileride şirkete taşınabilir)
- [ ] (Siz) Mali müşavir + şahıs şirketi (vergi kaydı, e-Arşiv fatura için şart)
- [ ] (Siz) App Store Connect: Paid Apps sözleşmesi, banka, vergi
- [x] Google Play: **iOS'tan sonra** ayrı aşama (22 Ekim)
- [ ] (Siz) Supabase Pro plan (yedek, duraklatma yok)

### 1.2 Alan adı ve web
- [x] (Siz) Alan adı — **alındı 6 Kasım 2026 (Natro):** asıl `moyoapp.com.tr`; yedek `moyomercek`, `moyoappmercek`, `moyoappklinik`, `moyooyun` (.com.tr). Yapı: `moyoapp.com.tr` ebeveyn tanıtım + `/destek` + `/yasal/*` + `/d/*` davet; `ebeveyn.` ebeveyn web giriş; `mercek.` Moyo Mercek (uzman ürünü) tanıtım; `uzman.` uzman girişi; panel ayrı adres. Önizleme dönemi: siteler gerçek adreste ama Cloudflare Access kilidi arkasında (yalnız kullanıcı), `/destek` ve `/yasal` açık.
- [x] (Siz) Natro → Cloudflare ad sunucusu değişikliği (6 Kasım 2026, alan adı Cloudflare'de etkin)
- [x] (Claude, yönetim paneli) **Cloudflare kurulumu (6 Kasım 2026):** Zero Trust (Free) + giriş yöntemi "E-posta kodu" (one-time PIN). Access uygulamaları: **"Moyo onizleme kilidi"** (`moyoapp.com.tr`, `ebeveyn.`, `mercek.`, `uzman.`; yalnız sahip, 7 gün oturum), **"Herkese acik: destek, yasal, AASA"** (`/destek`, `/yasal`, `/.well-known/apple-app-site-association`; bypass), **"Yonetim paneli (workers.dev)"** (`admin-panel.amy60946.workers.dev` + sürüm önizlemeleri; yalnız sahip, 24 saat) ve panel adresindeki `/destek` `/yasal` için bypass (yeni adrese 301). Kurallar Access'te tekrar kullanılabilir iki politika: "Yalniz sahip" (sahibin e-postası; depoya yazılmaz) ve "Herkese acik (bypass)". DNS: dört adres için kaynaksız `AAAA 100::` (proxied; Worker route'ları için, silinmez). Route'lar: `moyoapp.com.tr/destek`, `/destek/*`, `/yasal`, `/yasal/*` → Worker `admin-panel` (kökün geri kalanı ParentApp sitesinin). Denendi: kilitli adresler girişe, açık yollar sayfaya gidiyor.
- [ ] (Siz) Supabase → Edge Functions → Secrets → `LEGAL_PUBLIC_URL` = `https://moyoapp.com.tr` (yasal metin ve destek bağlantıları doğrudan yeni adrese gider; yapılmasa da eski adres yönlenir).
- [ ] (Siz) App Store Connect (üç uygulama) › App Information: **Privacy Policy URL** `https://moyoapp.com.tr/yasal/gizlilik`, sürüm sayfasında **Support URL** `https://moyoapp.com.tr/destek`. **Marketing URL** önizleme kilidi kalkana dek boş (kilitli sayfa inceleyiciye giriş ekranı gösterir).
- [ ] (ParentApp, ClinicApp pencereleri + Siz) Siteleri Cloudflare Worker olarak yayınla: `moyo-site` (kök), `moyo-ebeveyn`, `moyo-mercek`, `moyo-uzman`; `workers_dev` ve `preview_urls` **kapalı** (yoksa workers.dev adresi kilitsiz açık kalır), route/özel alan adı yapılandırmada yok; depoyu Cloudflare'e siz bağlarsınız (Workers & Pages › Create › Import a repository). İlk yayından sonra yönetim paneli penceresi route'ları bağlar.
- [ ] (Canlıya geçerken, yönetim paneli) Önizleme kilidini kaldır: Access › "Moyo onizleme kilidi" silinir (ya da yalnız `ebeveyn.`/`uzman.` gibi gerekirse daraltılır); panel kilidi kalır. Ardından Marketing URL'leri girilir.
- [ ] (Claude) Tanıtım + Gizlilik + Kullanım Koşulları + Destek sayfaları (3 ürün)
- [ ] (Claude) ClinicApp sitesi yayını, auth yönlendirmeleri, `APP_URL`
- [ ] (Claude) Universal Links (`apple-app-site-association`)

### 1.3 E-posta (Resend) — **iki uygulama için tek hesap, tek alan adı** (kullanıcı isteği 10 Kasım 2026: "hizalanarak, olabiliyorsa aynı hesaplardan"; ParentApp + Klinik pencereleri birlikte)
Karar: Resend ücretsiz (22 Ekim). Ücretsiz plan 1 alan adı verir; ikimize `moyoapp.com.tr` yeter. Supabase Auth SMTP proje başına tek: onay / şifre sıfırlama / e-posta değişikliği şablonları **iki uygulamada ortak**, tek gönderici adıyla gider. İş bölümü: ortak Auth şablonları ParentApp penceresi (uzman cümleleri Klinik'e gösterilir); `invite-email` ve ClinicApp'e özgü e-postalar Klinik penceresi; DNS yönetim paneli penceresi (Cloudflare anahtarı) ya da kullanıcı.
- [ ] (Siz) 1. resend.com'da hesap → Domains › Add domain › `moyoapp.com.tr` (bölge Avrupa)
- [ ] (Siz ya da yönetim paneli) 2. DNS: Resend'in gösterdiği SPF + MX (`send` alt alanında), DKIM (`resend._domainkey`), DMARC (`_dmarc`, başta `p=none`); Cloudflare'de "DNS only". Resend'in "Cloudflare'e otomatik kur" düğmesi de olur
- [ ] (Siz) 3. "Verified" olunca API Keys › yalnız gönderme yetkili **iki anahtar**: Supabase SMTP için, Edge Functions için (sohbete yapıştırılmaz)
- [ ] (Siz) 4. Supabase › Authentication › Emails › SMTP Settings: `smtp.resend.com`, port 465, kullanıcı `resend`, şifre = 1. anahtar, gönderen `noreply@moyoapp.com.tr`, ad **Moyo**; Rate Limits'te saatlik e-posta sınırını yükselt
- [ ] (ParentApp penceresi) 5. Türkçe Auth şablonları (onay, şifre sıfırlama, e-posta değişikliği, sihirli bağlantı, davet): nötr metin, uygulamaya göre fark dönüş adresinden (`parentapp://`, `ebeveyn.moyoapp.com.tr`, `clinicapp://`, `uzman.moyoapp.com.tr`) → (Siz) Authentication › Email Templates'e yapıştır
- [ ] (Siz) 6. Edge Functions › Secrets: `RESEND_API_KEY` = 2. anahtar, `MAIL_FROM` = `davet@moyoapp.com.tr`, `BRAND_NAME` = `Moyo`
- [ ] (Siz) 7. Gelen posta `destek@`, `kvkk@`, `fatura@`: Cloudflare › Email › Email Routing (ücretsiz, kökte MX; Resend'in MX'i `send` alt alanında, çakışmaz) → kendi posta kutunuza yönlendir
- [ ] (Claude, iki pencere) 8. Gmail / Outlook / iCloud uçtan uca deneme (kayıt onayı, şifremi unuttum: ParentApp + ClinicApp; davet e-postası)
- [ ] (Siz + iki pencere, birlikte seçilen an) 9. Authentication › Providers › Email › **Confirm email açık** — iki uygulamayı birden etkiler; App Review deneme hesapları önceden onaylı olmalı
- [ ] (Claude) Şifremi unuttum akışı (ParentApp, ClinicApp; `parentapp://`, `clinicapp://`) — ekranlar var, 8. adımda denenir
- [ ] (Claude) İşlem e-postaları: hoş geldin, deneme bitiyor, ödeme + fatura, hesap silindi (sonra; Resend Edge Function'dan)

### 1.4 Destek
- [ ] (Siz) `destek@`, `kvkk@`, `fatura@` posta kutuları
- [ ] (Claude) Uygulama içi "Yardım ve iletişim" (oyunda ebeveyn kapısı arkasında) — **destek sayfası ve formu yazıldı** (2 Kasım: `/destek`, sabit adres `…/functions/v1/support`, panel Destek kuyruğu; `sozlesme/admin.md` "Destek"); kalan: (Siz) SQL + `support` işlevi, (uygulama pencereleri) bağlantıyı ekle
- [ ] (Claude) SSS
- [ ] (Siz) Yanıt süresi; KVKK başvurusu yasal süre 30 gün

### 1.5 Hukuk metinleri (taslak Claude, onay Hukuk)
> **HUKUK ARŞİVİ — canlıya almadan önce kullanıcıya hatırlat (kullanıcı isteği 27 Ekim 2026).** Bütün hukuki metinler tek yerde: **`hukuk/`** (dizin + fonksiyon→hukuk haritası + bulunan sorunlar: `hukuk/README.md`; 15 taslak metin ve iç belge) ve karar notları `sozlesme/hukuk_notlari.md` (avukata sorular 5. bölüm). Avukatla bu dosya üzerinden ilerlenir; onaylanan metinler bu listeye işaretlenir.
- [ ] Kullanıcının platforma verdiği aktarım/işleme yetkileri (hizmet sağlayıcılar, yurt dışı, yetkili ekip erişimi, tanışma yanıtları, ölçüm, kanuni zorunluluk, işletme devri, onay kaydı): `hukuk_notlari.md` 3I
- [ ] KVKK Aydınlatma Metni (ebeveyn / çocuk / uzman; `trial_history`)
- [ ] Açık Rıza Metni (çocuk verisi, uzman paylaşımı, yurt dışı aktarım, pazarlama ayrı)
- [ ] Gizlilik Politikası (herkese açık URL)
- [ ] Kullanım Koşulları / EULA (abonelik bağlantısı uygulamada + mağazada)
- [ ] Mesafeli Satış Sözleşmesi + Ön Bilgilendirme Formu: web satışı olmadığı için şimdilik gerekmez (abonelik koşulları Kullanım Koşulları'nda)
- [ ] Uzman Hizmet Sözleşmesi + Veri İşleme Eki
- [ ] Ebeveyn kullanım koşulları — veli beyanı, uzmanı tanıma yükümlülüğü, platform sorumluluk sınırı (`sozlesme/hukuk_notlari.md` 3F–3G); uzman sözleşmesi — davette çocuk bilgisi ve uzman beyanları (A9–A11)
- [ ] Uzman değişiminde kayıt aktarımı: uzman sözleşmesi maddeleri + ebeveyn açık rıza metni (sürüm `uzman-gecis-v1`) + aydınlatma eklemeleri; taslak `sozlesme/hukuk_notlari.md`, avukata sorular 5. bölümde
- [ ] Çerez politikası + bant (ClinicApp web)
- [ ] "Tanı değildir" uyarı metni
- [ ] (Claude) Uygulamalara yerleştirme + sürümlü onay kaydı

### 1.6 KVKK işlemleri
- [ ] (Hukuk) VERBİS gerekliliği
- [ ] (Hukuk) Yurt dışı aktarım: standart sözleşme + Kurul'a bildirim
- [x] (Claude) Kişisel veri envanteri: `hukuk/46-veri-envanteri.md` (VERBİS biçimi, 14 kategori; taslak, avukat onayı bekler) + her yeni tabloyu denetleyen `tools/veri_envanteri_kontrol.py` (2 Kasım 2026)
- [ ] (Claude) Saklama ve imha işi (zamanlanmış) — **yazıldı ve testli** (`proposed/20261102200000_kvkk_ops.sql`, gece 03.17, kuru çalıştırmayla başlar); kalan: (Siz) SQL'i uygula, (Hukuk) süreler → panelden gerçek silme
- [ ] (Claude) Verimi indir (aile verisi dışa aktarma) — **sunucu yazıldı** (`my_data_export`, panelde `admin_user_export`); kalan: (Siz) SQL, (ParentApp/ClinicApp penceresi) Ayarlar › Gizlilik › Verimi indir
- [ ] (Claude) Ebeveyn onayının sürümlü kaydı (çocuk bağlanmadan önce)
- [ ] (Siz + Hukuk) Veri ihlali prosedürü (72 saat)

### 1.7 Hesap silme
- [x] Sunucu: `delete_account()` (ebeveyn, uzman)
- [ ] (Claude) Üç uygulamada görünür "Hesabımı sil" + web talep sayfası · ParentApp yapıldı (2 Kasım: Aile › Hesap'ta Çıkış Yap'ın altında ayrı satır)
- [ ] (Claude) Oyun: bağlantı kopunca/aile silinince yerel kayıt temizliği
- [ ] (Claude) Aktif abonelikte "Apple'dan iptal edin" uyarısı · ParentApp yapıldı (2 Kasım: sunucu + RevenueCat durumu, uygulama içi abonelik yönetimi; silme serbest)

### 1.8 Ödeme (RevenueCat) — **iki uygulama için tek hesap, tek proje "Moyo"** (kullanıcı isteği 10 Kasım 2026; ParentApp + Klinik pencereleri birlikte)
Karar: ParentApp ve ClinicApp ödemesi RevenueCat (22 Ekim; klinik sahibi birey olarak öder; iyzico yok). Ortaktaki `supabase/functions/billing-webhook` ikisini tek uçtan işler (aile → `family_subscriptions`, klinik → `billing_apply`). Proje genelinde entitlement ve offering listesi ortaktır: **ParentApp** entitlement `premium` + offering `default`; **ClinicApp** entitlement `clinic` + offering `clinic` (`getOfferings().all['clinic']`, `current` değil). İki uygulamada `appUserID` = Supabase kullanıcı kimliği. **Mağaza ücretsiz denemesi (intro offer) iki uygulamada da eklenmez:** deneme sunucuda ve kartsız (ParentApp 7 gün, ClinicApp 14 gün; ortak#172).
A. App Store Connect
- [ ] (Siz) 1. Business › Agreements › **Paid Apps** sözleşmesi + banka + vergi (etkin olmadan abonelikler TestFlight'ta da yüklenmez; onayı günler sürebilir, ilk iş)
- [ ] (Siz) 2. Users and Access › Integrations › **In-App Purchase** anahtarı (.p8 + Key ID + Issuer ID; bir kez indirilir, sohbete değil RevenueCat paneline)
- [ ] (Siz) 3. ParentApp › Subscriptions: grup "Moyo Premium", `parentapp.premium.monthly` (1 ay), `parentapp.premium.yearly` (1 yıl); TR fiyatı, Türkçe ad/açıklama, inceleme ekran görüntüsü (ilk abonelikler sürümle birlikte incelemeye gider)
- [ ] (Siz) 4. ClinicApp › Subscriptions: `com.clinicapp.uzman.solo.{monthly,yearly}`, `com.clinicapp.uzman.clinic.{monthly,yearly}` (ayrıntı Klinik penceresi)
B. RevenueCat
- [ ] (Siz) 5. Hesap + proje **"Moyo"**; iki App Store uygulaması (`com.parentapp.ios`, `com.clinicapp.uzman`), ikisine 2. adımdaki .p8 + Key ID + Issuer ID
- [ ] (Siz) 6. Her uygulamanın RevenueCat'teki "Apple Server Notification URL"si → App Store Connect › o uygulama › App Information › App Store Server Notifications (Production + Sandbox, Version 2)
- [ ] (Siz) 7. Product catalog: ürünleri içe aktar; ParentApp `premium` + `default` (aylık + yıllık paket); ClinicApp `clinic` + `clinic`
- [ ] (Siz) 8. API Keys: ParentApp genel anahtarı `appl_…` → parent-app GitHub Secrets `EXPO_PUBLIC_REVENUECAT_IOS_KEY`; ClinicApp genel anahtarı → clinic-app (Klinik penceresi söyler); **gizli anahtar** `sk_…` (API sürümü sorulursa v1; işlev REST v1 `/subscribers` okur)
- [ ] (Siz) 9. Integrations › Webhooks: `https://uhelhxqgpcjemadhsifx.supabase.co/functions/v1/billing-webhook`, Authorization = `Bearer <en az 24 karakterlik rastgele şifre>`
C. Supabase
- [ ] (Claude verir, Siz yayınlarsınız) 10. Edge Function `billing-webhook` (index.ts + state.ts), **Verify JWT kapalı**
- [ ] (Siz) 11. Edge Functions › Secrets: `BILLING_WEBHOOK_SECRET` (9. adımdaki şifre, "Bearer" olmadan), `REVENUECAT_API_KEY` (`sk_…`), denemede `BILLING_ALLOW_SANDBOX` = `1`
D. Uygulamalar ve deneme
- [x] (ParentApp penceresi) `react-native-purchases` 10.16.x (`parent-app/src/lib/purchases.ts`): `configure(appUserID)`, `logIn` / `logOut`, üyelik ekranı, geri yükle, "Aboneliği yönet", fiyat mağazadan; anahtar yoksa ödeme "bağlı değil" (2 Kasım 2026)
- [ ] (ClinicApp penceresi) `expo-iap` / `clinic-billing` yerine `react-native-purchases`: yalnız klinik sahibine üyelik ekranı, geri yükle, yönet; web'de "iPhone/iPad'den alın". Çalışma alanları: satın almadan önce RevenueCat abone niteliği `clinic_id`, `billing-webhook` onu okur (öneri Klinik penceresinde; webhook ortak, değişiklik DURUM'a)
- [ ] (Claude, iki pencere) 12. TestFlight'ta satın al, geri yükle, iptal, iade, grace period (TestFlight alışverişi ücretsiz deneme ortamıdır)
- [ ] (Siz) Gerçek fiyatlar
- [ ] En son (yayından önce): `BILLING_ALLOW_SANDBOX` silinir; yönetim panelinde `billing.enforce = true`
- [x] (Claude) KVKK aydınlatma metnine RevenueCat (yurt dışı veri işleyen) (`hukuk/10-aydinlatma-ebeveyn.md`, `hukuk/41-alt-isleyenler.md` 3.4; Resend 3.5)
- [x] iyzico: **gerekmiyor** (22 Ekim: klinik de birey olarak App Store'dan öder; web'de satış yok)
- [x] `20261022200000_clinic_billing.sql` uygulandı (23 Ekim)
- [ ] (Siz) **Aile davet et ödülü için Apple teklif kodu** (3 Kasım 2026) · **Canlıya alırken hatırlat (kullanıcı, 3 Kasım 2026):** kod üretme + panele yükleme ParentApp yayından önce yapılır. App Store Connect › ParentApp › Abonelikler › **aylık ve yıllık ürün ayrı ayrı** › Offer Codes › "1 ay ücretsiz" (mevcut aboneler), tek kullanımlık kodlar (en çok 6 ay geçerli) → dosyayı indir → yönetim paneli › **Davetler** › "Kod dosyası yükle" (ürün + App Store Connect'teki son tarih). App Store'dan ödeyen davet edene uygun kod kendiliğinden gider (`referral_rewards` `code_pending` → `code_sent`; `sozlesme/admin.md` "Davet ödülleri"). SQL uygulandı (3 Kasım 2026). Kodlar test ortamında denenemez: ilk kodu kendi gerçek aboneliğinde dene. Süre dolmadan (Sistem sağlığı uyarır) yeni parti üret

### 1.9 Fatura
- [ ] (MM) App Store gelirinin faturalanması (Apple'a)
- [ ] (Siz) e-Arşiv/e-Fatura özel entegratörü: **şimdilik gerekmez** (tüm satış App Store'da, müşteriye faturayı Apple keser); web satışı başlarsa gerekir
- [ ] (Claude) Ödeme → fatura → PDF e-posta: şimdilik gerekmez (yukarıdaki ile aynı koşul)
- [ ] (Claude) Fatura bilgisi alanları: şimdilik gerekmez

### 1.10 Güvenlik ve işletme
- [x] RLS + sızma testleri, anon kapalı, hız sınırları
- [ ] (Siz + Claude) Staging Supabase projesi
- [ ] (Siz) Günlük yedek + PITR + bir geri yükleme denemesi
- [ ] (Claude) İzleme ve alarm (sunucu, Edge Function, webhook) — **yazıldı**: `ops_health` + Edge Function `health` + panel Sistem sağlığı + saatlik GitHub yoklaması (`.github/workflows/saglik.yml`); kalan: (Siz) SQL + `health` yayını, isteğe bağlı Sentry Uptime
- [ ] (Siz) `PUSH_SECRET`
- [ ] (Claude) Push anahtarı taşıma riski kapatılsın
- [ ] (Siz) Geliştirme anahtarlarının yenilenmesi

## 2. Uygulamalar

### 2.1 Hepsi
- [x] Yayın biçimi: **elle** (kullanıcı, 2 Kasım 2026): App Store Connect → sürüm → "Manually release this version". Apple onaylar, kullanıcı onay verince yayına alınır (üç ürün)
- [ ] (Siz) iOS imza / sertifika sınırı (ParentApp + GameApp)
- [ ] (Claude) `PrivacyInfo.xcprivacy` · ParentApp yapıldı (2 Kasım: `app.json` → `ios.privacyManifests`; izleme yok, 14 veri türü, gerekçe kodları)
- [ ] (Siz + Claude) App Privacy etiketi · ParentApp taslağı: "ParentApp mağaza paketi" https://claude.ai/artifact/JNi1LAZC4A2cZFSm42Njym
- [ ] (Siz) Yaş derecelendirme anketi
- [ ] (Claude) Ekran görüntüleri, açıklama, anahtar kelimeler
- [ ] (Claude) App Review deneme hesabı + kalıcı inceleme çocuk kodu + not · ParentApp notu ve hesap planı taslak (aynı belge)
- [ ] (Claude) Bildirim izni ilk gereken anda
- [ ] (Claude) Yeni simge biçimi (Icon Composer)
- [ ] (Siz) TestFlight dış deneme (5–10 aile, en az 1 uzman)

### 2.2 GameApp
- [x] Kids Kategorisi: **hayır, normal oyun** (22 Ekim). Yine de Apple 5.1.4: üçüncü taraf analitik yok, dış bağlantılar ebeveyn kapısı arkasında; mağaza metninde "çocuklar için" yok
- [x] Kodsuz başlangıç: **hayır** (kullanıcı, 22 Ekim) — oyun bugünkü gibi kodla açılır; App Review için kalıcı deneme kodu (2.1)
- [ ] (Claude) İlk dokunuşa kadar süre ölçümü (hedef iPhone 11'de < 10 sn); pet adı ekranı atlanabilir
- [ ] (Claude) Çekirdek döngüler `docs/PLAN.md`'de iki cümle
- [ ] (ortak) Aile aboneliği bitince çocuk cezalandırılmaz kuralı (oyun ve birikimler kalır)
- [ ] (Claude) İlk 3 ay için 2–3 mevsimlik etkinlik planı (In-App Events)
- [ ] (Claude) App Preview oynanış videosu (≤ 30 sn, iPhone + iPad)
- [ ] (Karar) En düşük iOS 15.0 → 17 önerisi
- [ ] (Claude) Ebeveyn kapısı: ayarlar, dış bağlantı, destek, yasal, bağlama
- [ ] (Claude) Ödül dükkânı birleştirme, mesaj kutusu, bildirim + push anahtarı, yaş bandı C, avatar fotoğrafı
- [ ] (Claude) `track_events('child')` (üçüncü taraf yok)
- [ ] (Claude) Açılışta doğrudan oyun; ipuçları atlanabilir + "Nasıl oynanır"
- [ ] (Claude) Paket boyutu ve eski cihaz performansı ölçümü
- [ ] (Siz) "Quests", "Güneş Taşı" adları; yükleme ekranı görseli

### 2.3 ParentApp
- [ ] (Siz) **iPad ekran görüntüleri** (3 Kasım 2026: ParentApp artık iPad'i destekliyor, `supportsTablet: true`, iPad'de dikey + yatay): App Store Connect 13 inç iPad görüntüsü ister. Not: iPad desteği yayından sonra geri alınamaz
- [x] (Claude) Kayıt onayı + şifremi unuttum ekranları (var: `AuthScreens.tsx`, bağlantılar `parentapp://auth`)
- [x] (Claude) Abonelik ekranı 3.1.2 uyumu (fiyat, süre, yenileme, bağlantılar, geri yükle); ilk değerden sonra göster · 2 Kasım: fiyat mağazadan; deneme bitince açılır
- [x] (Claude) "Aboneliği yönet" (2 Kasım: uygulama içi Apple sayfası `showManageSubscriptions`)
- [ ] (Claude) `track_session` / `track_events('parent')`
- [ ] (Claude) Mesajlar + Ödüller uçtan uca deneme
- [ ] (Claude) Uzman önerisi alanlarının göreve taşınması
- [ ] (Claude) Uzman paylaşımında açık rıza metni + geri al

### 2.4 ClinicApp
- [ ] (Siz) Alan adı + barındırma → site
- [ ] (Claude) Üyelik canlıya alma (DURUM hatırlatması, 8 adım)
- [ ] (Claude) Kod geri sayımı + "Yeni kod al"; deneme kliniği premium vermez
- [ ] (Claude) Ekip üyesine fiyat gösterilmez
- [ ] (Siz + Hukuk) Uzman sözleşmesi + veri işleme eki onay akışı
- [ ] (Claude) Çerez bandı, `EXPO_PUBLIC_PRIVACY_URL`
- [ ] (Claude) Web oturum zaman aşımı, çıktıda "tanı değildir"

## 3. Admin paneli (Faz 1 canlıdan önce)
- [x] (ortak) Sunucu tarafı yazıldı ve testli: `proposed/20261023000000_admin.sql`, `sozlesme/admin.md` (destek/KVKK talep tabloları Faz 2)
- [x] Supabase'e uygulandı (23 Ekim)
- [x] İlk owner + iki adımlı doğrulama (23 Ekim)
- [x] Panel yayında: Cloudflare Workers (alan adı alınınca `admin.` alt alan adı bağlanır)
- [x] (ortak) `admin_*` fonksiyonları (rol + iki adımlı doğrulama + gerekçe + denetim kaydı)
- [ ] (Uygulamalar) `app_config` + kişiye istisna okuma (zorunlu güncelleme, bakım, bayraklar)
- [x] Panel yeri: **ayrı depo `amy60946/admin-panel`** (kullanıcı, 22 Ekim)
- [ ] (Karar) Panelin barındırılması (alan adı alınınca `admin.` alt alan adı)
- [ ] Faz 1 modülleri: arama, kullanıcı kartı, hesap işlemleri, istisnalar, kişiye bildirim, KVKK talepleri, uygulama ayarları
- [ ] (Siz) İlk süper admin + iki adımlı doğrulama

## 4. Analitik ve hata izleme
- [ ] (Siz) Sentry + PostHog (AB) hesapları (oyun için hesap yok)
- [ ] (ortak) ParentApp ve GameApp olay listeleri `sozlesme/akislar.md` §9
- [ ] (Claude) GameApp: Supabase'e olay servisi + Xcode Organizer/MetricKit
- [ ] (Claude) ParentApp + ClinicApp: Sentry + PostHog; replay ParentApp maskeli, ClinicApp kapalı
- [ ] (Claude) Admin Raporlar: kayıt, günlük aktif, G1/G7/G30, üç huni
