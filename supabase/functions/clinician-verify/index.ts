// clinician-verify: uzman doğrulama ön kontrolü (sozlesme/akislar.md 14, migrations/20261026050000_clinician_verification.sql).
// ClinicApp belgeyi `verify` kovasına yükleyip `clinician_verification_submit` dedikten sonra uzman oturumuyla çağırır:
//   POST { id }  →  { status: 'pending' | 'unreadable' | 'student_doc' | 'duplicate' | 'skipped', checks }
// "Verify JWT" KAPALI yayınlanır (diğer işlevlerimiz gibi; yeni anahtar düzeninde ağ geçidi oturum anahtarını reddedebiliyor):
// oturum işlevin içinde doğrulanır (auth.getUser), yalnız başvurunun sahibi kendi belgesini kontrol ettirebilir. Belge kendi sunucumuzda okunur (PDF metin katmanı); dışarıya veri gitmez, yapay zekâ yok.
// Kişinin adı ve kimlik numarası kaydedilmez; yalnız eşleşme sonucu ve özet (üniversite, bölüm, derece, mezuniyet yılı).
// Kesin olmayan hiçbir sonuç ret sayılmaz: karar yönetim panelinde bir kişinindir. Altyapı hatası (indirme, PDF okuyucu) ret değildir:
// başvuru bekler, yönetici inceler. Elle incelenen meslekler (hekim, diğer) ve BCBA'nın isteğe bağlı belgesi kendiliğinden reddedilmez.
// Her başvuru bir kez kontrol edilir. Her çağrıda karar verilmiş / geri çekilmiş başvuruların dosyaları kovadan silinir (storage_trash).
// Meslek tablosu veri/uzman_meslekleri.json ile aynı (Supabase panelinden tek dosya yapıştırılabilsin diye burada da tutulur).
// Saf işlevlerin testi: analyze.test.ts. Düzeltmeler: proposed/20261026300000_review_fixes.sql (26 Ekim 2026 denetimi).

export type Degree = 'lisans' | 'yuksek_lisans';
export type Profession = { programs: string[]; degree: Degree | null; manual?: boolean; bacb?: boolean };
export type Check = 'ok' | 'warn' | 'fail' | 'manual';
export type Analysis = {
  hard: 'unreadable' | 'student_doc' | null;
  barcode: string | null;
  checks: Record<string, Check>;
  extracted: { program?: string; degree?: string; graduation_year?: string };   // kişi adı ve üniversite satırı alınmaz
};

export const PROFESSIONS: Record<string, Profession> = {
  psikolog: { programs: ['psikoloji'], degree: 'lisans' },
  klinik_psikolog: { programs: ['klinik psikoloji'], degree: 'yuksek_lisans' },
  pdr: { programs: ['rehberlik ve psikolojik danışmanlık', 'psikolojik danışmanlık ve rehberlik', 'psikolojik danışma ve rehberlik', 'rehberlik ve psikolojik danışma'], degree: 'lisans' },
  ergoterapist: { programs: ['ergoterapi'], degree: 'lisans' },
  dil_konusma: { programs: ['dil ve konuşma terapisi'], degree: 'lisans' },
  ozel_egitim: { programs: ['özel eğitim öğretmenliği', 'zihin engelliler öğretmenliği', 'işitme engelliler öğretmenliği', 'görme engelliler öğretmenliği', 'özel eğitim'], degree: 'lisans' },
  cocuk_gelisimi: { programs: ['çocuk gelişimi'], degree: 'lisans' },
  bcba: { programs: [], degree: null, bacb: true },
  hekim: { programs: ['tıp'], degree: 'lisans', manual: true },
  diger: { programs: [], degree: null, manual: true },
};

const TR: Record<string, string> = { ç: 'c', ğ: 'g', ı: 'i', i: 'i', ö: 'o', ş: 's', ü: 'u', â: 'a', î: 'i', û: 'u' };
// Türkçe küçük harf + ASCII + tek boşluk (eşleştirme için)
export const norm = (s: string) =>
  s.toLocaleLowerCase('tr-TR').normalize('NFC').replace(/[çğıiöşüâîû]/g, (c) => TR[c] ?? c).replace(/[^a-z0-9.\-/:@ ]+/g, ' ')
    .replace(/\s+/g, ' ').trim();

