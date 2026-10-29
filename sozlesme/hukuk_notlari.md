# Hukuk notları — uzman daveti, çocuk önerisi, kayıt aktarımı, sorumluluk

> **Tam metin taslakları artık `hukuk/` klasöründe** (hukuk arşivi, dizin `hukuk/README.md`, 27 Ekim 2026). Bu dosya karar notları ve avukata sorular olarak kalır; maddeler oradaki metinlere işlendi.

> Taslak (26 Ekim 2026, kullanıcı istekleri). Avukata gidecek **madde önerileridir, hukuki görüş değildir.** Canlıda açılmadan önce hukuk onayı gerekir. Yeri: `CANLIYA_ALMA.md` 1.5 (Uzman Hizmet Sözleşmesi + Veri İşleme Eki, Açık Rıza Metni, Aydınlatma Metni). Akış: `akislar.md` 11.

Amaçlar: (1) ebeveyn çocuğunun takibini başka bir uzmana taşıdığında önceki uzmanın kayıtları yeni uzmana kesintisiz geçsin, önceki uzmanın kimliği gizli kalsın; (2) uzmanın davette girdiği çocuk bilgisi aile onaylamadan önce sunucuda durabilsin; (3) uzman kimliği doğrulanmadığı için yetki, onay ve doğrulama yükümlülüğü sözleşmeyle ebeveyne ve uzmana yazılsın, işletme korunsun. Aktarım için iki dayanak birlikte gerekir: **uzmanın sözleşmeyle verdiği izin** ve **ebeveynin açık rızası**.

## 1. Ne aktarılır, ne gizlenir

| Kayıt | Kimin girdisi | Yeni uzmana | Gizlenen |
|---|---|---|---|
| Notlar | Önceki uzman | Salt okunur, tarihli | Uzman ve klinik adı (metinde geçerse "[önceki uzman]") |
| Hedefler ve haftalık değerlendirmeler | Önceki uzman | Salt okunur | Aynı |
| Görev önerileri ve ailenin kararı | Önceki uzman, ebeveyn | Salt okunur | Aynı |
| Aile programı ve uygulama kayıtları | Önceki uzman, ebeveyn | Salt okunur | Aynı |
| Önceki uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgisi | — | **Aktarılmaz** | Tamamı; yeni uzman "Önceki uzman 1" ve dönem (ay) görür |
| Görevler, tamamlamalar, zor anlar | Ebeveyn, çocuk | Paylaşım açılınca zaten görünür | — |
| Posta, coin defteri | Aile | Aktarılmaz | — |

## 2. Dayanak özeti (avukat doğrulayacak)

- **Özel nitelikli veri:** çocuğun davranış ve gelişim kayıtları ile uzman notları sağlık verisi sayılabilir (KVKK md. 6). Aktarımın dayanağı ebeveynin (veli) **açık rızası**; rıza belirli konuya ilişkin, bilgilendirmeye dayalı ve özgür iradeyle verilmeli.
- **Aydınlatma:** rıza ekranından önce kısa aydınlatma (amaç, alıcı, yöntem, haklar; KVKK md. 10).
- **Geri alma:** ebeveyn rızayı istediği an geri alır; erişim hemen biter (KVKK md. 11 hakları).
- **Ölçülülük:** önceki uzmanın kendi kişisel verisi (adı, unvanı, kliniği) aktarıma konu edilmez; yalnız çocuğa ilişkin kayıtlar geçer (KVKK md. 4).
- **Roller:** önerimiz, notlar için klinik/uzmanın **veri sorumlusu**, platformun **veri işleyen** olması. Uzman, sözleşmeyle "ebeveyn isterse kayıtların adsız olarak sonraki uzmana açılması" talimatını önceden verir. Alternatif: platform ve klinik ayrı veri sorumluları. Seçim avukatın.
- **Meslek etiği:** psikolog ve terapistlerin meslek etik kurallarının, danışan (veli) onayıyla kayıt paylaşımına izin verdiği meslek örgütüyle doğrulanmalı.

## 3. Taslak maddeler

### A. Uzman Hizmet Sözleşmesi + Veri İşleme Eki

