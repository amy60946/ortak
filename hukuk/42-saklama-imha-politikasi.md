# Kişisel Veri Saklama ve İmha Politikası
| Anahtar | iç belge | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | İşletme içi: işletme sahibi (sorumlu), ekip, yazılımcılar (zamanlanmış imha işi); VERBİS kaydı gerekirse Kurul denetiminde sunulur. Kamuya açık özeti Gizlilik Politikası 12. bölümdedir | Dayanak | KVKK md. 4/2-d, 7, 12; Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik (md. 4–13); KVKK md. 16 (VERBİS) |

## Kısaca

- Her veri kategorisinin bir **saklama süresi** vardır. Süre dolunca veri **silinir**, **yok edilir** ya da **anonim hâle getirilir**.
- Mümkün olan her şey **otomatik** silinir (zamanlanmış imha işi, her gece). Ayrıca en geç **6 ayda bir** (Ocak ve Temmuz) elle **periyodik imha** gözden geçirmesi yapılır.
- Her imha işlemi kişisel veri içermeyen bir **imha kaydına** yazılır; kayıtlar en az **3 yıl** saklanır.
- Sorumlu: **işletme sahibi** (şimdilik tek kişi).
- Bilinmeyen süreler `[SÜRE]` ve öneriyle bırakıldı; avukat onaylayınca doldurulur. 10. bölüm yazılımda yapılacak işlerin listesidir.

## 1. Amaç ve kapsam

Bu politika, [ŞİRKET UNVANI]'nın Pofi Adası (GameApp), ParentApp, ClinicApp ve yönetim panelinde işlediği kişisel verilerin ne kadar saklanacağını, süre dolunca nasıl imha edileceğini ve bu işten kimin sorumlu olduğunu belirler. Bütün kayıt ortamlarını (veritabanı, dosya depolama, yedekler, hizmet sağlayıcılar, e-posta kutuları, ekip bilgisayarları, kâğıt) kapsar.

Temel ilke: Veri, işlendiği amaç için gereken süre kadar saklanır (KVKK md. 4/2-d). Kanun daha uzun saklamayı zorunlu kılıyorsa o süre kadar, yalnız o amaçla ve en az veriyle saklanır.

## 2. Tanımlar

| Terim | Anlamı |
|---|---|
| Silme | Verinin ilgili kullanıcılar için hiçbir şekilde erişilemez ve tekrar kullanılamaz hâle getirilmesi (veritabanında satırın silinmesi, dosyanın depolamadan silinmesi) |
| Yok etme | Verinin hiç kimse tarafından erişilemez, geri getirilemez ve tekrar kullanılamaz hâle getirilmesi (kâğıdın imha makinesinde, cihazın güvenli silme ya da fiziksel imhayla yok edilmesi) |
| Anonim hâle getirme | Verinin başka verilerle eşleştirilse bile kimliği belirli ya da belirlenebilir bir kişiyle ilişkilendirilemeyecek hâle getirilmesi (ör. kişi bazlı kullanım kayıtlarının günlük toplam sayılara indirilmesi) |
| Periyodik imha | Saklama süresi dolan verinin, bu politikada yazan aralıklarla re'sen imha edilmesi |
| Kayıt ortamı | Verinin bulunduğu her yer (bkz. 3. bölüm) |

## 3. Kayıt ortamları