const TITLES = new Set(['dr', 'doc', 'prof', 'uzm', 'psk', 'klinik', 'psikolog', 'ogr', 'gor', 'yrd', 'dt', 'ergoterapist']);
const word = (t: string, w: string) => new RegExp(`(^|[^a-z])${w}([^a-z]|$)`).test(t);

// Barkod biçimi: harf/rakam grupları tire ile (en az 3 grup) ve en az bir rakam. "Barkod numarası ile…" gibi düz sözcükler,
// ad soyad ya da tek parça metin barkod sayılmaz (aksi halde herkes aynı "barkodu" alır ve ikinci başvuru 'duplicate' olurdu).
const BARCODE = '[A-Za-zÇĞİÖŞÜçğıöşü0-9]{2,8}(?:-[A-Za-z0-9]{3,12}){2,7}';
export function findBarcode(text: string): string | null {
  const ok = (b?: string) => (b && /\d/.test(b) ? b.toLocaleUpperCase('tr-TR') : null);
  const labelled = ok(text.match(new RegExp(`barkod(?:\\s{0,3}(?:no|numaras[ıi]))?\\s{0,3}[:：]?\\s{0,3}(${BARCODE})`, 'i'))?.[1]);
  if (labelled) return labelled;
  for (const m of text.matchAll(new RegExp(`(?:^|[^A-Za-z0-9-])([A-ZÇĞİÖŞÜ]{2,6}(?:-[A-Za-z0-9]{4,12}){3,7})(?![A-Za-z0-9-])`, 'g'))) {
    const b = ok(m[1]);
    if (b) return b;
  }
  return null;
}

// Belgede bulunan en yüksek derece (ön lisans ayrı tutulur: lisans yerine geçmez)
export function highestDegree(t: string): 'doktora' | 'yuksek_lisans' | 'lisans' | 'on_lisans' | null {
  if (word(t, 'doktora')) return 'doktora';
  if (/yuksek lisans/.test(t)) return 'yuksek_lisans';
  const rest = t.replace(/on lisans/g, ' ').replace(/yuksek lisans/g, ' ');
  if (word(rest, 'lisans')) return 'lisans';
  if (/on lisans/.test(t)) return 'on_lisans';
  return null;
}

export function analyze(text: string, accountName: string, professionKey: string): Analysis {
  const t = norm(text ?? '');
  const checks: Record<string, Check> = {};
  const extracted: Analysis['extracted'] = {};
  const p = PROFESSIONS[professionKey] ?? PROFESSIONS.diger;
  const soft = !!(p.manual || p.bacb);   // elle incelenir: kesin ret yok, yönetici bakar
  if (t.replace(/[^a-z]/g, '').length < 40) {
    return { hard: soft ? null : 'unreadable', barcode: null, checks: soft ? { text: 'warn', program: 'manual' } : { text: 'fail' }, extracted };
  }
  checks.text = 'ok';
  if (/ogrenci belgesi/.test(t) && !/mezun/.test(t)) {
    if (!soft) return { hard: 'student_doc', barcode: null, checks: { ...checks, graduate: 'fail' }, extracted };
    checks.graduate = 'fail';
  }
  checks.edevlet = /turkiye\.gov\.tr|e-devlet|e devlet|belge-dogrulama|belge dogrulama/.test(t) ? 'ok' : 'warn';
  checks.graduate ??= /mezun/.test(t) ? 'ok' : 'warn';
  const barcode = findBarcode(text);
  checks.barcode = barcode ? 'ok' : 'warn';

  const tokens = norm(accountName ?? '').split(' ').filter((w) => /^[a-z]{2,}$/.test(w) && !TITLES.has(w));
  const hits = tokens.filter((w) => word(t, w));
  checks.name = tokens.length > 0 && hits.length === tokens.length ? 'ok' : hits.length > 0 ? 'warn' : 'fail';

  const degree = highestDegree(t);
  if (degree) extracted.degree = degree;
  if (p.manual || p.bacb) {
    checks.program = 'manual';
  } else {
    // sözcük sınırıyla: "psikoloji" "psikolojik danışmanlık" içinde eşleşmez
    const prog = p.programs.find((x) => new RegExp(`(^|[^a-z])${norm(x).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z]|$)`).test(t));
    checks.program = prog ? 'ok' : 'fail';
    if (prog) extracted.program = prog;
    const rank = { on_lisans: 0, lisans: 1, yuksek_lisans: 2, doktora: 3 } as const;
    const need = p.degree === 'yuksek_lisans' ? 2 : 1;
    checks.degree = degree && rank[degree] >= need ? 'ok' : 'fail';
  }
  const grad = t.match(/mezuniyet tarihi\s*[:\-]?\s*\d{1,2}[./]\d{1,2}[./]((?:19|20)\d{2})/);
  if (grad) extracted.graduation_year = grad[1];
  return { hard: null, barcode, checks, extracted };
}

