// node --experimental-strip-types --test supabase/functions/support/*.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { clean, handle, precheck, supportPage, teamNotice } from './index.ts';

const env = (k: string) => (k === 'LEGAL_PUBLIC_URL' ? 'https://admin-panel.example.workers.dev/yasal' : '');
const good = { app: 'parent', topic: 'bug', email: 'veli@example.com', name: 'Ayşe', message: 'Uygulama açılmıyor, yardım eder misiniz?', adult: true, elapsed_ms: 15000 };
const post = (b: unknown) => new Request('https://x/functions/v1/support', { method: 'POST', body: JSON.stringify(b) });

test('sabit adres destek sayfasına yönlenir ("/yasal" ile girilmiş olsa da)', async () => {
  assert.equal(supportPage('https://a.dev/yasal/'), 'https://a.dev/destek');
  assert.equal(supportPage(''), null);
  const r = await handle(new Request('https://x/functions/v1/support'), env, async () => null);
  assert.equal(r.status, 302); assert.equal(r.headers.get('Location'), 'https://admin-panel.example.workers.dev/destek');
  assert.equal((await handle(new Request('https://x/functions/v1/support'), () => '', async () => null)).status, 404);
});

test('ön denetim: tuzak alanı ve çok hızlı doldurma bot sayılır; eksik bilgi geçersiz', () => {
  assert.equal(precheck(clean(good)), null);
  assert.equal(precheck(clean({ ...good, website: 'http://spam' })), 'bot');
  assert.equal(precheck(clean({ ...good, elapsed_ms: 800 })), 'bot');
  assert.equal(precheck(clean({ ...good, email: 'yok' })), 'invalid');
  assert.equal(precheck(clean({ ...good, message: 'kısa' })), 'invalid');
  assert.equal(precheck(clean({ ...good, app: 'admin' })), 'invalid');
  assert.equal(precheck(clean({ ...good, adult: false })), 'adult');
  assert.equal(precheck(clean({ ...good, adult: '1' })), null);
  assert.equal(clean({ ...good, message: 'x'.repeat(5000) }).message.length, 3000);
});

test('gönderim: talep numarası; bot sessizce "tamam" alır ama kayıt açılmaz; sınır hataları Türkçe', async () => {
  let calls = 0;
  const create = async () => { calls++; return { ref: 'D-ABC234' }; };
  const ok = await handle(post(good), env, create);
  assert.equal(ok.status, 200); assert.deepEqual(await ok.json(), { ok: true, ref: 'D-ABC234' });
  const bot = await handle(post({ ...good, website: 'x' }), env, create);
  assert.equal(bot.status, 200); assert.equal((await bot.json()).ref, undefined); assert.equal(calls, 1);
  const many = await handle(post(good), env, async () => ({ error: 'too_many' }));
  assert.equal(many.status, 429); assert.match((await many.json()).error, /bugün/);
  const down = await handle(post(good), env, async () => { throw new Error('db'); });
  assert.equal(down.status, 503);
  const bad = await handle(new Request('https://x', { method: 'POST', body: 'bozuk' }), env, create);
  assert.equal(bad.status, 400);
});

test('ekip bildirimi: talep no, uygulama, konu, panel bağlantısı; e-posta, ad ve mesaj yok', async () => {
  const m = teamNotice('D-ABC234', clean(good), 'https://panel.example.com/');
  assert.equal(m.subject, 'Yeni destek talebi D-ABC234 · Moyo · Hata');
  assert.ok(m.text.includes('Panelde aç: https://panel.example.com/#/destek'));
  for (const part of [m.subject, m.text, m.html]) {
    assert.ok(!part.includes('veli@example.com') && !part.includes('Ayşe') && !part.includes('açılmıyor'));
  }
  assert.ok(teamNotice('D-X', { app: 'clinic', topic: 'privacy' }, '').text.endsWith('Yönetim paneli › Destek'));
  assert.ok(!teamNotice('D-X', { app: 'zz', topic: 'zz' }, 'javascript:alert(1)').html.includes('javascript'));
  // bildirim çağrılır; hata ya da gecikme talebi düşürmez
  let sent = '';
  const ok = await handle(post(good), env, async () => ({ ref: 'D-ABC234' }), async (ref) => { sent = ref; });
  assert.equal(ok.status, 200); assert.equal(sent, 'D-ABC234');
  const fail = await handle(post(good), env, async () => ({ ref: 'D-ABC235' }), async () => { throw new Error('resend 500'); });
  assert.deepEqual(await fail.json(), { ok: true, ref: 'D-ABC235' });
  let called = false;
  await handle(post({ ...good, website: 'x' }), env, async () => ({ ref: 'D-Z' }), async () => { called = true; });
  assert.equal(called, false);
});