| Ortam | Ne var | İmha yöntemi |
|---|---|---|
| Supabase veritabanı | Bütün uygulama verisi | Satır silme (bağlı kayıtlar zincirleme silinir); anonimleştirme (toplamlara indirme) |
| Supabase dosya depolama (özel kovalar) | Mesaj fotoğrafları ve sesli mesajlar (`mail`), davranış kayıtlarındaki ses kayıtları, uzman belgeleri (`verify`) | Dosya silme |
| Supabase yedekleri | Veritabanının günlük yedekleri ve zamana dönük geri yükleme kayıtları | Yedekler [SÜRE] sonunda kendiliğinden döner (öneri: en çok 30 gün) |
| Hizmet sağlayıcılar (`alt-isleyenler`) | RevenueCat abone kaydı, Resend gönderim kayıtları, Apple bildirim anahtarları, Cloudflare ağ kayıtları | Sağlayıcının silme yolu (API ya da destek talebi) ve sağlayıcının kendi saklama süreleri |
| Kullanıcı cihazları | Pofi Adası'nın yerel oyun kaydı; ParentApp ve ClinicApp önbelleği | Uygulama tarafında temizlik (bkz. 10. bölüm) |
| E-posta kutuları | `destek@`, `kvkk@`, `fatura@` yazışmaları | E-postanın silinmesi ve çöp kutusunun boşaltılması |
| Ekip bilgisayarları | Panelden indirilen müşteri listeleri (CSV, en çok 500 satır), ekran görüntüleri | Dosyanın silinmesi ve çöp kutusunun boşaltılması |
| Kâğıt | Yazılı KVKK başvuruları ve ekleri | Kilitli dolapta saklama; süre dolunca imha makinesinde yok etme |
| Kod depoları | Kişisel veri **konmaz** (kural) | — |

## 4. Saklama ve imha tablosu

"Bugün" sütunu: ✅ sistemde var · ⚠️ kısmen / teyit edilecek · ❌ yapılacak (10. bölüm).

