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

Son güncelleme: 2026-10-19

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
| 2 | [P] (ebeveyn 2) | Kendi hesabıyla Aile › Hesap › "Aileye katıl" bölümüne kodu yazar. | `join_family(code)` |
| 3 | [S] | Profil yeni aileye taşınır, kod tüketilir. Ebeveyn 2'nin eski ailesinde başka ebeveyn yoksa eski aile **ve tüm verisi silinir** (uygulama önce uyarır). | `profiles.family_id`, `invite_codes.used_at` |

---

## 2. Çocuğu oyuna bağlama (giriş kodu)

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Aile › çocuk › Genel › "Giriş kodu üret". Aynı çocuğun kullanılmamış eski kodu geçersiz olur. | `create_invite_code('child', child_id)` → **24 saat**, tek kullanım |
| 2 | [P → çocuk] | Ebeveyn kodu çocuğa söyler/gösterir (uygulama dışı). | — |
| 3 | [O] | Çocuk kodu yazar. Oyun büyük harfe çevirir, harf/rakam dışını atar, 6 karakter değilse hata. Hatalı denemelerde istemci beklemesi: 3 serbest, sonra 15 sn → ikiye katlanarak en fazla 300 sn. | `ChildCode`, `LoginThrottle` |
| 4 | [O] | Oturum yoksa **anonim oturum** açar. | `POST /auth/v1/signup` (anonim). Supabase'de "Anonymous Sign-Ins" açık olmalı. |
| 5 | [O → S] | Kodu kullanır. | `redeem_child_code(code)` → `{child_id, family_id, name, avatar, age_band}` |
| 6 | [S] | `children.user_id = auth.uid()` yapılır, kod tüketilir. Ebeveyn hesabıyla çağrılırsa reddedilir. | `children`, `invite_codes` |
| 7 | [O] | Yenileme anahtarı ve çocuk bilgisi cihazda güvenli saklanır; sonraki açılışlarda sessizce yenilenir. | `pofi.refresh_token`, `pofi.child` |
| 8 | [O] | İlk senkrondan **önce** sunucudaki oyun yedeğine bakar: yereldeki kayıt boşsa ya da yedek daha yeniyse yedeği alır (telefon değişimi). | `game_save_get()`; `SaveRestore` |
| 9 | [P] | Realtime ile çocuğun "bağlı" olduğu görünür (`linked` = `user_id` dolu). | `children` (Realtime) |

Not: Oyunun deneme kodları (`A1A1A1`, `B2B2B2`, `C3C3C3`) sahte arka uca gider; bu akışı kullanmaz.

### 2.1 Bağlantıyı kaldırma
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Aile › çocuk › "Cihaz bağlantısını kaldır". | `unlink_child_device(child_id)` → `children.user_id = null` |
| 2 | [O] | Sonraki denetimde kendi `children` satırını göremez → "Bağlantın kapatıldı, yeni kod iste". Yerel oyun kaydı **silinmez**. | `GET children?user_id=eq.<uid>` boş → `Revoked`; `child_me` → `42501` |
| 3 | [P] + [O] | Yeniden bağlanmak için 2. bölümdeki akış yeni kodla tekrarlanır. | |

---

## 3. Görev → çocuk tamamlar → ebeveyn inceler → coin

| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Ebeveyn görev oluşturur (hazır şablondan ya da özel): başlık, emoji, açıklama, başlangıç, tekrar (`daily`/`weekly`/`monthly` + günler), bitiş, hatırlatma, **inceleme gereksin mi** (varsayılan evet). | `tasks` insert |
| 2 | [P] | Görevi bir ya da daha çok çocuğa atar; her atamada zorluk ve coin (varsayılan Kolay 5 / Orta 10 / Zor 20, elle değişir). | `task_assignments` insert |
| 3 | [O] | Senkronda (zamanlaması Unity katmanında; doğrulanmalı) dünden 7 gün sonrasına kadar görev örneklerini çeker. Tekrarlar sunucuda açılır. Kaydı olmayan örnek `assigned`. | `child_tasks(from, to)` |
| 4 | [O] | Yeni görev için oyunda rozet + pet'ten bildirim. | `TaskEvent.NewTask` |
| 5 | [O] | Çocuk "Yaptım" ya da "Yapamam" der. Ekranda hemen görünür; ağ yoksa kuyrukta bekler (aynı görev için yalnız son niyet gönderilir). Gün geçtiyse ("kaçırıldı") işaretlenemez. | yerel `TaskBoard.Outbox` |
| 6 | [O → S] | Kuyruk gönderilir. | `child_set_status(task_id, date, 'pending' \| 'declined' \| 'assigned')` |
| 7 | [S] | `requires_review = true` → `pending` yazılır. `requires_review = false` → doğrudan `approved` (**coin hemen**, adım 10'a atla). `declined` → yalnız kayıt. `assigned` → kayıt silinir (geri al). Ebeveyn karar verdiyse değişmez. | `completions` |
| 8 | [P] | Realtime ile değişiklik gelir; **İnceleme** ekranında `pending` olanlar listelenir; Görevler'de durum etiketi (Onay bekliyor / Tamamlandı / Yapamadı / Reddedildi). | `completions` (Realtime) |
| 9a | [P] | **Onay:** kayıt `approved` yapılır. | `review_completion(..., 'approved')` (19 Ekim kararı; önceden doğrudan `completions` update) |
| 9b | [P] | **Ret:** ebeveyn isterse not yazar ("Yatak dağınık kalmış"); kayıt silinmez. | `review_completion(task, child, date, 'rejected', note)` |
| 10 | [S] | `approved`'a geçişte coin deftere eklenir (atamadaki `coins`). Onay geri alınırsa (başka duruma geçiş ya da silme) verilen tutar düşülür; görev/atama silinirse kazanılan coin kalır. | tetikleyici `completions_coin` → `coin_ledger` (`task` / `task_undo`) |
| 10a | [S] | Aynı geçişte **Güneş Taşı** yazılır: kolay 1 / orta 2 / zor 3 (`20261019030000_sun_stones`, uygulandı 19 Ekim). Geri almada o tamamlamanın taşı düşer. | tetikleyici `completions_sun_stone` → `sun_stone_ledger` |
| 11 | [O] | Sonraki senkronda görev durumu `approved`/`rejected` gelir (nihai; kuyruktaki çocuk niyeti düşer). Onayda kutlama sahnesi; retde ebeveynin notu gösterilir. | `child_tasks` (`status`, `parent_note`); `TaskEvent.Approved/Rejected` |
| 12 | [O] | Bakiye sunucudan alınır, artış "kazanılan coin" olarak kutlanır. Aynı gün ilk onayda görev serisi bonusu XP'si verilir (coin değil). | `child_me().balance`; `TaskStreak` |
| 12a | [O] | Onaylı her görev örneği için bir kez: zorluğa göre XP (20/35/50, sınıra sayılmaz) ve becerisine 1 yıldız (`ekonomi.md` 5B). Taş toplamı `child_me().sun_stones`'tan alınır; çocuk taşları adadaki onarım noktalarına yerleştirir. | `child_tasks` (`skill`, `difficulty`); `child_me().sun_stones` |
| 13 | [P] | Ebeveyn çocuğun bakiyesini görür. | `child_balance(child_id)` |

### 3.1 Coin harcama (oyun içi, ebeveyn adımı yok)
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [O] | Çocuk dükkânda eşya seçer; seviye kilidi, sahiplik, pete uyum ve bakiye oyunda denetlenir. Coin yerelde "bekleyen" olarak düşer, eşya hemen envantere girer. | `ShopRules.Buy`, `Wallet.TrySpend` |
| 2 | [O → S] | Harcama, istemcinin işlem kimliğiyle gönderilir (çevrimdışıysa kuyrukta kalır). | `spend_coins(tx, item_id, qty)` |
| 3 | [S] | Fiyat `game_items`'tan; aynı işlem iki kez düşülmez; bakiye yetmezse reddedilir. | `coin_ledger` (`spend`) |
| 4 | [O] | Kabul → kesinleşir. Ret (`not_enough_coins` / `unknown_item`) → eşya envanterden geri alınır, bakiye sunucudakine eşitlenir. | `Wallet.Acknowledge/Reject` |
| 5 | [P] | Ebeveynin gördüğü bakiye düşer (bir sonraki `child_balance` çağrısında). | |

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
| 3 | [O] | **Henüz yok.** Oyun kodunda `messages` kullanımı bulunamadı. RLS çocuğun kendi mesajlarını okumasına ve `sender='child'` ile göndermesine, Storage'a aile klasörüne yüklemesine izin verir. | — |
| 4 | [K] | Erişim **yok** (klinik önerisinde de Posta uzmanla paylaşılmaz). | — |

---

## 5. Uzman (klinik) paylaşımı — uygulandı

> **Uygulandı (19 Ekim 2026).** SQL: `supabase/migrations/20261019000000_clinic.sql`.
> ParentApp tarafı aynı dalda "Aile › Hesap › Uzmanım" (`ClinicShare.tsx`, `lib/clinic.ts`). ClinicApp henüz yazılmadı.

### 5.1 Uzman hesabı ve ekip
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Uzman kayıt olur; meta `account='clinician'`, `name`, `title`, `clinic_name`. | `auth.users` |
| 2 | [S] | Aile **oluşturulmaz**; yeni klinik (`plan='trial'`, 14 gün, 3 koltuk) + uzman (`role='owner'`). | `handle_new_user` → `clinics`, `clinicians` |
| 3 | [K] (sahip) | Ekip daveti üretir. | `clinic_create_invite('clinician')` → **7 gün** |
| 4 | [K] (yeni uzman) | Kayıtta `team_code` verir; koltuk doluysa reddedilir. | `handle_new_user` → `clinicians` (`member`) |
| 4a | [K] (giriş yapmış uzman) | Profil › "Ekip koduyla katıl": hesabı varsa kodla katılır. Eski kliniği **boşsa** (başka uzman, paylaşım, not, hedef yok) silinir; doluysa reddedilir. Sahibe `team_joined` bildirimi. | `clinic_join_team(kod)` (`20261021100000`, uygulandı) |
| 5 | [K] (üye) | Profilinde klinik adı, klinik sahibi ve davet edenin adı görünür; danışan listesi kliniğin bütün etkin paylaşımlarıdır (sahip ile aynı). | `clinician_me()` → `owner_name`, `invited_by_name`, `joined_at` (`20261021100000`, uygulandı) |

### 5.2 Aile paylaşımı (ebeveynin açık rızası)
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Uzman aile davet kodu üretir (isteğe bağlı etiket, ör. danışanın takma adı). | `clinic_create_invite('family', label)` → 6 karakter; **48 saat + bağlantı (öneri, bölüm 10)** |
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

### 5.5 Gözlem notu (ABC kaydı; eski adı "Zor an")
| # | Uygulama | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Ebeveyn zor bir anı kaydeder: Öncesi, Davranış (zorunlu), Sonucu, şiddet 1–5. | `abc_events` insert |
| 2 | [K] | Rızalı bağlantısı olan uzman okur. | `abc_events` (RLS `clinic_sees_child`) |

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
| 3 | [O] | Çocuk satırı silindiği için oyun sonraki denetimde bağlantıyı kapalı görür; yerel kayıt kalır. | `Revoked` |
| 4 | [K] (uygulandı, bölüm 9 veritabani.md) | Uzman "Hesabı sil": tek kişilik klinik (paylaşımlar, notlar, hedefler, davetler, üyelik kayıtları) silinir; ekipte başkası varsa klinik kalır, sahiplik en eski üyeye geçer. App Store aboneliği Apple'dan ayrıca kapatılır. | `delete_account()` |

---

## 7. Bildirimler (19 Ekim 2026'da uygulandı)

> SQL: `supabase/migrations/20261019130000_notifications.sql`. Bildirim satırlarını **yalnız sunucu tetikleyicileri** yazar; uygulamalar okur, okundu işaretler (`mark_notifications_read`), siler.
> İşlemi yapan kişiye bildirim gitmez. Uzmana yalnız rızalı (`active`) paylaşım bildirilir; posta ve coin uzmana bildirilmez.

| Olay | Kimden → kime | `kind` | Uygulama (`app`) |
|---|---|---|---|
| Çocuk "Yaptım" (inceleme bekliyor ya da incelemesiz onay) | Oyun → ailenin bütün ebeveynleri | `task_done` | parent |
| Çocuk "Yapamam" | Oyun → ebeveynler | `task_declined` | parent |
| Ebeveyn onayladı / reddetti | ParentApp → çocuk cihazı | `task_approved` / `task_rejected` | child |
| Yeni görev atandı (yalnız yeni atama; düzenleme bildirim üretmez) | ParentApp → çocuk | `task_assigned` | child |
| Posta | çocuk → ebeveynler / ebeveyn → çocuk | `message` | parent / child |
| Çocuğun cihazı koda bağlandı | Oyun → ebeveynler | `device_linked` | parent |
| İkinci ebeveyn aileye katıldı | ParentApp → diğer ebeveynler | `parent_joined` | parent |
| Aile çocuk(lar)ı uzmanla paylaştı (aynı anda paylaşılanlar **tek** bildirimde, adlarıyla) | ParentApp → sorumlu uzman (yoksa kliniğin uzmanları) | `clinic_shared` | clinic |
| Paylaşım durduruldu | aile durdurduysa → uzman; uzman durdurduysa → ebeveynler | `clinic_revoked` | clinic / parent |
| Uzman görev önerdi | ClinicApp → ebeveynler | `clinic_suggestion` | parent |
| Ebeveyn öneriye karar verdi | ParentApp → öneriyi yapan uzman | `suggestion_decided` | clinic |
| Gözlem notu | ParentApp → rızalı bağlantının uzmanı | `abc_event` | clinic |
| Ekibe yeni uzman katıldı | ClinicApp → klinik sahipleri | `team_joined` | clinic |

Teslim yolları:
- **Uygulama içi (üçü de):** `notifications` tablosu + Realtime (`user_id=eq.<kendi id>`); açılışta son 100 satır.
- **Telefona push (iOS, ParentApp ve GameApp):** cihaz Apple (APNs) cihaz anahtarını `register_push_token(token, 'parent'|'child', 'ios')` ile kaydeder. Her yeni bildirimde tetikleyici pg_net ile Edge Function `push-apns`'e yalnız bildirim kimliğini yollar; fonksiyon .p8 anahtarıyla Apple'a gönderir (konu: parent → `com.parentapp.ios`, child → `com.gameapp.ios`, clinic → `com.clinicapp.uzman`), geçersiz anahtarı siler, bildirimi `apns_sent_at` ile işaretler. Çıkışta `unregister_push_token`. Kod: `supabase/functions/push-apns/index.ts`; secret'lar `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID` (Supabase'de). Expo anahtarı (`ExponentPushToken[...]`) gelirse Expo Push API'ye gider (yedek yol).
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

