# Admin paneli ve KPI (`supabase/migrations/20261023000000_admin.sql`, uygulandı 23 Ekim 2026)

Panel: ayrı depo **`amy60946/admin-panel`** (web). Üç uygulamanın kullanıcıları tek panelden yönetilir. Panel yalnız aşağıdaki `admin_*` fonksiyonlarını çağırır; tablolara doğrudan erişemez.

## Güvenlik kuralları

| Kural | Nasıl |
|---|---|
| Yalnız admin | `admin_users` tablosunda rolü olan hesap. İlk owner SQL Editor'den eklenir (e-posta depoya yazılmaz). |
| İki adımlı doğrulama zorunlu | Her `admin_*` (yalnız `admin_me` hariç) JWT'de `aal = aal2` ister (Supabase MFA, TOTP). |
| Gerekçe zorunlu | Değiştiren her işlem 3–500 karakter gerekçe ister. |
| Denetim kaydı | `admin_audit`: kim, ne, kime, önce/sonra, gerekçe. Yalnız eklenir; owner ve sunucu dahil kimse değiştiremez/silemez. Silinen kullanıcının e-postası kayda yazılmaz. |
| Gizlilik | Mesaj içeriği, fotoğraf, ses, uzman notunun metni panelde **yok**; yalnız sayılar. |
| Kendine/adminlere | Admin kendini askıya alamaz/silemez; admin hesabı önce yetkisi kaldırılmadan askıya alınamaz/silinemez; son owner düşürülemez. |

## Roller

| Rol | Okur | Yapabilir |
|---|---|---|
| `viewer` | her şey (KPI, kartlar, denetim kaydı) | — |
| `support` | her şey | kişiye bildirim, aile/klinik denemesini uzatma, kişiye bayrak, oturumları kapatma, şifre sıfırlama e-postası (kayıt) |
| `finance` | her şey | aileye elle premium ver/kaldır, kliniğe elle üyelik ver/kaldır, deneme uzatma, KPI fiyatları |
| `owner` | her şey | hepsi + askıya alma, hesap silme, genel bayraklar, uygulama ayarı, admin yönetimi |

## Fonksiyonlar

