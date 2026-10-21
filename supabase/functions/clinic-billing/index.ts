// clinic-billing: ClinicApp üyeliği. Ödemeyi doğrular ve yalnız service role ile `billing_apply` çağırır;
// istemci planı kendisi yazamaz. "Verify JWT" KAPALI yayınlanır (Apple/iyzico bildirimleri JWT taşımaz);
// uzmandan gelen istekler aşağıda oturum anahtarıyla ayrıca doğrulanır.
//
// Yollar (POST, https://<proje>.supabase.co/functions/v1/clinic-billing/<yol>):
//   apple-verify     uzman (oturum) · {transactionId}  → App Store Server API'den doğrular, kliniği açar
//   apple-notify     Apple (App Store Server Notifications V2) · {signedPayload} → durumu Apple'dan yeniden okur
//   iyzico-start     uzman sahibi (oturum, web) · {plan_id, buyer{...}} → iyzico ödeme formu
//   iyzico-callback  iyzico (form POST, token) → sonucu iyzico'dan okur, kliniği açar, uygulamaya döner
//   iyzico-webhook   iyzico (abonelik yenileme/başarısız) → durumu iyzico'dan yeniden okur
//   iyzico-cancel    uzman sahibi (oturum, web) → yenilemeyi kapatır (dönem sonuna kadar açık)
//
// Secret'lar (Supabase → Edge Functions → Secrets):
//   APPLE_IAP_KEY_P8, APPLE_IAP_KEY_ID, APPLE_ISSUER_ID  (App Store Connect → Users and Access → Integrations → In-App Purchase)
//   IYZICO_API_KEY, IYZICO_SECRET_KEY, IYZICO_BASE_URL (https://api.iyzipay.com ya da https://sandbox-api.iyzipay.com)
//   APP_URL (ClinicApp web adresi; ödeme sonrası dönüş ve CORS)
import { createClient } from 'jsr:@supabase/supabase-js@2';

const BUNDLE_ID = 'com.clinicapp.uzman';
const env = (k: string) => Deno.env.get(k) ?? '';
const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });

const cors = () => ({
  'Access-Control-Allow-Origin': env('APP_URL') ? new URL(env('APP_URL')).origin : '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  Vary: 'Origin',
});
const json = (body: unknown, status = 200) => Response.json(body, { status, headers: cors() });

const b64url = (b: ArrayBuffer | Uint8Array | string) => {
  const bytes = typeof b === 'string' ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = '';
  bytes.forEach((x) => { s += String.fromCharCode(x); });
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
// JWS gövdesi (imza doğrulanmaz: yalnız Apple'a TLS ile doğrudan sorulan yanıtlarda ya da yeniden sorgulamak için kimlik okurken)
const jwsPayload = (jws: string) => {
  const p = (jws ?? '').split('.')[1] ?? '';
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(p.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0))));
};

type Plan = { id: string; package: string; period: 'monthly' | 'yearly'; apple_product_id: string | null; iyzico_plan_ref: string | null };
async function plans(): Promise<Plan[]> {
  const { data } = await db.from('billing_plans').select('id, package, period, apple_product_id, iyzico_plan_ref');
  return (data ?? []) as Plan[];
}

// Oturumdaki uzman (ve kliniği)
async function caller(req: Request) {
  const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data } = await db.auth.getUser(token);
  if (!data?.user) return null;
  const { data: me } = await db.from('clinicians').select('id, clinic_id, role, name').eq('id', data.user.id).maybeSingle();
  return me ? { ...me, email: data.user.email ?? '' } : null;
}

async function apply(source: string, externalId: string, clinicId: string | null, planId: string, status: string,
                     periodEnd: string | null, autoRenew: boolean, environment: string | null, payload: unknown) {
  const { data, error } = await db.rpc('billing_apply', {
    p_source: source, p_external_id: externalId, p_clinic_id: clinicId, p_plan_id: planId, p_status: status,
    p_period_end: periodEnd, p_auto_renew: autoRenew, p_environment: environment, p_payload: payload ?? {},
  });
  if (error) throw new Error(error.message);
  return data;
}

// ---------------------------------------------------------------- App Store
let appleJwt: { jwt: string; at: number } | null = null;
async function appleToken() {
  if (appleJwt && Date.now() - appleJwt.at < 30 * 60e3) return appleJwt.jwt;
  const body = env('APPLE_IAP_KEY_P8').replace(/\\n/g, '\n').replace(/-----(BEGIN|END) [A-Z ]*KEY-----/g, '').replace(/\s+/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(body), (c) => c.charCodeAt(0)),
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const iat = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'ES256', kid: env('APPLE_IAP_KEY_ID'), typ: 'JWT' }));
  const claims = b64url(JSON.stringify({ iss: env('APPLE_ISSUER_ID'), iat, exp: iat + 3000, aud: 'appstoreconnect-v1', bid: BUNDLE_ID }));
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(`${head}.${claims}`));
  appleJwt = { jwt: `${head}.${claims}.${b64url(sig)}`, at: Date.now() };
  return appleJwt.jwt;
}

