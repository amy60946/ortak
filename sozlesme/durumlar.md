# Durum ve sabit değer sözleşmesi

Uygulamalar arasında taşınan bütün "durum" ve sabit metin değerleri. **Yazım birebir aynı olmalı** (küçük harf, İngilizce;
yalnız `gender` Türkçe). Yeni bir değer eklenecekse önce bu dosya ve SQL güncellenir, sonra uygulamalar.

Kaynak:
- `parent-app/supabase/migrations/20261013000000_init.sql`, `20261014000000_task_repeat_order.sql`
- `game-app/supabase/proposed/20261015000000_pofi_game.sql` (uygulandı)
- `ortak/supabase/migrations/20261019000000_clinic.sql` (uygulandı); `parent-app`, `src/lib/clinic.ts`
- `game-app/Assets/_Pofi/Scripts/Logic/Tasks/ChildTask.cs`, `Services/Supabase/SupabaseGameService.cs`, `Services/IGameServices.cs`, `Services/IAuthService.cs`, `Profile/AgeBand.cs`, `Auth/LoginThrottle.cs`, `Services/ServerConfig.cs`, `Data/Definitions.cs`
- `parent-app/src/store.tsx`, `src/theme.ts`, `src/data/ageBands.ts`, `src/data/templates.ts`, `src/screens/TasksScreen.tsx`, `src/screens/ReviewScreen.tsx`
- `game-app/docs/PLAN.md`, `M4_SUNUCU_ONERISI.md`; `clinic-app/CLAUDE.md`

Son güncelleme: 2026-10-19

---

## 1. Görev tamamlama durumu (`completions.status`)

SQL kısıtı (M4 sonrası): `status in ('pending', 'approved', 'declined', 'rejected')`; öneri `20261027130000_review_detail` ile + `'retry'`.

