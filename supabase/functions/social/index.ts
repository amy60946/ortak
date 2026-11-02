// social: pazarlama paylaşımı köprüsü — Marketing iş akışı ↔ paylaşım servisi (Zernio) ↔ yönetim paneli "Paylaşım" ekranı.
// Akış ve kurallar: sozlesme/paylasim.md, hukuk/45-pazarlama-kurallari.md §8.
// Hesap şifresi hiçbir yerde yok: sosyal hesaplar Zernio'ya platformun kendi izin ekranıyla bağlanır; servisin anahtarı yalnız burada.
// Secret (Supabase → Edge Functions → Secrets): ZERNIO_API_KEY. İsteğe bağlı: MARKETING_GITHUB_TOKEN (panel olayını Marketing'e
// hemen iletir), SOCIAL_REPO (varsayılan amy60946/marketing).
// "Verify JWT" KAPALI yayınlanır: Marketing GitHub'ın imzaladığı kimlikle gelir (verifyGithub); panel isteğinde yetkiyi
// yöneticinin kendi oturumuyla SQL denetler (admin_social_check, migrations/…_admin_social.sql).
// Testi index.test.ts (node --experimental-strip-types --test supabase/functions/social/*.test.ts); Deno.serve yalnız Deno'da çalışır.
//
// İstekler:
//   Marketing (GitHub Actions kimliği, yalnız amy60946/marketing ana dalı):
//     { action: 'upload', filename, contentType, size }  →  { uploadUrl, publicUrl }   dosyayı uploadUrl'e PUT et
//     { action: 'submit', paket }                        →  { id, warnings }           servis üzerinde TASLAK açar
//     { action: 'status' }                               →  { posts, usage }           durum, düzeltme notu, sonuç sayıları, gönderi hakkı
//   Panel (yöneticinin Supabase oturumu; rol ve iki adımlı doğrulama SQL'de: admin_social_check):
//     { action: 'overview' }                                              her admin
//     { action: 'approve', id, reason, scheduledFor, platforms, captions, yapay_zeka }   owner → taslak planlanır
//     { action: 'request_changes', id, reason }                           owner → taslak "düzeltme" olur, not Marketing'e döner
//     { action: 'delete', id, reason }                                    owner → yayımlanmamış gönderi silinir

// =============================================================================================
// 1. Paket kuralları (saf)
// =============================================================================================
// Paket = Marketing'in hazırladığı tek gönderi (video + platform metinleri + kontrol listesi). Gönderi paylaşım servisinde (Zernio)
// TASLAK olarak açılır; yalnız panelde owner onaylayınca planlanır. Marketing'in eli hiçbir zaman "yayınla"ya değmez.

export const PLATFORMS = ['instagram', 'tiktok', 'youtube', 'facebook', 'threads', 'linkedin'] as const;
export type Platform = (typeof PLATFORMS)[number];
export const TZ = 'Europe/Istanbul';
// Gönderi türü (29 Ekim 2026): video (Reels / TikTok / Shorts), kaydırmalı (2–20 görsel), hikâye (tek görsel ya da video, metinsiz)
export const TURLER = ['video', 'kaydirmali', 'hikaye'] as const;
export type Tur = (typeof TURLER)[number];
export const TUR_PLATFORMS: Record<Tur, Platform[]> = {
  video: [...PLATFORMS],
  kaydirmali: ['instagram', 'tiktok', 'facebook'],
  hikaye: ['instagram', 'facebook'],
};

// Platform metin sınırları (karakter); YouTube'da metin = açıklama
const MAX_TEXT: Record<Platform, number> = {
  instagram: 2200, tiktok: 2200, youtube: 5000, facebook: 5000, threads: 500, linkedin: 3000,
};
// Marketing'in işaretlemesi gereken kontrol listesi (hukuk/45): biri eksikse paket reddedilir
export const CHECKS = {
  saglik_iddiasi_yok: 'Sağlık iddiası yok (tanı, tedavi, iyileştirme vaadi yok)',
  cocuga_cagri_yok: 'Çocuğa doğrudan çağrı yok',
  gercek_cocuk_verisi_yok: 'Gerçek kullanıcı ya da çocuk verisi yok',
  muzik_telifsiz: 'Müzik ve görseller telifsiz ya da lisanslı',
} as const;

export type Paket = {
  id: string;
  surum: number;
  baslik: string;
  tur: Tur;
  video?: string;
  gorseller: string[];
  kapak?: string;
  platformlar: Platform[];
  metin: Partial<Record<Platform, string>>;
  youtube_baslik?: string;
  onerilen_zaman?: string;
  yapay_zeka: boolean;
  ticari: boolean;
  kaynaklar: string[];
  kontrol: Record<keyof typeof CHECKS, boolean>;
  not?: string;
};

// deno-lint-ignore no-explicit-any
type Any = any;
const str = (v: unknown) => (typeof v === 'string' ? v.trim() : '');
const https = (v: string) => /^https:\/\/[^\s]+$/.test(v);

