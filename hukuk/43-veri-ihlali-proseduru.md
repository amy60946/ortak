# Veri İhlali Müdahale ve Bildirim Prosedürü
| Anahtar | iç belge | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | İşletme içi: işletme sahibi (ihlal sorumlusu), yönetim paneli rolleri (support, owner), yazılımcı; yılda bir tatbikatla denenir. **İhlal kayıtları herkese açık `ortak` deposuna yazılmaz** | Dayanak | KVKK md. 12/1, 12/5; Kişisel Verileri Koruma Kurulu'nun 24.01.2019 tarihli ve 2019/10 sayılı Kararı (Kişisel Veri İhlali Bildirim Usul ve Esasları); Kurul'un Kişisel Veri Güvenliği Rehberi (Teknik ve İdari Tedbirler) |

## Kısaca

- **Ne zaman çalışır?** Kişisel verinin yetkisiz kişilerin eline geçtiği ya da geçmiş olabileceği her durumda. Şüphe yeterlidir.
- **İlk saat:** olayı kayda al, sızıntıyı durdur (panelden oturum kapatma, askıya alma, özelliği bayrakla kapatma, bakım modu, anahtar yenileme), delilleri koru.
- **72 saat:** İhlali öğrendiğimiz andan itibaren gecikmeden, en geç 72 saat içinde Kişisel Verileri Koruma Kurulu'na bildirim.
- **İlgili kişiler:** Etkilenen kişiler belirlenince en kısa sürede doğrudan bildirim. Çocuk verisi söz konusuysa **veliye** (ailedeki bütün ebeveynlere) bildirilir, çocuğa değil.
- **Kayıt:** Bildirim gerekmese bile her olay **ihlal envanterine** yazılır.
- **Sorumlu:** işletme sahibi (şimdilik tek kişi).

## 1. Kapsam ve tanımlar

**Kişisel veri ihlali:** İşlenen kişisel verilerin kanuni olmayan yollarla başkaları tarafından elde edilmesi (KVKK md. 12/5). Bu prosedür ayrıca verinin yanlışlıkla değiştirilmesi, silinmesi ya da erişilemez hâle gelmesi gibi olayları da kayda alır; bildirim kararını 6. bölüme göre verir.

**Bizde olabilecek örnekler:**
- Supabase gizli anahtarının (`sb_secret_` / `service_role`) ya da bir Edge Function secret'ının sızması.
- Bir güvenlik kuralı hatası yüzünden bir ailenin ya da uzmanın başka bir ailenin verisini görmesi.
- Bir ekip hesabının ele geçirilmesi; panelden indirilen müşteri listesinin (CSV) kaybolması; ekip bilgisayarının ya da iki adımlı doğrulama telefonunun çalınması.
- Mesaj fotoğrafı, ses kaydı ya da uzman belgesi bağlantısının yetkisiz kişiye ulaşması.
- Uzman gibi davranan birinin davet yoluyla çocuk verisi elde etmesi.
- Bir KVKK yanıtının ya da destek e-postasının yanlış kişiye gönderilmesi.
- Bir hizmet sağlayıcının (`alt-isleyenler`) bize ihlal bildirmesi.

**Ciddiyet:**

| Düzey | Ne zaman |
|---|---|
| **Yüksek** | Sağlık verisi (tanı/ilaç yanıtları, davranış kayıtları, uzman notları), çocuk verisi, mesaj içeriği, fotoğraf, ses, uzman belgesindeki kimlik bilgisi; ya da çok sayıda kişi; ya da sızıntı sürüyor |
| **Orta** | Ad ve e-posta gibi iletişim verisi; sınırlı sayıda kişi; veri bilinen ve güvenilir bir alıcıda kaldı |
| **Düşük** | Yalnız kullanım kayıtları ya da özetlenmiş veri; kimseye ulaşmadığı doğrulandı |

Şüphede bir üst düzey seçilir.

## 2. Roller

| Rol | Kim | Görevi |
|---|---|---|
| İhlal sorumlusu | İşletme sahibi ([AD SOYAD], [TELEFON]) | Kararları verir, Kurul'a ve kişilere bildirir, envanteri tutar |
| Yedek | [YEDEK KİŞİ] | Sorumluya 2 saat içinde ulaşılamazsa ilk adımları atar |
| Yazılımcı | [YAZILIMCI] | Teknik inceleme, açığı kapatan düzeltme, anahtar yenileme |
| Hukuk | [AVUKAT] | Bildirim kararı ve metinleri |
| Ekip üyeleri (panel) | Destek/finans/izleyici rolleri | Şüpheyi hemen ihlal sorumlusuna bildirir; kullanıcıya kendi başına açıklama yapmaz, kanıtı silmez |