ParentApp olayları (22 Ekim 2026): `app.open`, `screen.<tasks|review|progress|family|create_task|task_details|chat|notifications|observation|rewards|paywall>`, `task.create` (`n`), `task.delete`, `task.review` (`approve`), `template.custom`, `child.add`, `invite.create` (`kind`), `family.join`, `message.send` (`kind`), `notification.open` (`kind`), `observation.create`, `reward.create`/`reward.update` (`kind`), `reward.delete`, `reward.give` (`n`), `reward.decide` (`approve`), `stones.deduct` (`n`, `reason`: doğru/yanlış; metin gönderilmez), `onboarding.done` / `onboarding.skip` (`step`; ilk kullanım rehberi, 26 Ekim 2026), `invite.accept` (`n`, `new`, `history`), `invite.decline`, `care.log` (`practiced`) (uzman daveti ve takip planı, 26 Ekim 2026).

ClinicApp olayları (ilk sürüm): `app.open`, `screen.home`, `screen.client` (`tab`), `screen.notifications`, `notification.open` (`kind`), `suggestion.send` (`n`), `suggestion.update`, `report.print`, `invite.family`, `invite.team`, `team.join`, `abc.play`, `onboarding.done` / `onboarding.skip` (`step`; ilk kullanım rehberi, 26 Ekim 2026).

