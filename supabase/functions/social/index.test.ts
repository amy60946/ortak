// Çalıştır: node --experimental-strip-types --test supabase/functions/social/*.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  AUDIENCE, GITHUB_ISSUER, handle, type Deps, type Jwk, approveBody, changesBody, draftBody, groupOf, idempotencyKey, parseApproval, parsePaket, pickAccounts, summarize, warnings,
} from './index.ts';

const good = () => ({
  id: '2026-11-01-uyku-rutini', baslik: 'Uyku rutini: 3 adım', video: 'https://media.zernio.com/v.mp4',
  platformlar: ['instagram', 'tiktok', 'youtube'],
  metin: { instagram: 'IG metni #uyku', tiktok: 'TikTok metni', youtube: 'YouTube açıklaması' },
  youtube_baslik: 'Uyku rutini: 3 adım', onerilen_zaman: '2026-11-01T20:30:00+03:00',
  yapay_zeka: true, ticari: false, kaynaklar: ['Mindell ve ark., 2015'],
  kontrol: { saglik_iddiasi_yok: true, cocuga_cagri_yok: true, gercek_cocuk_verisi_yok: true, muzik_telifsiz: true },
});
const NOW = new Date('2026-10-30T10:00:00Z');

test('geçerli paket: sürüm varsayılan 1, metinler kırpılır', () => {
  const r = parsePaket({ ...good(), metin: { ...good().metin, instagram: '  IG  ' } });
  assert.deepEqual(r.errors, []);
  assert.equal(r.paket!.surum, 1);
  assert.equal(r.paket!.metin.instagram, 'IG');
});

test('eksikler tek tek söylenir', () => {
  const raw: Record<string, unknown> = { ...good(), id: 'A B', video: 'http://x', platformlar: ['instagram', 'x'], metin: {},
    youtube_baslik: undefined, onerilen_zaman: '2026-11-01 20:30', kontrol: { saglik_iddiasi_yok: true } };
  delete raw.yapay_zeka;
  const e = parsePaket(raw).errors.join('\n');
  for (const s of ['id:', 'video:', '"x" desteklenmiyor', 'metin.instagram', 'onerilen_zaman', 'yapay_zeka', 'kontrol.cocuga_cagri_yok', 'kontrol.muzik_telifsiz'])
    assert.ok(e.includes(s), s);
  assert.ok(!e.includes('kontrol.saglik_iddiasi_yok'));
});

test('YouTube başlığı: gerekli, 100 karakter, açılı ayraç yok', () => {
  assert.ok(parsePaket({ ...good(), youtube_baslik: '' }).errors[0].startsWith('youtube_baslik'));
  assert.ok(parsePaket({ ...good(), youtube_baslik: 'a<b' }).errors[0].startsWith('youtube_baslik'));
  assert.deepEqual(parsePaket({ ...good(), platformlar: ['instagram'], youtube_baslik: '' }).errors, []);
});

test('uyarılar: sağlık/garanti/çocuğa çağrı; kaynaksız araştırma', () => {
  const p = parsePaket({ ...good(), kaynaklar: [], metin: { ...good().metin, instagram: 'Araştırmaya göre bu yöntem DEHB\'yi iyileştirir. Hemen indir!' } }).paket!;
  const w = warnings(p);
  assert.ok(w.includes('Tedavi / iyileştirme gibi okunabilecek ifade'));
  assert.ok(w.includes('Çocuğa doğrudan çağrı olabilir'));
  assert.ok(w.includes('Araştırmaya dayanıyor ama kaynak yok'));
  assert.deepEqual(warnings(parsePaket(good()).paket!), []);
});

