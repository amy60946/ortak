// calendar-import: uzmanın dış takvimini (Google, Apple, Outlook gizli iCal adresi) okur, önümüzdeki 60 gün ve geçen 14 günün
// etkinliklerini clinic_external_events'e yazar. ClinicApp Takvim'de bunlar gri "dış takvim" blokları olarak görünür; uzman
// isterse seansa çevirir (`clinic_external_event_mark`). POST, oturumla (Authorization: Bearer <uzman oturumu>).
// "Verify JWT" KAPALI yayınlanır (diğer işlevlerimiz gibi); oturum işlevin içinde doğrulanır. Adres yalnız izinli
// takvim sunucularına gider (SSRF yok), yönlendirme izlenmez, en çok 2 MB, 10 sn. Takvim adresi gizlidir; günlüğe yazılmaz.

// ---------------------------------------------------------------------
// Okuyucu (tek dosyada, panelden yapıştırarak yayınlanabilsin diye)
// ---------------------------------------------------------------------
// Küçük iCalendar (RFC 5545) okuyucu: VEVENT'leri bir zaman penceresinde tekil etkinliklere açar.
// Desteklenen: DTSTART/DTEND/DURATION (UTC "Z", TZID'li ya da yerel), RRULE FREQ=DAILY|WEEKLY|MONTHLY + INTERVAL, COUNT,
// UNTIL, BYDAY (haftalık), EXDATE, RECURRENCE-ID (tekil değişiklik), STATUS:CANCELLED (atlanır). Tüm gün etkinlikleri
// (VALUE=DATE) seans olmadığından atlanır. Saat dilimi tanımsızsa Europe/Istanbul kabul edilir.

export type Occ = { uid: string; start: string; end: string; summary: string };

type Prop = { name: string; params: Record<string, string>; value: string };

const unfold = (text: string) => text.replace(/\r\n[ \t]/g, '').replace(/\n[ \t]/g, '').split(/\r?\n/);

function parseLine(line: string): Prop | null {
  const i = line.indexOf(':');
  if (i < 0) return null;
  const head = line.slice(0, i), value = line.slice(i + 1);
  const [name, ...ps] = head.split(';');
  const params: Record<string, string> = {};
  for (const p of ps) { const j = p.indexOf('='); if (j > 0) params[p.slice(0, j).toUpperCase()] = p.slice(j + 1).replace(/^"|"$/g, ''); }
  return { name: name.toUpperCase(), params, value };
}

const unesc = (s: string) => s.replace(/\\n/gi, ' ').replace(/\\([,;\\])/g, '$1').trim();