export function parsePaket(raw: Any): { paket?: Paket; errors: string[] } {
  const e: string[] = [];
  if (!raw || typeof raw !== 'object') return { errors: ['Paket bir JSON nesnesi olmalı'] };
  const id = str(raw.id);
  if (!/^[a-z0-9][a-z0-9-]{2,79}$/.test(id)) e.push('id: küçük harf, rakam ve tire; 3–80 karakter');
  const surum = raw.surum === undefined ? 1 : Number(raw.surum);
  if (!Number.isInteger(surum) || surum < 1 || surum > 99) e.push('surum: 1–99 tam sayı');
  const baslik = str(raw.baslik);
  if (baslik.length < 3 || baslik.length > 120) e.push('baslik: 3–120 karakter');
  const tur = (raw.tur === undefined ? 'video' : str(raw.tur)) as Tur;
  if (!TURLER.includes(tur)) e.push(`tur: ${TURLER.join(', ')}`);
  const video = str(raw.video) || undefined;
  const gorseller: string[] = Array.isArray(raw.gorseller) ? raw.gorseller.map(str).filter(Boolean) : [];
  if (video && !https(video)) e.push('video: https bağlantısı (önce "upload" ile yükle)');
  if (gorseller.some((g) => !https(g))) e.push('gorseller: her biri https bağlantısı (önce "upload" ile yükle)');
  const list: unknown[] = Array.isArray(raw.platformlar) ? raw.platformlar : [];
  const platformlar = [...new Set(list.map(str))] as Platform[];
  if (tur === 'video') {
    if (!video) e.push('video: video türünde gerekli');
    if (gorseller.length) e.push('gorseller: video türünde olmaz');
  } else if (tur === 'kaydirmali') {
    const max = platformlar.includes('facebook') ? 10 : 20;
    if (video) e.push('video: kaydırmalıda olmaz (yalnız görsel)');
    if (gorseller.length < 2 || gorseller.length > max) e.push(`gorseller: kaydırmalıda 2–${max} görsel (${gorseller.length})`);
  } else if (tur === 'hikaye') {
    if ((video ? 1 : 0) + gorseller.length !== 1) e.push('hikâye: tek video ya da tek görsel');
  }
  const kapak = tur === 'video' ? str(raw.kapak) || undefined : undefined;
  if (kapak && !https(kapak)) e.push('kapak: https bağlantısı');

  if (!platformlar.length) e.push('platformlar: en az bir platform');
  for (const p of platformlar) {
    if (!PLATFORMS.includes(p)) e.push(`platformlar: "${p}" desteklenmiyor (${PLATFORMS.join(', ')})`);
    else if (TURLER.includes(tur) && !TUR_PLATFORMS[tur].includes(p)) e.push(`platformlar: "${p}" ${tur} türünde yok (${TUR_PLATFORMS[tur].join(', ')})`);
  }

  // Hikâyede metin olmaz (platformlar yazı almaz)
  const metin: Partial<Record<Platform, string>> = {};
  for (const p of tur === 'hikaye' ? [] : platformlar) {
    if (!PLATFORMS.includes(p)) continue;
    const t = str(raw.metin?.[p]);
    if (!t) e.push(`metin.${p}: boş olamaz`);
    else if (t.length > MAX_TEXT[p]) e.push(`metin.${p}: en çok ${MAX_TEXT[p]} karakter (${t.length})`);
    metin[p] = t;
  }
  const youtube_baslik = str(raw.youtube_baslik) || undefined;
  if (platformlar.includes('youtube')) {
    if (!youtube_baslik) e.push('youtube_baslik: YouTube için gerekli');
    else if (youtube_baslik.length > 100 || /[<>]/.test(youtube_baslik)) e.push('youtube_baslik: en çok 100 karakter, < > olmaz');
  }
  const onerilen_zaman = str(raw.onerilen_zaman) || undefined;
  if (onerilen_zaman && !isIsoWithZone(onerilen_zaman)) e.push('onerilen_zaman: saat dilimli ISO (ör. 2026-11-01T20:30:00+03:00)');
  if (typeof raw.yapay_zeka !== 'boolean') e.push('yapay_zeka: true/false açıkça yazılmalı (gerçekçi YZ görüntü/ses var mı)');
  if (typeof raw.ticari !== 'boolean') e.push('ticari: true/false açıkça yazılmalı (ürün/marka tanıtımı var mı)');
  const kaynaklar = Array.isArray(raw.kaynaklar) ? raw.kaynaklar.map(str).filter(Boolean) : [];
  if (kaynaklar.length > 10) e.push('kaynaklar: en çok 10');
  const kontrol = {} as Paket['kontrol'];
  for (const k of Object.keys(CHECKS) as (keyof typeof CHECKS)[]) {
    kontrol[k] = raw.kontrol?.[k] === true;
    if (!kontrol[k]) e.push(`kontrol.${k}: işaretlenmedi — ${CHECKS[k]}`);
  }
  const not = str(raw.not).slice(0, 1000) || undefined;
  if (e.length) return { errors: e };
  return {
    errors: [],
    paket: { id, surum, baslik, tur, video, gorseller, kapak, platformlar, metin, youtube_baslik, onerilen_zaman,
             yapay_zeka: raw.yapay_zeka, ticari: raw.ticari, kaynaklar: kaynaklar.slice(0, 10), kontrol, not },
  };
}

export function isIsoWithZone(s: string) {
  return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/.test(s) && !Number.isNaN(Date.parse(s));
}

// Uyarılar: reddetmez, panelde onaylayanın önüne konur (hukuk/45 §1.3 ve §2.1). Bilgi içeriğinde "tedavi" geçebilir;
// karar insanın.
const WATCH: [RegExp, string][] = [
  [/tedavi ed|tedavisi(dir| olur)|iyileştir|giderir|şifa/i, 'Tedavi / iyileştirme gibi okunabilecek ifade'],
  [/klinik olarak kanıtlan|bilimsel olarak kanıtlan|garantili|kesin sonuç|%\s?100/i, 'Kanıt / garanti iddiası'],
  [/terapi yerine|tanı koy|teşhis koy|zekâsını ölç|zekasını ölç|\biq\b/i, 'Tanı / ölçüm iddiası'],
  [/hemen indir|annene|babana|aldır|ailene söyle/i, 'Çocuğa doğrudan çağrı olabilir'],
  [/uzmanlar öneriyor|psikologlar öneriyor|doktorlar öneriyor|uzman onaylı/i, 'Belgesiz uzman önerisi iddiası'],
];
export function warnings(p: Paket): string[] {
  const text = [p.baslik, p.youtube_baslik ?? '', ...Object.values(p.metin)].join('\n');
  const out = WATCH.filter(([re]) => re.test(text)).map(([, label]) => label);
  if (/araştırma|çalışma(lar)?(a göre| gösteriyor)|bilim/i.test(text) && !p.kaynaklar.length) out.push('Araştırmaya dayanıyor ama kaynak yok');
  return out;
}

