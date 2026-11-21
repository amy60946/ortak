# Hizmet Sağlayıcılar (Alt İşleyenler) Listesi
| Anahtar | alt-isleyenler | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Herkese açık adres (`legal` sunucu işlevi, alan adı: `https://moyoapp.com.tr/yasal/alt-isleyenler`); Gizlilik Politikası 10. bölümden ve aydınlatma metinlerinden bağlantı; Uzman Hizmet Sözleşmesi Veri İşleme Eki'nden atıf; üç uygulamada Ayarlar › Yasal metinler | Dayanak | KVKK md. 9 (7499 s. Kanun ile 2024 değişikliği), md. 10, md. 11/1-ç, md. 12/2; Kişisel Verilerin Yurt Dışına Aktarılmasına İlişkin Usul ve Esaslar Hakkında Yönetmelik (2024) |

> Taslak (iç not, yayımlanmaz). 20 Kasım 2026: 14 Kasım kararları, çekirdek maddeler, Moyo adları, deneme 14 gün (sürüm v1 kaldı).
> 20 Kasım 2026 (ikinci tur, kullanıcının avukat sorularına yanıtları): aktarım amacı başa yazıldı (Kısaca), Moyo/Platform tanımı (1), Supabase satırında belge ve "özel nitelikli" nitelendirmesi çıktı (3.1), tek iletişim adresi `destek@`.

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

## Avukata notlar

1. **Standart sözleşme pratiği:** Supabase, Apple, RevenueCat, Resend ve Cloudflare gibi yabancı şirketlerin Kurul'un Türkçe standart sözleşmesini değiştirmeden imzalaması pratikte zor olabilir. İmzalamazlarsa hangi yol kalır (bağlayıcı şirket kuralları, arızi aktarım istisnası, açık rıza)? Kurul'a bildirimin veri sorumlusunca mı veri işleyence mi yapılacağı ve tek bildirimle birden çok sağlayıcının kapsanıp kapsanamayacağı.
2. **Apple'ın rolü:** Satışta bağımsız veri sorumlusu, APNs'te alt işleyen olarak yazıldı. Bu ayrım ve APNs için ayrıca sözleşme/güvence gerekip gerekmediği. Bildirim metninde çocuk adı geçiyor; bildirim içeriğini en aza indirmek (ör. "Yeni bir bildirimin var") tercih edilebilir — ürün kararı.
3. **Expo yedek yolu ve planlanan araçlar:** Expo Push (`00-olgular.md` §5) canlıda kapatılacak mı, yoksa listede mi kalacak? Kalırsa standart sözleşme gerekir. `CANLIYA_ALMA.md` 4'te planlanan Sentry ve PostHog eklenirse bu liste, gizlilik politikası ve ClinicApp web çerez onayı önceden değişmeli.
4. **Uzmana itiraz hakkı ve süre (6. bölüm):** kullanıcı kararı (20 Kasım 2026, A.4): uzman kayıtlarında uzman veri sorumlusu, Moyo veri işleyen (gizlilik 4. bölüm; A/B kapandı); bu kural Veri İşleme Eki'nin parçasıdır. Süre (öneri 30 gün) ve fesih sonucu onaylanmalı; bildirim süresi saklama süresi olmadığı için `[SÜRE]` kaldı (6. bölümde iki yer).
5. **Test dönemi Gmail:** Test e-postalarının gerçek kişilere (pilot uzman ve aileler) gitmesi durumunda bu dönem için de aktarım güvencesi gerekip gerekmediği.
6. **20 Kasım 2026 güncellemesi (iç not; koordinatör doğrulamalı):** Cloudflare satırı (alan adı ve DNS, Moyo Mercek web uygulaması, tanıtım ve davet sayfaları) ile RevenueCat ve Resend'in "Kullanımda" durumu `DURUM.md` kayıtlarına (6, 10, 11 Kasım 2026) göre yazıldı; `00-olgular` §5 hâlâ yalnız "yönetim paneli barındırma" diyor, güncellenmeli. Moyo Mercek web uygulaması Cloudflare'den yalnız dosya olarak sunulur, uygulama verisi tarayıcıdan doğrudan Supabase'e gider (yönetim paneli için de aynı mı, teyit edilmeli: 3.6 "panelde görüntülenen kullanıcı verisi Cloudflare ağından geçer" diyor). Kullanıcı kararı (20 Kasım 2026): her konu için tek e-posta `destek@moyoapp.com.tr` (`kvkk@` kullanılmaz); Cloudflare Email Routing yalnız `destek@`'i yönlendirir. Kurulursa KVKK başvuruları ve destek yazışmaları Cloudflare'den geçer; o zaman 3.6'ya eklenmeli.
7. **Seans ve takvim (olgularda yok):** Uzmanın dış takvim aboneliği (`sozlesme/akislar.md` 20 E) seans bilgisini (tür, isteğe bağlı baş harf) uzmanın seçtiği takvim hizmetine (Google, Apple, Microsoft) taşır; içe aktarmada sunucumuz uzmanın gizli iCal adresini okur. Bunlar uzmanın kendi seçtiği hizmetler: alt işleyen mi, 4. bölümde alıcı mı, yoksa uzmanın kendi aktarımı mı; bir satır gerekir mi.
8. **Uzmanın itirazında dışa aktarma:** 6. bölümdeki "kayıtlarını dışa aktarır" sözü Uzman Hizmet Sözleşmesi'nin daraltılan diliyle uyum için çıkarıldı (Moyo arşiv ya da dışa aktarma hizmeti taahhüt etmez; uygulamadaki rapor ve CSV araçları ayrıca durur). Fesih sonucunun Veri İşleme Eki'yle aynı yazılması gerekir.
9. **Yurt dışı aktarım ve Kurul bildirimi (kullanıcı, C.13; 20 Kasım 2026):** aktarımın amacının hizmeti çalıştırmak olduğu Kısaca'da başa yazıldı. Kullanıcı görüşü: Kurul bildirimi gerekmez; KVKK md. 9 standart sözleşme bildirimi (imzadan sonra 5 iş günü) yasal yükümlülük olabilir, teyit avukatta. Metindeki bildirim cümleleri olduğu gibi bırakıldı.
10. **Konum (3.1; kullanıcı, A.2):** Supabase satırında kayıtlar "özel nitelikli veri içerebilecek kayıtlar" diye nitelenmiyor, "kullanıcıların kendi girdiği takip kayıtları" deniyor; 6. bölümdeki "özel nitelikli veri içerebilecek kayıtları kapsıyorsa yeniden onay" kuralı koruma ağı olarak kaldı. md. 6 kapsamının teyidi avukatta.
