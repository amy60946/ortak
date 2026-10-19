-- =====================================================================
-- Görev ödülü kuralları (öneri, 19 Ekim 2026)
--   1. Onay geri alınınca, o görev için gerçekten verilmiş coin kadar düşülür
--      (önceden: o anki task_assignments.coins kadar; ödül sonradan değiştiyse yanlış tutar).
--   2. Görev ya da atama silinince kazanılmış coin geri alınmaz
--      (önceden: silme sırasına göre bazen alınıyor, bazen alınmıyordu).
--   3. Görev ödülüne üst sınır: 0–50 coin (oyunun sahte arka ucuyla aynı sınır).
--      Var olan satırlara dokunulmaz (not valid); yalnız yeni/değişen satırlar denetlenir.
--   4. ParentApp onayı da reddi gibi review_completion ile yapar (şema değişikliği yok; sözleşme kuralı).
-- Tekrar çalıştırılabilir.
-- =====================================================================

create or replace function public.completions_coin_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  coins integer;
  was_approved boolean := tg_op in ('UPDATE', 'DELETE') and old.status = 'approved';
  is_approved boolean := tg_op in ('INSERT', 'UPDATE') and new.status = 'approved';
  row_ public.completions%rowtype;
begin
  if tg_op = 'DELETE' then row_ := old; else row_ := new; end if;
  if is_approved = was_approved then
    return null;
  end if;
  if is_approved then
    select a.coins into coins from public.task_assignments a where a.task_id = row_.task_id and a.child_id = row_.child_id;
    coins := coalesce(coins, 0);
  else
    -- Görev ya da atama silindiyse (silme zinciri) kazanılmış coin çocukta kalır.
    if tg_op = 'DELETE' and (
      not exists (select 1 from public.tasks t where t.id = row_.task_id)
      or not exists (select 1 from public.task_assignments a where a.task_id = row_.task_id and a.child_id = row_.child_id)
    ) then
      return null;
    end if;
    -- Bu tamamlama için defterde kalan net tutar (verilen − geri alınan) kadar düşülür.
    select coalesce(sum(l.amount), 0)::integer into coins from public.coin_ledger l
      where l.child_id = row_.child_id and l.reason in ('task', 'task_undo') and l.ref like row_.id::text || ':%';
  end if;
  if coins <= 0 then
    return null;
  end if;
  if is_approved then
    insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, coins, 'task', row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  else
    insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, -coins, 'task_undo', row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  end if;
  return null;
end $$;
revoke execute on function public.completions_coin_trigger() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'task_assignments_coins_max_check') then
    alter table public.task_assignments add constraint task_assignments_coins_max_check check (coins <= 50) not valid;
  end if;
end $$;
