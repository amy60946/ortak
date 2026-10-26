# Hukuk notları — uzman daveti, çocuk önerisi, kayıt aktarımı, sorumluluk

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
9. **Davette çocuk bilgisi (aile onayından önce).** Uzman, aileyi davet ederken çocuğun yalnız adını ya da takma adını ve yaş grubunu girebilir; doğum tarihi, tanı, sağlık bilgisi, fotoğraf girmez. Uzman, bu bilgiyi girmeden önce ebeveynle görüştüğünü ve daveti onun bilgisiyle gönderdiğini beyan eder. Platform bu bilgiyi uzman adına ve yalnız daveti iletmek ve ebeveynin onayına sunmak amacıyla tutar; ebeveyn onaylayana kadar başka hiçbir amaçla işlemez. Ebeveyn onaylamaz, reddeder ya da davet süresi dolarsa bilgi silinir (bağlanmamış davette 48 saat, bağlanmış ama onaylanmamışta en geç 30 gün). Bilginin yanlış ya da hukuka aykırı girilmesinden uzman sorumludur.
10. **Uzmanın beyan ve taahhütleri.** Uzman; kimliğinin, mesleki unvanının ve yetkisinin doğru olduğunu, mesleğini mevzuata uygun icra ettiğini, yalnız tanıdığı ve hizmet verdiği ailelere davet gönderdiğini, davet bağlantısını yalnız ilgili ebeveyne ilettiğini beyan eder. Gerçeğe aykırı beyan ya da kötüye kullanım hâlinde hesap derhal kapatılabilir, ilgili kayıtlar yetkili mercilerle paylaşılabilir ve uzman doğan zararı tazmin eder.
11. **Doğrulama.** Platform, aksi açıkça belirtilmedikçe uzmanın kimliğini ve mesleki belgelerini doğrulamaz; ileride belge incelemesi yapılırsa "Doğrulanmış uzman" ifadesi yalnız incelenen belgeyi kapsar.

### B. Ebeveyn açık rıza metni (ParentApp onay ekranı) — sürüm `uzman-gecis-v1`

> Çocuğum **[çocuğun adı]** için daha önce çalıştığım uzman(lar)ın ClinicApp'e girdiği notların, hedeflerin, haftalık değerlendirmelerin, görev önerilerinin, aile programının ve benim uygulama kayıtlarımın, takibin kesintisiz sürmesi amacıyla yeni uzmanım **[yeni uzmanın adı]** ile yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez. Bu izni Uzmanım bölümünden istediğim an geri alabilirim; geri aldığımda erişim hemen sona erer.

Onay düğmesi: "Önceki uzmanın kayıtlarını da paylaş (adı gizlenir)". Metin değişirse sürüm adı da değişir (`uzman-gecis-v2` …); sistem hangi sürümün onaylandığını kaydeder.

### C. Aydınlatma metinlerine eklenecekler

- **Ebeveyn aydınlatması (çocuk önerisi):** "Uzmanınız sizi davet ederken çocuğunuzun adını ve yaş grubunu girmiş olabilir. Bu bilgi siz kontrol edip onaylayana kadar yalnız davet kaydında tutulur ve size gösterilir; onaylamazsanız ya da davet süresi dolarsa silinir. Onayladığınızda çocuğunuzun kaydı sizin düzelttiğiniz bilgiyle oluşur ve seçtiğiniz uzmanla paylaşılır."

- **Ebeveyn aydınlatması:** amaç (takibin sürekliliği), alıcı (ebeveynin seçtiği yeni uzman), aktarılan kayıt türleri (1. bölüm), yöntem (yalnız okuma, uygulama içinden), saklama, geri alma ve başvuru yolu (`kvkk@`).
- **Uzman aydınlatması:** uzmanın kişisel verisi (adı, unvanı, kliniği) aktarıma konu edilmez; girdiği kayıtlar ebeveyn izniyle adsız olarak sonraki uzmana açılabilir.

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
- **ClinicApp › davet formu (çocuk önerisi):** "Ebeveyn kayıt olunca bilgiler hazır gelir; kontrol edip onaylar, gerekirse düzeltir. Düzeltirse sana bildirim gelir. Yalnız ad/takma ad ve yaş grubu gir; tanı ya da sağlık bilgisi yazma."
- **ParentApp › davet ekranı (sürüm `uzman-paylasim-v1`):**
  > ClinicApp uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunun bilgilerini paylaşmadan önce bu uzmanı gerçek hayatta tanıdığından ve davetin ondan geldiğinden emin ol. Emin değilsen paylaşma; uzmanını bildiğin bir yoldan arayıp sor. Paylaşımı istediğin an Uzmanım bölümünden durdurabilirsin.
  >
  > ☐ Bu uzmanı tanıyorum ve çocuğun velisiyim (yasal temsilcisiyim). — kutu işaretlenmeden "Onayla ve paylaş" açılmaz. Altta: "Bu davet bana ait değil".
- **ParentApp › onay ekranı:** B'deki metin + düğme.

## 4. Sistemdeki karşılığı (öneri `proposed/20261026100000_family_invite_links.sql`)

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
9. Uzman doğrulaması yapılmadan çalışmak için ek bir yükümlülük var mı (ör. sağlık meslek mensuplarını listeleyen platformlar, uzaktan sağlık hizmetleri mevzuatı kapsamına girip girmediği)? Doğrulama seçenekleri `akislar.md` 14.