| Fonksiyon | Rol | Ne yapar |
|---|---|---|
| `admin_me()` | herkes | `{role, mfa}` ya da null (panel giriş akışı) |
| `admin_search(q, limit)` | okur | E-posta, ad, çocuk adı, klinik adı ya da kimlik (kullanıcı/aile/klinik/çocuk) ile arar; `%` ve `_` kaçırılır |
| `admin_user(user)` | okur | Hesap (e-posta, kayıt, son giriş, doğrulama, askı), tür, profil/uzman/çocuk, uygulama etkinliği, son 50 olay, son 20 bildirim, cihaz sayısı, bayraklar, denetim kaydı |
| `admin_family(family)` | okur | Aile, erişim durumu (`family_access_of`), abonelik, ebeveynler, çocuklar (bağlı mı, son görülme, oyun kaydı), görev sayıları, klinik paylaşımları, denetim |
| `admin_clinic(clinic)` | okur | Klinik, etkin mi, üyeler, danışan sayıları, abonelikler, ödeme olayları, denetim |
| `admin_audit_list(type, target, limit)` | okur | Denetim kaydı |
| `admin_extend_trial(family, gün, gerekçe)` | support, finance | 1–90 gün; bitmişse bugünden açılır |
| `admin_clinic_extend_trial(clinic, gün, gerekçe)` | support, finance | Yalnız denemedeki klinik |
| `admin_notify(user, başlık, metin, gerekçe, app?)` | support | `notifications` (kind `admin_message`) → push. Uygulama hesap türünden seçilir |
| `admin_set_user_flag(user, key, açık/kapalı/null, bitiş, gerekçe)` | support | Kişiye bayrak istisnası (null = sil) |
| `admin_signout(user, gerekçe)` | support | Tüm oturumlar kapanır |
| `admin_log_client('user.password_reset_email', user, gerekçe)` | support | Panelin istemciden gönderdiği şifre sıfırlama e-postasının kaydı |
| `admin_social_check(action, ref, gerekçe, after, dry)` | `view` okur; `approve` / `request_changes` / `delete` owner | Paylaşım ekranı (`social` işlevi üzerinden; `sozlesme/paylasim.md`, `migrations/20261028300000_admin_social.sql`, uygulandı 28 Ekim 2026). İçerik veritabanında tutulmaz; değişiklik servis işlemi başarılı olunca `system` / `social:<id>` olarak denetim kaydına yazılır |
| `admin_grant_premium(family, bitiş, gerekçe)` / `admin_revoke_premium` | finance | Elle premium (`source=manual`, en çok 2 yıl). Etkin mağaza aboneliği varsa reddedilir |
| `admin_clinic_grant(clinic, plan_id, bitiş, gerekçe)` / `admin_clinic_revoke` | finance | `billing_apply('manual', …)` |
| `admin_suspend(user, bitiş?, gerekçe)` / `admin_unsuspend` | owner | `auth.users.banned_until` + oturumlar kapanır |
| `admin_delete_user(user, gerekçe)` | owner | `delete_account` ile aynı gövde (`account_delete_of`); geri alınamaz |
| `admin_set_flag(key, açık, yüzde, açıklama, gerekçe)` / `admin_flags()` | owner / okur | Genel bayrak; yüzde ile kademeli açılış (kullanıcıya sabit) |
| `admin_set_app_config(app, min_version, maintenance, banner, gerekçe)` / `admin_app_config()` | owner / okur | `app_config` anahtarı `app.parent` / `app.child` / `app.clinic` |
| `admin_set_kpi_config(jsonb, gerekçe)` | owner, finance | `app_config.kpi`: `parent_monthly_try`, `parent_yearly_try`, `store_fee_pct` (15), `revenuecat_pct` (1) |
| `admin_list_admins()` / `admin_set_admin(email, rol|null, gerekçe)` | owner | Admin yönetimi |
| `admin_customers(app, kesim, arama, sıralama, azalan, limit, offset)` | okur | Müşteri listeleri (`migrations/20261026600000_admin_customers.sql`, uygulandı 26 Ekim): `{total, segments, rows}`. **parent** (aile): ebeveynler + e-posta, durum (`family_access_of`), bitiş, çocuk/cihaz, görev/onay/aktif gün (30 gün), bekleyen onay, uzman paylaşımı; kesimler new, trial, trial_ending (≤3 gün), premium, clinic, expired, pending, at_risk (deneme/premium + 7 gün yok), inactive (14 gün), no_child, no_device. **child** (çocuk): aile, yaş grubu, oyun bağlı mı, seviye, coin, "Yaptım"/onay/aktif gün (30 gün), uzmanla paylaşım; kesimler new, linked, unlinked, active_7, inactive, clinic. **clinic**: sahip + e-posta, durum (paid/manual/trial/expired), bitiş, uzman/koltuk, belgeli uzman, danışan, davet/paylaşım/öneri/not (30 gün), aktif gün; kesimler new, trial, trial_ending, paid, manual, expired, no_clients, inactive, at_risk. Arama ad/e-posta/kimlik (`%`/`_` kaçırılır); sıralama yalnız izinli alanlarla; limit en çok 500 (CSV). Mesaj/not içeriği yok |
| `admin_legal_documents()` / `admin_legal_publish(anahtar, sürüm, gerekçe)` | okur / owner | Yasal metin sürümleri, durum (taslak/yayında/eski), onaylayan sayısı (`migrations/20261027200000_legal.sql`, uygulandı 27 Ekim 2026). Yayımlayınca aynı anahtarın önceki yayını eskiye çekilir; onay isteyen metinde kullanıcılar yeniden onaylar. Yayındaki metin değiştirilemez |
| `admin_user_legal(kullanıcı)` | okur | Kullanıcının yasal onayları (anahtar, sürüm, uygulama, zaman, güncel mi) ve KVKK başvuruları |
| `admin_kvkk_requests(durum='open', limit)` / `admin_kvkk_request_log(e-posta, app, kanal, tür, özet, alınış, gerekçe)` / `admin_kvkk_request_update(id, durum, not, gerekçe)` | support | KVKK başvuru kuyruğu (md. 13: 30 gün; açıklar en yakın süreden). E-posta/yazılı/KEP başvurusu kayda alınır (alınıştan 30 gün). Yanıtlanınca/reddedilince kapanır, hesabı varsa `kvkk_answered` bildirimi; ret iç not ister. Yanıt metni e-postayla gider |
| `admin_verifications(durum='pending', limit)` | support | Uzman belge başvuruları (`20261026050000`, uygulandı): uzman, e-posta, klinik, meslek, BACB no, ön kontrol (`auto`), barkod, dosya var mı, önceki ret sayısı; bekleyenler en eskiden (barkod, BACB no ve e-posta içerdiği için yalnız support/owner, 26 Ekim denetimi) |
| `admin_verification_open(id)` | support | Belge yolunu döner ve görüntülemeyi denetim kaydına yazar. Panel bunu doğrudan değil, Edge Function **`verify-doc`** (`{action:'open', id}`) üzerinden çağırır; işlev 2 dk imzalı bağlantı döner. `20261026400000` (uygulandı 26 Ekim) ile `verify` kovası yöneticiye doğrudan kapalı (panel dışından açılıp kayıtsız kalamaz). Karar sonrası dosyaları `verify-doc` `{action:'purge'}` siler (`storage_trash`, `admin_can_review`) |
| `admin_verification_decide(id, onay, ret_nedeni, açıklama, barkod, özet, gerekçe)` | support | Onay → rozet (`clinicians.verified_profession/verified_at`) + bildirim; ret → neden kodu + uzmana açıklama. Özet yalnız `{university, program, degree, graduation_year}`. Dönen belge yolunu panel kovadan **siler** |
| `admin_verification_suspend(uzman, açıklama, gerekçe)` | support | Rozeti askıya alır (şikâyet, BCBA süresi) |
| `admin_intake(aile, gerekçe)` | owner (14 Kasım 2026'dan beri; önce support) | ParentApp tanışma soruları (`20261027120000`, uygulandı 27 Ekim 2026): kişi bazlı yanıtlar (kullanıcı kararı 27 Ekim 2026; 14 Kasım 2026: yalnız owner, `migrations/20261114200000_intake_observation_owner.sql`, uygulandı 14 Kasım 2026); her açılış denetim kaydında (`intake.view`). Sağlık yanıtları (tanı, ilaç) dahil |
| `admin_intake_summary(gün)` | okur | Soru × seçenek dağılımı, yalnız sayılar; sağlık soruları hariç |

Bayrak `parent_sms_verify` (28 Ekim 2026; tanım gerekmez, yoksa kapalı): ParentApp'te uzman bağlandıktan sonra telefon numarası + SMS kodu adımı. Açmadan önce Supabase'de SMS sağlayıcısı (ücretli) ve aydınlatma metni (`hukuk_notlari.md` J). `admin_set_flag('parent_sms_verify', true, 100, …)`.

Bayrak `clinician_verification` (`20261026050000`, uygulandı; varsayılan **kapalı**): belge incelemesini uygulamalarda görünür yapar. `admin_set_flag('clinician_verification', true, 100, …)` ile herkese, `admin_set_user_flag(uzman, 'clinician_verification', true, …)` ile önce tek uzmana açılır.

Bayrak `plan_change_suggestions` (ClinicApp, 2 Kasım 2026; varsayılan **kapalı**): Takip planında ailede ekli rutin/göreve "Değişiklik öner" düğmesini gösterir (`akislar.md` 12.1 adım 6–7). ParentApp "Uzmanın değişiklik önerisi" kartını yayınlamadan açılmaz: eski ParentApp değişiklik önerisini yeni görev gibi ekler (çift görev). Açmak: `admin_set_flag('plan_change_suggestions', true, 100, …)`.

Bayrak `care_plan` (ClinicApp + ParentApp, kullanıcı kararı 11 Kasım 2026 "lansman odağı: ebeveyn eğitimi"; tanım gerekmez, yoksa **kapalı**): Takip Planı'nı (davranış hedefleri, GAS, aile programı, tek gönderim) iki uygulamada **görünür** yapar. Kapalıyken ClinicApp'te Takip Planı bölümü, ona giden yollar ve ana ekrandaki plan nedenleri yok; danışan Ebeveyn Eğitimi'yle açılır (`akislar.md` 12.2). ParentApp aynı bayrağı `client_config('parent')` ile okur (aile tarafı gizlenir; ParentApp penceresi). Veri ve işlevler durur, yalnız arayüz gizlenir. Yeniden açmak: `admin_set_flag('care_plan', true, 100, …)`; önce tek uzmana: `admin_set_user_flag(uzman, 'care_plan', true, …)`. `plan_change_suggestions` yalnız bu bayrak açıkken anlam taşır.

Bayrak `cancel_flow` (ClinicApp, 18 Kasım 2026; tanım gerekmez, yoksa **kapalı**): Üyelik ekranında "Aboneliği yönet"i doğrudan Apple'ın abonelik sayfası yerine iptal öncesi pencereyle açar; iptal edilmiş üyelik kartını ve ödeme sorunu bandını gösterir (`akislar.md` 26 aşama 1). Teklif (indirim, ücretsiz ay) içermez. Açmak: `admin_set_flag('cancel_flow', true, 100, …)`; önce tek uzmana: `admin_set_user_flag(uzman, 'cancel_flow', true, …)`. TestFlight'ta gerçek cihazda denenmeden herkese açılmaz.

Bayrak `lifecycle_nudges` (ClinicApp, 18 Kasım 2026; tanım gerekmez, yoksa **kapalı**): cihazda planlanan hatırlatmaları (ilk davet, süresi dolan davet, ilk eğitim, taslak eğitim, deneme bitişinden 3 gün önce), davet sonrası izin açıklamasını ve Ayarlar › Bildirimler anahtarını açar (`akislar.md` 25 aşama 1). Açıkken iOS bildirim izni girişte değil, ilk davetten sonra sorulur. Kapatılınca cihazdaki planlı hatırlatmalar bir sonraki açılışta silinir. Sınırlar (hafta içi 08:30–19:00, günde 1, 7 günde 2, üç yanıtsız hatırlatmadan sonra 14 gün ara, %10 karşılaştırma grubu) şimdilik uygulamada sabit; kullanıcı kararı bekliyor.

Bayrak `nudges_server` (sunucu bildirim motoru, ÖNERİ `proposed/20261120230000_nudge_engine.sql`, 20 Kasım 2026; tanım gerekmez, yoksa **kapalı**): otomatik, kişiye göre seçilen hatırlatmaları (`nudge_run`, aşağıda "Otomatik bildirim motoru"; kurallar `akislar.md` 25 "Sunucu motoru") açar. Kişi başına değerlendirilir (`flag_on`: kişiye istisna → genel bayrak + yüzde). Ürüne özel anahtar `nudges_server_parent` / `nudges_server_clinic` genel bayrak ya da kişiye istisna olarak **tanımlıysa** o ürün için `nudges_server`'ın yerine geçer (ör. yalnız Moyo Mercek: `admin_set_flag('nudges_server_clinic', true, 100, …)`; yalnız Moyo: `nudges_server_parent`). Kapalıyken motor hiçbir şey yazmaz. Önce tek kişiye: `admin_set_user_flag(kullanıcı, 'nudges_server', true, …)`. Moyo Mercek bu bayrağı `client_config('clinic')` ile okur: `flags.nudges_server_clinic ?? flags.nudges_server` açıksa cihaz içi planlamayı (`lifecycle_nudges`) kapatır (Mercek penceresinin işi). Açmadan önce: kural metinleri Marketing §7.1 / hukuk_notlari N gözden geçirmesi, ParentApp'in `nudge` bildirimini açması (`data.nudge`).

## KVKK işletme ve izleme (`migrations/20261102200000_kvkk_ops.sql`, 2 Kasım 2026, **uygulandı**: canlıda doğrulandı 10 Kasım 2026)

| Fonksiyon | Rol | Ne yapar |
|---|---|---|
| `admin_retention_status(limit)` | okur | İmha ayarı (`app_config.retention`), pg_cron var mı, son çalışmalar (`retention_runs`). Panel: Hukuk › Saklama ve imha |
| `admin_retention_dry_run(gerekçe)` | owner | Şimdi kuru çalıştır: yalnız sayar, imha kaydına ve denetim kaydına (`retention.dry_run`) yazar. Gerçek silme yalnız gece işinde ve `live` açıkken |
| `admin_set_retention_config(jsonb, gerekçe)` | owner | Süreler ve `live`. Bilinmeyen anahtar, tam sayı olmayan ve alt sınırın altı reddedilir (imha kaydı ≥ 1095 gün, denetim kaydı ≥ 365, kullanım ≥ 400 …). `live` yalnız avukat süreleri onaylayınca açılır (`hukuk/42`) |
| `admin_user_export(kullanıcı, gerekçe)` | support | KVKK erişim başvurusu için "Verimi indir" ile aynı JSON; denetim kaydına `user.data_export`. Panel: kullanıcı kartı › Verilerini indir (KVKK). Dosya başvurana güvenli yoldan iletilir, sonra silinir |
| `admin_log_export(ne, satır, gerekçe)` | okur | Panelden toplu indirmenin kaydı (`export.csv`, hedef `system`/`customers.<app>`, satır sayısı). Müşteriler › CSV indir gerekçe ister ve "işin bitince dosyayı sil (en geç 30 gün)" uyarısı gösterir |
| `admin_health()` | okur | Sistem sağlığı (`ops_health`, `veritabani.md` 23). Panel: Sistem sağlığı ekranı + Özet'te uyarı bandı |

### Destek (`migrations/20261102210000_support.sql`, 2 Kasım 2026, **uygulandı**: canlıda doğrulandı 10 Kasım 2026; kullanıcı kararı: sayfada form)

| Fonksiyon | Rol | Ne yapar |
|---|---|---|
| `admin_support_requests(durum='open', limit)` | support | Destek kuyruğu: `open` (yeni + işlemde, en eski önce), `answered`, `closed`, `spam`, `all`. E-posta ve mesaj içerir (kişinin ekibe yazdığı metin; aile mesajı değildir) → yalnız destek rolü ve sahip |
| `admin_support_update(id, durum, iç not, gerekçe)` | support | Durum (new/in_progress/answered/closed/spam) ve iç not; denetim kaydına `support.update`, hedef `system`/`support:<D-no>` (e-posta ve mesaj yazılmaz) |

Akış: herkese açık **`https://moyoapp.com.tr/destek`** (panelin Worker'ı, Cloudflare route'u; panel adresindeki eski `/destek` buraya 301; JavaScript'siz form: uygulama, konu, e-posta, isteğe bağlı ad, mesaj, "18 yaşından büyüğüm", gizli tuzak alanı, doldurma süresi) → Edge Function **`support`** (POST; gövde en çok 20 000 karakter) → `support_requests` → **ekibe bildirim** (her yeni talepte `destek@moyoapp.com.tr`'ye tek satır: talep no `D-…`, uygulama, konu, "Panelde aç"; kişinin e-postası, adı ve mesajı bildirime girmez; Resend ya da test SMTP'si; başarısız bildirim talebi düşürmez; kullanıcı kararı 20 Kasım 2026) → panel **Destek** ekranı → "Yanıtla" ekibin e-posta uygulamasında taslak açar (Kimden `destek@`: Gmail'de "Farklı bir adresten posta gönder", `CANLIYA_ALMA` 1.4) → durum "Yanıtlandı". Sabit adres `…/functions/v1/support` (GET) `LEGAL_PUBLIC_URL` köküne `/destek` olarak yönlenir: App Store **Support URL** ve uygulamalardaki "Yardım ve iletişim" bunu kullanır (alan adı gelince uygulama sürümü gerekmez). **Sınırlar** (`proposed/20261121110000_support_invite_limits.sql`, 21 Kasım 2026, güvenlik denetimi; önce saatte toplam 60 tek sayaçtı, tek kişi formu herkese kapatabiliyordu): kaynak başına saatte 5 ve 24 saatte 15 (`too_many_source`); e-posta başına 24 saatte 3 (`too_many`; kaynak biliniyorsa yalnız aynı kaynaktan açılanlar sayılır, kaynak yoksa yalnız kaynaksız açılanlar: başkası bir kişinin adresini yazarak onun formunu kapatamaz; KVKK konusu muaf); kaynaksız talepler (eski işlev, secret ya da adres yok) paylara ek olarak kendi ortak kovasında saatte 30, KVKK 10 (`busy`); genel saatte 300 yalnız son çare ("istenmeyen" işaretlenenler ve KVKK sayılmaz, `busy`; doluyken son bir saatte yazmamış ve geniş ağından (IPv4 /24, IPv6 /48) da yazılmamış bilinen kaynak yine bir talep açar, sert tavan saatte 600); sınır iletileri destek@moyoapp.com.tr adresini önerir; sayaçlar danışma kilidiyle sıraya alınır (paralel istek aşamaz); "Kişisel verilerim (KVKK)" ayrı paydan saatte 100 (genel sınır dolsa da kabul, kaynak sınırına tabi; doluyken aynı ilk kez yazan kuralıyla bir KVKK talebi, sert tavan saatte 200). Kaynak: Worker gönderenin adresini (`CF-Connecting-IP`) `x-moyo-client-ip` ile ve paylaşılan secret `SUPPORT_FORWARD_KEY`'i `x-moyo-forward-key` ile iletir; işlev adrese yalnız anahtar sabit sürede eşleşirse güvenir, yoksa (her doğrudan çağıran gibi, `cf-worker` başlığına bakılmaz) kendi gördüğü adresi kullanır; secret tanımlı değilse kaynak yok (kaynaksız kova; `CANLIYA_ALMA` 1.4). Adres ayrıştırılır (IPv4'e eşlenmiş IPv6 → IPv4) ve düz saklanmaz: günlük rastgele tuzla SHA-256 (`support_requests.source_hash`, IPv6 /64; geniş ağ için ikinci özet `source_wide_hash`, yalnız ilk kez yazan istisnasında bakılır), sayımda bugünün ve dünün tuzu (gün dönümünde sayaç sıfırlanmaz), tuz ve özetler 2 gün sonra silinir, panel kuyruğu özetleri göstermez. **Davet e-postası sınırları** (aynı öneri; `invite-email`): alıcı başına 24 saatte 3, 7 günde 6 (`rate_recipient`; bir davetin 3 gönderimi sığar; Gmail, Proton, Yandex (alan adları ve `.` = `-`), Apple (me.com / mac.com = icloud.com), Türkçe karakterli alan adının Unicode / Punycode yazımları, `+etiket`, tırnak, sondaki nokta ve görünmez karakter takma adları tek alıcı; Fastmail alt alan adı adreslemesi birleşmez), uzman başına 24 saatte 20 ve ilk 24 saatte 5 (`rate_clinician`), sistem payı yerleşik hesaplara saatte 200, yeni hesaplara ayrı 60 (`rate_global`; yerleşik olmayan hesabın, deneme süresindeki uzman dahil, kayan 24 saatteki ilk 2 gönderimi bu pay dolu diye reddedilmez, sert tavan 150); davet adresi oluşturulurken biçim denetlenir ("E-posta adresi geçersiz"; yerel kısım ASCII ve RFC atext işaretleri, `&` `=` dahil; Türkçe karakterli alan adı kabul; görünmez karakter, bölünmez boşluk, tırnak, ayraç, çift ya da sondaki nokta reddedilir). Uzman adı, unvanı ve klinik adı e-postada temizlenir (bağlantı, adres, başka alfabelerin noktaya benzeyen karakterleri ve 5+ haneli telefon numarası çıkar; geriye ad kalmazsa "Uzmanınız", klinik adı yazılmaz). Worker'ın 404/502 sayfaları `no-store`. Sistem sağlığı: 2 günden uzun yanıtsız talep sarı; son 24 saatte kaynaksız talep geldiyse "Destek formu kaynak sınırı" sarı (`SUPPORT_FORWARD_KEY` eksik ya da eski `support` işlevi yayında; `CANLIYA_ALMA` 1.4). Saklama: kapanan 2 yıl, istenmeyen 30 gün (gece imha işi, `support_days`). Spam artarsa: Cloudflare Turnstile (ücretsiz; secret Supabase'e). Benchmark: Zammad web formu ve tuzak alanı, osTicket konu seçimi, Chatwoot yanıt süresi notu, laravel-honeypot doldurma süresi, Apple 1.3/1.5 ve App Store Connect Support URL açıklaması.

