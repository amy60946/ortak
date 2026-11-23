# Uygulama İçi Hukuki Metinler (yazılımcılar için)
| Anahtar | iç belge | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Moyo Oyun (GameApp), Moyo Ebeveyn (ParentApp) ve Moyo Mercek (ClinicApp) pencereleri; ekran ekran gösterilecek kısa metinler ve bağlı belge anahtarları | Dayanak | KVKK md. 3, 5, 6, 10, 11; 6502 s. TKHK md. 5; Kurul'un Çerez Uygulamaları Hakkında Rehberi; Apple App Review 3.1.2, 5.1.1 |

> İç not — 20 Kasım 2026: 14 Kasım kararları, çekirdek maddeler, Moyo adları, deneme 14 gün (sürüm v1 kaldı). Ekran metinlerinde ad kuralı: aile uygulaması kendinden "Moyo" diye söz eder, başka uygulamadan anılırken "Moyo Ebeveyn"; çocuğun oyunu "Moyo Oyun"; uzman ürünü uzmana dönük metinde "Moyo Mercek", aileye dönük metinde "Moyo Uzman". Tablolardaki uygulama adları yeni adlarla; "… penceresi" iç addır. Avukat dosyasının kısa metin önerileri §15'te (kullanıcı kararı bekler).
> 20 Kasım 2026 (ikinci tur, kullanıcının avukat sorularına yanıtları): Moyo Mercek kayıtta aile bağı bilgisi (§1.2, B.8), belge yükleme kullanılmıyor (§12, §14), Moyo Ebeveyn bildirim ayarları ve tanıtım izni (§14.1, yeni; kullanıcı kararı 5a, D.16), tek iletişim adresi `destek@`.
> 23 Kasım 2026: ebeveyn eğitimi ve kısa ebeveyn dersleri lansmanda kapalı (kullanıcı kararı; bayrak `parent_training`): her zaman görünen hesap silme metinlerinden (§5.1, §5.2) eğitim ve ders sözleri çıktı; yalnız eğitime ve derslere ait metinler (§13 ebeveyn dersleri ve kaynak kütüphanesi, §15 satır 2'deki eğitim yanıtı) bayrak açıkken gösterilir. Özgün metin `hukuk/ek-ebeveyn-egitimi.md`.

## Kısaca

- Bu belge, üç uygulamada gösterilecek hukuki kısa metinlerin **tek kaynağıdır**. Her metin için uygulama, ekran, metin ve bağlı belge anahtarı yazılıdır.
- Uzun metinler (koşullar, aydınlatma, gizlilik) uygulamaya gömülmez; `legal` sunucu işlevinden ya da `legal_documents_for(app)` ile açılır. Burada yalnız ekranın kendi kısa metinleri vardır.
- Onay kutuları **önceden işaretli gelmez**. Kullanım Koşulları onayı, aydınlatmayı okuma ve açık rızalar **ayrı satırlardır**; birbirine bağlanmaz.
- Açık rıza metinleri (`uzman-paylasim-v1`, `uzman-gecis-v1`) kendi akışlarında kalır; bu belge onları tekrar etmez. Tanışmadaki sağlık yanıtı rızası (`saglik-yanit-v1`) tanı ve ilaç sorularıyla birlikte 14 Kasım 2026'da kalktı.
- Avukat dosyasının önerdiği kısa metinler §15'te; uygulamaya alınmaları kullanıcı kararıyla (rapor alt satırı uygulandı).

## 0. Genel kurallar

| Kural | Ayrıntı |
|---|---|
| Hitap | Moyo Ebeveyn ve Moyo Mercek: "sen" (uygulamaların mevcut dili). Moyo Oyun: çocuğa kısa ve sade; ebeveyn kapısının arkası ebeveyne "sen" |
| Terimler | Aile ve uzman ekranlarında iş nesnesi **rutin** (paket) ve **adım** (tek iş), oyun ekranlarında **macera** (`sozlesme/durumlar.md` 5B). Gözlem anlamında "izle" yerine "takip"; "klinik karar" kullanılmaz; kendi metinlerimizde kayıtlara "sağlık verisi" denmez (`00-olgular.md` §1a). Moyo Mercek ekranlarında "danışan" kalır |
| Değişkenler | `{süslü parantez}` = uygulamanın doldurduğu değer (ör. `{fiyat}`). `[KÖŞELİ]` = canlıdan önce bir kez doldurulacak yer tutucu |
| Bağlantılar | Altı çizili metin = ilgili belgeyi açan bağlantı (anahtar tabloda) |
| Onay kaydı | Onay isteyen metinler `legal_accept(app, [{key, version}])` ile kaydedilir; bekleyenler `legal_pending(app)` (`migrations/20261027200000_legal.sql`, uygulandı 27 Ekim 2026) |
| Kayıt sırasında | Kayıt anında oturum henüz açık değil (e-posta doğrulaması). İşaretlenen sürümler kayıt bilgisine eklenir; ilk girişte `legal_accept` ile yazılır ya da ilk girişte `legal_pending` ekranı gösterilir |
| Moyo Oyun sesli okuma | Çocuğa gösterilen her yeni metin için ses üretilir (game-app `CLAUDE.md`, `build_voice.py --missing`) |
| Değişiklik | Bu belgedeki bir metin değişirse bağlı belgeyle tutarlılığı kontrol edilir; açık rıza metni değişirse rıza sürümü de değişir (`-v2`) |
| Diğer taslaklar | Moyo Mercek kısa metinleri `22-uzman-hizmet-sozlesmesi.md` Ek-3'te, çerez bandı `40-cerez-politikasi.md`'de, çocuğa kısa not `11-aydinlatma-cocuk-ve-veli.md` Kısım B'de de yazılı; bu belgedekilerle aynı tutulur |

**Belge anahtarları:**

| Anahtar | Belge | Uygulama | Onay ister |
|---|---|---|---|
| `kosullar-parentapp` | Moyo Ebeveyn Kullanım Koşulları (abonelik dahil) | parent | Evet |
| `kosullar-gameapp` | Moyo Oyun Koşulları (veli çocuk adına onaylar) | child (onay Moyo Ebeveyn'de) | Evet |
| `sozlesme-uzman` | Moyo Mercek Uzman Hizmet Sözleşmesi | clinic | Evet |
| `veri-isleme-eki` | Veri İşleme Eki (sözleşmenin Ek-1'i) | clinic | Evet |
| `aydinlatma-ebeveyn` | Ebeveyn Aydınlatma Metni | parent | Gösterildi kaydı (kutu yok) |
| `aydinlatma-uzman` | Uzman Aydınlatma Metni | clinic | Gösterildi kaydı (kutu yok) |
| `aydinlatma-cocuk` | Moyo Oyun Çocuk ve Veli Aydınlatma Metni | child (Moyo Ebeveyn'de gösterilir) | Gösterildi kaydı (kutu yok) |
| `gizlilik` | Gizlilik Politikası | hepsi + web | Hayır |
| `alt-isleyenler` | Hizmet Sağlayıcılar Listesi | hepsi + web | Hayır |
| `kvkk-basvuru` | KVKK Başvuru Usulü | hepsi + web | Hayır |
| `cerez-clinicapp-web` | Web Çerez Politikası (Moyo Mercek web; Moyo Ebeveyn web `/app/`) | clinic, web | Hayır |
| `acik-riza-metinleri` | Moyo Ebeveyn açık rıza metinleri (her rıza kendi sürümüyle: `uzman-paylasim-v1`, `uzman-gecis-v1`; `saglik-yanit-v1` 14 Kasım 2026'da kalktı) | parent, web | Ayrı rıza kutuları |

## 1. Kayıt ekranı onay satırları

### 1.1 Moyo Ebeveyn — kayıt

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Kayıt ol (e-posta + şifre), "Hesap oluştur" düğmesinin üstü | `kosullar-parentapp`, `aydinlatma-ebeveyn`, `gizlilik` |

> ☐ <u>Kullanım Koşulları</u>'nı okudum, kabul ediyorum.
>
> Kişisel verilerinin nasıl işlendiğini <u>Aydınlatma Metni</u>'nde anlatıyoruz. *(kutu yok; düz satır)*
>
> <small><u>Gizlilik Politikası</u></small>

- Koşullar kutusu işaretlenmeden "Hesap oluştur" pasif kalır. Aydınlatma bir onay değil, bilgilendirmedir: kutu konmaz; hesap oluşunca koşulların onayıyla birlikte aydınlatmanın **gösterildiği** de `legal_accept` ile kaydedilir (karar 27 Ekim 2026, avukat teyidi bekler).
- Bu ekranda **açık rıza kutusu yoktur**. Uzman paylaşımı kendi ekranında, isteğe bağlı sorulur (tanışmadaki sağlık soruları ve rızası 14 Kasım 2026'da kalktı). Pazarlama izni bugün istenmez.

**Güncel (kullanıcı kararı 28 Ekim 2026, parent-app):** "Kayıt ol" düğmesinin üstünde tek küçük satır, tek kutu:

> ☐ <u>Kullanım Koşulları</u>'nı kabul ediyorum. <u>Aydınlatma</u> · <u>Gizlilik</u>

- Kutu işaretlenmeden "Kayıt ol" pasif (etkin eylem). Aydınlatma ve gizlilik yalnız bağlantı; aydınlatmanın gösterildiği hesap açılınca kaydedilir.
- *Öneri (avukat dosyası, kullanıcı kararı bekler):* aynı kutunun metni §15 satır 1 ile uzar ("Moyo bir takip aracıdır; …").

### 1.2 Moyo Mercek — kayıt

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek (iPad + web) | Kayıt ol, "Hesap oluştur" düğmesinin üstü; ekip koduyla katılım ekranı | `sozlesme-uzman`, `veri-isleme-eki`, `aydinlatma-uzman`, `gizlilik` |

**Güncel (kullanıcı kararı 28 Ekim 2026, ortak#94):** "Hesap oluştur" düğmesinin hemen üstünde tek küçük satır:

> <u>Hizmet Sözleşmesi</u> ve <u>Veri İşleme Eki</u>'ni kabul ediyorum. <u>Aydınlatma</u> · <u>Gizlilik</u>

- Kabul **etkin bir eylemle** olmalı: satırdaki kutu işaretlenmeden ya da düğme "Kabul et ve hesap oluştur" olmadan hesap açılmaz (sessizce "kullanarak kabul" sayılmaz — `03-joon-karsilastirma.md` X4).
- Aydınlatma bağlantıdır, kutusu yoktur; hesap açılınca gösterildiği kaydedilir.
- *(Önceki uzun biçim: iki satır — sözleşme kutusu + ayrı aydınlatma satırı. Sözleşme Ek-3 bu kısa biçime göre güncellenecek.)*
- **Aile bağı bilgisi (kullanıcı kararı 20 Kasım 2026, B.8: "uzman kayıtlarının silineceğini uzmana en başta söylediğimizden emin ol"; Moyo Mercek penceresi uygular):** kabul satırının hemen üstünde tek küçük satır:

> Aile paylaşımı bitirirse yeni kayıt göremezsin; aile hesabını ya da çocuğu silerse o aileye ait notların ve kayıtların da silinir. Saklaman gereken kayıtları raporla ya da CSV ile kendin indir.

  Karşılığı Uzman Hizmet Sözleşmesi 6.4-a ve Ek-3 kayıt satırı, Uzman Aydınlatma Metni 7. Uzman arayüzündeki sınır uyarısı değildir (3 Kasım 2026 kararı): veri akışını anlatır.
- *Öneri (avukat dosyası, kullanıcı kararı bekler):* §15 satır 5 ("Moyo Mercek bir takip panelidir. …"); 3 Kasım 2026 kararıyla çelişebilir.

### 1.3 Moyo Ebeveyn — Moyo Oyun'u bağlamadan önce (veli onayı)

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Çocuk › "Giriş kodu üret" / QR — yalnız ilk kez ve metin güncellenince | `kosullar-gameapp`, `aydinlatma-cocuk` |

> **Moyo Oyun'u {çocuk_adı}'nın cihazına bağlamadan önce**
>
> Moyo Oyun'da reklam, satın alma ve dışarıdan izleme aracı (reklam ya da analiz takibi) yok. {çocuk_adı}'nın oyundaki ilerlemesi yalnız ailesine, izin verirsen uzmanına da gösterilir. Oyun ondan e-posta, konum, fotoğraf ya da ses almaz.
>
> *(27 Ekim'deki "izleme aracı yok" ifadesi kullanıcı sorusu üzerine netleştirildi, 28 Ekim 2026: kastedilen üçüncü taraf takip; oyunun aileye raporladığı ilerleme kaydı değil. Bkz. `sozlesme/hukuk_notlari.md` E.)*
>
> ☐ {çocuk_adı}'nın velisi olarak <u>Moyo Oyun Koşulları</u>'nı okudum, çocuğum adına kabul ediyorum.
>
> Çocuğunun verilerinin nasıl işlendiğini <u>Moyo Oyun Çocuk ve Veli Aydınlatma Metni</u>'nde anlatıyoruz. *(kutu yok)*

- Kayıt: `legal_accept('child', …)` (çocuk cihazı onay veremez; sunucu reddeder).

**Güncel (kullanıcı kararı 28 Ekim 2026: kısa, ayrıntı bağlantıda):** küçük kart; veli onayı ayrı kalır.

> **Moyo Oyun'u bağlamadan önce**
>
> Oyunda reklam, satın alma ve dışarıdan izleme aracı yok. {çocuk_adı}'nın ilerlemesini yalnız ailesi, izin verirsen uzmanı görür.
>
> ☐ Velisi olarak <u>Moyo Oyun Koşulları</u>'nı {çocuk_adı} adına kabul ediyorum. <u>Aydınlatma</u>

- "Oyun ondan e-posta, konum, fotoğraf ya da ses almaz" cümlesi karttan çıktı; aydınlatma metninde duruyor.

### 1.4 Moyo Ebeveyn — çocuk ekleme

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | ~~Çocuk ekle, "Kaydet" düğmesinin altı~~ **3 Kasım 2026'dan beri ekranda yok** (kullanıcı kararı: beyan Kullanım Koşulları'nda) | `kosullar-parentapp` (veli beyanı maddesi) |

> ~~Çocuğu ekleyerek velisi ya da yasal temsilcisi olduğunu beyan edersin. Doğum günü ve cinsiyet isteğe bağlıdır.~~

Kalan güvenceler: kayıtta Kullanım Koşulları kutusu (§1.1), oyuna bağlamadan önce veli onayı (§1.3), uzman davetinde veli beyanı kutusu (`uzman-paylasim-v1`). Avukata soru: `hukuk_notlari.md` soru 21.

## 2. Yeniden onay ekranı

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Üçü (Moyo Oyun metinleri Moyo Ebeveyn'de) | Açılışta `legal_pending(app)` boş değilse tam ekran | Güncellenen belge(ler) |

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
> <small>Kabul etmek istemiyorsan <u>hesabını silebilir</u> ya da `destek@moyoapp.com.tr` adresine yazabilirsin.</small>

- Birden çok metin güncellendiyse hepsi aynı ekranda alt alta; her biri ayrı kutu.
- **Moyo Mercek (28 Ekim 2026):** küçük kart, tek satır; sözleşme ve eki için tek kutu; `summary` yalnız "Kısaca neler değişti?" açılır alanında.
- **Moyo Ebeveyn (28 Ekim 2026):** aynı küçük kart. Koşullar için bir kutu ("<u>Moyo Ebeveyn Kullanım Koşulları</u> metnini kabul ediyorum."); Moyo Oyun metinleri güncellendiyse **ayrı** veli kutusu ("Velisi olarak <u>Moyo Oyun Koşulları</u> metnini {çocuklar} adına kabul ediyorum."); aydınlatmalar kutusuz bağlantı satırı ("Verilerinin nasıl işlendiği: …"); altta "hesabını silebilir ya da KVKK başvurusu gönderebilirsin".
- Kutu işaretlenmeden "Devam et" pasif. Bu ekrandayken bile Ayarlar › Hesabımı sil, Yasal metinler ve KVKK başvurusu açılabilir olmalı.
- **Moyo Oyun koşulları güncellenince:** Moyo Ebeveyn'de ebeveyne "Moyo Oyun koşulları güncellendi — {çocuk_adı} adına onayla". Çocuğun oyunu bu arada kilitlenmez (karar: Avukata notlar 3).
- **Onay istemeyen metin güncellenince** (Gizlilik Politikası, Hizmet Sağlayıcılar): kapatılabilir üst bant:
  > Gizlilik Politikamızı güncelledik. <u>Neler değişti?</u>

## 3. Ayarlar › Yasal metinler

| Uygulama | Ekran | Kaynak |
|---|---|---|
| Üçü | Ayarlar › Yasal metinler (Moyo Oyun'da ebeveyn kapısının arkasında). **Moyo Mercek:** Ayarlar › **"Yasal ve gizlilik"** tek sayfası — metin listesi ve KVKK başvuru formu aynı sayfada; ana ekran altındaki bağlantılar kaldırıldı (28 Ekim 2026). **Moyo Ebeveyn:** Aile › Hesap › **"Yasal ve gizlilik"** tek satırı (eski "Yasal metinler" ve "KVKK başvurusu" satırları birleşti): metinler, Verdiğin izinler, "KVKK başvurusu ve başvurularım" (28 Ekim 2026) | `legal_documents_for(app)` |

Her satır: **başlık** · sürüm · (onay isteyenlerde) "Onayladın: {tarih}".

| Moyo Ebeveyn | Moyo Mercek | Moyo Oyun (ebeveyn kapısı arkası) |
|---|---|---|
| Kullanım Koşulları | Uzman Hizmet Sözleşmesi | Moyo Oyun Koşulları |
| Aydınlatma Metni | Veri İşleme Eki | Çocuk ve Veli Aydınlatma Metni |
| Gizlilik Politikası | Aydınlatma Metni | Gizlilik Politikası |
| Moyo Oyun Koşulları | Gizlilik Politikası | KVKK Başvuru Usulü |
| Moyo Oyun Çocuk ve Veli Aydınlatma Metni | Hizmet Sağlayıcılar | |
| Hizmet Sağlayıcılar | KVKK Başvuru Usulü | |
| KVKK Başvuru Usulü | Çerez Politikası (yalnız web) | |
| **Verdiğin izinler** → uzman paylaşımı, önceki uzman kayıtları: durum + "Geri al" (sağlık yanıtı izni 14 Kasım 2026'da kalktı) | | |

"Verdiğin izinler" alt başlığı:
> Bu izinler isteğe bağlıdır. Geri aldığında uygulamayı kullanmaya devam edersin; ilgili paylaşım hemen durur.

## 4. Ayarlar › KVKK başvurusu

| Uygulama | Ekran | Bağlı belge | Sunucu |
|---|---|---|---|
| Moyo Ebeveyn, Moyo Mercek | Ayarlar › KVKK başvurusu (Moyo Mercek'te "Yasal ve gizlilik" sayfasının içinde; Moyo Ebeveyn'de Aile › Hesap › Yasal ve gizlilik › "KVKK başvurusu ve başvurularım") | `kvkk-basvuru` | `kvkk_request_create(app, kind, detail[, child])`, `my_kvkk_requests()` |

**Üst metin:**
> Kişisel verilerinle ilgili taleplerini buradan iletebilirsin. En geç 30 gün içinde, ücretsiz yanıt veririz. Yanıt {e-posta} adresine gelir. <u>Başvuru usulü</u>

**Alanlar:**

1. **Kimin için?** *(yalnız Moyo Ebeveyn)* — "Kendim" / "{çocuk_adı}" (her çocuk için bir seçenek). Çocuk seçilirse `app = 'child'` ve açıklamanın başına "Çocuk: {çocuk_adı}" eklenir.
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
| Başka bir talep | `other` | Uzmanının notlarıyla ilgili talepler uzmanın kliniğine iletilebilir. *(Moyo Ebeveyn)* |

3. **Açıklama** — çok satırlı, en çok 2000 karakter; düzeltme, itiraz, zarar ve diğer taleplerde zorunlu.
   Yer tutucu: *"Talebini kısaca yaz. Gerekmedikçe sağlık bilgisi ya da başka birinin kişisel bilgisini yazma."*
4. **Bilgi satırı:**
   > Başvurun hesabına bağlıdır; kimliğini ayrıca kanıtlaman gerekmez. Bazı taleplerde e-posta adresine bir doğrulama bağlantısı gönderebiliriz.

**Düğme:** Başvuruyu gönder

**Onay mesajı:**
> **Başvurun alındı.**
> Başvuru no: {kısa_no}
> En geç {son_tarih} tarihine kadar {e-posta} adresine yanıt vereceğiz. Durumunu "Başvurularım"dan takip edebilirsin.

**Başvurularım — durum adları:** `received` → Alındı · `in_progress` → İnceleniyor · `answered` → Yanıtlandı · `rejected` → Gerekçeli yanıt verildi (e-postana bak)

**Hata metinleri** (sunucudan gelir): "Talebini kısaca yaz" · "Açık başvurun var; yanıtlanınca yenisini gönderebilirsin" · "Açıklama en çok 2000 karakter".

**Bildirim** (`kvkk_answered`): Başlık "KVKK başvurun yanıtlandı" · Metin "Yanıtı e-posta adresine gönderdik."

**Moyo Oyun:** form yok; ebeveyn kapısı › Bilgi ekranında "Çocuğun adına başvuru: Moyo Ebeveyn › Aile › Hesap › Yasal ve gizlilik › KVKK başvurusu" (bkz. 10).

## 5. Hesap silme

### 5.1 Moyo Ebeveyn

| Uygulama | Ekran | Bağlı belge | Sunucu |
|---|---|---|---|
| Moyo Ebeveyn | Ayarlar › Hesabımı sil | `gizlilik` (13. bölüm) | `delete_account()` |

**Aktif mağaza aboneliği varsa (en üstte, kırmızı kutu):**
> **Aboneliğin Apple'da devam ediyor.**
> Hesabını silmek aboneliği durdurmaz; Apple ücret almaya devam eder. Önce aboneliğini iptal et.
> [ Aboneliği yönet ]

**Ailede başka ebeveyn yoksa:**
> **Hesabını silersen ailen de silinir.**
> Ailende başka ebeveyn olmadığı için şunlar kalıcı olarak silinir:
> - hesabın ve çocuk profillerin,
> - rutinler ve adımlar, onaylar, ödüller, inci ve Güneş Taşı geçmişi,
> - mesajlar, fotoğraflar ve sesli mesajlar,
> - davranış kayıtları, davranış olayları ve tanışma yanıtları,
> - uzman paylaşımları (uzmanın erişimi hemen biter) ve uzmanın bu çocuklar için tuttuğu notlar, hedefler ve takip planı,
> - oyun yedekleri.
>
> Çocuğunun cihazındaki Moyo Oyun'un aileyle bağlantısı kapanır.

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

**Uygulamaya giremeyenler için** (yardım sayfası ve SSS): "Uygulamaya giremiyorsan moyoapp.com.tr/destek sayfasındaki formdan ya da `destek@moyoapp.com.tr` adresinden silme talebinde bulunabilirsin."

### 5.2 Moyo Mercek

| Uygulama | Ekran | Bağlı belge | Sunucu |
|---|---|---|---|
| Moyo Mercek (iPad + web) | Profil › Hesabımı sil | `gizlilik`, `sozlesme-uzman` | `delete_account()` |

**Klinik sahibinin aktif mağaza üyeliği varsa:** 5.1'deki kutu, metin "Klinik üyeliğin Apple'da devam ediyor…" (web'de: "Üyeliğini iPhone/iPad'deki App Store ayarlarından iptal et.").

**Tek kişilik klinik:**
> **Kliniğin ve içindeki her şey silinir:** danışan paylaşımları, notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, hedef davranışlar, takip planları, davetler ve üyelik kaydı. Ailelerin Moyo Ebeveyn'deki kendi verileri silinmez; yalnız seninle paylaşımları biter. Ailenin hedef davranışlara bildirdiği olaylar (davranışın adıyla) ailede kalır; sen ve kliniğin bunlara artık erişemezsiniz. Kayıtların, ailenin izniyle sonraki uzmana aktarımı da sona erer. Mevzuatın sana yüklediği kayıt saklama yükümlülüğü sende; saklaman gereken kayıtları silmeden önce indir ya da yazdır.

**Ekipte başka uzman varken klinik sahibi:**
> Klinik kalır; sahiplik ekibin en eski üyesine ({ad}) geçer. Kliniğe ait kayıtlar klinikte kalır. Yalnız senin hesabın silinir.

**Ekip üyesi:**
> Yalnız senin hesabın silinir. Kliniğe ait kayıtlar klinikte kalır.

Alt kısım, onay ve düğme 5.1 ile aynı.

### 5.3 Moyo Oyun

Hesap silme ekranı yoktur (çocuğun hesabı yok). Ebeveyn kapısı › Bilgi ekranında cihaz bağlantısının kaldırılması ve silme yolu anlatılır (bkz. 10). Moyo Ebeveyn'de tek çocuk profilini silme ekranı bugün yok (`README.md` sorun 5); yapılınca metin "Moyo Ebeveyn › Aile › çocuk › Profili sil" olur.

## 6. Abonelik ekranı (Apple 3.1.2)

### 6.1 Moyo Ebeveyn

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Aile › Hesap › Üyelik; deneme bitince açılışta | `kosullar-parentapp`, `gizlilik` |

> **[PLAN ADI]**
> Bütün aile için: birden çok çocuk, sınırsız rutin ve adım, ödüller ve Güneş Taşı, mesajlar, davranış kayıtları.
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
- "Şimdilik ücretsiz devam et" altındaki not: "Ücretsiz planda 1 çocuk ve 3 etkin adımla devam edersin; ödüller, mesajlar ve davranış kayıtları kapalıdır."

### 6.2 Moyo Mercek

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek (iPad/iPhone) | Üyelik (yalnız klinik sahibi) | `sozlesme-uzman`, `gizlilik` |

6.1 ile aynı yapı; paketler "Bireysel" ve "Klinik", her biri aylık ve yıllık, içerik listesi `billing_plans`'tan.

- **Ekip üyesine:** fiyat gösterilmez. Metin: "Klinik üyeliğini klinik sahibi ({ad}) yönetir."
- **Web:** satın alma yok. Metin: "Üyeliği iPhone ya da iPad'deki Moyo Mercek'ten alabilirsin. Üyelik hesabına bağlıdır; web'de de açılır."

## 7. Deneme bitişi bildirimi

Deneme App Store denemesi değildir: kart istenmez, süre bitince **kendiliğinden ücret alınmaz**. Metinler buna göre yazıldı.

| Uygulama | Ne zaman | Kanal |
|---|---|---|
| Moyo Ebeveyn (deneme 14 gün; başka bir ailenin davet koduyla 21 gün) | Bitimden **3 gün önce**, tek ve tarafsız hatırlatma (kullanıcı kararı 18 Kasım 2026, `sozlesme/akislar.md` 25); bitince açılışta aşağıdaki not | Anlık bildirim + uygulama içi bildirim; e-posta "deneme bitiyor" sonraki aşamada (`akislar.md` 25 aşama 3; `CANLIYA_ALMA.md` 1.3) |
| Moyo Mercek (deneme 14 gün) | Bitimden 3 gün önce, tek hatırlatma (aynı karar; cihazda planlanır, hafta sonuna denk gelirse önceki cuma; bayrak `lifecycle_nudges`) | Aynı |

Gün sayısı metne sabit yazılmaz (`{gün}`); deneme süresi aileye göre değişir (14 ya da 21 gün).

**Moyo Ebeveyn — bitmeden:**
- Başlık: Denemenin bitmesine {gün} gün kaldı
- Metin: Bittiğinde ücretsiz planla devam edersin; senden kendiliğinden ücret alınmaz. Premium'u sürdürmek istersen üyelik ekranına bak.

**Moyo Ebeveyn — bitince (açılışta, 6.1 ekranının üstünde):**
> **Deneme süren bitti.** Ücretsiz planda 1 çocuk ve 3 etkin adımla devam edebilirsin; ödüller, mesajlar ve davranış kayıtları kapanır. Verilerin silinmez.

**Moyo Mercek — bitmeden:**
- Başlık: Denemenin bitmesine {gün} gün kaldı
- Metin: Deneme bitince danışan kayıtlarına erişim, üyelik alınana kadar kapanır. Verilerin silinmez; kendiliğinden ücret alınmaz.

**Moyo Mercek — bitince:**
> **Deneme süren bitti.** Üyelik alana kadar danışanlar, notlar, hedefler, öneriler ve davetler kapalı. Verilerin silinmedi; üyelik alınca kaldığın yerden devam edersin.

## 8. İnci ve Güneş Taşı bilgi notu (görünen ad İnci: 3 Kasım 2026; teknik ad coin)

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Ödüller › ilk açılışta 3 kartlık tur, son kart (3 Kasım 2026); "i" düğmesi turu yeniden açar. Ekranda kısaltılmış hâli: "Coin ve Güneş Taşı'nın parasal değeri yoktur: satın alınamaz, paraya çevrilemez. Ödülün sözünü sen verirsin; biz ödüllerin tarafı değiliz." | `kosullar-parentapp` |

> **İnci ve Güneş Taşı nedir?**
> **İnci**, çocuğunun senin onayladığın adımlarla kazandığı oyun içi puandır. Yalnız Moyo Oyun'daki eşyalara harcanır. Satın alınamaz, gerçek paraya çevrilemez, başkasına aktarılamaz; hesap silinince kaybolur.
> **Güneş Taşı**, çocuğuna verdiğin ödüllerin sayacıdır. Ödülleri ve değiş tokuş oranlarını (ör. "1 taş = 10 dk ekran") sen belirlersin. Taşın parasal değeri yoktur; ödülün sözünü sen verirsin, biz bu ödüllerin tarafı değiliz.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Oyun | Dükkân ve ödül dükkânı › "i" (çocuğa; sesli okunur) | `kosullar-gameapp` |

> İnciler adanın hazinesidir. Sorumluluklarını tamamlayınca kazanırsın, adadaki eşyalara harcarsın. Gerçek para değildir.
>
> Güneş Taşları ailenin ödülleri içindir. Taşın yetince ödül isteyebilirsin. Kararı ailen verir.

## 9. Acil durum notu

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Davranış kaydı ekranının altı (sabit); ~~Uzmanım ekranının altı~~ (3 Kasım 2026 kullanıcı kararıyla kaldırıldı); Yardım ve iletişim | `kosullar-parentapp` |

> Moyo bir acil yardım hizmeti değildir. Çocuğunun ya da başka birinin güvenliği tehlikedeyse hemen **112**'yi ara. Davranış kaydın uzmanına anında ulaşmayabilir.

*Öneri (avukat dosyası, kullanıcı kararı bekler):* kısa biçim §15 satır 4 ("Moyo acil durum hizmeti değildir. Acil durumda 112'yi ara."), davranış kaydı ekranında ve Yardım'da aynı metin.

**Moyo Mercek:** ekranlarda acil durum notu yok (kullanıcı kararı 3 Kasım 2026: uzman arayüzünde sınır uyarısı tekrarlanmaz). Sınır Uzman Hizmet Sözleşmesi 3.4 ve 3.4-a'da (acil durum ve kriz izleme hizmeti değildir; kayıtlar gecikmeyle ulaşabilir).

## 10. Moyo Oyun — ebeveyn kapısı › Bilgi ekranı

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Oyun | Ebeveyn kapısı geçildikten sonra "Bilgi" | `gizlilik`, `kosullar-gameapp`, `aydinlatma-cocuk`, `kvkk-basvuru` |

> *(En üstte, büyük yazıyla ve sesli okunarak: `aydinlatma-cocuk` Kısım B — çocuğa kısa not.)*
>
> **Ebeveynler için bilgi**
>
> - Moyo Oyun'da reklam, satın alma ve üçüncü taraf izleme aracı yok.
> - Çocuğundan e-posta, telefon, konum, fotoğraf ya da ses almıyoruz. Kamera yalnız Moyo Ebeveyn'deki QR kodu okumak için açılır; görüntü kaydedilmez.
> - Çocuğun yalnız seninle ve ailendeki diğer ebeveynle yazışır.
> - Oyun, Moyo Ebeveyn'de oluşturduğun profile bağlıdır. Profili Moyo Ebeveyn'den düzenlersin.
> - Bu cihazın bağlantısını kapatmak için: Moyo Ebeveyn › Aile › {çocuk_adı} › Cihaz bağlantısını kaldır. Çocuğunun verilerinin silinmesini KVKK başvurusuyla isteyebilir ya da Moyo Ebeveyn'de hesabını silerek aileyle birlikte silebilirsin.
> - Çocuğun adına KVKK başvurusu: Moyo Ebeveyn › Aile › Hesap › Yasal ve gizlilik › KVKK başvurusu.
> - Yardım ve iletişim: **Destek** (Safari'de açılır; yetişkinler için form). Adres: `https://moyoapp.com.tr/destek` (oyun 10 Kasım 2026'dan beri doğrudan bunu açar; adrese çocuk ya da cihaz kimliği eklenmez). Oyunda düğme "Yardım ve iletişim", yanında: "Soru, sorun ya da önerin için destek sayfasına yaz. Sayfa tarayıcıda açılır."
>
> <u>Gizlilik Politikası</u> · <u>Oyun Koşulları</u> · <u>Çocuk ve Veli Aydınlatma Metni</u> · <u>KVKK Başvuru Usulü</u> *(oyundaki düğme adı; belgenin adı Moyo Oyun Koşulları)*
> Destek: `destek@moyoapp.com.tr` · Sürüm {sürüm}
>
> [ Bu cihazın bağlantısını kaldır ] *(öneri: oyunun içinden de; `CANLIYA_ALMA.md` 2.2 "ebeveyn kapısı: bağlama")*

- Bağlantılar tarayıcıda açılır; açılmadan önce: "Bu bağlantı tarayıcıda açılacak."
- Kısım B sesli okunur; ebeveyn bölümü için sesli okuma gerekmez *(Oyun penceresi karar verir)*.

## 11. Moyo Mercek web — çerez bandı

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek web | İlk ziyarette alt bant, içeriği kapatmaz; "Anladım" sonrası bir daha gösterilmez (`40-cerez-politikasi.md` ile aynı metin) | `cerez-clinicapp-web`, `gizlilik` |

> Moyo Mercek web yalnız oturumunu açık tutmak ve seçimlerini hatırlamak için zorunlu tarayıcı depolaması kullanır. Analiz ya da reklam çerezi yok. <u>Çerez Politikası</u> [ Anladım ]

- Yalnız zorunlu kayıtlar varken onay istenmez, bilgilendirme yeterlidir. Analiz aracı eklenirse bant "Kabul et / Reddet" düğmeleri eşit görünürlükte, önceden seçimsiz hâle gelir ve araç onaydan önce yüklenmez.

## 12. Uzman ekranları (`hukuk_notlari.md` E)

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek | Danışan › Notlar, not alanının altı | `sozlesme-uzman` (A2–A3), `aydinlatma-uzman` |

> Notlarını aile görmez. Ebeveyn izin verirse notların, adın gizlenerek çocuğun sonraki uzmanına okunur olarak açılabilir. Nota kimlik bilgisi yazma.

*Öneri (avukat dosyası, kullanıcı kararı bekler):* not ve hedef alanlarında §15 satır 6 ("Çalışma notu. Tanı, ilaç ve kimlik bilgisi yazmayın; …"); 3 Kasım 2026 kararıyla çelişebilir.

Danışan menüsünde gözlem grubu "İzle" 14 Kasım 2026'dan beri **"Takip"** (uygulandı; Moyo Mercek ekranlarında "danışan" kalır).

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek | Danışan › devralınan kayıtlar başlığı | `uzman-gecis-v1` |

> Önceki uzman {n} · {başlangıç_ay} – {bitiş_ay} · ebeveynin izniyle, yalnız okuma

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek | Aileyi davet et › "Çocuğun adı" + yaş grubu alanının altı ve "i" | `sozlesme-uzman` (A9, A13) |

> Yalnız daveti kabul eden ebeveyn görür. Sağlık bilgisi yazma.

"i" ayrıntısı:
> Çocuğun adını ve yaş grubunu yazarsan yalnız daveti kabul eden ebeveyn görür; kontrol edip onaylar, düzeltirse sana bildirim gelir. Mesajda görünmez, davet bitince silinir.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek | Aileyi davet et › ebeveynin e-posta alanının altı | `sozlesme-uzman` (A13) |

> Bu adrese senin adına davet e-postası gider; çocuğun adı ve notun e-postada yer almaz. Aile yanıtlarsa yanıt senin e-posta adresine gelir. Daveti yalnız tanıdığın ve hizmet verdiğin aileye gönder.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek | ~~Belgeni yükle (bayrak `clinician_verification` açıkken)~~ **Özellik kullanılmıyor** (kullanıcı kararı 20 Kasım 2026: belge yükleme sistemden kaldırıldı; `clinician_verifications` tablosu durur, yeniden açılırsa önce metinler; herkese açık metinlerden belge, rozet, e-Devlet ve BACB anlatımı çıktı) | — |

> ~~Belgen yalnız inceleme için okunur, karar verilince silinir; kimlik numaran saklanmaz. Sana "Belge yüklendi: <meslek>", ailelere "Uzman diploma belgesini yükledi" görünür; Moyo bir doğrulama ya da yetki beyanı vermez.~~ (kullanılmıyor)

- Rozet adı 14 Kasım 2026 kararıyla "Belgesi incelendi" → "Belge yükledi" (uygulandı: Moyo Mercek "Belge yüklendi: <meslek>", Moyo Ebeveyn "Uzman diploma belgesini yükledi"). Özellik lansmanda kapalı (bayrak `clinician_verification`). Açık: Moyo Ebeveyn'de rozeti olmayan uzmanda "Belgesi incelenmedi" yazısı duruyor; yeni sözcük kullanıcı kararı bekler (`DURUM.md` 14 Kasım 2026). **20 Kasım 2026:** kullanıcı kararıyla "Belgesi incelenmedi" yazısı kalktı (P.2) ve belge yükleme sistemden kaldırıldı (B.7); rozet hiçbir ekranda gösterilmez.

Moyo Ebeveyn davet ekranı uyarısı ve veli beyanı kutusu (`uzman-paylasim-v1`) ile önceki uzman kayıtları onay metni (`uzman-gecis-v1`) `hukuk_notlari.md` B ve E'deki metinlerdir; burada tekrar edilmez. *Öneri (kullanıcı kararı bekler):* paylaşım onayına §15 satır 3 ("Paylaşılanlar uygulamada bıraktığın kayıtlardır. …").

## 13. "Tanı değildir" notu

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Haftalık özet, gösterge ve ilerleme ekranlarının altı | `kosullar-parentapp` |

> Bu sayılar çocuğunun uygulamadaki rutin ve adımlarını özetler; tanı, zekâ ya da dikkat puanı değildir.

**Ebeveyn dersleri (Gelişim › Ben; öneri 5 Kasım 2026, `sozlesme/akislar.md` 22; yalnız bayrak `parent_training` açıkken, lansmanda kapalı, kullanıcı kararı 23 Kasım 2026):** ders sayfasının ve "Yakında" kartının altında:

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Gelişim › Ben › ders sayfası, Yakında kartı | `kosullar-parentapp` |

> Bu dersler bilgi amaçlıdır; tanı ya da tedavi yerine geçmez.

Uzmanın önerdiği derste ek satır: "Uzmanın bu dersteki uygulama günlerini görür." Uzman paylaşımı ekranındaki "Paylaşılır" listesine (Moyo Ebeveyn ⓘ, rıza metni `uzman-paylasim-v1` "takip planı uygulama kayıtların" kapsamı) satır: "Uzmanının önerdiği derslerde uyguladığın günler" ve "Paylaşılmaz" listesine: "Kendi seçtiğin dersler". Sürümlü rıza metni değişmedi (`hukuk_notlari.md` 26). Ek satır ve bu iki liste satırı da yalnız bayrak açıkken gösterilir.

**Kaynak kütüphanesi (Moyo Ebeveyn ve Moyo Mercek; kullanıcı kararı 14 Kasım 2026, `hukuk_notlari.md` M.5; iki uygulamada uygulandı; yalnız bayrak `parent_training` açıkken, lansmanda kapalı):** kütüphane ekranının altında bir kez, göze batmadan (her eğitimde değil):

> Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz.

**Moyo Mercek ekranları:** göstergeler ve hedef grafiklerinin altında sınır metni yok (kullanıcı kararı 3 Kasım 2026; sözleşme 3.3 ve 3.4-a). Aşağıdaki dışa aktarma alt satırı kalır.

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Mercek | Dışa aktarılan belgelerin (rapor, ilerleme notu, bütün CSV'ler) alt satırı; ekranlarda yok | `sozlesme-uzman` |

> Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir.

- **Uygulandı** (Moyo Mercek, 14 Kasım 2026; `EXPORT_FOOTER`; CSV'de veriden bir boş satırla ayrılır). Eski alt bilgi ("… tek başına klinik karar için kullanılmaz") ve rapordaki "Sınırlar" bloğu kalktı (`hukuk_notlari.md` M.7).

## 14. İzin açıklamaları

iOS sistem penceresinde görünen amaç metinleri (`Info.plist`) ve sistem penceresinden önce gösterilen kısa ön açıklamalar.

| Uygulama | İzin (`Info.plist` anahtarı) | Ne zaman sorulur | Metin |
|---|---|---|---|
| Moyo Oyun | Kamera (`NSCameraUsageDescription`) | Giriş ekranında "QR okut"a ilk basıldığında, ebeveyn kapısından sonra | Moyo Ebeveyn'de gösterilen QR kodu okumak için kamerayı kullanırız. Görüntü kaydedilmez, gönderilmez. |
| Moyo Oyun | Bildirim (sistem; amaç metni yok) | İlk gereken anda *(öneri: ebeveyn kapısının arkasında)* | Ön açıklama: "Ailen sana yazınca ya da maceranı onaylayınca haber verelim mi?" [İzin ver] [Şimdi değil] |
| Moyo Ebeveyn | Mikrofon (`NSMicrophoneUsageDescription`) | Sesli mesaj ya da davranış kaydındaki ses kaydına ilk basıldığında | Sesli mesaj ve davranış kaydındaki ses kaydı için mikrofonu yalnız sen kayda bastığında kullanırız. |
| Moyo Ebeveyn | Fotoğraflar (`NSPhotoLibraryUsageDescription`) | Mesaja ilk fotoğraf eklenirken | Çocuğuna mesajla göndermek için seçtiğin fotoğrafa erişiriz. |
| Moyo Ebeveyn | Kamera (`NSCameraUsageDescription`) — *yalnız mesajda fotoğraf çekme varsa* | Mesajda "Fotoğraf çek"e ilk basıldığında | Çocuğuna mesajla göndereceğin fotoğrafı çekmek için kamerayı kullanırız. |
| Moyo Ebeveyn | Bildirim | İlk rutin ya da adım oluşturulunca *(öneri)* | Ön açıklama: "Çocuğun bir adımı yaptığında ya da sana yazdığında haber verelim mi?" [İzin ver] [Şimdi değil] |
| Moyo Mercek | Bildirim | İlk aile daveti gönderildikten sonra (bayrak `lifecycle_nudges` açıkken; `akislar.md` 25 aşama 1; önceki öneri: ilk aile bağlanınca) | Ön açıklama: "Bir aile seninle çocuk paylaştığında, öneri kararında ya da yeni davranış kaydında haber verelim mi?" [İzin ver] [Şimdi değil] |
| Moyo Mercek | ~~Fotoğraflar (`NSPhotoLibraryUsageDescription`) — yalnız belge görsel olarak seçilebiliyorsa~~ | — | Belge yükleme kullanılmıyor (kullanıcı kararı 20 Kasım 2026); izin istenmez. |

- İzin reddedilirse özellik kibarca kapanır; uygulamanın geri kalanı çalışır. Ayarlara yönlendiren metin: "İzni iPhone Ayarlar › {uygulama} bölümünden açabilirsin."

### 14.1 Moyo Ebeveyn — bildirim ayarları ve tanıtım izni (kullanıcı kararı 20 Kasım 2026, 5a ve D.16; öneri metin, Moyo penceresi uygular)

Kural: Moyo Ebeveyn'de bildirimler günde bir taneyi geçmemeye çalışır. Çocuğun oyunda işaretlediği adım bildirimlerini ebeveyn açıp kapatır; günün bütün adımları tamamlanınca tek bir "bugünün adımları tamamlandı" bildirimi gidebilir. Tanıtım ve kampanya bildirimi ya da e-postası yalnız ayrı izinle; izin ayrı anahtardır, **kapalı başlar**, her an kapatılır (Kullanım Koşulları 16.10; Moyo Mercek için Uzman Hizmet Sözleşmesi 17). Bildirim metnine sağlık bilgisi ve davranış ayrıntısı konmaz. Sunucu tarafı bildirim tercihleri işinde (`sozlesme/akislar.md`, başka pencere).

| Uygulama | Ekran | Bağlı belge |
|---|---|---|
| Moyo Ebeveyn | Aile › Ayarlar › Bildirimler | `kosullar-parentapp` (16.10), `aydinlatma-ebeveyn` (4 satır 14) |

> **Bildirimler**
> Moyo sana günde birden fazla bildirim göndermemeye çalışır.
>
> **Adım bildirimleri** [anahtar] — {çocuk_adı} oyunda bir adımı işaretleyince haber ver.
> **Günün özeti** [anahtar] — Bugünün bütün adımları tamamlanınca tek bildirim: "Bugünün adımları tamamlandı."
>
> **Kampanya ve yenilikler** [anahtar, kapalı başlar] — Tanıtım ve kampanya bildirimleri ile e-postaları. İstediğin an kapatabilirsin.
>
> <small>Hesap, abonelik, güvenlik ve uzman paylaşımıyla ilgili bildirimler bu ayarlara bağlı değildir. <u>Kullanım Koşulları</u></small>

- "Kampanya ve yenilikler" açılınca izin (zaman ve metin sürümüyle) kaydedilir ve İYS'ye bildirilir; kapatınca da (6563 s. Kanun; `45-pazarlama-kurallari.md` §4).
- Moyo Mercek'te aynı yapıda tek anahtar "Kampanya ve yenilikler" (kapalı başlar), Ayarlar › Bildirimler.
- Telefonla (SMS) doğrulama bugün yok (bayrak `parent_sms_verify` kapalı); açılırsa önce aydınlatma ve alt işleyen listesi güncellenir.

## 15. Avukat dosyası kısa metin önerileri (20 Kasım 2026; öneri, kullanıcı kararı bekler)

Kaynak: avukat dosyası ("takip platformu" konumu; `sozlesme/hukuk_notlari.md` M). Satır 7 dışında hiçbiri uygulamada değildir; uygulamaya alınmaları kullanıcı kararıyla. Uygulanan satır ilgili bölümdeki metnin yerine geçer ya da yanına eklenir ve burada "uygulandı" olur.

| # | Nerede (bağlı bölüm) | Metin | Neden | Durum |
|---|---|---|---|---|
| 1 | Moyo Ebeveyn kayıt onayı: tek satır, kutuyla (§1.1) | "Moyo bir takip aracıdır; sağlık hizmeti, tanı ya da acil durum hizmeti değildir. Koşulları okudum ve kabul ediyorum." | Koruyucu maddelerin açıkça onaylanması | Öneri, kullanıcı kararı bekler |
| 2 | Moyo Ebeveyn serbest metin alanları: not, davranış kaydı, onay notu (alan ipucu); ebeveyn eğitimi yanıtı yalnız bayrak `parent_training` açıkken | "Gözlemini yaz. Tanı, ilaç ya da sağlık bilgisi yazma." | Özel nitelikli veri girişini kaynağında azaltır; bugün yok | Öneri, kullanıcı kararı bekler |
| 3 | Uzmanla paylaşım onayı (Moyo Ebeveyn; §12 sonu, `uzman-paylasim-v1` ekranı) | "Paylaşılanlar uygulamada bıraktığın kayıtlardır. Paylaşımı istediğin an kapatabilirsin." | Kayıtların kullanıcıya ait olduğunu, kararın ebeveynde olduğunu gösterir | Öneri, kullanıcı kararı bekler |
| 4 | Davranış kaydı ekranı ve Yardım (Moyo Ebeveyn; §9) | "Moyo acil durum hizmeti değildir. Acil durumda 112'yi ara." | Bugün yalnız bir ekranda; Yardım'da da durmalı | Öneri, kullanıcı kararı bekler (§9'daki uzun metnin kısa biçimi) |
| 5 | Moyo Mercek kayıt onayı (§1.2) | "Moyo Mercek bir takip panelidir. Mesleki değerlendirme ve kayıt tutma yükümlülüğü sizdedir." | Rol ayrımının uzmanca onaylanması | Öneri, kullanıcı kararı bekler; 3 Kasım 2026 kararıyla çelişebilir |
| 6 | Moyo Mercek not ve hedef alanları (§12) | "Çalışma notu. Tanı, ilaç ve kimlik bilgisi yazmayın; resmî kaydınızı kendi sisteminizde tutun." | Bugün yalnız "kimlik bilgisi yazma" | Öneri, kullanıcı kararı bekler; 3 Kasım 2026 kararıyla çelişebilir |
| 7 | Dışa aktarılan rapor, ilerleme notu ve CSV'nin alt satırı (Moyo Mercek; §13) | "Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir." | — | **Uygulandı** (Moyo Mercek, 14 Kasım 2026) |
| 8 | Mağaza açıklamasının ve tanıtım sayfasının son satırı (Marketing; `45-pazarlama-kurallari.md` 1.7) | "Moyo bir takip aracıdır; sağlık hizmeti sunmaz, tanı koymaz." | Dış dilin konumla aynı olması (Marketing §7.1) | Öneri, kullanıcı kararı bekler |

- **3 Kasım 2026 kararı:** uzman arayüzündeki sınır uyarıları kaldırıldı (karşılıkları Uzman Hizmet Sözleşmesi 3.1–3.4). 5 ve 6 bu kararla çelişebilir; hangisinin uygulanacağı kullanıcı kararıdır.
- **Hitap:** 5 ve 6 avukat dosyasında "siz" diliyle; Moyo Mercek uygulaması "sen" der (§0). Uygulanırsa: "… yükümlülüğü sende.", "… yazma; resmî kaydını kendi sisteminde tut."
- **1:** bugünkü kayıt satırı (§1.1 "Güncel") tek kutu; öneri aynı kutunun metnini uzatır, yeni kutu açmaz.
- 2 ve 6'daki "tanı, ilaç" uyarısı çekirdek madde 5 (içerik sorumluluğu: serbest metin alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazılmaması istenir) ile aynı yöndedir; 2 bugün §4'teki KVKK açıklama alanı yer tutucusuyla da uyumludur.

## Avukata notlar

1. **Kayıt ekranında aydınlatma (karar önerisi uygulandı 27 Ekim 2026: kutusuz satır + "gösterildi" kaydı; avukat teyit etsin):** "Aydınlatma Metni'ni okudum" kutusu onay (rıza) gibi algılanabilir. Kutu yerine yalnız bağlantı + "gösterildi" kaydı mı yeterli, yoksa kutu ispat için mi tutulmalı? `tools/legal_seed.py` aydınlatmaları "onay ister" (okundu) olarak yüklüyor; `22-uzman-hizmet-sozlesmesi.md` Ek-3 ise Moyo Mercek'te aydınlatmayı kutusuz bir satır olarak öneriyor. İkisinden biri seçilip iki belge eşitlenmeli.
2. **Abonelik ekranı (6):** Apple'ın yenileme ve iptal bilgisi kendi cümlelerimizle yazıldı; 6502 s. Kanun ve Abonelik Sözleşmeleri Yönetmeliği açısından ekranda ayrıca bulunması gereken bir bilgi (ör. cayma hakkı istisnası, satıcının Apple olduğu) var mı? Deneme sunucu tarafında, kartsız ve ücretsiz bitiyor; ileride App Store "ücretsiz deneme" teklifine geçilirse 6–7. bölüm metinleri değişmeli.
3. **Moyo Oyun koşulları güncellenince oyun kilitlensin mi (2):** Veli yeni sürümü Moyo Ebeveyn'de onaylayana kadar çocuğun oyunu kilitlenmiyor (öneri: çocuğu cezalandırmamak). Bu, eski sürümle kullanımın sürmesi demek; hukuken kabul edilebilir mi?
4. **Hesap silmede kalanlar (5):** "Ödeme kayıtları, ekip işlem kaydı ve deneme e-posta özeti kalır" cümlesi `42-saklama-imha-politikasi.md` süreleriyle birlikte onaylanmalı.
5. **Ürün kararı / teyit gerekenler (yazılım):** Ekip sahibi silinince "kliniğe ait kayıtlar klinikte kalır" cümlesi sunucu davranışıyla teyit edilmeli. `kvkk_requests`'te çocuk alanı yok; "Kimin için?" seçimi bugün açıklamaya yazılıyor (ayrı sütun önerisi). Moyo Ebeveyn'de tek çocuk profilini silme ekranı yok (`README.md` sorun 5); 5.3 ve 10. bölüm buna göre yazıldı.
6. **Hesap silmede uzman kayıtları (5.1):** Ebeveyne "uzmanın bu çocuklar için tuttuğu notlar da silinir" deniyor (bugünkü sistem). Kullanıcı kararı (20 Kasım 2026, B.8): sorun değil; uzmana kayıtta en baştan söylenir (§1.2).
7. **Karşılama anketi zorunlu oldu (Moyo Mercek, 28 Ekim 2026):** "Şimdilik geç" kaldırıldı. Aydınlatma metni ankete "isteğe bağlı" diyor ve dayanağı meşru menfaat (ürün geliştirme). Ürün araştırması için zorunlu veri toplamak ölçülülük ilkesiyle (KVKK md. 4) çelişebilir. Öneri: ekran kalsın ama her soruda "söylemek istemiyorum / diğer" seçeneği olsun (Joon'daki gibi, `03` J2); yoksa aydınlatma "zorunlu" olarak düzeltilip amacı (ör. meslek → şablon önerisi) somut yazılmalı.
8. **Kısa metin önerileri (§15):** Moyo Mercek'teki iki satır (5 kayıt onayı, 6 not alanı ipucu) 3 Kasım 2026 kullanıcı kararıyla çelişebilir; kayıt onayındaki tek satırın ve alan ipucunun "sınır uyarısı" sayılıp sayılmayacağı kullanıcıya. 1'deki uzun onay satırı koruyucu maddelerin onaylandığını ispat için yeterli mi (kutu tek, metin uzuyor)?
9. **Klinik silinince ailenin yanıtları (5.2) — karar verildi (kullanıcı, 20 Kasım 2026: 3A):** Paylaşım kaydı ya da klinik silinince (uzman hesabını siler; tek kişilik klinik ya da bireysel alan) ailenin kendi girdiği ebeveyn eğitimi yanıtları, uygulama kayıtları, yapılacak işaretleri ve davranış olayları **silinmez**: aileye açılmış eğitimin içeriğiyle (adı, modüller, uygulama görevleri, yapılacaklar) birlikte ailede salt okunur kopya olarak kalır, uzmanın ve kliniğin erişimi kapanır; taslak eğitim, uzmanın gözlem verisi, ustalık ölçütü ve hedef davranış tanımı silinir (olayda yalnız davranışın adı kalır). Aile hesabını ya da çocuğu silerse hepsi silinir. Sunucu: `supabase/migrations/20261120200000_family_keeps_records.sql` (öneri). 5.2 metni buna göre yazıldı. Avukata kalan: (a) uzmanın yazdığı eğitim içeriğinin (başlık, görev ve yapılacak metinleri) uzman hesabı silindikten sonra ailede kalması Uzman Hizmet Sözleşmesi 4.5 ve 9.6'ya eklenmeli mi; (b) paylaşım geri alınınca (satır silinmez) aile bugün bu kayıtları görmüyor, silinince görüyor: geri almada da aileye salt okunur kopya açılsın mı (ürün kararı).
10. **Bildirim ayarları ve tanıtım izni (§14.1; kullanıcı kararı 20 Kasım 2026):** "günde bir taneyi geçmemeye çalışır" bir hedef olarak yazıldı (taahhüt değil); tanıtım izni ayrı anahtar ve kapalı başlar. Uygulama içi tanıtım bildiriminin ticari elektronik ileti sayılması ve İYS kaydı gerekip gerekmediği avukata (`hukuk_notlari.md` N).
11. **Kayıtta aile bağı bilgisi (§1.2; B.8):** kayıt satırının üstündeki tek satır uzmanın "önceden bilgilendirildiğini" ispat için yeterli mi; onay kaydına ayrıca yazılmalı mı (bugün yalnız sözleşme sürümü kaydediliyor)?
12. 23 Kasım 2026: ebeveyn eğitimi ve kısa ebeveyn dersleri lansmanda kapalı; metinden çıkarıldı, açılırken `hukuk/ek-ebeveyn-egitimi.md`'den geri eklenir (yeni sürüm). Not 9 (klinik silinince ailede kalan eğitim yanıtları) o zaman yeniden geçerli olur; bugün §5.2 yalnız davranış olaylarını sayar.
