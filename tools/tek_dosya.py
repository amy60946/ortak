#!/usr/bin/env python3
"""Edge Function'ı tek dosyaya birleştirir (Supabase panelindeki editörde ikinci dosya eklenemiyor, 11 Kasım 2026).

Kullanım: python3 tools/tek_dosya.py billing-webhook
Kaynak: supabase/functions/<ad>/index.ts + state.ts → supabase/functions/_tek-dosya/<ad>.ts
Kural: index.ts'teki `import … from './state.ts'` satırı kalkar, state.ts'in içeriği ilk importtan sonra
`export` sözcükleri çıkarılarak araya girer. Çıktı elle düzenlenmez.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent / 'supabase' / 'functions'
name = sys.argv[1] if len(sys.argv) > 1 else 'billing-webhook'
src = root / name
index = (src / 'index.ts').read_text().splitlines()
state = (src / 'state.ts').read_text().splitlines()

head = [
    '// ÜRETİLDİ — elle düzenlenmez. Kaynak: supabase/functions/%s/index.ts + state.ts (tek dosyada birleşik).' % name,
    '// Neden: Supabase panelindeki editörde ikinci dosya eklemek hata verdi (11 Kasım 2026); bu dosya tek başına yapıştırılır.',
    '// Kaynak değişirse yeniden üretilir (python3 tools/tek_dosya.py %s); iki sürümün derlenmiş çıktısı aynı olmalıdır.' % name,
]
local = [i for i, l in enumerate(index) if re.match(r"^import .* from '\./state\.ts';$", l)]
if len(local) != 1:
    sys.exit('index.ts içinde tek bir ./state.ts importu bekleniyordu')
cut = local[0]
before, after = index[:cut], index[cut + 1:]
body = ['// ---- state.ts (birleşik) ----'] + [re.sub(r'^export ', '', l) for l in state] + ['// ---- index.ts devamı ----']
out = head + before + body + after
(root / '_tek-dosya' / f'{name}.ts').write_text('\n'.join(out) + '\n')
print(f'yazıldı: supabase/functions/_tek-dosya/{name}.ts ({len(out)} satır)')