### Davet ödülleri (`migrations/20261103200000_referral_codes.sql`, uygulandı 3 Kasım 2026; kullanıcı kararı: kod havuzu, elle giriş yedek)

| Fonksiyon | Rol | Ne yapar |
|---|---|---|
| `admin_referral_overview()` | herkes | Davet KPI'ları (kod oluşturulan / kullanılan / abone olan, verilen ödül ayı), kod bekleyen ödüller (aile, tarih, aylık/yıllık), son gönderilenler (kodun son 4 karakteri), havuz ve partiler |
| `admin_offer_codes_add(kodlar, ürün, son tarih, parti, gerekçe)` | finance | App Store Connect'ten indirilen tek kullanımlık kod dosyası; bekleyenlere hemen atanır |
| `admin_offer_codes_remove(parti, gerekçe)` | finance | Yanlış yüklenen partinin atanmamış kodlarını ya da süresi geçmiş kodları siler |
| `admin_referral_send_code(ödül, kod?, gerekçe)` | finance, support | Tek ödüle havuzdan ya da elle kod (yedek) |

Panel ekranı **Davetler** (`#/davet`). Kodun tamamı panelde ve denetim kaydında görünmez (kodu yalnız aile ParentApp davet sayfasında görür). Sistem sağlığı "Davet ödülü kodları" satırı havuz azalınca uyarır. Ekip işi: App Store Connect › ParentApp › aylık ve yıllık ürün › Offer Codes › "1 ay ücretsiz" (mevcut aboneler) › tek kullanımlık kodlar → dosyayı indir → panelde Davetler › "Kod dosyası yükle" (ürün ve son tarih seçilir). Kodlar en çok 6 ay geçerli; havuz 14 günden az kalan kodu atamaz.