## 3. Tespit kaynakları

- Kullanıcının ya da uzmanın `destek@` / `kvkk@` adresine bildirimi.
- Supabase günlükleri (API, kimlik doğrulama, Edge Function), izleme ve alarm.
- Yönetim panelindeki denetim kaydında olağan dışı işlem (ör. gece yapılan toplu görüntüleme).
- Hizmet sağlayıcının güvenlik bildirimi ya da durum sayfası.
- GitHub gizli anahtar taraması.
- Ekip üyesinin bilgisayar ya da telefon kaybı.

## 4. İlk 24 saat

Saatler **ihlali öğrendiğimiz andan** itibaren sayılır. 72 saatlik Kurul süresi de bu andan başlar.

| Ne zaman | Adım | Nasıl |
|---|---|---|
| 0–1 saat | **1. Kayda al** | Envantere yeni olay numarası (İ-YYYY-NN); öğrenme anı (tarih, saat), kim bildirdi, ilk bilinenler. Bundan sonra paneldeki her işlemde gerekçe olarak "İhlal İ-YYYY-NN" yazılır |
| 0–1 saat | **2. Durdur ve sınırla** | 5. bölümdeki acil işlemler |
| 0–2 saat | **3. Delilleri koru** | Supabase günlüklerini dışa aktar; ilgili denetim kaydı satırlarını (`admin_audit_list`) indir; ekran görüntüleri; zaman damgaları. Günlük ve kayıt **silinmez**. Kişisel veri içeren deliller yalnız şifreli bir klasörde tutulur |
| 1–4 saat | **4. Kapsamı belirle** | Hangi veri ve hangi tablolar/kovalar; kaç ebeveyn, çocuk, uzman; hangi zaman aralığı; veri şifreli ya da özetlenmiş miydi; kimin eline geçti; sızıntı sürüyor mu |
| 4–12 saat | **5. Açığı kapat** | Düzeltme (güvenlik kuralı, işlev, yapılandırma), anahtar yenileme, düzeltmenin testi |
| 12–24 saat | **6. Değerlendir ve karar ver** | 6. bölüm; avukatla görüşme; Kurul ve kişi bildirim taslaklarının hazırlanması (12. bölüm) |
| 24. saat | **7. Durum özeti** | Envantere: bilinenler, alınan tedbirler, bildirim kararı, açık sorular |

## 5. Acil işlemler (yönetim paneli ve altyapı)

Panel işlemleri iki adımlı girişle yapılır; her biri gerekçe ister ve silinemez denetim kaydına geçer (`sozlesme/admin.md`).

