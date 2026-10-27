# Uygulama İçi Hukuki Metinler (yazılımcılar için)
| Anahtar | iç belge | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Pofi Adası (GameApp), ParentApp ve ClinicApp pencereleri; ekran ekran gösterilecek kısa metinler ve bağlı belge anahtarları | Dayanak | KVKK md. 3, 5, 6, 10, 11; 6502 s. TKHK md. 5; Kurul'un Çerez Uygulamaları Hakkında Rehberi; Apple App Review 3.1.2, 5.1.1 |

## Kısaca

- Bu belge, üç uygulamada gösterilecek hukuki kısa metinlerin **tek kaynağıdır**. Her metin için uygulama, ekran, metin ve bağlı belge anahtarı yazılıdır.
- Uzun metinler (koşullar, aydınlatma, gizlilik) uygulamaya gömülmez; `legal` sunucu işlevinden ya da `legal_documents_for(app)` ile açılır. Burada yalnız ekranın kendi kısa metinleri vardır.
- Onay kutuları **önceden işaretli gelmez**. Kullanım Koşulları onayı, aydınlatmayı okuma ve açık rızalar **ayrı satırlardır**; birbirine bağlanmaz.
- Açık rıza metinleri (`saglik-yanit-v1`, `uzman-paylasim-v1`, `uzman-gecis-v1`) kendi akışlarında kalır; bu belge onları tekrar etmez.

## 0. Genel kurallar

| Kural | Ayrıntı |
|---|---|
| Hitap | ParentApp ve ClinicApp: "sen" (uygulamaların mevcut dili). Pofi Adası: çocuğa kısa ve sade; ebeveyn kapısının arkası ebeveyne "sen" |
| Değişkenler | `{süslü parantez}` = uygulamanın doldurduğu değer (ör. `{fiyat}`). `[KÖŞELİ]` = canlıdan önce bir kez doldurulacak yer tutucu |
| Bağlantılar | Altı çizili metin = ilgili belgeyi açan bağlantı (anahtar tabloda) |
| Onay kaydı | Onay isteyen metinler `legal_accept(app, [{key, version}])` ile kaydedilir; bekleyenler `legal_pending(app)` (`proposed/20261027200000_legal.sql`) |
| Kayıt sırasında | Kayıt anında oturum henüz açık değil (e-posta doğrulaması). İşaretlenen sürümler kayıt bilgisine eklenir; ilk girişte `legal_accept` ile yazılır ya da ilk girişte `legal_pending` ekranı gösterilir |
| Pofi Adası sesli okuma | Çocuğa gösterilen her yeni metin için ses üretilir (game-app `CLAUDE.md`, `build_voice.py --missing`) |
| Değişiklik | Bu belgedeki bir metin değişirse bağlı belgeyle tutarlılığı kontrol edilir; açık rıza metni değişirse rıza sürümü de değişir (`-v2`) |
| Diğer taslaklar | ClinicApp kısa metinleri `22-uzman-hizmet-sozlesmesi.md` Ek-3'te, çerez bandı `40-cerez-politikasi.md`'de, çocuğa kısa not `11-aydinlatma-cocuk-ve-veli.md` Kısım B'de de yazılı; bu belgedekilerle aynı tutulur |

**Belge anahtarları:**