1. **Kayıtların niteliği.** Uzmanın ClinicApp'e girdiği notlar, hedefler, değerlendirmeler, görev önerileri ve aile programı, ebeveynin rızasıyla paylaşılan çocuğa ilişkin kayıtlardır.
2. **Süreklilik için aktarım.** Ebeveyn çocuğun takibini başka bir uzmana taşıdığında ve açıkça izin verdiğinde, bu kayıtlar sonraki uzmana salt okunur olarak açılabilir. Uzman bu aktarıma izin verir.
3. **Kimliğin gizlenmesi.** Aktarımda uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgisi gösterilmez; kayıtlarda geçen uzman ve klinik adları otomatik gizlenir. Uzman, serbest metin alanlarına kendisinin ya da başka kişilerin kimlik bilgisini yazmamayı kabul eder.
4. **Değiştirilmezlik.** Sonraki uzman aktarılan kayıtları değiştiremez ve silemez; kayıtlar tarihleriyle, aktaran uzmanın o tarihteki gözlemi olarak gösterilir.
5. **Rızanın geri alınması.** Ebeveyn izni geri alınca sonraki uzmanın erişimi derhal sona erer.
6. **Hesabın kapanması.** Uzman hesabını silerse ya da klinik kapanırsa kayıtların akıbeti avukatla belirlenecek (bkz. 5. bölüm). Bugünkü sistem: tek kişilik klinik silinince kayıtları da silinir ve aktarım biter.
7. **Sorumluluk.** Aktarılan kayıtlar tanı değildir. Sonraki uzman kendi mesleki değerlendirmesinden sorumludur.
8. **Saklama.** Paylaşım bittikten sonra kayıtların saklama süresi ve imhası Veri İşleme Eki'nde yazılır.
9. **Davette çocuk bilgisi (aile onayından önce).** Uzman, aileyi davet ederken çocuğun yalnız adını ya da takma adını ve yaş grubunu girebilir; doğum tarihi, tanı, sağlık bilgisi, fotoğraf girmez. Uzman, bu bilgiyi girmeden önce ebeveynle görüştüğünü ve daveti onun bilgisiyle gönderdiğini beyan eder. Platform bu bilgiyi uzman adına ve yalnız daveti iletmek ve ebeveynin onayına sunmak amacıyla tutar; ebeveyn onaylayana kadar başka hiçbir amaçla işlemez. Ebeveyn onaylamaz, reddeder ya da davet süresi dolarsa bilgi silinir (bağlanmamış davette 3 gün, bağlanmış ama onaylanmamışta en geç 30 gün). Bilginin yanlış ya da hukuka aykırı girilmesinden uzman sorumludur.
10. **Uzmanın beyan ve taahhütleri.** Uzman; kimliğinin, mesleki unvanının ve yetkisinin doğru olduğunu, mesleğini mevzuata uygun icra ettiğini, yalnız tanıdığı ve hizmet verdiği ailelere davet gönderdiğini, davet bağlantısını yalnız ilgili ebeveyne ilettiğini beyan eder. Gerçeğe aykırı beyan ya da kötüye kullanım hâlinde hesap derhal kapatılabilir, ilgili kayıtlar yetkili mercilerle paylaşılabilir ve uzman doğan zararı tazmin eder.
11. **Belge incelemesi.** Platform uzmanın kimliğini ve meslek icra yetkisini doğrulamaz. Uzman isterse mezuniyet belgesini (e-Devlet barkodlu) ya da BACB sicil numarasını yükler; platform belgenin e-Devlet'te ya da BACB sicilinde kayıtlı olduğunu ve belgedeki ad, bölüm ve derecenin beyanla uyduğunu inceler. Sonuç ailelere yalnız **"Belgesi incelendi: <meslek>"** olarak gösterilir; bu ifade kimlik doğrulaması, yetki onayı ya da hizmet kalitesi taahhüdü değildir. Gerçeğe aykırı belge ya da beyan madde 10'a tabidir; platform rozeti her an askıya alabilir.
12. **Belgenin işlenmesi.** Uzman, yüklediği belgenin yalnız bu inceleme için işlenmesini kabul eder: belge kendi sunucumuzda okunur (yapay zekâ ya da dış hizmet kullanılmaz), yalnız yetkili ekip üyesi görür ve her görüntüleme kayda geçer, karar verilince, başvuru kendiliğinden geri çevrilince, yeni belgeyle değiştirilince ya da hesap silinince dosya silinir; yalnız özet (üniversite, bölüm, derece, mezuniyet yılı), karar kaydı ve aynı belgenin iki hesapta kullanılmasını önlemek için belge barkodu saklanır. Kimlik numarası saklanmaz.
13. **Davet e-postası (taslak, 26 Ekim 2026).** Uzman ebeveynin e-posta adresini, ebeveynin bilgisi dahilinde ve yalnız o aileyi davet etmek için girer. Platform bu adresi uzman adına yalnız tek bir davet e-postası (en çok 3 kez yeniden gönderim) iletmek ve ebeveyn kayıt olunca daveti eşleştirmek için kullanır; pazarlama ya da başka amaçla kullanmaz. E-posta yalnız hizmet bilgisi içerir (reklam, fiyat, kampanya yok); konu satırında unvan, metinde çocuğun adı ve sağlık bilgisi yer almaz. E-postanın altında kimin adına gönderildiği ve aydınlatma metni bağlantısı bulunur. **Avukata sorulacak:** (a) ebeveyn adresi uzmandan geldiği için aydınlatmanın ilk iletişimde (bu e-postada) yapılması yeterli mi; (b) uzman tetiklemeli davet e-postası İYS kapsamı dışında hizmet iletisi sayılır mı; (c) e-posta sağlayıcısı yurt dışında (test: Google Gmail, canlı: Resend) — yurt dışı aktarım için standart sözleşme ve bildirim.

