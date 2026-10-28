#!/usr/bin/env python3
"""Hazır rutin kataloğunu denetler (veri/hazir_rutinler.json):
- her görev anahtarı veri/gorev_sablonlari.json'da var
- her görevin yaşları rutinin bütün yaş gruplarını kapsar (yaşa uymayan görev rutine giremez)
- yaş grupları K/A/B/C; aynı konunun sürümleri yaşta çakışmaz; saat HH:MM; haftalıkta gün 1–7
Kullanım: python3 tools/check_routines.py  (hata varsa çıkış kodu 1)"""
import json, re, sys, os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cat = {t['key']: t for t in json.load(open(os.path.join(root, 'veri/gorev_sablonlari.json')))['templates']}
data = json.load(open(os.path.join(root, 'veri/hazir_rutinler.json')))
errs, ids, seen = [], set(), {}
for r in data['routines']:
    rid = r['id']
    if rid in ids: errs.append(f'{rid}: kimlik tekrar')
    ids.add(rid)
    ages = r.get('ages') or []
    if not ages or any(a not in 'KABC' or len(a) != 1 for a in ages): errs.append(f'{rid}: yaş grupları K/A/B/C olmalı')
    for a in ages:
        key = (r.get('theme', rid), a)
        if key in seen: errs.append(f'{rid}: {a} grubu {seen[key]} ile çakışıyor')
        seen[key] = rid
    if r.get('repeat') not in ('weekdays', 'daily', 'weekly'): errs.append(f'{rid}: tekrar')
    if not r.get('items'): errs.append(f'{rid}: görev yok')
    for i in r.get('items', []):
        t = cat.get(i['key'])
        if not t: errs.append(f'{rid}: {i["key"]} katalogda yok'); continue
        miss = [a for a in ages if a not in t['ages']]
        if miss: errs.append(f'{rid}: "{t["title"]}" {"".join(miss)} grubuna uygun değil (görev: {"".join(t["ages"])})')
        if not re.fullmatch(r'([01]\d|2[0-3]):[0-5]\d', i.get('time', '')): errs.append(f'{rid}: {i["key"]} saat')
        if r.get('repeat') == 'weekly' and not (i.get('days') and all(1 <= d <= 7 for d in i['days'])): errs.append(f'{rid}: {i["key"]} günler')
if errs:
    print('\n'.join(errs)); sys.exit(1)
print(f'{len(data["routines"])} rutin, {sum(len(r["items"]) for r in data["routines"])} görev: tamam')
