// node --experimental-strip-types --test supabase/functions/calendar-import/ics_test.ts   (Deno: deno test)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { allowedUrl, expand } from './index.ts';

const cal = (body: string) => `BEGIN:VCALENDAR\r\nVERSION:2.0\r\n${body}END:VCALENDAR\r\n`;
const from = Date.parse('2026-11-01T00:00:00Z'), to = Date.parse('2026-12-31T00:00:00Z');

test('tek etkinlik, TZID İstanbul', () => {
  const o = expand(cal('BEGIN:VEVENT\r\nUID:a\r\nDTSTART;TZID=Europe/Istanbul:20261111T150000\r\nDTEND;TZID=Europe/Istanbul:20261111T154500\r\nSUMMARY:Nazlı\\, seans\r\nEND:VEVENT\r\n'), from, to);
  assert.equal(o.length, 1);
  assert.equal(o[0].start, '2026-11-11T12:00:00.000Z');
  assert.equal(o[0].end, '2026-11-11T12:45:00.000Z');
  assert.equal(o[0].summary, 'Nazlı, seans');
});

test('haftalık tekrar, sayıyla, bir örnek hariç ve biri taşınmış', () => {
  const o = expand(cal(
    'BEGIN:VEVENT\r\nUID:w\r\nDTSTART:20261104T120000Z\r\nDURATION:PT45M\r\nRRULE:FREQ=WEEKLY;COUNT=5\r\nEXDATE:20261111T120000Z\r\nSUMMARY:Ege\r\nEND:VEVENT\r\n' +
    'BEGIN:VEVENT\r\nUID:w\r\nRECURRENCE-ID:20261118T120000Z\r\nDTSTART:20261118T140000Z\r\nDTEND:20261118T144500Z\r\nSUMMARY:Ege (taşındı)\r\nEND:VEVENT\r\n'), from, to);
  assert.deepEqual(o.map((x) => x.start.slice(0, 16)), ['2026-11-04T12:00', '2026-11-18T14:00', '2026-11-25T12:00', '2026-12-02T12:00']);
  assert.equal(o[1].summary, 'Ege (taşındı)');
});

test('haftada iki gün, UNTIL ile', () => {
  const o = expand(cal('BEGIN:VEVENT\r\nUID:b\r\nDTSTART;TZID=Europe/Istanbul:20261102T100000\r\nDTEND;TZID=Europe/Istanbul:20261102T110000\r\nRRULE:FREQ=WEEKLY;BYDAY=MO,TH;UNTIL=20261113T235959Z\r\nEND:VEVENT\r\n'), from, to);
  assert.deepEqual(o.map((x) => x.start.slice(0, 16)), ['2026-11-02T07:00', '2026-11-05T07:00', '2026-11-09T07:00', '2026-11-12T07:00']);
});

test('tüm gün, iptal ve pencere dışı atlanır; alarm bloğu karışmaz', () => {
  const o = expand(cal(
    'BEGIN:VEVENT\r\nUID:c\r\nDTSTART;VALUE=DATE:20261110\r\nSUMMARY:Tatil\r\nEND:VEVENT\r\n' +
    'BEGIN:VEVENT\r\nUID:d\r\nDTSTART:20261110T090000Z\r\nDTEND:20261110T100000Z\r\nSTATUS:CANCELLED\r\nEND:VEVENT\r\n' +
    'BEGIN:VEVENT\r\nUID:e\r\nDTSTART:20250110T090000Z\r\nDTEND:20250110T100000Z\r\nEND:VEVENT\r\n' +
    'BEGIN:VEVENT\r\nUID:f\r\nDTSTART:20261120T090000Z\r\nDTEND:20261120T100000Z\r\nBEGIN:VALARM\r\nTRIGGER:-PT15M\r\nDESCRIPTION:x\r\nEND:VALARM\r\nSUMMARY:Toplantı\r\nEND:VEVENT\r\n'), from, to);
  assert.deepEqual(o.map((x) => x.uid), ['f']);
  assert.equal(o[0].summary, 'Toplantı');
});

test('katlanmış satır ve günlük tekrar yaz saatli bölgede duvar saatini korur', () => {
  const o = expand(cal('BEGIN:VEVENT\r\nUID:g\r\nDTSTART;TZID=Europe/Berlin:20261023T090000\r\nDTEND;TZID=Europe/Berlin:20261023T093000\r\nRRULE:FREQ=DAILY;COUNT=12\r\nSUMMARY:Uzun bir\r\n  başlık\r\nEND:VEVENT\r\n'), from, to);
  assert.equal(o[0].summary, 'Uzun bir başlık');
  assert.equal(o[0].start, '2026-11-01T08:00:00.000Z');   // 1 Kasım: Berlin kış saati (UTC+1)
  assert.equal(o.length, 3);
});

test('izinli adresler', () => {
  assert.ok(allowedUrl('https://calendar.google.com/calendar/ical/x/private-abc/basic.ics'));
  assert.ok(allowedUrl('https://p52-caldav.icloud.com/published/2/abc'));
  assert.ok(!allowedUrl('http://calendar.google.com/x'));
  assert.ok(!allowedUrl('https://calendar.google.com.evil.io/x'));
  assert.ok(!allowedUrl('https://169.254.169.254/latest'));
});
