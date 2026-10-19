# Durum ve sabit değer sözleşmesi

Uygulamalar arasında taşınan bütün "durum" ve sabit metin değerleri. **Yazım birebir aynı olmalı** (küçük harf, İngilizce;
yalnız `gender` Türkçe). Yeni bir değer eklenecekse önce bu dosya ve SQL güncellenir, sonra uygulamalar.

Kaynak:
- `parent-app/supabase/migrations/20261013000000_init.sql`, `20261014000000_task_repeat_order.sql`
- `pofi-adasi/supabase/proposed/20261015000000_pofi_game.sql` (uygulandı)
- `parent-app` dalı `origin/claude/project-thread-vwahaf`: `supabase/proposed/20261019000000_clinic.sql` (**öneri, uygulanmadı**), `src/lib/clinic.ts`
- `pofi-adasi/Assets/_Pofi/Scripts/Logic/Tasks/ChildTask.cs`, `Services/Supabase/SupabaseGameService.cs`, `Services/IGameServices.cs`, `Services/IAuthService.cs`, `Profile/AgeBand.cs`, `Auth/LoginThrottle.cs`, `Services/ServerConfig.cs`, `Data/Definitions.cs`
- `parent-app/src/store.tsx`, `src/theme.ts`, `src/data/ageBands.ts`, `src/data/templates.ts`, `src/screens/TasksScreen.tsx`, `src/screens/ReviewScreen.tsx`
- `pofi-adasi/docs/PLAN.md`, `M4_SUNUCU_ONERISI.md`; `clinic-app/CLAUDE.md`

Son güncelleme: 2026-10-19

---

## 1. Görev tamamlama durumu (`completions.status`)

SQL kısıtı (M4 sonrası): `status in ('pending', 'approved', 'declined', 'rejected')`.

