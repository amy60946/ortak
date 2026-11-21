# Kişisel Veri Saklama ve İmha Politikası
| Anahtar | iç belge | Sürüm | v1 | Durum | TASLAK — avukat onayı bekler |
| Nerede | İşletme içi: işletme sahibi (sorumlu), ekip, yazılımcılar (zamanlanmış imha işi); VERBİS kaydı gerekirse Kurul denetiminde sunulur. Kamuya açık özeti Gizlilik Politikası 12. bölümdedir | Dayanak | KVKK md. 4/2-d, 7, 12; Kişisel Verilerin Silinmesi, Yok Edilmesi veya Anonim Hale Getirilmesi Hakkında Yönetmelik (md. 4–13); KVKK md. 16 (VERBİS) |

> İç not — 20 Kasım 2026: 14 Kasım kararları, çekirdek maddeler, Moyo adları, deneme 14 gün (sürüm v1 kaldı).
> 20 Kasım 2026 (ikinci tur): kullanıcı saklama sürelerini "uygun" buldu (avukat dosyası D.15); 4. bölümdeki öneriler süre olarak yazıldı (sistemin `retention_run` ayarlarıyla karşılaştırıldı, avukata not 1). İstisna satır 9a: süresiz (kullanıcı kararı 5l). Belge yükleme özelliği kullanılmıyor (satır 11–12). Tek iletişim adresi `destek@`. Ürün adları: Moyo Ebeveyn (ParentApp), Moyo Oyun (GameApp / Pofi Adası), Moyo Mercek (ClinicApp). İşletmeci gerçek kişidir (`00-olgular.md` §1).

## Kısaca

- Her veri kategorisinin bir **saklama süresi** vardır. Süre dolunca veri **silinir**, **yok edilir** ya da **anonim hâle getirilir**.
- Mümkün olan her şey **otomatik** silinir (zamanlanmış imha işi, her gece). Ayrıca en geç **6 ayda bir** (Ocak ve Temmuz) elle **periyodik imha** gözden geçirmesi yapılır.
- Her imha işlemi kişisel veri içermeyen bir **imha kaydına** yazılır; kayıtlar en az **3 yıl** saklanır.
- Sorumlu: **işletme sahibi** (şimdilik tek kişi).
- Süreler 20 Kasım 2026'da kullanıcı onayıyla dolduruldu (avukat teyidi bekler); önerisi olmayan süreler `[SÜRE]` kaldı. 10. bölüm yazılımda yapılacak işlerin listesidir.

## 1. Amaç ve kapsam

Bu politika, Moyo'yu işleten [AD SOYAD] tarafından Moyo Oyun (GameApp), Moyo Ebeveyn (ParentApp), Moyo Mercek (ClinicApp) ve yönetim panelinde işlenen kişisel verilerin ne kadar saklanacağını, süre dolunca nasıl imha edileceğini ve bu işten kimin sorumlu olduğunu belirler. Bütün kayıt ortamlarını (veritabanı, dosya depolama, yedekler, hizmet sağlayıcılar, e-posta kutuları, ekip bilgisayarları, kâğıt) kapsar.

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
| Supabase dosya depolama (özel kovalar) | Mesaj fotoğrafları ve sesli mesajlar (`mail`), davranış kayıtlarındaki ses kayıtları, uzman belgeleri (`verify`; özellik kullanılmıyor, kova durur) | Dosya silme |
| Supabase yedekleri | Veritabanının günlük yedekleri ve zamana dönük geri yükleme kayıtları | Yedekler en çok 30 gün sonunda kendiliğinden döner |
| Hizmet sağlayıcılar (`alt-isleyenler`) | RevenueCat abone kaydı, Resend gönderim kayıtları, Apple bildirim anahtarları, Cloudflare ağ kayıtları | Sağlayıcının silme yolu (API ya da destek talebi) ve sağlayıcının kendi saklama süreleri |
| Kullanıcı cihazları | Moyo Oyun'un yerel oyun kaydı; Moyo Ebeveyn ve Moyo Mercek önbelleği | Uygulama tarafında temizlik (bkz. 10. bölüm) |
| E-posta kutuları | `destek@` yazışmaları (tek iletişim adresi; KVKK başvuruları, ihlal bildirimleri ve ödeme soruları dahil; kullanıcı kararı 20 Kasım 2026) | E-postanın silinmesi ve çöp kutusunun boşaltılması |
| Ekip bilgisayarları | Panelden indirilen müşteri listeleri (CSV, en çok 500 satır), ekran görüntüleri | Dosyanın silinmesi ve çöp kutusunun boşaltılması |
| Kâğıt | Yazılı KVKK başvuruları ve ekleri | Kilitli dolapta saklama; süre dolunca imha makinesinde yok etme |
| Kod depoları | Kişisel veri **konmaz** (kural) | — |