## 10. Uzman başlatır: aile davet bağlantısı (öneri, `proposed/20261026100000_family_invite_links.sql`, 26 Ekim 2026)

Karar (kullanıcı isteği 26 Ekim): akışı uzman başlatır. Uzman isterse önce takip planını (hedefler + aile programı) kurar, sonra aileye **bağlantı** gönderir (WhatsApp / e-posta / SMS / kopyala). Aile bağlantıdan ParentApp'i yükler, kayıt olur; uzman kendiliğinden tanımlıdır. Çocuk verisi yine **ebeveynin çocuk seçip onay vermesiyle** paylaşılır (rıza kuralı değişmedi).

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | "Aileyi davet et": isteğe bağlı ebeveyn adı, e-posta, **çocuğun adı ya da takma adı + yaş grubu** (K ≤5 · A 6–8 · B 9–12 · C 13+), kendi notu (aile görmez). | `clinic_create_invite('family', label, parent_name, parent_email, child_name, child_age_group)` → `{code (6), token (32), expires_at}`; **48 saat** |
| 2 | [K] | İsterse davete taslak takip planı ekler (paket seç → hedef/modül düzenle). | `clinic_goals` / `care_modules` (`invite_code`) |
| 3 | [K] | Paylaşır: WhatsApp (`wa.me/?text=`), e-posta (`mailto:`), sistem paylaşımı ya da kopyala. Mesajda bağlantı + yazılabilir kod. Kanal kaydedilir. | `clinic_invite_mark(code, channel)` |
| 4 | Ebeveyn | Bağlantıya dokunur: `https://<alan adı>/d/<token>`. ParentApp yüklüyse doğrudan uygulama açılır (Universal Link); değilse açılış sayfası (`web/davet`): uzman adı + "App Store'dan yükle" + "Daveti uygulamada aç" (`parentapp://davet/<token>`) + kod. | Edge Function `invite-info` → `clinic_invite_open(token)` (açıldı işareti) |
| 5 | [P] | Kayıt ekranında "Dr. X seni davet etti" bandı; kayıtta meta `clinic_invite = <token ya da kod>` gönderilir. | `handle_new_user` → davet aileye **bağlanır** (`claimed_family`); uzmana `invite_claimed` |
| 5a | [S] | Bağlantı/kod yoksa: davette e-posta yazılıysa aynı e-postayla kayıt olan ebeveyne davet kendiliğinden bağlanır. | `handle_new_user` |
| 5b | [P] | Hesabı olan ebeveyn bağlantıyı açar ya da kodu yazar. | `claim_clinic_invite(token|kod)` |
| 6 | [P] | Bekleyen davet ekranı (kullanıcı kararı 26 Ekim 2026): **"Dr. X, Efe (6–8) için seni davet etti. Bilgiler doğru mu?"** Ad, yaş grubu (isteğe bağlı doğum günü, cinsiyet, simge) **dolu ve düzenlenebilir**; ebeveyn ayrıca çocuk eklemez. Aynı ekranda **uzman doğrulanmaz uyarısı** (aşağıda) ve tek onay kutusu "Bu uzmanı tanıyorum ve çocuğun velisiyim"; düğme **"Onayla ve paylaş"**. Ailede başka çocuk varsa onları da işaretleyebilir. Altta "Bu davet bana ait değil" (reddet). Öneri yoksa ebeveyn adı yazar (aynı ekran). | `family_pending_invites()` (+ `child_name`, `child_age_group`), `family_accept_invite(anahtar, çocuk, çocuklar, geçmiş, onay_sürümü, geçmiş_sürümü)`, `family_decline_invite(anahtar)` |
| 6b | [S] | Onayda çocuk sunucuda oluşur ve paylaşılır; ebeveyn öneriyi değiştirdiyse uzmana **"Ebeveyn çocuk bilgisini düzeltti: Efe (A) → Efecan (B)"**; onaylanan ad uzmanın danışan listesinde. Sonradan ParentApp'te yapılan düzeltmeler de danışan listesine kendiliğinden yansır. Reddedilirse uzmana "Aile davetini kabul etmedi", davet kapanır, öneri ve taslak plan silinir. | `invite_child_updated`, `invite_declined`, `clinic_clients()` |
| 6c | [P] | Ebeveyn "Çocuk ekle" ile **aynı adda** bir çocuk eklemeye kalkarsa: bekleyen davette bu ad varsa "Uzmanının davetinde Efe zaten var — davete git"; ailede varsa "Kayıtlarında Efe adında bir çocuk var — yine de ekle / vazgeç". Sunucu da `family_accept_invite`'ta aynı adı yakalar (`{"error":"duplicate_child", child_id, name}`; ebeveyn "yine de ekle" derse `allow_duplicate: true`). | ParentApp (istemci) + `family_accept_invite` |
| 6d | [P] | Çocuk eklenince aynı ekranda "Çocuğunun tabletini bağla": **QR + yazılı 15 dakikalık giriş kodu** (kullanıcı onayı 26 Ekim 2026); GameApp QR'ı okur ya da kod yazılır. Oyun giriş kodu davete **konmaz**. | `create_child_login_code` (bugünkü; QR yalnız aynı kodu taşır) |
| 7 | [S] | Paylaşım açılır; taslak plan çocuğa taşınır; uzmana `clinic_shared` (mevcut), diğer ebeveyne `care_plan_shared`. | `clinic_links`, `clinic_goals`/`care_modules` (`link_id`) |
| 8 | [S] | 48 saatte kimse bağlamadıysa uzmana bir kez `invite_expired`. Zamanlayıcı (pg_cron, 15 dk) ya da ClinicApp açılışında. | `clinic_invites_expire()` / `clinic_invites_sweep()` |
| 9 | [K] | Davetlerim: durum (gönderildi / açıldı / kayıt oldu / paylaşıldı / süresi doldu / iptal), yeniden paylaş, iptal. Sahip bütün ekibin istatistiğini görür. | `clinic_invites_list(gün)`, `clinic_invite_stats(gün)`, `clinic_invite_mark(code, null, true)` |