test('kaynak: anahtar eşleşince Worker\'ın ilettiği adres; eşleşmezse işlevin gördüğü adres; anahtar yoksa kaynak yok', async () => {
  const { sourceOf, same } = await import('./index.ts');
  const KEY = 'f'.repeat(32);
  const withKey = (k: string) => (k === 'SUPPORT_FORWARD_KEY' ? KEY : '');
  const req = (h: Record<string, string>) => new Request('https://x', { method: 'POST', headers: h });
  const own = { 'x-forwarded-for': '198.51.100.1, 10.0.0.1' };
  assert.equal(sourceOf(req({ ...own, 'x-moyo-client-ip': '203.0.113.5', 'x-moyo-forward-key': KEY }), withKey), '203.0.113.5');
  assert.equal(sourceOf(req({ ...own, 'x-moyo-client-ip': '203.0.113.5', 'x-moyo-forward-key': KEY + 'x' }), withKey), '198.51.100.1');
  assert.equal(sourceOf(req({ ...own, 'x-moyo-client-ip': '203.0.113.5' }), withKey), '198.51.100.1');
  assert.equal(sourceOf(req({ ...own, 'x-moyo-client-ip': 'evil<script>', 'x-moyo-forward-key': KEY }), withKey), '198.51.100.1');
  assert.equal(sourceOf(req({}), withKey), 'unknown');
  assert.equal(sourceOf(req({ ...own, 'x-moyo-client-ip': '203.0.113.5', 'x-moyo-forward-key': KEY }), () => ''), null);
  // `cf-worker` başlığı (her Cloudflare Worker'ının alt isteğinde; saldırganın kendi Worker'ı da ekler) kaynaksız yol açmaz:
  // anahtarsız ya da yanlış anahtarla gelen istek, her doğrudan çağıran gibi işlevin gördüğü kendi adresiyle sayılır;
  // anahtar eşleşince yine iletilen adres
  const wk = { 'cf-worker': 'moyoapp.com.tr', 'cf-connecting-ip': '104.16.0.1' };
  assert.equal(sourceOf(req({ ...wk, 'x-moyo-client-ip': '203.0.113.5' }), withKey), '104.16.0.1');
  assert.equal(sourceOf(req({ ...wk }), withKey), '104.16.0.1');
  assert.equal(sourceOf(req({ ...wk, 'x-moyo-client-ip': '203.0.113.5', 'x-moyo-forward-key': 'yanlis'.repeat(4) }), withKey), '104.16.0.1');
  assert.equal(sourceOf(req({ 'cf-worker': 'attacker.workers.dev', 'cf-connecting-ip': '198.51.100.1' }), withKey), '198.51.100.1');
  assert.equal(sourceOf(req({ 'cf-worker': 'x', 'x-moyo-forward-key': 'bad', 'x-moyo-client-ip': '1.1.1.1', 'cf-connecting-ip': '198.51.100.1' }), withKey), '198.51.100.1');
  assert.equal(sourceOf(req({ 'cf-worker': 'x' }), withKey), 'unknown');
  assert.notEqual(sourceOf(req({ 'cf-worker': 'attacker.workers.dev' }), withKey), null);
  assert.equal(sourceOf(req({ ...wk, 'x-moyo-client-ip': '203.0.113.5', 'x-moyo-forward-key': KEY }), withKey), '203.0.113.5');
  // kısa anahtar (16'dan kısa) hiçbir zaman eşleşmez: Worker'dan gelen istek kendi adresiyle sayılır (kaynaksız yola düşmez)
  const shortKey = (k: string) => (k === 'SUPPORT_FORWARD_KEY' ? 'short' : '');
  assert.equal(sourceOf(req({ ...wk, 'x-moyo-forward-key': 'short', 'x-moyo-client-ip': '1.2.3.4' }), shortKey), '104.16.0.1');
  // adres gerçek ayrıştırıcıyla: eşlenmiş IPv6 → IPv4, IPv6 küçük harf kısa biçim, geçersiz değer düşer
  assert.equal(sourceOf(req({ 'x-moyo-client-ip': '::ffff:203.0.113.5', 'x-moyo-forward-key': KEY }), withKey), '203.0.113.5');
  assert.equal(sourceOf(req({ 'cf-connecting-ip': '::FFFF:198.51.100.2' }), withKey), '198.51.100.2');
  assert.equal(sourceOf(req({ 'x-moyo-client-ip': '2001:DB8:0:0::1', 'x-moyo-forward-key': KEY }), withKey), '2001:db8::1');
  assert.equal(sourceOf(req({ ...own, 'x-moyo-client-ip': '999.1.1.1', 'x-moyo-forward-key': KEY }), withKey), '198.51.100.1');
  assert.equal(sourceOf(req({ 'x-forwarded-for': '1.2.3' }), withKey), 'unknown');
  const { normIp } = await import('./index.ts');
  assert.equal(normIp('01.2.3.4'), null); assert.equal(normIp('::1'), '::1'); assert.equal(normIp('1:2:3'), null);
  assert.equal(normIp('fe80::1%eth0'), null); assert.equal(normIp('0.0.0.0'), '0.0.0.0');
  assert.equal(same('abc', 'abc'), true); assert.equal(same('abc', 'abd'), false); assert.equal(same('abc', 'abcd'), false);
  // handle kaynağı create'e iletir; kaynak sınırı Türkçe 429
  let got: string | null = 'yok';
  await handle(new Request('https://x', { method: 'POST', body: JSON.stringify(good), headers: { 'x-moyo-client-ip': '203.0.113.9', 'x-moyo-forward-key': KEY } }),
    withKey, async (_x, s) => { got = s; return { ref: 'D-A' }; });
  assert.equal(got, '203.0.113.9');
  const lim = await handle(post(good), env, async () => ({ error: 'too_many_source' }));
  assert.equal(lim.status, 429); assert.match((await lim.json()).error, /bağlantıdan/);
  // sınır iletileri e-posta yolunu önerir; tire yok
  for (const k of ['busy', 'too_many', 'too_many_source']) {
    const r = await handle(post(good), env, async () => ({ error: k }));
    const t = (await r.json()).error as string;
    assert.ok(t.endsWith('ya da destek@moyoapp.com.tr adresine yazın.'), t); assert.ok(!/[–—]| - /.test(t), t);
  }
});

