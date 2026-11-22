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
