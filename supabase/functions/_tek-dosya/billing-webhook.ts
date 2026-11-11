// ÜRETİLDİ — elle düzenlenmez. Kaynak: supabase/functions/billing-webhook/index.ts + state.ts (tek dosyada birleşik).
// Neden: Supabase panelindeki editörde ikinci dosya eklemek hata verdi (11 Kasım 2026); bu dosya tek başına yapıştırılır.
// Kaynak değişirse yeniden üretilir; iki sürümün derlenmiş çıktısı aynı olmalıdır.
// billing-webhook: RevenueCat abonelik olaylarını aile aboneliğine (family_subscriptions) ve klinik üyeliğine
// (billing_apply, kaynak 'revenuecat') yazar.
// Karar (kullanıcı, 22 Ekim 2026): ParentApp ve ClinicApp ödemesi RevenueCat ile; klinik sahibi birey olarak öder. HENÜZ YAYINDA DEĞİL — kurulum CANLIYA_ALMA.md 1.8.
//   RevenueCat → Project → Integrations → Webhooks: URL = https://<proje>.supabase.co/functions/v1/billing-webhook,
//   Authorization header = "Bearer <BILLING_WEBHOOK_SECRET>".
//   ParentApp, RevenueCat'e oturumdaki kullanıcının kimliğiyle (Supabase auth user id) giriş yapar: app_user_id → ailesi.
// Secret'lar (Supabase → Edge Functions → Secrets): BILLING_WEBHOOK_SECRET (≥ 24 karakter),
//   REVENUECAT_API_KEY (RevenueCat gizli anahtarı, sk_…; önerilir: durum her olayda RevenueCat'ten yeniden okunur,
//   böylece olay sırası karışsa da ve "geri yükle" başka hesaba geçse de (TRANSFER) doğru yazılır),
//   BILLING_ALLOW_SANDBOX=1 yalnız denemede. "Verify JWT" kapalı (çağıran RevenueCat).
// Ürün kimlikleri: parentapp.premium.monthly / parentapp.premium.yearly; ClinicApp com.clinicapp.uzman.{solo,clinic}.{monthly,yearly}
//   (yalnız klinik sahibi; klinik yolu REVENUECAT_API_KEY ister). Elle verilen (manual/web) premium,
//   mağaza aboneliği bitince ezilmez.
import { createClient } from 'jsr:@supabase/supabase-js@2';
// ---- state.ts (birleşik) ----
// billing-webhook için saf hesap: RevenueCat verisinden aile aboneliği satırını çıkarır (ağ ve veritabanı yok, testli).
// Test: node --experimental-strip-types --test supabase/functions/billing-webhook/state.test.ts

const PRODUCT_PREFIX = 'parentapp.premium.';
const CLINIC_PREFIX = 'com.clinicapp.uzman.';