test('gövde sınırı: Content-Length olmadan da 20 000 karakterde kesilir', async () => {
  const { readLimited } = await import('./index.ts');
  const big = JSON.stringify({ ...good, message: 'x'.repeat(30000) });
  const stream = () => new ReadableStream({ start(c) { const e = new TextEncoder().encode(big); for (let i = 0; i < e.length; i += 1000) c.enqueue(e.slice(i, i + 1000)); c.close(); } });
  const r = new Request('https://x', { method: 'POST', body: stream(), duplex: 'half' } as RequestInit);
  assert.equal(r.headers.get('content-length'), null);
  assert.equal(await readLimited(r), null);
  const r2 = new Request('https://x', { method: 'POST', body: stream(), duplex: 'half' } as RequestInit);
  assert.equal((await handle(r2, env, async () => ({ ref: 'D-A' }))).status, 413);
  assert.equal(await readLimited(new Request('https://x', { method: 'POST', body: 'kısa' })), 'kısa');
});

// =====================================================================================================================
// Destek kutusu: /support/inbound ve /support/reply (migrations/20261122100000_support_inbox.sql)
// =====================================================================================================================
const KEY = 'k'.repeat(32);
const ienv = (extra: Record<string, string> = {}) => (k: string) =>
  ({ SUPPORT_FORWARD_KEY: KEY, SUPPORT_NOTIFY_TO: 'sahip@example.org', ADMIN_PANEL_URL: 'https://panel.example.com/', ...extra } as Record<string, string>)[k] ?? '';
const mail = { from: 'Veli@Example.com', fromName: 'Ayşe Örnek', subject: 'Aboneliği iptal etmek istiyorum', text: 'Merhaba,\nNasıl iptal ederim?',
               messageId: '<m1@mail.example.com>', refs: '', attachments: [{ name: 'kimlik.jpg', size: 1200, type: 'image/jpeg', content: 'QUJD' }],
               auto: false, auth: 'pass' };
const inReq = (b: unknown, h: Record<string, string> = { 'x-moyo-forward-key': KEY }) =>
  new Request('https://x.supabase.co/functions/v1/support/inbound', { method: 'POST', body: typeof b === 'string' ? b : JSON.stringify(b), headers: h });