### B. Ebeveyn açık rıza metni (ParentApp onay ekranı) — sürüm `uzman-gecis-v1`

> Çocuğum **[çocuğun adı]** için daha önce çalıştığım uzman(lar)ın ClinicApp'e girdiği notların, hedeflerin, haftalık değerlendirmelerin, görev önerilerinin, aile programının ve benim uygulama kayıtlarımın, takibin kesintisiz sürmesi amacıyla yeni uzmanım **[yeni uzmanın adı]** ile yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez. Bu izni Uzmanım bölümünden istediğim an geri alabilirim; geri aldığımda erişim hemen sona erer.

Onay düğmesi: "Önceki uzmanın kayıtlarını da paylaş (adı gizlenir)". Metin değişirse sürüm adı da değişir (`uzman-gecis-v2` …); sistem hangi sürümün onaylandığını kaydeder.

### C. Aydınlatma metinlerine eklenecekler

- **Ebeveyn aydınlatması (çocuk önerisi):** "Uzmanınız sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz kontrol edip onaylayana kadar yalnız davet kaydında tutulur ve size gösterilir; onaylamazsanız ya da davet süresi dolarsa silinir. Onayladığınızda çocuğunuzun kaydı sizin düzelttiğiniz bilgiyle oluşur ve seçtiğiniz uzmanla paylaşılır."

- **Ebeveyn aydınlatması:** amaç (takibin sürekliliği), alıcı (ebeveynin seçtiği yeni uzman), aktarılan kayıt türleri (1. bölüm), yöntem (yalnız okuma, uygulama içinden), saklama, geri alma ve başvuru yolu (`kvkk@`).
- **Uzman aydınlatması:** uzmanın kişisel verisi (adı, unvanı, kliniği) aktarıma konu edilmez; girdiği kayıtlar ebeveyn izniyle adsız olarak sonraki uzmana açılabilir.
- **Uzman aydınlatması (belge incelemesi):** amaç (ailelere "Belgesi incelendi" bilgisini göstermek), işlenen veri (mezuniyet belgesi: ad, kimlik numarası, okul, bölüm, derece, tarih; BACB sicil no), saklama (dosya karar, kendiliğinden ret, değiştirme ya da hesap silmede silinir; özet, barkod ve karar kaydı hesap süresince), erişim (yalnız yetkili ekip, iki adımlı giriş, kayıtlı), haklar ve başvuru (`kvkk@`).

### D. Kullanım koşulları

- Platform tedavi ya da ebeveyn eğitimi vermez; uzmanın kendi programını kurması için şablon sunar. Göstergeler tanı değildir.

### F. Ebeveyn Kullanım Koşulları — yetki, onay ve sorumluluk (paylaşım onayı sürüm `uzman-paylasim-v1`)