test('taslak: isDraft, hesaplar, YZ etiketleri, TikTok onay alanları kapalı', () => {
  const p = parsePaket(good()).paket!;
  assert.throws(() => draftBody(p, { instagram: 'a1' }, 'r@s'), /bağlı hesap yok: tiktok, youtube/);
  const b = draftBody(p, { instagram: 'a1', tiktok: 'a2', youtube: 'a3' }, 'amy60946/marketing@abc1234', NOW);
  assert.equal(b.isDraft, true);
  assert.equal(b.scheduledFor, '2026-11-01T20:30:00+03:00');
  assert.equal(b.timezone, 'Europe/Istanbul');
  const by = Object.fromEntries(b.platforms.map((x) => [x.platform, x]));
  assert.equal(by.instagram.accountId, 'a1');
  assert.equal(by.instagram.platformSpecificData.isAiGenerated, true);
  assert.equal(by.tiktok.platformSpecificData.videoMadeWithAi, true);
  assert.equal(by.tiktok.platformSpecificData.contentPreviewConfirmed, false);
  assert.equal(by.tiktok.platformSpecificData.expressConsentGiven, false);
  assert.equal(by.tiktok.platformSpecificData.commercialContentType, 'none');
  assert.equal(by.youtube.platformSpecificData.madeForKids, false);
  assert.equal(by.youtube.platformSpecificData.containsSyntheticMedia, true);
  assert.equal(by.youtube.platformSpecificData.title, 'Uyku rutini: 3 adım');
  assert.equal(b.metadata.kaynak, 'marketing');
  assert.equal(b.metadata.durum, 'onay_bekliyor');
  assert.equal(b.metadata.gonderim, NOW.toISOString());
});

test('onay: gelecekte saat, platform ve metin; YZ seçimi zorunlu', () => {
  const ok = { scheduledFor: '2026-10-30T20:00:00+03:00', platforms: ['instagram'], captions: { instagram: 'x' }, yapay_zeka: false };
  assert.deepEqual(parseApproval(ok, NOW).errors, []);
  assert.match(parseApproval({ ...ok, scheduledFor: '2026-10-30T10:01:00Z' }, NOW).errors[0], /2 dakika/);
  assert.match(parseApproval({ ...ok, scheduledFor: '2027-06-01T10:00:00Z' }, NOW).errors[0], /180 gün/);
  assert.match(parseApproval({ ...ok, captions: {} }, NOW).errors[0], /instagram metni boş/);
  assert.match(parseApproval({ ...ok, yapay_zeka: undefined }, NOW).errors[0], /Yapay zekâ/);
  assert.match(parseApproval({ ...ok, platforms: [] }, NOW).errors[0], /En az bir/);
});

test('onay gövdesi: planlı, düzeltilmiş metin, TikTok önizleme + rıza açık, eski metadata korunur', () => {
  const p = parsePaket(good()).paket!;
  const draft = { _id: 'p1', status: 'draft', ...draftBody(p, { instagram: 'a1', tiktok: 'a2', youtube: 'a3' }, 'r', NOW) };
  const a = parseApproval({ scheduledFor: '2026-10-31T18:00:00+03:00', platforms: ['tiktok', 'youtube'],
    captions: { tiktok: 'Düzeltilmiş', youtube: 'Açıklama' }, yapay_zeka: false }, NOW).approval!;
  const b = approveBody(draft, a, NOW);
  assert.equal(b.isDraft, false);
  assert.deepEqual(b.platforms.map((x) => x.platform), ['tiktok', 'youtube']);
  const tt = b.platforms[0];
  assert.equal(tt.accountId, 'a2');
  assert.equal(tt.customContent, 'Düzeltilmiş');
  assert.equal(tt.platformSpecificData.contentPreviewConfirmed, true);
  assert.equal(tt.platformSpecificData.expressConsentGiven, true);
  assert.equal(tt.platformSpecificData.videoMadeWithAi, false);
  assert.equal(b.platforms[1].platformSpecificData.title, 'Uyku rutini: 3 adım');
  assert.equal(b.metadata.durum, 'onaylandi');
  assert.equal(b.metadata.paket, '2026-11-01-uyku-rutini');
  // taslakta olmayan platform eklenemez (hesap yok)
  const a2 = parseApproval({ ...a, platforms: ['facebook'], captions: { facebook: 'x' } }, NOW).approval!;
  assert.throws(() => approveBody(draft, a2, NOW), /hesabı yok: facebook/);
  // hesap nesne olarak gelirse de çalışır
  const d2 = { ...draft, platforms: [{ platform: 'tiktok', accountId: { _id: 'a9' } }] };
  const a3 = parseApproval({ ...a, platforms: ['tiktok'], captions: { tiktok: 'x' } }, NOW).approval!;
  assert.equal(approveBody(d2, a3, NOW).platforms[0].accountId, 'a9');
});

