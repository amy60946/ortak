-- Günlük rutin v2 (kullanıcı kararı 28 Ekim 2026; akislar.md 5.4, veritabani.md 19):
--   B) Rutin aileye TEK PAKET olarak önerilir: rutinin görevleri aynı `routine_group` ile işaretlenmiş ayrı öneri satırlarıdır.
--      ParentApp paketi tek kartta gösterir ("Hepsini ekle" / görev çıkararak ekle). Kabul edilince her görev AYRI görev olur;
--      inceleme (ebeveyn onayı) ve oyun ekranı görev görev çalışır (her görevin kendi eylemi, coin'i, sorumluluğu var).
--      Görevler `tasks.routine_*` ile rutinine bağlı kalır (ParentApp ve ileride oyun gruplu gösterebilir; zorunlu değil).
--   C) Uzmanın kendi rutinleri: `clinic_routines` (klinik içinde; isterse ekibe açık).
--   D) Rutin takip planındaki bir hedefe bağlanabilir: öneride `goal_id` (aynı paylaşımın hedefi).
-- Yaşa göre rutin seçimi veritabanında değil kataloğun kendisinde (veri/hazir_rutinler.json 'ages'; tools/check_routines.py).
-- Yalnız ekleme: var olan sütun, politika ve işlev davranışı değişmez. Tekrar çalıştırılabilir.
-- Önkoşul: migrations/20261019140000_clinic_suggestion_details.sql, 20261021300000_security_pentest.sql (öneri politikaları),
--          20261026100000_family_invite_links.sql (clinic_goals.link_id boş olabilir).

-- ---------------------------------------------------------------------
-- 1. Öneride rutin paketi ve hedef bağı
-- ---------------------------------------------------------------------
alter table public.clinic_task_suggestions
  add column if not exists routine_group    uuid,
  add column if not exists routine_title    text,
  add column if not exists routine_icon     text,
  add column if not exists routine_position smallint,
  add column if not exists routine_key      text,
  add column if not exists goal_id          uuid references public.clinic_goals (id) on delete set null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'cts_routine_check') then
    alter table public.clinic_task_suggestions add constraint cts_routine_check check (
      (routine_group is null and routine_title is null and routine_position is null)
      or (routine_group is not null and coalesce(char_length(routine_title), 0) between 1 and 60
          and coalesce(routine_position, -1) between 0 and 30));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cts_routine_meta_check') then
    alter table public.clinic_task_suggestions add constraint cts_routine_meta_check check (
      (routine_icon is null or char_length(routine_icon) <= 40) and (routine_key is null or char_length(routine_key) <= 60));
  end if;
end $$;
create index if not exists cts_routine_group_idx on public.clinic_task_suggestions (routine_group) where routine_group is not null;
create index if not exists cts_goal_idx on public.clinic_task_suggestions (goal_id) where goal_id is not null;

-- Hedef yalnız aynı paylaşımın hedefi olabilir (başka çocuğun ya da davet taslağının hedefi değil)
create or replace function public.cts_goal_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.goal_id is not null and not exists (
       select 1 from public.clinic_goals g where g.id = new.goal_id and g.link_id = new.link_id) then
    raise exception 'Hedef bu danışanın takip planında değil' using errcode = '23514';
  end if;
  return new;
end $$;
revoke execute on function public.cts_goal_guard() from public, anon, authenticated;
drop trigger if exists cts_goal_guard on public.clinic_task_suggestions;
create trigger cts_goal_guard before insert or update of goal_id, link_id on public.clinic_task_suggestions
  for each row execute function public.cts_goal_guard();

-- ---------------------------------------------------------------------
-- 2. Görevin rutini (ebeveyn yazar; paketten kabul edilen görevler ve ParentApp'in kendi hazır rutinleri)
-- ---------------------------------------------------------------------
alter table public.tasks
  add column if not exists routine_id       uuid,
  add column if not exists routine_title    text,
  add column if not exists routine_icon     text,
  add column if not exists routine_position smallint;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'tasks_routine_check') then
    alter table public.tasks add constraint tasks_routine_check check (
      (routine_id is null and routine_title is null and routine_position is null)
      or (routine_id is not null and coalesce(char_length(routine_title), 0) between 1 and 60
          and (routine_position is null or routine_position between 0 and 30)
          and (routine_icon is null or char_length(routine_icon) <= 40)));
  end if;