| Durum | Acil işlem | Nereden | Rol |
|---|---|---|---|
| Bir kullanıcı hesabı ele geçirilmiş olabilir | Bütün oturumlarını kapat (`admin_signout`) ve şifre sıfırlama e-postası gönder (`admin_log_client('user.password_reset_email', …)` ile kaydedilir) | Panel › kullanıcı kartı | support |
| Hesap kötüye kullanılıyor (ör. sahte uzman) | Hesabı askıya al (`admin_suspend`; oturumlar da kapanır); uzmansa belge rozetini askıya al (`admin_verification_suspend`) | Panel › kullanıcı kartı | owner / support |
| Etkilenen kişilere hızlı uyarı | Kişiye uygulama içi bildirim (`admin_notify`) | Panel › kullanıcı kartı | support |
| Bir özellik veri sızdırıyor | Özelliği bayrakla kapat (`admin_set_flag(anahtar, kapalı)`); tek kişide sorun varsa kişiye istisna (`admin_set_user_flag`) | Panel › Bayraklar | owner / support |
| Uygulamanın tamamı riskli | Bakım modu (`admin_set_app_config(…, maintenance = açık)`); düzeltilmiş sürüme zorlamak için `min_version`; herkese duyuru için `banner` | Panel › Uygulama ayarları | owner |
| Bir ekip üyesinin hesabı ele geçirilmiş olabilir | Yönetici yetkisini kaldır (`admin_set_admin(e-posta, yok)`), sonra hesabın oturumlarını kapat | Panel › Yöneticiler | owner |
| **Sahibin (owner) kendi hesabı** ele geçirilmiş olabilir | Supabase hesabına girip şifreyi ve iki adımlı doğrulamayı yenile; SQL Editor'den `admin_users` satırını geçici olarak kaldır; iki adımlı doğrulama faktörünü sıfırla (panel, son owner'ın düşürülmesine izin vermez) | Supabase paneli | İşletme sahibi |
| Gizli anahtar sızdı | Supabase'de gizli anahtarı yenile; sızan Edge Function secret'larını yenile (`APNS_KEY_P8`, `RESEND_API_KEY`, `BILLING_WEBHOOK_SECRET`, `REVENUECAT_API_KEY`, `PUSH_SECRET`, `SMTP_PASS` …) ve GitHub Secrets'ı güncelle; ilgili sağlayıcının panelinde eski anahtarı iptal et | Supabase, sağlayıcı panelleri, GitHub | İşletme sahibi + yazılımcı |
| Bir Edge Function kötüye kullanılıyor | İşlevi geçici olarak kapat ya da önceki sürümü yayınla | Supabase › Edge Functions | İşletme sahibi + yazılımcı |
| Herkesin oturumunu kapatmak gerekiyor | Yazılımcıyla Supabase oturumlarının toplu kapatılması (çocuk cihazlarının yeniden kodla bağlanması gerekebilir; ParentApp'te duyuru yapılır) | Supabase | İşletme sahibi + yazılımcı |
| Ekip bilgisayarı ya da telefonu kayıp | Panel oturumunu kapat, iki adımlı doğrulama faktörünü yenile, cihazı uzaktan sil; cihazda indirilmiş CSV varsa olay "Yüksek" sayılır | Panel, cihaz üreticisi hizmeti | İşletme sahibi |

## 6. Değerlendirme ve bildirim kararı

**Değerlendirilecekler:** Veri türü (özel nitelikli mi, çocuğa mı ait); kişi ve kayıt sayısı; veri okunabilir mi (şifreli, özetlenmiş, kimliksiz?); kimin eline geçti (bilinen ve güvenilir bir alıcı mı, bilinmeyen biri mi); sızıntı sürüyor mu; olası sonuçlar (ayrımcılık, itibar kaybı, oltalama/dolandırıcılık, çocuğun güvenliği, uzmanın mesleki zararı).

**Karar kuralı (öneri):** KVKK'da "düşük risk" istisnası yazılı değildir. Kişisel veri başkalarınca elde edildiyse ya da bu ihtimal dışlanamıyorsa **Kurul'a bildirilir**. Şüphede bildirilir. Bildirim yapılmamasına karar verilirse gerekçesi envantere yazılır.

## 7. Kurul'a bildirim (72 saat)

- **Süre:** İhlali öğrendiğimiz andan itibaren gecikmeden, en geç **72 saat** içinde.
- **Nasıl:** Kurul'un yayımladığı **Kişisel Veri İhlal Bildirim Formu** ile (Kurul'un internet sitesi üzerinden). [Güncel kanal avukatça teyit edilecek.]
- **Kademeli bildirim:** Bütün bilgiler hazır değilse bilinenlerle zamanında bildirilir, kalanı öğrenildikçe tamamlanır.
- **Gecikme:** 72 saat geçerse gecikmenin nedeni bildirime yazılır.
- **Bildirimi yapan:** İşletme sahibi.
- **Hazırlanacak bilgiler:**
  1. Veri sorumlusu bilgileri ve irtibat kişisi.
  2. İhlalin başlangıç ve bitiş tarihi/saati; öğrenme tarihi/saati; nasıl öğrenildiği.
  3. İhlalin kaynağı ve nasıl gerçekleştiği (siber saldırı, yetkisiz erişim, kayıp, hata, alt işleyen kaynaklı …).
  4. Etkilenen veri kategorileri; özel nitelikli veri olup olmadığı.
  5. Etkilenen kişi ve kayıt sayısı; kişi grupları (ebeveyn, çocuk, uzman, ekip).
  6. Olası sonuçlar.
  7. Alınan ve alınacak tedbirler.
  8. İlgili kişilere bildirim yapılıp yapılmadığı, ne zaman ve hangi yolla.
  9. Yurt dışı alıcı ya da alt işleyen varsa adı ve ülkesi.
- **Danışan kayıtları:** Uzmanın danışan kayıtları bakımından veri işleyen sayılırsak (Gizlilik Politikası 4. bölüm, seçenek A) ilgili klinik(ler)e gecikmeden bildiririz; Kurul'a bildirimi klinik yapar, biz bilgi ve destek veririz. Ayrı veri sorumlusuysak biz de bildiririz.

## 8. İlgili kişilere bildirim

