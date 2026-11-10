// node --experimental-strip-types --test supabase/functions/support/*.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { clean, handle, precheck, supportPage } from './index.ts';

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