| # | Veri kategorisi | Nerede | Saklama süresi | İmha yöntemi | Nasıl | Bugün |
|---|---|---|---|---|---|---|
| 1 | Ebeveyn hesabı ve profili (ad, takma ad, simge, e-posta, şifre özeti) | `auth.users`, `profiles` | Hesap silinene kadar | Silme | Kullanıcı (uygulama içi "Hesabımı sil") ya da ekip (`admin_delete_user`), derhal | ✅ |
| 2 | Aile, çocuk profilleri, görevler, tamamlamalar, ödüller, Güneş Taşı ve coin defterleri, oyun yedekleri | `families` ve bağlı tablolar | Aile silinene kadar; çocuk profili ebeveyn silince | Silme (zincirleme) | Son ebeveyn hesabını silince ya da ebeveyn çocuğu silince, derhal | ⚠️ veritabanı tek çocuğun silinmesine izin veriyor ama ParentApp'te ekranı yok (`README.md` sorun 5) |
| 3 | Aile içi mesajlar ve mesaj medyası | `messages`, kova `mail` | Aile silinene ya da ebeveyn mesajı silene kadar | Silme | Dosyayı bugün **uygulama** siliyor, sonra hesap silinir | ⚠️ sunucu tarafı yetim dosya temizliği yok |
| 4 | Davranış kayıtları ve ses kaydı | `abc_events`, kova `abc` | Aile silinene ya da ebeveyn kaydı silene kadar | Silme | Derhal | ⚠️ kayıt silinince ses dosyasının da silindiği teyit edilecek |
| 5 | Tanışma yanıtları | `intake_answers` | Hesap silinene ya da ebeveyn silene kadar | Silme | Derhal | ✅ |
| 6 | Sağlık yanıtları (tanı, ilaç) | `intake_answers` (açık rıza sürümüyle) | Ebeveyn silene, rızasını geri alana ya da hesap silinene kadar | Silme | Derhal | ⚠️ rıza geri alınınca yanıtın da silindiği teyit edilecek |
| 7 | Uzman paylaşımı ve geçiş onayları | `clinic_links.consent_*`, `clinic_link_history` | Paylaşım sürdükçe; geçiş izni geri alınınca satır silinir | Silme | Derhal | ✅ · paylaşım bittikten sonra ispat için saklama: [SÜRE] |
| 8 | Uzman hesabı, klinik, ekip | `clinicians`, `clinics` | Hesap/klinik silinene kadar; tek kişilik klinik uzmanla birlikte silinir, ekipte sahiplik en eski üyeye geçer | Silme | Derhal | ✅ |
| 9 | Uzmanın danışan kayıtları (notlar, hedefler, haftalık değerlendirmeler, görev önerileri, takip planı, etiketler) | `clinic_notes`, `clinic_goals`, `goal_ratings`, `clinic_task_suggestions` ve takip planı tabloları | Klinik silinene kadar. Ebeveyn paylaşımı geri alınca uzmanın erişimi biter ama kayıt kalır → [SÜRE] (öneri: paylaşım bittikten 12 ay sonra silme; uzmana 30 gün önce dışa aktarma bildirimi). **Aile ya da çocuk silinince o çocuğa ait kayıtlar da hemen silinir** (bugünkü sistem; avukat kararı bekliyor) | Silme | ❌ paylaşım sonrası süre işi yok | ❌ |
| 9a | Üyeliği ya da denemesi bitmiş kliniğin bütün verisi | klinik tabloları | Bugün süresiz (erişim kapanır, veri kalır) → [SÜRE] (öneri: 6 ay; 30 gün önce uzmana hatırlatma ve dışa aktarma imkânı; `22-uzman-hizmet-sozlesmesi.md` notu 2) | Silme | ❌ | ❌ |
| 10 | Davet bilgileri (ebeveyn adı ve e-postası, çocuğun adı ve yaş grubu) | `clinic_invites` | Bağlanmamış davet 3 gün; bağlanmış ama onaylanmamış en geç 30 gün; onay, ret ya da iptalde hemen | Silme | Otomatik (`clinic_invites_expire`, zamanlanmış) | ⚠️ zamanlanmış işin (pg_cron) canlıda açık olduğu teyit edilecek |
| 11 | Uzman belge dosyası | kova `verify` | Karar, kendiliğinden ret, yeni belgeyle değiştirme ya da hesap silmede | Silme | Otomatik (`verify-doc` silme adımı) | ✅ |
| 12 | Belge özeti, barkod, karar kaydı | `clinician_verifications` | Hesap süresince | Silme | Hesap silinince | ⚠️ hesap silinince silindiği teyit; barkodun kötüye kullanımı önlemek için hesap sonrası saklanması: [SÜRE] |
| 13 | Uzman karşılama anketi | anket tablosu (öneri `20261027100000`) | Hesap silinene kadar; toplam raporlar kimliksizdir | Silme | Hesap silinince | ⚠️ |
| 14 | Abonelik durumu | `family_subscriptions`, `billing_subscriptions` | Hesap/aile/klinik süresince | Silme | Hesapla birlikte | ✅ |
| 15 | Abonelik ve ödeme olayları | ödeme olay tabloları | [SÜRE] (öneri: 10 yıl; vergi ve ticaret mevzuatı) | Hesap silinince kişiyi tanıtan alanlar çıkarılır (takma ad); süre dolunca silme | ❌ takma adlaştırma yok | ❌ |
| 16 | Deneme geçmişi (e-posta SHA-256 özeti) | `trial_history` | [SÜRE] (öneri: denemenin başladığı tarihten 2 yıl) | Silme | ❌ otomatik iş yok | ❌ |
| 17 | Giriş kodu deneme kayıtları (IP dahil) | `code_attempts` | 15 dakika – 1 gün | Silme | Otomatik | ⚠️ hangi işin sildiği teyit edilecek |
| 18 | Bildirim anahtarları | `push_tokens` | Çıkışta, anahtar geçersiz olunca ya da hesap silinince | Silme | Otomatik | ✅ |
| 19 | Uygulama içi bildirimler | `notifications` | [SÜRE] (öneri: 12 ay); kullanıcı istediği an siler | Silme | ❌ otomatik iş yok | ❌ |
| 20 | Kullanım kayıtları | `app_events`, `activity_days`, `user_activity` | [SÜRE] (öneri: 25 ay) | Anonim hâle getirme (günlük toplamlara indirme), sonra kişi bazlı satırların silinmesi | ❌ | ❌ |
| 21 | Çocuk cihazlarının kimliği belirsiz oturumları | `auth.users` (anonim) | Çocuk profili ya da aile silinene, cihaz bağlantısı kapanana kadar | Silme | ❌ bağlantısı kalmayan anonim oturumların temizliği yok | ❌ |
| 22 | Ekip işlemleri denetim kaydı | `admin_audit` | [SÜRE] (öneri: 5 yıl); silinen kullanıcının e-postası yazılmaz | Silme | ❌ kayıt "yalnız eklenir" kuralıyla korunuyor; imha için özel, kayıtlı yol gerekir | ❌ |
| 23 | Yasal metin onay kayıtları | `legal_acceptances` (öneri `20261027200000`) | Hesap silinse de rastgele kimlikle kalır (öneri SQL'i güncellendi 27 Ekim: auth.users'a bağ yok) → [SÜRE] | Silme / takma ad | ❌ karar bekliyor | ❌ |
| 24 | KVKK başvuruları | `kvkk_requests` (öneri `20261027200000`) | Başvuru kapandıktan sonra [SÜRE] (öneri: 3 yıl) | Silme | ❌ | ❌ |
| 25 | Destek yazışmaları | `destek@` posta kutusu | Son yazışmadan [SÜRE] (öneri: 2 yıl) | Silme | Elle, periyodik imhada | ❌ |
| 26 | Veri ihlali envanteri | iç belge (`43-veri-ihlali-proseduru.md`) | [SÜRE] (öneri: 5 yıl) | Silme | Elle | — |
| 27 | İmha kayıtları | imha kayıt tablosu | En az 3 yıl (Yönetmelik) | Silme | Otomatik | ❌ tablo yok |
| 28 | Panelden indirilen dosyalar (CSV) | ekip bilgisayarı | İş bitince, en geç [SÜRE] (öneri: 30 gün) | Silme + çöp kutusunu boşaltma | Elle | — |
| 29 | Yedekler | Supabase | [SÜRE] (öneri: en çok 30 gün) | Kendiliğinden döner | Sağlayıcı | ⚠️ plan ve süre seçilince |
| 30 | Pofi Adası yerel oyun kaydı | çocuğun cihazı | Cihaz bağlantısı kapanınca ya da aile silinince | Uygulama içi temizlik | ❌ bugün yerel kayıt kalıyor (`CANLIYA_ALMA.md` 1.7) | ❌ |
| 31 | Hizmet sağlayıcılardaki kopyalar | RevenueCat, Resend, Apple, Cloudflare | Sağlayıcının süresi; hesap silinince RevenueCat'e silme isteği | Sağlayıcı silme yolu | ❌ | ❌ |
| 32 | Kâğıt başvurular | kilitli dolap | Satır 24 ile aynı | Yok etme (imha makinesi) | Elle | — |