end $$;
create index if not exists tasks_routine_idx on public.tasks (routine_id) where routine_id is not null;

-- ---------------------------------------------------------------------
-- 3. Uzmanın kendi rutinleri
-- ---------------------------------------------------------------------
create table if not exists public.clinic_routines (
  id          uuid primary key default gen_random_uuid(),
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  created_by  uuid references public.clinicians (id) on delete set null,
  title       text not null check (char_length(title) between 1 and 60),
  icon        text not null default 'repeat-outline' check (char_length(icon) <= 40),
  repeat      text not null default 'weekdays' check (repeat in ('weekdays', 'daily', 'weekly')),
  ages        text[] not null default '{}' check (ages <@ array['K', 'A', 'B', 'C']::text[]),
  items       jsonb not null default '[]',
  shared      boolean not null default false,
  archived    boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists clinic_routines_clinic_idx on public.clinic_routines (clinic_id);
alter table public.clinic_routines enable row level security;

-- Görevler: [{key?, title, emoji, skill?, category?, difficulty, coins?, time?, days?}] — en çok 12; yalnız bilinen alanlar
create or replace function public.clinic_routines_check() returns trigger
language plpgsql security definer set search_path = '' as $$
declare x jsonb;
begin
  if tg_op = 'INSERT' then
    new.clinic_id := public.my_clinic_id();
    new.created_by := auth.uid();
  else
    new.clinic_id := old.clinic_id;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  if jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) not between 1 and 12 then
    raise exception 'Rutinde 1–12 görev olmalı' using errcode = '23514';
  end if;
  for x in select * from jsonb_array_elements(new.items) loop
    if jsonb_typeof(x) <> 'object'
       or exists (select 1 from jsonb_object_keys(x) k
                  where k not in ('key', 'title', 'emoji', 'skill', 'category', 'difficulty', 'coins', 'time', 'days'))
       or char_length(coalesce(x ->> 'title', '')) not between 1 and 120
       or char_length(coalesce(x ->> 'emoji', '')) > 16
       or coalesce(x ->> 'difficulty', 'easy') not in ('easy', 'medium', 'hard')
       or (x ? 'coins' and (jsonb_typeof(x -> 'coins') <> 'number' or (x ->> 'coins')::numeric not between 0 and 50))
       or (x ? 'time' and coalesce(x ->> 'time', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
       or (x ? 'days' and (jsonb_typeof(x -> 'days') <> 'array'
           or exists (select 1 from jsonb_array_elements_text(x -> 'days') d where d !~ '^[1-7]$')))
       or char_length(coalesce(x ->> 'key', '')) > 60 or char_length(coalesce(x ->> 'skill', '')) > 40
       or char_length(coalesce(x ->> 'category', '')) > 20 then
      raise exception 'Rutin görevi geçersiz' using errcode = '23514';
    end if;
  end loop;
  return new;
end $$;
revoke execute on function public.clinic_routines_check() from public, anon, authenticated;
drop trigger if exists clinic_routines_check on public.clinic_routines;
create trigger clinic_routines_check before insert or update on public.clinic_routines
  for each row execute function public.clinic_routines_check();

-- Okur: kliniğin uzmanı kendi rutinlerini ve ekibe açılmışları; sahibi hepsini. Yazar: oluşturan (ve klinik sahibi).
drop policy if exists "rutin: klinik okur" on public.clinic_routines;
create policy "rutin: klinik okur" on public.clinic_routines for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or shared
              or exists (select 1 from public.clinicians m where m.id = auth.uid() and m.role = 'owner')));
drop policy if exists "rutin: uzman ekler" on public.clinic_routines;
create policy "rutin: uzman ekler" on public.clinic_routines for insert to authenticated
  with check (public.my_clinic_id() is not null and public.clinician_access());
drop policy if exists "rutin: sahibi düzenler" on public.clinic_routines;
create policy "rutin: sahibi düzenler" on public.clinic_routines for update to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or exists (select 1 from public.clinicians m where m.id = auth.uid() and m.role = 'owner')));
drop policy if exists "rutin: sahibi siler" on public.clinic_routines;
create policy "rutin: sahibi siler" on public.clinic_routines for delete to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or exists (select 1 from public.clinicians m where m.id = auth.uid() and m.role = 'owner')));
grant select, insert, update, delete on public.clinic_routines to authenticated;
