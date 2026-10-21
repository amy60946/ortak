# Ekonomi sözleşmesi (coin, fiyat, XP, seviye, göstergeler)

Bu dosyadaki sayılar iki ya da daha fazla uygulamanın **aynı** kabul etmesi gereken değerlerdir. Değişiklik önce burada ve SQL'de
yapılır, sonra oyun verisi (`Resources/Data/*.json`) ve ParentApp güncellenir.

Kaynak:
- `game-app/supabase/proposed/20261015000000_pofi_game.sql` (uygulandı: `coin_ledger`, `completions_coin_trigger`, `spend_coins`, `game_items`)
- `parent-app/supabase/migrations/20261013000000_init.sql` (`task_assignments.coins`)
- `parent-app/src/theme.ts` (`difficultyMeta`), `src/screens/TaskDetailsScreen.tsx`, `src/screens/CreateTaskScreen.tsx`, `src/store.tsx`
- `game-app/Assets/_Pofi/Scripts/Logic/Economy/Wallet.cs`, `Economy/XpSystem.cs`, `Progression/Progression.cs`, `Pet/PetStats.cs`, `Pet/PetCare.cs`, `Profile/AgeBand.cs`, `Shop/ShopRules.cs`, `State/SyncCoordinator.cs`, `App/StarterKit.cs`, `App/TestAccess.cs`, `App/DemoParent.cs`, `Services/Mock/MockBackend.cs`, `MiniGames/MiniGames.cs`, `MiniGames/Expeditions.cs`, `Cards/CardGameFramework.cs`, `Fishing/Fishing.cs`, `Garden/Garden.cs`, `Island/Gathering.cs`, `Island/Events.cs`
- `game-app/Assets/_Pofi/Scripts/Runtime/Core/GameBootstrap.cs`, `Runtime/Screens/MapScreen.cs`, `Runtime/Screens/ShopScreen.cs`
- `game-app/Assets/_Pofi/Resources/Data/items.json`, `levels.json`, `start.json`, `daily_quests.json`, `badges.json`
- `game-app/docs/PLAN.md` (§3, §6 taslak sayılar), `M4_SUNUCU_ONERISI.md`

Son güncelleme: 2026-10-19

---

## 1. Temel ilkeler

| İlke | Nerede uygulanıyor |
|---|---|
| Coin **yalnızca gerçek görevden**, **yalnızca ebeveyn onayıyla** gelir. Oyun içi etkinlik coin vermez. | Tetikleyici `completions_coin` (SQL); `Wallet` istemcide coin ekleyemez; `StarterKit` coin vermez; bahçe hasadı yiyecek verir, coin değil. |
| Bakiye her zaman **sunucunun** bakiyesidir; çakışmada sunucu kazanır. | `Wallet.ServerCoins`, `ApplyServerSnapshot`; `child_me().balance`. |
| Fiyatı **sunucu** belirler; istemcideki fiyat yalnız gösterim içindir. | `spend_coins` fiyatı `game_items`'tan okur; `ShopRules` yorumu. |
| XP yalnız oyun içi etkinliklerden gelir; **coin ile alınamaz**. XP ve seviye yalnız oyunda (cihaz + `game_saves` yedeği) tutulur; sunucuda XP sütunu yoktur. | `XpSystem`, `LevelTable`. |
| Pet asla ölmez/hastalanmaz; göstergeler bir tabanın altına inmez. | `PetStats.Tick`. |

---

## 2. Coin kazanma (gerçek görev)

### 2.1 Görev ödülü (`task_assignments.coins`)
| Zorluk | ParentApp varsayılanı | Değiştirilebilir mi? |
|---|---|---|
| `easy` (Kolay) | **5** | Evet, ebeveyn her çocuk için elle yazar |
| `medium` (Orta) | **10** | Evet |
| `hard` (Zor) | **20** | Evet |