**Uzman doğrulanmaz uyarısı (ParentApp, davet ekranında, kullanıcı kararı 26 Ekim 2026; metin sürümü `uzman-paylasim-v1`, `hukuk_notlari.md` 3F):**
> ClinicApp uzmanların kimliğini ve mesleki belgelerini doğrulamaz. Çocuğunun bilgilerini paylaşmadan önce bu uzmanı gerçek hayatta tanıdığından ve davetin ondan geldiğinden emin ol. Emin değilsen paylaşma; uzmanını bildiğin bir yoldan arayıp sor. Paylaşımı istediğin an Uzmanım bölümünden durdurabilirsin.
> ☐ Bu uzmanı tanıyorum ve çocuğun velisiyim (yasal temsilcisiyim).

Çocuk önerisi (kullanıcı kararı 26 Ekim 2026): yalnız ad/takma ad (≤ 40) + yaş grubu; doğum günü, cinsiyet, fotoğraf alınmaz. Açılış sayfası (`invite-info`), mesaj metni ve daveti bağlamamış aile göremez; yalnız daveti kendi ailesine bağlamış ebeveyn (`claim_clinic_invite`, `family_pending_invites`, `clinic_invite_preview`). Davet kullanılınca, iptal edilince, 48 saatte bağlanmayınca ya da bağlandıktan 30 gün sonra silinir. ParentApp'te yaş grubu → `age_band`: K, A → `A`; B, C → `B`. Uzmanın kendi notu (`label`) hiçbir aile yanıtında dönmez.

