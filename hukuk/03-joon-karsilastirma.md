# Hukuk arşivi — 03. Joon karşılaştırması (Privacy Policy 11 Haziran 2025, Terms of Service 21 Ocak 2026)

> 27 Ekim 2026, kullanıcı isteği: "Joon'un terms of service ve privacy policy'sini analiz et, referans alabileceğin içerik olabilir." Metinler kullanıcı tarafından sohbete yapıştırıldı (joonapp.io bu ortamın ağ iznine kapalı). **İlke düzeyinde referanstır: Joon'un cümleleri çevrilmez, kopyalanmaz.** Joon ABD hukukuna (COPPA, Kaliforniya yasaları, Delaware) göre yazılmış ve kendi ifadesiyle yalnız ABD'deki kullanıcılar için tasarlanmış; Türkiye'de geçerli olmayan ya da tüketiciye karşı geçersiz sayılabilecek maddeleri ayrıca işaretlendi.

## 1. Joon'un yapısı (bizimle aynı üçlü)

Joon da üç parçalı: ebeveyn uygulaması, çocuk uygulaması, klinisyen paneli. Gizlilik politikası tek metin; kullanım koşulları tek metin (klinisyen için ayrı sözleşme yok — yalnız "kurum" adına kullanan için COPPA sorumluluğu maddesi var). **Bizde uzman için ayrı sözleşme + veri işleme eki var; bu, Joon'dan daha kapsamlı.**

## 2. Joon'dan alınan ilkeler (bizde karşılığı)

| # | Joon'da | Bizde | Karar |
|---|---|---|---|
| J1 | Her bölümün başında bir cümlelik "kısaca" özeti | Her belgenin başında "Kısaca" var; bölüm başında yok | Gizlilik politikasında uzun bölümlere tek cümlelik özet eklenebilir (avukat metni kesinleştirirken). |
| J2 | Kayıt anketlerindeki **her** soruda "cevap vermek istemiyorum" seçeneği | Yalnız sağlık sorularında "söylemek istemiyorum" var | **Öneri (ürün):** ParentApp tanışma sorularının hepsi atlanabilir ya da "söylemek istemiyorum" seçenekli olsun (KVKK md. 4 ölçülülük). `README` sorun 13. |
| J3 | Kayıt bilgisinin (çocuğun davranış sorunları dahil) **ne için** kullanıldığı yazılı: hizmeti çocuğa göre uyarlamak | Tanı/ilaç sorularının amacı yazılı değil (`README` sorun 7) | Yanıt hangi öneriyi/şablonu değiştiriyorsa aydınlatmada somut yazılmalı; hiçbir şeyi değiştirmiyorsa soru kaldırılmalı. |
| J4 | Çocuktan yalnız ad (takma ad yeterli); cinsiyet ve doğum tarihi isteğe bağlı | Aynı | Var. |
| J5 | Çocuk kendisi hesap açamaz; ebeveyn/terapist/öğretmen davet eder | Yalnız ebeveyn açar; uzman yalnız ad önerir, ebeveyn onaylar | Bizimki daha sıkı; değişiklik yok. |
| J6 | Çocukta veri toplayan özellik (fotoğraf, yapay zekâ, ses) için **özelliğe özel ayrı ebeveyn onayı**, cihaz izni, istendiğinde geri alma ve **ince ayar** (hepsi açık / yalnız isteğe bağlı / kapalı) | Çocukta fotoğraf, ses, yapay zekâ yok | **Gelecek özellik kuralı** (§4 K1). |
| J7 | Çocuğun sesli yapay zekâ kullanımında ses gerçek zamanlı işlenir, **saklanmaz**; yetişkin gözetimi önerilir; terapi/tıbbi tavsiye değildir | Yapay zekâ yok | Gelecek özellik kuralı (§4 K2). |
| J8 | Uygunsuz içerik için uygulama içi **bildirme düğmesi**, ekip incelemesi, ebeveyne haber | Çocuk yalnız ailesiyle yazışır (yazı + hazır çıkartma); yabancıyla iletişim yok | Bugün gerek yok; aile dışına içerik paylaşımı eklenirse zorunlu (§4 K3). |
| J9 | "Lisanslı ruh sağlığı hizmeti sağlayıcısı değiliz; tıbbi tavsiye, tanı, tedavi yerine geçmez" — metnin **en başında, büyük harfle** | ParentApp ve uzman metinlerinin "Kısaca" ilk maddesinde | Var; mağaza açıklamasında ve ilk açılışta da görünmesi önerilir (`50-uygulama-ici-metinler.md`). |
| J10 | Esaslı değişiklikte bildirim ve gerekiyorsa **ebeveyn onayının yenilenmesi** | Sürümlü yeniden onay (`legal_pending`) — çocuk metinleri için veli yeniden onaylar | Var; bizimki daha güçlü (onay kaydı tutuluyor). |
| J11 | Silinen verinin **yedeklerde** kalabileceği, silinene dek işlenmeden ayrı tutulduğu | Gizlilik 216. satır ve saklama-imha (Supabase yedekleri `[SÜRE]`) | Var. Aydınlatmalarda da tek cümle olarak geçmeli (avukat kesinleştirirken). |
| J12 | Kurum (okul/klinik) adına kullananın ebeveyn onaylarını **kendisi alıp saklaması** ve istenince göstermesi | Ebeveyn onayı uygulamada, sürümlü kayıtla alınıyor; uzmanın meslek etiğinden doğan onamı uzmanda (sözleşme 6.2) | Var; bizimki ebeveyni doğrudan sürece kattığı için daha güçlü. |
| J13 | Bildirimler için cihaz ayarından vazgeçme | Gizlilikte var | Var. |
| J14 | Yasaklı kullanım listesi (taklit, tersine mühendislik, otomatik veri toplama, spam, güvenliği aşma) | ParentApp koşulları ve uzman sözleşmesinde var | Var. Tersine mühendislikte FSEK md. 38'deki kanuni istisnalar saklı tutulmalı (avukat). |

