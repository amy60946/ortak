// Marketing deposunun GitHub Actions iş akışında çalışır (sözleşme: ortak/sozlesme/paylasim.md). Bağımlılık yok (Node 20+).
//   node gonder.mjs gonder <klasör>...    her klasör: paket.json + video.mp4 (ya da video.mov) [+ kapak.jpg / kapak.png]
//   node gonder.mjs durum <çıktı.json>    onay durumu, düzeltme notları ve sonuç sayıları
// Gizli anahtar YOK: iş akışında "permissions: id-token: write" olmalı; GitHub kısa ömürlü bir kimlik belgesi verir,
// sunucu (social işlevi) bunun amy60946/marketing ana dalından geldiğini doğrular. Gönderiler yalnız TASLAK olur;
// yayın, panelde owner onayıyla.
import { readFile, stat, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { basename, join } from 'node:path';

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
      const video = first(dir, ['video.mp4', 'video.mov']);
      if (!video) throw new Error('video.mp4 ya da video.mov yok');
      paket.video = await upload(video);
      const kapak = first(dir, ['kapak.jpg', 'kapak.jpeg', 'kapak.png']);
      if (kapak) paket.kapak = await upload(kapak);
      const r = await call({ action: 'submit', paket });
      results.push({ klasor: dir, paket: paket.id, surum: paket.surum ?? 1, id: r.id, uyarilar: r.warnings ?? [], zaten_vardi: !!r.existing });
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
  const { posts } = await call({ action: 'status' });
  await writeFile(args[0], JSON.stringify({ guncellendi: new Date().toISOString(), gonderiler: posts }, null, 2) + '\n');
  console.log(`${posts.length} gönderi → ${args[0]}`);
} else {
  console.error('Kullanım: node gonder.mjs gonder <klasör>... | node gonder.mjs durum <çıktı.json>');
  process.exit(2);
}
