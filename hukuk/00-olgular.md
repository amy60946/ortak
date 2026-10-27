# Hukuk arşivi — 00. Olgular (metin yazarlarının tek kaynağı)

> 27 Ekim 2026. Bütün taslak metinler bu dosyadaki olgulara dayanır; olgu değişirse önce burası, sonra metinler. Köşeli parantezli alanlar (`[ŞİRKET UNVANI]`) canlıdan önce doldurulur. Hukuki görüş değildir; avukat onayı bekler.

## 1. Taraflar ve ürünler

| | |
|---|---|
| Veri sorumlusu | `[ŞİRKET UNVANI]` (şahıs şirketi kurulacak), `[ADRES]`, `[MERSİS/VKN]`. İletişim: `kvkk@[ALAN ADI]`, `destek@[ALAN ADI]`. Alan adı henüz alınmadı. |
| **Pofi Adası (GameApp)** | Çocuk oyunu, iOS. Hedef yaş 6–12 (yaş grupları K ≤5, A 6–8, B 9–12, C 13+). Ücretsiz; **uygulama içi satın alma yok, reklam yok, üçüncü taraf analiz/izleme aracı yok**. Çocuğun e-postası/şifresi yok: ebeveynin oluşturduğu çocuk profiline, ebeveynin gösterdiği 15 dakikalık tek kullanımlık kod ya da QR ile cihazdan bağlanılır (cihazda anonim oturum). Kamera yalnız QR okumak için, görüntü saklanmaz. Mağaza kategorisi: normal oyun (Kids kategorisi değil). |
| **ParentApp** | Ebeveyn uygulaması, iOS. E-posta + şifre ile kayıt. Aile aboneliği (aylık/yıllık, App Store üzerinden; RevenueCat ile doğrulama), 7 gün deneme, ücretsiz planda sınırlı özellik. İkinci ebeveyn davet edilebilir. |
| **ClinicApp** | Uzman (psikolog, klinik psikolog, PDR, ergoterapist, dil-konuşma terapisti, özel eğitim, çocuk gelişimi, BCBA, çocuk psikiyatristi, diğer) uygulaması; iPad + web. Klinik/uzman aboneliği (klinik sahibi birey olarak öder; App Store/RevenueCat; panelden elle üyelik), 14 gün deneme. Ekip (klinik sahibi + üyeler). |
| Yönetim paneli | Yalnız işletme ekibi (rol: sahip, finans, destek, izleyici). İki adımlı doğrulama zorunlu; her değişiklik gerekçeli ve silinemez denetim kaydında. Mesaj içeriği, fotoğraf, ses, uzman not metni panelde yok. |

Platform **sağlık hizmeti sunmaz**, tanı koymaz, uzman istihdam etmez, uzman-aile arasında aracılık/yönlendirme yapmaz; uzmanın aileyle çalışması için bir araçtır. Hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir. Acil durum hizmeti değildir (acil: 112).

## 2. İşlenen veriler (uygulama ve kişi bazında)

