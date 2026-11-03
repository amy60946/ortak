-- Uzman notu bir hedefe bağlanabilir (ClinicApp "N3", kullanıcı kararı 3 Kasım 2026): Takip Planı'nda hedefin bej
-- "YALNIZ SEN GÖRÜRSÜN" kutusundaki not simgesi; not danışan › Notlar'da da hedefin adıyla görünür. Aile görmez
-- (clinic_notes zaten yalnız klinik okur; RLS değişmez). Değerlendirme notu ayrıca goal_ratings.note'ta (sütun 19 Ekim'den beri var).
-- Tekrar çalıştırılabilir.

alter table public.clinic_notes add column if not exists goal_id uuid references public.clinic_goals (id) on delete set null;
create index if not exists clinic_notes_goal_idx on public.clinic_notes (goal_id) where goal_id is not null;

-- Hedef, notun danışanına (bağlantısına) ait olmalı: başka çocuğun hedefine not bağlanamaz
create or replace function public.clinic_notes_goal_check() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.goal_id is not null and not exists (
    select 1 from public.clinic_goals g where g.id = new.goal_id and g.link_id = new.link_id
  ) then
    raise exception 'goal_link_mismatch' using errcode = '23514';
  end if;
  return new;
end $$;
revoke execute on function public.clinic_notes_goal_check() from public, anon;

drop trigger if exists clinic_notes_goal_check on public.clinic_notes;
create trigger clinic_notes_goal_check before insert or update of goal_id on public.clinic_notes
  for each row execute function public.clinic_notes_goal_check();
