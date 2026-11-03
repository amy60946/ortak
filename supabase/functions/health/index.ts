// health: dış izleme servisi (UptimeRobot, Better Stack ya da GitHub Actions) için sistem sağlığı adresi.
//   GET /functions/v1/health                      → 200 {"status":"ok"|"info"|"warn"} · 503 {"status":"fail"} (alarm)
//   GET …/health  + başlık x-health-key: <HEALTH_KEY> → ayrıca denetim adları ve düzeyleri ({"checks":[{key, level}]})
//   Anahtar verilir ama yanlışsa 401. İzleme servisine anahtar gerekmez (Sentry: gizli anahtar izleme ayarına konmaz).
// Gövde hiçbir zaman sayı, zaman ya da kişisel veri taşımaz; ayrıntı panelde "Sistem sağlığı" ekranında.
// Denetimlerin kendisi SQL'de: public.ops_health() (proposed/20261102200000_kvkk_ops.sql). Sözleşme: sozlesme/admin.md.
// Yayın: Supabase → Edge Functions → health, "Verify JWT" KAPALI. Secret HEALTH_KEY isteğe bağlı (en az 24 karakter).
// Testi index.test.ts (node --experimental-strip-types --test supabase/functions/health/*.test.ts); Deno.serve yalnız Deno'da.

export type Level = 'ok' | 'info' | 'warn' | 'fail';
export type Check = { key: string; level: Level; label?: string; detail?: string };
export type Health = { status: Level; checked_at?: string; checks: Check[] };

const HEADERS = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' };

// Sabit sürede karşılaştırma (anahtar zamanlamadan tahmin edilemesin)
export function same(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

export function authorized(secret: string, given: string): boolean {
  return secret.length >= 24 && same(secret, given);
}

// Dışarıya giden özet: yalnız ad + düzey; en kötü düzey HTTP durumunu belirler
export function summarize(h: Health | null): { http: number; body: { status: Level; checks: { key: string; level: Level }[] } } {
  if (!h || !Array.isArray(h.checks)) return { http: 503, body: { status: 'fail', checks: [{ key: 'db', level: 'fail' }] } };
  const levels: Level[] = ['ok', 'info', 'warn', 'fail'];
  const checks = h.checks.filter((c) => c && typeof c.key === 'string' && levels.includes(c.level))
    .map((c) => ({ key: c.key, level: c.level }));
  const worst = checks.reduce<Level>((w, c) => (levels.indexOf(c.level) > levels.indexOf(w) ? c.level : w), 'ok');
  return { http: worst === 'fail' ? 503 : 200, body: { status: worst, checks } };
}

export async function handle(req: Request, env: (k: string) => string,
                             health: () => Promise<Health | null>): Promise<Response> {
  if (req.method !== 'GET' && req.method !== 'HEAD') return new Response('GET', { status: 405 });
  const given = req.headers.get('x-health-key');
  if (given !== null && !authorized(env('HEALTH_KEY'), given)) {
    return new Response(JSON.stringify({ error: 'yetkisiz' }), { status: 401, headers: HEADERS });
  }
  let h: Health | null = null;
  try { h = await health(); } catch { h = null; }
  const s = summarize(h);
  const body = given !== null ? s.body : { status: s.body.status };
  return new Response(req.method === 'HEAD' ? null : JSON.stringify(body), { status: s.http, headers: HEADERS });
}

if (typeof Deno !== 'undefined') {
  const env = (k: string) => Deno!.env.get(k) ?? '';
  Deno.serve(async (req) => handle(req, env, async () => {
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    const { data, error } = await db.rpc('ops_health');
    if (error) { console.error('ops_health', error.code); return null; }
    return data as Health;
  }));
}
