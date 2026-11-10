// node --test tools/paylasim/  (bağımlılık yok)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { takvim, takvimMetni, trZaman } from './takvim.mjs';

const now = new Date('2026-11-10T09:00:00Z');   // 10 Kasım Salı 12:00 Türkiye
const p = (o) => ({ id: o.paket, title: o.paket, tur: 'video', surum: 1, platforms: [{ platform: 'instagram', status: 'pending' }], ...o });
const posts = [
  p({ paket: 'eski', group: 'yayinda', status: 'published', scheduledFor: '2026-10-20T15:00:00.000Z' }),                 // aralık dışı
  p({ paket: 'dun', group: 'yayinda', status: 'published', scheduledFor: '2026-11-09T15:00:00.000Z',
      platforms: [{ platform: 'instagram', status: 'published', url: 'https://instagram.com/p/x' }, { platform: 'tiktok', status: 'published', url: 'https://tiktok.com/v/y' }] }),
  p({ paket: 'yarin', group: 'planli', status: 'scheduled', scheduledFor: '2026-11-11T18:00:00.000Z' }),                 // 21:00 TR
  p({ paket: 'onerilen', group: 'onay', status: 'draft', scheduledFor: '2026-11-11T09:30:00+03:00', tur: 'kaydirmali' }),
  p({ paket: 'gecen', group: 'onay', status: 'draft', scheduledFor: '2026-11-10T08:00:00+03:00' }),
  p({ paket: 'duzelt', group: 'duzeltme', status: 'draft', scheduledFor: '2026-11-13T20:00:00+03:00', changesNote: 'Metni kısalt', surum: 2 }),
  p({ paket: 'saatsiz', group: 'onay', status: 'draft', scheduledFor: null }),
  p({ paket: 'bozuk', group: 'sorun', status: 'failed', scheduledFor: '2026-11-12T10:00:00.000Z' }),
];

test('Türkiye saati: gün adı, tarih, saat', () => {
  assert.deepEqual(trZaman('2026-11-11T18:00:00.000Z'), { tarih: '2026-11-11', gun: '11 Kasım Çarşamba', saat: '21:00' });
  assert.deepEqual(trZaman('2026-11-10T22:30:00Z'), { tarih: '2026-11-11', gun: '11 Kasım Çarşamba', saat: '01:30' });   // gün dönümü
  assert.equal(trZaman('bozuk'), null);
});

test('gün gün sıralı plan, son 7 gün + ileri tarihler', () => {
  const t = takvim(posts, now);
  assert.deepEqual(t.gunler.map((g) => g.tarih), ['2026-11-09', '2026-11-10', '2026-11-11', '2026-11-12', '2026-11-13']);
  assert.ok(t.gunler.find((g) => g.tarih === '2026-11-10').bugun);
  assert.deepEqual(t.gunler.find((g) => g.tarih === '2026-11-11').gonderiler.map((k) => k.paket), ['onerilen', 'yarin']);   // saat sırası
  assert.ok(!JSON.stringify(t.gunler).includes('"eski"'));
});

test('kesin saat ile önerilen saat ayrılır; geçmiş öneri işaretlenir', () => {
  const t = takvim(posts, now);
  const k = Object.fromEntries(t.gunler.flatMap((g) => g.gonderiler).map((x) => [x.paket, x]));
  assert.equal(k.yarin.kesin, true);
  assert.equal(k.yarin.satir, '21:00 · Planlı · yarin s1 · video · Instagram');
  assert.equal(k.onerilen.kesin, false);
  assert.equal(k.onerilen.satir, '09:30 · Onay bekliyor (önerilen saat) · onerilen s1 · kaydırmalı · Instagram');
  assert.equal(k.gecen.gecikti, true);
  assert.match(k.gecen.satir, /önerilen saat geçti/);
  assert.equal(k.duzelt.duzeltme_notu, 'Metni kısalt');
  assert.equal(k.duzelt.durum, 'Düzeltme istendi');
  assert.deepEqual(k.dun.baglantilar, ['https://instagram.com/p/x', 'https://tiktok.com/v/y']);
  assert.equal(k.dun.satir, '18:00 · Yayında · dun s1 · video · Instagram + TikTok');
  assert.deepEqual(t.saatsiz.map((x) => x.paket), ['saatsiz']);
});

test('özet ve boş günler (sorunlu gönderi günü doldurmaz)', () => {
  const t = takvim(posts, now, { ileriGun: 5 });
  assert.deepEqual(t.ozet, { planli: 1, onay_bekliyor: 3, duzeltme_istendi: 1, sorun: 1,
    siradaki_yayin: '11 Kasım Çarşamba 21:00 · Planlı · yarin s1 · video · Instagram', son_planli_gun: '11 Kasım Çarşamba', bos_gun_sayisi: 2 });
  assert.deepEqual(t.bos_gunler, ['12 Kasım Perşembe', '14 Kasım Cumartesi']);
});

test('boş liste ve iş akışı metni', () => {
  const t = takvim([], now, { ileriGun: 2 });
  assert.deepEqual(t.gunler, []);
  assert.equal(t.ozet.siradaki_yayin, null);
  assert.equal(takvimMetni(t), 'Boş günler (2): 10 Kasım Salı, 11 Kasım Çarşamba');
  const m = takvimMetni(takvim(posts, now));
  assert.match(m, /^10 Kasım Salı \(bugün\)/);
  assert.ok(!m.includes('9 Kasım Pazartesi'));   // yalnız yayımlanmışların günü metinde yok
});
