// support: destek talebi (herkese açık /destek formu) ve sabit destek adresi.
//   GET  /functions/v1/support → 302 <LEGAL_PUBLIC_URL kökü>/destek  (App Store "Support URL" ve uygulamalardaki "Yardım ve
//        iletişim" bu sabit adresi kullanır; alan adı alınınca yalnız LEGAL_PUBLIC_URL değişir, uygulama sürümü gerekmez)
//   POST { app, topic, email, name?, message, adult: true, website?, elapsed_ms? } → 200 {ok, ref} · 400/429/503 {error}
//        `adult`: "18 yaşından büyüğüm" kutusu (form yetişkinler içindir; çocuk ürünü, Apple 1.3/5.1.4).
//        `website` gizli tuzak alanıdır (insan doldurmaz); 3 saniyeden kısa doldurulan form sessizce yok sayılır.
// Kayıt SQL'de: support_request_create (migrations/20261121110000_support_invite_limits.sql): kaynak (gönderenin adresi, günlük
//   tuzla özetlenir) başına saatte 5 ve 24 saatte 15; e-posta başına 24 saatte 3 (kaynak biliniyorsa aynı kaynaktan; KVKK
//   muaf); genel saatte 300 (son çare; istenmeyen ve KVKK sayılmaz; doluyken son saatte yazmamış, geniş ağından da (/24, /48)
//   yazılmamış kaynak 600'e kadar bir talep açar); KVKK ("privacy") ayrı paydan saatte 100 (aynı istisnayla 200'e kadar);
//   kaynaksız talepler ayrıca saatte 30 + KVKK 10'luk ortak kovada. Sınır iletilerinin hepsi destek@moyoapp.com.tr'yi önerir.
// Kaynak adresi: Worker (admin-panel/worker) formu gönderenin adresini `x-moyo-client-ip` başlığıyla, paylaşılan gizli anahtarı
//   `x-moyo-forward-key` ile iletir. Anahtar (secret SUPPORT_FORWARD_KEY) sabit sürede eşleşirse iletilen adres kullanılır;
//   eşleşmezse ya da başlık yoksa işlevin kendi gördüğü istemci adresi (her doğrudan çağıran gibi; `cf-worker` başlığına
//   bakılmaz: her Cloudflare Worker'ı bu başlıkla gelir, anahtarsız yol sınırsız olmasın). SUPPORT_FORWARD_KEY hiç tanımlı
//   değilse kaynak yok (SQL'de kaynaksız kova). Yayın sırası: önce Worker'a, sonra Supabase'e; arada geçen birkaç dakikada
//   Worker'dan gelen talepler kaynaksız kovada, sıra ters olursa Worker'ın tek adresinin kovasında sayılır (geçici).
//   Adresler normIp ile denetlenir (IPv4'e eşlenmiş IPv6 → IPv4).
// Gövde en çok 20 000 karakter (Content-Length olmasa da akış kesilir).
// Ekip uyarısı (kullanıcı kararları 20 Kasım 2026 ve 22 Kasım 2026 "2A"): yeni talepte (form ya da e-posta) ve e-postayla
//   yeniden açılan talepte SUPPORT_NOTIFY_TO adresine tek satırlık e-posta: talep no (formda uygulama ve konu), "Panelde aç".
//   Kişinin e-postası, adı ve mesajı uyarıya GİRMEZ. SUPPORT_NOTIFY_TO tanımlı değilse ya da @moyoapp.com.tr (ya da alt alan
//   adı) ise uyarı GİTMEZ: destek@ artık panele düşüyor, oraya giden uyarı yeni talep açardı (döngü). Eski varsayılan
//   (destek@) kalktı. Gönderim Resend (RESEND_API_KEY + MAIL_FROM; gönderen MAIL_FROM'un alan adında noreply@) ya da test
//   SMTP'si (SMTP_USER + SMTP_PASS). Başarısız uyarı talebi düşürmez (en çok 4 sn beklenir, yalnız hata kodu günlüğe yazılır).
//
// Destek kutusu (migrations/20261122100000_support_inbox.sql; sözleşme sozlesme/veritabani.md §39):
//   POST /support/inbound  Worker'ın email() işleyicisi (destek@moyoapp.com.tr → Cloudflare Email Routing → Worker). Başlık
//        x-moyo-forward-key = SUPPORT_FORWARD_KEY (sabit sürede; yoksa 401). Gövde JSON en çok 256 KB:
//        {from, fromName, subject, text, messageId, refs, attachments:[{name,size,type}], auto, auth}. RPC support_inbound_email
//        (service_role). Yeni konuşmada otomatik "alındı" yanıtı (Resend; Kimden SUPPORT_FROM ya da Moyo Destek
//        <destek@moyoapp.com.tr>; Auto-Submitted: auto-replied; In-Reply-To / References = gelen Message-ID) →
//        support_message_sent. Yanıt: 200 {ok:true, ref} · 200 {ok:false, error:"dropped"} (sınır: Worker başka yere iletmesin)
//        · 400 invalid · 401 unauthorized · 413 too_large · 503 server (Worker yeniden dener / yedek adrese iletir).
//   POST /support/reply  Panel; Authorization: Bearer <yöneticinin oturumu> + apikey. Gövde {request_id, body, close}.
//        admin_support_reply çağıranın oturumuyla (yetki SQL'de: destek rolü + iki adımlı giriş) → Resend (Kimden SUPPORT_FROM,
//        Reply-To destek@, düz metin + basit HTML, In-Reply-To yok) → support_message_sent. Yanıt 200 {ok:true, status}
//        · 400 invalid · 401/403 forbidden · 502/503 send_failed (talep "işlemde"ye döner). CORS yalnız panel adresleri
//        (ADMIN_PANEL_URL ve admin-panel.amy60946.workers.dev).
//   Günlüğe yalnız hata kodu yazılır (adres, konu, gövde, ek adı yazılmaz).
// Yayın: Supabase → Edge Functions → support, "Verify JWT" KAPALI. Secret: LEGAL_PUBLIC_URL (zaten var), SUPPORT_FORWARD_KEY,
//   RESEND_API_KEY; isteğe bağlı ADMIN_PANEL_URL ("Panelde aç" ve CORS), SUPPORT_NOTIFY_TO (ekip uyarısı), SUPPORT_FROM.
// Testi index.test.ts (node --experimental-strip-types --test supabase/functions/support/*.test.ts); Deno.serve yalnız Deno'da.