// Aboneliğin güncel durumu doğrudan Apple'dan (önce üretim, bulunamazsa sandbox/TestFlight)
async function appleStatus(transactionId: string) {
  if (!/^\d{1,30}$/.test(transactionId)) throw new Error('Geçersiz işlem numarası');
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const r = await fetch(`https://${host}/inApps/v1/subscriptions/${transactionId}`, {
      headers: { authorization: `Bearer ${await appleToken()}` },
    });
    if (r.status === 404) continue;
    if (!r.ok) throw new Error(`Apple ${r.status}`);
    const body = await r.json();
    if (body.bundleId && body.bundleId !== BUNDLE_ID) throw new Error('Başka uygulamanın aboneliği');
    for (const group of body.data ?? []) {
      for (const last of group.lastTransactions ?? []) {
        const tx = jwsPayload(last.signedTransactionInfo);
        const renewal = last.signedRenewalInfo ? jwsPayload(last.signedRenewalInfo) : {};
        return { tx, renewal, appleStatus: last.status as number, environment: body.environment as string };
      }
    }
    throw new Error('Abonelik bulunamadı');
  }
  throw new Error('Abonelik bulunamadı');
}

async function appleApply(transactionId: string, clinicId: string | null) {
  const { tx, renewal, appleStatus: st, environment } = await appleStatus(transactionId);
  if (tx.bundleId !== BUNDLE_ID) throw new Error('Başka uygulamanın aboneliği');
  const plan = (await plans()).find((p) => p.apple_product_id === tx.productId);
  if (!plan) throw new Error('Bilinmeyen ürün');
  // Satın alma, uygulamanın verdiği klinik kimliğiyle (appAccountToken) yapılmış olmalı
  if (clinicId && String(tx.appAccountToken ?? '').toLowerCase() !== clinicId.toLowerCase()) {
    throw new Error('Bu satın alma başka bir kliniğe ait');
  }
  const graceEnd = renewal.gracePeriodExpiresDate ? Number(renewal.gracePeriodExpiresDate) : 0;
  const end = Math.max(Number(tx.expiresDate ?? 0), st === 4 ? graceEnd : 0);
  const autoRenew = renewal.autoRenewStatus === 1;
  // 1 etkin · 2 bitti · 3 ödeme yeniden deneniyor · 4 ek süre · 5 iade/iptal
  const status = tx.revocationDate || st === 5 ? 'refunded' : st === 1 || st === 4 ? (autoRenew ? 'active' : 'canceled') : 'expired';
  return apply('app_store', String(tx.originalTransactionId), clinicId ?? (tx.appAccountToken ?? null), plan.id, status,
    end ? new Date(end).toISOString() : null, autoRenew && status === 'active', environment,
    { productId: tx.productId, appleStatus: st, transactionId: tx.transactionId });
}

// ---------------------------------------------------------------- iyzico
async function iyzico(method: 'GET' | 'POST', path: string, body?: unknown) {
  const raw = body === undefined ? '' : JSON.stringify(body);
  const rnd = `${Date.now()}${crypto.getRandomValues(new Uint32Array(1))[0]}`;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(env('IYZICO_SECRET_KEY')),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rnd + path + raw)));
  const sig = [...mac].map((b) => b.toString(16).padStart(2, '0')).join('');
  const auth = btoa(`apiKey:${env('IYZICO_API_KEY')}&randomKey:${rnd}&signature:${sig}`);
  const r = await fetch(env('IYZICO_BASE_URL') + path, {
    method,
    headers: { Authorization: `IYZWSv2 ${auth}`, 'x-iyzi-rnd': rnd, 'Content-Type': 'application/json', Accept: 'application/json' },
    body: method === 'POST' ? raw : undefined,
  });
  const out = await r.json().catch(() => ({}));
  if (!r.ok || out.status !== 'success') throw new Error(out.errorMessage ?? `iyzico ${r.status}`);
  return out;
}

const addPeriod = (from: Date, period: 'monthly' | 'yearly') => {
  const d = new Date(from);
  if (period === 'yearly') d.setUTCFullYear(d.getUTCFullYear() + 1); else d.setUTCMonth(d.getUTCMonth() + 1);
  d.setUTCDate(d.getUTCDate() + 1);  // yenileme günü ödeme gecikmesine bir gün pay
  return d;
};

