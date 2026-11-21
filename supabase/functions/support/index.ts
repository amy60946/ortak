// support: destek talebi (herkese açık /destek formu) ve sabit destek adresi.
//   GET  /functions/v1/support → 302 <LEGAL_PUBLIC_URL kökü>/destek  (App Store "Support URL" ve uygulamalardaki "Yardım ve
//        iletişim" bu sabit adresi kullanır; alan adı alınınca yalnız LEGAL_PUBLIC_URL değişir, uygulama sürümü gerekmez)
//   POST { app, topic, email, name?, message, adult: true, website?, elapsed_ms? } → 200 {ok, ref} · 400/429/503 {error}
//        `adult`: "18 yaşından büyüğüm" kutusu (form yetişkinler içindir; çocuk ürünü, Apple 1.3/5.1.4).
//        `website` gizli tuzak alanıdır (insan doldurmaz); 3 saniyeden kısa doldurulan form sessizce yok sayılır.
// Kayıt SQL'de: support_request_create (proposed/20261121110000_support_invite_limits.sql): kaynak (gönderenin adresi, günlük
//   tuzla özetlenir) başına saatte 5 ve günde 15; e-posta başına 24 saatte 3; genel saatte 300 (son çare; istenmeyen ve KVKK
//   sayılmaz); KVKK ("privacy") ayrı paydan saatte 100.
// Kaynak adresi: Worker (admin-panel/worker) formu gönderenin adresini `x-moyo-client-ip` başlığıyla, paylaşılan gizli anahtarı
//   `x-moyo-forward-key` ile iletir. Anahtar (secret SUPPORT_FORWARD_KEY) eşleşirse iletilen adres kullanılır; eşleşmezse ya da
//   başlık yoksa işlevin gördüğü istemci adresi. SUPPORT_FORWARD_KEY hiç tanımlı değilse kaynak sınırı uygulanmaz (Worker'dan
//   gelen bütün talepler tek adresten görünür; sınır formu herkese kapatırdı). Önce Worker'a, sonra Supabase'e eklenir.
// Gövde en çok 20 000 karakter (Content-Length olmasa da akış kesilir).
// Ekip bildirimi (kullanıcı kararı 20 Kasım 2026, "Destek formu kalsın"): her yeni talepte SUPPORT_NOTIFY_TO adresine
//   (yoksa destek@moyoapp.com.tr) tek satırlık e-posta: talep no, uygulama, konu, "Panelde aç". Kişinin e-postası, adı ve
//   mesajı bildirime GİRMEZ; kişisel veri panelde kalır. Gönderim Resend (RESEND_API_KEY + MAIL_FROM; gönderen adres
//   MAIL_FROM'un alan adında noreply@) ya da test SMTP'si (SMTP_USER + SMTP_PASS, invite-email ile aynı). Başarısız
//   bildirim talebi düşürmez (en çok 4 sn beklenir, yalnız hata kodu günlüğe yazılır).
// Yayın: Supabase → Edge Functions → support, "Verify JWT" KAPALI. Secret: LEGAL_PUBLIC_URL (zaten var); isteğe bağlı
//   ADMIN_PANEL_URL (panelin adresi; "Panelde aç" bağlantısı için) ve SUPPORT_NOTIFY_TO.
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
  too_many: [429, 'Bu e-posta adresinden bugün yeterince talep aldık; yanıtımızı bekleyin ya da yarın yeniden deneyin.'],
  too_many_source: [429, 'Bu bağlantıdan kısa sürede çok fazla talep geldi; bir süre sonra yeniden deneyin.'],
  busy: [503, 'Şu an çok fazla talep var; birkaç dakika sonra yeniden deneyin.'],
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

const IP = /^[0-9A-Fa-f:.]{2,45}$/;
// Talebin kaynağı: anahtar eşleşirse Worker'ın ilettiği adres; anahtar tanımlı değilse null (kaynak sınırı yok)
export function sourceOf(req: Request, env: (k: string) => string): string | null {
  const key = env('SUPPORT_FORWARD_KEY');
  if (!key) return null;
  const given = req.headers.get('x-moyo-forward-key');
  const fwd = (req.headers.get('x-moyo-client-ip') ?? '').trim();
  if (given !== null && key.length >= 16 && same(key, given) && IP.test(fwd)) return fwd;
  const own = (req.headers.get('cf-connecting-ip') ?? req.headers.get('x-real-ip')
               ?? (req.headers.get('x-forwarded-for') ?? '').split(',')[0]).trim();
  return own && IP.test(own) ? own : 'unknown';
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
export const NOTIFY_TO = 'destek@moyoapp.com.tr';

// Ekibe giden bildirim: yalnız talep no, uygulama, konu ve panel bağlantısı (e-posta, ad, mesaj yok).
export function teamNotice(ref: string, x: Pick<Input, 'app' | 'topic'>, panelUrl: string) {
  const app = APP_LABELS[x.app] ?? 'Diğer', topic = TOPIC_LABELS[x.topic] ?? 'Diğer';
  const base = panelUrl.replace(/\/+$/, '');
  const link = /^https:\/\//.test(base) ? `${base}/#/destek` : '';
  const line = `Yeni destek talebi ${ref} · ${app} · ${topic}`;
  const esc = (t: string) => t.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
  return {
    subject: line,
    text: link ? `${line}\nPanelde aç: ${link}` : `${line}\nYönetim paneli › Destek`,
    html: `<p>${esc(line)}</p><p>${link ? `<a href="${esc(link)}">Panelde aç</a>` : 'Yönetim paneli › Destek'}</p>`,
  };
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

if (typeof Deno !== 'undefined') {
  const env = (k: string) => Deno!.env.get(k) ?? '';
  Deno.serve(async (req) => handle(req, env, async (x, source) => {
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    const { data, error } = await db.rpc('support_request_create',
      { p_app: x.app, p_topic: x.topic, p_email: x.email, p_name: x.name, p_message: x.message, p_source: source });
    if (error) { console.error('support_request_create', error.code); return null; }
    return data as { ref?: string; error?: string };
  }, async (ref, x) => {
    const m = teamNotice(ref, x, env('ADMIN_PANEL_URL'));
    const to = env('SUPPORT_NOTIFY_TO') || NOTIFY_TO;
    try {
      if (env('RESEND_API_KEY') && env('MAIL_FROM')) {
        const from = `noreply@${env('MAIL_FROM').split('@')[1]}`;
        const r = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: { Authorization: `Bearer ${env('RESEND_API_KEY')}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ from: `Moyo Destek <${from}>`, to: [to], subject: m.subject, text: m.text, html: m.html }),
        });
        if (!r.ok) throw new Error(`resend ${r.status}`);
      } else if (env('SMTP_USER') && env('SMTP_PASS')) {
        const nodemailer = (await import('npm:nodemailer@7.0.9')).default;
        const port = Number(env('SMTP_PORT') || 465);
        const t = nodemailer.createTransport({ host: env('SMTP_HOST') || 'smtp.gmail.com', port, secure: port === 465,
                                               auth: { user: env('SMTP_USER'), pass: env('SMTP_PASS') } });
        await t.sendMail({ from: { name: 'Moyo Destek', address: env('SMTP_USER') }, to, subject: m.subject, text: m.text, html: m.html });
      }
    } catch (e) {
      const x2 = e as { code?: string; message?: string };
      console.error('support notify', x2.code ?? (String(x2.message ?? '').startsWith('resend') ? x2.message : 'error'));
    }
  }));
}