export const APPS = ['parent', 'child', 'clinic', 'other'] as const;
export const TOPICS = ['account', 'subscription', 'bug', 'privacy', 'clinic', 'other'] as const;
export const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
export const MIN_FILL_MS = 3000;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' } });

export const MESSAGES: Record<string, [number, string]> = {
  invalid: [400, 'Bilgiler eksik ya da hatalı: geçerli bir e-posta ve en az 10 karakterlik bir mesaj yazın.'],
  adult: [400, 'Bu form yetişkinler içindir; "18 yaşından büyüğüm" kutusunu işaretleyin. Çocuğunuz adına siz yazabilirsiniz.'],
  too_many: [429, 'Bu e-posta adresinden bugün yeterince talep aldık; yanıtımızı bekleyin, yarın yeniden deneyin ya da destek@moyoapp.com.tr adresine yazın.'],
  too_many_source: [429, 'Bu bağlantıdan kısa sürede çok fazla talep geldi; bir süre sonra yeniden deneyin ya da destek@moyoapp.com.tr adresine yazın.'],
  busy: [503, 'Şu an çok fazla talep var; birkaç dakika sonra yeniden deneyin ya da destek@moyoapp.com.tr adresine yazın.'],
  server: [503, 'Talep kaydedilemedi; biraz sonra yeniden deneyin.'],
};

export const MAX_BODY = 20000;

// Sabit sürede karşılaştırma (anahtar zamanlamadan tahmin edilemesin)
export function same(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

// Adresi gerçek ayrıştırıcıyla denetler ve tek biçime getirir; adres değilse null.
// IPv4 (her bölüm 0–255, baştaki sıfır yok) olduğu gibi; IPv6 URL ayrıştırıcısıyla kısaltılmış küçük harf biçime;
// IPv4'e eşlenmiş IPv6 (::ffff:a.b.c.d) IPv4'e çevrilir (yoksa bütün bu adresler SQL'de tek /64 kovasına düşerdi).
const V4 = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/;
export function normIp(s: string): string | null {
  const v = (s ?? '').trim();
  if (!v || v.length > 45) return null;
  if (V4.test(v)) return v;
  if (!v.includes(':') || !/^[0-9A-Fa-f:.]+$/.test(v)) return null;
  let host: string;
  try { host = new URL(`http://[${v}]/`).hostname.slice(1, -1); } catch { return null; }
  const m = /^::ffff:([0-9a-f]{1,4}):([0-9a-f]{1,4})$/.exec(host);
  if (m) {
    const hi = parseInt(m[1], 16), lo = parseInt(m[2], 16);
    return `${hi >> 8}.${hi & 255}.${lo >> 8}.${lo & 255}`;
  }
  return host;
}

// Talebin kaynağı: anahtar eşleşirse Worker'ın ilettiği adres; yoksa işlevin kendi gördüğü adres (geçersizse 'unknown',
// SQL'de tek ortak kova); anahtar tanımlı değilse null (kaynaksız kova). Anahtarsız gelen istek hangi başlığı taşırsa taşısın
// (ör. `cf-worker`: her Cloudflare Worker'ının alt isteğinde vardır) kaynaksız yola düşmez.
// Worker'ın paylaşılan anahtarı (SUPPORT_FORWARD_KEY) sabit sürede eşleşiyor mu; 16 karakterden kısa anahtar hiç eşleşmez
export function forwardKeyOk(req: Request, env: (k: string) => string): boolean {
  const key = env('SUPPORT_FORWARD_KEY');
  const given = req.headers.get('x-moyo-forward-key');
  return !!key && key.length >= 16 && given !== null && same(key, given);
}

export function sourceOf(req: Request, env: (k: string) => string): string | null {
  if (!env('SUPPORT_FORWARD_KEY')) return null;
  const fwd = normIp(req.headers.get('x-moyo-client-ip') ?? '');
  if (forwardKeyOk(req, env) && fwd) return fwd;
  const own = normIp((req.headers.get('cf-connecting-ip') ?? req.headers.get('x-real-ip')
               ?? (req.headers.get('x-forwarded-for') ?? '').split(',')[0]).trim());
  return own ?? 'unknown';
}

// Gövdeyi en çok max karakter okur; aşarsa null (Content-Length olmasa da)
export async function readLimited(req: Request, max = MAX_BODY): Promise<string | null> {
  if (Number(req.headers.get('content-length') ?? 0) > max * 4) return null;
  if (!req.body) return '';
  const reader = req.body.getReader();
  const dec = new TextDecoder();
  let text = '';
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      text += dec.decode(value, { stream: true });
      if (text.length > max) { await reader.cancel().catch(() => {}); return null; }
    }
  } catch {
    return '';
  }
  text += dec.decode();
  return text.length > max ? null : text;
}