| Sunucu değeri | Anlamı | Kim yazar | Oyun (C# `ChildTaskStatus`) | ParentApp (TS `CompletionStatus`, etiket) | Coin |
|---|---|---|---|---|---|
| *(kayıt yok)* → `'assigned'` | Atanmış, henüz işaretlenmedi | — (`child_tasks` kayıt yoksa `'assigned'` döndürür; **tabloda saklanmaz**) | `Assigned` | (durum yok, etiket gösterilmez) | — |
| `pending` | Çocuk "Yaptım" dedi, ebeveyn bakacak | Oyun (`child_set_status`) | `ChildDone` | `pending` — "Onay bekliyor" | — |
| `approved` | Ebeveyn onayladı (ya da inceleme gerektirmeyen görevde çocuk "Yaptım" dedi) | ParentApp; inceleme yoksa sunucu `pending`→`approved` çevirir | `Approved` | `approved` — "Tamamlandı" | **+coins** (tetikleyici) |
| `declined` | Çocuk "Yapamam" dedi | Oyun (`child_set_status`) | `DeclinedByChild` | `declined` — "Yapamadı" | — |
| `rejected` | Ebeveyn not yazarak reddetti | ParentApp (`review_completion`) | `RejectedByParent` | `rejected` — "Reddedildi" | — (önce `approved` idiyse **−coins**) |

Ek kurallar:
- `approved` ve `rejected` **nihai** durumdur: çocuk değiştiremez (`child_set_status` "Ebeveyn karar verdi" hatası; C# `ChildTask.IsFinal`).
- Çocuğun geçişleri (C# `TaskRules.CanChange` ve SQL `child_set_status` ile aynı): `Assigned → pending | declined`; `pending | declined → assigned` (geri al = kaydı sil).
- `child_set_status` girdisi yalnız `pending` / `declined` / `assigned` kabul eder. C# `StatusText`: `ChildDone→"pending"`, `DeclinedByChild→"declined"`, `Assigned→"assigned"`, onay/ret için `null` (gönderilmez).
- C# `ParseStatus`: bilinmeyen her değer `Assigned` sayılır.
- **"Kaçırıldı" (missed)** yalnız oyunda hesaplanır, sunucuda yoktur: durum `Assigned` ve yerel saat görev gününün sonunu (23:59:59.9999999) geçtiyse. Ceza yok; oyun o görevin işaretlenmesine izin vermez.
- ParentApp görev listesinde birden fazla çocuğa atanmış görev için tek etiket seçer: herhangi biri `pending` → `pending`; hepsi `approved` → `approved`; biri `rejected` → `rejected`; biri `declined` → `declined`.
- ParentApp **İnceleme** ekranı yalnız `pending` olanları listeler.

### 1.1 Tutarsızlıklar / dikkat edilecekler
| # | Konu | Ayrıntı |
|---|---|---|
| D1 | `assigned` hiç saklanmaz | `'assigned'` yalnız RPC girdisi/çıktısıdır; `completions` kısıtında yoktur. ClinicApp raporlarında "atanmış" = **kayıt yok** olarak hesaplanmalı. |
| D2 | Onay iki farklı yolla | ParentApp onayı **doğrudan** `completions` güncellemesiyle (`status='approved'`, `reviewed_at`, `reviewed_by`; `parent_note` yazılmaz), reddi `review_completion` RPC'siyle yapar. Doğrudan güncelleme yalnız var olan satırı değiştirir. İkisi de tetikleyiciyi çalıştırır. |
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
| `clinic_invites.kind` | `family` | Uzmanın aileye verdiği paylaşım kodu (ebeveyn ParentApp'te girer) | 7 gün, tek kullanım | **öneri, uygulanmadı** |
| `clinic_invites.kind` | `clinician` | Klinik ekibine katılım kodu (yalnız `owner` üretir; kayıtta `team_code`) | 7 gün, tek kullanım | **öneri, uygulanmadı** |

Kod biçimi:
- Sunucu üretimi (`random_code`): 6 karakter, alfabe `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (I, L, O, 0, 1 **yok**). `invite_codes.code` kısıtı `^[A-Z0-9]{6}$`. `clinic_invites.code` için kısıt yok (öneri).
- Oyun girişi (`ChildCode.Normalize`): küçük harf büyütülür, harf/rakam dışı karakterler atılır, uzunluk tam 6 olmalı. ParentApp: `trim().toUpperCase()`.
- Oyunun deneme kodları `A1A1A1`, `B2B2B2`, `C3C3C3`: `ServerConfig.DemoCodes = true` iken `RoutedAuthService` bunları sahte arka uca yönlendirir (sunucuya gitmez). `A1A1A1` sunucu alfabesinde olmayan `1` içerdiği için gerçek bir kodla çakışamaz; `B2B2B2` ve `C3C3C3` ise sunucu alfabesine uyar, yani çok düşük olasılıkla gerçek bir kodla aynı olabilir ve o durumda oyun gerçek kodu sahte arka uca gönderir. Mağaza sürümünde `DemoCodes` kapatılmalı (doğrulanmalı).
- Oyunda hatalı kod beklemesi (yalnız istemci, `LoginThrottle`): 3 deneme serbest, sonra 15 sn'den başlayıp her hatada ikiye katlanır, en fazla 300 sn. **Sunucuda deneme sınırı yok** (PLAN.md'de "yeni" olarak planlanmıştı; SQL'de bulunamadı).

---

## 4. Yaş bandı (`children.age_band`)

Karar (19 Ekim 2026, kullanıcı): **A 6–8 / B 9–12 / C 13–15** (oyun omurgası analizinin önerisi). Öneri SQL'i: `supabase/proposed/20261019010000_age_bands.sql` (uygulanana kadar canlıda eski kural geçerli: A 6–9 / B 10–12).

| Değer | Oyun (`AgeBand.cs`) | ParentApp etiketi (`ageBands.ts`) | SQL önerisi (`suggest_age_band`) |
|---|---|---|---|
| `A` | A | "6–8 yaş" | doğum günü yok **ya da** yaş < 9 |
| `B` | B | "9–12 yaş" | 9 ≤ yaş < 13 |
| `C` | C | "13–15 yaş" | yaş ≥ 13 |
| `null` | — | — | sunucu yanıtlarında `coalesce(age_band, suggest_age_band(birthday))` ile dolu gelir |

- Oyun bilinmeyen/boş değeri **`A`** (en güvenli) sayar (`AgeBandProfile.Parse`). ParentApp `suggestAgeBand` sunucuyla aynı kuralı kullanır.
- Ebeveynin elle seçtiği bant öneriden önce gelir; kural değişince kayıtlı bantlar kendiliğinden değişmez.
- Banda bağlı oyun ayarları (tema, ses, günlük XP sınırı …): `ekonomi.md` 5. bölüm.
- **Bant yalnız oyunun zorluk/arayüz ayarıdır.** Raporlar, analizler ve uzman çıktıları çocuğun gerçek yaşını (`children.birthday`, ebeveynin ParentApp'te girdiği) kullanır; bant sınırına bağlanmaz.
- Ana hedef kitle 6–12; C (13–15) desteklenir ama pazarlama hedefi değildir.

### 4.1 App Store / Google Play
- Mağaza **Kids Category dışında**, yaş derecelendirmesi en düşük (4+); Kids kurallarına gönüllü uyulur: üçüncü taraf reklam/analitik yok, dış bağlantı ve satın alma ebeveyn kapısının (`ParentGate`) arkasında. Kaynak: `game-app/docs/PLAN.md` §9 (Seçenek A).
- Apple Kids bantları (5 ve altı / 6–8 / 9–11) mağaza sınıflandırmasıdır; oyunun iç bantlarıyla aynı olmak zorunda değildir.
- Yaş **çocuktan sorulmaz**: doğum gününü ebeveyn ParentApp'te girer (ebeveyn onayı orada). Oyun yalnız bandı alır.

## 5. Coin defteri nedeni (`coin_ledger.reason`)

| Değer | Anlamı | Yazan | İşaret | `ref` |
|---|---|---|---|---|
| `task` | Görev onaylandı | Tetikleyici `completions_coin` | + | `<completion_id>:<epoch>` |
| `task_undo` | Onay geri alındı (durum değişti ya da kayıt silindi) | Tetikleyici | − | `<completion_id>:<epoch>` |
| `spend` | Oyunda harcama | `spend_coins` | − | istemcinin işlem kimliği (`p_tx`) |
| `adjust` | Elle düzeltme | Kısıtta var; **yazan fonksiyon yok** (yalnız service role) | ± | — |

`spend_coins` hata kodları (`error`): `null` (başarılı), `unknown_item`, `not_enough_coins`. Oyun eşlemesi (`ServiceError`): `NotEnoughCoins`, `UnknownItem`, diğerleri `Rejected`; HTTP 0/5xx → `Network` (kuyrukta kalır), 401/403 → `Unauthorized`.

---

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

## 7. Öneri — uygulanmadı (ClinicApp)

| Alan | Değerler | Anlamı |
|---|---|---|
| `clinic_links.status` | `active` (varsayılan) / `revoked` | Rıza etkin / ebeveyn ya da uzman sonlandırdı. Bir klinik–çocuk çifti için en fazla bir `active`. |
| `clinics.plan` | `trial` (varsayılan, 14 gün) / `small` / `business` / `custom` / `inactive` | Klinisyen başına abonelik. Etkin sayılanlar: `small`, `business`, `custom`, süresi dolmamış `trial`. |
| `clinicians.role` | `owner` / `member` | Klinik sahibi ekibe davet eder ve klinik adını değiştirir. |
| `clinic_task_suggestions.status` | `pending` (varsayılan) / `accepted` / `declined` | Ebeveyn kararı. `accepted` olunca görevi **ParentApp kendisi** oluşturur (sunucu otomatik görev açmaz). |
| `clinic_task_suggestions.difficulty` | `easy` / `medium` / `hard` (varsayılan `easy`) | Görevdeki ile aynı. |
| `family_subscriptions.plan` | `free` (varsayılan) / `premium` | Aile aboneliği. Etkin kliniğe bağlı çocuğu olan aile de premium sayılır (`family_premium`). |
| `family_subscriptions.source` | `store` (varsayılan) / `web` / `manual` | Ödeme kaynağı. |
| `completions.decline_reason` | `hard` / `no_time` / `did_not_want` / `other` / null | "Yapamam" nedeni. |
| `goal_ratings.rating` | −2, −1, 0, +1, +2 | GAS haftalık puanı. |
| `abc_events.intensity` | 1 … 5 (varsayılan 3) | Zor anın şiddeti. |
| Kayıt meta verisi | `raw_user_meta_data.account = 'clinician'`, `team_code`, `clinic_name`, `name`, `title` | Uzman kaydı (aile oluşturulmaz). |

### 7.1 Öneriyle ilgili tutarsızlıklar
| # | Konu | Ayrıntı |
|---|---|---|
| K1 | `decline_reason` yazılamıyor | Oyunun `child_set_status(p_task_id, p_date, p_status)` imzasında neden parametresi yok; C# da göndermiyor. Sütun eklenirse ya RPC'ye `p_reason` eklenmeli ya da alan hep null kalır. |
| K2 | `child_done_at` anlamı | Tetikleyici, ebeveynin `review_completion` ile kayıt **yokken** `approved` yazmasında da (çocuk hiç "Yaptım" demeden) `child_done_at` doldurur. "Çocuğun yaptım dediği an" raporu bu durumda yanıltıcı olabilir. |
| K3 | Kabul edilen öneri ↔ görev bağı | `accepted` öneri ile ParentApp'in oluşturduğu `tasks` satırı arasında sütun bağı yok (öneri kimliği görevde saklanmıyor). Uzman, önerisinin hangi göreve dönüştüğünü sunucudan izleyemez (doğrulanmalı). |