## 5. Saklamayı ve imhayı gerektiren sebepler

**Saklamayı gerektiren:** sözleşmenin ifası (hesap açık kaldıkça); vergi ve ticaret mevzuatı (ödeme kayıtları); bir hakkın tesisi, kullanılması veya korunması (onay kayıtları, ekip işlemleri kaydı, KVKK başvuruları); meşru menfaat (kötüye kullanımı önleme, güvenlik).

**İmhayı gerektiren:** işleme amacının ortadan kalkması (hesap silme, davetin süresinin dolması, belge incelemesinin bitmesi); açık rızanın geri alınması (sağlık yanıtları, uzman paylaşımı, geçiş izni); ilgili kişinin şartları oluşmuş silme talebi; saklama süresinin dolması.

## 6. Periyodik imha

- **Otomatik imha işi her gece** çalışır ve 4. bölümdeki otomatik satırları uygular.
- **Elle periyodik imha en geç 6 ayda bir**, Ocak ve Temmuz aylarının ilk haftasında yapılır. Kontrol listesi:
  1. Otomatik imha işi son 6 ayda her gece çalışmış mı (imha kaydı)?
  2. Yedek saklama süresi hâlâ politikadaki gibi mi?
  3. Süresi dolan destek ve KVKK yazışmaları silindi mi?
  4. Ekip bilgisayarlarında indirilmiş dosya kaldı mı?
  5. Süresi dolan kâğıt başvurular yok edildi mi?
  6. Hizmet sağlayıcılardan silme istekleri tamamlandı mı?
  7. Yeni bir veri kategorisi eklendi mi? Eklendiyse bu tabloya satır açıldı mı?
- Sonuç, kişisel veri içermeyen kısa bir tutanakla imha kaydına eklenir.
- İlk elle periyodik imha: [TARİH].

## 7. Talep üzerine silme