export type Input = { app: string; topic: string; email: string; name: string; message: string; adult: boolean; website: string; elapsed_ms: number | null };

export function clean(body: any): Input {
  const s = (v: unknown, max: number) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
  const n = Number(body?.elapsed_ms);
  return {
    app: s(body?.app, 20), topic: s(body?.topic, 20), email: s(body?.email, 254), name: s(body?.name, 80),
    message: s(body?.message, 3000), adult: body?.adult === true || body?.adult === '1',
    website: s(body?.website, 200), elapsed_ms: Number.isFinite(n) ? n : null,
  };
}

// Kayda gitmeden reddedilecek mi: 'bot' (sessizce yok say), 'invalid' ya da null (geçerli)
export function precheck(x: Input): 'bot' | 'invalid' | 'adult' | null {
  if (x.website) return 'bot';
  if (x.elapsed_ms !== null && x.elapsed_ms < MIN_FILL_MS) return 'bot';
  if (!(APPS as readonly string[]).includes(x.app) || !(TOPICS as readonly string[]).includes(x.topic)) return 'invalid';
  if (!EMAIL.test(x.email) || x.email.length < 6 || x.message.length < 10) return 'invalid';
  if (!x.adult) return 'adult';
  return null;
}

export function supportPage(publicUrl: string): string | null {
  const base = publicUrl.replace(/\/+$/, '').replace(/\/yasal$/, '');
  return base ? `${base}/destek` : null;
}

export const APP_LABELS: Record<string, string> = { parent: 'Moyo', child: 'Moyo Oyun', clinic: 'Moyo Mercek', other: 'Diğer' };
export const TOPIC_LABELS: Record<string, string> = {
  account: 'Hesap ve giriş', subscription: 'Abonelik ve ödeme', bug: 'Hata', privacy: 'Kişisel veriler (KVKK)',
  clinic: 'Klinik ve ekip', other: 'Diğer',
};
export const OWN_DOMAIN = 'moyoapp.com.tr';
export const SUPPORT_ADDRESS = 'destek@moyoapp.com.tr';

// Adres bizim alan adımızda (ya da alt alan adında) mı: oraya otomatik yanıt ve ekip uyarısı gitmez (döngü)
export function isOwnDomain(addr: string): boolean {
  const d = (addr ?? '').trim().toLowerCase().replace(/\.+$/, '').split('@').pop() ?? '';
  return d === OWN_DOMAIN || d.endsWith('.' + OWN_DOMAIN);
}

