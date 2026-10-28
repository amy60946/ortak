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

1. Marketing: `paylasim/hazir/<id>/` klasörüne `paket.json` + `video.mp4` (+ isteğe bağlı `kapak.jpg`) koyar ve ana dala alır.
2. İş akışı: `upload` → dosya servise yüklenir → `submit` → servis üzerinde **taslak** (`isDraft`). Kurala uymayan paket hata listesiyle geri döner, taslak açılmaz.
3. Panel › Paylaşım › **Onay bekliyor**: owner videoyu izler; uyarılar (sağlık iddiası, çocuğa çağrı, kaynaksız araştırma) üstte. Onaylayınca taslak **planlı** olur (TikTok'un "içeriği önizledim" ve "yayın için açık rıza" alanları yalnız bu anda işaretlenir).
4. **Düzeltme iste**: not taslağa yazılır; Marketing `durum` ile okur, aynı `id` ile `surum`u artırıp yeniden gönderir; eski taslak kendiliğinden silinir.
5. Yayından sonra sonuç sayıları (izlenme, beğeni, yorum, paylaşım, kaydetme) panelde ve `durum` çıktısında görünür. Servis planı analizi kapsamıyorsa boş kalır.

## Paket (`paket.json`)

| Alan | Zorunlu | Kural |
|---|---|---|
| `id` | evet | küçük harf, rakam, tire; 3–80 (ör. `2026-11-03-uyku-rutini`) |
| `surum` | hayır | 1–99, varsayılan 1. Düzeltmede artırılır |
| `baslik` | evet | 3–120; panelde ve servis kaydında görünen iç başlık |
| `platformlar` | evet | `instagram`, `tiktok`, `youtube`, `facebook`, `threads`, `linkedin` (servise bağlı hesabı olanlar) |
| `metin.<platform>` | seçilen her platform | Instagram/TikTok 2200, YouTube açıklaması 5000, Threads 500, LinkedIn 3000 karakter. Etiketler metnin içine yazılır |
| `youtube_baslik` | YouTube varsa | en çok 100, `<` `>` olmaz |
| `onerilen_zaman` | hayır | saat dilimli ISO, ör. `2026-11-03T20:30:00+03:00`; panelde değiştirilebilir |
| `yapay_zeka` | evet (true/false) | Gerçekçi yapay zekâ görüntü/ses varsa `true` → Instagram "AI info", TikTok "AI-generated", YouTube "değiştirilmiş/sentetik içerik" etiketi |
| `ticari` | evet (true/false) | Ürün/marka tanıtımı varsa `true` → TikTok "Your brand" beyanı |
| `kaynaklar` | bilgi içeriğinde | en çok 10; araştırma/literatür künyesi (`hukuk/45` 1.4) |
| `kontrol` | evet, dördü de `true` | `saglik_iddiasi_yok`, `cocuga_cagri_yok`, `gercek_cocuk_verisi_yok`, `muzik_telifsiz` |
| `not` | hayır | onaylayana not (en çok 1000) |
| `video`, `kapak` | — | gönderici doldurur (yükleme sonrası adres) |

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

## `social` işlevi

`POST https://uhelhxqgpcjemadhsifx.supabase.co/functions/v1/social` — "Verify JWT" **kapalı**. Secret: `ZERNIO_API_KEY` (Supabase → Edge Functions → Secrets). Kod ve testleri: `supabase/functions/social/index.ts`, `index.test.ts`.

| Kim | `action` | Gövde | Döner |
|---|---|---|---|
| Marketing | `upload` | `filename, contentType (video/mp4, video/quicktime, image/jpeg, image/png), size ≤ 1 GB` | `uploadUrl` (1 saat, PUT), `publicUrl` |
| Marketing | `submit` | `paket` | `id, warnings` · 400 `errors[]` · 409 sürüm zaten onaylı |
| Marketing | `status` | — | `posts[]` (özet + `changesNote` + `stats`) |
| Panel (her admin) | `overview` | — | `role, accounts[], posts[]` |
| Panel (owner) | `approve` | `id, reason, scheduledFor (≥ 2 dk sonra, ≤ 180 gün), platforms, captions, yapay_zeka` | `post` |
| Panel (owner) | `request_changes` | `id, reason` (not Marketing'e gider) | `post` |
| Panel (owner) | `delete` | `id, reason` (yayımlanmış olan silinmez) | `deleted` |

Gönderi grupları (`group`): `onay` (taslak), `duzeltme` (düzeltme istenmiş taslak), `planli`, `yayinda`, `sorun` (başarısız / kısmen başarısız).

Yetki: `admin_social_check(action, ref, reason, after, dry)` (`migrations/20261028300000_admin_social.sql`, uygulandı 28 Ekim 2026): `view` her admin; `approve`, `request_changes`, `delete` yalnız owner + iki adımlı doğrulama; değişiklik servis işlemi başarılı olunca `admin_audit`'e (`system`, `social:<id>`) yazılır. Bu veritabanında içerik ya da hesap bilgisi tutulmaz.

## Kurulum (kullanıcı)

1. ✔ Pazarlama e-postası; Instagram profesyonel hesap, TikTok işletme hesabı; ikisinde iki adımlı doğrulama.
2. ✔ zernio.com → ücretsiz plan → Accounts → Instagram ve TikTok'u bağla (platformun izin ekranı).
3. ✔ Zernio → API Keys → yeni anahtar → **Supabase → Edge Functions → Secrets → `ZERNIO_API_KEY`** (anahtar sohbete ya da depoya yazılmaz).
4. SQL: `migrations/20261028300000_admin_social.sql` ✔ uygulandı; işlev `social` ✔ yayında (Verify JWT kapalı) — 28 Ekim 2026.
5. Marketing penceresi: iş akışını ve ilk paketi ekler; panel › Paylaşım'da onay.
