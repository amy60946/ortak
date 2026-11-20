# Moyo Mercek Web Çerez Politikası
| Anahtar | cerez-clinicapp-web | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Moyo Mercek (eski ClinicApp) web sürümü ve (4 Kasım 2026'dan beri) Moyo Ebeveyn (eski ParentApp) web sürümü (`/app/`; tanıtım sayfası çerez kullanmaz): giriş sayfasının alt bilgisinde bağlantı; ilk açılışta bilgilendirme bandı (aşağıda öneri); giriş yapıldıktan sonra Ayarlar › Yasal ve gizlilik; herkese açık adres (`legal` sunucu işlevi, alan adı: `moyoapp.com.tr`) | Dayanak | KVKK md. 4, 5/2-c, 5/2-f, 10, 12; KVKK Kurumu "Çerez Uygulamaları Hakkında Rehber" (2022); Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ |

> Taslak, 27 Ekim 2026. Olgular: `hukuk/00-olgular.md`. Hukuki görüş değildir.
> 20 Kasım 2026: 14 Kasım kararları, çekirdek maddeler, Moyo adları, deneme 14 gün (sürüm v1 kaldı).

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

1.1. Bu politika, Moyo'yu işleten `[AD SOYAD]` ("Platform", "biz"; `[ADRES]`) tarafından işletilen **Moyo Mercek'in web sürümünde** kullanılan çerezleri ve benzeri tarayıcı depolama teknolojilerini anlatır.

1.2. Moyo Mercek'in iPhone ve iPad uygulaması tarayıcı çerezi kullanmaz; uygulama içindeki veri saklama Uzman Aydınlatma Metni'nde (`aydinlatma-uzman`) anlatılmıştır. Aile davet bağlantısının açılış sayfası (ebeveynlere yönelik) bu politikanın kapsamında değildir; bugünkü hâliyle çerez ya da tarayıcı depolaması kullanmaz.

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

7.1. Oturum bilgisi, kimlik doğrulama hizmet sağlayıcımız Supabase'in (Frankfurt, Almanya; AB bölgesi) sunucularında doğrulanır. Moyo Mercek web'in barındırıldığı hizmet sağlayıcısı (Cloudflare), sayfaları size iletirken IP adresi ve tarayıcı bilgisi gibi teknik bağlantı kayıtlarını işleyebilir. Hizmet sağlayıcılarımızın listesi ve yurt dışı aktarım bilgisi Uzman Aydınlatma Metni'nde ve `hukuk/41-alt-isleyenler.md`'de yer alır.

7.2. Moyo Mercek web, bu politikada sayılanlar dışında üçüncü taraf bir hizmetin tarayıcınıza çerez yerleştirmesine izin vermez.

## 8. Haklarınız ve başvuru

KVKK md. 11'deki haklarınızı ve başvuru yollarını Uzman Aydınlatma Metni'nde bulabilirsiniz. Sorularınız için: `kvkk@moyoapp.com.tr`.

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

## Avukata notlar

1. **Depolama listesinin teyidi (Klinik penceresi, 27 Ekim 2026: yapıldı; 20 Kasım 2026: yeniden tarandı):** Moyo Mercek (ClinicApp) web kodu tarandı; 3. bölümdeki tablo gerçek listedir (oturum anahtarı — kayıttaki e-posta, ad ve unvan dahil —, e-posta bağlantısı doğrulama kodu, rehber işareti, bant işareti). `sessionStorage`, çerez ve IndexedDB kullanılmıyor; kullanım ölçümünün oturum kimliği yalnız bellekte. Tanıtım sayfası Google Fonts'u dışarıdan yüklüyordu; yazı tipi sitenin kendi dosyasına alındı (dış istek yok). Web'de satın alma yok (kullanıcı kararı 22 Ekim 2026); koddaki eski iyzico ödeme formu web'de gösterilmez. 20 Kasım 2026 taramasında 27 Ekim'den sonra eklenen anahtarlar bulundu (hesap seçimi, görünüm, menü, kütüphane favorileri, hatırlatma ayarı, ipucu ve "Gördüm" işaretleri; `src/` içinde AsyncStorage anahtarları) ve tablonun son satırına toplandı; çerez ve `sessionStorage` yine yok. Kod değiştikçe yeniden taranmalı. Önizlemeye özgü `demo.*` anahtarları canlı derlemede kullanılmaz.
2. **Barındırma sağlayıcısı (7.1):** 6 Kasım 2026'dan beri Moyo Mercek web `uzman.moyoapp.com.tr` adresinde Cloudflare'da (Worker `moyo-uzman`); tanıtım sayfası `mercek.moyoapp.com.tr` (Worker `moyo-mercek`). Lansmana kadar sayfalar Cloudflare Access kilidinin arkasında; kilit, girişe izin verilen kişiler için Cloudflare'ın kendi oturum çerezini yerleştirir (kilit kalkınca kalkar). Bot koruması gibi özellikler açılırsa Cloudflare kendi zorunlu çerezlerini ekleyebilir; canlıdan önce tarayıcıda bakılıp tabloya ve alt işleyen listesine (`41`) eklenmeli.
3. **Arayüz tercihlerinin "zorunlu" sayılması (3; son satır 20 Kasım 2026'da genişledi):** Kurul rehberi, kullanıcının açıkça yaptığı seçimi hatırlayan depolamayı hangi koşulda zorunlu kabul ediyor? İşlevsel sayılırsa bu satır için onay gerekir ya da tercihler sunucuda (hesaba bağlı) tutulmalı.
4. **Rehberin güncel sürümü:** Dayanak satırında KVKK Kurumu'nun 2022 tarihli çerez rehberi anıldı; güncel sürüm ve varsa yeni Kurul kararları kontrol edilmeli.
5. **Bant gerekliliği:** Yalnız zorunlu depolama varken bant gösterilmesi zorunlu mu, yoksa alt bilgideki bağlantı yeterli mi? Öneri, şeffaflık için tek düğmeli bant.
