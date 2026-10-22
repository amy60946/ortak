// node --experimental-strip-types --test supabase/functions/billing-webhook/state.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { affectedUsers, fromEvent, fromSubscriber } from './state.ts';

const NOW = Date.parse('2026-11-01T00:00:00Z');
const one = (product: string, s: Record<string, unknown>) => ({ subscriber: { subscriptions: { [product]: s } } });

test('etkin aylık abonelik', () => {
  const r = fromSubscriber(one('parentapp.premium.monthly', { expires_date: '2026-11-20T00:00:00Z', store_transaction_id: 't1' }), NOW, false);
  assert.deepEqual(r, { billing: 'monthly', productId: 'parentapp.premium.monthly', transactionId: 't1',
    plan: 'premium', status: 'active', periodEnd: '2026-11-20T00:00:00Z', autoRenew: true });
});

test('yenileme kapalı: dönem sonuna kadar premium', () => {
  const r = fromSubscriber(one('parentapp.premium.yearly', { expires_date: '2027-01-01T00:00:00Z', unsubscribe_detected_at: '2026-10-30T00:00:00Z' }), NOW, false);
  assert.equal(r?.plan, 'premium');
  assert.equal(r?.status, 'canceled');
  assert.equal(r?.billing, 'yearly');
  assert.equal(r?.autoRenew, false);
});

test('ödeme sorunu, ek süre içinde', () => {
  const r = fromSubscriber(one('parentapp.premium.monthly', {
    expires_date: '2026-10-30T00:00:00Z', billing_issues_detected_at: '2026-10-30T00:00:00Z',
    grace_period_expires_date: '2026-11-15T00:00:00Z' }), NOW, false);
  assert.equal(r?.plan, 'premium');
  assert.equal(r?.status, 'grace');
  assert.equal(r?.periodEnd, '2026-11-15T00:00:00Z');
});

test('süresi dolmuş', () => {
  const r = fromSubscriber(one('parentapp.premium.monthly', { expires_date: '2026-10-01T00:00:00Z' }), NOW, false);
  assert.equal(r?.plan, 'free');
  assert.equal(r?.status, 'expired');
});

test('iade: hemen biter', () => {
  const r = fromSubscriber(one('parentapp.premium.monthly', { expires_date: '2026-11-20T00:00:00Z', refunded_at: '2026-10-31T00:00:00Z' }), NOW, false);
  assert.equal(r?.plan, 'free');
  assert.equal(r?.status, 'refunded');
});

test('sandbox yalnız izinliyse; başka ürün sayılmaz; en geç biten seçilir', () => {
  const body = { subscriber: { subscriptions: {
    'parentapp.premium.monthly': { expires_date: '2026-11-05T00:00:00Z' },
    'parentapp.premium.yearly': { expires_date: '2027-10-01T00:00:00Z', is_sandbox: true },
    'com.clinicapp.uzman.solo.monthly': { expires_date: '2028-01-01T00:00:00Z' },
  } } };
  assert.equal(fromSubscriber(body, NOW, false)?.productId, 'parentapp.premium.monthly');
  assert.equal(fromSubscriber(body, NOW, true)?.productId, 'parentapp.premium.yearly');
  assert.equal(fromSubscriber({ subscriber: { subscriptions: {} } }, NOW, false), null);
  assert.equal(fromSubscriber(null, NOW, false), null);
});

test('olay yolu (anahtarsız yedek)', () => {
  const base = { product_id: 'parentapp.premium.monthly', expiration_at_ms: Date.parse('2026-12-01T00:00:00Z') };
  assert.equal(fromEvent({ ...base, type: 'RENEWAL' })?.status, 'active');
  assert.equal(fromEvent({ ...base, type: 'CANCELLATION' })?.status, 'canceled');
  assert.equal(fromEvent({ ...base, type: 'CANCELLATION', cancel_reason: 'CUSTOMER_SUPPORT' })?.plan, 'free');
  assert.equal(fromEvent({ ...base, type: 'EXPIRATION' })?.status, 'expired');
  assert.equal(fromEvent({ ...base, type: 'TEST' }), null);
  assert.equal(fromEvent({ product_id: 'baska.urun', type: 'RENEWAL' }), null);
});

test('TRANSFER iki tarafı da etkiler', () => {
  assert.deepEqual(affectedUsers({ type: 'TRANSFER', transferred_from: ['a'], transferred_to: ['b', 'a'] }), ['a', 'b']);
  assert.deepEqual(affectedUsers({ type: 'RENEWAL', app_user_id: 'x' }), ['x']);
});
