// verify-doc: yönetim panelinin uzman belgesine tek kapısı (sozlesme/admin.md, migrations/20261026400000_verify_doc_server.sql).
// Kova `verify` yöneticiye doğrudan açık değil; belgeyi yalnız bu işlev, denetim kaydı yazdıktan sonra kısa süreli bağlantıyla verir.
//   POST { action: 'open', id }  →  { url }        admin_verification_open (support/owner + iki adımlı, denetim kaydı) → 2 dk imzalı bağlantı
//   POST { action: 'purge' }     →  { removed }    karar verilmiş / geri çekilmiş başvuruların dosyalarını siler (storage_trash)
// "Verify JWT" KAPALI yayınlanır (diğer işlevlerimiz gibi); yetkiyi işlevin içinde, yöneticinin kendi oturumuyla sunucu denetler
// (rol ve aal2 yalnız SQL'de: admin_verification_open / admin_can_review).

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers });
const LINK_SECONDS = 120;

// deno-lint-ignore no-explicit-any
async function drainTrash(db: any): Promise<number> {
  let removed = 0;
  for (let round = 0; round < 4; round++) {
    const { data } = await db.rpc('storage_trash_take', { p_bucket: 'verify', p_limit: 50 });
    const rows = (data ?? []) as { id: number; path: string }[];
    if (!rows.length) break;
    const { error } = await db.storage.from('verify').remove(rows.map((r) => r.path));
    if (error) throw new Error(error.message);
    await db.rpc('storage_trash_done', { p_ids: rows.map((r) => r.id) });
    removed += rows.length;
    if (rows.length < 50) break;
  }
  return removed;
}

if (typeof Deno !== 'undefined') {
  Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers });
    if (req.method !== 'POST') return reply({ error: 'method' }, 405);
    const env = (k: string) => Deno!.env.get(k) ?? '';
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const auth = req.headers.get('Authorization') ?? '';
    if (!/^Bearer\s+\S+/i.test(auth)) return reply({ error: 'auth' }, 401);
    const opts = { auth: { persistSession: false, autoRefreshToken: false } };
    // Yöneticinin oturumuyla: rol, iki adımlı doğrulama ve denetim kaydı SQL'de
    const me = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), { ...opts, global: { headers: { Authorization: auth } } });
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), opts);
    const body = await req.json().catch(() => ({}));

    if (body.action === 'open') {
      if (typeof body.id !== 'string') return reply({ error: 'id' }, 400);
      const { data: path, error } = await me.rpc('admin_verification_open', { p_id: body.id });
      if (error || typeof path !== 'string') return reply({ error: error?.message ?? 'Belge yok' }, 403);
      const { data, error: e2 } = await db.storage.from('verify').createSignedUrl(path, LINK_SECONDS);
      if (e2 || !data) return reply({ error: 'Bağlantı alınamadı' }, 500);
      return reply({ url: data.signedUrl });
    }

    if (body.action === 'purge') {
      const { data: ok } = await me.rpc('admin_can_review');
      if (ok !== true) return reply({ error: 'Yetki yok (Destek/Sahip + iki adımlı doğrulama)' }, 403);
      try {
        return reply({ removed: await drainTrash(db) });
      } catch (e) {
        return reply({ error: (e as Error).message }, 500);
      }
    }

    return reply({ error: 'action' }, 400);
  });
}
