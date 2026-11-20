# Hukuk arşivi — 00. Olgular (metin yazarlarının tek kaynağı)

> 27 Ekim 2026. Bütün taslak metinler bu dosyadaki olgulara dayanır; olgu değişirse önce burası, sonra metinler. Köşeli parantezli alanlar (`[AD SOYAD]`, `[ADRES]`, `[MERSİS/VKN]`, `[KEP ADRESİ]`, `[SÜRE]`, `[TARİH]`) lansmandan önceki son işte doldurulur. Hukuki görüş değildir; avukat onayı bekler.
>
> 20 Kasım 2026: 14 Kasım kararları, çekirdek maddeler, Moyo adları, deneme 14 gün (sürüm v1 kaldı).

## 1. Taraflar ve ürünler

| | |
|---|---|
| Hizmetin adı | **Moyo** (kullanıcı kararları 9–17 Kasım 2026; `sozlesme/durumlar.md` 5B). Üç ürün aşağıda. Teknik anahtarlar (`kosullar-parentapp`, `sozlesme-uzman` …), rıza sürüm adları (`uzman-paylasim-v1`, `uzman-gecis-v1`), bundle ve alan adları değişmez. Eski adlar (ParentApp, ClinicApp, GameApp, Pofi Adası) yayımlanan metinde kullanılmaz; künyede ve iç notta kalabilir. |
| Veri sorumlusu / hizmet sağlayıcı | **Gerçek kişi** (kullanıcı kararı 10 Kasım 2026: şirket kurulmayacak, bireysel): `[AD SOYAD]`, `[ADRES]`, `[MERSİS/VKN]` ve `[KEP ADRESİ]` (son ikisi gerçek kişide uygulanmayabilir). Yer tutucular lansmandan önceki son işte, avukat görüşüyle doldurulur (`hukuk_notlari.md` soru 28, M 8–9). Metinlerde "şirket" denmez ("biz", "işletmeci"); tanım: "Moyo", [AD SOYAD] tarafından işletilen uygulamaları ifade eder. İletişim: `kvkk@moyoapp.com.tr`, `destek@moyoapp.com.tr`. Alan adı `moyoapp.com.tr` (Kasım 2026). |
| **Moyo Oyun** (eski Pofi Adası / GameApp) | Çocuk oyunu, iOS. Hedef yaş 6–12 (yaş grupları K ≤5, A 6–8, B 9–12, C 13+). Ücretsiz; **uygulama içi satın alma yok, reklam yok, üçüncü taraf analiz/izleme aracı yok**. Çocuğun e-postası/şifresi yok: ebeveynin oluşturduğu çocuk profiline, ebeveynin gösterdiği 15 dakikalık tek kullanımlık kod ya da QR ile cihazdan bağlanılır (cihazda anonim oturum). Kamera yalnız QR okumak için, görüntü saklanmaz. Mağaza kategorisi: normal oyun (Kids kategorisi değil). |
| **Moyo Ebeveyn** (eski ParentApp; telefonda görünen ad "Moyo") | Ebeveyn uygulaması, iOS. E-posta + şifre ile kayıt. Aile aboneliği (aylık/yıllık, App Store üzerinden; RevenueCat ile doğrulama). **Ücretsiz deneme 14 gün**; başka bir ailenin davet koduyla (Aile davet et) katılan aile **21 gün** (varsayılan + 7); uzman daveti süreyi değiştirmez (kullanıcı kararı 18 Kasım 2026, `migrations/20261118200000_parent_trial_14.sql`, uygulandı 19 Kasım 2026). Deneme kartsızdır: ödeme bilgisi istenmez, kendiliğinden ücretli aboneliğe dönmez; bitince ücretsiz planda sürer (1 çocuk, 3 etkin adım; ödül, taş düşürme, ebeveyn mesajı ve davranış kaydı kapalı; onay, oyun ve uzman paylaşımı açık). İkinci ebeveyn davet edilebilir. |
| **Moyo Mercek** (eski ClinicApp; aileye dönük metinlerde ve yüzeylerde **Moyo Uzman**, kullanıcı kararı 17 Kasım 2026) | Uzman (psikolog, klinik psikolog, PDR, ergoterapist, dil-konuşma terapisti, özel eğitim, çocuk gelişimi, BCBA, çocuk psikiyatristi, diğer) uygulaması; iPad + web. Klinik/uzman aboneliği (klinik sahibi birey olarak öder; App Store/RevenueCat; panelden elle üyelik). **Ücretsiz deneme 14 gün** (kart yok; kullanıcı kararı 10 Kasım 2026, `migrations/20261110130000_clinic_trial_14.sql`, uygulandı 10 Kasım 2026); App Store aboneliğine ayrıca ücretsiz deneme eklenmez; yönetim panelinden uzatılabilir. Ekip (klinik sahibi + üyeler). "Moyo Mercek" adı yalnız uzmana dönük metinlerde; herkese açık genel metinlerde ilk geçişte bir kez "Moyo Mercek (ailelere dönük ekranlarda Moyo Uzman)". |
| Yönetim paneli | Yalnız işletme ekibi (rol: sahip, finans, destek, izleyici). İki adımlı doğrulama zorunlu; her değişiklik gerekçeli ve silinemez denetim kaydında. Mesaj içeriği, fotoğraf, ses, uzman not metni panelde yok. Tanışma yanıtlarını kişi bazında **yalnız sahip (owner)** gerekçe yazarak görür (`admin_intake`, 14 Kasım 2026'dan beri); öteki roller yalnız kimliksiz toplamları görür (`admin_intake_summary`). |

**Konum (avukat dosyası çekirdek maddeleri, 13–14 Kasım 2026):** Moyo, aile üyelerinin günlük rutin ve sorumlulukları kendi tercihleriyle kaydetmesini ve bu kayıtları görmesini sağlayan dijital bir takip aracıdır. Kayıtlar kullanıcıların kendi girdiği takip kayıtlarıdır; Moyo bu kayıtları saklar ve gösterir, bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Platform **sağlık hizmeti sunmaz**, tanı koymaz, tedavi önermez, uzman istihdam etmez, uzman-aile arasında aracılık/yönlendirme yapmaz; uzmanın aileyle çalışması için bir araçtır. Hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir. Acil durum ve kriz hizmeti değildir (acil: 112). Moyo'nun içeriği (ebeveyn eğitimi kütüphanesi, hazır rutin ve plan şablonları) genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz (gözden geçiren uzmanın adı yazılmaz).

## 1a. Terimler (14 Kasım 2026 kararları, `hukuk_notlari.md` M)

| Konu | Kural |
|---|---|
| "Sağlık verisi" | Kendi metinlerimizde kayıtlara "sağlık verisidir" denmez. Terim: **"özel nitelikli veri içerebilecek kayıtlar"** (ya da "… içerebilecek alanlar"). Davranış kaydı, davranış olayı, ebeveyn eğitimi yanıtları, uzman notları ve serbest metin "özel nitelikli veri içerebilir" diye anlatılır, kesin nitelendirme yapılmaz. Bu kayıtlar için koruma ve uzmanla paylaşımda açık rıza yerinde kalır. |
| "Danışan" | Yasal metinlerde **"aile"**; uzmana dönük belgelerin tanımlar bölümünde bir kez: "Aile: uzmanın Moyo Mercek'te birlikte çalıştığı ebeveyn ve çocuk." Çocuğun kendisi kastediliyorsa "çocuk". Moyo Mercek uygulamasının kendi ekranlarında "danışan" kalır (uzmanın dili). |
| "İzlemek" | Gözlem anlamında **"takip etmek / takip"** (Moyo Mercek menü grubu "İzle" → "Takip"). Kalanlar: reklam/çerez takibi anlamındaki "izleme aracı kullanmıyoruz", "kriz izleme hizmeti değildir", panel rolü "izleyici". |
| "Klinik karar" | Kullanılmaz. |
| İş nesnesi | Aile ve uzman metinlerinde **rutin** (paket) ve **adım** (tek iş); oyun metinlerinde **macera**. Genel anlamda "sorumluluk" kalabilir. Veritabanı adları (`tasks` …) değişmez. |
| Uzman rozeti | "Belgesi incelendi" → **"Belge yükledi"**: aileye "Uzman diploma belgesini yükledi", uzmana "Belge yüklendi: <meslek>". Moyo bir doğrulama ya da yetki beyanı vermez; rozet yalnız belgenin yüklendiğini söyler. Özellik lansmanda kapalı (bayrak `clinician_verification`). |
| Dışa aktarılan belgeler | Uzmanın raporu, ilerleme notu ve CSV'lerin altında tek satır: "Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir." (Moyo Mercek'te uygulandı 14 Kasım 2026; eski "Sınırlar" bloğu kalktı.) |

