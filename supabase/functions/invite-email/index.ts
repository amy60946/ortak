// invite-email: aile davetini sistem uzman adına e-postayla gönderir (sozlesme/akislar.md 10, proposed/20261027000000_invite_email.sql).
// ClinicApp daveti oluşturduktan sonra uzman oturumuyla çağırır:
//   POST { code }  →  { sent: true } | { sent: false, reason }
//   reason: not_configured (e-posta ayarı yok) · not_found · no_email · closed · expired · no_access · limit_invite · too_soon
//           · limit_day · send_failed
// "Verify JWT" KAPALI yayınlanır (diğer işlevlerimiz gibi); oturum işlevin içinde doğrulanır (auth.getUser).
// Gönderim yolu (Supabase → Edge Functions → Secrets; anahtar sohbete ya da depoya yazılmaz):
//   Canlı: RESEND_API_KEY + MAIL_FROM (alan adındaki adres, ör. davet@alanadi.com)
//   Test:  SMTP_USER + SMTP_PASS (Gmail adresi + Google "uygulama şifresi"; SMTP_HOST varsayılan smtp.gmail.com, SMTP_PORT 465)
//   İsteğe bağlı: INVITE_BASE_URL (ör. https://alanadi.com/d/), PARENTAPP_STORE_URL, PRIVACY_URL, BRAND_NAME (varsayılan ParentApp)
// İçerik: uzmanın unvanı + adı, kod, yükleme adımları, son geçerlilik. Çocuğun adı ve uzmanın notu e-postaya girmez; konu satırında
// unvan yok (sağlık çağrışımı bildirim ekranında görünmesin). Yanıtlar uzmanın e-postasına gider (Reply-To).
// Saf işlevlerin testi: email.test.ts.

export type InviteMail = { code: string; token: string | null; expires_at: string; to: string; clinician: string; title: string; clinic: string };
export type MailEnv = { brand: string; baseUrl: string; storeUrl: string; privacyUrl: string };
export type Built = { subject: string; text: string; html: string; fromName: string };

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
// başlık alanları: satır sonu ve adres karakterleri atılır
export const headerSafe = (s: string) => s.replace(/[\r\n<>"]+/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 80);

export function untilText(iso: string) {
  return new Date(iso).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });
}

