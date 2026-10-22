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
import { affectedUsers, clinicSubs, fromEvent, fromSubscriber, type Sub } from './state.ts';

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