// Ekip uyarısının adresi: SUPPORT_NOTIFY_TO tek ve geçerli bir adresse ve bizim alan adımızda değilse; yoksa uyarı gitmez
export function notifyTarget(env: (k: string) => string): string | null {
  const v = (env('SUPPORT_NOTIFY_TO') ?? '').trim().toLowerCase();
  if (!v || v.length > 254 || /[,;<>"\s]/.test(v) || !EMAIL.test(v) || isOwnDomain(v)) return null;
  return v;
}

// Ekibe giden bildirim: yalnız talep no, uygulama, konu ve panel bağlantısı (e-posta, ad, mesaj yok).
const esc = (t: string) => t.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

// Uyarının gövdesi: tek satır + panel bağlantısı (yalnız https adresi; yoksa "Yönetim paneli › Destek")
function noticeOf(line: string, panelUrl: string) {
  const base = (panelUrl ?? '').trim().replace(/\/+$/, '');
  const link = /^https:\/\/[^\s"'<>]+$/.test(base) ? `${base}/#/destek` : '';
  return {
    subject: line,
    text: link ? `${line}\nPanelde aç: ${link}` : `${line}\nYönetim paneli › Destek`,
    html: `<p>${esc(line)}</p><p>${link ? `<a href="${esc(link)}">Panelde aç</a>` : 'Yönetim paneli › Destek'}</p>`,
  };
}

export function teamNotice(ref: string, x: Pick<Input, 'app' | 'topic'>, panelUrl: string) {
  const app = APP_LABELS[x.app] ?? 'Diğer', topic = TOPIC_LABELS[x.topic] ?? 'Diğer';
  return noticeOf(`Yeni destek talebi ${ref} · ${app} · ${topic}`, panelUrl);
}

// E-postayla gelen talebin uyarısı: yalnız numara (konu satırı, gönderen ve gövde yok)
export function inboxNotice(ref: string, kind: 'new' | 'reopened', panelUrl: string) {
  return noticeOf(kind === 'reopened' ? `Destek talebine yeni ileti ${ref}` : `Yeni destek talebi ${ref}`, panelUrl);
}

export async function handle(req: Request, env: (k: string) => string,
                             create: (x: Input, source: string | null) => Promise<{ ref?: string; error?: string } | null>,
                             notify?: (ref: string, x: Input) => Promise<void>): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  if (req.method === 'GET' || req.method === 'HEAD') {
    const to = supportPage(env('LEGAL_PUBLIC_URL'));
    if (!to) return new Response('Destek sayfası adresi tanımlı değil', { status: 404, headers: CORS });
    return new Response(null, { status: 302, headers: { ...CORS, Location: to, 'Cache-Control': 'public, max-age=300' } });
  }
  if (req.method !== 'POST') return new Response('method', { status: 405, headers: CORS });
  const text = await readLimited(req);
  if (text === null) return json({ error: MESSAGES.invalid[1] }, 413);
  let body: any = null;
  try { body = JSON.parse(text); } catch { body = null; }
  const x = clean(body);
  const pre = precheck(x);
  if (pre === 'bot') return json({ ok: true });
  if (pre) return json({ error: MESSAGES[pre][1] }, MESSAGES[pre][0]);
  let r: { ref?: string; error?: string } | null = null;
  try { r = await create(x, sourceOf(req, env)); } catch { r = null; }
  if (r?.ref) {
    if (notify) {
      let timer: ReturnType<typeof setTimeout> | undefined;
      const limit = new Promise<void>((done) => { timer = setTimeout(done, 4000); });
      await Promise.race([notify(r.ref, x).catch(() => {}), limit]);
      clearTimeout(timer);
    }
    return json({ ok: true, ref: r.ref });
  }
  const [status, msg] = MESSAGES[r?.error ?? 'server'] ?? MESSAGES.server;
  return json({ error: msg }, status);
}

// =====================================================================================================================
// Destek kutusu: gelen e-posta ve panelden yanıt
// =====================================================================================================================
export type Route = 'form' | 'inbound' | 'reply' | null;

// Yol: …/support → form (GET yönlendirme, POST form), …/support/inbound, …/support/reply; başka alt yol yok (404)
export function routeOf(url: string): Route {
  let path = '/';
  try { path = new URL(url).pathname; } catch { return null; }
  const seg = path.split('/').filter(Boolean);
  const last = seg[seg.length - 1];
  if (last === 'inbound' || last === 'reply') return last;
  if (!last || last === 'support') return 'form';
  return null;
}

export const INBOUND_MAX_BYTES = 256 * 1024;
export const REPLY_MAX_BYTES = 128 * 1024;
export const BODY_MAX = 20000;

// Gövdeyi en çok max BAYT okur; aşarsa null (Content-Length olmasa da akış kesilir)
export async function readBytes(req: Request, max: number): Promise<string | null> {
  if (Number(req.headers.get('content-length') ?? 0) > max) return null;
  if (!req.body) return '';
  const reader = req.body.getReader();
  const parts: Uint8Array[] = [];
  let n = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      n += value.byteLength;
      if (n > max) { await reader.cancel().catch(() => {}); return null; }
      parts.push(value);
    }
  } catch {
    return '';
  }
  const all = new Uint8Array(n);
  let at = 0;
  for (const p of parts) { all.set(p, at); at += p.byteLength; }
  return new TextDecoder().decode(all);
}

// Metin alanı: NUL ve eşsiz vekil karakterler atılır (veritabanı reddederdi), en çok max karakter
const LONE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/g;
const txt = (v: unknown, max: number) =>
  typeof v === 'string' ? v.replace(/\u0000/g, '').slice(0, max).replace(LONE, '\uFFFD') : '';
