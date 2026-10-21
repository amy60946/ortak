// billing-webhook: ödeme sağlayıcısının abonelik olaylarını aile aboneliğine (family_subscriptions) yazar.
// HENÜZ YAYINDA DEĞİL — ödeme altyapısı bağlanınca açılır (ortak/DURUM.md hatırlatıcısı).
// Varsayılan biçim: RevenueCat webhook (App Store + Google Play aboneliklerini tek yerden yönetir).
//   RevenueCat → Project → Integrations → Webhooks: URL = https://<proje>.supabase.co/functions/v1/billing-webhook,
//   Authorization header = "Bearer <BILLING_WEBHOOK_SECRET>".
//   ParentApp, RevenueCat'e oturumdaki kullanıcının kimliğiyle (Supabase auth user id) giriş yapar: app_user_id → ailesi.
// Secret'lar (Supabase → Edge Functions → Secrets): BILLING_WEBHOOK_SECRET. "Verify JWT" kapalı (çağıran RevenueCat).
// Ürün kimlikleri: parentapp.premium.monthly (aylık, her ay yenilenir) / parentapp.premium.yearly (yıllık, peşin).
import { createClient } from 'jsr:@supabase/supabase-js@2';

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

Deno.serve(async (req) => {
  const secret = Deno.env.get('BILLING_WEBHOOK_SECRET') ?? '';
  if (req.method !== 'POST') return new Response('POST', { status: 405 });
  if (secret.length < 24 || !same(req.headers.get('authorization') ?? '', `Bearer ${secret}`)) {
    return new Response('yetkisiz', { status: 401 });
  }
  const body = await req.json().catch(() => null);
  const e = body?.event;
  if (!e?.type) return Response.json({ error: 'olay yok' }, { status: 400 });
  if (e.environment === 'SANDBOX' && Deno.env.get('BILLING_ALLOW_SANDBOX') !== '1') {
    return Response.json({ skipped: 'sandbox' });
  }

  const userId: string = e.app_user_id ?? '';
  if (!UUID.test(userId)) return Response.json({ skipped: 'anonim RevenueCat kullanıcısı' });
  const { data: profile } = await db.from('profiles').select('family_id').eq('id', userId).maybeSingle();
  if (!profile?.family_id) return Response.json({ skipped: 'aile yok' });

  const product: string = e.new_product_id ?? e.product_id ?? '';
  const billing = /year|annual|yillik/i.test(product) ? 'yearly' : 'monthly';
  const periodEnd = e.expiration_at_ms ? new Date(e.expiration_at_ms).toISOString() : null;

  // RevenueCat olay türü → abonelik durumu
  let plan = 'premium';
  let status = 'active';
  let autoRenew = true;
  switch (e.type) {
    case 'INITIAL_PURCHASE': case 'RENEWAL': case 'PRODUCT_CHANGE': case 'UNCANCELLATION': case 'SUBSCRIPTION_EXTENDED':
      break;
    case 'CANCELLATION':
      // Yenileme kapandı; dönem sonuna kadar premium. İade (CUSTOMER_SUPPORT) ise hemen biter.
      status = e.cancel_reason === 'CUSTOMER_SUPPORT' ? 'refunded' : 'canceled';
      autoRenew = false;
      if (status === 'refunded') plan = 'free';
      break;
    case 'BILLING_ISSUE':
      status = 'grace';
      break;
    case 'EXPIRATION':
      plan = 'free'; status = 'expired'; autoRenew = false;
      break;
    default:
      return Response.json({ skipped: e.type });
  }

  const { error } = await db.rpc('set_family_subscription', {
    p_family: profile.family_id, p_plan: plan, p_billing: billing, p_status: status, p_period_end: periodEnd,
    p_auto_renew: autoRenew, p_product_id: product || null, p_transaction_id: e.original_transaction_id ?? e.transaction_id ?? null,
    p_source: 'store',
  });
  if (error) {
    console.error(error.message);
    return Response.json({ error: 'kaydedilemedi' }, { status: 500 });   // RevenueCat yeniden dener
  }
  return Response.json({ ok: true });
});