// --- Zernio gövdeleri ------------------------------------------------------------------------
export type Accounts = Partial<Record<Platform, string>>;
export type Settings = { yapay_zeka: boolean; ticari: boolean; youtube_baslik?: string; kapak?: string; tur: Tur };

// approved: owner panelde önizleyip onayladı (TikTok "önizledim" + "açık rıza" alanları yalnız o zaman true)
export function platformData(p: Platform, s: Settings, approved: boolean): Record<string, unknown> {
  switch (p) {
    case 'instagram':
      if (s.tur === 'hikaye') return { contentType: 'story', isAiGenerated: s.yapay_zeka };
      if (s.tur === 'kaydirmali') return { isAiGenerated: s.yapay_zeka };
      return { isAiGenerated: s.yapay_zeka, shareToFeed: true, ...(s.kapak ? { instagramThumbnail: s.kapak } : {}) };
    case 'tiktok': {
      const common = { privacyLevel: 'PUBLIC_TO_EVERYONE', allowComment: true, commercialContentType: s.ticari ? 'brand_organic' : 'none',
                       contentPreviewConfirmed: approved, expressConsentGiven: approved };
      // Fotoğraf kaydırmalısı: düet/birleştirme yok; işletme fotoğraf yolunda YZ beyan alanı yok (servis true'yu reddeder)
      if (s.tur === 'kaydirmali') return { ...common, mediaType: 'photo', photoCoverIndex: 0 };
      return { ...common, allowDuet: false, allowStitch: false, videoMadeWithAi: s.yapay_zeka };
    }
    case 'youtube':
      // Ebeveyne yönelik içerik: çocuklara yönelik değil (COPPA); kategori 27 = Eğitim
      return { title: s.youtube_baslik, visibility: 'public', madeForKids: false, containsSyntheticMedia: s.yapay_zeka, categoryId: '27' };
    case 'facebook':
      return s.tur === 'hikaye' ? { contentType: 'story' } : {};
    default:
      return {};
  }
}

// TikTok fotoğraf gönderisinde başlık 90 karakterde kesilir; tam metin açıklamaya (description, en çok 4000)
export function tiktokPhotoTitle(caption: string): string {
  const first = caption.split(/\r?\n/)[0].trim();
  return first.length <= 90 ? first : first.slice(0, 89).trimEnd() + '…';
}

// Tek platform girdisi (taslak ve onayda aynı)
export function entry(x: Platform, accountId: string, caption: string | undefined, s: Settings, approved: boolean) {
  const data = platformData(x, s, approved);
  if (s.tur === 'hikaye') return { platform: x, accountId, platformSpecificData: data };
  if (x === 'tiktok' && s.tur === 'kaydirmali') {
    return { platform: x, accountId, customContent: tiktokPhotoTitle(caption ?? ''), platformSpecificData: { ...data, description: caption } };
  }
  return { platform: x, accountId, customContent: caption, platformSpecificData: data };
}

export function mediaOf(p: Pick<Paket, 'tur' | 'video' | 'gorseller' | 'kapak'>) {
  if (p.tur === 'kaydirmali') return p.gorseller.map((url) => ({ type: 'image', url }));
  if (p.tur === 'hikaye') return p.video ? [{ type: 'video', url: p.video }] : [{ type: 'image', url: p.gorseller[0] }];
  return [{ type: 'video', url: p.video, ...(p.kapak ? { thumbnail: p.kapak } : {}) }];
}

export function draftBody(p: Paket, accounts: Accounts, source: string, now = new Date()) {
  const missing = p.platformlar.filter((x) => !accounts[x]);
  if (missing.length) throw new Error(`Paylaşım servisinde bağlı hesap yok: ${missing.join(', ')}`);
  const s: Settings = { yapay_zeka: p.yapay_zeka, ticari: p.ticari, youtube_baslik: p.youtube_baslik, kapak: p.kapak, tur: p.tur };
  return {
    title: p.baslik,
    ...(p.tur === 'hikaye' ? {} : { content: p.metin[p.platformlar[0]] }),
    mediaItems: mediaOf(p),
    platforms: p.platformlar.map((x) => entry(x, accounts[x]!, p.metin[x], s, false)),
    isDraft: true,
    // Taslağa saat verilmez: servis saati geçmiş taslağı listeden düşürüyor (29 Ekim denemesi, sürüm 2). Öneri metadata'da;
    // gerçek saat onayda verilir.
    timezone: TZ,
    metadata: {
      kaynak: 'marketing', paket: p.id, surum: p.surum, tur: p.tur, durum: 'onay_bekliyor', onerilen_zaman: p.onerilen_zaman ?? null,
      yapay_zeka: p.yapay_zeka, ticari: p.ticari,
      youtube_baslik: p.youtube_baslik ?? null, kapak: p.kapak ?? null, kaynaklar: p.kaynaklar, not: p.not ?? null,
      uyarilar: warnings(p), gonderen: source, gonderim: now.toISOString(),
    },
  };
}

