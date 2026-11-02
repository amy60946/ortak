-- =====================================================================
-- Oyunda rutin kartı (28 Ekim 2026, kullanıcı onayı "Evet, yap"; ClinicApp penceresinin önerisi, akislar.md 5.4 adım 9)
--   Uzmanın ya da ebeveynin rutin paketinden gelen görevler (tasks.routine_*, öneri 20261028200000_routines_v2) oyunda
--   tek bir "rutin kartı" altında sırayla görünür. Bunun için child_tasks yanıtına dört alan eklenir:
--   routine_id, routine_title, routine_icon, routine_position (rutinsiz görevde dördü de null).
--   Ekonomi değişmez: her görev yine ayrı "Yaptım", ayrı onay, ayrı coin; rutin bitince ek coin yok.
-- Geriye uyum: yalnız sütun eklenir (eski oyun sürümü fazla alanı yok sayar). routines_v2 henüz uygulanmamışsa
-- sütunlar burada da açılır (aynı tip, "if not exists"; kısıt routines_v2'de).
-- Tekrar çalıştırılabilir.
-- =====================================================================

alter table public.tasks
  add column if not exists routine_id       uuid,
  add column if not exists routine_title    text,
  add column if not exists routine_icon     text,
  add column if not exists routine_position smallint;

-- dönüş tipi değiştiği için düşürülüp yeniden kurulur; gövde 20261022210000_task_reminder_boost ile aynı + rutin alanları
drop function if exists public.child_tasks(date, date);
create function public.child_tasks(p_from date, p_to date)
returns table (task_id uuid, date date, title text, description text, emoji text, coins integer,
               recurring boolean, repeat_kind text, requires_review boolean, status text, parent_note text,
               skill text, difficulty text, reminder text,
               routine_id uuid, routine_title text, routine_icon text, routine_position smallint)
language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  if p_to < p_from or p_to - p_from > 31 then
    raise exception 'Tarih aralığı en fazla 31 gün olabilir';
  end if;
  return query
    select t.id, d::date, t.title, t.description, t.emoji, a.coins, t.recurring, t.repeat_kind, t.requires_review,
           coalesce(c.status, 'assigned'), c.parent_note, t.skill, a.difficulty, t.reminder::text,
           t.routine_id, t.routine_title, t.routine_icon, t.routine_position
    from public.task_assignments a
    join public.tasks t on t.id = a.task_id
    cross join generate_series(p_from, p_to, interval '1 day') as d
    left join public.completions c on c.task_id = t.id and c.child_id = me and c.date = d::date
    where a.child_id = me and public.task_occurs_on(t, d::date)
    order by d, t.sort_order;
end $$;
revoke execute on function public.child_tasks(date, date) from public, anon;
grant execute on function public.child_tasks(date, date) to authenticated;
