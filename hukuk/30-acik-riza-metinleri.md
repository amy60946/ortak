# ParentApp Açık Rıza Metinleri
| Anahtar | — (her rıza kendi anahtarıyla: `saglik-yanit-v1`, `uzman-paylasim-v1`, `uzman-gecis-v1`) | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | ParentApp: tanışma (sağlık sorularından önce), uzman davet ekranı, çocuk seçme ekranı ve Uzmanım bölümü | Dayanak | KVKK md. 3/1-a (açık rıza tanımı), md. 4, 5/1, 6/2, 10, 11; Aydınlatma Yükümlülüğü Tebliği (aydınlatma ile rıza ayrı yapılır); Kurul'un açık rıza rehberi |

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

## Avukata notlar

1. **`uzman-paylasim-v1` sürümü:** bugün bu adla alınan onaylar yalnız uyarı (E) + "Bu uzmanı tanıyorum ve çocuğun velisiyim" beyanını içeriyor; neyin, kimle paylaşıldığını söyleyen bir rıza cümlesi ve kısa aydınlatma ekranda yok. Bu onaylar açık rıza için yeterli mi, yoksa canlıdan önce `uzman-paylasim-v2` ile **yeniden onay** mı alınmalı? Ayrıca veli beyanı ile rızanın tek kutu + tek düğmede birleşmesi uygun mu, yoksa ayrı bir "açık rıza veriyorum" kutusu mu gerekir?
2. **Önceden işaretli seçenek:** `akislar.md` 11 #2'ye göre "Önceki uzmanın kayıtlarını da paylaş" seçeneği bugün **varsayılan açık**. Açık rızanın "özgür irade ve açık beyan" şartıyla çelişir; bu taslakta işaretsiz yazıldı (ParentApp'te yazılım değişikliği gerekir).
3. **Klinik premium teşviki:** çocuğu ücretli bir klinikle paylaşan aile tam özellikleri ücretsiz alıyor (`family_premium`). Bu, sağlık verisini paylaşma rızasının özgürlüğünü zedeler mi?
4. **Sağlık yanıtlarının amacı belirsiz:** olgularda tanı/ilaç yanıtlarının uygulamada somut olarak neye yaradığı yazmıyor ("kişiselleştirme"). KVKK md. 4 (belirli, açık ve meşru amaç, ölçülülük) için amaç somut yazılmalı; kullanılmıyorsa soru kaldırılmalı. Ayrıca bu yanıtların uzmana hiç görünmediği ParentApp'in tanışma SQL'inde (`20261027120000`, ortakta yok) teyit edilmeli; 1.1'deki "uzmanla paylaşılan kayıtların arasında değildir" cümlesi buna dayanıyor.
5. **Sağlık sınırı:** "Çocuk bir psikolog, psikiyatrist ya da terapistle çalışıyor mu?" ve davranış sıklığı soruları (öfke nöbeti, endişe, dikkat isteyen işlerden kaçınma) bugün rızasız alınıyor. Sağlık verisi sayılırsa `saglik-yanit-v2` kapsamına girmeli. Zor an kayıtları için de ayrı rıza gerekip gerekmediği (`10-aydinlatma-ebeveyn.md` not 1).
6. **Yurt dışında saklama:** sağlık verisi yurt dışındaki sunucuda tutulacak; bu taslakta yurt dışı aktarım rızası işleme rızasıyla birleştirilmedi, yalnız bilgi olarak yazıldı. 2024 sonrası md. 9'da standart sözleşme yeterli mi, yoksa sağlık verisi için ayrı açık rıza mı gerekir (`hukuk_notlari.md` I2)?
7. **`uzman-gecis-v1` (B) metni:** (a) "Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez" kesin bir ifade; metindeki adların gizlenmesi "en iyi çaba" (yazım hatalı ya da kısaltılmış ad yakalanmayabilir) — ifade yumuşatılmalı mı (sürüm v2 olur)? (b) Ebeveyn, hiç görmediği notların aktarımına rıza veriyor; rıza "bilgilendirmeye dayalı" sayılır mı? (c) Önceki uzmana aktarım anında bildirim gerekir mi (`hukuk_notlari.md` 5. bölüm soru 2)?
8. **Geri almanın sonucu:** paylaşım durdurulunca uzmanın kendi notları klinikte kalıyor. Rıza geri alınınca bu notların silinmesi ya da anonimleştirilmesi gerekir mi (KVKK md. 7), yoksa uzmanın mesleki kayıt saklama yükümlülüğü mü önce gelir? Veri sorumlusunun kim olduğuna bağlı.
9. **Kimin rızası:** rızalar onaylayan tek ebeveynle kaydediliyor; diğer velinin bilgisi F5 beyanına dayanıyor. Ayrıca 13 yaş ve üstü çocuğun (yaş grubu C) kendi görüşü alınmalı mı?