test('düzeltme isteği: not metadata\'ya, durum düzeltme; servisin defter alanları geri gönderilmez', () => {
  const b = changesBody({ metadata: { paket: 'x', durum: 'onay_bekliyor', usageCounted: true, hidden: false } }, '  kaynak ekle ', NOW);
  assert.deepEqual(b.metadata, { paket: 'x', durum: 'duzeltme', duzeltme_notu: 'kaynak ekle', duzeltme: NOW.toISOString() });
});

test('gruplar ve özet', () => {
  assert.equal(groupOf({ status: 'draft', metadata: {} }), 'onay');
  assert.equal(groupOf({ status: 'draft', metadata: { durum: 'duzeltme' } }), 'duzeltme');
  assert.equal(groupOf({ status: 'scheduled' }), 'planli');
  assert.equal(groupOf({ status: 'published' }), 'yayinda');
  assert.equal(groupOf({ status: 'partial', platforms: [{ status: 'published' }, { status: 'failed' }] }), 'sorun');
  assert.equal(groupOf({ status: 'failed' }), 'sorun');
  const s = summarize({ _id: 'p1', status: 'published', title: 'T', mediaItems: [{ url: 'https://v' }], content: 'genel',
    metadata: { kaynak: 'marketing', paket: 'x', yapay_zeka: true, uyarilar: ['u'] },
    platforms: [{ platform: 'instagram', status: 'published', platformPostUrl: 'https://ig/p' }, { platform: 'tiktok', customContent: 'tt' }] });
  assert.equal(s.fromMarketing, true);
  assert.equal(s.ai, true);
  assert.equal(s.video, 'https://v');
  assert.equal(s.platforms[0].caption, 'genel');
  assert.equal(s.platforms[1].caption, 'tt');
  assert.equal(s.platforms[0].url, 'https://ig/p');
});

test('hesap seçimi: yeniden bağlanması gereken ve kapalı hesap atlanır', () => {
  assert.deepEqual(pickAccounts([
    { _id: 'x1', platform: 'instagram', isActive: true, needsReconnection: true },
    { _id: 'x2', platform: 'instagram', isActive: true },
    { _id: 'x3', platform: 'tiktok', isActive: true, enabled: false },
    { _id: 'x4', platform: 'twitter', isActive: true },
  ]), { instagram: 'x2' });
});