- **Süre:** Etkilenen kişiler belirlenince en kısa sürede.
- **Yol:** Doğrudan — kayıtlı e-posta adresine e-posta ve uygulama içi bildirim (`admin_notify`). Doğrudan ulaşılamıyorsa internet sitemizde duyuru ve uygulamada üst bant (`banner`).
- **Çocuk verisi:** Bildirim ailedeki **bütün ebeveynlere** yapılır. Pofi Adası'nda çocuğa ihlal mesajı gösterilmez.
- **Danışan kayıtları:** Uzmana ya da kliniğe; veri sorumlusu seçimine göre ebeveyne de.
- **İçerik:** ne oldu ve ne zaman; hangi verileriniz etkilendi; olası sonuçlar; ne yaptık; sizin ne yapmanızı öneriyoruz; nasıl ulaşırsınız.
- **Dil:** Sade, kısa, kaygıyı büyütmeyen ama bir şeyi küçültmeyen.

## 9. İhlal envanteri

Her olay için (bildirim yapılmasa bile) şu alanlar doldurulur:

| Alan | Örnek |
|---|---|
| Olay no | İ-2026-01 |
| Öğrenme anı / nasıl öğrenildi | 2026-11-03 14:20 · kullanıcı e-postası |
| İhlal aralığı | 2026-11-02 09:00 – 2026-11-03 15:10 |
| Ne oldu (kısa) | … |
| Veri kategorileri / özel nitelikli mi | e-posta, çocuk adı · hayır |
| Etkilenen kişi ve kayıt sayısı | 12 ebeveyn, 15 çocuk |
| Ciddiyet | Yüksek / Orta / Düşük |
| Alınan acil işlemler (denetim kaydı numaralarıyla) | … |
| Kök neden ve kalıcı düzeltme | … |
| Kurul bildirimi | tarih/saat, yok ise gerekçe |
| Kişilere bildirim | tarih, yol, kişi sayısı |
| Alt işleyen | varsa adı |
| Kapanış tarihi ve alınan ders | … |

- Envanter **herkese açık `ortak` deposuna yazılmaz**; erişimi yalnız ihlal sorumlusunda olan özel bir yerde tutulur ([ENVANTER YERİ]). `DURUM.md`'ye yalnız kişisel veri içermeyen tek satır yazılabilir ("güvenlik düzeltmesi yapıldı").
- Saklama: [SÜRE] (öneri: 5 yıl; `42-saklama-imha-politikasi.md` satır 26).

## 10. Hizmet sağlayıcı kaynaklı ihlal

- Sağlayıcının bildirimi geldiği an **öğrenme anıdır**; 72 saat buradan sayılır.
- Sağlayıcıdan hemen şunları iste: ne oldu, hangi müşteri verisi ve hangi bölge etkilendi, zaman aralığı, aldıkları tedbirler, bizim yapmamız gerekenler.
- Kendi tarafımızda: o sağlayıcıyla ilgili anahtarları yenile; etkilenen kendi kayıtlarımızı belirle; 4–8. bölümleri uygula.
- Sözleşmemiz gereği sağlayıcı ihlali bize gecikmeden bildirir (`alt-isleyenler` 5. bölüm). Sağlayıcıların güvenlik duyurularına ve durum sayfalarına abone olunur.

## 11. Kapanış ve öğrenme

- Kalıcı düzeltme (göç + test) yapılır; benzer açık için sızma testine madde eklenir.
- Bu prosedürde değişiklik gerekiyorsa sürüm artırılır.
- **Yılda bir tatbikat:** Uydurma bir olayla (ör. "panel CSV'si kayboldu") 4–9. bölümler baştan sona denenir; süreler ölçülür.

## 12. Taslak metinler

### 12.1 Kurul bildirim formu — "İhlalin açıklaması" alanı

> [TARİH SAAT] tarihinde, [nasıl öğrenildi] üzerine, [ŞİRKET UNVANI] olarak işlettiğimiz [Pofi Adası / ParentApp / ClinicApp] uygulamasında [ihlalin kısa tanımı] tespit edilmiştir. İhlal [başlangıç] ile [bitiş] arasında gerçekleşmiştir. Etkilenen veri kategorileri: [liste]; özel nitelikli veri [vardır/yoktur]. Etkilenen kişi sayısı yaklaşık [sayı] olup bunların [sayısı] çocuktur (çocuk verisi velisi tarafından oluşturulan profillere aittir). İhlal fark edilir edilmez [alınan acil tedbirler] uygulanmış, [kalıcı düzeltme] yapılmıştır. İlgili kişilere [tarih] tarihinde [e-posta ve uygulama içi bildirim] ile bilgi verilmiştir / verilecektir. Veri işleyen olarak [sağlayıcı, ülke] [etkilenmiştir / etkilenmemiştir].