Neden oyun kodu davette yok: çocuk hesabı davet anında yok (açmak için uzmanın çocuk hesabı açması gerekir, rıza kuralına aykırı); bağlantı ebeveynin telefonuna gelir, oyun çocuğun cihazında açılır; oyun kodu çocuk hesabının anahtarıdır (uzmanda ya da mesajın iletildiği kişide olursa çocuk gibi oyuna girip ebeveyn–çocuk mesajlarını görebilir); uzman hesapları doğrulanmıyor (kötü niyetli "uzman" riski); oyun kodu 15 dakika ve tek kullanımlık, davet 48 saat.

Kurallar: Bağlanmış davet 30 gün içinde çocuk paylaşımına kullanılabilir (48 saat yalnız bağlanana kadar). Bir davet tek aileye bağlanır. Kod yolu deneme sınırına tabidir (`code_attempts`); 32 karakterlik anahtar tahmin edilemez. Uzman yalnız kendi davetlerini, sahip kliniğin bütün davetlerini görür. Ekip kodu değişmedi (15 dakika).

Neden üçüncü taraf "ertelenmiş bağlantı" (Branch, AppsFlyer) yok: SDK, maliyet, izin/KVKK yükü. App Store'dan yükleme sonrası davet; (a) "Daveti uygulamada aç" dokunuşu, (b) e-posta eşleşmesi, (c) kod ile taşınır.

## 11. Uzman değişimi ve geçmiş aktarımı (öneri, aynı dosya)

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [P] | Uzmanım › uzman › "Paylaşımı durdur" (eski uzmanın erişimi hemen biter). | `revoke_clinic_link` (değişmedi) |
| 2 | [P] | Yeni uzmanın bağlantısı/kodu (bölüm 10). Çocuk seçme ekranında, çocuk daha önce başka uzmanla paylaşıldıysa "Önceki uzmanın kayıtlarını da paylaş (adı ve bilgileri gizlenir)" (varsayılan açık) + açık rıza metni; onaylanan metnin sürümü kaydedilir. | `redeem_clinic_invite_children(…, p_share_history, p_consent_version)` |
| 3 | [S] | Yeni uzman önceki paylaşımların notlarını, hedeflerini ve haftalık puanlarını, önerilerini, aile programını ve ebeveynin uygulama kayıtlarını **salt okur**. **Önceki uzman adsızdır** (26 Ekim 2026, kullanıcı kararı): adı, unvanı, kliniği ve kimlikleri yeni uzmana dönmez; "Önceki uzman 1, 2…" ve dönem (ay) görünür; metinlerde geçen klinik adı ve o kliniğin uzman adları "[önceki uzman]" ile değiştirilir (en iyi çaba). Tablolara doğrudan erişim yok, yalnız işlev. Görev/tamamlama/zor an verisini zaten görür. | `clinic_inherited_records(link)` |
| 4 | [P] | Aktarımı sonradan açıp kapatabilir (geri alınabilir rıza). Ebeveyn kendi ekranında uzman adlarını görür. | `clinic_link_history_set(link, açık, sürüm)`; `family_clinic_links()` → `history_shared`, `history_available` |

Not: Önceki uzmanın notları onun mesleki kaydıdır; aktarım yalnız ebeveyn rızasıyla, okuma olarak ve önceki uzmanın kimliği gizlenerek yapılır. Dayanak: uzman sözleşmesindeki aktarım maddesi + ebeveynin açık rızası (taslak maddeler `sozlesme/hukuk_notlari.md`). Canlıda açılmadan önce hukuk onayı gerekir.

## 12. Takip planı: hedefler ve aile programı (öneri, aynı dosya)

Biz tedavi yapmıyoruz; uzmanın kendi planını hızlı kurması için şablon (iskelet) sunuyoruz. Şablon kataloğu: `veri/takip_sablonlari.json` (7 alan, 27 hedef, 13 modül — 12 + "Gözlem ve zor an kaydı" girişi, 8 paket; kaynaklarıyla).

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | Danışan › Plan (ya da davet taslağı): paket seç ya da tek tek ekle. Hedef: alan, gözlenebilir davranış, ölçüm (evet-hayır / yüzde / sıklık / süre / düzey), başlangıç, hedef düzey, süre (hafta), evde destek, "aile görür". | `clinic_goals` (genişledi: `domain`, `measure`, `baseline`, `target`, `weeks`, `home_support`, `shared`, `status`, `position`, `template_key`) |
| 2 | [K] | Aile programı modülü: amaç, evde uygulama, kontrol listesi (≤ 8), durum (planlandı / etkin / tamamlandı). | `care_modules` |
| 3 | [K] | "Aileyle paylaş": tek bildirim. | `care_plan_publish(link)` → ebeveynlere `care_plan_shared` |
| 4 | [P] | Uzmanım › çocuk › Takip planı: paylaşılan hedefler (durumuyla) + etkin/tamamlanan modüller; her modülde günde tek dokunuş "Bugün uyguladım", isteğe bağlı zorluk (1–5), uygulayamadıysa neden (vakit yoktu / unuttum / çocuk direndi / nasıl yapacağımı bilemedim). | `family_care_plan(link)`, `care_module_logs` |
| 5 | [K] | Uzman uygulama kayıtlarını görür (son 14 gün: kaç gün, ortalama zorluk, engeller); hedefleri haftalık GAS (−2…+2) ile işaretler — **puanlar aileye görünmez**. | `care_module_logs`, `goal_ratings` |