### İzleme ve alarm

Benchmark (2 Kasım 2026; kaynaklar DURUM satırında): Supabase Free'de log 1 gün ve uyarı kuralı yok, Log Drains yalnız Pro+ ve ücretli → **dışarıdan yoklama** + **içeride denetim işlevi** seçildi (Sentry/Healthchecks deseni).

1. `ops_health()` her denetimi ok / info / warn / fail olarak döner (kişisel veri yok).
2. Edge Function **`health`** (Verify JWT kapalı): 200 ya da 503 + yalnız genel durum.
3. **GitHub Actions** `ortak/.github/workflows/saglik.yml`: her saat :41'de yoklar; 503 ya da yanıt yoksa iş kırmızı biter, GitHub e-posta gönderir (bildirim, dosyadaki zamanlamayı en son değiştiren hesaba gider; e-posta gelmiyorsa kullanıcı dosyadaki dakikayı GitHub'da bir kez değiştirsin). İşlev yayında değilse (404) yeşil biter.
4. İsteğe bağlı ikinci kanal (telefona anlık): **Sentry Uptime** (ücretsiz planda 1 izleyici, 1–60 dk aralık) → adres `…/functions/v1/health`, anahtar konmaz. Kurulursa `hukuk/41-alt-isleyenler.md`'ye eklenir (kişisel veri gitmez).
5. Gece imha işi kendi sonucunu `retention_runs`'a yazar; `ops_health` son 26 saatte çalışmadıysa sarı, hata verdiyse kırmızı.
6. Destek formu kaynağı (`support_source`, "Destek formu kaynak sınırı"): son 24 saatte "istenmeyen" olmayan kaynaksız destek talebi varsa sarı. Anlamı: `SUPPORT_FORWARD_KEY` Worker'da ve Supabase'de yok ya da eski `support` işlevi yayında; o arada bütün form saatte 30 talep (KVKK 10) kaynaksız kovayı paylaşır. Yapılacak: anahtarı iki yere ekle, `support`'u yeniden yayınla (`CANLIYA_ALMA` 1.4); son kaynaksız talep 24 saati geçince yeşile döner.