// Aboneliğin durumunu iyzico'dan okuyup yazar. renewed: yeni bir dönem ödendi
async function iyzicoSync(ref: string, clinicId: string | null, renewed: boolean, payload: unknown) {
  const sub = (await iyzico('GET', `/v2/subscription/subscriptions/${encodeURIComponent(ref)}`)).data ?? {};
  const plan = (await plans()).find((p) => p.iyzico_plan_ref && p.iyzico_plan_ref === sub.pricingPlanReferenceCode);
  if (!plan) throw new Error('Bilinmeyen iyzico paketi');
  const { data: cur } = await db.from('billing_subscriptions').select('period_end, clinic_id')
    .eq('source', 'iyzico').eq('external_id', ref).maybeSingle();
  // Ödenen dönem bugünden başlar; aynı ödeme için gelen tekrar bildirimler süreyi uzatmaz (en geç olan korunur)
  const paidUntil = addPeriod(new Date(), plan.period);
  const periodEnd = renewed || !cur?.period_end
    ? new Date(Math.max(paidUntil.getTime(), cur?.period_end ? new Date(cur.period_end).getTime() : 0)).toISOString()
    : cur.period_end;
  const s = String(sub.subscriptionStatus ?? '').toUpperCase();
  const status = s === 'ACTIVE' ? 'active' : s === 'CANCELED' ? 'canceled' : s === 'PENDING' ? 'pending' : 'expired';
  return apply('iyzico', ref, clinicId ?? cur?.clinic_id ?? null, plan.id, status, status === 'expired' ? new Date().toISOString() : periodEnd,
    status === 'active', env('IYZICO_BASE_URL').includes('sandbox') ? 'Sandbox' : 'Production', payload);
}

const clean = (v: unknown, max: number) => String(v ?? '').replace(/[<>]/g, '').trim().slice(0, max);