function fakeDeps(over: Record<string, unknown> = {}) {
  const log = { sent: [] as unknown[][], mails: [] as any[], notices: [] as any[], inbound: [] as any[], reply: [] as any[] };
  const deps: any = {
    create: async () => ({ ref: 'D-FORM23' }),
    inbound: async (x: any) => { log.inbound.push(x); return { ok: true, ref: 'D-ABC234', request_id: 'r1', new: true, reopened: false, ack: true,
                                                                ack_message_id: 'a1', ack_body: 'Merhaba,\n\nAlındı D-ABC234.\n\nMoyo Destek', notify: true }; },
    reply: async (jwt: string, apikey: string, x: any) => { log.reply.push({ jwt, apikey, x });
      return { data: { message_id: 'o1', to: 'veli@example.com', subject: 'Re: Abonelik [D-ABC234]', ref: 'D-ABC234', body: x.body, name: 'Ayşe Örnek' }, error: null }; },
    sent: async (...a: unknown[]) => { log.sent.push(a); },
    sendMail: async (m: any, idem: string) => { log.mails.push({ ...m, idem }); },
    sendNotice: async (to: string, m: any) => { log.notices.push({ to, ...m }); },
    mailReady: () => true,
    ...over,
  };
  return { deps, log };
}

test('yol: /support form, /support/inbound, /support/reply; başka alt yol 404', async () => {
  const { routeOf, serve } = await import('./index.ts');
  assert.equal(routeOf('https://x/functions/v1/support'), 'form');
  assert.equal(routeOf('https://x/support/'), 'form');
  assert.equal(routeOf('https://x'), 'form');
  assert.equal(routeOf('https://x/support/inbound'), 'inbound');
  assert.equal(routeOf('https://x/functions/v1/support/reply/?a=1'), 'reply');
  assert.equal(routeOf('https://x/support/baska'), null);
  assert.equal(routeOf('bozuk adres'), null);
  const { deps } = fakeDeps();
  assert.equal((await serve(new Request('https://x/support/baska', { method: 'POST' }), ienv(), deps)).status, 404);
  assert.equal((await serve(new Request('https://x/functions/v1/support'), env, deps)).status, 302);
  assert.equal((await serve(inReq(mail, {}), ienv(), deps)).status, 401);
  const form = await serve(post(good), env, deps);
  assert.deepEqual(await form.json(), { ok: true, ref: 'D-FORM23' });
});

test('ekip uyarısı adresi: yalnız tanımlı, tek ve bizim alan adımızda olmayan adres (döngü yok, eski varsayılan yok)', async () => {
  const { notifyTarget, isOwnDomain } = await import('./index.ts');
  const e = (v: string) => (k: string) => (k === 'SUPPORT_NOTIFY_TO' ? v : '');
  assert.equal(notifyTarget(() => ''), null);
  assert.equal(notifyTarget(e(' Sahip@Example.org ')), 'sahip@example.org');
  for (const v of ['destek@moyoapp.com.tr', 'DESTEK@MOYOAPP.COM.TR', 'a@posta.moyoapp.com.tr', 'a@moyoapp.com.tr.', 'a@x.com,b@y.com', 'Ad <a@x.com>', 'yok'])
    assert.equal(notifyTarget(e(v)), null, v);
  assert.equal(isOwnDomain('x@moyoapp.com.tr'), true); assert.equal(isOwnDomain('x@notmoyoapp.com.tr'), false);
  assert.equal(isOwnDomain('x@moyoapp.com.tr.evil.com'), false);
  const mod = await import('./index.ts');
  assert.equal((mod as Record<string, unknown>).NOTIFY_TO, undefined);
});

test('gelen ileti temizliği: adres, ekler yalnız ad/boyut/tür, NUL ve eşsiz vekil karakter, sınırlar', async () => {
  const { cleanInbound } = await import('./index.ts');
  const x = cleanInbound({ ...mail, from: 'Ayşe <Veli@Example.com>', subject: 'Satır\r\nsonu', text: 'a\u0000b\uD800c' + 'x'.repeat(30000),
                           attachments: [...Array(25)].map((_, i) => ({ name: `d${i}.pdf`, size: i === 0 ? -1 : 10, type: 'APPLICATION/PDF', content: 'X' })),
                           auth: 'weird', auto: 'true' })!;
  assert.equal(x.from, 'veli@example.com');
  assert.equal(x.subject, 'Satır sonu');
  assert.ok(x.text.startsWith('ab�c') && x.text.length === 20000);
  assert.equal(x.attachments.length, 20);
  assert.deepEqual(x.attachments[0], { name: 'd0.pdf', size: null, type: 'application/pdf' });
  assert.ok(!JSON.stringify(x.attachments).includes('content'));
  assert.equal(x.auth, 'none'); assert.equal(x.auto, false);
  assert.equal(cleanInbound({ ...mail, auth: 'fail', auto: true })!.auth, 'fail');
  for (const bad of [null, [], 'metin', { ...mail, from: 'adres-degil' }, { ...mail, from: '' }, { ...mail, from: 'a@b@c.com' }])
    assert.equal(cleanInbound(bad), null);
});

