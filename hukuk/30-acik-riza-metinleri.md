# Moyo Ebeveyn Açık Rıza Metinleri
| Anahtar | — (her rıza kendi anahtarıyla: `uzman-paylasim-v1`, `uzman-gecis-v1`) | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Moyo Ebeveyn (ParentApp): uzman davet ekranı, çocuk seçme ekranı ve Uzmanım bölümü | Dayanak | KVKK md. 3/1-a (açık rıza tanımı), md. 4, 5/1, 6/3-a, 10, 11; Aydınlatma Yükümlülüğü Tebliği (aydınlatma ile rıza ayrı yapılır); Kurul'un açık rıza rehberi |

> Taslak, 27 Ekim 2026. Olgular: `hukuk/00-olgular.md` §3. Kaynak maddeler: `sozlesme/hukuk_notlari.md` B (ürün adı ve iş nesnesi adı dışında aynen korundu), E, F, I4–I5; akışlar `sozlesme/akislar.md` 5.3, 10, 11. Ekran metinleri uygulamanın diliyle ("sen"), rıza cümleleri birinci tekil şahısla (B'deki gibi) yazıldı. Hukuki görüş değildir.
>
> 20 Kasım 2026: 14 Kasım kararları, çekirdek maddeler, Moyo adları, deneme 14 gün (sürüm v1 kaldı). Eski 1. bölüm "Sağlık yanıtları" (`saglik-yanit-v1`, tanı ve ilaç soruları) 14 Kasım 2026'da kaldırıldı (`migrations/20261114200000_intake_observation_owner.sql`; eski yanıtlar silindi, `intake_answers.consent_version` doldurulmuyor); bölümler yeniden numaralandı (2 → 1, 3 → 2). Ekibin tanışma yanıtlarını görmesi bu metinden çıktı (o anlatım yalnız eski 1. bölümdeydi; kişi bazında yalnız panel sahibi görür, `hukuk_notlari.md` M4). Paylaşım kapsamı "uygulamada bıraktığın kayıtlar" diye yazıldı ve davranış olayları, ebeveyn eğitimi yanıtları, ders uygulama günleri, randevu yanıtları eklendi (`akislar.md` 20, 22–24). Rıza metinlerinde (E uyarısı, B metni) yalnız ürün adı ve iş nesnesi adı güncellendi; sürüm adları değişmedi (`hukuk_notlari.md` 27a).
> 20 Kasım 2026 (ikinci tur, kullanıcının avukat sorularına yanıtları): `uzman-paylasim-v1` ile devam (C.12); 1.1 "ne paylaşılır / paylaşılmaz" listesi ve rıza cümlesi Ebeveyn Aydınlatma Metni 5.3 ile aynı kapsama getirildi; 1.2'deki belge rozeti çıktı (belge yükleme kaldırıldı); "Haklar" adresi `destek@` (tek iletişim adresi).

## Kısaca

- Bu iki onay **isteğe bağlıdır.** Vermezsen Moyo Ebeveyn'i kullanmaya devam edersin.
- Onay kutuları **hiçbir zaman önceden işaretli gelmez.** Her onay kendi ekranında, kendi metniyle sorulur.
- **Uzmanla paylaşım:** yalnız seçtiğin uzman ve seçtiğin çocuk. Paylaşılanlar uygulamada bıraktığın kayıtlardır. Uzman kayıtları yalnız okur.
- **Önceki uzman kayıtları:** yeni uzmana yalnız okunur açılır; önceki uzmanın adı gizlenir.
- Her onayı **istediğin an geri alırsın;** erişim hemen biter.
- Hangi metni ne zaman onayladığın, metnin sürümüyle birlikte kaydedilir.

"Moyo" ya da "Platform": `[AD SOYAD]` tarafından işletilen uygulamaların (Moyo Ebeveyn, Moyo Oyun, Moyo Mercek) tümü; tekil ve çoğul kullanım birbirinin yerine geçer.

## Bütün rıza ekranları için ortak kurallar

1. Rıza ekranından **önce**, aynı ekranın üstünde kısa bir aydınlatma kutusu ve "Aydınlatma Metni'nin tamamı" bağlantısı (`aydinlatma-ebeveyn`) gösterilir. Aydınlatmayı okumak rıza sayılmaz.
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

Uyarı (`hukuk_notlari.md` E; yalnız ürün adı güncellendi):

> Moyo uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunun bilgilerini paylaşmadan önce bu uzmanı gerçek hayatta tanıdığından ve davetin ondan geldiğinden emin ol. Emin değilsen paylaşma; uzmanını bildiğin bir yoldan arayıp sor. Paylaşımı istediğin an Uzmanım bölümünden durdurabilirsin.

Rıza cümlesi (yeni):

> *Çocuğum [seçilen çocukların adları] ile ilgili, uygulamada bıraktığım ve yukarıda yazan kayıtların, takibini yapabilmesi için [unvan] [uzman adı] ve onun kliniğinde bu paylaşımı görmeye yetkili kişilerle (klinik sahibi ve onun görevlendirdiği ekip üyeleri) yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Mesajlarımız, coin ve Güneş Taşı hareketleri, ödüller, oyun kaydı, tanışma yanıtlarım ve kendi seçtiğim dersler paylaşılmaz. Paylaşımı Uzmanım bölümünden istediğim an durdurabilirim; durdurduğumda erişim hemen sona erer.*

### 1.3 Onay kutusu ve düğmeler

- ☐ **Bu uzmanı tanıyorum ve çocuğun velisiyim (yasal temsilcisiyim).** (`hukuk_notlari.md` E, aynen)
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
| Nerede | Moyo Ebeveyn › davet onayı / çocuk seçme ekranı (çocuk daha önce başka bir uzmanla paylaşıldıysa) ve Uzmanım › [yeni uzman] › "Önceki uzmanın kayıtları" anahtarı | Dayanak | KVKK md. 6/3-a, md. 3/1-a, md. 4, md. 10; uzmanın sözleşmeyle önceden verdiği izin (`hukuk_notlari.md` A2–A3) |

### 2.1 Önce gösterilecek kısa aydınlatma

> **Önceki uzmanın kayıtları hakkında kısa bilgi**
> - **Neden:** takibin yeni uzmanla kesintisiz sürmesi.
> - **Kime:** seçtiğin yeni uzmana ve onun kliniğinde bu paylaşımı görmeye yetkili kişilere.
> - **Ne açılır:** önceki uzman(lar)ın notları, hedefleri, haftalık değerlendirmeleri, rutin ve adım önerileri ve senin kararların, aile programı ve senin uygulama kayıtların; her biri tarihiyle. Önceki uzmanın notlarını sen görmezsin; bunlar onun o tarihteki mesleki gözlemleridir ve tanı değildir.
> - **Nasıl:** yalnız okunur, uygulamanın içinden. Yeni uzman bu kayıtları değiştiremez ve silemez.
> - **Ne gizlenir:** önceki uzmanın adı, unvanı, kliniği ve iletişim bilgileri. Yeni uzman yalnız "Önceki uzman 1" ve dönemi (ay) görür. Metinlerde geçen uzman ve klinik adları otomatik gizlenir.
> - **Ne kadar:** sen izni geri alana kadar.
> - **Haklar:** `destek@moyoapp.com.tr`. [Aydınlatma Metni'nin tamamı]

### 2.2 Ekranda gösterilecek tam metin (`hukuk_notlari.md` B; yalnız ürün adı ve iş nesnesi adı güncellendi)

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

## Avukata notlar

1. **`uzman-paylasim-v1` sürümü (kullanıcı kararı 20 Kasım 2026, C.12: v1 ile devam; metin bu kapsamı karşılayacak biçimde yazıldı, 1.6):** bugün bu adla alınan onaylar yalnız uyarı (E) + "Bu uzmanı tanıyorum ve çocuğun velisiyim" beyanını içeriyor; neyin, kimle paylaşıldığını söyleyen bir rıza cümlesi ve kısa aydınlatma ekranda yok. Bu onaylar açık rıza için yeterli mi, yoksa canlıdan önce `uzman-paylasim-v2` ile **yeniden onay** mı alınmalı? Ayrıca veli beyanı ile rızanın tek kutu + tek düğmede birleşmesi uygun mu, yoksa ayrı bir "açık rıza veriyorum" kutusu mu gerekir?
2. **Önceden işaretli seçenek:** `akislar.md` 11 #2'ye göre "Önceki uzmanın kayıtlarını da paylaş" seçeneği bugün **varsayılan açık**. Açık rızanın "özgür irade ve açık beyan" şartıyla çelişir; bu taslakta işaretsiz yazıldı (ParentApp'te yazılım değişikliği gerekir).
3. **Klinik premium teşviki:** çocuğu ücretli bir klinikle paylaşan aile tam özellikleri ücretsiz alıyor (`family_premium`). Bu, özel nitelikli veri içerebilecek kayıtları paylaşma rızasının özgürlüğünü zedeler mi?
4. **Paylaşım kapsamındaki yeni kalemler:** davranış olayları, ebeveyn eğitimi yanıtları (modül tamamlama, test ve açık uçlu yanıtlar, uygulama kayıtları, yapılacaklar), uzmanın önerdiği derslerdeki uygulama günleri ve randevu yanıtları uzmanla paylaşım içinde oluşur ve uzmana görünür (`akislar.md` 20, 22–24). Bu taslakta 1.1'deki listeye yazıldı. Bunlar `uzman-paylasim-v1` ile verilmiş onayların kapsamında mı, yoksa ekrandaki metinle birlikte yeni sürüm ve yeniden onay mı gerekir (`hukuk_notlari.md` 26a)? ParentApp'teki "Paylaşılır" listesi (ⓘ) bu listeyle eşitlenmeli. 20 Kasım 2026: 1.1 listesi ve rıza cümlesi Ebeveyn Aydınlatma Metni 5.3 ile madde madde karşılaştırıldı ve eşitlendi (eklenenler: atamalar, eğitim yanıtlarının ayrıntısı, randevu notu, önceki kayıt geçmişi; rıza cümlesindeki "paylaşılmaz" listesine "kendi seçtiğim dersler").
5. **Tanışma sorularının sınırı:** tanı ve ilaç soruları 14 Kasım 2026'da kalktı. Kalan "Çocuk bir psikolog, psikiyatrist ya da terapistle çalışıyor mu?" ve davranış sıklığı soruları (öfke nöbeti, endişe, dikkat isteyen işlerden kaçınma; 14 Kasım'da eklenen iki günlük davranış maddesi) rızasız alınıyor ve uzmana gitmiyor. Özel nitelikli veri sayılırlarsa ayrı açık rıza gerekir mi? Davranış kayıtları için de ayrı rıza gerekip gerekmediği (`10-aydinlatma-ebeveyn.md` not 1).
6. **Yurt dışında saklama:** özel nitelikli veri içerebilecek kayıtlar yurt dışındaki sunucuda tutulacak; bu taslakta yurt dışı aktarım rızası işleme rızasıyla birleştirilmedi, yalnız bilgi olarak yazıldı. 2024 sonrası md. 9'da standart sözleşme yeterli mi, yoksa özel nitelikli veri için ayrı açık rıza mı gerekir (`hukuk_notlari.md` I2)?
7. **`uzman-gecis-v1` (B) metni:** (a) "Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez" kesin bir ifade; metindeki adların gizlenmesi "en iyi çaba" (yazım hatalı ya da kısaltılmış ad yakalanmayabilir) — ifade yumuşatılmalı mı (sürüm v2 olur)? (b) Ebeveyn, hiç görmediği notların aktarımına rıza veriyor; rıza "bilgilendirmeye dayalı" sayılır mı? (c) Önceki uzmana aktarım anında bildirim gerekir mi (`hukuk_notlari.md` 5. bölüm soru 2)?
8. **Geri almanın sonucu:** paylaşım durdurulunca uzmanın kendi notları klinikte kalıyor. Rıza geri alınınca bu notların silinmesi ya da anonimleştirilmesi gerekir mi (KVKK md. 7), yoksa uzmanın mesleki kayıt saklama yükümlülüğü mü önce gelir? Veri sorumlusunun kim olduğuna bağlı (kullanıcı kararı 20 Kasım 2026: uzman kayıtlarında uzman veri sorumlusu, Moyo veri işleyen; silme talebi bu kayıtlar için uzmana yönelir).
9. **Kimin rızası:** rızalar onaylayan tek ebeveynle kaydediliyor; diğer velinin bilgisi F5 beyanına dayanıyor. Ayrıca 13 yaş ve üstü çocuğun (yaş grubu C) kendi görüşü alınmalı mı?
10. **Madde numarası:** 7499 sayılı Kanun (1 Haziran 2024) sonrası özel nitelikli veride açık rıza md. 6/3-a; önceki taslaktaki "md. 6/2" atıfları buna çevrildi. Avukat teyidi.
11. **Açık rıza sözleşmeye gömülmez (kullanıcı, C.11):** Moyo Ebeveyn Kullanım Koşulları 6.3 bu ekranın varlığını ve kapsamını bildirir, rızanın kendisi bağlanma anında bu ekranda ayrıca alınır (ortak kural 4). Uzman Hizmet Sözleşmesi 7.4: uzman ailenin açık rızası olmadan hiçbir kaydı göremez.