| Sunucu değeri | Anlamı | Kim yazar | Oyun (C# `ChildTaskStatus`) | ParentApp (TS `CompletionStatus`, etiket) | Coin |
|---|---|---|---|---|---|
| *(kayıt yok)* → `'assigned'` | Atanmış, henüz işaretlenmedi | — (`child_tasks` kayıt yoksa `'assigned'` döndürür; **tabloda saklanmaz**) | `Assigned` | (durum yok, etiket gösterilmez) | — |
| `pending` | Çocuk "Yaptım" dedi, ebeveyn bakacak | Oyun (`child_set_status`) | `ChildDone` | `pending` — "Onay bekliyor" | — |
| `approved` | Ebeveyn onayladı (ya da inceleme gerektirmeyen görevde çocuk "Yaptım" dedi) | ParentApp; inceleme yoksa sunucu `pending`→`approved` çevirir | `Approved` | `approved` — "Tamamlandı" | **+coins** (tetikleyici) |
| `declined` | Çocuk "Yapamam" dedi | Oyun (`child_set_status`) | `DeclinedByChild` | `declined` — "Yapamadı" | — |
| `rejected` | Ebeveyn not yazarak reddetti | ParentApp (`review_completion`) | `RejectedByParent` | `rejected` — "Reddedildi" | — (önce `approved` idiyse **−coins**) |
| `retry` (öneri 27 Ekim 2026) | Ebeveyn "Tekrar dene" dedi: görev çocuğa geri döner, notu oyunda görünür | ParentApp (`review_completion(..., 'retry', not)`) | eski oyun: bilinmeyen → `Assigned` (yapılacaklara döner); GameApp önerisi: `RetryByParent` (Atandı gibi işaretlenebilir + not) | `retry` — "Tekrar denesin" | — (önce `approved` idiyse **−coins**, −taş) |

Ek kurallar:
- `approved` ve `rejected` **nihai** durumdur: çocuk değiştiremez (`child_set_status` "Ebeveyn karar verdi" hatası; C# `ChildTask.IsFinal`).
- `retry` nihai **değildir**: çocuk yeniden `pending` (Yaptım) ya da `declined` diyebilir. Ebeveyn yalnız bugünün (± 1 gün) görevi için `retry` verebilir (hint `retry_past`); geçmiş gün oyunda "kaçırıldı"dır.
- İnceleme ayrıntısı (aynı öneri): `completions.motivation` 1 (çok kolay) … 5 (çok zor) = "motive etmek ne kadar zordu?" (ebeveyn gözlemi, isteğe bağlı; puan ya da tanı değildir; paylaşım açıksa uzman okur). `completions.stones` 0–6 = onayda verilen taş (boş = zorluğa göre, `ekonomi.md` 5A).
- Çocuğun geçişleri (C# `TaskRules.CanChange` ve SQL `child_set_status` ile aynı): `Assigned → pending | declined`; `pending | declined → assigned` (geri al = kaydı sil).
- `child_set_status` girdisi yalnız `pending` / `declined` / `assigned` kabul eder. C# `StatusText`: `ChildDone→"pending"`, `DeclinedByChild→"declined"`, `Assigned→"assigned"`, onay/ret için `null` (gönderilmez).
- C# `ParseStatus`: bilinmeyen her değer `Assigned` sayılır.
- **"Kaçırıldı" (missed)** yalnız oyunda hesaplanır, sunucuda yoktur: durum `Assigned` ve yerel saat görev gününün sonunu (23:59:59.9999999) geçtiyse. Ceza yok; oyun o görevin işaretlenmesine izin vermez.
- ParentApp görev listesinde birden fazla çocuğa atanmış görev için tek etiket seçer: herhangi biri `pending` → `pending`; hepsi `approved` → `approved`; biri `rejected` → `rejected`; biri `declined` → `declined`.
- ParentApp **İnceleme** ekranı yalnız `pending` olanları listeler. Birden çok çocuklu görev etiketinde `retry`, `pending`'den sonra gelir.

### 1.1 Tutarsızlıklar / dikkat edilecekler
| # | Konu | Ayrıntı |
|---|---|---|
| D1 | `assigned` hiç saklanmaz | `'assigned'` yalnız RPC girdisi/çıktısıdır; `completions` kısıtında yoktur. ClinicApp raporlarında "atanmış" = **kayıt yok** olarak hesaplanmalı. |
| D2 | ~~Onay iki farklı yolla~~ | **Karar (19 Ekim):** ParentApp onayı da reddi de `review_completion` ile yapar (ParentApp güncellendi; sunucu değişikliği gerekmez). |
| D3 | Tarih sınırı farklı | Oyun "kaçırıldı" görevi (geçmiş gün) işaretletmez; sunucu `child_set_status` yalnız **gelecek** günü (`p_date > current_date + 1`) reddeder, geçmiş günlere sınır koymaz. `current_date` sunucu saat dilimine göredir (doğrulanmalı: Supabase varsayılanı UTC), oyun yerel tarihi kullanır. |
| D4 | ParentApp `toggleCompletion` | `store.tsx`'te ebeveynin kendi adına `pending`/`approved` yazdığı bir fonksiyon var ama hiçbir ekranda kullanılmıyor (Görevler'deki tamamla yuvarlağı kaldırıldı, `DURUM.md`). |
| D5 | Ret sonrası coin | `rejected` coin vermez; daha önce `approved` olan bir kayıt `rejected`'a çekilirse tetikleyici coini geri düşer (`task_undo`). |

---

## 2. Görev alanları

| Alan | Değerler | Kaynak | Not |
|---|---|---|---|
| `task_assignments.difficulty` | `easy` / `medium` / `hard` | SQL, TS `Difficulty` | ParentApp etiketleri: Kolay / Orta / Zor. Varsayılan coin: 5 / 10 / 20 (`ekonomi.md`). Oyun zorluğu kullanmaz (`child_tasks` döndürmez). |
| `tasks.repeat_kind` | `daily` / `weekly` / `monthly` (varsayılan `daily`) | SQL, TS `RepeatKind` | Yalnız `recurring = true` iken anlamlı. C# `Recurrence`: `Once` (recurring=false), `Daily`, `Weekly`, `Monthly`; bilinmeyen tür `Daily` sayılır. |
| `tasks.repeat_days` | haftalık: 1 = Pazartesi … 7 = Pazar (ISO); aylık: 1 … 31 | SQL | Ayda o gün yoksa ayın son günü. |
| `tasks.reminder` | `HH:MM` (regex `^[0-2][0-9]:[0-5][0-9]$`) | SQL | |
| `tasks.requires_review` | `true` (varsayılan) / `false` | SQL | `false` ise çocuğun "Yaptım"ı doğrudan `approved` olur. |
| `saved_templates.category` | `home` / `mind` / `learn` / `self` | SQL, `templates.ts` | Etiketler: Ev İşleri / Ruh Sağlığı / Öğrenme / Kişisel Bakım. |
| Oyun görev anahtarı | `"<task_id>|<yyyy-MM-dd>"` | C# `ChildTask.Key` | ParentApp yerel anahtarı farklı: `"<task_id>|<child_id>|<date>"`. Yalnız istemci içinde; sunucuya gitmez. |

---

## 3. Kod türleri

| Tablo / alan | Değer | Anlamı | Geçerlilik | Kaynak |
|---|---|---|---|---|
| `invite_codes.kind` | `parent` | İkinci ebeveyn daveti (`join_family`) | 24 saat, tek kullanım | SQL (uygulandı) |
| `invite_codes.kind` | `child` | Çocuğun oyuna giriş kodu (`redeem_child_code`); `child_id` zorunlu | 24 saat, tek kullanım; aynı çocuğa yeni kod eskisini geçersiz kılar | SQL (uygulandı) |
| `clinic_invites.kind` | `family` | Uzmanın aile daveti: 6 karakter kod + 32 karakter bağlantı anahtarı (`token`, `https://<alan adı>/d/<token>`) | 15 dk → 48 saat (`20261026100000`) → **3 gün** (`20261027000000`); aileye bağlanınca 30 gün | uygulandı (26 Ekim 2026) |
| `clinic_invites.kind` | `clinician` | Klinik ekibine katılım kodu (yalnız `owner` üretir; kayıtta `team_code`) | 7 gün, tek kullanım | uygulandı |

Kod biçimi:
- Sunucu üretimi (`random_code`): 6 karakter, alfabe `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (I, L, O, 0, 1 **yok**). `invite_codes.code` kısıtı `^[A-Z0-9]{6}$`. `clinic_invites.code` için kısıt yok (öneri).
- Oyun girişi (`ChildCode.Normalize`): küçük harf büyütülür, harf/rakam dışı karakterler atılır, uzunluk tam 6 olmalı. ParentApp: `trim().toUpperCase()`.
- Oyunun deneme kodları `A1A1A1`, `B2B2B2`, `C3C3C3`: `ServerConfig.DemoCodes = true` iken `RoutedAuthService` bunları sahte arka uca yönlendirir (sunucuya gitmez). `A1A1A1` sunucu alfabesinde olmayan `1` içerdiği için gerçek bir kodla çakışamaz; `B2B2B2` ve `C3C3C3` ise sunucu alfabesine uyar, yani çok düşük olasılıkla gerçek bir kodla aynı olabilir ve o durumda oyun gerçek kodu sahte arka uca gönderir. Mağaza sürümünde `DemoCodes` kapatılmalı (doğrulanmalı).
- Oyunda hatalı kod beklemesi (istemci, `LoginThrottle`): 3 deneme serbest, sonra 15 sn'den başlayıp her hatada ikiye katlanır, en fazla 300 sn. **Sunucu** (`20261019020000_server_rules`, uygulandı 19 Ekim): oturum başına 15 dakikada 10 hatalı deneme → HTTP 429 `{"error":"too_many_attempts"}`; hatalı kod → HTTP 400 `{"error":"invalid_code"}` (artık hata fırlatılmaz ki deneme sayılabilsin). Oyun 429'u `Throttled` sayar.

---

## 4. Yaş bandı (`children.age_band`)

> **UYGULANDI (22 Ekim 2026, kullanıcı kararı — XP takibi S1; `migrations/20261022220000_age_bands_four.sql`):** dört grup. Canlı kısıt `age_band in ('K', 'A', 'B', 'C')`.
>
> | Değer | Yaş | ParentApp etiketi | `suggest_age_band` | Oyun günlük XP sınırı |
> |---|---|---|---|---|
> | `K` | 5 ve altı | "5 ve altı" | yaş < 6 | 200 |
> | `A` | 6–8 | "6–8 yaş" | doğum günü yok ya da 6 ≤ yaş < 9 | 250 |
> | `B` | 9–12 | "9–12 yaş" | 9 ≤ yaş < 13 | 300 |
> | `C` | 13 ve üstü | "13 ve üstü" | yaş ≥ 13 | 350 |
>
> Seviye eşikleri gruba göre (`game_level_bands`, oyun `levels.json` `xpToNextByBand`); sunucunun harcama seviye kilidi (`child_level`) çocuğun grubunu kullanır. B tablosu bugünküyle aynı. Eski oyun sürümü `K`'yı A sayar. Aşağıdaki iki bantlı metin (19–21 Ekim) tarihe geçti.
> **ParentApp penceresi:** çocuk ekleme/düzenleme ekranında dört seçenek (`set_child_age_band` K/A/B/C).

**Tek kaynak (23 Ekim 2026; `20261023040000_age_band_single_source.sql`):**
- Sınırlar yalnız sunucudaki `public.age_band(doğum_günü, gün)` işlevinde: yaş < 6 → `K`, < 9 → `A`, < 13 → `B`, aksi `C`; doğum günü yoksa `A`. Gün verilmezse **Türkiye'nin bugünü** (`Europe/Istanbul`). Uygulamalar bu sınırları kendileri hesaplarsa yalnız gösterim içindir ve aynı kuralı kullanır.
- `children.age_band` **yalnız ebeveynin bilerek seçtiği** gruptur; `null` = **otomatik** (doğum gününden, çocuk büyüdükçe kendiliğinden değişir). ParentApp çocuk eklerken grup yazmaz; düzenleme ekranında "Otomatik (doğum gününden)" + K/A/B/C seçenekleri vardır.
- Etkin grup her yerde `child_age_band(child) = coalesce(age_band, age_band(birthday))`: `redeem_child_code`, `child_me` ve seviye kilidi (`child_level`) aynı değeri verir. **Oyun grubu her eşitlemede `child_me`'den okur** (girişte dondurmaz).
- Seviye düşmez: grup büyüyünce aynı XP daha küçük seviyeye denk gelebilir; oyun ulaşılan en yüksek seviyeyi kaydında tutar (`Xp.BestLevel`), sunucu `child_level` bunu korur (aynı XP ile K tablosunun verebileceğinden yüksek olamaz).
- **Eski kayıtlar Otomatik'e** (kullanıcı kararı, 23 Ekim 2026; uygulandı `migrations/20261023050000_age_band_reset_auto.sql`): daha önce elle ya da eski ParentApp'in kendiliğinden yazdığı gruplar bir kez silinir (`null`); iş `one_time_jobs`'a işaretlenir, yeniden çalıştırılınca sonradan bilerek seçilen grup korunur.
- **Raporlar ve ayrıntılı analizler** kaydedilmiş gruba bakmaz (değişebilir, geçmişi yok): olay günündeki gerçek yaşı `age_years(doğum_günü, olay_günü)` ile hesaplar; grup gerekirse `age_band(doğum_günü, olay_günü)`.
- Oyun bilinmeyen/boş değeri **`A`** (en güvenli) sayar (`AgeBandProfile.Parse`).
- Tarih: doğum günü takvim günüdür (saat dilimi yok); uygulamalar `YYYY-MM-DD`'yi yerel gün olarak okur, UTC'ye çevirmez.

- Banda bağlı oyun ayarları (tema, ses, günlük XP sınırı …): `ekonomi.md` 5. bölüm.
- Apple Kids kategorisi bantları (5 ve altı / 6–8 / 9–11) mağaza seçimidir, oyun bantlarından ayrıdır (`game-app/docs/PLAN.md` §9).

### 4.1 App Store / Google Play
- Mağaza **Kids Category dışında**, yaş derecelendirmesi en düşük (4+); Kids kurallarına gönüllü uyulur: üçüncü taraf reklam/analitik yok, dış bağlantı ve satın alma ebeveyn kapısının (`ParentGate`) arkasında. Kaynak: `game-app/docs/PLAN.md` §9 (Seçenek A).
- Apple Kids bantları (5 ve altı / 6–8 / 9–11) mağaza sınıflandırmasıdır; oyunun iç bantlarıyla aynı olmak zorunda değildir.
- Yaş **çocuktan sorulmaz**: doğum gününü ebeveyn ParentApp'te girer (ebeveyn onayı orada). Oyun yalnız bandı alır.

---

## 5. Coin defteri nedeni (`coin_ledger.reason`)

| Değer | Anlamı | Yazan | İşaret | `ref` |
|---|---|---|---|---|
| `task` | Görev onaylandı | Tetikleyici `completions_coin` | + | `<completion_id>:<epoch>` |
| `task_undo` | Onay geri alındı (durum değişti ya da kayıt silindi) | Tetikleyici | − | `<completion_id>:<epoch>` |
| `spend` | Oyunda harcama | `spend_coins` | − | istemcinin işlem kimliği (`p_tx`) |
| `adjust` | Elle düzeltme | Kısıtta var; **yazan fonksiyon yok** (yalnız service role) | ± | — |
| `welcome` | Hoş geldin coini (coin kuralının tek istisnası; `ekonomi.md` §2.4). Öneri `20261024100000_welcome_coins_first_reward`, uygulandı 24 Ekim 2026. | `claim_welcome_coins()` (oyun, ilk beslemede) | + (20) | `welcome` (çocuk başına tek satır) |

`spend_coins` hata kodları (`error`): `null` (başarılı), `unknown_item`, `not_enough_coins`, `level_locked` (`20261019020000_server_rules`, uygulandı 19 Ekim).
`claim_welcome_coins` hata kodları (`error`): `null` (başarılı, 20 coin yazıldı), `already_claimed` (daha önce alındı, yazılmadı). Ekranda gösterim: ParentApp coin geçmişi gösterirse `welcome` = "Hoş geldin hediyesi". Oyun eşlemesi (`ServiceError`): `NotEnoughCoins`, `UnknownItem`, diğerleri `Rejected`; HTTP 0/5xx → `Network` (kuyrukta kalır), 401/403 → `Unauthorized`.

---

## 5A. Güneş Taşı defteri nedeni (`sun_stone_ledger.reason`, `20261019030000_sun_stones` (uygulandı))

| Değer | Anlam | Yazan | İşaret | `ref` biçimi |
|---|---|---|---|---|
| `task` | Ebeveyn onayı | Tetikleyici `completions_sun_stone` | + (1/2/3) | `<completion_id>:<epoch>` |
| `task_undo` | Onay geri alındı | Tetikleyici | − (o tamamlamanın net taşı) | `<completion_id>:<epoch>` |
| `adjust` | Elle düzeltme (yönetici) | SQL | ± | serbest |

## 5B. Kalıcı adlar (karar: 19 Ekim 2026, kullanıcı)

| Kavram | Ad | Not |
|---|---|---|
| Ebeveynin gerçek görevlerinin adadaki panosu (eski geçici ad "Quests") | **Ev Görevleri** | Sağ üstteki oyun içi seviye görevleri "Görev" olarak kalır. |
| Onaylı gerçek görevin verdiği, adaya yerleştirilen taş | **Güneş Taşı** | Çoğul: Güneş Taşları. |

## 6. Diğer sabit değerler (uygulanmış)

| Alan | Değerler |
|---|---|
| `children.gender` | `kız` / `erkek` / null (Türkçe, `ı` harfiyle) |
| `profiles.avatar` varsayılanı | `erkek` |
| `messages.sender` | `parent` / `child` |
| `messages.kind` | `text` (body zorunlu) / `image` / `audio` (media_path zorunlu) |
| Storage kovası | `mail`, yol `<family_id>/<dosya>` |
| Eşya kategorisi (oyun verisi, sunucuya gitmez) | `food`, `cleaning`, `clothes`, `accessory`, `home`, `seed`, `decor` |
| Oyun giriş hataları (`AuthErrorKind`, yalnız oyun içi) | `None`, `InvalidCode`, `Revoked`, `Network`, `Throttled`, `Unknown` |

---

## 7. Klinik (ClinicApp) — uygulandı

| Alan | Değerler | Anlamı |
|---|---|---|
| `clinic_links.status` | `active` (varsayılan) / `revoked` | Rıza etkin / ebeveyn ya da uzman sonlandırdı. Bir klinik–çocuk çifti için en fazla bir `active`. |
| `clinics.plan` | `trial` (varsayılan; öneriyle 7 gün, eskiden 14) / `solo` (Bireysel) / `clinic` (Klinik, 10 uzman) / `small` / `business` / `custom` / `inactive` | Etkin sayılanlar: süresi dolmamış `trial`, `period_end`'i geçmemiş `solo`/`clinic`, elle verilmiş `small`/`business`/`custom`. Üyelik ayrıntısı `veritabani.md` 8. |
| `clinics.billing_source` | `revenuecat` (bugünkü yol) / `app_store` / `iyzico` (ileride kendi sistem) / `manual` / null | Ödeme kaynağı (öneri). |
| `billing_subscriptions.status` | `active` / `canceled` (dönem sonuna kadar açık) / `expired` / `refunded` / `pending` | Öneri. |
| `clinicians.role` | `owner` / `member` | Klinik sahibi ekibe davet eder, klinik adını değiştirir, bütün danışanları görür ve danışanları üyelere atar (`20261022100000`, uygulandı). Üye yalnız sorumlusu olduğu ve kendisine atanan danışanları görür. |
| `clinic_task_suggestions.status` | `pending` (varsayılan) / `accepted` / `declined` | Ebeveyn kararı. `accepted` olunca görevi **ParentApp kendisi** oluşturur (sunucu otomatik görev açmaz). |
| `clinic_task_suggestions.difficulty` | `easy` / `medium` / `hard` (varsayılan `easy`) | Görevdeki ile aynı. |
| `family_subscriptions.plan` | `free` (varsayılan) / `premium` | Aile aboneliği. Etkin kliniğe bağlı çocuğu olan aile de premium sayılır (`family_premium`). |
| `family_subscriptions.source` | `store` (varsayılan) / `web` / `manual` | Ödeme kaynağı. |
| `completions.decline_reason` | `hard` / `no_time` / `did_not_want` / `other` / null | "Yapamam" nedeni. |
| `goal_ratings.rating` | −2, −1, 0, +1, +2 | GAS haftalık puanı. |
| `abc_events.intensity` | 1 … 5 (varsayılan 3) | Gözlem notundaki olayın şiddeti. |
| Kayıt meta verisi | `raw_user_meta_data.account = 'clinician'`, `team_code`, `clinic_name`, `name`, `title`, `practice` (`solo` / `clinic`) | Uzman kaydı (aile oluşturulmaz). `practice` sunucuda kullanılmaz (ikisi de klinik açar); ClinicApp bireyselde ekip bölümünü gizler. |

### 7.1 Klinikle ilgili tutarsızlıklar
| # | Konu | Ayrıntı |
|---|---|---|
| K1 | ~~`decline_reason` yazılamıyor~~ **çözüldü** | Ayrı RPC `child_set_decline_reason(p_task_id, p_date, p_reason)`; `child_set_status` imzası değişmedi (eski oyun sürümü bozulmaz). Oyunun "Yapamam"dan sonra bunu çağırması gerekir; çağırmazsa neden null kalır. |
| K2 | ~~`child_done_at` anlamı~~ **çözüldü**: tetikleyici artık yalnız çocuğun işaretinde doldurur | Tetikleyici, ebeveynin `review_completion` ile kayıt **yokken** `approved` yazmasında da (çocuk hiç "Yaptım" demeden) `child_done_at` doldurur. "Çocuğun yaptım dediği an" raporu bu durumda yanıltıcı olabilir. |
| K3 | ~~Kabul edilen öneri ↔ görev bağı~~ **çözüldü**: `clinic_task_suggestions.task_id` | `accepted` öneri ile ParentApp'in oluşturduğu `tasks` satırı arasında sütun bağı yok (öneri kimliği görevde saklanmıyor). Uzman, önerisinin hangi göreve dönüştüğünü sunucudan izleyemez (doğrulanmalı). |

---

## 8. Bildirim (19 Ekim 2026'da uygulandı)

| Alan | Değerler |
|---|---|
| `notifications.app` | `parent` / `child` / `clinic` |
| `notifications.kind` | `task_done`, `task_declined`, `task_approved`, `task_rejected`, `task_retry` (öneri 27 Ekim 2026), `task_assigned`, `message`, `device_linked`, `parent_joined`, `clinic_shared`, `clinic_revoked`, `clinic_suggestion`, `suggestion_decided`, `abc_event`, `team_joined`, `client_assigned`, `admin_message`; `20261026100000` (uygulandı): `invite_claimed` (uzmana: aile daveti kabul etti), `invite_expired` (uzmana: 48 saatte kullanılmadı), `care_plan_shared` (ebeveyne: takip planı paylaşıldı/güncellendi), `invite_child_updated` (uzmana: ebeveyn önerilen çocuk bilgisini düzeltti; `child_id` dolu), `invite_declined` (uzmana: aile daveti kabul etmedi); `20261026050000` (uygulandı): `verification_approved`, `verification_rejected` (`data.reason`), `verification_suspended` (uzmana) (anlamları: `akislar.md` 7, 10, 12, 14) |
| `push_tokens.app` | `parent` / `child` / `clinic` |
| `push_tokens.platform` | `ios` / `android` / `web` |
| Push gönderilen anahtar biçimi | Apple cihaz anahtarı (onaltılık, `platform='ios'`) → `push-apns`; `ExponentPushToken[...]` → Expo |

---

## 9. Kategori, gün bölümü, gözlem notu (uygulandı — `migrations/20261019140000_parent_features.sql`; 21 Ekim 2026 doğrulandı)

| Alan | Değerler | Etiket (ParentApp) |
|---|---|---|
| `saved_templates.category` (ve şablon kategorisi) | `home` / `mind` / `learn` / `health` / `focus` / `relation` (`self` → `health` taşındı) | Ev İşleri / Ruh Sağlığı / Öğrenme ve Eğitim / Sağlık ve Spor / Odak ve Öz Denetim / İlişki Kurma |
| Kategori → beceri (`tasks.skill`, 23 Ekim 2026) | `home`→`teamwork`, `mind`→`stamina`, `learn`→`knowledge`, `health`→`strength`, `focus`→`focus`, `relation`→`kindness` | Takım Çalışması / Dayanıklılık / Bilgi / Güç / Odak / Nezaket (`ekonomi.md` 5B) |
| Şablon yaş grubu | `K` (5 ve altı) / `A` (6–8) / `B` (9–12) / `C` (13 ve üstü) — oyunun yaş grubuyla aynı (§4) | ParentApp süzgeci; bir şablon birden çok grupta olabilir (`gorev_sablonlari.md`) |
| `tasks.day_part` | `morning` / `noon` / `evening` / `null` | Sabah / Öğlen / Akşam / Herhangi (Anytime) |
| `abc_events.day_part` | `morning` / `noon` / `evening` / `night` | Sabah / Öğlen / Akşam / Gece |
| `abc_events.occurred_at` | seçilen gün + gün bölümünün temsil saati: 08:00 / 13:00 / 19:00 / 22:00 (yerel) | — |
| Gün bölümü saat aralığı (eski kayıtlar ve hatırlatma saatinden öneri) | sabah 05–11, öğle 11–16, akşam 16–21, gece 21–05 | — |
| `abc_events.group_id` | aynı olay birden çok çocuğu ilgilendiriyorsa ortak kimlik (her çocuğa bir satır) | — |
| Storage kovası `abc` | ses: `<family_id>/<dosya>.m4a`; uzman yalnız rızalı çocuğun kaydına bağlı sesi okur | — |

---

## 10. Avatar ve ebeveyn rolü (21 Ekim 2026)

| Alan | Değer | Not |
|---|---|---|
| `children.avatar` | hazır avatar kimliği (`flamingo`, `kedi` …) **ya da** `photo:<storage yolu>` | Fotoğraf: kova `mail`, yol `<family_id>/avatars/<dosya>.jpg`. Aile (ebeveyn + çocuk cihazı) okuyabilir; **uzman okuyamaz**. Oyun ve ClinicApp `photo:` ile başlayan değeri tanımazsa varsayılan avatar göstermeli. |
| `families.created_by` | aileyi kuran ebeveyn | Aileden çıkarılamaz; başka ebeveynin profilini / aile sahibini değiştiren yetki yok. |
| `profiles.invited_by` | davet kodunu üreten ebeveyn | Öneri `20261021000000_family_roles.sql`; uygulamada gösterilmez. |

---

> **ParentApp penceresinin önerileri (22 Ekim 2026, uygulanmadı).** Bölüm numaraları `P` ile başlar.

## P11. Kod hataları (uygulandı 22 Ekim 2026 — `migrations/20261022100000_codes_15min.sql`)

Deneme sınırı ve hata gövdesi canlıda (`migrations/20261021300000_security_pentest.sql`). Bu öneri: bütün kodlar **15 dakika**,
nedenli ret, IP sınırı. Yanıt geriye uyumlu (`error` değişmedi):
`{"error":"invalid_code","reason":"expired|used|not_found","hint":"<reason>","message":"<metin>"}` + HTTP 400;
çok deneme `{"error":"too_many_attempts","hint":"too_many_attempts","message":…}` + HTTP 429.

| `reason` | Metin | Uygulama |
|---|---|---|
| `expired` | Kodun süresi doldu (kodlar 15 dakika geçerli). Yeni kod iste. | "Yeni kod iste" |
| `used` | Bu kod daha önce kullanıldı. Yeni kod iste. | Aynı |
| `not_found` | Kod bulunamadı. Harfleri kontrol et ya da yeni kod iste. | Yeniden yazdırır |

- Sınır: oturum 15 dakikada 10, IP 30 hatalı deneme. Süresi dolan kod 1 gün tabloda kalır.
- Kodlar: ikinci ebeveyn, çocuk girişi, uzman aile kodu (6 karakter), ekip kodu (8 karakter, `clinic_join_team`) hepsi 15 dakika.

## P12. Abonelik durumu (uygulandı 22 Ekim 2026 — `migrations/20261022110000_subscriptions.sql`)

| `family_access().state` | Anlam | Erişim |
|---|---|---|
| `pending` | Aileyi kuran ebeveyn e-postasını henüz doğrulamadı (deneme başlamadı) | Tam |
| `trial` | 7 günlük deneme sürüyor (`trial_ends_at`, `days_left`) | Tam |
| `premium` | Ücretli abonelik: `plan` = `monthly` / `yearly`; iptal edilse de `period_end`'e kadar | Tam |
| `clinic` | Ücretli plandaki (`small`/`business`/`custom`) bir kliniğe bağlı çocuğu var | Tam |
| `expired` | Deneme bitti, abonelik yok | `enforced` ise ücretsiz plan |

- `family_access().full`: kısıt uygulanacak mı (false yalnız `expired` + `enforced`).
- `app_config.billing`: `enforce` (şimdilik **false**: ödeme bağlanınca true), `trial_days` 7, `free_max_tasks` 3, `free_max_children` 1.
- Ücretsiz plan sınırı hatası: `hint = 'premium_required'` (uygulama üyelik ekranını açar).
- `family_subscriptions.status`: `active` / `grace` (ödeme sorunu, ek süre) / `canceled` (yenileme kapalı, dönem sonuna kadar premium) / `expired` / `refunded`. `billing`: `monthly` / `yearly`.
- Mağaza ürün kimlikleri: `parentapp.premium.monthly`, `parentapp.premium.yearly`.

## P13. Mesaj türleri (uygulandı 22 Ekim 2026 — `migrations/20261022120000_messages.sql`)

| `messages.kind` | Kim gönderir | İçerik |
|---|---|---|
| `text` | Ebeveyn (≤ 2000), çocuk (≤ 500) | `body` |
| `sticker` | Ebeveyn, çocuk | `body` = çıkartma anahtarı (aşağıda) |
| `image` | Yalnız ebeveyn | `media_path` = `<aile>/<dosya>` (kova `mail`) |
| `audio` | Yalnız ebeveyn | `media_path`, `duration_ms` |

Çıkartma anahtarları ve Türkçe etiketleri: `heart` Kalp, `star` Yıldız, `thumbs_up` Harika, `hug` Sarılma, `smile` Gülümseme,
`laugh` Kahkaha, `wow` Vay, `sad` Üzgün, `sleepy` Uykulu, `party` Kutlama, `thanks` Teşekkürler, `love_you` Seni seviyorum.
Görselleri her uygulama kendi çizer (anahtar ortak). `read_at`: karşı taraf okudu.

## P14. Güneş Taşı ve ödül (uygulandı 22 Ekim 2026 — `migrations/20261022130000_sun_stones_rewards.sql`)

| Alan | Değerler |
|---|---|
| `sun_stone_ledger.reason` | `task` (onay), `task_undo` (onay geri alındı), `reward` (ödül verildi/onaylandı), `penalty` (ebeveyn düştü), `adjust` (ileride) |
| `reward_requests.source` | `child` (oyunda istedi) / `parent` (ebeveyn doğrudan verdi) |
| `reward_requests.status` | `pending` (bekliyor) / `approved` (verildi, taş düştü) / `rejected` (olmadı) / `canceled` (çocuk vazgeçti) |
| Hata `hint` | `not_enough_stones`, `too_many_requests` (5 bekleyen istek), `premium_required` |
| Bildirim `kind` | `reward_request` (ebeveynlere), `reward_given`, `reward_decided`, `stones_deducted` (çocuğa; diğer ebeveyne bilgi) |
| `reward_request` bildiriminin `data` alanı | `{request_id, child_id}`; çocuğun **ilk** isteğinde (oyundan gelen hiçbir önceki isteği yokken; durum fark etmez) ayrıca `"first": true` ve başlık `İlk ödül talebi: <ad> bir ödül istiyor`. Sonraki isteklerde `first` yok. Yeni `kind` yok. Öneri `20261024100000_welcome_coins_first_reward`, uygulandı 24 Ekim 2026. |

## P15. Aile daveti, geçmiş aktarımı, takip planı (`migrations/20261026100000_family_invite_links.sql`, uygulandı 26 Ekim 2026)

| Alan | Değerler | Anlam |
|---|---|---|
| davet durumu (`clinic_invite_status`, `clinic_invites_list.status`) | `sent`, `opened`, `claimed`, `shared`, `expired`, `revoked`, `declined` | gönderildi · bağlantı açıldı · aile kayıt oldu/kodu girdi · çocuk paylaşıldı · 48 saat doldu (ya da kayıt olup 30 günde paylaşmadı) · uzman iptal etti · aile reddetti |
| bayrak `clinician_verification` | `false` (ilk sürüm) / `true` | belge incelemesi görünür mü (ClinicApp satırı + sayfası, ParentApp rozeti/etiketi, sunucu başvurusu ve `verified_as`) |
| `clinician_surveys.profession` | `psikolog`, `klinik_psikolog`, `pdr`, `ergoterapist`, `dil_konusma`, `ozel_egitim`, `cocuk_gelisimi`, `bcba`, `hekim`, `oyun_terapisti`, `sanat_terapisti`, `aile_danismani`, `okul_rehber`, `ogrenci`, `diger` | karşılama anketi mesleği (ilk dokuzu + `diger` doğrulama meslekleriyle aynı; Türkçe adlar `veri/uzman_anketi.json`) |
| `clinician_surveys.challenges` | `home_followthrough`, `home_data`, `unpaid_time`, `no_system`, `between_sessions`, `progress_report` | evde düzenli uygulama · evden gözlem bilgisi · seans dışı ücretsiz zaman · düzenli sistem yok · seanslar arası iletişim · ilerlemeyi ölçme/gösterme |
| `clinician_surveys.features` | `plan_templates`, `parent_logging`, `reward_routines`, `progress_report`, `report_export`, `parent_materials` | hazır şablonlar · ebeveynin telefondan kaydı · ödüllü rutin · ilerleme raporu · PDF rapor · aileye materyal |
| `clinician_surveys.intent` | `trial`, `family`, `team`, `org` | denemek · bir aileyi bağlamak · ekibe katılmak · klinikte tek düzen (yalnız klinik sahibine sorulur) |
| `clinician_verifications.status` | `pending`, `auto_rejected`, `approved`, `rejected`, `withdrawn`, `suspended` | incelemede · ön kontrol geri çevirdi · belgesi incelendi · reddedildi · yerine yenisi geldi · askıya alındı |
| `clinician_verifications.profession` / `clinicians.verified_profession` | `psikolog`, `klinik_psikolog`, `pdr`, `ergoterapist`, `dil_konusma`, `ozel_egitim`, `cocuk_gelisimi`, `bcba`, `hekim`, `diger` | Türkçe ad `clinician_profession_label()`; eşleme `veri/uzman_meslekleri.json` |
| onay metni sürümleri | `uzman-paylasim-v1` (`clinic_links.consent_version`), `uzman-gecis-v1` (`clinic_link_history.consent_version`) | metin değişince sürüm adı artar (`hukuk_notlari.md`) |
| `clinic_invites.channel` | `whatsapp`, `email`, `sms`, `copy`, `other` | uzmanın paylaşım yolu (istatistik); sistem e-postası da `email` yazar (ayrımı `email_status`) |
| `clinic_invites.email_status` | `sending`, `sent`, `failed` / boş | sistem e-postası: gönderiliyor · gönderildi · gönderilemedi · hiç gönderilmedi (`20261027000000`, uygulandı) |
| `invite-email` yanıtı (`reason`) | `not_configured`, `not_found`, `no_email`, `closed`, `expired`, `no_access`, `limit_invite`, `too_soon`, `limit_day`, `send_failed` (+ `detail`, ör. `EAUTH`) | e-posta ayarı yok · davet yok/yetki yok · davette e-posta yok · aile bağladı/iptal/ret/kullanıldı · süresi doldu · üyelik etkin değil · davet başına 3 · 60 sn dolmadı · günde 30 davet · gönderilemedi (SMTP kullanıcı/uygulama şifresi hatalıysa `EAUTH`) |
| `clinic_invites.child_age_group` | `K`, `A`, `B`, `C` | 5 ve altı · 6–8 · 9–12 · 13 ve üstü (şablon yaş grupları). Davetle oluşan çocukta `age_band`: doğum günü varsa boş (otomatik), yoksa bu grup aynen (§4; 26 Ekim denetiminde K→A, C→B çevirisi kaldırıldı) |
| davet ret nedeni (`reason`) | `not_found`, `expired`, `used`, `accepted`, `declined`, `revoked`, `too_many_attempts` (hint) | bulunamadı · süresi doldu (3 gün / bağlandıktan 30 gün) · başka ailede kullanıldı · bu daveti zaten kabul ettin · bu daveti kapattın · uzman iptal etti · çok fazla hatalı deneme (`20261026300000`) |
| `invite-info` durumu | `open`, `used`, `expired`, `revoked`, `not_found` | açılış sayfası |
| `clinic_goals.measure` | `yesno`, `percent`, `frequency`, `duration`, `level` | evet-hayır (gün) · yüzde · sıklık · süre (dk) · düzey (yalnız GAS) |
| `clinic_goals.status` | `active`, `achieved`, `paused` | sürüyor · ulaşıldı · ara verildi |
| `clinic_goals.shared` | `true` / `false` | aile görür / yalnız klinik (eski hedefler `false`); aile, uzman "Planı aileye gönder" deyince görür (`pub`, `20261026300000`) |
| `care_modules.status` | `planned`, `active`, `done` | planlandı (aile görmez) · etkin · tamamlandı |
| `care_module_logs.barrier` | `no_time`, `forgot`, `child_resisted`, `unsure` | vakit yoktu · unuttum · çocuk direndi · nasıl yapacağımı bilemedim |
| `care_module_logs.difficulty` | 1–5 (boş olabilir) | ebeveynin "ne kadar zorlandım" öz bildirimi; puan değildir |
| hedef alanı (`clinic_goals.domain`, katalog) | `routine`, `attention`, `rules`, `emotion`, `social`, `sleep`, `school` | `veri/takip_sablonlari.json` `domains` (ekranda Türkçe adı) |

## P16. Tanışma soruları (`proposed/20261027120000_parent_setup_intake.sql`, öneri 27 Ekim 2026)

`intake_answers.question_key` ve seçenek anahtarları (`answer` = seçenek anahtarları dizisi; tek seçimde tek eleman). Soru metinleri ParentApp'te (`parent-app/src/data/intake.ts`), sürüm `v1`.

| Anahtar | Kime | Tür | Seçenekler |
|---|---|---|---|
| `main_goal` | ebeveyn | tek | `motivation`, `structure`, `behavior`, `executive`, `relationship`, `my_stress` |
| `other_goals` | ebeveyn | çoklu | aynı + `other` |
| `heard_from` | ebeveyn | tek | `expert`, `friend_family`, `social_ad`, `google`, `app_store`, `tiktok`, `other` |
| `task_conflict_freq`, `reminder_freq`, `prompt_conflict_freq` | ebeveyn | tek | `every_day`, `most_days`, `some_days`, `never` |
| `relate_reminding`, `relate_rewards_fade`, `relate_no_energy` | ebeveyn | tek | `yes`, `no` |
| `child_routine` | çocuk | tek | `yes`, `struggle`, `not_really` |
| `child_diagnosis` (sağlık, isteğe bağlı) | çocuk | çoklu | `adhd`, `autism`, `odd`, `anxiety_depression`, `other`, `none`, `prefer_not` |
| `child_medication` (sağlık, isteğe bağlı) | çocuk | tek | `yes`, `no`, `not_diagnosed`, `prefer_not` |
| `child_therapists` | çocuk | çoklu | `behavior`, `speech_ot`, `psych`, `other`, `none` |
| `child_organizing`, `child_effort_avoid`, `child_rules_argue`, `child_tantrums`, `child_feelings`, `child_worry` | çocuk | tek | `every_day`, `most_days`, `some_days`, `never` (geçen hafta) |
| `child_goals` | çocuk | çoklu | `chores`, `focus`, `impulses`, `bedtime`, `siblings`, `emotions`, `other` |
| `child_interests` | çocuk | çoklu | `sports`, `books`, `games_tech`, `arts`, `music_dance`, `animals_nature`, `other` |
| `child_motivators` | çocuk | çoklu | `screen_time`, `allowance`, `family_activity`, `friends_time`, `treats`, `other` |

Sağlık sorularında `prefer_not` dışındaki yanıt `consent_version` ister (`saglik-yanit-v1`). Hiçbir yanıt tanı, zekâ ya da dikkat puanı değildir; ebeveynin beyanıdır.
