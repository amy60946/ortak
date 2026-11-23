# Ek: ebeveyn eğitimi ve kısa ebeveyn dersleri (lansmanda kapalı; geri ekleme kaynağı)

> İç belge, yayımlanmaz (`tools/legal_seed.py` yüklemez). 23 Kasım 2026.

## Neden var

Kullanıcı kararıyla (23 Kasım 2026) **ebeveyn eğitimi** lansmanda bütün platformlarda kapalıdır ve kodda uzaktan ayar bayrağı `parent_training` arkasında, ileride açılmak üzere durur. Kapsam iki özelliktir:

- **Uzmanın atadığı ebeveyn eğitimi** (Moyo Mercek › Ebeveyn Eğitimi; kaynak kütüphanesindeki modüller, uygulama görevleri, yapılacaklar, gözlem verisi, ustalık; ebeveynin Moyo'daki yanıtları; `sozlesme/akislar.md` 23).
- **Moyo'nun kısa ebeveyn dersleri** (Gelişim › Ben, uzmanın önerdiği ders ve uygulama günleri, derslerden gelen Güneş Taşı; `akislar.md` 22).

Sunucu tarafı: `supabase/proposed/20261123210000_parent_training_off.sql`; akış `akislar.md` 27.4; hukuk notu `sozlesme/hukuk_notlari.md` S.7. Öteki özellikler (rutin ve adım, davranış kaydı, hedef davranış ve olay bildirimi, randevu ve seans, raporu aileye gönderme; ayrı bayraklı takip planı) değişmedi.

Yayımlanacak metinler lansmanda yalnız açılan hizmeti anlatsın diye eğitim ve ders anlatımları taslaklardan çıkarıldı ya da cümleden ayıklandı; madde numaraları ve atıflar korundu. Bu dosya, her değişen yerin **özgün metnini** (ve yerini bulmak için bugünkü hâlini) tutar.

## Özellik açılırken

1. Aşağıdaki "Özgün metin"leri bugünkü metnin yerine koy (o arada metin başka nedenle değiştiyse iki değişikliği birleştir; olgulara `00-olgular.md` bakılır).
2. Metinler o tarihte yayımlanmışsa sürümü artır (`README.md` "Nasıl çalışır" 5) ve seed'i yeniden üret (`python3 tools/legal_seed.py`); onay isteyen metinlerde kullanıcılar yeniden onaylar.
3. Başlık künyelerindeki "23 Kasım 2026" satırlarını ve "Avukata notlar"daki 23 Kasım notlarını güncelle; avukatın eğitimle ilgili eski soruları (`20` not 10, `22` not 9 ve 15, `23` not 4 ve 18, `10` not 12 ve 17, `50` not 9) yeniden geçerli olur.
4. `00-olgular.md`'deki "lansmanda kapalı" işaretlerini kaldır; `README.md` fonksiyon haritasındaki satırı düzelt.
5. `50-uygulama-ici-metinler.md`'de bayrak işaretleri (§13, §15 satır 2) kalkar; hesap silme metinlerine (§5.1, §5.2) eğitim ve ders sözleri geri girer (uygulamalar da aynı anda: Moyo Mercek `accountDelete.ts`, Moyo hesap silme ekranı).

## Değiştirilmeyenler

- **`30-acik-riza-metinleri.md`** (sürümlü rıza `uzman-paylasim-v1`; değiştirmek yeni sürüm ve var olan paylaşımlar için yeniden rıza ister): §1.1 "Ne paylaşılır" (ebeveyn eğitimindeki yanıtlar; uzmanın önerdiği derslerde uygulama günleri), §1.1 "Ne paylaşılmaz" (kendi seçtiğin dersler), §1.1 "Ne kadar" (ebeveyn eğitimi kapanır), §1.2 rıza cümlesi ("kendi seçtiğim dersler paylaşılmaz"), §1.5 Geri alma (ebeveyn eğitimi kapanır), Avukata not 4. Özellik kapalıyken bu veri oluşmaz; avukata soru `hukuk_notlari.md` S.7.
- İç belgeler (yayımlanmaz; veri ve tablolar durduğu için olduğu gibi): `42-saklama-imha-politikasi.md` satır 9 (`parent_training_*`), `43-veri-ihlali-proseduru.md` "Yüksek" satırı, `46-veri-envanteri.md` K3, K7 ve tablo eki (`parent_lesson*`, `parent_training*`).
- `40-cerez-politikasi.md` §3: Moyo Mercek web depolama listesindeki kaynak kütüphanesi favorileri anahtarı (`clinic.library.fav.v1.<hesap kimliği>`); daha önce kullanmış tarayıcılarda durabileceği için listede kaldı.

---

## `20-kullanim-kosullari-parentapp.md`

### 20.1 · 2. Tanımlar › "Ebeveyn eğitimi"

Özgün metin:

```text
- **Ebeveyn eğitimi:** uzmanınızın Moyo'nun içerik kütüphanesinden size atadığı modüller, uygulama görevleri ve yapılacaklar.
```

Bugün: satır çıkarıldı.

### 20.2 · 3. Hizmetin ne olduğu, ne olmadığı › 3.1

Özgün metin:

```text
3.1. Moyo Ebeveyn ile rutin ve adım oluşturur, çocuğunuzun "Yaptım"larını onaylar, ödülleri yönetir, çocuğunuzla mesajlaşır, davranış kaydı tutarsınız. İsterseniz kayıtlarınızı bir uzmanla paylaşır, uzmanınızın atadığı ebeveyn eğitimini kullanır ve tanımladığı davranışlar için olay bildirirsiniz.
```

Bugünkü metin:

```text
3.1. Moyo Ebeveyn ile rutin ve adım oluşturur, çocuğunuzun "Yaptım"larını onaylar, ödülleri yönetir, çocuğunuzla mesajlaşır, davranış kaydı tutarsınız. İsterseniz kayıtlarınızı bir uzmanla paylaşır ve uzmanınızın tanımladığı davranışlar için olay bildirirsiniz.
```

### 20.3 · 3. Hizmetin ne olduğu, ne olmadığı › 3.3

Özgün metin:

```text
3.3. **Kayıtların niteliği.** Uygulamadaki kayıtlar, kullanıcıların kendi girdiği takip kayıtlarıdır. Moyo bu kayıtları saklar ve gösterir; bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Davranış kaydındaki şiddet derecesi, olay bildirimindeki çocuğun tepkisi ve takip planındaki zorluk bildirimi sizin gözleminizdir. Ebeveyn eğitimindeki test sonucu sizin bilgi yoklamanızdır, çocuğa ait bir puan değildir.
```

Bugünkü metin:

```text
3.3. **Kayıtların niteliği.** Uygulamadaki kayıtlar, kullanıcıların kendi girdiği takip kayıtlarıdır. Moyo bu kayıtları saklar ve gösterir; bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Davranış kaydındaki şiddet derecesi, olay bildirimindeki çocuğun tepkisi ve takip planındaki zorluk bildirimi sizin gözleminizdir.
```

### 20.4 · 3. Hizmetin ne olduğu, ne olmadığı › 3.4

Özgün metin:

```text
3.4. **Moyo'nun içeriği.** Ebeveyn eğitimi kütüphanesi, kısa ebeveyn dersleri, hazır rutinler, öneriler ve ipuçları Moyo'nun hazırladığı içeriktir. Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz. Bu içeriğe dayanılarak verilen kararlardan ve bunların sonuçlarından, yasanın izin verdiği en geniş ölçüde, Moyo sorumlu değildir; kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. Uzmanınızın kendi yazdığı uygulama görevleri, yapılacaklar ve önerilerin içeriği uzmana aittir.
```

Bugünkü metin:

```text
3.4. **Moyo'nun içeriği.** Hazır rutinler, öneriler ve ipuçları Moyo'nun hazırladığı içeriktir. Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz. Bu içeriğe dayanılarak verilen kararlardan ve bunların sonuçlarından, yasanın izin verdiği en geniş ölçüde, Moyo sorumlu değildir; kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. Uzmanınızın kendi yazdığı önerilerin içeriği uzmana aittir.
```

### 20.5 · 5. Veli beyanı ve çocuk hesabından sorumluluk › 5.6

Özgün metin:

```text
5.6. **Başkalarının verisi.** Adım açıklamalarına, notlara, mesajlara, davranış kayıtlarına, olay bildirimlerine ve eğitim yanıtlarına çocuğunuz dışındaki kişilerin (öğretmen, akraba, başka çocuk) kişisel bilgilerini gereğinden fazla yazmayın. Ses kaydı alırken başkalarının sesini onların bilgisi olmadan kaydetmeyin.
```

Bugünkü metin:

```text
5.6. **Başkalarının verisi.** Adım açıklamalarına, notlara, mesajlara, davranış kayıtlarına ve olay bildirimlerine çocuğunuz dışındaki kişilerin (öğretmen, akraba, başka çocuk) kişisel bilgilerini gereğinden fazla yazmayın. Ses kaydı alırken başkalarının sesini onların bilgisi olmadan kaydetmeyin.
```

### 20.6 · 6. Uzmanla paylaşım › 6.6

Özgün metin:

```text
6.6. **Uzmanın önerileri.** Uzman size rutin ve adım önerebilir, ebeveyn eğitimi atayabilir, hedef davranış tanımlayabilir, randevu açabilir ve takip planı gönderebilir. Bunları kabul etmek, değiştirmek, uygulamak ya da reddetmek size kalmıştır.
```

Bugünkü metin:

```text
6.6. **Uzmanın önerileri.** Uzman size rutin ve adım önerebilir, hedef davranış tanımlayabilir, randevu açabilir ve takip planı gönderebilir. Bunları kabul etmek, değiştirmek, uygulamak ya da reddetmek size kalmıştır.
```

### 20.7 · 9. Coin, Güneş Taşı ve ödüller › 9.2

Özgün metin:

```text
9.2. **Güneş Taşı para değildir.** Güneş Taşı, onayladığınız adımlarla kazanılır ve çocuğunuza vereceğiniz ödüllerin sayacıdır. Para ya da ödeme aracı değildir; satın alınamaz, paraya çevrilemez. Kendi adımlarınızla ve uyguladığınız derslerle kazandığınız Güneş Taşlarını yalnız çocuğunuza oyunda hediye göndermek için kullanırsınız.
```

Bugünkü metin:

```text
9.2. **Güneş Taşı para değildir.** Güneş Taşı, onayladığınız adımlarla kazanılır ve çocuğunuza vereceğiniz ödüllerin sayacıdır. Para ya da ödeme aracı değildir; satın alınamaz, paraya çevrilemez. Kendi adımlarınızla kazandığınız Güneş Taşlarını yalnız çocuğunuza oyunda hediye göndermek için kullanırsınız.
```

### 20.8 · 11. İçerik ve mesajlar › 11.2

Özgün metin:

```text
11.2. **İçerik sorumluluğu.** Girilen kaydın doğruluğu ve içeriği girene aittir. Serbest metin alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazılmaması istenir; yazılan bilginin sorumluluğu yazandadır. Gönderdiğiniz yazı, fotoğraf, ses kaydı, adım açıklaması, not, davranış kaydı, olay bildirimi ve eğitim yanıtı çocuğunuza uygun olmalı ve başkalarının haklarını ihlal etmemelidir.
```

Bugünkü metin:

```text
11.2. **İçerik sorumluluğu.** Girilen kaydın doğruluğu ve içeriği girene aittir. Serbest metin alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazılmaması istenir; yazılan bilginin sorumluluğu yazandadır. Gönderdiğiniz yazı, fotoğraf, ses kaydı, adım açıklaması, not, davranış kaydı ve olay bildirimi çocuğunuza uygun olmalı ve başkalarının haklarını ihlal etmemelidir.
```

### 22.1 · Kısaca › "Moyo bir takip aracıdır"

Özgün metin:

```text
- **Moyo bir takip aracıdır:** Moyo, aile üyelerinin günlük rutin ve sorumlulukları kendi tercihleriyle kaydetmesini ve bu kayıtları görmesini sağlayan dijital bir takip aracıdır. Moyo Mercek, ebeveynin izniyle paylaştığı çocuğun ev rutinini takip etmenize; not, hedef, rutin ve adım önerisi, ebeveyn eğitimi ve takip planı hazırlamanıza yarar.
```

Bugünkü metin:

```text
- **Moyo bir takip aracıdır:** Moyo, aile üyelerinin günlük rutin ve sorumlulukları kendi tercihleriyle kaydetmesini ve bu kayıtları görmesini sağlayan dijital bir takip aracıdır. Moyo Mercek, ebeveynin izniyle paylaştığı çocuğun ev rutinini takip etmenize; not, hedef, rutin ve adım önerisi ile takip planı hazırlamanıza yarar.
```

### 22.2 · 2. Tanımlar › tablo satırı "Aile verisi"

Özgün metin:

```text
| Aile verisi | Ebeveynin ve çocuğun Moyo Ebeveyn ve Moyo Oyun'da oluşturduğu veriler (rutinler ve adımlar, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, davranış kayıtları ve ses kayıtları, davranış olayları, ebeveyn eğitimi yanıtları gibi) |
```

Bugünkü metin:

```text
| Aile verisi | Ebeveynin ve çocuğun Moyo Ebeveyn ve Moyo Oyun'da oluşturduğu veriler (rutinler ve adımlar, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, davranış kayıtları ve ses kayıtları, davranış olayları gibi) |
```

### 22.3 · 2. Tanımlar › tablo satırı "Uzman kayıtları"

Özgün metin:

```text
| Uzman kayıtları | Uzmanın Moyo Mercek'e bir aile için girdiği notlar, hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (aile programı), ebeveyn eğitimleri, hedef davranışlar, seans randevuları ve seans kayıtları, etiketler ve davet bilgileri |
```

Bugünkü metin:

```text
| Uzman kayıtları | Uzmanın Moyo Mercek'e bir aile için girdiği notlar, hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (aile programı), hedef davranışlar, seans randevuları ve seans kayıtları, etiketler ve davet bilgileri |
```

### 22.4 · 2. Tanımlar › tablo satırı "Kaynak kütüphanesi"

Özgün metin:

```text
| Kaynak kütüphanesi | Platformun sunduğu ebeveyn eğitimi içerikleri (okuma, çoktan seçmeli ve açık uçlu modüller) |
```

Bugün: satır çıkarıldı.

### 22.5 · 3. Hizmetin tanımı ve niteliği › 3.1-c

Özgün metin:

```text
   - c) aileye rutin ve adım önerisi, ebeveyn eğitimi, hedef davranış ve takip planı göndermesine,
```

Bugünkü metin:

```text
   - c) aileye rutin ve adım önerisi, hedef davranış ve takip planı göndermesine,
```

### 22.6 · 3. Hizmetin tanımı ve niteliği › 3.3

Özgün metin:

```text
3.3. **Göstergeler, içerik ve sonuç.** Moyo Mercek'teki oranlar, grafikler, hedef değerlendirmeleri ve raporlar, ailenin uygulamada bıraktığı kayıtların özetidir; zekâ ya da dikkat puanı da değildir ve mesleki değerlendirmenin yerini tutmaz. Moyo'nun içeriği (kaynak kütüphanesindeki ebeveyn eğitimi içerikleri, hazır rutinler ve takip planı şablonları) genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz. Şablonlar ve içerikler uzmanın kendi programını hızlı kurması için sunulur; bir şablonun ya da içeriğin aileye uygun olup olmadığına uzman karar verir. Bu içeriğe dayanılarak verilen kararlardan ve bunların sonuçlarından, yasanın izin verdiği en geniş ölçüde, Moyo sorumlu değildir; kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. Moyo belirli bir sonuç, gelişme ya da davranış değişikliği taahhüt etmez.
```

Bugünkü metin:

```text
3.3. **Göstergeler, içerik ve sonuç.** Moyo Mercek'teki oranlar, grafikler, hedef değerlendirmeleri ve raporlar, ailenin uygulamada bıraktığı kayıtların özetidir; zekâ ya da dikkat puanı da değildir ve mesleki değerlendirmenin yerini tutmaz. Moyo'nun içeriği (hazır rutinler ve takip planı şablonları) genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz. Şablonlar ve içerikler uzmanın kendi programını hızlı kurması için sunulur; bir şablonun ya da içeriğin aileye uygun olup olmadığına uzman karar verir. Bu içeriğe dayanılarak verilen kararlardan ve bunların sonuçlarından, yasanın izin verdiği en geniş ölçüde, Moyo sorumlu değildir; kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. Moyo belirli bir sonuç, gelişme ya da davranış değişikliği taahhüt etmez.
```

### 22.7 · 3. Hizmetin tanımı ve niteliği › 3.4-a

Özgün metin:

```text
3.4-a. **Sınırların bildirimi.** 3.2–3.4'teki sınırlar Moyo Mercek ekranlarında ayrıca uyarı olarak tekrarlanmaz; Uzman bu sözleşmeyi kabul ederek bunları bildiğini kabul eder. Yalnız kaynak kütüphanesi ekranının altında bir kez "Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz." yazar. Uzmanın dışa aktardığı belgelerin (rapor, ilerleme notu, CSV) altında tek satır yer alır: "Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir." (Ek-3).
```

Bugünkü metin:

```text
3.4-a. **Sınırların bildirimi.** 3.2–3.4'teki sınırlar Moyo Mercek ekranlarında ayrıca uyarı olarak tekrarlanmaz; Uzman bu sözleşmeyi kabul ederek bunları bildiğini kabul eder. Uzmanın dışa aktardığı belgelerin (rapor, ilerleme notu, CSV) altında tek satır yer alır: "Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir." (Ek-3).
```

### 22.8 · 3. Hizmetin tanımı ve niteliği › 3.5

Özgün metin:

```text
3.5. **Uzaktan sağlık hizmeti aracı değildir.** Moyo Mercek'te uzman ile aile arasında görüntülü ya da sesli görüşme ve serbest mesajlaşma özelliği yoktur. Uzman aileye yalnız rutin ve adım önerisi (kısa not dahil), ebeveyn eğitimi, hedef davranış, takip planı, randevu bilgisi ve hatırlatma gönderebilir; ebeveyn yalnız bunlara bağlı kısa yanıt ve not bırakabilir.
```

Bugünkü metin:

```text
3.5. **Uzaktan sağlık hizmeti aracı değildir.** Moyo Mercek'te uzman ile aile arasında görüntülü ya da sesli görüşme ve serbest mesajlaşma özelliği yoktur. Uzman aileye yalnız rutin ve adım önerisi (kısa not dahil), hedef davranış, takip planı, randevu bilgisi ve hatırlatma gönderebilir; ebeveyn yalnız bunlara bağlı kısa yanıt ve not bırakabilir.
```

### 22.9 · 4. Hesap, klinik ve ekip › 4.5

Özgün metin:

```text
4.5. **Hesabın silinmesi ve ekip.** Uzman hesabını sildiğinde: tek kişilik klinik bütün uzman kayıtları, paylaşımları, davetleri ve üyelik kayıtlarıyla birlikte silinir; ekipte başka uzman varsa klinik ve kayıtları kalır, hesabını silen klinik sahibiyse sahiplik kliniğin en eski üyesine geçer, ekip üyesiyse sorumlusu olduğu aileler klinik sahibine kalır. Klinik silindiğinde ailelerin Moyo Ebeveyn'deki kendi kayıtları silinmez: ailenin girdiği ebeveyn eğitimi yanıtları ve davranış olayları, aileye açılmış eğitimin içeriğiyle birlikte ailede salt okunur kalır; Uzmanın ve kliniğin bunlara erişimi kapanır. App Store üyeliği Apple hesabından ayrıca iptal edilir.
```

Bugünkü metin:

```text
4.5. **Hesabın silinmesi ve ekip.** Uzman hesabını sildiğinde: tek kişilik klinik bütün uzman kayıtları, paylaşımları, davetleri ve üyelik kayıtlarıyla birlikte silinir; ekipte başka uzman varsa klinik ve kayıtları kalır, hesabını silen klinik sahibiyse sahiplik kliniğin en eski üyesine geçer, ekip üyesiyse sorumlusu olduğu aileler klinik sahibine kalır. Klinik silindiğinde ailelerin Moyo Ebeveyn'deki kendi kayıtları silinmez: ailenin bildirdiği davranış olayları ailede salt okunur kalır; Uzmanın ve kliniğin bunlara erişimi kapanır. App Store üyeliği Apple hesabından ayrıca iptal edilir.
```

### 22.10 · 6. Mesleki sorumluluk ve etik › 6.1

Özgün metin:

```text
6.1. **Mesleki kararlar uzmanındır.** Kayıtlara dayanarak verilen her karar kullanıcının kendi kararıdır. Moyo kayıtları değerlendirmez, yorumlamaz, kimseyi yönlendirmez. Uzman kayıtlarının, rutin ve adım önerilerinin, ebeveyn eğitimlerinin, hedef davranışların ve takip planının içeriği uzmanın mesleki kararıdır. Uzman girdiği her kaydı kendi beyanıyla ve kendi sorumluluğunda girer; Moyo bu içeriği denetlemez, doğrulamaz, onaylamaz ve bunun için bir sorumluluk ya da yükümlülük üstlenmez.
```

Bugünkü metin:

```text
6.1. **Mesleki kararlar uzmanındır.** Kayıtlara dayanarak verilen her karar kullanıcının kendi kararıdır. Moyo kayıtları değerlendirmez, yorumlamaz, kimseyi yönlendirmez. Uzman kayıtlarının, rutin ve adım önerilerinin, hedef davranışların ve takip planının içeriği uzmanın mesleki kararıdır. Uzman girdiği her kaydı kendi beyanıyla ve kendi sorumluluğunda girer; Moyo bu içeriği denetlemez, doğrulamaz, onaylamaz ve bunun için bir sorumluluk ya da yükümlülük üstlenmez.
```

### 22.11 · 7. Aile daveti, çocuk bilgisi ve paylaşım › 7.5

Özgün metin:

```text
7.5. **Uzmanın gördüğü aile verisi.** Paylaşım etkin olduğu sürece uzman çocuğun rutin ve adımlarını, atamalarını, tamamlamalarını, "Yapamam" nedenlerini, ebeveynin notlarını, davranış kayıtlarını (ses kaydı dahil), ebeveynin bildirdiği davranış olaylarını, ebeveyn eğitimi yanıtlarını (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar; uzmanın önerdiği derslerde uygulama günleri), randevulara verilen yanıtları ve takip planı uygulama kayıtlarını **salt okur**. Aile içi mesajlar, coin defteri ve oyun kaydı uzmana gösterilmez. Uzman bu verileri yalnız aileye verdiği mesleki hizmet için kullanır; başka amaçla kopyalamaz, üçüncü kişilere vermez.
```

Bugünkü metin:

```text
7.5. **Uzmanın gördüğü aile verisi.** Paylaşım etkin olduğu sürece uzman çocuğun rutin ve adımlarını, atamalarını, tamamlamalarını, "Yapamam" nedenlerini, ebeveynin notlarını, davranış kayıtlarını (ses kaydı dahil), ebeveynin bildirdiği davranış olaylarını, randevulara verilen yanıtları ve takip planı uygulama kayıtlarını **salt okur**. Aile içi mesajlar, coin defteri ve oyun kaydı uzmana gösterilmez. Uzman bu verileri yalnız aileye verdiği mesleki hizmet için kullanır; başka amaçla kopyalamaz, üçüncü kişilere vermez.
```

### 22.12 · 9. Uzman kayıtlarının niteliği ve uzman değişiminde aktarım › 9.1

Özgün metin:

```text
9.1. **Kayıtların niteliği.** Uygulamadaki kayıtlar, kullanıcıların kendi girdiği takip kayıtlarıdır. Moyo bu kayıtları saklar ve gösterir; bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Uzmanın Moyo Mercek'e girdiği notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, ebeveyn eğitimleri, hedef davranışlar, seans kayıtları ve aile programı, ebeveynin rızasıyla paylaşılan çocuğa ilişkin kayıtlardır. Notlar, hedef değerlendirmeleri, seans kayıtları ve ebeveyn eğitimindeki gözlem verisi aileye gösterilmez; uzmanın aileye açık bıraktığı hedefler, "Aileye gönder" dediği takip planı, gönderdiği rutin ve adım önerileri, Etkin yaptığı ebeveyn eğitimleri, ebeveyn kaydına açtığı hedef davranışlar ve aileye gösterilmesini seçtiği randevular ilgili ebeveynlere gösterilir.
```

Bugünkü metin:

```text
9.1. **Kayıtların niteliği.** Uygulamadaki kayıtlar, kullanıcıların kendi girdiği takip kayıtlarıdır. Moyo bu kayıtları saklar ve gösterir; bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Uzmanın Moyo Mercek'e girdiği notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, hedef davranışlar, seans kayıtları ve aile programı, ebeveynin rızasıyla paylaşılan çocuğa ilişkin kayıtlardır. Notlar, hedef değerlendirmeleri ve seans kayıtları aileye gösterilmez; uzmanın aileye açık bıraktığı hedefler, "Aileye gönder" dediği takip planı, gönderdiği rutin ve adım önerileri, ebeveyn kaydına açtığı hedef davranışlar ve aileye gösterilmesini seçtiği randevular ilgili ebeveynlere gösterilir.
```

### 22.13 · 11. Kabul edilemez kullanım › 11.1-e

Özgün metin:

```text
   - e) şablonları, kaynak kütüphanesini ya da yazılımı toplu kopyalayarak başka bir ürün veya ticari amaç için kullanmak;
```

Bugünkü metin:

```text
   - e) şablonları ya da yazılımı toplu kopyalayarak başka bir ürün veya ticari amaç için kullanmak;
```

### 22.15 · 12. Fikri mülkiyet › 12.2

Özgün metin:

```text
12.2. **Uzmanın hakları.** Uzmanın uzman kayıtlarına yazdığı özgün içerik (notlar, hedef tanımları, değerlendirmeler, önerilerdeki ve eğitimlerdeki özgün metinler) uzmana ya da aralarındaki ilişkiye göre kliniğe aittir. Uzman bir şablonu ya da içeriği uyarladığında şablonun ya da içeriğin kendisi Platformun kalır; uzmanın eklediği özgün kısım uzmanın olur.
```

Bugünkü metin:

```text
12.2. **Uzmanın hakları.** Uzmanın uzman kayıtlarına yazdığı özgün içerik (notlar, hedef tanımları, değerlendirmeler, önerilerdeki özgün metinler) uzmana ya da aralarındaki ilişkiye göre kliniğe aittir. Uzman bir şablonu ya da içeriği uyarladığında şablonun ya da içeriğin kendisi Platformun kalır; uzmanın eklediği özgün kısım uzmanın olur.
```

### 22.16 · Ek-3 › tablo satırı "Kaynak kütüphanesi (ekranın altında, bir kez)"

Özgün metin:

```text
| Kaynak kütüphanesi (ekranın altında, bir kez) | "Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz." |
```

Bugün: satır çıkarıldı.

## `23-veri-isleme-eki.md`

### 23.1 · Kısaca › "Roller"

Özgün metin:

```text
- **Roller:** Ailelerle çalışırken Moyo Mercek'e girdiğiniz kayıtlarda (notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, ebeveyn eğitimleri, hedef davranışlar, seans kayıtları, takip planı, davet bilgileri) **kliniğiniz veri sorumlusu**, **Platform veri işleyen**dir. Bu kayıtları kendi beyanınızla ve kendi sorumluluğunuzda girersiniz; Moyo içeriği denetlemez, doğrulamaz, sorumluluk ve yükümlülük üstlenmez.
```

Bugünkü metin:

```text
- **Roller:** Ailelerle çalışırken Moyo Mercek'e girdiğiniz kayıtlarda (notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, hedef davranışlar, seans kayıtları, takip planı, davet bilgileri) **kliniğiniz veri sorumlusu**, **Platform veri işleyen**dir. Bu kayıtları kendi beyanınızla ve kendi sorumluluğunuzda girersiniz; Moyo içeriği denetlemez, doğrulamaz, sorumluluk ve yükümlülük üstlenmez.
```

### 23.2 · 2. Roller ve kapsam › 2.2-b

Özgün metin:

```text
   - b) **Aile verisi** (ebeveynin ve çocuğun Moyo Ebeveyn ve Moyo Oyun'da oluşturduğu rutinler ve adımlar, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, davranış kayıtları ve ses kayıtları, bildirilen davranış olayları, ebeveyn eğitimi yanıtları (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar), randevulara verilen yanıtlar, çocuğun profil bilgileri, ebeveyn adları): Platform Moyo Ebeveyn ve Moyo Oyun için veri sorumlusudur. Uzman bu verileri ebeveynin açık rızasıyla ve paylaşım sürdükçe görür; gördüğü veriyi kendi mesleki kaydına geçirmesi ya da rapor ve CSV olarak alması bakımından kendisi ayrı veri sorumlusudur.
```

Bugünkü metin:

```text
   - b) **Aile verisi** (ebeveynin ve çocuğun Moyo Ebeveyn ve Moyo Oyun'da oluşturduğu rutinler ve adımlar, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, davranış kayıtları ve ses kayıtları, bildirilen davranış olayları, randevulara verilen yanıtlar, çocuğun profil bilgileri, ebeveyn adları): Platform Moyo Ebeveyn ve Moyo Oyun için veri sorumlusudur. Uzman bu verileri ebeveynin açık rızasıyla ve paylaşım sürdükçe görür; gördüğü veriyi kendi mesleki kaydına geçirmesi ya da rapor ve CSV olarak alması bakımından kendisi ayrı veri sorumlusudur.
```

### 23.3 · 4. İlgili kişi grupları ve veri kategorileri › 4.2 tablo satırı "Ebeveyn eğitimi"

Özgün metin:

```text
| Ebeveyn eğitimi | Eğitimin hedefi, kimin için olduğu ve durumu (Taslak, Etkin, Ustalaştı); seçilen modüller, uygulama görevleri ve yapılacaklar; ustalık ölçütü ve Uzmanın girdiği gözlem verisi (gözlem verisi aileye görünmez); uzmanın inceleme bilgisi | Ebeveyn, çocuk |
```

Bugün: satır çıkarıldı.

### 23.4 · 6. Uzmanın önceden verdiği talimatlar › 6.1-b

Özgün metin:

```text
   - b) **Aileye gösterme:** Uzmanın aileye açık bıraktığı hedefleri, "Aileye gönder" dediği andaki takip planını, gönderdiği rutin ve adım önerilerini, Etkin yaptığı ebeveyn eğitimlerini, ebeveyn kaydına açtığı hedef davranışları ve aileye gösterilmesini seçtiği randevuları, paylaşım etkin olduğu sürece ilgili ebeveynlere göstermek ve bunlar için bildirim (Uzmanın istediği eğitim hatırlatması dahil) göndermek. Notlar, hedef değerlendirmeleri, seans kayıtları ve ebeveyn eğitimindeki gözlem verisi aileye gösterilmez.
```

Bugünkü metin:

```text
   - b) **Aileye gösterme:** Uzmanın aileye açık bıraktığı hedefleri, "Aileye gönder" dediği andaki takip planını, gönderdiği rutin ve adım önerilerini, ebeveyn kaydına açtığı hedef davranışları ve aileye gösterilmesini seçtiği randevuları, paylaşım etkin olduğu sürece ilgili ebeveynlere göstermek ve bunlar için bildirim göndermek. Notlar, hedef değerlendirmeleri ve seans kayıtları aileye gösterilmez.
```

### 23.5 · 6. Uzmanın önceden verdiği talimatlar › 6.1-e

Özgün metin:

```text
   - e) **Hesap silme ve ekipten ayrılma:** Uzman hesabını sildiğinde tek kişilik klinikte bütün uzman kayıtlarını silmek; ekipte başka uzman varsa kayıtları klinikte bırakmak, klinik sahibi hesabını siliyorsa sahipliği en eski üyeye devretmek, ekip üyesi hesabını siliyorsa onun sorumlu olduğu aileleri klinik sahibine bırakmak. Klinik silindiğinde aileye açılmış ebeveyn eğitimlerinin içeriğini (adı, modüller, uygulama görevleri, yapılacaklar) ailenin yanıtları ve davranış olaylarıyla birlikte ailede salt okunur bırakmak; taslak eğitimleri, gözlem verisini, ustalık ölçütünü ve hedef davranış tanımını silmek (olayda yalnız davranışın adı kalır). Bir ekip üyesi klinikten ayrıldığında ya da çıkarıldığında kayıtları klinikte bırakmak ve onun o klinikteki erişimini derhal kapatmak.
```

Bugünkü metin:

```text
   - e) **Hesap silme ve ekipten ayrılma:** Uzman hesabını sildiğinde tek kişilik klinikte bütün uzman kayıtlarını silmek; ekipte başka uzman varsa kayıtları klinikte bırakmak, klinik sahibi hesabını siliyorsa sahipliği en eski üyeye devretmek, ekip üyesi hesabını siliyorsa onun sorumlu olduğu aileleri klinik sahibine bırakmak. Klinik silindiğinde ailenin bildirdiği davranış olaylarını ailede salt okunur bırakmak; hedef davranış tanımını silmek (olayda yalnız davranışın adı kalır). Bir ekip üyesi klinikten ayrıldığında ya da çıkarıldığında kayıtları klinikte bırakmak ve onun o klinikteki erişimini derhal kapatmak.
```

## `10-aydinlatma-ebeveyn.md`

### 10.1 · 3. Hangi verileri işliyoruz › tablo satırı "Ebeveyn eğitimi"

Özgün metin:

```text
| **Ebeveyn eğitimi** | Uzmanınızın atadığı eğitimde: tamamladığınız modüller, test ve açık uçlu sorulara yanıtlarınız, uygulama kayıtlarınız ve yazdığınız düşünce, yapılacak işaretleriniz ve "Nasıl geçti?" yanıtınız. Kısa ebeveyn derslerinde (kendi seçtiğiniz ya da uzmanınızın önerdiği) ilerlemeniz ve uyguladığınız günler. Test sonucu sizin bilgi yoklamanızdır, çocuğa ait bir puan değildir. |
```

Bugün: satır çıkarıldı.

### 10.2 · 4. Amaçlar ve hukuki sebepler › tablo satırı 3

Özgün metin:

```text
| 3 | Rutin, adım onayı, coin, Güneş Taşı, ödül ve hediyeleri, kendi seçtiğiniz kısa ebeveyn derslerini çalıştırmak | Rutin ve ödül kayıtları; ebeveyn eğitimi (ders ilerlemesi) | md. 5/2-c |
```

Bugünkü metin:

```text
| 3 | Rutin, adım onayı, coin, Güneş Taşı, ödül ve hediyeleri çalıştırmak | Rutin ve ödül kayıtları | md. 5/2-c |
```

### 10.3 · 4. Amaçlar ve hukuki sebepler › tablo satırı 8

Özgün metin:

```text
| 8 | Uzmanınızın atadığı ebeveyn eğitimini ve tanımladığı hedef davranışlar için olay bildirmenizi çalıştırmak; bunları uzmanınıza göstermek | Ebeveyn eğitimi, davranış olayları | md. 5/1 ve md. 6/3-a açık rıza (`uzman-paylasim-v1`) * |
```

Bugünkü metin:

```text
| 8 | Uzmanınızın tanımladığı hedef davranışlar için olay bildirmenizi çalıştırmak; bunları uzmanınıza göstermek | Davranış olayları | md. 5/1 ve md. 6/3-a açık rıza (`uzman-paylasim-v1`) * |
```

### 10.4 · 5. Verileriniz kimlerle paylaşılır › 5.1

Özgün metin:

```text
**5.1. Ailenizdeki diğer ebeveyn.** Aileye ikinci bir ebeveyn katılırsa aile verisini (çocuk profilleri, rutinler, ödüller, mesajlar, davranış kayıtları ve olaylar, uzman paylaşımları) o da görür ve yönetir. Uzmanın size atadığı ebeveyn eğitimini görür, ama sizin yerinize işaretleyemez.
```

Bugünkü metin:

```text
**5.1. Ailenizdeki diğer ebeveyn.** Aileye ikinci bir ebeveyn katılırsa aile verisini (çocuk profilleri, rutinler, ödüller, mesajlar, davranış kayıtları ve olaylar, uzman paylaşımları) o da görür ve yönetir.
```

### 10.5 · 5. Verileriniz kimlerle paylaşılır › 5.3 "Ne görür"

Özgün metin:

```text
- **Ne görür (uygulamada sizin bıraktığınız kayıtlar):** çocuğun profil bilgileri; rutinleri, adımları ve atamaları; "Yaptım" kayıtları ve onay/ret kararlarınız; davranış kayıtları ve ses kayıtları; uzmanın tanımladığı hedef davranışlar için bildirdiğiniz **davranış olayları**; uzmanın atadığı **ebeveyn eğitimindeki yanıtlarınız** (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları ve düşünceniz, yapılacak işaretleri ve "Nasıl geçti?" yanıtınız); uzmanın önerdiği derslerde, öneriden sonra uyguladığınız günler; randevulara verdiğiniz yanıt ve notunuz; takip planı uygulama kayıtlarınız; rutin ve adım önerilerine kararlarınız. Paylaşımdan önceki rutin ve davranış kayıtlarının geçmişi de görünür.
```

Bugünkü metin:

```text
- **Ne görür (uygulamada sizin bıraktığınız kayıtlar):** çocuğun profil bilgileri; rutinleri, adımları ve atamaları; "Yaptım" kayıtları ve onay/ret kararlarınız; davranış kayıtları ve ses kayıtları; uzmanın tanımladığı hedef davranışlar için bildirdiğiniz **davranış olayları**; randevulara verdiğiniz yanıt ve notunuz; takip planı uygulama kayıtlarınız; rutin ve adım önerilerine kararlarınız. Paylaşımdan önceki rutin ve davranış kayıtlarının geçmişi de görünür.
```

### 10.6 · 5. Verileriniz kimlerle paylaşılır › 5.3 "Ne görmez"

Özgün metin:

```text
- **Ne görmez:** mesajlarınız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı, tanışma yanıtlarınız, kendi seçtiğiniz dersler.
```

Bugünkü metin:

```text
- **Ne görmez:** mesajlarınız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı, tanışma yanıtlarınız.
```

### 10.7 · 5. Verileriniz kimlerle paylaşılır › 5.3 "Uzman bu kayıtları yalnız okur" maddesi

Özgün metin:

```text
- Uzman bu kayıtları **yalnız okur**, değiştiremez. Size rutin ve adım önerebilir, ebeveyn eğitimi atayabilir, hedef davranış tanımlayabilir, randevu açabilir ve takip planı gönderebilir; kabul edip etmemek, uygulayıp uygulamamak size kalmıştır.
```

Bugünkü metin:

```text
- Uzman bu kayıtları **yalnız okur**, değiştiremez. Size rutin ve adım önerebilir, hedef davranış tanımlayabilir, randevu açabilir ve takip planı gönderebilir; kabul edip etmemek, uygulayıp uygulamamak size kalmıştır.
```

### 10.8 · 5. Verileriniz kimlerle paylaşılır › 5.3 "Durdurma"

Özgün metin:

```text
- **Durdurma:** Uzmanım bölümünden (uzmanın sayfasında Uzmanı yönet › çocuğu ayır ya da uzmanı kaldır) paylaşımı durdurduğunuz an uzmanın erişimi biter ve uzman o andan sonraki kayıtlarınızı göremez; o uzmanla yürüttüğünüz ebeveyn eğitimi, olay bildirimi ve randevular da size ve uzmana kapanır. Uzmanın o güne kadar Moyo Uzman'a yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır; bu kayıtları siz görmezsiniz.
```

Bugünkü metin:

```text
- **Durdurma:** Uzmanım bölümünden (uzmanın sayfasında Uzmanı yönet › çocuğu ayır ya da uzmanı kaldır) paylaşımı durdurduğunuz an uzmanın erişimi biter ve uzman o andan sonraki kayıtlarınızı göremez; o uzmanla yürüttüğünüz olay bildirimi ve randevular da size ve uzmana kapanır. Uzmanın o güne kadar Moyo Uzman'a yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır; bu kayıtları siz görmezsiniz.
```

### 10.9 · 5. Verileriniz kimlerle paylaşılır › 5.6

Özgün metin:

```text
**5.6. Yurt dışına aktarım.** Yukarıdaki sağlayıcıların sunucuları Türkiye dışında olabilir. Aktarımın amacı yalnız hizmeti çalıştırmaktır (veritabanı, depolama, e-posta, ödeme, bildirim). Verilerinizi yurt dışına KVKK md. 9'a uygun olarak aktarırız: Kişisel Verileri Koruma Kurulu'nun ilan ettiği standart sözleşmeyi sağlayıcıyla imzalar, imzadan sonra 5 iş günü içinde Kurul'a bildiririz (ya da varsa yeterlilik kararına dayanırız). Davranış kayıtları ve olaylar, ebeveyn eğitimi yanıtları, not alanları ve uzmanla paylaşılan kayıtlar da bu sunucularda saklanır.
```

Bugünkü metin:

```text
**5.6. Yurt dışına aktarım.** Yukarıdaki sağlayıcıların sunucuları Türkiye dışında olabilir. Aktarımın amacı yalnız hizmeti çalıştırmaktır (veritabanı, depolama, e-posta, ödeme, bildirim). Verilerinizi yurt dışına KVKK md. 9'a uygun olarak aktarırız: Kişisel Verileri Koruma Kurulu'nun ilan ettiği standart sözleşmeyi sağlayıcıyla imzalar, imzadan sonra 5 iş günü içinde Kurul'a bildiririz (ya da varsa yeterlilik kararına dayanırız). Davranış kayıtları ve olaylar, not alanları ve uzmanla paylaşılan kayıtlar da bu sunucularda saklanır.
```

### 10.10 · 7. Ne kadar süre saklıyoruz › tablo satırı "Ebeveyn eğitimi, davranış olayları, randevular"

Özgün metin:

```text
| Ebeveyn eğitimi, davranış olayları, randevular | Uzmanla paylaşıma bağlıdır: paylaşım durunca size ve uzmana kapanır. Uzmanın hesabı ya da kliniği silinirse sizin girdiğiniz eğitim yanıtları, uygulama kayıtları, yapılacak işaretleri ve davranış olayları, size açılmış eğitimin içeriğiyle birlikte sizde salt okunur kalır; uzmanın bunlara erişimi kapanır. Aile ya da çocuk silinince hepsi silinir |
```

Bugünkü metin:

```text
| Davranış olayları, randevular | Uzmanla paylaşıma bağlıdır: paylaşım durunca size ve uzmana kapanır. Uzmanın hesabı ya da kliniği silinirse sizin bildirdiğiniz davranış olayları sizde salt okunur kalır; uzmanın bunlara erişimi kapanır. Aile ya da çocuk silinince hepsi silinir |
```

## `12-aydinlatma-uzman.md`

### 12.1 · 1. Veri sorumlusu ve bu metnin kapsamı › 1.3-a

Özgün metin:

```text
   - a) **Uzman kayıtları** (ailelerle çalışırken yazdığınız notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, ebeveyn eğitimleri, hedef davranışlar, seans kayıtları, takip planı, etiketler ve davet formuna girdiğiniz ebeveyn ve çocuk bilgileri): Bu kayıtlarda veri sorumlusu siz (ya da kliniğiniz), Platform veri işleyendir; rollerimiz ve yükümlülüklerimiz **Veri İşleme Eki**'nde (`veri-isleme-eki`) düzenlenir. Bu kayıtları kendi beyanınızla ve kendi sorumluluğunuzda girersiniz; Moyo içeriği denetlemez, doğrulamaz, bunun için sorumluluk ya da yükümlülük üstlenmez.
```

Bugünkü metin:

```text
   - a) **Uzman kayıtları** (ailelerle çalışırken yazdığınız notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, hedef davranışlar, seans kayıtları, takip planı, etiketler ve davet formuna girdiğiniz ebeveyn ve çocuk bilgileri): Bu kayıtlarda veri sorumlusu siz (ya da kliniğiniz), Platform veri işleyendir; rollerimiz ve yükümlülüklerimiz **Veri İşleme Eki**'nde (`veri-isleme-eki`) düzenlenir. Bu kayıtları kendi beyanınızla ve kendi sorumluluğunuzda girersiniz; Moyo içeriği denetlemez, doğrulamaz, bunun için sorumluluk ya da yükümlülük üstlenmez.
```

### 12.2 · 1. Veri sorumlusu ve bu metnin kapsamı › 1.3-b

Özgün metin:

```text
   - b) **Aile verisi** (ebeveynin Moyo Ebeveyn'de oluşturduğu rutinler ve adımlar, tamamlamalar, davranış kayıtları ve olayları, ebeveyn eğitimi yanıtları gibi veriler): Bunlar ebeveyn aydınlatma metnine tabidir; siz bu verileri yalnız ebeveynin açık rızasıyla ve paylaşım sürdükçe görürsünüz.
```

Bugünkü metin:

```text
   - b) **Aile verisi** (ebeveynin Moyo Ebeveyn'de oluşturduğu rutinler ve adımlar, tamamlamalar, davranış kayıtları ve olayları gibi veriler): Bunlar ebeveyn aydınlatma metnine tabidir; siz bu verileri yalnız ebeveynin açık rızasıyla ve paylaşım sürdükçe görürsünüz.
```

### 12.3 · 7. Saklama süreleri › "Ailelerle ilgili kayıtlarınız" listesi, hesabı silme maddesi

Özgün metin:

```text
- Siz hesabınızı silerseniz ailenin kendi girdiği kayıtlar (ebeveyn eğitimi yanıtları ve davranış olayları dahil) ailede kalır; sizin ve kliniğinizin bunlara erişimi kapanır.
```

Bugünkü metin:

```text
- Siz hesabınızı silerseniz ailenin kendi girdiği kayıtlar (davranış olayları dahil) ailede kalır; sizin ve kliniğinizin bunlara erişimi kapanır.
```

## `01-gizlilik-politikasi.md`

### 01.1 · 3. Moyo Ebeveyn › "Ebeveyn eğitimi" paragrafı

Özgün metin:

```text
**Ebeveyn eğitimi:** Uzmanınız size bir eğitim atadıysa tamamladığınız modüller, test yanıtlarınız ve doğru sayısı, açık uçlu yanıtlarınız, uygulama kayıtlarınız (sayı ve isteğe bağlı kısa düşünce) ve tamamladığınız yapılacaklar (nasıl geçtiği ve isteğe bağlı kısa düşünce).
```

Bugün: satır çıkarıldı.

### 01.2 · 4. Moyo Mercek › "Aileyle ilgili kayıtlar"

Özgün metin:

```text
**Aileyle ilgili kayıtlar:** Uzmanın birlikte çalıştığı aile için girdiği notlar (aile görmez), hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (uzman gönderince aile görür), kayıt istediği hedef davranışlar ve stratejileri, atadığı ebeveyn eğitimleri ve bu eğitimler için girdiği gözlem verisi (aile görmez), etiketler. Uzman bu alanlara tanı, ilaç ya da sağlık bilgisi yazmamaya özen gösterir.
```

Bugünkü metin:

```text
**Aileyle ilgili kayıtlar:** Uzmanın birlikte çalıştığı aile için girdiği notlar (aile görmez), hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (uzman gönderince aile görür), kayıt istediği hedef davranışlar ve stratejileri, etiketler. Uzman bu alanlara tanı, ilaç ya da sağlık bilgisi yazmamaya özen gösterir.
```

### 01.3 · 8. Uzmanla paylaşım › "Uzman ne görür?"

Özgün metin:

```text
- **Uzman ne görür?** Paylaştığınız çocuğun profil bilgilerini (ad ya da takma ad, simge, yaş grubu; girdiyseniz doğum günü ve cinsiyet), çocuğa verilen rutin ve adımları, "Yaptım" ve onay kayıtlarını, davranış kayıtlarını, bildirdiğiniz davranış olaylarını, ebeveyn eğitimindeki yanıtlarınızı (tamamlanan modüller, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar), uzmanın önerdiği derslerde uyguladığınız günleri, randevulara verdiğiniz yanıtları, takip planı uygulama kayıtlarınızı ve uzmanın önerilerine verdiğiniz kararları. Bunlar uygulamada bıraktığınız kayıtlardır. Uzman bu kayıtları yalnız sizin açık rızanızla görür; paylaşımı durdurduğunuz andan sonra yeni kayıtlarınızı göremez. Uzman bunları yalnız okur, değiştiremez. Aile içi mesajları, coin hareketlerini ve oyun kaydını görmez.
```

Bugünkü metin:

```text
- **Uzman ne görür?** Paylaştığınız çocuğun profil bilgilerini (ad ya da takma ad, simge, yaş grubu; girdiyseniz doğum günü ve cinsiyet), çocuğa verilen rutin ve adımları, "Yaptım" ve onay kayıtlarını, davranış kayıtlarını, bildirdiğiniz davranış olaylarını, randevulara verdiğiniz yanıtları, takip planı uygulama kayıtlarınızı ve uzmanın önerilerine verdiğiniz kararları. Bunlar uygulamada bıraktığınız kayıtlardır. Uzman bu kayıtları yalnız sizin açık rızanızla görür; paylaşımı durdurduğunuz andan sonra yeni kayıtlarınızı göremez. Uzman bunları yalnız okur, değiştiremez. Aile içi mesajları, coin hareketlerini ve oyun kaydını görmez.
```

### 01.4 · 8. Uzmanla paylaşım › "Siz ne görürsünüz?"

Özgün metin:

```text
- **Siz ne görürsünüz?** Uzmanın gönderdiği rutin ve adım önerilerini, takip planını, size atadığı ebeveyn eğitimlerini ve kaydetmenizi istediği hedef davranışları. Uzmanın kendi notlarını ve gözlem verisini görmezsiniz.
```

Bugünkü metin:

```text
- **Siz ne görürsünüz?** Uzmanın gönderdiği rutin ve adım önerilerini, takip planını ve kaydetmenizi istediği hedef davranışları. Uzmanın kendi notlarını görmezsiniz.
```

## `41-alt-isleyenler.md`

### 41.1 · 3.1 Supabase › tablo satırı "Veri"

Özgün metin:

```text
| Veri | Bu uygulamalarda işlenen verilerin tamamı: ebeveyn, çocuk ve uzman hesap ve profil verisi; rutinler ve adımlar, mesajlar, oyun kaydı; davranış kayıtları ve davranış olayları, ebeveyn eğitimi yanıtları, tanışma yanıtları ve uzman notları gibi kullanıcıların kendi girdiği takip kayıtları; kullanım ve güvenlik kayıtları |
```

Bugünkü metin:

```text
| Veri | Bu uygulamalarda işlenen verilerin tamamı: ebeveyn, çocuk ve uzman hesap ve profil verisi; rutinler ve adımlar, mesajlar, oyun kaydı; davranış kayıtları ve davranış olayları, tanışma yanıtları ve uzman notları gibi kullanıcıların kendi girdiği takip kayıtları; kullanım ve güvenlik kayıtları |
```

## `44-kvkk-basvuru-usulu.md`

### 44.1 · 8. Uzmanla ilgili kayıtlar: kime başvurursunuz? › tablo satırı "Uzmanın birlikte çalıştığı aile hakkında girdiği kayıtlar"

Özgün metin:

```text
| Uzmanın birlikte çalıştığı aile hakkında girdiği kayıtlar (notlar, hedefler, değerlendirmeler, takip planı, hedef davranışlar, atadığı ebeveyn eğitimleri ve gözlem verisi, seans kayıtları) | Bu kayıtların veri sorumlusu uzman ya da kliniğidir; biz onun adına saklayan veri işleyeniz. Başvurunuzu uzmanınıza ya da kliniğine yapın. Bize gelirse kliniğe iletir ve size bildiririz; kliniğe teknik olarak yardım ederiz. |
```

Bugünkü metin:

```text
| Uzmanın birlikte çalıştığı aile hakkında girdiği kayıtlar (notlar, hedefler, değerlendirmeler, takip planı, hedef davranışlar, seans kayıtları) | Bu kayıtların veri sorumlusu uzman ya da kliniğidir; biz onun adına saklayan veri işleyeniz. Başvurunuzu uzmanınıza ya da kliniğine yapın. Bize gelirse kliniğe iletir ve size bildiririz; kliniğe teknik olarak yardım ederiz. |
```

### 44.2 · 8. Uzmanla ilgili kayıtlar: kime başvurursunuz? › tablo satırı "Ebeveynin girdiği kayıtlar"

Özgün metin:

```text
| Ebeveynin girdiği kayıtlar (rutinler ve adımlar, davranış kayıtları ve davranış olayları, ebeveyn eğitimi yanıtları, takip planı uygulama kayıtları) | Bize |
```

Bugünkü metin:

```text
| Ebeveynin girdiği kayıtlar (rutinler ve adımlar, davranış kayıtları ve davranış olayları, takip planı uygulama kayıtları) | Bize |
```

## `50-uygulama-ici-metinler.md`

### 50.1 · 5.1 Moyo Ebeveyn › "Ailede başka ebeveyn yoksa" listesi, 2. madde

Özgün metin:

```text
> - rutinler ve adımlar, onaylar, ödüller, inci ve Güneş Taşı geçmişi, ebeveyn dersleri ve uygulama günlerin,
```

Bugünkü metin:

```text
> - rutinler ve adımlar, onaylar, ödüller, inci ve Güneş Taşı geçmişi,
```

### 50.2 · 5.1 Moyo Ebeveyn › "Ailede başka ebeveyn yoksa" listesi, 5. madde

Özgün metin:

```text
> - uzman paylaşımları (uzmanın erişimi hemen biter) ve uzmanın bu çocuklar için tuttuğu notlar, hedefler, ebeveyn eğitimleri ve takip planı,
```

Bugünkü metin:

```text
> - uzman paylaşımları (uzmanın erişimi hemen biter) ve uzmanın bu çocuklar için tuttuğu notlar, hedefler ve takip planı,
```

### 50.3 · 5.2 Moyo Mercek › "Tek kişilik klinik" metni

Özgün metin:

```text
> **Kliniğin ve içindeki her şey silinir:** danışan paylaşımları, notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, taslak ebeveyn eğitimleri, eğitimlerdeki gözlem verilerin ve ustalık ölçütlerin, hedef davranışlar, takip planları, davetler ve üyelik kaydı. Ailelerin Moyo Ebeveyn'deki kendi verileri silinmez; yalnız seninle paylaşımları biter. Ailelere gönderdiğin eğitimler, ebeveynlerin bu eğitimlere verdiği yanıtlar ve kayıtlarla birlikte, ailenin hedef davranışlara bildirdiği olaylar da (davranışın adıyla) ailede kalır; sen ve kliniğin bunlara artık erişemezsiniz. Kayıtların, ailenin izniyle sonraki uzmana aktarımı da sona erer. Mevzuatın sana yüklediği kayıt saklama yükümlülüğü sende; saklaman gereken kayıtları silmeden önce indir ya da yazdır.
```

Bugünkü metin:

```text
> **Kliniğin ve içindeki her şey silinir:** danışan paylaşımları, notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, hedef davranışlar, takip planları, davetler ve üyelik kaydı. Ailelerin Moyo Ebeveyn'deki kendi verileri silinmez; yalnız seninle paylaşımları biter. Ailenin hedef davranışlara bildirdiği olaylar (davranışın adıyla) ailede kalır; sen ve kliniğin bunlara artık erişemezsiniz. Kayıtların, ailenin izniyle sonraki uzmana aktarımı da sona erer. Mevzuatın sana yüklediği kayıt saklama yükümlülüğü sende; saklaman gereken kayıtları silmeden önce indir ya da yazdır.
```

### 50.4 · 13. "Tanı değildir" notu › "Ebeveyn dersleri" başlığı (bayrak işareti eklendi)

Özgün metin:

```text
**Ebeveyn dersleri (Gelişim › Ben; öneri 5 Kasım 2026, `sozlesme/akislar.md` 22):** ders sayfasının ve "Yakında" kartının altında:
```

Bugünkü metin:

```text
**Ebeveyn dersleri (Gelişim › Ben; öneri 5 Kasım 2026, `sozlesme/akislar.md` 22; yalnız bayrak `parent_training` açıkken, lansmanda kapalı, kullanıcı kararı 23 Kasım 2026):** ders sayfasının ve "Yakında" kartının altında:
```

### 50.5 · 13. "Tanı değildir" notu › "Uzmanın önerdiği derste ek satır" paragrafı (bayrak cümlesi eklendi)

Özgün metin:

```text
Uzmanın önerdiği derste ek satır: "Uzmanın bu dersteki uygulama günlerini görür." Uzman paylaşımı ekranındaki "Paylaşılır" listesine (Moyo Ebeveyn ⓘ, rıza metni `uzman-paylasim-v1` "takip planı uygulama kayıtların" kapsamı) satır: "Uzmanının önerdiği derslerde uyguladığın günler" ve "Paylaşılmaz" listesine: "Kendi seçtiğin dersler". Sürümlü rıza metni değişmedi (`hukuk_notlari.md` 26).
```

Bugünkü metin:

```text
Uzmanın önerdiği derste ek satır: "Uzmanın bu dersteki uygulama günlerini görür." Uzman paylaşımı ekranındaki "Paylaşılır" listesine (Moyo Ebeveyn ⓘ, rıza metni `uzman-paylasim-v1` "takip planı uygulama kayıtların" kapsamı) satır: "Uzmanının önerdiği derslerde uyguladığın günler" ve "Paylaşılmaz" listesine: "Kendi seçtiğin dersler". Sürümlü rıza metni değişmedi (`hukuk_notlari.md` 26). Ek satır ve bu iki liste satırı da yalnız bayrak açıkken gösterilir.
```

### 50.6 · 13. "Tanı değildir" notu › "Kaynak kütüphanesi" başlığı (bayrak işareti eklendi)

Özgün metin:

```text
**Kaynak kütüphanesi (Moyo Ebeveyn ve Moyo Mercek; kullanıcı kararı 14 Kasım 2026, `hukuk_notlari.md` M.5; iki uygulamada uygulandı):** kütüphane ekranının altında bir kez, göze batmadan (her eğitimde değil):
```

Bugünkü metin:

```text
**Kaynak kütüphanesi (Moyo Ebeveyn ve Moyo Mercek; kullanıcı kararı 14 Kasım 2026, `hukuk_notlari.md` M.5; iki uygulamada uygulandı; yalnız bayrak `parent_training` açıkken, lansmanda kapalı):** kütüphane ekranının altında bir kez, göze batmadan (her eğitimde değil):
```

### 50.7 · 15. Avukat dosyası kısa metin önerileri › tablo satırı 2

Özgün metin:

```text
| 2 | Moyo Ebeveyn serbest metin alanları: not, davranış kaydı, onay notu, ebeveyn eğitimi yanıtı (alan ipucu) | "Gözlemini yaz. Tanı, ilaç ya da sağlık bilgisi yazma." | Özel nitelikli veri girişini kaynağında azaltır; bugün yok | Öneri, kullanıcı kararı bekler |
```

Bugünkü metin:

```text
| 2 | Moyo Ebeveyn serbest metin alanları: not, davranış kaydı, onay notu (alan ipucu); ebeveyn eğitimi yanıtı yalnız bayrak `parent_training` açıkken | "Gözlemini yaz. Tanı, ilaç ya da sağlık bilgisi yazma." | Özel nitelikli veri girişini kaynağında azaltır; bugün yok | Öneri, kullanıcı kararı bekler |
```

## `00-olgular.md`

### 00.1 · 1. Taraflar ve ürünler › "Konum (avukat dosyası çekirdek maddeleri)" paragrafı (işaret eklendi)

Özgün metin:

```text
**Konum (avukat dosyası çekirdek maddeleri, 13–14 Kasım 2026):** Moyo, aile üyelerinin günlük rutin ve sorumlulukları kendi tercihleriyle kaydetmesini ve bu kayıtları görmesini sağlayan dijital bir takip aracıdır. Kayıtlar kullanıcıların kendi girdiği takip kayıtlarıdır; Moyo bu kayıtları saklar ve gösterir, bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Platform **sağlık hizmeti sunmaz**, tanı koymaz, tedavi önermez, uzman istihdam etmez, uzman-aile arasında aracılık/yönlendirme yapmaz; uzmanın aileyle çalışması için bir araçtır. Hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir. Acil durum ve kriz hizmeti değildir (acil: 112). Sağlık hizmeti, uzaktan sağlık hizmeti ya da tıbbi cihaz değildir; tıbbi bir amaçla tasarlanmamıştır (kullanıcı, 20 Kasım 2026). Moyo'nun içeriği (ebeveyn eğitimi kütüphanesi, hazır rutin ve plan şablonları) genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz (gözden geçiren uzmanın adı yazılmaz); içeriğe dayanılarak verilen kararlardan Moyo sorumlu değildir.
```

Bugünkü metin:

```text
**Konum (avukat dosyası çekirdek maddeleri, 13–14 Kasım 2026):** Moyo, aile üyelerinin günlük rutin ve sorumlulukları kendi tercihleriyle kaydetmesini ve bu kayıtları görmesini sağlayan dijital bir takip aracıdır. Kayıtlar kullanıcıların kendi girdiği takip kayıtlarıdır; Moyo bu kayıtları saklar ve gösterir, bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Platform **sağlık hizmeti sunmaz**, tanı koymaz, tedavi önermez, uzman istihdam etmez, uzman-aile arasında aracılık/yönlendirme yapmaz; uzmanın aileyle çalışması için bir araçtır. Hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir. Acil durum ve kriz hizmeti değildir (acil: 112). Sağlık hizmeti, uzaktan sağlık hizmeti ya da tıbbi cihaz değildir; tıbbi bir amaçla tasarlanmamıştır (kullanıcı, 20 Kasım 2026). Moyo'nun içeriği (ebeveyn eğitimi kütüphanesi — lansmanda kapalı, bayrak `parent_training` —, hazır rutin ve plan şablonları) genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz (gözden geçiren uzmanın adı yazılmaz); içeriğe dayanılarak verilen kararlardan Moyo sorumlu değildir.
```

### 00.2 · 2. İşlenen veriler › "Ebeveyn (Moyo Ebeveyn)" paragrafı (işaret eklendi)

Özgün metin:

```text
**Ebeveyn (Moyo Ebeveyn):** ad, takma ad, simge; e-posta; şifre (yalnız kimlik doğrulama sağlayıcısında, özetlenmiş); aile adı; çocuk profilleri (ad/takma ad, simge, isteğe bağlı cinsiyet ve doğum günü, yaş grubu); rutinler ve adımlar (veritabanında `tasks`), tekrarlar, hatırlatmalar; çocuğun "Yaptım"ları ve ebeveyn onay/ret (isteğe bağlı not/neden); ödüller, Güneş Taşı defteri (ebeveynin taş düşürme nedeni dahil); coin defteri; ebeveyn↔çocuk mesajları (yazı, fotoğraf, sesli mesaj, çıkartma; okundu bilgisi); **davranış kayıtları** (ABC: öncül–davranış–sonuç; uygulamadaki adı "Davranış kaydı", 28 Ekim 2026 — eski adlar "zor an" / "gözlem notu") ve isteğe bağlı ses kaydı (özel nitelikli veri içerebilir); **tanışma yanıtları** (hedefler, nereden duydu, sorumluluk/hatırlatma çatışma sıklığı, çocuğun düzeni, çocuğun çalıştığı uzmanlar, geçen hafta davranış sıklıkları — 14 Kasım 2026'dan beri iki günlük davranış maddesi dahil: "yerinde durmakta ya da sırasını beklemekte zorlandı", "plan değişince ya da bir işten ötekine geçerken zorlandı" —, ilgi alanları, motive edenler; yanıtlar hazır seçeneklerdir, serbest metin yok; uzman görmez). **Tanı ve ilaç soruları ile sağlık yanıtı rızası (`saglik-yanit-v1`) 14 Kasım 2026'da kalktı**: eski yanıtlar silindi, sunucu bu iki soruya yanıt yazmaz (`migrations/20261114200000_intake_observation_owner.sql`); `intake_answers.consent_version` sütunu duruyor, doldurulmuyor. Uzman paylaşımı onayları; takip planı uygulama kayıtları (bugün uyguladım, zorluk 1–5, uygulayamama nedeni; takip planı lansmanda bayrakla kapalı, `akislar.md` 12.2); uzmanın atadığı **ebeveyn eğitimi** kayıtları (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları ve düşünce, yapılacak işaretleri ve "Nasıl geçti?" yanıtı; `akislar.md` 23; özel nitelikli veri içerebilir); uzmanın tanımladığı hedef davranışa ebeveynin bildirdiği **davranış olayları** (zaman, sayı ya da süre, öncesi–sonrası, denenen strateji, çocuğun tepkisi 1–5 — ebeveynin gözlemi, puan değil; `akislar.md` 24; özel nitelikli veri içerebilir); ebeveyn dersleri ve uygulama günleri (`akislar.md` 22); abonelik durumu (ürün, dönem sonu, işlem kimliği; kart bilgisi bizde yok, Apple'da); bildirim jetonu; kullanım kayıtları.
```

Bugünkü metin:

```text
**Ebeveyn (Moyo Ebeveyn):** ad, takma ad, simge; e-posta; şifre (yalnız kimlik doğrulama sağlayıcısında, özetlenmiş); aile adı; çocuk profilleri (ad/takma ad, simge, isteğe bağlı cinsiyet ve doğum günü, yaş grubu); rutinler ve adımlar (veritabanında `tasks`), tekrarlar, hatırlatmalar; çocuğun "Yaptım"ları ve ebeveyn onay/ret (isteğe bağlı not/neden); ödüller, Güneş Taşı defteri (ebeveynin taş düşürme nedeni dahil); coin defteri; ebeveyn↔çocuk mesajları (yazı, fotoğraf, sesli mesaj, çıkartma; okundu bilgisi); **davranış kayıtları** (ABC: öncül–davranış–sonuç; uygulamadaki adı "Davranış kaydı", 28 Ekim 2026 — eski adlar "zor an" / "gözlem notu") ve isteğe bağlı ses kaydı (özel nitelikli veri içerebilir); **tanışma yanıtları** (hedefler, nereden duydu, sorumluluk/hatırlatma çatışma sıklığı, çocuğun düzeni, çocuğun çalıştığı uzmanlar, geçen hafta davranış sıklıkları — 14 Kasım 2026'dan beri iki günlük davranış maddesi dahil: "yerinde durmakta ya da sırasını beklemekte zorlandı", "plan değişince ya da bir işten ötekine geçerken zorlandı" —, ilgi alanları, motive edenler; yanıtlar hazır seçeneklerdir, serbest metin yok; uzman görmez). **Tanı ve ilaç soruları ile sağlık yanıtı rızası (`saglik-yanit-v1`) 14 Kasım 2026'da kalktı**: eski yanıtlar silindi, sunucu bu iki soruya yanıt yazmaz (`migrations/20261114200000_intake_observation_owner.sql`); `intake_answers.consent_version` sütunu duruyor, doldurulmuyor. Uzman paylaşımı onayları; takip planı uygulama kayıtları (bugün uyguladım, zorluk 1–5, uygulayamama nedeni; takip planı lansmanda bayrakla kapalı, `akislar.md` 12.2); uzmanın atadığı **ebeveyn eğitimi** kayıtları (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları ve düşünce, yapılacak işaretleri ve "Nasıl geçti?" yanıtı; `akislar.md` 23; özel nitelikli veri içerebilir; **lansmanda kapalı**: bayrak `parent_training`, kullanıcı kararı 23 Kasım 2026, sunucu ortak `supabase/proposed/20261123210000_parent_training_off.sql`); uzmanın tanımladığı hedef davranışa ebeveynin bildirdiği **davranış olayları** (zaman, sayı ya da süre, öncesi–sonrası, denenen strateji, çocuğun tepkisi 1–5 — ebeveynin gözlemi, puan değil; `akislar.md` 24; özel nitelikli veri içerebilir); ebeveyn dersleri ve uygulama günleri (`akislar.md` 22; Gelişim › Ben, uzmanın önerdiği ders dahil; **lansmanda kapalı**: bayrak `parent_training`, kullanıcı kararı 23 Kasım 2026, sunucu ortak `supabase/proposed/20261123210000_parent_training_off.sql`); abonelik durumu (ürün, dönem sonu, işlem kimliği; kart bilgisi bizde yok, Apple'da); bildirim jetonu; kullanım kayıtları.
```

### 00.3 · 2. İşlenen veriler › "Uzman (Moyo Mercek)" paragrafı (işaret eklendi)

Özgün metin:

```text
**Uzman (Moyo Mercek):** ad, unvan, e-posta, klinik adı, ekip rolü; ~~isteğe bağlı mesleki belge incelemesi~~ (özellik kullanılmıyor, kullanıcı 20 Kasım 2026; tablo durur) (e-Devlet barkodlu mezuniyet belgesi — ad, T.C. kimlik no, okul, bölüm, derece, tarih içerir; BACB sicil no). Belge yalnız inceleme için okunur, karar verilince silinir; saklanan: özet (üniversite, bölüm, derece, yıl), barkod, karar kaydı; kimlik no saklanmaz. Rozet: aileye "Uzman diploma belgesini yükledi", uzmana "Belge yüklendi: <meslek>" (doğrulama beyanı değildir; özellik kapalı). Karşılama anketi yanıtları (meslek, zorluklar, yararlı özellikler, geliş nedeni; 28 Ekim 2026'dan beri atlanamaz, `README.md` sorun 16). Uzmanın aileyle ilgili girdileri: notlar (aile görmez), hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (gönderilince aile görür; lansmanda bayrakla kapalı), ebeveyn eğitimleri, hedef davranışlar ve stratejiler, seans randevuları ve seans kayıtları, etiketler. Davet bilgileri: ebeveynin adı ve e-postası, çocuğun adı/takma adı ve yaş grubu (aile onayına kadar; bağlanmamış davet 3 günde, bağlanmış onaylanmamış en geç 30 günde silinir). Abonelik; kullanım kayıtları.
```

Bugünkü metin:

```text
**Uzman (Moyo Mercek):** ad, unvan, e-posta, klinik adı, ekip rolü; ~~isteğe bağlı mesleki belge incelemesi~~ (özellik kullanılmıyor, kullanıcı 20 Kasım 2026; tablo durur) (e-Devlet barkodlu mezuniyet belgesi — ad, T.C. kimlik no, okul, bölüm, derece, tarih içerir; BACB sicil no). Belge yalnız inceleme için okunur, karar verilince silinir; saklanan: özet (üniversite, bölüm, derece, yıl), barkod, karar kaydı; kimlik no saklanmaz. Rozet: aileye "Uzman diploma belgesini yükledi", uzmana "Belge yüklendi: <meslek>" (doğrulama beyanı değildir; özellik kapalı). Karşılama anketi yanıtları (meslek, zorluklar, yararlı özellikler, geliş nedeni; 28 Ekim 2026'dan beri atlanamaz, `README.md` sorun 16). Uzmanın aileyle ilgili girdileri: notlar (aile görmez), hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (gönderilince aile görür; lansmanda bayrakla kapalı), ebeveyn eğitimleri (lansmanda kapalı, bayrak `parent_training`), hedef davranışlar ve stratejiler, seans randevuları ve seans kayıtları, etiketler. Davet bilgileri: ebeveynin adı ve e-postası, çocuğun adı/takma adı ve yaş grubu (aile onayına kadar; bağlanmamış davet 3 günde, bağlanmış onaylanmamış en geç 30 günde silinir). Abonelik; kullanım kayıtları.
```

### 00.4 · 2. İşlenen veriler › "Aile ya da çocuk silinince" paragrafı (işaret eklendi)

Özgün metin:

```text
**Aile ya da çocuk silinince:** uzmanla paylaşım kaydı aileye bağlı olduğu için o çocuğa ait uzman notları, hedefleri ve takip planı da silinir (bugünkü sistem). Kullanıcı kararı (20 Kasım 2026, B.8): sorun değil; uzmana kayıtta en baştan söylenir (`hukuk/50` §1.2, `22` 6.4-a), aile bağı kopunca uzman yeni veri görmez. (Çekirdek madde 7: uzmanın kayıt tutma ve saklama yükümlülükleri uzmandadır, Moyo'ya geçmez; uzman raporu ve CSV'yi kendisi indirir.) Uzmanın hesabı ya da kliniği silinince ailenin kendi girdiği eğitim yanıtları ve davranış olayları ailede kalır (3A; `supabase/migrations/20261120200000_family_keeps_records.sql`, uygulandı 22 Kasım 2026).
```

Bugünkü metin:

```text
**Aile ya da çocuk silinince:** uzmanla paylaşım kaydı aileye bağlı olduğu için o çocuğa ait uzman notları, hedefleri ve takip planı da silinir (bugünkü sistem). Kullanıcı kararı (20 Kasım 2026, B.8): sorun değil; uzmana kayıtta en baştan söylenir (`hukuk/50` §1.2, `22` 6.4-a), aile bağı kopunca uzman yeni veri görmez. (Çekirdek madde 7: uzmanın kayıt tutma ve saklama yükümlülükleri uzmandadır, Moyo'ya geçmez; uzman raporu ve CSV'yi kendisi indirir.) Uzmanın hesabı ya da kliniği silinince ailenin kendi girdiği eğitim yanıtları (eğitim lansmanda kapalı) ve davranış olayları ailede kalır (3A; `supabase/migrations/20261120200000_family_keeps_records.sql`, uygulandı 22 Kasım 2026).
```

### 00.5 · 3. Akışlar ve onaylar › tablo satırı "Uzmanın açtığı ebeveyn eğitimi ve hedef davranış" (işaret eklendi)

Özgün metin:

```text
| Uzmanın açtığı ebeveyn eğitimi ve hedef davranış (ebeveynin yanıtları, uygulama kayıtları, davranış olayları) | Uzmanla paylaşımın parçası (`uzman-paylasim-v1`); rıza metnindeki kapsamın yeterliliği avukata | `parent_training_*`, `clinic_target_behaviors`, `behavior_incidents`; paylaşım bitince aile ve uzman erişimi kapanır |
```

Bugünkü metin:

```text
| Uzmanın açtığı ebeveyn eğitimi (lansmanda kapalı, bayrak `parent_training`) ve hedef davranış (ebeveynin yanıtları, uygulama kayıtları, davranış olayları) | Uzmanla paylaşımın parçası (`uzman-paylasim-v1`); rıza metnindeki kapsamın yeterliliği avukata | `parent_training_*`, `clinic_target_behaviors`, `behavior_incidents`; paylaşım bitince aile ve uzman erişimi kapanır |
```