## 3. Joon'da olup **almadığımız** (Türk hukukunda geçersiz ya da bize uymayan)

| # | Joon'da | Neden almıyoruz |
|---|---|---|
| X1 | Web sitesini ziyaret etmek, Meta Pixel ve diğer izleme araçlarına **onay sayılıyor** | KVKK ve Kurul'un Çerez Rehberi (2022): zorunlu olmayan çerez/izleme için **önceden, açık ve ayrı** onay gerekir; "ziyaret ederek kabul" geçersiz. Çocuk ürününde reklam izleme ayrıca risk. → §4 K4. |
| X2 | Fotoğraf ve hizmet onayları "hizmeti kullanarak kabul edersiniz" diye **toplu** alınıyor | Açık rıza belirli konuya ilişkin ve özgür iradeyle olmalı; hizmet şartına bağlanamaz (KVKK md. 3, Kurul kararları). Bizde rızalar ayrı ekranda. |
| X3 | Kişisel verinin doğrudan pazarlama için **üçüncü taraflarla paylaşılabilmesi** | Bizde yok; olursa açık rıza + İYS (6563 s. Kanun) gerekir. |
| X4 | Değişiklik yayımlanınca yürürlüğe girer, **kullanmaya devam etmek kabul sayılır** | Genel işlem koşullarında esaslı değişiklik için açık kabul gerekir (TBK md. 20–25); bizde yeniden onay var. |
| X5 | Hizmete erişimi **hiçbir sebep göstermeden, bildirimsiz** kesme; tek taraflı fesih | Tüketiciye karşı haksız şart sayılabilir (6502 s. Kanun md. 5); bizde gerekçe + bildirim, kötüye kullanımda derhal. |
| X6 | Fiyatların **bildirimsiz** değişmesi | Bizde satıcı Apple; fiyat değişikliği Apple'ın bildirim kurallarıyla, sonraki dönemden. |
| X7 | Sorumluluğun **500 dolarla** sınırlanması; dolaylı zararların tamamen dışlanması | Ağır kusur ve kasttan sorumsuzluk geçersiz (TBK md. 115); tüketiciye karşı ağır sınırlama haksız şart olabilir. Bizde sınır yalnız uzman sözleşmesinde, kanuni istisnalar saklı. |
| X8 | "Kişisel verilerin gizliliğinden sorumlu tutulamayız" genel feragati | Veri güvenliği yükümlülüğü sözleşmeyle devredilemez (KVKK md. 12). |
| X9 | Kullanıcının platformu **tazmin etmesi** (indemnification) geniş biçimde | Tüketiciye karşı dengesiz; uzmanda yalnız kendi kusurlu beyanı/kullanımıyla sınırlı (sözleşme A10). |
| X10 | İadenin şirketin **takdirinde**, 30 gün içinde istenmesi | Satış Apple'da; iade Apple süreciyle, kanuni haklar saklı. |
| X11 | Delaware hukuku ve mahkemeleri, **1 yıllık dava süresi**, kazanan tarafın avukatlık ücreti | Tüketici uyuşmazlığında tüketici hakem heyeti / tüketicinin yerleşim yeri mahkemesi; zamanaşımı süreleri sözleşmeyle kısaltılamaz (TBK md. 148). |
| X12 | Şirketin sözleşmeyi **izinsiz devredebilmesi** | Bizde işletme devrinde önceden bildirim + hesabı silme hakkı (hukuk_notlari 3I9). |
| X13 | Çocuk fotoğraflarına erişim bir yerde "yetkili personel", başka yerde "tek bir kişi" — **iki metin birbiriyle çelişiyor** | Ders: bizde bütün metinler `00-olgular.md`'ye dayanır; olgu değişince önce orası. |
| X14 | Gmail/Takvim verisinin yapay zekâ sağlayıcısına (OpenAI) gönderilmesi | Bizde yapay zekâya veri gitmez; eklenirse §4 K2. |
| X15 | "Verdiğiniz bilginin doğru olması gerekmez" | Veli beyanı ve uzman beyanında doğruluk esastır. |

