// Çalıştır: node --experimental-strip-types --test supabase/functions/invite-email/email.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildInviteEmail, headerSafe } from './index.ts';

const inv = { code: 'ABC123', token: 'f'.repeat(32), expires_at: '2026-10-29T15:30:00Z', to: 'aile@ornek.com',
              clinician: 'Ece Kaya', title: 'Klinik Psikolog', clinic: 'Mavi Çocuk Merkezi' };
const env = { brand: '', baseUrl: '', storeUrl: '', privacyUrl: '' };

test('konu: ad var, unvan yok; gövdede unvan + ad + kod', () => {
  const b = buildInviteEmail(inv, env);
  assert.equal(b.subject, 'Ece Kaya sizi ParentApp uygulamasına davet ediyor');
  assert.ok(b.text.includes('Klinik Psikolog Ece Kaya (Mavi Çocuk Merkezi) sizi ParentApp uygulamasına ABC123 koduyla davet ediyor.'));
  assert.ok(b.html.includes('<strong>Klinik Psikolog Ece Kaya</strong> (Mavi Çocuk Merkezi)'));
  assert.ok(b.html.includes('>ABC123<'));
  assert.equal(b.fromName, 'Ece Kaya · ParentApp');
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
  assert.ok(a.text.includes('"Davet kodum var"'));
  const b = buildInviteEmail(inv, { ...env, baseUrl: 'https://ornek.com/d', storeUrl: 'https://apps.apple.com/x', privacyUrl: 'https://ornek.com/kvkk' });
  assert.ok(b.text.includes(`https://ornek.com/d/${'f'.repeat(32)}`));
  assert.ok(b.html.includes('Daveti aç') && b.html.includes('https://ornek.com/kvkk'));
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
