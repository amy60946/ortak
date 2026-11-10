# Uygulamalar arası akışlar

Her adımda **hangi uygulamanın** ne yaptığı ve hangi tablo/fonksiyonun kullanıldığı yazılıdır.
Uygulamalar birbirleriyle doğrudan konuşmaz; her şey ortak Supabase veritabanı üzerinden olur.

Simgeler: **[P]** ParentApp (ebeveyn) · **[O]** Oyun (GameApp, çocuk) · **[K]** ClinicApp (uzman) · **[S]** Sunucu (Supabase fonksiyonu/tetikleyicisi)

Kaynak:
- `parent-app/supabase/migrations/20261013000000_init.sql`, `20261014000000_task_repeat_order.sql`
- `game-app/supabase/proposed/20261015000000_pofi_game.sql` (uygulandı)
- `ortak/supabase/migrations/20261019000000_clinic.sql` (uygulandı); `parent-app`, `src/lib/clinic.ts`, `src/components/ClinicShare.tsx`
- `parent-app/src/store.tsx`, `src/lib/auth.tsx`, `src/screens/ReviewScreen.tsx`, `src/screens/TasksScreen.tsx`, `src/screens/TaskDetailsScreen.tsx`
- `game-app/Assets/_Pofi/Scripts/Logic/Services/Supabase/SupabaseAuthService.cs`, `SupabaseGameService.cs`, `Services/RoutedAuthService.cs`, `Auth/LoginThrottle.cs`, `State/SyncCoordinator.cs`, `State/SaveRestore.cs`, `Tasks/ChildTask.cs`, `Tasks/TaskSync.cs`, `Economy/Wallet.cs`, `Economy/XpSystem.cs`
- `parent-app/docs/SUPABASE.md`, `parent-app/docs/DURUM.md`, `game-app/docs/M4_SUNUCU_ONERISI.md`, `M4_UYGULAMA.md`

Son güncelleme: 2026-10-24 (3.1a hoş geldin coini, P11 ilk ödül talebi)

---

## 1. Ebeveyn kaydı ve aile

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Ebeveyn e-posta + şifreyle kayıt olur (meta: `nickname`, `name`, `avatar`). | `auth.users` |
| 2 | [S] | Anonim olmayan yeni kullanıcı için aile + profil oluşturulur. | tetikleyici `handle_new_user` → `families`, `profiles` |
| 3 | [P] | Ebeveyn çocuk ekler (ad, avatar, cinsiyet, doğum günü) ve isterse yaş bandını seçer. | `children` insert; ardından `set_child_age_band` |

### 1.1 İkinci ebeveyn daveti
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] (ebeveyn 1) | Aile › + › Ebeveyn › "Davet kodu üret". | `create_invite_code('parent')` → 6 karakter, **24 saat** |
| 2 | [P] (ebeveyn 2) | Kayıttan hemen sonra açılan "Kodun var mı?" ekranına ya da Aile › Hesap › "Kod gir" bölümüne kodu yazar (tek kutu: önce uzman daveti `claim_clinic_invite`, değilse `join_family`; 26 Ekim 2026). | `join_family(code)` |
| 3 | [S] | Profil yeni aileye taşınır, kod tüketilir. Ebeveyn 2'nin eski ailesinde başka ebeveyn yoksa eski aile **ve tüm verisi silinir** (uygulama önce uyarır). | `profiles.family_id`, `invite_codes.used_at` |

---

## 2. Çocuğu oyuna bağlama (giriş kodu)

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Aile › çocuk › Genel › "Giriş kodu üret". Aynı çocuğun kullanılmamış eski kodu geçersiz olur. | `create_invite_code('child', child_id)` → **24 saat**, tek kullanım |
| 2 | [P → çocuk] | Ebeveyn kodu çocuğa söyler/gösterir (uygulama dışı). ParentApp kodu yazıyla **ve QR olarak** gösterir (§2.0). | — |
| 3 | [O] | Çocuk kodu yazar ya da QR okutur (§2.0). Oyun büyük harfe çevirir, harf/rakam dışını atar, 6 karakter değilse hata. Hatalı denemelerde istemci beklemesi: 3 serbest, sonra 15 sn → ikiye katlanarak en fazla 300 sn. | `ChildCode`, `LoginThrottle` |
| 4 | [O] | Oturum yoksa **anonim oturum** açar. | `POST /auth/v1/signup` (anonim). Supabase'de "Anonymous Sign-Ins" açık olmalı. |
| 5 | [O → S] | Kodu kullanır. | `redeem_child_code(code)` → `{child_id, family_id, name, avatar, age_band}` |
| 6 | [S] | `children.user_id = auth.uid()` yapılır, kod tüketilir. Ebeveyn hesabıyla çağrılırsa reddedilir. | `children`, `invite_codes` |
| 7 | [O] | Yenileme anahtarı ve çocuk bilgisi cihazda güvenli saklanır; sonraki açılışlarda sessizce yenilenir. | `pofi.refresh_token`, `pofi.child` |
| 8 | [O] | İlk senkrondan **önce** sunucudaki oyun yedeğine bakar: yereldeki kayıt boşsa ya da yedek daha yeniyse yedeği alır (telefon değişimi). | `game_save_get()`; `SaveRestore` |
| 9 | [P] | Realtime ile çocuğun "bağlı" olduğu görünür (`linked` = `user_id` dolu). | `children` (Realtime) |

Not: Oyunun deneme kodları (`A1A1A1`, `B2B2B2`, `C3C3C3`) sahte arka uca gider; bu akışı kullanmaz.

### 2.0 QR ile bağlama (karar 26 Ekim 2026, kullanıcı: "QR ile ilerleriz; kodla da giriş yapılabildiği için PC'de o kullanılır")

Yeni sunucu işi yok: QR yalnız 1. adımdaki **aynı** kodu taşır (aynı süre, tek kullanım, aynı `redeem_child_code`).