// ---------------------------------------------------------------- yönlendirici
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors() });
  if (req.method !== 'POST') return json({ error: 'POST gerekli' }, 405);
  const route = new URL(req.url).pathname.split('/').filter(Boolean).pop();
  try {
    if (route === 'apple-verify') {
      const me = await caller(req);
      if (!me) return json({ error: 'Giriş gerekli' }, 401);
      if (me.role !== 'owner') return json({ error: 'Üyeliği yalnız klinik sahibi alır' }, 403);
      const { transactionId } = await req.json();
      return json(await appleApply(String(transactionId ?? ''), me.clinic_id));
    }

    if (route === 'apple-notify') {
      const { signedPayload } = await req.json().catch(() => ({}));
      const n = jwsPayload(signedPayload ?? '');
      if (n?.data?.bundleId !== BUNDLE_ID || !n?.data?.signedTransactionInfo) return json({ ok: true });
      // Bildirimin içeriğine güvenilmez: yalnız işlem numarası alınır, durum Apple'dan yeniden okunur
      const tx = jwsPayload(n.data.signedTransactionInfo);
      await appleApply(String(tx.originalTransactionId ?? tx.transactionId ?? ''), null).catch((e) => console.error('apple-notify', e.message));
      return json({ ok: true });
    }

    if (route === 'iyzico-start') {
      const me = await caller(req);
      if (!me) return json({ error: 'Giriş gerekli' }, 401);
      if (me.role !== 'owner') return json({ error: 'Üyeliği yalnız klinik sahibi alır' }, 403);
      const { plan_id, buyer } = await req.json();
      const plan = (await plans()).find((p) => p.id === plan_id);
      if (!plan?.iyzico_plan_ref) return json({ error: 'Bu paket web ödemesine henüz açık değil' }, 400);
      const b = buyer ?? {};
      const identity = clean(b.identityNumber, 11);
      const gsm = clean(b.gsmNumber, 20).replace(/[^\d+]/g, '');
      if (!/^\d{11}$/.test(identity)) return json({ error: 'T.C. kimlik numarası 11 hane olmalı' }, 400);
      if (!/^\+?\d{10,13}$/.test(gsm)) return json({ error: 'Cep telefonu geçersiz' }, 400);
      const name = clean(b.name, 60), surname = clean(b.surname, 60), city = clean(b.city, 40), address = clean(b.address, 200);
      if (!name || !surname || !city || !address) return json({ error: 'Ad, soyad, şehir ve adres gerekli' }, 400);
      const out = await iyzico('POST', '/v2/subscription/checkoutform/initialize', {
        locale: 'tr', conversationId: me.clinic_id,
        callbackUrl: `${env('SUPABASE_URL')}/functions/v1/clinic-billing/iyzico-callback`,
        pricingPlanReferenceCode: plan.iyzico_plan_ref, subscriptionInitialStatus: 'ACTIVE',
        customer: {
          name, surname, email: me.email, identityNumber: identity,
          gsmNumber: gsm.startsWith('+') ? gsm : `+90${gsm.replace(/^0/, '')}`,
          billingAddress: { contactName: `${name} ${surname}`, city, country: 'Turkey', address },
        },
      });
      // Ödeme oturumu kaydedilemezse form verilmez (ödeme alınıp kliniğe bağlanamaması olmasın)
      const saved = await db.from('billing_checkouts').insert({ token: out.token, clinic_id: me.clinic_id, plan_id: plan.id, created_by: me.id });
      if (saved.error) throw new Error('Ödeme başlatılamadı, biraz sonra tekrar dene');
      return json({ token: out.token, checkoutFormContent: out.checkoutFormContent });
    }

    if (route === 'iyzico-callback') {
      const form = await req.formData().catch(() => null);
      const token = String(form?.get('token') ?? '');
      const back = (ok: boolean) => Response.redirect(`${env('APP_URL') || 'https://clinicapp.app'}/?billing=${ok ? 'ok' : 'fail'}`, 303);
      if (!token) return back(false);
      // Oturum tek kez sahiplenilir (aynı dönüş iki kez gelirse ikincisi hiçbir şey yapmaz)
      const { data: co } = await db.from('billing_checkouts').update({ completed_at: new Date().toISOString() })
        .eq('token', token).is('completed_at', null).select('*').maybeSingle();
      if (!co) return back(false);
      try {
        const res = await iyzico('GET', `/v2/subscription/checkoutform/${encodeURIComponent(token)}`);
        const ref = res?.data?.referenceCode;
        if (!ref) throw new Error('Ödeme tamamlanmadı');
        await iyzicoSync(ref, co.clinic_id, true, { checkout: token });
        return back(true);
      } catch (e) {
        await db.from('billing_checkouts').update({ completed_at: null }).eq('token', token);
        console.error('iyzico-callback', (e as Error).message);
        return back(false);
      }
    }

    if (route === 'iyzico-webhook') {
      const raw = await req.text();
      const ev = JSON.parse(raw || '{}');
      // İmza varsa doğrulanır; yoksa da içerik değil, iyzico'dan yeniden okunan durum yazılır
      const given = req.headers.get('x-iyz-signature-v3');
      if (given) {
        const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(env('IYZICO_SECRET_KEY')),
          { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
        const msg = env('IYZICO_SECRET_KEY') + (ev.merchantId ?? '') + (ev.iyziEventType ?? '') + (ev.subscriptionReferenceCode ?? '')
          + (ev.orderReferenceCode ?? '') + (ev.customerReferenceCode ?? '');
        const mac = [...new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(msg)))]
          .map((b) => b.toString(16).padStart(2, '0')).join('');
        if (mac !== given.toLowerCase()) return json({ error: 'imza' }, 401);
      }
      const ref = String(ev.subscriptionReferenceCode ?? '');
      if (!ref) return json({ ok: true });
      const { data: known } = await db.from('billing_subscriptions').select('id').eq('source', 'iyzico').eq('external_id', ref).maybeSingle();
      if (!known) return json({ ok: true });  // bizim başlatmadığımız abonelik
      await iyzicoSync(ref, null, ev.iyziEventType === 'subscription.order.success', { event: ev.iyziEventType, order: ev.orderReferenceCode });
      return json({ ok: true });
    }

    if (route === 'iyzico-cancel') {
      const me = await caller(req);
      if (!me) return json({ error: 'Giriş gerekli' }, 401);
      if (me.role !== 'owner') return json({ error: 'Üyeliği yalnız klinik sahibi yönetir' }, 403);
      const { data: subs } = await db.from('billing_subscriptions').select('external_id').eq('clinic_id', me.clinic_id)
        .eq('source', 'iyzico').eq('status', 'active');
      for (const s of subs ?? []) {
        await iyzico('POST', `/v2/subscription/subscriptions/${encodeURIComponent(s.external_id)}/cancel`, {});
        await iyzicoSync(s.external_id, me.clinic_id, false, { cancel: true });
      }
      return json({ ok: true, canceled: (subs ?? []).length });
    }

    return json({ error: 'Bilinmeyen yol' }, 404);
  } catch (e) {
    console.error(route, (e as Error).message);
    return json({ error: (e as Error).message }, 400);
  }
});
