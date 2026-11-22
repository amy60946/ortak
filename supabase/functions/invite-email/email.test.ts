// Çalıştır: node --experimental-strip-types --test supabase/functions/invite-email/email.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildInviteEmail, headerSafe } from './index.ts';

const inv = { code: 'ABC123', token: 'f'.repeat(32), expires_at: '2026-10-29T15:30:00Z', to: 'aile@ornek.com',
              clinician: 'Ece Kaya', title: 'Klinik Psikolog', clinic: 'Mavi Çocuk Merkezi' };
const env = { brand: '', baseUrl: '', storeUrl: '', privacyUrl: '' };

test('konu: ad var, unvan yok; gövdede unvan + ad + kod', () => {
  const b = buildInviteEmail(inv, env);
  assert.equal(b.subject, 'Ece Kaya sizi Moyo uygulamasına davet ediyor');
  assert.ok(b.text.includes('Klinik Psikolog Ece Kaya (Mavi Çocuk Merkezi) sizi Moyo uygulamasına ABC123 koduyla davet ediyor.'));
  assert.ok(b.html.includes('<strong>Klinik Psikolog Ece Kaya</strong> (Mavi Çocuk Merkezi)'));
  assert.ok(b.html.includes('>ABC123<'));
  assert.equal(b.fromName, 'Ece Kaya · Moyo');
});

test('son geçerlilik İstanbul saatiyle', () => {
  const b = buildInviteEmail(inv, env);
  assert.ok(b.text.includes('29 Ekim 18:30'), b.text);
});

test('bireysel uzman: klinik adı = uzmanın adı ise tekrar edilmez', () => {
  const b = buildInviteEmail({ ...inv, clinic: 'Ece Kaya' }, env);
  assert.ok(b.text.includes('Klinik Psikolog Ece Kaya sizi'));
  assert.ok(!b.text.includes('(Ece Kaya)'));
});

test('alan adı yokken bağlantı yok, kod adımları var; varken bağlantı', () => {
  const a = buildInviteEmail(inv, env);
  assert.ok(!a.html.includes('Daveti aç') && !a.text.includes('https://'));
  assert.ok(a.text.includes('davet kodu sorulduğunda') && a.text.includes('Aile › Hesap › Kod gir'));
  const b = buildInviteEmail(inv, { ...env, baseUrl: 'https://ornek.com/d', storeUrl: 'https://apps.apple.com/x', privacyUrl: 'https://ornek.com/kvkk' });
  assert.ok(b.text.includes(`https://ornek.com/d/${'f'.repeat(32)}`));
  assert.ok(b.html.includes('Daveti aç') && b.html.includes('https://ornek.com/kvkk'));
});

test('mağaza bağlantısı varken 1. adım App Store sayfasına bağlanır', () => {
  const b = buildInviteEmail(inv, { ...env, storeUrl: 'https://apps.apple.com/tr/app/x' });
  assert.ok(b.html.includes(`<a href="https://apps.apple.com/tr/app/x"`) && b.html.includes('uygulamasını yükleyin</a>'));
  assert.ok(b.text.includes('uygulamasını yükleyin: https://apps.apple.com/tr/app/x'));
});

test('ad ve unvan HTML ve başlıkta zararsızlaştırılır', () => {
  const b = buildInviteEmail({ ...inv, clinician: 'Ece <b>"X"</b>\r\nBcc: kotu@ornek.com', title: '<script>' }, env);
  assert.ok(!b.html.includes('<b>') && !b.html.includes('<script>'));
  assert.ok(!/[\r\n]/.test(b.subject) && !/[\r\n<>]/.test(b.fromName));
  assert.equal(headerSafe('a\r\nb'), 'a b');
});

test('çocuk adı, uzman notu ve alıcı adresi gövdede yok; marka adı değişebilir', () => {
  const b = buildInviteEmail(inv, { ...env, brand: 'Pofi' });
  assert.ok(!b.text.includes('aile@ornek.com') && !b.html.includes('aile@ornek.com'));
  assert.equal(b.subject, 'Ece Kaya sizi Pofi uygulamasına davet ediyor');
});

