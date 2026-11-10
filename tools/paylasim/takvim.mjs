// Paylaşım takvimi: `social` işlevinin `status` çıktısından (gonderiler) Türkiye saatiyle gün gün plan.
// gonder.mjs `durum` bunu durum.json'un `takvim` alanına yazar; Marketing penceresi hangi içeriğin hangi gün ve saatte
// planda olduğunu, hangisinin onay beklediğini ve boş günleri buradan okur (sözleşme: ortak/sozlesme/paylasim.md "Takvim").
// İşleyiş referansı: Buffer "Queue", Later ve Hootsuite "Planner" (gün başlığı altında saat sırası, durum, platform; boş
// aralıklar görünür). Bağımlılık yok (Node 20+, Intl).

export const TZ = 'Europe/Istanbul';
const GUN_MS = 86_400_000;
const DURUM = { onay: 'Onay bekliyor', duzeltme: 'Düzeltme istendi', planli: 'Planlı', yayinda: 'Yayında', sorun: 'Sorun' };
const TUR = { video: 'video', kaydirmali: 'kaydırmalı', hikaye: 'hikâye' };
const PLATFORM = { instagram: 'Instagram', tiktok: 'TikTok', youtube: 'YouTube', facebook: 'Facebook', threads: 'Threads', linkedin: 'LinkedIn' };

const fTarih = new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' });
const fGun = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, weekday: 'long' });
const fAyGun = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, day: 'numeric', month: 'long' });
const fSaat = new Intl.DateTimeFormat('en-GB', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });

// ISO zaman → Türkiye saatiyle tarih (YYYY-MM-DD), gün adı ("11 Kasım Çarşamba") ve saat ("21:00")
export function trZaman(t) {
  const d = t instanceof Date ? t : new Date(t);
  if (Number.isNaN(d.getTime())) return null;
  return { tarih: fTarih.format(d), gun: `${fAyGun.format(d)} ${fGun.format(d)}`, saat: fSaat.format(d) };
}

export function takvim(gonderiler, now = new Date(), { gecmisGun = 7, ileriGun = 14 } = {}) {
  const bugun = trZaman(now).tarih;
  const alt = trZaman(new Date(now.getTime() - gecmisGun * GUN_MS)).tarih;
  const kayitlar = (gonderiler ?? []).map((p) => {
    const grup = DURUM[p?.group] ? p.group : 'sorun';
    const kesin = grup === 'planli' || grup === 'yayinda' || grup === 'sorun';   // onay/düzeltmede saat paketin önerisi
    const z = p?.scheduledFor ? trZaman(p.scheduledFor) : null;
    const gecikti = !kesin && !!z && Date.parse(p.scheduledFor) < now.getTime();
    const platformlar = (p?.platforms ?? []).map((t) => t?.platform).filter(Boolean);
    const durum = DURUM[grup] + (z && !kesin ? (gecikti ? ' (önerilen saat geçti)' : ' (önerilen saat)') : '');
    const satir = [z ? z.saat : 'saat yok', durum, `${p?.paket ?? p?.title ?? p?.id ?? '?'}${p?.surum ? ` s${p.surum}` : ''}`,
                   TUR[p?.tur] ?? 'video', platformlar.map((x) => PLATFORM[x] ?? x).join(' + ') || '—'].join(' · ');
    return {
      zaman: p?.scheduledFor ?? null, tarih: z?.tarih ?? null, gun: z?.gun ?? null, saat: z?.saat ?? null,
      durum: DURUM[grup], grup, kesin, gecikti, satir,
      id: p?.id ?? null, paket: p?.paket ?? null, surum: p?.surum ?? null, tur: p?.tur ?? 'video', baslik: p?.title ?? '',
      platformlar,
      platform_durumu: Object.fromEntries((p?.platforms ?? []).filter((t) => t?.platform).map((t) => [t.platform, t.status ?? null])),
      baglantilar: (p?.platforms ?? []).map((t) => t?.url).filter(Boolean),
      ...(grup === 'duzeltme' && p?.changesNote ? { duzeltme_notu: p.changesNote } : {}),
    };
  });
  // Görünen aralık: son `gecmisGun` gün + bütün ileri tarihler; saati olmayan bekleyenler en sonda
  const zamanli = kayitlar.filter((k) => k.tarih && k.tarih >= alt).sort((a, b) => Date.parse(a.zaman) - Date.parse(b.zaman));
  const saatsiz = kayitlar.filter((k) => !k.tarih && k.grup !== 'yayinda');
  const gunler = [];
  for (const k of zamanli) {
    const son = gunler[gunler.length - 1];
    if (son && son.tarih === k.tarih) son.gonderiler.push(k);
    else gunler.push({ tarih: k.tarih, gun: k.gun, bugun: k.tarih === bugun, gonderiler: [k] });
  }
  // Boş günler: bugünden itibaren `ileriGun` gün içinde planlı, onay bekleyen ya da düzeltilen hiçbir gönderisi olmayanlar
  const dolu = new Set(kayitlar.filter((k) => k.tarih && k.grup !== 'sorun').map((k) => k.tarih));
  const bos_gunler = [];
  for (let i = 0; i < ileriGun; i++) {
    const g = trZaman(new Date(now.getTime() + i * GUN_MS));
    if (!dolu.has(g.tarih)) bos_gunler.push(g.gun);
  }
  const ileri = zamanli.filter((k) => Date.parse(k.zaman) >= now.getTime());
  const say = (g) => kayitlar.filter((k) => k.grup === g).length;
  const siradaki = ileri.find((k) => k.grup === 'planli');
  return {
    saat_dilimi: TZ,
    aciklama: 'Saatler Türkiye saatidir. "kesin": true = panelde onaylanmış (planlı) ya da yayımlanmış saat; false = paketin '
            + 'önerdiği saat, gerçek saat onayda panelde verilir. Gösterilen aralık: son ' + gecmisGun + ' gün ve ileri tarihler.',
    ozet: {
      planli: say('planli'), onay_bekliyor: say('onay'), duzeltme_istendi: say('duzeltme'), sorun: say('sorun'),
      siradaki_yayin: siradaki ? `${siradaki.gun} ${siradaki.satir}` : null,
      son_planli_gun: [...ileri].reverse().find((k) => k.grup === 'planli')?.gun ?? null,
      bos_gun_sayisi: bos_gunler.length,
    },
    gunler,
    saatsiz,
    bos_gunler,
  };
}

// İş akışı günlüğü için kısa metin (ileri tarihli günler)
export function takvimMetni(t, enCok = 10) {
  const out = [];
  for (const g of t.gunler) {
    if (!g.gonderiler.some((k) => k.grup !== 'yayinda')) continue;
    out.push(`${g.gun}${g.bugun ? ' (bugün)' : ''}`);
    for (const k of g.gonderiler) out.push(`  ${k.satir}`);
    if (out.length >= enCok * 2) break;
  }
  if (t.bos_gunler.length) out.push(`Boş günler (${t.bos_gunler.length}): ${t.bos_gunler.join(', ')}`);
  return out.join('\n');
}
