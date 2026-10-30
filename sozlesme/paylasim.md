# Sosyal medya paylaşımı (Marketing → onay → yayın)

> 28 Ekim 2026, kullanıcı kararı: içerikler Marketing penceresinde standart paketle hazırlanır, **her paylaşım panelde owner onayıyla** yayımlanır; paylaşım servisi **Zernio** (ücretsiz plan, 2 hesap: Instagram + TikTok; YouTube Shorts sonra ücretli 3. hesap). X şimdilik yok (her gönderi ücretli, kitle zayıf); Facebook ayrı kanal değil (Instagram'ın "Facebook'ta da paylaş" ayarı denenecek). Kurallar: `hukuk/45-pazarlama-kurallari.md` §8.

## Kim ne yapar

| Kim | Ne |
|---|---|
| Marketing penceresi (`amy60946/marketing`, özel) | Paketi hazırlar (video + platform metinleri + kontrol listesi), ana dala gönderir; GitHub iş akışı `tools/paylasim/gonder.mjs` ile servise **taslak** olarak yükler. Onay durumunu ve düzeltme notlarını `durum` ile okur. Yayınlayamaz. |
| `social` Edge Function (bu depo) | Tek kapı. Marketing'i GitHub'ın imzaladığı kimlikle (OIDC) tanır: yalnız `amy60946/marketing`, yalnız `main`. Paketi denetler, taslak açar. Panel isteğinde yetkiyi SQL'e sordurur. Zernio anahtarı yalnız burada. |
| Yönetim paneli › Paylaşım (owner) | Videoyu izler, metinleri düzeltir, saat ve platform seçer, **Onayla** / **Düzeltme iste** / **Sil**. Her biri gerekçeli ve denetim kaydında. |
| Zernio | Onaylanan gönderiyi saatinde platformlara yollar; sonuç sayılarını verir. Sosyal hesaplar Zernio'ya **platformun kendi izin ekranıyla** bağlanır; şifre kimseye verilmez. |

## Akış

1. Marketing: `paylasim/hazir/<id>/` klasörüne `paket.json` + medyayı koyar ve ana dala alır. Video: `video.mp4` (+ isteğe bağlı `kapak.jpg`); kaydırmalı: `01.jpg`, `02.jpg` … (sırayla); hikâye: `video.mp4` ya da tek `01.jpg`.
2. İş akışı: `upload` → dosya servise yüklenir → `submit` → servis üzerinde **taslak** (`isDraft`). Kurala uymayan paket hata listesiyle geri döner, taslak açılmaz.
3. Panel › Paylaşım › **Onay bekliyor**: owner videoyu izler; uyarılar (sağlık iddiası, çocuğa çağrı, kaynaksız araştırma) üstte. Onaylayınca taslak **planlı** olur (TikTok'un "içeriği önizledim" ve "yayın için açık rıza" alanları yalnız bu anda işaretlenir).
4. **Düzeltme iste**: not taslağa yazılır ve **hemen** Marketing'e gider (aşağıda "Geri bildirim"); Marketing aynı `id` ile `surum`u artırıp yeniden gönderir, kullanıcıya "panelde yeni sürüm hazır" der; eski taslak kendiliğinden silinir. Onay ya da yeniden düzeltme yine panelde (döngü).
5. Yayından sonra sonuç sayıları (izlenme, beğeni, yorum, paylaşım, kaydetme) panelde ve `durum` çıktısında görünür. Servis planı analizi kapsamıyorsa boş kalır.

## Paket (`paket.json`)

| Alan | Zorunlu | Kural |
|---|---|---|
| `id` | evet | küçük harf, rakam, tire; 3–80 (ör. `2026-11-03-uyku-rutini`) |
| `surum` | hayır | 1–99, varsayılan 1. Düzeltmede artırılır |
| `baslik` | evet | 3–120; panelde ve servis kaydında görünen iç başlık |
| `tur` | hayır | `video` (varsayılan) · `kaydirmali` · `hikaye` (29 Ekim 2026). Aşağıdaki "Türler" tablosu |
| `platformlar` | evet | `instagram`, `tiktok`, `youtube`, `facebook`, `threads`, `linkedin` (servise bağlı hesabı olanlar) |
| `metin.<platform>` | seçilen her platform (hikâyede yok) | Instagram/TikTok 2200, YouTube açıklaması 5000, Threads 500, LinkedIn 3000 karakter. Etiketler metnin içine yazılır |
| `youtube_baslik` | YouTube varsa | en çok 100, `<` `>` olmaz |
| `onerilen_zaman` | hayır | saat dilimli ISO, ör. `2026-11-03T20:30:00+03:00`; panelde değiştirilebilir. Servisteki taslağa saat olarak verilmez (saati geçen taslak servis listesinden düşüyor), metadata'da durur; gerçek saat onayda verilir |
| `yapay_zeka` | evet (true/false) | **Kullanıcı kararı 29 Ekim 2026: `false` gönderilir** (etiket açılmaz, `hukuk/45` 8.4). `true` olursa Instagram "AI info", TikTok "AI-generated", YouTube "değiştirilmiş/sentetik içerik" etiketi açılır. Panelde anahtar yok; değer paketten |
| `ticari` | evet (true/false) | Ürün/marka tanıtımı varsa `true` → TikTok "Your brand" beyanı |
| `kaynaklar` | bilgi içeriğinde | en çok 10; araştırma/literatür künyesi (`hukuk/45` 1.4) |
| `kontrol` | evet, dördü de `true` | `saglik_iddiasi_yok`, `cocuga_cagri_yok`, `gercek_cocuk_verisi_yok`, `muzik_telifsiz` |
| `not` | hayır | onaylayana not (en çok 1000) |
| `video`, `gorseller`, `kapak` | — | gönderici doldurur (yükleme sonrası adresler; `gorseller` sırayla) |

### Türler

| `tur` | Medya | Platformlar | Metin | Not |
|---|---|---|---|---|
| `video` | tek dikey video (9:16), isteğe bağlı kapak | hepsi (YouTube yalnız burada) | evet | Instagram Reels, TikTok video, YouTube Shorts |
| `kaydirmali` | 2–20 görsel, JPG önerilir (1080×1350 ya da 1080×1920); Facebook seçiliyse en çok 10 | `instagram`, `tiktok`, `facebook` | evet | TikTok'ta fotoğraf gönderisi: başlık ilk satırdan 90 karakter, tam metin açıklamada; düet/birleştirme yok |
| `hikaye` | tek görsel ya da en çok 60 sn video | `instagram`, `facebook` | **yok** (platformlar hikâyede yazı almaz) | 24 saat görünür; yazı/etiket görselin içine işlenir |

Sabit platform ayarları (sunucuda): TikTok herkese açık, yorum açık, düet/birleştirme kapalı; YouTube herkese açık, **çocuklara yönelik değil** (`madeForKids: false` — içerik ebeveyne), kategori Eğitim; Instagram Reels akışta da görünür.

## Marketing iş akışı (örnek, `amy60946/marketing/.github/workflows/paylasim.yml`)

```yaml
name: Paylaşım
on:
  push:
    branches: [main]
    paths: ['paylasim/hazir/**']
  schedule: [{ cron: '17 6 * * *' }]   # her gün durum
  workflow_dispatch:
permissions:
  contents: write
  id-token: write        # GitHub kimliği (sır yok)
jobs:
  gonder:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/checkout@v4
        with: { repository: amy60946/ortak, path: ortak }
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - name: Yeni paketleri gönder
        if: github.event_name == 'push'
        run: |
          dirs=$(git diff --name-only ${{ github.event.before }} ${{ github.sha }} -- paylasim/hazir | cut -d/ -f1-3 | sort -u | while read d; do [ -f "$d/paket.json" ] && echo "$d"; done)
          [ -z "$dirs" ] || node ortak/tools/paylasim/gonder.mjs gonder $dirs
      - name: Durum
        if: always()
        run: node ortak/tools/paylasim/gonder.mjs durum paylasim/durum.json
      - name: Durumu kaydet
        if: always()
        run: |
          git config user.name "paylasim-bot"; git config user.email "paylasim-bot@users.noreply.github.com"
          git add paylasim/durum.json; git commit -m "paylaşım durumu" || true; git push || true
```

## Geri bildirim (panel → Marketing, 29 Ekim 2026)

Kullanıcı isteği: "Düzeltme istediğimde talebim Marketing'e doğrudan aksın; Marketing düzeltsin, bana tekrar göndersin."

- Panelde **Düzeltme iste**, **Onayla** ya da **Sil** (yalnız Marketing'in gönderdiği gönderiler) başarılı olunca `social` işlevi `amy60946/marketing` deposundaki **açık geri bildirim PR'ına** (dal `paylasim-geri-bildirim`, taslak PR, hiç birleştirilmez) bir yorum yazar ve paylaşım iş akışını çalıştırır (`durum.json` tazelenir).
- Marketing oturumu bu PR'a abonedir (`subscribe_pr_activity`); yorum gelince uyanır. Yorum: başlık (✏️ Düzeltme istendi / ✅ Onaylandı / 🗑️ Silindi), paket ve sürüm, alıntılanmış not, sonraki sürüm numarası; sonda makine satırı `<!-- paylasim:{"olay","id","paket","surum"} -->`.
- Düzeltmede Marketing: notu uygular, `surum`+1 paketi kullanıcının onayıyla ana dala alır, kullanıcıya "panelde yeni sürüm hazır" der. Yayın kararı yalnız panelde.
- Bildirim gidemezse panel işlemi yine geçerlidir; panel "Marketing'e bildirilemedi: <neden>" gösterir, günlük iş akışı yedektir.
- Anahtar: `MARKETING_GITHUB_TOKEN` (Supabase → Edge Functions → Secrets). GitHub **ince yetkili** anahtar (fine-grained): yalnız `amy60946/marketing`; izinler **Pull requests: Read and write**, **Actions: Read and write** (Metadata: Read kendiliğinden). Süre en çok 1 yıl; bitmeden yenilenir. Anahtar yoksa panel "otomatik bildirim kapalı" der.
- Yorumlar anahtarın sahibinin (kullanıcının) adıyla görünür; sondaki _Yönetim paneli (otomatik)_ satırı ayırır.

## Ölçümler (30 Ekim 2026)

Kaynak: Zernio'nun gönderi analizi (`GET /v1/analytics?postId=`); ayrı Instagram/TikTok anahtarı gerekmez. `status` ve panel yayımlanan son 20 gönderi için verir:
`stats` (toplam) ve `statsByPlatform[]` (`platform`, `sync`, `url` + aynı alanlar), `measuredAt` (ölçüm zamanı). Alanlar: `views` izlenme, `reach` erişim, `impressions` gösterim,
`likes`, `comments`, `shares` paylaşım/gönderme, `saves` kaydetme, `avgWatchMs` ortalama izlenme süresi (ms), `totalWatchMs` toplam izlenme (ms), `skipRate` ilk 3 sn'de geçme (%, Instagram Reels),
`completionRate` sonuna kadar izleme (0–1, TikTok işletme), `follows`, `profileViews`. Platform vermezse `null`. Saniye saniye izlenme eğrisi ve yeniden paylaşım yok.
Gönderici `durum` her çalıştığında `paylasim/olcum/<paket>.jsonl`'a satır ekler: `{t, id, surum, toplam, platformlar}`.

## `social` işlevi

`POST https://uhelhxqgpcjemadhsifx.supabase.co/functions/v1/social` — "Verify JWT" **kapalı**. Secret: `ZERNIO_API_KEY` (Supabase → Edge Functions → Secrets). Kod ve testleri: `supabase/functions/social/index.ts`, `index.test.ts`.

| Kim | `action` | Gövde | Döner |
|---|---|---|---|
| Marketing | `upload` | `filename, contentType (video/mp4, video/quicktime, image/jpeg, image/png), size ≤ 1 GB` | `uploadUrl` (1 saat, PUT), `publicUrl` |
| Marketing | `submit` | `paket` | `id, warnings` · 400 `errors[]` · 409 sürüm zaten onaylı |
| Marketing | `status` | — | `posts[]` (özet + `tur` + `images` + `changesNote` + `stats`), `usage` (plan, bu dönem kullanılan / hak, yenilenme günü; kullandıkça öde planında bağlı hesap sayısı ve bu dönem harcama; servis vermezse `null`). 29 Ekim 2026: hesap **Usage-Based** (kullandıkça öde) planında → gönderi sınırı yok, ücret bağlı hesap başına |
| Panel (her admin) | `overview` | — | `role, accounts[], posts[], usage` |
| Panel (owner) | `approve` | `id, reason, scheduledFor (≥ 2 dk sonra, ≤ 180 gün), platforms, captions, yapay_zeka` | `post, notify` |
| Panel (owner) | `request_changes` | `id, reason` (not Marketing'e gider) | `post, notify` |
| Panel (owner) | `delete` | `id, reason` (yayımlanmış olan silinmez) | `deleted, notify` |

`notify`: `null` (anahtar yok ya da Marketing'in gönderisi değil), `{ok: true}` ya da `{ok: false, error}`.

Gönderi grupları (`group`): `onay` (taslak), `duzeltme` (düzeltme istenmiş taslak), `planli`, `yayinda`, `sorun` (başarısız / kısmen başarısız).

Yetki: `admin_social_check(action, ref, reason, after, dry)` (`migrations/20261028300000_admin_social.sql`, uygulandı 28 Ekim 2026): `view` her admin; `approve`, `request_changes`, `delete` yalnız owner + iki adımlı doğrulama; değişiklik servis işlemi başarılı olunca `admin_audit`'e (`system`, `social:<id>`) yazılır. Bu veritabanında içerik ya da hesap bilgisi tutulmaz.

## Kurulum (kullanıcı)

1. ✔ Pazarlama e-postası; Instagram profesyonel hesap, TikTok işletme hesabı; ikisinde iki adımlı doğrulama.
2. ✔ zernio.com → ücretsiz plan → Accounts → Instagram ve TikTok'u bağla (platformun izin ekranı).
3. ✔ Zernio → API Keys → yeni anahtar → **Supabase → Edge Functions → Secrets → `ZERNIO_API_KEY`** (anahtar sohbete ya da depoya yazılmaz).
4. SQL: `migrations/20261028300000_admin_social.sql` ✔ uygulandı; işlev `social` ✔ yayında (Verify JWT kapalı) — 28 Ekim 2026.
5. ✔ Marketing penceresi: iş akışı ve ilk paket (29 Ekim 2026, deneme-1 → düzeltme → sürüm 2).
6. Geri bildirim: Marketing penceresi `paylasim-geri-bildirim` dalından taslak PR açar ve abone olur; kullanıcı ince yetkili GitHub anahtarını `MARKETING_GITHUB_TOKEN` olarak ekler; `social` işlevi yeniden yayımlanır.
