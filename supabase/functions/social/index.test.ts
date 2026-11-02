// Çalıştır: node --experimental-strip-types --test supabase/functions/social/*.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  AUDIENCE, GITHUB_ISSUER, entry, feedbackComment, handle, metrics, notifyGithub, tiktokPhotoTitle, usageOf, type Deps, type Jwk, approveBody, changesBody, draftBody, groupOf, idempotencyKey, parseApproval, parsePaket, pickAccounts, summarize, warnings,
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
  assert.equal('scheduledFor' in b, false, 'taslağa saat verilmez');
  assert.equal(b.metadata.onerilen_zaman, '2026-11-01T20:30:00+03:00');
  assert.equal(summarize({ _id: 'x', status: 'draft', ...b }).scheduledFor, '2026-11-01T20:30:00+03:00', 'panel öneriyi görür');
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
  const told: { kind: string; text: string }[] = [];
  const gh = async (body: unknown, claims = {}) => handle(`Bearer ${await k.sign(claims)}`, body, deps);
  const admin = (body: unknown) => handle('Bearer supabase-admin-jwt', body, deps);
  return { k, z, logs, deps, gh, admin, told };
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
  assert.equal(st.body.posts[0].stats.views, 120);
  assert.equal(st.body.posts[0].stats.likes, 9);
  assert.equal(st.body.posts[0].measuredAt, NOW.toISOString());
  assert.deepEqual(st.body.posts[0].statsByPlatform, []);
});

test('geri bildirim yorumu: düzeltme notu alıntılanır, sonraki sürüm söylenir, makine satırı var', () => {
  const post = { _id: 'p9', title: 'T', metadata: { kaynak: 'marketing', paket: 'deneme-1', surum: 1, usageCounted: true } };
  const t = feedbackComment('duzeltme', post, { note: 'Açıklamadan YZ satırını çıkar\nkısa olsun' });
  assert.ok(t.startsWith('✏️ **Düzeltme istendi** · `deneme-1` sürüm 1'));
  assert.ok(t.includes('> Açıklamadan YZ satırını çıkar\n> kısa olsun'));
  assert.ok(t.includes('`"surum": 2`'));
  assert.ok(t.endsWith('<!-- paylasim:{"olay":"duzeltme","id":"p9","paket":"deneme-1","surum":1} -->'));
  assert.ok(feedbackComment('onay', post, { scheduledFor: '2026-10-29T20:30:00+03:00', platforms: ['instagram', 'tiktok'] })
    .includes('Yayın: 2026-10-29T20:30:00+03:00 · instagram, tiktok'));
  assert.ok(feedbackComment('silindi', post, { note: 'vazgeçildi' }).includes('> vazgeçildi'));
});

test('panel olayı Marketing\'e bildirilir; bildirim hatası işlemi bozmaz; anahtar yoksa bildirim kapalı', async () => {
  const s = await setup();
  const paket = { ...good(), platformlar: ['instagram', 'tiktok'], metin: { instagram: 'IG', tiktok: 'TT' } };
  // anahtar yok → notify null
  const r0 = await s.gh({ action: 'submit', paket });
  const n0 = await s.admin({ action: 'request_changes', id: r0.body.id, reason: 'Kaynak ekle' });
  assert.equal(n0.status, 200);
  assert.equal(n0.body.notify, null);
  // anahtar var → yorum
  s.deps.notify = async (kind, text) => { s.told.push({ kind, text }); };
  const r1 = await s.gh({ action: 'submit', paket: { ...paket, surum: 2 } });
  const n1 = await s.admin({ action: 'request_changes', id: r1.body.id, reason: 'İlk cümle uzun' });
  assert.deepEqual(n1.body.notify, { ok: true });
  assert.equal(s.told[0].kind, 'duzeltme');
  assert.ok(s.told[0].text.includes('> İlk cümle uzun'));
  assert.ok(s.told[0].text.includes('`"surum": 3`'));
  // onay da bildirilir
  const r2 = await s.gh({ action: 'submit', paket: { ...paket, surum: 3 } });
  const ap = await s.admin({ action: 'approve', id: r2.body.id, reason: 'Uygun', scheduledFor: '2026-10-30T20:00:00+03:00',
    platforms: ['instagram'], captions: { instagram: 'IG' }, yapay_zeka: true });
  assert.deepEqual(ap.body.notify, { ok: true });
  assert.equal(s.told[1].kind, 'onay');
  // GitHub hatası: işlem yine başarılı, panel nedenini görür
  s.deps.notify = async () => { throw new Error('GitHub 401 (anahtar ya da yetki)'); };
  s.z.posts.set('dr9', { _id: 'dr9', status: 'draft', platforms: [], metadata: { kaynak: 'marketing', paket: 'x' } });
  const del = await s.admin({ action: 'delete', id: 'dr9', reason: 'vazgeçildi' });
  assert.equal(del.status, 200);
  assert.deepEqual(del.body.notify, { ok: false, error: 'GitHub 401 (anahtar ya da yetki)' });
  // Zernio'da elle açılmış gönderi Marketing'e bildirilmez
  s.z.posts.set('dr10', { _id: 'dr10', status: 'draft', platforms: [], metadata: {} });
  assert.equal((await s.admin({ action: 'delete', id: 'dr10', reason: 'vazgeçildi' })).body.notify, null);
});

