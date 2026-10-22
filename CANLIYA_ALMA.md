# Canlıya alma listesi (üç uygulama)

Ayrıntılı plan, gerekçeler ve öneriler: **Canlıya Alma Planı** belgesi https://claude.ai/artifact/7DAFNbjtvLMLTwKiG7DRv7
Bu dosya pencerelerin ortak takip listesidir; bir madde bitince `[x]` yapılır ve `DURUM.md`'ye satır yazılır.
Kim: **Siz** = kullanıcı (hesap, ödeme, imza, karar) · **Claude** = kod/SQL/metin · **Hukuk/MM** = avukat / mali müşavir.

## 1. Ortak altyapı (bitmeden hiçbir uygulama mağazaya çıkmaz)

### 1.1 Şirket ve hesaplar
- [ ] (Siz) Şirket/vergi kaydı, faturayı kesecek tüzel kişi
- [x] Apple Developer hesabı: **kişisel** (22 Ekim; ileride şirkete taşınabilir)
- [ ] (Siz) Mali müşavir + şahıs şirketi (vergi kaydı, e-Arşiv fatura için şart)
- [ ] (Siz) App Store Connect: Paid Apps sözleşmesi, banka, vergi
- [x] Google Play: **iOS'tan sonra** ayrı aşama (22 Ekim)
- [ ] (Siz) Supabase Pro plan (yedek, duraklatma yok)

### 1.2 Alan adı ve web
- [ ] (Siz) Alan adı
- [ ] (Claude) Tanıtım + Gizlilik + Kullanım Koşulları + Destek sayfaları (3 ürün)
- [ ] (Claude) ClinicApp sitesi yayını, auth yönlendirmeleri, `APP_URL`
- [ ] (Claude) Universal Links (`apple-app-site-association`)

### 1.3 E-posta
- [ ] (Siz) Gönderim servisi: **Resend ücretsiz** (karar 22 Ekim) — hesap açılacak, alan adı gerekli
- [ ] (Siz + Claude) SPF, DKIM, DMARC
- [ ] (Siz) Supabase SMTP + **Confirm email açık**
- [ ] (Claude) Türkçe şablonlar: onay, şifre sıfırlama, e-posta değişikliği, sihirli bağlantı, davet
- [ ] (Claude) Şifremi unuttum akışı (ParentApp, ClinicApp; `parentapp://`, `clinicapp://`)
- [ ] (Claude) İşlem e-postaları: hoş geldin, deneme bitiyor, ödeme + fatura, hesap silindi
- [ ] (Claude) Gmail / Outlook / iCloud uçtan uca deneme

### 1.4 Destek
- [ ] (Siz) `destek@`, `kvkk@`, `fatura@` posta kutuları
- [ ] (Claude) Uygulama içi "Yardım ve iletişim" (oyunda ebeveyn kapısı arkasında)
- [ ] (Claude) SSS
- [ ] (Siz) Yanıt süresi; KVKK başvurusu yasal süre 30 gün

### 1.5 Hukuk metinleri (taslak Claude, onay Hukuk)
- [ ] KVKK Aydınlatma Metni (ebeveyn / çocuk / uzman; `trial_history`)
- [ ] Açık Rıza Metni (çocuk verisi, uzman paylaşımı, yurt dışı aktarım, pazarlama ayrı)
- [ ] Gizlilik Politikası (herkese açık URL)
- [ ] Kullanım Koşulları / EULA (abonelik bağlantısı uygulamada + mağazada)
- [ ] Mesafeli Satış Sözleşmesi + Ön Bilgilendirme Formu (web/iyzico satışları)
- [ ] Uzman Hizmet Sözleşmesi + Veri İşleme Eki
- [ ] Çerez politikası + bant (ClinicApp web)
- [ ] "Tanı değildir" uyarı metni
- [ ] (Claude) Uygulamalara yerleştirme + sürümlü onay kaydı

### 1.6 KVKK işlemleri
- [ ] (Hukuk) VERBİS gerekliliği
- [ ] (Hukuk) Yurt dışı aktarım: standart sözleşme + Kurul'a bildirim
- [ ] (Claude) Kişisel veri envanteri
- [ ] (Claude) Saklama ve imha işi (zamanlanmış)
- [ ] (Claude) Verimi indir (aile verisi dışa aktarma)
- [ ] (Claude) Ebeveyn onayının sürümlü kaydı (çocuk bağlanmadan önce)
- [ ] (Siz + Hukuk) Veri ihlali prosedürü (72 saat)

### 1.7 Hesap silme
- [x] Sunucu: `delete_account()` (ebeveyn, uzman)
- [ ] (Claude) Üç uygulamada görünür "Hesabımı sil" + web talep sayfası
- [ ] (Claude) Oyun: bağlantı kopunca/aile silinince yerel kayıt temizliği
- [ ] (Claude) Aktif abonelikte "Apple'dan iptal edin" uyarısı

