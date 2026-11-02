// Marketing deposunun GitHub Actions iş akışında çalışır (sözleşme: ortak/sozlesme/paylasim.md). Bağımlılık yok (Node 20+).
//   node gonder.mjs gonder <klasör>...    her klasör: paket.json + medya. Video: video.mp4 / video.mov [+ kapak.jpg].
//                                          Kaydırmalı ("tur": "kaydirmali"): 01.jpg, 02.jpg … (2–20, sırayla). Hikâye ("tur": "hikaye"):
//                                          video.mp4 ya da tek 01.jpg.
//   node gonder.mjs durum <çıktı.json>    onay durumu, düzeltme notları ve sonuç sayıları
// Gizli anahtar YOK: iş akışında "permissions: id-token: write" olmalı; GitHub kısa ömürlü bir kimlik belgesi verir,
// sunucu (social işlevi) bunun amy60946/marketing ana dalından geldiğini doğrular. Gönderiler yalnız TASLAK olur;
// yayın, panelde owner onayıyla.
import { appendFile, mkdir, readdir, readFile, stat, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';

const FN = process.env.SOCIAL_URL || 'https://uhelhxqgpcjemadhsifx.supabase.co/functions/v1/social';
const TYPES = { '.mp4': 'video/mp4', '.mov': 'video/quicktime', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png' };

async function idToken() {
  const url = process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const tok = process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  if (!url || !tok) throw new Error('GitHub kimliği yok: iş akışına "permissions: id-token: write" ekle (yerelde çalışmaz)');
  const r = await fetch(`${url}${url.includes('?') ? '&' : '?'}audience=pofi-paylasim`, { headers: { Authorization: `Bearer ${tok}` } });
  if (!r.ok) throw new Error(`GitHub kimliği alınamadı (${r.status})`);
  return (await r.json()).value;
}

async function call(body) {
  const r = await fetch(FN, {
    method: 'POST',
    headers: { Authorization: `Bearer ${await idToken()}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) {
    const e = new Error(j.error || `HTTP ${r.status}`);
    e.errors = j.errors;
    throw e;
  }
  return j;
}

async function upload(file) {
  const ext = file.slice(file.lastIndexOf('.')).toLowerCase();
  const contentType = TYPES[ext];
  if (!contentType) throw new Error(`Desteklenmeyen dosya: ${file}`);
  const { size } = await stat(file);
  const { uploadUrl, publicUrl } = await call({ action: 'upload', filename: basename(file), contentType, size });
  const put = await fetch(uploadUrl, { method: 'PUT', headers: { 'Content-Type': contentType }, body: await readFile(file) });
  if (!put.ok) throw new Error(`Yükleme başarısız (${put.status}): ${file}`);
  return publicUrl;
}

const first = (dir, names) => names.map((n) => join(dir, n)).find((f) => existsSync(f));

async function gonder(dirs) {
  const results = [];
  for (const dir of dirs) {
    try {
      const paket = JSON.parse(await readFile(join(dir, 'paket.json'), 'utf8'));
      const tur = paket.tur ?? 'video';
      const video = first(dir, ['video.mp4', 'video.mov']);
      const images = (await readdir(dir)).filter((f) => /^\d{2}\.(jpe?g|png)$/i.test(f)).sort().map((f) => join(dir, f));
      if (tur === 'video' && !video) throw new Error('video.mp4 ya da video.mov yok');
      if (tur === 'kaydirmali' && images.length < 2) throw new Error('kaydırmalı için en az 2 görsel (01.jpg, 02.jpg …)');
      if (tur === 'hikaye' && !video && !images.length) throw new Error('hikâye için video.mp4 ya da 01.jpg');
      if (video && tur !== 'kaydirmali') paket.video = await upload(video);
      if (tur === 'kaydirmali' || (tur === 'hikaye' && !video)) {
        paket.gorseller = [];
        for (const f of tur === 'hikaye' ? images.slice(0, 1) : images) paket.gorseller.push(await upload(f));
      }
      const kapak = tur === 'video' ? first(dir, ['kapak.jpg', 'kapak.jpeg', 'kapak.png']) : null;
      if (kapak) paket.kapak = await upload(kapak);
      const r = await call({ action: 'submit', paket });
      results.push({ klasor: dir, paket: paket.id, surum: paket.surum ?? 1, tur, id: r.id, uyarilar: r.warnings ?? [], zaten_vardi: !!r.existing });
      console.log(`✓ ${paket.id}: onay kuyruğunda (${r.id})${r.warnings?.length ? ' · uyarı: ' + r.warnings.join('; ') : ''}`);
    } catch (e) {
      results.push({ klasor: dir, hata: e.message, ayrinti: e.errors ?? [] });
      console.error(`✗ ${dir}: ${e.message}`);
      for (const x of e.errors ?? []) console.error(`   - ${x}`);
    }
  }
  return results;
}

const [cmd, ...args] = process.argv.slice(2);
if (cmd === 'gonder' && args.length) {
  const res = await gonder(args);
  await writeFile('paylasim-sonuc.json', JSON.stringify(res, null, 2) + '\n');
  if (res.some((r) => r.hata)) process.exit(1);
} else if (cmd === 'durum' && args.length === 1) {
  const { posts, usage } = await call({ action: 'status' });
  await writeFile(args[0], JSON.stringify({ guncellendi: new Date().toISOString(), hak: usage ?? null, gonderiler: posts }, null, 2) + '\n');
  // Ölçüm geçmişi: yayımlanan her gönderi için paylasim/olcum/<paket>.jsonl'a zaman damgalı bir satır (karşılaştırma için)
  const dir = join(dirname(args[0]), 'olcum');
  for (const p of posts.filter((x) => x.measuredAt && x.paket)) {
    await mkdir(dir, { recursive: true });
    await appendFile(join(dir, `${p.paket}.jsonl`),
      JSON.stringify({ t: p.measuredAt, id: p.id, surum: p.surum, toplam: p.stats ?? null, platformlar: p.statsByPlatform ?? [] }) + '\n');
  }
  const hak = usage?.limit != null ? ` · bu dönem ${usage.used ?? '?'} / ${usage.limit} gönderi hakkı` : '';
  console.log(`${posts.length} gönderi → ${args[0]}${hak}`);
} else {
  console.error('Kullanım: node gonder.mjs gonder <klasör>... | node gonder.mjs durum <çıktı.json>');
  process.exit(2);
}
