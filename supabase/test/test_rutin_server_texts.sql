-- Sunucu metinleri ad kuralına göre (sozlesme/durumlar.md 5B):
--   5 Kasım 2026: eski "görev" metinleri kalmadı (migrations/20261105210000_macera_server_texts.sql);
--   14 Kasım 2026: aile ve uzman tarafında "rutin / adım", oyunda "macera" (proposed/20261120100000_rutin_server_texts.sql);
--   rozet bildirimi "Belge yüklendi" (hukuk_notlari M.3); eski ürün adları sunucu metninde yok.
\set ON_ERROR_STOP on
do $$
declare
  old text[] := array[' görevi yaptı: ', 'Yeni görev: ', 'Görevler artık oyunda', ' görev tamamladı.', 'Görev ve kayıtları',
                      ' görev önerisi', 'Görev bulunamadı', 'günün görevi', 'görev olmalı', 'Rutin görevi', 'çocuğun görevine',
                      'ya da görev var', 'Görev bu ailenin', 'Bu görev sana', 'Görev o gün', 'haftanın görevi', 'bugünün görevi',
                      'etkin görev', ' için görev önerdi'];
  -- ebeveyne ve uzmana giden işlevlerde "macera" yalnız oyunu anlatan cümlede geçebilir
  side text[] := array['completions_notify', 'claim_weekly_goal', 'care_plan_publish', 'care_plan_publish_selected',
                       'suggestions_notify', 'join_family', 'parent_assignments_guard', 'parent_task_done', 'review_completion',
                       'tasks_free_limit', 'clinic_links_notify_insert', 'clinic_routines_check', 'cts_change_guard'];
  r record;
  o text;
begin
  for r in select p.proname, p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' loop
    foreach o in array old loop
      if position(o in r.prosrc) > 0 then
        raise exception 'TEST BAŞARISIZ: % işlevinde eski metin kaldı: "%"', r.proname, o;
      end if;
    end loop;
    if r.proname = any(side) and r.prosrc ~* 'macera' then
      raise exception 'TEST BAŞARISIZ: % (aile/uzman tarafı) "macera" diyor', r.proname;
    end if;
    if r.prosrc ~ '(Ayrıntı ClinicApp|GameApp koşullarını|ClinicApp''''ten ya da)' then
      raise exception 'TEST BAŞARISIZ: % metninde eski ürün adı var', r.proname;
    end if;
    if position('Belgen incelendi' in r.prosrc) > 0 or position('Belgesi incelendi' in r.prosrc) > 0 then
      raise exception 'TEST BAŞARISIZ: % eski rozet metni', r.proname;
    end if;
  end loop;
  if not exists (select 1 from pg_proc where proname = 'completions_notify' and prosrc like '%adımı tamamladı: %') then
    raise exception 'TEST BAŞARISIZ: completions_notify yeni metni yok';
  end if;
  if not exists (select 1 from pg_proc where proname = 'children_notify_device' and prosrc like '%rutinler artık oyunda macera olarak%') then
    raise exception 'TEST BAŞARISIZ: children_notify_device yeni metni yok';
  end if;
  if not exists (select 1 from pg_proc where proname = 'admin_verification_decide' and prosrc like '%''Belge yüklendi''%') then
    raise exception 'TEST BAŞARISIZ: rozet bildirimi "Belge yüklendi" değil';
  end if;
  -- oyun tarafı "macera" kalır
  if not exists (select 1 from pg_proc where proname = 'task_assignments_notify' and prosrc like '%Yeni macera: %') then
    raise exception 'TEST BAŞARISIZ: çocuğa giden "Yeni macera" metni değişmemeli';
  end if;
  if not exists (select 1 from pg_proc where proname = 'child_set_status' and prosrc like '%Macera bulunamadı%') then
    raise exception 'TEST BAŞARISIZ: oyundaki hata metni "macera" kalmalı';
  end if;
  raise notice 'ok: aile/uzman "rutin / adım", oyun "macera", rozet "Belge yüklendi"';
end $$;
-- tetikleyiciler yerinde, yetkiler korunur (create or replace)
select 1 / (select count(*)::int from pg_trigger where tgname in ('completions_notify', 'task_assignments_notify') and not tgisinternal);
select 1 / (not has_function_privilege('anon', 'public.parent_task_done(uuid, date, boolean)', 'execute'))::int;
select 1 / has_function_privilege('authenticated', 'public.parent_task_done(uuid, date, boolean)', 'execute')::int;