1. **Veli beyanı.** Ebeveyn, ParentApp'e eklediği ve paylaştığı çocukların velisi ya da yasal temsilcisi olduğunu, paylaşım kararını verme yetkisine sahip olduğunu beyan eder.
2. **Uzmanı tanıma yükümlülüğü.** Platform uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Ebeveyn, çocuğunun verisini paylaşmadan önce uzmanı gerçek hayatta tanıdığını ve davetin ondan geldiğini kendisi teyit eder. Paylaşım kararı ve uzman seçimi tamamen ebeveynindir.
3. **Bilgilerin doğruluğu.** Uzmanın önerdiği çocuk bilgisini kontrol etmek, gerekirse düzeltmek ve onaylamak ebeveynin sorumluluğundadır; onaylanan bilgi ebeveynin beyanı sayılır.
4. **Paylaşımın kapsamı ve geri alınması.** Ebeveyn hangi çocuğu hangi uzmanla paylaştığını, önceki uzman kayıtlarının aktarımını ve bunların ne zaman sona ereceğini kendisi yönetir; Uzmanım bölümünden istediği an durdurur.
5. **Diğer veli.** Ailede birden fazla ebeveyn varsa, paylaşımı yapan ebeveyn diğer velinin bilgisi dahilinde hareket ettiğini kabul eder.
6. **Uzmanın hizmeti.** Uzman ile aile arasındaki mesleki ilişki, ücret, randevu ve tedavi kararları platformun dışındadır; platform bu ilişkinin tarafı değildir ve uzmanın mesleki tutum ve kararlarından sorumlu değildir.
7. **Kötüye kullanım bildirimi.** Ebeveyn, tanımadığı birinden davet alırsa ya da uzmandan şüphelenirse paylaşmaz ve `destek@` adresine bildirir; platform hesabı inceler, gerekirse kapatır.
8. **Onay kaydı.** Ebeveynin onayı, onayladığı metnin sürümü ve zamanıyla kaydedilir.

### G. Platformun rolü ve sorumluluk sınırı (avukat sınırları belirleyecek)

- Platform, uzman ile aile arasında bilgi paylaşımını sağlayan bir teknoloji hizmetidir; sağlık hizmeti sunmaz, uzmanları istihdam etmez, aracılık ya da yönlendirme yapmaz.
- Uzmanın kimliği, yeterliliği ve davranışı ile ebeveynin paylaşım kararından doğan sonuçlardan, kanunun izin verdiği ölçüde sorumluluk kabul edilmez.
- **Sınırlar (taslağı yazarken bilinmesi gereken):** ağır kusur ve kasttan sorumsuzluk önceden kaldırılamaz (TBK md. 115); tüketiciye karşı tek taraflı ağır sorumsuzluk şartları "haksız şart" sayılabilir (6502 sayılı Kanun md. 5); veri güvenliği yükümlülüğü platformda kalır, sözleşmeyle ebeveyne ya da uzmana devredilemez (KVKK md. 12). Yani sözleşme sorumluluğu **paylaştırır ve belgeler**, platformu tümüyle sorumsuz kılmaz.

### E. Uygulama içi kısa metinler

- **ClinicApp › Notlar** (not alanının altında): "Ebeveyn izin verirse notların, adın gizlenerek çocuğun sonraki uzmanına okunur olarak açılabilir. Nota kimlik bilgisi yazma."
- **ClinicApp › devralınan kayıtlar:** "Önceki uzman 1 · Mart 2026 – Ekim 2026 · ebeveynin izniyle, yalnız okuma".
- **ClinicApp › davet formu (çocuk önerisi):** alan "Çocuğun adı" + yaş grubu; altında "Yalnız daveti kabul eden ebeveyn görür. Sağlık bilgisi yazma." Ayrıntı "i" düğmesinde: "Çocuğun adını ve yaş grubunu yazarsan yalnız daveti kabul eden ebeveyn görür; kontrol edip onaylar, düzeltirse sana bildirim gelir. Mesajda görünmez, davet bitince silinir."
- **ParentApp › davet ekranı (sürüm `uzman-paylasim-v1`):**
  > ClinicApp uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunun bilgilerini paylaşmadan önce bu uzmanı gerçek hayatta tanıdığından ve davetin ondan geldiğinden emin ol. Emin değilsen paylaşma; uzmanını bildiğin bir yoldan arayıp sor. Paylaşımı istediğin an Uzmanım bölümünden durdurabilirsin.
  >
  > ☐ Bu uzmanı tanıyorum ve çocuğun velisiyim (yasal temsilcisiyim). — kutu işaretlenmeden "Onayla ve paylaş" açılmaz. Altta: "Bu davet bana ait değil".