Kurallar: Aileyle paylaşılmayan hedef (eski hedefler dahil, `shared=false`) yalnız klinikte. Planlandı durumundaki modül aileye görünmez. Ebeveynin zorluk bildirimi bir puan değildir, ekranda ölçek gibi gösterilmez. Hiçbir hedef tanı değildir; paket adları ihtiyaç alanıyla yazılır, tanı etiketi zorunlu değildir.

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

**Görünürlük (kullanıcı, 26 Ekim 2026):** özellik bayrağa bağlı: `clinician_verification`, **ilk sürümde KAPALI**. Kapalıyken ClinicApp'te "Belgeni yükle" satırı ve sayfası görünmez, sunucu başvuru almaz; ParentApp'te rozet de "Belgesi incelenmedi" etiketi de gösterilmez (yalnız uyarı + veli beyanı); aile yanıtlarında `verified_as` null döner. Açmak: yönetim paneli → Bayraklar → `clinician_verification` (önce kişiye istisnayla denenebilir). Karar hatırlatması `DURUM.md` Açık işler.

**Karar (kullanıcı, 26 Ekim 2026): seçenek 2, yarı otomatik** — öneri `proposed/20261026050000_clinician_verification.sql`, Edge Function `clinician-verify`, meslek eşlemesi `veri/uzman_meslekleri.json`. Uyarı + veli beyanı (1) rozet olsa da kalır.

### 14.1 Akış