test('uzmanın yazdığı ad, unvan ve klinik adından bağlantı ve adres çıkarılır', async () => {
  const { nameSafe } = await import('./index.ts');
  assert.equal(nameSafe('Ece Kaya'), 'Ece Kaya');
  assert.equal(nameSafe('Dr. Ayşe Şahin'), 'Dr. Ayşe Şahin');
  assert.equal(nameSafe('Kazan http://kotu.example/x hemen'), 'Kazan hemen');
  assert.equal(nameSafe('Ödül www.kotu.com tıkla'), 'Ödül tıkla');
  assert.equal(nameSafe('Yaz bana: kotu@ornek.com'), 'Yaz bana');   // izin listesi: iki nokta da atılır
  assert.equal(nameSafe('bit.ly/x ödül kotu-site.com/a'), 'ödül');
  assert.equal(nameSafe('Uzm. Psk. Ali'), 'Uzm. Psk. Ali');
  // bilinmeyen uzantı ve gizlenmiş adres: nokta ayrılır, bağlantı olmaz
  assert.equal(nameSafe('Ödül kotu.example'), 'Ödül kotu. example');
  assert.equal(nameSafe('kotu.zip/a.b'), 'kotu. zip a. b');   // bölü izin listesinde yok
  assert.equal(nameSafe('kotu\u200b.\u200bexample'), 'kotu. example');
  assert.equal(nameSafe('kotu\uFF0Eexample'), 'kotu. example');
  assert.equal(nameSafe('kotu\u3002com'), '');
  assert.equal(nameSafe('Uzm.Psk. Ali'), 'Uzm. Psk. Ali');
  assert.equal(nameSafe('Prof. Dr. Ayşe Şahin'), 'Prof. Dr. Ayşe Şahin');
  assert.equal(nameSafe('Ayşe.'), 'Ayşe.');
  for (const x of ['a.b.c.d', 'x.y/z', 'evil.example', 'b\u00ADit.ly']) assert.ok(!/\S\.\S/.test(nameSafe(x)), nameSafe(x));
  const m = buildInviteEmail({ code: 'ABC234', token: null, expires_at: '2026-11-25T10:00:00Z', to: 'a@b.co',
    clinician: 'Ece https://kotu.example', title: 'Psikolog www.x.com', clinic: 'Klinik kotu@x.com' },
    { brand: 'Moyo', baseUrl: '', storeUrl: '', privacyUrl: '' });
  for (const part of [m.subject, m.text, m.html, m.fromName]) assert.ok(!/kotu\.example|www\.x|kotu@x/.test(part), part);
});

test('ad alanları izin listesiyle: benzer noktalar, yalıtıcılar, köşeli ayraçlı adres ve başlık enjeksiyonu (yeniden test 3)', async () => {
  const { nameSafe } = await import('./index.ts');
  const linky = (t: string) => /\S\.\S|[\/:@\[\]()<>]|https?|www/i.test(t);
  // saldırı biçimleri: bağlantıya dönüşebilecek hiçbir şey kalmaz
  for (const x of ['visit evil\uFE52com', 'www\u2024evil\u2024com', 'evil\u00B7com', 'evil\u2027com', 'evil\u02D9com', 'evil\uFF0Ecom',
                   'evil\u3002com', 'evil\uFF61com', 'evil\u2E31com', 'evil\u2E33com', '\u2067moc.live\u2069', '\u2066evil.com\u2069',
                   'hxxps[:]//evil[.]com', 'hxxp://evil.com', 'evil(dot)com', 'evil[.]com', 'e\u200Dvil.c\u200Co\u2060m', '\u202Emoc.live',
                   '\uFF45\uFF56\uFF49\uFF4C\uFF0E\uFF43\uFF4F\uFF4D', 'evil.c\u034Fom', 'evil\u061C.com', 'Ali <a href=//e>x</a>',
                   'Ece\r\nBcc: all@x.com', 'Ad\u0085Bcc: x', 'Ad\u2028Bcc: x', 'a\tb\u000Bc\u000Cd', 'wa.me/905551112233', '@evil_insta']) {
    const t = nameSafe(x);
    assert.ok(!linky(t), `${JSON.stringify(x)} → ${JSON.stringify(t)}`);
    assert.ok(!/[\r\n\u0085\u2028\u2029\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]/.test(t), JSON.stringify(t));
  }
  assert.equal(nameSafe('visit evil\uFE52com'), 'visit');
  assert.equal(nameSafe('www\u2024evil\u2024com'), '');
  assert.equal(nameSafe('\u2067moc.live\u2069'), 'moc. live');
  assert.equal(nameSafe('hxxps[:]//evil[.]com'), 'hxxps evil . com');
  assert.equal(nameSafe('Ece\r\nBcc: all@x.com'), 'Ece Bcc');
  // gerçek adlar değişmez
  for (const ok of ['Dr. Ayşe Yılmaz', 'Ayşe-Nur Öztürk', "O'Brien", 'O’Brien', 'Ada & Deniz Klinik', 'Klinik 2', 'Prof. Dr. Çağrı İnce',
                    'Uzm. Psk. Ğülşen Şahin', 'Mavi Çocuk Merkezi']) assert.equal(nameSafe(ok), ok);
  assert.equal(nameSafe('a'.repeat(300)).length, 80);
  // konu ve gönderen adında da aynı temizlik
  const b = buildInviteEmail({ ...inv, clinician: 'Ece\r\nBcc: all@x.com <script>alert(1)</script> visit evil\uFE52com',
                               title: 'Uzm.\u2067moc.live\u2069', clinic: 'Klinik "x" <a href=//e> hxxps[:]//evil[.]com' }, env);
  for (const part of [b.subject, b.fromName]) {
    assert.ok(!/[\r\n<>"]|evil\.|evil\uFE52|\[|\]|\/|:/.test(part), part);
  }
  assert.ok(!b.html.includes('<script') && !b.html.includes('<a href=//e') && !b.html.includes('evil\uFE52com'));
  assert.ok(!/evil\.com|evil\uFE52com|\u2067/.test(b.text), b.text);
  assert.equal(buildInviteEmail({ ...inv, clinician: "Dr. Ayşe O'Brien", clinic: 'Ada & Deniz Klinik' }, env).subject,
               "Dr. Ayşe O'Brien sizi Moyo uygulamasına davet ediyor");
});