type Sub = {
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
function fromEvent(e: any): Sub | null {
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

// RevenueCat REST v1 `GET /subscribers/{id}` yanıtındaki tek aboneliğin güncel durumu.
function stateOf(product: string, s: any, nowMs: number): Sub {
  const base = { billing: billingOf(product), productId: product, transactionId: s.store_transaction_id ?? null };
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

function subsWith(body: any, prefix: string, allowSandbox: boolean): [string, any][] {
  const subs: Record<string, any> = body?.subscriber?.subscriptions ?? {};
  return Object.entries(subs).filter(([p, s]) => p.startsWith(prefix) && (!s?.is_sandbox || allowSandbox));
}

// ParentApp: en geç biten aile aboneliği (olay sırası ve TRANSFER sorununu çözer). null = hiç abonelik yok.
function fromSubscriber(body: any, nowMs: number, allowSandbox: boolean): Sub | null {
  let best: [string, any] | null = null;
  for (const e of subsWith(body, PRODUCT_PREFIX, allowSandbox)) {
    if (!best || (ms(e[1].expires_date) || 0) > (ms(best[1].expires_date) || 0)) best = e;
  }
  return best ? stateOf(best[0], best[1], nowMs) : null;
}

// ClinicApp (kullanıcı kararı 22 Ekim 2026: klinik sahibi birey olarak öder): uzmanın her klinik ürünü ayrı satır;
// klinik planını sunucu en geniş etkin abonelikten seçer (billing_recompute). status billing_subscriptions değerleriyle.
type ClinicSub = { productId: string; status: 'active' | 'canceled' | 'expired' | 'refunded'; periodEnd: string | null; autoRenew: boolean };
function clinicSubs(body: any, nowMs: number, allowSandbox: boolean): ClinicSub[] {
  return subsWith(body, CLINIC_PREFIX, allowSandbox).map(([product, s]) => {
    const st = stateOf(product, s, nowMs);
    // Ek süre (grace) klinikte etkin sayılır: erişim ek süre bitene dek açık kalır.
    return { productId: product, status: st.status === 'grace' ? 'active' : st.status, periodEnd: st.periodEnd, autoRenew: st.autoRenew };
  });
}

// Olayın etkilediği kullanıcılar: normalde app_user_id; TRANSFER'de (geri yükleme başka hesaba geçti) iki taraf.
function affectedUsers(e: any): string[] {
  const ids = e.type === 'TRANSFER'
    ? [...(e.transferred_from ?? []), ...(e.transferred_to ?? [])]
    : [e.app_user_id];
  return [...new Set(ids.filter((x: unknown): x is string => typeof x === 'string'))];
}
// ---- index.ts devamı ----

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

// Sabit sürede karşılaştırma (secret tahmini zamanlamadan öğrenilemesin)
function same(a: string, b: string) {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// RevenueCat'ten kullanıcının güncel kaydı. undefined = okunamadı (RevenueCat yeniden denesin).
async function readSubscriber(userId: string, key: string): Promise<any | undefined> {
  const r = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`, {
    headers: { authorization: `Bearer ${key}`, accept: 'application/json' },
  }).catch(() => null);
  if (!r?.ok) {
    console.error('revenuecat', r?.status);
    return undefined;
  }
  return await r.json().catch(() => undefined);
}

// Klinik sahibinin klinik ürünlerini üyeliğe yazar. false = hata (500, RevenueCat yeniden dener).
async function applyClinic(userId: string, body: any, allowSandbox: boolean, e: any): Promise<boolean> {
  const subs = clinicSubs(body, Date.now(), allowSandbox);
  // RevenueCat'te artık görünmeyen (ör. TRANSFER ile başka hesaba geçen) eski satırlar bugün biter.
  const { data: old } = await db.from('billing_subscriptions').select('external_id, plan_id')
    .eq('source', 'revenuecat').like('external_id', `${userId}:%`).in('status', ['active', 'canceled']);
  const gone = (old ?? []).filter((o) => !subs.some((c) => `${userId}:${c.productId}` === o.external_id));
  let ok = true;
  for (const o of gone) {
    const { error } = await db.rpc('billing_apply', {
      p_source: 'revenuecat', p_external_id: o.external_id, p_clinic_id: null, p_plan_id: o.plan_id, p_status: 'expired',
      p_period_end: new Date().toISOString(), p_auto_renew: false, p_environment: null, p_payload: { type: e.type },
    });
    if (error) { console.error(error.message); ok = false; }
  }
  if (!subs.length) return ok;
  const { data: me } = await db.from('clinicians').select('clinic_id, role').eq('id', userId).maybeSingle();
  if (!me?.clinic_id || me.role !== 'owner') {
    console.error('klinik aboneliği sahibi olmayan hesapta', userId);
    return ok;
  }
  for (const c of subs) {
    const { data: plan } = await db.from('billing_plans').select('id').eq('apple_product_id', c.productId).maybeSingle();
    if (!plan) { console.error('bilinmeyen ürün', c.productId); continue; }
    const { error } = await db.rpc('billing_apply', {
      p_source: 'revenuecat', p_external_id: `${userId}:${c.productId}`, p_clinic_id: me.clinic_id, p_plan_id: plan.id,
      p_status: c.status, p_period_end: c.periodEnd, p_auto_renew: c.autoRenew,
      p_environment: e.environment ?? null, p_payload: { type: e.type },
    });
    if (error && error.code !== 'P0409') { console.error(error.message); ok = false; }   // P0409: başka kliniğe bağlı, yeniden deneme anlamsız
  }
  return ok;
}

// Bir kullanıcının ailesine yazar. false = hata (500 dön, RevenueCat yeniden dener).
async function apply(userId: string, sub: Sub | null): Promise<boolean> {
  const { data: profile } = await db.from('profiles').select('family_id').eq('id', userId).maybeSingle();
  if (!profile?.family_id) return true;
  const { data: cur } = await db.from('family_subscriptions').select('source, plan')
    .eq('family_id', profile.family_id).maybeSingle();
  if (!sub) {
    // Bu kullanıcıda hiç abonelik yok (ör. TRANSFER ile başka hesaba geçti): yalnız mağaza kaynaklı premium kapanır.
    if (cur?.source !== 'store' || cur?.plan !== 'premium') return true;
    sub = { plan: 'free', status: 'expired', billing: 'monthly', periodEnd: null, autoRenew: false, productId: null, transactionId: null };
  }
  if (sub.plan === 'free' && cur && cur.source !== 'store') return true;   // elle verilen istisna korunur
  const { error } = await db.rpc('set_family_subscription', {
    p_family: profile.family_id, p_plan: sub.plan, p_billing: sub.billing, p_status: sub.status,
    p_period_end: sub.periodEnd, p_auto_renew: sub.autoRenew, p_product_id: sub.productId,
    p_transaction_id: sub.transactionId, p_source: 'store',
  });
  if (error) console.error(error.message);
  return !error;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get('BILLING_WEBHOOK_SECRET') ?? '';
  if (req.method !== 'POST') return new Response('POST', { status: 405 });
  if (secret.length < 24 || !same(req.headers.get('authorization') ?? '', `Bearer ${secret}`)) {
    return new Response('yetkisiz', { status: 401 });
  }
  const body = await req.json().catch(() => null);
  const e = body?.event;
  if (!e?.type) return Response.json({ error: 'olay yok' }, { status: 400 });
  const allowSandbox = Deno.env.get('BILLING_ALLOW_SANDBOX') === '1';
  if (e.environment === 'SANDBOX' && !allowSandbox) return Response.json({ skipped: 'sandbox' });

  const users = affectedUsers(e).filter((u) => UUID.test(u));
  if (!users.length) return Response.json({ skipped: 'anonim RevenueCat kullanıcısı' });
  const key = Deno.env.get('REVENUECAT_API_KEY') ?? '';

  let ok = true;
  for (const userId of users) {
    let sub: Sub | null | undefined;
    if (key) {
      const body = await readSubscriber(userId, key);
      if (body === undefined) { ok = false; continue; }
      sub = fromSubscriber(body, Date.now(), allowSandbox);
      ok = (await applyClinic(userId, body, allowSandbox, e)) && ok;
    } else {
      if (e.type === 'TRANSFER') continue;   // anahtarsız yolda iki tarafın durumu bilinemez
      sub = fromEvent(e);
      if (!sub) continue;
    }
    ok = (await apply(userId, sub)) && ok;
  }
  return ok ? Response.json({ ok: true }) : Response.json({ error: 'kaydedilemedi' }, { status: 500 });
});
