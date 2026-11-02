// support: destek talebi (herkese açık /destek formu) ve sabit destek adresi.
//   GET  /functions/v1/support → 302 <LEGAL_PUBLIC_URL kökü>/destek  (App Store "Support URL" ve uygulamalardaki "Yardım ve
//        iletişim" bu sabit adresi kullanır; alan adı alınınca yalnız LEGAL_PUBLIC_URL değişir, uygulama sürümü gerekmez)
//   POST { app, topic, email, name?, message, adult: true, website?, elapsed_ms? } → 200 {ok, ref} · 400/429/503 {error}
//        `adult`: "18 yaşından büyüğüm" kutusu (form yetişkinler içindir; çocuk ürünü, Apple 1.3/5.1.4).
//        `website` gizli tuzak alanıdır (insan doldurmaz); 3 saniyeden kısa doldurulan form sessizce yok sayılır.
// Kayıt SQL'de: support_request_create (proposed/20261102210000_support.sql; e-posta başına 24 saatte 3, saatte toplam 60).
// Yayın: Supabase → Edge Functions → support, "Verify JWT" KAPALI. Secret: LEGAL_PUBLIC_URL (zaten var).
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
  busy: [503, 'Şu an çok fazla talep var; birkaç dakika sonra yeniden deneyin.'],
  server: [503, 'Talep kaydedilemedi; biraz sonra yeniden deneyin.'],
};

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

export async function handle(req: Request, env: (k: string) => string,
                             create: (x: Input) => Promise<{ ref?: string; error?: string } | null>): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
  if (req.method === 'GET' || req.method === 'HEAD') {
    const to = supportPage(env('LEGAL_PUBLIC_URL'));
    if (!to) return new Response('Destek sayfası adresi tanımlı değil', { status: 404, headers: CORS });
    return new Response(null, { status: 302, headers: { ...CORS, Location: to, 'Cache-Control': 'public, max-age=300' } });
  }
  if (req.method !== 'POST') return new Response('method', { status: 405, headers: CORS });
  const text = await req.text().catch(() => '');
  if (text.length > 20000) return json({ error: MESSAGES.invalid[1] }, 413);
  let body: any = null;
  try { body = JSON.parse(text); } catch { body = null; }
  const x = clean(body);
  const pre = precheck(x);
  if (pre === 'bot') return json({ ok: true });
  if (pre) return json({ error: MESSAGES[pre][1] }, MESSAGES[pre][0]);
  let r: { ref?: string; error?: string } | null = null;
  try { r = await create(x); } catch { r = null; }
  if (r?.ref) return json({ ok: true, ref: r.ref });
  const [status, msg] = MESSAGES[r?.error ?? 'server'] ?? MESSAGES.server;
  return json({ error: msg }, status);
}

if (typeof Deno !== 'undefined') {
  const env = (k: string) => Deno!.env.get(k) ?? '';
  Deno.serve(async (req) => handle(req, env, async (x) => {
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    const { data, error } = await db.rpc('support_request_create',
      { p_app: x.app, p_topic: x.topic, p_email: x.email, p_name: x.name, p_message: x.message });
    if (error) { console.error('support_request_create', error.code); return null; }
    return data as { ref?: string; error?: string };
  }));
}