// Panelden onay: taslak → planlı. Metinler ve platform listesi panelde düzeltilebilir; saat gelecekte olmalı.
export type Approval = { scheduledFor: string; platforms: Platform[]; captions: Partial<Record<Platform, string>>; yapay_zeka: boolean };
export function parseApproval(raw: Any, now = new Date(), tur: Tur = 'video'): { approval?: Approval; errors: string[] } {
  const e: string[] = [];
  const scheduledFor = str(raw?.scheduledFor);
  if (!isIsoWithZone(scheduledFor)) e.push('Saat geçersiz');
  else if (Date.parse(scheduledFor) < now.getTime() + 2 * 60_000) e.push('Saat en az 2 dakika sonrası olmalı');
  else if (Date.parse(scheduledFor) > now.getTime() + 180 * 86_400_000) e.push('Saat en çok 180 gün sonrası olabilir');
  const platforms = (Array.isArray(raw?.platforms) ? [...new Set(raw.platforms.map(str))] : []) as Platform[];
  if (!platforms.length) e.push('En az bir platform seç');
  for (const p of platforms) if (!PLATFORMS.includes(p)) e.push(`Bilinmeyen platform: ${p}`);
  const captions: Partial<Record<Platform, string>> = {};
  for (const p of tur === 'hikaye' ? [] : platforms) {
    if (!PLATFORMS.includes(p)) continue;
    const t = str(raw?.captions?.[p]);
    if (!t) e.push(`${p} metni boş`);
    else if (t.length > MAX_TEXT[p]) e.push(`${p} metni en çok ${MAX_TEXT[p]} karakter`);
    captions[p] = t;
  }
  if (typeof raw?.yapay_zeka !== 'boolean') e.push('Yapay zekâ etiketi seçilmedi');
  return e.length ? { errors: e } : { errors: [], approval: { scheduledFor, platforms, captions, yapay_zeka: raw.yapay_zeka } };
}

// Servisin kendi yazdığı defter alanları geri gönderilmez (Zernio: "do not set them")
export function ownMeta(post: Any): Record<string, Any> {
  const { usageCounted: _u, usageRefunded: _r, hidden: _h, ...rest } = (post?.metadata ?? {}) as Record<string, Any>;
  return rest;
}

export function approveBody(post: Any, a: Approval, now = new Date()) {
  const meta = ownMeta(post);
  const tur: Tur = TURLER.includes(meta.tur) ? meta.tur : 'video';
  const s: Settings = { yapay_zeka: a.yapay_zeka, ticari: meta.ticari === true, youtube_baslik: meta.youtube_baslik ?? undefined,
                        kapak: meta.kapak ?? undefined, tur };
  const accounts: Accounts = {};
  for (const t of post?.platforms ?? []) {
    const id = typeof t.accountId === 'string' ? t.accountId : t.accountId?._id;
    if (t.platform && id) accounts[t.platform as Platform] = id;
  }
  const missing = a.platforms.filter((x) => !accounts[x]);
  if (missing.length) throw new Error(`Taslakta bu platformun hesabı yok: ${missing.join(', ')}`);
  if (a.platforms.includes('youtube') && !s.youtube_baslik) throw new Error('YouTube başlığı yok');
  return {
    isDraft: false,
    scheduledFor: a.scheduledFor,
    timezone: TZ,
    platforms: a.platforms.map((x) => entry(x, accounts[x]!, a.captions[x], s, true)),
    metadata: { ...meta, durum: 'onaylandi', yapay_zeka: a.yapay_zeka, onay: now.toISOString() },
  };
}

export function changesBody(post: Any, note: string, now = new Date()) {
  return { metadata: { ...ownMeta(post), durum: 'duzeltme', duzeltme_notu: note.trim().slice(0, 1000), duzeltme: now.toISOString() } };
}

// --- Panel ve Marketing için özet --------------------------------------------------------------
export type Group = 'onay' | 'duzeltme' | 'planli' | 'yayinda' | 'sorun';
export function groupOf(post: Any): Group {
  const st = post?.status;
  if (st === 'draft') return post?.metadata?.durum === 'duzeltme' ? 'duzeltme' : 'onay';
  if (st === 'scheduled' || st === 'pending_approval' || st === 'publishing') return 'planli';
  if (st === 'published') return 'yayinda';
  if (st === 'partial') return (post.platforms ?? []).some((t: Any) => t.status === 'failed') ? 'sorun' : 'yayinda';
  return 'sorun';   // failed, cancelled
}

export function summarize(post: Any) {
  const meta = (post?.metadata ?? {}) as Record<string, Any>;
  const items = (post?.mediaItems ?? []) as Any[];
  // Türü yazmayan eski kayıt: uzantı görsel değilse video sayılır
  const isVideo = (m: Any) => m?.type ? m.type === 'video' : !/\.(jpe?g|png|webp|gif)(\?|$)/i.test(String(m?.url ?? ''));
  const video = items.find(isVideo);
  return {
    id: String(post?._id ?? ''),
    group: groupOf(post),
    status: post?.status ?? null,
    title: post?.title ?? meta.paket ?? '',
    tur: (TURLER.includes(meta.tur) ? meta.tur : 'video') as Tur,
    video: video?.url ?? null,
    images: items.filter((m) => !isVideo(m) && m?.url).map((m) => String(m.url)),
    cover: meta.kapak ?? video?.thumbnail ?? null,
    // Taslakta servis saat alanına oluşturulma anını yazıyor (30 Ekim): taslakta yalnız paketin önerisi gösterilir
    scheduledFor: post?.status === 'draft' ? (meta.onerilen_zaman ?? null) : (post?.scheduledFor ?? meta.onerilen_zaman ?? null),
    createdAt: post?.createdAt ?? null,
    fromMarketing: meta.kaynak === 'marketing',
    paket: meta.paket ?? null,
    surum: meta.surum ?? null,
    ai: meta.yapay_zeka === true,
    commercial: meta.ticari === true,
    youtubeTitle: meta.youtube_baslik ?? null,
    sources: Array.isArray(meta.kaynaklar) ? meta.kaynaklar : [],
    note: meta.not ?? null,
    warnings: Array.isArray(meta.uyarilar) ? meta.uyarilar : [],
    changesNote: meta.duzeltme_notu ?? null,
    platforms: (post?.platforms ?? []).map((t: Any) => ({
      platform: t.platform,
      status: t.status ?? null,
      caption: t.platformSpecificData?.description ?? t.customContent ?? post?.content ?? '',
      url: t.platformPostUrl ?? null,
      error: t.errorMessage ?? null,
      publishedAt: t.publishedAt ?? null,
    })),
  };
}