test('aynı paket + sürüm aynı anahtarı verir (UUID biçimi)', async () => {
  const a = await idempotencyKey('x', 1);
  assert.equal(a, await idempotencyKey('x', 1));
  assert.notEqual(a, await idempotencyKey('x', 2));
  assert.match(a, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
});

// --- İstekler (sahte paylaşım servisi, gerçek RSA imzalı GitHub kimliği) ---

const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');

async function keys() {
  const k = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const pub = { ...(await crypto.subtle.exportKey('jwk', k.publicKey)), kid: 'k1' } as Jwk;
  const sign = async (claims: Record<string, unknown>, kid = 'k1') => {
    const h = enc({ alg: 'RS256', kid, typ: 'JWT' });
    const p = enc({ iss: GITHUB_ISSUER, aud: AUDIENCE, repository: 'amy60946/marketing', ref: 'refs/heads/main', sha: 'abcdef1234',
                    exp: NOW.getTime() / 1000 + 300, nbf: NOW.getTime() / 1000 - 10, ...claims });
    const s = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', k.privateKey, new TextEncoder().encode(`${h}.${p}`)));
    return `${h}.${p}.${Buffer.from(s).toString('base64url')}`;
  };
  return { pub, sign };
}

// Bellekte sahte paylaşım servisi
function fakeZernio() {
  const posts = new Map<string, any>();
  const calls: string[] = [];
  let n = 0;
  const accounts = [
    { _id: 'acc_ig', platform: 'instagram', username: 'pofi', isActive: true },
    { _id: 'acc_tt', platform: 'tiktok', username: 'pofi', isActive: true },
    { _id: 'acc_yt', platform: 'youtube', username: 'Pofi', isActive: true, needsReconnection: true },
  ];
  const zernio: Deps['zernio'] = async (method, path, body, headers) => {
    calls.push(`${method} ${path}${headers?.['Idempotency-Key'] ? ' +key' : ''}`);
    const m = /^\/v1\/posts\/([^/?]+)$/.exec(path);
    if (method === 'GET' && path === '/v1/accounts') return { status: 200, data: { accounts } };
    if (method === 'POST' && path === '/v1/media/presign') return { status: 200, data: { uploadUrl: 'https://up/1', publicUrl: 'https://media/1.mp4' } };
    if (method === 'GET' && path.startsWith('/v1/posts?')) return { status: 200, data: { posts: [...posts.values()].reverse() } };
    if (method === 'POST' && path === '/v1/posts') {
      const id = `p${++n}`;
      const post = { _id: id, status: (body as any).isDraft ? 'draft' : 'scheduled', createdAt: NOW.toISOString(), ...(body as any) };
      posts.set(id, post);
      return { status: 200, data: { post } };
    }
    if (m && method === 'GET') return posts.has(m[1]) ? { status: 200, data: { post: posts.get(m[1]) } } : { status: 404, data: { error: 'Post not found' } };
    if (m && method === 'PUT') {
      const p = { ...posts.get(m[1]), ...(body as any) };
      if ((body as any).isDraft === false) p.status = 'scheduled';
      posts.set(m[1], p);
      return { status: 200, data: { post: p } };
    }
    if (m && method === 'DELETE') { posts.delete(m[1]); return { status: 200, data: {} }; }
    if (method === 'GET' && path.startsWith('/v1/analytics')) return { status: 200, data: { analytics: { views: 120, likes: 9 } } };
    return { status: 400, data: { error: `beklenmeyen ${method} ${path}` } };
  };
  return { zernio, posts, calls, accounts };
}

async function setup(role: string | null = 'owner') {
  const k = await keys();
  const z = fakeZernio();
  const logs: any[] = [];
  const deps: Deps = {
    zernio: z.zernio,
    checkAdmin: async (action, ref = null, reason = null, after = null, dry = true) => {
      if (!role) throw new Error('Yetkisiz');
      if (action !== 'view' && role !== 'owner') throw new Error(`Bu işlem için rolün yetmiyor (${role})`);
      if (action !== 'view' && String(reason ?? '').trim().length < 3) throw new Error('Gerekçe yaz (en az 3 harf)');
      if (!dry) logs.push({ action, ref, reason, after });
      return role;
    },
    githubKeys: async () => [k.pub],
    repo: 'amy60946/marketing',
    now: () => NOW,
  };
  const gh = async (body: unknown, claims = {}) => handle(`Bearer ${await k.sign(claims)}`, body, deps);
  const admin = (body: unknown) => handle('Bearer supabase-admin-jwt', body, deps);
  return { k, z, logs, deps, gh, admin };
}

test('oturumsuz istek reddedilir', async () => {
  const { deps } = await setup();
  assert.equal((await handle('', { action: 'overview' }, deps)).status, 401);
});

test('GitHub kimliği: yalnız marketing deposu, ana dal, doğru kitle, geçerli imza', async () => {
  const s = await setup();
  assert.equal((await s.gh({ action: 'status' })).status, 200);
  assert.match((await s.gh({ action: 'status' }, { repository: 'baskasi/marketing' })).body.error, /Depo yetkili değil/);
  assert.match((await s.gh({ action: 'status' }, { ref: 'refs/heads/deneme' })).body.error, /ana daldan/);
  assert.match((await s.gh({ action: 'status' }, { aud: 'baska' })).body.error, /kitle/);
  assert.match((await s.gh({ action: 'status' }, { exp: NOW.getTime() / 1000 - 120 })).body.error, /süresi dolmuş/);
  const other = await keys();   // başka anahtarla imzalanmış, aynı kid
  assert.match((await handle(`Bearer ${await other.sign({})}`, { action: 'status' }, s.deps)).body.error, /İmza geçersiz/);
  const t = await s.k.sign({});
  const [h, , sig] = t.split('.');
  const forged = `${h}.${enc({ iss: GITHUB_ISSUER, aud: AUDIENCE, repository: 'amy60946/marketing', ref: 'refs/heads/main', exp: 9e9 })}.${sig}`;
  assert.equal((await handle(`Bearer ${forged}`, { action: 'status' }, s.deps)).status, 403);
});

test('Marketing yalnız upload/submit/status yapar; panel işlemleri yapamaz', async () => {
  const s = await setup();
  for (const action of ['approve', 'delete', 'overview', 'request_changes'])
    assert.equal((await s.gh({ action, id: 'p1', reason: 'neden olmasın' })).status, 403, action);
  assert.equal((await s.admin({ action: 'submit', paket: good() })).status, 403);
});

test('upload: tür ve boyut denetlenir, servis bağlantısı döner', async () => {
  const s = await setup();
  assert.equal((await s.gh({ action: 'upload', filename: 'a.exe', contentType: 'application/x-msdownload', size: 10 })).status, 400);
  assert.equal((await s.gh({ action: 'upload', filename: 'v.mp4', contentType: 'video/mp4', size: 0 })).status, 400);
  const r = await s.gh({ action: 'upload', filename: 'v ü.mp4', contentType: 'video/mp4', size: 1234 });
  assert.deepEqual(r.body, { uploadUrl: 'https://up/1', publicUrl: 'https://media/1.mp4' });
});

test('submit: kurala uymayan paket hata listesiyle döner; bağlı olmayan hesap söylenir', async () => {
  const s = await setup();
  const bad = await s.gh({ action: 'submit', paket: { ...good(), kontrol: {} } });
  assert.equal(bad.status, 400);
  assert.ok(bad.body.errors.length >= 4);
  // YouTube hesabı yeniden bağlanmalı → taslak açılmaz
  const r = await s.gh({ action: 'submit', paket: good() });
  assert.equal(r.status, 400);
  assert.match(r.body.error, /bağlı hesap yok: youtube/);
});

test('uçtan uca: taslak → panelde düzeltme → yeni sürüm eskisini siler → onay → planlı + denetim', async () => {
  const s = await setup();
  const paket = { ...good(), platformlar: ['instagram', 'tiktok'], metin: { instagram: 'IG', tiktok: 'TT' } };
  const r1 = await s.gh({ action: 'submit', paket });
  assert.equal(r1.status, 200, JSON.stringify(r1.body));
  assert.ok(s.z.calls.includes('POST /v1/posts +key'));
  assert.equal(s.z.posts.get(r1.body.id).status, 'draft');
  // aynı sürüm ikinci kez: yeni taslak açılmaz
  const again = await s.gh({ action: 'submit', paket });
  assert.equal(again.body.id, r1.body.id);
  assert.equal(again.body.existing, true);

  const ov = await s.admin({ action: 'overview' });
  assert.equal(ov.status, 200);
  assert.equal(ov.body.role, 'owner');
  assert.deepEqual(ov.body.accounts.map((a: any) => [a.platform, a.ok]), [['instagram', true], ['tiktok', true], ['youtube', false]]);
  assert.equal(ov.body.posts[0].group, 'onay');

  assert.equal((await s.admin({ action: 'request_changes', id: r1.body.id, reason: 'ok' })).status, 400);   // kısa gerekçe
  const ch = await s.admin({ action: 'request_changes', id: r1.body.id, reason: 'Kaynak ekle, ilk cümle uzun' });
  assert.equal(ch.status, 200);
  assert.equal(ch.body.post.group, 'duzeltme');
  const st = await s.gh({ action: 'status' });
  assert.equal(st.body.posts[0].changesNote, 'Kaynak ekle, ilk cümle uzun');

  const r2 = await s.gh({ action: 'submit', paket: { ...paket, surum: 2 } });
  assert.equal(r2.status, 200);
  assert.equal(s.z.posts.has(r1.body.id), false, 'eski sürüm silindi');

  const ap = { action: 'approve', id: r2.body.id, reason: 'Kurallara uygun', scheduledFor: '2026-10-30T20:00:00+03:00',
               platforms: ['instagram', 'tiktok'], captions: { instagram: 'IG son', tiktok: 'TT' }, yapay_zeka: true };
  assert.equal((await s.admin({ ...ap, scheduledFor: '2026-10-30T09:00:00Z' })).status, 400);   // geçmiş saat
  const ok = await s.admin(ap);
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  assert.equal(ok.body.post.group, 'planli');
  const stored = s.z.posts.get(r2.body.id);
  assert.equal(stored.platforms.find((p: any) => p.platform === 'tiktok').platformSpecificData.expressConsentGiven, true);
  assert.equal(stored.platforms.find((p: any) => p.platform === 'instagram').customContent, 'IG son');
  assert.deepEqual(s.logs.map((l) => l.action), ['request_changes', 'approve']);
  assert.equal(s.logs[1].after.scheduledFor, '2026-10-30T20:00:00+03:00');

  // planlanmış sürüm yeniden gönderilemez; onaylı taslak yeniden onaylanamaz
  assert.equal((await s.gh({ action: 'submit', paket: { ...paket, surum: 2 } })).status, 409);
  assert.equal((await s.admin(ap)).status, 409);
});

test('silme: yayındaki gönderi silinmez; taslak silinir ve kaydedilir', async () => {
  const s = await setup();
  s.z.posts.set('pub1', { _id: 'pub1', status: 'published', platforms: [], metadata: {} });
  s.z.posts.set('dr1', { _id: 'dr1', status: 'draft', platforms: [], metadata: { paket: 'x' } });
  assert.equal((await s.admin({ action: 'delete', id: 'pub1', reason: 'yanlış' })).status, 409);
  const r = await s.admin({ action: 'delete', id: 'dr1', reason: 'vazgeçildi' });
  assert.equal(r.status, 200);
  assert.equal(s.z.posts.has('dr1'), false);
  assert.deepEqual(s.logs[0].after, { status: 'draft', paket: 'x' });
  assert.equal((await s.admin({ action: 'delete', id: '../x', reason: 'vazgeçildi' })).status, 400);
});

test('yetki: viewer görür ama onaylayamaz; admin olmayan göremez', async () => {
  const v = await setup('viewer');
  assert.equal((await v.admin({ action: 'overview' })).status, 200);
  v.z.posts.set('dr1', { _id: 'dr1', status: 'draft', platforms: [], metadata: {} });
  const r = await v.admin({ action: 'delete', id: 'dr1', reason: 'vazgeçildi' });
  assert.equal(r.status, 403);
  assert.equal(v.z.posts.has('dr1'), true);
  const n = await setup(null);
  assert.equal((await n.admin({ action: 'overview' })).status, 403);
});

test('yayımlananlara sonuç sayıları eklenir', async () => {
  const s = await setup();
  s.z.posts.set('pub1', { _id: 'pub1', status: 'published', platforms: [], metadata: { kaynak: 'marketing' } });
  const st = await s.gh({ action: 'status' });
  assert.deepEqual(st.body.posts[0].stats, { views: 120, likes: 9, comments: 0, shares: 0, saves: 0 });
});