- **ParentApp › onay ekranı:** B'deki metin + düğme.

### I. Kullanıcının platforma verdiği aktarım ve işleme yetkileri (taslak, 27 Ekim 2026; kullanıcı isteği)

> Amaç: ebeveyn ve uzmanın, sistemin veriyi **hangi amaçla, kime ve nasıl aktarabileceğine** sözleşmede açıkça yetki vermesi. Ebeveyn Kullanım Koşulları (F) ve Uzman Hizmet Sözleşmesi (A) sonuna eklenir; aydınlatma metinleri (C) aynı listeyi kısa hâliyle içerir. Her madde onay ekranında sürümle kaydedilir (bkz. I10). **Avukat notu:** KVKK'da açık rıza hizmet şartına bağlanamaz; hizmet için zorunlu aktarımlar "sözleşmenin ifası / meşru menfaat / kanuni yükümlülük" dayanağıyla yazılır, açık rıza yalnız isteğe bağlı olanlarda (sağlık yanıtları, uzmanla paylaşım, önceki uzman kayıtları) ayrı onay kutusuyla alınır. Hangi maddenin hangi dayanağa dayanacağını avukat işaretler.

1. **Hizmet sağlayıcılarına aktarım.** Kullanıcı; verilerinin hizmetin sunulması için gereken ölçüde, platformun adına ve talimatıyla çalışan hizmet sağlayıcılara aktarılmasına yetki verir: veri barındırma ve veritabanı (Supabase), e-posta gönderimi (Resend), bildirim (Apple Push Notification), uygulama içi satın alma ve abonelik doğrulama (Apple, RevenueCat), yönetim paneli barındırma (Cloudflare). Bu sağlayıcılar veriyi yalnız bu hizmet için işler, kendi amaçlarıyla kullanmaz.
2. **Yurt dışına aktarım.** Yukarıdaki sağlayıcıların sunucuları yurt dışında olabilir. Kullanıcı, verilerinin KVKK md. 9'daki usule (standart sözleşme ve Kurul'a bildirim) uygun olarak bu sunuculara aktarılmasına yetki verir. Sağlık verisi (tanı/ilaç yanıtları, uzman notları) için ayrıca açık rıza alınır. *(Avukat: Supabase bölgesi ve standart sözleşme metni; `CANLIYA_ALMA.md` 1.6.)*
3. **Yetkili ekip erişimi.** Kullanıcı; platformun yetkili ekip üyelerinin, yalnız destek talebini yanıtlamak, güvenlik ve kötüye kullanım incelemesi, ödeme/abonelik sorunları ve kanuni yükümlülükler için hesap bilgilerine ve kullanım kayıtlarına erişebileceğini kabul eder. Erişim iki adımlı girişle, gerekçe yazılarak yapılır ve her erişim değiştirilemez denetim kaydına geçer. Mesaj içerikleri, fotoğraflar, ses kayıtları ve uzman notlarının metni ekip ekranlarında gösterilmez.
4. **Tanışma yanıtları (ParentApp ilk kurulum).** Ebeveyn; verdiği tanışma yanıtlarının (hedefler, çocuğun düzeni, ilgi alanları, motive edenler) uygulamayı kişiselleştirmek, destek vermek ve **kimliksiz toplamlar** hâlinde ürünü geliştirmek için işlenmesine, yetkili ekip üyesinin destek amacıyla gerekçeli ve kayıtlı olarak görüntülemesine yetki verir. Sağlık yanıtları (tanı, ilaç) isteğe bağlıdır, ayrı açık rızayla (`saglik-yanit-v1`) verilir, ekip ekranında varsayılan gizlidir ve toplam raporlarda gösterilmez. Ebeveyn bu yanıtları istediği an değiştirebilir ya da silebilir.
5. **Uzmanla paylaşım ve önceki uzman kayıtları.** Ebeveynin seçtiği uzmanla paylaşım (F, `uzman-paylasim-v1`) ve önceki uzman kayıtlarının aktarımı (B, `uzman-gecis-v1`) ayrı onay ekranlarıyla verilir; bu madde onların yerine geçmez, yalnız varlığını hatırlatır.
6. **Uzmanın yetkisi.** Uzman; girdiği kayıtların ebeveynin izniyle ailenin uygulamasında gösterilmesine, ebeveyn izin verirse adı gizlenerek sonraki uzmana salt okunur açılmasına (A2–A3), belge incelemesi için yüklediği belgenin yetkili ekipçe incelenmesine (A11–A12) ve karşılama anketindeki yanıtlarının kimliksiz toplamlar hâlinde ürün geliştirmede kullanılmasına yetki verir.
7. **Kullanım ve ölçüm verisi.** Kullanıcı; uygulamayı açma günü, sürüm, platform ve hangi ekranın/özelliğin kullanıldığı gibi kişisel içerik barındırmayan kullanım kayıtlarının hizmetin işleyişini ölçmek, hataları bulmak ve ürünü geliştirmek için işlenmesine yetki verir. Bu kayıtlarda serbest metin, mesaj içeriği ya da sağlık bilgisi bulunmaz; üçüncü taraf reklam ya da izleme aracı kullanılmaz.
8. **Kanuni zorunluluk.** Mahkeme, savcılık ya da yetkili kamu kurumunun usulüne uygun talebi hâlinde veriler, talep kapsamıyla sınırlı olarak bu mercilere aktarılabilir; kanunen yasak değilse kullanıcı bilgilendirilir.
9. **İşletme devri.** Platformun birleşme, devir ya da varlık satışı hâlinde veriler, aynı amaçlarla ve aynı koruma düzeyiyle devralan tarafa aktarılabilir; kullanıcı önceden bilgilendirilir ve hesabını silme hakkı saklıdır. *(Avukat: şahıs şirketi aşamasında bu maddenin geçerliliği ve bildirim süresi.)*
10. **Onay kaydı ve sürüm.** Kullanıcının hangi metni (Kullanım Koşulları, Aydınlatma, açık rızalar) hangi sürümle ve ne zaman onayladığı kaydedilir; metin değişince yeni sürüm yeniden onaylatılır. *(Yazılım: Kullanım Koşulları ve Aydınlatma onayının sürümlü kaydı henüz yok; açık rızalar sürümlü kaydediliyor — DURUM açık iş.)*
11. **Hesap silindikten sonra.** Hesap silinince kişisel veriler silinir; yalnız kanunen saklanması gereken kayıtlar (ör. ödeme kayıtları) ve değiştirilemez denetim kaydı, kişiyi doğrudan tanımlayan bilgi (e-posta) çıkarılarak saklama süresince tutulur.