// Bir saat dilimindeki duvar saatini UTC milisaniyeye çevirir (Intl ile; iki adım yaz saati düzeltmesi)
function zoned(y: number, mo: number, d: number, h: number, mi: number, s: number, tz: string): number {
  const guess = Date.UTC(y, mo - 1, d, h, mi, s);
  const off = (t: number) => {
    let f: Intl.DateTimeFormat;
    try { f = new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' }); }
    catch { f = new Intl.DateTimeFormat('en-US', { timeZone: 'Europe/Istanbul', hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' }); }
    const p = Object.fromEntries(f.formatToParts(new Date(t)).map((x) => [x.type, x.value]));
    return Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour % 24, +p.minute, +p.second) - t;
  };
  let t = guess - off(guess);
  t = guess - off(t);
  return t;
}

// DTSTART gibi bir değeri UTC milisaniyeye çevirir; tüm gün ise null
function toMs(p: Prop, fallbackTz: string): number | null {
  if (p.params.VALUE === 'DATE' || /^\d{8}$/.test(p.value)) return null;
  const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/.exec(p.value.trim());
  if (!m) return null;
  const [, y, mo, d, h, mi, s, z] = m;
  if (z) return Date.UTC(+y, +mo - 1, +d, +h, +mi, +s);
  return zoned(+y, +mo, +d, +h, +mi, +s, p.params.TZID || fallbackTz);
}

function durMs(v: string): number {
  const m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(v.trim());
  if (!m) return 0;
  const [, sign, w, d, h, mi, s] = m;
  const ms = (((+(w || 0) * 7 + +(d || 0)) * 24 + +(h || 0)) * 60 + +(mi || 0)) * 60000 + +(s || 0) * 1000;
  return sign === '-' ? -ms : ms;
}

const DAYS: Record<string, number> = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };

// Yerel duvar saatini koruyarak gün ekler (yaz saati değişse de 15:00 15:00 kalır)
function addDaysLocal(ms: number, days: number, tz: string): number {
  const f = new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' });
  const p = Object.fromEntries(f.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  const base = new Date(Date.UTC(+p.year, +p.month - 1, +p.day + days));
  return zoned(base.getUTCFullYear(), base.getUTCMonth() + 1, base.getUTCDate(), +p.hour % 24, +p.minute, +p.second, tz);
}
function weekdayLocal(ms: number, tz: string): number {
  const f = new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'short' });
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(f.format(new Date(ms)));
}

type Raw = { uid: string; summary: string; start: number; dur: number; tz: string; rrule?: Record<string, string>; exdates: Set<number>;
             recurrenceId?: number; cancelled: boolean };

export function expand(text: string, fromMs: number, toMs_: number, fallbackTz = 'Europe/Istanbul', limit = 1000): Occ[] {
  const lines = unfold(text);
  const raws: Raw[] = [];
  let cur: Raw | null = null, depth = 0;
  for (const line of lines) {
    if (/^BEGIN:VEVENT/i.test(line)) { cur = { uid: '', summary: '', start: NaN, dur: 0, tz: fallbackTz, exdates: new Set(), cancelled: false }; depth = 1; continue; }
    if (!cur) continue;
    if (/^BEGIN:/i.test(line)) { depth++; continue; }            // VALARM gibi iç bloklar
    if (/^END:VEVENT/i.test(line)) { if (depth === 1) { if (cur.uid && !Number.isNaN(cur.start)) raws.push(cur); cur = null; } continue; }
    if (/^END:/i.test(line)) { depth--; continue; }
    if (depth !== 1) continue;
    const p = parseLine(line);
    if (!p) continue;
    if (p.name === 'UID') cur.uid = p.value.trim();
    else if (p.name === 'SUMMARY') cur.summary = unesc(p.value).slice(0, 200);
    else if (p.name === 'STATUS') cur.cancelled = p.value.trim().toUpperCase() === 'CANCELLED';
    else if (p.name === 'DTSTART') { const v = toMs(p, fallbackTz); cur.start = v === null ? NaN : v; if (p.params.TZID) cur.tz = p.params.TZID; }
    else if (p.name === 'DTEND') { const v = toMs(p, fallbackTz); if (v !== null && !Number.isNaN(cur.start)) cur.dur = v - cur.start; else if (v !== null) (cur as Raw & { endMs?: number }).endMs = v; }
    else if (p.name === 'DURATION') cur.dur = durMs(p.value);
    else if (p.name === 'RRULE') cur.rrule = Object.fromEntries(p.value.split(';').map((kv) => { const [k, v] = kv.split('='); return [k.toUpperCase(), v ?? '']; }));
    else if (p.name === 'EXDATE') for (const v of p.value.split(',')) { const t = toMs({ ...p, value: v }, fallbackTz); if (t !== null) cur.exdates.add(t); }
    else if (p.name === 'RECURRENCE-ID') { const t = toMs(p, fallbackTz); if (t !== null) cur.recurrenceId = t; }
  }
  for (const r of raws) {
    const e = (r as Raw & { endMs?: number }).endMs;
    if (e !== undefined && r.dur === 0) r.dur = e - r.start;
    if (r.dur <= 0) r.dur = 60 * 60000;
  }
  // tekil değişiklikler (RECURRENCE-ID) ana serinin o örneğinin yerine geçer
  const overrides = new Map<string, Raw>();
  for (const r of raws) if (r.recurrenceId !== undefined) overrides.set(`${r.uid}|${r.recurrenceId}`, r);
  const out: Occ[] = [];
  const push = (r: Raw, start: number) => {
    if (out.length >= limit || r.cancelled) return;
    if (start + r.dur <= fromMs || start >= toMs_) return;
    out.push({ uid: r.uid, start: new Date(start).toISOString(), end: new Date(start + r.dur).toISOString(), summary: r.summary });
  };
  for (const r of raws) {
    if (r.recurrenceId !== undefined) { push(r, r.start); continue; }
    if (!r.rrule) { push(r, r.start); continue; }
    const freq = (r.rrule.FREQ || '').toUpperCase();
    const interval = Math.max(1, parseInt(r.rrule.INTERVAL || '1', 10) || 1);
    const count = r.rrule.COUNT ? parseInt(r.rrule.COUNT, 10) : Infinity;
    const untilP = r.rrule.UNTIL ? toMs({ name: 'UNTIL', params: {}, value: r.rrule.UNTIL.length === 8 ? r.rrule.UNTIL + 'T235959Z' : r.rrule.UNTIL }, r.tz) : null;
    const until = untilP ?? Infinity;
    const byday = (r.rrule.BYDAY || '').split(',').map((x) => DAYS[x.replace(/^[+-]?\d+/, '').toUpperCase()]).filter((x) => x !== undefined);
    let n = 0;
    const emit = (t: number) => {
      if (t > until || n >= count) return false;
      n++;
      if (!r.exdates.has(t)) { const ov = overrides.get(`${r.uid}|${t}`); if (!ov) push(r, t); }
      return true;
    };
    const hardStop = toMs_ + 24 * 3600e3;
    if (freq === 'DAILY') {
      for (let t = r.start, i = 0; t < hardStop && i < 3000; t = addDaysLocal(r.start, interval * ++i, r.tz)) if (!emit(t)) break;
    } else if (freq === 'WEEKLY') {
      const days = byday.length ? byday : [weekdayLocal(r.start, r.tz)];
      const startDow = weekdayLocal(r.start, r.tz);
      let stop = false;
      for (let w = 0; !stop && w < 600; w += interval) {
        const weekStart = addDaysLocal(r.start, w * 7 - ((startDow + 6) % 7), r.tz);   // o haftanın pazartesisi, aynı saat
        if (weekStart > hardStop) break;
        for (const d of [...days].sort((a, b) => ((a + 6) % 7) - ((b + 6) % 7))) {
          const t = addDaysLocal(weekStart, (d + 6) % 7, r.tz);
          if (t < r.start) continue;
          if (!emit(t)) { stop = true; break; }
        }
      }
    } else if (freq === 'MONTHLY') {
      for (let i = 0; i < 240; i += interval) {
        const f = new Intl.DateTimeFormat('en-US', { timeZone: r.tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' });
        const p = Object.fromEntries(f.formatToParts(new Date(r.start)).map((x) => [x.type, x.value]));
        const base = new Date(Date.UTC(+p.year, +p.month - 1 + i, 1));
        const dim = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth() + 1, 0)).getUTCDate();
        if (+p.day > dim) continue;
        const t = zoned(base.getUTCFullYear(), base.getUTCMonth() + 1, +p.day, +p.hour % 24, +p.minute, +p.second, r.tz);
        if (t > hardStop) break;
        if (!emit(t)) break;
      }
    } else {
      push(r, r.start);   // desteklenmeyen tekrar: yalnız ilk örnek
    }
  }
  return out.sort((a, b) => a.start.localeCompare(b.start));
}

// İzinli takvim adresleri (veritabanındaki calendar_url_allowed ile aynı)
export const allowedUrl = (u: string) =>
  /^https:\/\/(calendar\.google\.com|p[0-9]{1,3}-caldav\.icloud\.com|outlook\.office365\.com|outlook\.live\.com)\/\S+$/i.test(u);

// ---------------------------------------------------------------------
// İşlev
// ---------------------------------------------------------------------
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};

