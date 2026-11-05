-- Sunucu metinleri "macera" kuralına göre (proposed/20261105210000_macera_server_texts.sql; durumlar.md 5B).
-- Canlıdaki her işlevin gövdesinde eski "görev" metinleri kalmamalı (yasal metin tohumu ve panel KPI adı hariç).
\set ON_ERROR_STOP on
do $$
declare
  old text[] := array[' görevi yaptı: ', 'Yeni görev: ', 'Görevler artık oyunda', ' görev tamamladı.', 'Görev ve kayıtları',
                      ' görev önerisi', 'Görev bulunamadı', 'günün görevi', 'görev olmalı', 'Rutin görevi', 'çocuğun görevine',
                      'ya da görev var', 'Görev bu ailenin', 'Bu görev sana', 'Görev o gün', 'haftanın görevi', 'bugünün görevi',
                      'etkin görev', ' için görev önerdi'];
  r record;
  o text;
begin
  for r in select p.proname, p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' loop
    foreach o in array old loop
      if position(o in r.prosrc) > 0 then
        raise exception 'TEST BAŞARISIZ: % işlevinde eski metin kaldı: "%"', r.proname, o;
      end if;
    end loop;
  end loop;
  if not exists (select 1 from pg_proc where proname = 'completions_notify' and prosrc like '%macerayı tamamladı%') then
    raise exception 'TEST BAŞARISIZ: completions_notify yeni metni yok';
  end if;
  if not exists (select 1 from pg_proc where proname = 'task_assignments_notify' and prosrc like '%Yeni macera: %') then
    raise exception 'TEST BAŞARISIZ: task_assignments_notify yeni metni yok';
  end if;
  raise notice 'ok: sunucu metinlerinde eski "görev" ifadeleri yok';
end $$;
-- tetikleyiciler yerinde
select 1 / (select count(*)::int from pg_trigger where tgname in ('completions_notify', 'task_assignments_notify') and not tgisinternal);
