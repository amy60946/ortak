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
| `admin_grant_premium(family, bitiş, gerekçe)` / `admin_revoke_premium` | finance | Elle premium (`source=manual`, en çok 2 yıl). Etkin mağaza aboneliği varsa reddedilir |
| `admin_clinic_grant(clinic, plan_id, bitiş, gerekçe)` / `admin_clinic_revoke` | finance | `billing_apply('manual', …)` |
| `admin_suspend(user, bitiş?, gerekçe)` / `admin_unsuspend` | owner | `auth.users.banned_until` + oturumlar kapanır |
| `admin_delete_user(user, gerekçe)` | owner | `delete_account` ile aynı gövde (`account_delete_of`); geri alınamaz |
| `admin_set_flag(key, açık, yüzde, açıklama, gerekçe)` / `admin_flags()` | owner / okur | Genel bayrak; yüzde ile kademeli açılış (kullanıcıya sabit) |
| `admin_set_app_config(app, min_version, maintenance, banner, gerekçe)` / `admin_app_config()` | owner / okur | `app_config` anahtarı `app.parent` / `app.child` / `app.clinic` |
| `admin_set_kpi_config(jsonb, gerekçe)` | owner, finance | `app_config.kpi`: `parent_monthly_try`, `parent_yearly_try`, `store_fee_pct` (15), `revenuecat_pct` (1) |
| `admin_list_admins()` / `admin_set_admin(email, rol|null, gerekçe)` | owner | Admin yönetimi |
| `admin_verifications(durum='pending', limit)` | support | Uzman belge başvuruları (`20261026050000`, uygulandı): uzman, e-posta, klinik, meslek, BACB no, ön kontrol (`auto`), barkod, dosya var mı, önceki ret sayısı; bekleyenler en eskiden (barkod, BACB no ve e-posta içerdiği için yalnız support/owner, 26 Ekim denetimi) |
| `admin_verification_open(id)` | support | Belge yolunu döner ve görüntülemeyi denetim kaydına yazar. Panel bunu doğrudan değil, Edge Function **`verify-doc`** (`{action:'open', id}`) üzerinden çağırır; işlev 2 dk imzalı bağlantı döner. `20261026400000` (uygulandı 26 Ekim) ile `verify` kovası yöneticiye doğrudan kapalı (panel dışından açılıp kayıtsız kalamaz). Karar sonrası dosyaları `verify-doc` `{action:'purge'}` siler (`storage_trash`, `admin_can_review`) |
| `admin_verification_decide(id, onay, ret_nedeni, açıklama, barkod, özet, gerekçe)` | support | Onay → rozet (`clinicians.verified_profession/verified_at`) + bildirim; ret → neden kodu + uzmana açıklama. Özet yalnız `{university, program, degree, graduation_year}`. Dönen belge yolunu panel kovadan **siler** |
| `admin_verification_suspend(uzman, açıklama, gerekçe)` | support | Rozeti askıya alır (şikâyet, BCBA süresi) |

Bayrak `clinician_verification` (`20261026050000`, uygulandı; varsayılan **kapalı**): belge incelemesini uygulamalarda görünür yapar. `admin_set_flag('clinician_verification', true, 100, …)` ile herkese, `admin_set_user_flag(uzman, 'clinician_verification', true, …)` ile önce tek uzmana açılır.

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
| Özellik kullanımı | En sık olaylar ve kullanıcı sayısı (`track_events`) | `admin_kpi_events(app, gün, limit)` |

Klinik sınırı: KPI'lar ürün kullanımını ölçer; hiçbir gösterge çocuk için tanı, zekâ ya da dikkat puanı değildir ve panelde çocuk bazında puan gösterilmez.