| Konu | Kural |
|---|---|
| QR içeriği | `pofiadasi://baglan?kod=<KOD>` (KOD = 6 harf/rakam, büyük harf). Başka alan, çocuk adı ya da kimlik **konmaz**. |
| ParentApp [P] | "Giriş kodu üret" ekranında kodun yanında QR (orta düzey hata düzeltme, en az 220 pt, beyaz kenar payı). Kod yazıyla da görünür kalır (bilgisayar/tarayıcıda oyun kodla açılır). Süre dolunca QR de söner. |
| Oyun [O] — uygulama içi | Giriş ekranında "QR okut" (yalnız iOS uygulamasında; tarayıcı/bilgisayar sürümünde düğme yok, kod yazılır). Kamera yalnız bu ekranda, yalnız okumak için açılır; görüntü kaydedilmez, gönderilmez; üçüncü taraf kütüphane yok (iOS'un kendi okuyucusu). Kamera bu cihazda **ilk kez** istenmeden önce oyunun ebeveyn kapısı sorusu çıkar (geçilince bir daha sorulmaz). Okunan kod kutuya yazılır ve giriş başlar. |
| Oyun [O] — telefonun kamerası | Oyun `pofiadasi://` şemasını tanır: sistem kamerasıyla okutulunca oyun açılır, kod kutuya **yazılır ama giriş kendiliğinden başlamaz** — çocuk "Adaya gir"e basar (başka bir sitenin bağlantısı cihazı habersizce başka hesaba bağlayamasın). Oturum açıksa bağlantı yok sayılır. |
| Geçersiz QR | Şema/biçim tutmazsa "Bu QR Pofi Adası'nın değil" uyarısı; kod denemesi sayılmaz (`LoginThrottle` yalnız sunucuya giden denemede artar). |

**İlk görev önerisi (karar 26 Ekim 2026, kullanıcı; ParentApp'te yapılacak):** ebeveyn "Giriş kodu üret"e bastığında çocuğun hiç
görevi yoksa kod üretilmeden önce **yumuşak** bir adım çıkar: "Çocuğunuz adada ilk olarak panoya bakacak. Şimdi ilk görevi
ekleyelim mi?" + yaşına uygun 3 hazır görev (`veri/gorev_sablonlari.json`, tek dokunuşla ekle) + "Sonra ekleyeceğim" (kod yine
üretilir). Kesin engel konmaz (kayıtta vazgeçmeyi önlemek için). Oyunda pano hiçbir zaman boş başlamaz: rehberin hoş geldin görevi
(`ekonomi.md` §5A) ilk ziyarette panonun en üstündedir. Sunucu değişikliği yok (`create_invite_code` aynı).

### 2.1 Bağlantıyı kaldırma
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Aile › çocuk › "Cihaz bağlantısını kaldır". | `unlink_child_device(child_id)` → `children.user_id = null` |
| 2 | [O] | Sonraki denetimde kendi `children` satırını göremez → "Bağlantın kapatıldı, yeni kod iste". Bu cihazdaki oyun kaydı ve oturum **silinir** (2 Kasım 2026, `hukuk/42` satır 30); sunucudaki yedek kalır, yeni kodla bağlanınca geri gelir (`SaveRestore`). | `GET children?user_id=eq.<uid>` boş → `Revoked`; `child_me` → `42501` |
| 3 | [P] + [O] | Yeniden bağlanmak için 2. bölümdeki akış yeni kodla tekrarlanır. | |

---

## 3. Görev → çocuk tamamlar → ebeveyn inceler → coin

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Ebeveyn görev oluşturur (hazır şablondan ya da özel): başlık, emoji, açıklama, başlangıç, tekrar (`daily`/`weekly`/`monthly` + günler), bitiş, hatırlatma, **inceleme gereksin mi** (varsayılan evet). | `tasks` insert |
| 1a | [P] | **Hazır rutin** (27 Ekim 2026, yalnız ParentApp; veritabanı değişmez): Görev Oluştur'un üstündeki "Hazır rutinler" kartları (Güne hazır sabah, Okul dönüşü, Sakin akşam, Haftalık ev işleri, Ailece bir hafta, Hafta sonu keyfi; Görevler boşken "Bir rutinle başla"). Katalogdaki 4–6 görev tek seferde, **her biri ayrı tekrarlayan görev** olarak eklenir: kimin için, hafta içi / hafta sonu / her gün (gün gün seçim yok, eklendikten sonra görev düzenlemesinden; haftalıklarda her görevin kendi günü), saat = `reminder` (isteğe bağlı) ve gün bölümü, zorluk/coin katalogdan, inceleme açık. Eklemeden önce görev çıkarılır, adı ya da saati değiştirilir. Olay `routine.add` (`id`, `n`, `kids`, `timed`). Liste: `veri/hazir_rutinler.json` (tek kaynak; ParentApp kopyası `src/data/routines.json`, `bash tools/sync_routines.sh <ortak>/veri/hazir_rutinler.json`). | `tasks` + `task_assignments` insert (adım 1–2 ile aynı) |
| 2 | [P] | Görevi bir ya da daha çok çocuğa atar; her atamada zorluk ve coin (varsayılan Kolay 5 / Orta 10 / Zor 20, elle değişir). | `task_assignments` insert |
| 3 | [O] | Senkronda (zamanlaması Unity katmanında; doğrulanmalı) dünden 7 gün sonrasına kadar görev örneklerini çeker. Tekrarlar sunucuda açılır. Kaydı olmayan örnek `assigned`. | `child_tasks(from, to)` |
| 4 | [O] | Yeni görev için oyunda rozet + pet'ten bildirim. | `TaskEvent.NewTask` |
| 5 | [O] | Çocuk "Yaptım" ya da "Yapamam" der. Ekranda hemen görünür; ağ yoksa kuyrukta bekler (aynı görev için yalnız son niyet gönderilir). Gün geçtiyse ("kaçırıldı") işaretlenemez. | yerel `TaskBoard.Outbox` |
| 6 | [O → S] | Kuyruk gönderilir. | `child_set_status(task_id, date, 'pending' \| 'declined' \| 'assigned')` |
| 7 | [S] | `requires_review = true` → `pending` yazılır. `requires_review = false` → doğrudan `approved` (**coin hemen**, adım 10'a atla). `declined` → yalnız kayıt. `assigned` → kayıt silinir (geri al). Ebeveyn karar verdiyse değişmez. | `completions` |
| 8 | [P] | Realtime ile değişiklik gelir; **İnceleme** ekranında `pending` olanlar listelenir; Görevler'de durum etiketi (Onay bekliyor / Tamamlandı / Yapamadı / Reddedildi). | `completions` (Realtime) |
| 9a | [P] | **Onay:** kayıt `approved` yapılır. | `review_completion(..., 'approved')` (19 Ekim kararı; önceden doğrudan `completions` update) |
| 9b | [P] | **Ret:** ebeveyn isterse not yazar ("Yatak dağınık kalmış"); kayıt silinmez. | `review_completion(task, child, date, 'rejected', note)` |
| 9c | [P] | **İnceleme ayrıntısı** (`20261027130000_review_detail`, uygulandı, 27 Ekim 2026): satıra dokununca alt sayfa — "Motive etmek ne kadar zordu?" (1–5, isteğe bağlı, uzmana akar), Güneş Taşı − / + (0–6, varsayılan zorluğa göre), not (≤ 140, oyunda görünür), **Reddet / Tekrar dene / Onayla**. Satırdaki ✓ hızlı onay olarak kalır. | `review_completion(task, child, date, status, note, motivation, stones)` |
| 9d | [P → O] | **Tekrar dene:** kayıt `retry` olur, çocuğa `task_retry` bildirimi (not gövdede). Oyunda Atandı + tekrar bayrağı: "Yaptım" yeniden açık, kartta "Bir daha dener misin? Ailenden not: …" (not yoksa "Ailen bir daha denemeni istiyor"), Mavi haber verir; onay notu da kutlamada ve onaylı kartta (game-app 2bd61af; eski sürüm: Atandı, not görünmez). Çocuk yeniden "Yaptım" der → adım 6. Yalnız bugünün görevi. | `review_completion(..., 'retry', note)` → `child_set_status` |
| 10 | [S] | `approved`'a geçişte coin deftere eklenir (atamadaki `coins`). Onay geri alınırsa (başka duruma geçiş ya da silme) verilen tutar düşülür; görev/atama silinirse kazanılan coin kalır. | tetikleyici `completions_coin` → `coin_ledger` (`task` / `task_undo`) |
| 10a | [S] | Aynı geçişte **Güneş Taşı** yazılır: kolay 1 / orta 2 / zor 3 (`20261019030000_sun_stones`, uygulandı 19 Ekim). Geri almada o tamamlamanın taşı düşer. | tetikleyici `completions_sun_stone` → `sun_stone_ledger` |
| 11 | [O] | Sonraki senkronda görev durumu `approved`/`rejected` gelir (nihai; kuyruktaki çocuk niyeti düşer). Onayda kutlama sahnesi; retde ebeveynin notu gösterilir. | `child_tasks` (`status`, `parent_note`); `TaskEvent.Approved/Rejected` |
| 12 | [O] | Bakiye sunucudan alınır, artış "kazanılan coin" olarak kutlanır. Aynı gün ilk onayda görev serisi bonusu XP'si verilir (coin değil). | `child_me().balance`; `TaskStreak` |
| 12a | [O] | Onaylı her görev örneği için bir kez: zorluğa göre XP (6/10/14, günlük sınıra sayılmaz; görünmez günlük payı var — `ekonomi.md` 5.2) ve becerisine 1 yıldız (`ekonomi.md` 5B). Taş toplamı `child_me().sun_stones`'tan alınır; çocuk taşları adadaki onarım noktalarına yerleştirir. | `child_tasks` (`skill`, `difficulty`); `child_me().sun_stones` |
| 13 | [P] | Ebeveyn çocuğun bakiyesini görür. | `child_balance(child_id)` |

### 3.1 Coin harcama (oyun içi, ebeveyn adımı yok)
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [O] | Çocuk dükkânda eşya seçer; seviye kilidi, sahiplik, pete uyum ve bakiye oyunda denetlenir. Coin yerelde "bekleyen" olarak düşer, eşya hemen envantere girer. | `ShopRules.Buy`, `Wallet.TrySpend` |
| 2 | [O → S] | Harcama, istemcinin işlem kimliğiyle gönderilir (çevrimdışıysa kuyrukta kalır). | `spend_coins(tx, item_id, qty)` |
| 3 | [S] | Fiyat `game_items`'tan; aynı işlem iki kez düşülmez; bakiye yetmezse reddedilir. | `coin_ledger` (`spend`) |
| 4 | [O] | Kabul → kesinleşir. Ret (`not_enough_coins` / `unknown_item`) → eşya envanterden geri alınır, bakiye sunucudakine eşitlenir. | `Wallet.Acknowledge/Reject` |
| 5 | [P] | Ebeveynin gördüğü bakiye düşer (bir sonraki `child_balance` çağrısında). | |

### 3.1a Hoş geldin coini (coin kuralının tek istisnası; öneri `migrations/20261024100000_welcome_coins_first_reward.sql`, uygulandı 24 Ekim 2026)
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [O] | Çocuk Okti'yi **ilk kez beslediğinde** oyun hoş geldin coinini ister (çevrimdışıysa kuyrukta bekler; tekrar göndermek zararsızdır). | `claim_welcome_coins()` |
| 2 | [S] | Bu çocuğa daha önce verilmediyse deftere **+20** (`reason='welcome'`) yazar → `{ok:true, coins:20, balance, error:null}`. Verildiyse yazmaz → `{ok:false, coins:0, balance, error:'already_claimed'}`. Ebeveyn hesabı ya da bağlı olmayan oturum: `42501`. | `coin_ledger` (`welcome`) |
| 3 | [O] | `balance`'ı sunucu bakiyesi olarak alır (`Wallet.ApplyServerSnapshot`); `ok:true` ise kutlar ve çocuğu dükkâna (ilk aksesuar, ör. `glasses_round` 15) yönlendirebilir. `already_claimed` sessizce geçilir. | — |
| 4 | [P] | Ebeveyn bakiyede 20 coini görür (bildirim yok). Coin geçmişi gösterilirse satır adı "Hoş geldin hediyesi". | `child_balance(child_id)`, `coin_ledger` |

### 3.2 Oyun kaydı yedeği
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [O] | Her başarılı senkronun sonunda oyun durumu (pet, envanter, XP, seviye, ev …) sunucuya yazılır. | `game_save_put(data)` (≤ 262 144 bayt) |
| 2 | [P] | Okuma izni var; ParentApp bugün kullanmıyor. | `game_saves` |

---

## 4. Posta (mesajlar)

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Ebeveyn çocuğa yazı, fotoğraf ya da sesli mesaj gönderir. Fotoğraf/ses önce Storage'a yüklenir, sonra mesaj kaydı eklenir (kayıt başarısızsa dosya silinir). | Storage `mail/<family_id>/<id>.<uzantı>`; `messages` insert (`sender='parent'`, `kind` `text`/`image`/`audio`) |
| 2 | [P] | Diğer ebeveyn Realtime ile anında görür. | `messages` (Realtime) |
| 3 | [O] | Posta kutusu (23 Ekim 2026'dan beri): `child_messages` okunur, açılınca `mark_messages_read()`, B/C grubu `child_send_message` (yazı/çıkartma) yazar; fotoğraf/ses `mail` kovasından imzalı bağlantıyla. Realtime yok: oyun her eşitlemede (20 sn, öne gelişte de) yeniler. | `child_messages`, `child_send_message` |
| 4 | [K] | Erişim **yok** (klinik önerisinde de Posta uzmanla paylaşılmaz). | — |

---

## 5. Uzman (klinik) paylaşımı — uygulandı

> **Uygulandı (19 Ekim 2026).** SQL: `supabase/migrations/20261019000000_clinic.sql`.
> ParentApp tarafı aynı dalda "Aile › Hesap › Uzmanım" (`ClinicShare.tsx`, `lib/clinic.ts`). ClinicApp henüz yazılmadı.

### 5.1 Uzman hesabı ve ekip
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Uzman kayıt olur; meta `account='clinician'`, `name`, `title`, `clinic_name`, `practice` (`solo` / `clinic`; yalnız arayüz: bireyselde `clinic_name` = uzmanın adı, ana ekranda ekip bölümü yok; 26 Ekim 2026). | `auth.users` |
| 2 | [S] | Aile **oluşturulmaz**; yeni klinik (`plan='trial'`, 14 gün, 3 koltuk) + uzman (`role='owner'`). | `handle_new_user` → `clinics`, `clinicians` |
| 3 | [K] (sahip) | Ekip daveti üretir. | `clinic_create_invite('clinician')` → **7 gün** |
| 4 | [K] (yeni uzman) | Kayıtta `team_code` verir; koltuk doluysa reddedilir. | `handle_new_user` → `clinicians` (`member`) |
| 4a | [K] (giriş yapmış uzman) | Profil › "Ekip koduyla katıl": hesabı varsa kodla katılır. Eski kliniği **boşsa** (başka uzman, paylaşım, not, hedef yok) silinir; doluysa reddedilir. Sahibe `team_joined` bildirimi. | `clinic_join_team(kod)` (`20261021100000`, uygulandı) |
| 5 | [K] (üye) | Profilinde klinik adı, klinik sahibi ve davet edenin adı görünür; danışan listesi kliniğin bütün etkin paylaşımlarıdır (sahip ile aynı). | `clinician_me()` → `owner_name`, `invited_by_name`, `joined_at` (`20261021100000`, uygulandı) |

### 5.2 Aile paylaşımı (ebeveynin açık rızası)
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Uzman aile davet kodu üretir (isteğe bağlı etiket, ör. danışanın takma adı). | `clinic_create_invite('family', label)` → 6 karakter; **48 saat + bağlantı (bölüm 10)** |
| 2 | [K → ebeveyn] | Kodu aileye verir (uygulama dışı). | — |
| 3 | [P] | Ebeveyn Uzmanım › kodu yazar; **rıza vermeden önce** klinik adı, uzman adı ve unvanını görür. | `clinic_invite_preview(code)` |
| 4 | [P] | Paylaşılacak çocuğu seçer, "Onaylıyorum, paylaş". | `redeem_clinic_invite(code, child_id)` |
| 5 | [S] | Rıza kaydı oluşur (`status='active'`, `consent_by`, `consent_at`), kod tüketilir. | `clinic_links` |
| 6 | [K] | Uzman o çocuğun görevlerini, atamalarını, tamamlamalarını ve ABC kayıtlarını **yalnız okur**. Posta, coin defteri, oyun kaydı görünmez. | RLS `clinic_sees_child` |
| 7 | [P] | Ebeveyn etkin paylaşımlarını görür. | `family_clinic_links()` |

### 5.3 Rızayı geri alma
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] ya da [K] | "Paylaşımı durdur". | `revoke_clinic_link(link_id)` → `status='revoked'`, `revoked_at`, `revoked_by` |
| 2 | [S] | Uzmanın o çocuğa erişimi **hemen** biter (politikalar yalnız `active` bağlantıya bakar). Uzmanın kendi notları/hedefleri klinikte kalır. | — |
| 3 | [P] | Paylaşımı biten bağlantının bekleyen önerileri ParentApp'te gösterilmez. | `lib/clinic.ts` süzgeci |

### 5.4 Uzmanın görev önerisi
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Uzman rızalı bağlantı için görev önerir. Form ParentApp "Görev Oluştur" ile **birebir aynı**: şablon (kategori, ara) ya da özel görev; açıklama; zorluk + ödül (0–50); başlangıç; tek seferlik / tekrarlayan (her gün · haftalık günler · aylık günler) + son tarih; hatırlatma saati; inceleme gerekli; ebeveyne not. `pending` iken **günceller** (`clinic_update_suggestion`) ya da geri çeker. | `clinic_task_suggestions` insert (`status='pending'`) |
| 2 | [P] | Görevler ekranında bekleyen öneri bildirimi; Uzmanım'da kabul/ret. | `clinic_task_suggestions` select (`status='pending'`) |
| 3a | [P] | **Kabul:** öneri `accepted` yapılır, ardından ParentApp **kendisi** görev oluşturur. Öneri alanları göreve birebir taşınır: `title`, `emoji`, `skill`, `description`, `recurring`, `repeat_kind`, `repeat_days`, `end_date`, `reminder`, `requires_review`; atamada `difficulty` ve `coins` (null ise zorluğun varsayılanı 5/10/20); `start_date` null ya da geçmişse bugün. Ebeveyn kabul etmeden önce görev ekranında bunları değiştirebilir. (Eski öneriler — yeni sütunlar boş — için önceki varsayılanlar: bugün, `daily`, inceleme gerekli.) | update `status='accepted'`, `decided_at`; `tasks` + `task_assignments` insert; ardından öneriye `task_id` yazılır |
| 3b | [P] | **Ret:** `declined`. | update `status='declined'` |
| 4 | [O] | Kabul edilen görev oyuna sıradan bir görev olarak gelir (3. bölüm akışı). | `child_tasks` |

Not: Görev oluşunca ParentApp öneriye `task_id` yazar; uzman önerisinin hangi göreve dönüştüğünü buradan izler (ParentApp'te 22 Ekim 2026'dan beri).

**Günlük rutin v2 (kullanıcı kararı 28 Ekim 2026; `migrations/20261028200000_routines_v2.sql`, uygulandı 28 Ekim 2026; veritabani.md 21):** aşağıdaki ilk sürümün yerine geçer.

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | **Yaşa göre rutinler:** katalog her rutini bir yaş grubu aralığı için tutar (`veri/hazir_rutinler.json` sürüm 2, `ages` + `theme`; aynı konunun K / A–B / C sürümleri). Uzmana çocuğun yaş grubuna (`children.age_band`, yoksa doğum gününden; `durumlar.md` §4) uyan sürüm gösterilir; yaş bilinmiyorsa hepsi yaş etiketiyle. Rutindeki her görevin katalog yaşları rutinin bütün yaş gruplarını kapsar (`tools/check_routines.py`); bu yüzden "yaşa uymayan görevi ayıkla" (eski E seçeneği) gerekmez. | — |
| 2 | [K] | **Saat ve gün (F):** rutin penceresinde görev saatleri tek tek ya da hep birlikte (±15/30 dk) kaydırılır; tekrar: hafta içi · her gün · seçili günler. | öneri `reminder`, `repeat_kind`, `repeat_days` |
| 3 | [K] | **Hedefe bağlama (D):** isteğe bağlı "Hangi hedef için?" — yalnız bu paylaşımın takip planındaki hedef. Hedef kartında bağlı rutinin bu hafta tamamlanma oranı (ebeveyn kaydı; puan değil). | öneri `goal_id` (sunucu aynı paylaşımı denetler) |
| 4 | [K] | **Paket olarak gönder (B):** rutinin seçili görevleri aynı `routine_group` (yeni kimlik), `routine_title`, `routine_icon`, `routine_position` (sıra), `routine_key` (katalog kimliği ya da `own:<clinic_routines.id>`) ile **ayrı öneri satırları** olarak eklenir. Gönderilenlerde paket tek satır: "x / y eklendi". | `clinic_task_suggestions` insert × n |
| 5 | [P] | Uzmanım › <uzman> › Görev önerileri: aynı `routine_group` **tek kart** ("Güne hazır sabah · 5 görev · Hafta içi"): **Hepsini ekle** ya da düzenle (görev çıkar; isterse saat/gün değiştir) → ekle. Çıkarılanlar `declined`. Tek tek kabul de mümkün (bugünkü akış). | her öneri için 3a/3b (aşağıda) |
| 6 | [P] | Kabul edilen her görev **ayrı görev** olur ve rutinine bağlanır: `tasks.routine_id` = `routine_group`, `routine_title`, `routine_icon`, `routine_position`. **İnceleme (onay) ve oyun görev görev çalışır:** her görevin kendi "Yaptım", onayı, coin'i ve sorumluluğu vardır; rutin bir gruplama etiketidir, ödül birimi değildir. ParentApp kendi hazır rutinlerini eklerken de aynı alanları yazar (yeni `routine_id`). | `tasks` (+ `task_assignments`) insert; öneriye `task_id` |
| 7 | [K] | **Uzmanın kendi rutinleri (C):** Öneriler › Günlük rutin › "Rutinlerim": ad, simge, tekrar, yaş grupları, 1–12 görev (katalogdan ya da kendi yazdığı; saat, gün, zorluk, ödül); "Ekibe açık" seçilirse kliniğin diğer uzmanları görür (düzenleyemez). Klinik sahibi hepsini görür ve düzenler. Aileye 4–6 gibi gider. | `clinic_routines` |
| 8 | [O] | **Oyunda rutin kartı (GameApp, kullanıcı onayı 28 Ekim 2026):** aynı `routine_id`'li görevler Ev Görevleri'nde tek bir "rutin kartı" altında `routine_position` sırasıyla görünür: başlık (`routine_title` + `routine_icon`), ilerleme "2 / 4", yapılanlar soluk ve üstü çizili, sıradaki adım vurgulu ve "Yaptım" yalnız onda, sonrakiler soluk. K grubunda (≤ 5) liste yok: yalnız sıradaki adım büyük + nokta göstergesi. Her adım yine **ayrı görevdir** (ayrı Yaptım, onay, coin); ebeveyn bir adımı reddederse yalnız o adım etkilenir. Rutin bitince **ek coin yok**, yalnız kısa kutlama; **başarısızlık durumu yok** (kırmızı/çarpı/"kaçırdın" yok); saat görünür, geri sayım yok. Tek adımlı rutin sıradan kart gibi görünür. Veri: `child_tasks` yanıtında `routine_id`, `routine_title`, `routine_icon`, `routine_position` (`20261028210000_child_tasks_routine`, uygulandı 28 Ekim 2026). | `child_tasks` |

**Günlük rutin önerisi — ilk sürüm (kullanıcı isteği 27 Ekim 2026; veritabanı değişmedi; tarihçe):** Uzman Öneriler sekmesinde hazır bir rutini (ör. "Güne hazır sabah", 6 görev) tek seferde önerir. Katalog `veri/hazir_rutinler.json` (ParentApp'in hazır rutinleriyle aynı; görevler `gorev_sablonlari.json` anahtarlarıyla). Uzman görevleri seçip çıkarabilir (çocukta aynı adlı görev ya da bekleyen öneri varsa baştan seçili gelmez); her görev **ayrı bir öneri** satırı olur (`clinic_task_suggestions`; hatırlatma saati rutinden, tekrar: hafta içi = haftalık Pzt–Cum, her gün = günlük, haftalık = görevin günleri), `note` = "<Rutin adı> rutini" (+ uzmanın notu). Ebeveyn ParentApp'te her öneriyi ayrı kabul/ret eder (bugünkü akış). Alternatifler (tek öneri olarak paket, uzmanın kendi rutini, takip planına bağlama, yaşa göre seçim) karar bekliyor (DURUM HATIRLATMA).

### 5.5 Davranış kaydı (ABC kaydı; eski adları "Zor an", "Gözlem notu"; ad kararı kullanıcı 28 Ekim 2026: iki uygulamada da "Davranış kaydı")
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Ebeveyn zor bir anı kaydeder: Öncesi, Davranış (zorunlu), Sonucu, şiddet 1–5. | `abc_events` insert |
| 1a | [P] | Uzmanı hedef paylaştıysa (isteğe bağlı, 3 Kasım 2026 kullanıcı kararı): **"Hangi hedefle ilgili?"** uzmanın o çocuk için aileye gönderdiği etkin hedefler + "Diğer / emin değilim" (varsayılan). Seçilen hedefin açıklaması ipucu olarak görünür. Birden çok çocuk seçildiyse her çocuğun hedefi ayrı. Listede kaydın hedefi küçük etiketle görünür. Sunucu güncellemesi yoksa ya da hedef bu arada paylaşımdan çıktıysa kayıt hedefsiz kaydedilir (kayıt kaybolmaz). | `abc_events.goal_id` (`migrations/20261103120000_abc_goal.sql`, uygulandı 3 Kasım 2026; `abc_events_goal_guard`) |
| 2 | [K] | Rızalı bağlantısı olan uzman okur; hedefe bağlı kayıtları hedefe göre süzer (ClinicApp, Klinik penceresi). | `abc_events` (RLS `clinic_sees_child`) |

### 5.6 Uzmanın kendi çalışma alanı (aile görmez)
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Not yazar. | `clinic_notes` |
| 2 | [K] | Hedef (GAS) tanımlar, haftalık −2 … +2 puan verir. | `clinic_goals`, `goal_ratings` |

### 5.7 Abonelik
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [S] (service role) | Mağaza/web ödemesi aile aboneliğini yazar. | `family_subscriptions` (`free`/`premium`) |
| 2 | [S] | Aile, kendi aboneliği **ya da** etkin (deneme süresinde ya da ücretli) bir kliniğe bağlı çocuğu varsa premium sayılır. | `family_premium()`, `clinic_active()` |

### 5.8 ClinicApp üyeliği (`migrations/20261022200000_clinic_billing.sql`, uygulandı 23 Ekim)
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [S] | Yeni klinik 7 gün ücretsiz dener (kart yok, 10 koltuk). | `clinics.plan='trial'`, `trial_ends_at` |
| 2 | [K] | Ana ekranda kalan gün; "Üyelik" ekranında iki paket (Bireysel / Klinik), aylık–yıllık, içerik listesi. Yalnız klinik sahibi satın alır. | `billing_plans`, `clinician_me()` |
| 3 | [K] iPhone/iPad | **Karar (kullanıcı, 22 Ekim 2026): klinik sahibi BİREY olarak öder** (şirket hesabı/fatura yok). App Store aboneliği **RevenueCat** ile (ParentApp ile aynı yol): ClinicApp RevenueCat'e uzmanın Supabase kimliğiyle giriş yapar → RevenueCat → `billing-webhook` → durum RevenueCat'ten yeniden okunur → `billing_apply('revenuecat', '<uzman>:<ürün>', …)`. Yalnız klinik sahibinin aboneliği yazılır; ek süre (grace) etkin sayılır; başka hesaba geçen (TRANSFER) satır biter. | `billing_apply` |
| 3w | [K] web | Web panelinde satın alma yok: "Üyeliği iPhone/iPad'deki ClinicApp'ten alın". Üyelik uzman hesabına bağlı olduğu için web'de de açılır. (`clinic-billing` iyzico/Apple yolları ileride kendi sisteme geçiş için durur, yayınlanmaz.) | — |
| 4 | [S] | Deneme/üyelik bitince `clinician_access()` false: çocuk verisi, notlar, hedefler, öneriler, davet kapanır; veriler silinmez. Uygulama panel yerine üyelik ekranını gösterir. | RLS |
| 5 | [S] | Bireysel pakette yalnız sahip erişir; ekip üyesinin ekranında "Ekip erişimi kapalı". | `clinician_access()` |
| 6 | [P] | Etkin kliniğe bağlı aile premium sayılmaya devam eder (deneme dahil). | `family_premium()` |

ClinicApp olay adları (`track_events`, bölüm 9'a ek): `screen.membership{status}`, `membership.choose{plan}`, `membership.checkout{plan}`, `membership.purchased{plan,source}`, `membership.restore`, `membership.manage`.

---

## 6. Hesap silme

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Ebeveyn Storage dosyalarını siler, sonra hesabı siler. | Storage `mail`; `delete_account()` |
| 2 | [S] | Ailede başka ebeveyn yoksa aile ve bağlı her şey (çocuklar, görevler, tamamlamalar, mesajlar, coin defteri, oyun yedekleri) silinir. | `families` → cascade |
| 3 | [O] | Çocuk satırı silindiği için oyun sonraki denetimde bağlantıyı kapalı görür ve **bu cihazdaki çocuk verisini siler** (oyun kaydı, oturum belirteci; 2 Kasım 2026, `hukuk/42` satır 30). Yalnız cihaz bağlantısı kaldırıldıysa sunucudaki yedek kalır, yeniden bağlanınca geri gelir. | `Revoked` |
| 4 | [K] (uygulandı, bölüm 9 veritabani.md) | Uzman "Hesabı sil": tek kişilik klinik (paylaşımlar, notlar, hedefler, davetler, üyelik kayıtları) silinir; ekipte başkası varsa klinik kalır, sahiplik en eski üyeye geçer. App Store aboneliği Apple'dan ayrıca kapatılır. | `delete_account()` |

---

## 7. Bildirimler (19 Ekim 2026'da uygulandı)

> SQL: `supabase/migrations/20261019130000_notifications.sql`. Bildirim satırlarını **yalnız sunucu tetikleyicileri** yazar; uygulamalar okur, okundu işaretler (`mark_notifications_read`), siler.
> İşlemi yapan kişiye bildirim gitmez. Uzmana yalnız rızalı (`active`) paylaşım bildirilir; posta ve coin uzmana bildirilmez.

| Olay | Kimden → kime | `kind` | Uygulama (`app`) |
|---|---|---|---|
| Çocuk "Yaptım" (inceleme bekliyor ya da incelemesiz onay) | Oyun → ailenin bütün ebeveynleri | `task_done` | parent |
| Çocuk "Yapamam" | Oyun → ebeveynler | `task_declined` | parent |
| Ebeveyn onayladı / reddetti / tekrar dene dedi | ParentApp → çocuk cihazı | `task_approved` / `task_rejected` ("… onaylanmadı") / `task_retry` ("…: bir daha dener misin?", 27 Ekim 2026) | child |
| Yeni görev atandı (yalnız yeni atama; düzenleme bildirim üretmez) | ParentApp → çocuk | `task_assigned` | child |
| Posta | çocuk → ebeveynler / ebeveyn → çocuk | `message` | parent / child |
| Çocuğun cihazı koda bağlandı | Oyun → ebeveynler | `device_linked` | parent |
| İkinci ebeveyn aileye katıldı | ParentApp → diğer ebeveynler | `parent_joined` | parent |
| Aile çocuk(lar)ı uzmanla paylaştı (aynı anda paylaşılanlar **tek** bildirimde, adlarıyla) | ParentApp → sorumlu uzman (yoksa kliniğin uzmanları) | `clinic_shared` | clinic |
| Paylaşım durduruldu | aile durdurduysa → uzman; uzman durdurduysa → ebeveynler | `clinic_revoked` | clinic / parent |
| Uzman görev önerdi | ClinicApp → ebeveynler | `clinic_suggestion` | parent |
| Ebeveyn öneriye karar verdi | ParentApp → öneriyi yapan uzman | `suggestion_decided` | clinic |
| Davranış kaydı | ParentApp → rızalı bağlantının uzmanı | `abc_event` | clinic |
| Ekibe yeni uzman katıldı | ClinicApp → klinik sahipleri | `team_joined` | clinic |
| Çocuk ödül istedi (ilkinde `data.first = true`, başlık "İlk ödül talebi: …"; P11 3c) | Oyun → ebeveynler | `reward_request` | parent |

Teslim yolları:
- **Uygulama içi (üçü de):** `notifications` tablosu + Realtime (`user_id=eq.<kendi id>`); açılışta son 100 satır.
- **Telefona push (iOS, ParentApp ve GameApp):** cihaz Apple (APNs) cihaz anahtarını `register_push_token(token, 'parent'|'child', 'ios')` ile kaydeder. Her yeni bildirimde tetikleyici pg_net ile Edge Function `push-apns`'e yalnız bildirim kimliğini yollar; fonksiyon .p8 anahtarıyla Apple'a gönderir (konu: parent → `com.parentapp.ios`, child → `com.gameapp.ios`, clinic → `com.clinicapp.uzman`), geçersiz anahtarı siler, bildirimi `apns_sent_at` ile işaretler. Çıkışta `unregister_push_token`. Kod: `supabase/functions/push-apns/index.ts`; secret'lar `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID` (Supabase'de). Expo anahtarı (`ExponentPushToken[...]`) gelirse Expo Push API'ye gider (yedek yol).
- **Çocuğa push (K7 B, kullanıcı kararı 2 Kasım 2026; öneri `proposed/20261102200000_child_push.sql`):** varsayılan **kapalı**. (1) [P] ebeveyn ParentApp'te çocuk başına "Çocuğa bildirim" anahtarını açar, sessiz saatleri seçer (`parent_set_child_push`; varsayılan gece 20:30–08:00 + hafta içi okul saati 08:00–15:30). (2) [O] oyun `child_push_settings_me().enabled` ise ve ilk görev onaylandıktan sonra ebeveyn kapısının arkasında kısa açıklama gösterir; veli kabul ederse iOS izni istenir, cihaz anahtarı `register_push_token(token, 'child', 'ios')`. (3) [S] `push-apns` çocuk bildiriminde `child_push_claim` sorar: günde en çok 1, sessiz saatte hiç; metin genel ("Adada yeni bir haber var!"), içerik yok. Gönderilmeyen haber oyunda görünür. (4) [P] kapatınca çocuğun cihaz anahtarları silinir. Pet suçluluğu, geri sayım, "kaçırdın" yok (Radesky 2022; ICO).
- **GameApp (Unity):** uygulama içi liste + Realtime/yoklama; push için iOS cihaz anahtarını `app='child'` ile kaydetmesi yeterli.
- **ClinicApp (iPad/iPhone + web):** uygulama içi liste + Realtime; danışan listesinde çocuk başına okunmamış rozeti; dokununca ilgili danışan sekmesi (`abc_event` → Zor anlar, `suggestion_decided` → Öneriler, `clinic_shared` → danışan, `team_joined` → Ekip). iOS push: `register_push_token(token, 'clinic', 'ios')`, konu `com.clinicapp.uzman` (`push-apns` güncellemesi 21 Ekim 2026 — Edge Function yeniden yayınlanmalı). Web push sonra.
- `data` alanı: ilgili kimlikler (`task_id`, `child_id`, `date`, `message_id`, `suggestion_id`, `links` …) + push'ta `kind`, `notification_id`. Uygulama dokununca ekranı buna göre açar.

## 8. Uzmanla birden çok çocuk paylaşma (19 Ekim 2026'da uygulandı)

> SQL: `supabase/migrations/20261019120000_clinic_children.sql`.

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Kod girilir, uzman önizlenir, **birden çok çocuk** seçilip tek onayla paylaşılır. Kod yine tek kullanımlık. | `redeem_clinic_invite_children(kod, çocuklar[])` (tek INSERT → uzmana tek bildirim) |
| 2 | [P] | Uzmanım'da her uzmanın altında ailenin bütün çocukları: paylaşılanda "Çıkar", paylaşılmayanda "Ekle". Ekle açık rıza ister, kod gerekmez (o uzmanla etkin paylaşım varsa). | `clinic_share_child(klinik, çocuk)` / `revoke_clinic_link(link)` |
| 3 | [P] | Liste klinik başına gruplanır. | `family_clinic_links()` artık `clinic_id` de döndürür |
| 4 | [K] | Uzman çıkarılan çocuğu hemen göremez (RLS `active` bağlantıya bakar). | — |

## 9. Kullanıcı kaydı ve takip (21 Ekim 2026'da uygulandı, `migrations/20261021100000_clinic_team_tracking.sql`)

> Birinci taraf; üçüncü taraf analitik/reklam SDK'si **yok**. Olaylarda kişisel veri ya da serbest metin (ad, not, zor an içeriği) **yazılmaz**; yalnız ekran/eylem adı ve kimlik dışı küçük alanlar (`tab`, `kind`, sayı).

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | O, P, K | Açılışta ve öne gelişte oturum bildirilir (dakikada en çok bir oturum sayılır; gün değişince aktif gün +1). | `track_session(app, platform, sürüm)` → `user_activity` |
| 2 | O, P, K | Olaylar biriktirilir, toplu gönderilir (≤ 50/çağrı, kullanıcı başına ≤ 2000/gün). Ad biçimi `alan.eylem` (küçük harf, rakam, `_`, `.`). | `track_events(app, olaylar, platform, sürüm)` → `app_events` |
| 3 | — | İstemci bu tabloları **okuyamaz**. İş özetleri yalnız SQL Editor'den: `analytics.accounts`, `signups_daily`, `daily_active`, `events_daily`, `clinics_overview`, `families_overview`. | şema `analytics` (API'ye kapalı) |

ParentApp olayları (22 Ekim 2026): `app.open`, `screen.<tasks|review|progress|family|create_task|task_details|chat|notifications|observation|rewards|paywall>`, `task.create` (`n`), `task.delete`, `task.review` (`approve`, 27 Ekim 2026: + `decision` approved/rejected/retry, `motivation` 1–5), `template.custom`, `child.add`, `invite.create` (`kind`), `family.join`, `message.send` (`kind`), `notification.open` (`kind`), `observation.create`, `reward.create`/`reward.update` (`kind`), `reward.delete`, `reward.give` (`n`), `reward.decide` (`approve`), `stones.deduct` (`n`, `reason`: doğru/yanlış; metin gönderilmez), `onboarding.done` / `onboarding.skip` (`step`; ilk kullanım rehberi, 26 Ekim 2026; 3 Kasım 2026: + `mode` short/full/rewards; rewards = Ödüller ekranının 3 kartlık turu), `onboarding.start` (`mode`), `onboarding.later` ("Şimdi değil"), `first_steps.open` (`item`: child/link/task/approve/reward/clinic), `first_steps.collapse` / `first_steps.expand` (`n` tamamlanan; 3 Kasım 2026'ya kadar `first_steps.hide`), `first_steps.complete`, `observation.goal` (`n`: hedef seçilen çocuk sayısı) / `observation.goal_skip` (hedef sorulduğu hâlde seçilmedi; 3 Kasım 2026), `referral.redeem` (Apple hediye kodunu kullan), `code.redeem` (`kind`: invite/family/accepted), `code.skip`, `invite.accept` (`n`, `new`, `history`), `invite.decline`, `care.log` (`practiced`) (uzman daveti ve takip planı, 26 Ekim 2026). 27 Ekim 2026: `push.ask` (`yes`; bildirim ön sorusu).

ClinicApp olayları (ilk sürüm): `app.open`, `screen.home`, `screen.client` (`tab`), `screen.notifications`, `notification.open` (`kind`), `suggestion.send` (`n`), `suggestion.update`, `report.print`, `invite.family`, `invite.team`, `team.join`, `abc.play`, `onboarding.done` / `onboarding.skip` (`step`; ilk kullanım rehberi, 26 Ekim 2026), `invite.share` (`channel`), `invite.email` (`sent`, `reason`; sistem e-postası, 26 Ekim 2026), `survey.done` (`intent`, `profession`) / `survey.skip` (`step`) (karşılama anketi, 27 Ekim 2026), `plan.goal` (`edit`), `plan.module` (`edit`), `plan.package`, `plan.publish`, `verification.submit` (`profession`, `check`) (26 Ekim 2026); `sample.open`, `sample.tour` (`step`, kapatıldığı adım), `sample.hide` (listeden kaldırıldı), `start.hide` (örnek aile ve "Başlarken"), `export.abc` / `export.routine` (`rows`; CSV, dosya cihazda oluşur), `report.note_copy` (ilerleme notu), `settings.profile`, `settings.clinic`, `client.label` (28 Ekim 2026, Joon referanslı yeniden düzen). Takip planı yeniden tasarımı (2 Kasım 2026): `plan.routine_goal` (`link`), `plan.template_save` (`shared`, `modules`), `plan.template_apply` (`modules`, `routines`), `suggestion.change` (`n`, `remove`); `plan.publish`'e `drafts`, `plan`; `suggestion.routine` / `suggestion.send`'e `draft`, `from`. `screen.client`'te örnek ailede `sample: true`.

GameApp olayları (`track_events('child', …)`, 2 Kasım 2026; çocuk oyunu, anonim çocuk oturumu; **görev başlığı, ebeveyn notu, mesaj, ad gibi serbest metin gönderilmez** — istemci süzgeci `Logic/Analytics/Telemetry`: özellik değeri yalnız sayı, doğru/yanlış ya da `^[a-z0-9_.:-]{1,40}$` kimlik; aynı olay aynı oturumda tek satırda `n` ile sayılır; çağrı ≤ 50, istemci günlük üst sınırı 500; oturum `track_session('child', ios|web, sürüm)` açılışta ve 5 dk'dan uzun aradan sonra öne gelişte): `app.open` (`first_screen_ms`, `signed_in`; ilk ekrana kadar süre), `app.first_touch` (`ms`), `screen.<ad>` (`login`, `petselect`, `map`, `home`, `tasks`, `shop`, `wardrobe`, `minigame`, `garden`, `album`, `settings`, `decorate`, `festival`, `lighthouse`, `mail` …), `act.<sayaç>` (`n`; oyun içi eylem sayaçlarıyla aynı adlar: `pet_fed`, `pet_washed`, `pet_played` (K2 B: tamamlanan top oyunu), `pet_petted` (okşama), `quest_claimed` (K1 A), `home_entered`, `item_bought`, `minigames_played`, `runner_played`, `runner_finished`, `reward_requested`, `mail_sent`, `stone_placed`, `hut_built`, `gift_opened`, `tasks_approved` …), `guide.step` (`step`: rehber adımı kimliği, ör. `feed`), `level.up` (`level`), `task.done` / `task.cant` (`routine`: rutin adımı mı), `tips.off` / `tips.on` (K6 A: ipuçlarını kapatma/açma), `quest.claim` (`quest`: oyun görevi kimliği, ör. `dq_wash_1`; K1 A: biten görevin ödülü "Al" ile alındı). Sahte arka uçta (deneme kodları) hiçbir şey gönderilmez.

## 10. Uzman başlatır: aile davet bağlantısı (`migrations/20261026100000_family_invite_links.sql`, uygulandı 26 Ekim 2026)

Karar (kullanıcı isteği 26 Ekim): akışı uzman başlatır. Uzman isterse önce takip planını (hedefler + aile programı) kurar, sonra aileye **bağlantı** gönderir (WhatsApp / e-posta / SMS / kopyala). Aile bağlantıdan ParentApp'i yükler, kayıt olur; uzman kendiliğinden tanımlıdır. Çocuk verisi yine **ebeveynin çocuk seçip onay vermesiyle** paylaşılır (rıza kuralı değişmedi).

**Güncelleme — e-postayla davet (kullanıcı kararı 26 Ekim 2026, `migrations/20261027000000_invite_email.sql` + Edge Function `invite-email`, **uygulandı ve yayında 26 Ekim 2026**; test gönderimi Gmail):** kurumsal görünüm için davetin ana yolu **sistem e-postası**. Uzman ebeveynin e-postasını (ClinicApp'te **zorunlu**), isterse çocuğun adını + yaş grubunu ve kendi notunu yazar (ebeveyn adı alanı kalktı), **"E-posta gönder"** der; e-postayı sistem uzman adına gönderir (gönderen adı "Ad Soyad · ParentApp", yanıtlar uzmanın e-postasına). WhatsApp / SMS / sistem paylaşımı düğmeleri kalktı; **yedek**: kodu ya da davet metnini kopyalayıp uzmanın kendisi iletmesi (e-posta gönderilemezse ek olarak "E-posta uygulamasında aç"). Davet **3 gün** (72 saat; önce 48 saat). E-posta içeriği: marka başlığı, "**<unvan> <ad soyad>** (klinik) sizi ParentApp uygulamasına davet ediyor", büyük kod, son geçerlilik (İstanbul saati), yükleme/kod adımları, alan adı varken "Daveti aç" düğmesi, "hangi çocuğu paylaşacağınıza siz karar verirsiniz", altta kimin adına gönderildiği + yok sayma notu (+ `PRIVACY_URL` varsa aydınlatma bağlantısı). **Konu satırında unvan yok** ("Ece Kaya sizi ParentApp uygulamasına davet ediyor"; sağlık çağrışımı bildirim ekranında görünmesin); çocuk adı ve uzmanın notu e-postaya **girmez**. Gönderim yolu: test için kullanıcının Gmail hesabı (SMTP 465 + Google uygulama şifresi; Supabase Edge Function secret'ları `SMTP_USER`, `SMTP_PASS`), canlıda alan adı + Resend (`RESEND_API_KEY`, `MAIL_FROM`; CANLIYA ALMA 1–2; Resend varsa o kullanılır). Sınırlar: davet başına 3 e-posta, aynı davete 60 sn'de bir, uzman başına günde 30 davete e-posta; gönderilemeyen sayılmaz. Bağlanmış (aile kayıt olmuş), iptal edilmiş, reddedilmiş ya da süresi dolmuş davete e-posta gitmez.

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | "Aileyi davet et": isteğe bağlı ebeveyn adı, e-posta, **çocuğun adı + yaş grubu** (formda "Çocuğun adı"; kullanıcı kararı 26 Ekim 2026) (K ≤5 · A 6–8 · B 9–12 · C 13+), kendi notu (aile görmez). | `clinic_create_invite('family', label, parent_name, parent_email, child_name, child_age_group)` → `{code (6), token (32), expires_at}`; **3 gün** (72 saat, 27 Ekim göçü; önce 48 saat) |
| 2 | [K] | İsterse davete taslak takip planı ekler (paket seç → hedef/modül düzenle). | `clinic_goals` / `care_modules` (`invite_code`) |
| 3 | [K] | **"E-posta gönder"**: sistem e-postası (yukarıdaki güncelleme). Yedek: kodu / davet metnini kopyala, e-posta uygulamasında aç (eski sürüm: WhatsApp, `mailto:`, sistem paylaşımı). Kanal kaydedilir; sistem e-postasında `email_status` sending → sent / failed. | Edge Function `invite-email` → `clinic_invite_email_take(code, uzman)` / `clinic_invite_email_done(code, ok)` (yalnız service role); yedek `clinic_invite_mark(code, channel)` |
| 4 | Ebeveyn | Bağlantıya dokunur: `https://<alan adı>/d/<token>`. ParentApp yüklüyse doğrudan uygulama açılır (Universal Link); değilse açılış sayfası (`web/davet`): uzman adı + "App Store'dan yükle" + "Daveti uygulamada aç" (`parentapp://davet/<token>`) + kod. | Edge Function `invite-info` → `clinic_invite_open(token)` (açıldı işareti) |
| 5 | [P] | Bağlantıyla gelindiyse kayıt ekranında "Dr. X seni davet etti" bandı (oturum yok: `invite-info` bağlantı anahtarıyla; 6 karakterlik kodla kayıtta bant yok); kayıtta meta `clinic_invite = <token ya da kod>` gönderilir. | `handle_new_user` → davet aileye **bağlanır** (`claimed_family`); uzmana `invite_claimed` |
| 5a | [S] | Bağlantı/kod yoksa: davette e-posta yazılıysa, aynı e-postayla kayıt olan ebeveyn e-postasını **doğruladığında** davet kendiliğinden bağlanır (26 Ekim denetimi: doğrulanmamış e-postayla eşleşme yok; "Confirm email" kapalıyken kayıtla aynı anda yapılan kendiliğinden onay eşleşme yapmaz — o sürede ebeveyn kodu yazar). | `handle_user_email_confirmed` (auth.users `email_confirmed_at`) |
| 5b | [P] | Hesabı olan ebeveyn bağlantıyı açar ya da kodu yazar. | `claim_clinic_invite(token|kod)` |
| 6 | [P] | Bekleyen davet ekranı (kullanıcı kararı 26 Ekim 2026): **"Dr. X, Efe (6–8) için seni davet etti. Bilgiler doğru mu?"** Ad, yaş grubu (isteğe bağlı doğum günü, cinsiyet, simge) **dolu ve düzenlenebilir**; ebeveyn ayrıca çocuk eklemez. Aynı ekranda **uzman doğrulanmaz uyarısı** (aşağıda) ve tek onay kutusu "Bu uzmanı tanıyorum ve çocuğun velisiyim"; düğme **"Onayla ve paylaş"**. Ailede başka çocuk varsa onları da işaretleyebilir. Altta "Bu davet bana ait değil" (reddet; yalnız daveti kendi ailesine bağlamış ebeveyn). Öneri yoksa ebeveyn adı yazar (aynı ekran). | `family_pending_invites()` (+ `child_name`, `child_age_group`), `family_accept_invite(anahtar, çocuk, çocuklar, geçmiş, onay_sürümü, geçmiş_sürümü)`, `family_decline_invite(anahtar)` |
| 6b | [S] | Onayda çocuk sunucuda oluşur ve paylaşılır; ebeveyn öneriyi değiştirdiyse uzmana **"Ebeveyn çocuk bilgisini düzeltti: Efe (A) → Efecan (B)"**; onaylanan ad uzmanın danışan listesinde. Sonradan ParentApp'te yapılan düzeltmeler de danışan listesine kendiliğinden yansır. Reddedilirse uzmana "Aile davetini kabul etmedi", davet kapanır, öneri ve taslak plan silinir. | `invite_child_updated`, `invite_declined`, `clinic_clients()` |
| 6c | [P] | Ebeveyn "Çocuk ekle" ile **aynı adda** bir çocuk eklemeye kalkarsa: bekleyen davette bu ad varsa "Uzmanının davetinde Efe zaten var — davete git"; ailede varsa "Kayıtlarında Efe adında bir çocuk var — yine de ekle / vazgeç". Sunucu da `family_accept_invite`'ta aynı adı yakalar (`{"error":"duplicate_child", child_id, name}`; ebeveyn "yine de ekle" derse `allow_duplicate: true`). | ParentApp (istemci) + `family_accept_invite` |
| 6d | [P] | Çocuk eklenince aynı ekranda "Çocuğunun tabletini bağla": **QR + yazılı 15 dakikalık giriş kodu** (kullanıcı onayı 26 Ekim 2026); GameApp QR'ı okur ya da kod yazılır. Oyun giriş kodu davete **konmaz**. | `create_child_login_code` (bugünkü; QR yalnız aynı kodu taşır) |
| 7 | [S] | Paylaşım açılır; taslak plan **uzmanın önerdiği çocuğa** taşınır (öneri yoksa seçilen bütün çocuklara) ve aileye gönderilmiş sayılır; uzmana `clinic_shared` (mevcut), diğer ebeveyne `care_plan_shared` (aileye görünen bir şey varsa). Seçilen çocukların hepsi bu uzmanla zaten paylaşılıyorsa davet harcanmaz, hata döner. | `clinic_links`, `clinic_goals`/`care_modules` (`link_id`) |
| 8 | [S] | 3 günde kimse bağlamadıysa uzmana bir kez `invite_expired`. Zamanlayıcı (pg_cron, 15 dk) ya da ClinicApp açılışında. | `clinic_invites_expire()` / `clinic_invites_sweep()` |
| 9 | [K] | Davetlerim: durum (gönderildi / açıldı / kayıt oldu / paylaşıldı / süresi doldu / iptal / aile reddetti; kayıt olup 30 günde paylaşmayan da "süresi doldu") + e-posta durumu (gönderildi / gönderilemedi), e-postayı yeniden gönder, iptal. Sahip bütün ekibin istatistiğini görür (reddeden aile "kayıt" sayılmaz). | `clinic_invites_list(gün)`, `clinic_invite_stats(gün)`, `clinic_invite_mark(code, null, true)` |

**Uzman doğrulanmaz uyarısı (ParentApp, davet ekranında, kullanıcı kararı 26 Ekim 2026; metin sürümü `uzman-paylasim-v1`, `hukuk_notlari.md` 3F):**
> ClinicApp uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunun bilgilerini paylaşmadan önce bu uzmanı gerçek hayatta tanıdığından ve davetin ondan geldiğinden emin ol. Emin değilsen paylaşma; uzmanını bildiğin bir yoldan arayıp sor. Paylaşımı istediğin an Uzmanım bölümünden durdurabilirsin.
> ☐ Bu uzmanı tanıyorum ve çocuğun velisiyim (yasal temsilcisiyim).

Çocuk önerisi (kullanıcı kararı 26 Ekim 2026): yalnız ad/takma ad (≤ 40) + yaş grubu; doğum günü, cinsiyet, fotoğraf alınmaz. Açılış sayfası (`invite-info`), mesaj metni ve daveti bağlamamış aile göremez; yalnız daveti kendi ailesine bağlamış ebeveyn (`claim_clinic_invite`, `family_pending_invites`, `clinic_invite_preview`). Davet kullanılınca, iptal edilince, 3 günde bağlanmayınca ya da bağlandıktan 30 gün sonra silinir; kullanılmadan biten davetin taslak planı bir hafta sonra silinir. Davetle oluşan çocukta yaş grubu (`age_band`): doğum günü verildiyse boş (doğum gününden otomatik), verilmediyse önerilen grup aynen (K/A/B/C; 26 Ekim denetimi, eskiden K→A, C→B). Uzmanın kendi notu (`label`) hiçbir aile yanıtında dönmez; paylaşımdaki not yalnız kliniğin okuyabildiği `clinic_link_labels` tablosundadır (aile `clinic_links`'ten okuyamaz).

Ret nedenleri (`reason`, ParentApp metni gösterir): `not_found`, `expired` (3 gün / bağlandıktan 30 gün), `used` (başka aile), `accepted` (bu daveti zaten kabul ettin), `declined` (bu daveti kapattın), `revoked` (uzman iptal etti).

Neden oyun kodu davette yok: çocuk hesabı davet anında yok (açmak için uzmanın çocuk hesabı açması gerekir, rıza kuralına aykırı); bağlantı ebeveynin telefonuna gelir, oyun çocuğun cihazında açılır; oyun kodu çocuk hesabının anahtarıdır (uzmanda ya da mesajın iletildiği kişide olursa çocuk gibi oyuna girip ebeveyn–çocuk mesajlarını görebilir); uzman hesapları doğrulanmıyor (kötü niyetli "uzman" riski); oyun kodu 15 dakika ve tek kullanımlık, davet 3 gün.

Kurallar: Bağlanmış davet 30 gün içinde çocuk paylaşımına kullanılabilir (3 gün yalnız bağlanana kadar). Bir davet tek aileye bağlanır. Kod yolu deneme sınırına tabidir (`code_attempts`); başarılı kullanım sayacı **silmez** (whitehat2 W2-1; 26 Ekim denetiminde geri gelmişti, düzeltildi). 32 karakterlik anahtar tahmin edilemez. Uzman yalnız kendi davetlerini, sahip kliniğin bütün davetlerini görür. Ekip kodu değişmedi (15 dakika).

Neden üçüncü taraf "ertelenmiş bağlantı" (Branch, AppsFlyer) yok: SDK, maliyet, izin/KVKK yükü. App Store'dan yükleme sonrası davet; (a) "Daveti uygulamada aç" dokunuşu, (b) e-posta eşleşmesi (doğrulanmış e-posta), (c) kod ile taşınır.

## 11. Uzman değişimi ve geçmiş aktarımı (aynı dosya, uygulandı)

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Uzmanım › uzman › "Paylaşımı durdur" (eski uzmanın erişimi hemen biter). | `revoke_clinic_link` (değişmedi) |
| 2 | [P] | Yeni uzmanın bağlantısı/kodu (bölüm 10). Çocuk seçme ekranında, çocuk daha önce başka uzmanla paylaşıldıysa "Önceki uzmanın kayıtlarını da paylaş (adı ve bilgileri gizlenir)" (varsayılan açık) + açık rıza metni; onaylanan metnin sürümü kaydedilir. | `redeem_clinic_invite_children(…, p_share_history, p_consent_version)` |
| 3 | [S] | Yeni uzman önceki (**bitmiş**; çocuğun hâlâ gördüğü başka uzman sayılmaz, 26 Ekim denetimi) paylaşımların, o paylaşım bitene kadarki notlarını, hedeflerini ve haftalık puanlarını, önerilerini, aile programını ve ebeveynin uygulama kayıtlarını **salt okur**. **Önceki uzman adsızdır** (26 Ekim 2026, kullanıcı kararı): adı, unvanı, kliniği ve kimlikleri yeni uzmana dönmez; "Önceki uzman 1, 2…" ve dönem (ay) görünür; metinlerde geçen klinik adı (ve 4+ harfli anlamlı parçaları), o kliniğin uzman adları "[önceki uzman]", e-posta ve telefon "[iletişim]" ile değiştirilir; çocuğun kendi adı değiştirilmez; aynı klinik aynı numarayı alır (en iyi çaba). Tablolara doğrudan erişim yok, yalnız işlev. Görev/tamamlama/zor an verisini zaten görür. | `clinic_inherited_records(link)` |
| 4 | [P] | Aktarımı sonradan açıp kapatabilir (geri alınabilir rıza). Ebeveyn kendi ekranında uzman adlarını görür. | `clinic_link_history_set(link, açık, sürüm)`; `family_clinic_links()` → `history_shared`, `history_available` |

Not: Önceki uzmanın notları onun mesleki kaydıdır; aktarım yalnız ebeveyn rızasıyla, okuma olarak ve önceki uzmanın kimliği gizlenerek yapılır. Dayanak: uzman sözleşmesindeki aktarım maddesi + ebeveynin açık rızası (taslak maddeler `sozlesme/hukuk_notlari.md`). Canlıda açılmadan önce hukuk onayı gerekir.

## 12. Takip planı: hedefler ve aile programı (aynı dosya, uygulandı)

Biz tedavi yapmıyoruz; uzmanın kendi planını hızlı kurması için şablon (iskelet) sunuyoruz. Şablon kataloğu: `veri/takip_sablonlari.json` (7 alan, 27 hedef, 13 modül — 12 + "Gözlem ve zor an kaydı" girişi, 8 paket; kaynaklarıyla).

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Danışan › Plan (ya da davet taslağı): paket seç ya da tek tek ekle. Hedef: alan, gözlenebilir davranış, ölçüm (evet-hayır / yüzde / sıklık / süre / düzey), başlangıç, hedef düzey, süre (hafta), evde destek, "aile görür". **2 Kasım 2026 (kullanıcı kararı "B1"):** ClinicApp formu alan, davranış, hedef düzey, süre, aileye not (`description`), "aile görür"; `measure` / `baseline` / `home_support` formda yok (sütunlar duruyor; yeni hedefte `measure` şablondan ya da `level`, ötekiler boş; şablonun ev desteği `description`'a yazılır). ParentApp boş alanları göstermemeli. **3 Kasım 2026 (kullanıcı kararı "G1"):** "aile görür" anahtarı formdan da kalktı; yeni hedef `shared = true`, gizlemek yalnız hedef satırı ⋯ › "Aileden gizle" (sonraki gönderimde hedefin adı, düzeyi ve notu aileden kalkar; bağlı program ve rutinler gider). Kural ve şema değişmedi. **3 Kasım 2026 (kullanıcı kararı "N3"):** uzmanın hedefe özel notu: "Değerlendir" penceresinde isteğe bağlı not (`goal_ratings.note`) ve hedefin bej kutusunda not simgesi (`clinic_notes.goal_id`, `veritabani.md` 27); ikisi aileye gitmez. | `clinic_goals` (genişledi: `domain`, `measure`, `baseline`, `target`, `weeks`, `home_support`, `shared`, `status`, `position`, `template_key`) |
| 2 | [K] | Aile programı modülü: amaç, evde uygulama, kontrol listesi (≤ 8), durum (planlandı / etkin / tamamlandı). | `care_modules` |
| 3 | [K] | "Planı aileye gönder": aile planı **o anki hâliyle** görür; sonraki düzenlemeler yeniden gönderilene kadar ailede görünmez (26 Ekim denetimi; önceden her kayıt anında görünüyordu). Gönderilecek bir şey yoksa (aile görür hedef / etkin modül yok) hata; bildirim en çok 10 dakikada bir. | `care_plan_publish(link)` → `clinic_goals.pub` / `care_modules.pub` + ebeveynlere `care_plan_shared` |
| 4 | [P] | Uzmanım › çocuk › Takip planı: gönderilmiş hedefler (durumuyla) + etkin/tamamlanan modüller (aile tablolara doğrudan bakmaz, yalnız işlev); gönderilmiş etkin modülde günde tek dokunuş "Bugün uyguladım" (gün Türkiye saatiyle; ileri tarih yok, geriye en çok 14 gün), isteğe bağlı zorluk (1–5), uygulayamadıysa neden (vakit yoktu / unuttum / çocuk direndi / nasıl yapacağımı bilemedim). | `family_care_plan(link)`, `care_module_logs` |
| 5 | [K] | Uzman uygulama kayıtlarını görür (son 14 gün: kaç gün, ailenin bildirdiği zorluk sayıları — kolay / orta / zorlandı, engeller); paylaşım bitince kayıtlar uzmana görünmez. Hedefleri haftalık GAS (−2…+2) ile işaretler — **puanlar aileye görünmez**. | `care_module_logs`, `goal_ratings` |

Kurallar: Aileyle paylaşılmayan hedef (eski hedefler dahil, `shared=false`) yalnız klinikte. Planlandı durumundaki modül aileye görünmez. Ebeveynin zorluk bildirimi bir puan değildir, ekranda ölçek gibi gösterilmez. Hiçbir hedef tanı değildir; paket adları ihtiyaç alanıyla yazılır, tanı etiketi zorunlu değildir.

### 12.1 Takip planı yeniden tasarımı (kullanıcı kararları 30 Ekim ve 2 Kasım 2026, `migrations/20261102100000_plan_redesign.sql` uygulandı 2 Kasım 2026, veritabani.md 22)

**Ad (kullanıcı kararı 5 Kasım 2026):** ClinicApp'te takip planındaki hedefin adı **"Davranış hedefi"** (başlık, düğme, menü, kitaplık, rapor, ilerleme notu; eski "Hedef"). "Hedef düzey" (ulaşılacak düzey), "hedef davranış" (formdaki alan) ve GAS'ın "hedefe ulaşma" ölçeği değişmedi. Veritabanı (`care_goals`, `goal_id`) aynı. ParentApp'te de aynı ad (kullanıcı kararı 5 Kasım 2026): Takip planı'nda "Davranış hedefleri", davranış kaydında "Hangi davranış hedefiyle ilgili?", öneri ve rutin kartlarında "Davranış hedefi: …", hedefin ulaşılacak düzeyi "Hedef düzey: …".

Kararlar: ClinicApp'te **C · hedef hatları** (her hedef bir satır: hedef · aile programı · rutin/görev; ileride salt bakış "Harita"); bir program **birden çok hedefi** destekler; Şablonlarım paylaşımını **uzman seçer**; **tek "Aileye gönder"**; ailede ekli rutin/görev **değişiklik önerisiyle** düzenlenir; uzmanın kendi programı **yok** (sistem içerikleri kalır); iPad'de uzman **iPad görünümü / web görünümü** arasında seçer (sağ üstte düğme; yalnız uygulama ayarı). Taslaklar: https://claude.ai/artifact/MxXWHaP3MPLHp5o2GHj6VG, yan yana hikâye https://claude.ai/artifact/R3jRURSfeHDMyPcwLzYZNY.

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Hedef satırında programı hedefe bağlar (sürükle ya da Ekle); bir program birden çok hedefe bağlanabilir. | `care_module_goals` |
| 1b | [K] | Rutin ya da tek görevi bir hedefe bağlar ya da bağı kaldırır (ailede ekli olsa da; yalnız klinik bilgisi, aile hedef gönderilmişse rutini o hedefin altında görür). | `clinic_set_suggestion_goal(ids, goal)` |
| 2 | [K] | Şablon uygular (hedef + programlar + rutin taslakları; rutin çocuğun yaşına uygun sürümle) ya da hedef satırını "Şablon olarak kaydet" (ad + yalnız ben / ekibim). | `clinic_plan_templates` |
| 3 | [K] | Rutin ve görev önerileri **taslak** yazılır; aile görmez, bildirim yok. Taslak ve bekleyen öneri doğrudan düzenlenir ya da geri çekilir. | `clinic_task_suggestions.status = 'draft'`, `clinic_update_suggestion` |
| 4 | [K] | **Aileye gönder**: plan anlık görüntüsü + bütün taslaklar `pending`; aileye **tek** bildirim. | `care_plan_publish(link)` |
| 4a | [K] | **Önce özet, istenen bekler** (kullanıcı kararı 2 Kasım 2026, "G1"; `migrations/20261102500000_plan_publish_selected.sql`, uygulandı 2 Kasım 2026): "Aileye gönder" önce gidecekleri hedef hedef listeler (değişen hedef, program, rutin/görev taslağı, değişiklik önerisi), hepsi işaretli; işareti kaldırılan bekler (hedef/program ailede önceki gönderilmiş hâlinde, taslak taslak kalır). GAS ve "Aile görür" kapalı hedef listede çıkmaz. Aile yine tek bildirim alır; yeni bir şey yoksa bildirim gitmez. Program aileye yalnız gönderilmiş hedefleriyle görünür. | `care_plan_publish_selected(link, hold[])` |
| 5 | [P] | Uzmanım: plan hedefe göre gruplu (hedef → bu haftaki program → çocuğun rutini) ve rutin paketi (5.4). | `family_care_plan(link)`: `modules[].goal_ids`, `routines[]` |
| 6 | [K] | Ailede ekli rutin/görevi düzenlemek: **değişiklik önerisi** (saat, gün, tekrar; görev çıkarmak = `change_remove`; rutine görev eklemek = aynı `routine_group` ile yeni öneri). Rutin değişikliği her görev için ayrı satır, aynı `routine_group`. | `clinic_task_suggestions.kind = 'change'`, `target_task_id` |
| 7 | [P] | "Uzmanın değişiklik önerisi" kartı: **Uygula** → ParentApp aynı görevi günceller (`reminder`, `repeat_kind`, `repeat_days`, `recurring`, `end_date`); `change_remove` → görevin `end_date`'i bugün (başlangıcı ileride olan görev silinir); sonra öneri `accepted`. **Şimdilik değil** → `declined`. Yapılan adımlar, onaylar ve coin değişmez. | `tasks` update; öneri `status` |
| 8 | [S] | Karar uzmana bildirilir: "Değişiklik uygulandı / şimdilik uygulanmadı". | `suggestions_notify` |

Kurallar: Aile `draft` öneriyi görmez ve karar veremez. Paylaşım bitince taslaklar silinir. Eski ClinicApp sürümü öneriyi doğrudan `pending` ekler ve eskisi gibi tek tek bildirir. GameApp etkilenmez (rutin kartı görev alanlarından; saat değişince kendiliğinden güncel).

## 13a. Aileye "Çocuk ekle" kalsın mı? (değerlendirme, 26 Ekim 2026)

Öneri: **kalsın**, ama uzman davetiyle gelen ailede ayrı bir adım olmasın (yukarıda 6). Gerekçe: (1) ParentApp aile aboneliğiyle uzmansız da satılıyor; GameApp'ten gelen aile çocuğunu kendisi ekler; (2) kardeşler ve uzmana gitmeyen çocuklar; (3) uzman çocuk önerisini boş bırakabilir; (4) Joon da uzman daveti olsa bile ebeveynin "Manage Family" ile çocuk ekleyip silmesine izin veriyor. Uzman davetinde çocuk hazır gelir, ebeveyn yalnız kontrol edip onaylar; elle eklemede aynı ad uyarısı (6c).

## 14. Uzman doğrulama — seçenekler ve karar

Bugün uzman hesabı doğrulanmıyor; herkes "uzman" olarak kayıt olabilir. Şimdilik ParentApp'te uyarı + veli beyanı + sözleşme maddeleri (yukarıda, `hukuk_notlari.md` 3F–3H).

| # | Seçenek | Nasıl | Güç | Maliyet / efor |
|---|---|---|---|---|
| 1 | Uyarı + veli beyanı (bugün) | Davet ekranında uyarı ve onay kutusu, sürümlü kayıt | Zayıf (sorumluluğu ebeveyne yazar) | Yok |
| 2 | Belge yükleme + yönetici incelemesi | Uzman diploma / e-Devlet barkodlu mezuniyet belgesi ya da meslek kuruluşu üyelik belgesi yükler; yönetim panelinde ekip barkodu turkiye.gov.tr'de doğrular → "Doğrulanmış uzman" rozeti | Orta-güçlü | Düşük yazılım, kişi başı birkaç dakika inceleme |
| 3 | Kurum doğrulaması (Klinik paketi) | Vergi no + sağlık kuruluşu ruhsatı / MERSİS; fatura bilgisiyle eşleşme | Orta (kurumu doğrular, kişiyi değil) | Düşük |
| 4 | Kurumsal e-posta alanı | Klinik alan adlı e-postayla doğrulama | Zayıf-orta | Çok düşük |
| 5 | Ekip içi güven | Doğrulanmış sahibin ekip koduyla katılan üye "klinik tarafından eklendi" | Orta (sahibe bağlı) | Yok |
| 6 | Üçüncü taraf kimlik doğrulama (KYC) | Kimlik + canlı fotoğraf hizmeti | Kimliği güçlü, mesleği değil | Kişi başı ücret, yeni veri işleyen |
| 7 | e-Devlet ile giriş / resmî kayıt sorgusu | Kurumsal entegrasyon | En güçlü | Yüksek (başvuru, sözleşme) |

**Görünürlük (kullanıcı, 26 Ekim 2026):** özellik bayrağa bağlı: `clinician_verification`, **ilk sürümde KAPALI** (bayrak uzmana göre değerlendirilir: kişiye istisna açılan uzmanın rozetini aileler de görür; "Diğer" meslekte rozet "Uzman"). Kapalıyken başvuru başlatılamaz, gönderilemez, kovaya dosya yüklenemez. Kapalıyken ClinicApp'te "Belgeni yükle" satırı ve sayfası görünmez, sunucu başvuru almaz; ParentApp'te rozet de "Belgesi incelenmedi" etiketi de gösterilmez (yalnız uyarı + veli beyanı); aile yanıtlarında `verified_as` null döner. Açmak: yönetim paneli → Bayraklar → `clinician_verification` (önce kişiye istisnayla denenebilir). Karar hatırlatması `DURUM.md` Açık işler.

**Karar (kullanıcı, 26 Ekim 2026): seçenek 2, yarı otomatik** — `migrations/20261026050000_clinician_verification.sql` (uygulandı 26 Ekim 2026), Edge Function `clinician-verify`, meslek eşlemesi `veri/uzman_meslekleri.json`. Uyarı + veli beyanı (1) rozet olsa da kalır.

### 14.1 Akış

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | "Hesabını doğrula": meslek seç (BCBA ise BACB sicil no), e-Devlet'ten indirdiği **Yükseköğretim Mezun Belgesi** PDF'ini yükle (fotoğraf/tarama yok; BCBA'da belge isteğe bağlı). | `clinician_verification_start(meslek, bacb)` → `{id, upload_path}`; Storage `verify/<uzman>/<id>.pdf`; `clinician_verification_submit(id)` |
| 2 | [S] | Ön kontrol (birkaç saniye, kendi sunucumuzda, PDF metin katmanı): belge okunuyor mu, e-Devlet izi, mezuniyet, barkod, **ad** (hesap adı belgede mi), **bölüm** (meslek ↔ bölüm), **derece** (klinik psikolog: yüksek lisans/doktora; ön lisans lisans yerine geçmez). Yalnız kesin durumlar kendiliğinden ret: okunamayan belge, öğrenci belgesi, başka uzmanda **onaylı/askıda** barkod (bekleyen başvurudaki aynı barkod yalnız uyarı). Elle incelenen meslekler (hekim, diğer) ve BCBA kendiliğinden reddedilmez; altyapı hatası (indirme, PDF okuyucu) ret değildir, başvuru bekler. Barkod biçimi tireyle ayrılmış harf/rakam grupları ve en az bir rakam (düz sözcük barkod sayılmaz). Her başvuru bir kez kontrol edilir. Kişinin adı, kimlik numarası ve üniversite satırı saklanmaz (26 Ekim denetimi). | Edge Function `clinician-verify` (Verify JWT kapalı; oturumu kendisi doğrular) → `clinician_verification_autocheck` |
| 3 | Yönetici (support/owner, iki adımlı) | Panelde ön kontrol özeti + belge. Barkodu **turkiye.gov.tr/belge-dogrulama**'da sorgular, açılan asıl belgeyi yüklenenle karşılaştırır; BCBA'da **BACB sicili** (ad + sertifika no, durum etkin, disiplin kaydı). Şüphede kısa telefon. Onay ya da nedenli ret. Belge görüntüleme ve karar denetim kaydına yazılır. | `admin_verifications`, `admin_verification_open`, `admin_verification_decide`, `admin_verification_suspend` |
| 4 | [S] | Onayda belge dosyası silinir (panel kovadan siler), yalnız özet kalır (üniversite, bölüm, derece, mezuniyet yılı); ön kontrolün çıkardığı ayrıntı da silinir, barkod çakışma denetimi için kalır. Kendiliğinden reddedilen, geri çekilen (yeniden başlatılan) ve hesabı silinen başvuruların dosyaları `storage_trash` kuyruğuna girer, `clinician-verify` her çağrıda kovadan siler (26 Ekim denetimi). Gönderimden sonra ad değişirse onay verilemez. Uzmana `verification_approved` / `verification_rejected` (neden + açıklama) / `verification_suspended`. | `clinician_verifications.summary`, `clinicians.verified_profession`, `verified_at` |
| 5 | [P] | Davet ekranı, açılış sayfası ve Uzmanım'da **"Belgesi incelendi: Klinik psikolog"** rozeti; rozet yoksa "Belgesi incelenmedi" etiketi. Uyarı ve veli beyanı her durumda kalır. | `verified_as`: `clinic_invite_open`, `claim_clinic_invite`, `clinic_invite_preview`, `family_pending_invites`, `family_clinic_links` |
| 6 | [S] | Uzman adını değiştirirse rozet düşer (belgedeki adla eşleşme bozulur; yalnız büyük/küçük harf ya da boşluk değişikliği düşürmez), yeniden yükler. BCBA yılda bir yeniden bakılır (`recheck_at`). Şikâyette rozet askıya alınır. | tetikleyici `clinicians_verified_name_guard` |

### 14.2 İnceleme kriterleri ve teyit kaynakları

| Meslek | Aranan | Belge | Teyit kaynağı |
|---|---|---|---|
| Psikolog | Psikoloji lisans | e-Devlet Yükseköğretim Mezun Belgesi (barkodlu PDF) | turkiye.gov.tr/belge-dogrulama (barkod) |
| Klinik psikolog | Psikoloji lisans + klinik psikoloji yüksek lisans/doktora | Aynı (iki derece) | Aynı |
| PDR, ergoterapist, dil ve konuşma terapisti, özel eğitim öğretmeni, çocuk gelişimci | İlgili bölüm lisans | Aynı | Aynı |
| Davranış analisti (BCBA) | Etkin BACB sertifikası | BACB sicil no (+ mezun belgesi) | BACB herkese açık sicil sorgusu (bacb.com) |
| Yurt dışı mezun | Türkiye'de denklik | YÖK denklik belgesi | Barkodluysa e-Devlet, değilse elle |
| Çocuk ve ergen psikiyatristi | Tıp + uzmanlık | Mezun belgesi + uzmanlık belgesi | Uzmanlık için herkese açık sorgu bulunamadı: elle |

Ret nedenleri (`veri/uzman_meslekleri.json` `reasons`): `name_mismatch`, `barcode_invalid`, `program_mismatch`, `degree_mismatch`, `unreadable`, `student_doc`, `duplicate`, `bacb_inactive`, `name_changed`, `other`.

Sınırlar: e-Devlet sorgusu belgenin gerçek olduğunu gösterir, yükleyenin o kişi olduğunu değil (ad eşleşmesi + gerektiğinde telefon). Sağlık Bakanlığı diploma tescili / meslek icra yetkisi için herkese açık sorgu bulunamadı; yetki sorumluluğu uzman sözleşmesinde (`hukuk_notlari.md` A10). Rozet "Belgesi incelendi" der, "doğrulandı" demez (A11). Ön kontrol bir örnek belgeyle denendi; ilk gerçek belgelerde e-Devlet düzeni kontrol edilip gerekirse kurallar güncellenir.

## 15. Uzman karşılama anketi (`migrations/20261027100000_clinician_survey.sql`, uygulandı 27 Ekim 2026; kullanıcı isteği 27 Ekim 2026)

Kullanıcı Joon Health'in kayıt sonrası ekranlarını örnek gösterdi; Joon yalnız referanstır (metin ve düzen kopyalanmaz). Amaç: uzmanı tanımak (meslek, ihtiyaç, geliş nedeni), ilk adımı ona göre önermek ve ürün kararları için toplu veri.

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Kayıttan sonraki **ilk girişte bir kez** (cevap ya da "geç" kaydı yoksa) tam ekran: "Hoş geldin, <ad>". **Atlanamaz** (kullanıcı kararı 28 Ekim 2026: "Şimdilik geç" kalktı; her soru yanıtlanır). Eski "geç" kayıtları (`skipped`) yeniden sorulmaz. | `clinician_survey_me()` → null ise gösterilir |
| 2 | [K] | 1/4 **Mesleğin ne?** (tek seçim, 15 seçenek; doğrulama meslekleri + oyun terapisti, sanat/müzik/drama terapisti, aile danışmanı, okul rehber öğretmeni, öğrenci/stajyer). Kurumsal görünüm (28 Ekim 2026): grup başlıkları altında radyo listesi (Ruh sağlığı · Gelişim ve rehabilitasyon · Eğitim · Oyun ve dışavurumcu terapiler · Diğer; `veri/uzman_anketi.json` `groups` / `group`, yalnız görünüm) | — |
| 3 | [K] | 2/4 **Ailelerle çalışırken en çok neyde zorlanıyorsun?** (çoklu, 6) · 3/4 **Hangileri işine en çok yarar?** (çoklu, 6) | — |
| 4 | [K] (yalnız klinik sahibi) | 4/4 **Seni ClinicApp'e ne getirdi?** (tek, "en önemli nedenin"): denemek · bir aileyi bağlamak · kliniğimin ekibine katılmak · kliniğimde tek düzen. **Tek seçim bilinçli:** "Hazırsın" ekranındaki ilk adım (davet / ekip kodu / paketler) bu yanıta göre seçilir; çoklu seçimde tek ilk adım belirlenemez. Ekip üyesine sorulmaz (kodla katıldı). | `clinician_survey_save(meslek, zorluklar[], özellikler[], neden, geçti)` |
| 5 | [K] | **"Hazırsın"** ekranı nedene göre ilk adım: denemek / aile → "İlk aileni davet et" (davet penceresi açılır); ekip → ekip kodu kutusu + "Ekibe katıl" (`clinic_join_team`); tek düzen → "Paketleri gör"; her zaman "Panele geç". Ardından (davet/paket seçilmediyse) ilk kullanım rehberi. | — |

Seçenekler: `veri/uzman_anketi.json` (anahtar + Türkçe ad + simge; ClinicApp kopyası `src/data/survey.json`). Cevaplar **aileye ve diğer uzmanlara görünmez**; tablo doğrudan okunamaz (yalnız RPC). Yönetim paneli yalnız **toplam sayılar** görür: `admin_kpi_clinician_survey(gün)` → `{answered, skipped, profession{}, challenges{}, features{}, intent{}}` (kişi listesi yok). Hesap silinince cevap da silinir. Olaylar: `survey.done` (`intent`, `profession`), `survey.skip` (`step`).

## 13. Kim kimi nasıl ekler — güncel tablo (26 Ekim 2026)

| Kim | Kimi / neyi | Nasıl | Geçerlilik | Durum |
|---|---|---|---|---|
| Ebeveyn | İkinci ebeveyn | ParentApp Aile › + › Ebeveyn › davet kodu; diğeri "Kodun var mı?" ekranı ya da Aile › Hesap › "Kod gir" | 6 karakter, 15 dk | uygulandı |
| Ebeveyn | Çocuğun cihazı | Aile › çocuk › "Giriş kodu üret"; GameApp'te yazılır | çocuk başına, 15 dk, tek kullanım | uygulandı |
| Uzman | Aile | ClinicApp "Aileyi davet et" → **sistem e-postası** (kod + adımlar) + bağlantı (alan adı gelince). Kullanıcı kararı 28 Ekim 2026: süreç sistem üzerinden — davet metnini kopyalama / e-posta uygulamasında açma yok; kod yalnız e-posta gönderilemezse yedek olarak görünür. Davet penceresindeki taslak takip planı **gizli** (sunucu `invite_code` taslağını destekler; DURUM HATIRLATMA) | **3 gün** (bağlanınca 30 gün içinde çocuk paylaşımı) | e-posta: uygulandı `20261027000000` (bölüm 10) |
| Ebeveyn | Uzman → çocuk | Kayıtta bağlantı/e-posta ile ya da sonradan kod/bağlantıyla uzman tanımlanır; uzmanın önerdiği çocuğu kontrol edip düzeltir, uyarıyı okuyup "Onayla ve paylaş" (çocuk o an oluşur); istemezse reddeder | — | uygulandı (bölüm 10) |
| Ebeveyn | Aynı uzmana başka çocuk | Uzmanım'da "Ekle" (kodsuz) | — | uygulandı |
| Ebeveyn | Yeni uzmana geçmiş | Paylaşırken ya da sonradan "Önceki uzmanın kayıtlarını paylaş" | geri alınabilir | uygulandı (bölüm 11) |
| Ebeveyn / uzman | Paylaşımı durdurma | "Paylaşımı durdur" | hemen | uygulandı |
| Klinik sahibi | Ekibe uzman | "Ekibe uzman davet et"; yeni uzman kayıtta "Kodum var" ya da Ekip bölümünden | 8 karakter, 15 dk; koltuk sınırı; Bireysel pakette yok | uygulandı |
| Klinik sahibi | Ekip üyesine danışan | Danışan › "Ekip erişimi" (aç/kapat, sorumlu yap) | — | uygulandı |
| Ekip üyesi | Aile | Kendi davet e-postası; davet ettiği aileyi sahip de görür (sahip e-postayı yeniden gönderebilir) | 3 gün | bölüm 10 |

---

> **ParentApp penceresinin önerileri (22 Ekim 2026, uygulanmadı).** Bölüm numaraları `P` ile başlar.

## 16. ParentApp ilk kurulum ve tanışma soruları (`migrations/20261027120000_parent_setup_intake.sql`, uygulandı 27 Ekim 2026)

Kullanıcı kararları (27 Ekim 2026): önce kayıt, sonra sorular; akış kısaltıldı (ad kayıtta alınır, ayrı "ebeveyn bilgileri" ekranı yok; eşinin koduyla katılan çocuk sorularını görmez); yanıtlar yönetim panelinde **kişi bazlı** (avukat onayı canlıdan önce); tanı ve ilaç soruları **isteğe bağlı** (rıza sürümü `saglik-yanit-v1`).

**Web (4 Kasım 2026, kullanıcı isteği):** aynı akış web'de de çalışır. ParentApp + Pofi Adası tanıtım sayfası (`parent-app/site/`, kök) "Hesap oluştur" → `/app/#kayit` (adım 2'den başlar), "Giriş yap" → `/app/#giris`. `/app/` ParentApp'in web derlemesidir (giriş, kayıt, kurulum, cihaz bağlama QR'ı büyük ekranda); web'de satın alma ve bildirim yok, üyelik uygulamadan başlatılır. E-posta bağlantıları web'de `/app/`e döner (Supabase Redirect URLs'e `https://<alan adı>/app/**`). Yayın alan adı ve App Store yayınıyla birlikte (web'den açılan hesapta deneme kayıtta başlar).

| # | Ekran | Ne olur | Veritabanı |
|---|---|---|---|
| 1 | Açılış | "Başla" / "Hesabım var" (→ giriş). Marka tasarımı sonra. Web'de tanıtım sayfasından gelince doğrudan 2 ya da giriş. | — |
| 2 | Davet kodu? | "Davet kodun var mı?" (3 Kasım 2026'dan beri: uzmandan ya da seni davet eden bir aileden) Hayır → kayıt · Evet → "Davet kodunu yaz" → kayıt · "Hesabım var" → giriş. Kodun türü kendiliğinden anlaşılır: 6 karakter uzman daveti, 8 karakter aile davet kodu (19 "Aile davet et"; kurulumun başında kullanılır, sonuç pencereyle söylenir). Davet bağlantısıyla gelen bu soruyu görmez. | kayıt meta `clinic_invite` (kod ya da bağlantı anahtarı); aile kodu `redeem_guest_pass` |
| 3 | Kayıt | Ad, e-posta, şifre (bugünkü ekran). | `handle_new_user` (davet aileye bağlanır) |
| 4 | Aile soruları | Giriş ekranı ("Seni ve aileni tanıyalım", ne kadar sürer, ne işe yarar), ana hedef, diğer hedefler (ana hedef burada tekrar edilmez), bizi nereden duydun, kısa giriş, üç sıklık sorusu (araya bir "yalnız değilsin" ekranı). Her yanıt hemen kaydedilir. | `intake_answers` (`child_id` boş) |
| 5 | Sıradaki | "Çocuğunu ekle" · "Kodla aileye katıl". | — |
| 6a | Çocuk ekle | Uzman daveti bekliyorsa davet ekranı (öneri dolu, uyarı + veli beyanı, `family_accept_invite`); yoksa ad, cinsiyet, doğum günü, simge ya da ebeveynin fotoğraflarından fotoğraf (`photo:<yol>`, durumlar.md). | `children` (+ Storage `mail/<aile>/avatars/`) |
| 7a | Çocuk soruları | Çocuğu ekleyen ebeveyn yanıtlar (düzen, tanı*, ilaç*, uzmanlar, geçen hafta 6 sıklık sorusu, hedefler, ilgi alanları, motive edenler). *İsteğe bağlı, rıza satırı. | `intake_answers` (`child_id`) |
| 8a | Çocukların | Adlar (düzenlenebilir), "Sonra başka çocuk da ekleyebilirsin", Devam · Başka çocuk ekle (6a'ya döner). | `children.name` |
| 9 | Hazırlanıyor | ~1,5 sn "Her çocuk için odak alanlarını belirliyoruz". | — |
| 6b | Kodla katıl | Tek kutu (`CodeEntry`: önce uzman daveti, değilse `join_family`); uzman koduysa 6a'nın davet ekranına geçer. Aileye katılan 7a–8a'yı görmez. | `join_family` |
| 10 | Seni nasıl görsün? | Takma ad + ebeveyn avatarı (oyunda çocuğun gördüğü). | `profiles.nickname/avatar` |
| 11 | Tanıdık mı? ×3 | Üç cümle + sade çizim, Evet/Hayır. | `intake_answers` (`relate_*`) |
| 12 | Bitti | `parent_setup_complete()`; uygulamaya girilir. Sonra (planlandı): ekranın altında tek seferlik tanıtım teklifi. | `profiles.setup_completed_at` |
| 13 | Çocuğun cihazını kur | Uygulamada ilk iş: çocuk seç → "Başka cihaz" (Pofi Adası indirme bağlantısı paylaş + giriş kodu QR/yazılı) · "Bu cihaz" (App Store) · "Kurdum" / "Sonra yaparım". | `create_invite_code('child')` |
| 14 | Rehber ve İlk adımlar (3 Kasım 2026, kullanıcı kararı; benchmark: kısa ve kullanıcının açtığı turlar daha çok bitiriliyor) | Önce sorulur: "ParentApp nasıl çalışır?" → **Göster** / **Şimdi değil**. Göster → kısa tur (3 kart: görev ver → çocuk oyunda "Yaptım" der, ebeveyne bildirim → onayla, coin + Güneş Taşı). Aile › Hesap › "Nasıl kullanılır?" tam turu açar (+ ödüller, mesajlar, gelişim, sen de katıl, uzmanım). Ben'de **İlk adımlar** kartı (hesabın ilk 30 günü): çocuğunu ekle · oyuna bağla · ilk görevi ver · ilk onayı yap · bir ödül belirle; uzmanını bağla isteğe bağlı. Satır ilgili ekranı açar, yapılınca kendiliğinden işaretlenir; beşi bitince kaybolur. Başlıktaki ok kartı daraltır/açar (3 Kasım 2026, kullanıcı isteği: çarpı yok, kalan adımlar hep görülebilsin). Rehber kartlarında ilk kart dışında geri tuşu. | — (yalnız istemci; ödül sayısı `rewards`) |

Kurallar: Yanıt satırı kişi + çocuk + soru başına tek (`unique nulls not distinct`); her ebeveyn kendi yanıtını yazar, aile üyeleri okur, başka aile göremez. Uzman bu sürümde yanıtları görmez (ileride ebeveyn izniyle; paylaşım onay metni sürümü değişir). Yönetim paneli: `admin_intake(aile, gerekçe)` kişi bazlı (support/owner, denetim kaydı), `admin_intake_summary(gün)` yalnız sayılar. Bu göçten önceki ebeveynler kurulumu yapmış sayılır (`setup_completed_at` dolu).

## 18. Ebeveyn görevleri, ebeveynin Güneş Taşı, hediye dükkânı (`migrations/20261027140000_parent_tasks_gifts.sql`, uygulandı 27 Ekim 2026; kullanıcı isteği 27 Ekim 2026)

Amaç: ailece ya da yalnız ebeveynin yapacağı görevler; ebeveyn de taş kazanır ve taşla çocuğuna oyunda hediye gönderir (Joon "parent quests + gift shop" örneği, kopya değil).

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Görev ayrıntılarında çocukların altında **Ebeveynler (isteğe bağlı)**: kendini ya da ailedeki diğer ebeveyni seç, zorluk (Kolay/Orta/Zor = 1/2/3 taş). Çocukla birlikte seçilirse ailece görevdir; yalnız ebeveyn de olabilir (çocuk ataması yok). | `parent_assignments` (aile yazar; yalnız ailedeki ebeveyne) |
| 2 | [P] | Görevler'de ebeveyn avatarları görevde görünür; bana atanan görevde yuvarlak **Yaptım** düğmesi (bugün − 7 … bugün + 1). Yapan ebeveynin avatarında ✓. Süzgeçte **Ben** (bana atananlar). Ebeveyn görevi incelenmez. | `parent_task_done(görev, gün, yapıldı)` → `parent_completions` + `parent_stone_ledger` (`task` / `task_undo`) |
| 3 | [O] | Oyun değişmez: çocuğun görevi yine `child_tasks`'tan (ailece görevde yalnız çocuk satırı). | — |
| 4 | [P] | Aile › Ben › Genel: **Güneş Taşım** (kullanılabilir, bu hafta kazanılan / hediye) → **Geçmiş** (Güneş Taşı hesabı: bu hafta / bu ay / tümü, tarih, açıklama, taş, kalan) ve **Hediye dükkânı**. Aile › çocuk › Genel: **Güneş Taşı · N › Hesap** (çocuğun defteri: görev onayı, ödül, düşülen, hedef). Gelişim ayrıntıları Gelişim sekmesinde kalır. | `parent_stone_ledger`, `sun_stone_ledger` (aile okur) |
| 5 | [P] | Hediye dükkânı: çocuk seçilir, eşya (Giyecek / Ev / Süs), isteğe bağlı not (≤ 140) → **Hediye gönder**. Taş yetmezse düğme "Taş yetmiyor · N eksik". | `gift_items` (fiyat), `send_gift(çocuk, eşya, not)` → `child_gifts` + `parent_stone_ledger` (`gift`) + çocuğa `gift` bildirimi |
| 6 | [O] | Oyun her eşitlemede bekleyen hediyeleri alır; posta kutusunda paket kartı (kimden, eşya, not). Çocuk "Aç"a basınca eşya envantere ve kayda yazılır, sonra kapatılır; kapatma gitmezse sonraki eşitlemede yeniden denenir, eşya iki kez eklenmez. Tanınmayan `item_id` kapatılmaz ve gösterilmez. Hediye seviye kilidini aşar (`ekonomi.md` 5C). Oyun `gift` bildirim satırını okumaz; haber `child_gifts_pending`'den. Eski sürüm hediyeyi görmez; kayıt bekler. (game-app 2bd61af) | `child_gifts_pending()`, `claim_child_gift(id)` |

Olaylar (ParentApp): `task.parent_done` (`on`), `gift.send` (`item`, `stones`).

## P9. Kod süresi ve "yeni kod" (öneri, 21 Ekim 2026)

| # | Kim | Ne olur | Nerede |
|---|---|---|---|
| 1 | [P]/[K] | Kod üretilir; ekranda kalan süre (15:00'dan geri sayım) görünür. | `create_invite_code`, `clinic_create_invite` → `expires_at` |
| 2 | [P]/[K] | Süre bitince kod soluklaşır, "Süresi doldu" + **Yeni kod al** düğmesi. | uygulama |
| 3 | Kodu giren | Süresi dolmuş/kullanılmış kodda açık metin: "Kodun süresi doldu… Yeni kod iste." | `hint`: `code_expired` / `code_used` (durumlar 11) |
| 4 | [S] | 15 dakikada 10 hatalı denemeden sonra 15 dakika engel (429). | `code_attempts` |
| 5 | [K] kayıt | ClinicApp kayıt ekranı ekip kodunu hesap açmadan önce `clinic_team_code_status(kod)` ile denetler (girişsiz çağrılır). | — |

## P10. Ebeveyn ↔ çocuk mesajları (öneri, 21 Ekim 2026)

| # | Kim | Ne olur | Nerede |
|---|---|---|---|
| 1 | [P] | Aile › Mesajlar › çocuk: yazı, fotoğraf, sesli mesaj, çıkartma. | `messages` INSERT (fotoğraf/ses önce `mail` kovasına) |
| 2 | [S] | Çocuğa bildirim (+ push): "Yeni mesajın var". | `messages_notify` |
| 3 | [O] | Oyunda mesaj kutusu: `child_messages()` ile sohbet; açınca `mark_messages_read()`. Fotoğraf/ses için `storage.from('mail').createSignedUrl(media_path)`. Realtime: `messages` INSERT (`child_id=eq.<ben>`). | — |
| 4 | [O] | Çocuk yazı (≤ 500) ya da çıkartma ile yanıtlar. | `child_send_message('text'\|'sticker', body)` |
| 5 | [S] | İki ebeveyne bildirim: "<Çocuk> mesaj gönderdi". | `messages_notify` |
| 6 | [P] | Sohbet açılınca çocuğun mesajları okundu. Listede okunmamış sayısı. | `mark_messages_read(child_id)` |

Sınırlar: çocuk saatte 60, ebeveyn 200 mesaj; çocuk dosya gönderemez; kardeşler birbirinin sohbetini görmez; uzman mesajları göremez.

## P11. Ödüller ve Güneş Taşı (öneri, 21 Ekim 2026)

| # | Kim | Ne olur | Nerede |
|---|---|---|---|
| 1 | [P] | Görevler › + › **Ödül**: önerilen ödüllerden seçer ya da kendi ödülünü oluşturur (tür: eşya/etkinlik ya da değiş tokuş; taş fiyatı; hangi çocuklar; simge; ad). | `rewards` |
| 2 | [S] | Onaylanan görev taş verir (1/2/3). | tetikleyici `completions_stone` |
| 3a | [P] | Ödülü doğrudan verir (değiş tokuşta kaç kez) → taş düşer, çocuğa bildirim. | `give_reward(çocuk, ödül, adet)` |
| 3b | [O] | Çocuk oyunda ister (özellik oyunda birkaç seviye sonra açılır; seviye GameApp verisinde, sunucu seviye denetlemez) → ebeveynlere bildirim → [P] onaylar/reddeder. | `request_reward(ödül, adet)` → `{request_id, status, first}` → `decide_reward_request(istek, onay, not)` |
| 3c | [S → P] | **İlk talep bilgisi** (kullanıcı kararı, 24 Ekim 2026; göç `20261024100000_welcome_coins_first_reward`, uygulandı 24 Ekim 2026): çocuğun oyundan gelen **ilk** isteğinde (önceki hiçbir `source='child'` isteği yokken; durum fark etmez; ebeveynin doğrudan verdiği ödül sayılmaz) bildirim yine `kind='reward_request'`, ama `data.first = true` ve başlık "İlk ödül talebi: <ad> bir ödül istiyor". Yalnız bir kez; sonraki isteklerde `first` yok. ParentApp bildirimde ve istek kartında **"İlk ödül talebi"** etiketini gösterir (ör. "Nazlı ilk kez ödül istedi"). Oyun yanıttaki `first` ile çocuğa "ilk isteğin gönderildi" diyebilir. | `notifications.data.first`; `request_reward` yanıtı `first` |
| 4 | [P] | Bir ya da birkaç çocuk seçip taş düşer (ceza), isteğe bağlı nedenle → çocuğa bildirim. | `deduct_sun_stones(çocuk, adet, neden)` (çocuk başına) |
| 5 | [O] | Bakiye ve hareketler: `sun_stone_balance(ben)`, `sun_stone_ledger` (kendi satırları), `rewards` (kendine açık olanlar), `reward_requests` (kendi). | — |

## P12. Abonelik (öneri, 21 Ekim 2026)

| # | Kim | Ne olur | Nerede |
|---|---|---|---|
| 1 | [P] | Kayıt + e-posta doğrulama → 7 günlük deneme başlar. Görevler ekranında "Deneme: N gün kaldı". | `families.trial_started_at`, `family_access()` |
| 2 | [P] | Deneme bitince uygulama açılışta üyelik ekranını gösterir (Aylık / Yıllık). "Şimdilik ücretsiz devam et" seçilebilir. | uygulama |
| 3 | [P] | Satın alma mağazada (App Store); RevenueCat (karar 22 Ekim 2026) olayı sunucuya iletir; sunucu güncel durumu RevenueCat'ten yeniden okur (olay sırası, "geri yükle" ile hesap değişimi). ParentApp RevenueCat'e Supabase kullanıcı kimliğiyle giriş yapar (`app_user_id`). Elle verilen premium (`source` manual/web) mağaza aboneliği bitince ezilmez. ParentApp (2 Kasım 2026, `react-native-purchases` 10.16.x): ilk oturumda `configure(appUserID)`, kullanıcı değişince `logIn`, çıkışta `logOut`; entitlement `premium`, offering `default`; fiyat mağazadan. Satın alma / geri yüklemeden sonra `family_access()` birkaç saniye içinde yeniden okunur; webhook gelene kadar mağazadaki etkin üyelik kısıt göstermez (sunucu kısıtları webhook'la açılır). | `billing-webhook` → `set_family_subscription` |
| 4 | [S] | Ücretsiz planda: 3 etkin görev, 1 çocuk; ödül/taş düşme/ebeveyn mesajı/davranış kaydı kapalı. Onay, oyun, uzman paylaşımı açık. | tetikleyiciler (`hint = premium_required`) |
| 5 | [P] | Aile › Hesap › Üyelik: durum, plan, yenileme tarihi, "Satın alımları geri yükle", "Aboneliği yönet" (App Store). | uygulama |
| 6 | [P] | **Aile davet et** (önce misafir kartı, 28 Ekim 2026; 3 Kasım 2026 güncellendi, `migrations/20261028120000_guest_pass.sql`, uygulandı 3 Kasım 2026): davet edilen yeni ailenin denemesi 7 yerine 14 gün; o aile mağazadan abone olunca davet eden 1 ay kazanır (yılda en çok 12). Ayrıntı 19. | `families.trial_days`, `guest_passes` |

Anahtar: `app_config.billing.enforce = false` iken (bugün) kimse kısıtlanmaz; ödeme bağlanınca açılır.

## 17. Yasal metin onayı ve KVKK başvurusu (`migrations/20261027200000_legal.sql`, uygulandı 27 Ekim 2026; metinler `hukuk/`)

| Adım | Kim | Ne | Sunucu |
|---|---|---|---|
| 1 | [P] / [K] | Kayıt ekranında koşullar için onay kutusu ("Kullanım Koşulları'nı okudum, kabul ediyorum"; işaretlenmeden hesap açılmaz) ve altında **kutusuz** aydınlatma satırı ("Kişisel verilerinin nasıl işlendiğini Aydınlatma Metni'nde anlatıyoruz"); bağlantılar `legal` adresine. Aydınlatma onay değil bilgilendirmedir; gösterildiği kaydedilir. Açık rızalar bu ekrana konmaz. Metinler `hukuk/50-uygulama-ici-metinler.md`. | kayıttan hemen sonra `legal_accept(app, legal_pending(app))`. E-posta doğrulaması yüzünden oturum kayıtta açılmıyorsa (ClinicApp): işaretlenen sürümler kayıt bilgisine `legal: {anahtar: sürüm}` yazılır (sürümler oturumsuz `legal?format=json` listesinden), ilk girişte `legal_pending` içinden sürümü eşleşenler `legal_accept` ile sessizce kaydedilir; eşleşmeyen kalırsa adım 2 ekranı |
| 2 | [P] / [K] | Her açılışta (ve ön plana gelince) `legal_pending(app)`; boş değilse "Koşullarımız güncellendi" ekranı (`summary` + bağlantı) → kabul etmeden devam edilmez; "Hesabımı sil" seçeneği görünür. **Kısa biçim (kullanıcı kararı 28 Ekim 2026):** büyük sayfa ve metin başına kart yok — küçük kart, tek satır (metin adları bağlantı), sözleşmeler için tek kutu, aydınlatma kutusuz; `summary` yalnız "Kısaca neler değişti?" açılır kutusunda. Kayıt ekranında da tek küçük satır ("Hizmet Sözleşmesi ve Veri İşleme Eki'ni kabul ediyorum. Aydınlatma · Gizlilik"). | `legal_accept` |
| 3 | [P] | Çocuğu oyuna bağlamadan önce (kod/QR göstermeden) `legal_pending('child')` boş değilse veli GameApp koşullarını ve çocuk aydınlatmasını çocuk adına onaylar. Kısa kart (28 Ekim 2026): iki cümle + tek kutu + aydınlatma bağlantısı; veli onayı ParentApp'in yeniden onay kartında da ayrı kutudur. ParentApp'te "Yasal ve gizlilik" Aile › Hesap'ta tek satır. | `legal_accept('child', …)` |
| 4 | [O] | Oyun ebeveyn kapısında "Bilgi": çocuk dilinde kısa not (`aydinlatma-cocuk` içindeki çocuk bölümü) + gizlilik bağlantısı. Çocuk onay vermez. | — |
| 5 | [P] / [K] | **Tek başlık (kullanıcı kararı 28 Ekim 2026):** Ayarlar › **Yasal ve gizlilik** — tek sayfada `legal_documents_for(app)` listesi (sürüm, onay tarihi) ve aynı sayfadan KVKK başvurusu formu (tür + açıklama) → `kvkk_request_create`; "Başvurularım" `my_kvkk_requests`. Ana ekranda ayrı ayrı yasal bağlantı yok; yeniden onay ve üyelik duvarı ekranlarının altında tek "Yasal ve gizlilik" bağlantısı. Abonelik satın alma ekranındaki sözleşme + gizlilik bağlantıları (App Store kuralı) kalır. | — |
| 6 | Yönetim paneli | Hukuk › KVKK başvuruları (30 gün), e-postayla gelenleri kayda alma; Hukuk › Yasal metinler › Yayımla (avukat onayından sonra). | `admin_*` |

## 19. ParentApp: Ben ve Uzmanım sekmeleri, uzman bağla, telefon, aile davet et (kullanıcı isteği 28 Ekim 2026; Joon "Me / Care" örnekleri, kopya değil)

Sekmeler: **Bugün** (ana sayfa, ev simgesi; rota adı `Ben`; kullanıcı kararı 3 Kasım 2026, benchmark Headspace/Cozi "Today", Apple/Google: simgeler ya hep yazılı ya hep yazısız) · **Uzmanım** (simge: artısız çanta) · Görevler · Gelişim · Aile. İnceleme ayrı sekme değil, Ben › "Onay bekleyen" kartından açılır (bildirim `task_done` da oraya gider). Veritabanı yalnız aile daveti için değişir (`migrations/20261028120000_guest_pass.sql`, uygulandı 3 Kasım 2026); geri kalanı mevcut işlevlerle.

**Ben:** onay bekleyen sayısı → İnceleme (bekleyen yoksa kart beyaz/gri, varsa yeşil; 3 Kasım 2026) · "Aile davet et" kartı (X ile kapanır, sağ üstte hediye simgesi olarak kalır) · "Seni bekleyenler" (3 Kasım 2026'ya kadar "Senin görevlerin"; uzmanın bekleyen daveti, uzmanın programındaki bugünkü uygulamalar, uzmanın görev önerileri, eksik tanışma soruları; her satır ilgili ekranı açar; boşsa bölüm görünmez; ebeveynin kendi görevleri Bugünün ilerlemesi › Ben satırında) · "Programına devam et" (yalnız takip planında etkin uygulama varsa; bu hafta kaç gün) · "Bugünün ilerlemesi" (ebeveyn **Ben** + her çocuk, %; dokununca o kişinin bugünkü görevleri; görevi yoksa "Görev ekle"; Ben yanında ⓘ: birlikte yapılan görevlere kendini de ekle, Güneş Taşı kazan › taşlarla çocuğuna oyunda hediye gönder) · hızlı düğmeler Görev ver / Ödül / Davranış kaydı (defter simgesi) · en altta "ParentApp'i tanı" (rehber). Ödül ekranı ilk açılışta (ve ⓘ ile) 3 kartlık "kullanıyormuş gibi" tur: Güneş Taşı görevden gelir → ödül ekle → ödülü ver (son kartta coin/taş yasal notu, hukuk/50 §8). Geniş ekranda (yatay iPad) iki sütun.

**Uzmanım:** uzman bağlıysa sekme **doğrudan uzmanın sayfasıyla** açılır (3 Kasım 2026, kullanıcı isteği): geri düğmesi yok, sağ üstte **"Uzman bağla"**; birden çok uzmanda üstte uzman seçici (bekleyen iş sayısıyla); bekleyen davetler sayfanın başında; altta acil durum notu. Ana sayfadaki uzman satırları sekmeyi o uzmanla açar. Uzman yoksa: bekleyen davetler, "Uzman bağla", "Uzmanına anlat". Uzman sayfası: bugün yapılacaklar (etkin uygulamalar "bugün uyguladım" kutusuyla → `care_module_logs`; davranış kaydı), çocuk başına **program** (takip planı: hedefler + aile programı = uzmanın verdiği eğitimler; ilerleme bu hafta uygulanan gün / 7), görev önerileri (kabul/ret, 5.4), paylaşılan çocuklar (geçmiş aktarımı aç/kapat, paylaşılmayan çocuğu ekle). Sağ üst ayar → **Uzmanı yönet**: çocuğu uzmandan ayır (`revoke_clinic_link`) ya da uzmanı kaldır (bütün paylaşımları `revoke_clinic_link`); uzman yeni veriyi göremez, aldığı notlar onda kalır. Yapay zekâ asistanı yok (şimdilik).

**Uzman bağla** (Uzmanım, davet bağlantısı, kurulum):

| Adım | Kim | Ne | Sunucu |
|---|---|---|---|
| 1 | [P] | "Uzmanından davet kodu aldın mı?" **Evet** → kod (6 karakter; bağlantıyla gelindiyse hazır) → aynı ekranda uzman kartı ve **"Bu kimin uzmanı?"**: ailedeki çocuklar + uzmanın önerdiği yeni çocuk (düzeltilebilir). **Hayır** → "Uzmanına anlat" paylaşım metni, "Şimdilik geç". | `claim_clinic_invite` (10 adım 5b) |
| 2 | [P] | Paylaşılanlar notu, zorunlu uyarı + veli beyanı (önceden işaretli değil), önceki uzman kayıtları (açık rıza, isteğe bağlı) → "Uzmanla bağlan". | `family_accept_invite` (10 adım 6–6d; onay sürümleri değişmedi) |
| 3 | [P] | Bayrak `parent_sms_verify` açıksa ve hesapta numara yoksa: **telefon numarası** (ülke kodu, varsayılan +90) → SMS ile 6 haneli kod → doğrula. "Şimdilik geç" her adımda. Sağlayıcı yoksa adım kendiliğinden geçilir. | Supabase Auth `updateUser({phone})` + `verifyOtp(phone_change)` → `auth.users.phone` |
| 4 | [P] | "Hesaplar başarıyla bağlandı" + (kurulum dışında) yeni çocuğun tabletini bağlama. | — |

Davetle gelen yeni aile (bağlantı ya da kayıttan önce yazılan kod): kurulum tanışma sorularıyla değil "Uzman bağla" ile başlar. Bağlanınca (kullanıcı kararı 3 Kasım 2026; benchmark NN/g: kısa, atlanabilir, nedeni söylenen sorular) **"Aileni tanıyalım"** (yaklaşık 3 dakika) → **Başlayalım**: aile soruları → her çocuğun soruları → "seni nasıl görsün" → tanıdık mı → cihaz kurulumu; **Sonra**: doğrudan "seni nasıl görsün". Böylece sorular uygulama rehberinden önce biter. Yanıtlanmayanlar Ben'de **"Tanışma sorularını tamamla"** satırı olarak kalır (aile + yanıtı olmayan çocuklar; kurulumdaki ekranların aynısı). Olay `intake.invited` (`start`). Davet ekranı kapatılırsa kurulum her zamanki gibi sürer. Telefonla iletişim (uzmanın SMS hatırlatması) henüz yok: numara yalnız doğrulanıp saklanır; SMS gönderimi ayrı karar (DURUM hatırlatması).

**Aile davet et** (`migrations/20261028120000_guest_pass.sql`, uygulandı 3 Kasım 2026; önce "30 günlük misafir kartı", 3 Kasım 2026 kullanıcı kararıyla ödemeye bağlı davet ödülü; benchmark: YNAB ve Babbel'de iki taraf da 1 ay, yalnız davet edilen ödeyince; YouTube Premium / Cineworld 12 sınırı; Headspace / Calm tek taraflı misafir geçişi. Apple: davet ödülüne izin var (3.2.2(x)), sahte davet yasak (5.6.3), ödeme yapan aboneye süre yalnız Apple teklif koduyla verilebilir):

| Adım | Kim | Ne | Sunucu |
|---|---|---|---|
| 1 | [P] | Ana sayfa › "Aile davet et" kartı ya da hediye simgesi → "Davet kodunu paylaş": kod açılınca üretilir (kullanılmamış kod varsa aynısı), paylaşım metniyle gönderilir, kopyalanabilir. Ekranda iki taraf: **Onlar** 7 yerine 14 gün · **Sen** aile abone olursa 1 ay (yılda en çok 12). Altta özet: kaç aile başladı, kaçı abone oldu, kaç ay kazanıldı (kimlik yok). | `create_guest_pass()`, `my_referrals()` |
| 2 | Yeni aile | ParentApp'i indirir; açılışta "Davet kodun var mı?" sorusunda (kayıttan önce; kurulumun başında kullanılır), kurulumda "Kodum var"da ya da Aile › Hesap › Kod gir kutusunda 8 karakterli kodu yazar. Tek kod kutusu türü kendiliğinden anlar (6: uzman ya da eşin kodu, 8: aile davet kodu). | `redeem_guest_pass(kod)` |
| 3 | [S] | Kod yeni ailede (deneme ≤ 7 gün, daha önce kod yok, abone değil, kendi ailesi değil) bir kez geçerli: deneme **14 gün** olur. | `families.trial_days = 14` |
| 4 | [S → P] | Kodu veren aileye `guest_pass_used` bildirimi ("Davetin kullanıldı", kullananın kimliği yok). | `notify_parents` |
| 5 | [S] | Davet edilen aile mağazadan ilk kez ücretli aboneliğe geçince (webhook → `family_subscriptions`): davet edene 1 ay. Davet eden abone değilse ücretsiz süresi hemen uzar (`bonus_until`); App Store'dan ödüyorsa ödül "kod bekliyor" olur. Son 365 günde 12 ödülden sonrası uygulanmaz. Bir aile için bir kez; iade edilen abonelikte geri alınmaz. | `referral_on_paid` → `referral_rewards`, `families.bonus_until` |
| 6 | [S → P] | Davet edene `referral_reward` bildirimi ("1 ay hediye kazandın"); bildirime dokununca davet sayfası. | `notify_parents` |
| 7 | [A → P] | App Store'dan ödeyen davet edene ekip **Apple teklif kodu** (1 ay ücretsiz, App Store Connect › abonelik › Offer Codes) gönderir; ParentApp davet sayfasında kod + **"Kodu kullan"** (kod panoya kopyalanır, Apple'ın kod sayfası açılır; ücretsiz ay bir sonraki yenilemede başlar). Kod **havuzdan kendiliğinden** atanır (ekip App Store Connect'ten indirdiği kod dosyasını yönetim paneli › Davetler'e yükler; ailenin aylık/yıllık ürününe uygun, en az 14 gün kalan kod); havuz boşsa ödül "kod bekliyor" kalır, kod yüklenince ya da panelden elle gönderilir. Kod hemen atanırsa 6. adımdaki bildirim tek bildirimdir ("kodun hazır"). | `referral_rewards.offer_code`, `status = 'code_sent'`; `offer_code_pool`, `referral_assign` (`veritabani.md` 28) |

ParentApp olayları (bu bölüm): `invite.code` (`suggested`), `invite.tell`, `invite.accept`, `invite.decline`, `phone.code_sent`, `phone.verified`, `phone.skip`, `care.log` (`from: clinician`), `clinic.unlink` (`all`), `clinic.remove` (`n`), `guest_pass.share`, `referral.redeem`, `intake.later_done` (`n`), `code.redeem` (`kind: guest`).


## 20. Seans planlama ve takip (uygulandı 5 Kasım 2026; ortak `migrations/20261105100000_sessions.sql`, `veritabani.md` 29, `durumlar.md` P18)

Kullanıcı isteği: "Önerdiğin beş alternatifin geliştirmesini yap; ParentApp'in yapması gereken adımları söyle." Belge ve benchmark: https://claude.ai/artifact/TiMrtycSVdzbeNTiii6oNP, önizleme: https://claude.ai/artifact/DpcEfMzky7SqNWfrivbAVd. Konum: seans, seanslar arası ev programıyla bağlanır (C "seans döngüsü"); A, B, D, E aynı tabloların üstünde.

**ClinicApp (uzman):**
1. **Takvim** (A): ana ekrandan; gün / hafta, durum renkleri, sahip için uzman süzgeci, dolu saatler (`clinic_busy`), dış takvim blokları (E). "+ Seans": danışan ya da danışansız blok, uzman (sahip başkasına atar), tür, yer (yüz yüze / online / ev), oda, süre, tekrar (her hafta / iki haftada bir, kaç seans), aileye göster, paket.
2. **Durum** (A): Yapıldı · Gelmedi · İptal (süre içinde Geç iptal; affedilebilir) · Ertelendi; "notu bekleyen" listesi (yapıldı ama kaydı yok, son 14 gün).
3. **Seans öncesi özet** (C): son yapılan seanstan bu yana evde olanlar (rutin oranı ve önceki dönem, davranış kayıtları, bekleyen öneri, değerlendirme zamanı, ailenin yanıtı/notu) + kendiliğinden gündem; hesap ClinicApp'te mevcut verilerden.
4. **Seans kaydı** (C): katılanlar, gözlem / çalışılan / sonraki adım (yalnız klinik), gündem işaretleri, aileye ev ödevi = Takip Planı'nın gönderilmemiş maddeleri seçilip "Aileye gönder" (`care_plan_publish_selected`), sonraki seans.
5. **Danışan › Seanslar**: devam (yapıldı / gelmedi / geç iptal), son 10 hafta, her seansın ara döneminde evden gelenler, paket kullanımı, bekleme listesi.
6. **Takvim ayarları** (D, E): çalışma saatleri ve "aileye açık" saatler, odalar ve şubeler (sahip), geç iptal süresi ve paket sayımı, hatırlatma dakikaları, aileye randevu alma (aç/kapat, bildirim süresi, ufuk, süre), takvim aboneliği bağlantısı (kopyala, baş harf göster, yenile, kapat), dış takvim adresi ekle/kaldır + "Şimdi eşitle".
7. **Bekleme listesi** (D): danışanı listeye al; iptal ya da boş saatte "Bekleme listesine teklif et" → aile kabul ederse randevu.

**ParentApp (ebeveyn) — yapıldı 5 Kasım 2026 (parent-app acfa1d8; SQL uygulanana kadar bölüm görünmez):**
1. **Uzmanım › <uzman> › Randevular** (B): `family_sessions()`; yaklaşan (ilk 5) + geçmiş (son 60 gün); kart: gün, saat, süre, tür (`kind_label`), yer (`room` · `location`, `mode` online/ev), uzman; durum çipi (Planlandı / Yapıldı / Gelmedi / Geç iptal / İptal / Ertelendi). Not, gündem, paket gösterilmez (gelmez).
2. **Yanıt** (B): gelecekteki planlı kartta "Geleceğiz" / "Uygun değil" (isteğe bağlı kısa not, ≤ 300) → `family_session_respond`; verilen yanıt kartta görünür, değiştirilebilir. Saat değişince yanıt sıfırlanır (sunucu).
3. **Hatırlatma** (B): her açılışta ve `session_*` bildiriminde `family_sessions()` → gelecekteki `planned` her seans için `reminders` dakikaları kadar önce **yerel bildirim** (expo-notifications, cihazda; eski planlananlar silinip yeniden kurulur). Metin: "Yarın 15:00 Nazlı'nın seansı · Elif Örnek" / "2 saat sonra …". Bildirim ayarından kapatılabilir.
4. **Takvime ekle**: kartta .ics paylaşımı (cihaz takvimi), yalnız o seans.
5. **Bildirimler**: `session_scheduled`, `session_changed`, `session_cancelled`, `session_offer` → dokununca Uzmanım › Randevular (o seans vurgulu).
6. **Boşalan saat teklifi** (D): `status = 'offered'` kart üstte, son geçerlilik (`offer_expires_at`) ile; "Kabul et" / "İstemiyorum" → `family_offer_respond`.
7. **Randevu al** (D): `family_booking_slots(link)` boş değilse Randevular'da "Randevu al" → gün seç → saat seç → onay → `family_book_slot`; hatalar `slot_not_available` ("Bu saat az önce doldu"), `too_many_bookings` ("En çok 2 randevu alabilirsin").
8. Paylaşım durdurulunca randevular kalkar (sunucu); yerel hatırlatmalar silinir.
9. Olaylar: `session.list`, `session.respond` (`response`), `session.offer` (`accept`), `session.book`, `session.ics`.

ClinicApp olayları: `screen.calendar`, `session.create` (`repeat`, `n`, `visible`, `client`), `session.update` (`scope`), `session.status` (`status`, `waive`), `session.record`, `session.homework`, `session.delete`, `session.package`, `waitlist.add`, `waitlist.offer`, `calendar.availability`, `calendar.feed`, `calendar.source`, `calendar.external`.

**E · dış takvim**: abonelik (ClinicApp → uzmanın takvimi) tek yönlü ve adsız (tür + isteğe bağlı baş harf); dış takvimi okuma uzmanın gizli iCal adresiyle, −14 … +60 gün, tekrarlar açılır; seansa çevrilmeyen etkinlik yalnız uzmana görünür.

**Bu öneride yok (karar ve hesap bekliyor):** seans ücreti tahsilatı ve e-fatura (Apple 3.1.3(e): uygulama dışında alınan hizmetin ödemesi App Store dışı yöntemle; ödeme ve e-fatura sağlayıcısı kullanıcı kararı), yeni ailelere açık herkese açık randevu sayfası (alan adı ve barındırma, ClinicApp açık soru 3), SMS / WhatsApp hatırlatması (İYS ve maliyet).

## 21. Çalışma alanları: uzman birden çok klinikte ve kendi danışanlarıyla (uygulandı 5 Kasım 2026; `migrations/20261105090000_workspaces.sql`, `veritabani.md` 30, `durumlar.md` P19)

Kullanıcı kararı (5 Kasım 2026): klinik uzmanı kendi kodunu paylaşarak davet etmez; her uzmanın tek kişisel kodu var, klinik bu kodu ister ve uzmanı ekibine ekler; Türkiye'de uzmanların çoğu birden çok yerde ya da kendi adına çalıştığı için uzman birden çok klinikte ve kendi bireysel alanında çalışır. Klinikteki uzmanlar aile davet edebilir (varsayılan açık, sahip kapatabilir). Benchmark: SimplePractice, Jane, Cliniko, TherapyNotes (bir hesap = bir muayenehane; ikinci e-posta / ayrı hesap), Practice Better (bireysel hesabı ekibe taşıma), Sessions Health, Allia, Fresha, GitHub (tek kimlik + alan seçici, iki taraflı onay); Joon (uzman başına koltuk, aile ücretsiz; çoklu klinik görünmüyor).

| # | Kim | Adım | Sunucu |
|---|---|---|---|
| 1 | [K] | Kayıt: "Bireysel uzman" → bireysel alan; "Klinik" → klinik alanı (sahip). Kayıtta ekip kodu sorulmaz. | `handle_new_user` |
| 2 | [K] (uzman) | Ayarlar › **Kişisel kodun**: 8 karakter, kopyala / paylaş, gerekirse "Yenile". | `clinician_personal_code` |
| 3 | [K] (klinik sahibi) | Ayarlar › Ekip › **"Uzman ekle"**: uzmanın kodunu yazar → uzmanın adı ve unvanı görünür, "İstek gönderildi" (7 gün). Bekleyen istekler ekip listesinde, geri çekilebilir. Koltuk doluysa istek gönderilmez. | `clinic_member_request`, `clinic_team`, `clinic_member_request_cancel` |
| 4 | [K] (uzman) | Bildirim `team_request` / ana ekranda "Ekibe katılma isteği" kartı: klinik adı, gönderen, ekip sayısı → **Kabul et** / **Reddet**. Kabulde klinik alan seçicide görünür; bireysel alanında danışanı yoksa o kliniğe geçer. | `clinic_member_requests_mine`, `clinic_member_respond` |
| 5 | [K] | **Hesap seçici** (kullanıcıya görünen ad "hesap"; kullanıcı kararı 5 Kasım 2026: hesap ayarıdır, sık değişmez → ana ekranda sol üstte "ClinicApp" yanında küçük düğme, başlıkta ok yok; başlık klinik alanında kliniğin adı, bireysel alanda uzmanın adı): "**Bireysel hesap**" (kendi danışanları; yoksa "Bireysel hesabını aç") · "**Ekip hesabı**" (her klinik için bir satır: kliniğin adı sistemden, altında uzmanın adı, rol, ekip sayısı). Ekip hesabını uzman **açmaz ve adlandırmaz**: klinik onu kişisel koduyla ekleyip uzman kabul edince (adım 3–4) görünür; hiç yoksa "Henüz klinik daveti yok" + (i) "Bir kliniğin davetini kabul ettiğinde hesap burada görünür; o kliniğin danışanlarıyla buradan çalışırsın." Seçim cihazda kalır, her istekte `x-clinic-id`. Danışanlar, davetler, notlar, plan, seanslar, üyelik seçili hesabındır. Bildirime dokununca o hesaba geçilir (`data.clinic_id`). Kendi kliniğini kurmak seçicide değil, **Ayarlar › Kişisel kodun altında küçük "Kendi kliniğini kur"** (kliniğin adını yalnız sahibi yazar; sahibi olduğu klinik varsa görünmez; kurunca o ekip hesabına geçilir; kullanıcı kararı 5 Kasım 2026). Klinik hesaplarının görünen adı "Ekip hesabı" (kullanıcı onayı aynı gün). | `clinician_workspaces`, `clinician_personal_workspace`, `clinic_workspace_create` |
| 6 | [K] | Aile daveti hangi alandan gönderilirse danışan o alanındır; davet penceresinde "Bu davet <alan> adına gider". Ekip üyesinin daveti klinik sahibine de görünür. Sahip Ayarlar › Ekip'te **"Ekip üyeleri aile davet edebilir"** (açık) anahtarını kapatabilir; kapalıyken üye klinik alanında davet gönderemez ("Bu klinikte aile davetini klinik sahibi gönderir"). | `clinic_create_invite`, `clinic_invite_policy_set` |
| 7 | [P] | Ebeveyn rıza ekranında ve Uzmanım'da: klinik alanı "<Klinik> · <Uzman>", bireysel alan yalnız "<Unvan> <Uzman>" (klinik adı ve ek etiket yok; kullanıcı kararı 5 Kasım 2026, ParentApp penceresi). **ParentApp penceresi yapar.** | `clinic_invite_preview().independent`, `family_clinic_links().independent` |
| 8 | [K] | Ayrılma: üye Ayarlar › Ekip › "Bu klinikten ayrıl"; sahip üyeyi "Ekipten çıkar". Kliniğin danışanları, notlar ve planlar klinikte kalır; uzmanın erişimi hemen biter; sorumlu olduğu danışanların sorumlusu boşalır (sahibe düşer), bekleyen davetleri iptal, gelecekteki seansları uzmansız kalır. Aile uzmanla devam etmek isterse uzmanın bireysel alanından yeni davetle (yeni rıza); önceki kayıtlar yalnız ebeveyn onayıyla (bölüm 11). | `clinic_leave`, `clinic_member_remove`, `clinic_member_end` |
| 9 | [K] | Takvim: seçili alanın takvimi + başka alanlardaki kendi seansları gri "<Alan>" blokları; sahip ekibinin başka yerdeki saatlerini yalnız "dolu" görür; çakışma uyarısı bunları da sayar. Kendi takvimine aktarma (feed) bütün alanları kapsar. | `clinic_busy_elsewhere`, `calendar_feed_events` |
| 10 | [K] | Üyelik ve ücret alan başına: klinik, ekibindeki uzmanlar için koltuk öder (yalnız sahip satın alır); bireysel alanda danışanı olan uzman Bireysel paket alır; yalnız klinikte çalışan uzman ödeme yapmaz. Ödeme duvarı yalnız seçili alanda; alan değiştirilebilir. Yeni alan yeni deneme süresi vermez. | `clinician_me().access`, `clinic-billing` (`x-clinic-id`) |

Olaylar (ClinicApp): `workspace.switch` (`personal`), `workspace.create` (`kind`), `team.code_copy`, `team.code_rotate`, `team.request` (`result`), `team.request_cancel`, `team.respond` (`accept`), `team.leave`, `team.remove`, `team.invite_policy` (`on`).

Eski ekip kodu yolu (`clinic_create_invite('clinician')`, `clinic_join_team`, kayıtta `team_code`) eski sürümler için sunucuda çalışır; yeni ClinicApp'te yok. Hukuk: klinik alanındaki danışanda veri sorumlusu klinik, bireysel alanda uzman (`hukuk_notlari.md` 23, avukata soru).


## 22. Gelişim › aile üyesi: ebeveyn eğitimi (uygulandı 5 Kasım 2026; `migrations/20261105200000_parent_lessons.sql`, `veritabani.md` 31, `durumlar.md` P20, taş `ekonomi.md` 5C)

Amaç: ebeveynin kendi becerisi (ABA / davranışçı ebeveyn eğitimi tarzı kısa dersler; içerik sonra hazırlanır). Benchmark (5 Kasım 2026, ParentApp penceresi): Triple P (kısa oturum + ev ödevi), PCIT (günlük 5 dk ev pratiği), Good Inside (kısa video + senaryo), Kinedu / Lovevery (haftalık etkinlik), NOCD / Manatee (terapistin atadığı ödev), Duolingo / Khan (kısa ders, ilerleme), Joon Health (ebeveyn modülleri). İşleyiş referansıdır; içerik, karakter ve metin kopyalanmaz. **Kullanıcı kararları (5 Kasım 2026):** (a) "Bu haftanın becerisi" kartı: 3–5 dk ders + "Bu hafta dene" + 5 günlük nokta şeridi ("bu hafta 2/5 gün"; seri yok, kayıpsız), altında "Öğrendiğin beceriler"; uzmanın önerdiği ders "Uzmanının önerisi" etiketiyle önde. (b) Güneş Taşı uygulanan güne: "Bugün uyguladım" başına 1, haftada en çok 3, ebeveynin cüzdanına; hediyeyi ebeveyn bugünkü dükkândan seçer; dersi açmak taş getirmez. (c) Uzman yoksa ya da önermediyse ebeveyn kütüphaneden kendisi seçer; içerik gelene kadar "Yakında" kartı.

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | (ParentApp yapıldı 5 Kasım 2026, parent-app cd532f2 + acfa1d8) Gelişim sekmesinin üstündeki seçicide çocuk avatarlarının yanında aile üyesi **"Ben"** (giriş yapan ebeveyn). Ben seçilince çocuk grafikleri yerine ebeveyn bölümü. | `family_lessons()` |
| 2 | [P] | Katalog boşsa (içerik henüz yok) tek kart: "Yakında: kısa ebeveyn dersleri" + bir cümle açıklama. Sunucu güncellemesi yoksa (işlev yok) aynı kart. | `catalog = []` |
| 3 | [P] | **Bu haftanın becerisi** kartı (bir ders `current`): ad, süre ("4 dk"), "Dersi aç", "Bu hafta dene" yönergesi, 5 nokta (bu hafta uygulanan günler; 5'ten fazlası da 5 dolu gösterilir), "Bugün uyguladım" (bugün işaretliyse ✓ ve geri al), "Öğrendim". Taş satırı: "Bu hafta n/3 taş". | `parent_lesson_start`, `parent_lesson_open`, `parent_lesson_practice`, `parent_lesson_finish` |
| 4 | [P] | Bu haftanın becerisi yoksa: önce **Uzmanının önerisi** (uzman adı Uzmanım'daki gösterimle, `link_id` → `family_clinic_links`; not varsa), sonra kütüphane (kısa liste, "Başla"). Başka bir derse başlamak öncekini kapatır: uygulandıysa "Öğrendiğin beceriler"e, uygulanmadıysa kütüphaneye döner (`paused`, kayıp yok). | `assigned[]`, `catalog[]`, `mine[]` |
| 5 | [P] | **Öğrendiğin beceriler**: öğrenilen dersler (ad, kaç gün uygulandı); dokununca ders yeniden açılır, istenirse yeniden "Bu haftanın becerisi" yapılır. | `mine[status = learned]` |
| 6 | [P] | Ders sayfası: başlık, süre, metin (`body_md`, sade markdown), "Bu hafta dene", altta tek satır: "Bu dersler bilgi amaçlıdır; tanı ya da tedavi yerine geçmez." Önerilen derste ek satır: "Uzmanın bu dersteki uygulama günlerini görür." | `parent_lessons.body_md` |
| 7 | [P] | Bildirim `lesson_assigned` → Gelişim › Ben. | `notifications` |
| 8 | [K] | Danışan › Takip planı (ya da ayrı "Ebeveyn dersleri" bölümü): kütüphaneden ders seç + isteğe bağlı not (≤ 300) → **Öner**; önerilenler listesi (her ebeveyn: başladı / öğrendi, dersi açtı mı, öneriden sonra uygulanan günler), **Geri çek**. Uzman ders içeriğini yazmaz (sistem kataloğu). | `clinic_assign_lesson`, `clinic_parent_lessons`, `clinic_withdraw_lesson` |
| 9 | [A] | İleride: panelde ders kataloğu düzenleme (taslak → yayın). Bugün SQL ile. | `parent_lessons` |

Kurallar: Dersler bilgi amaçlıdır, tanı ya da tedavi değildir; arayüzde puan, seri, "kaçırdın" ve "takip / izleme / kontrol" sözcükleri yok. Uzman yalnız **kendi önerdiği** derslerde, öneri tarihinden sonraki günleri görür (paylaşım rızasındaki "takip planı uygulama kayıtların" kapsamı; `hukuk_notlari.md` 26); ebeveynin kendi seçtiği dersler uzmana gitmez; paylaşım bitince uzman ebeveyn bilgisini görmez. Paylaşım ekranındaki "Paylaşılır" listesinde bu satır yazılır (ParentApp `SCOPE_FULL`). Her ebeveynin dersi ve taşı kendisinindir; aile içindeki öteki ebeveyn görebilir (aile okur). Taş kuralı `ekonomi.md` 5C. GameApp etkilenmez (hediye bugünkü yoldan).

Olaylar (ParentApp): `lesson.start` (`key`, `assigned`), `lesson.open` (`key`), `lesson.practice` (`key`, `on`, `stone`), `lesson.finish` (`key`).

## 23. Ebeveyn eğitimi (uygulandı 9 Kasım 2026; ortak `migrations/20261110100000_parent_trainings.sql`, `veritabani.md` 32, `durumlar.md` P21)

Kullanıcı isteği (9 Kasım 2026): rakibin "Parent training" ekranlarına ve kütüphanesine **sadık kal**; Takip planı aile programı (`care_modules`) ve 5 Kasım ders düzeniyle (22, `parent_lessons`) **birleştirilmedi**, "sonra değerlendiririz". İçerik `veri/ebeveyn_egitimi_kutuphane.json` (131 öğe: okuma, çoktan seçmeli test, açık uçlu; özgün Türkçe; gözden geçiren uzman bekliyor; video ve PDF yok).

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Danışan › Ebeveyn Eğitimi › "+ Eğitim ekle" → "Yeni eğitim oluştur": "Ebeveyn deneyimini önizle", "Bu eğitim kimin için?" (ailenin ebeveynleri), "Eğitim hedefi" (başlık olur) → İleri → **Taslak** eğitim | `clinic_link_parents`, `parent_trainings` |
| 2 | [K] | Eğitim sayfası sekmeleri: **Özet** (özet kartları, "En uygun:" ekleme kartları, ustalık ölçütü + gözlem verisi %) · **Öğrenme modülleri** (kütüphaneden çoklu seçim, sıralama) · **Uygulama görevleri** (ad, açıklama, ölçüm Sıklık / Doğruluk / Süre / Ölçüm yok) · **Hızlı yapılacaklar** (ad, açıklama ≤ 255). Ana ekran › Kaynak kütüphanesi'nden de "Ebeveyn eğitimi olarak ata" (danışan → ebeveyn → eğitim ya da yeni) | `parent_training_modules`, `_tasks`, `_todos`, `_data` |
| 3 | [K] | Durum Taslak → **Etkin**: onay penceresi "Eğitim Etkin olarak işaretlensin mi? Bu işlem eğitimi ebeveyne gönderir." → ebeveyne `training_assigned` | tetikleyici `parent_trainings_notify` |
| 4 | [P] | Bildirim → Ben › "Görevlerin" (uzmanından n görev) ve "Derslere devam et" (eğitim + % çubuğu); Uzmanım › uzman › Günlük yapılacaklar. Eğitim sayfası: Öğrenme modülleri (tür etiketi + ad + işaret, %), Uygulama görevleri, Tek seferlik görevler, "Başla" | `family_trainings()` |
| 5 | [P] | Oynatıcı: "%x · n öğe kaldı"; **okuma** sayfa sayfa, son sayfada "Bu metni okudum" işaretlenmeden "Sonraki" açılmaz; **test** giriş kartı ("n soruluk çoktan seçmeli test"), "Cevabı kontrol et" → "✓ Doğru / ✗ Yanlış", "Sonraki soru" / "Bitir", sonuç kartı "%50 · 2 sorudan 1 tanesini doğru yanıtladın! Bu konuyu bir sonraki seansında uzmanınla gözden geçirmeni öneririz."; **açık uçlu** giriş kartı + soru başına sayfa "Yanıtını yaz…". %100'de kutlama yok, eğitim sayfasına dönülür | `family_training_module_complete(modül, yanıtlar, doğru, toplam)` |
| 6 | [P] | Uygulama görevi: "Parçası: <eğitim>", sarı başlık, açıklama, ölçüme göre sayı alanı ("Sıklık sayısı" / başarılı + toplam deneme / süre dk), "Paylaşmak istediğin bir düşünce var mı?" ≤ 255, Gönder | `family_training_log` (bugün ve önceki 14 gün) |
| 7 | [P] | Tek seferlik görev: "Atandı: Bugün", açıklama, atanma tarihi, "✓ Tamamlandı olarak işaretle" → "Nasıl geçti?" (1 Çok kötü … 5 Harika) + düşünce ≤ 140 ("Bu yalnızca uzmanınla paylaşılır.") → "🎉 Tamamlandı!" | `family_training_todo_set(yapılacak, true, puan, düşünce)` |
| 8 | [K] | Ebeveyn etkinliği → uzmana `training_activity` bildirimi, sol menüde nokta; Özet "• n incelemeye hazır · İncele"; modül / yapılacak satırında nokta, açınca incelendi (`reviewed_at`). "Etkileşimli modülü incele": sonuç tarihi, test "%50 (2 sorudan 1 doğru)", ebeveynin yanıtları. "Yapılacağı incele": puan etiketi + düşünce | tetikleyici `parent_training_activity_notify` |
| 9 | [K] | Uygulama görevleri kartında "Hatırlatma gönder" (eğitim başına 12 saatte bir) → ebeveyne `training_reminder` | `clinic_training_remind` |
| 10 | [K] | "Not oluştur": tarih aralığı (son 7 gün → bugün) → "Atananlar" listesi (tür: ad + atanma tarihi), Kopyala. Ustalaştı → ebeveyne `training_mastered` | — |

**ParentApp (yapıldı 9 Kasım 2026, parent-app `claude/parentapp-two-features-bn9o8e`):** adım 4–7. Ben › **Görevlerin** ("Uzmanından n görev": uygulama görevleri + tamamlanmamış tek seferlik görevler; tek eğitimde o eğitim, birden çokta "Görevlerin" listesi) ve **Derslere devam et** (eğitim + % çubuğu; Ustalaştı "Tamamlandı", öteki ebeveyne atanmış "<ad> için"); Uzmanım › uzman › Bugün yapılacaklar'da uygulama görevleri ve tek seferlik görevler; eğitim sayfası, oynatıcı (bitmiş öğe salt okunur, kayıtlı yanıtlarla), uygulama kaydı (bugünün günü), tek seferlik görev ("Geri al" ile işaret kaldırılır); bildirimler `training_*` → eğitim sayfası. İşlev yoksa (SQL uygulanmadı) bölümler görünmez. İçerik `src/data/trainingLibrary.json` ← `node tools/sync-training-library.mjs <ortak>/veri/ebeveyn_egitimi_kutuphane.json`. Kütüphanede ebeveyne görünen "Moyo Mercek" geçişi 6 Kasım kararına göre ("ebeveyn tarafında Mercek değil uzmanın") düzeltildi: `baslarken_r` başlığı "Uzmanınla eğitime başlarken" (ClinicApp yeniden eşitlemeli). Olaylar (ParentApp): `training.module` (`type`, `last`), `training.log` (`measure`, `note`), `training.todo` (`done`, `rating`).

Kurallar: aile tablolara yazamaz, yalnız işlevlerle; ebeveyn yalnız kendisine atanmış (ya da kimseye özel olmayan) **Etkin** eğitimde işlem yapar, aile içindeki öteki ebeveyn görür ama değiştiremez; uzman modül tamamlamasını ve yapılacak işaretini değiştiremez; gözlem verisini aile görmez; paylaşım bitince aile ve uzman erişimi kapanır. Test doğru sayısı ebeveynin bilgi yoklamasıdır, çocuğa ait puan değildir. Olaylar (ClinicApp): `training.create`, `training.status`, `training.delete`, `training.modules`, `training.task`, `training.todo`, `training.data`, `training.remind`.

## 24. Hedef davranışlar ve bildirilen olaylar (uygulandı 9 Kasım 2026; ortak `migrations/20261110110000_target_behaviors.sql`, `veritabani.md` 33, `durumlar.md` P22)

Kullanıcı isteği (9 Kasım 2026): rakibin "Target behaviors & reported incidents" ekranlarına sadık; mevcut "Davranış hedefi" (`clinic_goals`) ve "Davranış kaydı" (`abc_events`) ile **birleştirilmedi**.

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Danışan › Davranışlar ve Olaylar › "+ Hedef davranış ekle": "Ebeveyn deneyimini önizle", Hedef davranış (zorunlu), Açıklama (aileden istenen), Stratejiler (liste, en çok 10), Durum (Başlangıç ölçümü · Durağan · İyileşiyor · Geriliyor · Ustalaştı), "Ebeveyn davranış kaydı" (açık), Kayıt türü (Sıklık sayısı · ABC · Süre) | `clinic_target_behaviors` |
| 2 | [P] | Ben › Görevlerin › "Çocuğunun davranış olayını bildir" (Uzmanım › uzman › Günlük yapılacaklar'da da): (1) "Hangi davranış oldu?" hedefler + "Hiçbiri"; (2) türe göre: sıklık → olay tarihi + "Kaç kez oldu?"; ABC → olay tarihi + "Bu olaydan önce ne oldu?" + "Bu olaydan sonra ne oldu?"; süre → olay tarihi + "Ne kadar sürdü?"; "Hiçbiri" → "Ne oldu?" + tarih + önce/sonra + süre + sıklık; (3) "Hangi stratejiyi denedin?" (hedefin stratejileri + "Hiçbiri"; diğer olayda serbest metin) + "Çocuğun bu uygulamaya ne kadar iyi tepki verdi?" (1 Kötü … 5 Çok iyi) → Gönder → "Bu olayı kaydettiğin için teşekkürler" · "Başka bir olay bildir" / "Ana sayfaya dön" | `family_target_behaviors()`, `family_incident_report` |
| 3 | [K] | Yeni olay → paylaşımın uzmanlarına `behavior_incident` bildirimi. Hedef kartı (açılır): durum çipi, "Başlangıç: <tarih>", olay tablosu türe göre (Tarih · Bildiren · Sayı / Öncül · Sonuç / Süre · Uygulanan strateji · Çocuğun tepkisi). Altta "Diğer bildirilen olaylar" (Tarih · Bildiren · Davranış · Öncül · Sonuç · Süre · Sıklık · Uygulanan strateji · Çocuğun tepkisi). "Dışa aktar" (CSV) | — |

**ParentApp (yapıldı 9 Kasım 2026, parent-app `claude/parentapp-two-features-bn9o8e`):** adım 2. Giriş satırı yalnız ebeveyn kaydı açık en az bir hedef davranış varsa (Ben › Görevlerin, Uzmanım › uzman › Bugün yapılacaklar; o uzmanın paylaşımlarıyla). Birden çok çocuk paylaşılmışsa 1. adımda çocuk seçilir. Olay tarihi gün + saat (ileri değil, en çok 30 gün geri; sunucudaki kuralla aynı). Mevcut "Davranış kaydı" (`abc_events`) satırı yanında ayrı durur. Olay (ParentApp): `incident.report` (`type`: `frequency` / `abc` / `duration` / `other`, `strategy`).

Kurallar: aile tabloya yazamaz, yalnız `family_incident_report`; olay zamanı ileri olamaz, en çok 30 gün geri; türe göre zorunlu alan; ebeveyn kaydı kapalı ya da arşivli hedefe olay bildirilmez ve aile onu görmez; başka aile / klinik görmez; paylaşım bitince kapanır. Tepki ebeveynin gözlemidir, puan değildir.