| Anahtar | Belge | Uygulama | Onay ister |
|---|---|---|---|
| `kosullar-parentapp` | ParentApp Kullanım Koşulları (abonelik dahil) | parent | Evet |
| `kosullar-gameapp` | Pofi Adası Koşulları (veli çocuk adına onaylar) | child (onay ParentApp'te) | Evet |
| `sozlesme-uzman` | ClinicApp Uzman Hizmet Sözleşmesi | clinic | Evet |
| `veri-isleme-eki` | Veri İşleme Eki (sözleşmenin Ek-1'i) | clinic | Evet |
| `aydinlatma-ebeveyn` | Ebeveyn Aydınlatma Metni | parent | Gösterildi kaydı (kutu yok) |
| `aydinlatma-uzman` | Uzman Aydınlatma Metni | clinic | Gösterildi kaydı (kutu yok) |
| `aydinlatma-cocuk` | Pofi Adası Çocuk ve Veli Aydınlatma Metni | child (ParentApp'te gösterilir) | Gösterildi kaydı (kutu yok) |
| `gizlilik` | Gizlilik Politikası | hepsi + web | Hayır |
| `alt-isleyenler` | Hizmet Sağlayıcılar Listesi | hepsi + web | Hayır |
| `kvkk-basvuru` | KVKK Başvuru Usulü | hepsi + web | Hayır |
| `cerez-clinicapp-web` | ClinicApp Web Çerez Politikası | clinic, web | Hayır |
| `acik-riza-metinleri` | ParentApp açık rıza metinleri (her rıza kendi sürümüyle: `saglik-yanit-v1`, `uzman-paylasim-v1`, `uzman-gecis-v1`) | parent, web | Ayrı rıza kutuları |

## 1. Kayıt ekranı onay satırları

### 1.1 ParentApp — kayıt

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ParentApp | Kayıt ol (e-posta + şifre), "Hesap oluştur" düğmesinin üstü | `kosullar-parentapp`, `aydinlatma-ebeveyn`, `gizlilik` |

> ☐ <u>Kullanım Koşulları</u>'nı okudum, kabul ediyorum.
>
> Kişisel verilerinin nasıl işlendiğini <u>Aydınlatma Metni</u>'nde anlatıyoruz. *(kutu yok; düz satır)*
>
> <small><u>Gizlilik Politikası</u></small>

- Koşullar kutusu işaretlenmeden "Hesap oluştur" pasif kalır. Aydınlatma bir onay değil, bilgilendirmedir: kutu konmaz; hesap oluşunca koşulların onayıyla birlikte aydınlatmanın **gösterildiği** de `legal_accept` ile kaydedilir (karar 27 Ekim 2026, avukat teyidi bekler).
- Bu ekranda **açık rıza kutusu yoktur**. Sağlık soruları ve uzman paylaşımı kendi ekranlarında, isteğe bağlı sorulur. Pazarlama izni bugün istenmez.

### 1.2 ClinicApp — kayıt

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp (iPad + web) | Kayıt ol, "Hesap oluştur" düğmesinin üstü; ekip koduyla katılım ekranı | `sozlesme-uzman`, `veri-isleme-eki`, `aydinlatma-uzman`, `gizlilik` |

> ☐ <u>Uzman Hizmet Sözleşmesi</u>'ni ve <u>Veri İşleme Eki</u>'ni okudum, kabul ediyorum.
>
> Kişisel verilerinin nasıl işlendiğini <u>Uzman Aydınlatma Metni</u>'nde anlatıyoruz. *(kutu yok; düz satır — sözleşme Ek-3 ile aynı)*
>
> <small><u>Gizlilik Politikası</u></small>

### 1.3 ParentApp — Pofi Adası'nı bağlamadan önce (veli onayı)

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ParentApp | Çocuk › "Giriş kodu üret" / QR — yalnız ilk kez ve metin güncellenince | `kosullar-gameapp`, `aydinlatma-cocuk` |

> **Pofi Adası'nı {çocuk_adı}'nın cihazına bağlamadan önce**
>
> Pofi Adası'nda reklam, satın alma ve izleme aracı yok. Çocuğun yalnız ailesiyle yazışır; oyun ondan e-posta, konum, fotoğraf ya da ses almaz.
>
> ☐ {çocuk_adı}'nın velisi olarak <u>Pofi Adası Koşulları</u>'nı okudum, çocuğum adına kabul ediyorum.
>
> Çocuğunun verilerinin nasıl işlendiğini <u>Pofi Adası Çocuk ve Veli Aydınlatma Metni</u>'nde anlatıyoruz. *(kutu yok)*

- Kayıt: `legal_accept('child', …)` (çocuk cihazı onay veremez; sunucu reddeder).

### 1.4 ParentApp — çocuk ekleme

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ParentApp | Çocuk ekle / davetten çocuk onayı, "Kaydet" düğmesinin altı | `kosullar-parentapp` (veli beyanı maddesi) |

> Çocuğu ekleyerek velisi ya da yasal temsilcisi olduğunu beyan edersin. Doğum günü ve cinsiyet isteğe bağlıdır.

## 2. Yeniden onay ekranı

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Üçü (Pofi Adası metinleri ParentApp'te) | Açılışta `legal_pending(app)` boş değilse tam ekran | Güncellenen belge(ler) |

> **Koşullarımız güncellendi**
>
> {belge_adı} metnini güncelledik. Kısaca ne değişti:
> {özet — `legal_documents.summary`, madde madde}
>
> <u>Tam metni oku</u>
>
> ☐ Güncellenen {belge_adı}'nı okudum, kabul ediyorum. *(aydınlatma metninde kutu yok: "Aydınlatma metnimizi güncelledik" + [Tamam]; dokunulunca gösterildi kaydı)*
>
> [ Devam et ]
>
> <small>Kabul etmek istemiyorsan <u>hesabını silebilir</u> ya da `destek@[ALAN ADI]` adresine yazabilirsin.</small>

- Birden çok metin güncellendiyse hepsi aynı ekranda alt alta; her biri ayrı kutu.
- Kutu işaretlenmeden "Devam et" pasif. Bu ekrandayken bile Ayarlar › Hesabımı sil, Yasal metinler ve KVKK başvurusu açılabilir olmalı.
- **Pofi Adası koşulları güncellenince:** ParentApp'te ebeveyne "Pofi Adası koşulları güncellendi — {çocuk_adı} adına onayla". Çocuğun oyunu bu arada kilitlenmez (karar: Avukata notlar 3).
- **Onay istemeyen metin güncellenince** (Gizlilik Politikası, Hizmet Sağlayıcılar): kapatılabilir üst bant:
  > Gizlilik Politikamızı güncelledik. <u>Neler değişti?</u>

## 3. Ayarlar › Yasal metinler

| Uygulama | Ekran | Kaynak |
|---|---|---|
| Üçü | Ayarlar › Yasal metinler (Pofi Adası'nda ebeveyn kapısının arkasında) | `legal_documents_for(app)` |

Her satır: **başlık** · sürüm · (onay isteyenlerde) "Onayladın: {tarih}".

| ParentApp | ClinicApp | Pofi Adası (ebeveyn kapısı arkası) |
|---|---|---|
| Kullanım Koşulları | Uzman Hizmet Sözleşmesi | Pofi Adası Koşulları |
| Aydınlatma Metni | Veri İşleme Eki | Çocuk ve Veli Aydınlatma Metni |
| Gizlilik Politikası | Aydınlatma Metni | Gizlilik Politikası |
| Pofi Adası Koşulları | Gizlilik Politikası | KVKK Başvuru Usulü |
| Pofi Adası Çocuk ve Veli Aydınlatma Metni | Hizmet Sağlayıcılar | |
| Hizmet Sağlayıcılar | KVKK Başvuru Usulü | |
| KVKK Başvuru Usulü | Çerez Politikası (yalnız web) | |
| **Verdiğin izinler** → sağlık yanıtları, uzman paylaşımı, önceki uzman kayıtları: durum + "Geri al" | | |

"Verdiğin izinler" alt başlığı:
> Bu izinler isteğe bağlıdır. Geri aldığında uygulamayı kullanmaya devam edersin; ilgili paylaşım hemen durur.

## 4. Ayarlar › KVKK başvurusu

| Uygulama | Ekran | Bağlı belge | Sunucu |
|---|---|---|---|
| ParentApp, ClinicApp | Ayarlar › KVKK başvurusu | `kvkk-basvuru` | `kvkk_request_create(app, kind, detail)`, `my_kvkk_requests()` |

**Üst metin:**
> Kişisel verilerinle ilgili taleplerini buradan iletebilirsin. En geç 30 gün içinde, ücretsiz yanıt veririz. Yanıt {e-posta} adresine gelir. <u>Başvuru usulü</u>

**Alanlar:**

1. **Kimin için?** *(yalnız ParentApp)* — "Kendim" / "{çocuk_adı}" (her çocuk için bir seçenek). Çocuk seçilirse `app = 'child'` ve açıklamanın başına "Çocuk: {çocuk_adı}" eklenir.
2. **Ne istiyorsun?** (tek seçim)

| Seçenek metni | `kind` | Seçenek altı ipucu |
|---|---|---|
| Hakkımda hangi verileri, neden işlediğinizi öğrenmek | `info` | — |
| Verilerimin bir kopyasını almak | `access` | — |
| Yanlış ya da eksik bir bilginin düzeltilmesi | `correct` | Profil ve çocuk bilgilerini kendin de düzenleyebilirsin. |
| Verilerimin silinmesi | `delete` | Hesabının tamamını silmek için Ayarlar › Hesabımı sil daha hızlıdır. |
| Verilerimin kimlere aktarıldığını öğrenmek | `third_parties` | — |
| Bir işlemeye itiraz etmek | `object` | — |
| Uğradığım bir zararın giderilmesi | `damages` | — |
| Başka bir talep | `other` | Uzmanının notlarıyla ilgili talepler uzmanın kliniğine iletilebilir. *(ParentApp)* |

3. **Açıklama** — çok satırlı, en çok 2000 karakter; düzeltme, itiraz, zarar ve diğer taleplerde zorunlu.
   Yer tutucu: *"Talebini kısaca yaz. Gerekmedikçe sağlık bilgisi ya da başka birinin kişisel bilgisini yazma."*
4. **Bilgi satırı:**
   > Başvurun hesabına bağlıdır; kimliğini ayrıca kanıtlaman gerekmez. Bazı taleplerde e-posta adresine bir doğrulama bağlantısı gönderebiliriz.

**Düğme:** Başvuruyu gönder

**Onay mesajı:**
> **Başvurun alındı.**
> Başvuru no: {kısa_no}
> En geç {son_tarih} tarihine kadar {e-posta} adresine yanıt vereceğiz. Durumunu "Başvurularım"dan izleyebilirsin.

**Başvurularım — durum adları:** `received` → Alındı · `in_progress` → İnceleniyor · `answered` → Yanıtlandı · `rejected` → Gerekçeli yanıt verildi (e-postana bak)

**Hata metinleri** (sunucudan gelir): "Talebini kısaca yaz" · "Açık başvurun var; yanıtlanınca yenisini gönderebilirsin" · "Açıklama en çok 2000 karakter".

**Bildirim** (`kvkk_answered`): Başlık "KVKK başvurun yanıtlandı" · Metin "Yanıtı e-posta adresine gönderdik."

**Pofi Adası:** form yok; ebeveyn kapısı › Bilgi ekranında "Çocuğun adına başvuru: ParentApp › Ayarlar › KVKK başvurusu" (bkz. 10).

## 5. Hesap silme

### 5.1 ParentApp

| Uygulama | Ekran | Bağlı belge | Sunucu |
|---|---|---|---|
| ParentApp | Ayarlar › Hesabımı sil | `gizlilik` (13. bölüm) | `delete_account()` |

**Aktif mağaza aboneliği varsa (en üstte, kırmızı kutu):**
> **Aboneliğin Apple'da devam ediyor.**
> Hesabını silmek aboneliği durdurmaz; Apple ücret almaya devam eder. Önce aboneliğini iptal et.
> [ Aboneliği yönet ]

**Ailede başka ebeveyn yoksa:**
> **Hesabını silersen ailen de silinir.**
> Ailende başka ebeveyn olmadığı için şunlar kalıcı olarak silinir:
> - hesabın ve çocuk profillerin,
> - görevler, onaylar, ödüller, coin ve Güneş Taşı geçmişi,
> - mesajlar, fotoğraflar ve sesli mesajlar,
> - zor an kayıtları ve tanışma yanıtları,
> - uzman paylaşımları (uzmanın erişimi hemen biter) ve uzmanın bu çocuklar için tuttuğu notlar, hedefler ve takip planı,
> - oyun yedekleri.
>
> Çocuğunun cihazındaki Pofi Adası'nın aileyle bağlantısı kapanır.

**Ailede başka ebeveyn varsa:**
> **Yalnız senin hesabın silinir.**
> Ailende {diğer_ebeveyn} da var. Aile, çocuklar ve kayıtlar onda kalır.

**Her iki durumda alt kısım:**
> Kanunen saklamamız gereken ödeme kayıtları ve ekip işlem kaydı, e-posta adresin çıkarılarak süresi dolana kadar tutulur. Ücretsiz deneme hakkının tekrar kullanılmaması için e-posta adresinin geri çevrilemez bir özeti saklanır. <u>Ayrıntı</u>
>
> **Bu işlem geri alınamaz.** Onaylamak için **SİL** yaz: [ ______ ]
>
> [ Hesabımı kalıcı olarak sil ]

**Sonra:** "Hesabın silindi." ekranı + oturum kapanır.

**Uygulamaya giremeyenler için** (yardım sayfası ve SSS): "Uygulamaya giremiyorsan [ALAN ADI]/hesap-sil sayfasından ya da `kvkk@[ALAN ADI]` adresinden silme talebinde bulunabilirsin."

### 5.2 ClinicApp

| Uygulama | Ekran | Bağlı belge | Sunucu |
|---|---|---|---|
| ClinicApp (iPad + web) | Profil › Hesabımı sil | `gizlilik`, `sozlesme-uzman` | `delete_account()` |

**Klinik sahibinin aktif mağaza üyeliği varsa:** 5.1'deki kutu, metin "Klinik üyeliğin Apple'da devam ediyor…" (web'de: "Üyeliğini iPhone/iPad'deki App Store ayarlarından iptal et.").

**Tek kişilik klinik:**
> **Kliniğin ve içindeki her şey silinir:** danışan paylaşımları, notlar, hedefler, haftalık değerlendirmeler, görev önerileri, takip planları, davetler ve üyelik kaydı. Ailelerin ParentApp'teki kendi verileri silinmez; yalnız seninle paylaşımları biter. Kayıtların, ailenin izniyle sonraki uzmana aktarımı da sona erer. Saklaman gereken kayıtları önce yazdır ya da destekten iste.

**Ekipte başka uzman varken klinik sahibi:**
> Klinik kalır; sahiplik ekibin en eski üyesine ({ad}) geçer. Kliniğe ait kayıtlar klinikte kalır. Yalnız senin hesabın silinir.

**Ekip üyesi:**
> Yalnız senin hesabın silinir. Kliniğe ait kayıtlar klinikte kalır.

Alt kısım, onay ve düğme 5.1 ile aynı.

### 5.3 Pofi Adası

Hesap silme ekranı yoktur (çocuğun hesabı yok). Ebeveyn kapısı › Bilgi ekranında cihaz bağlantısının kaldırılması ve silme yolu anlatılır (bkz. 10). ParentApp'te tek çocuk profilini silme ekranı bugün yok (`README.md` sorun 5); yapılınca metin "ParentApp › Aile › çocuk › Profili sil" olur.

## 6. Abonelik ekranı (Apple 3.1.2)

### 6.1 ParentApp

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ParentApp | Aile › Hesap › Üyelik; deneme bitince açılışta | `kosullar-parentapp`, `gizlilik` |

> **[PLAN ADI]**
> Bütün aile için: birden çok çocuk, sınırsız görev, ödüller ve Güneş Taşı, mesajlar, zor an kayıtları.
>
> ○ **Aylık** — {fiyat_aylık} / ay (KDV dahil)
> ○ **Yıllık** — {fiyat_yıllık} / yıl (aylık {aylık_karşılık})
>
> [ {seçilen_fiyat} ile abone ol ]
>
> Ödeme, satın almayı onayladığında Apple hesabından alınır. Abonelik, dönem bitmeden en az 24 saat önce iptal edilmezse aynı süre ve fiyatla kendiliğinden yenilenir; yenileme ücreti dönemin son 24 saati içinde alınır. Aboneliğini iPhone Ayarlar › [adın] › Abonelikler'den ya da aşağıdaki "Aboneliği yönet" ile istediğin an iptal edebilirsin; iptal, ödenmiş dönemin sonunda geçerli olur. İade talepleri Apple'ın kurallarına göre Apple'a yapılır.
>
> <u>Kullanım Koşulları</u> · <u>Gizlilik Politikası</u> · <u>Satın alımları geri yükle</u> · <u>Aboneliği yönet</u>
>
> <small>Şimdilik ücretsiz devam et</small>

- Fiyatlar mağazanın yerel fiyatından okunur; ekranda sabit fiyat yazılmaz.
- Plan adı, süre ve fiyat düğmeden önce ve en az düğme kadar görünür olmalı.
- "Şimdilik ücretsiz devam et" altındaki not: "Ücretsiz planda 1 çocuk ve 3 etkin görevle devam edersin; ödüller, mesajlar ve zor an kayıtları kapalıdır."

### 6.2 ClinicApp

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp (iPad/iPhone) | Üyelik (yalnız klinik sahibi) | `sozlesme-uzman`, `gizlilik` |

6.1 ile aynı yapı; paketler "Bireysel" ve "Klinik", her biri aylık ve yıllık, içerik listesi `billing_plans`'tan.

- **Ekip üyesine:** fiyat gösterilmez. Metin: "Klinik üyeliğini klinik sahibi ({ad}) yönetir."
- **Web:** satın alma yok. Metin: "Üyeliği iPhone ya da iPad'deki ClinicApp'ten alabilirsin. Üyelik hesabına bağlıdır; web'de de açılır."

## 7. Deneme bitişi bildirimi

Deneme App Store denemesi değildir: kart istenmez, süre bitince **kendiliğinden ücret alınmaz**. Metinler buna göre yazıldı.

| Uygulama | Ne zaman | Kanal |
|---|---|---|
| ParentApp | Bitime 2 gün kala ve bittiği gün *(öneri)* | Anlık bildirim + uygulama içi bildirim; e-posta "deneme bitiyor" (`CANLIYA_ALMA.md` 1.3) |
| ClinicApp | Bitime 3 gün kala ve bittiği gün *(öneri)* | Aynı |

**ParentApp — bitmeden:**
- Başlık: Denemenin bitmesine {gün} gün kaldı
- Metin: Bittiğinde ücretsiz planla devam edersin; senden kendiliğinden ücret alınmaz. Premium'u sürdürmek istersen üyelik ekranına bak.

**ParentApp — bitince (açılışta, 6.1 ekranının üstünde):**
> **Deneme süren bitti.** Ücretsiz planda 1 çocuk ve 3 etkin görevle devam edebilirsin; ödüller, mesajlar ve zor an kayıtları kapanır. Verilerin silinmez.

**ClinicApp — bitmeden:**
- Başlık: Denemenin bitmesine {gün} gün kaldı
- Metin: Deneme bitince danışan kayıtlarına erişim, üyelik alınana kadar kapanır. Verilerin silinmez; kendiliğinden ücret alınmaz.

**ClinicApp — bitince:**
> **Deneme süren bitti.** Üyelik alana kadar danışanlar, notlar, hedefler, öneriler ve davetler kapalı. Verilerin silinmedi; üyelik alınca kaldığın yerden devam edersin.

## 8. Coin ve Güneş Taşı bilgi notu

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ParentApp | Ödüller › "i" düğmesi; ilk kullanım ipucu | `kosullar-parentapp` |

> **Coin ve Güneş Taşı nedir?**
> **Coin**, çocuğunun senin onayladığın görevlerle kazandığı oyun parasıdır. Yalnız Pofi Adası'ndaki eşyalara harcanır. Satın alınamaz, gerçek paraya çevrilemez, başkasına aktarılamaz; hesap silinince kaybolur.
> **Güneş Taşı**, çocuğuna verdiğin ödüllerin sayacıdır. Ödülleri ve değiş tokuş oranlarını (ör. "1 taş = 10 dk ekran") sen belirlersin. Taşın parasal değeri yoktur; ödülün sözünü sen verirsin, biz bu ödüllerin tarafı değiliz.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Pofi Adası | Dükkân ve ödül dükkânı › "i" (çocuğa; sesli okunur) | `kosullar-gameapp` |

> Coin'ler adanın parasıdır. Görevlerini yapınca kazanırsın, adadaki eşyalara harcarsın. Gerçek para değildir.
>
> Güneş Taşları ailenin ödülleri içindir. Taşın yetince ödül isteyebilirsin. Kararı ailen verir.

## 9. Acil durum notu

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ParentApp | Zor an kaydı ekranının altı (sabit); Uzmanım ekranının altı; Yardım ve iletişim | `kosullar-parentapp` |

> ParentApp bir acil yardım hizmeti değildir. Çocuğunun ya da başka birinin güvenliği tehlikedeyse hemen **112**'yi ara. Zor an kaydın uzmanına anında ulaşmayabilir.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Danışan › Zor anlar sekmesinin üstü; Yardım/Hakkında; web alt bilgisi | `sozlesme-uzman` |

> ClinicApp acil yardım ya da kriz izleme hizmeti değildir. Ailelerin kayıtları sana gecikmeyle ulaşabilir. Acil bir durum fark edersen **112**'yi ara ya da aileyi hemen 112'ye yönlendir.

## 10. Pofi Adası — ebeveyn kapısı › Bilgi ekranı

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Pofi Adası | Ebeveyn kapısı geçildikten sonra "Bilgi" | `gizlilik`, `kosullar-gameapp`, `aydinlatma-cocuk`, `kvkk-basvuru` |

> *(En üstte, büyük yazıyla ve sesli okunarak: `aydinlatma-cocuk` Kısım B — çocuğa kısa not.)*
>
> **Ebeveynler için bilgi**
>
> - Pofi Adası'nda reklam, satın alma ve üçüncü taraf izleme aracı yok.
> - Çocuğundan e-posta, telefon, konum, fotoğraf ya da ses almıyoruz. Kamera yalnız ParentApp'teki QR kodu okumak için açılır; görüntü kaydedilmez.
> - Çocuğun yalnız seninle ve ailendeki diğer ebeveynle yazışır.
> - Oyun, ParentApp'te oluşturduğun profile bağlıdır. Profili ParentApp'ten düzenlersin.
> - Bu cihazın bağlantısını kapatmak için: ParentApp › Aile › {çocuk_adı} › Cihaz bağlantısını kaldır. Çocuğunun verilerinin silinmesini KVKK başvurusuyla isteyebilir ya da ParentApp'te hesabını silerek aileyle birlikte silebilirsin.
> - Çocuğun adına KVKK başvurusu: ParentApp › Ayarlar › KVKK başvurusu.
>
> <u>Gizlilik Politikası</u> · <u>Pofi Adası Koşulları</u> · <u>Çocuk ve Veli Aydınlatma Metni</u> · <u>KVKK Başvuru Usulü</u>
> Destek: `destek@[ALAN ADI]` · Sürüm {sürüm}
>
> [ Bu cihazın bağlantısını kaldır ] *(öneri: oyunun içinden de; `CANLIYA_ALMA.md` 2.2 "ebeveyn kapısı: bağlama")*

- Bağlantılar tarayıcıda açılır; açılmadan önce: "Bu bağlantı tarayıcıda açılacak."
- Kısım B sesli okunur; ebeveyn bölümü için sesli okuma gerekmez *(Pofi Adası penceresi karar verir)*.

## 11. ClinicApp web — çerez bandı

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp web | İlk ziyarette alt bant, içeriği kapatmaz; "Anladım" sonrası bir daha gösterilmez (`40-cerez-politikasi.md` ile aynı metin) | `cerez-clinicapp-web`, `gizlilik` |

> ClinicApp web yalnız oturumunu açık tutmak ve seçimlerini hatırlamak için zorunlu tarayıcı depolaması kullanır. Analiz ya da reklam çerezi yok. <u>Çerez Politikası</u> [ Anladım ]

- Yalnız zorunlu kayıtlar varken onay istenmez, bilgilendirme yeterlidir. Analiz aracı eklenirse bant "Kabul et / Reddet" düğmeleri eşit görünürlükte, önceden seçimsiz hâle gelir ve araç onaydan önce yüklenmez.

## 12. Uzman ekranları (`hukuk_notlari.md` E)

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Danışan › Notlar, not alanının altı | `sozlesme-uzman` (A2–A3), `aydinlatma-uzman` |

> Notlarını aile görmez. Ebeveyn izin verirse notların, adın gizlenerek çocuğun sonraki uzmanına okunur olarak açılabilir. Nota kimlik bilgisi yazma.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Danışan › devralınan kayıtlar başlığı | `uzman-gecis-v1` |

> Önceki uzman {n} · {başlangıç_ay} – {bitiş_ay} · ebeveynin izniyle, yalnız okuma

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Aileyi davet et › "Çocuğun adı" + yaş grubu alanının altı ve "i" | `sozlesme-uzman` (A9, A13) |

> Yalnız daveti kabul eden ebeveyn görür. Sağlık bilgisi yazma.

"i" ayrıntısı:
> Çocuğun adını ve yaş grubunu yazarsan yalnız daveti kabul eden ebeveyn görür; kontrol edip onaylar, düzeltirse sana bildirim gelir. Mesajda görünmez, davet bitince silinir.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Aileyi davet et › ebeveynin e-posta alanının altı | `sozlesme-uzman` (A13) |

> Bu adrese senin adına davet e-postası gider; çocuğun adı ve notun e-postada yer almaz. Aile yanıtlarsa yanıt senin e-posta adresine gelir. Daveti yalnız tanıdığın ve hizmet verdiğin aileye gönder.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Belgeni yükle (bayrak `clinician_verification` açıkken) | `aydinlatma-uzman`, `sozlesme-uzman` (A11–A12) |

> Belgen yalnız inceleme için okunur, karar verilince silinir; kimlik numaran saklanmaz. Ailelere yalnız "Belgesi incelendi: <meslek>" görünür; bu bir yetki onayı değildir. <u>Uzman Aydınlatma Metni</u>

ParentApp davet ekranı uyarısı ve veli beyanı kutusu (`uzman-paylasim-v1`) ile önceki uzman kayıtları onay metni (`uzman-gecis-v1`) `hukuk_notlari.md` B ve E'deki metinlerdir; burada tekrar edilmez.

## 13. "Tanı değildir" notu

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ParentApp | Haftalık özet, gösterge ve ilerleme ekranlarının altı | `kosullar-parentapp` |

> Bu sayılar çocuğunun uygulamadaki görevlerini özetler; tanı, zekâ ya da dikkat puanı değildir.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Göstergeler ve hedef grafikleri (alt bilgi) | `sozlesme-uzman` |

> Bu oranlar ev rutinine ilişkin gözlem özetidir; tanı, zekâ ya da dikkat puanı değildir.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| ClinicApp | Yazdırma/PDF çıktısının alt bilgisi | `sozlesme-uzman` |

> Bu çıktı ailenin uygulama kayıtlarından ve uzmanın gözlemlerinden oluşur. Tanı değildir; tek başına klinik karar için kullanılmaz.

## 14. İzin açıklamaları

iOS sistem penceresinde görünen amaç metinleri (`Info.plist`) ve sistem penceresinden önce gösterilen kısa ön açıklamalar.

| Uygulama | İzin (`Info.plist` anahtarı) | Ne zaman sorulur | Metin |
|---|---|---|---|
| Pofi Adası | Kamera (`NSCameraUsageDescription`) | Giriş ekranında "QR okut"a ilk basıldığında, ebeveyn kapısından sonra | ParentApp'te gösterilen QR kodu okumak için kamerayı kullanırız. Görüntü kaydedilmez, gönderilmez. |
| Pofi Adası | Bildirim (sistem; amaç metni yok) | İlk gereken anda *(öneri: ebeveyn kapısının arkasında)* | Ön açıklama: "Ailen sana yazınca ya da görevini onaylayınca haber verelim mi?" [İzin ver] [Şimdi değil] |
| ParentApp | Mikrofon (`NSMicrophoneUsageDescription`) | Sesli mesaj ya da zor an ses kaydına ilk basıldığında | Sesli mesaj ve zor an ses kaydı için mikrofonu yalnız sen kayda bastığında kullanırız. |
| ParentApp | Fotoğraflar (`NSPhotoLibraryUsageDescription`) | Mesaja ilk fotoğraf eklenirken | Çocuğuna mesajla göndermek için seçtiğin fotoğrafa erişiriz. |
| ParentApp | Kamera (`NSCameraUsageDescription`) — *yalnız mesajda fotoğraf çekme varsa* | Mesajda "Fotoğraf çek"e ilk basıldığında | Çocuğuna mesajla göndereceğin fotoğrafı çekmek için kamerayı kullanırız. |
| ParentApp | Bildirim | İlk görev oluşturulunca *(öneri)* | Ön açıklama: "Çocuğun bir görevi yaptığında ya da sana yazdığında haber verelim mi?" [İzin ver] [Şimdi değil] |
| ClinicApp | Bildirim | İlk aile bağlanınca *(öneri)* | Ön açıklama: "Bir aile seninle çocuk paylaştığında, öneri kararında ya da yeni zor an kaydında haber verelim mi?" [İzin ver] [Şimdi değil] |
| ClinicApp | Fotoğraflar (`NSPhotoLibraryUsageDescription`) — *yalnız belge görsel olarak seçilebiliyorsa* | "Belgeni yükle"de | Mezuniyet belgeni yüklemek için seçtiğin dosyaya erişiriz. Belge incelemeden sonra silinir. |

- İzin reddedilirse özellik kibarca kapanır; uygulamanın geri kalanı çalışır. Ayarlara yönlendiren metin: "İzni iPhone Ayarlar › {uygulama} bölümünden açabilirsin."

## Avukata notlar

1. **Kayıt ekranında aydınlatma (karar önerisi uygulandı 27 Ekim 2026: kutusuz satır + "gösterildi" kaydı; avukat teyit etsin):** "Aydınlatma Metni'ni okudum" kutusu onay (rıza) gibi algılanabilir. Kutu yerine yalnız bağlantı + "gösterildi" kaydı mı yeterli, yoksa kutu ispat için mi tutulmalı? `tools/legal_seed.py` aydınlatmaları "onay ister" (okundu) olarak yüklüyor; `22-uzman-hizmet-sozlesmesi.md` Ek-3 ise ClinicApp'te aydınlatmayı kutusuz bir satır olarak öneriyor. İkisinden biri seçilip iki belge eşitlenmeli.
2. **Abonelik ekranı (6):** Apple'ın yenileme ve iptal bilgisi kendi cümlelerimizle yazıldı; 6502 s. Kanun ve Abonelik Sözleşmeleri Yönetmeliği açısından ekranda ayrıca bulunması gereken bir bilgi (ör. cayma hakkı istisnası, satıcının Apple olduğu) var mı? Deneme sunucu tarafında, kartsız ve ücretsiz bitiyor; ileride App Store "ücretsiz deneme" teklifine geçilirse 6–7. bölüm metinleri değişmeli.
3. **Pofi Adası koşulları güncellenince oyun kilitlensin mi (2):** Veli yeni sürümü ParentApp'te onaylayana kadar çocuğun oyunu kilitlenmiyor (öneri: çocuğu cezalandırmamak). Bu, eski sürümle kullanımın sürmesi demek; hukuken kabul edilebilir mi?
4. **Hesap silmede kalanlar (5):** "Ödeme kayıtları, ekip işlem kaydı ve deneme e-posta özeti kalır" cümlesi `42-saklama-imha-politikasi.md` süreleriyle birlikte onaylanmalı.
5. **Ürün kararı / teyit gerekenler (yazılım):** Ekip sahibi silinince "kliniğe ait kayıtlar klinikte kalır" cümlesi sunucu davranışıyla teyit edilmeli. `kvkk_requests`'te çocuk alanı yok; "Kimin için?" seçimi bugün açıklamaya yazılıyor (ayrı sütun önerisi). ParentApp'te tek çocuk profilini silme ekranı yok (`README.md` sorun 5); 5.3 ve 10. bölüm buna göre yazıldı.
6. **Hesap silmede uzman kayıtları (5.1):** Ebeveyne "uzmanın bu çocuklar için tuttuğu notlar da silinir" deniyor (bugünkü sistem). Uzmanın kayıt saklama yükümlülüğüyle çatışma kararı (`00-olgular.md` §2) değişirse bu satır da değişir.
