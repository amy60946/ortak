// invite-info: uzmanın aile davet bağlantısının açılış sayfası (web/davet) için herkese açık, salt okunur bilgi.
// GET https://<proje>.supabase.co/functions/v1/invite-info?t=<32 karakter anahtar>
// → {status: open|used|expired|revoked|not_found, clinic, clinician, title, code, expires_at}
// "Verify JWT" KAPALI yayınlanır (aile henüz hesap açmadı). Veritabanına yalnız service role ile `clinic_invite_open` çağrılır;
// anahtar 128 bit rastgele olduğundan tahmin edilemez. Kişisel veri yok: uzman adı/unvanı, klinik adı, kod.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const env = (k: string) => Deno.env.get(k) ?? '';
const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Cache-Control': 'no-store',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'GET') return Response.json({ status: 'not_found' }, { status: 405, headers });
  const t = (new URL(req.url).searchParams.get('t') ?? '').trim().toLowerCase();
  if (!/^[0-9a-f]{32}$/.test(t)) return Response.json({ status: 'not_found' }, { headers });
  const { data, error } = await db.rpc('clinic_invite_open', { p_token: t });
  if (error) return Response.json({ status: 'error' }, { status: 500, headers });
  // açık olmayan davette kod gösterilmez
  const out = data as Record<string, unknown>;
  if (out.status !== 'open') delete out.code;
  return Response.json(out, { headers });
});