## 2. İşlenen veriler (uygulama ve kişi bazında)

**Ebeveyn (Moyo Ebeveyn):** ad, takma ad, simge; e-posta; şifre (yalnız kimlik doğrulama sağlayıcısında, özetlenmiş); aile adı; çocuk profilleri (ad/takma ad, simge, isteğe bağlı cinsiyet ve doğum günü, yaş grubu); rutinler ve adımlar (veritabanında `tasks`), tekrarlar, hatırlatmalar; çocuğun "Yaptım"ları ve ebeveyn onay/ret (isteğe bağlı not/neden); ödüller, Güneş Taşı defteri (ebeveynin taş düşürme nedeni dahil); coin defteri; ebeveyn↔çocuk mesajları (yazı, fotoğraf, sesli mesaj, çıkartma; okundu bilgisi); **davranış kayıtları** (ABC: öncül–davranış–sonuç; uygulamadaki adı "Davranış kaydı", 28 Ekim 2026 — eski adlar "zor an" / "gözlem notu") ve isteğe bağlı ses kaydı (özel nitelikli veri içerebilir); **tanışma yanıtları** (hedefler, nereden duydu, sorumluluk/hatırlatma çatışma sıklığı, çocuğun düzeni, çocuğun çalıştığı uzmanlar, geçen hafta davranış sıklıkları — 14 Kasım 2026'dan beri iki günlük davranış maddesi dahil: "yerinde durmakta ya da sırasını beklemekte zorlandı", "plan değişince ya da bir işten ötekine geçerken zorlandı" —, ilgi alanları, motive edenler; yanıtlar hazır seçeneklerdir, serbest metin yok; uzman görmez). **Tanı ve ilaç soruları ile sağlık yanıtı rızası (`saglik-yanit-v1`) 14 Kasım 2026'da kalktı**: eski yanıtlar silindi, sunucu bu iki soruya yanıt yazmaz (`migrations/20261114200000_intake_observation_owner.sql`); `intake_answers.consent_version` sütunu duruyor, doldurulmuyor. Uzman paylaşımı onayları; takip planı uygulama kayıtları (bugün uyguladım, zorluk 1–5, uygulayamama nedeni; takip planı lansmanda bayrakla kapalı, `akislar.md` 12.2); uzmanın atadığı **ebeveyn eğitimi** kayıtları (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları ve düşünce, yapılacak işaretleri ve "Nasıl geçti?" yanıtı; `akislar.md` 23; özel nitelikli veri içerebilir); uzmanın tanımladığı hedef davranışa ebeveynin bildirdiği **davranış olayları** (zaman, sayı ya da süre, öncesi–sonrası, denenen strateji, çocuğun tepkisi 1–5 — ebeveynin gözlemi, puan değil; `akislar.md` 24; özel nitelikli veri içerebilir); ebeveyn dersleri ve uygulama günleri (`akislar.md` 22); abonelik durumu (ürün, dönem sonu, işlem kimliği; kart bilgisi bizde yok, Apple'da); bildirim jetonu; kullanım kayıtları.

**Çocuk (Moyo Oyun):** ebeveynin girdiği ad/simge/yaş grubu; cihazın anonim oturum kimliği; oyun kaydı (seviye, XP, evcil hayvan durumu, eşyalar, ada düzeni); coin harcamaları; macera listesi (ebeveynin rutin ve adımları) ve "Yaptım" işaretleri; ebeveyne mesaj (yazı ve hazır çıkartma); ödül istekleri; bildirim jetonu; kullanım kayıtları. Çocuktan doğrudan iletişim bilgisi, konum, fotoğraf, ses **alınmaz**; çocuk yalnız kendi ailesiyle mesajlaşır (yabancıyla iletişim yok).

**Uzman (Moyo Mercek):** ad, unvan, e-posta, klinik adı, ekip rolü; isteğe bağlı mesleki belge incelemesi (e-Devlet barkodlu mezuniyet belgesi — ad, T.C. kimlik no, okul, bölüm, derece, tarih içerir; BACB sicil no). Belge yalnız inceleme için okunur, karar verilince silinir; saklanan: özet (üniversite, bölüm, derece, yıl), barkod, karar kaydı; kimlik no saklanmaz. Rozet: aileye "Uzman diploma belgesini yükledi", uzmana "Belge yüklendi: <meslek>" (doğrulama beyanı değildir; özellik kapalı). Karşılama anketi yanıtları (meslek, zorluklar, yararlı özellikler, geliş nedeni; 28 Ekim 2026'dan beri atlanamaz, `README.md` sorun 16). Uzmanın aileyle ilgili girdileri: notlar (aile görmez), hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (gönderilince aile görür; lansmanda bayrakla kapalı), ebeveyn eğitimleri, hedef davranışlar ve stratejiler, seans randevuları ve seans kayıtları, etiketler. Davet bilgileri: ebeveynin adı ve e-postası, çocuğun adı/takma adı ve yaş grubu (aile onayına kadar; bağlanmamış davet 3 günde, bağlanmış onaylanmamış en geç 30 günde silinir). Abonelik; kullanım kayıtları.

**Herkes:** kullanım kayıtları (uygulama açma günleri, oturum sayısı, sürüm, platform, ekran/özellik olay adları — serbest metin ve içerik yok); bildirim kayıtları ve okunma; destek/ekip işlemlerinin denetim kaydı; giriş kodu deneme kayıtları (kötüye kullanım sınırı, IP dahil, 15 dakika); deneme geçmişi (yalnız Moyo Ebeveyn aileleri; yalnız e-posta özetinin SHA-256'sı, tekrar deneme suistimaline karşı).

**Destek formu (herkese açık /destek, 2 Kasım 2026):** yalnız yetişkinler ("18 yaşından büyüğüm" kutusu); e-posta (zorunlu), ad (isteğe bağlı), uygulama, konu, mesaj. Yalnız talebi yanıtlamak için; ekip panelde okur, yanıtı kendi e-postasından verir. Kapanan talep 2 yıl, istenmeyen 30 gün sonra silinir. Dosya eki, telefon, çocuk adı sorulmaz; mesaj kutusunda şifre/kart/sağlık bilgisi yazmama uyarısı.

**Bildirim metinleri:** bazı bildirimlerin başlık/metninde çocuğun adı geçebilir (ör. çocuğun bir adımı tamamladığını haber veren bildirim); bu metin bildirim sağlayıcısı (Apple, yedek yolda Expo) üzerinden telefona iletilir. Sağlık bilgisi ve davranış ayrıntısı bildirim metnine konmaz.

**Aile ya da çocuk silinince:** uzmanla paylaşım kaydı aileye bağlı olduğu için o çocuğa ait uzman notları, hedefleri ve takip planı da silinir (bugünkü sistem). Uzmanın mesleki kayıt saklama yükümlülüğüyle çatışabilir — avukat ve ürün kararı bekliyor. (Çekirdek madde 7: uzmanın kayıt tutma ve saklama yükümlülükleri uzmandadır, Moyo'ya geçmez.)

## 3. Akışlar ve onaylar (sistemde var)

| Akış | Dayanak (öneri) | Sistem karşılığı |
|---|---|---|
| Ebeveyn kaydı, aile, çocuk profili | Sözleşmenin ifası; veli beyanı | `profiles`, `families`, `children` |
| Çocuğu oyuna bağlama | Sözleşmenin ifası (ebeveyn başlatır) | 15 dk tek kullanımlık kod / QR |
| Uzmanla çocuk paylaşımı | **Açık rıza** `uzman-paylasim-v1` + "uzmanı tanıyorum, veliyim" kutusu | `clinic_links.consent_*`; ebeveyn istediği an geri alır |
| Uzmanın açtığı ebeveyn eğitimi ve hedef davranış (ebeveynin yanıtları, uygulama kayıtları, davranış olayları) | Uzmanla paylaşımın parçası (`uzman-paylasim-v1`); rıza metnindeki kapsamın yeterliliği avukata | `parent_training_*`, `clinic_target_behaviors`, `behavior_incidents`; paylaşım bitince aile ve uzman erişimi kapanır |
| Önceki uzman kayıtlarının yeni uzmana aktarımı | **Açık rıza** `uzman-gecis-v1` + uzman sözleşmesinde önceden izin | `clinic_link_history`; önceki uzmanın kimliği gizli |
| Tanışma soruları | Sözleşmenin ifası (md. 5/2-c; destek için 5/2-f; `aydinlatma-ebeveyn`). Tanı ve ilaç soruları ile ayrı açık rıza `saglik-yanit-v1` **14 Kasım 2026'da kalktı** | `intake_answers` (`consent_version` artık doldurulmuyor) |
| Uzman davet e-postası | Uzmanın beyanı (ebeveynin bilgisiyle) | davet başına en çok 3 e-posta (ilk + yeniden gönderimler), davet 3 gün geçerli |
| Uzman belge incelemesi | Uzmanın talebi (isteğe bağlı) | `clinician_verifications`; dosya karar sonrası silinir; rozet "Belge yükledi"; bayrak `clinician_verification` kapalı |
| Abonelik | Sözleşmenin ifası (Apple satıcıdır) | App Store + RevenueCat bildirimi |
| Hesap silme | Kullanıcı talebi | Uygulama içi `delete_account()`; aile/klinik verisi birlikte silinir; tek ebeveyn kalmışsa aile silinir |
| Yetkili ekip erişimi | Meşru menfaat / sözleşmenin ifası | iki adımlı, gerekçeli, silinemez denetim kaydı; tanışma yanıtları kişi bazında yalnız sahip (owner) rolüne gerekçeyle açılır, öteki roller yalnız kimliksiz toplamları görür |
| Kullanım ölçümü | Meşru menfaat | içerik yok, üçüncü taraf yok |
| Kullanım Koşulları kabulü / Aydınlatmanın gösterilmesi | Sözleşmenin kurulması; ispat (md. 5/2-e) | `migrations/20261027200000_legal.sql` (uygulandı 27 Ekim 2026): sürümlü kayıt `legal_acceptances` (kim, hangi metin, sürüm, uygulama, zaman); hesap silinse de rastgele hesap kimliğiyle kalır (e-posta/ad yok), saklama süresi sonunda imha |

## 4. Sanal değerler

- **Coin** (oyun içi): yalnız ebeveynin onayladığı adımlarla (oyunda "macera"; ve bir kez hoş geldin coini) kazanılır, yalnız oyun içi eşyalara harcanır. Satın alınamaz, paraya çevrilemez, devredilemez; hesap silinince kaybolur.
- **Güneş Taşı**: ebeveynin çocuğuna verdiği ödüllerin sayacı. Ebeveyn ödülleri ve "değiş tokuş" oranlarını (ör. "1 taş = 10 dk ekran") kendisi belirler; platform bu ödüllerin tarafı değildir, para ya da ödeme aracı değildir.

## 5. Hizmet sağlayıcılar (alt işleyenler)

| Sağlayıcı | Ne için | Veri | Konum |
|---|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | hepsi | Frankfurt, Almanya; AB bölgesi (Türkiye dışı) |
| Apple | App Store (satış ve abonelik — satıcı Apple'dır), bildirim (APNs) | abonelik işlemleri, bildirim jetonu, bildirim başlığı ve metni | ABD/AB |
| Expo (yedek bildirim yolu) | Cihaz Expo bildirim anahtarı verirse bildirim Expo Push API üzerinden Apple'a iletilir | bildirim jetonu, bildirim başlığı ve metni | ABD |
| RevenueCat | Abonelik durum doğrulaması | uygulama kullanıcı kimliği (rastgele kimlik), satın alma kayıtları | ABD |
| Resend | İşlem e-postaları (doğrulama, şifre sıfırlama, uzman daveti) | e-posta adresi, e-posta içeriği | ABD/AB |
| Cloudflare | Yönetim paneli barındırma | ekip oturumu (kullanıcı verisi panelde tarayıcıya gelir) | küresel |
| (test dönemi) Google Gmail SMTP | Test e-postaları | e-posta | ABD |

Reklam ağı, veri satışı, profil çıkarma, üçüncü taraf analiz SDK'sı **yok**. Yapay zekâ hizmetine veri gönderilmiyor (belge ön kontrolü kendi sunucumuzda).

## 6. Güvenlik

Tüm bağlantılar TLS; veritabanında satır düzeyi güvenlik (herkes yalnız kendi ailesini/kliniğini görür); çocuk cihazı yalnız kendi profilini görür; özel dosya kovaları (mesaj medyası, davranış kaydı sesi, uzman belgesi) imzalı kısa süreli bağlantıyla; yönetim paneli iki adımlı doğrulama + rol + gerekçe + silinemez kayıt; uzman belgesine yalnız sunucu işlevi kayıt yazarak 2 dk bağlantı verir.

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
| Yasal metin onay kayıtları | Hesap silinse de rastgele kimlikle `[SÜRE]` (öneri: sözleşme bitiminden 10 yıl — genel zamanaşımı) |
| KVKK başvuruları | Kapanıştan sonra `[SÜRE]` (öneri: 3 yıl); hesap silinince başvuru hesaptan ayrılır, yanıt e-postası kapanana dek kalır |

## 8. Bilinen açık konular

VERBİS gerekliliği (özel nitelikli veri içerebilecek kayıtların işlenmesi ana faaliyet sayılır mı); Supabase bölgesi ve yurt dışı aktarım (KVKK md. 9, 2024 değişikliği: standart sözleşme + 5 iş günü içinde Kurul'a bildirim); uzman notlarında veri sorumlusu (klinik mi platform mu); saklama süreleri; çocuğun yaşına göre kendi görüşü; Moyo Mercek'in uzaktan sağlık hizmeti mevzuatı karşısındaki durumu; işletmecinin gerçek kişi olmasının metinlere etkisi ve yayımlanacak ad/adres (`hukuk_notlari.md` soru 28; lansmandan önceki son iş).