### 1.8 Ödeme
- [ ] (Siz) ASC ürünleri (ParentApp 2, ClinicApp 4) + TR fiyatları
- [ ] (Siz) IAP .p8 anahtarı (Secrets) + App Store Server Notifications V2 adresi
- [ ] (Karar) ParentApp ödeme yolu: öneri `clinic-billing` (kendi sistemimiz); kullanıcı onayı bekleniyor
- [ ] (Siz) iyzico üye işyeri
- [ ] (Claude) Sandbox: satın al, geri yükle, iptal, iade, grace period
- [ ] (Claude) `proposed/20261022200000_clinic_billing.sql` uygulama; en son `billing.enforce = true`
- [ ] (Siz) Gerçek fiyatlar
- [ ] Klinik denemeleri ~2 Kasım'da bitiyor (gerekirse uzat)

### 1.9 Fatura
- [ ] (MM) App Store gelirinin faturalanması (Apple'a)
- [ ] (Siz) e-Arşiv/e-Fatura özel entegratörü (API'li)
- [ ] (Claude) Ödeme → fatura → PDF e-posta → `billing_events`; iadede iptal/iade faturası
- [ ] (Claude) Bireysel / kurumsal fatura bilgisi alanları

### 1.10 Güvenlik ve işletme
- [x] RLS + sızma testleri, anon kapalı, hız sınırları
- [ ] (Siz + Claude) Staging Supabase projesi
- [ ] (Siz) Günlük yedek + PITR + bir geri yükleme denemesi
- [ ] (Claude) İzleme ve alarm (sunucu, Edge Function, webhook)
- [ ] (Siz) `PUSH_SECRET`
- [ ] (Claude) Push anahtarı taşıma riski kapatılsın
- [ ] (Siz) Geliştirme anahtarlarının yenilenmesi

## 2. Uygulamalar

### 2.1 Hepsi
- [ ] (Siz) iOS imza / sertifika sınırı (ParentApp + GameApp)
- [ ] (Claude) `PrivacyInfo.xcprivacy`
- [ ] (Siz + Claude) App Privacy etiketi
- [ ] (Siz) Yaş derecelendirme anketi
- [ ] (Claude) Ekran görüntüleri, açıklama, anahtar kelimeler
- [ ] (Claude) App Review deneme hesabı + kalıcı inceleme çocuk kodu + not
- [ ] (Claude) Bildirim izni ilk gereken anda
- [ ] (Claude) Yeni simge biçimi (Icon Composer)
- [ ] (Siz) TestFlight dış deneme (5–10 aile, en az 1 uzman)

### 2.2 GameApp
- [x] Kids Kategorisi: **hayır, normal oyun** (22 Ekim). Yine de Apple 5.1.4: üçüncü taraf analitik yok, dış bağlantılar ebeveyn kapısı arkasında; mağaza metninde "çocuklar için" yok
- [ ] (Claude) **Kodsuz başlangıç** (WWDC 2014/602 + Apple 5.1.1(v)): önce pet + ada + ipuçları; "Ebeveynini bağla" sonra, ebeveyn kapısı arkasında; yerel ilerleme bağlanınca hesaba taşınır
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
- [ ] (Claude) Kayıt onayı + şifremi unuttum ekranları
- [ ] (Claude) Abonelik ekranı 3.1.2 uyumu (fiyat, süre, yenileme, bağlantılar, geri yükle); ilk değerden sonra göster
- [ ] (Claude) "Aboneliği yönet"
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
- [ ] (ortak) `admin_users`, `admin_audit`, `user_overrides`, `app_config` genişletme, `support_requests`, `privacy_requests` + RLS + test
- [ ] (ortak) `admin_*` fonksiyonları (rol denetimi + denetim kaydı + gerekçe)
- [ ] (Uygulamalar) `app_config` + kişiye istisna okuma (zorunlu güncelleme, bakım, bayraklar)
- [ ] (Karar) Panel teknolojisi (Expo web / ayrı site)
- [ ] Faz 1 modülleri: arama, kullanıcı kartı, hesap işlemleri, istisnalar, kişiye bildirim, KVKK talepleri, uygulama ayarları
- [ ] (Siz) İlk süper admin + iki adımlı doğrulama

## 4. Analitik ve hata izleme
- [ ] (Siz) Sentry + PostHog (AB) hesapları (oyun için hesap yok)
- [ ] (ortak) ParentApp ve GameApp olay listeleri `sozlesme/akislar.md` §9
- [ ] (Claude) GameApp: Supabase'e olay servisi + Xcode Organizer/MetricKit
- [ ] (Claude) ParentApp + ClinicApp: Sentry + PostHog; replay ParentApp maskeli, ClinicApp kapalı
- [ ] (Claude) Admin Raporlar: kayıt, günlük aktif, G1/G7/G30, üç huni