- İlgili kişi silme isterse (KVKK md. 7, 11; Yönetmelik md. 13): şartlar oluşmuşsa veri en geç **30 gün** içinde silinir ve kişiye bildirilir. Veri başkasına aktarılmışsa (ör. hizmet sağlayıcı) alıcıdan da silmesi istenir.
- Şartlar oluşmamışsa (ör. kanunen saklanması gereken ödeme kaydı) talep gerekçesiyle reddedilir; saklanan veri yalnız o amaçla tutulur.
- Hesabın uygulama içinden silinmesi derhal yapılır; ayrı başvuru gerekmez.
- Usul: KVKK Başvuru Usulü (`kvkk-basvuru`).

## 8. İmha kaydı

Her imha işlemi için kaydedilir: tarih ve saat, veri kategorisi (4. bölümdeki satır no), silinen/anonimleştirilen kayıt sayısı, yöntem, tetikleyen (gece işi / elle / başvuru no), sonuç (başarılı / hata).

- İmha kaydına kişisel veri yazılmaz (yalnız sayılar ve satır numaraları). Yedekten geri yükleme ihtimaline karşı, silinen hesapların rastgele kimlikleri yedek süresi ([SÜRE]) kadar ayrı bir listede tutulur ve süre dolunca silinir.
- İmha kayıtları en az **3 yıl** saklanır.

## 9. Sorumlular

| Görev | Kim |
|---|---|
| Politikanın sahibi, güncellenmesi, yıllık gözden geçirme | İşletme sahibi ([AD SOYAD]) |
| Otomatik imha işini izleme (hata alarmı) | İşletme sahibi |
| 6 aylık elle periyodik imha ve tutanak | İşletme sahibi |
| Silme taleplerini yanıtlama | İşletme sahibi (destek rolündeki ekip üyesi yardımcı olabilir) |
| Hizmet sağlayıcılara silme istekleri | İşletme sahibi |
| İmha işinin yazılması ve değiştirilmesi | Yazılımcı; yayından önce işletme sahibinin onayı |
| Yedek kişi | [YEDEK KİŞİ] |

## 10. Yazılımda yapılacaklar

1. **Zamanlanmış imha işi** (sunucuda, her gece; pg_cron): 4. bölümdeki ❌ satırları uygular — `trial_history` (16), `notifications` (19), kullanım kayıtlarını toplamlara indirip kişi bazlı satırları silme (20), bağlantısı kalmayan anonim çocuk oturumları (21), `admin_audit` (22), `kvkk_requests` (24), ödeme olaylarının takma adlaştırılması (15), paylaşım bittikten sonraki uzman kayıtları (9, süre kararı sonrası). Önce **kuru çalıştırma** (yalnız sayar), sonra gerçek silme.
2. **İmha kaydı tablosu** (ör. `retention_runs`): RLS açık, yalnız sunucu yazar, panelde salt okunur; 3 yıl.
3. **Denetim kaydında imha yolu:** `admin_audit` bugün kimsenin silemeyeceği biçimde korunuyor. Yalnız süresi dolan satırları silebilen, kendisi de imha kaydına yazan ayrı bir sunucu işlevi gerekir.
4. **Yetim dosya temizliği:** Mesaj medyası ve davranış kaydı sesleri bugün uygulama tarafından siliniyor; satırı silinmiş ama dosyası kalmış nesneleri sunucu tarafında bulup silen iş.
5. **Teyitler:** davranış kaydı silinince ses dosyası; sağlık rızası geri alınınca yanıtlar; uzman hesabı silinince belge özeti; `code_attempts` temizliği; `clinic_invites_expire`'ın canlıda zamanlanmış olarak çalıştığı.
6. **Hesap silme ekleri:** RevenueCat'e abone silme isteği; onay kayıtlarının (`legal_acceptances`) takma adlı arşive taşınması (avukat kararından sonra); silinen hesap kimliğinin "yedekten dönünce yeniden sil" listesine yazılması.
7. **Pofi Adası:** cihaz bağlantısı kapanınca ya da aile silinince yerel oyun kaydının temizlenmesi (`CANLIYA_ALMA.md` 1.7).
8. **Yönetim paneli:** CSV indirmeyi denetim kaydına yazma ve indirme sırasında "İşin bitince bu dosyayı sil" uyarısı; panelde imha kaydı ve 6 aylık gözden geçirme hatırlatması.
9. **Verimi indir** (aile verisinin dışa aktarılması, `CANLIYA_ALMA.md` 1.6): hem erişim başvurularında hem hareketsiz hesap silinmeden önce kullanılır.
10. **Hareketsiz hesap politikası (öneri, avukata):**
    - Ölçüt: hesabın ve bağlı çocuk cihazlarının **24 ay** boyunca hiç oturumu yoksa (`user_activity.last_seen_at`, üç uygulama birlikte).
    - Adımlar: silmeden **30 gün önce** e-posta + uygulama içi bildirim ("Hesabın 30 gün sonra silinecek; korumak için bir kez giriş yapman yeterli. İstersen önce verini indir."); 7 gün kala hatırlatma; süre dolunca `delete_account` ile aynı gövdeyle silme ve imha kaydı.
    - İstisnalar: etkin mağaza aboneliği ya da elle premium; ücretli ya da elle üyeliği olan klinik; açık KVKK başvurusu; bilinen bir hukuki uyuşmazlık; ailede son 24 ayda oturumu olan başka bir ebeveyn ya da çocuk cihazı.
    - Uzman: tek kişilik ve üyeliği bitmiş klinik için aynı kural; ekip kliniğinde yalnız uzmanın kendi hesabı (klinik kalır).