export function buildInviteEmail(m: InviteMail, e: MailEnv): Built {
  const brand = e.brand || 'ParentApp';
  const name = headerSafe(m.clinician) || 'Uzmanınız';
  const who = [headerSafe(m.title), name].filter(Boolean).join(' ');
  const clinic = headerSafe(m.clinic);
  const from = clinic && clinic !== name ? ` (${clinic})` : '';
  const until = untilText(m.expires_at);
  const link = m.token && e.baseUrl ? `${e.baseUrl.replace(/\/?$/, '/')}${m.token}` : '';
  const subject = `${name} sizi ${brand} uygulamasına davet ediyor`;

  const text = [
    'Merhaba,',
    '',
    `${who}${from} sizi ${brand} uygulamasına ${m.code} koduyla davet ediyor.`,
    '',
    link ? `Daveti açın: ${link}` : `1) ${brand} uygulamasını yükleyin${e.storeUrl ? `: ${e.storeUrl}` : ' (App Store)'}.`,
    link ? `Uygulama kod sorarsa: ${m.code}` : `2) Kayıt olun; açılan "Kodun var mı?" ekranına bu kodu yazın: ${m.code}`,
    `Hesabınız varsa: Aile › Hesap › Kod gir bölümüne kodu yazın.`,
    '',
    `Davet ${until} tarihine kadar geçerli.`,
    'Hangi çocuğunuzu paylaşacağınıza siz karar verirsiniz; paylaşımı istediğiniz an durdurabilirsiniz.',
    '',
    `Bu e-postayı ${name} sizin için ${brand} üzerinden gönderdi. Yanıtlarsanız yanıtınız doğrudan uzmanınıza gider.`,
    'Bu daveti beklemiyorsanız e-postayı yok sayabilirsiniz.',
    ...(e.privacyUrl ? [`Kişisel verileriniz: ${e.privacyUrl}`] : []),
  ].join('\n');

  const navy = '#0F1B3D';
  const btn = (href: string, label: string, primary: boolean) =>
    `<a href="${esc(href)}" style="display:inline-block;padding:13px 22px;border-radius:12px;font-weight:700;font-size:15px;text-decoration:none;` +
    (primary ? `background:${navy};color:#ffffff;` : `background:#ffffff;color:${navy};border:1px solid #E8EAEF;`) + `">${esc(label)}</a>`;
  const step = (n: number, body: string) =>
    `<tr><td valign="top" style="padding:6px 10px 6px 0;width:26px"><div style="width:24px;height:24px;border-radius:12px;background:#E6EAF5;color:${navy};font-weight:700;font-size:13px;line-height:24px;text-align:center">${n}</div></td>` +
    `<td style="padding:6px 0;font-size:15px;line-height:22px;color:${navy}">${body}</td></tr>`;
  const html = `<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(subject)}</title></head>
<body style="margin:0;padding:0;background:#F5F6F8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
<div style="display:none;max-height:0;overflow:hidden">Davet kodunuz: ${esc(m.code)} · ${esc(until)} tarihine kadar geçerli</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F5F6F8"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px">
<tr><td style="background:${navy};border-radius:18px 18px 0 0;padding:20px 28px">
  <span style="color:#ffffff;font-size:20px;font-weight:800;letter-spacing:.3px">${esc(brand)}</span><span style="display:inline-block;width:8px;height:8px;border-radius:4px;background:#E9B22B;margin-left:6px"></span>
</td></tr>
<tr><td style="background:#ffffff;border-radius:0 0 18px 18px;padding:28px">
  <p style="margin:0 0 14px;font-size:15px;line-height:22px;color:${navy}">Merhaba,</p>
  <p style="margin:0 0 22px;font-size:17px;line-height:25px;color:${navy}"><strong>${esc(who)}</strong>${esc(from)} sizi <strong>${esc(brand)}</strong> uygulamasına davet ediyor.</p>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F5F6F8;border-radius:14px"><tr><td align="center" style="padding:18px">
    <div style="font-size:12px;color:#8A91A3;margin-bottom:6px">Davet kodunuz</div>
    <div style="font-size:32px;font-weight:800;letter-spacing:6px;color:${navy};font-family:Menlo,Consolas,monospace">${esc(m.code)}</div>
    <div style="font-size:12px;color:#8A91A3;margin-top:6px">${esc(until)} tarihine kadar geçerli</div>
  </td></tr></table>
  <table role="presentation" cellpadding="0" cellspacing="0" style="margin:22px 0 8px">
    ${link ? step(1, `Aşağıdaki düğmeyle daveti açın.`) : step(1, `App Store'dan ${esc(brand)} uygulamasını yükleyin.`)}
    ${step(2, `Kayıt olun; açılan <strong>“Kodun var mı?”</strong> ekranına kodu yazın.`)}
    ${step(3, `Hesabınız varsa: <strong>Aile › Hesap › Kod gir</strong> bölümüne kodu yazın.`)}
  </table>
  ${link || e.storeUrl ? `<p style="margin:18px 0 6px">${link ? btn(link, 'Daveti aç', true) : btn(e.storeUrl, `${brand} uygulamasını yükle`, true)}</p>` : ''}
  <p style="margin:22px 0 0;font-size:14px;line-height:21px;color:#5B6275">Hangi çocuğunuzu paylaşacağınıza siz karar verirsiniz; paylaşımı istediğiniz an durdurabilirsiniz.</p>
</td></tr>
<tr><td style="padding:18px 28px;font-size:12px;line-height:18px;color:#8A91A3">
  Bu e-postayı ${esc(name)} sizin için ${esc(brand)} üzerinden gönderdi. Yanıtlarsanız yanıtınız doğrudan uzmanınıza gider.
  Bu daveti beklemiyorsanız e-postayı yok sayabilirsiniz.${e.privacyUrl ? ` <a href="${esc(e.privacyUrl)}" style="color:#8A91A3">Kişisel verileriniz</a>` : ''}
</td></tr>
</table></td></tr></table></body></html>`;
  return { subject, text, html, fromName: `${name} · ${brand}` };
}

// ---------------------------------------------------------------------------------------------------------------------
declare const Deno: { env: { get(k: string): string | undefined }; serve(h: (r: Request) => Response | Promise<Response>): void } | undefined;

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers });

export type Mail = { fromName: string; to: string; replyTo?: string; subject: string; text: string; html: string };

// Canlı: Resend (alan adı doğrulanmış olmalı)
async function sendResend(key: string, fromAddr: string, m: Mail) {
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: `${m.fromName} <${fromAddr}>`, to: [m.to], ...(m.replyTo ? { reply_to: m.replyTo } : {}),
                           subject: m.subject, text: m.text, html: m.html }),
  });
  if (!r.ok) throw new Error(`resend ${r.status}`);
}

// Test: SMTP (Gmail: 465, uygulama şifresi). Gönderen adres SMTP hesabının kendisidir; görünen ad uzmanın adı.
export async function sendSmtp(o: { host: string; port: number; user: string; pass: string }, m: Mail) {
  const nodemailer = (await import('npm:nodemailer@7.0.9')).default;
  const t = nodemailer.createTransport({ host: o.host, port: o.port, secure: o.port === 465, auth: { user: o.user, pass: o.pass } });
  await t.sendMail({ from: { name: m.fromName, address: o.user }, to: m.to, replyTo: m.replyTo, subject: m.subject, text: m.text, html: m.html });
}

if (typeof Deno !== 'undefined') {
  Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers });
    if (req.method !== 'POST') return reply({ error: 'method' }, 405);
    const env = (k: string) => Deno!.env.get(k) ?? '';
    const resend = env('RESEND_API_KEY') && env('MAIL_FROM');
    const smtp = env('SMTP_USER') && env('SMTP_PASS');
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
    const { data: who } = await db.auth.getUser(jwt);
    if (!who?.user) return reply({ error: 'auth' }, 401);
    const { code } = await req.json().catch(() => ({ code: null }));
    if (typeof code !== 'string' || !/^[A-Za-z0-9]{6}$/.test(code)) return reply({ error: 'code' }, 400);
    if (!resend && !smtp) return reply({ sent: false, reason: 'not_configured' });

    const { data: inv, error } = await db.rpc('clinic_invite_email_take', { p_code: code, p_user: who.user.id });
    if (error) return reply({ error: 'take' }, 500);
    if (inv?.error) return reply({ sent: false, reason: inv.error });
    const b = buildInviteEmail(inv as InviteMail, {
      brand: env('BRAND_NAME'), baseUrl: env('INVITE_BASE_URL'), storeUrl: env('PARENTAPP_STORE_URL'), privacyUrl: env('PRIVACY_URL'),
    });
    const mail: Mail = { fromName: b.fromName, to: String(inv.to), replyTo: who.user.email ?? undefined, subject: b.subject, text: b.text, html: b.html };
    let ok = true;
    let detail = '';
    try {
      if (resend) await sendResend(env('RESEND_API_KEY'), env('MAIL_FROM'), mail);
      else await sendSmtp({ host: env('SMTP_HOST') || 'smtp.gmail.com', port: Number(env('SMTP_PORT') || 465), user: env('SMTP_USER'), pass: env('SMTP_PASS') }, mail);
    } catch (e) {
      ok = false;
      // yalnız hata kodu günlüğe yazılır (adres ve içerik yazılmaz); EAUTH = SMTP kullanıcı/uygulama şifresi hatalı
      const x = e as { code?: string; responseCode?: number; message?: string };
      detail = x.code ?? (String(x.message ?? '').startsWith('resend') ? String(x.message) : 'error');
      console.error('invite-email gönderilemedi:', detail, x.responseCode ?? '');
    }
    await db.rpc('clinic_invite_email_done', { p_code: code, p_ok: ok });
    return reply(ok ? { sent: true } : { sent: false, reason: 'send_failed', detail });
  });
}
