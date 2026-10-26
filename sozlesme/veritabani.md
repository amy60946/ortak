# Veritabanı sözleşmesi (tablolar, fonksiyonlar, erişim kuralları)

Üç uygulama (GameApp oyunu, ParentApp, ClinicApp) **tek bir Supabase projesini** kullanır:
`https://uhelhxqgpcjemadhsifx.supabase.co`. Aralarındaki bütün iletişim bu veritabanı üzerinden olur.

Kaynak:
- `parent-app/supabase/migrations/20261013000000_init.sql` (temel şema)
- `parent-app/supabase/migrations/20261014000000_task_repeat_order.sql` (görev tekrarı ve sırası)
- `game-app/supabase/proposed/20261015000000_pofi_game.sql` (oyun eklemeleri, M4; 15 Ekim 2026'da uygulandı)
- `ortak/supabase/migrations/20261019000000_clinic.sql` (klinik; 19 Ekim 2026'da uygulandı); `parent-app/src/lib/clinic.ts`, `clinic-app/src/lib/clinic.ts`
- `parent-app/src/store.tsx`, `parent-app/src/lib/auth.tsx`
- `game-app/Assets/_Pofi/Scripts/Logic/Services/Supabase/SupabaseGameService.cs`, `SupabaseAuthService.cs`
- `game-app/docs/M4_SUNUCU_ONERISI.md`, `M4_UYGULAMA.md`, `parent-app/docs/SUPABASE.md`, `parent-app/docs/DURUM.md`

Son güncelleme: 2026-10-19

---

## 0. Kısaltmalar ve temel kavramlar

| Kavram | Anlamı |
|---|---|
| **Oyun** | GameApp (GameApp, Unity C#). Çocuk **anonim Supabase oturumu** açar, giriş koduyla bir `children` satırına bağlanır (`children.user_id = auth.uid()`). |
| **ParentApp** | Ebeveyn uygulaması (Expo). E-posta/şifre ile giriş; her ebeveyn bir `profiles` satırıdır ve bir aileye (`family_id`) bağlıdır. |
| **ClinicApp** | Uzman paneli (Expo: web + iPad). Tabloları aşağıda 4. bölümde (uygulandı). |
| `my_family_id()` | Oturumdaki **ebeveynin** ailesi (`profiles.family_id`). |
| `my_child_id()` | Oturumdaki **çocuğun** kimliği (`children.user_id = auth.uid()`). |
| `my_any_family_id()` | Ebeveyn ya da çocuk fark etmeksizin oturumun ailesi. |
| RLS | Satır düzeyi güvenlik. Her tabloda açıktır; politikalar "kim hangi satırı görür/yazar" kuralıdır. |
| `security definer` | Fonksiyon kendi yetkisiyle çalışır (RLS'yi aşar); içerideki kontroller güvenliği sağlar. |

Anahtarlar: istemcilere yalnız **publishable/anon** anahtar girer. `service_role` / `sb_secret_` hiçbir uygulamada yoktur
(oyunda `ServerConfig.LooksSecret` gizli anahtarı reddeder).

---

## 1. Uygulanmış — tablolar

"Yazar / Okur" sütunları: **O** = Oyun, **P** = ParentApp, **K** = ClinicApp (aşağıda 4. bölüm).
"Sunucu" = yalnızca tetikleyici/fonksiyon yazar, istemci doğrudan yazamaz.

### 1.1 Temel şema (ParentApp göçleri)

| Tablo | Amaç | Önemli sütunlar | Yazar | Okur |
|---|---|---|---|---|
| `families` | Aile | `id`, `name` (varsayılan `'Ailem'`), `created_by` | Sunucu (kayıtta `handle_new_user`); P yalnız `name` günceller | P (kendi ailesi), O (çocuğun ailesi, `my_any_family_id`) |
| `profiles` | Ebeveyn profili (auth.users ile bire bir) | `id` (= auth.users.id), `family_id`, `nickname` (`'Ben'`), `name`, `avatar` (`'erkek'`) | Sunucu (kayıt, `join_family`); P yalnız `nickname`, `name`, `avatar` | P (kendisi + aynı ailedeki ebeveynler) |
| `children` | Çocuk | `id`, `family_id`, `name` (1–60 karakter), `avatar`, `gender` (`'kız'`/`'erkek'`/null), `birthday`, `user_id` (oyunun anonim oturumu; unique), `age_band` (M4) | P (ekle/düzenle/sil; `user_id` hariç); `user_id` yalnız `redeem_child_code` / `unlink_child_device` ile | P (aile), O (yalnız kendi satırı: `user_id = auth.uid()`) |
| `tasks` | Görev (tekrarlı görev **tek satır**) | `title` (1–120), `emoji` (`'⭐'`), `skill`, `description`, `start_date`, `recurring`, `end_date`, `reminder` (`HH:MM`), `requires_review` (varsayılan `true`), `repeat_kind`, `repeat_days`, `sort_order` | P | P, O (yalnız kendisine atanmışlar; oyun pratikte `child_tasks` RPC'si üzerinden okur) |
| `task_assignments` | Görev ↔ çocuk ataması ve ödülü | PK (`task_id`, `child_id`), `family_id`, `difficulty` (`easy`/`medium`/`hard`), `coins` (0–50) | P | P, O (kendi atamaları) |
| `completions` | Bir görevin bir gündeki durumu | `task_id`, `child_id`, `date`, `status`, `parent_note` (M4, ≤ 300), `reviewed_at`, `reviewed_by`, `created_at`; **unique (`task_id`, `child_id`, `date`)** | O (`child_set_status` RPC'si), P (doğrudan + `review_completion`) | P, O (kendi satırları) |
| `messages` | Posta (ebeveyn ↔ çocuk) | `child_id`, `sender` (`parent`/`child`), `sender_id`, `kind` (`text`/`image`/`audio`), `body` (≤ 2000), `media_path`, `duration_ms` | P (sender=`parent`); çocuk (sender=`child`) RLS ile izinli | P, çocuk (kendi mesajları) |
| `saved_templates` | Kaydedilen hazır/özel görev şablonları | `template_key` (ör. `t1`), `is_custom`, `saved`, `title`, `emoji`, `category` (`home`/`mind`/`learn`/`self`), `difficulty`, `skill` | P | P |
| `invite_codes` | İkinci ebeveyn daveti ve çocuk giriş kodu | `code` (`^[A-Z0-9]{6}$`), `family_id`, `kind` (`parent`/`child`), `child_id` (yalnız `child` türünde dolu), `expires_at`, `used_at`, `used_by` | Sunucu (yalnız fonksiyonlarla) | P (kendi ailesinin kodları) |

Notlar:
- **Oyunda Posta yok:** Oyun kodunda `messages` tablosunu kullanan bir yer bulunamadı. RLS çocuğun okuyup göndermesine izin verir; bugün yalnız ParentApp kullanır.
- Görev tekrarı (`20261014000000_task_repeat_order.sql`): `repeat_kind` ∈ `daily`/`weekly`/`monthly` (varsayılan `daily`); `repeat_days` haftalıkta 1 = Pazartesi … 7 = Pazar, aylıkta 1 … 31 (ayda o gün yoksa ayın son günü). `sort_order` küçük olan üstte.
- **Realtime** yayını: `messages`, `completions`, `tasks`, `task_assignments`, `children`. ParentApp bunları dinler; oyun Realtime kullanmaz (senkron sırasında RPC ile çeker).
- **Storage** kovası `mail` (gizli, en fazla 10 MB; jpeg/png/heic/webp ve mp4/m4a/x-m4a/aac/mpeg). Dosya yolu `<family_id>/<dosya>`. Aile (ebeveyn **ve** çocuk) okur/yükler; yalnız ebeveyn siler.

### 1.2 Oyun eklemeleri (M4, uygulandı)

| Tablo / sütun | Amaç | Önemli sütunlar | Yazar | Okur |
|---|---|---|---|---|
| `children.age_band` | Yaş bandı | `'A'` (6–8) / `'B'` (9–12) / null (null ise doğum gününden önerilir). `'C'` 19 Ekim 2026'da kaldırıldı | P (doğrudan sütun izni + `set_child_age_band`) | O (`redeem_child_code`, `child_me` yanıtında), P |
| `completions.parent_note` | Ebeveynin ret/onay notu | ≤ 300 karakter | P (`review_completion`) | O (`child_tasks`), P |
| `coin_ledger` | Coin defteri. Bakiye = `sum(amount)` | `id` (bigserial), `family_id`, `child_id`, `amount` (≠ 0), `reason` (`task`/`task_undo`/`spend`/`adjust`), `ref`, `item_id`, `quantity`; **unique (`child_id`, `reason`, `ref`)** | **Sunucu** (tetikleyici `completions_coin` + `spend_coins`). İstemci yazamaz. | P (aile), O (kendi satırları; pratikte bakiye `child_me` ile gelir) |
| `sun_stone_ledger` | Güneş Taşı defteri (`20261019030000_sun_stones`, uygulandı 19 Ekim). Toplam = `sum(amount)` (en az 0) | `family_id`, `child_id`, `amount` (≠ 0), `reason` (`task`/`task_undo`/`adjust`), `ref`; unique (`child_id`, `reason`, `ref`) | yalnız tetikleyici `completions_sun_stone` | P (aile), O (kendi) |
| `game_items` | Dükkân fiyatları (**sunucu esas**) | `item_id` (PK), `price` (≥ 0), `min_level` (varsayılan 1) | Sunucu (SQL ile tohumlanır; istemci yazamaz) | Herkes (oturum açmış) |
| `game_levels` | Seviye eşikleri (`20261019020000_server_rules`, uygulandı 19 Ekim) | `level` (PK), `total_xp` | Sunucu (SQL ile tohumlanır; `levels.json` ile aynı) | Herkes (oturum açmış) |
| `code_attempts` | Hatalı kod denemeleri (`20261019020000_server_rules`, uygulandı 19 Ekim) | `user_id`, `at` | yalnız `redeem_child_code` | kimse (RLS açık, politika yok) |
| `game_saves` | Oyun kaydı yedeği | `child_id` (PK), `family_id`, `data` (jsonb, en fazla 262 144 bayt), `updated_at` | O (`game_save_put`) | O (`game_save_get`), P (aile; ParentApp bugün okumuyor) |

`game_items` içeriği oyunun `Resources/Data/items.json` dosyasıyla birebir aynıdır (48 eşya; fiyat ve seviye 2026-10-19'da karşılaştırıldı, fark yok). Liste: `ekonomi.md`.

---

## 2. Uygulanmış — fonksiyonlar (RPC)

"Çağıran": **O** = Oyun, **P** = ParentApp, **iç** = yalnız politika/diğer fonksiyonlar (istemciye kapalı ya da kullanılmıyor).

### 2.1 Temel şema

| Fonksiyon | Dönüş | Çağıran | Ne yapar |
|---|---|---|---|
| `create_invite_code(p_kind text default 'parent', p_child_id uuid default null)` | `table(code text, expires_at timestamptz)` | P | Ebeveyn oturumu gerekir. `parent` (ikinci ebeveyn) ya da `child` (çocuk girişi) kodu üretir. **24 saat** geçerli, tek kullanımlık. `child` türünde aynı çocuğun kullanılmamış eski kodları silinir. Ailenin süresi dolmuş kullanılmamış kodları temizlenir. |
| `join_family(p_code text)` | `uuid` (yeni aile); öneride `json {family_id}` + kod deneme sınırı (bölüm 9) | P | İkinci ebeveyn davet koduyla aileye katılır. Eski ailesinde başka ebeveyn yoksa eski aile ve tüm verisi silinir. |
| `redeem_child_code(p_code text)` | `json {child_id, family_id, name, avatar, age_band}` | O | Anonim oturum gerekir; ebeveyn hesabıyla çağrılamaz. Kodu tüketir, `children.user_id = auth.uid()` yapar (aynı oturumun önceki çocuk bağlantısı kaldırılır). M4 ile yanıta `age_band` eklendi. Öneri `20261019020000_server_rules`: hatalı kod 400 `{error:'invalid_code'}`, 15 dk'da 10 hata → 429 `{error:'too_many_attempts'}` (`code_attempts`, RLS açık, politika yok). |
| `delete_account()` | `void` | P | Hesabı siler; ailede başka ebeveyn yoksa ailenin tüm verisi de silinir (Storage dosyaları önce uygulama tarafından silinir). |
| `my_family_id()`, `my_child_id()`, `my_any_family_id()` | `uuid` | iç | Politikalarda oturumun ailesi / çocuğu. |
| `task_family(uuid)`, `child_family(uuid)`, `task_assigned_to_me(uuid)` | `uuid` / `boolean` | iç | Politikalarda tablolar arası kontrol. |
| `child_may_complete(p_task_id, p_status)` | `boolean` | iç | Eskiden çocuğun doğrudan `completions` yazımında izindi. **`20261022150000_security_game` (uygulandı 22 Ekim):** çocuk doğrudan yazım politikaları kaldırılır, bu fonksiyon kimseye açık değildir; çocuk yalnız `child_set_status` ile yazar. |
| `random_code()` | `text` | iç | 6 karakter, alfabe `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (I, L, O, 0, 1 yok). |
| `handle_new_user()` (tetikleyici) | — | iç | Yeni **anonim olmayan** kullanıcıda aile + profil oluşturur. Anonim (çocuk) oturumlarda hiçbir şey yapmaz. |
| `set_updated_at()` (tetikleyici) | — | iç | `profiles`, `tasks` için `updated_at`. |

### 2.2 Oyun eklemeleri (M4)

| Fonksiyon | Dönüş | Çağıran | Ne yapar |
|---|---|---|---|
| `child_me()` | `json {child_id, name, avatar, age_band, balance, sun_stones}` (`sun_stones`: `20261019030000_sun_stones` (uygulandı)) | O | Oturumdaki çocuk + coin bakiyesi. Bağlantı yoksa hata `42501` ("Bağlantı yok"). Oyun bakiyeyi buradan alır. |
| `child_tasks(p_from date, p_to date)` | `table(task_id, date, title, description, emoji, coins, recurring, repeat_kind, requires_review, status, parent_note, skill, difficulty)` (`skill`, `difficulty`: `20261019030000_sun_stones` (uygulandı)) | O | Tarih aralığındaki görev **örnekleri** (en fazla 31 gün). Tekrarlar sunucuda açılır (`task_occurs_on`). Kayıt yoksa `status = 'assigned'`. Sıra: gün, sonra `sort_order`. Oyun dünden 7 gün sonrasına kadar çeker. |
| `child_set_status(p_task_id uuid, p_date date, p_status text)` | `text` (yazılan durum) | O | Çocuğun niyeti: `pending` (yaptım), `declined` (yapamam), `assigned` (geri al → kaydı siler). Ebeveyn karar verdiyse (`approved`/`rejected`) hata. İnceleme gerektirmeyen görevde `pending` → `approved` yazılır. Gelecek gün (`> current_date + 1`) ve (`20261019020000_server_rules`, uygulandı 19 Ekim) iki gün öncesi ve daha eskisi (`< current_date - 1`) işaretlenemez. |
| `spend_coins(p_tx text, p_item_id text, p_quantity integer)` | `json {ok, error, balance}` | O | Harcama. Fiyat `game_items`'tan; `p_tx` 8–64 karakter, aynı `p_tx` ikinci kez düşmez (idempotent); `p_quantity` 1–20; bakiye eksiye düşmez. `error` ∈ `null`/`unknown_item`/`not_enough_coins`. Öneri `20261019020000_server_rules`: `min_level > child_level` → `level_locked`. |
| `game_save_get()` | `jsonb` (yoksa null) | O | Oyun kaydı yedeğini okur. |
| `game_save_put(p_data jsonb)` | `void` | O | Yedeği yazar (en fazla 262 144 bayt). |
| `set_child_age_band(p_child_id uuid, p_band text)` | `void` | P | Bandı yazar (`A`/`B`/`C` ya da null). |
| `review_completion(p_task_id, p_child_id, p_date, p_status, p_note default null)` | `void` | P | Ebeveyn kararı: `approved`/`rejected`/`pending`. Kayıt yoksa oluşturur; `parent_note`, `reviewed_at`, `reviewed_by` yazar. ParentApp onay ve ret için bunu çağırır (19 Ekim kararı). |
| `unlink_child_device(p_child_id uuid)` | `void` | P | `children.user_id = null`. Oyun bir sonraki kontrolde "bağlantın kapatıldı" der. |
| `child_balance(p_child_id uuid)` | `integer` | P | Aynı ailedeki çocuğun coin bakiyesi. |
| `suggest_age_band(p_birthday date)` | `text` | iç (istemciye açık ama kullanılmıyor) | Doğum günü yok → `A`; yaş < 9 → `A`; aksi `B` (C yok; `20261019110000_age_bands.sql`, canlıda doğrulandı 21 Ekim 2026). |
| `child_age_band(uuid)`, `coin_balance(uuid)` | `text` / `integer` | iç | İstemciye kapalı. |
| `task_occurs_on(t tasks, d date)` | `boolean` | iç | Görev o gün var mı (tek seferlik: başlangıç günü; tekrarlı: günlük / haftanın / ayın günleri; ayda olmayan gün → ayın son günü). |
| `completions_coin_trigger()` (tetikleyici `completions_coin`) | — | iç | `approved`'a geçişte `+coins` (`reason='task'`), `approved`'dan çıkışta ya da silinişte `-coins` (`reason='task_undo'`). Onayda tutar o andaki `task_assignments.coins`; geri almada o tamamlama için verilmiş net tutar, görev/atama silinmişse geri alma yok (`20261019100000_task_rewards.sql`, uygulandı). Ayrıntı: `ekonomi.md`. |

### 2.3 Oyunun doğrudan tablo okuması
- `GET /rest/v1/children?select=id&user_id=eq.<uid>`: Oyun bağlantının hâlâ açık olup olmadığını böyle denetler (`SupabaseAuthService.ValidateAsync`). Boş liste = bağlantı kaldırıldı (`Revoked`).

---

## 3. RLS ilkeleri (uygulanmış)

| Kim | Ne görür / ne yapar |
|---|---|
| **Ebeveyn** | Yalnız kendi ailesinin satırları (`family_id = my_family_id()`): çocuklar, görevler, atamalar, tamamlamalar, mesajlar, şablonlar, kodlar (yalnız okur), coin defteri (yalnız okur), oyun kayıtları (yalnız okur). Aynı ailedeki diğer ebeveyn profillerini görür. `families.name` ve kendi profilinin `nickname/name/avatar` alanlarını değiştirebilir. `children.user_id` sütununa doğrudan yazamaz. |
| **Çocuk (oyun, anonim oturum)** | Yalnız kendi `children` satırı; kendisine atanmış görevler ve atamalar; kendi tamamlamaları (okur; yazım **yalnız `child_set_status` RPC'si** ile — dün/bugün/yarın, ebeveyn kararı değişmez; doğrudan insert/delete `20261022150000_security_game` ile kapandı); kendi mesajları (okur, `sender='child'` ile gönderir); kendi coin defteri ve oyun kaydı (yalnız okur). Coin ekleyemez, fiyat belirleyemez. |
| **Herkes (oturum açmış)** | `game_items` (fiyat listesi) okunur. |
| **İstemci hiçbir zaman** | `invite_codes`, `coin_ledger`, `game_items`, `game_saves`, `families`(ekleme/silme), `profiles`(ekleme/silme) tablolarına doğrudan yazamaz. Bunlar yalnız fonksiyon/tetikleyiciyle değişir. |

---

## 4. Klinik (ClinicApp) — uygulandı

> **Uygulandı (19 Ekim 2026).** Kaynak: `supabase/migrations/20261019000000_clinic.sql`.
> Önkoşul: 1–2. bölümdeki şema. ParentApp'in "Aile › Hesap › Uzmanım" ekranı (aynı dalda, `src/lib/clinic.ts`) bu tabloları kullanır.
> İlkeler (SQL başlığından): uzman çocuğun verisini **yalnız ebeveynin açık rızasıyla** (`clinic_links.status = 'active'`) görür; ebeveyn rızayı her an geri alır; uzman **yalnız okur** (görev, tamamlama, ABC) ve görev **önerir**; Posta ve coin defteri uzmanla paylaşılmaz; klinik notları ve hedef puanları ailede görünmez.

### 4.1 Tablolar

| Tablo | Amaç | Önemli sütunlar | Yazar | Okur |
|---|---|---|---|---|
| `clinics` | Klinik | `name` (1–120), `plan` (`trial`/`solo`/`clinic`/`small`/`business`/`custom`/`inactive`, varsayılan `trial`), `seat_limit` (varsayılan 10 öneride; 1–1000), `trial_ends_at` (varsayılan +7 gün öneride; eskiden 14), üyelik alanları bölüm 8 | Sunucu (kayıtta); K sahibi yalnız `name`; plan/koltuk yalnız service role | K (kendi kliniği) |
| `clinicians` | Uzman (auth.users ile bire bir) | `id`, `clinic_id`, `name` (≤ 80), `title` (≤ 80), `role` (`owner`/`member`) | Sunucu (kayıtta); K yalnız kendi `name`, `title` | K (aynı klinik) |
| `clinic_invites` | Klinik davet kodları | `code`, `clinic_id`, `clinician_id`, `kind` (`family`/`clinician`), `label` (≤ 60), `expires_at` (varsayılan **+7 gün**), `used_at`, `used_by` | Sunucu (`clinic_create_invite`) | K (kendi kliniği) |
| `clinic_links` | **Rıza bağlantısı** klinik ↔ çocuk | `clinic_id`, `clinician_id`, `family_id`, `child_id`, `label`, `status` (`active`/`revoked`), `consent_by`, `consent_at`, `revoked_at`, `revoked_by`; bir klinik–çocuk çifti için tek `active` satır | Sunucu (`redeem_clinic_invite`, `revoke_clinic_link`); K yalnız `label`, `clinician_id` | K (kendi kliniği), P (kendi ailesi) |
| `clinic_notes` | Uzman notları (aile görmez) | `link_id`, `clinic_id`, `author_id`, `body` (1–4000) | K | K |
| `clinic_goals` | Hedef (GAS) | `link_id`, `title` (1–120), `description` (≤ 600), `archived` | K | K |
| `goal_ratings` | Haftalık hedef puanı | PK (`goal_id`, `week`), `week` (haftanın pazartesisi), `rating` (−2 … +2), `note` (≤ 300) | K | K |
| `abc_events` | Zor an kaydı (Öncesi–Davranış–Sonucu) | `family_id`, `child_id`, `occurred_at`, `antecedent` (≤ 400), `behavior` (1–400), `consequence` (≤ 400), `intensity` (1–5, varsayılan 3) | P | P, K (rızalı bağlantı varsa) |
| `clinic_task_suggestions` | Uzmanın aileye görev önerisi | `link_id`, `family_id`, `child_id`, `title`, `emoji`, `skill`, `difficulty` (`easy`/`medium`/`hard`), `recurring` (varsayılan true), `note` (≤ 300), `status` (`pending`/`accepted`/`declined`), `decided_at`, `task_id` (kabulde oluşan görev; yalnız aynı ailenin görevi). **20261019140000 ile:** ParentApp görev alanları `description` (≤ 1000), `category` (`home`/`mind`/`learn`/`self`/null), `template_key` (ParentApp şablonu, ör. `t9`; özel görevde null), `coins` (0–50; null = zorluğun varsayılanı), `start_date` (null/geçmiş = kabul günü), `repeat_kind` (`daily`/`weekly`/`monthly`), `repeat_days` (haftalık 1–7, aylık 1–31), `end_date`, `reminder` (`HH:MM`/null), `requires_review` (varsayılan true), `updated_at` | K (ekler; `pending` iken `clinic_update_suggestion` ile günceller ya da geri çeker); P yalnız `status`, `decided_at`, `task_id` | K, P |
| `family_subscriptions` | Aile aboneliği | `family_id` (PK), `plan` (`free`/`premium`), `source` (`store`/`web`/`manual`), `period_end` | Sunucu (service role) | P (kendi ailesi) |
| `completions.child_done_at` (yeni sütun) | Çocuğun "Yaptım"/"Yapamam" dediği an | tetikleyici `completions_child_done_at` doldurur | Sunucu | P, K |
| `completions.decline_reason` (yeni sütun) | "Yapamam" nedeni | `hard`/`no_time`/`did_not_want`/`other`/null | O (`child_set_decline_reason`; oyun henüz çağırmıyor, çağırmazsa null kalır) | P, K |

Realtime'a eklenecekler: `clinic_links`, `clinic_task_suggestions`, `abc_events`.

### 4.2 Fonksiyonlar

| Fonksiyon | Dönüş | Çağıran | Ne yapar |
|---|---|---|---|
| `clinic_create_invite(p_kind text default 'family', p_label text default '')` | `json {code, expires_at}` | K | Uzman, aile (`family`) ya da ekip (`clinician`, yalnız `owner`) daveti üretir. Kod `random_code()`; `invite_codes` ile çakışmaz. 7 gün geçerli. |
| `clinic_invite_preview(p_code text)` | `json {clinic, clinician, title}` | P | Ebeveyn, rıza vermeden önce kimin istediğini görür. |
| `redeem_clinic_invite(p_code text, p_child_id uuid)` | `json {link_id}` | P | Ebeveynin açık rızası: `clinic_links` satırı (`active`) oluşturur, kodu tüketir. Aynı klinik–çocuk için etkin bağlantı varsa hata. |
| `revoke_clinic_link(p_link_id uuid)` | `void` | P ya da K | Paylaşımı sonlandırır (`status='revoked'`). Erişim hemen biter. |
| `family_clinic_links()` | `table(link_id, child_id, clinic, clinician, title, consent_at)` | P | Ailenin etkin paylaşımları. |
| `clinician_me()` | `json {id, name, title, role, clinic_id, clinic, plan, seat_limit, trial_ends_at, active}` | K | Uzmanın kendi kaydı ve kliniği. |
| `clinic_clients()` (20261019140000) | `table(link_id, clinic_id, family_id, child_id, child_name, avatar, birthday, label, consent_at, parents)` | K | Etkin rızalı danışanlar; `parents` = ailedeki ebeveynlerin adı (yoksa takma adı), virgülle. `profiles` uzmana açılmaz. |
| `clinic_update_suggestion(p_id uuid, p jsonb)` (20261019140000) | `void` | K | Uzman kendi kliniğinin **bekleyen** önerisini günceller; yalnız `p`'de gelen alanlar değişir; karar verilmişse ya da paylaşım bittiyse hata. |
| `my_clinic_id()`, `clinic_sees_child(uuid)`, `clinic_sees_task(uuid)`, `clinic_link_mine(uuid)` | — | iç | Politikalar için. |
| `clinic_active(p_clinic_id)` | `boolean` | iç | Plan `small`/`business`/`custom` ya da `trial` ve deneme süresi bitmemiş. |
| `family_premium(p_family_id default null)` | `boolean` | P (doğrulanmalı: ParentApp'te çağrı bulunamadı) | Aile kendi aboneliğiyle premium **ya da** etkin bir kliniğe bağlı çocuğu var. |
| `handle_new_user()` (değişir) | — | iç | `raw_user_meta_data.account = 'clinician'` ise aile yerine klinik oluşturur (`owner`) ya da `team_code` ile ekibe katılır (`member`; koltuk sınırı denetlenir). Ebeveyn davranışı aynı kalır. |
| `completions_child_done_at()` (tetikleyici) | — | iç | `child_done_at` boşsa ve durum `pending`/`declined`'e (ya da **çocuğun** yazdığı `approved`'a) geçince `now()` yazar; ebeveynin doğrudan onayı "Yaptım" anı sayılmaz. Durum `declined` değilse `decline_reason`'ı siler. |
| `child_set_decline_reason(p_task_id uuid, p_date date, p_reason text)` | `void` | O | "Yapamam"dan sonra nedeni yazar (`hard`/`no_time`/`did_not_want`/`other`/null). Yalnız çocuğun kendi `declined` kaydına; yoksa hata. `child_set_status` değişmez. |

### 4.3 RLS ilkeleri

| Kim | Ne görür / ne yapar |
|---|---|
| **Uzman** | Kendi kliniği, ekip arkadaşları, kendi davetleri, kendi kliniğinin bağlantıları/notları/hedefleri/puanları/önerileri. Rızalı (`active`) bağlantısı olan çocuğun `children`, `tasks` (atanmış), `task_assignments`, `completions`, `abc_events` satırlarını **yalnız okur**. `messages`, `coin_ledger`, `game_saves` erişimi **yoktur**. Plan/koltuk sütunlarını değiştiremez. |
| **Ebeveyn** | Kendi ailesinin `clinic_links`, `clinic_task_suggestions` (yalnız `status`/`decided_at` günceller), `abc_events` (tam erişim), `family_subscriptions` (yalnız okur). `clinic_notes`, `clinic_goals`, `goal_ratings` **görmez**. |
| **Çocuk (oyun)** | Klinik tablolarının hiçbirine erişimi yok. |

---

## 5. Bildirimler ve çoklu çocuk paylaşımı (19 Ekim 2026'da uygulandı)

SQL: `supabase/migrations/20261019120000_clinic_children.sql`, `20261019130000_notifications.sql`. Akış: `akislar.md` 7–8.

| Tablo | Ne | Alanlar | Yazar | Okur |
|---|---|---|---|---|
| `notifications` | Kullanıcı başına bildirim kutusu | `id` (bigserial), `user_id`, `app`, `kind`, `title` (≤120), `body` (≤300), `data` (jsonb), `family_id`, `child_id`, `created_at`, `read_at` | **Yalnız sunucu tetikleyicileri**; kullanıcı yalnız `read_at` günceller ve siler | Kendi satırları (O, P, K) — Realtime yayınında |
| `push_tokens` | Cihaz push anahtarı | `token` (PK), `user_id`, `app`, `platform`, `updated_at` | Yalnız RPC | Kendi satırları |

| Fonksiyon | Kim | Ne |
|---|---|---|
| `register_push_token(p_token, p_app, p_platform)` | O, P, K | Anahtarı bu kullanıcıya bağlar (cihaz hesap değiştirdiyse taşınır) |
| `unregister_push_token(p_token)` | O, P, K | Çıkışta / bildirim kapatılınca |
| `mark_notifications_read(p_ids bigint[] default null)` | O, P, K | Verilenleri ya da hepsini okundu yapar; sayı döndürür |
| `redeem_clinic_invite_children(p_code, p_child_ids uuid[])` | P | Tek kodla birden çok çocuk; `{link_ids, clinic_id}` |
| `clinic_share_child(p_clinic_id, p_child_id)` | P | O klinikle etkin paylaşım varsa kodsuz çocuk ekler |
| `family_clinic_links()` | P | Dönüşe `clinic_id` eklendi |
| İç: `notify`, `notify_parents`, `notify_child`, `notify_clinic`, `child_name`, olay tetikleyicileri, `notifications_push` (pg_net → Edge Function `push-apns` / Expo) | — | İstemci çağıramaz |
| Edge Function `push-apns` (`supabase/functions/push-apns`) | sunucu | Bildirimi Apple'a gönderir; `notifications.apns_sent_at` yazar |

## 6. Klinik ekibi ve kullanıcı takibi (21 Ekim 2026'da uygulandı, `migrations/20261021100000_clinic_team_tracking.sql`)

Akış: `akislar.md` 5.1 (4a, 5) ve 9.

| Tablo | Ne | Alanlar | Yazar | Okur |
|---|---|---|---|---|
| `user_activity` | Kullanıcı × uygulama etkinliği | PK (`user_id`, `app`), `first_seen_at`, `last_seen_at`, `last_active_date`, `sessions`, `active_days`, `platform`, `app_version` | Yalnız `track_session` | **Kimse** (RLS açık, politika yok); SQL Editor / service_role |
| `app_events` | Uygulama olayları | `id`, `user_id`, `app`, `event` (`^[a-z][a-z0-9_.]{1,59}$`), `props` (nesne, ≤ 1000 karakter), `session_id`, `platform`, `app_version`, `occurred_at` (istemci saati, −2 gün…+5 dk), `created_at` | Yalnız `track_events` | **Kimse**; SQL Editor / service_role |

| Fonksiyon | Kim | Ne |
|---|---|---|
| `clinician_me()` | K | Dönüşe `owner_name`, `invited_by_name`, `joined_at` eklendi |
| `clinic_join_team(p_code)` | K | Giriş yapmış uzman ekip koduyla katılır (eski klinik boşsa silinir, doluysa hata). `{clinic_id}` |
| `track_session(p_app, p_platform, p_version)` | O, P, K | Oturum / aktif gün |
| `track_events(p_app, p_events jsonb, p_platform, p_version)` | O, P, K | Toplu olay; yazılan sayı döner |
| İç: `clinicians_notify_move` | — | Sonradan katılan uzman için sahibe `team_joined` |

Görünümler (şema `analytics`, anon/authenticated erişemez): `accounts` (her `auth.users` satırı: e-posta, kayıt, son giriş, tür `parent`/`clinician`/`child`/`other`, aile/klinik, son görülme, uygulama sürümleri), `signups_daily`, `daily_active`, `events_daily`, `clinics_overview`, `families_overview`.

## 7. Güvenlik sertleştirmesi (21 Ekim 2026'da uygulandı, `migrations/20261021200000_security_hardening.sql`)

- Girişsiz rol (`anon`) hiçbir `public` fonksiyonu çağıramaz (bugünkü ve sonraki fonksiyonlar; uzantılar hariç). Bütün uygulamalar girişten sonra çağırır; GameApp önce anonim oturum açar (`authenticated`).
- `family_premium(p_family_id)`: giriş yapmış kullanıcı yalnız kendi ailesini sorar; başka aile kimliği `false` döner. Oturumsuz (SQL Editor/service_role) bütün aileler.
- Güvenlik matrisi testi: `supabase/test/test_security_matrix.sql` (girişsiz, ebeveyn, başka aile, çocuk cihazı, klinik sahibi, ekip üyesi, başka klinik; rıza geri alınması).

## 8. ClinicApp üyeliği (`migrations/20261022200000_clinic_billing.sql`, uygulandı 23 Ekim)

Paketler: **Bireysel** (`solo`, 1 uzman) ve **Klinik** (`clinic`, ekip dahil en çok 10 uzman); aylık ya da yıllık. Yeni klinik **7 gün** ücretsiz dener (kart yok, denemede 10 koltuk). Deneme ya da üyelik bitince uzman çocuk verisine erişemez; veriler silinmez.

| Tablo / alan | Ne | Yazan | Okuyan |
|---|---|---|---|
| `clinics.plan` | `trial` / `solo` / `clinic` / (eski: `small`/`business`/`custom` elle, etkin) / `inactive` | Sunucu (`billing_apply`) | K |
| `clinics.billing_period`, `period_end`, `billing_source` (`app_store`/`iyzico`/`manual`), `auto_renew` | Üyelik dönemi | Sunucu | K (`clinician_me`) |
| `billing_plans` | Paket kataloğu: `id` (`solo_monthly`, `solo_yearly`, `clinic_monthly`, `clinic_yearly`), `package`, `period`, `seat_limit`, `price_try` (KDV dahil), `apple_product_id` (`com.clinicapp.uzman.<paket>.<dönem>`), `iyzico_plan_ref` | service role (SQL Editor) | K (yalnız `active`) |
| `billing_subscriptions` | Mağaza/iyzico aboneliği ↔ klinik: `source` + `external_id` (App Store `originalTransactionId` / iyzico abonelik referansı) tekil; `status` (`active`/`canceled`/`expired`/`refunded`/`pending`), `period_end`, `auto_renew` | yalnız `billing_apply` | kimse (RLS açık, politika yok) |
| `billing_checkouts` | Web ödeme oturumu (iyzico token → klinik, paket); tek kullanımlık | Edge Function | kimse |
| `billing_events` | Ödeme günlüğü | `billing_apply` | kimse; `analytics.clinic_billing` görünümü SQL Editor'den |

| Fonksiyon | Kim | Ne yapar |
|---|---|---|
| `clinician_access()` | iç / K | Oturumdaki uzman paneli kullanabilir mi: klinik etkin **ve** (sahip ya da paket ekibe izin veriyor). `clinic_sees_child`, `clinic_link_mine`, `clinic_clients`, notlar/hedefler/öneriler bunu ister. |
| `clinic_active(p_clinic_id)` | iç | `trial` süresi bitmemiş, `solo`/`clinic` `period_end` geçmemiş ya da eski elle verilmiş plan. |
| `clinician_me()` | K | Dönüşe `access`, `status` (`trial`/`active`/`expired`), `billing_period`, `period_end`, `billing_source`, `auto_renew`, `member_count` eklendi. |
| `billing_apply(source, external_id, clinic_id, plan_id, status, period_end, auto_renew, environment, payload)` | yalnız service role | Doğrulanmış ödemeyi yazar; aynı abonelik başka kliniğe bağlanamaz; kliniğin planını en geniş etkin abonelikten yeniden hesaplar (`billing_recompute`). Elle pilot üyelik: `select billing_apply('manual','pilot-1','<klinik>','clinic_yearly','active', now()+interval '90 days', false);` |
| `clinic_create_invite` | K | Üyelik etkin olmalı; Bireysel pakette ekip daveti yok. |

Ödeme yolu (kullanıcı kararı 22 Ekim 2026): **RevenueCat**, klinik sahibi birey olarak öder. Edge Function `billing-webhook` (Verify JWT kapalı; `REVENUECAT_API_KEY` zorunlu) klinik ürünlerini `billing_apply('revenuecat', '<uzman kimliği>:<ürün>', klinik, paket, …)` ile yazar; paket `billing_plans.apple_product_id`'den bulunur. `clinic-billing` (Apple doğrudan + iyzico) ileride kendi sisteme geçiş için depoda durur, yayınlanmaz.

## 9. Sızma denemesi düzeltmeleri (öneri, `proposed/20261022010000_security_pentest.sql`)

- **Kod deneme sınırı:** `join_family`, `clinic_invite_preview`, `redeem_clinic_invite`, `redeem_clinic_invite_children`, `clinic_join_team` hatalı kodda artık exception değil **HTTP 400** + `{"error":"invalid_code","message":"…"}` döner (deneme `code_attempts`'e yazılır); kullanıcı başına 15 dakikada 10 hatalı denemeden sonra **HTTP 429** `{"error":"too_many_attempts"}`. supabase-js bunu yine `error.message` olarak verir. `join_family` dönüşü `uuid` yerine `json {family_id}` (ParentApp yalnız hatayı okuyor).
- Ekip kodu **8 karakter, 48 saat**; aile kodu 6 karakter, 7 gün.
- Ekibe katılımda koltuk sayımı klinik satırı kilitlenerek yapılır (yarışla koltuk aşımı yok).
- `clinic_links.clinician_id` yalnız aynı klinikten bir uzman olabilir.
- Uzman hesabı `redeem_child_code` kullanamaz.
- `clinic_notes`: herkes okur; yalnız yazarı ya da klinik sahibi değiştirir/siler; `author_id`/`link_id` değiştirilemez.
- `clinic_task_suggestions` eklemede `created_by = auth.uid()`, `task_id`/`decided_at` boş olmalı.
- `track_events`/`track_session`: uygulama adı hesap türüyle eşleşmezse satır yazılmaz.
- `delete_account()` uzman hesabını da kapsar: tek kişilik klinik bütün verisiyle silinir; ekip varsa klinik kalır, sahiplik en eski üyeye geçer.
- `notifications_push` Vault'ta `push_secret` varsa `x-push-secret` başlığı gönderir; `push-apns` `PUSH_SECRET` tanımlıysa bu başlığı ister.
- TRUNCATE `anon`/`authenticated`'dan alınır.
- Test: `supabase/test/test_security_pentest.sql`.

---

> **ParentApp penceresinin önerileri (22 Ekim 2026, uygulanmadı).** Bölüm numaraları `P` ile başlar.

## P6. Kodlar, abonelik, mesajlar, Güneş Taşı, güvenlik (öneri, 21 Ekim 2026 — uygulanmadı)

SQL: `supabase/migrations/20261022100000_codes_15min.sql`, `20261022110000_subscriptions.sql`, `20261022120000_messages.sql`,
`20261022130000_sun_stones_rewards.sql`, `20261022140000_whitehat_fixes.sql`. Testler: `test_codes`, `test_subscriptions`,
`test_messages`, `test_rewards`, `test_whitehat`. Akış: `akislar.md` 9–12. Değerler: `durumlar.md` 11–14, `ekonomi.md` 9.

### 6.1 Tablolar

| Tablo / alan | Ne | Alanlar | Yazar | Okur |
|---|---|---|---|---|
| `code_attempts` (+alan) | `ip` eklendi (IP başına sınır) | — | Yalnız fonksiyonlar | Kimse (istemci) |
| `families.trial_started_at` | Deneme başlangıcı (e-posta doğrulama anı) | — | Sunucu tetikleyicisi | P (`family_access`) |
| `trial_history` | Deneme almış e-postaların SHA-256 özeti (yeniden kayıtla yeni deneme alınmasın) | `email_hash`, `started_at` | Sunucu | Kimse. Hesap silinince kalır → gizlilik metnine yazılmalı |
| `family_subscriptions` (+alan) | `billing`, `status`, `product_id`, `store_transaction_id`, `auto_renew`, `started_at` | — | Yalnız service role (`set_family_subscription`) | P (kendi ailesi) |
| `app_config` | Uygulama ayarı (`billing`) | `key`, `value` (jsonb) | Yalnız SQL Editor | Giriş yapmış herkes (`billing`) |
| `messages` (+alan) | `read_at`; `kind` += `sticker` | — | P/O INSERT (politika), `read_at` yalnız RPC | P (aile), O (kendi sohbeti) |
| `sun_stone_ledger` (+alan) | Güneş Taşı defteri (GameApp'ten): `note`, `created_by` eklendi; `reason` += `reward`, `penalty` | — | Yalnız tetikleyici/RPC | P (aile), O (kendi) — Realtime |
| `rewards` | Ebeveynin ödülleri | `title` (1–60), `kind` (`item` eşya/etkinlik · `exchange` değiş tokuş), `cost` (1–500 taş), `unit` (`minute` ekran süresi / `money` TL; yalnız değiş tokuş), `unit_amount` (cost taş karşılığı miktar), `child_ids` (boş = hepsi), `icon` (simge anahtarı), `active` | P (ücretsiz planda kapalı) | P, O (kendine açık + etkin) — Realtime |
| `reward_requests` | Ödül istekleri / verilen ödüller | `child_id`, `reward_id`, `title`, `quantity` (1–20), `cost` (toplam taş), `unit`, `amount` (toplam dakika/TL), `source`, `status`, `note`, `decided_*` | Yalnız RPC | P (aile), O (kendi) — Realtime |

### 6.2 Fonksiyonlar

| Fonksiyon | Kim | Ne |
|---|---|---|
| `join_family`, `redeem_child_code`, `clinic_invite_preview`, `redeem_clinic_invite(_children)`, `clinic_join_team` | P / O / K | Kod hatasında `reason` (expired/used/not_found) eklendi; durumlar P11 |
| `family_access()` | P | `{state, full, enforced, trial_started_at, trial_ends_at, days_left, plan, period_end, auto_renew, subscription_status, limits}` |
| `family_premium(p_family_id)` | P, K | premium / ücretli klinik / deneme sürüyor |
| `set_family_subscription(...)` | service role | Ödeme webhook'u (Edge Function `billing-webhook`, RevenueCat; secret'lar `BILLING_WEBHOOK_SECRET`, `REVENUECAT_API_KEY`) |
| `mark_messages_read(p_child_id)` | P (çocuğun mesajları), O (ebeveyn mesajları; parametresiz) | Okundu sayısı |
| `child_send_message(p_kind, p_body)` | O | `text` (≤ 500) / `sticker` → `{id, created_at}` |
| `child_messages(p_limit default 100)` | O | Sohbet (eskiden yeniye) + `from_name` |
| `sun_stones_spendable(p_child_id)` | P (aile), O (yalnız kendisi) | Harcanabilir bakiye (`child_me.sun_stones_spendable` da). `child_me.sun_stones` = kazanılan (ada), değişmedi |
| `give_reward(p_child_id, p_reward_id, p_quantity default 1)` | P | `{request_id, balance}` |
| `deduct_sun_stones(p_child_id, p_amount, p_note)` | P | `{balance}` |
| `request_reward(p_reward_id, p_quantity default 1)` | O | `{request_id, status}` |
| `cancel_reward_request(p_request_id)` | O | Bekleyen isteği geri çeker |
| `decide_reward_request(p_request_id, p_approve, p_note)` | P | `{status, balance}` |
| `register_push_token` (değişti) | O, P, K | Kullanıcı başına en yeni 5 anahtar |

### 6.3 Güvenlik değişiklikleri

- Çocuğun `completions`'a doğrudan INSERT izni kaldırıldı (yalnız `child_set_status`): istediği tarihe "onaylandı" yazıp coin basabiliyordu.
- Klinik denemesi (trial) aileye premium vermez; yalnız ücretli klinik planı.
- `clinic_goals.created_by`, `goal_ratings.rated_by` sunucu doldurur. Metin alanlarına uzunluk sınırı. Push anahtarı kullanıcı başına 5.
- Edge Function `push-apns`: yalnız son 10 dakikada oluşmuş bildirim; yanıtta cihaz bilgisi yok (gizli başlık kuralı korunur).

## 10. Klinik içi danışan ataması (22 Ekim 2026'da uygulandı, `migrations/20261022100000_clinic_assignments.sql`)

- **Görünürlük:** klinik sahibi kliniğin bütün paylaşımlarını görür. Ekip üyesi yalnız sorumlusu olduğu (`clinic_links.clinician_id`, ailenin kullandığı kodu üreten uzman) ve sahibin ona atadığı paylaşımları görür. Kural çocuk, görev, tamamlama, zor an + ses, not, hedef/puan, öneri ve danışan listesine (`clinic_clients`) sunucuda uygulanır (`clinic_link_visible`, `clinic_sees_child`, `clinic_link_mine`).
- **`clinic_link_access`** (`link_id`, `clinician_id`, `clinic_id`, `granted_by`): sahibin atamaları. RLS: sahip kliniğin bütün satırlarını, üye yalnız kendi satırlarını okur; yazma yalnız RPC.
- **RPC:** `clinic_assign(link_id, clinician_id, assigned bool)` (yalnız sahip; atanan üyeye `client_assigned` bildirimi), `clinic_set_responsible(link_id, clinician_id)` (yalnız sahip). Sorumlu uzmanı başka kimse değiştiremez (tetikleyici; kendi sorumluluğunu bırakma ve hesap silme hariç).
- **`clinic_clients()`** dönüşüne `clinician_id`, `clinician_name`, `assigned uuid[]` eklendi.
- **Bildirim alıcıları** (`clinic_link_recipients`): sorumlu + atananlar; kimse yoksa klinik sahibi. Kardeşlerin ortak zor an/paylaşım bildirimi kişi başına yalnız görebildiği çocukları içerir. Yeni bildirim türü: `client_assigned`.
- Uzman paylaşımı yalnız görebildiği danışan için sonlandırabilir.

## 11. Aile davet bağlantısı, geçmiş aktarımı, takip planı (öneri, `proposed/20261026100000_family_invite_links.sql`)

Akışlar: `akislar.md` 10–13. Durum adları: `durumlar.md` P15.

### 11.1 Tablolar
| Tablo | Ne | Alanlar | Okur | Yazar |
|---|---|---|---|---|
| `clinic_invites` (genişledi) | Aile daveti bağlantısı | `token` (32 hex, tekil), `parent_name` (≤ 60), `parent_email`, `channel`, `opened_at`, `claimed_at`, `claimed_family`, `expired_notified_at`, `revoked_at` | K: yalnız kendi davetleri, sahip hepsi (önceden bütün ekip) | yalnız RPC |
| `clinic_goals` (genişledi) | Hedef: GAS + takip planı | `link_id` artık boş olabilir; `invite_code` (davet taslağı), `domain`, `measure`, `baseline`, `target`, `weeks`, `home_support`, `shared`, `status`, `position`, `template_key`, `updated_at` | K (paylaşım ya da kendi davet taslağı); **P yalnız `shared` ve etkin paylaşım**; devralan K okur | K |
| `care_modules` | Aile programı modülü | `link_id` ya da `invite_code`, `title`, `aim`, `practice`, `checklist` (jsonb ≤ 8), `position`, `status`, `template_key`, `created_by` | K; P (etkin paylaşım; `planned` görünmez); devralan K | K |
| `care_module_logs` | Ebeveynin uygulama kaydı | `module_id`, `family_id` (sunucu), `day`, `practiced`, `difficulty` (1–5), `barrier`, `note` (≤ 300); kişi+gün tekil | P (kendi ailesi); K (görünür paylaşım ya da devralınan) | P (yalnız `active` modüle) |
| `clinic_link_history` | Geçmiş aktarımı rızası | `link_id` (yeni), `from_link_id` (önceki), `granted_by`, `granted_at`, `consent_version` (onaylanan metin sürümü) | P (kendi) | yalnız RPC |

`goal_ratings` (GAS puanı) aileye **kapalı** kalır; devralan uzman yalnız `clinic_inherited_records` ile okur (önceki uzman adsız).

### 11.2 Fonksiyonlar
| Fonksiyon | Kim | Ne |
|---|---|---|
| `clinic_create_invite(kind, label, parent_name, parent_email)` | K | Aile: 48 saat, `{code, token, expires_at}`; ekip: 15 dk (imza değişti; eski 2 argümanlı çağrı aynen çalışır) |
| `clinic_invite_mark(code, channel, revoke)` | K (davet sahibi / klinik sahibi) | Kanal kaydı ya da iptal (iptal taslak planı siler) |
| `clinic_invites_list(gün)` / `clinic_invite_stats(gün)` | K | Davet listesi + durum / uzman başına gönderilen, açılan, bağlanan, paylaşılan, süresi dolan |
| `clinic_invites_sweep()` | K | Kendi kliniğinin süresi dolan davetleri için `invite_expired` (zamanlayıcı yoksa) |
| `clinic_invites_expire(clinic?)` | yalnız sunucu (pg_cron) | Aynısı, bütün klinikler |
| `clinic_invite_open(token)` | yalnız service_role (Edge Function `invite-info`) | Açılış sayfası bilgisi + `opened_at` |
| `claim_clinic_invite(token|kod)` | P | Daveti aileye bağlar (çocuk paylaşılmaz); `{clinic, clinician, title, label, has_plan}` |
| `family_pending_invites()` | P | Bağlı, henüz paylaşılmamış davetler (30 gün) |
| `clinic_invite_preview(token|kod)` | P | Kod ya da anahtar; bağlanmış davet 30 gün |
| `redeem_clinic_invite_children(token|kod, çocuklar, paylaş_geçmiş=false, rıza_sürümü=null)` | P | Paylaşım + taslak planın taşınması (+ isteğe bağlı geçmiş aktarımı) |
| `clinic_link_history_set(link, açık, rıza_sürümü=null)` | P | Önceki uzman kayıtlarını bu uzmana aç/kapat; onaylanan metin sürümü kaydedilir |
| `clinic_inherited_records(link)` | K | Devralınan kayıtlar, önceki paylaşım başına: `{n, label: "Önceki uzman n", from, to (ay), notes, suggestions, goals (+ratings), modules (+logs)}`; ad, unvan, klinik ve kimlik yok; metinlerde adlar "[önceki uzman]" |
| `family_clinic_links()` | P | + `history_shared`, `history_available` |
| `care_plan_publish(link)` | K | Ebeveynlere tek `care_plan_shared` bildirimi |
| `family_care_plan(link)` | P | Paylaşılan hedefler + etkin/tamamlanan modüller + bu hafta uygulanan gün sayısı |
| `handle_new_user` | tetikleyici | Ebeveyn kaydında meta `clinic_invite` (anahtar/kod) ya da e-posta eşleşmesiyle daveti bağlar; hata kaydı engellemez |

Edge Function `invite-info` (Verify JWT kapalı): `GET ?t=<token>` → `{status, clinic, clinician, title, code?, expires_at}`. Açılış sayfası: `web/davet/index.html` (+ `apple-app-site-association.example.json`).
