# Hizmet Sağlayıcılar (Alt İşleyenler) Listesi
| Anahtar | alt-isleyenler | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | Herkese açık adres (`legal` sunucu işlevi, alan adı alınınca `https://[ALAN ADI]/alt-isleyenler`); Gizlilik Politikası 10. bölümden ve aydınlatma metinlerinden bağlantı; Uzman Hizmet Sözleşmesi Veri İşleme Eki'nden atıf; üç uygulamada Ayarlar › Yasal metinler | Dayanak | KVKK md. 9 (7499 s. Kanun ile 2024 değişikliği), md. 10, md. 11/1-ç, md. 12/2; Kişisel Verilerin Yurt Dışına Aktarılmasına İlişkin Usul ve Esaslar Hakkında Yönetmelik (2024) |

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
| 4 | RevenueCat | Alt işleyen | Abonelik durumunun doğrulanması | ParentApp (ClinicApp kullanmaz; App Store'u doğrudan doğrular) | ABD | Kurulum aşamasında |
| 5 | Resend | Alt işleyen | İşlem e-postaları | ParentApp, ClinicApp | ABD / AB | Alan adı alınınca |
| 6 | Cloudflare | Alt işleyen | Ekip yönetim panelinin barındırılması | Ekip paneli | Küresel ağ | Kullanımda |
| 8 | iyzico | Ödeme hizmetinde bağımsız veri sorumlusu (ödeme kuruluşu, 6493 s. Kanun); öneri | ClinicApp web üyelik ödemesi | ClinicApp web | Türkiye | Kodda var; canlıda kapalı |
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
| İlgili kişiler | Abone olan ebeveynler |
| Konum | ABD |
| Aktarım güvencesi | [standart sözleşme imzalanacak] + Kurul'a bildirim |

### 3.4a iyzico (ClinicApp web ödemesi)

| | |
|---|---|
| Rol | Ödeme hizmetinde bağımsız veri sorumlusu (lisanslı ödeme kuruluşu); öneri, avukat teyit edecek |
| Amaç | ClinicApp web sürümünde üyelik ödemesinin alınması, yenilenmesi ve iptali |
| Veri | Klinik sahibinin adı, soyadı, e-postası, T.C. kimlik numarası, cep telefonu, fatura adresi (şehir, adres) ve kart bilgisi. Kart bilgisi yalnız iyzico'nun ödeme formuna girilir, bize gelmez. T.C. kimlik no, telefon ve adres sunucumuzdan iyzico'ya iletilir, bizde saklanmaz. |
| İlgili kişiler | ClinicApp web'den üyelik alan klinik sahipleri |
| Konum | Türkiye |
| Aktarım güvencesi | Yurt içi aktarım (KVKK md. 8); yurt dışı aktarım yok |

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

## Avukata notlar

1. **Standart sözleşme pratiği:** Supabase, Apple, RevenueCat, Resend ve Cloudflare gibi yabancı şirketlerin Kurul'un Türkçe standart sözleşmesini değiştirmeden imzalaması pratikte zor olabilir. İmzalamazlarsa hangi yol kalır (bağlayıcı şirket kuralları, arızi aktarım istisnası, açık rıza)? Kurul'a bildirimin veri sorumlusunca mı veri işleyence mi yapılacağı ve tek bildirimle birden çok sağlayıcının kapsanıp kapsanamayacağı.
2. **Apple'ın rolü:** Satışta bağımsız veri sorumlusu, APNs'te alt işleyen olarak yazıldı. Bu ayrım ve APNs için ayrıca sözleşme/güvence gerekip gerekmediği. Bildirim metninde çocuk adı geçiyor; bildirim içeriğini en aza indirmek (ör. "Yeni bir bildirimin var") tercih edilebilir — ürün kararı.
3. **Expo yedek yolu ve planlanan araçlar:** Expo Push (`00-olgular.md` §5) canlıda kapatılacak mı, yoksa listede mi kalacak? Kalırsa standart sözleşme gerekir. `CANLIYA_ALMA.md` 4'te planlanan Sentry ve PostHog eklenirse bu liste, gizlilik politikası ve ClinicApp web çerez onayı önceden değişmeli.
4. **Uzmana itiraz hakkı ve süre (6. bölüm):** Uzman veri sorumlusu sayılırsa (gizlilik 4. bölüm seçenek A) bu kural Veri İşleme Eki'nin parçası olur; süre (öneri 30 gün) ve fesih sonucu onaylanmalı.
5. **Test dönemi Gmail:** Test e-postalarının gerçek kişilere (pilot uzman ve aileler) gitmesi durumunda bu dönem için de aktarım güvencesi gerekip gerekmediği.
