// billing-webhook için saf hesap: RevenueCat verisinden aile aboneliği satırını çıkarır (ağ ve veritabanı yok, testli).
// Test: node --experimental-strip-types --test supabase/functions/billing-webhook/state.test.ts

export const PRODUCT_PREFIX = 'parentapp.premium.';

export type Sub = {
  plan: 'premium' | 'free';
  status: 'active' | 'grace' | 'canceled' | 'expired' | 'refunded';
  billing: 'monthly' | 'yearly';
  periodEnd: string | null;
  autoRenew: boolean;
  productId: string | null;
  transactionId: string | null;
};

const billingOf = (product: string): Sub['billing'] => (/year|annual|yillik/i.test(product) ? 'yearly' : 'monthly');
const ms = (iso: string | null | undefined) => (iso ? Date.parse(iso) : NaN);

// Webhook olayından (API anahtarı yoksa yedek yol). null = bu olay aboneliği değiştirmez.
export function fromEvent(e: any): Sub | null {
  const product: string = e.new_product_id ?? e.product_id ?? '';
  if (!product.startsWith(PRODUCT_PREFIX)) return null;
  const sub: Sub = {
    plan: 'premium', status: 'active', billing: billingOf(product),
    periodEnd: e.expiration_at_ms ? new Date(e.expiration_at_ms).toISOString() : null,
    autoRenew: true, productId: product,
    transactionId: e.original_transaction_id ?? e.transaction_id ?? null,
  };
  switch (e.type) {
    case 'INITIAL_PURCHASE': case 'RENEWAL': case 'PRODUCT_CHANGE': case 'UNCANCELLATION': case 'SUBSCRIPTION_EXTENDED':
      return sub;
    case 'CANCELLATION':
      // Yenileme kapandı; dönem sonuna kadar premium. İade (CUSTOMER_SUPPORT) ise hemen biter.
      if (e.cancel_reason === 'CUSTOMER_SUPPORT') return { ...sub, plan: 'free', status: 'refunded', autoRenew: false };
      return { ...sub, status: 'canceled', autoRenew: false };
    case 'BILLING_ISSUE':
      return { ...sub, status: 'grace' };
    case 'EXPIRATION':
      return { ...sub, plan: 'free', status: 'expired', autoRenew: false };
    default:
      return null;
  }
}

// RevenueCat REST v1 `GET /subscribers/{id}` yanıtından güncel durum (olay sırası ve TRANSFER sorununu çözer).
// null = bu kullanıcının hiç ParentApp aboneliği yok.
export function fromSubscriber(body: any, nowMs: number, allowSandbox: boolean): Sub | null {
  const subs: Record<string, any> = body?.subscriber?.subscriptions ?? {};
  let best: [string, any] | null = null;
  for (const [product, s] of Object.entries(subs)) {
    if (!product.startsWith(PRODUCT_PREFIX)) continue;
    if (s?.is_sandbox && !allowSandbox) continue;
    if (!best || (ms(s.expires_date) || 0) > (ms(best[1].expires_date) || 0)) best = [product, s];
  }
  if (!best) return null;
  const [product, s] = best;
  const base = {
    billing: billingOf(product), productId: product,
    transactionId: s.store_transaction_id ?? null,
  };
  if (s.refunded_at) {
    return { ...base, plan: 'free', status: 'refunded', periodEnd: s.expires_date ?? null, autoRenew: false };
  }
  const exp = ms(s.expires_date);
  const grace = ms(s.grace_period_expires_date);
  const autoRenew = !s.unsubscribe_detected_at;
  if (!Number.isFinite(exp) || exp > nowMs) {
    // Süresi dolmamış (ya da süresiz). Yenileme kapalıysa dönem sonuna kadar premium.
    const status = s.billing_issues_detected_at ? 'grace' : autoRenew ? 'active' : 'canceled';
    return { ...base, plan: 'premium', status, periodEnd: s.expires_date ?? null, autoRenew };
  }
  if (grace > nowMs) {
    // Ödeme sorunu: Apple ek süresi boyunca premium sürer.
    return { ...base, plan: 'premium', status: 'grace', periodEnd: s.grace_period_expires_date, autoRenew };
  }
  return { ...base, plan: 'free', status: 'expired', periodEnd: s.expires_date ?? null, autoRenew: false };
}

// Olayın etkilediği kullanıcılar: normalde app_user_id; TRANSFER'de (geri yükleme başka hesaba geçti) iki taraf.
export function affectedUsers(e: any): string[] {
  const ids = e.type === 'TRANSFER'
    ? [...(e.transferred_from ?? []), ...(e.transferred_to ?? [])]
    : [e.app_user_id];
  return [...new Set(ids.filter((x: unknown): x is string => typeof x === 'string'))];
}