test('GitHub bildirimi: açık geri bildirim PR\'ını bulur, yorum yazar, iş akışını çalıştırır; PR yoksa söyler', async () => {
  const real = globalThis.fetch;
  const calls: string[] = [];
  let prs: unknown[] = [{ number: 7 }];
  globalThis.fetch = (async (url: string, init?: RequestInit) => {
    calls.push(`${init?.method ?? 'GET'} ${url} ${(init?.headers as Record<string, string>)?.Authorization ?? ''} ${init?.body ?? ''}`);
    if (url.includes('/pulls?')) return new Response(JSON.stringify(prs), { status: 200 });
    if (url.endsWith('/comments')) return new Response('{}', { status: 201 });
    return new Response(null, { status: 204 });
  }) as typeof fetch;
  try {
    await notifyGithub('tok', 'amy60946/marketing')('duzeltme', 'not');
    assert.equal(calls[0], 'GET https://api.github.com/repos/amy60946/marketing/pulls?state=open&head=amy60946:paylasim-geri-bildirim Bearer tok ');
    assert.equal(calls[1], 'POST https://api.github.com/repos/amy60946/marketing/issues/7/comments Bearer tok {"body":"not"}');
    assert.equal(calls[2], 'POST https://api.github.com/repos/amy60946/marketing/actions/workflows/paylasim.yml/dispatches Bearer tok {"ref":"main"}');
    prs = [];
    await assert.rejects(notifyGithub('tok', 'amy60946/marketing')('duzeltme', 'not'), /açık geri bildirim PR'ı yok/);
  } finally {
    globalThis.fetch = real;
  }
});

const img = (n: number) => Array.from({ length: n }, (_, i) => `https://media.zernio.com/${String(i + 1).padStart(2, '0')}.jpg`);
const base = () => { const g = good() as Record<string, unknown>; delete g.video; delete g.youtube_baslik; return g; };

test('kaydırmalı: 2–20 görsel (Facebook varsa 10), yalnız Instagram/TikTok/Facebook, video olmaz', () => {
  const k = { ...base(), tur: 'kaydirmali', gorseller: img(5), platformlar: ['instagram', 'tiktok'], metin: { instagram: 'IG', tiktok: 'TT' } };
  assert.deepEqual(parsePaket(k).errors, []);
  assert.match(parsePaket({ ...k, gorseller: img(1) }).errors.join(), /2–20 görsel \(1\)/);
  assert.match(parsePaket({ ...k, gorseller: img(21) }).errors.join(), /2–20/);
  assert.match(parsePaket({ ...k, gorseller: img(11), platformlar: ['facebook'], metin: { facebook: 'x' } }).errors.join(), /2–10/);
  assert.match(parsePaket({ ...k, platformlar: ['youtube'], metin: { youtube: 'x' }, youtube_baslik: 'y' }).errors.join(), /"youtube" kaydirmali türünde yok/);
  assert.match(parsePaket({ ...k, video: 'https://v.mp4' }).errors.join(), /kaydırmalıda olmaz/);
  assert.match(parsePaket({ ...k, tur: 'slayt' }).errors.join(), /tur: video, kaydirmali, hikaye/);
});

test('kaydırmalı taslak: görseller sırayla; TikTok fotoğraf (başlık 90, tam metin açıklamada, düet/YZ alanı yok)', () => {
  const long = 'Akşam rutini için beş küçük adım: hepsi birlikte ve sırayla, telaşsız, oyun gibi; sonunda kitap var ve ışıklar kısılır\nİkinci satır';
  const p = parsePaket({ ...base(), tur: 'kaydirmali', gorseller: img(3), platformlar: ['instagram', 'tiktok'], metin: { instagram: 'IG', tiktok: long } }).paket!;
  const b = draftBody(p, { instagram: 'a1', tiktok: 'a2' }, 'r', NOW);
  assert.deepEqual(b.mediaItems, img(3).map((url) => ({ type: 'image', url })));
  const tt = b.platforms.find((x) => x.platform === 'tiktok')!;
  assert.equal(tt.customContent!.length, 90);
  assert.ok(tt.customContent!.endsWith('…'));
  assert.equal((tt.platformSpecificData as Record<string, unknown>).description, long);
  assert.equal((tt.platformSpecificData as Record<string, unknown>).mediaType, 'photo');
  assert.equal('allowDuet' in tt.platformSpecificData, false);
  assert.equal('videoMadeWithAi' in tt.platformSpecificData, false);
  const ig = b.platforms.find((x) => x.platform === 'instagram')!;
  assert.equal('shareToFeed' in ig.platformSpecificData, false);
  assert.equal(b.metadata.tur, 'kaydirmali');
  // onay: TikTok rıza alanları açılır, panelde tam metin görünür
  const draft = { _id: 'k1', status: 'draft', ...b };
  const sm = summarize(draft);
  assert.equal(sm.tur, 'kaydirmali');
  assert.deepEqual(sm.images, img(3));
  assert.equal(sm.video, null);
  assert.equal(sm.platforms.find((x) => x.platform === 'tiktok')!.caption, long);
  const a = parseApproval({ scheduledFor: '2026-10-30T20:00:00+03:00', platforms: ['tiktok'], captions: { tiktok: 'Kısa' }, yapay_zeka: false }, NOW, 'kaydirmali').approval!;
  const ap = approveBody(draft, a, NOW).platforms[0];
  assert.equal(ap.customContent, 'Kısa');
  assert.equal((ap.platformSpecificData as Record<string, unknown>).expressConsentGiven, true);
  assert.equal((ap.platformSpecificData as Record<string, unknown>).description, 'Kısa');
  assert.equal(tiktokPhotoTitle('kısa'), 'kısa');
});

test('hikâye: tek medya, metinsiz, yalnız Instagram/Facebook; onayda metin istenmez', () => {
  const h = { ...base(), tur: 'hikaye', gorseller: img(1), platformlar: ['instagram'], metin: {} };
  assert.deepEqual(parsePaket(h).errors, []);
  assert.match(parsePaket({ ...h, gorseller: img(2) }).errors.join(), /tek video ya da tek görsel/);
  assert.match(parsePaket({ ...h, gorseller: [] }).errors.join(), /tek video ya da tek görsel/);
  assert.match(parsePaket({ ...h, platformlar: ['tiktok'] }).errors.join(), /"tiktok" hikaye türünde yok/);
  const p = parsePaket({ ...h, gorseller: [], video: 'https://media.zernio.com/h.mp4', metin: { instagram: 'yok sayılır' } }).paket!;
  const b = draftBody(p, { instagram: 'a1' }, 'r', NOW);
  assert.deepEqual(b.mediaItems, [{ type: 'video', url: 'https://media.zernio.com/h.mp4' }]);
  assert.equal('content' in b, false);
  assert.deepEqual(b.platforms[0], { platform: 'instagram', accountId: 'a1', platformSpecificData: { contentType: 'story', isAiGenerated: true } });
  assert.deepEqual(parseApproval({ scheduledFor: '2026-10-30T20:00:00+03:00', platforms: ['instagram'], captions: {}, yapay_zeka: false }, NOW, 'hikaye').errors, []);
  assert.match(parseApproval({ scheduledFor: '2026-10-30T20:00:00+03:00', platforms: ['instagram'], captions: {}, yapay_zeka: false }, NOW).errors.join(), /instagram metni boş/);
  assert.deepEqual(entry('facebook', 'f1', undefined, { yapay_zeka: false, ticari: false, tur: 'hikaye' }, true),
    { platform: 'facebook', accountId: 'f1', platformSpecificData: { contentType: 'story' } });
});

test('gönderi hakkı özeti', () => {
  assert.deepEqual(usageOf({ planName: 'Free', billingAnchorDay: 28, hasAccess: true, limits: { uploads: 20 }, usage: { uploads: 4, lastReset: '2026-10-28T00:00:00Z' } }),
    { plan: 'Free', used: 4, limit: 20, resetDay: 28, lastReset: '2026-10-28T00:00:00Z', access: true, accounts: null, spendCents: null, creditCents: null });
  assert.deepEqual(usageOf({ planName: 'Usage-Based', billingSystem: 'metronome', hasAccess: true, limits: { uploads: -1, profiles: -1 },
    usage: { connectedAccounts: 2 }, spend: { currentPeriodCents: 0, creditsRemainingCents: 500 } }),
    { plan: 'Usage-Based', used: null, limit: null, resetDay: null, lastReset: null, access: true, accounts: 2, spendCents: 0, creditCents: 500 });
  assert.equal(usageOf({ planName: 'Usage', limits: { uploads: -1 }, usage: {} })!.limit, null);   // sınırsız
  assert.equal(usageOf(null), null);
});

test('ölçümler: eksik alan null, sayılar korunur', () => {
  assert.deepEqual(metrics({ views: 241, likes: 2, shares: 1, saves: 1, reach: 180, igReelsAvgWatchTime: 4300, reelsSkipRate: 41.5 }),
    { views: 241, reach: 180, impressions: null, likes: 2, comments: 0, shares: 1, saves: 1, avgWatchMs: 4300, totalWatchMs: null,
      skipRate: 41.5, completionRate: null, follows: null, profileViews: null });
  assert.equal(metrics(null), null);
});

test('taslakta saat: servisin yazdığı oluşturulma anı değil, paketin önerisi', () => {
  const d = { _id: 'd1', status: 'draft', scheduledFor: '2026-10-30T14:20:00.000Z', metadata: { onerilen_zaman: '2026-10-31T21:00:00+03:00' } };
  assert.equal(summarize(d).scheduledFor, '2026-10-31T21:00:00+03:00');
  assert.equal(summarize({ ...d, metadata: {} }).scheduledFor, null);
  assert.equal(summarize({ ...d, status: 'scheduled' }).scheduledFor, '2026-10-30T14:20:00.000Z');
});
