// node --experimental-strip-types --test supabase/functions/health/*.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { authorized, handle, summarize, type Health } from './index.ts';

const KEY = 'k'.repeat(30);
const env = (k: string) => (k === 'HEALTH_KEY' ? KEY : '');
const ok: Health = { status: 'ok', checks: [{ key: 'cron', level: 'ok', detail: '2 iş' }, { key: 'kvkk', level: 'info', detail: '1 açık' }] };
const bad: Health = { status: 'fail', checks: [{ key: 'kvkk', level: 'fail', detail: '1 başvurunun süresi geçti' }, { key: 'push', level: 'warn' }] };

test('anahtar: kısa, yanlış ya da boş reddedilir', () => {
  assert.equal(authorized('', ''), false);
  assert.equal(authorized('kisa', 'kisa'), false);
  assert.equal(authorized(KEY, KEY + 'x'), false);
  assert.equal(authorized(KEY, KEY), true);
});

test('özet: en kötü düzey; fail → 503; ayrıntı (sayı, metin) dışarı çıkmaz', () => {
  const a = summarize(ok);
  assert.equal(a.http, 200); assert.equal(a.body.status, 'info');
  assert.deepEqual(a.body.checks, [{ key: 'cron', level: 'ok' }, { key: 'kvkk', level: 'info' }]);
  const b = summarize(bad);
  assert.equal(b.http, 503); assert.equal(b.body.status, 'fail');
  assert.ok(!JSON.stringify(b.body).includes('süresi'));
  assert.equal(summarize(null).http, 503);
  assert.equal(summarize({ status: 'ok', checks: [{ key: 'x', level: 'bilinmez' as any }] }).body.checks.length, 0);
});

test('istek: anahtarsız yalnız durum; doğru anahtarla denetim listesi; yanlış anahtar 401; hata 503', async () => {
  const r0 = await handle(new Request('https://x/functions/v1/health'), env, async () => ok);
  assert.equal(r0.status, 200); assert.deepEqual(await r0.json(), { status: 'info' });
  const r1 = await handle(new Request('https://x/functions/v1/health', { headers: { 'x-health-key': KEY } }), env, async () => ok);
  assert.equal(r1.status, 200); assert.equal((await r1.json()).checks.length, 2);
  const r2 = await handle(new Request('https://x/functions/v1/health', { headers: { 'x-health-key': 'yanlis' } }), env, async () => ok);
  assert.equal(r2.status, 401);
  const r3 = await handle(new Request('https://x/functions/v1/health'), env, async () => bad);
  assert.equal(r3.status, 503); assert.deepEqual(await r3.json(), { status: 'fail' });
  const r4 = await handle(new Request('https://x/functions/v1/health'), env, async () => { throw new Error('db'); });
  assert.equal(r4.status, 503);
  const r5 = await handle(new Request('https://x/functions/v1/health', { method: 'POST' }), env, async () => ok);
  assert.equal(r5.status, 405);
  const r6 = await handle(new Request('https://x/functions/v1/health?key=' + KEY), env, async () => ok);
  assert.ok(!('checks' in (await r6.json())), 'anahtar adreste kabul edilmez (yalnız başlık)');
});