// Tek satır (ad, konu): denetim karakterleri ve satır ayırıcılar boşluk, boşluklar tekleşir
export const oneLine = (v: unknown, max: number) =>
  [...txt(v, max * 2).replace(/[\u0000-\u001f\u007f\u2028\u2029\ufeff]/g, ' ').replace(/\s+/g, ' ').trim()].slice(0, max).join('').trim();

export type Attachment = { name: string; size: number | null; type: string };
export type InboundInput = {
  from: string; fromName: string; subject: string; text: string; messageId: string; refs: string;
  attachments: Attachment[]; auto: boolean; auth: 'pass' | 'fail' | 'none';
};

// Worker'ın gönderdiği iletiyi denetler; gönderen geçerli bir adres değilse null. Ekte yalnız ad, boyut, tür (içerik yok).
export function cleanInbound(b: any): InboundInput | null {
  if (!b || typeof b !== 'object' || Array.isArray(b)) return null;
  let from = txt(b.from, 400).trim();
  const inner = /<([^<>\s]+@[^<>\s]+)>/.exec(from);
  if (inner) from = inner[1];
  from = from.toLowerCase();
  if (from.length < 6 || from.length > 254 || !EMAIL.test(from)) return null;
  const attachments: Attachment[] = (Array.isArray(b.attachments) ? b.attachments : [])
    .filter((a: unknown) => !!a && typeof a === 'object' && !Array.isArray(a)).slice(0, 20)
    .map((a: any) => ({
      name: oneLine(a.name, 200),
      size: typeof a.size === 'number' && Number.isFinite(a.size) && a.size >= 0 ? Math.floor(a.size) : null,
      type: oneLine(a.type, 100).toLowerCase(),
    }));
  const auth = b.auth === 'pass' || b.auth === 'fail' ? b.auth : 'none';
  return {
    from, fromName: oneLine(b.fromName, 80), subject: oneLine(b.subject, 998), text: txt(b.text, BODY_MAX),
    messageId: oneLine(b.messageId, 500), refs: oneLine(b.refs, 8000), attachments, auto: b.auto === true, auth,
  };
}

// Yanıt konusu (SQL'deki support_reply_subject ile aynı kural): "Re: <konu ya da Destek talebiniz> [D-XXXXXX]";
// konudaki bütün [D-…] numaraları ve baştaki Re: / Ynt: / Fwd: / İlt: / AW: / SV: önekleri atılır; numara bir kez; ≤ 200.
const PREFIX = /^(re|ynt|yan[ıi]t|fwd?|[iİı]lt|aw|wg|sv|vs|antw|tr)\s*(\[[0-9]+\])?\s*:/i;
export function replySubject(subject: string | null | undefined, ref: string): string {
  let s = oneLine(subject ?? '', 998).replace(/\[\s*[Dd]-[A-Za-z0-9]{6}\s*\]/g, ' ').replace(/\s+/g, ' ').trim();
  while (PREFIX.test(s)) s = s.slice(s.indexOf(':') + 1).trim();
  if (!s) s = 'Destek talebiniz';
  return `Re: ${[...s].slice(0, 180).join('').trim()} [${ref}]`;
}

// Otomatik "alındı" yanıtının metni (SQL'deki support_ack_body ile aynı; RPC'nin ack_body'si önceliklidir)
export function ackBody(ref: string): string {
  return ['Merhaba,', '', `İletinizi aldık. Talep numaranız: ${ref}. En kısa sürede bu adresten yanıt vereceğiz.`, '',
    'Yanıtlarken konu satırındaki numarayı silmeyin; böylece yazışmanız aynı talepte kalır. Lütfen e-postayla şifre ya da kart bilgisi göndermeyin.',
    '', 'Bu e-posta otomatik gönderildi.', '', 'Moyo Destek'].join('\n');
}

// Düz metinden basit HTML (kaçışlı; bağlantı ve biçim yok)
export function textToHtml(text: string): string {
  const paras = text.replace(/\r\n?/g, '\n').split(/\n{2,}/).map((p) => esc(p).replace(/\n/g, '<br>'));
  return `<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.5;color:#0f1b3d">${paras.map((p) => `<p>${p}</p>`).join('')}</div>`;
}

