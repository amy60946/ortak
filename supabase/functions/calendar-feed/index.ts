// calendar-feed: uzmanın ClinicApp seanslarını kendi takvimine (Google, Apple, Outlook) tek yönlü aktaran .ics aboneliği.
// GET https://<proje>.supabase.co/functions/v1/calendar-feed?t=<48 karakter belirteç>
// "Verify JWT" KAPALI yayınlanır: takvim uygulamaları oturum taşımaz; belirteç 192 bit rastgele, uzman Takvim ayarlarından
// yeniler ya da kapatır (`clinic_calendar_feed`). Veritabanına yalnız service role ile `calendar_feed_events` çağrılır.
// Kişisel veri en az: çocuk adı yok (isteğe bağlı baş harf), not ve aile bilgisi yok; seans türü, saat, oda ya da "Online".
import { createClient } from 'jsr:@supabase/supabase-js@2';

const env = (k: string) => Deno.env.get(k) ?? '';
const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });

type Ev = { uid: string; start: string; end: string; summary: string; location: string; cancelled: boolean };

const esc = (s: string) => s.replace(/\\/g, '\\\\').replace(/;/g, '\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
const utc = (iso: string) => new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
// 75 baytı aşan satırlar katlanır (RFC 5545 3.1); çok baytlı Türkçe harf bölünmez
const enc = new TextEncoder();
const fold = (line: string) => {
  const out: string[] = [];
  let cur = '', bytes = 0;
  for (const ch of line) {
    const b = enc.encode(ch).length;
    if (bytes + b > (out.length ? 74 : 75)) { out.push(cur); cur = ''; bytes = 0; }
    cur += ch; bytes += b;
  }
  out.push(cur);
  return out.join('\r\n ');
};

Deno.serve(async (req) => {
  if (req.method !== 'GET') return new Response('', { status: 405 });
  const t = (new URL(req.url).searchParams.get('t') ?? '').trim().toLowerCase();
  if (!/^[0-9a-f]{48}$/.test(t)) return new Response('', { status: 404 });
  const { data, error } = await db.rpc('calendar_feed_events', { p_token: t });
  if (error) return new Response('', { status: 500 });
  const events = (data ?? []) as Ev[];
  const now = utc(new Date().toISOString());
  const lines = [
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//ClinicApp//Seanslar//TR', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH',
    'X-WR-CALNAME:ClinicApp seansları', 'X-WR-TIMEZONE:Europe/Istanbul', 'REFRESH-INTERVAL;VALUE=DURATION:PT30M', 'X-PUBLISHED-TTL:PT30M',
  ];
  for (const e of events) {
    lines.push('BEGIN:VEVENT', `UID:${e.uid}@clinicapp`, `DTSTAMP:${now}`, `DTSTART:${utc(e.start)}`, `DTEND:${utc(e.end)}`,
      fold(`SUMMARY:${esc(e.summary)}`));
    if (e.location) lines.push(fold(`LOCATION:${esc(e.location)}`));
    lines.push(`STATUS:${e.cancelled ? 'CANCELLED' : 'CONFIRMED'}`, 'TRANSP:OPAQUE', 'END:VEVENT');
  }
  lines.push('END:VCALENDAR');
  return new Response(lines.join('\r\n') + '\r\n', {
    headers: { 'Content-Type': 'text/calendar; charset=utf-8', 'Cache-Control': 'private, max-age=600', 'Content-Disposition': 'inline; filename="clinicapp.ics"' },
  });
});
