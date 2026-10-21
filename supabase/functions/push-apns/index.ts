// push-apns: bir bildirimi (notifications satırı) alıcının iPhone'larına Apple Push (APNs) ile gönderir.
// Çağıran: veritabanı tetikleyicisi notifications_push (pg_net) → body {"notification_id": 123}.
// Aynı bildirim iki kez gönderilmez (apns_sent_at). "Verify JWT" kapalı çalışır; çağrı yalnız henüz gönderilmemiş
// gerçek bir bildirimi gönderebilir, başka bir şey yapamaz.
// Secret'lar (Supabase → Edge Functions → Secrets): APNS_KEY_P8 (.p8 dosyasının tüm metni), APNS_KEY_ID, APNS_TEAM_ID.
// İsteğe bağlı: PUSH_SECRET (Vault'taki `push_secret` ile aynı değer) tanımlıysa çağrı `x-push-secret` başlığını taşımalı.
// İsteğe bağlı: APNS_SANDBOX=1 (yalnız Xcode'dan kurulan geliştirme sürümleri için; TestFlight/App Store üretimdir).
import { createClient } from 'jsr:@supabase/supabase-js@2';

const TOPIC: Record<string, string> = { parent: 'com.parentapp.ios', child: 'com.gameapp.ios', clinic: 'com.clinicapp.uzman' };
const PROD = 'api.push.apple.com';
const SANDBOX = 'api.sandbox.push.apple.com';

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

const b64url = (b: ArrayBuffer | Uint8Array | string) => {
  const bytes = typeof b === 'string' ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = '';
  bytes.forEach((x) => { s += String.fromCharCode(x); });
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

// Apple sağlayıcı anahtarı (JWT, ES256): 20–60 dk geçerli; 50 dk önbellek
let cached: { jwt: string; at: number } | null = null;
async function providerToken() {
  if (cached && Date.now() - cached.at < 50 * 60e3) return cached.jwt;
  const pem = Deno.env.get('APNS_KEY_P8') ?? '';
  const body = pem.replace(/\\n/g, '\n').replace(/-----(BEGIN|END) [A-Z ]*KEY-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const head = b64url(JSON.stringify({ alg: 'ES256', kid: Deno.env.get('APNS_KEY_ID') }));
  const claims = b64url(JSON.stringify({ iss: Deno.env.get('APNS_TEAM_ID'), iat: Math.floor(Date.now() / 1000) }));
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(`${head}.${claims}`));
  cached = { jwt: `${head}.${claims}.${b64url(sig)}`, at: Date.now() };
  return cached.jwt;
}

async function send(host: string, token: string, topic: string, payload: unknown) {
  const r = await fetch(`https://${host}/3/device/${token}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${await providerToken()}`,
      'apns-topic': topic, 'apns-push-type': 'alert', 'apns-priority': '10',
    },
    body: JSON.stringify(payload),
  });
  const reason = r.ok ? '' : ((await r.json().catch(() => ({}))) as { reason?: string }).reason ?? String(r.status);
  return { ok: r.ok, status: r.status, reason };
}

Deno.serve(async (req) => {
  const secret = Deno.env.get('PUSH_SECRET');
  if (secret && req.headers.get('x-push-secret') !== secret) return Response.json({ error: 'yetkisiz' }, { status: 401 });
  const { notification_id } = await req.json().catch(() => ({}));
  if (!notification_id) return Response.json({ error: 'notification_id gerekli' }, { status: 400 });

  // Sahiplen: yalnız henüz gönderilmemişse
  const { data: n } = await db.from('notifications').update({ apns_sent_at: new Date().toISOString() })
    .eq('id', notification_id).is('apns_sent_at', null).select('*').maybeSingle();
  if (!n) return Response.json({ skipped: true });
  const topic = TOPIC[n.app];
  if (!topic) return Response.json({ skipped: 'uygulama için iOS kimliği yok' });

  const { data: tokens } = await db.from('push_tokens').select('token')
    .eq('user_id', n.user_id).eq('app', n.app).eq('platform', 'ios').not('token', 'like', 'ExponentPushToken[%');
  const { count } = await db.from('notifications').select('id', { count: 'exact', head: true })
    .eq('user_id', n.user_id).is('read_at', null);
  const data = { ...(n.data ?? {}), kind: n.kind, notification_id: n.id };
  // expo-notifications veriyi "body" alanından okur; Unity için üst düzeyde de var
  const payload = { aps: { alert: { title: n.title, body: n.body }, sound: 'default', badge: count ?? 0 }, body: data, ...data };

  const first = Deno.env.get('APNS_SANDBOX') === '1' ? SANDBOX : PROD;
  const results = [];
  for (const { token } of tokens ?? []) {
    let r = await send(first, token, topic, payload);
    // Geliştirme sürümünün anahtarı üretim sunucusunda "BadDeviceToken" verir: bir kez diğer sunucuyu dene
    if (r.reason === 'BadDeviceToken') r = await send(first === PROD ? SANDBOX : PROD, token, topic, payload);
    if (r.status === 410 || r.reason === 'BadDeviceToken' || r.reason === 'Unregistered') {
      await db.from('push_tokens').delete().eq('token', token);
    }
    results.push({ ok: r.ok, reason: r.reason });
  }
  return Response.json({ sent: results.filter((x) => x.ok).length, results });
});