test('gövde sınırı (bayt): /support/inbound 256 KB, Content-Length olmadan da', async () => {
  const { readBytes, handleInbound, INBOUND_MAX_BYTES } = await import('./index.ts');
  const big = JSON.stringify({ ...mail, text: 'ğ'.repeat(140000) });   // 140 000 karakter ama ~280 KB
  assert.ok(big.length < INBOUND_MAX_BYTES && new TextEncoder().encode(big).length > INBOUND_MAX_BYTES);
  const stream = () => new ReadableStream({ start(c) { const e = new TextEncoder().encode(big); for (let i = 0; i < e.length; i += 4096) c.enqueue(e.slice(i, i + 4096)); c.close(); } });
  assert.equal(await readBytes(new Request('https://x', { method: 'POST', body: stream(), duplex: 'half' } as RequestInit), INBOUND_MAX_BYTES), null);
  const { deps, log } = fakeDeps();
  const r = await handleInbound(new Request('https://x/support/inbound', { method: 'POST', body: stream(), duplex: 'half', headers: { 'x-moyo-forward-key': KEY } } as RequestInit), ienv(), deps);
  assert.equal(r.status, 413); assert.equal(log.inbound.length, 0);
  assert.equal(await readBytes(new Request('https://x', { method: 'POST', body: 'çok kısa' }), 100), 'çok kısa');
  assert.equal(await readBytes(new Request('https://x', { method: 'POST', body: 'x', headers: { 'content-length': '999' } }), 100), null);
});

test('/support/inbound: anahtar, geçersiz gövde, sunucu hatası, sınır, yinelenen teslim', async () => {
  const { handleInbound } = await import('./index.ts');
  const { deps, log } = fakeDeps();
  assert.equal((await handleInbound(inReq(mail, {}), ienv(), deps)).status, 401);
  assert.equal((await handleInbound(inReq(mail, { 'x-moyo-forward-key': KEY + 'x' }), ienv(), deps)).status, 401);
  assert.equal((await handleInbound(inReq(mail), () => '', deps)).status, 401, 'anahtar tanımlı değilse kapalı');
  const short = (k: string) => (k === 'SUPPORT_FORWARD_KEY' ? 'kisa' : '');
  assert.equal((await handleInbound(inReq(mail, { 'x-moyo-forward-key': 'kisa' }), short, deps)).status, 401, 'kısa anahtar eşleşmez');
  assert.equal((await handleInbound(new Request('https://x/support/inbound', { headers: { 'x-moyo-forward-key': KEY } }), ienv(), deps)).status, 405);
  const bad = await handleInbound(inReq('bozuk'), ienv(), deps);
  assert.equal(bad.status, 400); assert.deepEqual(await bad.json(), { ok: false, error: 'invalid' });
  assert.equal((await handleInbound(inReq({ ...mail, from: 'yok' }), ienv(), deps)).status, 400);
  assert.equal(log.inbound.length, 0);
  for (const inbound of [async () => null, async () => { throw new Error('db şifre=gizli'); }, async () => ({ ok: false, error: 'garip' })]) {
    const r = await handleInbound(inReq(mail), ienv(), { ...deps, inbound });
    assert.equal(r.status, 503); const t = await r.text();
    assert.equal(t, '{"ok":false,"error":"server"}', 'ham hata dönmez');
  }
  const dropped = await handleInbound(inReq(mail), ienv(), { ...deps, inbound: async () => ({ ok: false, error: 'dropped' }) });
  assert.equal(dropped.status, 200, 'sınır: Worker başka yere iletmesin'); assert.deepEqual(await dropped.json(), { ok: false, error: 'dropped' });
  const dup = fakeDeps({ inbound: async () => ({ ok: true, duplicate: true, ref: 'D-ABC234', ack: false, notify: false }) });
  const d = await handleInbound(inReq(mail), ienv(), dup.deps);
  assert.deepEqual(await d.json(), { ok: true, ref: 'D-ABC234' });
  assert.equal(dup.log.mails.length + dup.log.notices.length + dup.log.sent.length, 0, 'yinelenen teslimde e-posta yok');
});