// Bağlı hesaplar: her platform için yayınlanabilir ilk hesap
export function pickAccounts(list: Any[]): Accounts {
  const out: Accounts = {};
  for (const a of list ?? []) {
    if (!PLATFORMS.includes(a?.platform) || out[a.platform as Platform]) continue;
    if (a.isActive === false || a.enabled === false || a.needsReconnection === true) continue;
    out[a.platform as Platform] = a._id;
  }
  return out;
}

export function accountRows(list: Any[]) {
  return (list ?? []).filter((a) => PLATFORMS.includes(a?.platform)).map((a) => ({
    platform: a.platform, username: a.username ?? a.displayName ?? '', ok: a.isActive !== false && a.enabled !== false && !a.needsReconnection,
    reconnect: a.needsReconnection === true,
  }));
}

// Aynı kimliğin anahtarı: aynı paket + sürüm iki kez gönderilirse servis aynı gönderiyi döner
export async function idempotencyKey(id: string, surum: number): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`paylasim:${id}:${surum}`)));
  const h = [...d.slice(0, 16)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-5${h.slice(13, 16)}-${((parseInt(h[16], 16) & 3) | 8).toString(16)}${h.slice(17, 20)}-${h.slice(20, 32)}`;
}

// --- Marketing'e geri bildirim --------------------------------------------------------------------
// Panel olayı (düzeltme / onay / silme) marketing deposundaki açık "geri bildirim" PR'ına yorum olarak düşer; Marketing
// oturumu o PR'a abone olduğu için hemen uyanır. Sonda makinenin okuyacağı satır var. Yorum yazılamasa da panel işlemi geçerlidir.
export const FEEDBACK_BRANCH = 'paylasim-geri-bildirim';
export type FeedbackKind = 'duzeltme' | 'onay' | 'silindi';
export function feedbackComment(kind: FeedbackKind, post: Any, extra: { note?: string; scheduledFor?: string; platforms?: string[] } = {}): string {
  const meta = ownMeta(post);
  const surum = Number(meta.surum) || null;
  const which = meta.paket ? `\`${meta.paket}\`${surum ? ` sürüm ${surum}` : ''}` : `"${post?.title ?? post?._id ?? ''}"`;
  const head = { duzeltme: '✏️ **Düzeltme istendi**', onay: '✅ **Onaylandı**', silindi: '🗑️ **Silindi**' }[kind];
  const lines = [`${head} · ${which}`, ''];
  const quote = (t?: string) => '> ' + String(t ?? '').trim().replace(/\r?\n/g, '\n> ');
  if (kind === 'duzeltme') {
    lines.push(quote(extra.note), '', `Yapılacak: aynı \`id\` ile \`"surum": ${(surum ?? 1) + 1}\` gönder; onay yine panelde (ortak \`sozlesme/paylasim.md\`).`);
  } else if (kind === 'onay') {
    lines.push(`Yayın: ${extra.scheduledFor ?? '—'} · ${(extra.platforms ?? []).join(', ')}`);
  } else {
    lines.push(`Gerekçe:`, quote(extra.note));
  }
  lines.push('', '_Yönetim paneli (otomatik)_',
    `<!-- paylasim:${JSON.stringify({ olay: kind, id: post?._id ?? null, paket: meta.paket ?? null, surum })} -->`);
  return lines.join('\n');
}

// --- GitHub Actions kimliği (Marketing deposu) --------------------------------------------------
// Marketing'in iş akışı GitHub'ın imzaladığı kısa ömürlü kimlik belgesini (OIDC) gönderir; paylaşılan bir sır yok.
export const GITHUB_ISSUER = 'https://token.actions.githubusercontent.com';
export const AUDIENCE = 'pofi-paylasim';

const b64url = (s: string) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(s.length / 4) * 4, '=')), (c) => c.charCodeAt(0));
export function peekIssuer(token: string): string | null {
  try {
    return JSON.parse(new TextDecoder().decode(b64url(token.split('.')[1] ?? ''))).iss ?? null;
  } catch {
    return null;
  }
}

export type Jwk = JsonWebKey & { kid?: string };
// Doğrulanırsa iddiaları döner, yoksa hata atar. repo: "sahip/ad", ref yalnız ana dal.
export async function verifyGithub(token: string, keys: Jwk[], repo: string, now = Date.now()): Promise<Record<string, Any>> {
  const [h, p, sig] = token.split('.');
  if (!h || !p || !sig) throw new Error('Kimlik belgesi bozuk');
  const header = JSON.parse(new TextDecoder().decode(b64url(h)));
  if (header.alg !== 'RS256') throw new Error('İmza türü desteklenmiyor');
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('İmza anahtarı bulunamadı');
  const key = await crypto.subtle.importKey('jwk', { kty: jwk.kty, n: jwk.n, e: jwk.e }, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64url(sig), new TextEncoder().encode(`${h}.${p}`));
  if (!ok) throw new Error('İmza geçersiz');
  const c = JSON.parse(new TextDecoder().decode(b64url(p)));
  const t = Math.floor(now / 1000);
  if (c.iss !== GITHUB_ISSUER) throw new Error('Yayıncı GitHub değil');
  if (!(c.aud === AUDIENCE || (Array.isArray(c.aud) && c.aud.includes(AUDIENCE)))) throw new Error('Hedef kitle yanlış');
  if (typeof c.exp !== 'number' || c.exp < t - 60) throw new Error('Kimlik belgesinin süresi dolmuş');
  if (typeof c.nbf === 'number' && c.nbf > t + 60) throw new Error('Kimlik belgesi henüz geçerli değil');
  if (String(c.repository ?? '').toLowerCase() !== repo.toLowerCase()) throw new Error(`Depo yetkili değil: ${c.repository}`);
  if (c.ref !== 'refs/heads/main') throw new Error('Yalnız ana daldan (main) gönderilebilir');
  return c;
}