async function fetchIcs(url: string): Promise<string> {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 10_000);
  try {
    const res = await fetch(url, { redirect: 'manual', signal: ctl.signal, headers: { Accept: 'text/calendar' } });
    if (res.status >= 300 && res.status < 400) {
      const next = res.headers.get('location') ?? '';
      if (!allowedUrl(next)) throw new Error('redirect_not_allowed');
      const res2 = await fetch(next, { redirect: 'manual', signal: ctl.signal });
      if (!res2.ok) throw new Error(`http_${res2.status}`);
      return await readLimited(res2);
    }
    if (!res.ok) throw new Error(`http_${res.status}`);
    return await readLimited(res);
  } finally {
    clearTimeout(timer);
  }
}
async function readLimited(res: Response): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return '';
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > 2_000_000) { await reader.cancel(); throw new Error('too_large'); }
    chunks.push(value);
  }
  const all = new Uint8Array(size);
  let o = 0;
  for (const c of chunks) { all.set(c, o); o += c.length; }
  const text = new TextDecoder().decode(all);
  if (!/BEGIN:VCALENDAR/i.test(text)) throw new Error('not_ical');
  return text;
}

// Deno'da yayın; Node testleri (ics_test.ts) yalnız okuyucuyu kullanır
declare const Deno: { serve: (h: (r: Request) => Promise<Response>) => void; env: { get: (k: string) => string | undefined } } | undefined;
if (typeof Deno !== 'undefined') Deno.serve(async (req) => {
  const env = (k: string) => Deno!.env.get(k) ?? '';
  const { createClient } = await import('jsr:@supabase/supabase-js@2');
  const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'POST') return Response.json({ error: 'method' }, { status: 405, headers });
  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const { data: who } = await db.auth.getUser(jwt);
  const uid = who?.user?.id;
  if (!uid) return Response.json({ error: 'auth' }, { status: 401, headers });
  const { data: sources, error } = await db.rpc('calendar_import_sources', { p_clinician: uid });
  if (error) return Response.json({ error: 'db' }, { status: 500, headers });
  const from = Date.now() - 14 * 864e5, to = Date.now() + 60 * 864e5;
  let events = 0, failed = 0;
  for (const s of (sources ?? []) as { id: string; url: string }[]) {
    try {
      if (!allowedUrl(s.url)) throw new Error('url_not_allowed');
      const occ = expand(await fetchIcs(s.url), from, to);
      const { data: n } = await db.rpc('calendar_import_store', {
        p_source: s.id, p_events: occ, p_from: new Date(from).toISOString(), p_to: new Date(to).toISOString(), p_error: null,
      });
      events += (n as number) ?? 0;
    } catch (e) {
      failed++;
      await db.rpc('calendar_import_store', {
        p_source: s.id, p_events: [], p_from: new Date(from).toISOString(), p_to: new Date(to).toISOString(),
        p_error: String((e as Error)?.message ?? 'error').slice(0, 60),
      });
    }
  }
  return Response.json({ sources: (sources ?? []).length, events, failed }, { headers });
});
