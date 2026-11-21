// node --experimental-strip-types --test supabase/functions/clinic-billing/*.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { appleHosts, environmentOk, preRoute, same, PROD_HOST, SANDBOX_HOST } from './index.ts';

const envOf = (o: Record<string, string>) => (k: string) => o[k] ?? '';
const post = (h: Record<string, string> = {}) => new Request('https://x/functions/v1/clinic-billing/r', { method: 'POST', headers: h });

test('kapatma anahtarı: CLINIC_BILLING_ENABLED tam "1" değilse her yol 410', () => {
  for (const v of ['', '0', 'true', '1 ', 'yes']) {
    for (const r of ['apple-verify', 'apple-notify', 'iyzico-webhook', 'iyzico-start', undefined]) {
      assert.equal(preRoute(envOf({ CLINIC_BILLING_ENABLED: v }), post(), r)?.status, 410, `${v}:${r}`);
    }
  }
  assert.equal(preRoute(envOf({ CLINIC_BILLING_ENABLED: '1' }), post(), 'apple-verify'), null);
});

test('açıkken: imzası doğrulanmayan Apple bildirimi 501; imzasız iyzico bildirimi 401', () => {
  const on = envOf({ CLINIC_BILLING_ENABLED: '1' });
  assert.equal(preRoute(on, post(), 'apple-notify')?.status, 501);
  assert.equal(preRoute(on, post(), 'iyzico-webhook')?.status, 401);
  assert.equal(preRoute(on, post({ 'x-iyz-signature-v3': 'ab' }), 'iyzico-webhook'), null);
});

test('sandbox yalnız BILLING_ALLOW_SANDBOX=1 ile', () => {
  assert.deepEqual(appleHosts(envOf({})), [PROD_HOST]);
  assert.deepEqual(appleHosts(envOf({ BILLING_ALLOW_SANDBOX: '1' })), [PROD_HOST, SANDBOX_HOST]);
  assert.equal(environmentOk(envOf({}), 'Production'), true);
  assert.equal(environmentOk(envOf({}), 'Sandbox'), false);
  assert.equal(environmentOk(envOf({}), undefined), false);
  assert.equal(environmentOk(envOf({ BILLING_ALLOW_SANDBOX: '1' }), 'Sandbox'), true);
  assert.equal(same('ab', 'ab') && !same('ab', 'ac') && !same('ab', 'abc'), true);
});