## 4. Saklama ve imha tablosu

"Bugün" sütunu: ✅ sistemde var · ⚙️ yazıldı ve Supabase'e uygulandı (`supabase/migrations/20261102200000_kvkk_ops.sql`, canlıda doğrulandı 10 Kasım 2026; imha işi **kuru çalıştırmayla** çalışır, süreler avukat onayıyla kesinleşince panelden gerçek silme açılır) · ⚠️ kısmen / teyit edilecek · ❌ yapılacak (10. bölüm).

| # | Veri kategorisi | Nerede | Saklama süresi | İmha yöntemi | Nasıl | Bugün |
|---|---|---|---|---|---|---|
| 1 | Ebeveyn hesabı ve profili (ad, takma ad, simge, e-posta, şifre özeti) | `auth.users`, `profiles` | Hesap silinene kadar | Silme | Kullanıcı (uygulama içi "Hesabımı sil") ya da ekip (`admin_delete_user`), derhal | ✅ |
| 2 | Aile, çocuk profilleri, rutinler ve adımlar (`tasks`), tamamlamalar, ödüller, Güneş Taşı ve coin defterleri, oyun yedekleri | `families` ve bağlı tablolar | Aile silinene kadar; çocuk profili ebeveyn silince | Silme (zincirleme) | Son ebeveyn hesabını silince ya da ebeveyn çocuğu silince, derhal | ⚠️ veritabanı tek çocuğun silinmesine izin veriyor ama Moyo Ebeveyn'de ekranı yok (`README.md` sorun 5) |
| 3 | Aile içi mesajlar ve mesaj medyası | `messages`, kova `mail` | Aile silinene ya da ebeveyn mesajı silene kadar | Silme | Dosyayı bugün **uygulama** siliyor, sonra hesap silinir | ⚠️ sunucu tarafı yetim dosya temizliği yok |
| 4 | Davranış kayıtları ve ses kaydı (özel nitelikli veri içerebilecek kayıtlar) | `abc_events`, kova `abc` | Aile silinene ya da ebeveyn kaydı silene kadar | Silme | Derhal | ⚠️ kayıt silinince ses dosyasının da silindiği teyit edilecek |
| 5 | Tanışma yanıtları (hazır seçenekler; 14 Kasım 2026'dan beri tanı ve ilaç sorusu yok) | `intake_answers` | Hesap silinene ya da ebeveyn silene kadar | Silme | Derhal | ✅ |
| 6 | ~~Sağlık yanıtları (tanı, ilaç)~~ **Kalktı 14 Kasım 2026:** sorular ve açık rıza `saglik-yanit-v1` kaldırıldı, var olan yanıtlar silindi; sunucu bu iki soruya yanıt yazmaz (`migrations/20261114200000_intake_observation_owner.sql`). `consent_version` sütunu duruyor, doldurulmuyor | `intake_answers` | — | — | — | ✅ (satır numarası korunuyor) |
| 7 | Uzman paylaşımı ve geçiş onayları | `clinic_links.consent_*`, `clinic_link_history` | Paylaşım sürdükçe; geçiş izni geri alınınca satır silinir | Silme | Derhal | ✅ · paylaşım bittikten sonra ispat için saklama: [SÜRE] |
| 8 | Uzman hesabı, klinik, ekip | `clinicians`, `clinics` | Hesap/klinik silinene kadar; tek kişilik klinik uzmanla birlikte silinir, ekipte sahiplik en eski üyeye geçer | Silme | Derhal | ✅ |
| 9 | Uzmanın aile kayıtları (notlar, hedefler, değerlendirmeler, rutin ve adım önerileri, takip planı, etiketler) ile ebeveyn eğitimi kayıtları ve davranış olayları (özel nitelikli veri içerebilecek kayıtlar) | `clinic_notes`, `clinic_goals`, `goal_ratings`, `clinic_task_suggestions`, takip planı tabloları, `parent_training_*`, `clinic_target_behaviors`, `behavior_incidents` (hepsi paylaşım kaydına `clinic_links` bağlı; klinik ya da paylaşım kaydı silinince uzmanın kayıtları zincirleme silinir. **Ailenin kendi girdiği kayıtlar ailede kalır** (kullanıcı kararı 20 Kasım 2026, hukuk kararı 3A; öneri `supabase/proposed/20261120200000_family_keeps_records.sql`): aileye açılmış ebeveyn eğitimleri ile ebeveynin modül yanıtları, uygulama kayıtları, yapılacak işaretleri ve davranış olayları salt okunur aile kopyası olur, uzmanın erişimi kapanır; taslak eğitim, uzmanın gözlem verisi, ustalık ölçütü ve hedef davranış tanımı silinir (olayda yalnız hedefin adı kalır). Aile kopyası satır 2 ve 4 gibi aile ya da çocuk silinene kadar saklanır) | Klinik silinene kadar. Ebeveyn paylaşımı geri alınca uzmanın erişimi biter ama kayıt kalır; uzman o andan sonraki kayıtları göremez. Paylaşım bittikten sonraki süre: bugün klinik silinene kadar (metinlere sistemin davranışı yazıldı; eski öneri "paylaşım bittikten 12 ay sonra silme, uzmana 30 gün önce dışa aktarma bildirimi" uygulanmadı, karar bekliyor). **Aile ya da çocuk silinince o çocuğa ait kayıtlar da hemen silinir** (bugünkü sistem; kullanıcı kararı 20 Kasım 2026, B.8: sorun değil, uzmana kayıtta en baştan söylenir) | Silme | ❌ paylaşım sonrası süre işi yok | ❌ |
| 9a | Üyeliği ya da denemesi bitmiş kliniğin bütün verisi | klinik tabloları | **Süresiz** (kullanıcı kararı 20 Kasım 2026, 5l): hesap ya da klinik silinene kadar kalır; erişim kapanır, üyelik yenilenince açılır (eski öneri 6 ay + hatırlatma kalktı; `22` 10.7, 14.4) | Hesap/klinik silinince silme (satır 8) | Derhal | ✅ |
| 10 | Davet bilgileri (ebeveyn adı ve e-postası, çocuğun adı ve yaş grubu) | `clinic_invites` | Bağlanmamış davet 3 gün; bağlanmış ama onaylanmamış en geç 30 gün; onay, ret ya da iptalde hemen | Silme | Otomatik (`clinic_invites_expire` çocuk alanları; gece imha işi ebeveyn adı/e-postası, 30 gün) | ⚙️ |
| 11 | Uzman belge dosyası (**özellik kullanılmıyor**, kullanıcı 20 Kasım 2026; kova ve tablo durur, yeniden açılırsa önce metinler) | kova `verify` | Karar, kendiliğinden ret, yeni belgeyle değiştirme ya da hesap silmede | Silme | Otomatik (`verify-doc` silme adımı) | ✅ |
| 12 | Belge özeti, barkod, karar kaydı (**özellik kullanılmıyor**, kullanıcı 20 Kasım 2026; `clinician_verifications` tablosu durur, yeniden açılırsa önce metinler) | `clinician_verifications` | Hesap süresince | Silme | Hesap silinince | ⚠️ hesap silinince silindiği teyit; barkodun kötüye kullanımı önlemek için hesap sonrası saklanması: [SÜRE] |
| 13 | Uzman karşılama anketi | anket tablosu (öneri `20261027100000`) | Hesap silinene kadar; toplam raporlar kimliksizdir | Silme | Hesap silinince | ⚠️ |
| 14 | Abonelik durumu | `family_subscriptions`, `billing_subscriptions` | Hesap/aile/klinik süresince | Silme | Hesapla birlikte | ✅ |
| 15 | Abonelik ve ödeme olayları | ödeme olay tabloları | 10 yıl (vergi ve ticaret mevzuatı) | Hesap silinince kişiyi tanıtan alanlar çıkarılır (takma ad); süre dolunca silme | ❌ takma adlaştırma yok | ❌ |
| 16 | Deneme geçmişi (e-posta SHA-256 özeti) | `trial_history` | Denemenin başladığı tarihten 2 yıl | Silme | Gece imha işi | ⚙️ |
| 17 | Giriş kodu deneme kayıtları (IP dahil) | `code_attempts` | 15 dakika – 1 gün | Silme | Gece imha işi (ayrıca giriş kodu işlevi) | ⚙️ |
| 18 | Bildirim anahtarları | `push_tokens` | Çıkışta, anahtar geçersiz olunca ya da hesap silinince | Silme | Otomatik | ✅ |
| 19 | Uygulama içi bildirimler | `notifications` | 12 ay; kullanıcı istediği an siler | Silme | Gece imha işi | ⚙️ |
| 19a | Otomatik hatırlatma kaydı (hangi hatırlatmanın gönderildiği ya da atlandığı, açılıp açılmadığı) | `nudge_log` | 12 ay | Silme | Gece işi `nudge_log_prune` (imha işi canlıya alınınca siler; öneri `20261120231000_nudge_kvkk.sql`) | ⚙️ |
| 20 | Kullanım kayıtları | `app_events`, `activity_days`, `user_activity` | 25 ay | Anonim hâle getirme (günlük toplamlara indirme), sonra kişi bazlı satırların silinmesi | Gece imha işi: önce `usage_daily_totals`'a günlük toplam, sonra kişi bazlı satırlar silinir | ⚙️ |
| 21 | Çocuk cihazlarının kimliği belirsiz oturumları | `auth.users` (anonim) | Çocuk profili ya da aile silinene, cihaz bağlantısı kapanana kadar | Silme | Gece imha işi: çocuğa bağlı olmayan ve 30 gün girişsiz anonim oturum | ⚙️ |
| 22 | Ekip işlemleri denetim kaydı | `admin_audit` | 5 yıl; silinen kullanıcının e-postası yazılmaz | Silme | Gece imha işi (yalnız bu işle ve en az 1 yıl eski kesimle silinebilir) | ⚙️ |
| 23 | Yasal metin onay kayıtları | `legal_acceptances` (öneri `20261027200000`) | Hesap silinse de rastgele kimlikle kalır (öneri SQL'i güncellendi 27 Ekim: auth.users'a bağ yok) → [SÜRE] | Silme / takma ad | ❌ karar bekliyor | ❌ |
| 24 | KVKK başvuruları | `kvkk_requests` (öneri `20261027200000`) | Başvuru kapandıktan sonra 3 yıl | Silme | Gece imha işi | ⚙️ |
| 25 | Destek talepleri ve yazışmaları | `support_requests` (/destek formu); ekibin e-posta kutusundaki yanıtlar | Kapanıştan 2 yıl; istenmeyen (spam) 30 gün | Silme | Tablo: gece imha işi (`support_days`); e-posta kutusu: elle, periyodik imhada | ⚙️ |
| 26 | Veri ihlali envanteri | iç belge (`43-veri-ihlali-proseduru.md`) | 5 yıl | Silme | Elle | — |
| 27 | İmha kayıtları | imha kayıt tablosu | En az 3 yıl (Yönetmelik) | Silme | Gece imha işi (en az 3 yıl, alt sınır sunucuda) | ⚙️ |
| 28 | Panelden indirilen dosyalar (CSV) | ekip bilgisayarı | İş bitince, en geç 30 gün | Silme + çöp kutusunu boşaltma | Elle | — |
| 29 | Yedekler | Supabase | En çok 30 gün | Kendiliğinden döner | Sağlayıcı | ⚠️ plan ve süre seçilince |
| 30 | Moyo Oyun yerel oyun kaydı | çocuğun cihazı | Cihaz bağlantısı kapanınca ya da aile silinince | Uygulama içi temizlik | ✅ oyun bağlantının kapandığını görünce kaydı ve oturumu siler (game-app `GameBootstrap.ForgetDevice`, 2 Kasım 2026; TestFlight 35'ten beri) | ❌ |
| 31 | Hizmet sağlayıcılardaki kopyalar | RevenueCat, Resend, Apple, Cloudflare | Sağlayıcının süresi; hesap silinince RevenueCat'e silme isteği | Sağlayıcı silme yolu | ❌ | ❌ |
| 32 | Kâğıt başvurular | kilitli dolap | Satır 24 ile aynı | Yok etme (imha makinesi) | Elle | — |

## 5. Saklamayı ve imhayı gerektiren sebepler

**Saklamayı gerektiren:** sözleşmenin ifası (hesap açık kaldıkça); vergi ve ticaret mevzuatı (ödeme kayıtları); bir hakkın tesisi, kullanılması veya korunması (onay kayıtları, ekip işlemleri kaydı, KVKK başvuruları); meşru menfaat (kötüye kullanımı önleme, güvenlik).

**İmhayı gerektiren:** işleme amacının ortadan kalkması (hesap silme, davetin süresinin dolması, belge incelemesinin bitmesi); açık rızanın geri alınması (uzman paylaşımı, geçiş izni); ilgili kişinin şartları oluşmuş silme talebi; saklama süresinin dolması.

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

- İmha kaydına kişisel veri yazılmaz (yalnız sayılar ve satır numaraları). Yedekten geri yükleme ihtimaline karşı, silinen hesapların rastgele kimlikleri yedek süresi (en çok 30 gün) kadar ayrı bir listede tutulur ve süre dolunca silinir.
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

1. ⚙️ (2 Kasım 2026: `retention_run`, `kvkk_ops` uygulandı; 15 ve 9 karar bekliyor; 9a süresiz, kullanıcı kararı 20 Kasım 2026) **Zamanlanmış imha işi** (sunucuda, her gece; pg_cron): 4. bölümdeki ❌ satırları uygular — `trial_history` (16), `notifications` (19), kullanım kayıtlarını toplamlara indirip kişi bazlı satırları silme (20), bağlantısı kalmayan anonim çocuk oturumları (21), `admin_audit` (22), `kvkk_requests` (24), ödeme olaylarının takma adlaştırılması (15), paylaşım bittikten sonraki uzman kayıtları (9, süre kararı sonrası). Önce **kuru çalıştırma** (yalnız sayar), sonra gerçek silme.
2. ⚙️ (`retention_runs`) **İmha kaydı tablosu** (ör. `retention_runs`): RLS açık, yalnız sunucu yazar, panelde salt okunur; 3 yıl.
3. ⚙️ (`admin_audit_immutable` yalnız imha işinin ≥ 1 yıl eski kesimine izin verir) **Denetim kaydında imha yolu:** `admin_audit` bugün kimsenin silemeyeceği biçimde korunuyor. Yalnız süresi dolan satırları silebilen, kendisi de imha kaydına yazan ayrı bir sunucu işlevi gerekir.
4. **Yetim dosya temizliği:** Mesaj medyası ve davranış kaydı sesleri bugün uygulama tarafından siliniyor; satırı silinmiş ama dosyası kalmış nesneleri sunucu tarafında bulup silen iş.
5. **Teyitler:** davranış kaydı silinince ses dosyası; uzman hesabı silinince belge özeti (özellik kullanılmıyor); `code_attempts` temizliği; `clinic_invites_expire`'ın canlıda zamanlanmış olarak çalıştığı.
6. **Hesap silme ekleri:** RevenueCat'e abone silme isteği; onay kayıtlarının (`legal_acceptances`) takma adlı arşive taşınması (avukat kararından sonra); silinen hesap kimliğinin "yedekten dönünce yeniden sil" listesine yazılması.
7. **Moyo Oyun:** cihaz bağlantısı kapanınca ya da aile silinince yerel oyun kaydının temizlenmesi (`CANLIYA_ALMA.md` 1.7).
8. ⚙️ (panel: CSV gerekçe + kayıt + uyarı, Hukuk › Saklama ve imha, 6 aylık hatırlatma) **Yönetim paneli:** CSV indirmeyi denetim kaydına yazma ve indirme sırasında "İşin bitince bu dosyayı sil" uyarısı; panelde imha kaydı ve 6 aylık gözden geçirme hatırlatması.
9. ⚙️ (`my_data_export`, `admin_user_export`; uygulama ekranları Moyo Ebeveyn / Moyo Mercek) **Verimi indir** (aile verisinin dışa aktarılması, `CANLIYA_ALMA.md` 1.6): hem erişim başvurularında hem hareketsiz hesap silinmeden önce kullanılır.
10. **Hareketsiz hesap politikası (öneri, avukata):**
    - Ölçüt: hesabın ve bağlı çocuk cihazlarının **24 ay** boyunca hiç oturumu yoksa (`user_activity.last_seen_at`, üç uygulama birlikte).
    - Adımlar: silmeden **30 gün önce** e-posta + uygulama içi bildirim ("Hesabın 30 gün sonra silinecek; korumak için bir kez giriş yapman yeterli. İstersen önce verini indir."); 7 gün kala hatırlatma; süre dolunca `delete_account` ile aynı gövdeyle silme ve imha kaydı.
    - İstisnalar: etkin mağaza aboneliği ya da elle premium; ücretli ya da elle üyeliği olan klinik; açık KVKK başvurusu; bilinen bir hukuki uyuşmazlık; ailede son 24 ayda oturumu olan başka bir ebeveyn ya da çocuk cihazı.
    - Uzman: tek kişilik ve üyeliği bitmiş klinik için aynı kural; ekip kliniğinde yalnız uzmanın kendi hesabı (klinik kalır).

## 11. Politikanın güncellenmesi

Yeni bir veri kategorisi, yeni bir hizmet sağlayıcı ya da yeni bir süre kararı olduğunda bu politika güncellenir ve sürüm numarası artar (v1, v2 …). Eski sürümler saklanır. Politika yılda en az bir kez gözden geçirilir.

Yürürlük: [TARİH] · Sürüm: v1 · Sorumlu: işletme sahibi

## Avukata notlar

1. **Süreler (20 Kasım 2026: kullanıcı "uygun" dedi, öneriler süre olarak yazıldı; avukat teyidi):** deneme geçmişi 2 yıl, denetim kaydı 5 yıl, ödeme olayları 10 yıl (işletmeci gerçek kişi olduğu için VUK ve, tacir sayılırsa, TTK saklama süreleri mali müşavirle birlikte; `hukuk_notlari.md` soru 28), kullanım kayıtları 25 ay, bildirimler 12 ay, KVKK başvuruları 3 yıl, destek yazışmaları 2 yıl, yedekler en çok 30 gün, ihlal envanteri 5 yıl, panelden indirilen dosya 30 gün. **Sistemle karşılaştırma** (`migrations/20261102200000_kvkk_ops.sql`, `app_config.retention`): `trial_history_days` 730, `notifications_days` 365, `usage_days` 760 (≈ 25 ay), `audit_days` 1825, `kvkk_closed_days` 1095, `support_days` 730 (spam 30), `runs_days` 1095, `invite_pii_days` 30: metinlerle aynı, fark yok. Sistemde zamanlanmış adımı olmayanlar: ödeme olayları (15; takma adlaştırma ve 10 yıl sonra silme yok), yedekler (29; Supabase planına bağlı, teyit edilecek), ihlal envanteri (26) ve panel CSV (28) elle. Önerisi olmadığı için `[SÜRE]` kalanlar: satır 7 (paylaşım bittikten sonra onayın ispat için saklanması), 12 (barkodun hesap sonrası saklanması; özellik kullanılmıyor), 23 (yasal metin onay kayıtları; `00-olgular` §7 öneri: sözleşme bitiminden 10 yıl), satır 9'un paylaşım sonrası süresi (metinlere sistemin davranışı yazıldı: klinik silinene kadar). Satır 9a kullanıcı kararıyla süresiz.
2. **Uzmanın aile kayıtları (satır 9 ve 9a):** Bugün aile ya da çocuk silinince uzmanın o çocuğa ait notları da hemen siliniyor; üyeliği biten klinikte ise veri süresiz kalıyor. **Kullanıcı kararları (20 Kasım 2026):** birincisi sorun değil (B.8; uzmana kayıtta en baştan söylenir, yükümlülük uzmanda); ikincisi süresiz kalır (5l). Veri sorumlusu: uzman, Moyo veri işleyen (A.4; gizlilik 4. bölüm A/B kapandı). Avukata kalan: Paylaşım bittikten sonra ne kadar saklanmalı; uzmanın mesleki kayıt saklama yükümlülüğü (psikolog, terapist vb.) platforma nasıl yansır; veri sorumlusu seçimiyle (gizlilik 4. bölüm A/B) birlikte karara bağlanmalı (`hukuk_notlari.md` 5/3–5/4).
3. **Hareketsiz hesap politikası (10/10):** 24 ay + 30 gün uyarı + silme önerisi; tüketici mevzuatı ve aile aboneliği açısından uygun mu, Kullanım Koşulları'na madde gerekir mi.
4. **Onay kayıtlarının ispatı (satır 23):** Hesap silindikten sonra hangi onay kaydının, ne kadar ve hangi dayanakla (md. 5/2-e) takma adla saklanacağı.
5. **VERBİS ve politika zorunluluğu:** Kullanıcı görüşü (20 Kasım 2026, A.5): VERBİS gerekmez (veri sorumlusu gerçek kişi; ana faaliyet özel nitelikli veri işleme değil); avukat teyidi. Politika yine de iç düzen için tutulur. Yönetmelik bu politikayı VERBİS'e kayıt yükümlüsü veri sorumluları için zorunlu kılıyor. Özel nitelikli veri içerebilecek kayıtların işlenmesi ana faaliyet sayılırsa istisna dışı kalırız; o durumda bu politika zorunludur ve VERBİS kaydıyla tutarlı olmalı.
6. **5651 sayılı Kanun:** Aile içi mesajlaşma nedeniyle yer sağlayıcı sayılırsak trafik bilgisi (IP, zaman) saklama yükümlülüğü doğabilir. Bugün IP yalnız kod deneme kayıtlarında ve en çok 1 gün tutuluyor; çelişki varsa süre buna göre değişmeli.