// =============================================================================================
// 2. İstek yönlendirme (bağımlılıklar dışarıdan; testte sahte servis)
// =============================================================================================

export type ZernioCall = (method: string, path: string, body?: unknown, headers?: Record<string, string>) => Promise<{ status: number; data: Any }>;
export type Deps = {
  zernio: ZernioCall;
  checkAdmin: (action: string, ref?: string | null, reason?: string | null, after?: unknown, dry?: boolean) => Promise<string>;
  githubKeys: () => Promise<Jwk[]>;
  repo: string;
  now: () => Date;
  // MARKETING_GITHUB_TOKEN tanımlı değilse yok; panel "otomatik bildirim kapalı" der
  notify?: (kind: FeedbackKind, text: string) => Promise<void>;
};
export type Out = { status: number; body: Any };
type Told = { ok: boolean; error?: string } | null;
async function tell(d: Deps, kind: FeedbackKind, post: Any, extra: Parameters<typeof feedbackComment>[2]): Promise<Told> {
  if (!d.notify) return null;
  try {
    await d.notify(kind, feedbackComment(kind, post, extra));
    return { ok: true };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

class Fail extends Error {
  status: number;
  extra: Record<string, unknown>;
  constructor(status: number, message: string, extra: Record<string, unknown> = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}
const ok = (body: Any): Out => ({ status: 200, body });
const ID = /^[A-Za-z0-9_-]{1,64}$/;
const MEDIA = ['video/mp4', 'video/quicktime', 'image/jpeg', 'image/png'];

async function z(d: Deps, method: string, path: string, body?: unknown, headers?: Record<string, string>) {
  const r = await d.zernio(method, path, body, headers);
  if (r.status >= 400) {
    const msg = r.data?.error ?? r.data?.message ?? `Paylaşım servisi hatası (${r.status})`;
    throw new Fail(r.status === 401 || r.status === 403 ? 502 : r.status >= 500 ? 502 : 400, `Paylaşım servisi: ${msg}`);
  }
  return r.data ?? {};
}
const posts = async (d: Deps) => ((await z(d, 'GET', '/v1/posts?limit=50&sortBy=created-desc')).posts ?? []) as Any[];
const accounts = async (d: Deps) => ((await z(d, 'GET', '/v1/accounts')).accounts ?? []) as Any[];
// Plan ve bu dönemin gönderi hakkı (servis vermezse null; panel ve Marketing durumu gösterir)
export function usageOf(u: Any) {
  if (!u || typeof u !== 'object') return null;
  return {
    plan: u.planName ?? null,
    used: typeof u.usage?.uploads === 'number' ? u.usage.uploads : null,
    limit: typeof u.limits?.uploads === 'number' && u.limits.uploads >= 0 ? u.limits.uploads : null,
    resetDay: u.billingAnchorDay ?? null,
    lastReset: u.usage?.lastReset ?? null,
    access: u.hasAccess !== false,
    // Kullandıkça öde planı (29 Ekim 2026: hesabımız bu planda): gönderi sınırı yok, ücret bağlı hesap başına
    accounts: typeof u.usage?.connectedAccounts === 'number' ? u.usage.connectedAccounts : null,
    spendCents: typeof u.spend?.currentPeriodCents === 'number' ? u.spend.currentPeriodCents : null,
    creditCents: typeof u.spend?.creditsRemainingCents === 'number' ? u.spend.creditsRemainingCents : null,
  };
}
async function usage(d: Deps) {
  try {
    const r = await d.zernio('GET', '/v1/usage');
    return r.status < 400 ? usageOf(r.data) : null;
  } catch {
    return null;
  }
}
async function getPost(d: Deps, id: string) {
  const post = (await z(d, 'GET', `/v1/posts/${id}`)).post;
  if (!post) throw new Fail(404, 'Gönderi bulunamadı');
  return post;
}

// Yayımlanmış olanların ölçümleri (servisin analizi; en çok 20 gönderi): toplam + platform başına, ölçüm zamanıyla
export function metrics(a: Any) {
  if (!a || typeof a !== 'object') return null;
  const n = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
  return {
    views: n(a.views) ?? 0, reach: n(a.reach), impressions: n(a.impressions),
    likes: n(a.likes) ?? 0, comments: n(a.comments) ?? 0, shares: n(a.shares) ?? 0, saves: n(a.saves) ?? 0,
    avgWatchMs: n(a.igReelsAvgWatchTime), totalWatchMs: n(a.igReelsVideoViewTotalTime),
    skipRate: n(a.reelsSkipRate), completionRate: n(a.completionRate), follows: n(a.follows), profileViews: n(a.profileViews),
  };
}
async function withAnalytics(d: Deps, list: ReturnType<typeof summarize>[]) {
  const live = list.filter((p) => p.group === 'yayinda').slice(0, 20);
  const at = d.now().toISOString();
  await Promise.all(live.map(async (p) => {
    try {
      const r = await d.zernio('GET', `/v1/analytics?postId=${p.id}`);
      if (r.status >= 400) return;
      const total = metrics(r.data?.analytics);
      if (total) (p as Any).stats = total;
      (p as Any).statsByPlatform = ((r.data?.platformAnalytics ?? []) as Any[]).map((x) => ({
        platform: x.platform ?? null, sync: x.syncStatus ?? null, url: x.platformPostUrl ?? null, ...(metrics(x.analytics) ?? {}),
      }));
      (p as Any).measuredAt = at;
    } catch { /* ölçüm isteğe bağlı */ }
  }));
  return list;
}

async function marketing(body: Any, d: Deps, source: string): Promise<Out> {
  if (body.action === 'upload') {
    const filename = String(body.filename ?? '').replace(/[^A-Za-z0-9._-]/g, '_').slice(0, 120);
    const size = Number(body.size);
    if (!filename) throw new Fail(400, 'filename gerekli');
    if (!MEDIA.includes(body.contentType)) throw new Fail(400, `contentType: ${MEDIA.join(', ')}`);
    if (!Number.isFinite(size) || size <= 0 || size > 1_000_000_000) throw new Fail(400, 'size: 1 bayt – 1 GB');
    const r = await z(d, 'POST', '/v1/media/presign', { filename, contentType: body.contentType, size });
    if (!r.uploadUrl || !r.publicUrl) throw new Fail(502, 'Yükleme bağlantısı alınamadı');
    return ok({ uploadUrl: r.uploadUrl, publicUrl: r.publicUrl });
  }
  if (body.action === 'submit') {
    const { paket, errors } = parsePaket(body.paket);
    if (!paket) throw new Fail(400, 'Paket kurallara uymuyor', { errors });
    const all = await posts(d);
    const mine = all.filter((p) => p?.metadata?.kaynak === 'marketing' && p?.metadata?.paket === paket.id);
    const same = mine.find((p) => Number(p.metadata.surum) === paket.surum);
    if (same) {
      if (same.status !== 'draft') throw new Fail(409, `Bu paket sürümü zaten ${same.status}; düzeltme için "surum"u artır`);
      return ok({ id: same._id, warnings: same.metadata.uyarilar ?? [], existing: true });
    }
    if (mine.some((p) => p.status !== 'draft' && Number(p.metadata.surum) > paket.surum)) throw new Fail(409, 'Daha yeni bir sürüm zaten onaylanmış');
    let draft;
    const acc = pickAccounts(await accounts(d));
    try { draft = draftBody(paket, acc, source, d.now()); } catch (e) { throw new Fail(400, (e as Error).message); }
    const created = await z(d, 'POST', '/v1/posts', draft, { 'Idempotency-Key': await idempotencyKey(paket.id, paket.surum) });
    const id = created.post?._id;
    if (!id) throw new Fail(502, 'Taslak açılamadı');
    // Aynı paketin eski, onaylanmamış sürümleri kaldırılır (onay kuyruğunda tek sürüm kalsın)
    for (const old of mine) if (old.status === 'draft' && Number(old.metadata.surum) < paket.surum) await z(d, 'DELETE', `/v1/posts/${old._id}`);
    return ok({ id, warnings: [...(created.post?.metadata?.uyarilar ?? []), ...(created.warnings ?? [])] });
  }
  if (body.action === 'status') {
    const list = (await posts(d)).filter((p) => p?.metadata?.kaynak === 'marketing').map(summarize);
    return ok({ posts: await withAnalytics(d, list), usage: await usage(d) });
  }
  throw new Fail(400, 'action');
}

async function panel(body: Any, d: Deps): Promise<Out> {
  if (body.action === 'overview') {
    const role = await d.checkAdmin('view');
    const [acc, list, use] = await Promise.all([accounts(d), posts(d), usage(d)]);
    return ok({ role, accounts: accountRows(acc), posts: await withAnalytics(d, list.map(summarize)), usage: use });
  }
  if (!['approve', 'request_changes', 'delete'].includes(body.action)) throw new Fail(400, 'action');
  const id = String(body.id ?? '');
  if (!ID.test(id)) throw new Fail(400, 'Gönderi kimliği geçersiz');
  const reason = String(body.reason ?? '');
  await d.checkAdmin(body.action, id, reason, null, true);
  const post = await getPost(d, id);

  if (body.action === 'approve') {
    if (post.status !== 'draft') throw new Fail(409, 'Yalnız onay bekleyen taslak onaylanır');
    const { approval, errors } = parseApproval(body, d.now(), TURLER.includes(post.metadata?.tur) ? post.metadata.tur : 'video');
    if (!approval) throw new Fail(400, errors.join(' · '), { errors });
    let upd;
    try { upd = approveBody(post, approval, d.now()); } catch (e) { throw new Fail(400, (e as Error).message); }
    const r = await z(d, 'PUT', `/v1/posts/${id}`, upd);
    await d.checkAdmin('approve', id, reason, { scheduledFor: approval.scheduledFor, platforms: approval.platforms, yapay_zeka: approval.yapay_zeka }, false);
    const notify = post.metadata?.kaynak === 'marketing' ? await tell(d, 'onay', post, { scheduledFor: approval.scheduledFor, platforms: approval.platforms }) : null;
    return ok({ post: summarize(r.post ?? { ...post, ...upd, status: 'scheduled' }), warnings: r.warnings ?? [], notify });
  }
  if (body.action === 'request_changes') {
    if (post.status !== 'draft') throw new Fail(409, 'Yalnız taslak için düzeltme istenir');
    const r = await z(d, 'PUT', `/v1/posts/${id}`, changesBody(post, reason, d.now()));
    await d.checkAdmin('request_changes', id, reason, null, false);
    const notify = post.metadata?.kaynak === 'marketing' ? await tell(d, 'duzeltme', post, { note: reason }) : null;
    return ok({ post: summarize(r.post ?? { ...post, metadata: { ...post.metadata, durum: 'duzeltme', duzeltme_notu: reason } }), notify });
  }
  // delete
  if (post.status === 'published' || post.status === 'partial') throw new Fail(409, 'Yayındaki gönderi buradan silinmez; platformun kendisinden kaldır');
  await z(d, 'DELETE', `/v1/posts/${id}`);
  await d.checkAdmin('delete', id, reason, { status: post.status, paket: post.metadata?.paket ?? null }, false);
  const notify = post.metadata?.kaynak === 'marketing' ? await tell(d, 'silindi', post, { note: reason }) : null;
  return ok({ deleted: id, notify });
}

export async function handle(auth: string, body: Any, d: Deps): Promise<Out> {
  try {
    const token = /^Bearer\s+(\S+)$/i.exec(auth.trim())?.[1];
    if (!token) return { status: 401, body: { error: 'Oturum yok' } };
    if (!body || typeof body !== 'object') return { status: 400, body: { error: 'Gövde JSON olmalı' } };
    if (peekIssuer(token) === GITHUB_ISSUER) {
      let claims;
      try { claims = await verifyGithub(token, await d.githubKeys(), d.repo, d.now().getTime()); } catch (e) { throw new Fail(403, (e as Error).message); }
      if (!['upload', 'submit', 'status'].includes(body.action)) throw new Fail(403, 'Marketing bu işlemi yapamaz');
      return await marketing(body, d, `${claims.repository}@${String(claims.sha ?? '').slice(0, 7)}`);
    }
    if (['upload', 'submit', 'status'].includes(body.action)) throw new Fail(403, 'Bu işlem yalnız Marketing iş akışından');
    try {
      return await panel(body, d);
    } catch (e) {
      if (e instanceof Fail) throw e;
      const m = (e as Error).message ?? '';
      // admin_social_check hataları (Yetkisiz, iki adımlı doğrulama, rol, gerekçe)
      throw new Fail(/Yetki|İki adımlı|rolün|42501/.test(m) ? 403 : 400, m);
    }
  } catch (e) {
    if (e instanceof Fail) return { status: e.status, body: { error: e.message, ...e.extra } };
    return { status: 500, body: { error: (e as Error).message ?? 'Sunucu hatası' } };
  }
}

// =============================================================================================
// 3. Deno sunucusu
// =============================================================================================
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers });

let jwks: { at: number; keys: Jwk[] } | null = null;
async function githubKeys(): Promise<Jwk[]> {
  if (jwks && Date.now() - jwks.at < 10 * 60_000) return jwks.keys;
  const r = await fetch('https://token.actions.githubusercontent.com/.well-known/jwks');
  if (!r.ok) throw new Error('GitHub anahtarları alınamadı');
  jwks = { at: Date.now(), keys: (await r.json()).keys ?? [] };
  return jwks.keys;
}

// Geri bildirim PR'ına yorum + paylaşım iş akışını çalıştır (durum.json tazelensin). Anahtar: ince yetkili GitHub anahtarı,
// yalnız marketing deposu; Pull requests: yazma, Actions: yazma (sozlesme/paylasim.md "Geri bildirim").
export function notifyGithub(token: string, repo: string) {
  const h = { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'pofi-social' };
  return async (_kind: FeedbackKind, text: string) => {
    const owner = repo.split('/')[0];
    const list = await fetch(`https://api.github.com/repos/${repo}/pulls?state=open&head=${owner}:${FEEDBACK_BRANCH}`, { headers: h });
    if (!list.ok) throw new Error(`GitHub ${list.status} (anahtar ya da yetki)`);
    const n = (await list.json())[0]?.number;
    if (!n) throw new Error(`marketing deposunda açık geri bildirim PR'ı yok (${FEEDBACK_BRANCH})`);
    const c = await fetch(`https://api.github.com/repos/${repo}/issues/${n}/comments`, { method: 'POST', headers: h, body: JSON.stringify({ body: text }) });
    if (!c.ok) throw new Error(`Yorum yazılamadı (GitHub ${c.status})`);
    await fetch(`https://api.github.com/repos/${repo}/actions/workflows/paylasim.yml/dispatches`, {
      method: 'POST', headers: h, body: JSON.stringify({ ref: 'main' }),
    }).catch(() => null);
  };
}

if (typeof Deno !== 'undefined') {
  Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers });
    if (req.method !== 'POST') return reply({ error: 'method' }, 405);
    const env = (k: string) => Deno!.env.get(k) ?? '';
    const key = env('ZERNIO_API_KEY');
    if (!key) return reply({ error: 'Paylaşım servisi bağlı değil (ZERNIO_API_KEY eksik)' }, 503);
    const auth = req.headers.get('Authorization') ?? '';
    const body = await req.json().catch(() => null);
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const me = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), {
      auth: { persistSession: false, autoRefreshToken: false }, global: { headers: { Authorization: auth } },
    });
    const deps: Deps = {
      zernio: async (method, path, payload, extra) => {
        const r = await fetch(`https://zernio.com/api${path}`, {
          method,
          headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', ...(extra ?? {}) },
          body: payload === undefined ? undefined : JSON.stringify(payload),
        });
        const text = await r.text();
        let data;
        try { data = text ? JSON.parse(text) : {}; } catch { data = { error: text.slice(0, 300) }; }
        return { status: r.status, data };
      },
      checkAdmin: async (action, ref = null, reason = null, after = null, dry = true) => {
        const { data, error } = await me.rpc('admin_social_check', { p_action: action, p_ref: ref, p_reason: reason, p_after: after, p_dry: dry });
        if (error) throw new Error(error.message);
        return String(data);
      },
      githubKeys,
      repo: env('SOCIAL_REPO') || 'amy60946/marketing',
      now: () => new Date(),
      notify: env('MARKETING_GITHUB_TOKEN') ? notifyGithub(env('MARKETING_GITHUB_TOKEN'), env('SOCIAL_REPO') || 'amy60946/marketing') : undefined,
    };
    const out = await handle(auth, body, deps);
    return reply(out.body, out.status);
  });
}