## 4. Sistemdeki karşılığı (öneri `migrations/20261026100000_family_invite_links.sql`)

| Gereklilik | Nasıl |
|---|---|
| Ebeveynin açık rızası, sürümlü | `redeem_clinic_invite_children(…, p_share_history, p_consent_version)`, `clinic_link_history_set(link, açık, sürüm)` → `clinic_link_history.consent_version`, `granted_by`, `granted_at` |
| Geri alınabilir | `clinic_link_history_set(link, false)` → kayıt silinir, erişim hemen biter |
| Önceki uzmanın kimliği gizli | Yeni uzman tablolara doğrudan erişemez; yalnız `clinic_inherited_records(link)`: ad, unvan, klinik ve kimlik dönmez, "Önceki uzman n" + dönem (ay) |
| Metinde geçen adlar | Klinik adı, o kliniğin uzman adları ve en az 3 harfli ad parçaları "[önceki uzman]" ile değiştirilir (en iyi çaba: yazım hatalı ya da kısaltılmış ad yakalanmaz) |
| Salt okuma | İşlev yalnız okur; tablolarda devralan uzmana yazma kuralı yok |
| Paylaşım onayı, sürümlü (uyarı + veli beyanı) | `family_accept_invite(…, p_consent_version)` → `clinic_links.consent_version` (`consent_by`, `consent_at` zaten var) |
| Aile onayından önce çocuk bilgisi | `clinic_invites.child_name/child_age_group`; yalnız daveti bağlamış aileye görünür; onay, ret, iptal ya da süre dolunca silinir |
| Ebeveyn düzeltir, uzmana yansır | `family_accept_invite` düzeltilmiş bilgiyle çocuğu oluşturur, uzmana `invite_child_updated`; sonraki düzeltmeler `clinic_clients()` ile |
| Uzman belge incelemesi | `migrations/20261026050000_clinician_verification.sql`: belge yalnız yöneticiye açık kovada, görüntüleme denetim kaydında, karar sonrası dosya silinir, özette ad/kimlik yok; rozet `verified_as` |
| Yanlış aileye giden davet | `family_decline_invite` → davet kapanır, öneri silinir, uzmana `invite_declined` |
| Test | `test/test_family_invite_links.sql` 5. ve 6. bölüm |

