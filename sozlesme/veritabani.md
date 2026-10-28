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
| `completions` | Bir görevin bir gündeki durumu | `task_id`, `child_id`, `date`, `status`, `parent_note` (M4, ≤ 300), `reviewed_at`, `reviewed_by`, `created_at`; `20261027130000`, uygulandı: `motivation` (1–5), `stones` (0–6); **unique (`task_id`, `child_id`, `date`)** | O (`child_set_status` RPC'si), P (doğrudan + `review_completion`) | P, O (kendi satırları) |
| `messages` | Posta (ebeveyn ↔ çocuk) | `child_id`, `sender` (`parent`/`child`), `sender_id`, `kind` (`text`/`image`/`audio`), `body` (≤ 2000), `media_path`, `duration_ms` | P (sender=`parent`); çocuk (sender=`child`) RLS ile izinli | P, çocuk (kendi mesajları) |
| `saved_templates` | Kaydedilen hazır/özel görev şablonları | `template_key` (ör. `t1`), `is_custom`, `saved`, `title`, `emoji`, `category` (`home`/`mind`/`learn`/`self`), `difficulty`, `skill` | P | P |
| `task_templates` (uygulandı `20261023010000`, 23 Ekim 2026) | Ev Görevleri şablon kataloğu (Türkçe; `gorev_sablonlari.md`; sürüm 2 temizliği `migrations/20261023030000`) | `key` (`gs_<kategori>_<sıra>`), `title`, `emoji`, `category` (ana = beceri), `categories` (süzgeç etiketleri), `age_bands` (K/A/B/C), `difficulty`, `coins`, `skill`, `sort`, `active` | yalnız göç | P, K, O (oturumlu herkes okur; RLS select `active`) |
| `invite_codes` | İkinci ebeveyn daveti ve çocuk giriş kodu | `code` (`^[A-Z0-9]{6}$`), `family_id`, `kind` (`parent`/`child`), `child_id` (yalnız `child` türünde dolu), `expires_at`, `used_at`, `used_by` | Sunucu (yalnız fonksiyonlarla) | P (kendi ailesinin kodları) |

Notlar:
- **Oyunda Posta yok:** Oyun kodunda `messages` tablosunu kullanan bir yer bulunamadı. RLS çocuğun okuyup göndermesine izin verir; bugün yalnız ParentApp kullanır.
- Görev tekrarı (`20261014000000_task_repeat_order.sql`): `repeat_kind` ∈ `daily`/`weekly`/`monthly` (varsayılan `daily`); `repeat_days` haftalıkta 1 = Pazartesi … 7 = Pazar, aylıkta 1 … 31 (ayda o gün yoksa ayın son günü). `sort_order` küçük olan üstte.
- **Realtime** yayını: `messages`, `completions`, `tasks`, `task_assignments`, `children`. ParentApp bunları dinler; oyun Realtime kullanmaz (senkron sırasında RPC ile çeker).
- **Storage** kovası `mail` (gizli, en fazla 10 MB; jpeg/png/heic/webp ve mp4/m4a/x-m4a/aac/mpeg). Dosya yolu `<family_id>/<dosya>`. Aile (ebeveyn **ve** çocuk) okur/yükler; yalnız ebeveyn siler.

### 1.2 Oyun eklemeleri (M4, uygulandı)

| Tablo / sütun | Amaç | Önemli sütunlar | Yazar | Okur |
|---|---|---|---|---|
| `children.age_band` | Ebeveynin seçtiği yaş grubu (isteğe bağlı) | `'K'` (≤5) / `'A'` (6–8) / `'B'` (9–12) / `'C'` (13+) / null = otomatik (doğum gününden, `durumlar.md` §4) | P (doğrudan sütun izni + `set_child_age_band`) | O (`redeem_child_code`, `child_me` yanıtında), P |
| `completions.parent_note` | Ebeveynin ret/onay/tekrar dene notu | ≤ 300 karakter | P (`review_completion`) | O (`child_tasks`), P |
| `completions.motivation` (uygulandı 27 Ekim 2026) | "Motive etmek ne kadar zordu?" ebeveyn gözlemi | 1 çok kolay … 5 çok zor, null = yanıtsız | P (`review_completion`) | P, K (bağlı ve rızalı; "tamamlama: bağlı klinik okur") |
| `completions.stones` (uygulandı 27 Ekim 2026) | Onayda verilen Güneş Taşı | 0–6, null = zorluğa göre (yalnız `approved`'da dolu) | P (`review_completion`) | P, K |
| `coin_ledger` | Coin defteri. Bakiye = `sum(amount)` | `id` (bigserial), `family_id`, `child_id`, `amount` (≠ 0), `reason` (`task`/`task_undo`/`spend`/`adjust`; öneri §12: + `welcome`), `ref`, `item_id`, `quantity`; **unique (`child_id`, `reason`, `ref`)** | **Sunucu** (tetikleyici `completions_coin` + `spend_coins`; öneri §12: `claim_welcome_coins`). İstemci yazamaz. | P (aile), O (kendi satırları; pratikte bakiye `child_me` ile gelir) |
| `sun_stone_ledger` | Güneş Taşı defteri (`20261019030000_sun_stones`, uygulandı 19 Ekim). Toplam = `sum(amount)` (en az 0) | `family_id`, `child_id`, `amount` (≠ 0), `reason` (`task`/`task_undo`/`adjust`), `ref`; unique (`child_id`, `reason`, `ref`) | yalnız tetikleyici `completions_sun_stone` | P (aile), O (kendi) |
| `game_items` | Dükkân fiyatları (**sunucu esas**) | `item_id` (PK), `price` (≥ 0), `min_level` (varsayılan 1) | Sunucu (SQL ile tohumlanır; istemci yazamaz) | Herkes (oturum açmış) |
| `game_levels` | Seviye eşikleri (`20261019020000_server_rules`, uygulandı 19 Ekim) | `level` (PK), `total_xp` | Sunucu (SQL ile tohumlanır; `levels.json` ile aynı) | Herkes (oturum açmış) |
| `code_attempts` | Hatalı kod denemeleri (`20261019020000_server_rules`, uygulandı 19 Ekim) | `user_id`, `at` | yalnız `redeem_child_code` | kimse (RLS açık, politika yok) |
| `game_saves` | Oyun kaydı yedeği | `child_id` (PK), `family_id`, `data` (jsonb, en fazla 262 144 bayt), `updated_at` | O (`game_save_put`) | O (`game_save_get`), P (aile; ParentApp bugün okumuyor) |

`game_items` içeriği oyunun `Resources/Data/items.json` dosyasıyla birebir aynıdır (48 eşya; fiyat ve seviye 2026-10-19'da karşılaştırıldı, fark yok). Liste: `ekonomi.md`.
Oyuna 23 Ekim'de eklenen 19 komik eşya (`fancy`) için öneri `migrations/20261024110000_fancy_items_catalog.sql` (uygulandı 24 Ekim 2026; §13). Bekçi testi `test_items_catalog.sql` sunucu kataloğunu `items.json` ile karşılaştırır.

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
| `task_templates_for(p_category text, p_band text)` | `setof task_templates` | P, K | Süzgeç: kategori etiketlerde ve yaş grubu (null = hepsi), `sort` sırasıyla. anon çağıramaz. |
| `skill_key(p)` | P, K, O (uygulandı: `migrations/20261023020000_skill_keys.sql`, 23 Ekim 2026) | Eski beceri etiketi → anahtar (`teamwork` … `kindness`); eşleşmeyen aynen. Tetikleyiciler `tasks_skill_key`, `cts_skill_key` yazarken uygular |
| `child_set_status(p_task_id uuid, p_date date, p_status text)` | `text` (yazılan durum) | O | Çocuğun niyeti: `pending` (yaptım), `declined` (yapamam), `assigned` (geri al → kaydı siler). Ebeveyn karar verdiyse (`approved`/`rejected`) hata. İnceleme gerektirmeyen görevde `pending` → `approved` yazılır. Gelecek gün (`> current_date + 1`) ve (`20261019020000_server_rules`, uygulandı 19 Ekim) iki gün öncesi ve daha eskisi (`< current_date - 1`) işaretlenemez. |
| `spend_coins(p_tx text, p_item_id text, p_quantity integer)` | `json {ok, error, balance}` | O | Harcama. Fiyat `game_items`'tan; `p_tx` 8–64 karakter, aynı `p_tx` ikinci kez düşmez (idempotent); `p_quantity` 1–20; bakiye eksiye düşmez. `error` ∈ `null`/`unknown_item`/`not_enough_coins`. Öneri `20261019020000_server_rules`: `min_level > child_level` → `level_locked`. |
| `game_save_get()` | `jsonb` (yoksa null) | O | Oyun kaydı yedeğini okur. |
| `game_save_put(p_data jsonb)` | `void` | O | Yedeği yazar (en fazla 262 144 bayt). |
| `set_child_age_band(p_child_id uuid, p_band text)` | `void` | P | Grubu yazar (`K`/`A`/`B`/`C`; null = otomatik). |
| `review_completion(p_task_id, p_child_id, p_date, p_status, p_note default null, p_motivation default null, p_stones default null)` | `void` | P | Ebeveyn kararı: `approved`/`rejected`/`pending`/`retry` (`20261027130000`, uygulandı: + `retry`, motivasyon 1–5, taş 0–6; retry yalnız bugün, hint `retry_past`). Kayıt yoksa oluşturur; `parent_note`, `reviewed_at`, `reviewed_by` yazar. ParentApp onay ve ret için bunu çağırır (19 Ekim kararı). Eski 5 parametreli çağrılar aynen çalışır. |
| `unlink_child_device(p_child_id uuid)` | `void` | P | `children.user_id = null`. Oyun bir sonraki kontrolde "bağlantın kapatıldı" der. |
| `child_balance(p_child_id uuid)` | `integer` | P | Aynı ailedeki çocuğun coin bakiyesi. |
| `suggest_age_band(p_birthday date)` | `text` | P, iç | `age_band(p_birthday)` ile aynı (eski ad, korunur). |
| `age_band(p_birthday date, p_on date default null)` | `text` | P, iç | Yaş grubunun tek kaynağı: < 6 `K`, < 9 `A`, < 13 `B`, aksi `C`; doğum günü yok `A`; gün yoksa Türkiye'nin bugünü (`20261023040000`). |
| `age_years(p_birthday date, p_on date default null)` | `integer` | P, iç | Verilen gündeki gerçek yaş (analiz ve raporlar bunu kullanır). |
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
| `abc_events` | Gözlem notu (Öncesi–Davranış–Sonucu) | `family_id`, `child_id`, `occurred_at`, `antecedent` (≤ 400), `behavior` (1–400), `consequence` (≤ 400), `intensity` (1–5, varsayılan 3) | P | P, K (rızalı bağlantı varsa) |
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

## 7.1 Tek seferlik veri işleri (uygulandı 23 Ekim 2026, `migrations/20261023050000_age_band_reset_auto.sql`)

| Tablo | Ne | Kim okur/yazar |
|---|---|---|
| `one_time_jobs` | `key` (birincil), `done_at`. Tek seferlik veri işinin yapıldığı işareti (ör. `age_band_reset_auto_20261023`: eski yaş grupları Otomatik'e). | Hiçbir uygulama (RLS açık, politika yok; `public`, `anon`, `authenticated` yetkisiz). Yalnız SQL Editor. |

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
| `child_messages(p_limit default 100)` | O | Sohbet (eskiden yeniye) + `from_name` + `from_avatar` (ebeveyn satırında gönderenin `profiles.avatar`'ı; öneri `20261027220000_parent_avatar_game`) |
| `sun_stones_spendable(p_child_id)` | P (aile), O (yalnız kendisi) | Harcanabilir bakiye (`child_me.sun_stones_spendable` da). `child_me.sun_stones` = kazanılan (ada), değişmedi |
| `give_reward(p_child_id, p_reward_id, p_quantity default 1)` | P | `{request_id, balance}` |
| `deduct_sun_stones(p_child_id, p_amount, p_note)` | P | `{balance}` |
| `request_reward(p_reward_id, p_quantity default 1)` | O | `{request_id, status}` (öneri §12: + `first`; ilk talepte ebeveyn bildirimi `data.first = true`) |
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

## 11. XP takibi: hatırlatma, 2× XP teklifi, dört yaş grubu, haftalık hedef (22 Ekim 2026'da uygulandı)

Dosyalar sırayla: `migrations/20261022210000_task_reminder_boost.sql`, `migrations/20261022220000_age_bands_four.sql`, `migrations/20261022230000_weekly_goal.sql` (testler `test_task_reminder_boost.sql`, `test_age_bands.sql`, `test_weekly_goal.sql`).

| Ad | Tür | Ne | Yazan | Okuyan |
|---|---|---|---|---|
| `child_tasks(p_from, p_to)` | RPC (değişti) | Yanıta `reminder` (`HH:MM`/null) eklendi (Y5: hatırlatmadan önce "Yaptım" bonusu oyunda hesaplanır) | — | O |
| `task_boosts` | Tablo | 2× XP teklifi (Y2): `child_id`, `task_id`, `date`, `family_id`, `choice` (`accepted` "Deneyeceğim" / `skipped` "Şimdi değil"), `offered_at`; görev örneği başına tek kayıt | O (`child_record_boost`) | P (aile), O (kendi) — K rızayla sonra |
| `child_record_boost(p_task_id, p_date, p_choice)` | RPC | Teklif cevabı; yalnız kendi atanmış görevi, bugün/dün; 7 günde en çok 3 farklı teklif | O | — |
| `children.age_band` | Sütun (kısıt değişti) | `K`/`A`/`B`/`C` (`durumlar.md` §4) | P | O, P |
| `game_level_bands` | Tablo | Gruba göre seviye eşikleri (`band`, `level`, `total_xp`); herkes okur, yazan yok | — | herkes (authenticated) |
| `child_level(uuid)` | iç (değişti) | Çocuğun grubunun tablosu; yoksa `game_levels` | — | `spend_coins` |
| `weekly_goal_claims` | Tablo | Haftalık hedef ödülü alındı (`child_id`, `week_start` pazartesi, `target`) | fonksiyon | P (aile), O (kendi) |
| `child_goal_settings` | Tablo | Ebeveynin hedef üst sınırı `weekly_cap` (1–200, null = otomatik) | fonksiyon (`set_weekly_goal_cap`) | P (aile) |
| `child_weekly_goal()` / `weekly_goal(p_child_id)` | RPC | `{week_start, target, auto, cap, done, assigned, claimed}`; hedef = son 2 hafta onaylı ortalaması × 1,2 (yukarı), en az 3, en çok bu haftaki görevlerin %90'ı; geçmişsiz çocukta ya da <3 görevde `target` null | — | O / P |
| `set_weekly_goal_cap(p_child_id, p_cap)` | RPC | Ebeveyn hedefi düşürür (null = otomatik) | P | — |
| `claim_weekly_goal()` | RPC | Hedefe ulaşan çocuk haftada bir kez: +2 Güneş Taşı (defter nedeni `goal`, ada ilerlemesine sayılır) + ebeveyne bildirim (`kind = 'weekly_goal'`). Hata: `no_goal`, `not_reached`, `already_claimed` | O | — |

## 12. Hoş geldin coini ve ilk ödül talebi (`migrations/20261024100000_welcome_coins_first_reward.sql`, uygulandı 24 Ekim 2026)

Kullanıcı kararı (24 Ekim 2026). Testler `test_welcome_coins.sql`, `test_reward_first.sql`. Kurallar `ekonomi.md` §1, §2.4; akış `akislar.md` 3.1a, P11 3c; değerler `durumlar.md` §5, P14.

| Ad | Tür | Ne | Yazan | Okuyan |
|---|---|---|---|---|
| `coin_ledger.reason` | Kısıt (değişti) | + `welcome` (hoş geldin coini) | — | — |
| `coin_ledger_welcome_once` | Benzersiz dizin | `(child_id) where reason = 'welcome'`: çocuk başına en çok bir hoş geldin satırı | — | — |
| `claim_welcome_coins()` | RPC (yeni) | `jsonb {ok, coins, balance, error}`. Oturumdaki çocuğa bir kez **+20 coin** (`reason='welcome'`, `ref='welcome'`); sonraki çağrılar yazmaz (`ok=false`, `coins=0`, `error='already_claimed'`). `balance` = `coin_balance` (= `child_me().balance`). Çocuk yoksa `42501` "Bağlantı yok". `anon` çağıramaz; `authenticated` çağırır. | O (ilk beslemede) | — |
| `request_reward(p_reward_id, p_quantity default 1)` | RPC (değişti) | Gövde aynı; yanıta `first` (boolean) eklendi. Çocuğun ilk isteğinde (önceki `source='child'` satırı yokken, durum fark etmez) ebeveyn bildirimi `kind='reward_request'`, `data = {request_id, child_id, first: true}`, başlık "İlk ödül talebi: <ad> bir ödül istiyor". Sonrakilerde `data = {request_id, child_id}`, başlık "<ad> bir ödül istiyor". | O | P (bildirim) |

Bakiye hesapları değişmedi: `coin_balance` bütün satırları toplar (`welcome` dahil); onay geri alma (`completions_coin_trigger`) yalnız `task`/`task_undo` satırlarına bakar.

## 13. Komik eşyalar kataloğu (`migrations/20261024110000_fancy_items_catalog.sql`, uygulandı 24 Ekim 2026)

`ekonomi.md` E9 (24 Ekim 2026). Yeni tablo, sütun ya da fonksiyon yok; yalnız `game_items` satırları (`insert … on conflict (item_id) do update`, tekrar çalıştırılabilir).

| Ad | Tür | Ne | Yazan | Okuyan |
|---|---|---|---|---|
| `game_items` | Veri (19 satır eklenir) | Oyunun 19 komik eşyası (`items.json` `fancy: true`), fiyat ve seviye `items.json`'daki gibi; liste `ekonomi.md` §4.2. Uygulanınca katalog 67 eşya; `spend_coins` bunlar için artık `unknown_item` değil, fiyatı ve seviye kilidini (`level_locked`) sunucudan uygular. | Sunucu (SQL) | Herkes (oturum açmış), `spend_coins` |

Testler: `test_fancy_items.sql` (19 eşyanın fiyat/seviyesi, bağlı çocuğun `hat_bucket` alması, seviye kilidi, fiyatın sunucudan düşülmesi, istemcinin katalogu değiştirememesi), `test_items_catalog.sql` (bekçi: oyun deposu yandayken — `../game-app` ya da `GAME_ITEMS_JSON` — `items.json`'daki her eşya sunucuda aynı fiyat ve seviyede, sunucuda oyunda olmayan eşya yok; dosya yoksa uyarıyla atlanır).

## 14. Beyaz şapka taraması 2 (`migrations/20261025000000_whitehat2.sql`, uygulandı 25 Ekim 2026)

24 Ekim 2026 güvenlik turu (kullanıcı: "kodda ve oyunda güvenlik açıklarını kontrol et, beyaz şapka olarak bir kez daha geç"). Test `test_whitehat2.sql` (bulgu + engellenen ~40 saldırı gerileme testi olarak).

| Ad | Tür | Ne |
|---|---|---|
| W2-1 · `redeem_child_code`, `join_family`, `redeem_clinic_invite_children`, `clinic_join_team` | RPC (değişti) | Başarılı kod kullanımı artık `code_attempts` satırlarını **silmez**. Önce siliyordu; satırlar IP damgasını da taşıdığı için oturum (10), IP (30) ve genel (200) sınırlar birlikte sıfırlanıyordu: kendi ailesine sınırsız kod üretebilen biri her 9 hatalı denemeden sonra kendi koduyla girip sayacı temizleyerek başka ailelerin kodlarını sınırsız deneyebiliyordu. Gövdelerin geri kalanı aynı; eski denemeler `code_throttled` içindeki 1 günlük temizlikle gider, 15 dakikalık pencere kendiliğinden kayar. Gerçek kullanıcı etkilenmez (yalnız hatalı denemeler sayılır). |

Canlıda girişsiz denemeler (24 Ekim 2026, yalnız okuma): 49 tablonun hiçbirinden satır okunamadı, 143 fonksiyonun hepsi `42501` ile reddetti, `mail`/`abc` kovaları listelenemedi. Ayar notu: e-posta doğrulaması kapalı (`mailer_autoconfirm`), anonim giriş açık (çocuk cihazı için gerekli) — doğrulama SMTP ile birlikte açılmalı (`CANLIYA_ALMA.md`).
## 15. Aile davet bağlantısı, geçmiş aktarımı, takip planı (`migrations/20261026100000_family_invite_links.sql`, uygulandı 26 Ekim 2026)

Akışlar: `akislar.md` 10–13. Durum adları: `durumlar.md` P15.

### 15.1 Tablolar
| Tablo | Ne | Alanlar | Okur | Yazar |
|---|---|---|---|---|
| `clinic_invites` (genişledi) | Aile daveti bağlantısı | `token` (32 hex, tekil), `parent_name` (≤ 60), `parent_email`, `channel`, `opened_at`, `claimed_at`, `claimed_family`, `expired_notified_at`, `revoked_at`, `child_name` (≤ 40, uzmanın önerisi), `child_age_group` (`K`/`A`/`B`/`C`; davet bitince ikisi de silinir), `declined_at` | K: yalnız kendi davetleri, sahip hepsi (önceden bütün ekip) | yalnız RPC |
| `clinic_goals` (genişledi) | Hedef: GAS + takip planı | `link_id` artık boş olabilir; `invite_code` (davet taslağı), `domain`, `measure`, `baseline`, `target`, `weeks`, `home_support`, `shared`, `status`, `position`, `template_key`, `updated_at`, `pub` (aileye gönderilen sürüm; yalnız sunucu yazar) | K (paylaşım ya da kendi davet taslağı); **P tabloyu okumaz, yalnız `family_care_plan` (gönderilen sürüm);** eskiden: P yalnız `shared` ve etkin paylaşım**; devralan K okur | K |
| `care_modules` | Aile programı modülü | `link_id` ya da `invite_code`, `title`, `aim`, `practice`, `checklist` (jsonb ≤ 8), `position`, `status`, `template_key`, `created_by`, `pub` (gönderilen sürüm) | K; P tabloyu okumaz (`family_care_plan`); devralan K (işlevle) | K |
| `care_module_logs` | Ebeveynin uygulama kaydı | `module_id`, `family_id` (sunucu), `day`, `practiced`, `difficulty` (1–5), `barrier`, `note` (≤ 300); kişi+gün tekil | P (kendi ailesi); K (yalnız **etkin** paylaşım; devralınan işlevle) | P (yalnız gönderilmiş etkin modüle; gün Türkiye saatiyle, ileri tarih yok, ≤ 14 gün geri) |
| `clinician_verifications` (`20261026050000`, uygulandı) | Uzman belge başvurusu | `clinician_id`, `profession`, `bacb_number`, `file_path` (karar sonrası null), `status`, `auto` (ön kontrol), `barcode`, `reason`, `note`, `summary` (onayda özet; ad/kimlik yok), `submitted_at`, `submitted_name` (gönderimdeki ad; onayda karşılaştırılır), `decided_at/by`, `recheck_at` | yok (yalnız RPC) | `clinician_verification_*`, `admin_verification*` |
| `clinicians` (genişledi) | Rozet | `verified_profession`, `verified_at` (uzman yazamaz; ad değişince düşer) | değişmedi | yönetici kararı |
| `clinic_links` (genişledi) | Paylaşım | `consent_version` (ebeveynin onayladığı paylaşım metni, ör. `uzman-paylasim-v1`), `plan_published_at`; `label` sütunu artık hep boş (not `clinic_link_labels`'ta) | değişmedi | `family_accept_invite` yazar |
| `clinic_link_history` | Geçmiş aktarımı rızası | `link_id` (yeni), `from_link_id` (önceki), `granted_by`, `granted_at`, `consent_version` (onaylanan metin sürümü) | P (kendi) | yalnız RPC |
| `clinic_link_labels` (`20261026300000`, uygulandı 26 Ekim 2026) | Uzmanın paylaşım notu (etiket) | `link_id`, `clinic_id`, `label` (≤ 60) | K (görünür paylaşım); **aile okumaz** | `clinic_links.label` yazımı tetikleyiciyle buraya taşınır |
| `storage_trash` (`20261026300000`, uygulandı 26 Ekim 2026) | Silinecek kova dosyaları | `bucket`, `path` | yalnız service_role (`storage_trash_take/done`) | tetikleyici (`clinician_verifications`) |

`goal_ratings` (GAS puanı) aileye **kapalı** kalır; devralan uzman yalnız `clinic_inherited_records` ile okur (önceki uzman adsız).

### 15.2 Fonksiyonlar
| Fonksiyon | Kim | Ne |
|---|---|---|
| `clinic_create_invite(kind, label, parent_name, parent_email, child_name, child_age_group)` | K | Aile: **3 gün** (72 saat, `20261027000000`, uygulandı 26 Ekim 2026; önce 48 saat), `{code, token, expires_at}`; ekip: 15 dk (imza değişti; eski 2 ve 4 argümanlı çağrılar aynen çalışır). Çocuk önerisi yalnız aile davetinde; yaş grubu `K`/`A`/`B`/`C` |
| `clinic_invite_mark(code, channel, revoke)` | K (davet sahibi / klinik sahibi) | Kanal kaydı ya da iptal (iptal taslak planı siler) |
| `clinic_invites_list(gün)` / `clinic_invite_stats(gün)` | K | Davet listesi + durum / uzman başına gönderilen, açılan, bağlanan, paylaşılan, süresi dolan |
| `clinic_invites_sweep()` | K | Kendi kliniğinin süresi dolan davetleri için `invite_expired` (zamanlayıcı yoksa) |
| `clinic_invites_expire(clinic?)` | yalnız sunucu (pg_cron) | Aynısı, bütün klinikler |
| `clinic_invite_email_take(code, uzman)` / `clinic_invite_email_done(code, ok)` | yalnız service_role (Edge Function `invite-email`) | Sistem e-postası (`20261027000000`, uygulandı 26 Ekim 2026): hak al (davet açık, e-postası var, üyelik etkin; davet başına 3, 60 sn'de bir, uzman başına günde 30 davet) → `{code, token, expires_at, to, clinician, title, clinic}` (çocuk önerisi ve not yok) ya da `{error}`; sonuç `sent`/`failed` (gönderilemeyen sayılmaz). `clinic_invites` + `email_count`, `email_sent_at`, `email_status`; `clinic_invites_list` bu üçünü de döndürür |
| `clinic_invite_open(token)` | yalnız service_role (Edge Function `invite-info`) | Açılış sayfası bilgisi + `opened_at` |
| `claim_clinic_invite(token|kod)` | P | Daveti aileye bağlar (çocuk paylaşılmaz); `{code, clinic_id, clinic, clinician, title, child_name, child_age_group, has_plan}` (uzmanın notu `label` dönmez) |
| `family_pending_invites()` | P | Bağlı, henüz paylaşılmamış davetler (30 gün): `code, clinic, clinician, title, child_name, child_age_group, claimed_at, has_plan` |
| `clinic_invite_preview(token|kod)` | P | Kod ya da anahtar; bağlanmış davet 30 gün |
| `redeem_clinic_invite_children(token|kod, çocuklar, paylaş_geçmiş=false, geçmiş_sürümü=null, plan_çocuğu=null, paylaşım_sürümü=null)` | P | Paylaşım + taslak planın taşınması (yalnız `plan_çocuğu`na, yoksa hepsine) ve aileye gönderilmesi (+ isteğe bağlı geçmiş aktarımı). Çocukların hepsi zaten paylaşılıyorsa hata (davet harcanmaz). Davet akışında `family_accept_invite` tercih edilir |
| `family_accept_invite(token|kod, çocuk jsonb?, çocuklar uuid[]?, paylaş_geçmiş, onay_sürümü, geçmiş_sürümü)` | P | Uzmanın önerdiği çocuğu ebeveynin düzelttiği haliyle oluşturur (`{name, age_group, birthday?, gender?, avatar?, allow_duplicate?}`; yaş grubu → `age_band`: doğum günü varsa boş (otomatik), yoksa önerilen grup K/A/B/C; 26 Ekim denetimi) ve/veya var olan çocukları ekler, paylaşır; `clinic_links.consent_version`. Aynı ad: `{"error":"duplicate_child", child_id, name, message}` (HTTP 200). Düzeltildiyse uzmana `invite_child_updated`. `{link_ids, child_ids, clinic_id}` |
| `clinician_verification_start(meslek, bacb?)` / `clinician_verification_submit(id)` / `clinician_verification_me()` | K | Belge başvurusu: `{id, upload_path}` → Storage `verify` → gönder; durum `{verified_label, verified_at, last: {status, reason, note, …}}` |
| `clinician_verification_autocheck(id, auto, barkod, kesin)` / `clinician_verification_for_check(id, kullanıcı)` | yalnız service_role (Edge Function `clinician-verify`) | Ön kontrol sonucu (başvuru başına bir kez); başka uzmanda onaylı/askıdaki barkod → `duplicate`, bekleyendeki → uyarı; hekim/diğer/BCBA kendiliğinden reddedilmez |
| `storage_trash_take(kova, n)` / `storage_trash_done(idler)` | yalnız service_role | Silinecek belge kuyruğu (karar, kendiliğinden ret, geri çekilme, hesap silme) |
| Aile yanıtlarında `verified_as` | P | `clinic_invite_open`, `claim_clinic_invite`, `clinic_invite_preview`, `family_pending_invites`, `family_clinic_links`: "Klinik psikolog" ya da null |
| `clinic_share_child(klinik, çocuk, onay_sürümü=null)` | P | Aynı uzmana başka çocuk ekler (kod gerekmez); onay metni sürümü kaydedilir (`20261026300000`) |
| `family_decline_invite(token|kod)` | P | "Bu davet bana ait değil" (yalnız daveti kendine bağlamış aile): davet `declined`, öneri + taslak plan silinir, uzmana `invite_declined` |
| `clinic_link_history_set(link, açık, rıza_sürümü=null)` | P | Önceki uzman kayıtlarını bu uzmana aç/kapat; onaylanan metin sürümü kaydedilir |
| `clinic_inherited_records(link)` | K | Devralınan kayıtlar, önceki paylaşım başına: `{n, label: "Önceki uzman n", from, to (ay), notes, suggestions, goals (+ratings), modules (+logs)}`; ad, unvan, klinik ve kimlik yok; metinlerde adlar "[önceki uzman]", e-posta/telefon "[iletişim]"; yalnız bitmiş paylaşımlar, bitiş tarihine kadarki kayıtlar |
| `family_clinic_links()` | P | + `history_shared`, `history_available` (yalnız bitmiş önceki paylaşım varsa) |
| `care_plan_publish(link)` | K | Planın o anki hâlini aileye gönderir (`pub`); boş plan hata; ebeveynlere `care_plan_shared` (10 dakikada en çok bir) |
| `family_care_plan(link)` | P | Gönderilmiş hedefler + etkin/tamamlanan modüller + bu hafta (Türkiye günü) uygulanan gün sayısı |
| `handle_new_user` | tetikleyici | Ebeveyn kaydında meta `clinic_invite` (anahtar/kod) ile daveti bağlar; hata kaydı engellemez |
| `handle_user_email_confirmed` | tetikleyici (auth.users `email_confirmed_at`) | E-posta doğrulanınca (kayıttan ≥ 1 dk sonra) davetteki e-postayla eşleşen açık daveti bağlar |

Edge Function `invite-info` (Verify JWT kapalı): `GET ?t=<token>` → `{status, clinic, clinician, title, code?, expires_at}`. Açılış sayfası: `web/davet/index.html` (+ `apple-app-site-association.example.json`).

## 16. Uzman karşılama anketi (`migrations/20261027100000_clinician_survey.sql`, uygulandı 27 Ekim 2026; akış `akislar.md` 15)

| Tablo | Ne | Alanlar | Kim yazar | Kim okur |
|---|---|---|---|---|
| `clinician_surveys` | Uzmanın kayıt sonrası anket cevabı (uzman başına bir satır) | `clinician_id` (pk, uzman silinince silinir), `profession`, `challenges text[]`, `features text[]`, `intent`, `skipped`, `version`, `created_at`, `updated_at` | yalnız RPC | yalnız RPC (RLS açık, doğrudan erişim yok) |

| Fonksiyon | Kim | Ne |
|---|---|---|
| `clinician_survey_me()` | K | Kendi cevabı `{profession, challenges, features, intent, skipped, version, updated_at}` ya da null (anket gösterilir) |
| `clinician_survey_save(meslek, zorluklar[], özellikler[], neden, geçti=false)` | K | Kaydet/güncelle; bilinmeyen anahtar reddedilir, tekrarlar tekilleşir |
| `clinician_survey_keys(tür)` | K | Geçerli anahtarlar (`profession`, `challenges`, `features`, `intent`); `veri/uzman_anketi.json` ile aynı |
| `admin_kpi_clinician_survey(gün)` | yönetim paneli (`admin_require`, 2 adımlı) | Toplam sayılar: cevaplayan, geçen, seçenek başına sayı; kişi kimliği dönmez |

## 17. ParentApp ilk kurulum ve tanışma soruları (`migrations/20261027120000_parent_setup_intake.sql`, uygulandı 27 Ekim 2026)

| Tablo / alan | Kim okur | Kim yazar | Not |
|---|---|---|---|
| `intake_answers` (`family_id`, `user_id`, `child_id?`, `question_key`, `answer` jsonb dizi, `version`, `consent_version?`) | aile üyeleri | yalnız yanıtlayan (kendi satırı; aile/kişi kimliği sunucudan) | Kişi + çocuk + soru başına tek satır (`unique nulls not distinct`), upsert `onConflict: user_id,child_id,question_key`. Çocuk aileye ait olmalı; seçenekler `^[a-z0-9_]{1,40}$`; sağlık sorularında rıza sürümü (durumlar.md P16). Uzman erişimi yok. |
| `profiles.setup_completed_at` | aile | `parent_setup_complete()` | İlk kurulum bitti mi; göçten önceki ebeveynler dolu. İstemci doğrudan yazamaz (sütun izni yok). |

| Fonksiyon | Kim | Ne yapar |
|---|---|---|
| `parent_setup_complete()` | ebeveyn | Kurulumu bitti olarak işaretler (bir kez) |
| `admin_intake(aile, gerekçe)` | admin support/owner (2FA) | Kişi bazlı yanıtlar (üye adı/takma adı, çocuk adı, soru, yanıt, sürüm); her açılış `admin_audit` (`intake.view`) |
| `admin_intake_summary(gün=90)` | her admin rolü | Soru × seçenek başına yanıt ve aile sayısı; kimlik yok, sağlık soruları (`child_diagnosis`, `child_medication`) hariç (hukuk_notlari I4) |

## 18. Yasal metinler, onay kaydı, KVKK başvuruları (`migrations/20261027200000_legal.sql` + `20261027210000_legal_seed.sql`, uygulandı 27 Ekim 2026; Edge Function `legal` yayında; metinler `hukuk/`)

| Tablo | Ne | Erişim |
|---|---|---|
| `legal_documents` | `key` + `version` (pk), başlık, `apps` (parent/child/clinic/web), `requires_acceptance`, `summary` (yeniden onayda "ne değişti"), `body_md`, `status` draft/published/retired | Tablo kapalı; uygulamalar RPC, herkese açık okuma Edge Function `legal`. Yayındaki metin değişmez (tetikleyici) |
| `legal_acceptances` | kullanıcı × metin × sürüm, `app`, zaman | kendi satırını okur; yazma `legal_accept` |
| `kvkk_requests` | başvuru: kullanıcı (silinse null), yanıt e-postası, app, kanal, tür, açıklama, durum, alınış, `due_at` (+30 gün), iç not | kendi başvurusunun iç not dışı alanlarını okur; yazma RPC |

| RPC | Kim | Ne |
|---|---|---|
| `legal_documents_for(app)` | authenticated | Uygulamanın güncel metinleri (yayındaki; yoksa en yeni taslak) + kullanıcının onay zamanı |
| `legal_pending(app)` | authenticated | Güncel sürümü onaylanmamış, onay isteyen metinler (kayıt sonrası ve açılışta) |
| `legal_accept(app, [{key, version}])` | authenticated | Yalnız o uygulamanın güncel, onay isteyen sürümleri; `app='child'` yalnız veli (ParentApp) çağırır. Dönüş: kalan bekleyenler |
| `kvkk_request_create(app, tür, açıklama)` / `my_kvkk_requests()` | authenticated | Başvuru (en çok 5 açık; düzeltme/itiraz/zarar/diğer açıklama ister) ve listesi |
| Edge Function `legal` | herkes (Verify JWT kapalı) | `GET ?doc=<anahtar>[&v=<sürüm>][&format=json]` HTML/JSON; `GET` liste. Supabase alan adında HTML düz metin gider: secret `LEGAL_PUBLIC_URL` tanımlıysa tarayıcı isteği `<LEGAL_PUBLIC_URL>/yasal/<anahtar>[?v=]` sayfasına 302 ile yönlenir (yönetim paneli Worker'ı, `admin-panel/worker/`); JSON isteği yönlenmez |

## 19. Ebeveyn görevleri ve hediye dükkânı (`migrations/20261027140000_parent_tasks_gifts.sql`, uygulandı 27 Ekim 2026; akış `akislar.md` 18)

| Tablo | Ne | Alanlar | Kim yazar | Kim okur |
|---|---|---|---|---|
| `parent_assignments` | Görevin ebeveyn ataması | pk (`task_id`, `user_id`), `family_id`, `difficulty` (easy/medium/hard) | P (aile; tetikleyici: görev ve kişi aynı aileden, kimlik alanları değişmez) | P (aile) |
| `parent_completions` | Ebeveynin "Yaptım" işareti | pk (`task_id`, `user_id`, `date`), `family_id`, `done_at` | yalnız `parent_task_done` | P (aile) |
| `parent_stone_ledger` | Ebeveynin taş defteri; bakiye = toplam (en az 0) | `user_id`, `family_id`, `amount` (≠ 0), `reason` (`task`/`task_undo`/`gift`), `ref` (görev\|gün:zaman ya da hediye kimliği), `item_id?`, `child_id?`; unique (`user_id`, `reason`, `ref`) | yalnız işlevler | P (aile) |
| `gift_items` | Hediye dükkânı (oyunun kalıcı eşyaları) | `item_id` (→ `game_items`), `stones` (= ceil(coin / 10)), `sort` | göç | herkes (giriş yapmış) |
| `child_gifts` | Gönderilen hediye | `id`, `family_id`, `child_id`, `item_id`, `from_user`, `from_name` (gönderenin takma adı), `note?` (≤ 140), `stones`, `created_at`, `claimed_at?` | yalnız `send_gift` / `claim_child_gift` | P (aile), O (kendi) |

| Fonksiyon | Kim | Ne |
|---|---|---|
| `parent_task_done(görev, gün, yapıldı=true)` → yeni bakiye | P | Kendi atamasını işaretler / geri alır; gün bugün − 7 … + 1 (hint `date_range`), görev o gün olmalı (`not_on_date`), atanmış olmalı (`not_assigned`) |
| `send_gift(çocuk, eşya, not)` → `{ok, balance, gift_id, error}` | P | `error`: `unknown_item` / `not_enough_stones`; başarıda taş düşer, çocuğa `gift` bildirimi |
| `child_gifts_pending()` → (id, item_id, from_name, note, created_at, from_avatar) | O | Kapatılmamış hediyeler, eskiden yeniye; `from_avatar` gönderenin bugünkü avatarı (öneri `20261027220000_parent_avatar_game`; hesabı silinmişse null) |
| `claim_child_gift(id)` → boolean | O | İlk çağrı true (kapatır), sonrakiler false |

## 20. Misafir kartı: bir aileye 30 gün hediye (öneri `proposed/20261028120000_guest_pass.sql`, **uygulanmadı**; akış `akislar.md` 19)

| Tablo / alan | Ne | Alanlar | Kim yazar | Kim okur |
|---|---|---|---|---|
| `families.trial_days` | Ailenin kendi deneme süresi (gün, 1–90); boşsa `app_config.billing.trial_days` (7) | smallint | yalnız `redeem_guest_pass` (30) | `family_access_of` |
| `guest_passes` | Ailenin hediye ettiği kart | `code` pk (`^[A-Z2-9]{8}$`), `family_id`, `created_by`, `created_at`, `expires_at` (+60 gün), `redeemed_family?`, `redeemed_at?` | yalnız `create_guest_pass` / `redeem_guest_pass` (istemci yazamaz) | P (kendi ailesinin kartları; RLS) |

| Fonksiyon | Kim | Ne |
|---|---|---|
| `create_guest_pass()` → `{code, expires_at, new}` | P | Ailenin kullanılmamış, süresi dolmamış kartı varsa aynısı (paylaşılan kod değişmesin); yoksa yeni. Aile başına en çok 20 kart (hint `limit`) |
| `redeem_guest_pass(kod)` → `{ok, trial_ends_at}` ya da `{ok:false, error}` | P | Kod denemesi ortak sınırda (`code_throttled`; hatalı kod `code_attempts`'e yazılır). `error`: `not_found` / `used` / `expired` / `own` (kendi ailesinin kartı) / `already` (aile daha önce kart kullandı) / `premium` (abone) / `not_new` (deneme başlayalı 7 günden fazla) / `too_many_attempts`. Başarıda `trial_days = 30`, deneme başlamadıysa bugün başlar; kartın sahibi ailenin ebeveynlerine `guest_pass_used` bildirimi (kullananın kimliği yok) |
| `family_access_of(aile)` (değişti) | — | Deneme sonu `trial_started_at + coalesce(trial_days, ayar)`; dönüşe `trial_days` ve `guest_pass` (aile kart kullandı mı) eklendi. Diğer kurallar aynı |

Telefon numarası (ParentApp "Uzman bağla" sonrası, bayrak `parent_sms_verify`; `akislar.md` 19): yeni tablo yok. Numara Supabase Auth'un kendi akışıyla (`auth.updateUser({phone})` → SMS kodu → `verifyOtp(type: 'phone_change')`) `auth.users.phone`'a yazılır; uzmana ve öteki ebeveyne gösterilmez. SMS sağlayıcısı Supabase → Authentication → Sign In / Providers → Phone'da tanımlanınca çalışır (ücretli).

