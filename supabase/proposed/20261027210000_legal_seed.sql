-- Yasal metin taslakları (üretildi: python3 tools/legal_seed.py; kaynak ortak/hukuk/*.md). Elle düzenleme.
-- Önkoşul: 20261027200000_legal.sql. Yalnız taslak satırlar güncellenir; yayımlanmış sürüm değişmez. Tekrar çalıştırılabilir.

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('gizlilik', 'v1', 'Gizlilik Politikası', '{parent,child,clinic,web}', false, $md$# Gizlilik Politikası

## Kısaca

> **Bir bakışta**
>
> **Ne topluyoruz?** Ebeveynin hesabı (ad, e-posta), ebeveynin eklediği çocuk profili (ad ya da takma ad, simge, yaş grubu), görevler ve onaylar, aile içi mesajlar, oyun kaydı, uzmanın ve ebeveynin girdiği takip kayıtları, abonelik durumu ve içeriği olmayan kullanım kayıtları.
>
> **Neden?** Uygulamaları çalıştırmak: çocuğun görevlerini ve oyununu ebeveyne bağlamak, ebeveynin isterse uzmanıyla paylaşmasını sağlamak, aboneliği yönetmek, hizmeti güvenli tutmak ve iyileştirmek.
>
> **Kim görür?** Yalnız kendi aileniz. Uzman yalnız siz izin verdiğinizde ve yalnız izin verdiğiniz çocuğu görür; izni istediğiniz an geri alırsınız. Ekibimiz yalnız gerektiğinde, iki adımlı girişle, gerekçe yazarak ve kayıt altında bakar; mesajlarınızı, fotoğraflarınızı, ses kayıtlarınızı ve uzman notlarının metnini göremez.
>
> **Ne yapmıyoruz?**
> - Reklam göstermiyoruz.
> - Verinizi satmıyor, kiralamıyor, pazarlama için kimseyle paylaşmıyoruz.
> - Sizi ya da çocuğunuzu izlemiyoruz: üçüncü taraf reklam, analiz ya da izleme aracı kullanmıyoruz.
> - Verinizi yapay zekâ hizmetlerine göndermiyoruz.
> - Çocuktan e-posta, telefon, konum, fotoğraf ya da ses almıyoruz. Çocuk yalnız kendi ailesiyle yazışır.
> - Hiçbir gösterge tanı, zekâ ya da dikkat puanı değildir.
>
> **Haklarınız:** Verinizi görebilir, düzeltebilir, silebilir, hesabınızı uygulamanın içinden kapatabilirsiniz. Başvuru: uygulamada Ayarlar › KVKK başvurusu ya da `kvkk@[ALAN ADI]`. 30 gün içinde ücretsiz yanıt veririz.

## 1. Biz kimiz, bu metin neyi kapsar?

Bu politika **Pofi Adası** (çocuk oyunu, iOS), **ParentApp** (ebeveyn uygulaması, iOS) ve **ClinicApp** (uzman uygulaması, iPad ve web) ile bu uygulamaların internet sayfalarını ve gönderdiği e-postaları kapsar.

Kişisel verilerinizin veri sorumlusu:
**[ŞİRKET UNVANI]**, [ADRES], MERSİS/VKN: [MERSİS/VKN]
E-posta: `kvkk@[ALAN ADI]` (kişisel veri konuları), `destek@[ALAN ADI]` (diğer sorular).

Bu metinde "biz" bu şirketi anlatır.

Bu politika genel çerçevedir. Hangi verinin hangi hukuki sebeple işlendiğini kişiye göre ayrı ayrı anlatan metinlerimiz şunlardır:

| Kim için | Metin |
|---|---|
| Ebeveynler | Ebeveyn Aydınlatma Metni (`aydinlatma-ebeveyn`) |
| Uzmanlar | Uzman Aydınlatma Metni (`aydinlatma-uzman`) |
| Pofi Adası'nı oynayan çocuk ve velisi | Pofi Adası Çocuk ve Veli Aydınlatma Metni (`aydinlatma-cocuk`) |

Bu politika ile aydınlatma metinleri birlikte okunur.

**Hizmetimizin sınırı:** Uygulamalarımız sağlık hizmeti sunmaz, tanı koymaz, tedavi etmez. Uzman istihdam etmeyiz; uzman ile aile arasında aracılık ya da yönlendirme yapmayız. ClinicApp, uzmanın kendi tanıdığı aileyle çalışması için bir araçtır. Uygulamalarımız acil yardım hizmeti değildir: acil durumda **112**'yi arayın.

## 2. Pofi Adası (GameApp)

**Nasıl bağlanır?** Çocuğun e-postası ya da şifresi yoktur. Ebeveyn, ParentApp'te çocuğu için bir profil oluşturur. Sonra ParentApp'in gösterdiği 15 dakika geçerli, tek kullanımlık kodu ya da QR kodu çocuğun cihazına girer. Cihaz bu profile bağlanır ve cihazda kimliği belirsiz bir oturum açılır.

**İşlediğimiz veriler:**
- Ebeveynin girdiği bilgiler: çocuğun adı ya da takma adı, simgesi, yaş grubu.
- Cihazın oturum kimliği (rastgele bir kimlik).
- Oyun kaydı: seviye, deneyim puanı, evcil hayvanın durumu, eşyalar, ada düzeni, coin harcamaları.
- Ebeveynin verdiği görevler ve çocuğun "Yaptım" işaretleri.
- Çocuğun ebeveynine gönderdiği mesajlar (yazı ve hazır çıkartma) ve ödül istekleri.
- Bildirim gönderebilmek için cihazın bildirim anahtarı.
- Kullanım kayıtları (bkz. 5. bölüm).

**İşlemediğimiz veriler:** Çocuktan e-posta, telefon, şifre, konum, fotoğraf, ses, rehber bilgisi almayız. Reklam kimliği kullanmayız.

**Kamera:** Yalnız ebeveynin gösterdiği QR kodu okumak için ve yalnız o ekranda açılır. Görüntü kaydedilmez, hiçbir yere gönderilmez.

**Satın alma ve reklam:** Pofi Adası'nda uygulama içi satın alma ve reklam yoktur. Dış bağlantılar ve ayarlar ebeveyn kapısının arkasındadır.

**Coin:** Oyundaki coin yalnız ebeveynin onayladığı görevlerle kazanılır ve yalnız oyun içi eşyalara harcanır. Para değildir, satın alınamaz, paraya çevrilemez.

**Kim görür?** Ailedeki ebeveynler. Ebeveyn çocuğu bir uzmanla paylaşırsa uzman çocuğun görevlerini ve "Yaptım" kayıtlarını görür; oyun kaydını, coin'i ve aile içi mesajları görmez.

## 3. ParentApp

**Hesap:** Ad, takma ad, simge, e-posta. Şifreniz bizde açık hâlde durmaz; yalnız kimlik doğrulama sağlayıcımızda geri çevrilemez biçimde (özetlenmiş) saklanır.

**Aile ve çocuklar:** Aile adı; çocuk profilleri (ad ya da takma ad, simge, yaş grubu; isteğe bağlı cinsiyet ve doğum günü). Ailenize ikinci bir ebeveyn davet edebilirsiniz; o da aile verisini görür.

**Günlük kullanım:** Görevler, tekrarlar, hatırlatmalar; çocuğun "Yaptım"ları ve sizin onayınız ya da reddiniz (isteğe bağlı not ve neden); ödüller; Güneş Taşı ve coin hareketleri (taş düşürdüğünüzde yazdığınız neden dahil).

**Mesajlar:** Çocuğunuzla aranızdaki yazılar, fotoğraflar, sesli mesajlar, çıkartmalar ve okundu bilgisi. Fotoğraf ve sesler yalnız ailenize açık, özel bir depolama alanında tutulur.

**Zor an kayıtları:** Yaşanan zor bir anın öncesi, davranış ve sonucu; şiddet derecesi; isteğe bağlı ses kaydı.

**Tanışma yanıtları:** İlk kurulumda verdiğiniz yanıtlar (hedefler, bizi nereden duyduğunuz, çocuğun düzeni, ilgi alanları, motive edenler gibi). Bunları uygulamayı size göre ayarlamak, size destek vermek ve **kimliksiz toplamlar** hâlinde ürünü geliştirmek için kullanırız.

**Sağlık soruları (isteğe bağlı):** Tanışmada çocuğunuzun bir tanısı ya da düzenli kullandığı bir ilaç olup olmadığını sorabiliriz. Yanıt vermek zorunlu değildir; "söylemek istemiyorum" seçeneği vardır. Yanıt verirseniz bunu **ayrı bir açık rıza** ile yaparsınız. Yanıtları istediğiniz an değiştirebilir ya da silebilirsiniz. Bu yanıtlar ekip ekranlarında varsayılan olarak gizlidir ve toplam raporlarda yer almaz.

**Uzman paylaşımı ve takip planı:** Uzmanla paylaşım onaylarınız (hangi metnin hangi sürümünü, ne zaman onayladığınız); uzmanın gönderdiği takip planını uygulama kayıtlarınız ("bugün uyguladım", zorluk derecesi, uygulayamama nedeni). Ayrıntı 7. bölümde.

**Abonelik:** Aile aboneliği App Store üzerinden satılır; satıcı Apple'dır. Kart bilgileriniz bize gelmez. Biz yalnız aboneliğin durumunu (ürün, dönem sonu, işlem kimliği) görürüz. Ücretsiz deneme hakkının tekrar tekrar kullanılmasını önlemek için e-posta adresinizin geri çevrilemez özetini (SHA-256) saklarız; bu özet hesabınızı silseniz de [SÜRE] boyunca kalır.

**İzinler:** Mikrofon (sesli mesaj ve zor an ses kaydı için, yalnız siz kayda bastığınızda), fotoğraflar (mesaja fotoğraf eklemek için), bildirimler. İzinleri telefonunuzun ayarlarından istediğiniz an kapatabilirsiniz.

**Kim görür?** Ailenizdeki diğer ebeveyn(ler). Çocuğunuz kendi görevlerini, size ait mesajları ve ödüllerini görür. Uzman yalnız sizin izninizle (7. bölüm).

## 4. ClinicApp

**Hesap:** Ad, unvan, e-posta, klinik adı, ekipteki rol.

**Belge incelemesi (isteğe bağlı):** Uzman isterse e-Devlet barkodlu mezuniyet belgesini ya da BACB sicil numarasını yükler. Belgede ad, T.C. kimlik numarası, okul, bölüm, derece ve tarih bulunur. Belge kendi sunucumuzda okunur; yapay zekâ ya da dış bir hizmet kullanılmaz. Belgeyi yalnız yetkili ekip üyesi görür ve her görüntüleme kayda geçer. Karar verilince dosya silinir. Yalnız özet (üniversite, bölüm, derece, mezuniyet yılı), belge barkodu ve karar kaydı saklanır. Kimlik numarası saklanmaz. Ailelere yalnız "Belgesi incelendi: <meslek>" bilgisi gösterilir; bu bir kimlik doğrulaması ya da yetki onayı değildir.

**Karşılama anketi:** Meslek, karşılaşılan zorluklar, yararlı bulunan özellikler, gelme nedeni. Kimliksiz toplamlar hâlinde ürünü geliştirmek için kullanılır.

**Danışanla ilgili kayıtlar:** Uzmanın girdiği notlar (aile görmez), hedefler ve haftalık değerlendirmeler, görev önerileri, takip planı (uzman gönderince aile görür), etiketler.

**Davet bilgileri:** Uzman bir aileyi davet ederken ebeveynin adını ve e-postasını, çocuğun adını ya da takma adını ve yaş grubunu girer. Bu bilgi yalnız daveti iletmek ve ebeveynin onayına sunmak için tutulur. Kullanılmayan davet 3 günde, bağlanmış ama onaylanmamış davet en geç 30 günde silinir. Davet 3 gün geçerlidir; davet başına ebeveyne en çok 3 e-posta (ilk gönderim ve yeniden gönderimler) gider. Bu e-postalar reklam içermez; çocuğun adı ve sağlık bilgisi e-postaya yazılmaz.

**Abonelik:** Klinik üyeliği App Store üzerinden satılır; kart bilgisi bize gelmez.

**Web:** ClinicApp'in web sürümü yalnız oturumu açık tutmak ve seçimlerinizi hatırlamak için zorunlu tarayıcı depolaması kullanır; analiz ya da reklam çerezi yoktur. Ayrıntı: ClinicApp Web Çerez Politikası (`cerez-clinicapp-web`).

**Danışan kayıtlarında rolümüz:**
[SEÇENEK A — öneri: Uzmanın danışanı hakkında girdiği notlar, hedefler, değerlendirmeler ve takip planı bakımından veri sorumlusu uzman ya da kliniğidir; biz bu kayıtları onun adına ve talimatıyla saklayan **veri işleyeniz**. Bu kayıtlarla ilgili başvurular öncelikle uzmana ya da kliniğe yapılır; biz uzmana teknik olarak yardım ederiz.]
[SEÇENEK B: Bu kayıtlar bakımından biz ve klinik ayrı ayrı veri sorumlusuyuz.]

## 5. Üç uygulamada ortak kayıtlar

- **Kullanım kayıtları:** Uygulamayı açtığınız günler, oturum sayısı, uygulama sürümü, platform ve hangi ekranın ya da özelliğin kullanıldığını gösteren olay adları. Bu kayıtlarda serbest metin, mesaj içeriği ya da sağlık bilgisi yoktur. Kendi sunucumuzda tutulur; üçüncü taraf analiz aracına gitmez. Amaç: hizmetin çalıştığını ölçmek, hataları bulmak, ürünü geliştirmek.
- **Bildirim kayıtları:** Size giden uygulama içi bildirimler ve okunup okunmadığı. Anlık bildirimin başlığında ya da metninde çocuğunuzun adı geçebilir (ör. "Efe görevi tamamladı"); bu metin Apple'ın bildirim hizmetiyle (yedek yolda Expo üzerinden) telefona iletilir. Bildirim metnine sağlık bilgisi konmaz.
- **Giriş kodu deneme kayıtları:** Kod tahminiyle kötüye kullanımı önlemek için hatalı denemeler IP adresiyle birlikte kısa süre (15 dakika ile 1 gün arası) tutulur.
- **Onay kayıtları:** Hangi metni (Kullanım Koşulları, aydınlatma metni, açık rızalar) hangi sürümüyle ve ne zaman onayladığınız.
- **Ekip işlemleri kaydı:** Ekibimizin hesabınızda yaptığı her işlem gerekçesiyle, değiştirilemez bir kayda yazılır.
- **Destek ve başvurular:** Bize yazdığınızda e-posta adresiniz ve yazışmanız; KVKK başvurularınızın kaydı.

## 6. Hangi amaçla ve hangi hukuki sebeple?

| Amaç | Hukuki sebep (KVKK) |
|---|---|
| Hesap açmak, aileyi ve çocuk profilini kurmak, çocuğun cihazını bağlamak, görev–onay–ödül akışını, mesajlaşmayı ve oyunu çalıştırmak | Sözleşmenin kurulması ve ifası (md. 5/2-c) |
| Aboneliği ve deneme süresini yönetmek | Sözleşmenin ifası (md. 5/2-c) |
| Deneme hakkının kötüye kullanımını önlemek, kod denemelerini sınırlamak, güvenlik ve ekip işlemlerini kayda almak | Meşru menfaat (md. 5/2-f) |
| İçeriksiz kullanım ölçümü, kimliksiz toplamlarla ürün geliştirme | Meşru menfaat (md. 5/2-f) |
| Ödeme kayıtlarını saklamak, resmî makamların usulüne uygun taleplerini yanıtlamak, KVKK başvurularını yanıtlamak | Hukuki yükümlülük (md. 5/2-ç) |
| Onay kayıtlarını ve ekip işlemleri kaydını hak ve savunmalarımız için saklamak | Bir hakkın tesisi, kullanılması veya korunması (md. 5/2-e) |
| Tanışmadaki sağlık soruları; çocuğun uzmanla paylaşılması; önceki uzman kayıtlarının yeni uzmana açılması | **Açık rıza** (md. 6) — her biri ayrı ekranda, isteğe bağlı, istediğiniz an geri alınabilir |

Her işlemin ayrıntılı dayanağı ilgili aydınlatma metnindedir. Açık rıza vermemeniz uygulamanın temel kullanımını engellemez.

## 7. Çocukların gizliliği

- Çocuğun profilini ebeveyn (veli ya da yasal temsilci) oluşturur, yönetir ve siler. Çocuğun verisi velinin bilgisi ve kararıyla işlenir.
- Yaş çocuğa sorulmaz; doğum gününü ya da yaş grubunu ebeveyn girer.
- Çocuktan doğrudan iletişim bilgisi, konum, fotoğraf ya da ses alınmaz.
- Çocuk yalnız kendi ailesiyle yazışır; yabancıyla iletişim kurabileceği bir alan yoktur.
- Oyunda reklam, satın alma ve izleme aracı yoktur. Dış bağlantılar ebeveyn kapısının arkasındadır.
- Çocuğa oyunun içinde, yaşına uygun dille kısa bir bilgi gösterilir (`aydinlatma-cocuk`).
- Veli, çocuğun verisini ParentApp'ten görür, düzeltir, siler; cihaz bağlantısını kapatabilir; çocuk adına KVKK başvurusu yapabilir.
- Çocuğun verisi bir uzmanla yalnız velinin açık rızasıyla paylaşılır.

## 8. Uzmanla paylaşım

- **Uzmanları doğrulamıyoruz.** Uzmanın kimliğini ve meslek yetkisini kontrol etmeyiz. "Belgesi incelendi" bilgisi yalnız belgenin kayıtta göründüğünü anlatır. Paylaşmadan önce uzmanı gerçek hayatta tanıdığınızdan emin olun.
- **Paylaşımı siz başlatırsınız.** Uzmanın davetini açarsınız, çocuğun bilgisini kontrol edersiniz, "Bu uzmanı tanıyorum ve çocuğun velisiyim" kutusunu işaretler ve açık rıza verirsiniz.
- **Uzman ne görür?** Paylaştığınız çocuğun profil bilgilerini (ad ya da takma ad, simge, yaş grubu; girdiyseniz doğum günü ve cinsiyet), çocuğa verilen görevleri, "Yaptım" ve onay kayıtlarını, zor an kayıtlarını ve takip planı uygulama kayıtlarınızı. Uzman bunları yalnız okur, değiştiremez. Aile içi mesajları, coin hareketlerini ve oyun kaydını görmez.
- **Siz ne görürsünüz?** Uzmanın gönderdiği görev önerilerini ve takip planını. Uzmanın kendi notlarını görmezsiniz.
- **Uzman değişirse:** İsterseniz, ayrı bir açık rızayla, önceki uzman(lar)ın kayıtları yeni uzmanınıza yalnız okunur olarak açılır. Önceki uzmanın adı ve iletişim bilgileri gösterilmez.
- **Geri alma:** Paylaşımı ve önceki kayıtların aktarımını Uzmanım bölümünden istediğiniz an durdurursunuz. Uzmanın erişimi hemen sona erer.
- **Davetten önce:** Uzmanınız sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz onaylayana kadar yalnız davet kaydında durur; onaylamazsanız ya da süre dolarsa silinir.
- Uzman ile aile arasındaki mesleki ilişki, ücret, randevu ve tedavi kararları uygulamanın dışındadır.

## 9. Ekibimizin erişimi

Ekibimiz hesap bilgilerinize ve kullanım kayıtlarınıza yalnız şu amaçlarla bakar: destek talebinizi yanıtlamak, güvenlik ve kötüye kullanım incelemesi, abonelik sorunları ve kanuni yükümlülükler.

- Giriş iki adımlı doğrulamayla yapılır; her ekip üyesinin yalnız işine yeten bir rolü vardır.
- Bir şeyi değiştiren her işlem için gerekçe yazılır ve işlem değiştirilemez, silinemez bir kayda geçer.
- Mesaj içerikleri, fotoğraflar, ses kayıtları ve uzman notlarının metni ekip ekranlarında **gösterilmez**.
- Tanışma yanıtları yalnız destek için, gerekçe yazılarak açılır. Sağlık yanıtları ekip ekranında varsayılan olarak gizlidir.

## 10. Hizmet sağlayıcılarımız ve yurt dışına aktarım

Hizmeti sunmak için bizim adımıza ve talimatımızla çalışan hizmet sağlayıcılar kullanırız. Bunlar veriyi yalnız bu iş için işler, kendi amaçları için kullanamaz.

| Sağlayıcı | Ne için | Konum |
|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | [SUPABASE BÖLGESİ] |
| Apple | App Store satışı ve aboneliği (satıcı Apple'dır), anlık bildirim (APNs) | ABD / AB |
| Expo | Yedek bildirim yolu: cihaz Expo bildirim anahtarı verirse bildirim Expo üzerinden Apple'a iletilir | ABD |
| RevenueCat | Abonelik durumunun doğrulanması | ABD |
| Resend | İşlem e-postaları (doğrulama, şifre sıfırlama, uzman daveti) | ABD / AB |
| Cloudflare | Ekip yönetim panelinin barındırılması | Küresel ağ |

Güncel ve ayrıntılı liste: **Hizmet Sağlayıcılar (Alt İşleyenler) Listesi** (`alt-isleyenler`). Yeni bir sağlayıcı eklemeden önce listeyi güncelleriz.

**Yurt dışı:** Bu sağlayıcıların bazı sunucuları Türkiye dışındadır. Aktarımı KVKK md. 9'a uygun yaparız: Kişisel Verileri Koruma Kurulu'nun ilan ettiği standart sözleşmeyi imzalar ve imzadan sonra 5 iş günü içinde Kurul'a bildiririz. [Sağlık verisi için ek şart: avukat belirleyecek.]

**Apple:** App Store'dan satın aldığınızda satıcı Apple'dır; ödeme bilgileriniz Apple'ın kendi gizlilik politikasına tabidir.

**Kanuni zorunluluk:** Mahkeme, savcılık ya da yetkili bir kamu kurumunun usulüne uygun talebi olursa veriyi yalnız talep kapsamında paylaşırız. Kanun yasaklamıyorsa sizi bilgilendiririz.

**İşletme devri:** Şirketimiz birleşir, devredilir ya da varlıkları satılırsa veriler aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa geçebilir. Bunu önceden bildiririz; hesabınızı silme hakkınız saklıdır.

## 11. Güvenlik

- Bütün bağlantılar şifrelidir (TLS).
- Veritabanında her kullanıcı yalnız kendi ailesini ya da kliniğini görebilir (satır düzeyi güvenlik). Çocuğun cihazı yalnız kendi profilini görür.
- Mesaj fotoğrafları, ses kayıtları ve uzman belgeleri özel depolama alanlarında durur; yalnız kısa süreli, imzalı bağlantıyla açılır.
- Ekip paneli iki adımlı doğrulama, rol, gerekçe ve silinemez kayıtla korunur.
- Bir veri ihlali olursa yasal süreler içinde Kişisel Verileri Koruma Kurulu'na ve etkilenen kişilere bildiririz.

Hiçbir sistem kusursuz değildir. Şifrenizi kimseyle paylaşmayın; çocuğunuzun cihazına bağlantı kodunu yalnız siz girin.

## 12. Ne kadar saklıyoruz?

| Veri | Süre |
|---|---|
| Hesap, aile ve klinik verisi | Hesap silinene kadar; silince gecikmeden silinir |
| Uzmanın danışan kayıtları | Klinik ya da (tek kişilik klinikte) uzman hesabı silinene kadar. Ebeveyn paylaşımı geri alınca uzmanın erişimi biter. Aile ya da çocuk profili silinince o çocuğa ait uzman kayıtları da silinir. [Paylaşım bittikten sonraki saklama: [SÜRE]] |
| Kullanılmayan davet bilgisi | 3 gün; bağlanmış ama onaylanmamış davet en geç 30 gün |
| Uzman belge dosyası | Karar verilince silinir |
| Giriş kodu deneme kayıtları | 15 dakika ile 1 gün arası |
| Deneme hakkı kaydı (e-posta özeti) | [SÜRE] |
| Ekip işlemleri kaydı | [SÜRE]; silinen kullanıcının e-postası bu kayda yazılmaz |
| Abonelik ve ödeme kayıtları | [SÜRE] (vergi ve ticaret mevzuatının istediği süre) |
| Kullanım kayıtları | [SÜRE]; sonra yalnız kimliksiz toplamlar kalır |
| KVKK başvuru kayıtları | Başvuru kapandıktan sonra [SÜRE] |

Silinen veriler yedeklerden de [SÜRE] içinde kendiliğinden çıkar. Süre dolan veriyi en geç 6 ayda bir yaptığımız periyodik imhayla siler, yok eder ya da kimliksiz hâle getiririz.

## 13. Hesabınızı silmek

- **ParentApp ve ClinicApp:** Ayarlar › Hesabımı sil. Ailede başka ebeveyn yoksa aile, çocuk profilleri ve onlara bağlı her şey (görevler, mesajlar, fotoğraflar, ses kayıtları, coin ve taş hareketleri, oyun yedekleri, uzman paylaşımları ve uzmanın bu çocuklar için tuttuğu notlar, hedefler ve takip planı) silinir. Başka ebeveyn varsa aile onda kalır, yalnız sizin hesabınız silinir. Tek kişilik klinikte klinik ve kayıtları silinir; ekipte başka uzman varsa klinik kalır.
- **Pofi Adası:** Çocuğun ayrı hesabı yoktur. Ebeveyn, ParentApp'ten çocuğun cihaz bağlantısını kaldırabilir, çocuğun profilini ya da aileyi silebilir; oyunun bağlantısı kapanır.
- **Abonelik:** Hesabı silmek App Store aboneliğini durdurmaz. Aboneliği iPhone/iPad Ayarlar › [adınız] › Abonelikler'den ayrıca iptal edin.
- Kanunen saklamak zorunda olduğumuz kayıtlar (ör. ödeme kayıtları) ve ekip işlemleri kaydı, sizi doğrudan tanıtan bilgi (e-posta) çıkarılarak süresi dolana kadar saklanır.

## 14. Haklarınız ve başvuru

KVKK md. 11 uyarınca şunları isteyebilirsiniz: verinizin işlenip işlenmediğini öğrenmek; işlenmişse bilgi istemek; işleme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenmek; yurt içinde ya da yurt dışında kimlere aktarıldığını bilmek; eksik ya da yanlışsa düzeltilmesini, şartları oluşmuşsa silinmesini ya da yok edilmesini ve bunların aktarılan kişilere bildirilmesini istemek; yalnız otomatik sistemlerle yapılan bir analizin aleyhinize sonucuna itiraz etmek; kanuna aykırı işleme yüzünden zarara uğradıysanız zararın giderilmesini istemek.

**Kendiniz hemen yapabilecekleriniz:** profil ve çocuk bilgilerini düzeltmek, sağlık yanıtlarını silmek, uzman paylaşımını geri almak, cihaz bağlantısını kapatmak, hesabınızı silmek.

**Başvuru yolları:** uygulamada Ayarlar › KVKK başvurusu (hesabınıza bağlıdır, kimliğinizi ayrıca kanıtlamanız gerekmez); `kvkk@[ALAN ADI]` (kayıtlı e-posta adresinizden); [ADRES] adresine yazılı ve imzalı; KEP: [KEP ADRESİ].

Başvurunuzu en geç **30 gün** içinde **ücretsiz** yanıtlarız. Çocuğunuz adına veli olarak başvurabilirsiniz. Yanıttan memnun kalmazsanız Kişisel Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz. Ayrıntı: **KVKK Başvuru Usulü** (`kvkk-basvuru`).

## 15. E-postalar ve bildirimler

Size yalnız hizmetle ilgili e-postalar göndeririz: e-posta doğrulama, şifre sıfırlama, uzman daveti, abonelik ve hesap bilgileri. Bunlar reklam içermez. Bugün pazarlama e-postası göndermiyoruz; ileride gönderirsek bunu ayrı onayınızla ve kanunun öngördüğü kayıt sistemleri üzerinden yaparız. Anlık bildirimleri telefonunuzun ayarlarından kapatabilirsiniz.

## 16. Değişiklikler

Her metnin bir sürümü vardır (v1, v2 …). Yayımlanan bir sürüm değiştirilmez; değişiklik yeni sürümdür ve eski sürümler saklanır.

- **Önemli değişiklikte** (ör. yeni bir veri türü, yeni bir amaç, yeni bir yurt dışı sağlayıcı) uygulamayı açtığınızda neyin değiştiğini kısa bir özetle gösteririz. Onay gerektiren metinlerde yeniden onayınızı isteriz.
- **Küçük değişiklikte** (yazım, açıklama) bu sayfayı güncelleriz ve sürüm tarihini değiştiririz.

Yürürlük: [TARİH] · Sürüm: v1

## 17. İletişim

[ŞİRKET UNVANI], [ADRES]
Kişisel veri konuları: `kvkk@[ALAN ADI]` · Diğer konular: `destek@[ALAN ADI]`
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('aydinlatma-ebeveyn', 'v1', 'ParentApp Aydınlatma Metni (Ebeveyn)', '{parent}', true, $md$# ParentApp Aydınlatma Metni (Ebeveyn)

> Taslak, 27 Ekim 2026. Olgular: `hukuk/00-olgular.md`. Uyarlama ilkeleri: `hukuk/02-ornekler-ve-turk-hukuku.md`. Taslak maddeler: `sozlesme/hukuk_notlari.md` (C, I). Hukuki görüş değildir.

## Kısaca

- Verilerinizin sorumlusu `[ŞİRKET UNVANI]`'dır. Sorularınız için: `kvkk@[ALAN ADI]`.
- Hesabınızı, ailenizi, çocuklarınızın profilini, görevleri, ödülleri ve mesajları yalnız uygulamayı çalıştırmak için işleriz.
- **Reklam yok. Verinizi satmayız. Sizi izlemeyiz:** reklam ağı, üçüncü taraf analiz ya da izleme aracı kullanmayız.
- Tanı ve ilaç soruları isteğe bağlıdır. Yalnız ayrıca onay verirseniz kaydedilir.
- Çocuğunuzun kayıtları bir uzmanla yalnız siz seçerseniz ve ayrıca onay verirseniz paylaşılır. Paylaşımı istediğiniz an durdurursunuz.
- Veriler hizmet sağlayıcılarımızın yurt dışındaki sunucularında da tutulabilir. Bunu KVKK'nın öngördüğü güvencelerle yaparız.
- Hesabınızı uygulamanın içinden silebilirsiniz. Ailede başka ebeveyn yoksa ailenin bütün verisi de silinir.
- Haklarınız için uygulama içinden ya da `kvkk@[ALAN ADI]` adresine yazın. 30 gün içinde ücretsiz yanıt veririz.

## Tam metin

### 1. Bu metin ne anlatır

1.1. Bu metin, ParentApp'i kullanan ebeveynlere kişisel verilerinin nasıl işlendiğini anlatır. 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) md. 10 gereği hazırlanmıştır.

1.2. ParentApp'e eklediğiniz çocukların verisini veli ya da yasal temsilci olarak siz yönetirsiniz. Bu nedenle çocuklarınızın ParentApp'teki verisi de bu metindedir. Çocuğunuzun Pofi Adası (GameApp) oyununda oluşan verisi ayrıca **Pofi Adası Aydınlatma Metni**'nde (`aydinlatma-cocuk`) anlatılır.

1.3. Bu metni okumanız bir onay ya da açık rıza değildir. Açık rıza gereken işlemler (sağlık yanıtları, uzmanla paylaşım, önceki uzman kayıtlarının aktarımı) ayrı ekranlarda, ayrı metinlerle sorulur. Onay vermemeniz ParentApp'i kullanmanızı engellemez.

### 2. Veri sorumlusu

| | |
|---|---|
| Unvan | `[ŞİRKET UNVANI]` |
| Adres | `[ADRES]` |
| MERSİS / VKN | `[MERSİS/VKN]` |
| KVKK başvuruları | `kvkk@[ALAN ADI]` |
| Destek | `destek@[ALAN ADI]` |

ParentApp, Pofi Adası ve ClinicApp aynı veri sorumlusunun ürünleridir ve aynı sunucuları kullanır.

### 3. Hangi verileri işliyoruz

| Kategori | Veriler |
|---|---|
| **Kimlik ve iletişim** | Adınız, takma adınız, seçtiğiniz simge, e-posta adresiniz |
| **Hesap güvenliği** | Şifreniz (yalnız kimlik doğrulama hizmetinde, geri çevrilemez biçimde özetlenmiş olarak; biz göremeyiz), oturum bilgisi, kod giriş denemeleri (IP adresi dahil), deneme hakkı geçmişi (e-posta adresinizin geri çevrilemez özeti) |
| **Aile ve çocuk profili** | Aile adı; çocuğun adı ya da takma adı, simgesi, yaş grubu; isteğe bağlı cinsiyet ve doğum günü |
| **Görev ve ödül kayıtları** | Görevler, tekrarlar, hatırlatmalar; çocuğun "Yaptım" ve "Yapamam" işaretleri; onay ya da ret kararınız ve isteğe bağlı notunuz; coin hareketleri; Güneş Taşı hareketleri (taş düşürürken yazdığınız neden dahil); ödülleriniz ve çocuğun ödül istekleri |
| **Mesajlar** | Siz ve çocuğunuz arasındaki yazılar, fotoğraflar, sesli mesajlar, çıkartmalar; okundu bilgisi |
| **Zor an kayıtları** | Öncesi, davranış, sonucu, sizin verdiğiniz şiddet derecesi (1–5) ve isteğe bağlı ses kaydı. Şiddet derecesi sizin gözleminizdir; puan ya da tanı değildir. |
| **Tanışma yanıtları** | İlk kurulumdaki sorular: hedefleriniz, bizi nereden duyduğunuz, görev ve hatırlatma yüzünden tartışma sıklığı, çocuğun günlük düzeni, geçen hafta bazı davranışların sıklığı, çocuğun bir uzmanla çalışıp çalışmadığı, çocuk için hedefleriniz, ilgi alanları, onu motive eden şeyler |
| **Sağlık yanıtları** (özel nitelikli, isteğe bağlı) | Çocuk için konmuş ya da düşündüğünüz tanı; düzenli kullandığı ilaç. Yalnız ayrı açık rızanızla (`saglik-yanit-v1`). |
| **Uzmanla ilgili kayıtlar** | Hangi çocuğu hangi uzmanla paylaştığınız; onaylarınızın metin sürümü ve zamanı; önceki uzman kayıtlarının aktarım izni; uzmanın görev önerilerine verdiğiniz kararlar; takip planında "Bugün uyguladım" kayıtlarınız, bildirdiğiniz zorluk (1–5) ve uygulayamama nedeni. Zorluk bildirimi puan değildir. |
| **Uzmanın davetle getirdiği bilgiler** | Uzman sizi davet ederken e-posta adresinizi ve çocuğunuzun adını ve yaş grubunu girmiş olabilir (bkz. 5.4) |
| **Abonelik** | Plan, dönem sonu, abonelik durumu, mağaza işlem kimliği, deneme başlangıcı. **Kart bilgileriniz bize gelmez; Apple'da kalır.** |
| **Cihaz ve kullanım** | Bildirim jetonu; size giden bildirimler ve okunup okunmadığı; uygulamayı açtığınız günler, oturum sayısı, uygulama sürümü, platform, kullandığınız ekran ve özelliklerin adları. Bu kayıtlarda serbest metin, mesaj ya da sağlık bilgisi yoktur. |
| **Destek ve denetim** | Bize yazdığınız destek e-postaları; yetkili ekip üyelerinin hesabınızda yaptığı işlemlerin gerekçeli kaydı |
| **Onay kayıtları** | Hangi metni (Kullanım Koşulları, aydınlatma, açık rızalar) hangi sürümle ve ne zaman onayladığınız |

Kart bilgisi, T.C. kimlik numarası ya da konum istemeyiz.

### 4. Amaçlar ve hukuki sebepler

Her işlemin dayanağı KVKK'daki şu şartlardır: **md. 5/2-c** sözleşmenin kurulması ve ifası · **md. 5/2-ç** hukuki yükümlülüğümüz · **md. 5/2-e** bir hakkın kurulması, kullanılması ya da korunması · **md. 5/2-f** temel hak ve özgürlüklerinize zarar vermeyen meşru menfaatimiz · **md. 5/1 ve md. 6/2** açık rıza.

| # | Ne için | Hangi veri | Hukuki sebep |
|---|---|---|---|
| 1 | Hesap açmak, giriş, e-posta doğrulama, şifre sıfırlama | Kimlik ve iletişim, hesap güvenliği | md. 5/2-c |
| 2 | Aileyi ve çocuk profillerini kurmak; çocuğu 15 dakikalık tek kullanımlık kod ya da QR ile Pofi Adası'na bağlamak | Aile ve çocuk profili | md. 5/2-c (veli olarak sizinle kurulan sözleşme) * |
| 3 | Görev, onay, coin, Güneş Taşı ve ödülleri çalıştırmak | Görev ve ödül kayıtları | md. 5/2-c |
| 4 | Siz ve çocuğunuz arasında mesajlaşma | Mesajlar | md. 5/2-c |
| 5 | Zor anları kaydetmeniz | Zor an kayıtları | md. 5/2-c; sağlık verisi sayılırsa md. 6/2 açık rıza * |
| 6 | Uygulamayı ailenize göre düzenlemek, destek vermek | Tanışma yanıtları | md. 5/2-c; destek için md. 5/2-f * |
| 7 | Ürünü geliştirmek: yanıtların **kimliksiz toplamları**, "bizi nereden duydunuz" | Tanışma yanıtları (sağlık yanıtları hariç) | md. 5/2-f |
| 8 | Tanı ve ilaç yanıtlarını kaydetmek | Sağlık yanıtları | md. 6/2 açık rıza (`saglik-yanit-v1`) |
| 9 | Çocuğunuzun kayıtlarını seçtiğiniz uzmanla paylaşmak | Uzmanla ilgili kayıtlar + paylaşılan kayıtlar (5.3) | md. 5/1 ve md. 6/2 açık rıza (`uzman-paylasim-v1`) |
| 10 | Önceki uzmanın kayıtlarını yeni uzmana açmak | Önceki uzman kayıtları | md. 6/2 açık rıza (`uzman-gecis-v1`) |
| 11 | Uzman davetini size iletmek ve hesabınızla eşleştirmek | Uzmanın davetle getirdiği bilgiler | md. 5/2-f * |
| 12 | Abonelik ve deneme süresini yönetmek | Abonelik | md. 5/2-c; kayıtların saklanması md. 5/2-ç |
| 13 | Deneme hakkının e-posta başına bir kez kullanılması | E-posta özeti | md. 5/2-f |
| 14 | Bildirim göndermek (cihazınızda izin verdiyseniz) | Bildirim jetonu | md. 5/2-c |
| 15 | Hizmetin işleyişini ölçmek, hataları bulmak, ürünü geliştirmek | Kullanım kayıtları | md. 5/2-f |
| 16 | Güvenlik: kod deneme sınırı, kötüye kullanım incelemesi, denetim kaydı | Hesap güvenliği, destek ve denetim | md. 5/2-ç (KVKK md. 12 güvenlik yükümlülüğü) ve md. 5/2-f |
| 17 | Destek taleplerinizi yanıtlamak | Talebe göre gereken veriler | md. 5/2-c ve md. 5/2-f |
| 18 | Hangi metni onayladığınızı ispat etmek | Onay kayıtları | md. 5/2-ç ve md. 5/2-e |
| 19 | Mahkeme ya da yetkili kurumların usulüne uygun talepleri | Talep kapsamındaki veriler | md. 5/2-a ve md. 5/2-ç |
| 20 | Hukuki uyuşmazlıklarda hakkımızı korumak | Uyuşmazlıkla ilgili veriler | md. 5/2-e |

\* Avukatın teyit edeceği dayanaklar (bkz. Avukata notlar).

Verilerinizi reklam için kullanmayız, satmayız, profil çıkarmak için kullanmayız. Yapay zekâ hizmetlerine göndermeyiz.

### 5. Verileriniz kimlerle paylaşılır

**5.1. Ailenizdeki diğer ebeveyn.** Aileye ikinci bir ebeveyn katılırsa aile verisini (çocuk profilleri, görevler, ödüller, mesajlar, zor an kayıtları, uzman paylaşımları) o da görür ve yönetir.

**5.2. Çocuğunuzun Pofi Adası cihazı.** Bağlı cihaz yalnız o çocuğun profilini, görevlerini, ona yazdığınız mesajları, ona açık ödülleri ve kendi coin ve Güneş Taşı hareketlerini görür. Kardeşler birbirinin mesajlarını görmez.

**5.3. Uzman — yalnız açık rızanızla.** Bir uzmanın davetini onaylar ve çocuğunuzu seçerseniz:
- **Kim görür:** davet eden uzman; o kliniğin sahibi; klinik sahibinin bu paylaşımı atadığı ekip üyeleri.
- **Ne görür:** çocuğun profil bilgileri; görevleri ve atamaları; "Yaptım" kayıtları ve onay/ret kararlarınız; zor an kayıtları ve ses kayıtları; takip planı uygulama kayıtlarınız; görev önerilerine kararlarınız. Bu kayıtların paylaşımdan önceki geçmişi de görünür.
- **Ne görmez:** mesajlarınız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı.
- Uzman bu kayıtları **yalnız okur**, değiştiremez. Size görev önerebilir ve takip planı gönderebilir; kabul edip etmemek size kalmıştır.
- **Durdurma:** Uzmanım bölümünden "Paylaşımı durdur" dediğiniz an uzmanın erişimi biter. Uzmanın o güne kadar ClinicApp'e yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır; bu kayıtları siz görmezsiniz.
- **Önceki uzmanın kayıtları:** Takibi başka bir uzmana taşırsanız ve ayrıca izin verirseniz, önceki uzmanın notları, hedefleri, haftalık değerlendirmeleri, görev önerileri, aile programı ve sizin uygulama kayıtlarınız yeni uzmana **yalnız okunur** olarak açılır. Amaç takibin kesintisiz sürmesidir. Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez. Bu izni Uzmanım bölümünden istediğiniz an geri alırsınız; erişim hemen biter.
- **Uzmanlar doğrulanmaz.** Platform uzmanın kimliğini ve meslek yetkisini doğrulamaz. Bir uzmanın yanında "Belgesi incelendi: <meslek>" yazıyorsa bu, uzmanın yüklediği mezuniyet belgesinin ya da sicil kaydının incelendiği anlamına gelir; kimlik doğrulaması ya da hizmet kalitesi taahhüdü değildir. Paylaşmadan önce uzmanı gerçek hayatta tanıdığınızdan emin olun.

**5.4. Uzmanın davetinde gelen bilgiler.** Uzmanınız sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz kontrol edip onaylayana kadar yalnız davet kaydında tutulur ve size gösterilir; onaylamazsanız ya da davet süresi dolarsa silinir. Onayladığınızda çocuğunuzun kaydı sizin düzelttiğiniz bilgiyle oluşur ve seçtiğiniz uzmanla paylaşılır.
Uzman e-posta adresinizi de girmiş olabilir. Bu adresi yalnız tek bir davet e-postası (en çok 3 kez yeniden gönderim) iletmek ve kayıt olduğunuzda daveti eşleştirmek için kullanırız; pazarlama için kullanmayız. Davet sizin ailenize bağlanmazsa 3 günde, bağlanıp onaylanmazsa en geç 30 günde silinir. "Bu davet bana ait değil" derseniz davet kapanır ve uzmanın girdiği çocuk bilgisi silinir.

**5.5. Hizmet sağlayıcılar (veri işleyenler).** Hizmeti sunmak için aşağıdaki sağlayıcılarla çalışırız. Bu sağlayıcılar verinizi yalnız bizim adımıza ve talimatımızla işler; kendi amaçları için kullanmaz.

| Sağlayıcı | Ne için | Hangi veri | Konum |
|---|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | Bu metindeki bütün veriler | `[SUPABASE BÖLGESİ]` |
| Apple | Bildirim gönderimi (APNs) | Bildirim jetonu, bildirim içeriği | ABD / AB |
| RevenueCat | Abonelik durumunu doğrulama | Rastgele uygulama kullanıcı kimliği, satın alma kayıtları | ABD |
| Resend | İşlem e-postaları (doğrulama, şifre sıfırlama, uzman daveti) | E-posta adresi, e-postanın içeriği | ABD / AB |
| Cloudflare | Yönetim panelinin barındırılması | Yetkili ekip üyesinin ekranında açılan veriler | Küresel |

Abonelik satışını **Apple** yapar. Satın alma sırasında Apple'a verdiğiniz bilgiler (ödeme bilgisi dahil) Apple'ın kendi gizlilik koşullarına tabidir; bunlar bize gelmez. Apple bize yalnız abonelik durumunu ve işlem kimliğini iletir.

**5.6. Yurt dışına aktarım.** Yukarıdaki sağlayıcıların sunucuları Türkiye dışında olabilir. Verilerinizi yurt dışına KVKK md. 9'a uygun olarak aktarırız: Kişisel Verileri Koruma Kurulu'nun ilan ettiği standart sözleşmeyi sağlayıcıyla imzalar, imzadan sonra 5 iş günü içinde Kurul'a bildiririz (ya da varsa yeterlilik kararına dayanırız). Sağlık yanıtları, zor an kayıtları ve uzmanla paylaşılan kayıtlar da bu sunucularda saklanır.

**5.7. Yetkili kurumlar.** Mahkeme, savcılık ya da yetkili bir kamu kurumunun usulüne uygun talebi olursa veriler, talebin kapsamıyla sınırlı olarak aktarılabilir. Kanun yasaklamıyorsa sizi bilgilendiririz.

**5.8. İşletme devri.** Birleşme, devir ya da varlık satışı olursa veriler aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa geçebilir. Sizi önceden bilgilendiririz; hesabınızı silme hakkınız saklıdır.

**5.9. Yetkili ekibimizin erişimi.** Ekibimizin yetkili üyeleri yalnız destek talebinizi yanıtlamak, güvenlik ve kötüye kullanım incelemesi, abonelik sorunları ve kanuni yükümlülükler için hesap bilgilerinize ve kullanım kayıtlarınıza erişebilir. Erişim iki adımlı girişle ve gerekçe yazılarak yapılır; her erişim değiştirilemez bir denetim kaydına geçer. **Mesaj içerikleri, fotoğraflar, ses kayıtları ve uzman notlarının metni ekip ekranlarında gösterilmez.** Tanışma yanıtları ekip ekranında yalnız gerekçe yazılarak açılır; sağlık yanıtları orada da ayrıca gizli gelir.

### 6. Verileri nasıl topluyoruz

Verileri elektronik ortamda, otomatik ya da kısmen otomatik yollarla toplarız:
- ParentApp'e sizin girdiğiniz bilgilerden;
- çocuğunuzun Pofi Adası'nda yaptığı işlemlerden ("Yaptım", mesaj, ödül isteği);
- uzmanın sizi davet ederken girdiği bilgilerden (e-posta adresiniz, çocuğun adı ve yaş grubu);
- Apple ve RevenueCat'in bize ilettiği abonelik durumundan;
- uygulamayı kullanırken cihazınızdan kendiliğinden gelen bilgilerden (sürüm, platform, bildirim jetonu, kod denemelerinde IP adresi).

Hukuki sebepler 4. maddededir.

### 7. Ne kadar süre saklıyoruz

| Veri | Süre |
|---|---|
| Hesap, aile ve çocuk verisi (görevler, mesajlar, ödüller, zor anlar, tanışma yanıtları) | Hesap silinene kadar; silmede derhal |
| Sağlık yanıtları | Rızanızı geri alana ya da yanıtları silene kadar; en geç hesap silinene kadar |
| Uzmanla paylaşım | Paylaşımı durdurana kadar. Uzmanın kendi notları: klinik ya da tek kişilik klinikte uzman hesabı silinene kadar |
| Uzman davetindeki bilgiler (e-posta, çocuk adı) | 3 gün (ailenize bağlanmamış davet) / en geç 30 gün (bağlanmış ama onaylanmamış davet) |
| Kod deneme kayıtları (IP dahil) | 15 dakika – 1 gün |
| Deneme hakkı geçmişi (e-posta özeti) | `[SÜRE]` — hesap silinse de bu süre boyunca kalır |
| Denetim kaydı | `[SÜRE]` — silinen kullanıcının e-postası yazılmaz |
| Abonelik ve ödeme olayları | `[SÜRE]` (vergi ve ticaret mevzuatı) |
| Kullanım kayıtları | `[SÜRE]`, sonra yalnız kimliksiz toplamlar |

Süresi dolan veriyi siler, yok eder ya da anonim hâle getiririz. Bunu en geç altı ayda bir yaptığımız periyodik imha ile de denetleriz.

**Hesabınızı sildiğinizde:** kişisel verileriniz silinir. Ailede başka ebeveyn yoksa aile ve ona bağlı her şey (çocuk profilleri, görevler, mesajlar, coin ve Güneş Taşı hareketleri, oyun yedekleri) de silinir. Ailede başka ebeveyn varsa aile verisi onun hesabında kalır. Kanunen saklamamız gereken kayıtlar (ör. ödeme kayıtları) ve denetim kaydı, sizi doğrudan tanıtan bilgi (e-posta) çıkarılarak yukarıdaki süreler boyunca tutulur. Hesabınızı silmek App Store aboneliğinizi iptal etmez; aboneliği Apple'dan ayrıca kapatmanız gerekir.

### 8. Verilerinizi nasıl koruyoruz

Bütün bağlantılar şifrelidir. Veritabanında herkes yalnız kendi ailesini görür; çocuğun cihazı yalnız kendi profilini görür. Mesaj fotoğrafları, ses kayıtları ve zor an sesleri özel alanlarda tutulur ve yalnız kısa süreli, imzalı bağlantıyla açılır. Yönetim paneline iki adımlı doğrulamayla girilir; her işlem gerekçeli ve silinemez biçimde kaydedilir. Bir veri ihlali olursa Kurul'a ve size kanunda öngörülen sürelerde bildiririz.

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

Birçok işlemi başvuru yapmadan da uygulamada kendiniz yapabilirsiniz: bilgilerinizi düzeltmek, tanışma ve sağlık yanıtlarını değiştirmek ya da silmek, uzman paylaşımını durdurmak, hesabınızı silmek.

### 10. Nasıl başvurursunuz

10.1. Başvuru yolları:
- ParentApp içinden: `[EKRAN YOLU: Ayarlar › Yasal metinler › KVKK başvurusu]`;
- ParentApp'e kayıtlı e-posta adresinizden `kvkk@[ALAN ADI]` adresine;
- yazılı ve imzalı olarak `[ADRES]` adresine;
- kayıtlı elektronik posta (KEP) ya da güvenli elektronik imzayla `[KEP ADRESİ]` adresine.

10.2. Başvurunuzda adınızı, hesabınızdaki e-posta adresini ve ne istediğinizi yazın. Başvurunun size ait olduğunu doğrulamak için ek bilgi isteyebiliriz.

10.3. Başvurunuzu en geç **30 gün** içinde sonuçlandırırız. Yanıt ücretsizdir; işlem ayrıca bir maliyet gerektirirse Kurul'un belirlediği tarifeye göre ücret istenebilir.

10.4. Başvurunuz reddedilirse, yanıtı yetersiz bulursanız ya da süresinde yanıt alamazsanız, yanıtı öğrendiğiniz tarihten başlayarak 30 gün ve her hâlde başvuru tarihinden başlayarak 60 gün içinde Kişisel Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz (KVKK md. 14).

### 11. Bu metin değişirse

Her metnin bir sürümü vardır. Esaslı bir değişiklikte sizi uygulamada bilgilendiririz; açık rızaya dayanan bir işlemin kapsamı değişirse yeniden onayınızı isteriz. Önceki sürümler `[ALAN ADI]` adresinde arşivlenir.

Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('aydinlatma-cocuk', 'v1', 'Pofi Adası Aydınlatma Metni (Veli ve Çocuk)', '{child}', true, $md$# Pofi Adası Aydınlatma Metni (Veli ve Çocuk)

> Taslak, 27 Ekim 2026. Olgular: `hukuk/00-olgular.md` §1–2, §5–7. Ebeveyn tarafı: `10-aydinlatma-ebeveyn.md`. Hukuki görüş değildir.

## Kısaca

- Pofi Adası ücretsizdir. **Reklam yok, uygulama içi satın alma yok, veri satışı yok, üçüncü taraf analiz ya da izleme aracı yok.**
- Çocuğunuzun e-postası ve şifresi yoktur. Profili siz ParentApp'te açarsınız; oyun, sizin gösterdiğiniz 15 dakikalık tek kullanımlık kod ya da QR ile bağlanır.
- Oyun yalnız çalışması için gerekenleri tutar: oyun kaydı, görevler, coin, aile içi mesajlar.
- Çocuğunuz yalnız kendi ailesiyle mesajlaşır. Yabancılarla iletişim yoktur.
- Kamera yalnız QR okumak için açılır. Görüntü kaydedilmez, gönderilmez.
- Çocuğunuzdan konum, fotoğraf, ses ya da iletişim bilgisi almayız.
- Çocuğunuzun haklarını veli olarak siz kullanırsınız: `kvkk@[ALAN ADI]`.

## Kısım A — Velilere tam metin

### 1. Bu metin kimin için

1.1. Bu metin, çocuğunu Pofi Adası (GameApp) oyununa bağlayan veliler içindir. Çocuğunuzun oyunda oluşan verisinin nasıl işlendiğini anlatır. KVKK md. 10 gereği hazırlanmıştır.

1.2. Çocuğunuzun verisi sizin adınıza ve sizin yönetiminizde işlenir. ParentApp'teki veriler için **ParentApp Aydınlatma Metni** (`aydinlatma-ebeveyn`) geçerlidir; bu iki metin birlikte okunur.

1.3. Kısım B'deki kısa notu çocuğunuzla birlikte okumanızı öneririz.

### 2. Veri sorumlusu

`[ŞİRKET UNVANI]`, `[ADRES]`, `[MERSİS/VKN]`. KVKK başvuruları: `kvkk@[ALAN ADI]`. Destek: `destek@[ALAN ADI]`.

### 3. Oyun çocuğunuzu nasıl tanır

3.1. Çocuğunuz oyuna e-posta ya da şifreyle girmez. Oyun cihazda, ad ya da e-posta istemeyen **anonim bir oturum** açar. Bu oturuma rastgele bir kimlik verilir.

3.2. Siz ParentApp'te bir giriş kodu ürettiğinizde (yazı ya da QR olarak), kod 15 dakika geçerlidir ve bir kez kullanılır. Çocuğunuz kodu yazınca ya da QR'ı okutunca bu anonim oturum, sizin açtığınız çocuk profiline bağlanır.

3.3. Oturum anahtarı cihazın güvenli alanında (iOS anahtar zinciri) tutulur. Oyun sonraki açılışlarda sessizce devam eder.

3.4. Giriş kodunu yalnız çocuğunuzun cihazında kullanın. Kodu ya da QR'ı başkasıyla paylaşmayın: kodu kullanan cihaz, çocuğunuzun görevlerini ve sizinle mesajlarını görebilir.

### 4. Hangi verileri işliyoruz

| Kategori | Veriler |
|---|---|
| Sizin ParentApp'te girdiğiniz | Çocuğun adı ya da takma adı, simgesi, yaş grubu (oyun bunları gösterir ve yaşa uygun ayarları seçer) |
| Oturum | Cihazın anonim oturum kimliği |
| Oyun kaydı | Seviye, deneyim puanı (XP), evcil hayvanın durumu, eşyalar, adanın düzeni. Cihazda tutulur; sunucuda yedeği vardır. |
| Coin | Coin bakiyesi ve oyun içi harcamalar |
| Görevler | Sizin verdiğiniz görevler; çocuğun "Yaptım" ve "Yapamam" işaretleri; sizin onayınız, retiniz ve notunuz |
| Mesajlar | Çocuğun size yazdığı yazılar ve seçtiği hazır çıkartmalar; sizin ona gönderdiğiniz yazı, fotoğraf ve sesli mesajlar; okundu bilgisi |
| Ödüller | Çocuğun Güneş Taşı bakiyesi ve sizden istediği ödüller |
| Cihaz ve kullanım | Bildirim jetonu; oyunu açtığı günler, sürüm, platform, kullanılan ekran ve özelliklerin adları (serbest metin ve içerik yok) |
| Güvenlik | Kod giriş denemeleri (IP adresi dahil, kötüye kullanımı önlemek için kısa süre) |

**Almadıklarımız:** Çocuğunuzdan e-posta, telefon, şifre, adres, konum, fotoğraf, ses kaydı ya da kişi listesi almayız. Kamera görüntüsü kaydedilmez. Çocuğunuz oyundan dosya, fotoğraf ya da ses gönderemez.

### 5. Amaçlar ve hukuki sebepler

| Ne için | Hukuki sebep (KVKK) |
|---|---|
| Oyunu çocuğunuzun profiline bağlamak ve oturumu sürdürmek | md. 5/2-c — veli olarak sizinle kurulan sözleşmenin ifası * |
| Görevleri göstermek, "Yaptım"ı size iletmek, onaylanan görev için coin ve Güneş Taşı yazmak | md. 5/2-c * |
| Oyun kaydını yedeklemek (cihaz değişince kaldığı yerden devam) | md. 5/2-c * |
| Aile içi mesajlaşma ve ödül istekleri | md. 5/2-c * |
| Bildirim göndermek (cihazda izin verilmişse) | md. 5/2-c * |
| Oyunun işleyişini ölçmek ve hataları bulmak | md. 5/2-f — meşru menfaat |
| Kod deneme sınırı ve kötüye kullanımı önleme | md. 5/2-ç (KVKK md. 12 güvenlik yükümlülüğü) ve md. 5/2-f |
| Yetkili kurumların usulüne uygun talepleri | md. 5/2-a ve md. 5/2-ç |

\* Avukatın teyit edeceği dayanak (bkz. Avukata notlar).

Çocuğunuzun verisini reklam, pazarlama ya da profil çıkarma için kullanmayız, satmayız.

### 6. Verileri kim görür

- **Siz ve ailenizdeki diğer ebeveyn:** görevleri, "Yaptım"ları, coin ve Güneş Taşı bakiyesini, mesajları, ödül isteklerini görürsünüz.
- **Kardeşler:** birbirinin mesajlarını ve hesabını görmez. Her cihaz yalnız kendi çocuğunun profilini görür.
- **Uzman — yalnız sizin açık rızanızla:** Çocuğunuzu ParentApp'te bir uzmanla paylaşırsanız uzman profil bilgilerini, görevleri ve "Yaptım" kayıtlarını **yalnız okur**. Oyun kaydını, mesajları, coin ve Güneş Taşı hareketlerini göremez. Paylaşımı istediğiniz an durdurursunuz.
- **Hizmet sağlayıcılar:** veriler Supabase sunucularında (`[SUPABASE BÖLGESİ]`) tutulur; bildirimler Apple'ın bildirim hizmetiyle (APNs) gönderilir. Sağlayıcılar veriyi yalnız bizim adımıza işler. Yurt dışına aktarım KVKK md. 9'a uygun güvencelerle yapılır (ayrıntı: ParentApp Aydınlatma Metni 5.5–5.6).
- **Yetkili ekibimiz:** yalnız destek, güvenlik ve kanuni yükümlülük için, iki adımlı girişle, gerekçe yazarak ve kayıt altında erişir. Mesaj içerikleri ekip ekranlarında gösterilmez.
- **Yetkili kurumlar:** yalnız usulüne uygun talep olursa ve talep kapsamıyla sınırlı olarak.

Çocuğunuz oyunda yabancılarla konuşamaz, başka oyuncuları göremez, kimseyle eşleşmez.

### 7. Kamera, izinler ve ebeveyn kapısı

7.1. **Kamera** yalnız giriş ekranında, yalnız QR kodu okumak için açılır. Okuma iOS'un kendi araçlarıyla yapılır; üçüncü taraf kütüphane kullanılmaz. Görüntü kaydedilmez, hiçbir yere gönderilmez. QR yalnız giriş kodunu taşır; çocuğun adı ya da kimliği QR'da yoktur.

7.2. Kamera bir cihazda ilk kez istenmeden önce **ebeveyn kapısı** çıkar. Ebeveyn kapısı, bir yetişkinin çözeceği bir sorudur. Ayarlar, kamera izni, dış bağlantılar ve yasal bilgiler bu kapının arkasındadır. Lütfen soruyu çocuğunuza çözdürmeyin.

7.3. **Bildirim** izni iOS tarafından ayrıca sorulur. İzin vermeseniz de oyun çalışır.

### 8. Reklam, satın alma ve izleme yok

- Oyunda reklam gösterilmez.
- Uygulama içi satın alma yoktur. Coin parayla alınamaz; yalnız sizin onayladığınız görevlerle (ve bir kez hoş geldin hediyesi olarak) kazanılır.
- Üçüncü taraf analiz, reklam ya da izleme aracı yoktur. Kullanım kayıtları yalnız kendi sunucumuzda tutulur.
- Çocuğunuzun verisiyle profil çıkarmayız, veriyi kimseye satmayız.

### 9. Ne kadar süre saklıyoruz

| Veri | Süre |
|---|---|
| Çocuk profili, görevler, mesajlar, coin ve Güneş Taşı hareketleri, sunucudaki oyun yedeği | Ailenin hesabı silinene kadar |
| Cihazdaki oyun kaydı | Oyun cihazdan kaldırılana kadar (bağlantıyı kaldırmak cihazdaki kaydı silmez) |
| Kod deneme kayıtları (IP dahil) | 15 dakika – 1 gün |
| Kullanım kayıtları | `[SÜRE]`, sonra yalnız kimliksiz toplamlar |

**Bağlantıyı kaldırmak:** ParentApp'te çocuğun "Cihaz bağlantısını kaldır" seçeneğiyle oyunun hesaba erişimi biter. Oyun "Bağlantın kapatıldı" der. Cihazdaki oyun kaydı silinmez; silmek için oyunu cihazdan kaldırın.

**Silmek:** ParentApp'te hesabınızı sildiğinizde, ailede başka ebeveyn yoksa çocuğun sunucudaki bütün verisi (profil, görevler, mesajlar, coin, oyun yedeği) de silinir.

### 10. Haklarınız ve başvuru

Çocuğunuz adına KVKK md. 11'deki hakları veli olarak siz kullanırsınız: verinin işlenip işlenmediğini öğrenmek, bilgi istemek, düzeltme, silme, aktarılan kişileri öğrenmek, itiraz ve zararın giderilmesini istemek. Başvuru yolları ve süreler ParentApp Aydınlatma Metni'nin 9. ve 10. maddelerindedir: uygulama içinden, kayıtlı e-postanızdan `kvkk@[ALAN ADI]` adresine ya da yazılı olarak `[ADRES]` adresine. En geç 30 gün içinde ücretsiz yanıt veririz.

Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`

## Kısım B — Çocuğa kısa not (6–12 yaş)

> **Merhaba!**
>
> Pofi Adası'nda oynarken oyun bazı şeyleri hatırlar: seviyeni, eşyalarını ve ailenin verdiği görevleri.
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
values ('aydinlatma-uzman', 'v1', 'ClinicApp Uzman Aydınlatma Metni', '{clinic}', true, $md$# ClinicApp Uzman Aydınlatma Metni

## Kısaca

- **Kim:** ClinicApp'i `[ŞİRKET UNVANI]` işletir. Sizin (uzmanın) hesap verileriniz için veri sorumlusu biziz. Danışanlarınız hakkında girdiğiniz kayıtlarda roller farklıdır; bunlar **Veri İşleme Eki**'nde yazılıdır.
- **Ne topluyoruz:** adınız, unvanınız, e-postanız, klinik adınız ve ekip rolünüz; üyelik bilgisi; isteğe bağlı olarak mesleki belge incelemesi ve karşılama anketi yanıtlarınız; içerik barındırmayan kullanım kayıtları.
- **Neden:** hesabınızı açmak ve hizmeti sunmak, ailelere ve ekibinize kim olduğunuzu göstermek, üyeliğinizi yürütmek, güvenliği sağlamak ve ürünü kimliksiz toplamlarla geliştirmek.
- **Aileler ne görür:** adınız, unvanınız, klinik adınız; belge incelemesi açıksa "Belgesi incelendi: <meslek>" bilgisi. Davet e-postasında gönderen adınız görünür; aile yanıtlarsa yanıt e-posta adresinize gelir.
- **Yapmadıklarımız:** verinizi satmayız; reklam göstermeyiz; üçüncü taraf analiz ya da izleme aracı kullanmayız; verinizi yapay zekâ hizmetine göndermeyiz.
- **Belgeniz:** yalnız inceleme için okunur, karar verilince silinir; T.C. kimlik numaranız saklanmaz.
- **Sunucular:** verileriniz yurt dışındaki sunucularda tutulabilir; aktarım KVKK md. 9'daki usulle yapılır.
- **Haklarınız:** KVKK md. 11'deki haklarınızı uygulama içinden ya da `kvkk@[ALAN ADI]` adresinden kullanabilirsiniz; en geç 30 gün içinde ücretsiz yanıt veririz. Hesabınızı uygulama içinden silebilirsiniz.

---

## 1. Veri sorumlusu ve bu metnin kapsamı

1.1. Kişisel verileriniz, veri sorumlusu sıfatıyla `[ŞİRKET UNVANI]` ("Platform", "biz") tarafından işlenir. Adres: `[ADRES]`. MERSİS/VKN: `[MERSİS/VKN]`. İletişim: `kvkk@[ALAN ADI]` (kişisel veri başvuruları), `destek@[ALAN ADI]` (destek).

1.2. Platform; çocuklar için Pofi Adası (GameApp), ebeveynler için ParentApp ve uzmanlar için ClinicApp uygulamalarını işletir. Bu metin, **ClinicApp hesabı açan uzmanların ve klinik ekip üyelerinin kendi kişisel verilerini** kapsar.

1.3. Bu metnin kapsamı dışında kalanlar:
   - a) **Danışan kayıtları** (danışanlarınız için yazdığınız notlar, hedefler, haftalık değerlendirmeler, görev önerileri, takip planı, danışan etiketleri ve davet formuna girdiğiniz ebeveyn ve çocuk bilgileri): Bu kayıtlarda rollerimiz ve yükümlülüklerimiz **Veri İşleme Eki**'nde (`veri-isleme-eki`) düzenlenir.
   - b) **Aile verisi** (ebeveynin ParentApp'te oluşturduğu görevler, tamamlamalar, zor an kayıtları gibi veriler): Bunlar ebeveyn aydınlatma metnine tabidir; siz bu verileri yalnız ebeveynin açık rızasıyla ve paylaşım sürdükçe görürsünüz.

1.4. Bu metinde "Uzman" ClinicApp hesabı açan gerçek kişiyi, "Klinik" uzmanın kaydıyla oluşan çalışma alanını (bireysel ya da ekipli), "Klinik sahibi" kliniği kuran ya da sahipliği devralan uzmanı, "Ekip üyesi" klinik sahibinin davetiyle kliniğe katılan uzmanı anlatır.

## 2. İşlediğimiz kişisel veriler ve toplama yöntemi

2.1. Aşağıdaki verileri, siz ClinicApp'e (iPad ya da web) girdiğinizde ve uygulamayı kullandıkça otomatik yollarla; üyelik bilgisini ayrıca Apple ve RevenueCat'ten gelen bildirimlerle topluyoruz.

| Kategori | Veriler | Nereden |
|---|---|---|
| Kimlik | Ad soyad, unvan | Kayıt ve profil ekranı |
| İletişim | E-posta adresi | Kayıt ekranı |
| Mesleki bilgi | Klinik adı, çalışma biçimi (bireysel / klinik), ekip rolü (sahip / üye), kliniğe katılma tarihi, sizi ekibe davet eden uzmanın adı, size atanan ya da sorumlusu olduğunuz danışanlar | Kayıt, ekip daveti, klinik sahibinin atamaları |
| Hesap güvenliği | Şifre (yalnız kimlik doğrulama sağlayıcısında, geri çevrilemez biçimde özetlenmiş; biz göremeyiz), oturum bilgileri, kod deneme kayıtları (IP adresi dahil) | Giriş ve kod ekranları |
| Mesleki belge incelemesi (isteğe bağlı) | Seçtiğiniz meslek; e-Devlet barkodlu Yükseköğretim Mezun Belgesi (belgede ad soyad, T.C. kimlik numarası, üniversite, bölüm, derece, mezuniyet tarihi yer alır); BACB sicil numarası; ön kontrol sonucu; inceleme kararı ve ret nedeni | "Belgeni yükle" sayfası |
| Karşılama anketi (isteğe bağlı) | Mesleğiniz, ailelerle çalışırken zorlandığınız alanlar, işinize yarayacak özellikler, ClinicApp'e geliş nedeniniz (yalnız klinik sahibine sorulur) ya da anketi geçtiğiniz bilgisi | İlk girişteki anket ekranı |
| Üyelik | Paket, dönem (aylık / yıllık), dönem sonu, otomatik yenileme durumu, mağaza işlem kimliği, ödeme olayları; RevenueCat'te hesabınıza bağlı rastgele kullanıcı kimliği. **Kart bilginiz bizde değil, Apple'dadır.** | ClinicApp üyelik ekranı, Apple, RevenueCat |
| Bildirim | Cihazınızın bildirim jetonu, size gönderilen bildirimler ve okunma bilgisi | ClinicApp (iPad) |
| Kullanım kayıtları | Uygulamayı açtığınız günler, oturum sayısı, uygulama sürümü, platform, kullandığınız ekran ve özelliklerin olay adları (serbest metin ve içerik yazılmaz) | ClinicApp, otomatik |
| Destek ve denetim | Destek yazışmalarınız; yetkili ekibimizin hesabınızda yaptığı işlemlerin denetim kaydı (kim, ne, ne zaman, hangi gerekçeyle) | Destek kanalları, yönetim paneli |
| Yazar bilgisi | Danışan kayıtlarından hangisini sizin yazdığınız | ClinicApp, otomatik |

2.2. Sizden **özel nitelikli kişisel veri** (ör. kendi sağlık veriniz) istemeyiz. Yüklediğiniz mezun belgesinde özel nitelikli veri bulunmaz; belgede T.C. kimlik numaranız bulunduğu için belge yalnız inceleme amacıyla okunur ve numara saklanmaz (madde 6).

## 3. Amaçlar ve hukuki sebepler (KVKK md. 5)

| Amaç | İşlenen veriler | Hukuki sebep (öneri) |
|---|---|---|
| Hesabınızı açmak, giriş yapmanızı sağlamak, kliniğinizi ve ekibinizi yönetmek | Kimlik, iletişim, mesleki bilgi, hesap güvenliği | Sözleşmenin kurulması ve ifası (md. 5/2-c) |
| Ailelere ve ekip arkadaşlarınıza kim olduğunuzu göstermek (davet önizlemesi, ParentApp'te "Uzmanım", davet açılış sayfası, ekip ekranı) | Ad, unvan, klinik adı, ekip rolü | Sözleşmenin ifası (md. 5/2-c) |
| Aile davetini sizin adınıza e-postayla iletmek | Ad, unvan, klinik adı, e-posta adresiniz (yanıt adresi olarak) | Sözleşmenin ifası (md. 5/2-c) |
| Mesleki belge incelemesi ve ailelere "Belgesi incelendi" bilgisini göstermek (yalnız siz isterseniz) | Belge incelemesi verileri | Sözleşmenin ifası (md. 5/2-c; sizin talebinizle sunulan ek hizmet) ve meşru menfaat (md. 5/2-f; aileleri sahte uzman riskine karşı korumak) — *avukat teyit edecek* |
| Üyeliği yürütmek, ödemeyi doğrulamak, ödeme kayıtlarını tutmak | Üyelik verileri | Sözleşmenin ifası (md. 5/2-c); kanuni yükümlülük (md. 5/2-ç; vergi ve ticaret mevzuatı) |
| Hizmet bildirimleri göndermek (ör. davetin açılması ya da kabulü, ekibe katılım, size danışan atanması, belge incelemesi sonucu) | Kimlik, bildirim | Sözleşmenin ifası (md. 5/2-c) |
| Güvenlik ve kötüye kullanımın önlenmesi (kod deneme sınırı, e-posta gönderim sınırı, hesabın askıya alınması, denetim kaydı) | Hesap güvenliği, kullanım ve denetim kayıtları | Meşru menfaat (md. 5/2-f); veri güvenliği yükümlülüğü (md. 5/2-ç, md. 12) |
| Destek taleplerinizi yanıtlamak | Kimlik, iletişim, destek yazışmaları, ilgili hesap bilgileri | Sözleşmenin ifası (md. 5/2-c); meşru menfaat (md. 5/2-f) |
| Hizmetin işleyişini ölçmek, hataları bulmak, ürünü geliştirmek (kimliksiz toplamlarla) | Kullanım kayıtları, karşılama anketi yanıtları | Meşru menfaat (md. 5/2-f). Anket isteğe bağlıdır; yanıtlar yönetim ekranında yalnız toplam sayı olarak görünür |
| Hukuki uyuşmazlıklarda hakların korunması; yetkili mercilerin usulüne uygun taleplerinin karşılanması | İlgili veriler, taleple sınırlı | Bir hakkın tesisi, kullanılması veya korunması (md. 5/2-e); kanuni yükümlülük (md. 5/2-ç) |

## 4. Verileriniz kimlere, hangi amaçla aktarılır

4.1. **Ailelere görünen bilgiler.** Sizin davet ettiğiniz ya da sizinle paylaşım yapan ebeveynler ParentApp'te şunları görür: adınız, unvanınız, klinik adınız ve — mesleki belge incelemesi özelliği açıksa — "Belgesi incelendi: <meslek>" ya da "Belgesi incelenmedi" bilgisi. Davet e-postasında gönderen adı olarak adınız ve ParentApp adı, metinde unvanınız ve klinik adınız yer alır; aile bu e-postayı yanıtlarsa yanıt sizin e-posta adresinize gider ve aile adresinizi görür. Ebeveyn, kendi ParentApp ekranında daha önce çalıştığı uzmanların adlarını görmeye devam edebilir. Bu aktarımın amacı, ebeveynin çocuğunun verisini kiminle paylaştığını bilerek karar vermesidir (md. 5/2-c, md. 8).

4.2. **Ekibinize görünen bilgiler.** Aynı klinikteki uzmanlar adınızı, unvanınızı ve ekip rolünüzü görür. Klinik sahibi; ekip üyelerinin katılma tarihini, kimin davet ettiğini, ekip üyelerinin gönderdiği aile davetlerini ve bunların durumunu görür. Karşılama anketi yanıtlarınız ekibinize ve ailelere **görünmez**.

4.3. **Sonraki uzmana aktarılmayan bilgiler.** Bir ebeveyn çocuğunun takibini başka bir uzmana taşıdığında ve açıkça izin verdiğinde, sizin yazdığınız danışan kayıtları sonraki uzmana salt okunur olarak açılabilir (Uzman Hizmet Sözleşmesi ve Veri İşleme Eki). Bu durumda **adınız, unvanınız, klinik adınız, iletişim ve kimlik bilgileriniz sonraki uzmana aktarılmaz**; sonraki uzman yalnız "Önceki uzman 1" gibi bir sıra adı ve dönemi (ay olarak) görür. Kayıt metinlerinde geçen klinik ve uzman adları ile e-posta ve telefon bilgileri otomatik olarak gizlenir. Bu gizleme en iyi çabayla yapılır; yazım hatalı ya da kısaltılmış adlar yakalanamayabilir. Bu nedenle serbest metin alanlarına kendinizin ya da başkalarının kimlik bilgisini yazmamanızı rica ederiz.

4.4. **Platformun yetkili ekibi.** Yetkili ekip üyelerimiz; yalnız destek talebinizi yanıtlamak, güvenlik ve kötüye kullanım incelemesi, üyelik ve ödeme sorunları, belge incelemesi ve kanuni yükümlülükler için hesap bilgilerinize, üyelik durumunuza ve kullanım sayılarınıza erişebilir. Erişim iki adımlı doğrulamayla ve rolle sınırlıdır, her değişiklik gerekçe yazılarak yapılır ve silinemez bir denetim kaydına geçer. Danışan notlarınızın metni yönetim ekranlarında **gösterilmez**. Mesleki belgenizi yalnız inceleme yetkisi olan ekip üyeleri, kayda geçen ve iki dakika geçerli bir bağlantıyla görür.

4.5. **Hizmet sağlayıcılar (alt işleyenler).** Hizmeti sunmak için, bizim adımıza ve talimatımızla çalışan aşağıdaki sağlayıcılara gereken ölçüde veri aktarırız. Güncel liste ayrıca yayımlanır (`41-alt-isleyenler.md`, herkese açık "Alt İşleyenler" sayfası).

| Sağlayıcı | Ne için | Hangi verileriniz | Konum |
|---|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | Bu metindeki bütün veriler | `[SUPABASE BÖLGESİ]` |
| Apple | App Store (üyelik satışı; satıcı Apple'dır), bildirim gönderimi (APNs) | Üyelik işlemleri, bildirim jetonu ve bildirim metni | ABD / AB |
| RevenueCat | Üyelik durumunun doğrulanması | Rastgele kullanıcı kimliği, satın alma kayıtları | ABD |
| Resend | İşlem e-postaları (e-posta doğrulama, şifre sıfırlama, sizin adınıza aile daveti) | E-posta adresiniz, adınız, unvanınız, klinik adınız, e-posta içeriği | ABD / AB |
| Cloudflare | Yönetim panelinin barındırılması | Yetkili ekibin ekranına gelen hesap ve üyelik bilgileri | Küresel |
| Google (Gmail SMTP) — yalnız test dönemi | Test e-postaları | E-posta adresi, e-posta içeriği | ABD |

Bu sağlayıcılar verilerinizi yalnız bu hizmetler için işler, kendi amaçlarıyla kullanmaz.

4.6. **Yetkili merciler.** Mahkeme, savcılık ya da yetkili kamu kurumunun usulüne uygun talebi hâlinde verileriniz, talep kapsamıyla sınırlı olarak bu mercilere aktarılabilir; kanunen yasak değilse sizi bilgilendiririz (md. 5/2-ç, md. 8). Gerçeğe aykırı beyan ya da kötüye kullanım hâlinde ilgili kayıtlar yetkili mercilerle paylaşılabilir (Uzman Hizmet Sözleşmesi).

4.7. **İşletme devri.** Platformun birleşmesi, devri ya da varlık satışı hâlinde verileriniz, aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa aktarılabilir; sizi önceden bilgilendiririz ve hesabınızı silme hakkınız saklıdır.

4.8. **Yapmadıklarımız.** Verilerinizi satmayız, kiralamayız; reklam ağlarıyla paylaşmayız; profil çıkarıp pazarlama yapmayız; üçüncü taraf analiz ya da izleme aracı kullanmayız; verilerinizi yapay zekâ hizmetine göndermeyiz (belge ön kontrolü kendi sunucumuzda yapılır).

## 5. Yurt dışına aktarım

5.1. Hizmet sağlayıcılarımızın sunucuları yurt dışında bulunabilir (madde 4.5'teki "Konum" sütunu). Veritabanımızın bulunduğu bölge: `[SUPABASE BÖLGESİ]`.

5.2. Yurt dışına aktarım KVKK md. 9'a uygun yapılır: aktarılan ülke için Kurul'un yeterlilik kararı varsa ona dayanılır; yoksa Kurul'un ilan ettiği **standart sözleşme** imzalanır ve imzadan itibaren **5 iş günü** içinde Kurul'a bildirilir. Yalnız arızi ve md. 9/6'da sayılan istisnai hâllerde başka dayanaklar kullanılabilir.

## 6. Mesleki belge incelemesi hakkında ayrıca

6.1. **Amaç:** Ailelere "Belgesi incelendi: <meslek>" bilgisini göstermek. Bu bilgi kimlik doğrulaması, meslek icra yetkisinin onayı ya da hizmet kalitesi taahhüdü değildir.

6.2. **Nasıl:** Yüklediğiniz belge önce kendi sunucumuzda otomatik bir ön kontrolden geçer (belgenin okunabilirliği, e-Devlet izi, mezuniyet, barkod, adınızın, bölümün ve derecenin beyanınızla uyumu). Yalnız kesin durumlar (okunamayan belge, öğrenci belgesi, başka bir hesapta onaylı ya da askıdaki barkod) kendiliğinden reddedilir; diğer başvuruları yetkili ekip üyemiz inceler, barkodu e-Devlet'in belge doğrulama hizmetinde (BCBA için BACB'nin herkese açık sicilinde) sorgular, gerekirse sizi kısaca arar.

6.3. **Otomatik karara itiraz:** Ön kontrolün kendiliğinden verdiği ret kararına itiraz edebilir (md. 11/1-g), yeni belgeyle yeniden başvurabilir ya da `destek@[ALAN ADI]` üzerinden ekip incelemesi isteyebilirsiniz.

6.4. **Saklama:** Belge dosyası; karar verilince, başvuru kendiliğinden reddedilince, yeni belgeyle değiştirilince ya da hesabınız silinince silinir. Yalnız **özet** (üniversite, bölüm, derece, mezuniyet yılı), **karar kaydı** ve aynı belgenin iki hesapta kullanılmasını önlemek için **belge barkodu** hesabınız süresince saklanır. Adınız ve T.C. kimlik numaranız özette saklanmaz.

6.5. **Rozetin düşmesi:** Profil adınızı değiştirirseniz rozet düşer ve belgeyi yeniden yüklemeniz gerekir; BCBA sertifikası yılda bir yeniden kontrol edilir; şikâyet hâlinde rozet askıya alınabilir.

## 7. Saklama süreleri

| Veri | Süre |
|---|---|
| Hesap, profil, klinik ve ekip bilgileri | Hesabınız silinene kadar; silmede derhal silinir. Ekipte başka uzman varsa klinik kalır, sahiplik en eski üyeye geçer. |
| Karşılama anketi yanıtları | Hesabınız silinene kadar |
| Belge dosyası | Karar, kendiliğinden ret, değiştirme ya da hesap silmede derhal |
| Belge özeti, barkod, karar kaydı | Hesabınız süresince; hesap silinince silinir |
| Kod deneme kayıtları (IP dahil) | 15 dakika – 1 gün |
| Kullanım kayıtları | `[SÜRE]` (öneri: 25 ay; sonra yalnız kimliksiz toplam) |
| Bildirim kayıtları | `[SÜRE]` |
| Denetim kaydı | `[SÜRE]` (öneri: 5 yıl); silinen kullanıcının e-postası kayda yazılmaz |
| Üyelik ve ödeme olayları | `[SÜRE]` (vergi ve ticaret mevzuatındaki süre; öneri: 10 yıl) |

Süresi dolan veriler Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik'e göre, 6 ayı geçmeyen periyodik imha dönemlerinde silinir, yok edilir ya da anonim hâle getirilir. Hesap silindikten sonra yalnız kanunen saklanması gereken kayıtlar ve değiştirilemez denetim kaydı, sizi doğrudan tanımlayan bilgi (e-posta) çıkarılarak saklama süresince tutulur.

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
- ClinicApp içinden: Ayarlar › Yasal metinler › "Kişisel veri başvurusu";
- ClinicApp'te kayıtlı e-posta adresinizden `kvkk@[ALAN ADI]` adresine;
- kayıtlı elektronik posta (KEP), güvenli elektronik imza ya da mobil imzayla;
- yazılı olarak `[ADRES]` adresine.

9.2. Başvurunuzda adınız soyadınız, (yazılı başvuruda) imzanız, tebligata esas adresiniz ya da e-posta adresiniz ve talep konunuz bulunmalıdır. Kimliğinizi doğrulamak için ek bilgi isteyebiliriz.

9.3. Başvurunuzu niteliğine göre en kısa sürede ve **en geç 30 gün** içinde ücretsiz sonuçlandırırız. İşlem ayrıca bir maliyet gerektirirse Kurul'un belirlediği tarifeye göre ücret alınabilir. Başvurunuz reddedilir, yanıtı yetersiz bulursanız ya da süresinde yanıt verilmezse Kişisel Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz (md. 14).

9.4. **Danışan kayıtlarına ilişkin başvurular:** Bir ebeveyn ya da başka bir kişi, sizin girdiğiniz danışan kayıtlarıyla ilgili olarak bize başvurursa başvuruyu Veri İşleme Eki'ndeki usulle size iletiriz.

9.5. **Hesap silme:** Hesabınızı ClinicApp içinden ("Hesabı sil") silebilirsiniz. App Store üyeliğiniz Apple hesabınızdan ayrıca iptal edilmelidir; hesap silmek üyeliği kendiliğinden iptal etmez.

## 10. Değişiklikler

Bu metin değişirse yeni sürümü ClinicApp'te ve herkese açık adreste yayımlarız; esaslı değişiklikleri uygulama içinde ve e-postayla bildiririz. Her sürüm, anahtarı ve sürüm numarasıyla kayıt altındadır.

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('kosullar-parentapp', 'v1', 'ParentApp Kullanım Koşulları', '{parent}', true, $md$# ParentApp Kullanım Koşulları

> Taslak, 27 Ekim 2026. Olgular: `hukuk/00-olgular.md`. Taslak maddeler: `sozlesme/hukuk_notlari.md` D, F, G, I (bu metne "siz" diliyle yerleştirildi). Sürüm adları korunmuştur: `uzman-paylasim-v1`, `uzman-gecis-v1`, `saglik-yanit-v1`. Hukuki görüş değildir.

## Kısaca

- ParentApp, ailelerin görevleri, ödülleri ve aile içi iletişimi düzenlemesine yardım eden bir araçtır. **Sağlık hizmeti değildir, tanı koymaz. Acil durumlarda 112'yi arayın; uygulama acil yardım hizmeti değildir.**
- Eklediğiniz ve paylaştığınız çocukların velisi ya da yasal temsilcisi olduğunuzu beyan edersiniz. Çocuğunuzun hesabından siz sorumlusunuz.
- **Uzmanlar doğrulanmaz.** Çocuğunuzu yalnız gerçek hayatta tanıdığınız bir uzmanla paylaşın. Paylaşımı istediğiniz an durdurursunuz.
- Aile aboneliğini **Apple satar.** Fiyat ve dönem satın alma ekranındadır. Dönem bitmeden en az 24 saat önce kapatmazsanız kendiliğinden yenilenir. İptal ve iade Apple üzerinden yapılır.
- 7 günlük deneme ücretsizdir; ödeme bilgisi istenmez ve kendiliğinden ücretli aboneliğe dönmez. Sonra ücretsiz planda, sınırlı özellikle devam edebilirsiniz.
- **Coin ve Güneş Taşı para değildir.** Ödülleri siz belirler ve siz verirsiniz; biz bu ödüllerin tarafı değiliz.
- Hesabınızı istediğiniz an uygulamanın içinden silebilirsiniz.
- Koşullar değişirse size bildiririz; esaslı değişiklikte yeniden onayınızı isteriz.

## Tam metin

### 1. Taraflar ve kapsam

1.1. Bu koşullar, `[ŞİRKET UNVANI]` ("biz") ile ParentApp'i kullanan ebeveyn ("siz") arasındaki sözleşmedir. Adresimiz `[ADRES]`, MERSİS/VKN `[MERSİS/VKN]`.

1.2. Kişisel verilerinizin nasıl işlendiği **ParentApp Aydınlatma Metni**'nde (`aydinlatma-ebeveyn`) anlatılır. Aydınlatma metni bu sözleşmenin parçası değildir; bilgi verir.

1.3. Açık rıza gerektiren işlemler (sağlık yanıtları `saglik-yanit-v1`, uzmanla paylaşım `uzman-paylasim-v1`, önceki uzman kayıtlarının aktarımı `uzman-gecis-v1`) bu koşulların içinde değildir. Ayrı ekranlarda, ayrı metinlerle sorulur. Reddetmeniz ParentApp'i kullanmanızı engellemez.

1.4. Çocuğunuzun kullandığı Pofi Adası oyunu için ayrıca **Pofi Adası Kullanım Koşulları** (`kosullar-gameapp`) geçerlidir. Onları da veli olarak siz kabul edersiniz.

### 2. Tanımlar

- **ParentApp:** ebeveynler için iOS uygulaması.
- **Pofi Adası (GameApp):** çocuklar için iOS oyunu.
- **ClinicApp:** uzmanların kullandığı uygulama (iPad ve web).
- **Uzman:** ClinicApp'i kullanan psikolog, terapist, özel eğitim uzmanı gibi meslek mensubu. Uzman bizim çalışanımız değildir.
- **Aile:** ParentApp'te sizin, varsa diğer ebeveynin ve çocuk profillerinin bulunduğu ortak alan.
- **Coin:** Pofi Adası'nda oyun içi eşyalar için kullanılan sanal değer.
- **Güneş Taşı:** çocuğunuza vereceğiniz gerçek hayat ödüllerinin sayacı.

### 3. Hizmetin ne olduğu, ne olmadığı

3.1. ParentApp ile görev oluşturur, çocuğunuzun "Yaptım"larını onaylar, ödülleri yönetir, çocuğunuzla mesajlaşır, zor anları kaydeder ve isterseniz bir uzmanla paylaşırsınız.

3.2. **ParentApp sağlık hizmeti sunmaz.** Tanı koymaz, tedavi ya da ebeveyn eğitimi vermez. Uzman istihdam etmez; uzman ile aile arasında aracılık ya da yönlendirme yapmaz. Uzmanların kendi programlarını kurması için şablon sunar.

3.3. Uygulamadaki hiçbir sayı, gösterge, sıklık ya da derece **tanı, zekâ ya da dikkat puanı değildir.** Zor an kaydındaki şiddet derecesi ve takip planındaki zorluk bildirimi sizin gözleminizdir.

3.4. Uygulamadaki öneriler, hazır görevler ve ipuçları genel bilgidir. Bir uzmanın mesleki değerlendirmesinin yerine geçmez.

3.5. **Acil durumlarda 112'yi arayın; uygulama acil yardım hizmeti değildir.** Mesajlar ve kayıtlar bir uzmana anında ulaşmaz.

### 4. Hesap ve güvenlik

4.1. ParentApp'i kullanmak için 18 yaşını doldurmuş olmalısınız.

4.2. Kayıt için e-posta adresi ve şifre gerekir. Bilgilerinizin doğru ve güncel olması sizin sorumluluğunuzdadır. Deneme süresi e-postanızı doğruladığınızda başlar.

4.3. Hesabınız kişiseldir. Şifrenizi kimseyle paylaşmayın. Diğer ebeveyn kendi hesabıyla aileye katılır (7. madde).

4.4. Hesabınızın izinsiz kullanıldığını düşünürseniz şifrenizi değiştirin ve `destek@[ALAN ADI]` adresine yazın.

4.5. Çocuğun giriş kodu ve ikinci ebeveyn davet kodu 15 dakika geçerlidir ve bir kez kullanılır. Uzmanın aile daveti 3 gün geçerlidir. Kötüye kullanımı önlemek için hatalı kod denemeleri sınırlanır.

### 5. Veli beyanı ve çocuk hesabından sorumluluk

5.1. **Veli beyanı.** ParentApp'e eklediğiniz ve paylaştığınız çocukların velisi ya da yasal temsilcisi olduğunuzu, paylaşım kararını verme yetkisine sahip olduğunuzu beyan edersiniz.

5.2. **Çocuğun hesabı.** Çocuğunuzun Pofi Adası profilini siz açar, siz yönetirsiniz. Çocuğun e-postası ya da şifresi yoktur; oyun sizin ürettiğiniz kod ya da QR ile bağlanır. Kodu yalnız çocuğunuzun cihazında kullanın. Çocuğunuzun oyunu ve ParentApp'teki kayıtları nasıl kullandığını gözetmek size aittir.

5.3. **Bağlantıyı kaldırma.** Bir cihazın çocuğunuzun hesabına erişimini ParentApp'ten "Cihaz bağlantısını kaldır" ile istediğiniz an kapatırsınız.

5.4. **Bilgilerin doğruluğu.** Bir uzmanın önerdiği çocuk bilgisini (ad, yaş grubu) kontrol etmek, gerekirse düzeltmek ve onaylamak sizin sorumluluğunuzdadır. Onayladığınız bilgi sizin beyanınız sayılır.

5.5. **Diğer veli.** Ailede birden fazla ebeveyn varsa, paylaşımı yapan ebeveyn diğer velinin bilgisi dahilinde hareket ettiğini kabul eder.

5.6. **Başkalarının verisi.** Görev açıklamalarına, notlara, mesajlara ve zor an kayıtlarına çocuğunuz dışındaki kişilerin (öğretmen, akraba, başka çocuk) kişisel bilgilerini gereğinden fazla yazmayın. Ses kaydı alırken başkalarının sesini onların bilgisi olmadan kaydetmeyin.

### 6. Uzmanla paylaşım

6.1. **Paylaşım sizin kararınızdır.** Çocuğunuzun kayıtları bir uzmanla yalnız siz davet kodunu ya da bağlantısını onaylayıp çocuğu seçtiğinizde ve açık rıza verdiğinizde (`uzman-paylasim-v1`) paylaşılır. Neyin paylaşıldığı ve kimin gördüğü Aydınlatma Metni 5.3'te yazılıdır.

6.2. **Uzmanı tanıma yükümlülüğü.** Platform uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunuzun verisini paylaşmadan önce uzmanı gerçek hayatta tanıdığınızı ve davetin ondan geldiğini kendiniz teyit edersiniz. Paylaşım kararı ve uzman seçimi tamamen sizindir. Emin değilseniz paylaşmayın; uzmanınızı bildiğiniz bir yoldan arayıp sorun.

6.3. **"Belgesi incelendi" ifadesi.** Bazı uzmanların yanında "Belgesi incelendi: <meslek>" yazabilir. Bu, uzmanın isteğiyle yüklediği mezuniyet belgesinin (e-Devlet barkodlu) ya da sicil kaydının incelendiği anlamına gelir. Kimlik doğrulaması, meslek yetkisi onayı ya da hizmet kalitesi taahhüdü değildir.

6.4. **Uzmanın davetindeki çocuk bilgisi.** Uzman sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz kontrol edip onaylayana kadar yalnız davet kaydında tutulur; onaylamazsanız ya da davet süresi dolarsa silinir. Davet size ait değilse "Bu davet bana ait değil" deyin.

6.5. **Kapsam ve geri alma.** Hangi çocuğu hangi uzmanla paylaştığınızı, önceki uzman kayıtlarının aktarımını (`uzman-gecis-v1`) ve bunların ne zaman biteceğini siz yönetirsiniz. Uzmanım bölümünden istediğiniz an durdurursunuz; uzmanın erişimi hemen biter.

6.6. **Uzmanın önerileri.** Uzman size görev önerebilir ve takip planı gönderebilir. Bunları kabul etmek, değiştirmek ya da reddetmek size kalmıştır.

6.7. **Uzmanın hizmeti.** Uzman ile aileniz arasındaki mesleki ilişki, ücret, randevu ve tedavi kararları platformun dışındadır. Biz bu ilişkinin tarafı değiliz ve uzmanın mesleki tutum ve kararlarından sorumlu değiliz.

6.8. **Kötüye kullanım bildirimi.** Tanımadığınız birinden davet alırsanız ya da bir uzmandan şüphelenirseniz paylaşmayın ve `destek@[ALAN ADI]` adresine bildirin. Hesabı inceler, gerekirse kapatırız.

6.9. **Onay kaydı.** Onayınız, onayladığınız metnin sürümü ve zamanıyla kaydedilir.

### 7. İkinci ebeveyn

7.1. Aileye ikinci bir ebeveyni, ParentApp'te ürettiğiniz 15 dakikalık tek kullanımlık davet koduyla davet edebilirsiniz. Davet ettiğiniz kişi kendi hesabını kullanır.

7.2. Aileye katılan ebeveyn aile verisini (çocuk profilleri, görevler, ödüller, mesajlar, zor an kayıtları, uzman paylaşımları) sizinle birlikte görür ve yönetir. Yalnız güvendiğiniz ve çocuğunuz üzerinde velayet ya da bakım sorumluluğu olan kişiyi davet edin.

7.3. Katılan ebeveynin önceki ailesinde başka ebeveyn yoksa, o eski aile **ve bütün verisi silinir.** Uygulama bunu katılmadan önce uyarır.

7.4. Ebeveynlerden biri hesabını silerse aile ve veriler diğer ebeveynin hesabında kalır.

### 8. Abonelik, deneme ve ödeme

8.1. **Planlar.** ParentApp'in ücretsiz planı ve aylık ya da yıllık **Aile aboneliği** vardır. Abonelik aileye bağlıdır; ailedeki ebeveynler ve çocuklar birlikte yararlanır.

8.2. **Deneme.** Kayıt olup e-posta adresinizi doğruladığınızda 7 günlük ücretsiz deneme başlar ve bütün özellikler açılır. Deneme için ödeme bilgisi istenmez; deneme bitince kendiliğinden ücretli aboneliğe dönüşmez. Kalan gün uygulamada görünür. Deneme her e-posta adresi için bir kez verilir.

8.3. **Ücretsiz plan.** Deneme bitince abone olabilir ya da ücretsiz planda devam edebilirsiniz. Ücretsiz planda bazı özellikler sınırlıdır. Bugünkü sınırlar: en çok 1 çocuk ve 3 etkin görev; ödüller, taş düşürme, çocuğa mesaj gönderme ve zor an kaydı kapalı. Görev onayı, Pofi Adası ve uzman paylaşımı açıktır. Var olan kayıtlarınız silinmez; yalnız yeni ekleme sınırlanır. Güncel sınırlar Üyelik ekranında yazılıdır; daraltılırsa önceden duyururuz.

8.4. **Klinik üzerinden tam özellik.** Çocuğunuz, ücretli üyeliği etkin olan bir klinikteki uzmanla paylaşılıyorsa aileniz bu süre boyunca tam özellikleri ücretsiz kullanır. Paylaşım ya da kliniğin üyeliği biterse ve kendi aboneliğiniz yoksa ücretsiz plana dönersiniz. Bu bir kolaylıktır; uzmanla paylaşmanız için bir koşul değildir.

8.5. **Satıcı Apple'dır.** Aile aboneliği App Store'dan satın alınır. Satıcı Apple'dır; ücret Apple hesabınızdan alınır ve Apple'ın satış koşulları da geçerlidir. Kart bilgileriniz bize gelmez. Fiyat (Türk lirası, vergiler dahil) ve dönem, satın almadan önce satın alma ekranında gösterilir.

8.6. **Otomatik yenileme.** Abonelik, dönem bitmeden en az 24 saat önce otomatik yenilemeyi kapatmazsanız aynı süreyle kendiliğinden yenilenir. Yenileme ücreti, dönemin bitmesinden önceki 24 saat içinde Apple hesabınızdan alınır. Fiyat değişirse Apple'ın kurallarına göre önceden bilgilendirilirsiniz; Apple gerektiriyorsa onayınız istenir, onay vermezseniz abonelik dönem sonunda yenilenmez.

8.7. **İptal.** Aboneliğinizi her zaman, ek ücret ödemeden, kurduğunuz yoldan kapatabilirsiniz: iPhone'da **Ayarlar › [adınız] › Abonelikler › ParentApp › Aboneliği İptal Et**, ya da ParentApp'te **Aile › Hesap › Üyelik › Aboneliği yönet**. İptal, ödediğiniz dönemin sonunda geçerli olur; dönem bitene kadar özellikleri kullanırsınız. İptal, aboneliği satın alan ebeveynin Apple hesabından yapılır. **Uygulamayı ya da hesabınızı silmek aboneliği iptal etmez.**

8.8. **Cayma hakkı ve iade.** Abonelik, satın alma onayınızla elektronik ortamda hemen başlayan bir hizmettir. Mesafeli Sözleşmeler Yönetmeliği md. 15/1-ğ uyarınca, elektronik ortamda anında ifa edilen hizmetlerde cayma hakkı kullanılamaz. Satıcı Apple olduğu için iade talepleri Apple'ın iade politikasına göre Apple'a yapılır (Apple'ın "Sorun bildir" sayfası: reportaproblem.apple.com). Biz doğrudan iade yapamayız; başvurunuzda `destek@[ALAN ADI]` üzerinden yardımcı oluruz. Hizmet hiç ya da gereği gibi sunulmazsa kanundan doğan haklarınız saklıdır.

8.9. **Satın alımları geri yükleme.** Telefon değiştirirseniz Üyelik ekranındaki "Satın alımları geri yükle" ile aboneliğiniz hesabınıza yeniden bağlanır.

### 9. Coin, Güneş Taşı ve ödüller

9.1. **Coin para değildir.** Coin yalnız sizin onayladığınız görevlerle (ve çocuk başına bir kez verilen hoş geldin hediyesiyle) kazanılır ve yalnız Pofi Adası'ndaki oyun içi eşyalara harcanır. Satın alınamaz, paraya çevrilemez, başkasına devredilemez. Bir onayı geri alırsanız o görevin coini düşer. Hesap silinince coinler kaybolur.

9.2. **Güneş Taşı para değildir.** Güneş Taşı, onayladığınız görevlerle kazanılır ve çocuğunuza vereceğiniz ödüllerin sayacıdır. Para ya da ödeme aracı değildir; satın alınamaz, paraya çevrilemez.

9.3. **Ödüller sizinle çocuğunuz arasındadır.** Ödülleri, taş karşılıklarını ve değiş tokuş oranlarını (ör. "1 taş = 10 dakika ekran süresi" ya da harçlık) siz belirler ve siz verirsiniz. Platform bu ödüllerin tarafı değildir: para tutmaz, ödeme almaz ya da yapmaz, ödülü sağlamaz ve ödülün verilip verilmemesinden sorumlu değildir.

9.4. **Taş düşürme** sizin kararınızdır; çocuğunuza bildirim gider. Önceden birlikte konuştuğunuz kurallar için ve seyrek kullanmanızı öneririz.

9.5. Teknik bir hata yüzünden yanlış yazılan coin ya da taşı düzeltebiliriz; düzeltmeyi size bildiririz.

### 10. Kabul edilemez kullanım

ParentApp'i şu amaçlarla kullanamazsınız:
- velisi ya da yasal temsilcisi olmadığınız bir çocuğu eklemek ya da paylaşmak;
- başkasının hesabına, ailesine ya da çocuk profiline erişmeye çalışmak; giriş ya da davet kodlarını yabancılarla paylaşmak;
- çocuğa zarar verebilecek, şiddet, taciz, nefret ya da cinsellik içeren, hukuka aykırı içerik göndermek;
- coin, Güneş Taşı, deneme süresi ya da abonelik kurallarını aşmaya çalışmak (ör. sahte hesaplarla yeniden deneme almak);
- uygulamayı tersine mühendislikle çözmek, güvenliğini sınamak ya da otomatik araçlarla erişmek (izinli güvenlik bildirimleri için bize yazın);
- ParentApp'i ticari bir hizmet sunmak için kullanmak (uzmanlar ClinicApp'i kullanır).

Bu kurallara aykırılıkta 14.2. madde uygulanır.

### 11. İçerik ve mesajlar

11.1. **Mesajlaşma aile içidir.** Mesajları yalnız siz, ailedeki diğer ebeveyn ve mesajın gittiği çocuk görür. Uzmanlar ve yabancılar göremez; kardeşler birbirinin sohbetini görmez.

11.2. **İçeriğinizden siz sorumlusunuz.** Gönderdiğiniz yazı, fotoğraf, ses kaydı, görev açıklaması, not ve zor an kaydı çocuğunuza uygun olmalı ve başkalarının haklarını ihlal etmemelidir.

11.3. **İçeriğin sahibi sizsiniz.** Bize yalnız hizmeti sunmak için (saklamak, ailenize ve izin verdiğiniz uzmana göstermek, yedeklemek) sınırlı, ücretsiz ve devredilemez bir kullanım izni verirsiniz. Bu izin hesabınız silinince biter.

11.4. Mesaj içerikleri, fotoğraflar ve ses kayıtları ekip ekranlarımızda gösterilmez. Hukuka aykırı bir içerik bize bildirilirse ya da usulüne uygun kanuni bir talep olursa, yalnız o içerikle sınırlı inceleme yapabilir, içeriği kaldırabilir ya da hesabı askıya alabiliriz.

11.5. Kötüye kullanımı önlemek için mesaj sayısına ve uzunluğuna sınır uygulanır.

### 12. Fikri mülkiyet

ParentApp, Pofi Adası ve ClinicApp'in yazılımı, tasarımı, karakterleri, görselleri, sesleri ve metinleri `[ŞİRKET UNVANI]`'na ya da lisans verenlerine aittir. Size, bu koşullar süresince, uygulamayı kişisel ve ailevi amaçla kullanmanız için kişisel, devredilemez, münhasır olmayan bir kullanım hakkı veririz. Uygulamayı kopyalayamaz, değiştiremez, satamaz ya da kiralayamazsınız. Sizin içeriğiniz size aittir (11.3).

### 13. Hizmet değişikliği ve kesinti

13.1. ParentApp'i geliştirmeye devam ederiz; özellikler eklenebilir, değişebilir ya da kaldırılabilir. Abonelikle sunulan esaslı bir özelliği kaldırırsak bunu önceden bildiririz.

13.2. Bakım çalışmalarını mümkün olduğunca önceden duyururuz. İnternet, cihaz, Apple ya da hizmet sağlayıcı kaynaklı kesintiler olabilir; hizmetin hiç kesilmeyeceğini ya da hatasız olacağını taahhüt edemeyiz.

13.3. Hatırlatmalar ve bildirimler gecikebilir ya da ulaşmayabilir. Önemli işleri yalnız uygulamanın hatırlatmasına bağlamayın.

13.4. Hizmeti tamamen sonlandırırsak bunu en az `[SÜRE]` önce bildiririz. Bu sürede verilerinizle ilgili taleplerinizi karşılarız.

### 14. Hesabın kapatılması ve silinmesi

14.1. **Sizin silmeniz.** Hesabınızı istediğiniz an ParentApp içinden (`[EKRAN YOLU: Aile › Hesap › Hesabımı sil]`) silebilirsiniz. Silme geri alınamaz:
- Ailede başka ebeveyn yoksa aile ve ona bağlı her şey (çocuk profilleri, görevler, mesajlar, coin ve Güneş Taşı hareketleri, oyun yedekleri, uzman paylaşımları) silinir. Çocuğunuzun oyunu bağlantının kapandığını görür.
- Ailede başka ebeveyn varsa aile ve veriler onun hesabında kalır; yalnız sizin hesabınız silinir.
- App Store aboneliğiniz kendiliğinden iptal olmaz; Apple'dan ayrıca kapatın (8.7).
- Kanunen saklamamız gereken kayıtlar Aydınlatma Metni 7. maddedeki sürelerle tutulur.

14.2. **Bizim kapatmamız.** Bu koşulları ağır biçimde ihlal ederseniz (ör. veli olmadığınız bir çocuğu eklemek, çocuğa zarar verecek içerik göndermek, sistemi kötüye kullanmak) önce uyarır ya da hesabı geçici olarak askıya alırız; çocuk güvenliğini tehlikeye atan durumlarda hesabı derhal kapatabiliriz. Nedenini size bildiririz. İtiraz için `destek@[ALAN ADI]` adresine yazabilirsiniz. Haksız bir kapatmaya karşı kanuni haklarınız saklıdır.

### 15. Sorumluluk

15.1. **Platformun rolü.** ParentApp, uzman ile aile arasında bilgi paylaşımını sağlayan bir teknoloji hizmetidir; sağlık hizmeti sunmaz, uzmanları istihdam etmez, aracılık ya da yönlendirme yapmaz.

15.2. **Uzman ve paylaşım kararı.** Uzmanın kimliği, yeterliliği ve davranışından, sizin paylaşım kararınızdan doğan sonuçlardan, kanunun izin verdiği ölçüde sorumlu değiliz.

15.3. **Aile içi kararlar.** Görevler, ödüller, taş düşürme, mesajlar ve çocuğunuzun cihaz kullanımıyla ilgili kararlar sizindir.

15.4. **Bizim sorumluluğumuz.** Hizmeti makul özenle sunarız. Kontrolümüz dışındaki olaylardan (Apple'ın hizmetleri, internet ve cihaz arızaları, doğal afet gibi mücbir sebepler) doğan zararlardan, kanunun izin verdiği ölçüde sorumlu değiliz.

15.5. **Saklı kalan hükümler.** Bu maddedeki hiçbir hüküm:
- kast ya da ağır kusurumuzdan doğan sorumluluğumuzu kaldırmaz (TBK md. 115);
- tüketici olarak kanundan doğan haklarınızı sınırlamaz (6502 sayılı Kanun);
- kişisel verilerin güvenliğini sağlama yükümlülüğümüzü size ya da uzmana devretmez (KVKK md. 12).

15.6. **Sizin sorumluluğunuz.** Gerçeğe aykırı beyanınızdan (ör. veli olmadığınız hâlde çocuk eklemek) ya da başkalarının verisini hukuka aykırı girmenizden doğan, kusurunuza dayanan zararlardan siz sorumlusunuz.

### 16. Verilerin işlenmesi ve aktarımı

Hizmeti sunmak için aşağıdaki işlemleri yaparız. Bunlar bu sözleşmenin uygulanmasının parçasıdır; ayrıntıları ve her birinin hukuki sebebi Aydınlatma Metni'ndedir. **Bu madde açık rıza değildir.** Açık rıza gereken işlemler ayrı ekranlarda sorulur ve reddetmeniz hizmeti engellemez.

16.1. **Hizmet sağlayıcılar.** Verileriniz, hizmet için gereken ölçüde, bizim adımıza ve talimatımızla çalışan sağlayıcılarda işlenir: veritabanı ve barındırma (Supabase), e-posta gönderimi (Resend), bildirim (Apple), abonelik doğrulama (Apple, RevenueCat), yönetim paneli barındırma (Cloudflare). Sağlayıcılar veriyi kendi amaçlarıyla kullanmaz.

16.2. **Yurt dışı.** Bu sağlayıcıların sunucuları yurt dışında olabilir. Aktarımı KVKK md. 9'daki usule (standart sözleşme ve Kurul'a bildirim) uygun yaparız.

16.3. **Yetkili ekip erişimi.** Ekibimizin yetkili üyeleri yalnız destek, güvenlik ve kötüye kullanım incelemesi, abonelik sorunları ve kanuni yükümlülükler için; iki adımlı girişle, gerekçe yazarak ve her erişim değiştirilemez kayda geçerek hesap bilgilerinize ve kullanım kayıtlarınıza erişebilir. Mesaj içerikleri, fotoğraflar, ses kayıtları ve uzman notlarının metni ekip ekranlarında gösterilmez.

16.4. **Tanışma yanıtları.** İlk kurulumda verdiğiniz yanıtlar uygulamayı ailenize göre düzenlemek, destek vermek ve **kimliksiz toplamlar** hâlinde ürünü geliştirmek için kullanılır. Sağlık yanıtları (tanı, ilaç) isteğe bağlıdır ve ayrı açık rızayla (`saglik-yanit-v1`) alınır; toplam raporlarda gösterilmez. Yanıtlarınızı istediğiniz an değiştirebilir ya da silebilirsiniz.

16.5. **Uzmanla paylaşım ve önceki uzman kayıtları.** Bunlar ayrı onay ekranlarıyla (`uzman-paylasim-v1`, `uzman-gecis-v1`) verilir; bu madde onların yerine geçmez.

16.6. **Kullanım verisi.** Uygulamayı açtığınız günler, sürüm, platform ve kullandığınız ekran ve özelliklerin adları; hizmetin işleyişini ölçmek, hataları bulmak ve ürünü geliştirmek için işlenir. Bu kayıtlarda serbest metin, mesaj ya da sağlık bilgisi yoktur; üçüncü taraf reklam ya da izleme aracı kullanılmaz.

16.7. **Kanuni zorunluluk.** Mahkeme, savcılık ya da yetkili kamu kurumunun usulüne uygun talebi olursa veriler, talep kapsamıyla sınırlı olarak aktarılabilir. Kanun yasaklamıyorsa sizi bilgilendiririz.

16.8. **İşletme devri.** Birleşme, devir ya da varlık satışı olursa veriler aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa aktarılabilir. Sizi önceden bilgilendiririz; hesabınızı silme hakkınız saklıdır.

16.9. **Hesap silindikten sonra.** Kişisel verileriniz silinir. Yalnız kanunen saklanması gereken kayıtlar (ör. ödeme kayıtları) ve değiştirilemez denetim kaydı, sizi doğrudan tanıtan bilgi (e-posta) çıkarılarak saklama süresince tutulur.

### 17. Onay kaydı, koşulların değişmesi ve yeniden onay

17.1. Bu koşulları kayıt ekranında, önceden işaretlenmemiş kutuyu işaretleyerek kabul edersiniz. Hangi metni (Kullanım Koşulları, aydınlatma okundu bilgisi, açık rızalar) hangi sürümle ve ne zaman onayladığınız kaydedilir.

17.2. Koşulları değiştirmemiz gerekirse:
- **Esaslı değişiklikleri** (haklarınızı, ücretleri ya da verilerinizin kullanımını etkileyenler) yürürlükten en az `[SÜRE]` önce uygulamada bildiririz ve uygulama açılışında yeni sürümü onaylamanızı isteriz. Onaylamazsanız hesabınızı silebilir ve aboneliğinizi dönem sonunda bitirebilirsiniz.
- **Küçük değişiklikleri** (yazım düzeltmesi, iletişim bilgisi, lehinize değişiklik) bildirimle yaparız.
- Aleyhinize bir değişikliği onayınız olmadan uygulamayız.

17.3. Her metnin sürüm adı vardır (`kosullar-parentapp` v1, v2 …). Önceki sürümler `[ALAN ADI]` adresinde arşivlenir.

### 18. Uyuşmazlık

18.1. Bu sözleşmeye Türk hukuku uygulanır. Bir sorununuz olursa önce `destek@[ALAN ADI]` adresine yazmanızı rica ederiz; bu zorunlu değildir.

18.2. Uyuşmazlıklarda, her yıl Ticaret Bakanlığının ilan ettiği parasal sınırın altında kalan konularda **Tüketici Hakem Heyetine**, sınırın üstündekilerde **Tüketici Mahkemesine** başvurabilirsiniz. Tüketici Mahkemesinde dava açmadan önce arabulucuya başvurmak kanunen gerekebilir.

18.3. Başvuruyu kendi yerleşim yerinizdeki ya da işlemin yapıldığı yerdeki Tüketici Hakem Heyetine ya da Tüketici Mahkemesine yapabilirsiniz.

18.4. App Store üzerinden yapılan ödeme ve iade konularında Apple'ın kendi koşulları ve başvuru yolları da geçerlidir.

### 19. İletişim

`[ŞİRKET UNVANI]`, `[ADRES]`. Destek: `destek@[ALAN ADI]`. Kişisel veriler: `kvkk@[ALAN ADI]`.

### 20. Son hükümler

20.1. Bu koşulların dili Türkçedir.

20.2. Bir hüküm geçersiz sayılırsa diğer hükümler geçerliliğini korur.

20.3. Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`.
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('kosullar-gameapp', 'v1', 'Pofi Adası Kullanım Koşulları', '{child}', true, $md$# Pofi Adası Kullanım Koşulları

> Taslak, 27 Ekim 2026. Olgular: `hukuk/00-olgular.md` §1, §2, §4. Ana sözleşme: `20-kullanim-kosullari-parentapp.md`. Hukuki görüş değildir.

## Kısaca

- Bu koşulları **çocuğunuz değil, veli olarak siz** kabul edersiniz.
- Pofi Adası ücretsizdir. **Reklam yok, uygulama içi satın alma yok, üçüncü taraf izleme yok.**
- Çocuğunuz oyuna sizin ParentApp'te gösterdiğiniz 15 dakikalık tek kullanımlık kod ya da QR ile bağlanır.
- **Coin para değildir:** yalnız sizin onayladığınız görevlerle kazanılır, yalnız oyun içi eşyalara harcanır.
- Ayarlar, kamera izni ve dış bağlantılar **ebeveyn kapısının** arkasındadır. Soruyu çocuğunuza çözdürmeyin.
- Çocuğunuz **yalnız kendi ailesiyle** mesajlaşır.
- Bağlantıyı ParentApp'ten istediğiniz an kaldırabilir, hesabınızı silerek çocuğun verisini de silebilirsiniz.

## Tam metin

### 1. Kapsam ve kabul

1.1. Bu koşullar, `[ŞİRKET UNVANI]` ("biz") ile çocuğunu Pofi Adası (GameApp) oyununa bağlayan veli ("siz") arasındadır.

1.2. Bu koşulları **çocuğunuz kabul etmez.** Çocuğunuzu oyuna ilk kez bağlamadan önce ParentApp'te siz, veli ya da yasal temsilci olarak kabul edersiniz. Onayınız metnin sürümü ve zamanıyla kaydedilir.

1.3. Burada yazmayan her konuda **ParentApp Kullanım Koşulları** (`kosullar-parentapp`) geçerlidir: sorumluluk, hizmet değişikliği, koşulların değişmesi ve yeniden onay, uyuşmazlık ve iletişim maddeleri dahil. Çocuğunuzun verisinin nasıl işlendiği **Pofi Adası Aydınlatma Metni**'ndedir (`aydinlatma-cocuk`).

### 2. Oyun

2.1. Pofi Adası, çocuğunuzun bir evcil hayvana baktığı, adayı geliştirdiği ve ailesinin verdiği görevleri takip ettiği bir oyundur. Ücretsizdir.

2.2. Oyunda **reklam yoktur, uygulama içi satın alma yoktur,** üçüncü taraf analiz ya da izleme aracı yoktur.

2.3. Oyundaki seviye, deneyim puanı (XP), yıldızlar ve evcil hayvanın göstergeleri **yalnız oyun içindir.** Çocuğunuz hakkında bir değerlendirme, tanı ya da puan değildir. Evcil hayvan hastalanmaz ve ölmez.

### 3. Oyuna bağlanma ve kullanım

3.1. Çocuğunuzun e-postası ya da şifresi yoktur. Oyun, ParentApp'te ürettiğiniz 15 dakikalık tek kullanımlık kod ya da QR ile çocuğunuzun profiline bağlanır.

3.2. Kodu yalnız çocuğunuzun cihazında kullanın; başkasıyla paylaşmayın. Kodu kullanan cihaz çocuğunuzun görevlerini ve sizinle mesajlarını görebilir.

3.3. Cihaz değişirse yeni bir kodla bağlanırsınız; oyun sunucudaki yedekten kaldığı yerden devam eder.

3.4. Çocuğunuzun oyunu ne zaman ve ne kadar oynadığını gözetmek size aittir.

### 4. Coin ve Güneş Taşı

4.1. **Coin para değildir.** Coin yalnız sizin ParentApp'te onayladığınız görevlerle (ve çocuk başına bir kez verilen hoş geldin hediyesiyle) kazanılır. Yalnız oyun içi eşyalara harcanır. Oyunun içindeki hiçbir etkinlik coin vermez.

4.2. Coin satın alınamaz, paraya çevrilemez, başka bir çocuğa ya da hesaba devredilemez. Bir onayı geri alırsanız o görevin coini düşer. Hesap silinince coinler ve oyun içi eşyalar kaybolur.

4.3. Bakiye her zaman sunucudaki bakiyedir. Bağlantı yokken yapılan bir harcama sunucuda kabul edilmezse eşya geri alınır.

4.4. **Güneş Taşı** da para değildir. Onayladığınız görevlerle kazanılır; çocuğunuz taşları adaya yerleştirebilir ve sizden ödül isteyebilir. Ödülleri ve karşılıklarını siz belirler, isteği siz onaylar ya da reddedersiniz. Ödüller sizinle çocuğunuz arasındadır; biz tarafı değiliz (ParentApp Kullanım Koşulları 9. madde).

### 5. Ebeveyn kapısı

5.1. Ayarlar, kamera izni, dış bağlantılar ve yasal bilgiler **ebeveyn kapısının** arkasındadır. Ebeveyn kapısı, bir yetişkinin çözeceği bir sorudur.

5.2. Lütfen soruyu çocuğunuza çözdürmeyin ve cevabını söylemeyin. Kapının arkasında yaptığınız ayarlardan siz sorumlusunuz.

5.3. Kamera yalnız giriş ekranında, yalnız QR okumak için açılır. Görüntü kaydedilmez ve gönderilmez.

### 6. Mesajlaşma yalnız ailedir

6.1. Çocuğunuz oyunda **yalnız kendi ailesindeki ebeveynlerle** mesajlaşır. Yabancılar, başka oyuncular ve uzmanlar çocuğunuza yazamaz, mesajları göremez. Kardeşler birbirinin sohbetini görmez.

6.2. Çocuğunuz yazı ve hazır çıkartma gönderebilir; dosya, fotoğraf ya da ses gönderemez. Kötüye kullanımı önlemek için mesaj sayısına sınır vardır.

6.3. Çocuğunuza gönderdiğiniz içerikten siz sorumlusunuz (ParentApp Kullanım Koşulları 11. madde).

### 7. Bağlantıyı kaldırma

7.1. ParentApp'te çocuğun "Cihaz bağlantısını kaldır" seçeneğiyle bir cihazın erişimini istediğiniz an kapatırsınız. Oyun "Bağlantın kapatıldı" der ve hesaba erişemez.

7.2. Cihazdaki oyun kaydı bu işlemle silinmez. Yeniden bağlanmak için yeni bir kod üretirsiniz.

### 8. Hesabın ve oyun kaydının silinmesi

8.1. ParentApp'te hesabınızı sildiğinizde, ailede başka ebeveyn yoksa çocuğunuzun sunucudaki bütün verisi (profil, görevler, mesajlar, coin ve Güneş Taşı hareketleri, oyun yedeği) silinir. Ailede başka ebeveyn varsa veriler onun hesabında kalır.

8.2. Cihazdaki oyun kaydını silmek için oyunu cihazdan kaldırın.

8.3. Silme geri alınamaz.

### 9. Kabul edilemez kullanım

Oyunu ya da çocuğunuzun hesabını şu amaçlarla kullanamazsınız ve kullandıramazsınız: başka bir çocuğun koduyla bağlanmak; coin, taş ya da görev kurallarını aşmaya çalışmak; oyunu tersine mühendislikle çözmek, değiştirmek ya da otomatik araçlarla kullanmak. Bu durumda ParentApp Kullanım Koşulları 14.2. madde uygulanır.

### 10. Fikri mülkiyet

Pofi Adası'nın yazılımı, karakterleri, görselleri, müziği, sesleri ve metinleri `[ŞİRKET UNVANI]`'na ya da lisans verenlerine aittir. Size, bu koşullar süresince, oyunu çocuğunuzla kişisel ve ailevi amaçla kullanmanız için kişisel, devredilemez, münhasır olmayan bir kullanım hakkı veririz.

### 11. İletişim

`[ŞİRKET UNVANI]`, `[ADRES]`. Destek: `destek@[ALAN ADI]`. Kişisel veriler: `kvkk@[ALAN ADI]`.

Yürürlük tarihi: `[YÜRÜRLÜK TARİHİ]`.
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('sozlesme-uzman', 'v1', 'ClinicApp Uzman Hizmet Sözleşmesi', '{clinic}', true, $md$# ClinicApp Uzman Hizmet Sözleşmesi

## Kısaca

- **ClinicApp bir araçtır:** Ebeveynin izniyle paylaştığı çocuğun ev rutinini izlemenize, not, hedef, görev önerisi ve takip planı hazırlamanıza yarar. Platform sağlık hizmeti vermez, tanı koymaz, uzman istihdam etmez, aile ile uzman arasında aracılık ya da yönlendirme yapmaz.
- **Acil durum hizmeti değildir:** Risk gördüğünüzde 112'yi aramak ve danışanı uygun yere yönlendirmek sizin mesleki sorumluluğunuzdadır.
- **Mesleki sorumluluk sizdedir:** unvanınızın ve yetkinizin doğruluğu, meslek etiği, danışanın (velinin) bilgilendirilmesi ve onayı, meslek sırrı ve kayıt saklama yükümlülüğü.
- **Davet:** yalnız tanıdığınız ve hizmet verdiğiniz ailelere; çocuk için yalnız ad ya da takma ad ve yaş grubu; sağlık bilgisi yazılmaz. Paylaşım yalnız ebeveynin onayıyla açılır, ebeveyn istediği an durdurur.
- **Kayıtlarınız:** Ebeveyn izin verirse sonraki uzmana adınız gizlenerek salt okunur açılabilir; buna şimdiden izin veriyorsunuz.
- **Üyelik:** App Store üzerinden (satıcı Apple), klinik sahibi birey olarak öder; 7 gün ücretsiz deneme; iptal Apple hesap ayarlarından. Üyelik bitince erişim kapanır, veriler hemen silinmez.
- **Sorumluluk:** Platformun sorumluluğu kanunun izin verdiği ölçüde sınırlıdır; kast ve ağır kusur, veri güvenliği yükümlülüğü ve kanunen sınırlanamayan hâller hariç.
- **Ekler:** Veri İşleme Eki bu sözleşmenin parçasıdır; kişisel verileriniz için Uzman Aydınlatma Metni'ni okuyun.

---

## 1. Taraflar, kabul ve sözleşmenin parçaları

1.1. Bu sözleşme, `[ADRES]` adresinde bulunan `[ŞİRKET UNVANI]` ("Platform") ile ClinicApp'te hesap açan ya da bir kliniğe ekip üyesi olarak katılan uzman ("Uzman") arasında kurulur.

1.2. Uzman, kayıt ekranındaki (ekip üyesi için ekip koduyla katılım ekranındaki) onay kutusunu işaretleyerek bu sözleşmeyi okuduğunu ve kabul ettiğini beyan eder. Platform, onaylanan metnin anahtarını, sürümünü ve onay zamanını kaydeder. Sözleşme metni onaydan önce ve her zaman ClinicApp'te (Ayarlar › Yasal metinler) ve herkese açık adreste okunabilir.

1.3. Aşağıdakiler bu sözleşmenin ayrılmaz parçasıdır: **Ek-1 Veri İşleme Eki** (`veri-isleme-eki`), **Ek-2 Alt işleyenler listesi** (`41-alt-isleyenler.md`; herkese açık "Alt İşleyenler" sayfası), **Ek-3 ClinicApp'teki kısa bilgilendirme metinleri** (bu belgenin sonunda). **Uzman Aydınlatma Metni** (`aydinlatma-uzman`) sözleşme değil, KVKK md. 10 uyarınca yapılan bilgilendirmedir.

1.4. Uzman, ClinicApp'i mesleki faaliyeti kapsamında kullandığını kabul eder.

## 2. Tanımlar

| Terim | Anlamı |
|---|---|
| ClinicApp | Platformun uzmanlar için sunduğu iPad uygulaması ve web sürümü |
| ParentApp | Platformun ebeveynler için sunduğu uygulama |
| Pofi Adası (GameApp) | Platformun çocuklar için sunduğu oyun |
| Klinik | Uzmanın kaydıyla ClinicApp'te oluşan çalışma alanı (bireysel ya da ekipli) |
| Klinik sahibi | Kliniği kuran ya da sahipliği devralan uzman |
| Ekip üyesi | Klinik sahibinin ekip davetiyle kliniğe katılan uzman |
| Koltuk | Bir klinikte aynı anda hesap açabilecek uzman sayısı |
| Ebeveyn | Çocuğun velisi ya da yasal temsilcisi olduğunu beyan eden ParentApp kullanıcısı |
| Danışan | Ebeveynin, açık rızasıyla uzmanla paylaştığı çocuk |
| Paylaşım | Ebeveynin bir çocuğu bir klinikle paylaşması; etkin olduğu sürece uzman o çocuğun aile verisini salt okur |
| Aile verisi | Ebeveynin ve çocuğun ParentApp ve Pofi Adası'nda oluşturduğu veriler (görevler, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, zor an kayıtları ve ses kayıtları gibi) |
| Danışan kayıtları | Uzmanın ClinicApp'e girdiği notlar, hedefler, haftalık değerlendirmeler, görev önerileri, takip planı (aile programı), danışan etiketleri ve davet bilgileri |
| Takip planı | Uzmanın danışan için kurduğu hedefler ve aile programı modülleri |
| Şablonlar | Platformun sunduğu görev şablonları, hazır rutinler, takip planı şablonları (alanlar, hedefler, modüller, paketler) ve rapor biçimleri |
| Belge incelemesi | Uzmanın isteğiyle mesleki belgesinin Platform tarafından incelenmesi |
| Rozet | Belge incelemesi olumlu sonuçlanınca ailelere gösterilen "Belgesi incelendi: <meslek>" bilgisi |

## 3. Hizmetin tanımı ve niteliği

3.1. **Ne sunuyoruz.** ClinicApp, uzmanın:
   - a) aileyi davet etmesine ve ebeveynin onayıyla paylaşılan çocuğun aile verisini salt okumasına,
   - b) danışan için not tutmasına, hedef tanımlamasına ve haftalık değerlendirme yapmasına,
   - c) aileye görev önerisi ve takip planı göndermesine,
   - ç) yazdırılabilir rapor almasına,
   - d) klinik ekibini ve danışan atamalarını yönetmesine
   yarayan bir yazılım aracıdır.

3.2. **Sağlık hizmeti değildir.** Platform sağlık hizmeti sunmaz; tanı koymaz, tedavi ya da ebeveyn eğitimi vermez, uzman istihdam etmez. Platform uzman ile aile arasında aracılık, eşleştirme ya da yönlendirme yapmaz; uzman rehberi ya da listesi yayımlamaz. Uzman ile aile arasındaki mesleki ilişki, ücret, randevu ve tedavi kararları Platformun dışındadır; Platform bu ilişkinin tarafı değildir.

3.3. **Göstergeler tanı değildir.** ClinicApp'teki oranlar, grafikler, hedef değerlendirmeleri ve raporlar ev rutinine ilişkin gözlem özetleridir; hiçbiri tanı, zekâ ya da dikkat puanı değildir ve mesleki değerlendirmenin yerini tutmaz. Şablonlar uzmanın kendi programını hızlı kurması için sunulan iskeletlerdir; bir şablonun danışana uygun olup olmadığına uzman karar verir.

3.4. **Acil durum hizmeti değildir.** ClinicApp'teki kayıtlar Platform tarafından anlık izlenmez. Uzman; danışanın ya da başkasının hayatı, sağlığı veya güvenliği için risk gördüğünde 112'yi aramaktan, danışanı uygun sağlık kuruluşuna yönlendirmekten ve mevzuattan doğan bildirim yükümlülüklerini yerine getirmekten kendisi sorumludur.

3.5. **Uzaktan sağlık hizmeti aracı değildir.** ClinicApp'te uzman ile aile arasında görüntülü ya da sesli görüşme ve serbest mesajlaşma özelliği yoktur; uzman aileye yalnız görev önerisi (kısa not dahil) ve takip planı gönderebilir.

3.6. **Hizmetin işleyişi.** Platform hizmeti makul özenle ve kesintisiz sunmaya çalışır; ancak bakım, güncelleme, hizmet sağlayıcı kesintisi ya da mücbir sebep nedeniyle hizmet geçici olarak durabilir. Platform özellik ekleyebilir, değiştirebilir ya da kaldırabilir; uzmanın ödediği hizmetin esaslı bir bölümünü kaldıracaksa bunu en az `[SÜRE]` (öneri: 30 gün) önce bildirir.

## 4. Hesap, klinik ve ekip

4.1. **Hesap.** Uzman kayıtta doğru ad, unvan ve e-posta bilgisi verir ve bunları güncel tutar. Her uzman kendi hesabını kullanır; hesap paylaşılamaz. Şifrenin ve hesaba erişilen cihazların güvenliği uzmandadır; uzman, hesabının yetkisiz kullanıldığını fark ederse derhal `destek@[ALAN ADI]` adresine bildirir.

4.2. **Klinik.** Kayıtla birlikte uzman adına bir klinik oluşur ve uzman o kliniğin sahibi olur. Bireysel çalışan uzmanda klinik adı uzmanın adıdır.

4.3. **Ekip.** Klinik sahibi, paketinin izin verdiği koltuk sayısı kadar uzmanı ekip davetiyle kliniğe katabilir (bugün Bireysel pakette 1, Klinik paketinde ekip dahil en çok 10 uzman; güncel sayılar Üyelik ekranında). Klinik sahibi kliniğin bütün paylaşımlarını görür; ekip üyesi yalnız sorumlusu olduğu ya da klinik sahibinin kendisine atadığı danışanları görür. Danışanın sorumlu uzmanını ve ekip erişimini yalnız klinik sahibi değiştirir; ekip üyesi yalnız kendi sorumluluğunu bırakabilir.

4.4. **Klinik sahibinin sorumluluğu.** Klinik sahibi;
   - a) ekibe yalnız kliniğinde mesleki hizmet veren ve meslek icra yetkisi bulunan kişileri almayı,
   - b) danışanlara erişimi yalnız o danışanla çalışması gereken ekip üyelerine açmayı,
   - c) ekip üyelerinin meslek sırrına ve bu sözleşmeye uymasını sağlamayı,
   - ç) kliniğinden ayrılan bir ekip üyesinin danışan erişimini derhal kapatmayı ya da kapatılması için Platforma başvurmayı
   üstlenir. Klinik sahibi, ekip üyelerinin bu sözleşmeye aykırı davranışlarından doğan zararlardan, borcun ifasında yardımcı kişi kullananın sorumluluğuna ilişkin genel hükümler (TBK md. 116) çerçevesinde Platforma karşı sorumludur. Her ekip üyesi ayrıca kendi eylemlerinden bizzat sorumludur.

4.5. **Hesabın silinmesi ve ekip.** Uzman hesabını sildiğinde: tek kişilik klinik bütün danışan kayıtları, paylaşımları, davetleri ve üyelik kayıtlarıyla birlikte silinir; ekipte başka uzman varsa klinik ve kayıtları kalır, hesabını silen klinik sahibiyse sahiplik kliniğin en eski üyesine geçer, ekip üyesiyse sorumlusu olduğu danışanlar klinik sahibine kalır. App Store üyeliği Apple hesabından ayrıca iptal edilir.

## 5. Uzmanın beyan ve taahhütleri

5.1. Uzman;
   - a) kimliğinin, mesleki unvanının ve meslek icra yetkisinin doğru olduğunu, unvan alanına sahip olmadığı bir unvanı ya da uzmanlığı yazmayacağını,
   - b) mesleğini yürürlükteki mevzuata ve bağlı olduğu meslek kuruluşunun kurallarına uygun icra ettiğini,
   - c) ClinicApp'te yalnız tanıdığı ve hizmet verdiği ailelere davet gönderdiğini, davet bağlantısını ya da kodunu yalnız ilgili ebeveyne ilettiğini,
   - ç) ClinicApp'i yalnız danışanına verdiği mesleki hizmet kapsamında ve danışanın yararına kullanacağını
   beyan ve taahhüt eder.

5.2. Gerçeğe aykırı beyan ya da kötüye kullanım hâlinde Platform hesabı derhal askıya alabilir ya da kapatabilir, rozeti kaldırabilir, ilgili kayıtları yetkili mercilerle paylaşabilir; Uzman bundan doğan zararı tazmin eder (madde 15.5).

## 6. Mesleki sorumluluk ve etik

6.1. **Mesleki kararlar uzmanındır.** Danışan kayıtlarının, görev önerilerinin ve takip planının içeriği uzmanın mesleki kararıdır. Platform bu içerikleri denetlemez, onaylamaz ve bunlardan sorumlu değildir.

6.2. **Meslek etiği ve onam.** Uzman, bağlı olduğu meslek kuruluşunun etik kurallarına (ör. Türk Psikologlar Derneği Etik Yönetmeliği) uyar. Danışanın velisini ClinicApp'i kullanacağı konusunda bilgilendirmek ve meslek kurallarının gerektirdiği onamı almak uzmanın yükümlülüğüdür. Ebeveynin ParentApp'te verdiği paylaşım onayı (`uzman-paylasim-v1`) ve önceki uzman kayıtlarına ilişkin açık rızası (`uzman-gecis-v1`), Platformun sistemindeki paylaşımın dayanağıdır; uzmanın meslek kurallarından doğan bilgilendirme ve onam yükümlülüğünün yerine geçmez.

6.3. **Meslek sırrı ve gizlilik.** Uzman, ClinicApp'te öğrendiği bilgiler bakımından meslek sırrı yükümlülüğü altındadır. Yazdırdığı raporları, ekran görüntülerini ve ClinicApp'e eriştiği cihazları korur; ortak kullanılan bilgisayarda oturumunu kapatır; danışan bilgisini yalnız mesleki gereklilik ölçüsünde paylaşır.

6.4. **Kayıt saklama yükümlülüğü uzmanındır.** ClinicApp bir elektronik sağlık kaydı ya da arşiv sistemi değildir. Ebeveyn paylaşımı durdurduğunda uzmanın o çocuğun aile verisine erişimi hemen biter; ebeveyn hesabını ya da çocuğun profilini sildiğinde o çocuğa bağlı paylaşım ve danışan kayıtları da silinir; üyelik bittiğinde erişim kapanır (madde 10.7). Uzman, mevzuat ya da meslek kuralları gereği saklaması gereken kayıtları ClinicApp'ten bağımsız olarak kendisi saklar.

6.5. **Veri en aza indirme.** Uzman, serbest metin alanlarına (not, etiket, hedef açıklaması, ebeveyne not) yalnız mesleki olarak gerekli bilgiyi yazar; kendisinin, ailenin ya da üçüncü kişilerin kimlik ve iletişim bilgilerini, gereği yoksa tanı ve ilaç gibi sağlık bilgilerini yazmaz.

## 7. Aile daveti, çocuk bilgisi ve paylaşım

7.1. **Davet.** Uzman, "Aileyi davet et" ekranında ebeveynin e-posta adresini, isterse çocuğun adını ya da takma adını ve yaş grubunu ve yalnız kendisinin göreceği bir not girer. Davet 3 gün geçerlidir; ebeveyn daveti bu sürede hesabına bağlarsa çocuk paylaşımı için 30 gün içinde kullanılabilir. Uzman isterse davete taslak bir takip planı ekleyebilir; aile daveti kabul etmezse taslak plan silinir.

7.2. **Davette çocuk bilgisi (aile onayından önce).** Uzman, aileyi davet ederken çocuğun yalnız adını ya da takma adını ve yaş grubunu girebilir; doğum tarihi, tanı, sağlık bilgisi ya da fotoğraf girmez. Uzman, bu bilgiyi girmeden önce ebeveynle görüştüğünü ve daveti onun bilgisiyle gönderdiğini beyan eder. Platform bu bilgiyi uzman adına ve yalnız daveti iletmek ve ebeveynin onayına sunmak amacıyla tutar; ebeveyn onaylayana kadar başka hiçbir amaçla işlemez ve yalnız daveti kendi ailesine bağlamış ebeveyne gösterir. Ebeveyn bilgiyi düzeltebilir; düzeltme uzmana bildirilir ve danışan listesine yansır. Ebeveyn onaylamaz, reddeder ya da davet süresi dolarsa bilgi silinir (bağlanmamış davette 3 gün, bağlanmış ama onaylanmamış davette en geç 30 gün). Bilginin yanlış ya da hukuka aykırı girilmesinden uzman sorumludur.

7.3. **Davet e-postası.** Uzman, ebeveynin e-posta adresini ebeveynin bilgisi dahilinde ve yalnız o aileyi davet etmek için girer. Platform bu adresi uzman adına yalnız davet e-postasını (sınırlı sayıda yeniden gönderimle) iletmek ve ebeveyn kayıt olup e-postasını doğruladığında daveti eşleştirmek için kullanır; pazarlama ya da başka bir amaçla kullanmaz. E-posta yalnız hizmet bilgisi içerir (reklam, fiyat, kampanya içermez); konu satırında unvan, metinde çocuğun adı, uzmanın notu ve sağlık bilgisi yer almaz. E-postada gönderen adı olarak uzmanın adı görünür, yanıtlar uzmanın e-posta adresine gider; altta kimin adına gönderildiği ve aydınlatma metni bağlantısı bulunur. Uzman, daveti kodu kopyalayarak kendisi iletirse doğru kişiye ve güvenli bir yoldan iletilmesinden kendisi sorumludur.

7.4. **Paylaşım yalnız ebeveynin onayıyla.** Çocuğun aile verisi uzmana, ancak ebeveyn uzmanın kim olduğunu görüp çocuğu seçerek açık rızasını verdiğinde açılır. Platform uzmanların kimliğini ve mesleki belgelerini doğrulamadığını ebeveyne açıkça bildirir ve ondan uzmanı tanıdığını ve çocuğun velisi olduğunu beyan etmesini ister.

7.5. **Uzmanın gördüğü aile verisi.** Paylaşım etkin olduğu sürece uzman danışanın görevlerini, atamalarını, tamamlamalarını, "Yapamam" nedenlerini, ebeveynin notlarını, zor an kayıtlarını (ses kaydı dahil) ve takip planı uygulama kayıtlarını **salt okur**. Aile içi mesajlar, coin defteri ve oyun kaydı uzmana gösterilmez. Uzman bu verileri yalnız danışana verdiği mesleki hizmet için kullanır; başka amaçla kopyalamaz, üçüncü kişilere vermez.

7.6. **Paylaşımın sona ermesi.** Ebeveyn paylaşımı istediği an durdurabilir; uzman da görebildiği danışan için paylaşımı sonlandırabilir. Paylaşım sona erince uzmanın o çocuğun aile verisine erişimi hemen biter. Bugünkü sistemde uzman, üyeliği etkin olduğu sürece sona ermiş paylaşıma ait kendi danışan kayıtlarını okuyabilir ve silebilir; ancak yeni kayıt ekleyemez ve mevcut kayıtları değiştiremez.

## 8. Mesleki belge incelemesi

8.1. Belge incelemesi isteğe bağlıdır ve Platformun takdiriyle sunulur; özellik açık değilse ailelere ne rozet ne de "incelenmedi" etiketi gösterilir.

8.2. Platform uzmanın kimliğini ve meslek icra yetkisini doğrulamaz. Uzman isterse mezuniyet belgesini (e-Devlet barkodlu) ya da BACB sicil numarasını yükler; Platform belgenin e-Devlet'te ya da BACB sicilinde kayıtlı olduğunu ve belgedeki ad, bölüm ve derecenin beyanla uyduğunu inceler. Sonuç ailelere yalnız **"Belgesi incelendi: <meslek>"** olarak gösterilir; bu ifade kimlik doğrulaması, yetki onayı ya da hizmet kalitesi taahhüdü değildir. Uzman rozeti "Platform tarafından onaylanmış uzman" ya da benzeri bir anlamda tanıtamaz. Gerçeğe aykırı belge ya da beyan madde 5.2'ye tabidir; Platform rozeti her an askıya alabilir.

8.3. Uzman, yüklediği belgenin yalnız bu inceleme için işlenmesini kabul eder: belge Platformun kendi sunucusunda okunur (yapay zekâ ya da dış hizmet kullanılmaz), yalnız yetkili ekip üyesi görür ve her görüntüleme kayda geçer; karar verilince, başvuru kendiliğinden geri çevrilince, yeni belgeyle değiştirilince ya da hesap silinince dosya silinir. Yalnız özet (üniversite, bölüm, derece, mezuniyet yılı), karar kaydı ve aynı belgenin iki hesapta kullanılmasını önlemek için belge barkodu saklanır. Kimlik numarası saklanmaz.

8.4. Uzman profil adını değiştirirse rozet düşer ve belge yeniden yüklenir; BCBA sertifikası yılda bir yeniden kontrol edilir; şikâyet hâlinde rozet askıya alınır.

8.5. Platform incelemeyi makul özenle yapar. İnceleme, sahte ya da başkasına ait bir belgenin her durumda fark edilmesini garanti etmez; Platformun inceleme hatasından sorumluluğu madde 15'teki sınırlara tabidir.

## 9. Danışan kayıtlarının niteliği ve uzman değişiminde aktarım

9.1. **Kayıtların niteliği.** Uzmanın ClinicApp'e girdiği notlar, hedefler, değerlendirmeler, görev önerileri ve aile programı, ebeveynin rızasıyla paylaşılan çocuğa ilişkin kayıtlardır. Notlar ve hedef değerlendirmeleri aileye gösterilmez; uzmanın "aile görür" işaretlediği hedefler, "Planı aileye gönder" dediği takip planı ve gönderdiği görev önerileri ilgili ebeveynlere gösterilir.

9.2. **Süreklilik için aktarım.** Ebeveyn çocuğun takibini başka bir uzmana taşıdığında ve açıkça izin verdiğinde, bu kayıtlar sonraki uzmana salt okunur olarak açılabilir. **Uzman bu aktarıma şimdiden izin verir** ve bu izin Veri İşleme Eki'nde Platforma verilmiş bir talimattır.

9.3. **Kimliğin gizlenmesi.** Aktarımda uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgisi gösterilmez; sonraki uzman yalnız "Önceki uzman 1" gibi bir sıra adı ve dönemi (ay olarak) görür. Kayıtlarda geçen uzman ve klinik adları ile e-posta ve telefon bilgileri otomatik gizlenir. Bu gizleme en iyi çabayla yapılır; yazım hatalı ya da kısaltılmış adlar yakalanamayabilir. Uzman, serbest metin alanlarına kendisinin ya da başka kişilerin kimlik bilgisini yazmamayı kabul eder.

9.4. **Değiştirilmezlik.** Sonraki uzman aktarılan kayıtları değiştiremez ve silemez; kayıtlar tarihleriyle, aktaran uzmanın o tarihteki gözlemi olarak gösterilir.

9.5. **Rızanın geri alınması.** Ebeveyn izni geri alınca sonraki uzmanın aktarılan kayıtlara erişimi derhal sona erer.

9.6. **Hesabın kapanması.** Bugünkü sistemde tek kişilik klinik silinince kayıtları da silinir ve aktarım biter; ekipte başka uzman varsa kayıtlar klinikte kalır ve aktarım sürebilir.

9.7. **Sorumluluk.** Aktarılan kayıtlar tanı değildir. Sonraki uzman kendi mesleki değerlendirmesinden sorumludur; önceki uzman, kaydı yazdığı tarihteki gözleminin sonradan nasıl kullanıldığından sorumlu tutulamaz.

9.8. **Devralan uzmanın yükümlülüğü.** Uzman, kendisine aktarılan kayıtları yalnız danışanın takibinin sürekliliği için okur; kayıtlardan önceki uzmanın kimliğini çıkarmaya çalışmaz. Gizlemenin yakalayamadığı bir kimlik bilgisi görürse bunu kullanmaz ve Platforma bildirir.

9.9. **Saklama.** Paylaşım bittikten sonra kayıtların saklanması ve imhası Veri İşleme Eki'ne ve madde 14'e tabidir.

## 10. Üyelik ve ödeme

10.1. **Paketler.** ClinicApp, Bireysel ve Klinik paketleriyle, aylık ya da yıllık dönemlerle sunulur. Paketlerin içeriği, koltuk sayısı ve KDV dahil fiyatı ClinicApp'in Üyelik ekranında ve App Store'da satın almadan önce gösterilir.

10.2. **Satıcı Apple'dır.** Üyelik App Store üzerinden, uygulama içi satın alma olarak satılır. Ödeme, faturalama, iade ve otomatik yenileme Apple'ın kurallarına ve Apple Medya Hizmetleri Hüküm ve Koşulları'na tabidir. Platform kart bilgisini görmez; üyelik durumunu Apple ve RevenueCat'ten gelen bildirimlerle doğrular. Satın almaya ilişkin belge ve makbuzlar Apple tarafından sağlanır.

10.3. **Ödeyen klinik sahibidir.** Üyeliği yalnız klinik sahibi, kendi Apple hesabıyla ve birey olarak satın alır. Üyelik, paketin izin verdiği ölçüde kliniğin bütün ekibine erişim sağlar; ekip üyeleri ayrıca ödeme yapmaz. Bireysel pakette yalnız klinik sahibi erişir. ClinicApp web sürümünde satın alma yapılmaz; iPhone ya da iPad'deki ClinicApp'te alınan üyelik, uzman hesabına bağlı olduğu için web sürümünde de geçerlidir.

10.4. **Deneme süresi.** Yeni klinik, ödeme bilgisi istenmeden 7 (yedi) gün ücretsiz deneme süresinden yararlanır (Platform süreyi uzatabilir). Deneme süresinin sonunda ücretli pakete geçilmezse hiçbir ücret alınmaz ve erişim madde 10.7'ye göre kapanır. Platform deneme süresini kendi takdiriyle uzatabilir.

10.5. **Otomatik yenileme ve iptal.** App Store üyelikleri, iptal edilmedikçe her dönem sonunda aynı süre için otomatik yenilenir ve ücret Apple hesabına yansıtılır. Klinik sahibi üyeliğini her zaman Apple hesabının abonelik ayarlarından (iPhone/iPad: Ayarlar › Apple hesabı › Abonelikler) iptal edebilir; yenilemenin durması için iptalin Apple'ın belirlediği süre içinde (bugün dönem bitiminden en az 24 saat önce) yapılması gerekir. İptal, ödenmiş dönemin sonunda geçerli olur. ClinicApp hesabını silmek üyeliği kendiliğinden iptal etmez.

10.6. **Elle tanımlanan üyelik.** Platform; pilot çalışma, kurumsal anlaşma ya da benzeri durumlarda kliniğe yönetim paneli üzerinden süreli üyelik tanımlayabilir. Bu üyeliğin koşulları ve süresi uzmana ayrıca yazılı olarak bildirilir; süre sonunda ücretli pakete geçilmezse erişim madde 10.7'ye göre kapanır.

10.7. **Üyelik ya da deneme bitince.** Etkin deneme ya da üyelik yoksa uzman danışanların aile verisine, danışan kayıtlarına, görev önerilerine ve davet özelliğine erişemez; ClinicApp panel yerine Üyelik ekranını gösterir. Bu durumda veriler hemen silinmez; madde 14.4'teki süre boyunca saklanır ve üyelik bu süre içinde yenilenirse erişim kaldığı yerden açılır. Bireysel pakette ekip üyelerinin erişimi kapalıdır.

10.8. **Fiyat değişikliği.** Platform paket fiyatlarını değiştirebilir. Değişiklik mevcut üyelere Apple'ın kurallarına uygun olarak önceden bildirilir ve bir sonraki yenileme döneminden itibaren uygulanır; kabul etmeyen klinik sahibi üyeliğini iptal edebilir.

10.9. **İade.** İade talepleri Apple'ın iade süreci üzerinden yapılır ve Apple'ın kararına tabidir. Mevzuatın tanıdığı haklar saklıdır.

10.10. **Ailelere tanınan avantajlar.** Platform, etkin üyeliği olan kliniklere bağlı ailelere ParentApp'te ek özellikler sunabilir. Bu avantajlar Platformun takdirindedir, değiştirilebilir ve uzman bakımından bu sözleşmeden doğan bir hak oluşturmaz.

## 11. Kabul edilemez kullanım

11.1. Uzman ClinicApp'i şu amaçlarla kullanamaz:
   - a) tanımadığı ya da hizmet vermediği kişilere davet göndermek; davet özelliğini toplu, istenmeyen ya da reklam ve pazarlama amaçlı ileti için kullanmak;
   - b) başkası adına hesap açmak; sahip olmadığı bir unvanı, belgeyi ya da yetkiyi beyan etmek; hesabını ya da koltuğunu başkasıyla paylaşmak;
   - c) çocukla Platform üzerinden doğrudan iletişim kurmaya çalışmak; ebeveynden çocuğun oyun giriş kodunu ya da QR'ını istemek; çocuğun cihazına bağlanmaya çalışmak;
   - ç) davet formuna, notlara ya da diğer serbest metin alanlarına gereksiz kimlik bilgisi, üçüncü kişilere ait bilgi ya da davette sağlık bilgisi yazmak;
   - d) yetkisi olmayan verilere erişmeye çalışmak; güvenlik önlemlerini aşmaya çalışmak; izinsiz güvenlik testi yapmak; yazılımı tersine mühendislikle çözmek; otomatik araçlarla veri çekmek ya da sisteme olağan dışı yük bindirmek;
   - e) şablonları ya da yazılımı toplu kopyalayarak başka bir ürün veya ticari amaç için kullanmak;
   - f) hukuka, kişilik haklarına ya da çocuğun üstün yararına aykırı içerik girmek;
   - g) Platformu tanı veya tedavi hizmeti olarak tanıtmak; Platformun adını ve markalarını izinsiz kullanmak; rozeti madde 8.2'ye aykırı biçimde sunmak.

11.2. Aykırılık hâlinde Platform, aykırılığın ağırlığına göre uyarabilir, ilgili özelliği kısıtlayabilir, hesabı askıya alabilir ya da sözleşmeyi madde 14.3 uyarınca feshedebilir. Aileleri, çocukları ya da sistemi korumak için gerekiyorsa bu önlemler önceden bildirim yapılmadan alınabilir; bu durumda uzmana gerekçe en kısa sürede bildirilir. Uzman `destek@[ALAN ADI]` adresinden itiraz edebilir.

## 12. Fikri mülkiyet

12.1. **Platformun hakları.** ClinicApp, ParentApp ve Pofi Adası yazılımları, arayüzleri, markaları, şablonları (görev şablonları, hazır rutinler, takip planı şablonları, rapor biçimleri) ve Platformun hazırladığı metinler Platforma ya da lisans verenlerine aittir. Platform, uzmana sözleşme süresince ClinicApp'i mesleki hizmeti için kullanma hakkını münhasır olmayan, devredilemeyen ve alt lisans verilemeyen biçimde tanır. Şablonların dayandığı kaynaklardaki üçüncü kişi hakları saklıdır.

12.2. **Uzmanın hakları.** Uzmanın danışan kayıtlarına yazdığı özgün içerik (notlar, hedef tanımları, değerlendirmeler, önerilerdeki özgün metinler) uzmana ya da aralarındaki ilişkiye göre kliniğe aittir. Uzman bir şablonu uyarladığında şablonun kendisi Platformun kalır; uzmanın eklediği özgün kısım uzmanın olur.

12.3. **Platforma verilen sınırlı izin.** Uzman, kendi içeriğini yalnız hizmetin sunulması için (saklama, yedekleme, uzmana ve yetkili ekibine gösterme, aileye gönderilen kısmı aileye gösterme, madde 9 uyarınca sonraki uzmana açma) sözleşme ve saklama süresiyle sınırlı, ücretsiz kullanma izni verir. Platform bu içeriği pazarlamada, reklamda ya da yapay zekâ modeli eğitiminde kullanmaz.

12.4. **Aile verisi** aileye aittir; uzmanın bu veriyi yalnız paylaşım sürdükçe okuma yetkisi vardır.

12.5. **Geri bildirim.** Uzmanın ürüne ilişkin önerileri Platform tarafından ayrıca bir bedel ödenmeden kullanılabilir; bu, uzmanın danışan kayıtlarını kapsamaz.

## 13. Kişisel veriler ve Platforma verilen yetkiler

13.1. **Uzmanın kendi verileri** Uzman Aydınlatma Metni'nde (`aydinlatma-uzman`) anlatıldığı şekilde işlenir.

13.2. **Danışan kayıtları** bakımından tarafların rolleri ve yükümlülükleri **Veri İşleme Eki**'nde düzenlenir.

13.3. **Aile verisi** uzmana ebeveynin açık rızasıyla gösterilir. Uzman, bu verileri görmeye başladığı andan itibaren kendi kullanımı (ör. kendi mesleki kaydına geçirmesi, rapor yazdırması) bakımından KVKK'dan doğan yükümlülüklerine, özellikle veri güvenliği yükümlülüğüne (md. 12) uyar.

13.4. **Uzmanın Platforma verdiği yetkiler.** Uzman, sözleşmenin ifası kapsamında Platforma şu yetkileri verir:
   - a) girdiği kayıtların ebeveynin izniyle ailenin uygulamasında gösterilmesi; ebeveyn izin verirse adı gizlenerek sonraki uzmana salt okunur açılması (madde 9);
   - b) belge incelemesi için yüklediği belgenin yetkili ekipçe incelenmesi (madde 8);
   - c) karşılama anketindeki yanıtlarının kimliksiz toplamlar hâlinde ürün geliştirmede kullanılması;
   - ç) verilerinin, hizmetin sunulması için gereken ölçüde, Platformun adına ve talimatıyla çalışan hizmet sağlayıcılara (Ek-2) aktarılması ve bu sağlayıcıların sunucuları yurt dışındaysa KVKK md. 9'daki usule (standart sözleşme ve Kurul'a bildirim) uygun olarak aktarılması;
   - d) Platformun yetkili ekip üyelerinin yalnız destek, güvenlik ve kötüye kullanım incelemesi, üyelik ve ödeme sorunları ile kanuni yükümlülükler için, iki adımlı girişle, gerekçe yazarak ve her erişimi değiştirilemez denetim kaydına geçirerek hesap bilgilerine ve kullanım kayıtlarına erişmesi (not metinleri ekip ekranlarında gösterilmez);
   - e) kişisel içerik barındırmayan kullanım kayıtlarının hizmetin işleyişini ölçmek, hataları bulmak ve ürünü geliştirmek için işlenmesi;
   - f) yetkili mercilerin usulüne uygun talebi hâlinde verilerin talep kapsamıyla sınırlı olarak aktarılması (kanunen yasak değilse uzman bilgilendirilir);
   - g) Platformun birleşme, devir ya da varlık satışı hâlinde verilerin aynı amaçlarla ve aynı koruma düzeyiyle devralana aktarılması (uzman önceden bilgilendirilir, hesabını silme hakkı saklıdır).
   Bu yetkiler açık rıza değildir; hangi işlemenin hangi hukuki sebebe dayandığı Uzman Aydınlatma Metni'nde yazılıdır.

13.5. **Ticari bilgilerin gizliliği.** Platform, uzmanın kliniğine ilişkin bilgileri (ör. danışan sayısı, davet ve kullanım istatistikleri) gizli tutar; yalnız kimliksiz toplamlar hâlinde ve hizmetin işleyişini ölçmek için kullanır.

## 14. Süre, sona erme, verinin dışa aktarılması ve silinmesi

14.1. **Süre.** Sözleşme belirsiz sürelidir; uzman hesabını silene ya da sözleşme feshedilene kadar sürer. Ücretli üyelik dönemleri madde 10'a tabidir.

14.2. **Uzmanın feshi.** Uzman sözleşmeyi her zaman ClinicApp'teki "Hesabı sil" ile sona erdirebilir. Üyeliğin iptali madde 10.5'e göre Apple hesabından ayrıca yapılır.

14.3. **Platformun feshi.** Platform;
   - a) madde 5 ya da 11'e ağır ya da tekrarlanan aykırılık, kanuni zorunluluk veya ailelerin ya da çocukların korunması gibi haklı bir sebeple derhal,
   - b) haklı sebep olmaksızın en az `[SÜRE]` (öneri: 30 gün) önceden bildirimle
   sözleşmeyi feshedebilir. (b) hâlinde ve Platformun ClinicApp hizmetini tümüyle sona erdirmesi hâlinde bildirim süresi en az `[SÜRE]` (öneri: 90 gün) olur ve uzmana madde 14.5'teki dışa aktarma imkânı tanınır.

14.4. **Üyeliği sona eren klinikte saklama.** Deneme ya da üyelik bittikten sonra danışan kayıtları `[SÜRE]` (öneri: 6 ay) boyunca saklanır. Bu sürenin dolmasından en az 30 gün önce klinik sahibine e-postayla hatırlatma yapılır. Süre sonunda üyelik yenilenmemişse danışan kayıtları silinir; uzmanın hesap bilgileri hesap silinene kadar kalır.

14.5. **Dışa aktarma.** Uzman, sözleşme sona ermeden ya da hesabını silmeden önce:
   - a) ClinicApp'in sunduğu yazdırılabilir raporları alabilir;
   - b) `destek@[ALAN ADI]` adresine başvurarak kendi danışan kayıtlarının (notlar, hedefler, değerlendirmeler, görev önerileri, takip planı) bir kopyasını isteyebilir. Platform talebi `[SÜRE]` (öneri: 30 gün) içinde, yaygın kullanılan ve okunabilir bir dosya biçiminde karşılar.
   Dışa aktarma uzmanın kendi girdileriyle sınırlıdır; aile verisi, ebeveynin ayrıca onayı olmadan dışa aktarılmaz.

14.6. **Silme.** Hesap silindiğinde veriler madde 4.5'e göre derhal silinir; yedeklerden silinme Veri İşleme Eki'ndeki süre içinde tamamlanır. Kanunen saklanması gereken kayıtlar (ör. ödeme kayıtları) ve değiştirilemez denetim kaydı, kişiyi doğrudan tanımlayan bilgi (e-posta) çıkarılarak saklama süresince tutulur.

14.7. **Sona ermeden sonra devam eden hükümler.** Madde 6.3, 9.7, 12, 14.5–14.6, 15, 19 ve 20 sözleşme sona erdikten sonra da uygulanır.

## 15. Sorumluluk ve sınırları

15.1. **Platformun yükümlülükleri.** Platform hizmeti makul özenle sunar ve kişisel verilerin güvenliği için KVKK md. 12'deki teknik ve idari tedbirleri alır (Veri İşleme Eki, Ek-A). Veri güvenliği yükümlülüğü sözleşmeyle uzmana devredilmez.

15.2. **Platformun sorumlu olmadığı hâller.** Kanunun izin verdiği ölçüde Platform;
   - a) uzmanın mesleki kararlarından, danışan kayıtlarının içeriğinden ve bunların sonuçlarından,
   - b) ebeveynin ya da çocuğun girdiği bilgilerin doğruluğundan,
   - c) ebeveynin paylaşımı durdurması, rızasını geri alması ya da hesabını silmesi sonucu uzmanın erişimini kaybetmesinden,
   - ç) uzmanın şifresinin, cihazının ya da yazdırdığı raporların güvenliğinin sağlanmamasından,
   - d) Apple, App Store ya da ödeme süreçlerinden kaynaklanan sorunlardan,
   - e) uzmanın serbest metne yazdığı ve otomatik gizlemenin yakalayamadığı kimlik bilgilerinden,
   - f) mücbir sebeplerden (doğal afet, salgın, savaş, genel internet ya da enerji kesintisi, hizmet sağlayıcının elinde olmayan kesintisi, resmî makam kararı gibi)
   doğan zararlardan sorumlu değildir.

15.3. **Sorumluluğun sınırı.** Platform, hafif kusuruyla sebep olduğu dolaylı zararlardan (kâr kaybı, itibar kaybı, iş kaybı gibi) sorumlu değildir. Platformun bu sözleşmeden doğan doğrudan zararlar için toplam sorumluluğu, zarara yol açan olaydan önceki `[SÜRE]` (öneri: 12 ay) içinde klinik sahibinin üyelik için ödediği bedelle sınırlıdır.

15.4. **Sınırın uygulanmadığı hâller.** Madde 15.2 ve 15.3'teki sınırlar; Platformun kastı ya da ağır kusuru (TBK md. 115), kişilerin hayatına ve vücut bütünlüğüne gelen zararlar, kişisel verilerin korunmasına ilişkin kanunen sınırlanamayan sorumluluklar ve kanunen sınırlanamayan diğer hâller bakımından uygulanmaz.

15.5. **Uzmanın tazmin yükümlülüğü.** Uzman; gerçeğe aykırı beyanı (madde 5), hukuka aykırı davet ya da veri girişi (madde 7), mesleki kusuru (madde 6) ya da kabul edilemez kullanımı (madde 11) nedeniyle ailelerin, çocukların, yetkili makamların ya da diğer üçüncü kişilerin Platforma yönelttiği talepler sonucu Platformun uğradığı zararı, kusuru oranında tazmin eder. Platform böyle bir talebi uzmana gecikmeksizin bildirir ve savunmaya katılmasına imkân tanır.

## 16. Sözleşmenin değişmesi ve yeniden onay

16.1. **Esaslı değişiklik.** Uzmanın hak ve yükümlülüklerini, kişisel verilerin işlenmesini ya da ücreti etkileyen değişiklikler, yürürlüğe girmeden en az `[SÜRE]` (öneri: 30 gün) önce uygulama içinde ve kayıtlı e-postaya bildirilir. Yeni sürüm, uzmanın ClinicApp açılışında **yeniden onayıyla** yürürlüğe girer. Uzman yeni sürümü onaylamazsa ClinicApp'i kullanamaz ancak verilerini dışa aktarma (madde 14.5) ve hesabını silme hakkı saklıdır; bu süre içinde veriler silinmez.

16.2. **Esaslı olmayan değişiklik.** Yalnız uzmanın lehine olan, yazım düzeltmesi niteliğindeki ya da yeni bir özelliği tanıtan değişiklikler uygulama içi bildirimle yürürlüğe girer.

16.3. **Kanuni zorunluluk.** Mevzuat değişikliği ya da yetkili makam kararı gerektiriyorsa daha kısa bir süre uygulanabilir; gerekçe bildirimde yazılır.

16.4. **Sürüm kaydı.** Her sürüm anahtarı ve sürüm numarasıyla yayımlanır; uzmanın hangi sürümü ne zaman onayladığı kaydedilir. Alt işleyen değişiklikleri Veri İşleme Eki'ndeki usule tabidir.

## 17. Bildirimler ve iletişim

Platform uzmana uygulama içi bildirimle ve kayıtlı e-posta adresine yazar. Uzman Platforma `destek@[ALAN ADI]` (genel destek), `kvkk@[ALAN ADI]` (kişisel veriler) ve `[ADRES]` (yazılı bildirim) üzerinden ulaşır. Uzman, e-posta adresini güncel tutmakla yükümlüdür.

## 18. Devir

Uzman bu sözleşmeden doğan hak ve yükümlülüklerini Platformun yazılı onayı olmadan devredemez. Platform, birleşme, devir ya da varlık satışı hâlinde sözleşmeyi devralan tarafa devredebilir; uzmanı önceden bilgilendirir ve uzmanın hesabını silme hakkı saklıdır.

## 19. Uygulanacak hukuk, uyuşmazlıklar ve delil

19.1. Bu sözleşmeye Türkiye Cumhuriyeti hukuku uygulanır.

19.2. Uyuşmazlıklarda yetkili mahkeme ve icra daireleri, Hukuk Muhakemeleri Kanunu'nun genel hükümlerine göre belirlenir. Taraflar tacir ya da kamu tüzel kişisi ise `[ADRES]`'in bulunduğu yer mahkemeleri ve icra daireleri yetkilidir (HMK md. 17). Kanunen zorunlu arabuluculuk hükümleri saklıdır.

19.3. Platformun elektronik kayıtları (onay kayıtları, denetim kaydı, sistem kayıtları) uyuşmazlıklarda delil olarak kullanılabilir (HMK md. 193); karşı ispat hakkı saklıdır.

## 20. Çeşitli

20.1. **Bölünebilirlik.** Bu sözleşmenin bir hükmü geçersiz sayılırsa diğer hükümler geçerliliğini korur; geçersiz hüküm, amacına en yakın geçerli hükümle yorumlanır.

20.2. **Bütünlük.** Bu sözleşme ve ekleri, ClinicApp kullanımına ilişkin taraflar arasındaki anlaşmanın tamamıdır. Elle tanımlanan üyelik (madde 10.6) için yapılan yazılı anlaşma, o üyeliğe özgü konularda bu sözleşmeden önce gelir.

20.3. **Haktan feragat sayılmama.** Platformun bir hakkını kullanmaması ya da geç kullanması, o haktan feragat ettiği anlamına gelmez.

20.4. **Dil.** Sözleşmenin Türkçe metni esastır.

---

## Ek-1 ve Ek-2

- **Ek-1:** Veri İşleme Eki — `hukuk/23-veri-isleme-eki.md` (anahtar `veri-isleme-eki`).
- **Ek-2:** Alt işleyenler listesi — `hukuk/41-alt-isleyenler.md`.

## Ek-3: ClinicApp'teki kısa bilgilendirme metinleri

Bu metinler uygulamanın ilgili yerinde gösterilir ve sözleşmenin yorumunda dikkate alınır. Uygulama dili "sen" hitabıdır.

| Yer | Metin | Kaynak |
|---|---|---|
| Kayıt ekranı (onay kutusu; işaretlenmeden "Hesap oluştur" açılmaz) | ☐ ClinicApp Uzman Hizmet Sözleşmesi'ni ve Veri İşleme Eki'ni okudum, kabul ediyorum. — Altında, kutudan ayrı: "Kişisel verilerinin nasıl işlendiğini Uzman Aydınlatma Metni'nde okuyabilirsin." | öneri |
| Ekip koduyla katılım | Aynı onay kutusu ve aydınlatma bağlantısı. | öneri |
| Ana ekran / danışan ayrıntısı (alt bilgi) | "ClinicApp acil yardım hizmeti değildir. Acil durumda 112'yi ara." | öneri (`02` uyarlama kararı 6) |
| Göstergeler ve rapor (alt bilgi) | "Bu oranlar ev rutinine ilişkin gözlem özetidir; tanı, zekâ ya da dikkat puanı değildir." | öneri (`hukuk_notlari.md` D) |
| Notlar (not alanının altında) | "Ebeveyn izin verirse notların, adın gizlenerek çocuğun sonraki uzmanına okunur olarak açılabilir. Nota kimlik bilgisi yazma." | mevcut taslak (`hukuk_notlari.md` E) |
| Devralınan kayıtlar | "Önceki uzman 1 · Mart 2026 – Ekim 2026 · ebeveynin izniyle, yalnız okuma" | mevcut taslak (`hukuk_notlari.md` E) |
| Davet formu (çocuk önerisi) | Alan "Çocuğun adı" + yaş grubu; altında "Yalnız daveti kabul eden ebeveyn görür. Sağlık bilgisi yazma." Ayrıntı "i" düğmesinde: "Çocuğun adını ve yaş grubunu yazarsan yalnız daveti kabul eden ebeveyn görür; kontrol edip onaylar, düzeltirse sana bildirim gelir. Mesajda görünmez, davet bitince silinir." | mevcut taslak (`hukuk_notlari.md` E) |
| Davet formu (e-posta) | "Bu adrese senin adına davet e-postası gider; çocuğun adı ve notun e-postada yer almaz. Aile yanıtlarsa yanıt senin e-posta adresine gelir. Daveti yalnız tanıdığın ve hizmet verdiğin aileye gönder." | öneri (A13) |
| Belgeni yükle | "Belgen yalnız inceleme için okunur, karar verilince silinir; kimlik numaran saklanmaz. Ailelere yalnız 'Belgesi incelendi: <meslek>' görünür; bu bir yetki onayı değildir. Ayrıntı: Uzman Aydınlatma Metni." | öneri (A11–A12) |
| Üyelik ekranı (satın alma düğmesinin yakınında) | Paket adı, dönem, KDV dahil fiyat; "Üyelik, dönem bitiminden en az 24 saat önce iptal edilmezse aynı süre için otomatik yenilenir ve ücret Apple hesabına yansıtılır. İptal: Ayarlar › Apple hesabı › Abonelikler." + Uzman Hizmet Sözleşmesi ve Uzman Aydınlatma Metni bağlantıları. | öneri (Apple 3.1.2) |
| Hesabı sil (onaydan önce) | "Tek kişilik kliniğinde bütün danışan kayıtların kalıcı olarak silinir. Saklaman gereken kayıtları önce yazdır ya da destekten iste. App Store üyeliğini Apple hesabından ayrıca iptal et." | öneri |

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('veri-isleme-eki', 'v1', 'Veri İşleme Eki (ClinicApp Uzman Hizmet Sözleşmesi, Ek-1)', '{clinic}', true, $md$# Veri İşleme Eki (ClinicApp Uzman Hizmet Sözleşmesi, Ek-1)

## Kısaca

- **Roller (öneri):** Danışanlarınız için ClinicApp'e girdiğiniz kayıtlarda (notlar, hedefler, değerlendirmeler, görev önerileri, takip planı, davet bilgileri) **kliniğiniz veri sorumlusu**, **Platform veri işleyen**dir.
- **Yalnız talimatla:** Platform bu kayıtları yalnız sizin talimatınızla ve hizmeti sunmak için işler; satmaz, reklamda ya da yapay zekâ eğitiminde kullanmaz.
- **Önceden verdiğiniz talimatlar:** aileye gönderdiğiniz kısmı aileye göstermek, sizin adınıza davet e-postası göndermek, ebeveyn açıkça izin verirse kayıtlarınızı adınız gizlenerek sonraki uzmana salt okunur açmak, ebeveyn hesabını silince ilgili kayıtları silmek.
- **Güvenlik:** gizlilik taahhüdü vermiş, rolle sınırlı, iki adımlı girişli ekip; satır düzeyi güvenlik, şifreli bağlantı, silinemez denetim kaydı (Ek-A).
- **Alt işleyenler:** güncel liste yayımlanır; değişiklikten önce bildirilir, itiraz edebilirsiniz.
- **Yurt dışı:** KVKK md. 9'a uygun standart sözleşme ve Kurul'a bildirim.
- **İhlal:** öğrendiğimizde gecikmeksizin, en geç `[SÜRE]` saat içinde size bildiririz; Kurul'a 72 saat içindeki bildiriminizde size yardım ederiz.
- **Sona erince:** kayıtlarınızı dışa aktarabilirsiniz; sonra silinir.

---

## 1. Taraflar, konu ve öncelik

1.1. Bu Ek, ClinicApp Uzman Hizmet Sözleşmesi'nin ("Sözleşme") ayrılmaz parçasıdır ve Sözleşme'nin onaylanmasıyla birlikte kabul edilir. Sözleşme'de tanımlanan terimler bu Ek'te aynı anlamda kullanılır.

1.2. Taraflar:
   - a) **Veri sorumlusu:** Uzmanın çalıştığı klinik. Kliniğin tüzel kişiliği ya da ayrı bir işletmesi varsa o; yoksa klinik sahibi uzman. Tek kişilik klinikte uzmanın kendisi. Ekip üyeleri, veri sorumlusunun yetkisiyle ve onun adına hareket eden kişilerdir. Bu Ek'te kısaca "**Uzman**" denir.
   - b) **Veri işleyen:** `[ŞİRKET UNVANI]` ("**Platform**"), `[ADRES]`.

1.3. Kişisel verilere ilişkin konularda bu Ek ile Sözleşme arasında çelişki olursa bu Ek uygulanır.

## 2. Roller ve kapsam

2.1. **Danışan kayıtları.** Uzmanın ClinicApp'e girdiği danışan kayıtları (madde 4.2) bakımından Uzman veri sorumlusu, Platform veri işleyendir. Platform bu kayıtları Uzman adına, bu Ek'teki talimatlar çerçevesinde işler.

2.2. **Kapsam dışında kalanlar.** Bu Ek aşağıdakileri kapsamaz:
   - a) **Uzmanın kendi hesap verisi** (ad, unvan, e-posta, üyelik, belge incelemesi, anket, kullanım kayıtları): Platform veri sorumlusudur; Uzman Aydınlatma Metni'ne tabidir.
   - b) **Aile verisi** (ebeveynin ve çocuğun ParentApp ve Pofi Adası'nda oluşturduğu görevler, atamalar, tamamlamalar, "Yapamam" nedenleri, ebeveyn notları, zor an kayıtları ve ses kayıtları, çocuğun profil bilgileri, ebeveyn adları): Platform ParentApp ve Pofi Adası için veri sorumlusudur. Uzman bu verileri ebeveynin açık rızasıyla ve paylaşım sürdükçe görür; gördüğü veriyi kendi mesleki kaydına geçirmesi ya da rapor olarak yazdırması bakımından kendisi ayrı veri sorumlusudur.

2.3. **Platformun kendi amaçlarıyla sınırlı işleme.** Platform, danışan kayıtlarının içeriğine bakmadan yalnız sayısal bilgileri (ör. bir klinikte son 30 günde yazılan not, gönderilen öneri sayısı) hizmetin işleyişini ölçmek, destek vermek ve kötüye kullanımı önlemek için kendi meşru menfaatine dayanarak işler; güvenlik ve denetim kayıtlarını ve kanunen tutması gereken kayıtları kendi veri sorumluluğu altında tutar. Bu işleme kimliksizdir ya da danışan kayıtlarının içeriğini kapsamaz.

## 3. İşlemenin konusu, niteliği, amacı ve süresi

| | |
|---|---|
| Konu | ClinicApp hizmetinin Sözleşme'ye göre sunulması |
| Niteliği | Kaydetme, saklama, yedekleme, düzenleme; Uzmana ve klinik sahibinin yetkilendirdiği ekip üyelerine gösterme; Uzmanın gönderdiği kısmı ilgili ebeveynlere gösterme ve bildirim gönderme; Uzman adına davet e-postası gönderme ve daveti eşleştirme; ebeveynin açık rızasıyla sonraki uzmana salt okunur açma; silme ve imha |
| Amaç | Uzmanın danışan ve ailesiyle yürüttüğü mesleki çalışmanın ClinicApp üzerinden desteklenmesi |
| Süre | Sözleşme süresince ve madde 13'teki sona erme süreçleri tamamlanana kadar |

## 4. İlgili kişi grupları ve veri kategorileri

4.1. **İlgili kişi grupları:**
   - a) Çocuklar (danışanlar);
   - b) Ebeveynler (veliler ve yasal temsilciler) ve aynı ailedeki diğer ebeveyn;
   - c) Uzman ve klinik ekip üyeleri (kayıtların yazarı ve sorumlusu olarak);
   - ç) Uzmanın serbest metne yazması hâlinde üçüncü kişiler (önerilmez; Sözleşme md. 6.5).

4.2. **Danışan kayıtları (bu Ek'in kapsamı):**

| Kategori | İçerik | Kimin hakkında |
|---|---|---|
| Davet bilgileri | Ebeveynin e-posta adresi; çocuğun adı ya da takma adı ve yaş grubu (yalnız aile onayına kadar); Uzmanın davet notu; davetin ve e-postanın durumu (gönderildi, açıldı, bağlandı, paylaşıldı, süresi doldu, iptal, reddedildi) | Ebeveyn, çocuk |
| Danışan etiketi | Uzmanın danışan için yalnız kliniğin gördüğü kısa adı ya da notu | Çocuk |
| Notlar | Serbest metin; aile görmez | Çocuk, ebeveyn |
| Hedefler ve değerlendirmeler | Alan, gözlenebilir davranış, ölçüm biçimi, başlangıç ve hedef düzey, süre, evde destek, aileye görünürlük; haftalık değerlendirme (−2 … +2) ve kısa not (değerlendirmeler aileye görünmez) | Çocuk |
| Görev önerileri | Başlık, açıklama, tekrar, hatırlatma saati, ödül, inceleme gerekliliği, ebeveyne not; ailenin kararı ve oluşan görevle bağı | Çocuk, ebeveyn |
| Takip planı (aile programı) | Modüllerin amacı, evde uygulama, kontrol listesi, durumu; aileye gönderim bilgisi; ebeveynin bu modüller için girdiği uygulama kayıtları (bugün uyguladım, zorluk 1–5, uygulayamama nedeni) | Çocuk, ebeveyn |
| Klinik içi atamalar | Danışanın sorumlu uzmanı ve erişim açılan ekip üyeleri | Uzman, çocuk |
| Yazar ve zaman bilgisi | Kaydı hangi uzmanın, ne zaman yazdığı | Uzman |

4.3. **Özel nitelikli veri.** Notlar, hedefler ve değerlendirmeler çocuğun ruh sağlığına, gelişimine ve davranışına ilişkin bilgi içerebilir ve KVKK md. 6 anlamında sağlık verisi sayılabilir. Taraflar bu kayıtların tamamına özel nitelikli veri düzeyinde koruma uygular. Uzman tanı, ilaç ve benzeri bilgileri yalnız mesleki gereklilik ölçüsünde yazar; davet bilgilerine hiçbir sağlık bilgisi yazmaz.

## 5. Uzmanın (veri sorumlusunun) yükümlülükleri

5.1. **Hukuki sebep ve aydınlatma.** Danışan kayıtlarının işlenmesi için gerekli hukuki sebebin bulunması, gerektiğinde açık rızanın alınması ve ilgili kişilerin aydınlatılması Uzmanın yükümlülüğüdür (KVKK md. 5, 6, 10). Ebeveynin ParentApp'te verdiği paylaşım onayı (`uzman-paylasim-v1`) ve önceki uzman kayıtlarına ilişkin açık rızası (`uzman-gecis-v1`) Platformun sistemindeki paylaşımın ve aktarımın dayanağıdır; Uzmanın kendi mesleki kayıtları için aydınlatma ve onam yükümlülüğünü kaldırmaz.

5.2. **Talimatların hukuka uygunluğu.** Uzman, Platforma verdiği talimatların mevzuata ve meslek kurallarına uygun olmasını sağlar.

5.3. **En az veri.** Uzman yalnız mesleki olarak gerekli veriyi girer (Sözleşme md. 6.5 ve 7.2).

5.4. **Ekip ve erişim.** Uzman (klinik sahibi), danışan kayıtlarına yalnız o danışanla çalışması gereken ekip üyelerinin erişmesini sağlar, ekip üyelerine gizlilik yükümlülüğünü bildirir ve ayrılan ekip üyesinin erişimini derhal kapatır.

5.5. **Hesap ve cihaz güvenliği.** Uzman şifresini, ClinicApp'e eriştiği cihazları ve yazdırdığı raporları korur.

5.6. **Başvurular ve bildirimler.** Danışan kayıtlarıyla ilgili ilgili kişi başvurularını yanıtlamak (md. 11, 13), danışan kayıtlarını etkileyen bir veri ihlalini Kurul'a ve ilgililere bildirmek (md. 12/5) ve varsa VERBİS kaydı yükümlülüğü Uzmandadır. Platform bunlarda madde 10 ve 11'deki gibi yardım eder.

## 6. Uzmanın önceden verdiği talimatlar

6.1. Uzman, Sözleşme'yi onaylayarak Platforma aşağıdaki işlemler için yazılı talimat verir:
   - a) **Temel hizmet:** danışan kayıtlarını kaydetmek, saklamak, yedeklemek; Uzmana ve klinik sahibinin yetkilendirdiği ekip üyelerine göstermek.
   - b) **Aileye gösterme:** Uzmanın "aile görür" işaretlediği hedefleri, "Planı aileye gönder" dediği andaki takip planını ve gönderdiği görev önerilerini, paylaşım etkin olduğu sürece ilgili ebeveynlere göstermek ve bunlar için bildirim göndermek. Notlar ve hedef değerlendirmeleri aileye gösterilmez.
   - c) **Davet:** Uzmanın girdiği ebeveyn e-posta adresine Uzman adına davet e-postası göndermek (sınırlı sayıda yeniden gönderimle); ebeveyn aynı adresle kayıt olup adresini doğruladığında daveti eşleştirmek; çocuk bilgisini yalnız daveti kendi ailesine bağlamış ebeveyne göstermek; ebeveynin düzelttiği bilgiyi Uzmana bildirmek; davet kullanıldığında, iptal edildiğinde, reddedildiğinde ya da süresi dolduğunda çocuk bilgisini silmek (bağlanmamış davette 3 gün, bağlanmış ama onaylanmamış davette en geç 30 gün); kabul edilmeyen davetin taslak planını silmek.
   - ç) **Sonraki uzmana aktarım:** Ebeveyn çocuğun takibini başka bir uzmana taşıdığında ve açık rıza verdiğinde (`uzman-gecis-v1`), sona ermiş paylaşımlara ait ve paylaşımın bittiği tarihe kadarki danışan kayıtlarını (notlar, hedefler, haftalık değerlendirmeler, görev önerileri ve ailenin kararı, takip planı ve uygulama kayıtları) sonraki uzmana **salt okunur** açmak. Bu aktarımda Uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgileri aktarılmaz; sonraki uzmana yalnız "Önceki uzman n" sıra adı ve dönem (ay) gösterilir; kayıt metinlerinde geçen klinik ve uzman adları ile e-posta ve telefon bilgileri en iyi çabayla gizlenir. Sonraki uzman tablolara doğrudan erişemez, kayıtları değiştiremez ve silemez. Ebeveyn rızasını geri aldığında erişim derhal kapatılır.
   - d) **Ebeveynin kararlarına uyum:** Ebeveyn paylaşımı durdurduğunda Uzmanın o çocuğun aile verisine erişimini derhal kapatmak; ebeveyn hesabını ya da çocuğun profilini sildiğinde o çocuğa bağlı paylaşımı ve danışan kayıtlarını silmek.
   - e) **Hesap silme:** Uzman hesabını sildiğinde tek kişilik klinikte bütün danışan kayıtlarını silmek; ekipte başka uzman varsa kayıtları klinikte bırakmak, klinik sahibi hesabını siliyorsa sahipliği en eski üyeye devretmek, ekip üyesi hesabını siliyorsa onun sorumlu olduğu danışanları klinik sahibine bırakmak.
   - f) **Destek:** Uzmanın talebi üzerine, yalnız o talebi çözmek için ve kayıt altında hesap ve klinik bilgilerine bakmak. Not metinleri yönetim ekranlarında gösterilmez.
   - g) **Üyelik bitince:** Sözleşme md. 10.7 ve 14.4'e göre erişimi kapatmak, kayıtları saklama süresi boyunca tutmak ve süre sonunda silmek.

6.2. **Ek talimatlar.** Uzman ek talimatlarını ClinicApp'teki ayarlar ve araçlarla ya da yazılı olarak (`destek@[ALAN ADI]`, `kvkk@[ALAN ADI]`) verir. Platform, bir talimatın mevzuata aykırı olduğunu düşünürse bunu Uzmana derhal bildirir ve aykırılık giderilene kadar o talimatı uygulamayabilir.

## 7. Platformun (veri işleyenin) yükümlülükleri

7.1. **Yalnız talimatla işleme.** Platform danışan kayıtlarını yalnız bu Ek'teki ve Uzmanın verdiği talimatlarla işler. Kanun gereği başka bir işleme zorunluysa (ör. yetkili merci talebi), kanunen yasak değilse bunu işlemeden önce Uzmana bildirir.

7.2. **Kendi amaçları için kullanmama.** Platform danışan kayıtlarını satmaz, kiralamaz; reklam, pazarlama, profil çıkarma ya da yapay zekâ modeli eğitimi için kullanmaz; madde 2.3 dışında kendi amaçları için işlemez.

7.3. **Gizlilik taahhüdü olan personel.** Platform danışan kayıtlarına ya da bunları barındıran sistemlere erişebilecek çalışanlarını ve yetkili ekip üyelerini yazılı gizlilik taahhüdüyle bağlar; erişimi rolle (sahip, finans, destek, izleyici) ve işin gerektirdiği ölçüyle sınırlar. Yönetim panelinde iki adımlı doğrulama zorunludur, her değişiklik gerekçe yazılarak yapılır ve silinemez denetim kaydına geçer; not metinleri, mesaj içerikleri, fotoğraflar ve ses kayıtları yönetim ekranlarında gösterilmez.

7.4. **Güvenlik tedbirleri.** Platform, KVKK md. 12 ve Kurul'un rehberine uygun olarak Ek-A'daki teknik ve idari tedbirleri alır ve teknolojinin gelişimine göre günceller. Taraflar, KVKK md. 12/2 uyarınca veri işleyenin işlediği veriler bakımından güvenlik tedbirlerinin alınmasından birlikte sorumludur; bu sorumluluk sözleşmeyle kaldırılamaz.

7.5. **Yardım.** Platform; ilgili kişi başvurularının yanıtlanmasında (madde 11), veri ihlali bildiriminde (madde 10) ve Kurul'un sorularının yanıtlanmasında, işlemenin niteliğini ve elindeki bilgileri göz önünde tutarak makul ölçüde yardım eder.

7.6. **Kayıt.** Platform yaptığı işlemlerin ve yetkili ekip erişimlerinin kaydını tutar.

## 8. Alt işleyenler

8.1. **Genel yetki.** Uzman, Platformun `hukuk/41-alt-isleyenler.md`'de (herkese açık "Alt İşleyenler" sayfası) listelenen alt işleyenleri kullanmasına genel yetki verir. Bugünkü liste özetle:

| Alt işleyen | Danışan kayıtlarıyla ilişkisi | Konum |
|---|---|---|
| Supabase | Veritabanı, kimlik doğrulama, dosya depolama ve sunucu işlevleri; bütün danışan kayıtları burada barındırılır | `[SUPABASE BÖLGESİ]` |
| Resend | Uzman adına davet e-postası: ebeveynin e-posta adresi ve e-posta içeriği (içerikte çocuğun adı ve Uzmanın notu yoktur) | ABD / AB |
| Apple (APNs) | Uzmana ve ebeveyne gönderilen bildirimlerin iletilmesi; bildirim metni | ABD / AB |
| Cloudflare | Yönetim panelinin barındırılması; danışan kayıtlarının içeriği panelde gösterilmez, yalnız sayılar | Küresel |
| Google (Gmail SMTP) — yalnız test dönemi | Test davet e-postaları; canlı kullanımda kullanılmaz | ABD |

Apple (App Store) ve RevenueCat yalnız üyelik bilgisini işler; danışan kayıtlarına erişmez.

8.2. **Alt işleyen sözleşmeleri.** Platform her alt işleyenle, bu Ek'tekinden daha az koruyucu olmayan veri koruma yükümlülüklerini içeren yazılı bir sözleşme yapar. Platform, alt işleyenin bu yükümlülüklere aykırılığından Uzmana karşı, yardımcı kişinin fiilinden sorumluluk kuralları (TBK md. 116) çerçevesinde sorumludur.

8.3. **Değişiklik ve itiraz.** Platform yeni bir alt işleyen eklemeden ya da birini değiştirmeden en az `[SÜRE]` (öneri: 30 gün) önce Uzmanı uygulama içinde ve e-postayla bilgilendirir ve listeyi günceller. Uzman bu süre içinde, veri korumaya ilişkin makul bir gerekçeyle yazılı olarak itiraz edebilir. Taraflar iyi niyetle çözüm arar; çözüm bulunamazsa Uzman Sözleşme'yi değişiklik yürürlüğe girmeden önce feshedebilir. Güvenlik gereği ya da bir alt işleyenin hizmetini aniden durdurması gibi acil hâllerde daha kısa süre uygulanabilir; gerekçe bildirimde yazılır.

## 9. Yurt dışına aktarım

9.1. Alt işleyenlerin sunucuları yurt dışında bulunabilir (madde 8.1). Uzman, danışan kayıtlarının bu sunuculara aşağıdaki güvencelerle aktarılması için Platforma talimat ve yetki verir.

9.2. Aktarım KVKK md. 9'a uygun yapılır: aktarılan ülke için Kurul'un yeterlilik kararı varsa ona dayanılır; yoksa Platform alt işleyenle Kurul'un ilan ettiği **standart sözleşmeyi** (veri işleyenden veri işleyene aktarım için olanı) imzalar ve imzadan itibaren **5 iş günü** içinde Kurul'a bildirir. Md. 9/6'daki arızi aktarım hâlleri yalnız istisnai durumlarda kullanılır.

9.3. Özel nitelikli veri içerebilen danışan kayıtları için aktarımda şifreli bağlantı ve alt işleyenin durağan veri şifrelemesi gibi ek güvenceler uygulanır.

9.4. Platform veritabanının bulunduğu bölgeyi değiştirirse madde 8.3'teki usulü uygular.

## 10. Kişisel veri ihlali

10.1. **Uzmana bildirim.** Platform, danışan kayıtlarını etkileyen bir veri ihlalini öğrendiğinde Uzmana gecikmeksizin ve **en geç `[SÜRE]` saat** (öneri: 24 saat) içinde, uygulama içi bildirim ve kayıtlı e-posta yoluyla bildirir.

10.2. **Bildirimin içeriği.** Bildirimde, o an bilinebildiği ölçüde: ihlalin niteliği ve zamanı; etkilenen ilgili kişi grupları ve tahmini kayıt sayısı; olası sonuçları; Platformun aldığı ve önerdiği tedbirler; Platformdaki irtibat kişisi yer alır. Henüz bilinmeyen bilgiler öğrenildikçe gecikmeksizin iletilir.

10.3. **Kurul'a ve ilgililere bildirim.** Danışan kayıtlarına ilişkin ihlali Kurul'a 72 saat içinde ve ilgili kişilere makul en kısa sürede bildirmek veri sorumlusu olarak Uzmanın yükümlülüğüdür; Platform bildirimin hazırlanması için gereken bilgi ve belgeleri sağlar. İhlal Platformun veri sorumlusu olduğu verileri de (aile verisi, uzman hesap verisi) etkiliyorsa Platform bu veriler için kendi bildirimini yapar; taraflar ilgili kişilere yapılacak bildirimleri birbiriyle uyumlu yürütür. Uzmanın talimatıyla Platform, ebeveynlere ParentApp üzerinden bildirim iletebilir.

10.4. **Önlem ve kayıt.** Platform ihlalin etkisini azaltmak için gecikmeksizin gerekli önlemleri alır; ihlali, etkilerini ve alınan önlemleri kayıt altına alır.

## 11. İlgili kişi başvuruları

11.1. Platforma, Uzmanın danışan kayıtlarıyla ilgili bir başvuru gelirse Platform başvuruyu `[SÜRE]` (öneri: 5 iş günü) içinde Uzmana iletir ve Uzmanın talimatı olmadan bu kayıtlar hakkında esasa ilişkin yanıt vermez. Başvuru Platformun veri sorumlusu olduğu verileri de kapsıyorsa o kısmı Platform kendisi yanıtlar. KVKK md. 13'teki 30 günlük süre her iki taraf için de gözetilir.

11.2. Platform, Uzmanın başvuruyu yanıtlayabilmesi için danışan kayıtlarını bulma, düzeltme, silme ve dışa aktarma işlemlerinde ClinicApp araçlarıyla ya da destek talebiyle yardım eder.

11.3. Ebeveynin ParentApp'te kullandığı paylaşımı durdurma ve önceki uzman kayıtlarının aktarımını geri alma hakları, Uzmanın ayrıca talimatına gerek olmadan Platform tarafından derhal uygulanır (madde 6.1-ç ve 6.1-d).

## 12. Denetim

12.1. Platform, bu Ek'e uyduğunu göstermek için gereken bilgileri (güncel tedbirler özeti, alt işleyen listesi, varsa bağımsız denetim raporları ve alt işleyenlerin güvenlik sertifikaları ya da raporları) Uzmanın makul talebi üzerine yazılı olarak sağlar.

12.2. Bu bilgiler yeterli değilse Uzman, yılda en çok bir kez, en az 30 gün önceden yazılı bildirimle, çalışma saatleri içinde ve gizlilik taahhüdü vermiş bağımsız bir denetçi aracılığıyla, Platformun ilgili süreçlerini makul ölçüde denetleyebilir. Denetim diğer müşterilerin verilerine ve Platformun ticari sırlarına erişimi kapsamaz; masrafı Uzmana aittir. Bir veri ihlalinden sonra ya da Kurul'un talebi üzerine ek denetim yapılabilir.

12.3. Alt işleyenler bakımından Platform, onların yayımladığı denetim raporlarını ve sertifikalarını iletmekle yükümlüdür; alt işleyenlerin tesislerinde yerinde denetim bu Ek'in kapsamında değildir.

12.4. Platform, Kurul'un denetimlerinde ve bilgi taleplerinde işbirliği yapar.

## 13. Sona erme: iade ve silme

13.1. Sözleşme sona ermeden ya da Uzman hesabını silmeden önce Uzman, danışan kayıtlarının bir kopyasını Sözleşme md. 14.5'e göre alabilir.

13.2. Platform danışan kayıtlarını:
   - a) Uzman hesabını sildiğinde Sözleşme md. 4.5'e ve madde 6.1-e'ye göre derhal;
   - b) üyelik ya da deneme sona erdikten sonra Sözleşme md. 14.4'teki saklama süresi (`[SÜRE]`) dolduğunda;
   - c) Sözleşme feshedildiğinde, dışa aktarma süresinin sonunda
   siler. Yedeklerdeki kopyalar en geç `[SÜRE]` (öneri: 30 gün) içinde, yedekleme döngüsüyle silinir; bu sürede yedekler yalnız felaket kurtarma için kullanılır.

13.3. Silme, yok etme ya da anonim hâle getirme, Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik'e uygun yapılır. Uzmanın yazılı talebi üzerine Platform silmenin yapıldığını yazılı olarak teyit eder. Kanunen saklanması gerekenler dışında Platform danışan kayıtlarının kopyasını tutmaz.

13.4. Sonraki uzmana salt okunur açılmış kayıtlar, önceki kliniğin kayıtlarının bir görünümüdür; önceki klinik silindiğinde bu kayıtlar da silinir ve sonraki uzmanın erişimi sona erer.

## 14. Sorumluluk

Bu Ek'ten doğan sorumluluk Sözleşme md. 15'e tabidir. KVKK md. 12/2'deki birlikte sorumluluk ve kanunen sınırlanamayan sorumluluklar saklıdır. Her taraf kendi yükümlülüklerine aykırılıktan doğan zarardan sorumludur.

## 15. Süre ve değişiklik

Bu Ek, Sözleşme ile birlikte yürürlüğe girer ve madde 13'teki süreçler tamamlanana kadar yürürlükte kalır. Değişiklikler Sözleşme md. 16'daki usule (esaslı değişiklikte önceden bildirim ve yeniden onay), alt işleyen değişiklikleri madde 8.3'e tabidir.

---

## Ek-A: Teknik ve idari tedbirler

"Durum" sütunu bugünkü sistemi gösterir; "yapılacak" olanlar canlıya almadan önce tamamlanır (`CANLIYA_ALMA.md` 1.5–1.6).

### Teknik tedbirler

| Tedbir | Nasıl | Durum |
|---|---|---|
| İletim güvenliği | Bütün bağlantılar TLS ile şifreli | var |
| Satır düzeyi erişim kontrolü | Veritabanında satır düzeyi güvenlik: herkes yalnız kendi ailesini ya da kliniğini görür; uzman çocuğun aile verisini yalnız etkin paylaşım varken salt okur; ekip üyesi yalnız sorumlusu olduğu ve kendisine atanan danışanları görür; mesajlar, coin defteri ve oyun kaydı uzmana kapalıdır | var |
| Girişsiz erişimin engellenmesi | Giriş yapmamış rol hiçbir veritabanı işlevini çağıramaz | var |
| Çocuk cihazının sınırlanması | Çocuk cihazı yalnız kendi profilini görür; klinik tablolarına erişimi yoktur | var |
| Devralınan kayıtların korunması | Sonraki uzman tablolara doğrudan erişemez; yalnız kimlik gizleyen ve salt okuyan bir sunucu işlevi kullanılır | var |
| Özel dosyalar | Mesaj medyası, zor an ses kayıtları ve uzman belgeleri özel kovalarda; yalnız imzalı, kısa süreli bağlantıyla açılır | var |
| Uzman belgesi | Belgeye yalnız sunucu işlevi, denetim kaydı yazarak 2 dakikalık bağlantı verir; karar sonrası dosya silinir | var |
| Kimlik doğrulama | Şifreler kimlik doğrulama sağlayıcısında geri çevrilemez biçimde özetlenmiş; yönetim panelinde iki adımlı doğrulama zorunlu | var |
| Kötüye kullanım sınırları | Kod deneme sınırı (IP dahil), davet e-postası gönderim sınırları, olay kaydı sınırları | var |
| Gizli anahtar yönetimi | Gizli anahtarlar yalnız sunucu sırlarında; uygulamalara yalnız herkese açık (publishable) anahtar girer | var |
| Güvenlik testleri | Rol bazlı güvenlik matrisi testleri; sızma denemesi ve güvenlik taramalarının bulgularının düzeltilmesi | var; canlıdan önce ve önemli değişikliklerde tekrarlanır |
| Durağan veri şifrelemesi ve yedekleme | Barındırma sağlayıcısının (Supabase) altyapısında | sağlayıcı beyanıyla teyit edilecek |
| Değiştirilemez denetim kaydı | Yönetim işlemleri yalnız eklenen, kimsenin değiştiremediği ve silemediği kayda yazılır | var |
| Üçüncü taraf izleme yokluğu | Reklam ağı, üçüncü taraf analiz SDK'sı yok; yapay zekâ hizmetine veri gönderilmez | var |
| Asgari veri | Davette çocuk için yalnız ad ve yaş grubu; davet e-postasında çocuğun adı ve sağlık bilgisi yok; kullanım olaylarında serbest metin yok | var |

### İdari tedbirler

| Tedbir | Nasıl | Durum |
|---|---|---|
| Rol ve yetki | Yönetim panelinde roller (sahip, finans, destek, izleyici); her değişiklik gerekçeli; belge incelemesi yalnız yetkili rollerde | var |
| İçerik gizliliği | Not metni, mesaj içeriği, fotoğraf ve ses kaydı yönetim ekranlarında yok; sağlık yanıtları varsayılan gizli | var |
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
values ('acik-riza-metinleri', 'v1', 'ParentApp Açık Rıza Metinleri', '{parent,web}', false, $md$# ParentApp Açık Rıza Metinleri

> Taslak, 27 Ekim 2026. Olgular: `hukuk/00-olgular.md` §3. Kaynak maddeler: `sozlesme/hukuk_notlari.md` B (aynen korundu), E, F, I4–I5; akışlar `sozlesme/akislar.md` 5.3, 10, 11. Ekran metinleri uygulamanın diliyle ("sen"), rıza cümleleri birinci tekil şahısla (B'deki gibi) yazıldı. Hukuki görüş değildir.

## Kısaca

- Bu üç onay **isteğe bağlıdır.** Vermezsen ParentApp'i kullanmaya devam edersin.
- Onay kutuları **hiçbir zaman önceden işaretli gelmez.** Her onay kendi ekranında, kendi metniyle sorulur.
- **Sağlık yanıtları:** tanı ve ilaç soruları. "Belirtmek istemiyorum" seçeneği her zaman var.
- **Uzmanla paylaşım:** yalnız seçtiğin uzman ve seçtiğin çocuk. Uzman kayıtları yalnız okur.
- **Önceki uzman kayıtları:** yeni uzmana yalnız okunur açılır; önceki uzmanın adı gizlenir.
- Her onayı **istediğin an geri alırsın;** erişim hemen biter.
- Hangi metni ne zaman onayladığın, metnin sürümüyle birlikte kaydedilir.

## Bütün rıza ekranları için ortak kurallar

1. Rıza ekranından **önce**, aynı ekranın üstünde kısa bir aydınlatma kutusu ve "Aydınlatma Metni'nin tamamı" bağlantısı (`aydinlatma-ebeveyn`) gösterilir. Aydınlatmayı okumak rıza sayılmaz.
2. Onay kutusu **önceden işaretli gelmez.** Onay düğmesi kutu işaretlenmeden açılmaz.
3. Ret ya da vazgeç seçeneği onay düğmesi kadar görünür olur. Her ekranda şu cümle bulunur: **"Reddetmen uygulamayı kullanmanı engellemez."**
4. Rıza, Kullanım Koşulları onayının içine gömülmez; hizmet koşulu yapılmaz.
5. Onayın sürümü, onaylayan ebeveyn ve zaman kaydedilir. **Ekrandaki metin değişirse sürüm adı da değişir** (`…-v2`); sistem hangi sürümün onaylandığını tutar.
6. Geri alma yolu her zaman uygulamanın içindedir ve onay vermek kadar kolaydır. Geri alma, o ana kadar yapılan işlemleri geçersiz kılmaz.

---

## 1. Sağlık yanıtları
| Anahtar | saglik-yanit-v1 | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | ParentApp › ilk kurulum (tanışma) › "{ad} için konmuş ya da düşündüğünüz bir tanı var mı?" ve "{ad} düzenli kullandığı bir ilaç var mı?" sorularından hemen önce; her çocuk için ayrı. Ayrıca yanıtlar sonradan değiştirilirken `[EKRAN YOLU]` | Dayanak | KVKK md. 6/2, md. 3/1-a, md. 10 |

### 1.1 Önce gösterilecek kısa aydınlatma

> **Sağlık bilgisi hakkında kısa bilgi**
> - **Kim işler:** `[ŞİRKET UNVANI]`.
> - **Ne:** [Çocuğun adı] için konmuş ya da düşündüğün tanı ve düzenli kullandığı ilaç hakkındaki yanıtların.
> - **Neden:** ParentApp'i [çocuğun adı]'nın ihtiyacına göre düzenlemek.
> - **Kim görür:** sen ve ailendeki diğer ebeveyn. Ekibimiz yalnız destek için, gerekçe yazarak ve ayrıca açarak görebilir; her açılış kayda geçer. Bu yanıtlar uzmanla paylaşılan kayıtların arasında değildir. Kimliksiz toplam raporlarda kullanılmaz.
> - **Nerede:** hizmet sağlayıcımızın sunucularında (`[SUPABASE BÖLGESİ]`); bu sunucular yurt dışında olabilir.
> - **Ne kadar:** sen silene ya da iznini geri alana kadar; en geç hesabın silinene kadar.
> - **Haklar:** düzeltme, silme, bilgi isteme. Başvuru: `kvkk@[ALAN ADI]`. [Aydınlatma Metni'nin tamamı]

### 1.2 Ekranda gösterilecek tam metin

> **Sıradaki iki soru isteğe bağlı.**
>
> [Çocuğun adı] için bir tanı olup olmadığını ve düzenli kullandığı bir ilaç olup olmadığını soracağız. Bu bilgiler sağlık verisidir. Bu yüzden önce iznini istiyoruz.
>
> Yanıtlarını yalnız ParentApp'i [çocuğun adı]'nın ihtiyacına göre düzenlemek için kullanırız. Reklam için kullanmayız, kimseye satmayız. Bu yanıtlar tanı yerine geçmez; çocuğun hakkında bir değerlendirme yapmak için kullanılmaz.
>
> Yanıtlarını istediğin an değiştirebilir, silebilir ya da bu izni geri alabilirsin. Her soruda "Belirtmek istemiyorum" seçeneği var.
>
> Rıza cümlesi: *[Çocuğun adı] için tanı ve düzenli ilaç kullanımıyla ilgili vereceğim yanıtların, yukarıda yazan amaçla ParentApp'te işlenmesine açık rıza veriyorum.*

### 1.3 Onay kutusu ve düğmeler

- ☐ **Tanı ve ilaç yanıtlarımın sağlık verisi olarak işlenmesine açık rıza veriyorum.**
- Düğme: **"Devam"** (kutu işaretlenmeden açılmaz) → iki soru gösterilir.
- Düğme: **"Bu soruları atla"** (aynı büyüklükte).

### 1.4 Ret ya da vazgeç sonucu

> **Reddetmen uygulamayı kullanmanı engellemez.**

"Bu soruları atla" denirse iki sağlık sorusu gösterilmez ve sağlıkla ilgili hiçbir yanıt kaydedilmez; tanışmanın kalan soruları sürer. Soruda "Belirtmek istemiyorum" seçilirse yalnız bu seçim kaydedilir; bunun için izin gerekmez. Ebeveyn soruları sonradan `[EKRAN YOLU]` bölümünden yanıtlayabilir.

### 1.5 Geri alma

`[EKRAN YOLU]` › **"Sağlık yanıtlarımı sil ve iznimi geri al"**. Yanıtlar hemen silinir; geri alma kaydedilir. Yanıtı değiştirmek için aynı bölümden yeniden yanıtlanır (yeni yanıt aynı izinle kaydedilir).

### 1.6 Kayıt

`intake_answers.consent_version = 'saglik-yanit-v1'` + onay zamanı ve onaylayan ebeveyn. Ekrandaki metin, bugün ParentApp'te `saglik-yanit-v1` adıyla gösterilen metinden farklıysa bu taslak yayına `saglik-yanit-v2` olarak girer.

---

## 2. Uzmanla paylaşım
| Anahtar | uzman-paylasim-v1 | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | ParentApp › bekleyen davet ekranı ("[Uzman], [çocuk] ([yaş grubu]) için seni davet etti. Bilgiler doğru mu?") ve Uzmanım › kod gir › çocuk seçme ekranı | Dayanak | KVKK md. 5/1, md. 6/2, md. 3/1-a, md. 10 |

### 2.1 Önce gösterilecek kısa aydınlatma

> **Uzmanla paylaşım hakkında kısa bilgi**
> - **Kim işler:** `[ŞİRKET UNVANI]`; paylaşınca çocuğunun kayıtları seçtiğin uzmanın kliniğinde de görünür.
> - **Neden:** uzmanın çocuğunun takibini yapabilmesi.
> - **Ne paylaşılır:** çocuğun profil bilgileri; görevleri ve "Yaptım" kayıtları, onay ve ret kararların (geçmiş kayıtlar dahil); zor an kayıtları ve ses kayıtları; takip planı uygulama kayıtların; uzmanın önerilerine kararların.
> - **Ne paylaşılmaz:** mesajlarınız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı.
> - **Kim görür:** davet eden uzman, kliniğin sahibi ve sahibin bu paylaşımı atadığı ekip üyeleri. Uzman kayıtları yalnız okur, değiştiremez.
> - **Ne kadar:** sen durdurana kadar. Durdurunca uzmanın erişimi hemen biter; uzmanın o güne kadar yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır.
> - **Haklar:** `kvkk@[ALAN ADI]`. [Aydınlatma Metni'nin tamamı]

### 2.2 Ekranda gösterilecek tam metin

Üst bölüm (bugünkü ekran): **"[Unvan] [Uzman adı] ([Klinik adı]), [çocuğun adı] ([yaş grubu]) için seni davet etti. Bilgiler doğru mu?"** Ad ve yaş grubu düzenlenebilir; ailede başka çocuk varsa onlar da işaretlenebilir. Uzmanın yanında belge incelemesi varsa "Belgesi incelendi: <meslek>" ve "i" düğmesinde: "Bu, kimlik doğrulaması ya da hizmet kalitesi taahhüdü değildir."

Uyarı (`hukuk_notlari.md` E, aynen):

> ClinicApp uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunun bilgilerini paylaşmadan önce bu uzmanı gerçek hayatta tanıdığından ve davetin ondan geldiğinden emin ol. Emin değilsen paylaşma; uzmanını bildiğin bir yoldan arayıp sor. Paylaşımı istediğin an Uzmanım bölümünden durdurabilirsin.

Rıza cümlesi (yeni):

> *Çocuğum [seçilen çocukların adları] ile ilgili yukarıda yazan kayıtların, takibini yapabilmesi için [unvan] [uzman adı] ve onun kliniğinde bu paylaşımı görmeye yetkili kişilerle (klinik sahibi ve onun görevlendirdiği ekip üyeleri) yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Mesajlarımız, coin ve Güneş Taşı hareketleri, ödüller ve oyun kaydı paylaşılmaz. Paylaşımı Uzmanım bölümünden istediğim an durdurabilirim; durdurduğumda erişim hemen sona erer.*

### 2.3 Onay kutusu ve düğmeler

- ☐ **Bu uzmanı tanıyorum ve çocuğun velisiyim (yasal temsilcisiyim).** (`hukuk_notlari.md` E, aynen)
- Düğme: **"Onayla ve paylaş"** — kutu işaretlenmeden açılmaz. Düğmeye basmak, üstteki rıza cümlesinin onayıdır.
- Alt bağlantı: **"Bu davet bana ait değil"**.
- Çocuk daha önce başka bir uzmanla paylaşıldıysa aynı ekranda, **ayrı ve işaretsiz** olarak 3. bölümdeki seçenek çıkar.

### 2.4 Ret ya da vazgeç sonucu

> **Reddetmen uygulamayı kullanmanı engellemez.**

- **"Bu davet bana ait değil":** davet kapanır; uzmana "Aile davetini kabul etmedi" bildirimi gider; uzmanın girdiği çocuk bilgisi ve taslak plan silinir. Hiçbir kayıt paylaşılmaz.
- **Ekrandan çıkmak:** paylaşım olmaz. Davet, ailene bağlıysa 30 gün içinde yeniden açılabilir; süre dolunca uzmanın girdiği bilgiler silinir.

### 2.5 Geri alma

**Uzmanım › [uzman] › "Paylaşımı durdur".** Uzmanın erişimi hemen biter; o uzmandan bekleyen görev önerileri artık gösterilmez. Uzmanın o güne kadar yazdığı kendi notları ve hedefleri kliniğin kayıtlarında kalır. Aynı uzmanla yeniden paylaşmak yeni bir onay ister.

### 2.6 Kayıt ve sürüm

`clinic_links.consent_version`, `consent_by`, `consent_at`. Bugün `uzman-paylasim-v1` adıyla yalnız uyarı (E) ve onay kutusu kaydediliyor. Bu taslak ekrana rıza cümlesini ve kısa aydınlatmayı ekliyor; ekrandaki metin değişeceği için yayına **`uzman-paylasim-v2`** olarak girmelidir (ortak kural 5).

---

## 3. Önceki uzman kayıtlarının yeni uzmana açılması
| Anahtar | uzman-gecis-v1 | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | ParentApp › davet onayı / çocuk seçme ekranı (çocuk daha önce başka bir uzmanla paylaşıldıysa) ve Uzmanım › [yeni uzman] › "Önceki uzmanın kayıtları" anahtarı | Dayanak | KVKK md. 6/2, md. 3/1-a, md. 4, md. 10; uzmanın sözleşmeyle önceden verdiği izin (`hukuk_notlari.md` A2–A3) |

### 3.1 Önce gösterilecek kısa aydınlatma

> **Önceki uzmanın kayıtları hakkında kısa bilgi**
> - **Neden:** takibin yeni uzmanla kesintisiz sürmesi.
> - **Kime:** seçtiğin yeni uzmana ve onun kliniğinde bu paylaşımı görmeye yetkili kişilere.
> - **Ne açılır:** önceki uzman(lar)ın notları, hedefleri, haftalık değerlendirmeleri, görev önerileri ve senin kararların, aile programı ve senin uygulama kayıtların; her biri tarihiyle. Önceki uzmanın notlarını sen görmezsin; bunlar onun o tarihteki mesleki gözlemleridir ve tanı değildir.
> - **Nasıl:** yalnız okunur, uygulamanın içinden. Yeni uzman bu kayıtları değiştiremez ve silemez.
> - **Ne gizlenir:** önceki uzmanın adı, unvanı, kliniği ve iletişim bilgileri. Yeni uzman yalnız "Önceki uzman 1" ve dönemi (ay) görür. Metinlerde geçen uzman ve klinik adları otomatik gizlenir.
> - **Ne kadar:** sen izni geri alana kadar.
> - **Haklar:** `kvkk@[ALAN ADI]`. [Aydınlatma Metni'nin tamamı]

### 3.2 Ekranda gösterilecek tam metin (`hukuk_notlari.md` B, aynen)

> Çocuğum **[çocuğun adı]** için daha önce çalıştığım uzman(lar)ın ClinicApp'e girdiği notların, hedeflerin, haftalık değerlendirmelerin, görev önerilerinin, aile programının ve benim uygulama kayıtlarımın, takibin kesintisiz sürmesi amacıyla yeni uzmanım **[yeni uzmanın adı]** ile yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez. Bu izni Uzmanım bölümünden istediğim an geri alabilirim; geri aldığımda erişim hemen sona erer.

### 3.3 Onay kutusu

- ☐ **Önceki uzmanın kayıtlarını da paylaş (adı gizlenir)** — **işaretsiz gelir.** Ayrı bir seçimdir; 2. bölümdeki paylaşım onayından bağımsızdır.

### 3.4 Ret ya da vazgeç sonucu

> **Reddetmen uygulamayı kullanmanı engellemez.**

Kutu boş bırakılırsa yeni uzmanla paylaşım yine olur (2. bölüm), ama önceki uzmanın notları, hedefleri, değerlendirmeleri, önerileri ve aile programı yeni uzmana açılmaz. Görevler, "Yaptım" kayıtları ve zor anlar 2. bölümdeki paylaşımla zaten görünür.

### 3.5 Geri alma

**Uzmanım › [yeni uzman] › "Önceki uzmanın kayıtları"** anahtarını kapat. İzin kaydı silinir, yeni uzmanın bu kayıtlara erişimi hemen biter. Anahtarı yeniden açmak yeni bir onaydır ve sürümüyle kaydedilir.

### 3.6 Kayıt

`clinic_link_history.consent_version = 'uzman-gecis-v1'`, `granted_by`, `granted_at`. B metni aynen korunduğu için sürüm değişmez; 3.1'deki kısa aydınlatma rıza metninin parçası değildir.

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('cerez-clinicapp-web', 'v1', 'ClinicApp Web Çerez Politikası', '{clinic,web}', false, $md$# ClinicApp Web Çerez Politikası

## Kısaca

- ClinicApp web yalnız **zorunlu** tarayıcı depolaması kullanır: oturumunuzu açık tutmak ve ekranda yaptığınız seçimleri hatırlamak için.
- **Analiz, reklam, sosyal medya ya da üçüncü taraf izleme çerezi kullanmayız**; tarayıcı parmak izi gibi başka izleme yöntemleri de kullanmayız.
- Kullanımı ölçmek için tuttuğumuz kayıtlar sunucumuzda, içerik barındırmadan tutulur; bunun için tarayıcınıza izleme çerezi yerleştirilmez.
- Zorunlu depolama için onayınız istenmez (Kurul'un çerez rehberi); bu metin bilgilendirme amaçlıdır.
- Tarayıcı ayarlarından bu depolamayı silebilir ya da engelleyebilirsiniz; engellerseniz ClinicApp web'e giriş yapamazsınız.
- Ortak bir bilgisayarda işiniz bitince **Çıkış yap**ın; oturum bilgisi silinir.
- Zorunlu olmayan bir çerez eklersek önce bu metni güncelleriz ve onayınızı almadan kullanmayız.

---

## 1. Kapsam ve veri sorumlusu

1.1. Bu politika, `[ŞİRKET UNVANI]` ("Platform", "biz"; `[ADRES]`) tarafından işletilen **ClinicApp'in web sürümünde** kullanılan çerezleri ve benzeri tarayıcı depolama teknolojilerini anlatır.

1.2. ClinicApp'in iPad uygulaması tarayıcı çerezi kullanmaz; uygulama içindeki veri saklama Uzman Aydınlatma Metni'nde (`aydinlatma-uzman`) anlatılmıştır. Aile davet bağlantısının açılış sayfası (ebeveynlere yönelik) bu politikanın kapsamında değildir; bugünkü hâliyle çerez ya da tarayıcı depolaması kullanmaz.

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

Bu depolamada danışan bilgisi, not, mesaj ya da başka kişisel içerik tutulmaz. Danışan kayıtları tarayıcınızda kalıcı olarak saklanmaz; ekranda görüntülenmek üzere sunucudan alınır. Kullanım ölçümünün oturum kimliği yalnız sayfa açıkken bellekte tutulur, tarayıcıya yazılmaz.

**Yazı tipleri ve betikler:** ClinicApp web ve tanıtım sayfası yazı tiplerini ve simgelerini kendi sunucumuzdan yükler (Google Fonts gibi dış hizmetlere istek gitmez); üçüncü taraf betik yüklenmez. ClinicApp web'de satın alma yoktur; üyelik iPhone/iPad'deki ClinicApp'ten App Store ile alınır.

## 4. Kullanmadıklarımız

4.1. ClinicApp web'de şunlar **yoktur**:
- analiz ya da istatistik çerezleri (ör. üçüncü taraf ziyaretçi analiz araçları),
- reklam, yeniden hedefleme ya da sosyal medya çerezleri ve pikselleri,
- tarayıcı parmak izi ya da cihazınızı çerezsiz tanımaya yönelik başka yöntemler,
- kişisel verinizi satmak ya da reklam ağlarıyla paylaşmak.

4.2. **Kullanım ölçümü:** Hangi ekranın ve özelliğin kullanıldığını, sürüm ve platform bilgisini, içerik ve serbest metin yazmadan, **kendi sunucumuzda** ve hesabınıza bağlı olarak kaydederiz (Uzman Aydınlatma Metni, kullanım kayıtları). Bu ölçüm için tarayıcınıza izleme çerezi yerleştirilmez ve üçüncü taraf bir araç kullanılmaz.

## 5. Hukuki sebep ve onay

5.1. Kullandığımız depolamanın tamamı, açıkça talep ettiğiniz hizmetin (ClinicApp web'e giriş yapıp çalışmanın) sunulması için zorunludur. Bu depolama yoluyla yapılan işleme KVKK md. 5/2-c (sözleşmenin ifası) ve md. 5/2-f (meşru menfaat: hesabın ve verinin güvenliği) hukuki sebeplerine dayanır.

5.2. KVKK Kurumu'nun çerez rehberine göre zorunlu çerezler için açık rıza aranmaz; ancak aydınlatma yapılır. Bu politika ve aşağıdaki bilgilendirme bandı bu amaçla sunulur.

## 6. Depolamayı nasıl yönetirsiniz

6.1. **Çıkış yap:** ClinicApp web'de çıkış yaptığınızda oturum bilgisi tarayıcınızdan silinir. Ortak kullanılan bir bilgisayarda işiniz bitince her zaman çıkış yapın.

6.2. **Tarayıcı ayarları:** Tarayıcınızın gizlilik ya da site verileri ayarlarından ClinicApp web'in depoladığı verileri görebilir, silebilir ya da engelleyebilirsiniz. Zorunlu depolamayı engellerseniz ClinicApp web'e giriş yapamazsınız ya da her açılışta yeniden giriş yapmanız gerekir.

6.3. **Gizli pencere:** Tarayıcınızın gizli (özel) penceresinde depolanan veriler pencere kapanınca silinir.

## 7. Üçüncü taraflar ve yurt dışı

7.1. Oturum bilgisi, kimlik doğrulama hizmet sağlayıcımız Supabase'in (`[SUPABASE BÖLGESİ]`) sunucularında doğrulanır. ClinicApp web'in barındırıldığı hizmet sağlayıcısı, sayfaları size iletirken IP adresi ve tarayıcı bilgisi gibi teknik bağlantı kayıtlarını işleyebilir. Hizmet sağlayıcılarımızın listesi ve yurt dışı aktarım bilgisi Uzman Aydınlatma Metni'nde ve `hukuk/41-alt-isleyenler.md`'de yer alır.

7.2. ClinicApp web, bu politikada sayılanlar dışında üçüncü taraf bir hizmetin tarayıcınıza çerez yerleştirmesine izin vermez.

## 8. Haklarınız ve başvuru

KVKK md. 11'deki haklarınızı ve başvuru yollarını Uzman Aydınlatma Metni'nde bulabilirsiniz. Sorularınız için: `kvkk@[ALAN ADI]`.

## 9. Değişiklikler

9.1. Kullandığımız depolama değişirse bu politikayı güncelleriz; tablo her zaman güncel listeyi gösterir.

9.2. İleride zorunlu olmayan bir çerez ya da depolama (ör. analiz) eklemeye karar verirsek: önce bu politikayı güncelleriz, web sürümüne kabul ve reddin eşit kolaylıkta sunulduğu bir onay ekranı ekleriz ve **açık rızanızı almadan** o depolamayı kullanmayız. Onayınızı istediğiniz an geri alabilirsiniz.

---

## Bilgilendirme bandı (öneri)

ClinicApp web'in ilk açılışında ekranın altında, içeriği kapatmayan ince bir bant. Yalnız zorunlu depolama olduğu için "Kabul et / Reddet" yerine tek düğme yeterlidir; düğmeye basınca bant bir daha gösterilmez (bu tercih de yerel depolamada tutulur).

> ClinicApp web yalnız oturumunu açık tutmak ve seçimlerini hatırlamak için zorunlu tarayıcı depolaması kullanır. Analiz ya da reklam çerezi yok. **[Çerez Politikası]** · **[Anladım]**

Giriş yaptıktan sonra Ayarlar › Yasal metinler › Çerez Politikası'ndan her zaman ulaşılır.

---
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('alt-isleyenler', 'v1', 'Hizmet Sağlayıcılar (Alt İşleyenler) Listesi', '{parent,child,clinic,web}', false, $md$# Hizmet Sağlayıcılar (Alt İşleyenler) Listesi

## Kısaca

Pofi Adası, ParentApp ve ClinicApp'i çalıştırmak için bizim adımıza ve talimatımızla çalışan birkaç hizmet sağlayıcı kullanırız. Bu sayfa hepsini, ne için kullandığımızı, hangi veriye eriştiklerini, nerede olduklarını ve yurt dışı aktarımı hangi güvenceyle yaptığımızı gösterir. Reklam ağı, veri satın alan ya da analiz/izleme yapan bir sağlayıcı **yoktur**. Yapay zekâ hizmetine veri gönderilmez. Yeni bir sağlayıcı eklemeden önce bu listeyi güncelleriz.

## 1. Tanımlar

- **Veri sorumlusu:** [ŞİRKET UNVANI] ("biz").
- **Alt işleyen (hizmet sağlayıcı):** Kişisel veriyi yalnız bizim adımıza ve talimatımızla işleyen şirket. Veriyi kendi amaçları için kullanamaz.
- **Bağımsız veri sorumlusu:** Veriyi kendi amaçları için de işleyen ve kendi gizlilik politikasına tabi olan şirket (ör. App Store satışında Apple).

## 2. Özet liste

| # | Sağlayıcı | Rol | Ne için | Hangi uygulama | Konum | Durum |
|---|---|---|---|---|---|---|
| 1 | Supabase | Alt işleyen | Veritabanı, kimlik doğrulama, dosya depolama, sunucu işlevleri | Üçü + ekip paneli | [SUPABASE BÖLGESİ] | Kullanımda |
| 2 | Apple | Satışta bağımsız veri sorumlusu; bildirimde alt işleyen | App Store satışı ve aboneliği; anlık bildirim (APNs) | Üçü | ABD / AB | Kullanımda |
| 3 | Expo | Alt işleyen | Yedek bildirim yolu | ParentApp, ClinicApp (Expo anahtarı kaydeden cihazlar) | ABD | Kodda var; canlıda kalıp kalmayacağı karar bekliyor |
| 4 | RevenueCat | Alt işleyen | Abonelik durumunun doğrulanması | ParentApp, ClinicApp | ABD | Kurulum aşamasında |
| 5 | Resend | Alt işleyen | İşlem e-postaları | ParentApp, ClinicApp | ABD / AB | Alan adı alınınca |
| 6 | Cloudflare | Alt işleyen | Ekip yönetim panelinin barındırılması | Ekip paneli | Küresel ağ | Kullanımda |
| 7 | Google (Gmail SMTP) | Alt işleyen | Yalnız test dönemi e-postaları | ClinicApp (davet) | ABD | **Yalnız test; canlıdan önce kaldırılır** |

## 3. Ayrıntılar

### 3.1 Supabase

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | Bütün uygulama verisinin tutulduğu veritabanı; e-posta + şifre ile giriş ve çocuk cihazının kimliği belirsiz oturumu; mesaj fotoğrafları, sesli mesajlar, zor an ses kayıtları ve uzman belgeleri için özel dosya depolama; bildirim, e-posta ve belge ön kontrolü gibi sunucu işlevleri; zamanlanmış işler |
| Veri | Bu uygulamalarda işlenen verilerin tamamı: ebeveyn, çocuk ve uzman hesap ve profil verisi; görevler, mesajlar, oyun kaydı; zor an kayıtları, tanışma ve isteğe bağlı sağlık yanıtları, uzman notları (özel nitelikli veri dahil); kullanım ve güvenlik kayıtları |
| İlgili kişiler | Ebeveynler, çocuklar, uzmanlar, ekip üyeleri |
| Konum | [SUPABASE BÖLGESİ] |
| Aktarım güvencesi | [standart sözleşme imzalanacak] + imzadan sonra 5 iş günü içinde Kurul'a bildirim |
| Sağlayıcının alt işleyenleri | Bulut altyapısı ve destek hizmetleri — [Supabase'in güncel listesinden eklenecek] |

### 3.2 Apple

| | |
|---|---|
| Rol | **App Store satışı ve aboneliği:** satıcı Apple'dır, ödeme ve Apple Kimliği bilgileri bakımından bağımsız veri sorumlusudur (Apple'ın gizlilik politikası geçerlidir). **Anlık bildirim (APNs):** bizim talimatımızla bildirimi cihaza iletir |
| Amaç | Abonelik satışı, yenileme, iade; ParentApp, Pofi Adası ve ClinicApp'e anlık bildirim iletmek |
| Veri | Bize gelen: işlem kimliği, ürün, dönem sonu, yenileme durumu (kart bilgisi bize gelmez). Apple'a giden: cihazın bildirim anahtarı ve bildirim başlığı ile metni (ör. "Elif bir görevi tamamladı" — çocuğun adı geçebilir) |
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
| Durum | Alan adı alınınca kullanılmaya başlar; reklam ya da kampanya e-postası için kullanılmaz |

### 3.6 Cloudflare

| | |
|---|---|
| Rol | Alt işleyen |
| Amaç | Ekibimizin kullandığı yönetim panelinin barındırılması. [Alan adı alınınca kullanılması düşünülen: alan adı ve DNS, davet açılış sayfası, ClinicApp web sitesi, herkese açık yasal metin sayfaları — karar verilince bu satır güncellenir] |
| Veri | Ekip üyesinin oturum bilgisi; panelde görüntülenen kullanıcı verisi Cloudflare ağından şifreli bağlantıyla geçer; ağ düzeyinde ziyaretçi IP adresleri |
| İlgili kişiler | Ekip üyeleri; panelde kaydı görüntülenen ebeveyn, çocuk ve uzmanlar |
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
| Ebeveynin seçtiği uzman | Yalnız ebeveynin açık rızasıyla, geri alınana kadar | Gizlilik Politikası 8. bölümde sayılan çocuk kayıtları |
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
| Yeni alt işleyen ya da mevcut bir alt işleyene yeni veri türü veya yeni ülke | (1) Yurt dışıysa standart sözleşmeyi imzalarız; (2) bu listenin yeni sürümünü ve Gizlilik Politikası 10. bölümünü yayımlarız; (3) uygulama içinde "Hizmet sağlayıcı listemiz güncellendi" bildirimi gösteririz; değişiklik özel nitelikli veriyi ya da yeni bir amacı kapsıyorsa onay gerektiren metinlerde yeniden onay isteriz; (4) Kurul'a bildirim yaparız | Kullanmaya başlamadan **önce**; Kurul bildirimi imzadan sonra 5 iş günü içinde |
| Uzmanlar için (Veri İşleme Eki) | Yeni alt işleyen uzmanlara e-postayla ve ClinicApp'te duyurulur. Uzman makul gerekçeyle itiraz edebilir; çözüm bulunamazsa sözleşmeyi cezasız sona erdirir, kayıtlarını dışa aktarır ve sildirir | Kullanmaya başlamadan en az [SÜRE] önce (öneri: 30 gün) |
| Acil değişiklik (güvenlik açığı, sağlayıcının hizmeti aniden kesmesi) | Değişikliği yaparız, sonra yukarıdaki adımları tamamlarız | En geç [SÜRE] içinde (öneri: 7 gün) |
| Alt işleyenin çıkarılması | Listeyi güncelleriz; sağlayıcıdan verinin silindiğini teyit ederiz | Çıkarıldığında |

Her güncellemede bu sayfanın sürümü (v1, v2 …) ve tarihi değişir; eski sürümler saklanır. Liste yılda en az bir kez gözden geçirilir.

Yürürlük: [TARİH] · Sürüm: v1 · İletişim: `kvkk@[ALAN ADI]`
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)
values ('kvkk-basvuru', 'v1', 'KVKK Başvuru Usulü', '{parent,child,clinic,web}', false, $md$# KVKK Başvuru Usulü

## Kısaca

- Kişisel verilerinizle ilgili her talebi bize iletebilirsiniz: bilgi almak, kopyasını istemek, düzeltmek, silmek, itiraz etmek, kimlere aktarıldığını öğrenmek, zararın giderilmesini istemek.
- **En kolay yol:** ParentApp ya da ClinicApp › Ayarlar › **KVKK başvurusu**. Hesabınıza bağlıdır; kimliğinizi ayrıca kanıtlamanız gerekmez.
- Diğer yollar: `kvkk@[ALAN ADI]` (kayıtlı e-posta adresinizden), [ADRES] adresine imzalı dilekçe, KEP.
- En geç **30 gün** içinde, **ücretsiz** yanıt veririz.
- Çocuğunuz adına veli olarak başvurabilirsiniz.
- Uzmanın danışan notları gibi kayıtlarda başvurunuzu uzmanın kliniğine yönlendirebiliriz (8. bölüm).

## 1. Kimler başvurabilir?

- ParentApp kullanan ebeveynler.
- ClinicApp kullanan uzmanlar.
- Pofi Adası'nı oynayan çocuklar adına velileri ya da yasal temsilcileri.
- Bir uzmanın davet ettiği ama henüz kayıt olmamış ebeveynler.
- Hesabını silmiş eski kullanıcılar ve bize yazışma yoluyla verisini iletmiş herkes.

Başkası adına başvuru için noter onaylı vekâletname gerekir (velinin çocuk adına başvurusu 7. bölümde).

## 2. Başvuru yolları

| Yol | Nasıl | Kimlik |
|---|---|---|
| **Uygulama içi** (önerilen) | ParentApp ya da ClinicApp › Ayarlar › KVKK başvurusu. Başvurunuzun durumunu aynı ekranda "Başvurularım" altında görürsünüz | Hesabınızla giriş yapmış olmanız yeterlidir |
| **E-posta** | `kvkk@[ALAN ADI]` | Sistemimizde kayıtlı e-posta adresinizden göndermeniz ya da güvenli elektronik imza veya mobil imza kullanmanız gerekir |
| **Yazılı** | [ADRES] adresine ıslak imzalı dilekçe; elden, posta ya da noter aracılığıyla | İmza ve 3. bölümdeki bilgiler |
| **KEP** | [KEP ADRESİ] adresine kendi KEP adresinizden | KEP |

Pofi Adası'nda başvuru formu yoktur; çocuk adına başvuruyu veli ParentApp'ten yapar.

## 3. Başvuruda bulunması gerekenler

- Adınız ve soyadınız; yazılı başvuruda imzanız.
- Türk vatandaşıysanız T.C. kimlik numaranız; değilseniz uyruğunuz ve pasaport ya da kimlik numaranız.
- Tebligata esas yerleşim yeri ya da iş yeri adresiniz.
- Varsa bildirime esas e-posta adresiniz ve telefonunuz.
- Talebinizin konusu ve varsa belgeleriniz.
- Hangi uygulamayla ilgili olduğu (Pofi Adası, ParentApp, ClinicApp) ve çocuk adına başvuruyorsanız hangi çocuk.

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
| Verinizin bir kopyasını almak | Hesabınıza ait verilerin okunabilir bir dökümünü güvenli bir bağlantıyla göndeririz. Başka kişilere ait veriler (ör. diğer ebeveynin yazdıkları) ayıklanabilir | [Verimi indir — yapılınca eklenecek] |
| Eksik ya da yanlış verinin düzeltilmesi | Düzeltir, sonucunu bildiririz | Profil ve çocuk bilgilerini düzenlemek |
| Verinin silinmesi ya da yok edilmesi | Şartlar oluşmuşsa siler, sonucunu bildiririz. Kanunen saklamak zorunda olduğumuz kayıtları (ör. ödeme kayıtları) yalnız o amaçla ve süresi kadar tutarız | Hesabımı sil; sağlık yanıtlarını sil; mesaj ve kayıtları silmek; [çocuk profilini sil — ParentApp'e eklenecek] |
| Verinin yurt içinde ya da yurt dışında aktarıldığı kişileri öğrenmek | Alıcıları ve ülkelerini yazarız | Hizmet Sağlayıcılar Listesi (`alt-isleyenler`) |
| Düzeltme ve silmenin, verinin aktarıldığı kişilere bildirilmesi | Verinin aktarıldığı hizmet sağlayıcılara ve gerekiyorsa uzmana bildiririz | — |
| Yalnız otomatik sistemlerle yapılan bir analizin aleyhinize sonucuna itiraz | İtirazınızı inceleriz. Bugün sizin hakkınızda yalnız otomatik sistemlerle sonuç doğuran bir karar vermiyoruz | — |
| Kanuna aykırı işleme yüzünden uğradığınız zararın giderilmesi | Talebinizi inceler, gerekçeli yanıt veririz | — |
| Uzmanla paylaşımı durdurmak | Başvuru gerekmez | ParentApp › Uzmanım › paylaşımı durdur; erişim hemen biter |

## 6. Süre ve ücret

- Başvurunuzu, bize ulaştığı tarihten itibaren talebin niteliğine göre en kısa sürede ve **en geç 30 gün** içinde sonuçlandırırız.
- Yanıt **ücretsizdir**. Mevzuatın izin verdiği hâllerde bile ücret almıyoruz.
- Yanıtı yazılı ya da elektronik olarak, başvurduğunuz yolla veririz. Uygulama içi başvurunun yanıtı kayıtlı e-posta adresinize gider; uygulamada başvurunuzun durumu "Yanıtlandı" olur.
- Talebinizi reddedersek gerekçesini yazarız.

## 7. Çocuğunuz adına başvuru

- Pofi Adası'nda çocuğun ayrı bir hesabı yoktur; profilini veli ParentApp'te oluşturur. Çocuğun verisiyle ilgili talepleri veli yapar.
- **Ailede kayıtlı ebeveynseniz:** ParentApp › Ayarlar › KVKK başvurusu › "Kimin için?" › çocuğunuzu seçin. Ebeveyn hesabınız ve çocuğu eklerken verdiğiniz veli beyanı yeterlidir.
- **Ailede kayıtlı olmayan veli ya da vasi iseniz:** `kvkk@[ALAN ADI]`, yazılı ya da KEP yoluyla başvurun ve velayet ya da vesayetinizi gösteren belgeyi ekleyin.
- Çocuğun cihazının oyunla bağlantısını başvuru gerekmeden hemen kapatabilirsiniz: ParentApp › Aile › çocuk › Cihaz bağlantısını kaldır. Çocuğun profilinin ve ona bağlı verilerin (görevler, mesajlar, oyun kaydı) silinmesini bu sayfadaki yollarla isteyebilirsiniz; ailenin tamamı için hesabınızı silmeniz yeterlidir.

## 8. Uzmanla ilgili kayıtlar: kime başvurursunuz?

| Kayıt | Kime |
|---|---|
| Uzmanın danışanı hakkında girdiği notlar, hedefler, haftalık değerlendirmeler, takip planı | [SEÇENEK A: Bu kayıtların veri sorumlusu uzman ya da kliniğidir. Başvurunuzu uzmanınıza ya da kliniğine yapın. Bize gelirse kliniğe iletir ve size bildiririz; kliniğe teknik olarak yardım ederiz.] [SEÇENEK B: Bize ya da kliniğe başvurabilirsiniz; ikimiz de yanıtlarız.] |
| Uzmanla paylaşımı durdurmak | Başvuru gerekmez: ParentApp › Uzmanım |
| Uzmanın sizi davet ederken girdiği bilgiler (adınız, e-postanız, çocuğun adı ve yaş grubu) | Davet kaydı kullanılmazsa en geç 3 gün, bağlanıp onaylanmazsa en geç 30 gün içinde kendiliğinden silinir. Daha önce silinmesini isterseniz bize yazın |
| Uzmanın kendi hesabı ve belge incelemesi (uzmanlar için) | Bize |
| Ebeveynin girdiği kayıtlar (görevler, zor anlar, takip planı uygulama kayıtları) | Bize |

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

Başvurunuzu, kanalını, türünü, açıklamanızı, durumunu, tarihlerini ve yanıt özetini kayıt altına alırız. Bu kaydı yalnız yetkili ekip üyeleri görür; her işlem denetim kaydına geçer. Başvuru kapandıktan sonra [SÜRE] saklanır.

Yürürlük: [TARİH] · Sürüm: v1 · [ŞİRKET UNVANI], [ADRES] · `kvkk@[ALAN ADI]`
$md$)
on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,
  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md
where public.legal_documents.status = 'draft';