### 12.2 Ebeveyne e-posta

> **Konu:** Hesabınızla ilgili bir güvenlik bildirimi
>
> Merhaba [AD],
>
> [TARİH] tarihinde sistemimizde bir güvenlik sorunu fark ettik. Bu sorun nedeniyle [hangi veriler: ör. adınız, e-posta adresiniz ve çocuğunuzun takma adı] yetkisiz bir kişi tarafından görülmüş olabilir. [Etkilenmeyenler: ör. Mesajlarınız, fotoğraflarınız ve ses kayıtlarınız etkilenmedi.]
>
> **Ne yaptık?** Sorunu [TARİH SAAT]'te kapattık, [ör. bütün oturumları kapattık ve güvenlik anahtarlarını yeniledik] ve durumu Kişisel Verileri Koruma Kurulu'na bildirdik.
>
> **Ne yapmanızı öneriyoruz?** [ör. ParentApp'e yeniden giriş yapın ve şifrenizi değiştirin. Bizden geliyormuş gibi görünen ve şifre ya da kod isteyen e-postalara yanıt vermeyin; biz şifrenizi hiçbir zaman sormayız.]
>
> Sorularınız için bu e-postayı yanıtlayabilir ya da `kvkk@[ALAN ADI]` adresine yazabilirsiniz.
>
> Yaşattığımız endişe için özür dileriz.
> [ŞİRKET UNVANI]

### 12.3 Uygulama içi bildirim (`admin_notify`)

- **Başlık:** Güvenlik bildirimi
- **Metin:** Hesabınızı etkileyebilecek bir güvenlik sorunu yaşadık ve kapattık. Ayrıntıları ve önerilerimizi e-posta adresinize gönderdik.

### 12.4 Uzmana ya da kliniğe e-posta (danışan kayıtları)

> **Konu:** ClinicApp güvenlik bildirimi — danışan kayıtları
>
> Merhaba [AD],
>
> [TARİH] tarihinde ClinicApp'te [kısa tanım] fark ettik. Kliniğinize ait [hangi kayıtlar: ör. 3 danışanın hedef kayıtları] [ARALIK] arasında yetkisiz erişime açık kalmış olabilir. Uzman notlarınızın metni [etkilendi / etkilenmedi].
>
> Sorunu [TARİH SAAT]'te kapattık. Etkilenen danışanların listesi ve ayrıntılı bilgi ekte / ClinicApp'te. [Veri işleyen seçeneği: Veri sorumlusu olarak Kurul'a ve ailelere bildirim yapmanız gerekebilir; bunun için ihtiyaç duyduğunuz bütün bilgiyi sağlarız.] [Ayrı veri sorumlusu seçeneği: Durumu Kurul'a ve etkilenen ailelere biz de bildirdik.]
>
> İletişim: `kvkk@[ALAN ADI]`

### 12.5 Uygulama üst bandı (`banner`, doğrudan ulaşılamayan kişiler için)

> Bir güvenlik sorunu yaşadık ve kapattık. Ayrıntı: [ALAN ADI]/guvenlik-bildirimi

## Avukata notlar

1. **Bildirim eşiği:** KVKK md. 12/5 ve 2019/10 sayılı Kurul kararında risk eşiği yazılı değil; 6. bölümdeki "veri başkalarınca elde edildiyse ya da dışlanamıyorsa bildir" kuralı doğru mu? Yalnız erişilemezlik ya da silinme olaylarında (veri kimsenin eline geçmeden) bildirim gerekir mi?
2. **Kim bildirir (danışan kayıtları):** Veri sorumlusu seçimine (gizlilik 4. bölüm A/B) göre Kurul'a ve ailelere bildirimi klinik mi biz mi yaparız; Veri İşleme Eki'ne "gecikmeden, en geç [SÜRE] saat içinde kliniğe bildirim" süresi yazılmalı (öneri: 24 saat).
3. **Bildirim kanalı ve form:** Kurul'un güncel ihlal bildirim kanalı (çevrim içi form / VERBİS) ve formun güncel alanları; VERBİS kaydımız yoksa bildirimin nasıl yapılacağı.
4. **Veliye bildirim:** Ailede kayıtlı olmayan ikinci bir veli (ör. ayrı yaşayan ebeveyn) bilinmiyorsa yalnız kayıtlı ebeveynlere bildirmek yeterli mi?
5. **Sahte uzman vakası:** Ebeveynin rızasıyla ama aldatılarak bir sahte uzmana paylaşılan çocuk verisi "kanuni olmayan yolla elde etme" sayılıp Kurul'a bildirim gerektirir mi?