- Sınır: **0–50** (`20261019100000_task_rewards.sql`, 19 Ekim 2026'da uygulandı). ParentApp girişi yalnız rakam kabul eder ve 0–50'ye sıkıştırır. Var olan 50 üstü satırlara dokunulmaz (kısıt `not valid`).
- Coin **görev başına değil, atama (görev × çocuk) başına** tutulur; aynı görev iki çocuğa farklı ödülle atanabilir.
- `coins = 0` ise onayda deftere satır yazılmaz.
- Sahte arka uç (yalnız oyun önizlemesi, `MockBackend.ParentAssign`) ödülü **1–50** aralığına sıkıştırır; demo görevler 5 / 10 / 10 / 5 / 20 coin (`DemoParent.Samples`). Üst sınır gerçek sunucuyla aynı (50).

### 2.2 Ne zaman yazılır (tetikleyici `completions_coin`)
| Olay (`completions`) | Defter satırı |
|---|---|
| `status` `approved` olur (INSERT ya da UPDATE) | `+coins`, `reason='task'` |
| `status` `approved`'dan başka bir değere geçer (ör. `rejected`, `pending`) | `−verilen`, `reason='task_undo'` |
| `approved` kayıt silinir (görev ve atama duruyor) | `−verilen`, `reason='task_undo'` |
| Görev ya da atama silinir (silme zinciri) | yazılmaz: kazanılmış coin çocukta kalır |
| Diğer geçişler (`pending`↔`declined` vb.) | yazılmaz |

- Onayda tutar **o anki** `task_assignments.coins`'tir. Geri almada "verilen" = o tamamlama için defterde kalan net tutar (`task` − `task_undo`); onaydan sonra ödül değişse de verilen kadar düşülür. (Karar ve uygulama 19 Ekim 2026, `20261019100000_task_rewards.sql`.)
- Geri alma, çocuk coini harcadıysa bakiyeyi eksiye düşürebilir (bilinçli: onay geri alınınca hak edilmemiş coin geri gelir).
- ParentApp onayı ve reddi **ikisi de** `review_completion` ile yapar.
- `ref = '<completion_id>:<epoch>'`; `unique (child_id, reason, ref)`.
- İnceleme gerektirmeyen görevde (`requires_review = false`) çocuğun "Yaptım"ı doğrudan `approved` yazılır → coin hemen gelir.

### 2.3 Oyunda kazancın görünmesi
- Oyun senkronunda (`SyncCoordinator`): görevler çekilir → `child_me().balance` alınır → `Wallet.ApplyServerSnapshot` artışı "kazanılan coin" olarak kutlar.
- Senkron sırası: (1) bekleyen görev niyetleri → (2) bekleyen harcamalar → (3) görevler (dün … +7 gün) → (4) bakiye → (5) kayıt yedeği.

---

## 3. Coin harcama (`spend_coins`)

| Kural | Değer |
|---|---|
| İşlem kimliği `p_tx` | 8–64 karakter; oyun `Guid.NewGuid().ToString("N")` (32 karakter) üretir |
| Tekrar gönderim | Aynı `p_tx` ikinci kez düşülmez (`ok=true`, güncel bakiye) |
| Adet `p_quantity` | 1–20 (sunucu). Oyun dükkânı bugün hep **1** adet alır (`ShopScreen`) |
| Fiyat | `game_items.price × p_quantity` |
| Bakiye yetmezse | `ok=false`, `error='not_enough_coins'`, düşülmez |
| Bilinmeyen eşya / geçersiz adet | `ok=false`, `error='unknown_item'` |
| Eksi bakiye | Olamaz (aynı çocuğun harcamaları `for update` ile sıraya girer) |
| Seviye kilidi (`min_level`) | Oyunda `ShopRules`; sunucuda `spend_coins` → `level_locked` (`20261019020000_server_rules` (uygulandı); seviye = `child_level`: kayıttaki `Xp.TotalXp` + `game_levels`). `game_levels` eşikleri `levels.json` ile aynı tutulur. |

İstemci akışı (`Wallet`): harcama önce yerelde "bekleyen" olarak düşülür (`Available = ServerCoins − bekleyenler`), sunucu kabul edince kesinleşir; reddederse eşya envanterden geri alınır. Ağ hatası (HTTP 0 / 5xx) → kuyrukta kalır, tekrar denenir.

---

## 4. Dükkân fiyatları (`game_items` = `items.json`)

48 eşya; sunucu (`game_items`) ve oyun verisi (`items.json`) 2026-10-19'da karşılaştırıldı: **fiyat ve seviye birebir aynı**.
Etkiler (gösterge artışı) yalnız oyun verisindedir.

### 4.1 Tüketilenler (yiyecek, temizlik, tohum)
| item_id | Ad (oyun) | Fiyat | Seviye | Etki |
|---|---|---|---|---|
| `food_apple` | Elma | 3 | 1 | tokluk +20 |
| `food_coconut` | Hindistan cevizi | 4 | 1 | tokluk +25, mutluluk +3 |
| `food_bread` | | 3 | 1 | tokluk +22 |
| `food_watermelon` | | 5 | 2 | tokluk +28, mutluluk +5 |
| `food_carrot` | | 3 | 2 | tokluk +20 |
| `food_fish` | | 6 | 3 | tokluk +35 |
| `food_icecream` | | 6 | 4 | tokluk +15, mutluluk +15 |
| `food_corn` | | 4 | 6 | tokluk +26 |
| `food_tomato` | | 3 | 6 | tokluk +18 |
| `clean_soap` | | 3 | 1 | temizlik +40 |
| `clean_bubble_bath` | | 8 | 4 | temizlik +70, mutluluk +8 |
| `seed_carrot` | | 2 | 6 | → `food_carrot`, 30 dk |
| `seed_corn` | | 2 | 6 | → `food_corn`, 60 dk |
| `seed_tomato` | | 2 | 6 | → `food_tomato`, 45 dk |
| `seed_watermelon` | | 3 | 7 | → `food_watermelon`, 120 dk |

### 4.2 Kalıcı eşyalar
| Grup | item_id — fiyat (seviye) |
|---|---|
| Gözlük | `glasses_round` 15 (1), `glasses_sun` 20 (2), `glasses_star` 25 (5) |
| Kıyafet | `shirt_stripes` 25 (2), `shirt_hawaii` 35 (2), `apron_sailor` 30 (2), `hoodie_soft` 45 (4), `vest_explorer` 50 (7), `raincoat` 60 (8) |
| Şapka / baş | `hat_cap` 20 (3), `hat_straw` 25 (3), `hat_beanie` 22 (3), `hat_crown` 40 (5), `headphones` 35 (4) |
| Aksesuar | `scarf_knit` 18 (2), `backpack_small` 30 (3), `cape_hero` 45 (5), `badge_patch` 12 (2), `sash_belt` 15 (3), `glove_mitten` 15 (4), `hand_flag` 10 (2) |
| Ev eşyası (etki: ev göstergesi, ilk yerleştirmede bir kez) | `home_bed` 60 (4) ev +25 · `home_rug` 40 (4) ev +15 · `home_lamp` 45 (4) ev +15 · `home_bookshelf` 80 (6) ev +20 · `home_aquarium` 100 (8) ev +30, mutluluk +5 |
| Süs | `decor_umbrella` 35 (3), `decor_sandcastle` 25 (2), `decor_palm` 50 (5), `decor_lanterns` 70 (12) |
| Özel setler | `set_captain` 180 (9), `set_captain_hat` 70 (9), `set_star_cape` 150 (14) |

### 4.3 Coin dışı başlangıç / test
| Ne | Değer | Not |
|---|---|---|
| Hoş geldin hediyesi (`start.json`) | `food_apple` ×3, `clean_soap` ×2 | Pet ilk adlandırılınca bir kez; **coin yok**; yalnız oyun envanterine (sunucuya yazılmaz). |
| Test erişimi (`TestAccess`) | 5000 coin, tüketilenlerden 20'şer, en üst seviye | **Yalnız sahte arka uç** (önizleme). Gerçek hesapta yok. |

---

## 5. XP ve günlük sınır (yalnız oyun)

### 5.1 Yaş bandına göre ayarlar (`AgeBandProfile.For`)

> 19 Ekim kararı: bantlar A 6–8 / B 9–12; C kaldırıldı (`durumlar.md` 4). A/B ayarlarının yeni yaş aralıklarına göre yeniden ayarlanması oyun penceresinin işidir; değerler değişirse önce burası güncellenir.

| Bant | Günlük XP sınırı | Tema | Ses hep açık | Ses varsayılan | Altyazı varsayılan | Mini oyun zorluğu | Düğme ölçeği |
|---|---|---|---|---|---|---|---|
| A | **250** | `rounded_icons` | evet | açık | açık | 0.3 | 1.25 |
| B | **300** | `balanced` | hayır | açık | açık | 0.6 | 1.0 |
| ~~C~~ | ~~350~~ | ~~`compact`~~ | | | | ~~0.85~~ | ~~0.9~~ |

- Gün, cihazın **yerel** tarihine göre döner.
- Sınıra **sayılan** kaynaklar: `MiniGame`, `CardGame`, `Fishing`, `Garden`, `DailyQuest`. **Sayılmayan**: `TaskStreak` (gerçek görev serisi), `Achievement` (rozet, keşif, etkinlik, kulübe vb.).

### 5.2 XP kaynakları (koddaki sayılar)
| Kaynak | XP | Sınıra sayılır mı |
|---|---|---|
| **Gerçek görev onayı** (Ö2, `RealTaskRewards.Xp`; karar 19 Ekim) | Zorluğa göre (`task_assignments.difficulty`): kolay **20**, orta **35**, zor **50**. Her onaylı görev örneği bir kez. | Hayır |
| Gerçek görev serisi (`TaskStreak.Bonus`): art arda günlerde en az bir **onaylı** görev | 1. gün 10, her gün +5, 7. günden sonra **40**'ta sabit (10, 15, 20, 25, 30, 35, 40). Aynı gün ikinci onay bonus vermez; seri kırılırsa 1'den başlar, ceza yok. | Hayır |
| Mini oyun (`MiniGameXp.For`) | `min(40, 5 + skor × puanBaşı)`; hindistan cevizi puanBaşı 1, mağara 2 | Evet |
| "Pet'e yardım" mini oyunu | `max(10, 25 − 2 × deneme)` | Evet |
| Dağ yürüyüşü | `min(40, 10 + round(25 × toplanan / en iyi))` | Evet |
| Masa oyunları (`CardRewards.Xp`) | Kazanınca `round(20 + 20 × zorluk)`, kaybedince 8 | Evet |
| Balık (`Fishing.Xp`) | `5 × nadirlik + (yeni tür ise 10)` (Runtime'da çağrısı bulunamadı — doğrulanmalı) | Evet (`Fishing`) |
| Günlük oyun içi görevler (`daily_quests.json`, günde 3) | 10–20 (ör. `dq_feed_2` 15, `dq_wash_1` 10, `dq_coconut_10` 20, `dq_fish_2` 20) | Evet |
| Rozetler (`badges.json`) | 20–100 (ör. `badge_first_task` 20, `badge_task_10` 40, `badge_streak_7` 60, `badge_master` 100) | Hayır |
| Adada parıltı keşfi (`MapScreen`) | yeni 10, tekrar 3 | Hayır |
| Kulübe yapma (`Gathering.HutXp`) | 40 (tarif: 6 odun, 4 dal, 3 taş) | Hayır |
| Festival / final etkinliği (`Events`) | 25 / 100 | Hayır |

Not: Rozetlerden `badge_first_task` ve `badge_task_10` gerçek görev onayına (`tasks_approved` sayacı) bağlıdır; yani ParentApp onayı oyunda XP'yi de dolaylı etkiler.

---

## 5A. Güneş Taşı (Ö1; `20261019030000_sun_stones` (uygulandı), karar 19 Ekim 2026)

- **Yalnız ebeveyn onayıyla** gelir (oyun içi hiçbir eylem taş vermez). Zorluğa göre: kolay **1**, orta **2**, zor **3** (`stones_for_difficulty`). Coin'i 0 olan görev de taş verir.
- Sunucu: `sun_stone_ledger` (nedenler `task` / `task_undo` / `adjust`), yalnız tetikleyici `completions_sun_stone` yazar. Onay geri alınırsa o tamamlamanın verdiği taş düşer. Toplam `child_me().sun_stones` (en az 0).
- **Taş harcanmaz, adaya yerleştirilir**: onarım noktaları (sis, köprü, iskele, fener) oyun verisindedir (`Resources/Data/sun_spots.json`); yerleştirme oyun kaydında tutulur. Yerleştirilebilir = kazanılan toplam − yerleştirilen (en az 0). Onay geri alınıp toplam düşerse yerleştirilmiş taş geri alınmaz (ceza yok); yeni taşlar önce aradaki farkı kapatır.
- ParentApp taş toplamını defterden (RLS: aile okur) gösterebilir.

## 5B. Beceriler (Ö2; karar 19 Ekim 2026)

Görev becerisi `tasks.skill` serbest metindir (ParentApp şablon etiketi). Oyun ve raporlar aşağıdaki **tek sözlüğe** eşler (`SkillCatalog`); eşleşmeyen (`Özel`, boş) beceri yıldızı vermez, yalnız XP/taş verir.

| Anahtar | Ad (Türkçe) | Eşlenen etiketler (bugünkü ParentApp şablonları dahil) |
|---|---|---|
| `focus` | Odak | Odak, Odaklanma |
| `kindness` | Nezaket | Nezaket, Empati, Minnettarlık |
| `responsibility` | Sorumluluk | Sorumluluk, Takım Çalışması |
| `independence` | Bağımsızlık | Bağımsızlık |
| `calm` | Sakinlik | Sakinlik, Sakinleşme |
| `self_care` | Öz Bakım | Öz Bakım |

- Her onaylı görev örneği becerisine **1 yıldız** ekler (oyun kaydında). Kademe: 5 yıldız bronz, 15 gümüş, 30 altın.
- Öneri (ParentApp penceresi): şablon etiketlerini zamanla bu altı ada çekmek; eşleme tablosu o zamana kadar geriye uyum sağlar.

## 5C. Gerçek ödüller (Ö7; öneri `20261022100000_reward_shop`, 22 Ekim 2026)

- Ebeveyn ödülü ve fiyatını koyar (1–500 coin). Coin, **ebeveyn ödülü verdiğinde** düşer (`coin_ledger.reason = 'reward'`), istek anında değil.
- Bekleyen isteklerin toplamı çocuğun **kullanılabilir coin**'inden ayrılır: `available = bakiye − bekleyenler`. Yeni istek `available ≥ fiyat` ister.
  Oyun dükkânı (`spend_coins`) ayrılmış coin'i bilmez; çocuk bu arada eşya alırsa ebeveyn "ver" dediğinde bakiye yetmeyebilir → `not_enough_coins`, istek bekler, coin eksiye düşmez.
  Oyun arayüzü bu yüzden eşya dükkânında "ödüle ayrılmış" coin'i ayrıca gösterir.
- Önerilen fiyat aralığı (ParentApp'te ipucu, kural değil): küçük ödül 10–30, orta 40–80, büyük 100–200 coin. Günlük görev başına ödül ≤ 50 olduğundan büyük ödül birkaç günlük birikim ister.
- "Önce rutin, sonra oyun" (mini oyunlar sabah rutini bitince açılır) Ö7'nin isteğe bağlı ayarıdır; bu öneriye dahil değil, ayrıca karara bağlanacak.

## 6. Seviye tablosu (`levels.json`, yalnız oyun)

En fazla seviye **15**. Büyüme evresi: Yavru Sv1, Genç **Sv5**, Yetişkin **Sv10**.

| Seviye | Bu seviyeye toplam XP | Sonrakine gereken |
|---|---|---|
| 1 | 0 | 100 |
| 2 | 100 | 135 |
| 3 | 235 | 182 |
| 4 | 417 | 246 |
| 5 | 663 | 332 |
| 6 | 995 | 448 |
| 7 | 1443 | 605 |
| 8 | 2048 | 817 |
| 9 | 2865 | 1103 |
| 10 | 3968 | 1489 |
| 11 | 5457 | 2010 |
| 12 | 7467 | 2714 |
| 13 | 10181 | 3664 |
| 14 | 13845 | 4946 |
| 15 | 18791 | — |

Seviyeyle açılanlar (özet; tam liste `levels.json` → `unlocks`): Sv1 ev, dükkân (temel yiyecek, sabun, gözlük), görev panosu, hindistan cevizi ve "pet'e yardım" oyunları · Sv2 yüzme koyu, kıyafet · Sv3 sörf, şapkalar, oyun kulübesi, renk eşleştirme · Sv4 domino, ev süsleme · Sv5 kayak tepesi, kule, Genç evre · Sv6 bahçe, tohumlar · Sv7 iskele, balık tutma · Sv8 koleksiyon kitabı, günlük etkinlik panosu · Sv9 özel setler · Sv10 Yetişkin evre, ev genişletme · Sv11 mağara · Sv12 festival · Sv13 dağ yürüyüşü · Sv14 özel pet seti · Sv15 deniz feneri, usta rozeti, final kutlaması.

Bahçe tarlası: Sv6'da 3, her iki seviyede +1, en fazla 6 (`Garden.PlotCountFor`).

---

## 7. Pet göstergeleri (yalnız oyun)

Dört gösterge (0–100): tokluk (`fullness`), temizlik (`cleanliness`), mutluluk (`happiness`), ev (`home`). Başlangıç her biri **80**.

| Ayar (`StatDecayConfig.Default`) | Değer |
|---|---|
| Saatte düşüş | **4** puan |
| Taban (altına inmez) | **10** |
| Bir takvim gününde en fazla düşüş (gösterge başına) | **60** puan (gün UTC'ye göre döner) |
| Üzgün eşiği | **30**'un altı |
| Saat geri alınırsa | Düşüş uygulanmaz |

| Eylem (`PetCare`) | Etki |
|---|---|
| Besle | Yiyeceğin etkisi (4.1). Tokluk ≥ **95** ise "zaten tok". |
| Yıka | Temizlik ürününün etkisi (4.1). |
| Oyna | Mutluluk +**12** |
| Evi düzenle | Ev +**10** |
| Ev eşyası yerleştir | Eşyanın etkisi, ilk yerleştirmede bir kez |
| Gece döngüsü | **Kapalı** (`NightCycle = false`); açılırsa 21:00–07:00 pet uyur |

Not: `PLAN.md` gösterge düşüşünde sunucu saatinin referans alınacağını yazar; kodda düşüş cihaz UTC saatiyle hesaplanır (doğrulanmalı).

---

## 8. Tutarsızlıklar ve açık noktalar

| # | Konu | Ayrıntı |
|---|---|---|
| E1 | ~~Görev ödülü üst sınırı~~ | **Karar (19 Ekim):** 0–50. SQL kısıtı uygulandı, ParentApp girişi sıkıştırıyor. |
| E2 | Sıfır fiyat | SQL `price >= 0` izin verir; oyun `Wallet.TrySpend` `unitPrice <= 0`'ı reddeder ve `GameData.Validate` "fiyat pozitif olmalı" der. Bugün 0 fiyatlı eşya yok. **Karar: fiyat > 0** (`game_items_price_positive`). |
| E3 | Adet sınırı | Sunucu 1–20; oyun `Wallet` yalnız `> 0` denetler. Bugün dükkân hep 1 alır. **Karar: oyun da 1–20 denetler** (`Wallet.TrySpend`). |
| E4 | `min_level` | Sunucuda tutulur ama `spend_coins` denetlemez; seviye yalnız oyunda bilinir. **Karar: sunucu denetler** — seviye, oyun kaydındaki `Xp.TotalXp` ve `game_levels` eşiklerinden (`child_level`); hata `level_locked`. Oyun harcamadan önce kaydı yedekler. |
| E5 | Plan adları eski | `PLAN.md` §3 `child_game_state`, `shop_prices`, `sync_game_state`, `game_config` adlarını kullanır; uygulanan SQL'de bunların yerine `game_saves`, `game_items`, `game_save_get/put` var; `game_config` (uzaktan XP sınırı/fiyat ayarı) **yok**. |
| E6 | ~~Onay sonrası ödül değişimi~~ | **Karar (19 Ekim):** geri alma verilen kadar düşer; görev/atama silinince coin kalır (bkz. 2.2). Uygulandı. |
| E7 | Bakiye ParentApp'te | ParentApp bakiyeyi `child_balance` ile okur; defter satırlarını (geçmiş) bugün göstermiyor (doğrulanmalı). |
| E8 | Klinik paylaşımı | Coin defteri uzmanla **paylaşılmaz** (klinik göçü, uygulandı). |