## Uygulamaların okuması: `client_config(app)`

Her uygulama açılışta (ve ön plana gelince) çağırır: `{"app": {"min_version", "maintenance", "banner"}, "flags": {"<key>": true|false}}`.

- `min_version` uygulama sürümünden büyükse: "Güncelleme gerekli" ekranı (App Store'a gider).
- `maintenance = true`: "Kısa bir bakım yapıyoruz" ekranı.
- `banner`: üstte kapatılabilir duyuru.
- Bayrak sırası: kişiye istisna (süresi dolmamış) → genel bayrak (açık + yüzde) → kapalı.

## KPI tanımları

Kaynak: `activity_days` (her gün `track_session` bir satır yazar; geçmiş seri bu göçten sonra birikir), `user_activity`, `families`, `children`, `tasks`, `completions`, `family_subscriptions`, `billing_subscriptions`, `clinic_*`, `app_events`, `notifications`, `push_tokens`.

| KPI | Tanım | Fonksiyon |
|---|---|---|
| DAU / WAU / MAU | Uygulama başına bugün / son 7 / son 30 günde en az bir oturumu olan kişi | `admin_kpi_summary` → `active` |
| Yapışkanlık | DAU / MAU | aynı |
| Yeni | Son N günde açılan aile, ilk kez oyunu açan çocuk, klinik, uzman | `new` |
| Aktif abonelik | Mağaza premium aileler (aylık / yıllık), elle premium, ücretli klinik, elle klinik, denemedeki klinik | `revenue` |
| MRR (aylık tekrarlayan gelir) | Brüt: aylık × fiyat + yıllık × fiyat / 12 (aile fiyatları `app_config.kpi`, klinik `billing_plans.price_try`). Net: brüt × (1 − mağaza %15) × (1 − RevenueCat %1). Tahmindir; gerçek tahsilat App Store Connect raporlarındadır | `revenue.mrr_*` |
| Deneme → ücretli | Denemesi son N günde biten ailelerden bugün mağaza premium olanların oranı | `trial` |
| Kayıp (churn) | Son N günde süresi biten/iade edilen aile abonelikleri; üyeliği biten klinikler | `churn` |
| Etkileşim | Oluşturulan görev, tamamlanan, onaylanan, onay oranı, onay süresi ortancası (dk), aktif çocuk, bildirim okunma oranı, bildirim açık kullanıcı | `engagement` |
| Klinik | Etkin paylaşım, danışanı olan klinik, öneri, not, rızası geri alınan | `clinic` |
| Uygulama bazında | ParentApp (aile, abone, deneme, gelir, görev/onay, ödül, bildirim), GameApp (çocuk, bağlı cihaz, aktif çocuk, "Yaptım", ödül isteği, bildirim), ClinicApp (klinik, uzman, ücretli/deneme/elle, gelir, paylaşım, öneri, not, bildirim) + toplam gelir | `admin_kpi_apps(gün)` (`migrations/20261024000000_admin_fixes.sql`, uygulandı 24 Ekim) |
| Aile davet hunisi | Son N günde oluşturulan aile davetleri: gönderildi → açıldı → kayıt/kod → çocuk paylaşıldı; süresi dolan, uzmanın iptal ettiği, ailenin reddettiği. Toplam, paylaşım yoluna ve uzmana göre (durumlar P15) | `admin_kpi_invites(gün)` (`migrations/20261026200000_admin_invite_funnel.sql`, uygulandı 26 Ekim) |
| Günlük seri | Gün × uygulama: aktif ve yeni kullanıcı (en çok 1 yıl) | `admin_kpi_daily(from, to)` |
| Elde tutma | İlk görülme haftası kohortu; G1/G7/G30 = ilk günden 1/7/30 gün sonra yeniden aktif olanların oranı (henüz dolmamışsa boş) | `admin_kpi_retention(hafta)` |
| Huniler | **parent:** kayıt → e-posta onayı → çocuk eklendi → cihaz bağlandı → ilk görev → ilk onay → ücretli. **child:** eklendi → bağlandı → oyunu açtı → ilk "Yaptım" → ilk onay → 7. gün aktif. **clinic:** açıldı → ilk aile → ilk öneri → ilk not → ücretli | `admin_kpi_funnel(app, from, to)` |
| Huni (App Store → yenileme; ÖNERİ `20261120220000`) | Kümülatif adımlar, ilk adıma ve öncekine göre %, önceki adımdan medyan saat, adımda kalanların son ekranı, iptal nedeni, kpis `{value, n}`; adım tanımları aşağıda "Huni, abonelik sağlığı ve kıyas" | `admin_funnel(ürün, from, to)`, `admin_funnel_people` |
| Abonelik sağlığı (ÖNERİ `20261120220000`) | Aktif ücretli, denemede, deneme → ücretli, yeni, kayıp, 30 günlük kayıp, yenileme, iade, ödeme sorunu, MRR (aylık eşdeğer), ARPU, plan ve hafta kırılımı | `admin_subscription_health(ürün, from, to)` |
| Kıyas (ÖNERİ `20261120220000`) | Anahtar başına dış kaynaklı değer ve aralık (`low`–`high`), iyi yönü (`better`); yalnız iç karşılaştırma | `admin_benchmarks()` |
| Otomatik bildirim (ÖNERİ `20261120230000`) | Kural başına gönderilen, açılan, 72 saatte hedefe geçen; karşılaştırma grubu ve fark (yüzde puanı) | `admin_nudge_stats(ürün, from, to)` |
| Özellik kullanımı | En sık olaylar ve kullanıcı sayısı (`track_events`) | `admin_kpi_events(app, gün, limit)` |

Klinik sınırı: KPI'lar ürün kullanımını ölçer; hiçbir gösterge çocuk için tanı, zekâ ya da dikkat puanı değildir ve panelde çocuk bazında puan gösterilmez.

## Huni, abonelik sağlığı ve kıyas (ÖNERİ `proposed/20261120220000_funnel_analytics.sql`, 20 Kasım 2026; uygulanmadı; test `test_funnel_analytics.sql`)

Kullanıcı isteği (20 Kasım 2026): App Store'u görmekten ödemeye kadar nerede düşüldüğü, kim hangi ekranda kaldı, abonelik sağlığı, global kıyaslar. Bütün yüzdeler **0–100**. Her `kpis` alanı `{"value", "n"}` (`n` payda; `n` = 0 ise `value` null; panel küçük örneği `n`'den anlar). Eski `admin_kpi_funnel` kalır.