## 11. Politikanın güncellenmesi

Yeni bir veri kategorisi, yeni bir hizmet sağlayıcı ya da yeni bir süre kararı olduğunda bu politika güncellenir ve sürüm numarası artar (v1, v2 …). Eski sürümler saklanır. Politika yılda en az bir kez gözden geçirilir.

Yürürlük: [TARİH] · Sürüm: v1 · Sorumlu: işletme sahibi

## Avukata notlar

1. **Süreler:** 4. bölümdeki bütün `[SÜRE]`'ler: deneme geçmişi (öneri 2 yıl), denetim kaydı (öneri 5 yıl), ödeme olayları (öneri 10 yıl — şahıs şirketi için VUK ve TTK saklama süreleri mali müşavirle birlikte), kullanım kayıtları (öneri 25 ay), bildirimler (öneri 12 ay), KVKK başvuruları (öneri 3 yıl), destek yazışmaları (öneri 2 yıl), yedekler (öneri en çok 30 gün), ihlal envanteri (öneri 5 yıl).
2. **Uzman danışan kayıtları (satır 9 ve 9a):** Bugün aile ya da çocuk silinince uzmanın o çocuğa ait notları da hemen siliniyor; üyeliği biten klinikte ise veri süresiz kalıyor. İkisi de karara bağlanmalı. Paylaşım bittikten sonra ne kadar saklanmalı; uzmanın mesleki kayıt saklama yükümlülüğü (psikolog, terapist vb.) platforma nasıl yansır; veri sorumlusu seçimiyle (gizlilik 4. bölüm A/B) birlikte karara bağlanmalı (`hukuk_notlari.md` 5/3–5/4).
3. **Hareketsiz hesap politikası (10/10):** 24 ay + 30 gün uyarı + silme önerisi; tüketici mevzuatı ve aile aboneliği açısından uygun mu, Kullanım Koşulları'na madde gerekir mi.
4. **Onay kayıtlarının ispatı (satır 23):** Hesap silindikten sonra hangi onay kaydının, ne kadar ve hangi dayanakla (md. 5/2-e) takma adla saklanacağı.
5. **VERBİS ve politika zorunluluğu:** Yönetmelik bu politikayı VERBİS'e kayıt yükümlüsü veri sorumluları için zorunlu kılıyor. Sağlık verisi işleme ana faaliyet sayılırsa istisna dışı kalırız; o durumda bu politika zorunludur ve VERBİS kaydıyla tutarlı olmalı.
6. **5651 sayılı Kanun:** Aile içi mesajlaşma nedeniyle yer sağlayıcı sayılırsak trafik bilgisi (IP, zaman) saklama yükümlülüğü doğabilir. Bugün IP yalnız kod deneme kayıtlarında ve en çok 1 gün tutuluyor; çelişki varsa süre buna göre değişmeli.
