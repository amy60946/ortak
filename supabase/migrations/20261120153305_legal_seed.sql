-- Yasal metin taslakları (üretildi: python3 tools/legal_seed.py; kaynak ortak/hukuk/*.md). Elle düzenleme.
-- Önkoşul: migrations/20261027200000_legal.sql. Yalnız taslak satırlar güncellenir; yayımlanmış sürüm değişmez. Tekrar çalıştırılabilir.

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('gizlilik', 'v1', 'Gizlilik Politikası', '{parent,child,clinic,web}', false, $md$# Gizlilik Politikası

## Kısaca

> **Bir bakışta**
>
> **Ne topluyoruz?** Ebeveynin hesabı (ad, e-posta), ebeveynin eklediği çocuk profili (ad ya da takma ad, simge, yaş grubu), rutinler, adımlar ve onaylar, aile içi mesajlar, oyun kaydı, uzmanın ve ebeveynin girdiği takip kayıtları, abonelik durumu ve içeriği olmayan kullanım kayıtları.
>
> **Neden?** Uygulamaları çalıştırmak: çocuğun rutinlerini ve oyununu ebeveyne bağlamak, ebeveynin isterse uzmanıyla paylaşmasını sağlamak, aboneliği yönetmek, hizmeti güvenli tutmak ve iyileştirmek.
>
> **Kim görür?** Yalnız kendi aileniz. Uzman yalnız siz izin verdiğinizde ve yalnız izin verdiğiniz çocuğu görür; izni istediğiniz an geri alırsınız. Ekibimiz yalnız gerektiğinde, iki adımlı girişle, gerekçe yazarak ve kayıt altında bakar; mesajlarınızı, fotoğraflarınızı, ses kayıtlarınızı ve uzman notlarının metnini göremez.
>
> **Ne yapmıyoruz?**
> - Reklam göstermiyoruz.
> - Verinizi satmıyor, kiralamıyor, pazarlama için kimseyle paylaşmıyoruz.
> - Sizi ya da çocuğunuzu izlemiyoruz: üçüncü taraf reklam, analiz ya da izleme aracı kullanmıyoruz.
> - Verinizi yapay zekâ hizmetlerine göndermiyoruz.
> - Çocuktan e-posta, telefon, konum, fotoğraf ya da ses almıyoruz. Çocuk yalnız kendi ailesiyle yazışır.
> - Hiçbir gösterge tanı ya da puan değildir.
>
> **Haklarınız:** Verinizi görebilir, düzeltebilir, silebilir, hesabınızı uygulamanın içinden kapatabilirsiniz. Başvuru: uygulamada Yasal ve gizlilik › KVKK başvurusu ya da `destek@moyoapp.com.tr` (konu: "KVKK başvurusu"). 30 gün içinde ücretsiz yanıt veririz.

## 1. Biz kimiz, bu metin neyi kapsar?

"Moyo" ya da "Platform": [AD SOYAD] tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer. Bu politika Moyo'nun üç uygulamasını, bu uygulamaların internet sayfalarını ve gönderdiği e-postaları kapsar:

- **Moyo Ebeveyn**: ebeveyn uygulaması (iOS; telefonda "Moyo" adıyla görünür),
- **Moyo Oyun**: çocuğun oyunu (iOS),
- **Moyo Mercek (ailelere dönük ekranlarda Moyo Uzman)**: uzman uygulaması (iPad ve web).

Kişisel verilerinizin veri sorumlusu:
**[AD SOYAD]**, [ADRES], MERSİS/VKN: [MERSİS/VKN]
E-posta: `destek@moyoapp.com.tr` (bütün konular; kişisel veri başvurularında konu satırına "KVKK başvurusu" yazmanızı rica ederiz).

Bu metinde "biz", Moyo'yu işleten bu kişiyi (veri sorumlusunu) anlatır.

Bu politika genel çerçevedir. Hangi verinin hangi hukuki sebeple işlendiğini kişiye göre ayrı ayrı anlatan metinlerimiz şunlardır:

| Kim için | Metin |
|---|---|
| Ebeveynler | Ebeveyn Aydınlatma Metni ([Moyo Ebeveyn Aydınlatma Metni](/yasal/aydinlatma-ebeveyn)) |
| Uzmanlar | Uzman Aydınlatma Metni ([Moyo Mercek Uzman Aydınlatma Metni](/yasal/aydinlatma-uzman)) |
| Moyo Oyun'u oynayan çocuk ve velisi | Çocuk ve Veli Aydınlatma Metni ([Moyo Oyun Aydınlatma Metni (Veli ve Çocuk)](/yasal/aydinlatma-cocuk)) |

Bu politika ile aydınlatma metinleri birlikte okunur.

**Hizmetimizin sınırı:** Moyo sağlık hizmeti sunmaz, tanı koymaz, tedavi önermez; hiçbir gösterge tanı ya da puan değildir. Acil durum ve kriz hizmeti değildir; acil durumda **112** aranır. Moyo sağlık hizmeti, uzaktan sağlık hizmeti ya da tıbbi cihaz değildir; tıbbi bir amaçla tasarlanmamıştır. Uzman istihdam etmeyiz; uzman ile aile arasında aracılık ya da yönlendirme yapmayız. Moyo Mercek, uzmanın kendi tanıdığı aileyle çalışması için bir araçtır.

**Kayıtların niteliği:** Uygulamadaki kayıtlar, kullanıcıların kendi girdiği takip kayıtlarıdır. Moyo bu kayıtları saklar ve gösterir; bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz.

**Genel ilke:** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

## 2. Moyo Oyun

**Nasıl bağlanır?** Çocuğun e-postası ya da şifresi yoktur. Ebeveyn, Moyo Ebeveyn'de çocuğu için bir profil oluşturur. Sonra Moyo Ebeveyn'in gösterdiği 15 dakika geçerli, tek kullanımlık kodu ya da QR kodu çocuğun cihazına girer. Cihaz bu profile bağlanır ve cihazda kimliği belirsiz bir oturum açılır.

**İşlediğimiz veriler:**
- Ebeveynin girdiği bilgiler: çocuğun adı ya da takma adı, simgesi, yaş grubu.
- Cihazın oturum kimliği (rastgele bir kimlik).
- Oyun kaydı: seviye, deneyim puanı, evcil hayvanın durumu, eşyalar, ada düzeni, coin harcamaları.
- Ebeveynin eklediği rutin ve adımlar (oyunda "macera" olarak görünür) ve çocuğun "Yaptım" işaretleri.
- Çocuğun ebeveynine gönderdiği mesajlar (yazı ve hazır çıkartma) ve ödül istekleri.
- Bildirim gönderebilmek için cihazın bildirim anahtarı.
- Kullanım kayıtları (bkz. 5. bölüm).

**İşlemediğimiz veriler:** Çocuktan e-posta, telefon, şifre, konum, fotoğraf, ses, rehber bilgisi almayız. Reklam kimliği kullanmayız.

**Kamera:** Yalnız ebeveynin gösterdiği QR kodu okumak için ve yalnız o ekranda açılır. Görüntü kaydedilmez, hiçbir yere gönderilmez.

**Satın alma ve reklam:** Moyo Oyun'da uygulama içi satın alma ve reklam yoktur. Dış bağlantılar ve ayarlar ebeveyn kapısının arkasındadır.

**Coin:** Oyundaki coin yalnız ebeveynin onayladığı maceralarla kazanılır ve yalnız oyun içi eşyalara harcanır. Para değildir, satın alınamaz, paraya çevrilemez.

**Kim görür?** Ailedeki ebeveynler. Ebeveyn çocuğu bir uzmanla paylaşırsa uzman çocuğun rutinlerini, adımlarını ve "Yaptım" kayıtlarını görür; oyun kaydını, coin'i ve aile içi mesajları görmez.

## 3. Moyo Ebeveyn

**Hesap:** Ad, takma ad, simge, e-posta. Şifreniz bizde açık hâlde durmaz; yalnız kimlik doğrulama sağlayıcımızda geri çevrilemez biçimde (özetlenmiş) saklanır.

**Aile ve çocuklar:** Aile adı; çocuk profilleri (ad ya da takma ad, simge, yaş grubu; isteğe bağlı cinsiyet ve doğum günü). Ailenize ikinci bir ebeveyn davet edebilirsiniz; o da aile verisini görür.

**Günlük kullanım:** Rutinler ve adımlar, tekrarlar, hatırlatmalar; çocuğun "Yaptım"ları ve sizin onayınız ya da reddiniz (isteğe bağlı not ve neden); ödüller; Güneş Taşı ve coin hareketleri (taş düşürdüğünüzde yazdığınız neden dahil).

**Mesajlar:** Çocuğunuzla aranızdaki yazılar, fotoğraflar, sesli mesajlar, çıkartmalar ve okundu bilgisi. Fotoğraf ve sesler yalnız ailenize açık, özel bir depolama alanında tutulur.

**Davranış kayıtları:** Yaşanan zor bir anın öncesi, davranış ve sonucu; şiddet derecesi; isteğe bağlı ses kaydı.

**Davranış olayları:** Uzmanınız bir hedef davranış için kayıt istediyse bildirdiğiniz olaylar: tarih ve saat; kayıt türüne göre kaç kez olduğu, öncesi ve sonrası ya da süresi; denediğiniz strateji ve çocuğun buna tepkisi (sizin gözleminizdir, puan değildir).

**Ebeveyn eğitimi:** Uzmanınız size bir eğitim atadıysa tamamladığınız modüller, test yanıtlarınız ve doğru sayısı, açık uçlu yanıtlarınız, uygulama kayıtlarınız (sayı ve isteğe bağlı kısa düşünce) ve tamamladığınız yapılacaklar (nasıl geçtiği ve isteğe bağlı kısa düşünce).

Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Serbest metin alanlarına tanı, ilaç ya da sağlık bilgisi yazmamanızı isteriz. Yine de bu alanlara yazılanlar dahil bütün kayıtlarınız korunur: başka aileler göremez, bir uzmana yalnız açık rızanızla açılır.

**Tanışma yanıtları:** İlk kurulumda verdiğiniz yanıtlar (hedefler, bizi nereden duyduğunuz, çocuğun düzeni, geçen haftaki bazı günlük davranışların ne sıklıkta olduğu, ilgi alanları, motive edenler gibi). Bunları uygulamayı size göre ayarlamak, size destek vermek ve **kimliksiz toplamlar** hâlinde ürünü geliştirmek için kullanırız.

**Uzman paylaşımı ve takip planı:** Uzmanla paylaşım onaylarınız (hangi metnin hangi sürümünü, ne zaman onayladığınız); uzmanın gönderdiği takip planını uygulama kayıtlarınız ("bugün uyguladım", zorluk derecesi, uygulayamama nedeni). Ayrıntı 8. bölümde.

**Abonelik:** Aile aboneliği App Store üzerinden satılır; satıcı Apple'dır. Kart bilgileriniz bize gelmez. Biz yalnız aboneliğin durumunu (ürün, dönem sonu, işlem kimliği) görürüz. Ücretsiz deneme hakkının tekrar tekrar kullanılmasını önlemek için e-posta adresinizin geri çevrilemez özetini (SHA-256) saklarız; bu özet hesabınızı silseniz de denemenin başladığı tarihten 2 yıl boyunca kalır.

**İzinler:** Mikrofon (sesli mesaj ve davranış kaydındaki ses kaydı için, yalnız siz kayda bastığınızda), fotoğraflar (mesaja fotoğraf eklemek için), bildirimler. İzinleri telefonunuzun ayarlarından istediğiniz an kapatabilirsiniz.

**Kim görür?** Ailenizdeki diğer ebeveyn(ler). Çocuğunuz oyunda kendi maceralarını, sizinle yazışmalarını ve ödüllerini görür. Uzman yalnız sizin izninizle (8. bölüm).

## 4. Moyo Mercek

**Hesap:** Ad, unvan, e-posta, klinik adı, ekipteki rol.

**Karşılama anketi:** Meslek, karşılaşılan zorluklar, yararlı bulunan özellikler, gelme nedeni. Kimliksiz toplamlar hâlinde ürünü geliştirmek için kullanılır.

**Aileyle ilgili kayıtlar:** Uzmanın birlikte çalıştığı aile için girdiği notlar (aile görmez), hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (uzman gönderince aile görür), kayıt istediği hedef davranışlar ve stratejileri, atadığı ebeveyn eğitimleri ve bu eğitimler için girdiği gözlem verisi (aile görmez), etiketler. Uzman bu alanlara tanı, ilaç ya da sağlık bilgisi yazmamaya özen gösterir.

**Davet bilgileri:** Uzman bir aileyi davet ederken ebeveynin adını ve e-postasını, çocuğun adını ya da takma adını ve yaş grubunu girer. Bu bilgi yalnız daveti iletmek ve ebeveynin onayına sunmak için tutulur. Kullanılmayan davet 3 günde, bağlanmış ama onaylanmamış davet en geç 30 günde silinir. Davet 3 gün geçerlidir; davet başına ebeveyne en çok 3 e-posta (ilk gönderim ve yeniden gönderimler) gider. Bu e-postalar reklam içermez; çocuğun adı ve sağlık bilgisi e-postaya yazılmaz.

**Abonelik:** Klinik üyeliği App Store üzerinden satılır; kart bilgisi bize gelmez.

**Web:** Moyo Mercek'in web sürümü yalnız oturumu açık tutmak ve seçimlerinizi hatırlamak için zorunlu tarayıcı depolaması kullanır; analiz ya da reklam çerezi yoktur. Ayrıntı: Web Çerez Politikası ([Moyo Mercek Web Çerez Politikası](/yasal/cerez-clinicapp-web)).

**Uzmanın aile kayıtlarında rolümüz:** Uzmanın birlikte çalıştığı aile hakkında girdiği notlar, hedefler, değerlendirmeler, takip planı ve öteki kayıtlar bakımından veri sorumlusu uzman ya da kliniğidir; biz bu kayıtları onun adına ve talimatıyla saklayan **veri işleyeniz**. Uzman girdiği her kaydı kendi beyanıyla ve kendi sorumluluğunda girer; Moyo bu içeriği denetlemez, doğrulamaz, bunun için sorumluluk ya da yükümlülük üstlenmez. Bu kayıtlarla ilgili başvurular öncelikle uzmana ya da kliniğe yapılır; biz uzmana teknik olarak yardım ederiz.

## 5. Üç uygulamada ortak kayıtlar

- **Kullanım kayıtları:** Uygulamayı açtığınız günler, oturum sayısı, uygulama sürümü, platform ve hangi ekranın ya da özelliğin kullanıldığını gösteren olay adları. Bu kayıtlarda serbest metin, mesaj içeriği ya da sağlık bilgisi yoktur. Kendi sunucumuzda tutulur; üçüncü taraf analiz aracına gitmez. Amaç: hizmetin çalıştığını ölçmek, hataları bulmak, ürünü geliştirmek.
- **Bildirim kayıtları:** Size giden uygulama içi bildirimler ve okunup okunmadığı. Anlık bildirimin başlığında ya da metninde çocuğunuzun adı geçebilir (ör. "Efe adımı tamamladı"); bu metin Apple'ın bildirim hizmetiyle (yedek yolda Expo üzerinden) telefona iletilir. Bildirim metnine sağlık bilgisi konmaz.
- **Giriş kodu deneme kayıtları:** Kod tahminiyle kötüye kullanımı önlemek için hatalı denemeler IP adresiyle birlikte kısa süre (15 dakika ile 1 gün arası) tutulur.
- **Onay kayıtları:** Hangi metni (Kullanım Koşulları, aydınlatma metni, açık rızalar) hangi sürümüyle ve ne zaman onayladığınız.
- **Ekip işlemleri kaydı:** Ekibimizin hesabınızda yaptığı her işlem gerekçesiyle, değiştirilemez bir kayda yazılır.
- **Destek ve başvurular:** Destek formundan ya da e-postayla yazdığınızda e-posta adresiniz, (yazdıysanız) adınız, seçtiğiniz uygulama ve konu, mesajınız ve yazışmamız; KVKK başvurularınızın kaydı. Destek formu yetişkinler içindir.

## 6. Hangi amaçla ve hangi hukuki sebeple?

| Amaç | Hukuki sebep (KVKK) |
|---|---|
| Hesap açmak, aileyi ve çocuk profilini kurmak, çocuğun cihazını bağlamak, adım–onay–ödül akışını, mesajlaşmayı ve oyunu çalıştırmak | Sözleşmenin kurulması ve ifası (md. 5/2-c) |
| Aboneliği ve deneme süresini yönetmek | Sözleşmenin ifası (md. 5/2-c) |
| Deneme hakkının kötüye kullanımını önlemek, kod denemelerini sınırlamak, güvenlik ve ekip işlemlerini kayda almak | Meşru menfaat (md. 5/2-f) |
| İçeriksiz kullanım ölçümü, kimliksiz toplamlarla ürün geliştirme | Meşru menfaat (md. 5/2-f) |
| Ödeme kayıtlarını saklamak, resmî makamların usulüne uygun taleplerini yanıtlamak, KVKK başvurularını yanıtlamak | Hukuki yükümlülük (md. 5/2-ç) |
| Onay kayıtlarını ve ekip işlemleri kaydını hak ve savunmalarımız için saklamak | Bir hakkın tesisi, kullanılması veya korunması (md. 5/2-e) |
| Çocuğun ve uygulamada bıraktığınız kayıtların uzmanla paylaşılması; önceki uzman kayıtlarının yeni uzmana açılması | **Açık rıza** (md. 5/1 ve md. 6/3-a; serbest metne yazılmış olabilecek bilgiler için de koruma sağlar) — her biri ayrı ekranda, isteğe bağlı, istediğiniz an geri alınabilir |

Her işlemin ayrıntılı dayanağı ilgili aydınlatma metnindedir. Açık rıza vermemeniz uygulamanın temel kullanımını engellemez.

## 7. Çocukların gizliliği

- Çocuğun profilini ebeveyn (veli ya da yasal temsilci) oluşturur, yönetir ve siler. Çocuğun verisi velinin bilgisi ve kararıyla işlenir.
- Yaş çocuğa sorulmaz; doğum gününü ya da yaş grubunu ebeveyn girer.
- Çocuktan doğrudan iletişim bilgisi, konum, fotoğraf ya da ses alınmaz.
- Çocuk yalnız kendi ailesiyle yazışır; yabancıyla iletişim kurabileceği bir alan yoktur.
- Oyunda reklam, satın alma ve izleme aracı yoktur. Dış bağlantılar ebeveyn kapısının arkasındadır.
- Çocuğa oyunun içinde, yaşına uygun dille kısa bir bilgi gösterilir ([Moyo Oyun Aydınlatma Metni (Veli ve Çocuk)](/yasal/aydinlatma-cocuk)).
- Veli, çocuğun verisini Moyo Ebeveyn'den görür, düzeltir, siler; cihaz bağlantısını kapatabilir; çocuk adına KVKK başvurusu yapabilir.
- Çocuğun verisi bir uzmanla yalnız velinin açık rızasıyla paylaşılır.

## 8. Uzmanla paylaşım

- **Uzmanları doğrulamıyoruz.** Uzmanın kimliğini, unvanını ve meslek yetkisini kontrol etmeyiz; uzman hakkında bir doğrulama ya da yetki beyanı göstermeyiz. Uzmanın adı ve unvanı kendi beyanıdır. Paylaşmadan önce uzmanı gerçek hayatta tanıdığınızdan emin olun.
- **Paylaşımı siz başlatırsınız.** Uzmanın davetini açarsınız, çocuğun bilgisini kontrol edersiniz, "Bu uzmanı tanıyorum ve çocuğun velisiyim" kutusunu işaretler ve açık rıza verirsiniz.
- **Uzman ne görür?** Paylaştığınız çocuğun profil bilgilerini (ad ya da takma ad, simge, yaş grubu; girdiyseniz doğum günü ve cinsiyet), çocuğa verilen rutin ve adımları, "Yaptım" ve onay kayıtlarını, davranış kayıtlarını, bildirdiğiniz davranış olaylarını, ebeveyn eğitimindeki yanıtlarınızı (tamamlanan modüller, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar), uzmanın önerdiği derslerde uyguladığınız günleri, randevulara verdiğiniz yanıtları, takip planı uygulama kayıtlarınızı ve uzmanın önerilerine verdiğiniz kararları. Bunlar uygulamada bıraktığınız kayıtlardır. Uzman bu kayıtları yalnız sizin açık rızanızla görür; paylaşımı durdurduğunuz andan sonra yeni kayıtlarınızı göremez. Uzman bunları yalnız okur, değiştiremez. Aile içi mesajları, coin hareketlerini ve oyun kaydını görmez.
- **Siz ne görürsünüz?** Uzmanın gönderdiği rutin ve adım önerilerini, takip planını, size atadığı ebeveyn eğitimlerini ve kaydetmenizi istediği hedef davranışları. Uzmanın kendi notlarını ve gözlem verisini görmezsiniz.
- **Uzman değişirse:** İsterseniz, ayrı bir açık rızayla, önceki uzman(lar)ın kayıtları yeni uzmanınıza yalnız okunur olarak açılır. Önceki uzmanın adı ve iletişim bilgileri gösterilmez.
- **Geri alma:** Paylaşımı ve önceki kayıtların aktarımını Uzmanım bölümünden istediğiniz an durdurursunuz. Uzmanın erişimi hemen sona erer.
- **Davetten önce:** Uzmanınız sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz onaylayana kadar yalnız davet kaydında durur; onaylamazsanız ya da süre dolarsa silinir.
- **Uzman ile aile arasındaki ilişki:** Uzman ile aile arasındaki mesleki ilişki (hizmet, ücret, randevu, iletişim ve öneriler) yalnız onların arasındadır; Moyo bu ilişkinin tarafı, aracısı ya da güvencesi değildir. Her kullanıcı kendi girdiği kayıttan sorumludur.

## 9. Ekibimizin erişimi

Ekibimiz hesap bilgilerinize ve kullanım kayıtlarınıza yalnız şu amaçlarla bakar: destek talebinizi yanıtlamak, güvenlik ve kötüye kullanım incelemesi, abonelik sorunları ve kanuni yükümlülükler.

- Giriş iki adımlı doğrulamayla yapılır; her ekip üyesinin yalnız işine yeten bir rolü vardır.
- Bir şeyi değiştiren her işlem için gerekçe yazılır ve işlem değiştirilemez, silinemez bir kayda geçer.
- Mesaj içerikleri, fotoğraflar, ses kayıtları ve uzman notlarının metni ekip ekranlarında **gösterilmez**.
- Tanışma yanıtlarını kişi bazında yalnız yönetim panelinde sahip yetkisi olan kişi görür; yalnız destek için, gerekçe yazılarak açılır ve kayda geçer. Öteki ekip üyeleri yalnız kimliksiz toplamları görür.

## 10. Hizmet sağlayıcılarımız ve yurt dışına aktarım

Hizmeti sunmak için bizim adımıza ve talimatımızla çalışan hizmet sağlayıcılar kullanırız. Bunlar veriyi yalnız bu iş için işler, kendi amaçları için kullanamaz. Verinin bu sağlayıcılara ve yurt dışına aktarılmasının amacı yalnız hizmeti çalıştırmaktır (veritabanı, depolama, e-posta, ödeme, bildirim).

| Sağlayıcı | Ne için | Konum |
|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | Frankfurt, Almanya; AB bölgesi |
| Apple | App Store satışı ve aboneliği (satıcı Apple'dır), anlık bildirim (APNs) | ABD / AB |
| Expo | Yedek bildirim yolu: cihaz Expo bildirim anahtarı verirse bildirim Expo üzerinden Apple'a iletilir | ABD |
| RevenueCat | Abonelik durumunun doğrulanması | ABD |
| Resend | İşlem e-postaları (doğrulama, şifre sıfırlama, uzman daveti) | ABD / AB |
| Cloudflare | Ekip yönetim panelinin barındırılması | Küresel ağ |

Güncel ve ayrıntılı liste: **Hizmet Sağlayıcılar (Alt İşleyenler) Listesi** ([Hizmet Sağlayıcılar (Alt İşleyenler) Listesi](/yasal/alt-isleyenler)). Yeni bir sağlayıcı eklemeden önce listeyi güncelleriz.

**Yurt dışı:** Bu sağlayıcıların bazı sunucuları Türkiye dışındadır. Aktarımı KVKK md. 9'a uygun yaparız: Kişisel Verileri Koruma Kurulu'nun ilan ettiği standart sözleşmeyi imzalar ve imzadan sonra 5 iş günü içinde Kurul'a bildiririz. [Özel nitelikli veri içerebilecek kayıtlar için ek şart: avukat belirleyecek.]

**Apple:** App Store'dan satın aldığınızda satıcı Apple'dır; ödeme bilgileriniz Apple'ın kendi gizlilik politikasına tabidir.

**Kanuni zorunluluk:** Mahkeme, savcılık ya da yetkili bir kamu kurumunun usulüne uygun talebi olursa veriyi yalnız talep kapsamında paylaşırız. Kanun yasaklamıyorsa sizi bilgilendiririz.

**İşletme devri:** Moyo'nun işletmesi başka bir kişiye ya da şirkete devredilirse veriler aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa geçebilir. Bunu önceden bildiririz; hesabınızı silme hakkınız saklıdır.

## 11. Güvenlik

- Bütün bağlantılar şifrelidir (TLS).
- Veritabanında her kullanıcı yalnız kendi ailesini ya da kliniğini görebilir (satır düzeyi güvenlik). Çocuğun cihazı yalnız kendi profilini görür.
- Mesaj fotoğrafları ve ses kayıtları özel depolama alanlarında durur; yalnız kısa süreli, imzalı bağlantıyla açılır.
- Ekip paneli iki adımlı doğrulama, rol, gerekçe ve silinemez kayıtla korunur.
- Bir veri ihlali olursa yasal süreler içinde Kişisel Verileri Koruma Kurulu'na ve etkilenen kişilere bildiririz.

Hiçbir sistem kusursuz değildir. Şifrenizi kimseyle paylaşmayın; çocuğunuzun cihazına bağlantı kodunu yalnız siz girin.

## 12. Ne kadar saklıyoruz?

| Veri | Süre |
|---|---|
| Hesap, aile ve klinik verisi | Hesap silinene kadar; silince gecikmeden silinir |
| Uzmanın aile kayıtları | Klinik ya da (tek kişilik klinikte) uzman hesabı silinene kadar. Ebeveyn paylaşımı geri alınca uzmanın erişimi biter; uzman o andan sonraki kayıtları göremez. Aile ya da çocuk profili silinince o çocuğa ait uzman kayıtları da silinir. Kliniğin denemesi ya da üyeliği bitince kayıtlar silinmez; uzmanın erişimi kapanır, üyelik yenilenince açılır |
| Kullanılmayan davet bilgisi | 3 gün; bağlanmış ama onaylanmamış davet en geç 30 gün |
| Giriş kodu deneme kayıtları | 15 dakika ile 1 gün arası |
| Deneme hakkı kaydı (e-posta özeti) | Denemenin başladığı tarihten 2 yıl |
| Ekip işlemleri kaydı | 5 yıl; silinen kullanıcının e-postası bu kayda yazılmaz |
| Abonelik ve ödeme kayıtları | 10 yıl (vergi ve ticaret mevzuatının istediği süre) |
| Bildirim kayıtları | 12 ay; isterseniz daha önce silersiniz |
| Kullanım kayıtları | 25 ay; sonra yalnız kimliksiz toplamlar kalır |
| KVKK başvuru kayıtları | Başvuru kapandıktan sonra 3 yıl |
| Destek talepleri | Talep kapandıktan sonra 2 yıl; istenmeyen (spam) iletiler 30 gün |

Silinen veriler yedeklerden de en geç 30 gün içinde kendiliğinden çıkar. Süre dolan veriyi en geç 6 ayda bir yaptığımız periyodik imhayla siler, yok eder ya da kimliksiz hâle getiririz.

## 13. Hesabınızı silmek

- **Moyo Ebeveyn ve Moyo Mercek:** Moyo Ebeveyn'de Aile › Hesap › Hesabımı sil, Moyo Mercek'te Ayarlar › Hesabı sil. Ailede başka ebeveyn yoksa aile, çocuk profilleri ve onlara bağlı her şey (rutinler ve adımlar, mesajlar, fotoğraflar, ses kayıtları, coin ve taş hareketleri, oyun yedekleri, uzman paylaşımları ve uzmanın bu çocuklar için tuttuğu notlar, hedefler ve takip planı) silinir. Başka ebeveyn varsa aile onda kalır, yalnız sizin hesabınız silinir. Tek kişilik klinikte klinik ve kayıtları silinir; ekipte başka uzman varsa klinik kalır.
- **Moyo Oyun:** Çocuğun ayrı hesabı yoktur. Ebeveyn, Moyo Ebeveyn'den çocuğun cihaz bağlantısını kaldırabilir, çocuğun profilini ya da aileyi silebilir; oyunun bağlantısı kapanır.
- **Abonelik:** Hesabı silmek App Store aboneliğini durdurmaz. Aboneliği iPhone/iPad Ayarlar › [adınız] › Abonelikler'den ayrıca iptal edin.
- Kanunen saklamak zorunda olduğumuz kayıtlar (ör. ödeme kayıtları) ve ekip işlemleri kaydı, sizi doğrudan tanıtan bilgi (e-posta) çıkarılarak süresi dolana kadar saklanır.

## 14. Haklarınız ve başvuru

KVKK md. 11 uyarınca şunları isteyebilirsiniz: verinizin işlenip işlenmediğini öğrenmek; işlenmişse bilgi istemek; işleme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenmek; yurt içinde ya da yurt dışında kimlere aktarıldığını bilmek; eksik ya da yanlışsa düzeltilmesini, şartları oluşmuşsa silinmesini ya da yok edilmesini ve bunların aktarılan kişilere bildirilmesini istemek; yalnız otomatik sistemlerle yapılan bir analizin aleyhinize sonucuna itiraz etmek; kanuna aykırı işleme yüzünden zarara uğradıysanız zararın giderilmesini istemek.

**Kendiniz hemen yapabilecekleriniz:** profil ve çocuk bilgilerini düzeltmek, uzman paylaşımını geri almak, cihaz bağlantısını kapatmak, hesabınızı silmek.

**Başvuru yolları:** uygulamada Yasal ve gizlilik › KVKK başvurusu (Moyo Ebeveyn'de Aile › Hesap altında, Moyo Mercek'te Ayarlar altında; hesabınıza bağlıdır, kimliğinizi ayrıca kanıtlamanız gerekmez); `destek@moyoapp.com.tr` (kayıtlı e-posta adresinizden; konu satırına "KVKK başvurusu" yazın); [ADRES] adresine yazılı ve imzalı; KEP: [KEP ADRESİ].

Başvurunuzu en geç **30 gün** içinde **ücretsiz** yanıtlarız. Çocuğunuz adına veli olarak başvurabilirsiniz. Yanıttan memnun kalmazsanız Kişisel Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz. Ayrıntı: **KVKK Başvuru Usulü** ([KVKK Başvuru Usulü](/yasal/kvkk-basvuru)).

## 15. E-postalar ve bildirimler

Size yalnız hizmetle ilgili e-postalar göndeririz: e-posta doğrulama, şifre sıfırlama, uzman daveti, abonelik ve hesap bilgileri. Bunlar reklam içermez. Tanıtım ve kampanya bildirimi ya da e-postası yalnız ayrı izninizle gönderilir; bu izin Ayarlar'da ayrı bir anahtardır, kapalı başlar ve istediğiniz an kapatılır. İzin verirseniz bu iletileri kanunun öngördüğü kayıt sistemleri (İYS) üzerinden göndeririz. Hizmetle ilgili bildirimler ve e-postalar bu izne bağlı değildir. Hangi bildirimleri alacağınızı uygulamanın Ayarlar bölümünden seçersiniz; anlık bildirimleri telefonunuzun ayarlarından da kapatabilirsiniz. Telefonla (SMS) doğrulama bugün yoktur; açılırsa telefon numarasının nasıl işleneceği önceden ayrıca bildirilir.

## 16. Değişiklikler

Her metnin bir sürümü vardır (v1, v2 …). Yayımlanan bir sürüm değiştirilmez; değişiklik yeni sürümdür ve eski sürümler saklanır.

- **Önemli değişiklikte** (ör. yeni bir veri türü, yeni bir amaç, yeni bir yurt dışı sağlayıcı) uygulamayı açtığınızda neyin değiştiğini kısa bir özetle gösteririz. Onay gerektiren metinlerde yeniden onayınızı isteriz.
- **Küçük değişiklikte** (yazım, açıklama) bu sayfayı güncelleriz ve sürüm tarihini değiştiririz.

Yürürlük: [TARİH] · Sürüm: v1

## 17. İletişim

[AD SOYAD], [ADRES]
E-posta: `destek@moyoapp.com.tr` (kişisel veri başvurularında konu: "KVKK başvurusu")
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('aydinlatma-ebeveyn', 'v1', 'Moyo Ebeveyn Aydınlatma Metni', '{parent}', true, $md$# Moyo Ebeveyn Aydınlatma Metni

## Kısaca

- Veri sorumlusu, Moyo'yu işleten `[AD SOYAD]`. Sorularınız için: `destek@moyoapp.com.tr`.
- Hesabınızı, ailenizi, çocuklarınızın profilini, rutinleri, ödülleri ve mesajları yalnız uygulamayı çalıştırmak için işleriz.
- **Reklam yok. Verinizi satmayız. Sizi izlemeyiz:** reklam ağı, üçüncü taraf analiz ya da izleme aracı kullanmayız.
- Tanı ya da ilaç sormayız. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Not alanlarına tanı, ilaç ya da sağlık bilgisi yazmamanızı isteriz; bütün kayıtlarınızı ek önlemlerle koruruz.
- Çocuğunuzun kayıtları bir uzmanla yalnız siz seçerseniz ve ayrıca onay verirseniz paylaşılır. Paylaşılanlar uygulamada bıraktığınız kayıtlardır. Paylaşımı istediğiniz an durdurursunuz.
- Veriler hizmet sağlayıcılarımızın yurt dışındaki sunucularında da tutulabilir. Bunu KVKK'nın öngördüğü güvencelerle yaparız.
- Hesabınızı uygulamanın içinden silebilirsiniz. Ailede başka ebeveyn yoksa ailenin bütün verisi de silinir.
- Haklarınız için uygulama içinden ya da `destek@moyoapp.com.tr` adresine (konu: "KVKK başvurusu") yazın. 30 gün içinde ücretsiz yanıt veririz.

## Tam metin

### 1. Bu metin ne anlatır

1.1. Bu metin, Moyo Ebeveyn'i (telefonda görünen adı "Moyo") kullanan ebeveynlere kişisel verilerinin nasıl işlendiğini anlatır. 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) md. 10 gereği hazırlanmıştır.

1.2. Moyo Ebeveyn'e eklediğiniz çocukların verisini veli ya da yasal temsilci olarak siz yönetirsiniz. Bu nedenle çocuklarınızın Moyo Ebeveyn'deki verisi de bu metindedir. Çocuğunuzun Moyo Oyun'da oluşan verisi ayrıca **Moyo Oyun Aydınlatma Metni**'nde ([Moyo Oyun Aydınlatma Metni (Veli ve Çocuk)](/yasal/aydinlatma-cocuk)) anlatılır.

1.3. Bu metni okumanız bir onay ya da açık rıza değildir. Açık rıza gereken işlemler (uzmanla paylaşım, önceki uzman kayıtlarının aktarımı) ayrı ekranlarda, ayrı metinlerle sorulur. Onay vermemeniz Moyo Ebeveyn'i kullanmanızı engellemez.

1.4. **Genel ilke.** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

### 2. Veri sorumlusu

| | |
|---|---|
| Ad soyad | `[AD SOYAD]` (Moyo'yu işleten gerçek kişi) |
| Adres | `[ADRES]` |
| MERSİS / VKN | `[MERSİS/VKN]` |
| İletişim (KVKK başvuruları dahil) | `destek@moyoapp.com.tr` (KVKK başvurusunda konu: "KVKK başvurusu") |

"Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer. Moyo Ebeveyn, Moyo Oyun ve uzmanların kullandığı Moyo Uzman aynı veri sorumlusunun ürünleridir ve aynı sunucuları kullanır.

### 3. Hangi verileri işliyoruz

| Kategori | Veriler |
|---|---|
| **Kimlik ve iletişim** | Adınız, takma adınız, seçtiğiniz simge, e-posta adresiniz |
| **Hesap güvenliği** | Şifreniz (yalnız kimlik doğrulama hizmetinde, geri çevrilemez biçimde özetlenmiş olarak; biz göremeyiz), oturum bilgisi, kod giriş denemeleri (IP adresi dahil), deneme hakkı geçmişi (e-posta adresinizin geri çevrilemez özeti) |
| **Aile ve çocuk profili** | Aile adı; çocuğun adı ya da takma adı, simgesi, yaş grubu; isteğe bağlı cinsiyet ve doğum günü |
| **Rutin ve ödül kayıtları** | Rutinler ve adımlar, tekrarlar, hatırlatmalar; çocuğun "Yaptım" ve "Yapamam" işaretleri; onay ya da ret kararınız ve isteğe bağlı notunuz; coin hareketleri; Güneş Taşı hareketleri (taş düşürürken yazdığınız neden dahil); ödülleriniz ve çocuğun ödül istekleri; kendi adımlarınız, Güneş Taşlarınız ve çocuğunuza oyunda gönderdiğiniz hediyeler |
| **Mesajlar** | Siz ve çocuğunuz arasındaki yazılar, fotoğraflar, sesli mesajlar, çıkartmalar; okundu bilgisi |
| **Davranış kayıtları ve olaylar** | Davranış kaydı: öncesi, davranış, sonucu, sizin verdiğiniz şiddet derecesi (1–5) ve isteğe bağlı ses kaydı. Davranış olayı (uzmanınızın tanımladığı hedef davranış için bildirdiğiniz): zaman, sayı ya da süre, öncesi ve sonrası, denediğiniz strateji, çocuğun tepkisi (1–5) ve yazdığınız açıklama. Derece ve tepki sizin gözleminizdir; puan ya da tanı değildir. |
| **Tanışma yanıtları** | İlk kurulumdaki sorular: hedefleriniz, bizi nereden duyduğunuz, rutin ve hatırlatma yüzünden tartışma sıklığı, çocuğun günlük düzeni, geçen hafta bazı günlük davranışların sıklığı (ör. sırasını beklemekte ya da bir işten ötekine geçerken zorlanma), çocuğun bir uzmanla çalışıp çalışmadığı, çocuk için hedefleriniz, ilgi alanları, onu motive eden şeyler. Yanıtlar hazır seçeneklerdir; tanı ya da ilaç sorulmaz. |
| **Ebeveyn eğitimi** | Uzmanınızın atadığı eğitimde: tamamladığınız modüller, test ve açık uçlu sorulara yanıtlarınız, uygulama kayıtlarınız ve yazdığınız düşünce, yapılacak işaretleriniz ve "Nasıl geçti?" yanıtınız. Kısa ebeveyn derslerinde (kendi seçtiğiniz ya da uzmanınızın önerdiği) ilerlemeniz ve uyguladığınız günler. Test sonucu sizin bilgi yoklamanızdır, çocuğa ait bir puan değildir. |
| **Uzmanla ilgili kayıtlar** | Hangi çocuğu hangi uzmanla paylaştığınız; onaylarınızın metin sürümü ve zamanı; önceki uzman kayıtlarının aktarım izni; uzmanın rutin ve adım önerilerine verdiğiniz kararlar; uzmanın açtığı randevulara verdiğiniz yanıt ("Geleceğiz" / "Uygun değil") ve notunuz; takip planında "Bugün uyguladım" kayıtlarınız, bildirdiğiniz zorluk (1–5) ve uygulayamama nedeni. Zorluk bildirimi puan değildir. |
| **Uzmanın davetle getirdiği bilgiler** | Uzman sizi davet ederken e-posta adresinizi ve çocuğunuzun adını ve yaş grubunu girmiş olabilir (bkz. 5.4) |
| **Abonelik** | Plan, dönem sonu, abonelik durumu, mağaza işlem kimliği, deneme başlangıcı. **Kart bilgileriniz bize gelmez; Apple'da kalır.** |
| **Cihaz ve kullanım** | Bildirim jetonu; size giden bildirimler ve okunup okunmadığı; uygulamayı açtığınız günler, oturum sayısı, uygulama sürümü, platform, kullandığınız ekran ve özelliklerin adları. Bu kayıtlarda serbest metin, mesaj ya da kayıt içeriği yoktur. |
| **Destek ve denetim** | Bize yazdığınız destek e-postaları; yetkili ekip üyelerinin hesabınızda yaptığı işlemlerin gerekçeli kaydı |
| **Onay kayıtları** | Hangi metni (Kullanım Koşulları, aydınlatma, açık rızalar) hangi sürümle ve ne zaman onayladığınız |

Kart bilgisi, T.C. kimlik numarası, konum, tanı ya da ilaç bilgisi istemeyiz. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Not ve açıklama alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazmamanızı rica ederiz. Bu alanlara yine de böyle bir bilgi yazılırsa kayıt aynı güvenlik önlemleriyle korunur ve bir uzmana yalnız açık rızanızla açılır.

### 4. Amaçlar ve hukuki sebepler

Her işlemin dayanağı KVKK'daki şu şartlardır: **md. 5/2-c** sözleşmenin kurulması ve ifası · **md. 5/2-ç** hukuki yükümlülüğümüz · **md. 5/2-e** bir hakkın kurulması, kullanılması ya da korunması · **md. 5/2-f** temel hak ve özgürlüklerinize zarar vermeyen meşru menfaatimiz · **md. 5/1 ve md. 6/3-a** açık rıza.

| # | Ne için | Hangi veri | Hukuki sebep |
|---|---|---|---|
| 1 | Hesap açmak, giriş, e-posta doğrulama, şifre sıfırlama | Kimlik ve iletişim, hesap güvenliği | md. 5/2-c |
| 2 | Aileyi ve çocuk profillerini kurmak; çocuğu 15 dakikalık tek kullanımlık kod ya da QR ile Moyo Oyun'a bağlamak | Aile ve çocuk profili | md. 5/2-c (veli olarak sizinle kurulan sözleşme) * |
| 3 | Rutin, adım onayı, coin, Güneş Taşı, ödül ve hediyeleri, kendi seçtiğiniz kısa ebeveyn derslerini çalıştırmak | Rutin ve ödül kayıtları; ebeveyn eğitimi (ders ilerlemesi) | md. 5/2-c |
| 4 | Siz ve çocuğunuz arasında mesajlaşma | Mesajlar | md. 5/2-c |
| 5 | Davranış kaydı tutmanız | Davranış kayıtları (davranış kaydı) | md. 5/2-c * |
| 6 | Uygulamayı ailenize göre düzenlemek, destek vermek | Tanışma yanıtları | md. 5/2-c; destek için md. 5/2-f * |
| 7 | Ürünü geliştirmek: yanıtların **kimliksiz toplamları**, "bizi nereden duydunuz" | Tanışma yanıtları | md. 5/2-f |
| 8 | Uzmanınızın atadığı ebeveyn eğitimini ve tanımladığı hedef davranışlar için olay bildirmenizi çalıştırmak; bunları uzmanınıza göstermek | Ebeveyn eğitimi, davranış olayları | md. 5/1 ve md. 6/3-a açık rıza (`uzman-paylasim-v1`) * |
| 9 | Çocuğunuzun kayıtlarını seçtiğiniz uzmanla paylaşmak | Uzmanla ilgili kayıtlar + paylaşılan kayıtlar (5.3) | md. 5/1 ve md. 6/3-a açık rıza (`uzman-paylasim-v1`) |
| 10 | Önceki uzmanın kayıtlarını yeni uzmana açmak | Önceki uzman kayıtları | md. 6/3-a açık rıza (`uzman-gecis-v1`) |
| 11 | Uzman davetini size iletmek ve hesabınızla eşleştirmek | Uzmanın davetle getirdiği bilgiler | md. 5/2-f * |
| 12 | Abonelik ve deneme süresini yönetmek | Abonelik | md. 5/2-c; kayıtların saklanması md. 5/2-ç |
| 13 | Deneme hakkının e-posta başına bir kez kullanılması | E-posta özeti | md. 5/2-f |
| 14 | Bildirim göndermek (cihazınızda izin verdiyseniz; hangi bildirimlerin geleceğini, ör. çocuğun oyunda işaretlediği adım bildirimlerini, Moyo Ebeveyn'in ayarlarından siz açıp kapatırsınız; tanıtım ve kampanya bildirimleri yalnız ayrı izninizle gelir, bu izin kapalı başlar) | Bildirim jetonu | md. 5/2-c |
| 15 | Hizmetin işleyişini ölçmek, hataları bulmak, ürünü geliştirmek | Kullanım kayıtları | md. 5/2-f |
| 16 | Güvenlik: kod deneme sınırı, kötüye kullanım incelemesi, denetim kaydı | Hesap güvenliği, destek ve denetim | md. 5/2-ç (KVKK md. 12 güvenlik yükümlülüğü) ve md. 5/2-f |
| 17 | Destek taleplerinizi yanıtlamak | Talebe göre gereken veriler | md. 5/2-c ve md. 5/2-f |
| 18 | Hangi metni onayladığınızı ispat etmek | Onay kayıtları | md. 5/2-ç ve md. 5/2-e |
| 19 | Mahkeme ya da yetkili kurumların usulüne uygun talepleri | Talep kapsamındaki veriler | md. 5/2-a ve md. 5/2-ç |
| 20 | Hukuki uyuşmazlıklarda hakkımızı korumak | Uyuşmazlıkla ilgili veriler | md. 5/2-e |

\* Avukatın teyit edeceği dayanaklar.

Verilerinizi reklam için kullanmayız, satmayız, profil çıkarmak için kullanmayız. Yapay zekâ hizmetlerine göndermeyiz.

### 5. Verileriniz kimlerle paylaşılır

**5.1. Ailenizdeki diğer ebeveyn.** Aileye ikinci bir ebeveyn katılırsa aile verisini (çocuk profilleri, rutinler, ödüller, mesajlar, davranış kayıtları ve olaylar, uzman paylaşımları) o da görür ve yönetir. Uzmanın size atadığı ebeveyn eğitimini görür, ama sizin yerinize işaretleyemez.

**5.2. Çocuğunuzun Moyo Oyun cihazı.** Bağlı cihaz yalnız o çocuğun profilini, maceralarını (sizin verdiğiniz adımlar oyunda macera olarak görünür), ona yazdığınız mesajları, ona açık ödülleri ve kendi coin ve Güneş Taşı hareketlerini görür. Kardeşler birbirinin mesajlarını görmez.

**5.3. Uzman — yalnız açık rızanızla.** Bir uzmanın davetini onaylar ve çocuğunuzu seçerseniz:
- **Kim görür:** davet eden uzman; o kliniğin sahibi; klinik sahibinin bu paylaşımı atadığı ekip üyeleri.
- **Ne görür (uygulamada sizin bıraktığınız kayıtlar):** çocuğun profil bilgileri; rutinleri, adımları ve atamaları; "Yaptım" kayıtları ve onay/ret kararlarınız; davranış kayıtları ve ses kayıtları; uzmanın tanımladığı hedef davranışlar için bildirdiğiniz **davranış olayları**; uzmanın atadığı **ebeveyn eğitimindeki yanıtlarınız** (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları ve düşünceniz, yapılacak işaretleri ve "Nasıl geçti?" yanıtınız); uzmanın önerdiği derslerde, öneriden sonra uyguladığınız günler; randevulara verdiğiniz yanıt ve notunuz; takip planı uygulama kayıtlarınız; rutin ve adım önerilerine kararlarınız. Paylaşımdan önceki rutin ve davranış kayıtlarının geçmişi de görünür.
- **Ne görmez:** mesajlarınız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı, tanışma yanıtlarınız, kendi seçtiğiniz dersler.
- Uzman bu kayıtları **yalnız okur**, değiştiremez. Size rutin ve adım önerebilir, ebeveyn eğitimi atayabilir, hedef davranış tanımlayabilir, randevu açabilir ve takip planı gönderebilir; kabul edip etmemek, uygulayıp uygulamamak size kalmıştır.
- **Durdurma:** Uzmanım bölümünden (uzmanın sayfasında Uzmanı yönet › çocuğu ayır ya da uzmanı kaldır) paylaşımı durdurduğunuz an uzmanın erişimi biter ve uzman o andan sonraki kayıtlarınızı göremez; o uzmanla yürüttüğünüz ebeveyn eğitimi, olay bildirimi ve randevular da size ve uzmana kapanır. Uzmanın o güne kadar Moyo Uzman'a yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır; bu kayıtları siz görmezsiniz.
- **Önceki uzmanın kayıtları:** Takibi başka bir uzmana taşırsanız ve ayrıca izin verirseniz, önceki uzmanın notları, hedefleri, haftalık değerlendirmeleri, rutin ve adım önerileri, aile programı ve sizin uygulama kayıtlarınız yeni uzmana **yalnız okunur** olarak açılır. Amaç takibin kesintisiz sürmesidir. Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez. Bu izni Uzmanım bölümünden istediğiniz an geri alırsınız; erişim hemen biter.
- **Uzmanlar doğrulanmaz.** Platform uzmanın kimliğini, unvanını ve meslek yetkisini doğrulamaz; uzman hakkında bir doğrulama, yetki beyanı ya da hizmet kalitesi taahhüdü vermez. Uzmanın adı ve unvanı kendi beyanıdır. Paylaşmadan önce uzmanı gerçek hayatta tanıdığınızdan emin olun.
- **Uzman ile aile arasındaki ilişki.** Uzman ile aile arasındaki mesleki ilişki (hizmet, ücret, randevu, iletişim ve öneriler) yalnız onların arasındadır; Moyo bu ilişkinin tarafı, aracısı ya da güvencesi değildir. Her kullanıcı kendi girdiği kayıttan sorumludur.

**5.4. Uzmanın davetinde gelen bilgiler.** Uzmanınız sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz kontrol edip onaylayana kadar yalnız davet kaydında tutulur ve size gösterilir; onaylamazsanız ya da davet süresi dolarsa silinir. Onayladığınızda çocuğunuzun kaydı sizin düzelttiğiniz bilgiyle oluşur ve seçtiğiniz uzmanla paylaşılır.
Uzman e-posta adresinizi de girmiş olabilir. Bu adresi yalnız tek bir davet e-postası (en çok 3 kez yeniden gönderim) iletmek ve kayıt olduğunuzda daveti eşleştirmek için kullanırız; pazarlama için kullanmayız. Davet sizin ailenize bağlanmazsa 3 günde, bağlanıp onaylanmazsa en geç 30 günde silinir. "Bu davet bana ait değil" derseniz davet kapanır ve uzmanın girdiği çocuk bilgisi silinir.

**5.5. Hizmet sağlayıcılar (veri işleyenler).** Hizmeti sunmak için aşağıdaki sağlayıcılarla çalışırız. Bu sağlayıcılar verinizi yalnız bizim adımıza ve talimatımızla işler; kendi amaçları için kullanmaz.

| Sağlayıcı | Ne için | Hangi veri | Konum |
|---|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | Bu metindeki bütün veriler | Frankfurt, Almanya; AB bölgesi |
| Apple | Bildirim gönderimi (APNs) | Bildirim jetonu, bildirim içeriği | ABD / AB |
| Expo | Yedek bildirim yolu: cihaz Expo bildirim anahtarı verirse bildirim Expo üzerinden Apple'a iletilir | Bildirim jetonu, bildirim başlığı ve metni | ABD |
| RevenueCat | Abonelik durumunu doğrulama | Rastgele uygulama kullanıcı kimliği, satın alma kayıtları | ABD |
| Resend | İşlem e-postaları (doğrulama, şifre sıfırlama, uzman daveti) | E-posta adresi, e-postanın içeriği | ABD / AB |
| Cloudflare | Yönetim panelinin barındırılması | Yetkili ekip üyesinin ekranında açılan veriler | Küresel |

Abonelik satışını **Apple** yapar. Satın alma sırasında Apple'a verdiğiniz bilgiler (ödeme bilgisi dahil) Apple'ın kendi gizlilik koşullarına tabidir; bunlar bize gelmez. Apple bize yalnız abonelik durumunu ve işlem kimliğini iletir.

**5.6. Yurt dışına aktarım.** Yukarıdaki sağlayıcıların sunucuları Türkiye dışında olabilir. Aktarımın amacı yalnız hizmeti çalıştırmaktır (veritabanı, depolama, e-posta, ödeme, bildirim). Verilerinizi yurt dışına KVKK md. 9'a uygun olarak aktarırız: Kişisel Verileri Koruma Kurulu'nun ilan ettiği standart sözleşmeyi sağlayıcıyla imzalar, imzadan sonra 5 iş günü içinde Kurul'a bildiririz (ya da varsa yeterlilik kararına dayanırız). Davranış kayıtları ve olaylar, ebeveyn eğitimi yanıtları, not alanları ve uzmanla paylaşılan kayıtlar da bu sunucularda saklanır.

**5.7. Yetkili kurumlar.** Mahkeme, savcılık ya da yetkili bir kamu kurumunun usulüne uygun talebi olursa veriler, talebin kapsamıyla sınırlı olarak aktarılabilir. Kanun yasaklamıyorsa sizi bilgilendiririz.

**5.8. İşletme devri.** Birleşme, devir ya da varlık satışı olursa veriler aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa geçebilir. Sizi önceden bilgilendiririz; hesabınızı silme hakkınız saklıdır.

**5.9. Yetkili ekibimizin erişimi.** Ekibimizin yetkili üyeleri yalnız destek talebinizi yanıtlamak, güvenlik ve kötüye kullanım incelemesi, abonelik sorunları ve kanuni yükümlülükler için hesap bilgilerinize ve kullanım kayıtlarınıza erişebilir. Erişim iki adımlı girişle ve gerekçe yazılarak yapılır; her erişim değiştirilemez bir denetim kaydına geçer. **Mesaj içerikleri, fotoğraflar, ses kayıtları ve uzman notlarının metni ekip ekranlarında gösterilmez.** Tanışma yanıtlarınızı kişi bazında yalnız en yetkili rol (sahip) gerekçe yazarak açabilir; öteki ekip üyeleri yalnız kimliksiz toplamları görür.

### 6. Verileri nasıl topluyoruz

Verileri elektronik ortamda, otomatik ya da kısmen otomatik yollarla toplarız:
- Moyo Ebeveyn'e sizin girdiğiniz bilgilerden;
- çocuğunuzun Moyo Oyun'da yaptığı işlemlerden ("Yaptım", mesaj, ödül isteği);
- uzmanın sizi davet ederken girdiği bilgilerden (e-posta adresiniz, çocuğun adı ve yaş grubu);
- Apple ve RevenueCat'in bize ilettiği abonelik durumundan;
- uygulamayı kullanırken cihazınızdan kendiliğinden gelen bilgilerden (sürüm, platform, bildirim jetonu, kod denemelerinde IP adresi).

Hukuki sebepler 4. maddededir.

### 7. Ne kadar süre saklıyoruz

| Veri | Süre |
|---|---|
| Hesap, aile ve çocuk verisi (rutinler, mesajlar, ödüller, davranış kayıtları, tanışma yanıtları) | Hesap silinene kadar; silmede derhal |
| Ebeveyn eğitimi, davranış olayları, randevular | Uzmanla paylaşıma bağlıdır: paylaşım durunca size ve uzmana kapanır. Uzmanın hesabı ya da kliniği silinirse sizin girdiğiniz eğitim yanıtları, uygulama kayıtları, yapılacak işaretleri ve davranış olayları, size açılmış eğitimin içeriğiyle birlikte sizde salt okunur kalır; uzmanın bunlara erişimi kapanır. Aile ya da çocuk silinince hepsi silinir |
| Uzmanla paylaşım | Paylaşımı durdurana kadar. Uzmanın kendi notları: klinik ya da tek kişilik klinikte uzman hesabı silinene kadar |
| Uzman davetindeki bilgiler (e-posta, çocuk adı) | 3 gün (ailenize bağlanmamış davet) / en geç 30 gün (bağlanmış ama onaylanmamış davet) |
| Kod deneme kayıtları (IP dahil) | 15 dakika – 1 gün |
| Deneme hakkı geçmişi (e-posta özeti) | Denemenin başladığı tarihten 2 yıl — hesap silinse de bu süre boyunca kalır |
| Denetim kaydı | 5 yıl — silinen kullanıcının e-postası yazılmaz |
| Abonelik ve ödeme olayları | 10 yıl (vergi ve ticaret mevzuatı) |
| Bildirimler | 12 ay; isterseniz daha önce silersiniz |
| Kullanım kayıtları | 25 ay, sonra yalnız kimliksiz toplamlar |
| KVKK başvuruları | Başvuru kapandıktan sonra 3 yıl |
| Destek talepleri | Talep kapandıktan sonra 2 yıl |

Silinen veriler yedeklerden de en geç 30 gün içinde kendiliğinden çıkar. Süresi dolan veriyi siler, yok eder ya da anonim hâle getiririz. Bunu en geç altı ayda bir yaptığımız periyodik imha ile de denetleriz.

**Hesabınızı sildiğinizde:** kişisel verileriniz silinir. Ailede başka ebeveyn yoksa aile ve ona bağlı her şey (çocuk profilleri, rutinler, mesajlar, coin ve Güneş Taşı hareketleri, oyun yedekleri) de silinir. Ailede başka ebeveyn varsa aile verisi onun hesabında kalır. Kanunen saklamamız gereken kayıtlar (ör. ödeme kayıtları) ve denetim kaydı, sizi doğrudan tanıtan bilgi (e-posta) çıkarılarak yukarıdaki süreler boyunca tutulur. Hesabınızı silmek App Store aboneliğinizi iptal etmez; aboneliği Apple'dan ayrıca kapatmanız gerekir.

### 8. Verilerinizi nasıl koruyoruz

Bütün bağlantılar şifrelidir. Veritabanında herkes yalnız kendi ailesini görür; çocuğun cihazı yalnız kendi profilini görür. Mesaj fotoğrafları, ses kayıtları ve davranış kaydı sesleri özel alanlarda tutulur ve yalnız kısa süreli, imzalı bağlantıyla açılır. Yönetim paneline iki adımlı doğrulamayla girilir; her işlem gerekçeli ve silinemez biçimde kaydedilir. Bir veri ihlali olursa Kurul'a ve size kanunda öngörülen sürelerde bildiririz.

### 9. Haklarınız (KVKK md. 11)

Kendiniz ve veli olarak çocuğunuz için şu haklara sahipsiniz:
- a) Kişisel verinizin işlenip işlenmediğini öğrenmek,
- b) İşlenmişse buna ilişkin bilgi istemek,
- c) İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenmek,
- ç) Yurt içinde ya da yurt dışında aktarıldığı üçüncü kişileri bilmek,
- d) Eksik ya da yanlış işlenmişse düzeltilmesini istemek,
- e) KVKK md. 7'deki şartlarla silinmesini ya da yok edilmesini istemek,
- f) (d) ve (e) bentlerindeki işlemlerin, verinin aktarıldığı üçüncü kişilere bildirilmesini istemek,
- g) Yalnız otomatik sistemlerle analiz edilmesi sonucu aleyhinize bir sonuç çıkmasına itiraz etmek,
- ğ) Kanuna aykırı işleme yüzünden zarara uğrarsanız zararın giderilmesini istemek.

Açık rızaya dayanan işlemlerde rızanızı istediğiniz an geri alabilirsiniz. Geri alma, o ana kadar yapılan işlemleri geçersiz kılmaz.

Birçok işlemi başvuru yapmadan da uygulamada kendiniz yapabilirsiniz: bilgilerinizi düzeltmek, tanışma yanıtlarını değiştirmek ya da silmek, uzman paylaşımını durdurmak, hesabınızı silmek.

### 10. Nasıl başvurursunuz

10.1. Başvuru yolları:
- Moyo Ebeveyn içinden: `[EKRAN YOLU: Ayarlar › Yasal metinler › KVKK başvurusu]`;
- Moyo Ebeveyn'e kayıtlı e-posta adresinizden `destek@moyoapp.com.tr` adresine (konu: "KVKK başvurusu");
- yazılı ve imzalı olarak `[ADRES]` adresine;
- kayıtlı elektronik posta (KEP) ya da güvenli elektronik imzayla `[KEP ADRESİ]` adresine.

10.2. Başvurunuzda adınızı, hesabınızdaki e-posta adresini ve ne istediğinizi yazın. Başvurunun size ait olduğunu doğrulamak için ek bilgi isteyebiliriz.

10.3. Başvurunuzu en geç **30 gün** içinde sonuçlandırırız. Yanıt ücretsizdir; işlem ayrıca bir maliyet gerektirirse Kurul'un belirlediği tarifeye göre ücret istenebilir.

10.4. Başvurunuz reddedilirse, yanıtı yetersiz bulursanız ya da süresinde yanıt alamazsanız, yanıtı öğrendiğiniz tarihten başlayarak 30 gün ve her hâlde başvuru tarihinden başlayarak 60 gün içinde Kişisel Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz (KVKK md. 14).

### 11. Bu metin değişirse

Her metnin bir sürümü vardır. Esaslı bir değişiklikte sizi uygulamada bilgilendiririz; açık rızaya dayanan bir işlemin kapsamı değişirse yeniden onayınızı isteriz. Önceki sürümler `moyoapp.com.tr` adresinde arşivlenir.

Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('aydinlatma-cocuk', 'v1', 'Moyo Oyun Aydınlatma Metni (Veli ve Çocuk)', '{child}', true, $md$# Moyo Oyun Aydınlatma Metni (Veli ve Çocuk)

## Kısaca

- Moyo Oyun ücretsizdir. **Reklam yok, uygulama içi satın alma yok, veri satışı yok, üçüncü taraf analiz ya da izleme aracı yok.**
- Çocuğunuzun e-postası ve şifresi yoktur. Profili siz Moyo Ebeveyn'de açarsınız; oyun, sizin gösterdiğiniz 15 dakikalık tek kullanımlık kod ya da QR ile bağlanır.
- Oyun yalnız çalışması için gerekenleri tutar: oyun kaydı, maceralar, coin, aile içi mesajlar.
- Çocuğunuz yalnız kendi ailesiyle mesajlaşır. Yabancılarla iletişim yoktur.
- Kamera yalnız QR okumak için açılır. Görüntü kaydedilmez, gönderilmez.
- Çocuğunuzdan konum, fotoğraf, ses ya da iletişim bilgisi almayız.
- Çocuğunuzun haklarını veli olarak siz kullanırsınız: `destek@moyoapp.com.tr`.

## Kısım A — Velilere tam metin

### 1. Bu metin kimin için

1.1. Bu metin, çocuğunu Moyo Oyun'a bağlayan veliler içindir. Çocuğunuzun oyunda oluşan verisinin nasıl işlendiğini anlatır. KVKK md. 10 gereği hazırlanmıştır.

1.2. Çocuğunuzun verisi sizin adınıza ve sizin yönetiminizde işlenir. Moyo Ebeveyn'deki veriler için **Moyo Ebeveyn Aydınlatma Metni** ([Moyo Ebeveyn Aydınlatma Metni](/yasal/aydinlatma-ebeveyn)) geçerlidir; bu iki metin birlikte okunur.

1.3. Kısım B'deki kısa notu çocuğunuzla birlikte okumanızı öneririz.

1.4. **Çocuk.** 18 yaşından küçük çocuğun bu hizmetle ilgili hak ve yükümlülüklerini velisi ya da yasal temsilcisi olan ebeveyn kullanır ve üstlenir. Çocuğun hesabını veli açar ve yönetir; çocuğun kullanımından, çocuk adına verilen onaylardan ve girilen kayıtlardan ebeveyn sorumludur.

1.5. **Genel ilke.** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

### 2. Veri sorumlusu

Moyo'yu işleten `[AD SOYAD]`, `[ADRES]`, `[MERSİS/VKN]`. İletişim (KVKK başvuruları dahil): `destek@moyoapp.com.tr`.

"Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer.

### 3. Oyun çocuğunuzu nasıl tanır

3.1. Çocuğunuz oyuna e-posta ya da şifreyle girmez. Oyun cihazda, ad ya da e-posta istemeyen **anonim bir oturum** açar. Bu oturuma rastgele bir kimlik verilir.

3.2. Siz Moyo Ebeveyn'de bir giriş kodu ürettiğinizde (yazı ya da QR olarak), kod 15 dakika geçerlidir ve bir kez kullanılır. Çocuğunuz kodu yazınca ya da QR'ı okutunca bu anonim oturum, sizin açtığınız çocuk profiline bağlanır.

3.3. Oturum anahtarı cihazın güvenli alanında (iOS anahtar zinciri) tutulur. Oyun sonraki açılışlarda sessizce devam eder.

3.4. Giriş kodunu yalnız çocuğunuzun cihazında kullanın. Kodu ya da QR'ı başkasıyla paylaşmayın: kodu kullanan cihaz, çocuğunuzun maceralarını ve sizinle mesajlarını görebilir.

### 4. Hangi verileri işliyoruz

| Kategori | Veriler |
|---|---|
| Sizin Moyo Ebeveyn'de girdiğiniz | Çocuğun adı ya da takma adı, simgesi, yaş grubu (oyun bunları gösterir ve yaşa uygun ayarları seçer) |
| Oturum | Cihazın anonim oturum kimliği |
| Oyun kaydı | Seviye, deneyim puanı (XP), evcil hayvanın durumu, eşyalar, adanın düzeni. Cihazda tutulur; sunucuda yedeği vardır. |
| Coin | Coin bakiyesi ve oyun içi harcamalar |
| Maceralar | Sizin Moyo Ebeveyn'de verdiğiniz rutin ve adımlar (oyunda her adım bir macera olarak görünür); çocuğun "Yaptım" ve "Yapamam" işaretleri; sizin onayınız, retiniz ve notunuz |
| Mesajlar | Çocuğun size yazdığı yazılar ve seçtiği hazır çıkartmalar; sizin ona gönderdiğiniz yazı, fotoğraf ve sesli mesajlar; okundu bilgisi |
| Ödüller | Çocuğun Güneş Taşı bakiyesi ve sizden istediği ödüller; sizin oyunda gönderdiğiniz hediyeler |
| Cihaz ve kullanım | Bildirim jetonu; oyunu açtığı günler, sürüm, platform, kullanılan ekran ve özelliklerin adları (serbest metin ve içerik yok) |
| Güvenlik | Kod giriş denemeleri (IP adresi dahil, kötüye kullanımı önlemek için kısa süre) |

**Almadıklarımız:** Çocuğunuzdan e-posta, telefon, şifre, adres, konum, fotoğraf, ses kaydı ya da kişi listesi almayız. Kamera görüntüsü kaydedilmez. Çocuğunuz oyundan dosya, fotoğraf ya da ses gönderemez.

### 5. Amaçlar ve hukuki sebepler

| Ne için | Hukuki sebep (KVKK) |
|---|---|
| Oyunu çocuğunuzun profiline bağlamak ve oturumu sürdürmek | md. 5/2-c — veli olarak sizinle kurulan sözleşmenin ifası * |
| Maceraları göstermek, "Yaptım"ı size iletmek, onaylanan macera için coin ve Güneş Taşı yazmak | md. 5/2-c * |
| Oyun kaydını yedeklemek (cihaz değişince kaldığı yerden devam) | md. 5/2-c * |
| Aile içi mesajlaşma, ödül istekleri ve hediyeler | md. 5/2-c * |
| Bildirim göndermek (cihazda izin verilmişse) | md. 5/2-c * |
| Oyunun işleyişini ölçmek ve hataları bulmak | md. 5/2-f — meşru menfaat |
| Kod deneme sınırı ve kötüye kullanımı önleme | md. 5/2-ç (KVKK md. 12 güvenlik yükümlülüğü) ve md. 5/2-f |
| Yetkili kurumların usulüne uygun talepleri | md. 5/2-a ve md. 5/2-ç |

\* Avukatın teyit edeceği dayanak.

Çocuğunuzun verisini reklam, pazarlama ya da profil çıkarma için kullanmayız, satmayız.

### 6. Verileri kim görür

- **Siz ve ailenizdeki diğer ebeveyn:** maceraları, "Yaptım"ları, coin ve Güneş Taşı bakiyesini, mesajları, ödül isteklerini görürsünüz.
- **Kardeşler:** birbirinin mesajlarını ve hesabını görmez. Her cihaz yalnız kendi çocuğunun profilini görür.
- **Uzman — yalnız sizin açık rızanızla:** Çocuğunuzu Moyo Ebeveyn'de bir uzmanla paylaşırsanız uzman, Moyo Uzman'da profil bilgilerini, maceraları (sizin verdiğiniz adımları) ve "Yaptım" kayıtlarını **yalnız okur**. Oyun kaydını, mesajları, coin ve Güneş Taşı hareketlerini göremez. Paylaşımı istediğiniz an durdurursunuz.
- **Hizmet sağlayıcılar:** veriler Supabase sunucularında (Frankfurt, Almanya; AB bölgesi) tutulur; bildirimler Apple'ın bildirim hizmetiyle (APNs) gönderilir. Sağlayıcılar veriyi yalnız bizim adımıza işler. Yurt dışına aktarım KVKK md. 9'a uygun güvencelerle yapılır (ayrıntı: Moyo Ebeveyn Aydınlatma Metni 5.5–5.6).
- **Yetkili ekibimiz:** yalnız destek, güvenlik ve kanuni yükümlülük için, iki adımlı girişle, gerekçe yazarak ve kayıt altında erişir. Mesaj içerikleri ekip ekranlarında gösterilmez.
- **Yetkili kurumlar:** yalnız usulüne uygun talep olursa ve talep kapsamıyla sınırlı olarak.

Çocuğunuz oyunda yabancılarla konuşamaz, başka oyuncuları göremez, kimseyle eşleşmez.

### 7. Kamera, izinler ve ebeveyn kapısı

7.1. **Kamera** yalnız giriş ekranında, yalnız QR kodu okumak için açılır. Okuma iOS'un kendi araçlarıyla yapılır; üçüncü taraf kütüphane kullanılmaz. Görüntü kaydedilmez, hiçbir yere gönderilmez. QR yalnız giriş kodunu taşır; çocuğun adı ya da kimliği QR'da yoktur.

7.2. Kamera bir cihazda ilk kez istenmeden önce **ebeveyn kapısı** çıkar. Ebeveyn kapısı, bir yetişkinin çözeceği bir sorudur. Ayarlar, kamera izni, dış bağlantılar ve yasal bilgiler bu kapının arkasındadır. Lütfen soruyu çocuğunuza çözdürmeyin.

7.3. **Bildirim** izni iOS tarafından ayrıca sorulur. İzin vermeseniz de oyun çalışır.

### 8. Reklam, satın alma ve izleme yok

- Oyunda reklam gösterilmez.
- Uygulama içi satın alma yoktur. Coin parayla alınamaz; yalnız sizin onayladığınız maceralarla (ve bir kez hoş geldin hediyesi olarak) kazanılır.
- Üçüncü taraf analiz, reklam ya da izleme aracı yoktur. Kullanım kayıtları yalnız kendi sunucumuzda tutulur.
- Çocuğunuzun verisiyle profil çıkarmayız, veriyi kimseye satmayız.

### 9. Ne kadar süre saklıyoruz

| Veri | Süre |
|---|---|
| Çocuk profili, maceralar, mesajlar, coin ve Güneş Taşı hareketleri, sunucudaki oyun yedeği | Ailenin hesabı silinene kadar |
| Cihazdaki oyun kaydı | Oyun cihazdan kaldırılana kadar (bağlantıyı kaldırmak cihazdaki kaydı silmez) |
| Kod deneme kayıtları (IP dahil) | 15 dakika – 1 gün |
| Kullanım kayıtları | 25 ay, sonra yalnız kimliksiz toplamlar |

**Bağlantıyı kaldırmak:** Moyo Ebeveyn'de çocuğun "Cihaz bağlantısını kaldır" seçeneğiyle oyunun hesaba erişimi biter. Oyun "Bağlantın kapatıldı" der. Cihazdaki oyun kaydı silinmez; silmek için oyunu cihazdan kaldırın.

**Silmek:** Moyo Ebeveyn'de hesabınızı sildiğinizde, ailede başka ebeveyn yoksa çocuğun sunucudaki bütün verisi (profil, maceralar, mesajlar, coin, oyun yedeği) de silinir.

### 10. Haklarınız ve başvuru

Çocuğunuz adına KVKK md. 11'deki hakları veli olarak siz kullanırsınız: verinin işlenip işlenmediğini öğrenmek, bilgi istemek, düzeltme, silme, aktarılan kişileri öğrenmek, itiraz ve zararın giderilmesini istemek. Başvuru yolları ve süreler Moyo Ebeveyn Aydınlatma Metni'nin 9. ve 10. maddelerindedir: uygulama içinden, kayıtlı e-postanızdan `destek@moyoapp.com.tr` adresine (konu: "KVKK başvurusu") ya da yazılı olarak `[ADRES]` adresine. En geç 30 gün içinde ücretsiz yanıt veririz.

Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`

## Kısım B — Çocuğa kısa not (6–12 yaş)

> **Merhaba!**
>
> Moyo Oyun'da oynarken oyun bazı şeyleri hatırlar: seviyeni, eşyalarını ve ailenin verdiği maceraları.
> Bunları sadece oyun çalışsın diye saklarız; kimseye satmayız.
> Bu oyunda sadece ailen seninle konuşabilir; başka kimse sana yazamaz.
> Oyunda reklam yok ve oyun senden hiç para istemez.
> Kamerayı sadece ailenin gösterdiği kodu okutmak için açarız; fotoğrafını çekmeyiz.
> Merak ettiğin ya da canını sıkan bir şey olursa ailene söyle.

Gösterim: büyük yazı, kısa satırlar, oyunun sesli okumasıyla (ses dosyası eksik kalmasın: game-app `build_voice.py --missing`). Altta veliler için "Velilere tam metin" bağlantısı (Kısım A).
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('aydinlatma-uzman', 'v1', 'Moyo Mercek Uzman Aydınlatma Metni', '{clinic}', true, $md$# Moyo Mercek Uzman Aydınlatma Metni

## Kısaca

- **Kim:** Moyo Mercek'i `[AD SOYAD]` işletir. Sizin (uzmanın) hesap verileriniz için veri sorumlusu biziz. Ailelerle çalışırken girdiğiniz kayıtlarda veri sorumlusu sizsiniz (ya da kliniğiniz), biz veri işleyeniz; ayrıntı **Veri İşleme Eki**'nde.
- **Ne topluyoruz:** adınız, unvanınız, e-postanız, klinik adınız, çalıştığınız klinikler ve ekip rolünüz; üyelik bilgisi; karşılama anketi yanıtlarınız; isteğe bağlı olarak takvim bilgileriniz; içerik barındırmayan kullanım kayıtları.
- **Neden:** hesabınızı açmak ve hizmeti sunmak, ailelere ve ekibinize kim olduğunuzu göstermek, üyeliğinizi yürütmek, güvenliği sağlamak ve ürünü kimliksiz toplamlarla geliştirmek.
- **Aileler ne görür:** adınız, unvanınız, klinik adınız; aileye gösterilmesini seçtiğiniz randevular. Davet e-postasında gönderen adınız görünür; aile yanıtlarsa yanıt e-posta adresinize gelir.
- **Yapmadıklarımız:** verinizi satmayız; reklam göstermeyiz; üçüncü taraf analiz ya da izleme aracı kullanmayız; verinizi yapay zekâ hizmetine göndermeyiz.
- **Sunucular:** verileriniz yurt dışındaki sunucularda tutulabilir; aktarım KVKK md. 9'daki usulle yapılır.
- **Haklarınız:** KVKK md. 11'deki haklarınızı uygulama içinden ya da `destek@moyoapp.com.tr` adresinden (konu: "KVKK başvurusu") kullanabilirsiniz; en geç 30 gün içinde ücretsiz yanıt veririz. Hesabınızı uygulama içinden silebilirsiniz.

---

## 1. Veri sorumlusu ve bu metnin kapsamı

1.1. Kişisel verileriniz, veri sorumlusu sıfatıyla Moyo'yu işleten `[AD SOYAD]` ("Platform", "biz") tarafından işlenir. Adres: `[ADRES]`. MERSİS/VKN: `[MERSİS/VKN]`. İletişim: `destek@moyoapp.com.tr` (bütün konular; kişisel veri başvurularında konu: "KVKK başvurusu").

1.2. Platform; çocuklar için Moyo Oyun, ebeveynler için Moyo Ebeveyn ve uzmanlar için Moyo Mercek uygulamalarını işletir. "Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer. Bu metinde Platforma yüklenen hak ve yükümlülükler, veri sorumlusu olarak onu işleten kişiye aittir. Bu metin, **Moyo Mercek hesabı açan uzmanların ve klinik ekip üyelerinin kendi kişisel verilerini** kapsar.

1.3. Bu metnin kapsamı dışında kalanlar:
   - a) **Uzman kayıtları** (ailelerle çalışırken yazdığınız notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, ebeveyn eğitimleri, hedef davranışlar, seans kayıtları, takip planı, etiketler ve davet formuna girdiğiniz ebeveyn ve çocuk bilgileri): Bu kayıtlarda veri sorumlusu siz (ya da kliniğiniz), Platform veri işleyendir; rollerimiz ve yükümlülüklerimiz **Veri İşleme Eki**'nde ([Veri İşleme Eki (Moyo Mercek Uzman Hizmet Sözleşmesi, Ek-1)](/yasal/veri-isleme-eki)) düzenlenir. Bu kayıtları kendi beyanınızla ve kendi sorumluluğunuzda girersiniz; Moyo içeriği denetlemez, doğrulamaz, bunun için sorumluluk ya da yükümlülük üstlenmez.
   - b) **Aile verisi** (ebeveynin Moyo Ebeveyn'de oluşturduğu rutinler ve adımlar, tamamlamalar, davranış kayıtları ve olayları, ebeveyn eğitimi yanıtları gibi veriler): Bunlar ebeveyn aydınlatma metnine tabidir; siz bu verileri yalnız ebeveynin açık rızasıyla ve paylaşım sürdükçe görürsünüz.

1.4. Bu metinde "Uzman" Moyo Mercek hesabı açan gerçek kişiyi, "Klinik" uzmanın Moyo Mercek'te çalıştığı alanı (kendi bireysel hesabı ya da bir kliniğin ekip hesabı; bir uzman birden çok klinikte çalışabilir), "Klinik sahibi" kliniği kuran ya da sahipliği devralan uzmanı, "Ekip üyesi" klinik sahibinin ekibe katılma isteğini kabul ederek kliniğe katılan uzmanı anlatır. Aile: uzmanın Moyo Mercek'te birlikte çalıştığı ebeveyn ve çocuk.

1.5. **Genel ilke.** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

## 2. İşlediğimiz kişisel veriler ve toplama yöntemi

2.1. Aşağıdaki verileri, siz Moyo Mercek'e (iPhone, iPad ya da web) girdiğinizde ve uygulamayı kullandıkça otomatik yollarla; üyelik bilgisini ayrıca Apple ve RevenueCat'ten gelen bildirimlerle topluyoruz.

| Kategori | Veriler | Nereden |
|---|---|---|
| Kimlik | Ad soyad, unvan | Kayıt ve profil ekranı |
| İletişim | E-posta adresi | Kayıt ekranı |
| Mesleki bilgi | Klinik adı, çalışma biçimi (bireysel / klinik), çalıştığınız klinikler ve her birindeki rolünüz (sahip / üye), kliniğe katılma tarihi, sizi ekibe ekleyen uzmanın adı, kişisel kodunuz ve ekibe katılma istekleri, size atanan ya da sorumlusu olduğunuz aileler | Kayıt, ekip istekleri, klinik sahibinin atamaları |
| Hesap güvenliği | Şifre (yalnız kimlik doğrulama sağlayıcısında, geri çevrilemez biçimde özetlenmiş; biz göremeyiz), oturum bilgileri, kod deneme kayıtları (IP adresi dahil) | Giriş ve kod ekranları |
| Karşılama anketi | Mesleğiniz, ailelerle çalışırken zorlandığınız alanlar, işinize yarayacak özellikler, Moyo Mercek'e geliş nedeniniz (yalnız klinik sahibine sorulur); eski sürümde anketi geçtiyseniz bu bilgi | İlk girişte bir kez gösterilen anket ekranı |
| Üyelik | Paket, dönem (aylık / yıllık), dönem sonu, otomatik yenileme durumu, mağaza işlem kimliği, ödeme olayları; RevenueCat'te hesabınıza bağlı rastgele kullanıcı kimliği. **Kart bilginiz bizde değil, Apple'dadır.** | Moyo Mercek üyelik ekranı, Apple, RevenueCat |
| Takvim (isteğe bağlı) | Çalışma saatleriniz ve odalar; takvim aboneliği bağlantınızın belirteci; eklerseniz dış takviminizin (Google, iCloud, Outlook) gizli adresi ve bu takvimden okunan etkinlikler (zaman ve başlık) | Takvim ayarları; eklediğiniz dış takvim |
| Bildirim | Cihazınızın bildirim jetonu, size gönderilen bildirimler ve okunma bilgisi | Moyo Mercek (iPhone, iPad) |
| Kullanım kayıtları | Uygulamayı açtığınız günler, oturum sayısı, uygulama sürümü, platform, kullandığınız ekran ve özelliklerin olay adları (serbest metin ve içerik yazılmaz) | Moyo Mercek, otomatik |
| Destek ve denetim | Destek yazışmalarınız; yetkili ekibimizin hesabınızda yaptığı işlemlerin denetim kaydı (kim, ne, ne zaman, hangi gerekçeyle) | Destek kanalları, yönetim paneli |
| Yazar bilgisi | Uzman kayıtlarından hangisini sizin yazdığınız | Moyo Mercek, otomatik |

2.2. Sizden **özel nitelikli kişisel veri** (ör. kendi sağlık veriniz) ya da T.C. kimlik numaranızı istemeyiz. Dış takviminizden okunan etkinlik başlıkları başkalarına ait bilgi içerebilir; bu etkinlikler yalnız size görünür ve ailelere ya da ekibinize gösterilmez.

## 3. Amaçlar ve hukuki sebepler (KVKK md. 5)

| Amaç | İşlenen veriler | Hukuki sebep (öneri) |
|---|---|---|
| Hesabınızı açmak, giriş yapmanızı sağlamak, kliniğinizi ve ekibinizi yönetmek | Kimlik, iletişim, mesleki bilgi, hesap güvenliği | Sözleşmenin kurulması ve ifası (md. 5/2-c) |
| Ailelere ve ekip arkadaşlarınıza kim olduğunuzu göstermek (davet önizlemesi, Moyo Ebeveyn'de "Uzmanım", davet açılış sayfası, ekip ekranı, ekibe katılma isteği) | Ad, unvan, klinik adı, ekip rolü | Sözleşmenin ifası (md. 5/2-c) |
| Aile davetini sizin adınıza e-postayla iletmek | Ad, unvan, klinik adı, e-posta adresiniz (yanıt adresi olarak) | Sözleşmenin ifası (md. 5/2-c) |
| Üyeliği yürütmek, ödemeyi doğrulamak, ödeme kayıtlarını tutmak | Üyelik verileri | Sözleşmenin ifası (md. 5/2-c); kanuni yükümlülük (md. 5/2-ç; vergi ve ticaret mevzuatı) |
| Hizmet bildirimleri göndermek (ör. davetin açılması ya da kabulü, ekibe katılma isteği, size aile atanması) | Kimlik, bildirim | Sözleşmenin ifası (md. 5/2-c) |
| Takviminizi ve seanslarınızı göstermek, çakışmaları denetlemek; isterseniz seanslarınızı kendi takviminize aktarmak ve dış takviminizi Moyo Mercek'te göstermek | Takvim verileri, mesleki bilgi | Sözleşmenin ifası (md. 5/2-c) |
| Güvenlik ve kötüye kullanımın önlenmesi (kod deneme sınırı, e-posta gönderim sınırı, hesabın askıya alınması, denetim kaydı) | Hesap güvenliği, kullanım ve denetim kayıtları | Meşru menfaat (md. 5/2-f); veri güvenliği yükümlülüğü (md. 5/2-ç, md. 12) |
| Destek taleplerinizi yanıtlamak | Kimlik, iletişim, destek yazışmaları, ilgili hesap bilgileri | Sözleşmenin ifası (md. 5/2-c); meşru menfaat (md. 5/2-f) |
| Size uygun ilk adımı önermek; hizmetin işleyişini ölçmek, hataları bulmak, ürünü geliştirmek (kimliksiz toplamlarla) | Kullanım kayıtları, karşılama anketi yanıtları | Meşru menfaat (md. 5/2-f). Anket ilk girişte bir kez sorulur; yanıtlar yönetim ekranında yalnız toplam sayı olarak görünür |
| Hukuki uyuşmazlıklarda hakların korunması; yetkili mercilerin usulüne uygun taleplerinin karşılanması | İlgili veriler, taleple sınırlı | Bir hakkın tesisi, kullanılması veya korunması (md. 5/2-e); kanuni yükümlülük (md. 5/2-ç) |

## 4. Verileriniz kimlere, hangi amaçla aktarılır

4.1. **Ailelere görünen bilgiler.** Sizin davet ettiğiniz ya da sizinle paylaşım yapan ebeveynler Moyo Ebeveyn'de (orada uzman ürününün adı Moyo Uzman'dır) şunları görür: adınız, unvanınız, klinik adınız (bireysel hesapta yalnız unvanınız ve adınız). Moyo uzman hakkında bir doğrulama ya da yetki beyanı göstermez. Aileye gösterilmesini seçtiğiniz randevularda gün, saat, süre, tür, yer ve adınız görünür. Davet e-postasında gönderen adı olarak adınız ve Moyo adı, metinde unvanınız ve klinik adınız yer alır; aile bu e-postayı yanıtlarsa yanıt sizin e-posta adresinize gider ve aile adresinizi görür. Ebeveyn, kendi Moyo Ebeveyn ekranında daha önce çalıştığı uzmanların adlarını görmeye devam edebilir. Bu aktarımın amacı, ebeveynin çocuğunun verisini kiminle paylaştığını bilerek karar vermesidir (md. 5/2-c, md. 8).

4.2. **Ekibinize görünen bilgiler.** Aynı klinikteki uzmanlar adınızı, unvanınızı ve ekip rolünüzü görür. Klinik sahibi; ekip üyelerinin katılma tarihini, kimin eklediğini, ekip üyelerinin gönderdiği aile davetlerini ve bunların durumunu görür. Sizi ekibine eklemek isteyen klinik sahibi, kişisel kodunuzu yazınca adınızı ve unvanınızı görür. Birden çok klinikte çalışıyorsanız, bir kliniğin sahibi başka yerlerdeki seans saatlerinizi o kliniğin takviminde yalnız "dolu" olarak görür (öteki klinik ve aile bilgisi olmadan). Karşılama anketi yanıtlarınız ve dış takvim etkinlikleriniz ekibinize ve ailelere **görünmez**.

4.3. **Sonraki uzmana aktarılmayan bilgiler.** Bir ebeveyn çocuğunun takibini başka bir uzmana taşıdığında ve açıkça izin verdiğinde, sizin yazdığınız uzman kayıtları sonraki uzmana salt okunur olarak açılabilir (Uzman Hizmet Sözleşmesi ve Veri İşleme Eki). Bu durumda **adınız, unvanınız, klinik adınız, iletişim ve kimlik bilgileriniz sonraki uzmana aktarılmaz**; sonraki uzman yalnız "Önceki uzman 1" gibi bir sıra adı ve dönemi (ay olarak) görür. Kayıt metinlerinde geçen klinik ve uzman adları ile e-posta ve telefon bilgileri otomatik olarak gizlenir. Bu gizleme en iyi çabayla yapılır; yazım hatalı ya da kısaltılmış adlar yakalanamayabilir. Bu nedenle serbest metin alanlarına kendinizin ya da başkalarının kimlik bilgisini yazmamanızı rica ederiz.

4.4. **Platformun yetkili ekibi.** Yetkili ekip üyelerimiz; yalnız destek talebinizi yanıtlamak, güvenlik ve kötüye kullanım incelemesi, üyelik ve ödeme sorunları ve kanuni yükümlülükler için hesap bilgilerinize, üyelik durumunuza ve kullanım sayılarınıza erişebilir. Erişim iki adımlı doğrulamayla ve rolle sınırlıdır, her değişiklik gerekçe yazılarak yapılır ve silinemez bir denetim kaydına geçer. Uzman notlarınızın metni yönetim ekranlarında **gösterilmez**.

4.5. **Hizmet sağlayıcılar (alt işleyenler).** Hizmeti sunmak için, bizim adımıza ve talimatımızla çalışan aşağıdaki sağlayıcılara gereken ölçüde veri aktarırız. Güncel liste ayrıca yayımlanır.

| Sağlayıcı | Ne için | Hangi verileriniz | Konum |
|---|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | Bu metindeki bütün veriler | Frankfurt, Almanya; AB bölgesi |
| Apple | App Store (üyelik satışı; satıcı Apple'dır), bildirim gönderimi (APNs) | Üyelik işlemleri, bildirim jetonu ve bildirim metni | ABD / AB |
| RevenueCat | Üyelik durumunun doğrulanması | Rastgele kullanıcı kimliği, satın alma kayıtları | ABD |
| Resend | İşlem e-postaları (e-posta doğrulama, şifre sıfırlama, sizin adınıza aile daveti) | E-posta adresiniz, adınız, unvanınız, klinik adınız, e-posta içeriği | ABD / AB |
| Cloudflare | Yönetim panelinin ve Moyo Mercek web sürümünün sayfalarının barındırılması | Yetkili ekibin ekranına gelen hesap ve üyelik bilgileri; web sürümünü açtığınızda bağlantı kayıtları (IP adresi, tarayıcı bilgisi) | Küresel |
| Google (Gmail SMTP) — yalnız test dönemi | Test e-postaları | E-posta adresi, e-posta içeriği | ABD |

Bu sağlayıcılar verilerinizi yalnız bu hizmetler için işler, kendi amaçlarıyla kullanmaz.

4.6. **Yetkili merciler.** Mahkeme, savcılık ya da yetkili kamu kurumunun usulüne uygun talebi hâlinde verileriniz, talep kapsamıyla sınırlı olarak bu mercilere aktarılabilir; kanunen yasak değilse sizi bilgilendiririz (md. 5/2-ç, md. 8). Gerçeğe aykırı beyan ya da kötüye kullanım hâlinde ilgili kayıtlar yetkili mercilerle paylaşılabilir (Uzman Hizmet Sözleşmesi).

4.7. **İşletme devri.** Platformun birleşmesi, devri ya da varlık satışı hâlinde verileriniz, aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa aktarılabilir; sizi önceden bilgilendiririz ve hesabınızı silme hakkınız saklıdır.

4.8. **Yapmadıklarımız.** Verilerinizi satmayız, kiralamayız; reklam ağlarıyla paylaşmayız; profil çıkarıp pazarlama yapmayız; üçüncü taraf analiz ya da izleme aracı kullanmayız; verilerinizi yapay zekâ hizmetine göndermeyiz.

## 5. Yurt dışına aktarım

5.1. Hizmet sağlayıcılarımızın sunucuları yurt dışında bulunabilir (madde 4.5'teki "Konum" sütunu). Aktarımın amacı yalnız hizmeti çalıştırmaktır (veritabanı, depolama, e-posta, ödeme, bildirim). Veritabanımızın bulunduğu bölge: Frankfurt, Almanya; AB bölgesi.

5.2. Yurt dışına aktarım KVKK md. 9'a uygun yapılır: aktarılan ülke için Kurul'un yeterlilik kararı varsa ona dayanılır; yoksa Kurul'un ilan ettiği **standart sözleşme** imzalanır ve imzadan itibaren **5 iş günü** içinde Kurul'a bildirilir. Yalnız arızi ve md. 9/6'da sayılan istisnai hâllerde başka dayanaklar kullanılabilir.

## 6. Kimliğiniz ve unvanınız

6.1. Moyo uzmanın kimliğini, mesleki unvanını ya da meslek icra yetkisini doğrulamaz ve bunun için belge istemez. Ailelere yalnız sizin beyan ettiğiniz ad, unvan ve klinik adı gösterilir; Moyo bunlar hakkında bir doğrulama ya da yetki beyanı vermez. Bilgilerin doğruluğu sizin beyanınızdır ve sorumluluğunuzdadır (Uzman Hizmet Sözleşmesi).

## 7. Saklama süreleri

| Veri | Süre |
|---|---|
| Hesap, profil, klinik ve ekip bilgileri | Hesabınız silinene kadar; silmede derhal silinir. Ekipte başka uzman varsa klinik kalır, sahiplik en eski üyeye geçer. |
| Karşılama anketi yanıtları | Hesabınız silinene kadar |
| Takvim ayarları ve dış takvim adresi | Siz kaldırana ya da hesabınız silinene kadar |
| Dış takvimden okunan etkinlikler | `[SÜRE]` (okuma aralığı bugünden 14 gün önce ile 60 gün sonrası; eşitlemede yenilenir) |
| Kod deneme kayıtları (IP dahil) | 15 dakika – 1 gün |
| Kullanım kayıtları | 25 ay; sonra yalnız kimliksiz toplam |
| Bildirim kayıtları | 12 ay; isterseniz daha önce silersiniz |
| Denetim kaydı | 5 yıl; silinen kullanıcının e-postası kayda yazılmaz |
| Üyelik ve ödeme olayları | 10 yıl (vergi ve ticaret mevzuatındaki süre) |
| KVKK başvuruları | Başvuru kapandıktan sonra 3 yıl |
| Destek talepleri | Talep kapandıktan sonra 2 yıl |

Süresi dolan veriler Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik'e göre, 6 ayı geçmeyen periyodik imha dönemlerinde silinir, yok edilir ya da anonim hâle getirilir. Hesap silindikten sonra yalnız kanunen saklanması gereken kayıtlar ve değiştirilemez denetim kaydı, sizi doğrudan tanımlayan bilgi (e-posta) çıkarılarak saklama süresince tutulur. Silinen veriler yedeklerden de en geç 30 gün içinde kendiliğinden çıkar.

**Ailelerle ilgili kayıtlarınız (Veri İşleme Eki).** Bu kayıtlar ailenin paylaşımına bağlıdır ve bunu baştan bilmeniz gerekir:
- Aile paylaşımı sonlandırınca o andan sonra ailenin yeni kayıtlarını göremezsiniz.
- Aile hesabını ya da çocuğun profilini silerse, o aileye ait notlarınız ve kayıtlarınız da silinir. Bu kural ailenin kendi verisi üzerindeki kontrolünü ve silme hakkını korur; kayıtlar aileye bağlı takip kayıtlarıdır ve Moyo bir arşiv sistemi değildir.
- Kliniğinizin denemesi ya da üyeliği bitince kayıtlar silinmez; erişiminiz kapanır, üyelik yenilenince kaldığınız yerden açılır. Kayıtlar klinik ya da hesabınız silinene kadar saklanır.
- Siz hesabınızı silerseniz ailenin kendi girdiği kayıtlar (ebeveyn eğitimi yanıtları ve davranış olayları dahil) ailede kalır; sizin ve kliniğinizin bunlara erişimi kapanır.
- Mevzuatın ve meslek kurallarının size yüklediği kayıt tutma ve saklama yükümlülüğü sizdedir. Saklamanız gereken kayıtları gerektiğinde raporla, ilerleme notuyla ya da CSV olarak kendiniz indirir ve kendi sisteminizde saklarsınız.

## 8. Haklarınız (KVKK md. 11)

Bize başvurarak:
- a) kişisel verilerinizin işlenip işlenmediğini öğrenme,
- b) işlenmişse buna ilişkin bilgi talep etme,
- c) işlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,
- ç) yurt içinde ya da yurt dışında aktarıldığı üçüncü kişileri bilme,
- d) eksik ya da yanlış işlenmişse düzeltilmesini isteme,
- e) KVKK md. 7'deki şartlar çerçevesinde silinmesini ya da yok edilmesini isteme,
- f) (d) ve (e) bentlerine göre yapılan işlemlerin, verilerin aktarıldığı üçüncü kişilere bildirilmesini isteme,
- g) münhasıran otomatik sistemlerle analiz edilmesi sonucu aleyhinize bir sonuç çıkmasına itiraz etme,
- ğ) kanuna aykırı işlenmesi sebebiyle zarara uğramanız hâlinde zararın giderilmesini talep etme

haklarına sahipsiniz.

## 9. Başvuru yolu

9.1. Başvurunuzu şu yollardan biriyle yapabilirsiniz:
- Moyo Mercek içinden: Ayarlar › Yasal ve gizlilik › KVKK başvurusu;
- Moyo Mercek'te kayıtlı e-posta adresinizden `destek@moyoapp.com.tr` adresine (konu: "KVKK başvurusu");
- kayıtlı elektronik posta (KEP), güvenli elektronik imza ya da mobil imzayla;
- yazılı olarak `[ADRES]` adresine.

9.2. Başvurunuzda adınız soyadınız, (yazılı başvuruda) imzanız, tebligata esas adresiniz ya da e-posta adresiniz ve talep konunuz bulunmalıdır. Kimliğinizi doğrulamak için ek bilgi isteyebiliriz.

9.3. Başvurunuzu niteliğine göre en kısa sürede ve **en geç 30 gün** içinde ücretsiz sonuçlandırırız. İşlem ayrıca bir maliyet gerektirirse Kurul'un belirlediği tarifeye göre ücret alınabilir. Başvurunuz reddedilir, yanıtı yetersiz bulursanız ya da süresinde yanıt verilmezse Kişisel Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz (md. 14).

9.4. **Uzman kayıtlarına ilişkin başvurular:** Bir ebeveyn ya da başka bir kişi, sizin girdiğiniz uzman kayıtlarıyla ilgili olarak bize başvurursa başvuruyu Veri İşleme Eki'ndeki usulle size iletiriz.

9.5. **Hesap silme:** Hesabınızı Moyo Mercek içinden ("Hesabı sil") silebilirsiniz. App Store üyeliğiniz Apple hesabınızdan ayrıca iptal edilmelidir; hesap silmek üyeliği kendiliğinden iptal etmez.

## 10. Değişiklikler

Bu metin değişirse yeni sürümü Moyo Mercek'te ve herkese açık adreste yayımlarız; esaslı değişiklikleri uygulama içinde ve e-postayla bildiririz. Her sürüm, anahtarı ve sürüm numarasıyla kayıt altındadır.

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('kosullar-parentapp', 'v1', 'Moyo Ebeveyn Kullanım Koşulları', '{parent}', true, $md$# Moyo Ebeveyn Kullanım Koşulları

## Kısaca

- Moyo Ebeveyn (telefonda "Moyo"), ailelerin rutinleri, ödülleri ve aile içi iletişimi düzenlemesine yardım eden bir takip aracıdır. **Sağlık hizmeti değildir, tanı koymaz, belirli bir sonuç taahhüt etmez. Acil durumlarda 112'yi arayın; uygulama acil durum hizmeti değildir.**
- Eklediğiniz ve paylaştığınız çocukların velisi ya da yasal temsilcisi olduğunuzu beyan edersiniz. Çocuğunuzun hesabından, girdiğiniz kayıtlardan ve onlara dayanarak verdiğiniz kararlardan siz sorumlusunuz.
- **Uzmanlar doğrulanmaz.** Çocuğunuzu yalnız gerçek hayatta tanıdığınız bir uzmanla paylaşın. Paylaşımı istediğiniz an durdurursunuz.
- Aile aboneliğini **Apple satar.** Fiyat ve dönem satın alma ekranındadır. Dönem bitmeden en az 24 saat önce kapatmazsanız kendiliğinden yenilenir. İptal ve iade Apple üzerinden yapılır.
- 14 günlük deneme ücretsizdir (başka bir ailenin davet koduyla katılırsanız 21 gün); ödeme bilgisi istenmez ve kendiliğinden ücretli aboneliğe dönmez. Sonra ücretsiz planda, sınırlı özellikle devam edebilirsiniz.
- **Coin ve Güneş Taşı para değildir.** Ödülleri siz belirler ve siz verirsiniz; biz bu ödüllerin tarafı değiliz.
- Hesabınızı istediğiniz an uygulamanın içinden silebilirsiniz.
- **Moyo ilişkilerinizin tarafı değildir:** uzmanla aranızdaki ilişki ve girdiğiniz kayıtlar size aittir; Moyo bunlar için sorumluluk üstlenmez (kanunun saklı tuttuğu haklarınız dışında).
- Tanıtım ve kampanya iletileri yalnız ayrı izninizle gelir; izin kapalı başlar.
- Koşullar değişirse size bildiririz; esaslı değişiklikte yeniden onayınızı isteriz.

## Tam metin

### 1. Taraflar ve kapsam

1.1. Bu koşullar, Moyo'yu işleten `[AD SOYAD]` ("biz") ile Moyo Ebeveyn'i kullanan ebeveyn ("siz") arasındaki sözleşmedir. **Hizmet sağlayıcı.** "Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer. Adresimiz `[ADRES]`, MERSİS/VKN `[MERSİS/VKN]`.

1.2. Kişisel verilerinizin nasıl işlendiği **Moyo Ebeveyn Aydınlatma Metni**'nde ([Moyo Ebeveyn Aydınlatma Metni](/yasal/aydinlatma-ebeveyn)) anlatılır. Aydınlatma metni bu sözleşmenin parçası değildir; bilgi verir.

1.3. Açık rıza gerektiren işlemler (uzmanla paylaşım `uzman-paylasim-v1`, önceki uzman kayıtlarının aktarımı `uzman-gecis-v1`) bu koşulların içinde değildir. Ayrı ekranlarda, ayrı metinlerle sorulur. Reddetmeniz Moyo Ebeveyn'i kullanmanızı engellemez.

1.4. Çocuğunuzun kullandığı Moyo Oyun için ayrıca **Moyo Oyun Kullanım Koşulları** ([Moyo Oyun Kullanım Koşulları](/yasal/kosullar-gameapp)) geçerlidir. Onları da veli olarak siz kabul edersiniz.

### 2. Tanımlar

- **Moyo Ebeveyn:** ebeveynler için iOS uygulaması (telefonda görünen adı "Moyo").
- **Moyo Oyun:** çocuklar için iOS oyunu.
- **Moyo Uzman:** uzmanların kullandığı uygulama (iPad ve web).
- **Uzman:** Moyo Uzman'ı kullanan psikolog, terapist, özel eğitim uzmanı gibi meslek mensubu. Uzman bizim çalışanımız değildir.
- **Aile:** Moyo Ebeveyn'de sizin, varsa diğer ebeveynin ve çocuk profillerinin bulunduğu ortak alan.
- **Rutin ve adım:** çocuğunuza verdiğiniz sorumluluklar. Adım tek bir iştir; rutin birkaç adımdan oluşur. Verdiğiniz her adım, Moyo Oyun'da çocuğunuz için bir macera olur.
- **Ebeveyn eğitimi:** uzmanınızın Moyo'nun içerik kütüphanesinden size atadığı modüller, uygulama görevleri ve yapılacaklar.
- **Coin:** Moyo Oyun'da oyun içi eşyalar için kullanılan sanal değer.
- **Güneş Taşı:** çocuğunuza vereceğiniz gerçek hayat ödüllerinin sayacı.

### 3. Hizmetin ne olduğu, ne olmadığı

3.1. Moyo Ebeveyn ile rutin ve adım oluşturur, çocuğunuzun "Yaptım"larını onaylar, ödülleri yönetir, çocuğunuzla mesajlaşır, davranış kaydı tutarsınız. İsterseniz kayıtlarınızı bir uzmanla paylaşır, uzmanınızın atadığı ebeveyn eğitimini kullanır ve tanımladığı davranışlar için olay bildirirsiniz.

3.2. **Tanı, tedavi ve acil durum.** Moyo sağlık hizmeti sunmaz, tanı koymaz, tedavi önermez; hiçbir gösterge tanı ya da puan değildir. Acil durum ve kriz hizmeti değildir; acil durumda 112 aranır. Moyo sağlık hizmeti, uzaktan sağlık hizmeti ya da tıbbi cihaz değildir; tıbbi bir amaçla tasarlanmamıştır. Kayıtlar ve olay bildirimleri bir uzmana anında ulaşmaz. Moyo uzman istihdam etmez; uzman ile aile arasında aracılık ya da yönlendirme yapmaz. Uzmanların kendi programlarını kurması için şablon sunar.

3.3. **Kayıtların niteliği.** Uygulamadaki kayıtlar, kullanıcıların kendi girdiği takip kayıtlarıdır. Moyo bu kayıtları saklar ve gösterir; bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Davranış kaydındaki şiddet derecesi, olay bildirimindeki çocuğun tepkisi ve takip planındaki zorluk bildirimi sizin gözleminizdir. Ebeveyn eğitimindeki test sonucu sizin bilgi yoklamanızdır, çocuğa ait bir puan değildir.

3.4. **Moyo'nun içeriği.** Ebeveyn eğitimi kütüphanesi, kısa ebeveyn dersleri, hazır rutinler, öneriler ve ipuçları Moyo'nun hazırladığı içeriktir. Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz. Bu içeriğe dayanılarak verilen kararlardan ve bunların sonuçlarından, yasanın izin verdiği en geniş ölçüde, Moyo sorumlu değildir; kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. Uzmanınızın kendi yazdığı uygulama görevleri, yapılacaklar ve önerilerin içeriği uzmana aittir.

3.5. **Sonuç taahhüdü.** Moyo belirli bir sonuç, gelişme ya da davranış değişikliği taahhüt etmez.

3.6. **Genel ilke.** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

### 4. Hesap ve güvenlik

4.1. Moyo Ebeveyn'i kullanmak için 18 yaşını doldurmuş olmalısınız.

4.2. Kayıt için e-posta adresi ve şifre gerekir. Bilgilerinizin doğru ve güncel olması sizin sorumluluğunuzdadır. Deneme süresi e-postanızı doğruladığınızda başlar.

4.3. Hesabınız kişiseldir. Şifrenizi kimseyle paylaşmayın. Diğer ebeveyn kendi hesabıyla aileye katılır (7. madde).

4.4. Hesabınızın izinsiz kullanıldığını düşünürseniz şifrenizi değiştirin ve `destek@moyoapp.com.tr` adresine yazın.

4.5. Çocuğun giriş kodu ve ikinci ebeveyn davet kodu 15 dakika geçerlidir ve bir kez kullanılır. Uzmanın aile daveti 3 gün geçerlidir. Başka bir aileye verdiğiniz aile davet kodu 60 gün geçerlidir ve bir kez kullanılır (8.10). Kötüye kullanımı önlemek için hatalı kod denemeleri sınırlanır.

### 5. Veli beyanı ve çocuk hesabından sorumluluk

5.1. **Veli beyanı.** Moyo Ebeveyn'e eklediğiniz ve paylaştığınız çocukların velisi ya da yasal temsilcisi olduğunuzu, paylaşım kararını verme yetkisine sahip olduğunuzu beyan edersiniz.

5.2. **Çocuğun hesabı.** 18 yaşından küçük çocuğun bu hizmetle ilgili hak ve yükümlülüklerini velisi ya da yasal temsilcisi olan ebeveyn kullanır ve üstlenir. Çocuğun hesabını veli açar ve yönetir; çocuğun kullanımından, çocuk adına verilen onaylardan ve girilen kayıtlardan ebeveyn sorumludur. Çocuğunuzun Moyo Oyun profilini siz açar, siz yönetirsiniz. Çocuğun e-postası ya da şifresi yoktur; oyun sizin ürettiğiniz kod ya da QR ile bağlanır. Kodu yalnız çocuğunuzun cihazında kullanın. Çocuğunuzun oyunu ve Moyo Ebeveyn'deki kayıtları nasıl kullandığını gözetmek size aittir.

5.3. **Bağlantıyı kaldırma.** Bir cihazın çocuğunuzun hesabına erişimini Moyo Ebeveyn'den "Cihaz bağlantısını kaldır" ile istediğiniz an kapatırsınız.

5.4. **Bilgilerin doğruluğu.** Bir uzmanın önerdiği çocuk bilgisini (ad, yaş grubu) kontrol etmek, gerekirse düzeltmek ve onaylamak sizin sorumluluğunuzdadır. Onayladığınız bilgi sizin beyanınız sayılır.

5.5. **Diğer veli.** Ailede birden fazla ebeveyn varsa, paylaşımı yapan ebeveyn diğer velinin bilgisi dahilinde hareket ettiğini kabul eder.

5.6. **Başkalarının verisi.** Adım açıklamalarına, notlara, mesajlara, davranış kayıtlarına, olay bildirimlerine ve eğitim yanıtlarına çocuğunuz dışındaki kişilerin (öğretmen, akraba, başka çocuk) kişisel bilgilerini gereğinden fazla yazmayın. Ses kaydı alırken başkalarının sesini onların bilgisi olmadan kaydetmeyin.

### 6. Uzmanla paylaşım

6.1. **Paylaşım sizin kararınızdır.** Çocuğunuzun kayıtları bir uzmanla yalnız siz davet kodunu ya da bağlantısını onaylayıp çocuğu seçtiğinizde ve açık rıza verdiğinizde (`uzman-paylasim-v1`) paylaşılır. Paylaşılanlar, uygulamada sizin bıraktığınız kayıtlardır; neyin paylaşıldığı ve kimin gördüğü Aydınlatma Metni 5.3'te yazılıdır.

6.2. **Uzmanı tanıma yükümlülüğü.** Platform uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunuzun verisini paylaşmadan önce uzmanı gerçek hayatta tanıdığınızı ve davetin ondan geldiğini kendiniz teyit edersiniz. Paylaşım kararı ve uzman seçimi tamamen sizindir. Emin değilseniz paylaşmayın; uzmanınızı bildiğiniz bir yoldan arayıp sorun.

6.3. **Açık rıza ekranı.** Bir uzmana bağlanırken uygulama ayrı bir açık rıza ekranı gösterir (`uzman-paylasim-v1`); ekranda neyin, kiminle paylaşılacağı yazar. Bu koşulları kabul ederek bu ekranın varlığını ve kapsamını bildiğinizi kabul edersiniz. Açık rıza bu koşulların parçası değildir ve hizmetin şartı yapılmaz: uzmana bağlandığınız anda ayrıca alınır ve istediğiniz an geri alınır (6.5). Rıza vermezseniz uzman çocuğunuzun hiçbir kaydını göremez.

6.4. **Uzmanın davetindeki çocuk bilgisi.** Uzman sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz kontrol edip onaylayana kadar yalnız davet kaydında tutulur; onaylamazsanız ya da davet süresi dolarsa silinir. Davet size ait değilse "Bu davet bana ait değil" deyin.

6.5. **Kapsam ve geri alma.** Hangi çocuğu hangi uzmanla paylaştığınızı, önceki uzman kayıtlarının aktarımını (`uzman-gecis-v1`) ve bunların ne zaman biteceğini siz yönetirsiniz. Uzmanım bölümünden istediğiniz an durdurursunuz; uzmanın erişimi hemen biter.

6.6. **Uzmanın önerileri.** Uzman size rutin ve adım önerebilir, ebeveyn eğitimi atayabilir, hedef davranış tanımlayabilir, randevu açabilir ve takip planı gönderebilir. Bunları kabul etmek, değiştirmek, uygulamak ya da reddetmek size kalmıştır.

6.7. **Uzman ile aile arasındaki ilişki.** Uzman ile aile arasındaki mesleki ilişki (hizmet, ücret, randevu, iletişim ve öneriler) yalnız onların arasındadır; Moyo bu ilişkinin tarafı, aracısı ya da güvencesi değildir. Her kullanıcı kendi girdiği kayıttan sorumludur. Uzmanın açtığı randevular uygulamada görünebilir; randevunun yapılması, ücreti ve içeriği sizinle uzman arasındadır. Uzmanın mesleki tutum ve kararlarından, yasanın izin verdiği en geniş ölçüde, sorumlu değiliz; kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır.

6.8. **Kötüye kullanım bildirimi.** Tanımadığınız birinden davet alırsanız ya da bir uzmandan şüphelenirseniz paylaşmayın ve `destek@moyoapp.com.tr` adresine bildirin. Hesabı inceler, gerekirse kapatırız.

6.9. **Onay kaydı.** Onayınız, onayladığınız metnin sürümü ve zamanıyla kaydedilir.

### 7. İkinci ebeveyn

7.1. Aileye ikinci bir ebeveyni, Moyo Ebeveyn'de ürettiğiniz 15 dakikalık tek kullanımlık davet koduyla davet edebilirsiniz. Davet ettiğiniz kişi kendi hesabını kullanır.

7.2. Aileye katılan ebeveyn aile verisini (çocuk profilleri, rutinler, ödüller, mesajlar, davranış kayıtları ve olaylar, uzman paylaşımları) sizinle birlikte görür ve yönetir. Yalnız güvendiğiniz ve çocuğunuz üzerinde velayet ya da bakım sorumluluğu olan kişiyi davet edin.

7.3. Katılan ebeveynin önceki ailesinde başka ebeveyn yoksa, o eski aile **ve bütün verisi silinir.** Uygulama bunu katılmadan önce uyarır.

7.4. Ebeveynlerden biri hesabını silerse aile ve veriler diğer ebeveynin hesabında kalır.

### 8. Abonelik, deneme ve ödeme

8.1. **Planlar.** Moyo Ebeveyn'in ücretsiz planı ve aylık ya da yıllık **Aile aboneliği** vardır. Abonelik aileye bağlıdır; ailedeki ebeveynler ve çocuklar birlikte yararlanır.

8.2. **Deneme.** Kayıt olup e-posta adresinizi doğruladığınızda 14 günlük ücretsiz deneme başlar ve bütün özellikler açılır. Başka bir ailenin size verdiği aile davet koduyla katılırsanız deneme 21 gün olur (8.10). Bir uzmanın daveti deneme süresini değiştirmez. Deneme için ödeme bilgisi istenmez; deneme bitince kendiliğinden ücretli aboneliğe dönüşmez. Kalan gün uygulamada görünür. Deneme her e-posta adresi için bir kez verilir.

8.3. **Ücretsiz plan.** Deneme bitince abone olabilir ya da ücretsiz planda devam edebilirsiniz. Ücretsiz planda bazı özellikler sınırlıdır. Bugünkü sınırlar: en çok 1 çocuk ve 3 etkin adım; ödüller, taş düşürme, çocuğa mesaj gönderme ve davranış kaydı kapalı. Adım onayı, Moyo Oyun ve uzman paylaşımı açıktır. Var olan kayıtlarınız silinmez; yalnız yeni ekleme sınırlanır. Güncel sınırlar Üyelik ekranında yazılıdır; daraltılırsa önceden duyururuz.

8.4. **Klinik üzerinden tam özellik.** Çocuğunuz, ücretli üyeliği etkin olan bir klinikteki uzmanla paylaşılıyorsa aileniz bu süre boyunca tam özellikleri ücretsiz kullanır. Paylaşım ya da kliniğin üyeliği biterse ve kendi aboneliğiniz yoksa ücretsiz plana dönersiniz. Bu bir kolaylıktır; uzmanla paylaşmanız için bir koşul değildir.

8.5. **Satıcı Apple'dır.** Aile aboneliği App Store'dan satın alınır. Satıcı Apple'dır; ücret Apple hesabınızdan alınır ve Apple'ın satış koşulları da geçerlidir. Kart bilgileriniz bize gelmez. Fiyat (Türk lirası, vergiler dahil) ve dönem, satın almadan önce satın alma ekranında gösterilir.

8.6. **Otomatik yenileme.** Abonelik, dönem bitmeden en az 24 saat önce otomatik yenilemeyi kapatmazsanız aynı süreyle kendiliğinden yenilenir. Yenileme ücreti, dönemin bitmesinden önceki 24 saat içinde Apple hesabınızdan alınır. Fiyat değişirse Apple'ın kurallarına göre önceden bilgilendirilirsiniz; Apple gerektiriyorsa onayınız istenir, onay vermezseniz abonelik dönem sonunda yenilenmez.

8.7. **İptal.** Aboneliğinizi her zaman, ek ücret ödemeden, kurduğunuz yoldan kapatabilirsiniz: iPhone'da **Ayarlar › [adınız] › Abonelikler › Moyo › Aboneliği İptal Et**, ya da Moyo Ebeveyn'de **Aile › Hesap › Üyelik › Aboneliği yönet**. İptal, ödediğiniz dönemin sonunda geçerli olur; dönem bitene kadar özellikleri kullanırsınız. İptal, aboneliği satın alan ebeveynin Apple hesabından yapılır. **Uygulamayı ya da hesabınızı silmek aboneliği iptal etmez.**

8.8. **Cayma hakkı ve iade.** Abonelik, satın alma onayınızla elektronik ortamda hemen başlayan bir hizmettir. Mesafeli Sözleşmeler Yönetmeliği md. 15/1-ğ uyarınca, elektronik ortamda anında ifa edilen hizmetlerde cayma hakkı kullanılamaz. Satıcı Apple olduğu için iade talepleri Apple'ın iade politikasına göre Apple'a yapılır (Apple'ın "Sorun bildir" sayfası: reportaproblem.apple.com). Biz doğrudan iade yapamayız; başvurunuzda `destek@moyoapp.com.tr` üzerinden yardımcı oluruz. Hizmet hiç ya da gereği gibi sunulmazsa kanundan doğan haklarınız saklıdır.

8.9. **Satın alımları geri yükleme.** Telefon değiştirirseniz Üyelik ekranındaki "Satın alımları geri yükle" ile aboneliğiniz hesabınıza yeniden bağlanır.

8.10. **Aile davet et.** Moyo Ebeveyn'de ürettiğiniz aile davet kodunu tanıdığınız başka bir aileyle kendi paylaşım yolunuzla paylaşabilirsiniz.
- Kod 60 gün geçerlidir ve bir kez kullanılır. Yalnız yeni bir ailede geçerlidir: denemesi başlayalı 14 günü geçmemiş, daha önce davet kodu kullanmamış, abone olmayan ve sizin aileniz olmayan bir aile. Kodu kullanan ailenin denemesi 21 gün olur.
- Davet ettiğiniz aile App Store'dan ilk kez ücretli aboneliğe geçerse ailenize 1 ay ücretsiz kullanım verilir; son 365 günde en çok 12 ay. Abone değilseniz ücretsiz süreniz hemen uzar. App Store'dan ödüyorsanız bu 1 ay Apple'ın teklif koduyla verilir ve bir sonraki yenilemede başlar.
- Davet ödülü paraya çevrilemez, devredilemez, satılamaz. Davet edilen aile aboneliğini iade alsa da verilen ödül geri alınmaz.
- Sahte hesaplarla ya da kendi hesabınıza davet ve öteki kötüye kullanımlarda ödül iptal edilir (10. madde).
- İki aile birbirinin kimliğini görmez; size yalnız kaç ailenin katıldığı ve kaç ay kazandığınız gösterilir.
- Davet programını değiştirebilir ya da sonlandırabiliriz; kazanılmış ödüller korunur.

8.11. **İndirim teklifleri.** Zaman zaman indirim teklif edebiliriz (ör. aboneliğinizi iptal etmek istediğinizde). Teklifin koşulları (fiyat, süre, süre sonundaki fiyat ve kendiliğinden yenilenme) teklif ekranında birlikte yazılır; teklifi kabul etmek zorunda değilsiniz ve iptal yolu her zaman açıktır (8.7).

### 9. Coin, Güneş Taşı ve ödüller

9.1. **Coin para değildir.** Coin yalnız sizin onayladığınız adımlarla (ve çocuk başına bir kez verilen hoş geldin hediyesiyle) kazanılır ve yalnız Moyo Oyun'daki oyun içi eşyalara harcanır. Satın alınamaz, paraya çevrilemez, başkasına devredilemez. Bir onayı geri alırsanız o adımın coini düşer. Hesap silinince coinler kaybolur.

9.2. **Güneş Taşı para değildir.** Güneş Taşı, onayladığınız adımlarla kazanılır ve çocuğunuza vereceğiniz ödüllerin sayacıdır. Para ya da ödeme aracı değildir; satın alınamaz, paraya çevrilemez. Kendi adımlarınızla ve uyguladığınız derslerle kazandığınız Güneş Taşlarını yalnız çocuğunuza oyunda hediye göndermek için kullanırsınız.

9.3. **Ödüller sizinle çocuğunuz arasındadır.** Ödülleri, taş karşılıklarını ve değiş tokuş oranlarını (ör. "1 taş = 10 dakika ekran süresi" ya da harçlık) siz belirler ve siz verirsiniz. Platform bu ödüllerin tarafı değildir: para tutmaz, ödeme almaz ya da yapmaz, ödülü sağlamaz ve ödülün verilip verilmemesinden sorumlu değildir.

9.4. **Taş düşürme** sizin kararınızdır; çocuğunuza bildirim gider. Önceden birlikte konuştuğunuz kurallar için ve seyrek kullanmanızı öneririz.

9.5. Teknik bir hata yüzünden yanlış yazılan coin ya da taşı düzeltebiliriz; düzeltmeyi size bildiririz.

### 10. Kabul edilemez kullanım

Moyo Ebeveyn'i şu amaçlarla kullanamazsınız:
- velisi ya da yasal temsilcisi olmadığınız bir çocuğu eklemek ya da paylaşmak;
- başkasının hesabına, ailesine ya da çocuk profiline erişmeye çalışmak; giriş ya da davet kodlarını yabancılarla paylaşmak;
- çocuğa zarar verebilecek, şiddet, taciz, nefret ya da cinsellik içeren, hukuka aykırı içerik göndermek;
- coin, Güneş Taşı, deneme süresi, davet ödülü ya da abonelik kurallarını aşmaya çalışmak (ör. sahte hesaplarla yeniden deneme almak, davet kodunu kendinize kullanmak);
- uygulamayı tersine mühendislikle çözmek, güvenliğini sınamak ya da otomatik araçlarla erişmek (izinli güvenlik bildirimleri için bize yazın);
- Moyo Ebeveyn'i ticari bir hizmet sunmak için kullanmak (uzmanlar Moyo Uzman'ı kullanır).

Bu kurallara aykırılıkta 14.2. madde uygulanır.

### 11. İçerik ve mesajlar

11.1. **Mesajlaşma aile içidir.** Mesajları yalnız siz, ailedeki diğer ebeveyn ve mesajın gittiği çocuk görür. Uzmanlar ve yabancılar göremez; kardeşler birbirinin sohbetini görmez.

11.2. **İçerik sorumluluğu.** Girilen kaydın doğruluğu ve içeriği girene aittir. Serbest metin alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazılmaması istenir; yazılan bilginin sorumluluğu yazandadır. Gönderdiğiniz yazı, fotoğraf, ses kaydı, adım açıklaması, not, davranış kaydı, olay bildirimi ve eğitim yanıtı çocuğunuza uygun olmalı ve başkalarının haklarını ihlal etmemelidir.

11.3. **İçeriğin sahibi sizsiniz.** Bize yalnız hizmeti sunmak için (saklamak, ailenize ve izin verdiğiniz uzmana göstermek, yedeklemek) sınırlı, ücretsiz ve devredilemez bir kullanım izni verirsiniz. Bu izin hesabınız silinince biter.

11.4. Mesaj içerikleri, fotoğraflar ve ses kayıtları ekip ekranlarımızda gösterilmez. Hukuka aykırı bir içerik bize bildirilirse ya da usulüne uygun kanuni bir talep olursa, yalnız o içerikle sınırlı inceleme yapabilir, içeriği kaldırabilir ya da hesabı askıya alabiliriz.

11.5. Kötüye kullanımı önlemek için mesaj sayısına ve uzunluğuna sınır uygulanır.

### 12. Fikri mülkiyet

Moyo Ebeveyn, Moyo Oyun ve Moyo Uzman'ın yazılımı, tasarımı, karakterleri, görselleri, sesleri, metinleri ve içerik kütüphanesi bize (`[AD SOYAD]`) ya da lisans verenlerimize aittir. Size, bu koşullar süresince, uygulamayı kişisel ve ailevi amaçla kullanmanız için kişisel, devredilemez, münhasır olmayan bir kullanım hakkı veririz. Uygulamayı kopyalayamaz, değiştiremez, satamaz ya da kiralayamazsınız. Sizin içeriğiniz size aittir (11.3).

### 13. Hizmet değişikliği ve kesinti

13.1. Moyo Ebeveyn'i geliştirmeye devam ederiz; özellikler eklenebilir, değişebilir ya da kaldırılabilir. Abonelikle sunulan esaslı bir özelliği kaldırırsak bunu önceden bildiririz.

13.2. **Hizmetin sunumu.** Hizmet olduğu gibi sunulur; kesintisiz ya da hatasız olacağı taahhüt edilmez. Bakım çalışmalarını mümkün olduğunca önceden duyururuz. İnternet, cihaz, Apple ya da hizmet sağlayıcı kaynaklı kesintiler olabilir.

13.3. Hatırlatmalar ve bildirimler gecikebilir ya da ulaşmayabilir. Önemli işleri yalnız uygulamanın hatırlatmasına bağlamayın.

13.4. Hizmeti tamamen sonlandırırsak bunu en az `[SÜRE]` önce bildiririz. Bu sürede verilerinizle ilgili taleplerinizi karşılarız.

### 14. Hesabın kapatılması ve silinmesi

14.1. **Sizin silmeniz.** Hesabınızı istediğiniz an Moyo Ebeveyn içinden (`[EKRAN YOLU: Aile › Hesap › Hesabımı sil]`) silebilirsiniz. Silme geri alınamaz:
- Ailede başka ebeveyn yoksa aile ve ona bağlı her şey (çocuk profilleri, rutinler, mesajlar, coin ve Güneş Taşı hareketleri, oyun yedekleri, uzman paylaşımları ve uzmanın bu çocuklar için tuttuğu kayıtlar) silinir. Çocuğunuzun oyunu bağlantının kapandığını görür.
- Ailede başka ebeveyn varsa aile ve veriler onun hesabında kalır; yalnız sizin hesabınız silinir.
- App Store aboneliğiniz kendiliğinden iptal olmaz; Apple'dan ayrıca kapatın (8.7).
- Kanunen saklamamız gereken kayıtlar Aydınlatma Metni 7. maddedeki sürelerle tutulur.

14.2. **Bizim kapatmamız.** Bu koşulları ağır biçimde ihlal ederseniz (ör. veli olmadığınız bir çocuğu eklemek, çocuğa zarar verecek içerik göndermek, sistemi kötüye kullanmak) önce uyarır ya da hesabı geçici olarak askıya alırız; çocuk güvenliğini tehlikeye atan durumlarda hesabı derhal kapatabiliriz. Nedenini size bildiririz. İtiraz için `destek@moyoapp.com.tr` adresine yazabilirsiniz. Haksız bir kapatmaya karşı kanuni haklarınız saklıdır.

### 15. Sorumluluk

15.1. **Platformun rolü.** Moyo Ebeveyn, ailenin kendi kayıtlarını tutmasını ve isterse bunları uzmanıyla paylaşmasını sağlayan bir teknoloji hizmetidir; uzmanları istihdam etmez, aracılık ya da yönlendirme yapmaz (3.2). Genel ilke 3.6'dadır.

15.2. **Uzman ve paylaşım kararı.** Uzmanın kimliği, yeterliliği ve davranışından, sizin paylaşım kararınızdan doğan sonuçlardan, kanunun izin verdiği ölçüde sorumlu değiliz.

15.3. **Kararlar.** Kayıtlara dayanarak verilen her karar kullanıcının kendi kararıdır. Moyo kayıtları değerlendirmez, yorumlamaz, kimseyi yönlendirmez. Rutinler, ödüller, taş düşürme, mesajlar ve çocuğunuzun cihaz kullanımıyla ilgili kararlar da sizindir.

15.4. **Bizim sorumluluğumuz.** Hizmeti makul özenle sunarız. Kontrolümüz dışındaki olaylardan (Apple'ın hizmetleri, internet ve cihaz arızaları, doğal afet gibi mücbir sebepler) doğan zararlardan, kanunun izin verdiği ölçüde sorumlu değiliz. **Sorumluluğun sınırı.** Moyo'nun sorumluluğu, yasanın izin verdiği en geniş ölçüde, doğrudan zararlarla ve son 12 ayda ödenen ücretle sınırlıdır. Kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır.

15.5. **Saklı kalan hükümler.** Bu maddedeki hiçbir hüküm, 15.4'teki sınır dahil:
- kast ya da ağır kusurumuzdan doğan sorumluluğumuzu kaldırmaz (TBK md. 115);
- tüketici olarak kanundan doğan haklarınızı sınırlamaz (6502 sayılı Kanun);
- kişisel verilerin güvenliğini sağlama yükümlülüğümüzü size ya da uzmana devretmez (KVKK md. 12).

15.6. **Sizin sorumluluğunuz.** Gerçeğe aykırı beyanınızdan (ör. veli olmadığınız hâlde çocuk eklemek) ya da başkalarının verisini hukuka aykırı girmenizden doğan, kusurunuza dayanan zararlardan siz sorumlusunuz.

### 16. Verilerin işlenmesi ve aktarımı

Hizmeti sunmak için aşağıdaki işlemleri yaparız. Bunlar bu sözleşmenin uygulanmasının parçasıdır; ayrıntıları ve her birinin hukuki sebebi Aydınlatma Metni'ndedir. **Bu madde açık rıza değildir.** Açık rıza gereken işlemler ayrı ekranlarda sorulur ve reddetmeniz hizmeti engellemez.

16.1. **Hizmet sağlayıcılar.** Verileriniz, hizmet için gereken ölçüde, bizim adımıza ve talimatımızla çalışan sağlayıcılarda işlenir: veritabanı ve barındırma (Supabase), e-posta gönderimi (Resend), bildirim (Apple; yedek yolda Expo), abonelik doğrulama (Apple, RevenueCat), yönetim paneli barındırma (Cloudflare). Sağlayıcılar veriyi kendi amaçlarıyla kullanmaz.

16.2. **Yurt dışı.** Bu sağlayıcıların sunucuları yurt dışında olabilir. Aktarımı KVKK md. 9'daki usule (standart sözleşme ve Kurul'a bildirim) uygun yaparız.

16.3. **Yetkili ekip erişimi.** Ekibimizin yetkili üyeleri yalnız destek, güvenlik ve kötüye kullanım incelemesi, abonelik sorunları ve kanuni yükümlülükler için; iki adımlı girişle, gerekçe yazarak ve her erişim değiştirilemez kayda geçerek hesap bilgilerinize ve kullanım kayıtlarınıza erişebilir. Mesaj içerikleri, fotoğraflar, ses kayıtları ve uzman notlarının metni ekip ekranlarında gösterilmez.

16.4. **Tanışma yanıtları.** İlk kurulumda verdiğiniz yanıtlar uygulamayı ailenize göre düzenlemek, destek vermek ve **kimliksiz toplamlar** hâlinde ürünü geliştirmek için kullanılır. Tanı ya da ilaç sorulmaz. Yanıtlarınızı kişi bazında ekip ekranında yalnız en yetkili rol (sahip) gerekçe yazarak açabilir; öteki ekip üyeleri yalnız kimliksiz toplamları görür. Yanıtlar uzmanla paylaşılmaz. Yanıtlarınızı istediğiniz an değiştirebilir ya da silebilirsiniz.

16.5. **Uzmanla paylaşım ve önceki uzman kayıtları.** Bunlar ayrı onay ekranlarıyla (`uzman-paylasim-v1`, `uzman-gecis-v1`) verilir; bu madde onların yerine geçmez.

16.6. **Kullanım verisi.** Uygulamayı açtığınız günler, sürüm, platform ve kullandığınız ekran ve özelliklerin adları; hizmetin işleyişini ölçmek, hataları bulmak ve ürünü geliştirmek için işlenir. Bu kayıtlarda serbest metin, mesaj ya da kayıt içeriği yoktur; üçüncü taraf reklam ya da izleme aracı kullanılmaz.

16.7. **Kanuni zorunluluk.** Mahkeme, savcılık ya da yetkili kamu kurumunun usulüne uygun talebi olursa veriler, talep kapsamıyla sınırlı olarak aktarılabilir. Kanun yasaklamıyorsa sizi bilgilendiririz.

16.8. **İşletme devri.** Birleşme, devir ya da varlık satışı olursa veriler aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa aktarılabilir. Sizi önceden bilgilendiririz; hesabınızı silme hakkınız saklıdır.

16.9. **Hesap silindikten sonra.** Kişisel verileriniz silinir. Yalnız kanunen saklanması gereken kayıtlar (ör. ödeme kayıtları) ve değiştirilemez denetim kaydı, sizi doğrudan tanıtan bilgi (e-posta) çıkarılarak saklama süresince tutulur.

16.10. **Bildirimler ve tanıtım iletileri.** Tanıtım ve kampanya bildirimi ya da e-postası yalnız ayrı izninizle gönderilir; bu izin Ayarlar'da ayrı bir anahtardır, kapalı başlar ve istediğiniz an kapatılır. İzin verirseniz iletiler kanunun öngördüğü kayıt sistemi (İYS) üzerinden ve her birinde ücretsiz ret yoluyla gönderilir. Hizmetle ilgili bildirimler ve e-postalar (hesap, abonelik, güvenlik, uzman paylaşımı) bu izne bağlı değildir; hangi bildirimlerin geleceğini Ayarlar'dan seçersiniz. Telefonla (SMS) doğrulama bugün yoktur; açılırsa telefon numaranızın nasıl işleneceği önceden ayrıca bildirilir.

### 17. Onay kaydı, koşulların değişmesi ve yeniden onay

17.1. Bu koşulları kayıt ekranında, önceden işaretlenmemiş kutuyu işaretleyerek kabul edersiniz. Hangi metni (Kullanım Koşulları, aydınlatma okundu bilgisi, açık rızalar) hangi sürümle ve ne zaman onayladığınız kaydedilir.

17.2. Koşulları değiştirmemiz gerekirse:
- **Esaslı değişiklikleri** (haklarınızı, ücretleri ya da verilerinizin kullanımını etkileyenler) yürürlükten en az `[SÜRE]` önce uygulamada bildiririz ve uygulama açılışında yeni sürümü onaylamanızı isteriz. Onaylamazsanız hesabınızı silebilir ve aboneliğinizi dönem sonunda bitirebilirsiniz.
- **Küçük değişiklikleri** (yazım düzeltmesi, iletişim bilgisi, lehinize değişiklik) bildirimle yaparız.
- Aleyhinize bir değişikliği onayınız olmadan uygulamayız.

17.3. Her metnin sürüm adı vardır ([Moyo Ebeveyn Kullanım Koşulları](/yasal/kosullar-parentapp) v1, v2 …). Önceki sürümler `moyoapp.com.tr` adresinde arşivlenir.

### 18. Uyuşmazlık

18.1. Bu sözleşmeye Türk hukuku uygulanır. Bir sorununuz olursa önce `destek@moyoapp.com.tr` adresine yazmanızı rica ederiz; bu zorunlu değildir.

18.2. Uyuşmazlıklarda, her yıl Ticaret Bakanlığının ilan ettiği parasal sınırın altında kalan konularda **Tüketici Hakem Heyetine**, sınırın üstündekilerde **Tüketici Mahkemesine** başvurabilirsiniz. Tüketici Mahkemesinde dava açmadan önce arabulucuya başvurmak kanunen gerekebilir.

18.3. Başvuruyu kendi yerleşim yerinizdeki ya da işlemin yapıldığı yerdeki Tüketici Hakem Heyetine ya da Tüketici Mahkemesine yapabilirsiniz.

18.4. App Store üzerinden yapılan ödeme ve iade konularında Apple'ın kendi koşulları ve başvuru yolları da geçerlidir.

### 19. İletişim

`[AD SOYAD]`, `[ADRES]`. İletişim (kişisel veri başvuruları dahil): `destek@moyoapp.com.tr`; KVKK başvurusunda konu satırına "KVKK başvurusu" yazmanızı rica ederiz.

### 20. Son hükümler

20.1. Bu koşulların dili Türkçedir.

20.2. Bir hüküm geçersiz sayılırsa diğer hükümler geçerliliğini korur.

20.3. Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`.
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('kosullar-gameapp', 'v1', 'Moyo Oyun Kullanım Koşulları', '{child}', true, $md$# Moyo Oyun Kullanım Koşulları

## Kısaca

- Bu koşulları **çocuğunuz değil, veli olarak siz** kabul edersiniz.
- Moyo Oyun ücretsizdir. **Reklam yok, uygulama içi satın alma yok, üçüncü taraf izleme yok.**
- Moyo sağlık hizmeti sunmaz, tanı koymaz; oyundaki göstergeler çocuğunuz hakkında bir değerlendirme değildir. Acil durumda 112'yi arayın.
- Çocuğunuz oyuna sizin Moyo Ebeveyn'de gösterdiğiniz 15 dakikalık tek kullanımlık kod ya da QR ile bağlanır.
- **Coin para değildir:** yalnız sizin onayladığınız maceralarla kazanılır, yalnız oyun içi eşyalara harcanır.
- Ayarlar, kamera izni ve dış bağlantılar **ebeveyn kapısının** arkasındadır. Soruyu çocuğunuza çözdürmeyin.
- Çocuğunuz **yalnız kendi ailesiyle** mesajlaşır.
- Bağlantıyı Moyo Ebeveyn'den istediğiniz an kaldırabilir, hesabınızı silerek çocuğun verisini de silebilirsiniz.

## Tam metin

### 1. Kapsam ve kabul

1.1. Bu koşullar, Moyo'yu işleten `[AD SOYAD]` ("biz") ile çocuğunu Moyo Oyun'a bağlayan veli ("siz") arasındadır. "Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer.

1.2. Bu koşulları **çocuğunuz kabul etmez.** Çocuğunuzu oyuna ilk kez bağlamadan önce Moyo Ebeveyn'de siz, veli ya da yasal temsilci olarak kabul edersiniz. Onayınız metnin sürümü ve zamanıyla kaydedilir.

1.3. Burada yazmayan her konuda **Moyo Ebeveyn Kullanım Koşulları** ([Moyo Ebeveyn Kullanım Koşulları](/yasal/kosullar-parentapp)) geçerlidir: sorumluluk, hizmet değişikliği, koşulların değişmesi ve yeniden onay, uyuşmazlık ve iletişim maddeleri dahil. Çocuğunuzun verisinin nasıl işlendiği **Moyo Oyun Aydınlatma Metni**'ndedir ([Moyo Oyun Aydınlatma Metni (Veli ve Çocuk)](/yasal/aydinlatma-cocuk)).

### 2. Oyun

2.1. Moyo Oyun, çocuğunuzun bir evcil hayvana baktığı, adayı geliştirdiği ve ailesinin verdiği maceraları takip ettiği bir oyundur. Moyo Ebeveyn'de verdiğiniz her adım, oyunda çocuğunuz için bir macera olur. Ücretsizdir.

2.2. Oyunda **reklam yoktur, uygulama içi satın alma yoktur,** üçüncü taraf analiz ya da izleme aracı yoktur.

2.3. Oyundaki seviye, deneyim puanı (XP), yıldızlar ve evcil hayvanın göstergeleri **yalnız oyun içindir;** çocuğunuz hakkında bir değerlendirme değildir. Evcil hayvan hastalanmaz ve ölmez.

2.4. **Tanı, tedavi ve acil durum.** Moyo sağlık hizmeti sunmaz, tanı koymaz, tedavi önermez; hiçbir gösterge tanı ya da puan değildir. Acil durum ve kriz hizmeti değildir; acil durumda 112 aranır. Moyo sağlık hizmeti, uzaktan sağlık hizmeti ya da tıbbi cihaz değildir; tıbbi bir amaçla tasarlanmamıştır.

### 3. Oyuna bağlanma ve kullanım

3.1. Çocuğunuzun e-postası ya da şifresi yoktur. Oyun, Moyo Ebeveyn'de ürettiğiniz 15 dakikalık tek kullanımlık kod ya da QR ile çocuğunuzun profiline bağlanır.

3.2. Kodu yalnız çocuğunuzun cihazında kullanın; başkasıyla paylaşmayın. Kodu kullanan cihaz çocuğunuzun maceralarını ve sizinle mesajlarını görebilir.

3.3. Cihaz değişirse yeni bir kodla bağlanırsınız; oyun sunucudaki yedekten kaldığı yerden devam eder.

3.4. **Çocuk.** 18 yaşından küçük çocuğun bu hizmetle ilgili hak ve yükümlülüklerini velisi ya da yasal temsilcisi olan ebeveyn kullanır ve üstlenir. Çocuğun hesabını veli açar ve yönetir; çocuğun kullanımından, çocuk adına verilen onaylardan ve girilen kayıtlardan ebeveyn sorumludur. Çocuğunuzun oyunu ne zaman ve ne kadar oynadığını gözetmek size aittir.

### 4. Coin ve Güneş Taşı

4.1. **Coin para değildir.** Coin yalnız sizin Moyo Ebeveyn'de onayladığınız maceralarla (ve çocuk başına bir kez verilen hoş geldin hediyesiyle) kazanılır. Yalnız oyun içi eşyalara harcanır. Oyunun içindeki hiçbir etkinlik coin vermez.

4.2. Coin satın alınamaz, paraya çevrilemez, başka bir çocuğa ya da hesaba devredilemez. Bir onayı geri alırsanız o maceranın coini düşer. Hesap silinince coinler ve oyun içi eşyalar kaybolur.

4.3. Bakiye her zaman sunucudaki bakiyedir. Bağlantı yokken yapılan bir harcama sunucuda kabul edilmezse eşya geri alınır.

4.4. **Güneş Taşı** da para değildir. Onayladığınız maceralarla kazanılır; çocuğunuz taşları adaya yerleştirebilir ve sizden ödül isteyebilir. Ödülleri ve karşılıklarını siz belirler, isteği siz onaylar ya da reddedersiniz. Ödüller sizinle çocuğunuz arasındadır; biz tarafı değiliz (Moyo Ebeveyn Kullanım Koşulları 9. madde).

### 5. Ebeveyn kapısı

5.1. Ayarlar, kamera izni, dış bağlantılar ve yasal bilgiler **ebeveyn kapısının** arkasındadır. Ebeveyn kapısı, bir yetişkinin çözeceği bir sorudur.

5.2. Lütfen soruyu çocuğunuza çözdürmeyin ve cevabını söylemeyin. Kapının arkasında yaptığınız ayarlardan siz sorumlusunuz.

5.3. Kamera yalnız giriş ekranında, yalnız QR okumak için açılır. Görüntü kaydedilmez ve gönderilmez.

### 6. Mesajlaşma yalnız ailedir

6.1. Çocuğunuz oyunda **yalnız kendi ailesindeki ebeveynlerle** mesajlaşır. Yabancılar, başka oyuncular ve uzmanlar çocuğunuza yazamaz, mesajları göremez. Kardeşler birbirinin sohbetini görmez.

6.2. Çocuğunuz yazı ve hazır çıkartma gönderebilir; dosya, fotoğraf ya da ses gönderemez. Kötüye kullanımı önlemek için mesaj sayısına sınır vardır.

6.3. Çocuğunuza gönderdiğiniz içerikten siz sorumlusunuz (Moyo Ebeveyn Kullanım Koşulları 11. madde).

### 7. Bağlantıyı kaldırma

7.1. Moyo Ebeveyn'de çocuğun "Cihaz bağlantısını kaldır" seçeneğiyle bir cihazın erişimini istediğiniz an kapatırsınız. Oyun "Bağlantın kapatıldı" der ve hesaba erişemez.

7.2. Cihazdaki oyun kaydı bu işlemle silinmez. Yeniden bağlanmak için yeni bir kod üretirsiniz.

### 8. Hesabın ve oyun kaydının silinmesi

8.1. Moyo Ebeveyn'de hesabınızı sildiğinizde, ailede başka ebeveyn yoksa çocuğunuzun sunucudaki bütün verisi (profil, maceralar, mesajlar, coin ve Güneş Taşı hareketleri, oyun yedeği) silinir. Ailede başka ebeveyn varsa veriler onun hesabında kalır.

8.2. Cihazdaki oyun kaydını silmek için oyunu cihazdan kaldırın.

8.3. Silme geri alınamaz.

### 9. Kabul edilemez kullanım

Oyunu ya da çocuğunuzun hesabını şu amaçlarla kullanamazsınız ve kullandıramazsınız: başka bir çocuğun koduyla bağlanmak; coin, taş ya da macera kurallarını aşmaya çalışmak; oyunu tersine mühendislikle çözmek, değiştirmek ya da otomatik araçlarla kullanmak. Bu durumda Moyo Ebeveyn Kullanım Koşulları 14.2. madde uygulanır.

### 10. Fikri mülkiyet

Moyo Oyun'un yazılımı, karakterleri, görselleri, müziği, sesleri ve metinleri bize (`[AD SOYAD]`) ya da lisans verenlerimize aittir. Size, bu koşullar süresince, oyunu çocuğunuzla kişisel ve ailevi amaçla kullanmanız için kişisel, devredilemez, münhasır olmayan bir kullanım hakkı veririz.

### 11. Sorumluluk

**Genel ilke.** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

**Uzman ile aile arasındaki ilişki.** Uzman ile aile arasındaki mesleki ilişki (hizmet, ücret, randevu, iletişim ve öneriler) yalnız onların arasındadır; Moyo bu ilişkinin tarafı, aracısı ya da güvencesi değildir. Her kullanıcı kendi girdiği kayıttan sorumludur.

**Sorumluluğun sınırı.** Moyo'nun sorumluluğu, yasanın izin verdiği en geniş ölçüde, doğrudan zararlarla ve son 12 ayda ödenen ücretle sınırlıdır. Kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. Sorumlulukla ilgili öteki konularda Moyo Ebeveyn Kullanım Koşulları 15. madde geçerlidir.

### 12. İletişim

`[AD SOYAD]`, `[ADRES]`. İletişim (kişisel veri başvuruları dahil): `destek@moyoapp.com.tr`; KVKK başvurusunda konu satırına "KVKK başvurusu" yazmanızı rica ederiz.

Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`.
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('sozlesme-uzman', 'v1', 'Moyo Mercek Uzman Hizmet Sözleşmesi', '{clinic}', true, $md$# Moyo Mercek Uzman Hizmet Sözleşmesi

## Kısaca

- **Moyo bir takip aracıdır:** Moyo, aile üyelerinin günlük rutin ve sorumlulukları kendi tercihleriyle kaydetmesini ve bu kayıtları görmesini sağlayan dijital bir takip aracıdır. Moyo Mercek, ebeveynin izniyle paylaştığı çocuğun ev rutinini takip etmenize; not, hedef, rutin ve adım önerisi, ebeveyn eğitimi ve takip planı hazırlamanıza yarar.
- **Sağlık hizmeti değildir:** Moyo sağlık hizmeti sunmaz, tanı koymaz, tedavi önermez; hiçbir gösterge tanı ya da puan değildir. Moyo sağlık hizmeti, uzaktan sağlık hizmeti ya da tıbbi cihaz değildir; tıbbi bir amaçla tasarlanmamıştır. Uzman istihdam etmez; aile ile uzman arasında aracılık ya da yönlendirme yapmaz; belirli bir sonuç taahhüt etmez.
- **Acil durum ve kriz izleme hizmeti değildir:** Ailenin kayıtları size gecikmeyle ulaşabilir. Risk gördüğünüzde 112'yi aramak ve aileyi uygun yere yönlendirmek sizin mesleki sorumluluğunuzdadır. Bu sınırlar uygulama ekranlarında ayrıca uyarı olarak tekrarlanmaz.
- **Mesleki sorumluluk sizdedir:** unvanınızın ve yetkinizin doğruluğu, mesleki değerlendirmeniz, meslek etiği, ebeveynin bilgilendirilmesi ve onayı, meslek sırrı, kayıt tutma ve saklama yükümlülüğü. Moyo kayıtları saklar ve gösterir; arşiv ya da dışa aktarma hizmeti taahhüt etmez. Kayıtlarınızı kendi beyanınızla ve sorumluluğunuzda girersiniz; bu kayıtlarda veri sorumlusu sizsiniz, Moyo veri işleyendir.
- **Aile bağı:** aile paylaşımı sonlandırınca o andan sonraki kayıtlarını göremezsiniz; aile hesabını ya da çocuğu silerse o aileye ait notlarınız ve kayıtlarınız da silinir. Saklamanız gereken kayıtları raporla ya da CSV olarak kendiniz indirirsiniz.
- **Moyo ilişkinin tarafı değildir:** aileyle aranızdaki mesleki ilişki (hizmet, ücret, randevu, iletişim, öneriler) yalnız sizin aranızdadır.
- **Davet:** yalnız tanıdığınız ve hizmet verdiğiniz ailelere; çocuk için yalnız ad ya da takma ad ve yaş grubu; sağlık bilgisi yazılmaz. Paylaşım yalnız ebeveynin onayıyla açılır, ebeveyn istediği an durdurur.
- **Kayıtlarınız:** Ebeveyn izin verirse sonraki uzmana adınız gizlenerek salt okunur açılabilir; buna şimdiden izin veriyorsunuz.
- **Üyelik:** App Store üzerinden (satıcı Apple), klinik sahibi birey olarak öder; 14 gün ücretsiz deneme; iptal Apple hesap ayarlarından. Üyelik bitince erişim kapanır, veriler silinmez; üyelik yenilenince kaldığınız yerden açılır.
- **Sorumluluk:** Moyo'nun sorumluluğu, yasanın izin verdiği en geniş ölçüde, doğrudan zararlarla ve son 12 ayda ödenen ücretle sınırlıdır; kast, ağır kusur, veri güvenliği yükümlülüğü ve kanunen sınırlanamayan hâller hariç.
- **Ekler:** Veri İşleme Eki bu sözleşmenin parçasıdır; kişisel verileriniz için Uzman Aydınlatma Metni'ni okuyun.

---

## 1. Taraflar, kabul ve sözleşmenin parçaları

1.1. Bu sözleşme, Moyo'yu işleten ve `[ADRES]` adresinde bulunan `[AD SOYAD]` ile Moyo Mercek'te hesap açan ya da bir kliniğin ekibine katılan uzman ("Uzman") arasında kurulur. "Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer. Bu sözleşmede Moyo'ya ya da Platforma yüklenen hak, yükümlülük ve sorumluluklar, onu işleten kişiye (`[AD SOYAD]`) aittir.

1.2. Uzman, hesap açarken kayıt ekranındaki onay kutusunu işaretleyerek bu sözleşmeyi okuduğunu ve kabul ettiğini beyan eder. Bir kliniğin ekibine sonradan katılan uzmandan ayrıca onay alınmaz; kendi hesabını açarken verdiği onay geçerlidir. Platform, onaylanan metnin anahtarını, sürümünü ve onay zamanını kaydeder. Sözleşme metni onaydan önce ve her zaman Moyo Mercek'te (Ayarlar › Yasal ve gizlilik) ve herkese açık adreste okunabilir.

1.3. Aşağıdakiler bu sözleşmenin ayrılmaz parçasıdır: **Ek-1 Veri İşleme Eki** ([Veri İşleme Eki (Moyo Mercek Uzman Hizmet Sözleşmesi, Ek-1)](/yasal/veri-isleme-eki)), **Ek-2 Alt işleyenler listesi**, **Ek-3 Moyo Mercek'teki kısa bilgilendirme metinleri** (bu belgenin sonunda). **Uzman Aydınlatma Metni** ([Moyo Mercek Uzman Aydınlatma Metni](/yasal/aydinlatma-uzman)) sözleşme değil, KVKK md. 10 uyarınca yapılan bilgilendirmedir.

1.4. Uzman, Moyo Mercek'i mesleki faaliyeti kapsamında kullandığını kabul eder.

## 2. Tanımlar

| Terim | Anlamı |
|---|---|
| Moyo ya da Platform | `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer (madde 1.1). Bu sözleşmede Moyo'ya ya da Platforma ilişkin hak, yükümlülük ve sorumluluklar onu işleten kişiye (`[AD SOYAD]`) aittir |
| Moyo Mercek | Platformun uzmanlar için sunduğu iPhone ve iPad uygulaması ve web sürümü (ailelere dönük ekranlarda adı Moyo Uzman) |
| Moyo Ebeveyn | Platformun ebeveynler için sunduğu uygulama |
| Moyo Oyun | Platformun çocuklar için sunduğu oyun |
| Klinik | Uzmanın Moyo Mercek'te çalıştığı alan: uzmanın kendi bireysel hesabı ya da bir kliniğin ekip hesabı. Bir uzman birden çok klinikte çalışabilir |
| Klinik sahibi | Kliniği kuran ya da sahipliği devralan uzman |
| Ekip üyesi | Klinik sahibinin ekibe katılma isteğini kabul ederek kliniğe katılan uzman |
| Koltuk | Bir klinikte aynı anda çalışabilecek uzman sayısı |
| Ebeveyn | Çocuğun velisi ya da yasal temsilcisi olduğunu beyan eden Moyo Ebeveyn kullanıcısı |
| Aile | Uzmanın Moyo Mercek'te birlikte çalıştığı ebeveyn ve çocuk |
| Paylaşım | Ebeveynin bir çocuğu açık rızasıyla bir klinikle paylaşması; etkin olduğu sürece uzman o çocuğun aile verisini salt okur |
| Aile verisi | Ebeveynin ve çocuğun Moyo Ebeveyn ve Moyo Oyun'da oluşturduğu veriler (rutinler ve adımlar, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, davranış kayıtları ve ses kayıtları, davranış olayları, ebeveyn eğitimi yanıtları gibi) |
| Uzman kayıtları | Uzmanın Moyo Mercek'e bir aile için girdiği notlar, hedefler ve değerlendirmeler, rutin ve adım önerileri, takip planı (aile programı), ebeveyn eğitimleri, hedef davranışlar, seans randevuları ve seans kayıtları, etiketler ve davet bilgileri |
| Takip planı | Uzmanın çocuk için kurduğu davranış hedefleri ve aile programı modülleri |
| Şablonlar | Platformun sunduğu adım şablonları, hazır rutinler, takip planı şablonları (alanlar, hedefler, modüller, paketler) ve rapor biçimleri |
| Kaynak kütüphanesi | Platformun sunduğu ebeveyn eğitimi içerikleri (okuma, çoktan seçmeli ve açık uçlu modüller) |

## 3. Hizmetin tanımı ve niteliği

3.1. **Ne sunuyoruz.** Moyo, aile üyelerinin günlük rutin ve sorumlulukları kendi tercihleriyle kaydetmesini ve bu kayıtları görmesini sağlayan dijital bir takip aracıdır. Moyo Mercek, bu aracın uzmanlara yönelik bölümüdür ve uzmanın:
   - a) aileyi davet etmesine ve ebeveynin onayıyla paylaşılan çocuğun aile verisini salt okumasına,
   - b) aile için not tutmasına, hedef tanımlamasına ve değerlendirme yapmasına,
   - c) aileye rutin ve adım önerisi, ebeveyn eğitimi, hedef davranış ve takip planı göndermesine,
   - ç) seanslarını planlamasına ve seans kaydı tutmasına,
   - d) yazdırılabilir rapor ve indirilebilir özet (ilerleme notu, CSV) almasına,
   - e) klinik ekibini ve aile atamalarını yönetmesine
   yarayan bir yazılım aracıdır.

3.2. **Sağlık hizmeti değildir.** Moyo sağlık hizmeti sunmaz, tanı koymaz, tedavi önermez; hiçbir gösterge tanı ya da puan değildir. Acil durum ve kriz hizmeti değildir; acil durumda 112 aranır. Moyo sağlık hizmeti, uzaktan sağlık hizmeti ya da tıbbi cihaz değildir; tıbbi bir amaçla tasarlanmamıştır. Platform uzman istihdam etmez; uzman ile aile arasında aracılık, eşleştirme ya da yönlendirme yapmaz; uzman rehberi ya da listesi yayımlamaz.

3.2-a. **Uzman ile aile arasındaki ilişki.** Uzman ile aile arasındaki mesleki ilişki (hizmet, ücret, randevu, iletişim ve öneriler) yalnız onların arasındadır; Moyo bu ilişkinin tarafı, aracısı ya da güvencesi değildir. Her kullanıcı kendi girdiği kayıttan sorumludur. Mesleki kararlar Uzmanındır (madde 6.1).

3.3. **Göstergeler, içerik ve sonuç.** Moyo Mercek'teki oranlar, grafikler, hedef değerlendirmeleri ve raporlar, ailenin uygulamada bıraktığı kayıtların özetidir; zekâ ya da dikkat puanı da değildir ve mesleki değerlendirmenin yerini tutmaz. Moyo'nun içeriği (kaynak kütüphanesindeki ebeveyn eğitimi içerikleri, hazır rutinler ve takip planı şablonları) genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz. Şablonlar ve içerikler uzmanın kendi programını hızlı kurması için sunulur; bir şablonun ya da içeriğin aileye uygun olup olmadığına uzman karar verir. Bu içeriğe dayanılarak verilen kararlardan ve bunların sonuçlarından, yasanın izin verdiği en geniş ölçüde, Moyo sorumlu değildir; kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. Moyo belirli bir sonuç, gelişme ya da davranış değişikliği taahhüt etmez.

3.4. **Acil durum ve kriz izleme hizmeti değildir.** Moyo Mercek kriz izleme ya da acil uyarı aracı değildir. Ailenin kayıtları Uzmana gecikmeyle ulaşabilir; Platform bu kayıtları değerlendirmez ve anlık olarak gözden geçirmez. Uzman; çocuğun ya da başkasının hayatı, sağlığı veya güvenliği için risk gördüğünde 112'yi aramaktan, aileyi uygun sağlık kuruluşuna yönlendirmekten ve mevzuattan doğan bildirim yükümlülüklerini yerine getirmekten kendisi sorumludur.

3.4-a. **Sınırların bildirimi.** 3.2–3.4'teki sınırlar Moyo Mercek ekranlarında ayrıca uyarı olarak tekrarlanmaz; Uzman bu sözleşmeyi kabul ederek bunları bildiğini kabul eder. Yalnız kaynak kütüphanesi ekranının altında bir kez "Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz." yazar. Uzmanın dışa aktardığı belgelerin (rapor, ilerleme notu, CSV) altında tek satır yer alır: "Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir." (Ek-3).

3.5. **Uzaktan sağlık hizmeti aracı değildir.** Moyo Mercek'te uzman ile aile arasında görüntülü ya da sesli görüşme ve serbest mesajlaşma özelliği yoktur. Uzman aileye yalnız rutin ve adım önerisi (kısa not dahil), ebeveyn eğitimi, hedef davranış, takip planı, randevu bilgisi ve hatırlatma gönderebilir; ebeveyn yalnız bunlara bağlı kısa yanıt ve not bırakabilir.

3.6. **Hizmetin sunumu.** Hizmet olduğu gibi sunulur; kesintisiz ya da hatasız olacağı taahhüt edilmez. Bakım, güncelleme, hizmet sağlayıcı kesintisi ya da mücbir sebep nedeniyle hizmet geçici olarak durabilir. Platform özellik ekleyebilir, değiştirebilir ya da kaldırabilir; uzmanın ödediği hizmetin esaslı bir bölümünü kaldıracaksa bunu en az `[SÜRE]` (öneri: 30 gün) önce bildirir.

3.7. **Genel ilke.** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

## 4. Hesap, klinik ve ekip

4.1. **Hesap.** Uzman kayıtta doğru ad, unvan ve e-posta bilgisi verir ve bunları güncel tutar. Her uzman kendi hesabını kullanır; hesap paylaşılamaz. Şifrenin ve hesaba erişilen cihazların güvenliği uzmandadır; uzman, hesabının yetkisiz kullanıldığını fark ederse derhal `destek@moyoapp.com.tr` adresine bildirir.

4.2. **Klinik.** Kayıtla birlikte uzman adına bir klinik oluşur ve uzman o kliniğin sahibi olur. Bireysel çalışan uzmanda klinik adı uzmanın adıdır (bireysel hesap). Uzman ayrıca kendi kliniğini kurabilir ve başka kliniklerin ekibine katılabilir. Her klinik ayrı bir çalışma alanıdır: aile, davetin gönderildiği kliniğe aittir; klinikler birbirinin ailelerini ve kayıtlarını görmez.

4.3. **Ekip.** Klinik sahibi, paketinin izin verdiği koltuk sayısı kadar uzmanı ekibine ekleyebilir: uzmanın kişisel koduyla ekibe katılma isteği gönderir, uzman isteği kabul edince kliniğe katılır (bugün Bireysel pakette 1, Klinik paketinde ekip dahil en çok 10 uzman; güncel sayılar Üyelik ekranında). Klinik sahibi kliniğin bütün paylaşımlarını görür; ekip üyesi yalnız sorumlusu olduğu ya da klinik sahibinin kendisine atadığı aileleri görür. Ailenin sorumlu uzmanını ve ekip erişimini yalnız klinik sahibi değiştirir; ekip üyesi yalnız kendi sorumluluğunu bırakabilir. Ekip üyelerinin aile davet edip edemeyeceğini klinik sahibi belirler. Ekip üyesi klinikten ayrılabilir, klinik sahibi ekip üyesini ekipten çıkarabilir; ayrılan ya da çıkarılan uzmanın o klinikteki ailelere erişimi hemen biter, kliniğin kayıtları klinikte kalır.

4.4. **Klinik sahibinin sorumluluğu.** Klinik sahibi;
   - a) ekibe yalnız kliniğinde mesleki hizmet veren ve meslek icra yetkisi bulunan kişileri almayı,
   - b) ailelere erişimi yalnız o aileyle çalışması gereken ekip üyelerine açmayı,
   - c) ekip üyelerinin meslek sırrına ve bu sözleşmeye uymasını sağlamayı,
   - ç) kliniğinden ayrılan bir ekip üyesini derhal ekipten çıkarmayı ya da çıkarılması için Platforma başvurmayı
   üstlenir. Klinik sahibi, ekip üyelerinin bu sözleşmeye aykırı davranışlarından doğan zararlardan, borcun ifasında yardımcı kişi kullananın sorumluluğuna ilişkin genel hükümler (TBK md. 116) çerçevesinde Platforma karşı sorumludur. Her ekip üyesi ayrıca kendi eylemlerinden bizzat sorumludur.

4.5. **Hesabın silinmesi ve ekip.** Uzman hesabını sildiğinde: tek kişilik klinik bütün uzman kayıtları, paylaşımları, davetleri ve üyelik kayıtlarıyla birlikte silinir; ekipte başka uzman varsa klinik ve kayıtları kalır, hesabını silen klinik sahibiyse sahiplik kliniğin en eski üyesine geçer, ekip üyesiyse sorumlusu olduğu aileler klinik sahibine kalır. Klinik silindiğinde ailelerin Moyo Ebeveyn'deki kendi kayıtları silinmez: ailenin girdiği ebeveyn eğitimi yanıtları ve davranış olayları, aileye açılmış eğitimin içeriğiyle birlikte ailede salt okunur kalır; Uzmanın ve kliniğin bunlara erişimi kapanır. App Store üyeliği Apple hesabından ayrıca iptal edilir.

## 5. Uzmanın beyan ve taahhütleri

5.1. Uzman;
   - a) kimliğinin, mesleki unvanının ve meslek icra yetkisinin doğru olduğunu, unvan alanına sahip olmadığı bir unvanı ya da uzmanlığı yazmayacağını,
   - b) mesleğini yürürlükteki mevzuata ve bağlı olduğu meslek kuruluşunun kurallarına uygun icra ettiğini,
   - c) Moyo Mercek'te yalnız tanıdığı ve hizmet verdiği ailelere davet gönderdiğini, davet bağlantısını ya da kodunu yalnız ilgili ebeveyne ilettiğini,
   - ç) Moyo Mercek'i yalnız aileye verdiği mesleki hizmet kapsamında ve çocuğun yararına kullanacağını
   beyan ve taahhüt eder.

5.2. Gerçeğe aykırı beyan ya da kötüye kullanım hâlinde Platform hesabı derhal askıya alabilir ya da kapatabilir, ilgili kayıtları yetkili mercilerle paylaşabilir; Uzman bundan doğan zararı tazmin eder (madde 15.5).

## 6. Mesleki sorumluluk ve etik

6.1. **Mesleki kararlar uzmanındır.** Kayıtlara dayanarak verilen her karar kullanıcının kendi kararıdır. Moyo kayıtları değerlendirmez, yorumlamaz, kimseyi yönlendirmez. Uzman kayıtlarının, rutin ve adım önerilerinin, ebeveyn eğitimlerinin, hedef davranışların ve takip planının içeriği uzmanın mesleki kararıdır. Uzman girdiği her kaydı kendi beyanıyla ve kendi sorumluluğunda girer; Moyo bu içeriği denetlemez, doğrulamaz, onaylamaz ve bunun için bir sorumluluk ya da yükümlülük üstlenmez.

6.2. **Meslek etiği ve onam.** Uzman, bağlı olduğu meslek kuruluşunun etik kurallarına (ör. Türk Psikologlar Derneği Etik Yönetmeliği) uyar. Ebeveyni Moyo Mercek'i kullanacağı konusunda bilgilendirmek ve meslek kurallarının gerektirdiği onamı almak uzmanın yükümlülüğüdür. Ebeveynin Moyo Ebeveyn'de verdiği paylaşım onayı (`uzman-paylasim-v1`) ve önceki uzman kayıtlarına ilişkin açık rızası (`uzman-gecis-v1`), Platformun sistemindeki paylaşımın dayanağıdır; uzmanın meslek kurallarından doğan bilgilendirme ve onam yükümlülüğünün yerine geçmez.

6.3. **Meslek sırrı ve gizlilik.** Uzman, Moyo Mercek'te öğrendiği bilgiler bakımından meslek sırrı yükümlülüğü altındadır. Yazdırdığı ya da indirdiği belgeleri (rapor, ilerleme notu, CSV), ekran görüntülerini ve Moyo Mercek'e eriştiği cihazları korur; ortak kullanılan bilgisayarda oturumunu kapatır; aileye ilişkin bilgiyi yalnız mesleki gereklilik ölçüsünde paylaşır.

6.4. **Kayıt tutma ve saklama yükümlülüğü uzmanındır.** Uzman, mesleki değerlendirmesinden, birlikte çalıştığı aileyle ilişkisinden ve mevzuatın kendisine yüklediği kayıt tutma ve saklama yükümlülüklerinden kendisi sorumludur; bu yükümlülükler Moyo'ya geçmez. Moyo kayıtları saklar ve gösterir (madde 9.1); Platform bir arşiv ya da dışa aktarma hizmeti taahhüt etmez (madde 14.5). Ebeveyn paylaşımı durdurduğunda uzmanın o çocuğun aile verisine erişimi hemen biter; ebeveyn hesabını ya da çocuğun profilini sildiğinde o çocuğa bağlı paylaşım ve uzman kayıtları da silinir; üyelik bittiğinde erişim kapanır (madde 10.7). Uzman, mevzuat ya da meslek kuralları gereği saklaması gereken kayıtları Moyo Mercek'ten bağımsız olarak kendi sisteminde saklar.

6.4-a. **Aile bağı koparsa.** Uzman, hesap açarken aşağıdakileri bildiğini kabul eder:
   - a) Aile paylaşımı sonlandırınca Uzman o andan sonra ailenin yeni kayıtlarını göremez.
   - b) Aile hesabını ya da çocuğun profilini silerse Uzmanın o aileye ait notları ve kayıtları da silinir.
   - c) Uzman hesabını silerse ailenin kendi girdiği kayıtlar ailede kalır (madde 4.5).
   Bu kurallar ailenin kendi verisi üzerindeki kontrolünü ve KVKK'dan doğan silme hakkını korur; kayıtlar aileye bağlı takip kayıtlarıdır ve Moyo bir arşiv sistemi değildir (madde 9.1). Uzmanın yasal kayıt ve saklama yükümlülüğü Uzmandadır (madde 6.4); Uzman gerektiğinde raporu, ilerleme notunu ve CSV'yi kendisi indirir (madde 14.5). Ailenin bu kararlarından doğan erişim kaybından Platform sorumlu değildir (madde 15.2-c).

6.5. **İçerik sorumluluğu ve en az veri.** Girilen kaydın doğruluğu ve içeriği girene aittir. Serbest metin alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazılmaması istenir; yazılan bilginin sorumluluğu yazandadır. Uzman, serbest metin alanlarına (not, etiket, hedef açıklaması, seans kaydı, ebeveyne not) yalnız mesleki olarak gerekli bilgiyi yazar; kendisinin, ailenin ya da üçüncü kişilerin kimlik ve iletişim bilgilerini yazmaz.

## 7. Aile daveti, çocuk bilgisi ve paylaşım

7.1. **Davet.** Uzman, "Aileyi davet et" ekranında ebeveynin e-posta adresini, isterse çocuğun adını ya da takma adını ve yaş grubunu ve yalnız kendisinin göreceği bir not girer. Davet 3 gün geçerlidir; ebeveyn daveti bu sürede hesabına bağlarsa çocuk paylaşımı için 30 gün içinde kullanılabilir. Uzman isterse davete taslak bir takip planı ekleyebilir; aile daveti kabul etmezse taslak plan silinir.

7.2. **Davette çocuk bilgisi (aile onayından önce).** Uzman, aileyi davet ederken çocuğun yalnız adını ya da takma adını ve yaş grubunu girebilir; doğum tarihi, tanı, sağlık bilgisi ya da fotoğraf girmez. Uzman, bu bilgiyi girmeden önce ebeveynle görüştüğünü ve daveti onun bilgisiyle gönderdiğini beyan eder. Platform bu bilgiyi uzman adına ve yalnız daveti iletmek ve ebeveynin onayına sunmak amacıyla tutar; ebeveyn onaylayana kadar başka hiçbir amaçla işlemez ve yalnız daveti kendi ailesine bağlamış ebeveyne gösterir. Ebeveyn bilgiyi düzeltebilir; düzeltme uzmana bildirilir ve aile listesine yansır. Ebeveyn onaylamaz, reddeder ya da davet süresi dolarsa bilgi silinir (bağlanmamış davette 3 gün, bağlanmış ama onaylanmamış davette en geç 30 gün). Bilginin yanlış ya da hukuka aykırı girilmesinden uzman sorumludur.

7.3. **Davet e-postası.** Uzman, ebeveynin e-posta adresini ebeveynin bilgisi dahilinde ve yalnız o aileyi davet etmek için girer. Platform bu adresi uzman adına yalnız davet e-postasını (sınırlı sayıda yeniden gönderimle) iletmek ve ebeveyn kayıt olup e-postasını doğruladığında daveti eşleştirmek için kullanır; pazarlama ya da başka bir amaçla kullanmaz. E-posta yalnız hizmet bilgisi içerir (reklam, fiyat, kampanya içermez); konu satırında unvan, metinde çocuğun adı, uzmanın notu ve sağlık bilgisi yer almaz. E-postada gönderen adı olarak uzmanın adı görünür, yanıtlar uzmanın e-posta adresine gider; altta kimin adına gönderildiği ve aydınlatma metni bağlantısı bulunur. Uzman, daveti kodu kopyalayarak kendisi iletirse doğru kişiye ve güvenli bir yoldan iletilmesinden kendisi sorumludur.

7.4. **Paylaşım yalnız ebeveynin onayıyla.** Çocuğun aile verisi uzmana, ancak ebeveyn uzmanın kim olduğunu görüp çocuğu seçerek açık rızasını verdiğinde açılır. Uzman, ailenin açık rızası olmadan ailenin hiçbir kaydını göremez. Bu rıza ebeveynden Moyo Ebeveyn'de ayrı bir ekranda alınır (`uzman-paylasim-v1`) ve ebeveyn tarafından her an geri alınabilir. Platform uzmanların kimliğini ve mesleki belgelerini doğrulamadığını ebeveyne açıkça bildirir ve ondan uzmanı tanıdığını ve çocuğun velisi olduğunu beyan etmesini ister.

7.5. **Uzmanın gördüğü aile verisi.** Paylaşım etkin olduğu sürece uzman çocuğun rutin ve adımlarını, atamalarını, tamamlamalarını, "Yapamam" nedenlerini, ebeveynin notlarını, davranış kayıtlarını (ses kaydı dahil), ebeveynin bildirdiği davranış olaylarını, ebeveyn eğitimi yanıtlarını (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar; uzmanın önerdiği derslerde uygulama günleri), randevulara verilen yanıtları ve takip planı uygulama kayıtlarını **salt okur**. Aile içi mesajlar, coin defteri ve oyun kaydı uzmana gösterilmez. Uzman bu verileri yalnız aileye verdiği mesleki hizmet için kullanır; başka amaçla kopyalamaz, üçüncü kişilere vermez.

7.6. **Paylaşımın sona ermesi.** Ebeveyn paylaşımı istediği an durdurabilir; uzman da görebildiği aile için paylaşımı sonlandırabilir. Paylaşım sona erince uzmanın o çocuğun aile verisine erişimi hemen biter; uzman o andan sonraki kayıtları göremez. Bugünkü sistemde uzman, üyeliği etkin olduğu sürece sona ermiş paylaşıma ait kendi uzman kayıtlarını okuyabilir ve silebilir; ancak yeni kayıt ekleyemez ve mevcut kayıtları değiştiremez.

## 8. Uzmanın kimliği ve unvanı

8.1. Platform uzmanın kimliğini, mesleki unvanını ve meslek icra yetkisini doğrulamaz; belge incelemesi yapmaz ve ailelere uzman hakkında bir doğrulama, rozet ya da yetki beyanı göstermez. Ailelere yalnız Uzmanın beyan ettiği ad, unvan ve klinik adı gösterilir. Bu bilgilerin doğruluğu Uzmanın beyanıdır ve sorumluluğundadır (madde 5).

## 9. Uzman kayıtlarının niteliği ve uzman değişiminde aktarım

9.1. **Kayıtların niteliği.** Uygulamadaki kayıtlar, kullanıcıların kendi girdiği takip kayıtlarıdır. Moyo bu kayıtları saklar ve gösterir; bir sağlık kaydı, hasta dosyası ya da arşiv sistemi tutmaz. Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Uzmanın Moyo Mercek'e girdiği notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, ebeveyn eğitimleri, hedef davranışlar, seans kayıtları ve aile programı, ebeveynin rızasıyla paylaşılan çocuğa ilişkin kayıtlardır. Notlar, hedef değerlendirmeleri, seans kayıtları ve ebeveyn eğitimindeki gözlem verisi aileye gösterilmez; uzmanın aileye açık bıraktığı hedefler, "Aileye gönder" dediği takip planı, gönderdiği rutin ve adım önerileri, Etkin yaptığı ebeveyn eğitimleri, ebeveyn kaydına açtığı hedef davranışlar ve aileye gösterilmesini seçtiği randevular ilgili ebeveynlere gösterilir.

9.2. **Süreklilik için aktarım.** Ebeveyn çocuğun takibini başka bir uzmana taşıdığında ve açıkça izin verdiğinde, bu kayıtlar sonraki uzmana salt okunur olarak açılabilir. **Uzman bu aktarıma şimdiden izin verir** ve bu izin Veri İşleme Eki'nde Platforma verilmiş bir talimattır.

9.3. **Kimliğin gizlenmesi.** Aktarımda uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgisi gösterilmez; sonraki uzman yalnız "Önceki uzman 1" gibi bir sıra adı ve dönemi (ay olarak) görür. Kayıtlarda geçen uzman ve klinik adları ile e-posta ve telefon bilgileri otomatik gizlenir. Bu gizleme en iyi çabayla yapılır; yazım hatalı ya da kısaltılmış adlar yakalanamayabilir. Uzman, serbest metin alanlarına kendisinin ya da başka kişilerin kimlik bilgisini yazmamayı kabul eder.

9.4. **Değiştirilmezlik.** Sonraki uzman aktarılan kayıtları değiştiremez ve silemez; kayıtlar tarihleriyle, aktaran uzmanın o tarihteki gözlemi olarak gösterilir.

9.5. **Rızanın geri alınması.** Ebeveyn izni geri alınca sonraki uzmanın aktarılan kayıtlara erişimi derhal sona erer.

9.6. **Hesabın kapanması.** Bugünkü sistemde tek kişilik klinik silinince kayıtları da silinir ve aktarım biter; ekipte başka uzman varsa kayıtlar klinikte kalır ve aktarım sürebilir.

9.7. **Sorumluluk.** Aktarılan kayıtlar tanı değildir. Sonraki uzman kendi mesleki değerlendirmesinden sorumludur; önceki uzman, kaydı yazdığı tarihteki gözleminin sonradan nasıl kullanıldığından sorumlu tutulamaz.

9.8. **Devralan uzmanın yükümlülüğü.** Uzman, kendisine aktarılan kayıtları yalnız çocuğun takibinin sürekliliği için okur; kayıtlardan önceki uzmanın kimliğini çıkarmaya çalışmaz. Gizlemenin yakalayamadığı bir kimlik bilgisi görürse bunu kullanmaz ve Platforma bildirir.

9.9. **Saklama.** Paylaşım bittikten sonra kayıtların saklanması ve imhası Veri İşleme Eki'ne ve madde 14'e tabidir.

## 10. Üyelik ve ödeme

10.1. **Paketler.** Moyo Mercek, Bireysel ve Klinik paketleriyle, aylık ya da yıllık dönemlerle sunulur. Paketlerin içeriği, koltuk sayısı ve KDV dahil fiyatı Moyo Mercek'in Üyelik ekranında ve App Store'da satın almadan önce gösterilir.

10.2. **Satıcı Apple'dır.** Üyelik App Store üzerinden, uygulama içi satın alma olarak satılır. Ödeme, faturalama, iade ve otomatik yenileme Apple'ın kurallarına ve Apple Medya Hizmetleri Hüküm ve Koşulları'na tabidir. Platform kart bilgisini görmez; üyelik durumunu Apple ve RevenueCat'ten gelen bildirimlerle doğrular. Satın almaya ilişkin belge ve makbuzlar Apple tarafından sağlanır.

10.3. **Ödeyen klinik sahibidir.** Üyeliği yalnız klinik sahibi, kendi Apple hesabıyla ve birey olarak satın alır. Üyelik kliniğe aittir ve paketin izin verdiği ölçüde kliniğin bütün ekibine erişim sağlar; ekip üyeleri o klinik için ayrıca ödeme yapmaz. Bireysel pakette yalnız klinik sahibi erişir. Birden çok klinikte çalışan uzman için üyelik her klinikte ayrıdır: kendi bireysel hesabında ailesi olan uzman bunun için ayrıca üyelik alır. Moyo Mercek web sürümünde satın alma yapılmaz; iPhone ya da iPad'deki Moyo Mercek'te alınan üyelik, uzman hesabına bağlı olduğu için web sürümünde de geçerlidir.

10.4. **Deneme süresi.** Yeni uzman, ödeme bilgisi istenmeden 14 (on dört) gün ücretsiz deneme süresinden yararlanır; App Store aboneliğine ayrıca ücretsiz deneme eklenmez. Uzmanın sonradan açtığı klinik ya da bireysel hesap yeni bir deneme süresi başlatmaz. Deneme süresinin sonunda ücretli pakete geçilmezse hiçbir ücret alınmaz ve erişim madde 10.7'ye göre kapanır. Platform deneme süresini kendi takdiriyle uzatabilir.

10.5. **Otomatik yenileme ve iptal.** App Store üyelikleri, iptal edilmedikçe her dönem sonunda aynı süre için otomatik yenilenir ve ücret Apple hesabına yansıtılır. Klinik sahibi üyeliğini her zaman Apple hesabının abonelik ayarlarından (iPhone/iPad: Ayarlar › Apple hesabı › Abonelikler) iptal edebilir; yenilemenin durması için iptalin Apple'ın belirlediği süre içinde (bugün dönem bitiminden en az 24 saat önce) yapılması gerekir. İptal, ödenmiş dönemin sonunda geçerli olur. Moyo Mercek hesabını silmek üyeliği kendiliğinden iptal etmez.

10.6. **Elle tanımlanan üyelik.** Platform; pilot çalışma, kurumsal anlaşma ya da benzeri durumlarda kliniğe yönetim paneli üzerinden süreli üyelik tanımlayabilir. Bu üyeliğin koşulları ve süresi uzmana ayrıca yazılı olarak bildirilir; süre sonunda ücretli pakete geçilmezse erişim madde 10.7'ye göre kapanır.

10.7. **Üyelik ya da deneme bitince.** Bir klinikte etkin deneme ya da üyelik yoksa uzman o klinikteki ailelerin aile verisine, uzman kayıtlarına, rutin ve adım önerilerine ve davet özelliğine erişemez; Moyo Mercek o klinik için panel yerine Üyelik ekranını gösterir. Bu durumda veriler silinmez; madde 14.4'e göre saklanır ve üyelik yenilenince erişim kaldığı yerden açılır. Bireysel pakette ekip üyelerinin erişimi kapalıdır.

10.8. **Fiyat değişikliği.** Platform paket fiyatlarını değiştirebilir. Değişiklik mevcut üyelere Apple'ın kurallarına uygun olarak önceden bildirilir ve bir sonraki yenileme döneminden itibaren uygulanır; kabul etmeyen klinik sahibi üyeliğini iptal edebilir.

10.9. **İade.** İade talepleri Apple'ın iade süreci üzerinden yapılır ve Apple'ın kararına tabidir. Mevzuatın tanıdığı haklar saklıdır.

10.10. **Ailelere tanınan avantajlar.** Platform, etkin üyeliği olan kliniklere bağlı ailelere Moyo Ebeveyn'de ek özellikler sunabilir. Bu avantajlar Platformun takdirindedir, değiştirilebilir ve uzman bakımından bu sözleşmeden doğan bir hak oluşturmaz.

10.11. **İndirim teklifleri.** Platform zaman zaman indirim teklif edebilir (ör. klinik sahibi üyeliğini iptal etmek istediğinde). Teklifin koşulları (fiyat, süre, süre sonundaki fiyat ve kendiliğinden yenilenme) teklif ekranında birlikte yazılır; teklifi kabul etmek zorunlu değildir ve iptal yolu her zaman açıktır (madde 10.5).

## 11. Kabul edilemez kullanım

11.1. Uzman Moyo Mercek'i şu amaçlarla kullanamaz:
   - a) tanımadığı ya da hizmet vermediği kişilere davet göndermek; davet özelliğini toplu, istenmeyen ya da reklam ve pazarlama amaçlı ileti için kullanmak;
   - b) başkası adına hesap açmak; sahip olmadığı bir unvanı, belgeyi ya da yetkiyi beyan etmek; hesabını ya da koltuğunu başkasıyla paylaşmak;
   - c) çocukla Moyo üzerinden doğrudan iletişim kurmaya çalışmak; ebeveynden çocuğun oyun giriş kodunu ya da QR'ını istemek; çocuğun cihazına bağlanmaya çalışmak;
   - ç) davet formuna, notlara ya da diğer serbest metin alanlarına gereksiz kimlik bilgisi, üçüncü kişilere ait bilgi ya da davette sağlık bilgisi yazmak;
   - d) yetkisi olmayan verilere erişmeye çalışmak; güvenlik önlemlerini aşmaya çalışmak; izinsiz güvenlik testi yapmak; yazılımı tersine mühendislikle çözmek; otomatik araçlarla veri çekmek ya da sisteme olağan dışı yük bindirmek;
   - e) şablonları, kaynak kütüphanesini ya da yazılımı toplu kopyalayarak başka bir ürün veya ticari amaç için kullanmak;
   - f) hukuka, kişilik haklarına ya da çocuğun üstün yararına aykırı içerik girmek;
   - g) Moyo'yu tanı veya tedavi hizmeti olarak tanıtmak; Moyo adını ve markalarını izinsiz kullanmak; Moyo tarafından doğrulanmış ya da onaylanmış uzman olduğunu ileri sürmek.

11.2. Aykırılık hâlinde Platform, aykırılığın ağırlığına göre uyarabilir, ilgili özelliği kısıtlayabilir, hesabı askıya alabilir ya da sözleşmeyi madde 14.3 uyarınca feshedebilir. Aileleri, çocukları ya da sistemi korumak için gerekiyorsa bu önlemler önceden bildirim yapılmadan alınabilir; bu durumda uzmana gerekçe en kısa sürede bildirilir. Uzman `destek@moyoapp.com.tr` adresinden itiraz edebilir.

## 12. Fikri mülkiyet

12.1. **Platformun hakları.** Moyo Mercek, Moyo Ebeveyn ve Moyo Oyun yazılımları, arayüzleri, markaları, şablonları (adım şablonları, hazır rutinler, takip planı şablonları, rapor biçimleri), kaynak kütüphanesi ve Platformun hazırladığı metinler Platforma ya da lisans verenlerine aittir. Platform, uzmana sözleşme süresince Moyo Mercek'i mesleki hizmeti için kullanma hakkını münhasır olmayan, devredilemeyen ve alt lisans verilemeyen biçimde tanır. Şablonların ve içeriklerin dayandığı kaynaklardaki üçüncü kişi hakları saklıdır.

12.2. **Uzmanın hakları.** Uzmanın uzman kayıtlarına yazdığı özgün içerik (notlar, hedef tanımları, değerlendirmeler, önerilerdeki ve eğitimlerdeki özgün metinler) uzmana ya da aralarındaki ilişkiye göre kliniğe aittir. Uzman bir şablonu ya da içeriği uyarladığında şablonun ya da içeriğin kendisi Platformun kalır; uzmanın eklediği özgün kısım uzmanın olur.

12.3. **Platforma verilen sınırlı izin.** Uzman, kendi içeriğini yalnız hizmetin sunulması için (saklama, yedekleme, uzmana ve yetkili ekibine gösterme, aileye gönderilen kısmı aileye gösterme, madde 9 uyarınca sonraki uzmana açma) sözleşme ve saklama süresiyle sınırlı, ücretsiz kullanma izni verir. Platform bu içeriği pazarlamada, reklamda ya da yapay zekâ modeli eğitiminde kullanmaz.

12.4. **Aile verisi** aileye aittir; uzmanın bu veriyi yalnız paylaşım sürdükçe okuma yetkisi vardır.

12.5. **Geri bildirim.** Uzmanın ürüne ilişkin önerileri Platform tarafından ayrıca bir bedel ödenmeden kullanılabilir; bu, uzmanın uzman kayıtlarını kapsamaz.

## 13. Kişisel veriler ve Platforma verilen yetkiler

13.1. **Uzmanın kendi verileri** Uzman Aydınlatma Metni'nde ([Moyo Mercek Uzman Aydınlatma Metni](/yasal/aydinlatma-uzman)) anlatıldığı şekilde işlenir.

13.2. **Uzman kayıtları** bakımından Uzman (klinik) veri sorumlusu, Platform veri işleyendir; tarafların rolleri ve yükümlülükleri **Veri İşleme Eki**'nde düzenlenir.

13.3. **Aile verisi** uzmana ebeveynin açık rızasıyla gösterilir. Uzman, bu verileri görmeye başladığı andan itibaren kendi kullanımı (ör. kendi mesleki kaydına geçirmesi, rapor yazdırması ya da CSV indirmesi) bakımından KVKK'dan doğan yükümlülüklerine, özellikle veri güvenliği yükümlülüğüne (md. 12) uyar.

13.4. **Uzmanın Platforma verdiği yetkiler.** Uzman, sözleşmenin ifası kapsamında Platforma şu yetkileri verir:
   - a) girdiği kayıtların ebeveynin izniyle Moyo Ebeveyn'de gösterilmesi; ebeveyn izin verirse adı gizlenerek sonraki uzmana salt okunur açılması (madde 9);
   - b) karşılama anketindeki yanıtlarının kimliksiz toplamlar hâlinde ürün geliştirmede kullanılması;
   - c) verilerinin, hizmetin sunulması için gereken ölçüde, Platformun adına ve talimatıyla çalışan hizmet sağlayıcılara (Ek-2) aktarılması ve bu sağlayıcıların sunucuları yurt dışındaysa KVKK md. 9'daki usule (standart sözleşme ve Kurul'a bildirim) uygun olarak aktarılması;
   - ç) Platformun yetkili ekip üyelerinin yalnız destek, güvenlik ve kötüye kullanım incelemesi, üyelik ve ödeme sorunları ile kanuni yükümlülükler için, iki adımlı girişle, gerekçe yazarak ve her erişimi değiştirilemez denetim kaydına geçirerek hesap bilgilerine ve kullanım kayıtlarına erişmesi (not metinleri ekip ekranlarında gösterilmez);
   - d) kişisel içerik barındırmayan kullanım kayıtlarının hizmetin işleyişini ölçmek, hataları bulmak ve ürünü geliştirmek için işlenmesi;
   - e) yetkili mercilerin usulüne uygun talebi hâlinde verilerin talep kapsamıyla sınırlı olarak aktarılması (kanunen yasak değilse uzman bilgilendirilir);
   - f) Platformun işini devretmesi ya da Moyo'yu bir başkasına devretmesi hâlinde verilerin aynı amaçlarla ve aynı koruma düzeyiyle devralana aktarılması (uzman önceden bilgilendirilir, hesabını silme hakkı saklıdır).
   Bu yetkiler açık rıza değildir; hangi işlemenin hangi hukuki sebebe dayandığı Uzman Aydınlatma Metni'nde yazılıdır.

13.5. **Ticari bilgilerin gizliliği.** Platform, uzmanın kliniğine ilişkin bilgileri (ör. aile sayısı, davet ve kullanım istatistikleri) gizli tutar; yalnız kimliksiz toplamlar hâlinde ve hizmetin işleyişini ölçmek için kullanır.

## 14. Süre, sona erme, kayıtların çıktısı ve silinmesi

14.1. **Süre.** Sözleşme belirsiz sürelidir; uzman hesabını silene ya da sözleşme feshedilene kadar sürer. Ücretli üyelik dönemleri madde 10'a tabidir.

14.2. **Uzmanın feshi.** Uzman sözleşmeyi her zaman Moyo Mercek'teki "Hesabı sil" ile sona erdirebilir. Üyeliğin iptali madde 10.5'e göre Apple hesabından ayrıca yapılır.

14.3. **Platformun feshi.** Platform;
   - a) madde 5 ya da 11'e ağır ya da tekrarlanan aykırılık, kanuni zorunluluk veya ailelerin ya da çocukların korunması gibi haklı bir sebeple derhal,
   - b) haklı sebep olmaksızın en az `[SÜRE]` (öneri: 30 gün) önceden bildirimle
   sözleşmeyi feshedebilir. (b) hâlinde ve Platformun Moyo Mercek hizmetini tümüyle sona erdirmesi hâlinde bildirim süresi en az `[SÜRE]` (öneri: 90 gün) olur; Uzman bu süre içinde madde 14.5'teki araçlarla kayıtlarının çıktısını alabilir.

14.4. **Üyeliği sona eren klinikte saklama.** Deneme ya da üyelik bittikten sonra uzman kayıtları silinmez; klinik ya da Uzmanın hesabı silinene kadar saklanır. Bu sürede o kliniğin kayıtlarına erişim kapalıdır (madde 10.7); üyelik yenilenince erişim kaldığı yerden açılır. Uzmanın hesap bilgileri hesap silinene kadar kalır.

14.5. **Kayıtların çıktısı.** Uzman, sözleşme sona ermeden ya da hesabını silmeden önce Moyo Mercek'in sunduğu araçlarla (yazdırılabilir rapor, ilerleme notu, CSV indirme) kayıtlarının çıktısını alabilir. Bu araçlar bir kolaylıktır; Platform ayrıca bir arşiv ya da dışa aktarma hizmeti taahhüt etmez. Saklaması gereken kayıtları kendi sisteminde saklamak Uzmanın yükümlülüğüdür (madde 6.4). Bu çıktılar aile verisinden özet içerebilir; bunlar bakımından madde 6.3 ve 13.3 uygulanır. Uzmanın kendi kişisel verilerine ilişkin kanuni hakları (Uzman Aydınlatma Metni) saklıdır.

14.6. **Silme.** Hesap silindiğinde veriler madde 4.5'e göre derhal silinir; yedeklerden silinme Veri İşleme Eki'ndeki süre içinde tamamlanır. Kanunen saklanması gereken kayıtlar (ör. ödeme kayıtları) ve değiştirilemez denetim kaydı, kişiyi doğrudan tanımlayan bilgi (e-posta) çıkarılarak saklama süresince tutulur.

14.7. **Sona ermeden sonra devam eden hükümler.** Madde 6.3, 9.7, 12, 14.5–14.6, 15, 19 ve 20 sözleşme sona erdikten sonra da uygulanır.

## 15. Sorumluluk ve sınırları

15.1. **Platformun yükümlülükleri.** Platform hizmeti makul özenle sunar ve kişisel verilerin güvenliği için KVKK md. 12'deki teknik ve idari tedbirleri alır (Veri İşleme Eki, Ek-A). Veri güvenliği yükümlülüğü sözleşmeyle uzmana devredilmez.

15.2. **Platformun sorumlu olmadığı hâller.** Kanunun izin verdiği ölçüde Platform;
   - a) uzmanın mesleki kararlarından, uzman kayıtlarının içeriğinden ve bunların sonuçlarından,
   - b) ebeveynin ya da çocuğun girdiği bilgilerin doğruluğundan,
   - c) ebeveynin paylaşımı durdurması, rızasını geri alması ya da hesabını silmesi sonucu uzmanın erişimini kaybetmesinden,
   - ç) uzmanın şifresinin, cihazının ya da yazdırdığı ve indirdiği belgelerin güvenliğinin sağlanmamasından,
   - d) Apple, App Store ya da ödeme süreçlerinden kaynaklanan sorunlardan,
   - e) uzmanın serbest metne yazdığı ve otomatik gizlemenin yakalayamadığı kimlik bilgilerinden,
   - f) mücbir sebeplerden (doğal afet, salgın, savaş, genel internet ya da enerji kesintisi, hizmet sağlayıcının elinde olmayan kesintisi, resmî makam kararı gibi)
   doğan zararlardan sorumlu değildir.

15.3. **Sorumluluğun sınırı.** Moyo'nun sorumluluğu, yasanın izin verdiği en geniş ölçüde, doğrudan zararlarla ve son 12 ayda ödenen ücretle sınırlıdır. Kast, ağır kusur ve tüketicinin vazgeçilemez hakları saklıdır. "Son 12 ayda ödenen ücret", zarara yol açan olaydan önceki 12 ay içinde klinik sahibinin o klinik için ödediği üyelik bedelidir. Platform, hafif kusuruyla sebep olduğu dolaylı zararlardan (kâr kaybı, itibar kaybı, iş kaybı gibi) sorumlu değildir.

15.4. **Sınırın uygulanmadığı hâller.** Madde 15.2 ve 15.3'teki sınırlar; Platformun kastı ya da ağır kusuru (TBK md. 115), kişilerin hayatına ve vücut bütünlüğüne gelen zararlar, kişisel verilerin korunmasına ilişkin kanunen sınırlanamayan sorumluluklar ve kanunen sınırlanamayan diğer hâller bakımından uygulanmaz.

15.5. **Uzmanın tazmin yükümlülüğü.** Uzman; gerçeğe aykırı beyanı (madde 5), hukuka aykırı davet ya da veri girişi (madde 7), mesleki kusuru (madde 6) ya da kabul edilemez kullanımı (madde 11) nedeniyle ailelerin, çocukların, yetkili makamların ya da diğer üçüncü kişilerin Platforma yönelttiği talepler sonucu Platformun uğradığı zararı, kusuru oranında tazmin eder. Platform böyle bir talebi uzmana gecikmeksizin bildirir ve savunmaya katılmasına imkân tanır.

## 16. Sözleşmenin değişmesi ve yeniden onay

16.1. **Esaslı değişiklik.** Uzmanın hak ve yükümlülüklerini, kişisel verilerin işlenmesini ya da ücreti etkileyen değişiklikler, yürürlüğe girmeden en az `[SÜRE]` (öneri: 30 gün) önce uygulama içinde ve kayıtlı e-postaya bildirilir. Yeni sürüm, uzmanın Moyo Mercek açılışında **yeniden onayıyla** yürürlüğe girer. Uzman yeni sürümü onaylamazsa Moyo Mercek'i kullanamaz ancak kayıtlarının çıktısını alma (madde 14.5) ve hesabını silme hakkı saklıdır; bu süre içinde veriler silinmez.

16.2. **Esaslı olmayan değişiklik.** Yalnız uzmanın lehine olan, yazım düzeltmesi niteliğindeki ya da yeni bir özelliği tanıtan değişiklikler uygulama içi bildirimle yürürlüğe girer.

16.3. **Kanuni zorunluluk.** Mevzuat değişikliği ya da yetkili makam kararı gerektiriyorsa daha kısa bir süre uygulanabilir; gerekçe bildirimde yazılır.

16.4. **Sürüm kaydı.** Her sürüm anahtarı ve sürüm numarasıyla yayımlanır; uzmanın hangi sürümü ne zaman onayladığı kaydedilir. Alt işleyen değişiklikleri Veri İşleme Eki'ndeki usule tabidir.

## 17. Bildirimler ve iletişim

Platform uzmana uygulama içi bildirimle ve kayıtlı e-posta adresine yazar. Tanıtım ve kampanya bildirimi ya da e-postası yalnız Uzmanın ayrı izniyle gönderilir; bu izin Moyo Mercek'in Ayarlar bölümünde ayrı bir anahtardır, kapalı başlar ve Uzman istediği an kapatır. İzin verilirse iletiler kanunun öngördüğü kayıt sistemi (İYS) üzerinden ve her birinde ücretsiz ret yoluyla gönderilir. Hizmetle ilgili bildirimler ve e-postalar (hesap, üyelik, güvenlik, aile paylaşımı) bu izne bağlı değildir. Telefonla (SMS) doğrulama bugün yoktur; açılırsa telefon numarasının nasıl işleneceği önceden ayrıca bildirilir. Uzman Platforma bütün konularda (kişisel veri başvuruları, itirazlar ve ödeme soruları dahil) `destek@moyoapp.com.tr` ve `[ADRES]` (yazılı bildirim) üzerinden ulaşır; KVKK başvurusunda konu satırına "KVKK başvurusu" yazılması istenebilir. Uzman, e-posta adresini güncel tutmakla yükümlüdür.

## 18. Devir

Uzman bu sözleşmeden doğan hak ve yükümlülüklerini Platformun yazılı onayı olmadan devredemez. Platform, işini ya da Moyo'yu bir başkasına devretmesi hâlinde sözleşmeyi devralan tarafa devredebilir; uzmanı önceden bilgilendirir ve uzmanın hesabını silme hakkı saklıdır.

## 19. Uygulanacak hukuk, uyuşmazlıklar ve delil

19.1. Bu sözleşmeye Türkiye Cumhuriyeti hukuku uygulanır.

19.2. Uyuşmazlıklarda yetkili mahkeme ve icra daireleri, Hukuk Muhakemeleri Kanunu'nun genel hükümlerine göre belirlenir. Taraflar tacir ya da kamu tüzel kişisi ise `[ADRES]`'in bulunduğu yer mahkemeleri ve icra daireleri yetkilidir (HMK md. 17). Kanunen zorunlu arabuluculuk hükümleri saklıdır.

19.3. Platformun elektronik kayıtları (onay kayıtları, denetim kaydı, sistem kayıtları) uyuşmazlıklarda delil olarak kullanılabilir (HMK md. 193); karşı ispat hakkı saklıdır.

## 20. Çeşitli

20.1. **Bölünebilirlik.** Bu sözleşmenin bir hükmü geçersiz sayılırsa diğer hükümler geçerliliğini korur; geçersiz hüküm, amacına en yakın geçerli hükümle yorumlanır.

20.2. **Bütünlük.** Bu sözleşme ve ekleri, Moyo Mercek kullanımına ilişkin taraflar arasındaki anlaşmanın tamamıdır. Elle tanımlanan üyelik (madde 10.6) için yapılan yazılı anlaşma, o üyeliğe özgü konularda bu sözleşmeden önce gelir.

20.3. **Haktan feragat sayılmama.** Platformun bir hakkını kullanmaması ya da geç kullanması, o haktan feragat ettiği anlamına gelmez.

20.4. **Dil.** Sözleşmenin Türkçe metni esastır.

---

## Ek-1 ve Ek-2

- **Ek-1:** Veri İşleme Eki — [Veri İşleme Eki (Moyo Mercek Uzman Hizmet Sözleşmesi, Ek-1)](/yasal/veri-isleme-eki) (anahtar [Veri İşleme Eki (Moyo Mercek Uzman Hizmet Sözleşmesi, Ek-1)](/yasal/veri-isleme-eki)).
- **Ek-2:** Alt işleyenler listesi — [Hizmet Sağlayıcılar (Alt İşleyenler) Listesi](/yasal/alt-isleyenler).

## Ek-3: Moyo Mercek'teki kısa bilgilendirme metinleri

Bu metinler uygulamanın ilgili yerinde gösterilir ve sözleşmenin yorumunda dikkate alınır. Uygulama dili "sen" hitabıdır.

| Yer | Metin |
|---|---|
| Kayıt ekranı (onay kutusu; işaretlenmeden "Kayıt ol" açılmaz) | ☐ "Hizmet Sözleşmesi ve Veri İşleme Eki'ni kabul ediyorum. Aydınlatma · Gizlilik" — tek satır; "Aydınlatma" (Uzman Aydınlatma Metni) ve "Gizlilik" bağlantıdır, kutuya bağlı değildir. Kutunun üstünde kısa bilgi (madde 6.4-a): "Aile paylaşımı bitirirse yeni kayıt göremezsin; aile hesabını ya da çocuğu silerse o aileye ait notların ve kayıtların da silinir. Saklaman gereken kayıtları raporla ya da CSV ile kendin indir." |
| Dışa aktarılan belgeler: rapor, ilerleme notu, CSV (alt satır) | "Ailenin uygulamada bıraktığı kayıtların özetidir; tanı ya da değerlendirme değildir." (Ekranlarda sınır uyarısı gösterilmez; 3.4-a.) |
| Kaynak kütüphanesi (ekranın altında, bir kez) | "Genel bilgilendirmedir, mesleki değerlendirmenin yerini tutmaz." |
| Notlar (not alanının altında) | "Notlarını aile görmez; yalnız kliniğindeki uzmanlar okur. Ebeveyn izin verirse notların, adın gizlenerek çocuğun sonraki uzmanına okunur olarak açılabilir. Nota kimlik bilgisi yazma." |
| Devralınan kayıtlar | "Önceki uzman 1 · Mart 2026 – Ekim 2026 · ebeveynin izniyle, yalnız okuma" |
| Davet formu (çocuk önerisi) | Alan "Çocuğun adı" + yaş grubu; altında "Yalnız daveti kabul eden ebeveyn görür. Sağlık bilgisi yazma." Ayrıntı "i" düğmesinde: "Çocuğun adını ve yaş grubunu yazarsan yalnız daveti kabul eden ebeveyn görür; kontrol edip onaylar, düzeltirse sana bildirim gelir. Mesajda görünmez, davet bitince silinir." |
| Davet formu (e-posta) | "Bu adrese senin adına davet e-postası gider; çocuğun adı ve notun e-postada yer almaz. Aile yanıtlarsa yanıt senin e-posta adresine gelir. Daveti yalnız tanıdığın ve hizmet verdiğin aileye gönder." |
| Üyelik ekranı (satın alma düğmesinin yakınında) | Paket adı, dönem, KDV dahil fiyat; "Üyelik, dönem bitiminden en az 24 saat önce iptal edilmezse aynı süre için otomatik yenilenir ve ücret Apple hesabına yansıtılır. İptal: Ayarlar › Apple hesabı › Abonelikler." + Uzman Hizmet Sözleşmesi ve Uzman Aydınlatma Metni bağlantıları. |
| Hesabı sil (onaydan önce) | Tek kişilik klinikte: kliniğin ve içindeki her şeyin (paylaşımlar, notlar, davranış hedefleri, değerlendirmeler, rutin ve adım önerileri, takip planları, davetler, üyelik kaydı) silineceği; ailelerin Moyo'daki kendi verilerinin silinmeyeceği, yalnız uzmanla paylaşımlarının biteceği; "Saklaman gereken kayıtları önce yazdır."; App Store üyeliğinin Apple Ayarlar'dan ayrıca kapatılacağı. Ekipte sahip ya da üye için: klinik ve kayıtları klinikte kalır, yalnız kendi hesabı silinir. |

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('veri-isleme-eki', 'v1', 'Veri İşleme Eki (Moyo Mercek Uzman Hizmet Sözleşmesi, Ek-1)', '{clinic}', true, $md$# Veri İşleme Eki (Moyo Mercek Uzman Hizmet Sözleşmesi, Ek-1)

## Kısaca

- **Roller:** Ailelerle çalışırken Moyo Mercek'e girdiğiniz kayıtlarda (notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, ebeveyn eğitimleri, hedef davranışlar, seans kayıtları, takip planı, davet bilgileri) **kliniğiniz veri sorumlusu**, **Platform veri işleyen**dir. Bu kayıtları kendi beyanınızla ve kendi sorumluluğunuzda girersiniz; Moyo içeriği denetlemez, doğrulamaz, sorumluluk ve yükümlülük üstlenmez.
- **Yalnız talimatla:** Platform bu kayıtları yalnız sizin talimatınızla ve hizmeti sunmak için işler; satmaz, reklamda ya da yapay zekâ eğitiminde kullanmaz.
- **Önceden verdiğiniz talimatlar:** aileye gönderdiğiniz kısmı aileye göstermek, sizin adınıza davet e-postası göndermek, ebeveyn açıkça izin verirse kayıtlarınızı adınız gizlenerek sonraki uzmana salt okunur açmak, ebeveyn hesabını silince ilgili kayıtları silmek.
- **Özel nitelikli veri içerebilecek alanlar korunur:** serbest metin alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazılmaması istenir.
- **Güvenlik:** gizlilik taahhüdü vermiş, rolle sınırlı, iki adımlı girişli ekip; satır düzeyi güvenlik, şifreli bağlantı, silinemez denetim kaydı (Ek-A).
- **Alt işleyenler:** güncel liste yayımlanır; değişiklikten önce bildirilir, itiraz edebilirsiniz.
- **Yurt dışı:** KVKK md. 9'a uygun standart sözleşme ve Kurul'a bildirim.
- **İhlal:** öğrendiğimizde gecikmeksizin, en geç `[SÜRE]` saat içinde size bildiririz; Kurul'a 72 saat içindeki bildiriminizde size yardım ederiz.
- **Sona erince:** kayıtlarınızın çıktısını Moyo Mercek'in araçlarıyla alabilirsiniz; hesabınız ya da sözleşme sona erince kayıtlar silinir. Üyelik ya da deneme bitince kayıtlar silinmez, erişim kapanır. Moyo arşiv ya da dışa aktarma hizmeti taahhüt etmez.

---

## 1. Taraflar, konu ve öncelik

1.1. Bu Ek, Moyo Mercek Uzman Hizmet Sözleşmesi'nin ("Sözleşme") ayrılmaz parçasıdır ve Sözleşme'nin onaylanmasıyla birlikte kabul edilir. Sözleşme'de tanımlanan terimler (ör. Aile, Aile verisi, Uzman kayıtları) bu Ek'te aynı anlamda kullanılır.

1.2. Taraflar:
   - a) **Veri sorumlusu:** Uzmanın çalıştığı klinik. Kliniğin tüzel kişiliği ya da ayrı bir işletmesi varsa o; yoksa klinik sahibi uzman. Tek kişilik klinikte ve uzmanın bireysel hesabında uzmanın kendisi. Ekip üyeleri, veri sorumlusunun yetkisiyle ve onun adına hareket eden kişilerdir. Bu Ek'te kısaca "**Uzman**" denir.
   - b) **Veri işleyen:** Moyo'yu işleten `[AD SOYAD]`, `[ADRES]`. "Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer. Bu Ek'te Platforma yüklenen hak ve yükümlülükler, veri işleyen olarak onu işleten kişiye aittir.

1.3. Kişisel verilere ilişkin konularda bu Ek ile Sözleşme arasında çelişki olursa bu Ek uygulanır.

## 2. Roller ve kapsam

2.1. **Uzman kayıtları.** Uzmanın Moyo Mercek'e girdiği uzman kayıtları (madde 4.2) bakımından Uzman veri sorumlusu, Platform veri işleyendir. Platform bu kayıtları Uzman adına, bu Ek'teki talimatlar çerçevesinde işler. Uzman girdiği her kaydı kendi beyanıyla ve kendi sorumluluğunda girer; Moyo bu içeriği denetlemez, doğrulamaz ve bunun için bir sorumluluk ya da yükümlülük üstlenmez (Sözleşme md. 6.1).

2.2. **Kapsam dışında kalanlar.** Bu Ek aşağıdakileri kapsamaz:
   - a) **Uzmanın kendi hesap verisi** (ad, unvan, e-posta, çalıştığı klinikler, üyelik, anket, takvim ayarları, kullanım kayıtları): Platform veri sorumlusudur; Uzman Aydınlatma Metni'ne tabidir.
   - b) **Aile verisi** (ebeveynin ve çocuğun Moyo Ebeveyn ve Moyo Oyun'da oluşturduğu rutinler ve adımlar, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, davranış kayıtları ve ses kayıtları, bildirilen davranış olayları, ebeveyn eğitimi yanıtları (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar), randevulara verilen yanıtlar, çocuğun profil bilgileri, ebeveyn adları): Platform Moyo Ebeveyn ve Moyo Oyun için veri sorumlusudur. Uzman bu verileri ebeveynin açık rızasıyla ve paylaşım sürdükçe görür; gördüğü veriyi kendi mesleki kaydına geçirmesi ya da rapor ve CSV olarak alması bakımından kendisi ayrı veri sorumlusudur.

2.3. **Platformun kendi amaçlarıyla sınırlı işleme.** Platform, uzman kayıtlarının içeriğine bakmadan yalnız sayısal bilgileri (ör. bir klinikte son 30 günde yazılan not, gönderilen öneri sayısı) hizmetin işleyişini ölçmek, destek vermek ve kötüye kullanımı önlemek için kendi meşru menfaatine dayanarak işler; güvenlik ve denetim kayıtlarını ve kanunen tutması gereken kayıtları kendi veri sorumluluğu altında tutar. Bu işleme kimliksizdir ya da uzman kayıtlarının içeriğini kapsamaz.

## 3. İşlemenin konusu, niteliği, amacı ve süresi

| | |
|---|---|
| Konu | Moyo Mercek hizmetinin Sözleşme'ye göre sunulması |
| Niteliği | Kaydetme, saklama, yedekleme, düzenleme; Uzmana ve klinik sahibinin yetkilendirdiği ekip üyelerine gösterme; Uzmanın gönderdiği kısmı ilgili ebeveynlere gösterme ve bildirim gönderme; Uzman adına davet e-postası gönderme ve daveti eşleştirme; ebeveynin açık rızasıyla sonraki uzmana salt okunur açma; silme ve imha |
| Amaç | Uzmanın aileyle yürüttüğü mesleki çalışmanın Moyo Mercek üzerinden desteklenmesi |
| Süre | Sözleşme süresince ve madde 13'teki sona erme süreçleri tamamlanana kadar |

## 4. İlgili kişi grupları ve veri kategorileri

4.1. **İlgili kişi grupları:**
   - a) Çocuklar;
   - b) Ebeveynler (veliler ve yasal temsilciler) ve aynı ailedeki diğer ebeveyn;
   - c) Uzman ve klinik ekip üyeleri (kayıtların yazarı ve sorumlusu olarak);
   - ç) Uzmanın serbest metne yazması hâlinde üçüncü kişiler (önerilmez; Sözleşme md. 6.5).

4.2. **Uzman kayıtları (bu Ek'in kapsamı):**

| Kategori | İçerik | Kimin hakkında |
|---|---|---|
| Davet bilgileri | Ebeveynin e-posta adresi; çocuğun adı ya da takma adı ve yaş grubu (yalnız aile onayına kadar); Uzmanın davet notu; davetin ve e-postanın durumu (gönderildi, açıldı, bağlandı, paylaşıldı, süresi doldu, iptal, reddedildi) | Ebeveyn, çocuk |
| Etiket | Uzmanın çocuk için yalnız kliniğin gördüğü kısa adı ya da notu | Çocuk |
| Notlar | Serbest metin (genel ya da bir hedefe bağlı); aile görmez | Çocuk, ebeveyn |
| Hedefler ve değerlendirmeler | Alan, gözlenebilir davranış, ölçüm biçimi, başlangıç ve hedef düzey, süre, evde destek, aileye not, aileye görünürlük; değerlendirme (−2 … +2) ve kısa not (değerlendirmeler aileye görünmez) | Çocuk |
| Rutin ve adım önerileri | Başlık, açıklama, tekrar, hatırlatma saati, ödül, inceleme gerekliliği, ebeveyne not, rutin paketi, bağlı hedef; ailenin kararı ve oluşan rutin ya da adımla bağı | Çocuk, ebeveyn |
| Takip planı (aile programı) | Modüllerin amacı, evde uygulama, kontrol listesi, durumu; aileye gönderim bilgisi; ebeveynin bu modüller için girdiği uygulama kayıtları (bugün uyguladım, zorluk 1–5, uygulayamama nedeni) | Çocuk, ebeveyn |
| Ebeveyn eğitimi | Eğitimin hedefi, kimin için olduğu ve durumu (Taslak, Etkin, Ustalaştı); seçilen modüller, uygulama görevleri ve yapılacaklar; ustalık ölçütü ve Uzmanın girdiği gözlem verisi (gözlem verisi aileye görünmez); uzmanın inceleme bilgisi | Ebeveyn, çocuk |
| Hedef davranışlar | Hedef davranış, açıklama, stratejiler, durum, kayıt türü, ebeveyn kaydının açık olup olmadığı | Çocuk |
| Seanslar | Randevu (zaman, süre, tür, yer, oda, durum, aileye görünürlük, paket); seans kaydı (katılanlar, gözlem, çalışılan, sonraki adım, gündem; aile görmez); bekleme listesi notu | Çocuk, ebeveyn |
| Klinik içi atamalar | Ailenin sorumlu uzmanı ve erişim açılan ekip üyeleri | Uzman, çocuk |
| Yazar ve zaman bilgisi | Kaydı hangi uzmanın, ne zaman yazdığı | Uzman |

4.3. **Özel nitelikli veri içerebilecek alanlar korunur.** Moyo'daki kayıtlar, kullanıcıların uygulamayı kullanma alışkanlığına ilişkin kendi girdiği takip kayıtlarıdır; Moyo sağlık verisi ya da başka özel nitelikli veri toplamaz ve bu amaçla işlemez. Notlar, hedefler, değerlendirmeler, seans kayıtları ve diğer serbest metin alanlarına yine de böyle bir bilgi yazılabileceği için taraflar bu kayıtların tamamına özel nitelikli veri düzeyinde koruma uygular. Girilen kaydın doğruluğu ve içeriği girene aittir. Serbest metin alanlarına tanı, ilaç ya da başkasına ait sağlık bilgisi yazılmaması istenir; yazılan bilginin sorumluluğu yazandadır. Uzman davet bilgilerine hiçbir sağlık bilgisi yazmaz.

## 5. Uzmanın (veri sorumlusunun) yükümlülükleri

5.1. **Hukuki sebep ve aydınlatma.** Uzman kayıtlarının işlenmesi için gerekli hukuki sebebin bulunması, gerektiğinde açık rızanın alınması ve ilgili kişilerin aydınlatılması Uzmanın yükümlülüğüdür (KVKK md. 5, 6, 10). Ebeveynin Moyo Ebeveyn'de verdiği paylaşım onayı (`uzman-paylasim-v1`) ve önceki uzman kayıtlarına ilişkin açık rızası (`uzman-gecis-v1`) Platformun sistemindeki paylaşımın ve aktarımın dayanağıdır; Uzmanın kendi mesleki kayıtları için aydınlatma ve onam yükümlülüğünü kaldırmaz.

5.2. **Talimatların hukuka uygunluğu.** Uzman, Platforma verdiği talimatların mevzuata ve meslek kurallarına uygun olmasını sağlar.

5.3. **En az veri.** Uzman yalnız mesleki olarak gerekli veriyi girer (Sözleşme md. 6.5 ve 7.2).

5.4. **Ekip ve erişim.** Uzman (klinik sahibi), uzman kayıtlarına yalnız o aileyle çalışması gereken ekip üyelerinin erişmesini sağlar, ekip üyelerine gizlilik yükümlülüğünü bildirir ve ayrılan ekip üyesini derhal ekipten çıkarır.

5.5. **Hesap ve cihaz güvenliği.** Uzman şifresini, Moyo Mercek'e eriştiği cihazları ve yazdırdığı ya da indirdiği belgeleri (rapor, ilerleme notu, CSV) korur.

5.6. **Başvurular ve bildirimler.** Uzman kayıtlarıyla ilgili ilgili kişi başvurularını yanıtlamak (md. 11, 13), uzman kayıtlarını etkileyen bir veri ihlalini Kurul'a ve ilgililere bildirmek (md. 12/5) ve varsa VERBİS kaydı yükümlülüğü Uzmandadır. Platform bunlarda madde 10 ve 11'deki gibi yardım eder.

## 6. Uzmanın önceden verdiği talimatlar

6.1. Uzman, Sözleşme'yi onaylayarak Platforma aşağıdaki işlemler için yazılı talimat verir:
   - a) **Temel hizmet:** uzman kayıtlarını kaydetmek, saklamak, yedeklemek; Uzmana ve klinik sahibinin yetkilendirdiği ekip üyelerine göstermek.
   - b) **Aileye gösterme:** Uzmanın aileye açık bıraktığı hedefleri, "Aileye gönder" dediği andaki takip planını, gönderdiği rutin ve adım önerilerini, Etkin yaptığı ebeveyn eğitimlerini, ebeveyn kaydına açtığı hedef davranışları ve aileye gösterilmesini seçtiği randevuları, paylaşım etkin olduğu sürece ilgili ebeveynlere göstermek ve bunlar için bildirim (Uzmanın istediği eğitim hatırlatması dahil) göndermek. Notlar, hedef değerlendirmeleri, seans kayıtları ve ebeveyn eğitimindeki gözlem verisi aileye gösterilmez.
   - c) **Davet:** Uzmanın girdiği ebeveyn e-posta adresine Uzman adına davet e-postası göndermek (sınırlı sayıda yeniden gönderimle); ebeveyn aynı adresle kayıt olup adresini doğruladığında daveti eşleştirmek; çocuk bilgisini yalnız daveti kendi ailesine bağlamış ebeveyne göstermek; ebeveynin düzelttiği bilgiyi Uzmana bildirmek; davet kullanıldığında, iptal edildiğinde, reddedildiğinde ya da süresi dolduğunda çocuk bilgisini silmek (bağlanmamış davette 3 gün, bağlanmış ama onaylanmamış davette en geç 30 gün); kabul edilmeyen davetin taslak planını silmek.
   - ç) **Sonraki uzmana aktarım:** Ebeveyn çocuğun takibini başka bir uzmana taşıdığında ve açık rıza verdiğinde (`uzman-gecis-v1`), sona ermiş paylaşımlara ait ve paylaşımın bittiği tarihe kadarki uzman kayıtlarını (notlar, hedefler, değerlendirmeler, rutin ve adım önerileri ve ailenin kararı, takip planı ve uygulama kayıtları) sonraki uzmana **salt okunur** açmak. Bu aktarımda Uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgileri aktarılmaz; sonraki uzmana yalnız "Önceki uzman n" sıra adı ve dönem (ay) gösterilir; kayıt metinlerinde geçen klinik ve uzman adları ile e-posta ve telefon bilgileri en iyi çabayla gizlenir. Sonraki uzman tablolara doğrudan erişemez, kayıtları değiştiremez ve silemez. Ebeveyn rızasını geri aldığında erişim derhal kapatılır.
   - d) **Ebeveynin kararlarına uyum:** Ebeveyn paylaşımı durdurduğunda Uzmanın o çocuğun aile verisine erişimini derhal kapatmak; ebeveyn hesabını ya da çocuğun profilini sildiğinde o çocuğa bağlı paylaşımı ve uzman kayıtlarını silmek.
   - e) **Hesap silme ve ekipten ayrılma:** Uzman hesabını sildiğinde tek kişilik klinikte bütün uzman kayıtlarını silmek; ekipte başka uzman varsa kayıtları klinikte bırakmak, klinik sahibi hesabını siliyorsa sahipliği en eski üyeye devretmek, ekip üyesi hesabını siliyorsa onun sorumlu olduğu aileleri klinik sahibine bırakmak. Klinik silindiğinde aileye açılmış ebeveyn eğitimlerinin içeriğini (adı, modüller, uygulama görevleri, yapılacaklar) ailenin yanıtları ve davranış olaylarıyla birlikte ailede salt okunur bırakmak; taslak eğitimleri, gözlem verisini, ustalık ölçütünü ve hedef davranış tanımını silmek (olayda yalnız davranışın adı kalır). Bir ekip üyesi klinikten ayrıldığında ya da çıkarıldığında kayıtları klinikte bırakmak ve onun o klinikteki erişimini derhal kapatmak.
   - f) **Destek:** Uzmanın talebi üzerine, yalnız o talebi çözmek için ve kayıt altında hesap ve klinik bilgilerine bakmak. Not metinleri yönetim ekranlarında gösterilmez.
   - g) **Üyelik bitince:** Sözleşme md. 10.7 ve 14.4'e göre erişimi kapatmak; kayıtları silmeden, klinik ya da Uzmanın hesabı silinene kadar tutmak; üyelik yenilenince erişimi yeniden açmak.
   - ğ) **Takvim aboneliği:** Uzman takvim aboneliği bağlantısı oluşturursa, seanslarının zamanını ve türünü (Uzman seçerse ailenin baş harfini de) bu bağlantıyı kullanan takvim hizmetine iletmek; Uzman bağlantıyı yenilediğinde ya da kapattığında eski bağlantıdan iletimi durdurmak. Ailenin adı bu bağlantıdan iletilmez.

6.2. **Ek talimatlar.** Uzman ek talimatlarını Moyo Mercek'teki ayarlar ve araçlarla ya da yazılı olarak (`destek@moyoapp.com.tr`) verir. Platform, bir talimatın mevzuata aykırı olduğunu düşünürse bunu Uzmana derhal bildirir ve aykırılık giderilene kadar o talimatı uygulamayabilir.

## 7. Platformun (veri işleyenin) yükümlülükleri

7.1. **Yalnız talimatla işleme.** Platform uzman kayıtlarını yalnız bu Ek'teki ve Uzmanın verdiği talimatlarla işler. Kanun gereği başka bir işleme zorunluysa (ör. yetkili merci talebi), kanunen yasak değilse bunu işlemeden önce Uzmana bildirir.

7.2. **Kendi amaçları için kullanmama.** Platform uzman kayıtlarını satmaz, kiralamaz; reklam, pazarlama, profil çıkarma ya da yapay zekâ modeli eğitimi için kullanmaz; madde 2.3 dışında kendi amaçları için işlemez.

7.3. **Gizlilik taahhüdü olan personel.** Platform uzman kayıtlarına ya da bunları barındıran sistemlere erişebilecek çalışanlarını ve yetkili ekip üyelerini yazılı gizlilik taahhüdüyle bağlar; erişimi rolle (sahip, finans, destek, izleyici) ve işin gerektirdiği ölçüyle sınırlar. Yönetim panelinde iki adımlı doğrulama zorunludur, her değişiklik gerekçe yazılarak yapılır ve silinemez denetim kaydına geçer; not metinleri, mesaj içerikleri, fotoğraflar ve ses kayıtları yönetim ekranlarında gösterilmez.

7.4. **Güvenlik tedbirleri.** Platform, KVKK md. 12 ve Kurul'un rehberine uygun olarak Ek-A'daki teknik ve idari tedbirleri alır ve teknolojinin gelişimine göre günceller. Taraflar, KVKK md. 12/2 uyarınca veri işleyenin işlediği veriler bakımından güvenlik tedbirlerinin alınmasından birlikte sorumludur; bu sorumluluk sözleşmeyle kaldırılamaz.

7.5. **Yardım.** Platform; ilgili kişi başvurularının yanıtlanmasında (madde 11), veri ihlali bildiriminde (madde 10) ve Kurul'un sorularının yanıtlanmasında, işlemenin niteliğini ve elindeki bilgileri göz önünde tutarak makul ölçüde yardım eder.

7.6. **Kayıt.** Platform yaptığı işlemlerin ve yetkili ekip erişimlerinin kaydını tutar.

## 8. Alt işleyenler

8.1. **Genel yetki.** Uzman, Platformun [Hizmet Sağlayıcılar (Alt İşleyenler) Listesi](/yasal/alt-isleyenler)'de (herkese açık "Alt İşleyenler" sayfası) listelenen alt işleyenleri kullanmasına genel yetki verir. Bugünkü liste özetle:

| Alt işleyen | Uzman kayıtlarıyla ilişkisi | Konum |
|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama ve sunucu işlevleri; bütün uzman kayıtları burada barındırılır | Frankfurt, Almanya; AB bölgesi |
| Resend | Uzman adına davet e-postası: ebeveynin e-posta adresi ve e-posta içeriği (içerikte çocuğun adı ve Uzmanın notu yoktur) | ABD / AB |
| Apple (APNs) | Uzmana ve ebeveyne gönderilen bildirimlerin iletilmesi; bildirim metni | ABD / AB |
| Cloudflare | Yönetim panelinin ve Moyo Mercek web sürümünün sayfalarının barındırılması; uzman kayıtlarının içeriği yönetim panelinde gösterilmez, yalnız sayılar | Küresel |
| Google (Gmail SMTP) — yalnız test dönemi | Test davet e-postaları; canlı kullanımda kullanılmaz | ABD |

Apple (App Store) ve RevenueCat yalnız üyelik bilgisini işler; uzman kayıtlarına erişmez.

8.2. **Alt işleyen sözleşmeleri.** Platform her alt işleyenle, bu Ek'tekinden daha az koruyucu olmayan veri koruma yükümlülüklerini içeren yazılı bir sözleşme yapar. Platform, alt işleyenin bu yükümlülüklere aykırılığından Uzmana karşı, yardımcı kişinin fiilinden sorumluluk kuralları (TBK md. 116) çerçevesinde sorumludur.

8.3. **Değişiklik ve itiraz.** Platform yeni bir alt işleyen eklemeden ya da birini değiştirmeden en az `[SÜRE]` (öneri: 30 gün) önce Uzmanı uygulama içinde ve e-postayla bilgilendirir ve listeyi günceller. Uzman bu süre içinde, veri korumaya ilişkin makul bir gerekçeyle yazılı olarak itiraz edebilir. Taraflar iyi niyetle çözüm arar; çözüm bulunamazsa Uzman Sözleşme'yi değişiklik yürürlüğe girmeden önce feshedebilir. Güvenlik gereği ya da bir alt işleyenin hizmetini aniden durdurması gibi acil hâllerde daha kısa süre uygulanabilir; gerekçe bildirimde yazılır.

## 9. Yurt dışına aktarım

9.1. Alt işleyenlerin sunucuları yurt dışında bulunabilir (madde 8.1). Uzman, uzman kayıtlarının bu sunuculara aşağıdaki güvencelerle aktarılması için Platforma talimat ve yetki verir.

9.2. Aktarım KVKK md. 9'a uygun yapılır: aktarılan ülke için Kurul'un yeterlilik kararı varsa ona dayanılır; yoksa Platform alt işleyenle Kurul'un ilan ettiği **standart sözleşmeyi** (veri işleyenden veri işleyene aktarım için olanı) imzalar ve imzadan itibaren **5 iş günü** içinde Kurul'a bildirir. Md. 9/6'daki arızi aktarım hâlleri yalnız istisnai durumlarda kullanılır.

9.3. Özel nitelikli veri içerebilecek uzman kayıtları için aktarımda şifreli bağlantı ve alt işleyenin durağan veri şifrelemesi gibi ek güvenceler uygulanır.

9.4. Platform veritabanının bulunduğu bölgeyi değiştirirse madde 8.3'teki usulü uygular.

## 10. Kişisel veri ihlali

10.1. **Uzmana bildirim.** Platform, uzman kayıtlarını etkileyen bir veri ihlalini öğrendiğinde Uzmana gecikmeksizin ve **en geç `[SÜRE]` saat** (öneri: 24 saat) içinde, uygulama içi bildirim ve kayıtlı e-posta yoluyla bildirir.

10.2. **Bildirimin içeriği.** Bildirimde, o an bilinebildiği ölçüde: ihlalin niteliği ve zamanı; etkilenen ilgili kişi grupları ve tahmini kayıt sayısı; olası sonuçları; Platformun aldığı ve önerdiği tedbirler; Platformdaki irtibat kişisi yer alır. Henüz bilinmeyen bilgiler öğrenildikçe gecikmeksizin iletilir.

10.3. **Kurul'a ve ilgililere bildirim.** Uzman kayıtlarına ilişkin ihlali Kurul'a 72 saat içinde ve ilgili kişilere makul en kısa sürede bildirmek veri sorumlusu olarak Uzmanın yükümlülüğüdür; Platform bildirimin hazırlanması için gereken bilgi ve belgeleri sağlar. İhlal Platformun veri sorumlusu olduğu verileri de (aile verisi, uzman hesap verisi) etkiliyorsa Platform bu veriler için kendi bildirimini yapar; taraflar ilgili kişilere yapılacak bildirimleri birbiriyle uyumlu yürütür. Uzmanın talimatıyla Platform, ebeveynlere Moyo Ebeveyn üzerinden bildirim iletebilir.

10.4. **Önlem ve kayıt.** Platform ihlalin etkisini azaltmak için gecikmeksizin gerekli önlemleri alır; ihlali, etkilerini ve alınan önlemleri kayıt altına alır.

## 11. İlgili kişi başvuruları

11.1. Platforma uzman kayıtlarıyla ilgili bir başvuru gelirse Platform başvuruyu `[SÜRE]` (öneri: 5 iş günü) içinde Uzmana iletir ve Uzmanın talimatı olmadan bu kayıtlar hakkında esasa ilişkin yanıt vermez. Başvuru Platformun veri sorumlusu olduğu verileri de kapsıyorsa o kısmı Platform kendisi yanıtlar. KVKK md. 13'teki 30 günlük süre her iki taraf için de gözetilir.

11.2. Platform, Uzmanın başvuruyu yanıtlayabilmesi için uzman kayıtlarını bulma, düzeltme, silme ve ilgili kişiye verilecek bilgiyi hazırlama işlemlerinde Moyo Mercek araçlarıyla ya da destek talebiyle yardım eder.

11.3. Ebeveynin Moyo Ebeveyn'de kullandığı paylaşımı durdurma ve önceki uzman kayıtlarının aktarımını geri alma hakları, Uzmanın ayrıca talimatına gerek olmadan Platform tarafından derhal uygulanır (madde 6.1-ç ve 6.1-d).

## 12. Denetim

12.1. Platform, bu Ek'e uyduğunu göstermek için gereken bilgileri (güncel tedbirler özeti, alt işleyen listesi, varsa bağımsız denetim raporları ve alt işleyenlerin güvenlik sertifikaları ya da raporları) Uzmanın makul talebi üzerine yazılı olarak sağlar.

12.2. Bu bilgiler yeterli değilse Uzman, yılda en çok bir kez, en az 30 gün önceden yazılı bildirimle, çalışma saatleri içinde ve gizlilik taahhüdü vermiş bağımsız bir denetçi aracılığıyla, Platformun ilgili süreçlerini makul ölçüde denetleyebilir. Denetim diğer müşterilerin verilerine ve Platformun ticari sırlarına erişimi kapsamaz; masrafı Uzmana aittir. Bir veri ihlalinden sonra ya da Kurul'un talebi üzerine ek denetim yapılabilir.

12.3. Alt işleyenler bakımından Platform, onların yayımladığı denetim raporlarını ve sertifikalarını iletmekle yükümlüdür; alt işleyenlerin tesislerinde yerinde denetim bu Ek'in kapsamında değildir.

12.4. Platform, Kurul'un denetimlerinde ve bilgi taleplerinde işbirliği yapar.

## 13. Sona erme: kayıtların çıktısı ve silme

13.1. Sözleşme sona ermeden ya da Uzman hesabını silmeden önce Uzman, uzman kayıtlarının çıktısını Moyo Mercek'in araçlarıyla (rapor, ilerleme notu, CSV) alabilir (Sözleşme md. 14.5). Platform ayrıca bir arşiv ya da dışa aktarma hizmeti taahhüt etmez; saklanması gereken kayıtları kendi sisteminde saklamak Uzmanın yükümlülüğüdür (Sözleşme md. 6.4).

13.2. Platform uzman kayıtlarını:
   - a) Uzman hesabını sildiğinde Sözleşme md. 4.5'e ve madde 6.1-e'ye göre derhal;
   - b) Sözleşme feshedildiğinde, fesih bildirim süresinin sonunda (derhal fesihte fesihten sonra `[SÜRE]` içinde)
   siler. Üyelik ya da deneme sona erdiğinde kayıtlar silinmez; klinik ya da Uzmanın hesabı silinene kadar saklanır (Sözleşme md. 14.4). Yedeklerdeki kopyalar en geç 30 gün içinde, yedekleme döngüsüyle silinir; bu sürede yedekler yalnız felaket kurtarma için kullanılır.

13.3. Silme, yok etme ya da anonim hâle getirme, Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik'e uygun yapılır. Uzmanın yazılı talebi üzerine Platform silmenin yapıldığını yazılı olarak teyit eder. Kanunen saklanması gerekenler dışında Platform uzman kayıtlarının kopyasını tutmaz.

13.4. Sonraki uzmana salt okunur açılmış kayıtlar, önceki kliniğin kayıtlarının bir görünümüdür; önceki klinik silindiğinde bu kayıtlar da silinir ve sonraki uzmanın erişimi sona erer.

## 14. Sorumluluk

**Genel ilke.** Moyo, kullanıcıların kendi kayıtlarını tutması ve isterse paylaşması için bir araç sunar. Moyo; ebeveyn, çocuk ve uzman arasındaki ilişkinin, kullanıcıların girdiği kayıtların ve bu kayıtlara dayanarak verilen kararların tarafı değildir ve bunlar için bir sorumluluk ya da yükümlülük üstlenmez. Bu ilke yasanın izin verdiği en geniş ölçüde geçerlidir; kast, ağır kusur, tüketicinin vazgeçilemez hakları ve kişisel verilerin korunmasına ilişkin kanuni yükümlülükler saklıdır. Her kullanıcı kendi girdiği kayıttan sorumludur.

Bu Ek'ten doğan sorumluluk Sözleşme md. 15'e tabidir. KVKK md. 12/2'deki birlikte sorumluluk ve kanunen sınırlanamayan sorumluluklar saklıdır. Her taraf kendi yükümlülüklerine aykırılıktan doğan zarardan sorumludur.

## 15. Süre ve değişiklik

Bu Ek, Sözleşme ile birlikte yürürlüğe girer ve madde 13'teki süreçler tamamlanana kadar yürürlükte kalır. Değişiklikler Sözleşme md. 16'daki usule (esaslı değişiklikte önceden bildirim ve yeniden onay), alt işleyen değişiklikleri madde 8.3'e tabidir.

---

## Ek-A: Teknik ve idari tedbirler


### Teknik tedbirler

| Tedbir | Nasıl | Durum |
|---|---|---|
| İletim güvenliği | Bütün bağlantılar TLS ile şifreli | var |
| Satır düzeyi erişim kontrolü | Veritabanında satır düzeyi güvenlik: herkes yalnız kendi ailesini ya da kliniğini görür; klinikler birbirinin ailelerini görmez; uzman çocuğun aile verisini yalnız etkin paylaşım varken salt okur; ekip üyesi yalnız sorumlusu olduğu ve kendisine atanan aileleri görür; mesajlar, coin defteri ve oyun kaydı uzmana kapalıdır | var |
| Girişsiz erişimin engellenmesi | Giriş yapmamış rol hiçbir veritabanı işlevini çağıramaz | var |
| Çocuk cihazının sınırlanması | Çocuk cihazı yalnız kendi profilini görür; klinik tablolarına erişimi yoktur | var |
| Devralınan kayıtların korunması | Sonraki uzman tablolara doğrudan erişemez; yalnız kimlik gizleyen ve salt okuyan bir sunucu işlevi kullanılır | var |
| Özel dosyalar | Mesaj medyası ve davranış kayıtlarındaki ses kayıtları özel kovalarda; yalnız imzalı, kısa süreli bağlantıyla açılır | var |
| Kimlik doğrulama | Şifreler kimlik doğrulama sağlayıcısında geri çevrilemez biçimde özetlenmiş; yönetim panelinde iki adımlı doğrulama zorunlu | var |
| Kötüye kullanım sınırları | Kod deneme sınırı (IP dahil), davet e-postası gönderim sınırları, olay kaydı sınırları | var |
| Gizli anahtar yönetimi | Gizli anahtarlar yalnız sunucu sırlarında; uygulamalara yalnız herkese açık (publishable) anahtar girer | var |
| Güvenlik testleri | Rol bazlı güvenlik matrisi testleri; sızma denemesi ve güvenlik taramalarının bulgularının düzeltilmesi | var; canlıdan önce ve önemli değişikliklerde tekrarlanır |
| Durağan veri şifrelemesi ve yedekleme | Barındırma sağlayıcısının (Supabase) altyapısında | sağlayıcı beyanıyla teyit edilecek |
| Değiştirilemez denetim kaydı | Yönetim işlemleri yalnız eklenen, kimsenin değiştiremediği ve silemediği kayda yazılır | var |
| Üçüncü taraf izleme yokluğu | Reklam ağı, üçüncü taraf analiz SDK'sı yok; yapay zekâ hizmetine veri gönderilmez | var |
| Asgari veri | Davette çocuk için yalnız ad ve yaş grubu; davet e-postasında çocuğun adı ve sağlık bilgisi yok; takvim aboneliğinde ailenin adı yok; kullanım olaylarında serbest metin yok | var |

### İdari tedbirler

| Tedbir | Nasıl | Durum |
|---|---|---|
| Rol ve yetki | Yönetim panelinde roller (sahip, finans, destek, izleyici); her değişiklik gerekçeli | var |
| İçerik gizliliği | Not metni, mesaj içeriği, fotoğraf ve ses kaydı yönetim ekranlarında yok; ebeveynin tanışma yanıtlarını kişi bazında yalnız sahip rolü gerekçe yazarak görür, öteki roller yalnız kimliksiz toplamları | var |
| Gizlilik taahhütnamesi | Yetkili ekip üyeleri ve çalışanlardan yazılı taahhüt | yapılacak |
| Farkındalık eğitimi | Yetkili ekip için KVKK ve güvenlik eğitimi | yapılacak |
| Veri ihlali prosedürü | Tespit, değerlendirme, uzmana bildirim (`[SÜRE]` saat), Kurul'a 72 saat, kayıt | yapılacak |
| Saklama ve imha politikası | Süreler, periyodik imha (en geç 6 ayda bir), zamanlanmış silme işi | yapılacak |
| Kişisel veri envanteri | Veri kategorileri, amaçlar, alıcılar, süreler | yapılacak |
| Alt işleyen sözleşmeleri | Her alt işleyenle veri işleme sözleşmesi ve gerekiyorsa md. 9 standart sözleşmesi + Kurul'a bildirim | yapılacak |
| Erişimlerin gözden geçirilmesi | Yönetim paneli yetkililerinin düzenli kontrolü; ayrılanın yetkisinin derhal kaldırılması | yapılacak (dönemi belirlenecek) |

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('acik-riza-metinleri', 'v1', 'Moyo Ebeveyn Açık Rıza Metinleri', '{parent,web}', false, $md$# Moyo Ebeveyn Açık Rıza Metinleri

## Kısaca

- Bu iki onay **isteğe bağlıdır.** Vermezsen Moyo Ebeveyn'i kullanmaya devam edersin.
- Onay kutuları **hiçbir zaman önceden işaretli gelmez.** Her onay kendi ekranında, kendi metniyle sorulur.
- **Uzmanla paylaşım:** yalnız seçtiğin uzman ve seçtiğin çocuk. Paylaşılanlar uygulamada bıraktığın kayıtlardır. Uzman kayıtları yalnız okur.
- **Önceki uzman kayıtları:** yeni uzmana yalnız okunur açılır; önceki uzmanın adı gizlenir.
- Her onayı **istediğin an geri alırsın;** erişim hemen biter.
- Hangi metni ne zaman onayladığın, metnin sürümüyle birlikte kaydedilir.

"Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer.

## Bütün rıza ekranları için ortak kurallar

1. Rıza ekranından **önce**, aynı ekranın üstünde kısa bir aydınlatma kutusu ve "Aydınlatma Metni'nin tamamı" bağlantısı ([Moyo Ebeveyn Aydınlatma Metni](/yasal/aydinlatma-ebeveyn)) gösterilir. Aydınlatmayı okumak rıza sayılmaz.
2. Onay kutusu **önceden işaretli gelmez.** Onay düğmesi kutu işaretlenmeden açılmaz.
3. Ret ya da vazgeç seçeneği onay düğmesi kadar görünür olur. Her ekranda şu cümle bulunur: **"Reddetmen uygulamayı kullanmanı engellemez."**
4. Rıza, Kullanım Koşulları onayının içine gömülmez; hizmet koşulu yapılmaz.
5. Onayın sürümü, onaylayan ebeveyn ve zaman kaydedilir. **Ekrandaki metin değişirse sürüm adı da değişir** (`…-v2`); sistem hangi sürümün onaylandığını tutar.
6. Geri alma yolu her zaman uygulamanın içindedir ve onay vermek kadar kolaydır. Geri alma, o ana kadar yapılan işlemleri geçersiz kılmaz.

---

## 1. Uzmanla paylaşım
| Anahtar | uzman-paylasim-v1 | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Moyo Ebeveyn › bekleyen davet ekranı ("[Uzman], [çocuk] ([yaş grubu]) için seni davet etti. Bilgiler doğru mu?") ve Uzmanım › kod gir › çocuk seçme ekranı | Dayanak | KVKK md. 5/1, md. 6/3-a, md. 3/1-a, md. 10 |

### 1.1 Önce gösterilecek kısa aydınlatma

> **Uzmanla paylaşım hakkında kısa bilgi**
> - **Kim işler:** Moyo'yu işleten `[AD SOYAD]`; paylaşınca çocuğunun kayıtları seçtiğin uzmanın kliniğinde (Moyo Uzman) de görünür.
> - **Neden:** uzmanın çocuğunun takibini yapabilmesi.
> - **Ne paylaşılır:** uygulamada bıraktığın kayıtlar: çocuğun profil bilgileri; rutinleri, adımları ve atamaları; "Yaptım" kayıtları ve onay ve ret kararların; davranış kayıtları ve ses kayıtları; uzmanın tanımladığı hedef davranışlar için bildirdiğin davranış olayları; uzmanın atadığı ebeveyn eğitimindeki yanıtların (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtların ve düşüncen, yapılacak işaretlerin ve "Nasıl geçti?" yanıtın); uzmanın önerdiği derslerde, öneriden sonra uyguladığın günler; randevulara verdiğin yanıt ve notun; takip planı uygulama kayıtların; rutin ve adım önerilerine kararların. Paylaşımdan önceki rutin ve davranış kayıtlarının geçmişi de görünür.
> - **Ne paylaşılmaz:** mesajlarınız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı, tanışma yanıtların, kendi seçtiğin dersler.
> - **Kim görür:** davet eden uzman, kliniğin sahibi ve sahibin bu paylaşımı atadığı ekip üyeleri. Uzman kayıtları yalnız okur, değiştiremez.
> - **Ne kadar:** sen durdurana kadar. Durdurunca uzmanın erişimi hemen biter; o uzmanla yürüttüğün ebeveyn eğitimi, olay bildirimi ve randevular da kapanır. Uzmanın o güne kadar yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır.
> - **Haklar:** `destek@moyoapp.com.tr`. [Aydınlatma Metni'nin tamamı]

### 1.2 Ekranda gösterilecek tam metin

Üst bölüm (bugünkü ekran): **"[Unvan] [Uzman adı] ([Klinik adı]), [çocuğun adı] ([yaş grubu]) için seni davet etti. Bilgiler doğru mu?"** Ad ve yaş grubu düzenlenebilir; ailede başka çocuk varsa onlar da işaretlenebilir. Uzman hakkında doğrulama ya da rozet bilgisi gösterilmez.

Uyarı:

> Moyo uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunun bilgilerini paylaşmadan önce bu uzmanı gerçek hayatta tanıdığından ve davetin ondan geldiğinden emin ol. Emin değilsen paylaşma; uzmanını bildiğin bir yoldan arayıp sor. Paylaşımı istediğin an Uzmanım bölümünden durdurabilirsin.

Rıza cümlesi (yeni):

> *Çocuğum [seçilen çocukların adları] ile ilgili, uygulamada bıraktığım ve yukarıda yazan kayıtların, takibini yapabilmesi için [unvan] [uzman adı] ve onun kliniğinde bu paylaşımı görmeye yetkili kişilerle (klinik sahibi ve onun görevlendirdiği ekip üyeleri) yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Mesajlarımız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı, tanışma yanıtlarım ve kendi seçtiğim dersler paylaşılmaz. Paylaşımı Uzmanım bölümünden istediğim an durdurabilirim; durdurduğumda erişim hemen sona erer.*

### 1.3 Onay kutusu ve düğmeler

- ☐ **Bu uzmanı tanıyorum ve çocuğun velisiyim (yasal temsilcisiyim).**
- Düğme: **"Onayla ve paylaş"** — kutu işaretlenmeden açılmaz. Düğmeye basmak, üstteki rıza cümlesinin onayıdır.
- Alt bağlantı: **"Bu davet bana ait değil"**.
- Çocuk daha önce başka bir uzmanla paylaşıldıysa aynı ekranda, **ayrı ve işaretsiz** olarak 2. bölümdeki seçenek çıkar.

### 1.4 Ret ya da vazgeç sonucu

> **Reddetmen uygulamayı kullanmanı engellemez.**

- **"Bu davet bana ait değil":** davet kapanır; uzmana "Aile davetini kabul etmedi" bildirimi gider; uzmanın girdiği çocuk bilgisi ve taslak plan silinir. Hiçbir kayıt paylaşılmaz.
- **Ekrandan çıkmak:** paylaşım olmaz. Davet, ailene bağlıysa 30 gün içinde yeniden açılabilir; süre dolunca uzmanın girdiği bilgiler silinir.

### 1.5 Geri alma

**Uzmanım › [uzman] › ayar › Uzmanı yönet › çocuğu ayır (yalnız o çocuk) ya da uzmanı kaldır (bütün çocuklar).** Uzmanın erişimi hemen biter; o uzmandan bekleyen rutin ve adım önerileri artık gösterilmez, o uzmanla yürüttüğün ebeveyn eğitimi, olay bildirimi ve randevular kapanır. Uzmanın o güne kadar yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır. Aynı uzmanla yeniden paylaşmak yeni bir onay ister.

### 1.6 Kayıt ve sürüm

`clinic_links.consent_version`, `consent_by`, `consent_at`. Bugün `uzman-paylasim-v1` adıyla yalnız uyarı (E) ve onay kutusu kaydediliyor. Bu taslak ekrana rıza cümlesini ve kısa aydınlatmayı ekliyor. Sürüm `uzman-paylasim-v1` kalır; bu metin v1'in kapsamıdır ve 1.1'deki liste Ebeveyn Aydınlatma Metni 5.3 ile aynıdır.

---

## 2. Önceki uzman kayıtlarının yeni uzmana açılması
| Anahtar | uzman-gecis-v1 | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Moyo Ebeveyn › davet onayı / çocuk seçme ekranı (çocuk daha önce başka bir uzmanla paylaşıldıysa) ve Uzmanım › [yeni uzman] › "Önceki uzmanın kayıtları" anahtarı | Dayanak | KVKK md. 6/3-a, md. 3/1-a, md. 4, md. 10; uzmanın sözleşmeyle önceden verdiği izin |

### 2.1 Önce gösterilecek kısa aydınlatma

> **Önceki uzmanın kayıtları hakkında kısa bilgi**
> - **Neden:** takibin yeni uzmanla kesintisiz sürmesi.
> - **Kime:** seçtiğin yeni uzmana ve onun kliniğinde bu paylaşımı görmeye yetkili kişilere.
> - **Ne açılır:** önceki uzman(lar)ın notları, hedefleri, haftalık değerlendirmeleri, rutin ve adım önerileri ve senin kararların, aile programı ve senin uygulama kayıtların; her biri tarihiyle. Önceki uzmanın notlarını sen görmezsin; bunlar onun o tarihteki mesleki gözlemleridir ve tanı değildir.
> - **Nasıl:** yalnız okunur, uygulamanın içinden. Yeni uzman bu kayıtları değiştiremez ve silemez.
> - **Ne gizlenir:** önceki uzmanın adı, unvanı, kliniği ve iletişim bilgileri. Yeni uzman yalnız "Önceki uzman 1" ve dönemi (ay) görür. Metinlerde geçen uzman ve klinik adları otomatik gizlenir.
> - **Ne kadar:** sen izni geri alana kadar.
> - **Haklar:** `destek@moyoapp.com.tr`. [Aydınlatma Metni'nin tamamı]

### 2.2 Ekranda gösterilecek tam metin

> Çocuğum **[çocuğun adı]** için daha önce çalıştığım uzman(lar)ın Moyo Uzman'a girdiği notların, hedeflerin, haftalık değerlendirmelerin, rutin ve adım önerilerinin, aile programının ve benim uygulama kayıtlarımın, takibin kesintisiz sürmesi amacıyla yeni uzmanım **[yeni uzmanın adı]** ile yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez. Bu izni Uzmanım bölümünden istediğim an geri alabilirim; geri aldığımda erişim hemen sona erer.

### 2.3 Onay kutusu

- ☐ **Önceki uzmanın kayıtlarını da paylaş (adı gizlenir)** — **işaretsiz gelir.** Ayrı bir seçimdir; 1. bölümdeki paylaşım onayından bağımsızdır.

### 2.4 Ret ya da vazgeç sonucu

> **Reddetmen uygulamayı kullanmanı engellemez.**

Kutu boş bırakılırsa yeni uzmanla paylaşım yine olur (1. bölüm), ama önceki uzmanın notları, hedefleri, değerlendirmeleri, önerileri ve aile programı yeni uzmana açılmaz. Rutinler, adımlar, "Yaptım" kayıtları ve davranış kayıtları 1. bölümdeki paylaşımla zaten görünür.

### 2.5 Geri alma

**Uzmanım › [yeni uzman] › "Önceki uzmanın kayıtları"** anahtarını kapat. İzin kaydı silinir, yeni uzmanın bu kayıtlara erişimi hemen biter. Anahtarı yeniden açmak yeni bir onaydır ve sürümüyle kaydedilir.

### 2.6 Kayıt

`clinic_link_history.consent_version = 'uzman-gecis-v1'`, `granted_by`, `granted_at`. B metninde yalnız ürün adı ve iş nesnesi adı değiştiği için sürüm değişmez; 2.1'deki kısa aydınlatma rıza metninin parçası değildir.

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('cerez-clinicapp-web', 'v1', 'Moyo Mercek Web Çerez Politikası', '{clinic,web}', false, $md$# Moyo Mercek Web Çerez Politikası

## Kısaca

- Moyo Mercek web yalnız **zorunlu** tarayıcı depolaması kullanır: oturumunuzu açık tutmak ve ekranda yaptığınız seçimleri hatırlamak için.
- **Analiz, reklam, sosyal medya ya da üçüncü taraf izleme çerezi kullanmayız**; tarayıcı parmak izi gibi başka izleme yöntemleri de kullanmayız.
- Kullanımı ölçmek için tuttuğumuz kayıtlar sunucumuzda, içerik barındırmadan tutulur; bunun için tarayıcınıza izleme çerezi yerleştirilmez.
- Zorunlu depolama için onayınız istenmez (Kurul'un çerez rehberi); bu metin bilgilendirme amaçlıdır.
- Tarayıcı ayarlarından bu depolamayı silebilir ya da engelleyebilirsiniz; engellerseniz Moyo Mercek web'e giriş yapamazsınız.
- Ortak bir bilgisayarda işiniz bitince **Çıkış yap**ın; oturum bilgisi silinir.
- Zorunlu olmayan bir çerez eklersek önce bu metni güncelleriz ve onayınızı almadan kullanmayız.

---

## 1. Kapsam ve veri sorumlusu

1.1. Bu politika, Moyo'yu işleten `[AD SOYAD]` ("biz"; `[ADRES]`) tarafından sunulan **Moyo Mercek'in web sürümünde** kullanılan çerezleri ve benzeri tarayıcı depolama teknolojilerini anlatır. "Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer.

1.2. Moyo Mercek'in iPhone ve iPad uygulaması tarayıcı çerezi kullanmaz; uygulama içindeki veri saklama Uzman Aydınlatma Metni'nde ([Moyo Mercek Uzman Aydınlatma Metni](/yasal/aydinlatma-uzman)) anlatılmıştır. Aile davet bağlantısının açılış sayfası (ebeveynlere yönelik) bu politikanın kapsamında değildir; bugünkü hâliyle çerez ya da tarayıcı depolaması kullanmaz.

## 2. Çerez ve yerel depolama nedir

2.1. **Çerez**, ziyaret ettiğiniz web sitesinin tarayıcınıza yerleştirdiği küçük bir metin dosyasıdır. **Yerel depolama** (localStorage) ve **oturum depolaması** (sessionStorage), sitenin tarayıcınızda bilgi saklamasını sağlayan benzer teknolojilerdir. Bu politikada hepsine kısaca "depolama" denir.

2.2. Depolama; amacına göre **zorunlu** (istediğiniz hizmetin çalışması için şart olan), **işlevsel**, **analiz** ve **reklam/hedefleme** olarak; kimin yerleştirdiğine göre **birinci taraf** (bizim) ve **üçüncü taraf** olarak ayrılır.

## 3. Kullandığımız depolama

| Ne | Tür | Amaç | Ne kadar kalır | Taraf | Kategori |
|---|---|---|---|---|---|
| Oturum bilgisi (`sb-<proje>-auth-token`): kimlik doğrulama sağlayıcısının erişim ve yenileme anahtarı ile hesabınızın e-posta adresi ve kayıtta yazdığınız bilgiler (ad, unvan) | Yerel depolama | Giriş yaptığınızı hatırlamak, isteklerinizin size ait olduğunu sunucuda doğrulamak | Oturumunuz açık kaldığı sürece; **Çıkış yap** ile silinir; anahtar kısa sürelidir ve oturum sürdükçe yenilenir | Birinci taraf (anahtar Supabase kimlik doğrulama hizmetiyle doğrulanır) | Zorunlu |
| E-posta bağlantısı doğrulama kodu (`sb-<proje>-auth-token-code-verifier`) | Yerel depolama | Şifre yenileme ya da e-posta doğrulama bağlantısının yalnız onu isteyen tarayıcıda açılabilmesi (güvenlik) | Bağlantı kullanılınca silinir | Birinci taraf | Zorunlu |
| İlk kullanım rehberinin gösterildiği (`clinic.onboarding.v1.<hesap kimliği>`) | Yerel depolama | Rehberi her açılışta yeniden göstermemek | Siz silene kadar | Birinci taraf | Zorunlu (sizin kapattığınız rehberin hatırlanması) |
| Bu bilgilendirme bandının kapatıldığı (`clinicapp.cookie-notice.v1`) | Yerel depolama | Bandı bir daha göstermemek | Siz silene kadar | Birinci taraf | Zorunlu |
| Arayüz seçimleri ve tek seferlik işaretler: seçili hesap (`clinic.workspace.v1.<hesap kimliği>`), görünüm ve menü (`clinic.layout.v2`, `clinic.menu.v1`), kaynak kütüphanesi favorileri (`clinic.library.fav.v1.<hesap kimliği>`), hatırlatma ayarı ve sayaçları (`clinic.nudge.v1`, `clinic.nudge.on.v1`, `clinic.nudge.primer.v1` + hesap kimliği), gösterilen ipuçları, örnek aile ve başlangıç adımları (`clinic.hint.v1…`, `clinic.explain.v1…`, `clinic.sample…`, `clinic.start…`), "Gördüm" işaretleri (`clinic.attention.seen.v1.<hesap kimliği>`: paylaşım kimliği ve zaman) | Yerel depolama | Ekranı sizin bıraktığınız gibi açmak; kapattığınız ipucunu ya da gördüğünüz bildirimi yeniden göstermemek | Siz silene kadar | Birinci taraf | Zorunlu (sizin yaptığınız seçimin hatırlanması) |

Bu depolamada aile adı, not, mesaj ya da başka kişisel içerik tutulmaz; işaretler yalnız rastgele kimlikler ve zaman bilgisi içerir. Uzman kayıtları ve aile verisi tarayıcınızda kalıcı olarak saklanmaz; ekranda görüntülenmek üzere sunucudan alınır. Kullanım ölçümünün oturum kimliği yalnız sayfa açıkken bellekte tutulur, tarayıcıya yazılmaz.

**Yazı tipleri ve betikler:** Moyo Mercek web ve tanıtım sayfası yazı tiplerini ve simgelerini kendi sunucumuzdan yükler (Google Fonts gibi dış hizmetlere istek gitmez); üçüncü taraf betik yüklenmez. Moyo Mercek web'de satın alma yoktur; üyelik iPhone/iPad'deki Moyo Mercek'ten App Store ile alınır.

## 4. Kullanmadıklarımız

4.1. Moyo Mercek web'de şunlar **yoktur**:
- analiz ya da istatistik çerezleri (ör. üçüncü taraf ziyaretçi analiz araçları),
- reklam, yeniden hedefleme ya da sosyal medya çerezleri ve pikselleri,
- tarayıcı parmak izi ya da cihazınızı çerezsiz tanımaya yönelik başka yöntemler,
- kişisel verinizi satmak ya da reklam ağlarıyla paylaşmak.

4.2. **Kullanım ölçümü:** Hangi ekranın ve özelliğin kullanıldığını, sürüm ve platform bilgisini, içerik ve serbest metin yazmadan, **kendi sunucumuzda** ve hesabınıza bağlı olarak kaydederiz (Uzman Aydınlatma Metni, kullanım kayıtları). Bu ölçüm için tarayıcınıza izleme çerezi yerleştirilmez ve üçüncü taraf bir araç kullanılmaz.

## 5. Hukuki sebep ve onay

5.1. Kullandığımız depolamanın tamamı, açıkça talep ettiğiniz hizmetin (Moyo Mercek web'e giriş yapıp çalışmanın) sunulması için zorunludur. Bu depolama yoluyla yapılan işleme KVKK md. 5/2-c (sözleşmenin ifası) ve md. 5/2-f (meşru menfaat: hesabın ve verinin güvenliği) hukuki sebeplerine dayanır.

5.2. KVKK Kurumu'nun çerez rehberine göre zorunlu çerezler için açık rıza aranmaz; ancak aydınlatma yapılır. Bu politika ve aşağıdaki bilgilendirme bandı bu amaçla sunulur.

## 6. Depolamayı nasıl yönetirsiniz

6.1. **Çıkış yap:** Moyo Mercek web'de çıkış yaptığınızda oturum bilgisi tarayıcınızdan silinir. Ortak kullanılan bir bilgisayarda işiniz bitince her zaman çıkış yapın.

6.2. **Tarayıcı ayarları:** Tarayıcınızın gizlilik ya da site verileri ayarlarından Moyo Mercek web'in depoladığı verileri görebilir, silebilir ya da engelleyebilirsiniz. Zorunlu depolamayı engellerseniz Moyo Mercek web'e giriş yapamazsınız ya da her açılışta yeniden giriş yapmanız gerekir.

6.3. **Gizli pencere:** Tarayıcınızın gizli (özel) penceresinde depolanan veriler pencere kapanınca silinir.

## 7. Üçüncü taraflar ve yurt dışı

7.1. Oturum bilgisi, kimlik doğrulama hizmet sağlayıcımız Supabase'in (Frankfurt, Almanya; AB bölgesi) sunucularında doğrulanır. Moyo Mercek web'in barındırıldığı hizmet sağlayıcısı (Cloudflare), sayfaları size iletirken IP adresi ve tarayıcı bilgisi gibi teknik bağlantı kayıtlarını işleyebilir. Hizmet sağlayıcılarımızın listesi ve yurt dışı aktarım bilgisi Uzman Aydınlatma Metni'nde ve [Hizmet Sağlayıcılar (Alt İşleyenler) Listesi](/yasal/alt-isleyenler)'de yer alır.

7.2. Moyo Mercek web, bu politikada sayılanlar dışında üçüncü taraf bir hizmetin tarayıcınıza çerez yerleştirmesine izin vermez.

## 8. Haklarınız ve başvuru

KVKK md. 11'deki haklarınızı ve başvuru yollarını Uzman Aydınlatma Metni'nde bulabilirsiniz. Sorularınız için: `destek@moyoapp.com.tr`.

## 9. Değişiklikler

9.1. Kullandığımız depolama değişirse bu politikayı güncelleriz; tablo her zaman güncel listeyi gösterir.

9.2. İleride zorunlu olmayan bir çerez ya da depolama (ör. analiz) eklemeye karar verirsek: önce bu politikayı güncelleriz, web sürümüne kabul ve reddin eşit kolaylıkta sunulduğu bir onay ekranı ekleriz ve **açık rızanızı almadan** o depolamayı kullanmayız. Onayınızı istediğiniz an geri alabilirsiniz.

9.3. **Tanıtım sayfaları ve reklam ölçümü.** Ürünlerimizi tanıttığımız web sayfalarında reklam ya da ziyaretçi ölçüm aracı (ör. sosyal medya pikseli) kullanmaya karar verirsek bu araçlar sayfa açılınca **yüklenmez**; yalnız bilgilendirme bandında "Kabul et"e bastığınızda yüklenir ve "Reddet" aynı kolaylıkta sunulur. Sayfayı ziyaret etmek onay sayılmaz. Bu durumda önce bu politikayı, Gizlilik Politikası'nı ve Hizmet Sağlayıcılar Listesi'ni güncelleriz. Uygulamaların içinde (Moyo Oyun, Moyo Ebeveyn, Moyo Mercek) reklam ya da izleme aracı kullanılmaz.

---

## Bilgilendirme bandı (öneri)

Moyo Mercek web'in ilk açılışında ekranın altında, içeriği kapatmayan ince bir bant. Yalnız zorunlu depolama olduğu için "Kabul et / Reddet" yerine tek düğme yeterlidir; düğmeye basınca bant bir daha gösterilmez (bu tercih de yerel depolamada tutulur).

> Moyo Mercek web yalnız oturumunu açık tutmak ve seçimlerini hatırlamak için zorunlu tarayıcı depolaması kullanır. Analiz ya da reklam çerezi yok. **[Çerez Politikası]** · **[Anladım]**

Giriş yaptıktan sonra Ayarlar › Yasal ve gizlilik › Çerez Politikası'ndan her zaman ulaşılır.

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('alt-isleyenler', 'v1', 'Hizmet Sağlayıcılar (Alt İşleyenler) Listesi', '{parent,child,clinic,web}', false, $md$# Hizmet Sağlayıcılar (Alt İşleyenler) Listesi

## Kısaca

Moyo Ebeveyn, Moyo Oyun ve Moyo Mercek'i (ailelere dönük ekranlarda Moyo Uzman) çalıştırmak için bizim adımıza ve talimatımızla çalışan birkaç hizmet sağlayıcı kullanırız. Bu sayfa hepsini, ne için kullandığımızı, hangi veriye eriştiklerini, nerede olduklarını ve yurt dışı aktarımı hangi güvenceyle yaptığımızı gösterir. Reklam ağı, veri satın alan ya da analiz/izleme yapan bir sağlayıcı **yoktur**. Yapay zekâ hizmetine veri gönderilmez. Yeni bir sağlayıcı eklemeden önce bu listeyi güncelleriz.

**Aktarımın amacı:** Verinin bu sağlayıcılara ve yurt dışına aktarılmasının amacı yalnız hizmeti çalıştırmaktır (veritabanı, depolama, e-posta, ödeme, bildirim). Sağlayıcılar veriyi kendi amaçları için kullanamaz.

## 1. Tanımlar

- **Veri sorumlusu:** Moyo'yu işleten [AD SOYAD] ("biz").
- **Moyo ya da Platform:** "Moyo" ya da "Platform": [AD SOYAD] tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer.
- **Alt işleyen (hizmet sağlayıcı):** Kişisel veriyi yalnız bizim adımıza ve talimatımızla işleyen şirket. Veriyi kendi amaçları için kullanamaz.
- **Bağımsız veri sorumlusu:** Veriyi kendi amaçları için de işleyen ve kendi gizlilik politikasına tabi olan şirket (ör. App Store satışında Apple).

## 2. Özet liste

| # | Sağlayıcı | Rol | Ne için | Hangi uygulama | Konum | Durum |
|---|---|---|---|---|---|---|
| 1 | Supabase | Alt işleyen | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | Üçü + ekip paneli | Frankfurt, Almanya; AB bölgesi | Kullanımda |
| 2 | Apple | Satışta bağımsız veri sorumlusu; bildirimde alt işleyen | App Store satışı ve aboneliği; anlık bildirim (APNs) | Üçü | ABD / AB | Kullanımda |
| 3 | Expo | Alt işleyen | Yedek bildirim yolu | Moyo Ebeveyn, Moyo Mercek (Expo anahtarı kaydeden cihazlar) | ABD | Kodda var; canlıda kalıp kalmayacağı karar bekliyor |
| 4 | RevenueCat | Alt işleyen | Abonelik durumunun doğrulanması | Moyo Ebeveyn, Moyo Mercek | ABD | Kullanımda |
| 5 | Resend | Alt işleyen | İşlem e-postaları | Moyo Ebeveyn, Moyo Mercek | ABD / AB | Kullanımda |
| 6 | Cloudflare | Alt işleyen | Alan adı ve DNS; ekip yönetim panelinin, Moyo Mercek web uygulamasının, tanıtım ve davet sayfalarının ve herkese açık yasal metin / destek sayfalarının barındırılması (destek formunun içeriği Cloudflare üzerinden geçer, orada saklanmaz) | Ekip paneli, Moyo Mercek web, moyoapp.com.tr sayfaları (/yasal, /destek dahil) | Küresel ağ | Kullanımda |
| 7 | Google (Gmail SMTP) | Alt işleyen | Yalnız test dönemi e-postaları | Moyo Mercek (davet) | ABD | **Yalnız test; canlıdan önce kaldırılır** |

## 3. Ayrıntılar

### 3.1 Supabase

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | Bütün uygulama verisinin tutulduğu veritabanı; e-posta + şifre ile giriş ve çocuk cihazının kimliği belirsiz oturumu; mesaj fotoğrafları, sesli mesajlar ve davranış kayıtlarındaki ses kayıtları için özel dosya depolama; bildirim ve e-posta gibi sunucu işlevleri; zamanlanmış işler |
| Veri | Bu uygulamalarda işlenen verilerin tamamı: ebeveyn, çocuk ve uzman hesap ve profil verisi; rutinler ve adımlar, mesajlar, oyun kaydı; davranış kayıtları ve davranış olayları, ebeveyn eğitimi yanıtları, tanışma yanıtları ve uzman notları gibi kullanıcıların kendi girdiği takip kayıtları; kullanım ve güvenlik kayıtları |
| İlgili kişiler | Ebeveynler, çocuklar, uzmanlar, ekip üyeleri |
| Konum | Frankfurt, Almanya; AB bölgesi |
| Aktarım güvencesi | [standart sözleşme imzalanacak] + imzadan sonra 5 iş günü içinde Kurul'a bildirim |
| Sağlayıcının alt işleyenleri | Bulut altyapısı ve destek hizmetleri — [Supabase'in güncel listesinden eklenecek] |

### 3.2 Apple

| | |
|---|---|
| Rol | **App Store satışı ve aboneliği:** satıcı Apple'dır, ödeme ve Apple Kimliği bilgileri bakımından bağımsız veri sorumlusudur (Apple'ın gizlilik politikası geçerlidir). **Anlık bildirim (APNs):** bizim talimatımızla bildirimi cihaza iletir |
| Amaç | Abonelik satışı, yenileme, iade; Moyo Ebeveyn, Moyo Oyun ve Moyo Mercek'e anlık bildirim iletmek |
| Veri | Bize gelen: işlem kimliği, ürün, dönem sonu, yenileme durumu (kart bilgisi bize gelmez). Apple'a giden: cihazın bildirim anahtarı ve bildirim başlığı ile metni (ör. "Elif adımı tamamladı" — çocuğun adı geçebilir) |
| İlgili kişiler | Ebeveynler, uzmanlar (satış); ebeveynler, çocuklar, uzmanlar (bildirim) |
| Konum | ABD / AB |
| Aktarım güvencesi | Bildirim için: [standart sözleşme imzalanacak] + Kurul'a bildirim. Satış için: Apple'ın kendi koşulları |

### 3.3 Expo (yedek bildirim yolu)

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | Cihaz Apple anahtarı yerine Expo bildirim anahtarı kaydettiyse anlık bildirimi Expo Push hizmeti üzerinden Apple'a iletmek |
| Veri | Expo bildirim anahtarı, bildirim başlığı ve metni (çocuğun adı geçebilir; sağlık bilgisi konmaz) |
| İlgili kişiler | Ebeveynler, uzmanlar; bildirim metninde adı geçen çocuklar |
| Konum | ABD |
| Aktarım güvencesi | [standart sözleşme imzalanacak] + Kurul'a bildirim |
| Durum | Yedek yol; canlıda kapatılırsa bu satır listeden çıkar |

### 3.4 RevenueCat

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | App Store aboneliğinin geçerli olup olmadığını doğrulamak ve durum değişikliğini (yenileme, iptal, iade) sunucumuza bildirmek |
| Veri | Uygulama kullanıcı kimliği (Supabase'in verdiği rastgele kimlik; ad ve e-posta gönderilmez), satın alma kayıtları (ürün, işlem kimliği, tarih, durum, mağaza ülkesi). [Uygulamadaki RevenueCat kütüphanesinin ayrıca gönderdiği cihaz ve uygulama bilgileri RevenueCat belgelerinden teyit edilip eklenecek] |
| İlgili kişiler | Abone olan ebeveynler ve klinik sahibi uzmanlar |
| Konum | ABD |
| Aktarım güvencesi | [standart sözleşme imzalanacak] + Kurul'a bildirim |

### 3.5 Resend

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | İşlem e-postaları: e-posta doğrulama, şifre sıfırlama, e-posta değişikliği, uzmanın aile daveti, abonelik ve hesap bilgilendirmeleri |
| Veri | Alıcının e-posta adresi ve e-posta içeriği. Davet e-postasında uzmanın adı, unvanı, klinik adı ve davet kodu bulunur; çocuğun adı ve sağlık bilgisi yazılmaz, konu satırında unvan yer almaz |
| İlgili kişiler | Ebeveynler, uzmanlar |
| Konum | ABD / AB |
| Aktarım güvencesi | [standart sözleşme imzalanacak] + Kurul'a bildirim |
| Durum | Kullanımda; reklam ya da kampanya e-postası için kullanılmaz |

### 3.6 Cloudflare

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | Alan adının (moyoapp.com.tr) DNS hizmeti; ekibimizin kullandığı yönetim panelinin, Moyo Mercek'in web uygulamasının, tanıtım ve davet sayfalarının ve herkese açık yasal metin ve destek sayfalarının barındırılması |
| Veri | Ekip üyesinin oturum bilgisi; panelde görüntülenen kullanıcı verisi Cloudflare ağından şifreli bağlantıyla geçer; ağ düzeyinde ziyaretçi IP adresleri |
| İlgili kişiler | Ekip üyeleri; panelde kaydı görüntülenen ebeveyn, çocuk ve uzmanlar; sayfaları ve Moyo Mercek web uygulamasını açan ziyaretçiler |
| Konum | Küresel ağ |
| Aktarım güvencesi | [standart sözleşme imzalanacak] + Kurul'a bildirim |

### 3.7 Google (Gmail SMTP) — yalnız test dönemi

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | Test döneminde uzman davet e-postalarının gönderilmesi |
| Veri | Alıcının e-posta adresi ve davet e-postasının içeriği |
| Konum | ABD |
| Durum | Canlıya almadan önce kaldırılır; yerini Resend alır. Bu satır o zaman listeden çıkar |

## 4. Alt işleyen olmayan alıcılar

Aşağıdakiler bizim adımıza çalışan hizmet sağlayıcı değildir; ama veriniz onlara aktarılabilir:

| Alıcı | Ne zaman | Hangi veri |
|---|---|---|
| Ailenizdeki diğer ebeveyn | Ailenize katıldığında | Aile ve çocuk verisi |
| Ebeveynin seçtiği uzman | Yalnız ebeveynin açık rızasıyla, geri alınana kadar | Gizlilik Politikası 8. bölümde sayılan kayıtlar (uygulamada bırakılan kayıtlar) |
| Yeni uzman (önceki uzman kayıtları) | Yalnız ebeveynin ayrı açık rızasıyla | Önceki uzmanın kayıtları, uzmanın adı gizlenerek, salt okunur |
| Yetkili kamu kurumları ve yargı mercileri | Usulüne uygun talep olduğunda | Talep kapsamıyla sınırlı |
| Hukuk ve mali danışmanlarımız | Bir hakkın korunması ya da kanuni yükümlülük gerektiğinde | Gerekli olanla sınırlı |

## 5. Her alt işleyenle yaptığımız sözleşme

Her alt işleyenle yazılı bir veri işleme sözleşmesi yapar ya da sağlayıcının sözleşmesini kabul ederiz. Sözleşmede en az şunlar bulunur:

1. Veri yalnız bizim talimatımızla ve bu sayfada yazan amaçla işlenir.
2. Sağlayıcı uygun teknik ve idari güvenlik tedbirlerini alır (KVKK md. 12/2: güvenlikten birlikte sorumluyuz).
3. Sağlayıcı bir veri ihlalini fark edince bize gecikmeden bildirir.
4. Sağlayıcı kendi alt işleyenlerini bize bildirir.
5. Sözleşme bitince veri silinir ya da bize iade edilir.
6. Yurt dışı aktarımda Kurul'un ilan ettiği standart sözleşme değiştirilmeden kullanılır ve imzadan sonra 5 iş günü içinde Kurul'a bildirilir.

## 6. Değişiklik bildirimi kuralı

| Değişiklik | Ne yaparız | Ne zaman |
|---|---|---|
| Yeni alt işleyen ya da mevcut bir alt işleyene yeni veri türü veya yeni ülke | (1) Yurt dışıysa standart sözleşmeyi imzalarız; (2) bu listenin yeni sürümünü ve Gizlilik Politikası 10. bölümünü yayımlarız; (3) uygulama içinde "Hizmet sağlayıcı listemiz güncellendi" bildirimi gösteririz; değişiklik özel nitelikli veri içerebilecek kayıtları ya da yeni bir amacı kapsıyorsa onay gerektiren metinlerde yeniden onay isteriz; (4) Kurul'a bildirim yaparız | Kullanmaya başlamadan **önce**; Kurul bildirimi imzadan sonra 5 iş günü içinde |
| Uzmanlar için (Veri İşleme Eki) | Yeni alt işleyen uzmanlara e-postayla ve Moyo Mercek'te duyurulur. Uzman makul gerekçeyle itiraz edebilir; çözüm bulunamazsa sözleşmeyi cezasız sona erdirebilir ve kayıtlarının silinmesini isteyebilir | Kullanmaya başlamadan en az [SÜRE] önce (öneri: 30 gün) |
| Acil değişiklik (güvenlik açığı, sağlayıcının hizmeti aniden kesmesi) | Değişikliği yaparız, sonra yukarıdaki adımları tamamlarız | En geç [SÜRE] içinde (öneri: 7 gün) |
| Alt işleyenin çıkarılması | Listeyi güncelleriz; sağlayıcıdan verinin silindiğini teyit ederiz | Çıkarıldığında |

Her güncellemede bu sayfanın sürümü (v1, v2 …) ve tarihi değişir; eski sürümler saklanır. Liste yılda en az bir kez gözden geçirilir.

Yürürlük: [TARİH] · Sürüm: v1 · İletişim: `destek@moyoapp.com.tr`
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('kvkk-basvuru', 'v1', 'KVKK Başvuru Usulü', '{parent,child,clinic,web}', false, $md$# KVKK Başvuru Usulü

## Kısaca

- Kişisel verilerinizle ilgili her talebi bize iletebilirsiniz: bilgi almak, kopyasını istemek, düzeltmek, silmek, itiraz etmek, kimlere aktarıldığını öğrenmek, zararın giderilmesini istemek.
- **En kolay yol:** uygulamanın içinden **KVKK başvurusu**: Moyo Ebeveyn'de Aile › Hesap › Yasal ve gizlilik, Moyo Mercek (ailelere dönük ekranlarda Moyo Uzman) uygulamasında Ayarlar › Yasal ve gizlilik. Hesabınıza bağlıdır; kimliğinizi ayrıca kanıtlamanız gerekmez.
- Diğer yollar: `destek@moyoapp.com.tr` (kayıtlı e-posta adresinizden; konu satırına "KVKK başvurusu" yazın), [ADRES] adresine imzalı dilekçe, KEP.
- En geç **30 gün** içinde, **ücretsiz** yanıt veririz.
- Çocuğunuz adına veli olarak başvurabilirsiniz.
- Uzmanın aileyle ilgili notları gibi kayıtlarda başvurunuzu uzmanın kliniğine yönlendirebiliriz (8. bölüm).

"Moyo" ya da "Platform": [AD SOYAD] tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer. Bu metinde "biz", Moyo'yu işleten veri sorumlusunu ([AD SOYAD]) anlatır.

## 1. Kimler başvurabilir?

- Moyo Ebeveyn kullanan ebeveynler.
- Moyo Mercek kullanan uzmanlar.
- Moyo Oyun'u oynayan çocuklar adına velileri ya da yasal temsilcileri.
- Bir uzmanın davet ettiği ama henüz kayıt olmamış ebeveynler.
- Hesabını silmiş eski kullanıcılar ve bize yazışma yoluyla verisini iletmiş herkes.

Başkası adına başvuru için noter onaylı vekâletname gerekir (velinin çocuk adına başvurusu 7. bölümde).

## 2. Başvuru yolları

| Yol | Nasıl | Kimlik |
|---|---|---|
| **Uygulama içi** (önerilen) | Moyo Ebeveyn'de Aile › Hesap › Yasal ve gizlilik › KVKK başvurusu; Moyo Mercek'te Ayarlar › Yasal ve gizlilik › KVKK başvurusu. Başvurunuzun durumunu aynı ekranda "Başvurularım" altında görürsünüz | Hesabınızla giriş yapmış olmanız yeterlidir |
| **E-posta** | `destek@moyoapp.com.tr` (bütün konular için tek adresimiz; konu satırına "KVKK başvurusu" yazmanızı rica ederiz) | Sistemimizde kayıtlı e-posta adresinizden göndermeniz ya da güvenli elektronik imza veya mobil imza kullanmanız gerekir |
| **Yazılı** | [ADRES] adresine ıslak imzalı dilekçe; elden, posta ya da noter aracılığıyla | İmza ve 3. bölümdeki bilgiler |
| **KEP** | [KEP ADRESİ] adresine kendi KEP adresinizden | KEP |

Moyo Oyun'da başvuru formu yoktur; çocuk adına başvuruyu veli Moyo Ebeveyn'den yapar.

## 3. Başvuruda bulunması gerekenler

- Adınız ve soyadınız; yazılı başvuruda imzanız.
- Türk vatandaşıysanız T.C. kimlik numaranız; değilseniz uyruğunuz ve pasaport ya da kimlik numaranız.
- Tebligata esas yerleşim yeri ya da iş yeri adresiniz.
- Varsa bildirime esas e-posta adresiniz ve telefonunuz.
- Talebinizin konusu ve varsa belgeleriniz.
- Hangi uygulamayla ilgili olduğu (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) ve çocuk adına başvuruyorsanız hangi çocuk.

Uygulama içi başvuruda adınız ve e-posta adresiniz hesabınızdan gelir. [T.C. kimlik numarası uygulama içi başvuruda istenecek mi: avukat kararı.]

## 4. Kimliğinizi nasıl doğrularız?

Amacımız verinizi başkasına vermemektir.

- **Uygulama içi:** Hesabınızla giriş yapmış olmanız yeterlidir. Verilerinizin kopyası ya da silinmesi gibi taleplerde ayrıca kayıtlı e-posta adresinize bir doğrulama bağlantısı gönderebiliriz.
- **E-posta:** Kayıtlı adresinizden geldiyse yanıtı da o adrese göndeririz. Başka bir adresten geldiyse uygulamaya giriş yapıp başvurunuzu oradan yinelemenizi ya da kayıtlı adresinize gönderdiğimiz kodu bize iletmenizi isteriz.
- **Yazılı ve KEP:** İmzanız ve verdiğiniz bilgiler; gerekirse kayıtlı e-posta adresinizden teyit.
- Kimlik belgesi fotokopisini yalnız başka yolla doğrulayamazsak isteriz; doğrulamadan sonra imha ederiz.
- Kimliğinizi doğrulayamazsak veri vermeyiz ve bunu gerekçesiyle size bildiririz.

## 5. Neler isteyebilirsiniz?

| Talep (KVKK md. 11) | Ne yaparız | Uygulamada kendiniz hemen yapabilecekleriniz |
|---|---|---|
| Verinizin işlenip işlenmediğini öğrenmek; işlenmişse bilgi istemek; amacını ve amaca uygun kullanılıp kullanılmadığını öğrenmek | Hangi verinizi, hangi amaçla, hangi hukuki sebeple işlediğimizi ve ne kadar sakladığımızı yazarız | Gizlilik Politikası ve aydınlatma metinleri |
| Verinizin bir kopyasını almak | Hesabınıza ait verilerin okunabilir bir dökümünü güvenli bir bağlantıyla göndeririz. Başka kişilere ait veriler (ör. diğer ebeveynin yazdıkları) ayıklanabilir | Moyo Ebeveyn / Moyo Mercek › Yasal ve gizlilik › "Verimi indir" (sunucu hazır: `my_data_export`; uygulama ekranı eklenince) |
| Eksik ya da yanlış verinin düzeltilmesi | Düzeltir, sonucunu bildiririz | Profil ve çocuk bilgilerini düzenlemek |
| Verinin silinmesi ya da yok edilmesi | Şartlar oluşmuşsa siler, sonucunu bildiririz. Kanunen saklamak zorunda olduğumuz kayıtları (ör. ödeme kayıtları) yalnız o amaçla ve süresi kadar tutarız | Hesabımı sil; mesaj ve kayıtları silmek; [çocuk profilini sil — Moyo Ebeveyn'e eklenecek] |
| Verinin yurt içinde ya da yurt dışında aktarıldığı kişileri öğrenmek | Alıcıları ve ülkelerini yazarız | Hizmet Sağlayıcılar Listesi ([Hizmet Sağlayıcılar (Alt İşleyenler) Listesi](/yasal/alt-isleyenler)) |
| Düzeltme ve silmenin, verinin aktarıldığı kişilere bildirilmesi | Verinin aktarıldığı hizmet sağlayıcılara ve gerekiyorsa uzmana bildiririz | — |
| Yalnız otomatik sistemlerle yapılan bir analizin aleyhinize sonucuna itiraz | İtirazınızı inceleriz. Bugün sizin hakkınızda yalnız otomatik sistemlerle sonuç doğuran bir karar vermiyoruz | — |
| Kanuna aykırı işleme yüzünden uğradığınız zararın giderilmesi | Talebinizi inceler, gerekçeli yanıt veririz | — |
| Uzmanla paylaşımı durdurmak | Başvuru gerekmez | Moyo Ebeveyn › Uzmanım › uzmanınız › Uzmanı kaldır; erişim hemen biter |

## 6. Süre ve ücret

- Başvurunuzu, bize ulaştığı tarihten itibaren talebin niteliğine göre en kısa sürede ve **en geç 30 gün** içinde sonuçlandırırız.
- Yanıt **ücretsizdir**. Mevzuatın izin verdiği hâllerde bile ücret almıyoruz.
- Yanıtı yazılı ya da elektronik olarak, başvurduğunuz yolla veririz. Uygulama içi başvurunun yanıtı kayıtlı e-posta adresinize gider; uygulamada başvurunuzun durumu "Yanıtlandı" olur.
- Talebinizi reddedersek gerekçesini yazarız.

## 7. Çocuğunuz adına başvuru

- Moyo Oyun'da çocuğun ayrı bir hesabı yoktur; profilini veli Moyo Ebeveyn'de oluşturur. Çocuğun verisiyle ilgili talepleri veli yapar.
- **Ailede kayıtlı ebeveynseniz:** Moyo Ebeveyn › Aile › Hesap › Yasal ve gizlilik › KVKK başvurusu › "Kimin için?" › çocuğunuzu seçin. Ebeveyn hesabınız ve çocuğu eklerken verdiğiniz veli beyanı yeterlidir.
- **Ailede kayıtlı olmayan veli ya da vasi iseniz:** `destek@moyoapp.com.tr` (konu: "KVKK başvurusu"), yazılı ya da KEP yoluyla başvurun ve velayet ya da vesayetinizi gösteren belgeyi ekleyin.
- Çocuğun cihazının oyunla bağlantısını başvuru gerekmeden hemen kapatabilirsiniz: Moyo Ebeveyn › Aile › çocuk › Cihaz bağlantısını kaldır. Çocuğun profilinin ve ona bağlı verilerin (rutinler ve adımlar, mesajlar, oyun kaydı) silinmesini bu sayfadaki yollarla isteyebilirsiniz; ailenin tamamı için hesabınızı silmeniz yeterlidir.

## 8. Uzmanla ilgili kayıtlar: kime başvurursunuz?

| Kayıt | Kime |
|---|---|
| Uzmanın birlikte çalıştığı aile hakkında girdiği kayıtlar (notlar, hedefler, değerlendirmeler, takip planı, hedef davranışlar, atadığı ebeveyn eğitimleri ve gözlem verisi, seans kayıtları) | Bu kayıtların veri sorumlusu uzman ya da kliniğidir; biz onun adına saklayan veri işleyeniz. Başvurunuzu uzmanınıza ya da kliniğine yapın. Bize gelirse kliniğe iletir ve size bildiririz; kliniğe teknik olarak yardım ederiz. |
| Uzmanla paylaşımı durdurmak | Başvuru gerekmez: Moyo Ebeveyn › Uzmanım |
| Uzmanın sizi davet ederken girdiği bilgiler (adınız, e-postanız, çocuğun adı ve yaş grubu) | Davet kaydı kullanılmazsa en geç 3 gün, bağlanıp onaylanmazsa en geç 30 gün içinde kendiliğinden silinir. Daha önce silinmesini isterseniz bize yazın |
| Uzmanın kendi hesabı (uzmanlar için) | Bize |
| Ebeveynin girdiği kayıtlar (rutinler ve adımlar, davranış kayıtları ve davranış olayları, ebeveyn eğitimi yanıtları, takip planı uygulama kayıtları) | Bize |

## 9. Hangi durumlarda talebi yerine getiremeyiz?

- Kimliğinizi doğrulayamazsak.
- Talep başka bir kişinin verisini kapsıyorsa (o kısmı ayıklarız).
- Veriyi kanunen saklamak zorundaysak (silme talebinde; yalnız o amaçla tutarız).
- KVKK md. 28/2'de sayılan hâllerde.
- Talep açıkça dayanaksızsa ya da kötüye kullanılıyorsa.

Her ret gerekçelidir.

## 10. Kurul'a şikâyet

Başvurunuz reddedilirse, yanıtımızı yetersiz bulursanız ya da 30 gün içinde yanıt vermezsek, yanıtımızı öğrendiğiniz tarihten itibaren 30 gün içinde ve her hâlde başvuru tarihinizden itibaren 60 gün içinde Kişisel Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz (KVKK md. 14). Kurul'a şikâyetten önce bize başvurmanız gerekir.

## 11. Başvuru kayıtları

Başvurunuzu, kanalını, türünü, açıklamanızı, durumunu, tarihlerini ve yanıt özetini kayıt altına alırız. Bu kaydı yalnız yetkili ekip üyeleri görür; her işlem denetim kaydına geçer. Başvuru kapandıktan sonra 3 yıl saklanır.

Yürürlük: [TARİH] · Sürüm: v1 · [AD SOYAD], [ADRES] · `destek@moyoapp.com.tr`
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';