| # | Kim | Adım | Veritabanı |
|---|---|---|---|
| 1 | [K] | "Hesabını doğrula": meslek seç (BCBA ise BACB sicil no), e-Devlet'ten indirdiği **Yükseköğretim Mezun Belgesi** PDF'ini yükle (fotoğraf/tarama yok; BCBA'da belge isteğe bağlı). | `clinician_verification_start(meslek, bacb)` → `{id, upload_path}`; Storage `verify/<uzman>/<id>.pdf`; `clinician_verification_submit(id)` |
| 2 | [S] | Ön kontrol (birkaç saniye, kendi sunucumuzda, PDF metin katmanı): belge okunuyor mu, e-Devlet izi, mezuniyet, barkod, **ad** (hesap adı belgede mi), **bölüm** (meslek ↔ bölüm), **derece** (klinik psikolog: yüksek lisans/doktora; ön lisans lisans yerine geçmez). Yalnız kesin durumlar kendiliğinden ret: okunamayan belge, öğrenci belgesi, başka hesabın barkodu. Kişinin adı ve kimlik numarası saklanmaz. | Edge Function `clinician-verify` → `clinician_verification_autocheck` |
| 3 | Yönetici (support/owner, iki adımlı) | Panelde ön kontrol özeti + belge. Barkodu **turkiye.gov.tr/belge-dogrulama**'da sorgular, açılan asıl belgeyi yüklenenle karşılaştırır; BCBA'da **BACB sicili** (ad + sertifika no, durum etkin, disiplin kaydı). Şüphede kısa telefon. Onay ya da nedenli ret. Belge görüntüleme ve karar denetim kaydına yazılır. | `admin_verifications`, `admin_verification_open`, `admin_verification_decide`, `admin_verification_suspend` |
| 4 | [S] | Onayda belge dosyası silinir (panel kovadan siler), yalnız özet kalır (üniversite, bölüm, derece, mezuniyet yılı). Uzmana `verification_approved` / `verification_rejected` (neden + açıklama) / `verification_suspended`. | `clinician_verifications.summary`, `clinicians.verified_profession`, `verified_at` |
| 5 | [P] | Davet ekranı, açılış sayfası ve Uzmanım'da **"Belgesi incelendi: Klinik psikolog"** rozeti; rozet yoksa "Belgesi incelenmedi" etiketi. Uyarı ve veli beyanı her durumda kalır. | `verified_as`: `clinic_invite_open`, `claim_clinic_invite`, `clinic_invite_preview`, `family_pending_invites`, `family_clinic_links` |
| 6 | [S] | Uzman adını değiştirirse rozet düşer (belgedeki adla eşleşme bozulur), yeniden yükler. BCBA yılda bir yeniden bakılır (`recheck_at`). Şikâyette rozet askıya alınır. | tetikleyici `clinicians_verified_name_guard` |

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

## 13. Kim kimi nasıl ekler — güncel tablo (26 Ekim 2026)

| Kim | Kimi / neyi | Nasıl | Geçerlilik | Durum |
|---|---|---|---|---|
| Ebeveyn | İkinci ebeveyn | ParentApp Aile › + › Ebeveyn › davet kodu; diğeri Aile › Hesap › "Aileye katıl" | 6 karakter, 15 dk | uygulandı |
| Ebeveyn | Çocuğun cihazı | Aile › çocuk › "Giriş kodu üret"; GameApp'te yazılır | çocuk başına, 15 dk, tek kullanım | uygulandı |
| Uzman | Aile | ClinicApp "Aileyi davet et" → bağlantı (WhatsApp/e-posta/SMS/kopyala) + kod; isteğe bağlı taslak takip planı | **48 saat** (bağlanınca 30 gün içinde çocuk paylaşımı) | öneri (bölüm 10) |
| Ebeveyn | Uzman → çocuk | Kayıtta bağlantı/e-posta ile ya da sonradan kod/bağlantıyla uzman tanımlanır; uzmanın önerdiği çocuğu kontrol edip düzeltir, uyarıyı okuyup "Onayla ve paylaş" (çocuk o an oluşur); istemezse reddeder | — | öneri (bölüm 10) |
| Ebeveyn | Aynı uzmana başka çocuk | Uzmanım'da "Ekle" (kodsuz) | — | uygulandı |
| Ebeveyn | Yeni uzmana geçmiş | Paylaşırken ya da sonradan "Önceki uzmanın kayıtlarını paylaş" | geri alınabilir | öneri (bölüm 11) |
| Ebeveyn / uzman | Paylaşımı durdurma | "Paylaşımı durdur" | hemen | uygulandı |
| Klinik sahibi | Ekibe uzman | "Ekibe uzman davet et"; yeni uzman kayıtta "Kodum var" ya da Ekip bölümünden | 8 karakter, 15 dk; koltuk sınırı; Bireysel pakette yok | uygulandı |
| Klinik sahibi | Ekip üyesine danışan | Danışan › "Ekip erişimi" (aç/kapat, sorumlu yap) | — | uygulandı |
| Ekip üyesi | Aile | Kendi davet bağlantısı; davet ettiği aileyi sahip de görür | 48 saat | öneri (bölüm 10) |

---

> **ParentApp penceresinin önerileri (22 Ekim 2026, uygulanmadı).** Bölüm numaraları `P` ile başlar.

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
| 3b | [O] | Çocuk oyunda ister (**henüz oyunda yok**: hatırlatıcı) → ebeveynlere bildirim → [P] onaylar/reddeder. | `request_reward(ödül, adet)` → `decide_reward_request(istek, onay, not)` |
| 4 | [P] | Bir ya da birkaç çocuk seçip taş düşer (ceza), isteğe bağlı nedenle → çocuğa bildirim. | `deduct_sun_stones(çocuk, adet, neden)` (çocuk başına) |
| 5 | [O] | Bakiye ve hareketler: `sun_stone_balance(ben)`, `sun_stone_ledger` (kendi satırları), `rewards` (kendine açık olanlar), `reward_requests` (kendi). | — |

## P12. Abonelik (öneri, 21 Ekim 2026)

| # | Kim | Ne olur | Nerede |
|---|---|---|---|
| 1 | [P] | Kayıt + e-posta doğrulama → 7 günlük deneme başlar. Görevler ekranında "Deneme: N gün kaldı". | `families.trial_started_at`, `family_access()` |
| 2 | [P] | Deneme bitince uygulama açılışta üyelik ekranını gösterir (Aylık / Yıllık). "Şimdilik ücretsiz devam et" seçilebilir. | uygulama |
| 3 | [P] | Satın alma mağazada (App Store); RevenueCat (karar 22 Ekim 2026) olayı sunucuya iletir; sunucu güncel durumu RevenueCat'ten yeniden okur (olay sırası, "geri yükle" ile hesap değişimi). ParentApp RevenueCat'e Supabase kullanıcı kimliğiyle giriş yapar (`app_user_id`). Elle verilen premium (`source` manual/web) mağaza aboneliği bitince ezilmez. | `billing-webhook` → `set_family_subscription` |
| 4 | [S] | Ücretsiz planda: 3 etkin görev, 1 çocuk; ödül/taş düşme/ebeveyn mesajı/gözlem notu kapalı. Onay, oyun, uzman paylaşımı açık. | tetikleyiciler (`hint = premium_required`) |
| 5 | [P] | Aile › Hesap › Üyelik: durum, plan, yenileme tarihi, "Satın alımları geri yükle", "Aboneliği yönet" (App Store). | uygulama |

Anahtar: `app_config.billing.enforce = false` iken (bugün) kimse kısıtlanmaz; ödeme bağlanınca açılır.
