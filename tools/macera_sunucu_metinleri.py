#!/usr/bin/env python3
"""Sunucu metinleri "macera" kuralına göre (durumlar.md 5B; kullanıcı kararı 5 Kasım 2026).
Her işlevin EN SON tanımını (migrations/ + proposed/, dosya sırasıyla) alır, yalnız aşağıdaki metin parçalarını değiştirir
(mantık, imza ve yetkiler aynı kalır) ve proposed/20261105210000_macera_server_texts.sql dosyasını üretir.
En son tanımı proposed/ içinde olan işlevler (henüz uygulanmamış) burada yazılmaz; onlar kendi önerilerinde düzeltilir.
Çalıştır: python3 tools/macera_sunucu_metinleri.py   (yeniden üretmek güvenlidir)"""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent / 'supabase'
OUT = root / 'proposed' / '20261105210000_macera_server_texts.sql'

# (eski, yeni): tırnak içindeki metin parçaları. Uygulama kodu bu metinlere göre dal ayırmaz (ipucu kodları değişmez).
SUBS = [
    ("' görevi yaptı: '", "' macerayı tamamladı: '"),
    ("'Yeni görev: '", "'Yeni macera: '"),
    ("'Görevler artık oyunda görünüyor.'", "'Maceralar artık oyunda görünüyor.'"),
    ("' görev tamamladı. Birlikte kutlayın!'", "' macera tamamladı. Birlikte kutlayın!'"),
    ("'. Görev ve kayıtları artık görebilirsin.'", "'. Maceraları ve kayıtları artık görebilirsin.'"),
    ("' görev önerisi'", "' macera önerisi'"),
    ("'Görev bulunamadı'", "'Macera bulunamadı'"),
    ("'Bu günün görevi için teklif kaydedilemez'", "'Bu günün macerası için teklif kaydedilemez'"),
    ("'Gelecek günün görevi işaretlenemez'", "'Gelecek günün macerası işaretlenemez'"),
    ("'Geçmiş günün görevi işaretlenemez'", "'Geçmiş günün macerası işaretlenemez'"),
    ("'Rutinde 1–12 görev olmalı'", "'Rutinde 1–12 macera olmalı'"),
    ("'Rutin görevi geçersiz'", "'Rutindeki macera geçersiz'"),
    ("'Değişiklik önerisi yalnız bu çocuğun görevine yapılır'", "'Değişiklik önerisi yalnız bu çocuğun macerasına yapılır'"),
    ("kayıtlı çocuk ya da görev var;", "kayıtlı çocuk ya da macera var;"),
    ("'Görev bu ailenin değil'", "'Macera bu ailenin değil'"),
    ("'Bu görev sana atanmamış'", "'Bu macera sana atanmamış'"),
    ("'Görev o gün yok'", "'Macera o gün yok'"),
    ("'Yalnız son bir haftanın görevi işaretlenebilir'", "'Yalnız son bir haftanın macerası işaretlenebilir'"),
    ("'Yalnız bugünün görevi tekrar denenebilir'", "'Yalnız bugünün macerası tekrar denenebilir'"),
    ("'Ücretsiz planda en çok % etkin görev olabilir'", "'Ücretsiz planda en çok % etkin macera olabilir'"),
]
# Bilerek değişmeyenler: yasal metin tohumları (sürümlü metin, hukuk_notlari 25), yönetim paneli KPI adı 'İlk görev' (iç ekran),
# veritabanı adları ve ipucu kodları.

files = sorted((root / 'migrations').glob('*.sql')) + sorted((root / 'proposed').glob('*.sql'))
files = [f for f in files if f != OUT]
head = re.compile(r'create\s+(?:or\s+replace\s+)?function\s+public\.([a-z0-9_]+)\s*\(', re.I)
latest = {}
for f in files:
    s = f.read_text()
    for m in head.finditer(s):
        dm = re.compile(r'\bas\s+(\$[a-z_]*\$)', re.I).search(s, m.end())
        tag = dm.group(1)
        b1 = s.index(tag, dm.end())
        end = s.index(';', b1 + len(tag)) + 1
        latest[m.group(1)] = (f, s[m.start():end])

parts, used = [], set()
for name in sorted(latest):
    f, text = latest[name]
    new = text
    for a, b in SUBS:
        if a in new:
            new = new.replace(a, b); used.add(a)
    if new == text:
        continue
    if f.parent.name == 'proposed':
        sys.exit(f'{name}: en son tanımı uygulanmamış öneride ({f.name}); metni orada düzelt')
    new = re.sub(r'^create\s+function', 'create or replace function', new, flags=re.I)
    parts.append(f'-- {name} (önceki tanım: migrations/{f.name})\n{new}\n')
missing = [a for a, _ in SUBS if a not in used]
if missing:
    sys.exit('Bulunamayan metin: ' + ', '.join(missing))

OUT.write_text(
    '-- Sunucu metinleri "macera" kuralına göre (kullanıcı kararı 5 Kasım 2026; sozlesme/durumlar.md 5B).\n'
    '-- ÜRETİLDİ: tools/macera_sunucu_metinleri.py — elle düzenleme; aracı değiştirip yeniden üret.\n'
    '-- Her işlevin en son tanımı aynen, yalnız ekranda görünen metin değişti: bildirim başlıkları ("… macerayı tamamladı:",\n'
    '-- "Yeni macera:", "n macera önerisi", "n macera tamamladı") ve hata iletileri ("Macera bulunamadı" …). Mantık, imza,\n'
    '-- yetkiler ve ipucu (hint) kodları değişmez; tetikleyiciler yerinde kalır. Yasal metinler değişmez (avukata soru 25).\n'
    '-- Tekrar çalıştırılabilir (create or replace).\n\n' + '\n'.join(parts))
print(f'{OUT.name}: {len(parts)} işlev')
