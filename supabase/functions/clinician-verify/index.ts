// clinician-verify: uzman doğrulama ön kontrolü (sozlesme/akislar.md 14, proposed/20261026050000_clinician_verification.sql).
// ClinicApp belgeyi `verify` kovasına yükleyip `clinician_verification_submit` dedikten sonra uzman oturumuyla çağırır:
//   POST { id }  →  { status: 'pending' | 'unreadable' | 'student_doc' | 'duplicate' | 'skipped', checks }
// "Verify JWT" KAPALI yayınlanır (diğer işlevlerimiz gibi; yeni anahtar düzeninde ağ geçidi oturum anahtarını reddedebiliyor):
// oturum işlevin içinde doğrulanır (auth.getUser), yalnız başvurunun sahibi kendi belgesini kontrol ettirebilir. Belge kendi sunucumuzda okunur (PDF metin katmanı); dışarıya veri gitmez, yapay zekâ yok.
// Kişinin adı ve kimlik numarası kaydedilmez; yalnız eşleşme sonucu ve özet (üniversite, bölüm, derece, mezuniyet yılı).
// Kesin olmayan hiçbir sonuç ret sayılmaz: karar yönetim panelinde bir kişinindir. Meslek tablosu veri/uzman_meslekleri.json ile aynı
// (Supabase panelinden tek dosya yapıştırılabilsin diye burada da tutulur). Saf işlevlerin testi: analyze.test.ts.

export type Degree = 'lisans' | 'yuksek_lisans';
export type Profession = { programs: string[]; degree: Degree | null; manual?: boolean; bacb?: boolean };
export type Check = 'ok' | 'warn' | 'fail' | 'manual';
export type Analysis = {
  hard: 'unreadable' | 'student_doc' | null;
  barcode: string | null;
  checks: Record<string, Check>;
  extracted: { university?: string; program?: string; degree?: string; graduation_year?: string };
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

export function findBarcode(text: string): string | null {
  const labelled = text.match(/barkod(?:\s*(?:no|numaras[ıi]))?\s*[:：]?\s*([A-Za-zÇĞİÖŞÜ0-9][A-Za-zÇĞİÖŞÜ0-9-]{7,40})/i);
  if (labelled) return labelled[1].toUpperCase();
  const pattern = text.match(/\b([A-ZÇĞİÖŞÜ]{2,6}-[A-Za-z0-9]{4,}(?:-[A-Za-z0-9]{4,}){2,6})\b/);
  return pattern ? pattern[1].toUpperCase() : null;
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
  if (t.replace(/[^a-z]/g, '').length < 40) return { hard: 'unreadable', barcode: null, checks: { text: 'fail' }, extracted };
  checks.text = 'ok';
  if (/ogrenci belgesi/.test(t) && !/mezun/.test(t)) return { hard: 'student_doc', barcode: null, checks: { ...checks, graduate: 'fail' }, extracted };
  checks.edevlet = /turkiye\.gov\.tr|e-devlet|e devlet|belge-dogrulama|belge dogrulama/.test(t) ? 'ok' : 'warn';
  checks.graduate = /mezun/.test(t) ? 'ok' : 'warn';
  const barcode = findBarcode(text);
  checks.barcode = barcode ? 'ok' : 'warn';

  const tokens = norm(accountName ?? '').split(' ').filter((w) => /^[a-z]{2,}$/.test(w) && !TITLES.has(w));
  const hits = tokens.filter((w) => word(t, w));
  checks.name = tokens.length > 0 && hits.length === tokens.length ? 'ok' : hits.length > 0 ? 'warn' : 'fail';

  const p = PROFESSIONS[professionKey] ?? PROFESSIONS.diger;
  const degree = highestDegree(t);
  if (degree) extracted.degree = degree;
  if (p.manual || p.bacb) {
    checks.program = 'manual';
  } else {
    const prog = p.programs.find((x) => t.includes(norm(x)));
    checks.program = prog ? 'ok' : 'fail';
    if (prog) extracted.program = prog;
    const rank = { on_lisans: 0, lisans: 1, yuksek_lisans: 2, doktora: 3 } as const;
    const need = p.degree === 'yuksek_lisans' ? 2 : 1;
    checks.degree = degree && rank[degree] >= need ? 'ok' : 'fail';
  }
  const uni = text.match(/([A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü.' ’-]{1,80}\s(?:ÜNİVERSİTESİ|Üniversitesi))/);
  if (uni) extracted.university = uni[1].replace(/\s+/g, ' ').trim().slice(0, 120);
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
    const { data: v } = await db.rpc('clinician_verification_for_check', { p_id: id, p_user: who.user.id });
    if (!v || v.status !== 'pending') return reply({ status: 'skipped' });

    let a: Analysis = { hard: null, barcode: null, checks: { program: 'manual' }, extracted: {} };
    if (v.file_path) {
      const { data: file, error } = await db.storage.from('verify').download(v.file_path);
      const buf = error || !file ? null : new Uint8Array(await file.arrayBuffer());
      const isPdf = !!buf && buf.length > 4 && buf[0] === 0x25 && buf[1] === 0x50 && buf[2] === 0x44 && buf[3] === 0x46; // %PDF
      if (!isPdf) {
        a = { hard: 'unreadable', barcode: null, checks: { text: 'fail' }, extracted: {} };
      } else {
        try {
          const { extractText, getDocumentProxy } = await import('npm:unpdf@1.8.1');
          const pdf = await getDocumentProxy(buf!);
          const { text } = await extractText(pdf, { mergePages: true });
          a = analyze(String(text ?? ''), String(v.name ?? ''), String(v.profession));
        } catch {
          a = { hard: 'unreadable', barcode: null, checks: { text: 'fail' }, extracted: {} };
        }
      }
    }
    const { data: status, error } = await db.rpc('clinician_verification_autocheck', {
      p_id: id, p_auto: { checks: a.checks, extracted: a.extracted, version: 1 }, p_barcode: a.barcode, p_hard: a.hard,
    });
    if (error) return reply({ error: 'save' }, 500);
    return reply({ status, checks: a.checks });
  });
}