test('/support/inbound: yeni talep → otomatik yanıt (başlıklar) + içeriksiz ekip uyarısı; RPC\'ye temiz alanlar', async () => {
  const { handleInbound } = await import('./index.ts');
  const { deps, log } = fakeDeps();
  const r = await handleInbound(inReq(mail), ienv(), deps);
  assert.equal(r.status, 200); assert.deepEqual(await r.json(), { ok: true, ref: 'D-ABC234' });
  assert.equal(log.inbound[0].from, 'veli@example.com');
  assert.deepEqual(log.inbound[0].attachments, [{ name: 'kimlik.jpg', size: 1200, type: 'image/jpeg' }]);
  assert.equal(log.mails.length, 1);
  const m = log.mails[0];
  assert.equal(m.to, 'veli@example.com'); assert.equal(m.from, 'Moyo Destek <destek@moyoapp.com.tr>'); assert.equal(m.idem, 'support-a1');
  assert.equal(m.subject, 'Re: Aboneliği iptal etmek istiyorum [D-ABC234]');
  assert.equal(m.text, 'Merhaba,\n\nAlındı D-ABC234.\n\nMoyo Destek', 'saklanan metin gönderilir');
  assert.deepEqual(m.headers, { 'Auto-Submitted': 'auto-replied', 'X-Auto-Response-Suppress': 'All',
                                'In-Reply-To': '<m1@mail.example.com>', References: '<m1@mail.example.com>' });
  assert.deepEqual(log.sent, [['a1', true, null]]);
  assert.equal(log.notices.length, 1);
  const n = log.notices[0];
  assert.equal(n.to, 'sahip@example.org'); assert.equal(n.subject, 'Yeni destek talebi D-ABC234');
  assert.ok(n.text.includes('https://panel.example.com/#/destek'));
  for (const part of [n.subject, n.text, n.html]) for (const s of ['veli@', 'Ayşe', 'iptal', 'kimlik']) assert.ok(!part.includes(s), s);
});

test('/support/inbound: gönderilemeyen yanıt kayda kısa kodla; ayar yoksa not_configured; uyarı döngüsü yok; yeniden açılma', async () => {
  const { handleInbound } = await import('./index.ts');
  const fail = fakeDeps({ sendMail: async () => { throw new Error('resend 422'); } });
  assert.equal((await handleInbound(inReq(mail), ienv(), fail.deps)).status, 200, 'gönderilemese de ileti alınmıştır');
  assert.deepEqual(fail.log.sent, [['a1', false, 'resend_422']]);
  const off = fakeDeps({ mailReady: () => false });
  await handleInbound(inReq(mail), ienv(), off.deps);
  assert.deepEqual(off.log.sent, [['a1', false, 'not_configured']]); assert.equal(off.log.mails.length, 0);
  const own = fakeDeps();
  await handleInbound(inReq(mail), ienv({ SUPPORT_NOTIFY_TO: 'destek@moyoapp.com.tr' }), own.deps);
  assert.equal(own.log.notices.length, 0, 'destek@ adresine uyarı gitmez (yeni talep açardı)');
  const none = fakeDeps();
  await handleInbound(inReq(mail), ienv({ SUPPORT_NOTIFY_TO: '' }), none.deps);
  assert.equal(none.log.notices.length, 0, 'adres tanımlı değilse uyarı yok');
  const re = fakeDeps({ inbound: async () => ({ ok: true, ref: 'D-ABC234', new: false, reopened: true, ack: false, ack_message_id: null, notify: true }) });
  await handleInbound(inReq(mail), ienv(), re.deps);
  assert.equal(re.log.mails.length, 0); assert.equal(re.log.notices[0].subject, 'Destek talebine yeni ileti D-ABC234');
  const quiet = fakeDeps({ inbound: async () => ({ ok: true, ref: 'D-ABC234', new: false, reopened: false, ack: false, notify: false }) });
  await handleInbound(inReq(mail), ienv(), quiet.deps);
  assert.equal(quiet.log.notices.length + quiet.log.mails.length, 0);
  // bizim alan adımızdan ya da otomatik iletiye yanıt gitmez (SQL zaten ack vermez; işlev de göndermez)
  const loop = fakeDeps();
  await handleInbound(inReq({ ...mail, from: 'ekip@moyoapp.com.tr' }), ienv(), loop.deps);
  await handleInbound(inReq({ ...mail, auto: true }), ienv(), loop.deps);
  assert.equal(loop.log.mails.length, 0); assert.deepEqual(loop.log.sent, [['a1', false, 'skipped'], ['a1', false, 'skipped']]);
});

