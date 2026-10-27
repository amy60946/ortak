// legal: yasal metinlerin herkese açık adresi (mağaza "Gizlilik Politikası" bağlantısı, kayıt ekranında okuma, web).
// Alan adı alınana dek: https://<proje>.supabase.co/functions/v1/legal?doc=gizlilik  (sözleşme: sozlesme/admin.md, hukuk/README.md)
//   GET ?doc=<anahtar>[&v=<sürüm>][&format=html|json]   güncel (yayındaki; yoksa taslak) ya da belirtilen sürüm
//   GET (doc yok)                                        metin listesi
// "Verify JWT" KAPALI yayınlanır: oturum gerekmez, yalnız okur. Tablo anon'a kapalı; işlev sunucu anahtarıyla yalnız
// legal_documents'tan taslak/yayında/eski metni okur. Metinler depodan gelir (ortak/hukuk), kullanıcı girdisi değildir.

const BASE_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const HTML_HEADERS = {
  ...BASE_HEADERS,
  'Content-Type': 'text/html; charset=utf-8',
  'Cache-Control': 'public, max-age=300',
  'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'",
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
};

export const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
export const KEY = /^[a-z][a-z0-9-]{1,59}$/;
export const VER = /^v[0-9]{1,3}$/;

export function page(title: string, body: string, draft: boolean): string {
  return `<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title><style>
:root{color-scheme:light dark;--bg:#fff;--fg:#1d2433;--mu:#5d6678;--ln:#e3e6ec;--ac:#2f6fdb;--wb:#fff4d6;--wf:#6b4d00}
@media (prefers-color-scheme:dark){:root{--bg:#12151b;--fg:#e8ebf1;--mu:#9aa3b2;--ln:#2a303b;--ac:#7aa7ff;--wb:#3a2f12;--wf:#ffd98a}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
main{max-width:760px;margin:0 auto;padding:24px 16px 64px}a{color:var(--ac)}h1{font-size:1.6em;line-height:1.25}
h2{font-size:1.25em;margin-top:2em;border-top:1px solid var(--ln);padding-top:1em}table{border-collapse:collapse;width:100%;display:block;overflow-x:auto}
td,th{border:1px solid var(--ln);padding:6px 8px;vertical-align:top;text-align:left}blockquote{margin:0;padding:8px 14px;border-left:3px solid var(--ln);color:var(--mu)}
.draft{background:var(--wb);color:var(--wf);padding:10px 14px;border-radius:10px;margin-bottom:16px}.mu{color:var(--mu);font-size:.9em}
</style></head><body><main>${draft ? '<div class="draft">TASLAK — bu metin henüz hukuk onayından geçmedi.</div>' : ''}${body}</main></body></html>`;
}

if (typeof Deno !== 'undefined') {
  Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers: BASE_HEADERS });
    if (req.method !== 'GET') return new Response('method', { status: 405, headers: BASE_HEADERS });
    const url = new URL(req.url);
    const doc = url.searchParams.get('doc') ?? '';
    const ver = url.searchParams.get('v') ?? '';
    const asJson = url.searchParams.get('format') === 'json';
    const env = (k: string) => Deno!.env.get(k) ?? '';
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });

    if (!doc) {
      const { data } = await db.from('legal_documents').select('key, version, title, status, apps')
        .in('status', ['published', 'draft']).order('title');
      // her anahtarın güncel sürümü (yayındaki; yoksa en yeni taslak)
      const cur = new Map<string, any>();
      for (const d of data ?? []) {
        const c = cur.get(d.key);
        const rank = (x: any) => (x.status === 'published' ? 1000 : 0) + Number(String(x.version).slice(1));
        if (!c || rank(d) > rank(c)) cur.set(d.key, d);
      }
      const list = [...cur.values()];
      if (asJson) return Response.json(list, { headers: BASE_HEADERS });
      const items = list.map((d) => `<li><a href="?doc=${esc(d.key)}">${esc(d.title)}</a> <span class="mu">${esc(d.version)}${d.status === 'draft' ? ' · taslak' : ''}</span></li>`).join('');
      return new Response(page('Yasal metinler', `<h1>Yasal metinler</h1><ul>${items}</ul>`, false), { headers: HTML_HEADERS });
    }

    if (!KEY.test(doc) || (ver && !VER.test(ver))) return new Response('bad request', { status: 400, headers: BASE_HEADERS });
    let q = db.from('legal_documents').select('key, version, title, status, published_at, body_md').eq('key', doc);
    q = ver ? q.eq('version', ver) : q.in('status', ['published', 'draft']);
    const { data, error } = await q;
    if (error) return new Response('error', { status: 500, headers: BASE_HEADERS });
    const rows = (data ?? []).sort((a: any, b: any) =>
      (b.status === 'published' ? 1 : 0) - (a.status === 'published' ? 1 : 0) || Number(b.version.slice(1)) - Number(a.version.slice(1)));
    const d = rows[0];
    if (!d) return new Response(page('Bulunamadı', '<h1>Metin bulunamadı</h1><p><a href="?">Yasal metinler</a></p>', false), { status: 404, headers: HTML_HEADERS });
    if (asJson) return Response.json(d, { headers: BASE_HEADERS });
    const { marked } = await import('npm:marked@12.0.2');
    const html = await marked.parse(d.body_md, { gfm: true });
    const foot = `<p class="mu">Sürüm ${esc(d.version)}${d.published_at ? ' · yayın ' + esc(String(d.published_at).slice(0, 10)) : ''}${d.status === 'retired' ? ' · eski sürüm' : ''} · <a href="?">Bütün yasal metinler</a></p>`;
    return new Response(page(d.title, html + foot, d.status === 'draft'), { headers: HTML_HEADERS });
  });
}
