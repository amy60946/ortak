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
  assert.equal(nameSafe('Yaz bana: kotu@ornek.com'), 'Yaz bana:');
  assert.equal(nameSafe('bit.ly/x ödül kotu-site.com/a'), 'ödül');
  assert.equal(nameSafe('Uzm. Psk. Ali'), 'Uzm. Psk. Ali');
  const m = buildInviteEmail({ code: 'ABC234', token: null, expires_at: '2026-11-25T10:00:00Z', to: 'a@b.co',
    clinician: 'Ece https://kotu.example', title: 'Psikolog www.x.com', clinic: 'Klinik kotu@x.com' },
    { brand: 'Moyo', baseUrl: '', storeUrl: '', privacyUrl: '' });
  for (const part of [m.subject, m.text, m.html, m.fromName]) assert.ok(!/kotu\.example|www\.x|kotu@x/.test(part), part);
});