// Kimden: SUPPORT_FROM ("Ad <adres>" ya da yalnız adres) geçerliyse o, yoksa Moyo Destek <destek@moyoapp.com.tr>
export function fromAddress(env: (k: string) => string): string {
  const v = (env('SUPPORT_FROM') ?? '').trim();
  const named = /^([^<>"\r\n,;]{1,80})<([^<>\s@]+@[^<>\s@]+\.[^<>\s@]+)>$/.exec(v);
  if (named) return `${named[1].trim()} <${named[2]}>`;
  if (v && v.length <= 254 && EMAIL.test(v) && !/[<>",;\s]/.test(v)) return v;
  return `Moyo Destek <${SUPPORT_ADDRESS}>`;
}

// Message-ID başlığı: "<id>"; boşluk, köşeli ayraç ya da satır sonu içeren değer kullanılmaz
export function messageIdHeader(id: string): string | null {
  const v = (id ?? '').trim().replace(/^<|>$/g, '');
  return v && v.length <= 500 && /^[^\s<>()"]+$/.test(v) ? `<${v}>` : null;
}

export type Mail = { from: string; to: string; replyTo?: string; subject: string; text: string; html: string; headers?: Record<string, string> };

export function ackMail(x: { ref: string; subject: string; body?: string | null; messageId: string; to: string }, env: (k: string) => string): Mail {
  const text = x.body && x.body.trim() ? x.body : ackBody(x.ref);
  const mid = messageIdHeader(x.messageId);
  return {
    from: fromAddress(env), to: x.to, replyTo: SUPPORT_ADDRESS, subject: replySubject(x.subject, x.ref), text, html: textToHtml(text),
    headers: { 'Auto-Submitted': 'auto-replied', 'X-Auto-Response-Suppress': 'All', ...(mid ? { 'In-Reply-To': mid, References: mid } : {}) },
  };
}

export type ReplyData = { message_id: string; to: string; subject: string; ref: string; body: string; name: string | null };

// Panelden yanıt: alıcı (ad varsa "Ad" <adres>), konu (SQL'den), gövde + numara satırı; Reply-To destek@; In-Reply-To yok
export function replyMail(d: ReplyData, env: (k: string) => string): Mail {
  const name = oneLine(d.name ?? '', 80).replace(/[<>"\\,;]/g, '').trim();
  const ref = /^D-[A-Z0-9]{6}$/.test(d.ref) ? d.ref : '';
  const text = `${d.body}${ref ? `\n\nTalep numaranız ${ref}. Yanıtlarken konu satırındaki numarayı silmeyin.` : ''}`;
  return {
    from: fromAddress(env), to: name ? `"${name}" <${d.to}>` : d.to, replyTo: SUPPORT_ADDRESS,
    subject: oneLine(d.subject, 200) || replySubject(null, ref), text, html: textToHtml(text),
  };
}

// CORS: yalnız yönetim paneli adresleri (ADMIN_PANEL_URL'nin kökü ve workers.dev paneli)
export const PANEL_WORKERS_DEV = 'https://admin-panel.amy60946.workers.dev';
export function panelOrigins(env: (k: string) => string): string[] {
  const out = [PANEL_WORKERS_DEV];
  try {
    const u = new URL((env('ADMIN_PANEL_URL') ?? '').trim());
    if (u.protocol === 'https:') out.push(u.origin);
  } catch { /* tanımlı değil */ }
  return out;
}
// İstek kaynağına göre CORS başlıkları; kaynak (Origin) varsa ve panel değilse null
export function replyCors(origin: string | null, env: (k: string) => string): Record<string, string> | null {
  const base = { 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
                 'Access-Control-Max-Age': '600', Vary: 'Origin' };
  if (origin === null) return base;
  return panelOrigins(env).includes(origin) ? { ...base, 'Access-Control-Allow-Origin': origin } : null;
}

const res = (body: unknown, status: number, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { ...headers, 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' } });

// Gönderim hatasının kısa kodu (günlüğe ve support_message_sent'e; adres ya da içerik yok)
export function errCode(e: unknown): string {
  const x = e as { name?: string; code?: string; message?: string };
  if (x?.name === 'TimeoutError' || x?.name === 'AbortError') return 'timeout';
  const m = /^resend (\d{3})$/.exec(String(x?.message ?? ''));
  if (m) return `resend_${m[1]}`;
  if (x?.message === 'not_configured') return 'not_configured';
  return typeof x?.code === 'string' && /^[A-Z0-9_]{2,40}$/.test(x.code) ? x.code : 'error';
}

export type InboundResult = {
  ok: boolean; error?: string; duplicate?: boolean; ref?: string; request_id?: string; new?: boolean; reopened?: boolean;
  ack?: boolean; ack_message_id?: string | null; ack_body?: string | null; notify?: boolean;
};
export type ReplyInput = { request_id: string; body: string; close: boolean };
export type Deps = {
  create: (x: Input, source: string | null) => Promise<{ ref?: string; error?: string } | null>;
  notify?: (ref: string, x: Input) => Promise<void>;
  inbound: (x: InboundInput) => Promise<InboundResult | null>;
  reply: (jwt: string, apikey: string, x: ReplyInput) => Promise<{ data?: ReplyData | null; error?: { code?: string } | null }>;
  sent: (id: string, ok: boolean, error: string | null) => Promise<void>;
  sendMail: (m: Mail, idempotencyKey: string) => Promise<void>;   // Resend; hata fırlatır
  sendNotice?: (to: string, m: { subject: string; text: string; html: string }) => Promise<void>;
  mailReady: () => boolean;                                        // RESEND_API_KEY var mı
};

const within = <T>(p: Promise<T>, ms: number) => {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const limit = new Promise<void>((done) => { timer = setTimeout(done, ms); });
  return Promise.race([p.then(() => {}, () => {}), limit]).finally(() => clearTimeout(timer));
};

// Gönder ve sonucu yaz (sonuç yazılamasa da hata yukarı çıkmaz)
async function sendAndRecord(deps: Deps, id: string, m: Mail): Promise<boolean> {
  let ok = false, code: string | null = null;
  if (!deps.mailReady()) code = 'not_configured';
  else {
    try { await deps.sendMail(m, `support-${id}`); ok = true; } catch (e) { code = errCode(e); }
  }
  try { await deps.sent(id, ok, code); } catch { /* sağlık denetimi bekleyen iletiyi gösterir */ }
  return ok;
}

export async function handleInbound(req: Request, env: (k: string) => string, deps: Deps): Promise<Response> {
  if (req.method !== 'POST') return res({ ok: false, error: 'method' }, 405);
  if (!forwardKeyOk(req, env)) return res({ ok: false, error: 'unauthorized' }, 401);
  const text = await readBytes(req, INBOUND_MAX_BYTES);
  if (text === null) return res({ ok: false, error: 'too_large' }, 413);
  let body: unknown = null;
  try { body = JSON.parse(text); } catch { body = null; }
  const x = cleanInbound(body);
  if (!x) return res({ ok: false, error: 'invalid' }, 400);
  let r: InboundResult | null = null;
  try { r = await deps.inbound(x); } catch { r = null; }
  if (!r) return res({ ok: false, error: 'server' }, 503);
  if (!r.ok) {
    if (r.error === 'dropped') return res({ ok: false, error: 'dropped' }, 200);
    return r.error === 'invalid' ? res({ ok: false, error: 'invalid' }, 400) : res({ ok: false, error: 'server' }, 503);
  }
  if (r.duplicate || !r.ref) return res({ ok: true, ref: r.ref ?? null }, 200);
  const jobs: Promise<unknown>[] = [];
  if (r.ack && r.ack_message_id) {
    if (isOwnDomain(x.from) || x.auto) {
      jobs.push(deps.sent(r.ack_message_id, false, 'skipped').catch(() => {}));
    } else {
      jobs.push(sendAndRecord(deps, r.ack_message_id,
        ackMail({ ref: r.ref, subject: x.subject, body: r.ack_body, messageId: x.messageId, to: x.from }, env)));
    }
  }
  const to = r.notify ? notifyTarget(env) : null;
  if (to && deps.sendNotice) jobs.push(deps.sendNotice(to, inboxNotice(r.ref, r.reopened ? 'reopened' : 'new', env('ADMIN_PANEL_URL'))));
  await Promise.all(jobs.map((j) => within(j, 12000)));
  return res({ ok: true, ref: r.ref }, 200);
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function cleanReply(b: any): ReplyInput | null {
  if (!b || typeof b !== 'object' || typeof b.request_id !== 'string' || !UUID.test(b.request_id) || typeof b.body !== 'string') return null;
  const body = txt(b.body, BODY_MAX + 1).trim();
  if (!body || body.length > BODY_MAX) return null;
  return { request_id: b.request_id.toLowerCase(), body, close: b.close === true };
}

export async function handleReply(req: Request, env: (k: string) => string, deps: Deps): Promise<Response> {
  const cors = replyCors(req.headers.get('origin'), env);
  if (!cors) return res({ ok: false, error: 'forbidden' }, 403, { Vary: 'Origin' });
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return res({ ok: false, error: 'invalid' }, 405, cors);
  const jwt = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
  if (!jwt || jwt === (req.headers.get('authorization') ?? '').trim()) return res({ ok: false, error: 'forbidden' }, 401, cors);
  const text = await readBytes(req, REPLY_MAX_BYTES);
  if (text === null) return res({ ok: false, error: 'invalid' }, 413, cors);
  let body: unknown = null;
  try { body = JSON.parse(text); } catch { body = null; }
  const x = cleanReply(body);
  if (!x) return res({ ok: false, error: 'invalid' }, 400, cors);
  const apikey = env('SUPABASE_ANON_KEY') || (req.headers.get('apikey') ?? '');
  let r: { data?: ReplyData | null; error?: { code?: string } | null };
  try { r = await deps.reply(jwt, apikey, x); } catch { return res({ ok: false, error: 'send_failed' }, 503, cors); }
  if (r.error) {
    const code = r.error.code ?? '';
    const denied = code === '42501' || /^PGRST30\d$/.test(code);
    return res({ ok: false, error: denied ? 'forbidden' : 'invalid' }, denied ? 403 : 400, cors);
  }
  const d = r.data;
  if (!d || typeof d.message_id !== 'string' || typeof d.to !== 'string' || !EMAIL.test(d.to)) {
    return res({ ok: false, error: 'invalid' }, 400, cors);
  }
  const ok = await sendAndRecord(deps, d.message_id, replyMail(d, env));
  return ok ? res({ ok: true, status: x.close ? 'closed' : 'answered' }, 200, cors)
            : res({ ok: false, error: 'send_failed', status: 'in_progress' }, 502, cors);
}

// Yönlendirici: form (GET / POST), /inbound, /reply; başka yol 404
export async function serve(req: Request, env: (k: string) => string, deps: Deps): Promise<Response> {
  const route = routeOf(req.url);
  if (route === 'inbound') return handleInbound(req, env, deps);
  if (route === 'reply') return handleReply(req, env, deps);
  if (route === 'form') return handle(req, env, deps.create, deps.notify);
  return new Response('Bulunamadı', { status: 404, headers: { 'Cache-Control': 'no-store' } });
}

// Canlı: Resend (alan adı doğrulanmış; 10 sn'de kesilir). Yalnız durum kodu hata olarak çıkar.
async function sendResend(key: string, m: Mail, idem?: string) {
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', ...(idem ? { 'Idempotency-Key': idem } : {}) },
    body: JSON.stringify({ from: m.from, to: [m.to], subject: m.subject, text: m.text, html: m.html,
                           ...(m.replyTo ? { reply_to: m.replyTo } : {}), ...(m.headers ? { headers: m.headers } : {}) }),
    signal: AbortSignal.timeout(10000),
  });
  if (!r.ok) throw new Error(`resend ${r.status}`);
}

if (typeof Deno !== 'undefined') {
  const env = (k: string) => Deno!.env.get(k) ?? '';
  const service = async () => {
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    return createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
  };
  // Ekip uyarısı: Resend (noreply@<MAIL_FROM alan adı>) ya da test SMTP'si; hiçbiri yoksa gönderilmez
  const sendNotice = async (to: string, m: { subject: string; text: string; html: string }) => {
    try {
      if (env('RESEND_API_KEY') && env('MAIL_FROM')) {
        const from = `noreply@${env('MAIL_FROM').split('@')[1]}`;
        await sendResend(env('RESEND_API_KEY'), { from: `Moyo Destek <${from}>`, to, subject: m.subject, text: m.text, html: m.html });
      } else if (env('SMTP_USER') && env('SMTP_PASS')) {
        const nodemailer = (await import('npm:nodemailer@7.0.9')).default;
        const port = Number(env('SMTP_PORT') || 465);
        const t = nodemailer.createTransport({ host: env('SMTP_HOST') || 'smtp.gmail.com', port, secure: port === 465,
                                               auth: { user: env('SMTP_USER'), pass: env('SMTP_PASS') } });
        await t.sendMail({ from: { name: 'Moyo Destek', address: env('SMTP_USER') }, to, subject: m.subject, text: m.text, html: m.html });
      }
    } catch (e) {
      console.error('support notify', errCode(e));
    }
  };
  Deno.serve((req) => serve(req, env, {
    create: async (x, source) => {
      const db = await service();
      const { data, error } = await db.rpc('support_request_create',
        { p_app: x.app, p_topic: x.topic, p_email: x.email, p_name: x.name, p_message: x.message, p_source: source });
      if (error) { console.error('support_request_create', error.code); return null; }
      return data as { ref?: string; error?: string };
    },
    notify: async (ref, x) => {
      const to = notifyTarget(env);
      if (to) await sendNotice(to, teamNotice(ref, x, env('ADMIN_PANEL_URL')));
    },
    inbound: async (x) => {
      const db = await service();
      const { data, error } = await db.rpc('support_inbound_email', {
        p_from: x.from, p_from_name: x.fromName, p_subject: x.subject, p_body: x.text, p_message_id: x.messageId || null,
        p_refs: x.refs, p_attachments: x.attachments, p_auto: x.auto, p_auth: x.auth });
      if (error) { console.error('support_inbound_email', error.code); return null; }
      return data as InboundResult;
    },
    reply: async (jwt, apikey, x) => {
      const { createClient } = await import('jsr:@supabase/supabase-js@2');
      const db = createClient(env('SUPABASE_URL'), apikey, {
        global: { headers: { Authorization: `Bearer ${jwt}` } }, auth: { persistSession: false, autoRefreshToken: false } });
      const { data, error } = await db.rpc('admin_support_reply', { p_id: x.request_id, p_body: x.body, p_close: x.close });
      if (error) console.error('admin_support_reply', error.code);
      return { data: data as ReplyData | null, error: error ? { code: error.code } : null };
    },
    sent: async (id, ok, code) => {
      const db = await service();
      const { error } = await db.rpc('support_message_sent', { p_message: id, p_ok: ok, p_error: code });
      if (error) console.error('support_message_sent', error.code);
      if (!ok) console.error('support mail', code);
    },
    sendMail: (m, idem) => sendResend(env('RESEND_API_KEY'), m, idem),
    sendNotice,
    mailReady: () => !!env('RESEND_API_KEY'),
  }));
}