| Fonksiyon | Rol | Ne yapar |
|---|---|---|
| `admin_funnel(ürün, başlangıç, bitiş)` | okur | `{product, from, to, cohort_size, store {impressions, page_views, downloads} \| null, steps [{key, label, count, pct_of_first, pct_of_prev, median_hours_from_prev, note?}], drops [{after, lost, top_exits [{screen, count}]}], cancel_reasons [{reason, count}], kpis {store_tap_through, store_page_conversion, download_to_signup, signup_to_activation}}`. Ürün `parent` / `clinic`, aralık en çok 1 yıl |
| `admin_funnel_people(ürün, adım, başlangıç, bitiş, limit=50)` | support (owner) | O adımda kalanlar (art arda ulaştığı son adım = `adım`; `drops[].after` ile aynı anahtar): `[{id, id_short, kind, joined_at, reached, last_event, last_screen, last_seen, state}]`. `kind` `family` (id = aile kimliği → `admin_family`) / `user` (id = uzmanın kimliği → `admin_user`). `state` müşteri ekranının adları: aile `trial` / `premium` / `clinic` / `pending` / `expired`, uzman (varsayılan kliniği) `paid` / `manual` / `trial` / `expired`. E-posta, ad, çocuk adı **yok**. App Store adımları kişi bazında değildir (`[]`). En çok 500 |
| `admin_subscription_health(ürün, başlangıç, bitiş)` | okur | `{active_paid, in_trial, trials_started, trials_ended, trial_to_paid_pct, new_paid, churned, churn_pct_30d, renewals, refunds, billing_issues, mrr_try, arpu_try, prices_set, by_plan [{plan, active, mrr_try}], weekly [{week, trials, paid, churned}], kpis {trial_to_paid, monthly_churn, monthly_renewal_m1, annual_renewal, annual_share, refund_rate, billing_issue_rate}, notes}`. `active_paid`, `in_trial`, `mrr_try` bugüne göre; ötekiler aralığa göre. `week` = haftanın pazartesisi (`YYYY-MM-DD`, Türkiye saati) |
| `admin_benchmarks()` | okur | `[{key, product, label, value, unit, better, low, high, source, source_url, as_of, note, updated_at}]` (tablo `kpi_benchmarks`). `low` / `high` sayısal alt / üst sınır (iyi / kötü değil); `better` `high` (büyük iyi) / `low` (küçük iyi: kayıp, iade, ödeme sorunu). Yalnız iç karşılaştırma; pazarlamada kullanılmaz (`hukuk/45`) |
| `admin_benchmark_set(anahtar, ürün, değer, alt, üst, kaynak, kaynak_url, tarih, gerekçe, not=null)` | owner | Aynı anahtar + ürün üzerine yazar; değer, alt, üst üçü de boşsa siler. Ad, birim, yön anahtarın sabit eşlemesinden (`kpi_benchmark_meta`; seed'de verilmezse tetikleyici doldurur). Yüzde 0–100, alt ≤ üst, bağlantı `https://`. Denetim `benchmark.set` / `benchmark.delete`, hedef `config` / `benchmark:<ürün>:<anahtar>` |
| `admin_store_funnel_set(ürün, gün, gösterim, ürün_sayfası, indirme, gerekçe)` | owner | App Store Connect › Analytics günlük değerleri (elle; ileride içe aktarma `source = 'import'`). Aynı gün üzerine yazar; üçü de boşsa siler. Gün bugünden ileri ya da 2 yıldan eski olamaz. Denetim `store_funnel.set` |

**Adımlar (anahtarlar sabit; sözleşme koordinatör 20 Kasım 2026).** Kümülatif: bir adım ancak öncekilerin hepsine ulaşanlar içinden sayılır (sayı hiç artmaz). Kohort: Moyo = aralıkta açılan **aile** (`families.created_at`), Moyo Mercek = aralıkta kayıt olan **uzman** (`clinicians.created_at`). `median_hours_from_prev` = önceki adımdan bu adıma geçen saatlerin ortancası (iki adıma da ulaşanlar). Tahmin olan zamanlar işaretli.

| Ürün | Adım | Kaynak |
|---|---|---|
| ikisi | `store_impression`, `store_page_view`, `store_download` | `store_funnel_daily` (aralıktaki günlerin toplamı; veri yoksa `count` null + `note`) |
| parent | `signup` | `families.created_at` |
| parent | `email_verified` | aileyi açanın `auth.users.email_confirmed_at` (yoksa ailedeki ilk onay, yoksa `trial_started_at`) |
| parent | `child_added` | ilk `children.created_at` |
| parent | `game_linked` | `children.user_id` dolu; zaman **tahmin**: çocuk satırı ile oyunun anonim hesabından geç olanı (bağlanma anı tutulmuyor) |
| parent | `first_routine` | ilk `tasks.created_at` |
| parent | `first_done` | ilk `completions.child_done_at` ("Yapamam" sayılmaz) |
| parent | `first_approved` | ilk ebeveyn onayı (`status = approved`, `reviewed_by` dolu; `reviewed_at`) |
| parent | `active_d7` | ebeveynlerden birinin kayıttan 7–13 gün sonra etkin günü (`activity_days`) |
| parent | `trial_end` | deneme sonu geçti (`trial_started_at` + `trial_days` / `billing.trial_days`, davet ödülü `bonus_until`; `family_access_of` ile aynı) |
| parent | `paid` | `family_subscriptions.started_at` (kaynak `store` / `web`; elle verilen sayılmaz) |
| parent | `renewed` | **tahmin**: aile aboneliğinin geçmişi tutulmuyor; dönem sonu başlangıç + 2 dönem − 3 günü aştıysa yenilenmiş (zaman = başlangıç + 1 dönem) |
| clinic | `signup` | `clinicians.created_at` |
| clinic | `survey_done` | atlanmamış `clinician_surveys` satırı |
| clinic | `first_invite` | ilk aile daveti (`clinic_invites`, `kind = family`, `clinician_id`) |
| clinic | `family_linked` | sorumlusu olduğu ya da kendi açtığı klinikteki ilk paylaşım (`clinic_links.created_at`) |
| clinic | `first_training` | ilk Etkin eğitim (`parent_trainings.activated_at`) |
| clinic | `active_w2` | kayıttan 7–13 gün sonra etkin gün |
| clinic | `trial_end` | kendi açtığı alanların en geç `trial_ends_at`'i geçti |
| clinic | `paid` | kendi kliniğinde ilk mağaza üyeliği (`billing_subscriptions`, `source <> manual`) |
| clinic | `renewed` | RevenueCat `RENEWAL` olayı (`billing_events.payload.type`) ya da dönem sonu ilk dönemi aştı |

Çıkış noktası (`top_exits`): o adımda kalanların ParentApp / ClinicApp'teki son `screen.*` olayı (yoksa `app.open` dışındaki son olay, o da yoksa `(olay yok)`), en sık 5. İptal nedeni: `membership.cancel_reason` olayının `reason`'ı, aralıkta kişi başına (`akislar.md` 9).

**Kıyas anahtarları (kpis ve `kpi_benchmarks.key`):** `store_tap_through` (pv / gösterim), `store_page_conversion` (indirme / pv), `download_to_signup` (kohort / indirme; Mercek web kaydı indirmesiz olabildiği için %100'ü aşabilir), `signup_to_activation` (parent: kayıttan 7 gün içinde ilk ebeveyn onayı, payda kaydının üzerinden 7 gün geçenler; clinic: 14 gün içinde ilk aile bağlandı), `trial_to_paid` (aralıkta denemesi bitenlerden ücretli olan), `monthly_churn` (aralığın sonundaki 30 günde: pencere başında ücretli olanlardan biten), `monthly_renewal_m1` / `annual_renewal` (ilk dönemi aralıkta biten aylık / yıllık aboneliklerden yenilenen; sonuç 3 gün sonra kesinleşir), `annual_share` (aktif ücretlilerde yıllık payı), `refund_rate` (iade / (yeni + yenileme)), `billing_issue_rate` (ödeme sorunu / aktif ücretli), `d1_retention`, `d7_retention`, `d30_retention` (`admin_kpi_retention`).

**Abonelik verisi notları:** Moyo'da `family_subscriptions` aile başına tek satırdır (geçmiş yok): kayıp ve iade son güncellemeden (`status` expired / refunded, `updated_at`), ödeme sorunu `status = grace`, yenileme dönem sonundan tahmin. Moyo Mercek'te `billing_events` (her webhook'ta `apply:<durum>`, `payload.type` RevenueCat olay türü): bitiş = son etkin olaydan sonraki ilk `apply:expired|refunded`, yenileme `RENEWAL`, ödeme sorunu `BILLING_ISSUE`. MRR KDV dahil brüt, aylık eşdeğer (yıllık / 12); fiyatlar Moyo `app_config.kpi` (`parent_monthly_try` 349,99, `parent_yearly_try` 3.499,99; öneri bu değerleri 0 ise yazar, `admin_set_kpi_config` ile değişir), Moyo Mercek `billing_plans.price_try` (`ekonomi.md` 9). Elle verilen premium / üyelik ücretli sayılmaz.

## Otomatik bildirim motoru (ÖNERİ `proposed/20261120230000_nudge_engine.sql`, 20 Kasım 2026; uygulanmadı; test `test_nudge_engine.sql`; akış `akislar.md` 25 "Sunucu motoru")

| Fonksiyon | Rol | Ne yapar |
|---|---|---|
| `admin_nudge_stats(ürün, başlangıç, bitiş)` | okur | Kural başına `[{rule, label, enabled, category, sent, opened, converted, holdout, holdout_converted, lift_pct, skipped {limit, quiet, pref}}]`. `converted` = 72 saatte kuralın hedef adımına geçen; `lift_pct` = gönderilenlerin dönüşüm yüzdesi − karşılaştırma grubunun dönüşüm yüzdesi (**yüzde puanı**; ikisinden birinde kayıt yoksa null). `skipped` atlanan kişi + ref sayısı (aynı gün tekrarları sayılmaz). Hesap bilgisi kuralları (deneme bitişi) karşılaştırma grubuna girmez: `holdout` 0, `lift_pct` null |
| `admin_nudge_rules()` | okur | Kurallar: anahtar, ürün, ad, tetik, adımlar, bekleme, tür, başlık, metin, `route`, sıra, açık mı |
| `admin_nudge_rule_set(anahtar, açık, gerekçe)` | owner | Kuralı aç / kapat (metin değişmez; metin yalnız SQL ile). Denetim `nudge.rule`, hedef `config` / `nudge:<anahtar>`. Öneri yeniden çalıştırılınca owner'ın seçimi korunur |
| Bayrak `nudges_server` | owner | Yukarıda "Bayrak `nudges_server`" |

Zamanlama: `nudge_run()` (istemciye kapalı; `service_role` ve zamanlayıcı). pg_cron açıksa iş `nudge-run` her 15 dakikada (`7,22,37,52 * * * *`); `ops_health` "Zamanlayıcı" satırı bu işi de denetler.