test('yanıt konusu: önekler ve numaralar atılır, numara bir kez (SQL support_reply_subject ile aynı örnekler)', async () => {
  const { replySubject } = await import('./index.ts');
  assert.equal(replySubject('RE: Fwd: AW: İlt: Fatura [D-ABC234]  [d-xyz789]', 'D-ABC234'), 'Re: Fatura [D-ABC234]');
  assert.equal(replySubject('Re:', 'D-ABC234'), 'Re: Destek talebiniz [D-ABC234]');
  assert.equal(replySubject(null, 'D-ABC234'), 'Re: Destek talebiniz [D-ABC234]');
  assert.equal(replySubject('Ynt: YANIT: Sv: Hesabım', 'D-ABC234'), 'Re: Hesabım [D-ABC234]');
  assert.equal(replySubject('Satır\r\nsonu', 'D-ABC234'), 'Re: Satır sonu [D-ABC234]');
  assert.ok([...replySubject('ç'.repeat(300), 'D-ABC234')].length <= 200);
  assert.equal((replySubject('Re: x [D-ABC234] [D-ABC234]', 'D-ABC234').match(/\[D-/g) ?? []).length, 1);
});

test('posta kurucuları: Kimden, Message-ID başlığı, HTML kaçışı, panel yanıtı', async () => {
  const { ackMail, ackBody, replyMail, fromAddress, messageIdHeader, textToHtml } = await import('./index.ts');
  assert.equal(fromAddress(() => ''), 'Moyo Destek <destek@moyoapp.com.tr>');
  assert.equal(fromAddress((k) => (k === 'SUPPORT_FROM' ? 'Moyo Yardım <yardim@moyoapp.com.tr>' : '')), 'Moyo Yardım <yardim@moyoapp.com.tr>');
  assert.equal(fromAddress((k) => (k === 'SUPPORT_FROM' ? 'kotu\r\nBcc: x@y.com <a@b.com>' : '')), 'Moyo Destek <destek@moyoapp.com.tr>');
  assert.equal(messageIdHeader('m1@x'), '<m1@x>'); assert.equal(messageIdHeader('<m1@x>'), '<m1@x>');
  assert.equal(messageIdHeader('a b@x'), null); assert.equal(messageIdHeader('a\r\nBcc: z@x'), null); assert.equal(messageIdHeader(''), null);
  const a = ackMail({ ref: 'D-ABC234', subject: '', body: null, messageId: 'bozuk id', to: 'v@example.com' }, () => '');
  assert.equal(a.text, ackBody('D-ABC234')); assert.ok(a.text.includes('D-ABC234') && a.text.endsWith('Moyo Destek'));
  assert.deepEqual(a.headers, { 'Auto-Submitted': 'auto-replied', 'X-Auto-Response-Suppress': 'All' });
  assert.equal(a.subject, 'Re: Destek talebiniz [D-ABC234]');
  assert.ok(!/[–—]/.test(ackBody('D-X')), 'tire yok');
  assert.equal(textToHtml('<script>a</script>\n\nb & c'), '<div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.5;color:#0f1b3d"><p>&lt;script&gt;a&lt;/script&gt;</p><p>b &amp; c</p></div>');
  const r = replyMail({ message_id: 'o1', to: 'veli@example.com', subject: 'Re: Abonelik [D-ABC234]', ref: 'D-ABC234', body: 'Merhaba <b>', name: 'Ayşe "x" <Örnek>' }, () => '');
  assert.equal(r.to, '"Ayşe x Örnek" <veli@example.com>'); assert.equal(r.replyTo, 'destek@moyoapp.com.tr');
  assert.equal(r.subject, 'Re: Abonelik [D-ABC234]'); assert.equal(r.headers, undefined, 'In-Reply-To yok');
  assert.ok(r.text.startsWith('Merhaba <b>\n\nTalep numaranız D-ABC234.')); assert.ok(r.html.includes('Merhaba &lt;b&gt;'));
  assert.equal(replyMail({ message_id: 'o1', to: 'v@example.com', subject: '', ref: 'D-ABC234', body: 'x', name: null }, () => '').to, 'v@example.com');
});

test('/support/reply: CORS yalnız panel, oturum, gövde, yetki, gönderim sonucu; ham hata yok', async () => {
  const { handleReply, replyCors, panelOrigins, errCode } = await import('./index.ts');
  const renv = ienv({ SUPABASE_ANON_KEY: 'sb_publishable_test' });
  const panel = 'https://panel.example.com';
  assert.deepEqual(panelOrigins(renv), ['https://admin-panel.amy60946.workers.dev', panel]);
  assert.deepEqual(panelOrigins(ienv({ ADMIN_PANEL_URL: 'http://panel.example.com' })), ['https://admin-panel.amy60946.workers.dev']);
  assert.equal(replyCors('https://evil.example', renv), null);
  assert.equal(replyCors(null, renv)!['Access-Control-Allow-Origin'], undefined);
  const rq = (b: unknown, h: Record<string, string> = {}, method = 'POST') =>
    new Request('https://x/functions/v1/support/reply', { method, ...(method === 'POST' ? { body: JSON.stringify(b) } : {}),
      headers: { origin: panel, authorization: 'Bearer jwt-admin', apikey: 'sb_publishable_header', ...h } });
  const ok = { request_id: '11111111-2222-4333-8444-555555555555', body: '  Merhaba, App Store › Abonelikler.  ', close: false };
  const { deps, log } = fakeDeps();
  const pre = await handleReply(rq(null, {}, 'OPTIONS'), renv, deps);
  assert.equal(pre.status, 204); assert.equal(pre.headers.get('access-control-allow-origin'), panel);
  const wd = await handleReply(rq(null, { origin: 'https://admin-panel.amy60946.workers.dev' }, 'OPTIONS'), renv, deps);
  assert.equal(wd.headers.get('access-control-allow-origin'), 'https://admin-panel.amy60946.workers.dev');
  const evil = await handleReply(rq(ok, { origin: 'https://evil.example' }), renv, deps);
  assert.equal(evil.status, 403); assert.equal(evil.headers.get('access-control-allow-origin'), null); assert.equal(log.reply.length, 0);
  for (const h of [{ authorization: '' }, { authorization: 'jwt-admin' }]) {
    const r = await handleReply(rq(ok, h), renv, deps);
    assert.equal(r.status, 401); assert.deepEqual(await r.json(), { ok: false, error: 'forbidden' });
  }
  for (const b of [{ ...ok, request_id: 'x' }, { ...ok, body: '   ' }, { ...ok, body: 'x'.repeat(20001) }, { ...ok, body: 5 }, null]) {
    const r = await handleReply(rq(b), renv, deps);
    assert.equal(r.status, 400); assert.deepEqual(await r.json(), { ok: false, error: 'invalid' });
  }
  assert.equal(log.reply.length, 0);
  const good2 = await handleReply(rq(ok), renv, deps);
  assert.equal(good2.status, 200); assert.deepEqual(await good2.json(), { ok: true, status: 'answered' });
  assert.equal(good2.headers.get('access-control-allow-origin'), panel);
  assert.deepEqual(log.reply[0], { jwt: 'jwt-admin', apikey: 'sb_publishable_test', x: { ...ok, body: 'Merhaba, App Store › Abonelikler.' } });
  assert.equal(log.mails[0].to, '"Ayşe Örnek" <veli@example.com>'); assert.equal(log.mails[0].idem, 'support-o1');
  assert.deepEqual(log.sent, [['o1', true, null]]);
  const closed = await handleReply(rq({ ...ok, close: true }), ienv(), deps);
  assert.deepEqual(await closed.json(), { ok: true, status: 'closed' });
  assert.equal(log.reply[1].apikey, 'sb_publishable_header', 'ortamda anahtar yoksa isteğin apikey başlığı');
  for (const [code, status, error] of [['42501', 403, 'forbidden'], ['PGRST301', 403, 'forbidden'], ['P0001', 400, 'invalid'], ['42883', 400, 'invalid']] as const) {
    const x = fakeDeps({ reply: async () => ({ data: null, error: { code, message: 'İstenmeyen olarak işaretli talebe yanıt gönderilmez' } }) });
    const r = await handleReply(rq(ok), renv, x.deps);
    assert.equal(r.status, status, code); assert.deepEqual(await r.json(), { ok: false, error }); assert.equal(x.log.mails.length, 0);
  }
  const down = fakeDeps({ reply: async () => { throw new Error('ağ'); } });
  const dr = await handleReply(rq(ok), renv, down.deps);
  assert.equal(dr.status, 503); assert.deepEqual(await dr.json(), { ok: false, error: 'send_failed' });
  const sf = fakeDeps({ sendMail: async () => { throw new Error('resend 500'); } });
  const s = await handleReply(rq(ok), renv, sf.deps);
  assert.equal(s.status, 502); assert.deepEqual(await s.json(), { ok: false, error: 'send_failed', status: 'in_progress' });
  assert.deepEqual(sf.log.sent, [['o1', false, 'resend_500']]);
  const nc = fakeDeps({ mailReady: () => false });
  assert.equal((await handleReply(rq(ok), renv, nc.deps)).status, 502); assert.deepEqual(nc.log.sent, [['o1', false, 'not_configured']]);
  const lost = fakeDeps({ sent: async () => { throw new Error('db'); } });
  assert.equal((await handleReply(rq(ok), renv, lost.deps)).status, 200, 'sonuç yazılamasa da gönderilen yanıt başarılı');
  assert.equal(errCode(Object.assign(new Error('x'), { name: 'TimeoutError' })), 'timeout');
  assert.equal(errCode(new Error('resend 429')), 'resend_429'); assert.equal(errCode(Object.assign(new Error('a'), { code: 'EAUTH' })), 'EAUTH');
  assert.equal(errCode(new Error('veli@example.com bulunamadı')), 'error');
});
