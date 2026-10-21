-- =====================================================================
-- ParentApp istekleri (öneri, 19 Ekim 2026)
--   1. Görev kategorileri 6'ya çıktı: home, mind, learn, health, focus, relation ('self' → 'health').
--   2. Görevin gün bölümü: tasks.day_part = morning | noon | evening | null (= herhangi). Görevler ekranı filtresi.
--   3. Zor an kaydı (abc_events):
--        day_part (morning | noon | evening | night) — ebeveyn seçer; occurred_at o bölümün temsil saatine yazılır
--        group_id — aynı olay birden çok çocukla ilgiliyse her çocuğa bir satır, ortak group_id
--        audio_path, duration_ms — ebeveynin sesli kaydı (Storage kovası 'abc', yol <family_id>/<dosya>)
--      Uzman sesi yalnız rızalı (active) bağlantıdaki çocuğun kaydına aitse dinleyebilir.
--   4. Zor an bildirimi deyim düzeyinde: aynı anda kaydedilen çocuklar uzmana TEK bildirimde.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- 1. Kategoriler
alter table public.saved_templates drop constraint if exists saved_templates_category_check;
update public.saved_templates set category = 'health' where category = 'self';
alter table public.saved_templates add constraint saved_templates_category_check
  check (category in ('home', 'mind', 'learn', 'health', 'focus', 'relation'));

-- 2. Görevin gün bölümü
alter table public.tasks add column if not exists day_part text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'tasks_day_part_check') then
    alter table public.tasks add constraint tasks_day_part_check check (day_part in ('morning', 'noon', 'evening'));
  end if;
end $$;

-- 3. Zor an
alter table public.abc_events add column if not exists day_part text;
alter table public.abc_events add column if not exists group_id uuid;
alter table public.abc_events add column if not exists audio_path text;
alter table public.abc_events add column if not exists duration_ms integer;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'abc_events_day_part_check') then
    alter table public.abc_events add constraint abc_events_day_part_check check (day_part in ('morning', 'noon', 'evening', 'night'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'abc_events_audio_path_check') then
    -- ses dosyası ailenin klasöründe olmalı
    alter table public.abc_events add constraint abc_events_audio_path_check
      check (audio_path is null or split_part(audio_path, '/', 1) = family_id::text);
  end if;
end $$;
-- eski kayıtların gün bölümü saatinden (sabah 05–11, öğle 11–16, akşam 16–21, gece 21–05)
update public.abc_events set day_part = case
    when extract(hour from occurred_at) >= 5 and extract(hour from occurred_at) < 11 then 'morning'
    when extract(hour from occurred_at) >= 11 and extract(hour from occurred_at) < 16 then 'noon'
    when extract(hour from occurred_at) >= 16 and extract(hour from occurred_at) < 21 then 'evening'
    else 'night' end
  where day_part is null;
create index if not exists abc_events_group_idx on public.abc_events (group_id);

-- Ses kovası: aile yükler/okur/siler; uzman yalnız rızalı çocuğun kaydına bağlı sesi okur
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('abc', 'abc', false, 10485760, array['audio/m4a', 'audio/mp4', 'audio/x-m4a', 'audio/aac', 'audio/mpeg', 'audio/webm'])
on conflict (id) do nothing;
drop policy if exists "zor an sesi: aile okur" on storage.objects;
create policy "zor an sesi: aile okur" on storage.objects for select to authenticated
  using (bucket_id = 'abc' and (storage.foldername(name))[1] = public.my_family_id()::text);
drop policy if exists "zor an sesi: aile yükler" on storage.objects;
create policy "zor an sesi: aile yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'abc' and (storage.foldername(name))[1] = public.my_family_id()::text);
drop policy if exists "zor an sesi: aile siler" on storage.objects;
create policy "zor an sesi: aile siler" on storage.objects for delete to authenticated
  using (bucket_id = 'abc' and (storage.foldername(name))[1] = public.my_family_id()::text);
drop policy if exists "zor an sesi: bağlı uzman dinler" on storage.objects;
create policy "zor an sesi: bağlı uzman dinler" on storage.objects for select to authenticated
  using (bucket_id = 'abc' and exists (
    select 1 from public.abc_events e where e.audio_path = storage.objects.name and public.clinic_sees_child(e.child_id)));

-- 4. Zor an bildirimi: aynı INSERT'teki çocuklar uzman başına tek bildirim
create or replace function public.abc_events_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in
    select l.clinic_id, l.clinician_id, count(*) as n, string_agg(c.name, ', ' order by c.name) as names,
           max(n.intensity) as intensity, bool_or(n.audio_path is not null) as has_audio,
           (array_agg(n.child_id))[1] as first_child,
           jsonb_agg(jsonb_build_object('abc_id', n.id, 'child_id', n.child_id)) as items
      from new_rows n
      join public.clinic_links l on l.child_id = n.child_id and l.status = 'active'
      join public.children c on c.id = n.child_id
     group by l.clinic_id, l.clinician_id
  loop
    perform public.notify_clinic(r.clinic_id, r.clinician_id, 'abc_event', 'Yeni zor an kaydı: ' || r.names,
      'Şiddet ' || r.intensity || '/5' || case when r.has_audio then ' · 🎤 sesli kayıt' else '' end,
      jsonb_build_object('items', r.items, 'abc_id', (r.items -> 0 ->> 'abc_id'), 'child_id', r.first_child),
      case when r.n = 1 then r.first_child end);
  end loop;
  return null;
end $$;
drop trigger if exists abc_events_notify on public.abc_events;
create trigger abc_events_notify after insert on public.abc_events
  referencing new table as new_rows for each statement execute function public.abc_events_notify();
revoke execute on function public.abc_events_notify() from public, anon, authenticated;
