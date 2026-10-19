-- =====================================================================
-- ParentApp – görev tekrar ayrıntısı ve görev sırası
-- Supabase panelinde: SQL Editor > New query > bu dosyanın tamamını
-- yapıştır > Run. Birden fazla çalıştırılırsa zarar vermez.
-- =====================================================================

-- Tekrarlayan görev: her gün / haftanın seçilen günleri / ayın seçilen günleri
--   repeat_kind = 'daily'   → her gün
--   repeat_kind = 'weekly'  → repeat_days: 1 = Pazartesi … 7 = Pazar
--   repeat_kind = 'monthly' → repeat_days: ayın günleri 1 … 31
--                             (ayda o gün yoksa ayın son günü sayılır)
alter table public.tasks
  add column if not exists repeat_kind text not null default 'daily',
  add column if not exists repeat_days smallint[] not null default '{}',
  -- Görevler ekranında basılı tutup sürükleyerek değiştirilen sıra (küçük olan üstte)
  add column if not exists sort_order double precision not null
    default extract(epoch from now());

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'tasks_repeat_kind_check') then
    alter table public.tasks add constraint tasks_repeat_kind_check
      check (repeat_kind in ('daily', 'weekly', 'monthly'));
  end if;
end $$;

-- Mevcut görevler oluşturulma sırasını korusun
update public.tasks set sort_order = extract(epoch from created_at)
  where sort_order >= extract(epoch from now()) - 5;
