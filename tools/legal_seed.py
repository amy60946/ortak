#!/usr/bin/env python3
"""ortak/hukuk/*.md → supabase/proposed/<zaman>_legal_seed.sql (legal_documents taslak gövdeleri).

Kullanım: python3 tools/legal_seed.py [çıktı.sql]
- İlk seed `migrations/20261027210000_legal_seed.sql` (uygulandı 27 Ekim 2026). Metin değişince yeni dosya üretilir:
  varsayılan çıktı `supabase/proposed/<UTC zaman>_legal_seed.sql`; her seed bütün metinleri taşıdığı için proposed'daki
  eski (uygulanmamış) seed dosyası silinir, kullanıcıya yalnız en yenisi verilir.
- Herkese açık metinlerden başlıktaki künye tablosu ve "## Avukata notlar" bölümü çıkarılır (iç notlar yayımlanmaz).
- Yalnız taslak (draft) satırlar güncellenir; yayımlanmış sürüm değişmez (yeni metin = yeni sürüm: dosyadaki "Sürüm" alanını artır).
- İç belgeler (saklama-imha, ihlal prosedürü, uygulama içi metinler, olgular) yüklenmez.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HUKUK = ROOT / 'hukuk'
ALL = ['parent', 'child', 'clinic', 'web']
# dosya → (anahtar, uygulamalar, onay ister mi)
FILES = {
    '01-gizlilik-politikasi.md': ('gizlilik', ALL, False),
    '10-aydinlatma-ebeveyn.md': ('aydinlatma-ebeveyn', ['parent'], True),
    '11-aydinlatma-cocuk-ve-veli.md': ('aydinlatma-cocuk', ['child'], True),
    '12-aydinlatma-uzman.md': ('aydinlatma-uzman', ['clinic'], True),
    '20-kullanim-kosullari-parentapp.md': ('kosullar-parentapp', ['parent'], True),
    '21-kullanim-kosullari-gameapp.md': ('kosullar-gameapp', ['child'], True),
    '22-uzman-hizmet-sozlesmesi.md': ('sozlesme-uzman', ['clinic'], True),
    '23-veri-isleme-eki.md': ('veri-isleme-eki', ['clinic'], True),
    '30-acik-riza-metinleri.md': ('acik-riza-metinleri', ['parent', 'web'], False),
    '40-cerez-politikasi.md': ('cerez-clinicapp-web', ['clinic', 'web'], False),
    '41-alt-isleyenler.md': ('alt-isleyenler', ALL, False),
    '44-kvkk-basvuru-usulu.md': ('kvkk-basvuru', ALL, False),
}


def public_body(text: str) -> tuple[str, str, str]:
    lines = text.splitlines()
    title = next((l[2:].strip() for l in lines if l.startswith('# ')), 'Yasal metin')
    ver = 'v1'
    m = re.search(r'\|\s*Sürüm\s*\|\s*(v\d+)\s*\|', text)
    if m:
        ver = m.group(1)
    out, i = [], 0
    while i < len(lines) and not lines[i].startswith('# '):
        i += 1
    out.append(lines[i] if i < len(lines) else '# ' + title)
    i += 1
    while i < len(lines) and (lines[i].startswith('|') or not lines[i].strip()):   # künye tablosu (H1'in hemen altı)
        i += 1
    # künyenin altındaki iç kaynak notu ("> Taslak, 27 Ekim … Olgular: hukuk/…") yayımlanmaz
    if i < len(lines) and lines[i].startswith('> Taslak'):
        while i < len(lines) and lines[i].startswith('>'):
            i += 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    out += [''] + lines[i:]
    body = '\n'.join(out)
    body = re.split(r'\n##\s+Avukata notlar.*', body, maxsplit=1)[0].rstrip() + '\n'
    return title, ver, clean_internal(body)


# Herkese açık metinde iç atıf kalmasın: <!-- iç -->…<!-- /iç --> blokları, dosya/yol atıflı parantezler silinir;
# başka metne atıf (dosya adı ya da anahtar) o metnin sayfasına bağlantı olur (/yasal/<anahtar>; uygulamalar bu yolu kendi okuyucusunda açar).
INTERNAL = r'(?:hukuk/|sozlesme/|supabase/|CANLIYA_ALMA|DURUM\.md|hukuk_notlari|\.md\b|\.sql\b)'


def clean_internal(body: str) -> str:
    body = re.sub(r'<!--\s*iç\s*-->.*?<!--\s*/iç\s*-->\n?', '', body, flags=re.S)
    body = re.sub(r'\s*\((?:[^()\n]*?)`[^`\n]*' + INTERNAL + r'[^`\n]*`(?:[^()\n]*?)\)', '', body)
    def link(m: re.Match) -> str:
        ref = m.group(1)
        name = ref.split('/')[-1]
        key = FILES.get(name, (None,))[0] if name in FILES else (ref if ref in KEYS else None)
        return f'[{TITLES.get(key, key)}](/yasal/{key})' if key else m.group(0)
    body = re.sub(r'`((?:hukuk/)?[0-9]{2}-[a-z0-9-]+\.md|[a-z][a-z0-9-]+)`', link, body)
    return body


KEYS = {v[0] for v in FILES.values()}
TITLES: dict = {}


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def load_titles() -> None:
    for name, (key, _, _) in FILES.items():
        f = HUKUK / name
        if f.exists():
            TITLES[key] = next((l[2:].strip() for l in f.read_text(encoding='utf-8').splitlines() if l.startswith('# ')), key)


def main() -> None:
    load_titles()
    if len(sys.argv) > 1:
        out = pathlib.Path(sys.argv[1])
    else:
        import datetime
        for old in (ROOT / 'supabase/proposed').glob('*_legal_seed.sql'):
            old.unlink()   # uygulanmamış eski seed: yerini en yenisi alır
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S')
        out = ROOT / f'supabase/proposed/{stamp}_legal_seed.sql'
    parts = ['-- Yasal metin taslakları (üretildi: python3 tools/legal_seed.py; kaynak ortak/hukuk/*.md). Elle düzenleme.',
             '-- Önkoşul: migrations/20261027200000_legal.sql. Yalnız taslak satırlar güncellenir; yayımlanmış sürüm değişmez. Tekrar çalıştırılabilir.', '']
    for name, (key, apps, req) in FILES.items():
        f = HUKUK / name
        if not f.exists():
            print(f'eksik: {name}', file=sys.stderr)
            continue
        title, ver, body = public_body(f.read_text(encoding='utf-8'))
        tag = '$md$'
        assert tag not in body, name
        parts.append(
            f"insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md)\n"
            f"values ({q(key)}, {q(ver)}, {q(title)}, '{{{','.join(apps)}}}', {'true' if req else 'false'}, {tag}{body}{tag})\n"
            f"on conflict (key, version) do update set title = excluded.title, apps = excluded.apps,\n"
            f"  requires_acceptance = excluded.requires_acceptance, body_md = excluded.body_md\n"
            f"where public.legal_documents.status = 'draft';\n")
    out.write_text('\n'.join(parts), encoding='utf-8')
    print(out)


if __name__ == '__main__':
    main()