## 5. Avukata sorular

1. Notlar için veri sorumlusu kim: klinik mi, platform mu, ikisi mi?
2. Ebeveynin açık rızası tek başına yeterli mi, yoksa önceki uzmanın aktarım anında ayrıca bilgilendirilmesi gerekir mi? (Bugün bildirilmiyor; sözleşmede önceden izin var.)
3. Önceki uzman hesabını silerse çocuğa ilişkin kayıtlar silinmeli mi, yoksa saklama süresince ebeveynin rızasıyla aktarılabilir kalmalı mı?
4. Saklama süresi ve imha: paylaşım bittikten sonra kaç ay/yıl?
5. Veriler yurt dışında barındırılıyorsa (Supabase bölgesi) aktarım için standart sözleşme ve Kurul'a bildirim (`CANLIYA_ALMA.md` 1.6).
6. Çocuğun belli bir yaştan sonra (ör. 15+) kendi görüşünün alınması gerekir mi?
7. Uzmanın davette çocuk adını aile onayından önce girmesi için uzman sözleşmesindeki beyan (A9) yeterli dayanak mı, yoksa aydınlatma ilk mesajda mı yapılmalı?
8. "Uzmanı tanıyorum ve veliyim" onay kutusu ile sorumluluk maddeleri (3F) tüketici mevzuatı açısından ne ölçüde geçerli; sorumluluk sınırı (3G) nasıl yazılmalı?
9. Belge incelemesi sonrası gösterilen "Belgesi incelendi" ifadesi ve inceleme kapsamı (A11) yeterince açık mı; inceleme hatasında sorumluluk nasıl sınırlanır?
10. Uzman doğrulaması yapılmadan çalışmak için ek bir yükümlülük var mı (ör. sağlık meslek mensuplarını listeleyen platformlar, uzaktan sağlık hizmetleri mevzuatı kapsamına girip girmediği)? Doğrulama seçenekleri `akislar.md` 14.
11. Bölüm I'deki her maddenin dayanağı (sözleşmenin ifası, meşru menfaat, kanuni yükümlülük, açık rıza) hangisi; hangileri ayrı onay kutusu ister?
12. Yurt dışı aktarım (I2) için 2024 KVKK değişikliği sonrası standart sözleşme yeterli mi; sağlık verisi için ek şart var mı?
13. Yetkili ekip erişimi (I3, I4): destek amaçlı kişi bazında tanışma yanıtı görüntüleme aydınlatmada açıkça yazılınca yeterli mi; sağlık yanıtları ekipçe hiç görülmemeli mi?
14. **Sosyal medyada yapay zekâ etiketi (kullanıcı kararı 29 Ekim 2026: etiket açılmaz, `hukuk/45` 8.4).** Pazarlama videoları animasyon + gerçekçi sentetik anlatıcı sesi; platformlar (Meta, TikTok, YouTube) gerçekçi YZ ses/görüntüde etiket istiyor. Bu biçimde Meta/TikTok etiketi zorunlu mu, etiketsiz paylaşımın riski ne (platform yaptırımı, hesap)? Türkiye'de reklam/tüketici mevzuatı ya da Reklam Kurulu açısından etiketsiz yayının riski ne; "yanıltıcı reklam" sayılabilir mi; şirket hesabının platform kuralını ihlali sözleşmesel risk mi? Avukat görüşüne göre karar yeniden değerlendirilir.
