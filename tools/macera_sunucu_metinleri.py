#!/usr/bin/env python3
"""Sunucu metinleri ad kuralına göre (sozlesme/durumlar.md 5B).

Geçmiş: 5 Kasım 2026 kuralı ("görev" → "macera", üç üründe) migrations/20261105210000_macera_server_texts.sql ile uygulandı.
Bugünkü kural (kullanıcı kararı 14 Kasım 2026): aile (Moyo) ve uzman (Moyo Mercek) tarafında **rutin** (paket) ve **adım**
(tek iş); oyunda (Moyo Oyun) **macera** kalır. Aynı metin çocuğa ve ebeveyne giden işlevlerde ortak olabildiği için
değişiklikler İŞLEV ADIYLA verilir: çocuğa giden işlevler (child_*, task_assignments_notify) listede yoktur.
Aynı dosyada iki metin düzeltmesi daha: uzman rozeti "Belgen incelendi" → "Belge yüklendi" (hukuk_notlari M.3) ve
eski ürün adları (ClinicApp, ParentApp, GameApp → Moyo Mercek, Moyo, Moyo Oyun).

Her işlevin EN SON tanımını (migrations/ + proposed/, dosya sırasıyla) alır, yalnız aşağıdaki metin parçalarını değiştirir
(mantık, imza ve yetkiler aynı kalır) ve migrations/20261120100000_rutin_server_texts.sql dosyasını üretir
(UYGULANDI 20 Kasım 2026: öneri proposed/'dan migrations/'a taşındı; araç kayıt için durur, yeniden üretmek aynı dosyayı verir). Bu dosya
20261105210000_macera_server_texts'in yerine geçer (aynı işlevlerin yeni tanımı); eski göç uygulanmış geçmiş olarak kalır.
En son tanımı proposed/ içinde başka bir önerideyse araç durur (metni orada düzelt).
Çalıştır: python3 tools/macera_sunucu_metinleri.py   (yeniden üretmek güvenlidir)"""
import pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent / 'supabase'
OUT = root / 'migrations' / '20261120100000_rutin_server_texts.sql'

# işlev → [(eski, yeni)]: tırnak içindeki metin parçaları. Uygulama kodu bu metinlere göre dal ayırmaz (ipucu kodları değişmez).
SUBS = {
    # Ebeveyne (Moyo) giden bildirimler ve hatalar
    'completions_notify': [("' macerayı tamamladı: '", "' adımı tamamladı: '")],
    'claim_weekly_goal': [("' macera tamamladı. Birlikte kutlayın!'", "' adım tamamladı. Birlikte kutlayın!'")],
    'children_notify_device': [("'Maceralar artık oyunda görünüyor.'", "'Eklediğin rutinler artık oyunda macera olarak görünüyor.'")],
    'care_plan_publish': [("' macera önerisi'", "' adım önerisi'")],
    'care_plan_publish_selected': [("' macera önerisi'", "' adım önerisi'")],
    'suggestions_notify': [("' için macera önerdi'", "' için adım önerdi'")],
    'join_family': [("kayıtlı çocuk ya da macera var;", "kayıtlı çocuk ya da rutin var;")],
    'parent_assignments_guard': [("'Macera bu ailenin değil'", "'Adım bu ailenin değil'")],
    'parent_task_done': [("'Bu macera sana atanmamış'", "'Bu adım sana atanmamış'"),
                         ("'Macera o gün yok'", "'Adım o gün yok'"),
                         ("'Yalnız son bir haftanın macerası işaretlenebilir'", "'Yalnız son bir haftanın adımı işaretlenebilir'")],
    'review_completion': [("'Yalnız bugünün macerası tekrar denenebilir'", "'Yalnız bugünün adımı tekrar denenebilir'")],
    'tasks_free_limit': [("'Ücretsiz planda en çok % etkin macera olabilir'", "'Ücretsiz planda en çok % etkin adım olabilir'")],
    'legal_accept': [("'GameApp koşullarını veli ParentApp''te onaylar'", "'Moyo Oyun koşullarını veli Moyo''da onaylar'")],
    # Uzmana (Moyo Mercek) giden bildirimler ve hatalar
    'clinic_links_notify_insert': [("'. Maceraları ve kayıtları artık görebilirsin.'", "'. Rutinleri ve kayıtları artık görebilirsin.'")],
    'clinic_routines_check': [("'Rutinde 1–12 macera olmalı'", "'Rutinde 1–12 adım olmalı'"),
                              ("'Rutindeki macera geçersiz'", "'Rutindeki adım geçersiz'")],
    'cts_change_guard': [("'Değişiklik önerisi yalnız bu çocuğun macerasına yapılır'",
                          "'Değişiklik önerisi yalnız bu çocuğun adımına yapılır'")],
    'admin_verification_decide': [
        ("'Belgen incelendi'", "'Belge yüklendi'"),
        ("""'Ailelerin davet ekranında "Belgesi incelendi: '""", """'Panelinde "Belge yüklendi: '"""),
        ("""'" görünür.'""", """'" görünür; ailelere "Uzman diploma belgesini yükledi" yazar.'"""),
        ("'Ayrıntı ClinicApp''te.'", "'Ayrıntı Moyo Mercek''te.'")],
    # Uzmanın KVKK veri kopyasındaki not (uzman sözleşmesi: dışa aktarma sözü daraltıldı, hukuk avukat dosyası)
    'data_export_of': [("'Danışanlarla ilgili notlar, hedefler ve takip planı kliniğin kaydıdır; ClinicApp''ten ya da destek talebiyle ayrıca dışa aktarılır.'",
                        "'Ailelerle ilgili notlar, hedefler ve takip planı uzmanın kendi mesleki kaydıdır ve bu dosyaya girmez; rapor ve CSV Moyo Mercek''ten indirilir.'")],
}
# Bilerek değişmeyenler: çocuğa (Moyo Oyun) giden metinler ("Yeni macera: …", "Macera bulunamadı", "Gelecek günün macerası …"),
# görev şablonu başlıkları (çocuk oyunda görür), ebeveyn eğitimindeki "Uygulama görevleri" (ayrı kavram), yönetim paneli KPI
# adı 'İlk görev' (iç ekran), yasal metin tohumları (tools/legal_seed.py), veritabanı adları ve ipucu kodları.

