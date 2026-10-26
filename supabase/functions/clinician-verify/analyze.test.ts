// Çalıştır: node --experimental-strip-types --test supabase/functions/clinician-verify/analyze.test.ts
// Örnek metinler e-Devlet "Yükseköğretim Mezun Belgesi" düzenine benzetilmiştir; gerçek kişi verisi değildir.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { analyze, findBarcode, highestDegree, norm } from './index.ts';

const doc = (program: string, level: string, extra = '') => `T.C. YÜKSEKÖĞRETİM KURULU BAŞKANLIĞI
YÜKSEKÖĞRETİM MEZUN BELGESİ
Adı Soyadı: AYŞE NUR YILMAZ  T.C. Kimlik No: 1**********
Üniversite: ÖRNEK ÜNİVERSİTESİ  Fakülte: Fen-Edebiyat Fakültesi
Program: ${program}  Öğrenim Düzeyi: ${level}  Durumu: Mezun
Mezuniyet Tarihi: 15.06.2019
${extra}
Bu belgenin doğruluğunu https://www.turkiye.gov.tr/belge-dogrulama adresinden Barkod No: YOK-1A2B-3C4D-5E6F ile sorgulayabilirsiniz.`;

test('psikolog lisans: hepsi tamam', () => {
  const a = analyze(doc('PSİKOLOJİ', 'Lisans'), 'Dr. Ayşe Nur Yılmaz', 'psikolog');
  assert.equal(a.hard, null);
  assert.equal(a.barcode, 'YOK-1A2B-3C4D-5E6F');
  assert.deepEqual([a.checks.name, a.checks.program, a.checks.degree, a.checks.edevlet, a.checks.graduate], ['ok', 'ok', 'ok', 'ok', 'ok']);
  assert.equal(a.extracted.university, 'ÖRNEK ÜNİVERSİTESİ');
  assert.equal(a.extracted.graduation_year, '2019');
});

test('klinik psikolog: yalnız lisans yetmez, yüksek lisans gerekir', () => {
  assert.equal(analyze(doc('PSİKOLOJİ', 'Lisans'), 'Ayşe Nur Yılmaz', 'klinik_psikolog').checks.program, 'fail');
  const a = analyze(doc('KLİNİK PSİKOLOJİ', 'Yüksek Lisans', 'Program: PSİKOLOJİ Öğrenim Düzeyi: Lisans'), 'Ayşe Nur Yılmaz', 'klinik_psikolog');
  assert.equal(a.checks.program, 'ok');
  assert.equal(a.checks.degree, 'ok');
});

test('ön lisans lisans yerine geçmez', () => {
  const a = analyze(doc('ÇOCUK GELİŞİMİ', 'Ön Lisans'), 'Ayşe Nur Yılmaz', 'cocuk_gelisimi');
  assert.equal(a.checks.program, 'ok');
  assert.equal(a.checks.degree, 'fail');
  assert.equal(highestDegree(norm('Öğrenim Düzeyi: Ön Lisans')), 'on_lisans');
});

test('ad eşleşmezse fail, kısmi eşleşmede uyarı', () => {
  assert.equal(analyze(doc('PSİKOLOJİ', 'Lisans'), 'Mehmet Demir', 'psikolog').checks.name, 'fail');
  assert.equal(analyze(doc('PSİKOLOJİ', 'Lisans'), 'Ayşe Kaya', 'psikolog').checks.name, 'warn');
});

test('bölüm uymazsa fail', () => {
  assert.equal(analyze(doc('İŞLETME', 'Lisans'), 'Ayşe Nur Yılmaz', 'ergoterapist').checks.program, 'fail');
});

test('öğrenci belgesi ve okunamayan belge kesin ret', () => {
  assert.equal(analyze('T.C. ÖĞRENCİ BELGESİ Psikoloji bölümü 3. sınıf öğrencisidir. Ayşe Nur Yılmaz uzun bir metin burada', 'Ayşe', 'psikolog').hard, 'student_doc');
  assert.equal(analyze('   ', 'Ayşe', 'psikolog').hard, 'unreadable');
});

test('BCBA ve elle incelenen meslekler ön kontrolde bölüm aramaz', () => {
  assert.equal(analyze(doc('PSİKOLOJİ', 'Lisans'), 'Ayşe Nur Yılmaz', 'bcba').checks.program, 'manual');
  assert.equal(analyze(doc('TIP', 'Lisans'), 'Ayşe Nur Yılmaz', 'hekim').checks.program, 'manual');
});

test('barkod etiketsiz de bulunur', () => {
  assert.equal(findBarcode('... YÖK-ab12-CD34-ef56-7890 ...'), 'YÖK-AB12-CD34-EF56-7890');
  assert.equal(findBarcode('barkod yok'), null);
});