## 4. Bizim için çıkan kurallar (gelecek özellikler)

- **K1 — Çocukta veri toplayan yeni özellik** (fotoğraf, ses, konum, kamera ile çekim, serbest metin paylaşımı): ayrı veli onay ekranı (sürümlü, `acik-riza` ailesinde yeni anahtar), cihaz izni, ParentApp'te açık/kapalı ayarı, istenince geri alma ve silme; varsayılan **kapalı**; aydınlatma ve alt işleyen listesi önce güncellenir.
- **K2 — Yapay zekâ**: çocuğa açık her yapay zekâ özelliği için ayrı veli onayı; çocuk sesi/metni sağlayıcıda saklanmaz (sözleşmeyle), eğitim için kullanılmaz; yurt dışı aktarım KVKK md. 9; "tavsiye değildir" uyarısı; sağlık verisi yapay zekâya gönderilmez. Uzman tarafında da aynı (notlar yapay zekâya gitmez, aksi ayrı onay).
- **K3 — Aile dışı içerik**: çocuğun ailesi dışındaki biriyle (uzman dahil) içerik paylaşabildiği bir özellik eklenirse uygulama içi "bildir" düğmesi, inceleme süreci ve ebeveyne haber zorunlu.
- **K4 — Tanıtım sitesi ve reklam ölçümü** (pazarlama planındaki Meta/Instagram reklamları): sitede yalnız zorunlu çerezle açılır; reklam pikseli (Meta Pixel vb.) ya da analiz aracı **ancak çerez bandında "kabul" sonrası** yüklenir ("reddet" aynı kolaylıkta); gizlilik politikası, çerez politikası ve alt işleyen listesi önce güncellenir; uygulamaların içine reklam/izleme SDK'sı konmaz; çocuk uygulamasında hiçbir koşulda yok. Kurul Çerez Rehberi (2022), KVKK md. 5/1, md. 9.
- **K5 — Pazarlama iletisi**: e-posta/SMS ile tanıtım gönderilecekse ayrı onay + İYS kaydı + her iletide ret bağlantısı; hizmet iletileri (doğrulama, davet, şifre) ayrı tutulur.

## 5. Yapılan değişiklikler (27 Ekim 2026)

- `02-ornekler-ve-turk-hukuku.md`: Joon satırı eklendi.
- `40-cerez-politikasi.md`: tanıtım sitesi kuralı (K4) eklendi.
- `README.md`: dizine bu dosya; sorun 13 (tanışma sorularının hepsi atlanabilir olsun).

## Avukata notlar

1. J2/J3: tanışma sorularının hepsinin isteğe bağlı olması ve amaçlarının aydınlatmada somut yazılması yeterli mi; "davranış sıklığı" soruları sağlık verisi sayılır mı (`README` sorun 2)?
2. K4: tanıtım sitesinde reklam pikseli kullanılırsa Meta ile ortak veri sorumluluğu ve yurt dışı aktarım nasıl kurgulanmalı; çerez bandı metni.
3. J14: tersine mühendislik yasağının FSEK md. 38 istisnalarıyla birlikte yazımı.