files = sorted((root / 'migrations').glob('*.sql')) + sorted((root / 'proposed').glob('*.sql'))
files = [f for f in files if f != OUT and not f.name.endswith('_legal_seed.sql')]
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

parts, missing = [], []
for name, subs in SUBS.items():
    if name not in latest:
        sys.exit(f'{name}: işlev bulunamadı')
    f, text = latest[name]
    if f.parent.name == 'proposed':   # başka bir uygulanmamış öneri bu işlevi yeniden tanımlıyor
        sys.exit(f'{name}: en son tanımı uygulanmamış öneride ({f.name}); metni orada düzelt')
    new = text
    for a, b in subs:
        if a not in new:
            missing.append(f'{name}: {a}')
        new = new.replace(a, b)
    new = re.sub(r'^create\s+function', 'create or replace function', new, flags=re.I)
    parts.append(f'-- {name} (önceki tanım: {f.parent.name}/{f.name})\n{new}\n')
if missing:
    sys.exit('Bulunamayan metin:\n' + '\n'.join(missing))

OUT.write_text(
    '-- Sunucu metinleri: aile ve uzman tarafında "rutin / adım", oyunda "macera" (kullanıcı kararı 14 Kasım 2026;\n'
    '-- sozlesme/durumlar.md 5B). 20261105210000_macera_server_texts\'in yerine geçer. Ayrıca uzman rozeti bildirimi\n'
    '-- "Belgen incelendi" → "Belge yüklendi" (sozlesme/hukuk_notlari.md M.3) ve eski ürün adları → Moyo adları.\n'
    '-- ÜRETİLDİ: tools/macera_sunucu_metinleri.py — elle düzenleme; aracı değiştirip yeniden üret.\n'
    '-- Her işlevin en son tanımı aynen, yalnız ekranda görünen metin değişti. Mantık, imza, yetkiler ve ipucu (hint)\n'
    '-- kodları değişmez; tetikleyiciler yerinde kalır. Çocuğa giden metinler ("Yeni macera: …") değişmez.\n'
    '-- Tekrar çalıştırılabilir (create or replace).\n\n' + '\n'.join(parts))
print(f'{OUT.name}: {len(parts)} işlev')
