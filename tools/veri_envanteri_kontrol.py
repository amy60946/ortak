#!/usr/bin/env python3
"""Kişisel veri envanteri denetimi: göçlerdeki ve önerilerdeki her `create table public.<ad>` için
hukuk/46-veri-envanteri.md "Ek A" tablosunda satır olmalı. Eksik varsa adları yazar ve 1 ile çıkar.
Çalıştır: python3 tools/veri_envanteri_kontrol.py   (supabase/test/run.sh sonunda da çalışır)"""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
tables = set()
for d in ('supabase/migrations', 'supabase/proposed'):
    for f in sorted((root / d).glob('*.sql')):
        tables |= set(re.findall(r'create\s+table\s+(?:if\s+not\s+exists\s+)?public\.([a-z_][a-z0-9_]*)', f.read_text(), re.I))
inv = (root / 'hukuk/46-veri-envanteri.md').read_text()
listed = set(re.findall(r'^\|\s*`([a-z_][a-z0-9_]*)`\s*\|', inv, re.M))
missing = sorted(tables - listed)
if missing:
    print('Kişisel veri envanterinde olmayan tablo(lar): ' + ', '.join(missing))
    print('hukuk/46-veri-envanteri.md "Ek A" tablosuna kategoriyle (K1–K14 ya da —) ekle; kişisel veri varsa 1. bölümü ve 42 §4\'ü de güncelle.')
    sys.exit(1)
print(f'veri envanteri: {len(tables)} tablonun hepsi listede')