// ---------------------------------------------------------------------------------------------------------------------
declare const Deno: { env: { get(k: string): string | undefined }; serve(h: (r: Request) => Response | Promise<Response>): void } | undefined;

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers });

// "%PDF" ilk 1024 bayt içinde (geçerli PDF'lerde başta birkaç bayt olabilir)
export function isPdf(buf: Uint8Array): boolean {
  const n = Math.min(buf.length - 4, 1024);
  for (let i = 0; i <= n; i++) if (buf[i] === 0x25 && buf[i + 1] === 0x50 && buf[i + 2] === 0x44 && buf[i + 3] === 0x46) return true;
  return false;
}

// Karar verilmiş, geri çekilmiş ya da hesabı silinmiş başvuruların belgeleri (sunucu kuyruğu) kovadan silinir
// deno-lint-ignore no-explicit-any
async function drainTrash(db: any) {
  const { data } = await db.rpc('storage_trash_take', { p_bucket: 'verify', p_limit: 50 });
  const rows = (data ?? []) as { id: number; path: string }[];
  if (!rows.length) return;
  const { error } = await db.storage.from('verify').remove(rows.map((r) => r.path));
  if (!error) await db.rpc('storage_trash_done', { p_ids: rows.map((r) => r.id) });
}

if (typeof Deno !== 'undefined') {
  Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { headers });
    if (req.method !== 'POST') return reply({ error: 'method' }, 405);
    const env = (k: string) => Deno!.env.get(k) ?? '';
    const { createClient } = await import('jsr:@supabase/supabase-js@2');
    const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
    const { data: who } = await db.auth.getUser(jwt);
    if (!who?.user) return reply({ error: 'auth' }, 401);
    const { id } = await req.json().catch(() => ({ id: null }));
    if (typeof id !== 'string') return reply({ error: 'id' }, 400);
    await drainTrash(db);
    const { data: v } = await db.rpc('clinician_verification_for_check', { p_id: id, p_user: who.user.id });
    // her başvuru bir kez, yalnız gönderildikten sonra (alanlar yoksa: SQL düzeltmesi henüz uygulanmadı, eski davranış)
    if (!v || v.status !== 'pending' || v.submitted === false || v.checked === true) return reply({ status: 'skipped' });

    let a: Analysis = { hard: null, barcode: null, checks: { program: 'manual' }, extracted: {} };
    if (v.file_path) {
      // altyapı hatası ret değildir: başvuru bekler, yönetici belgeyi açıp inceler
      const { data: file, error } = await db.storage.from('verify').download(v.file_path);
      if (error || !file) return reply({ status: 'error' }, 503);
      const buf = new Uint8Array(await file.arrayBuffer());
      if (!isPdf(buf)) {
        a = analyze('', String(v.name ?? ''), String(v.profession));   // PDF değil: okunamadı (elle incelenen meslekte ret yok)
      } else {
        let text: string;
        try {
          const { extractText, getDocumentProxy } = await import('npm:unpdf@1.8.1');
          text = String((await extractText(await getDocumentProxy(buf), { mergePages: true })).text ?? '');
        } catch {
          return reply({ status: 'error' }, 503);
        }
        a = analyze(text, String(v.name ?? ''), String(v.profession));
      }
    }
    const { data: status, error } = await db.rpc('clinician_verification_autocheck', {
      p_id: id, p_auto: { checks: a.checks, extracted: a.extracted, version: 1 }, p_barcode: a.barcode, p_hard: a.hard,
    });
    if (error) return reply({ error: 'save' }, 500);
    return reply({ status, checks: a.checks });
  });
}