**Ebeveyn (ParentApp):** ad, takma ad, simge; e-posta; şifre (yalnız kimlik doğrulama sağlayıcısında, özetlenmiş); aile adı; çocuk profilleri (ad/takma ad, simge, isteğe bağlı cinsiyet ve doğum günü, yaş grubu); görevler, tekrarlar, hatırlatmalar; çocuğun "Yaptım"ları ve ebeveyn onay/ret (isteğe bağlı not/neden); ödüller, Güneş Taşı defteri (ebeveynin taş düşürme nedeni dahil); coin defteri; ebeveyn↔çocuk mesajları (yazı, fotoğraf, sesli mesaj, çıkartma; okundu bilgisi); "zor an" (ABC: öncül–davranış–sonuç) kayıtları ve isteğe bağlı ses kaydı; **tanışma yanıtları** (hedefler, nereden duydu, görev/hatırlatma çatışma sıklığı, çocuğun düzeni, geçen hafta davranış sıklıkları, hedefler, ilgi alanları, motive edenler; **isteğe bağlı sağlık soruları: tanı ve düzenli ilaç** — "söylemek istemiyorum" seçeneğiyle, ayrı açık rıza `saglik-yanit-v1`); uzman paylaşımı onayları; takip planı uygulama kayıtları (bugün uyguladım, zorluk 1–5, uygulayamama nedeni); abonelik durumu (ürün, dönem sonu, işlem kimliği; kart bilgisi bizde yok, Apple'da); bildirim jetonu; kullanım kayıtları.

**Çocuk (GameApp):** ebeveynin girdiği ad/simge/yaş grubu; cihazın anonim oturum kimliği; oyun kaydı (seviye, XP, evcil hayvan durumu, eşyalar, ada düzeni); coin harcamaları; görev listesi ve "Yaptım" işaretleri; ebeveyne mesaj (yazı ve hazır çıkartma); ödül istekleri; bildirim jetonu; kullanım kayıtları. Çocuktan doğrudan iletişim bilgisi, konum, fotoğraf, ses **alınmaz**; çocuk yalnız kendi ailesiyle mesajlaşır (yabancıyla iletişim yok).

**Uzman (ClinicApp):** ad, unvan, e-posta, klinik adı, ekip rolü; isteğe bağlı mesleki belge incelemesi (e-Devlet barkodlu mezuniyet belgesi — ad, T.C. kimlik no, okul, bölüm, derece, tarih içerir; BACB sicil no). Belge yalnız inceleme için okunur, karar verilince silinir; saklanan: özet (üniversite, bölüm, derece, yıl), barkod, karar kaydı; kimlik no saklanmaz. Karşılama anketi yanıtları (meslek, zorluklar, yararlı özellikler, geliş nedeni). Uzmanın danışanla ilgili girdileri: notlar (aile görmez), hedefler ve haftalık değerlendirmeler, görev önerileri, takip planı (gönderilince aile görür), etiketler. Davet bilgileri: ebeveynin adı ve e-postası, çocuğun adı/takma adı ve yaş grubu (aile onayına kadar; bağlanmamış davet 3 günde, bağlanmış onaylanmamış en geç 30 günde silinir). Abonelik; kullanım kayıtları.

**Herkes:** kullanım kayıtları (uygulama açma günleri, oturum sayısı, sürüm, platform, ekran/özellik olay adları — serbest metin ve içerik yok); bildirim kayıtları ve okunma; destek/ekip işlemlerinin denetim kaydı; giriş kodu deneme kayıtları (kötüye kullanım sınırı, IP dahil, 15 dakika); deneme geçmişi (yalnız e-posta özetinin SHA-256'sı, tekrar deneme suistimaline karşı).

## 3. Akışlar ve onaylar (sistemde var)

| Akış | Dayanak (öneri) | Sistem karşılığı |
|---|---|---|
| Ebeveyn kaydı, aile, çocuk profili | Sözleşmenin ifası; veli beyanı | `profiles`, `families`, `children` |
| Çocuğu oyuna bağlama | Sözleşmenin ifası (ebeveyn başlatır) | 15 dk tek kullanımlık kod / QR |
| Uzmanla çocuk paylaşımı | **Açık rıza** `uzman-paylasim-v1` + "uzmanı tanıyorum, veliyim" kutusu | `clinic_links.consent_*`; ebeveyn istediği an geri alır |
| Önceki uzman kayıtlarının yeni uzmana aktarımı | **Açık rıza** `uzman-gecis-v1` + uzman sözleşmesinde önceden izin | `clinic_link_history`; önceki uzmanın kimliği gizli |
| Tanışma sağlık soruları | **Açık rıza** `saglik-yanit-v1` (isteğe bağlı) | `intake_answers.consent_version` |
| Uzman davet e-postası | Uzmanın beyanı (ebeveynin bilgisiyle) | tek e-posta + en çok 3 yeniden gönderim, 3 gün |
| Uzman belge incelemesi | Uzmanın talebi (isteğe bağlı) | `clinician_verifications`; dosya karar sonrası silinir |
| Abonelik | Sözleşmenin ifası (Apple satıcıdır) | App Store + RevenueCat bildirimi |
| Hesap silme | Kullanıcı talebi | Uygulama içi `delete_account()`; aile/klinik verisi birlikte silinir; tek ebeveyn kalmışsa aile silinir |
| Yetkili ekip erişimi | Meşru menfaat / sözleşmenin ifası | iki adımlı, gerekçeli, silinemez denetim kaydı; tanışma yanıtları gerekçeyle açılır, sağlık yanıtları varsayılan gizli |
| Kullanım ölçümü | Meşru menfaat | içerik yok, üçüncü taraf yok |
| Kullanım Koşulları / Aydınlatma onayı | — | **Eklenecek:** sürümlü onay kaydı (`legal_acceptances`) |

## 4. Sanal değerler

- **Coin** (oyun içi): yalnız ebeveynin onayladığı görevlerle (ve bir kez hoş geldin coini) kazanılır, yalnız oyun içi eşyalara harcanır. Satın alınamaz, paraya çevrilemez, devredilemez; hesap silinince kaybolur.
- **Güneş Taşı**: ebeveynin çocuğuna verdiği ödüllerin sayacı. Ebeveyn ödülleri ve "değiş tokuş" oranlarını (ör. "1 taş = 10 dk ekran") kendisi belirler; platform bu ödüllerin tarafı değildir, para ya da ödeme aracı değildir.

## 5. Hizmet sağlayıcılar (alt işleyenler)

| Sağlayıcı | Ne için | Veri | Konum |
|---|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | hepsi | `[SUPABASE BÖLGESİ]` (yurt dışı olabilir) |
| Apple | App Store (satış ve abonelik — satıcı Apple'dır), bildirim (APNs) | abonelik işlemleri, bildirim jetonu | ABD/AB |
| RevenueCat | Abonelik durum doğrulaması | uygulama kullanıcı kimliği (rastgele kimlik), satın alma kayıtları | ABD |
| Resend | İşlem e-postaları (doğrulama, şifre sıfırlama, uzman daveti) | e-posta adresi, e-posta içeriği | ABD/AB |
| Cloudflare | Yönetim paneli barındırma | ekip oturumu (kullanıcı verisi panelde tarayıcıya gelir) | küresel |
| (test dönemi) Google Gmail SMTP | Test e-postaları | e-posta | ABD |

Reklam ağı, veri satışı, profil çıkarma, üçüncü taraf analiz SDK'sı **yok**. Yapay zekâ hizmetine veri gönderilmiyor (belge ön kontrolü kendi sunucumuzda).

## 6. Güvenlik

Tüm bağlantılar TLS; veritabanında satır düzeyi güvenlik (herkes yalnız kendi ailesini/kliniğini görür); çocuk cihazı yalnız kendi profilini görür; özel dosya kovaları (mesaj medyası, zor an sesi, uzman belgesi) imzalı kısa süreli bağlantıyla; yönetim paneli iki adımlı doğrulama + rol + gerekçe + silinemez kayıt; uzman belgesine yalnız sunucu işlevi kayıt yazarak 2 dk bağlantı verir.

## 7. Saklama (bugünkü sistem; avukat süreleri onaylayacak)

| Veri | Süre |
|---|---|
| Hesap ve aile/klinik verisi | Hesap silinene kadar; silmede derhal |
| Uzman notları | Klinik silinene / uzman hesabı (tek kişilik klinik) silinene kadar; paylaşım geri alınınca uzman erişimi biter |
| Davet bilgisi (çocuk adı, ebeveyn e-postası) | 3 gün (bağlanmamış) / 30 gün (bağlanmış onaysız) |
| Uzman belgesi dosyası | Karar anında silinir |
| Kod deneme kayıtları | 15 dakika–1 gün |
| Deneme geçmişi (e-posta özeti) | `[SÜRE]` (öneri: 2 yıl) |
| Denetim kaydı | `[SÜRE]` (öneri: 5 yıl); silinen kullanıcının e-postası yazılmaz |
| Abonelik/ödeme olayları | `[SÜRE]` (vergi/ticaret mevzuatı; öneri 10 yıl) |
| Kullanım kayıtları | `[SÜRE]` (öneri: 25 ay, sonra yalnız toplam) |

## 8. Bilinen açık konular

VERBİS gerekliliği (sağlık verisi işleme ana faaliyet sayılır mı); Supabase bölgesi ve yurt dışı aktarım (KVKK md. 9, 2024 değişikliği: standart sözleşme + 5 iş günü içinde Kurul'a bildirim); uzman notlarında veri sorumlusu (klinik mi platform mu); saklama süreleri; çocuğun yaşına göre kendi görüşü; ClinicApp'in uzaktan sağlık hizmeti mevzuatı karşısındaki durumu.
