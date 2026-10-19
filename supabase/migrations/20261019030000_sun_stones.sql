-- =====================================================================
-- Güneş Taşı (Ö1) + görev becerisi ve zorluğu oyuna (Ö2). Karar: 19 Ekim 2026, kullanıcı.
--   1. sun_stone_ledger: taş defteri. Taş YALNIZCA ebeveyn onayıyla (tetikleyici) gelir: kolay 1, orta 2, zor 3.
--      Onay geri alınırsa o tamamlamanın taşları düşer. Taş harcanmaz; oyunda adaya "yerleştirilir"
--      (yerleştirme oyun kaydındadır, sunucu yalnız kazanılan toplamı bilir).
--   2. child_me yanıtına sun_stones (toplam) eklenir.
--   3. child_tasks yanıtına skill (tasks.skill) ve difficulty (task_assignments.difficulty) eklenir:
--      oyun gerçek görev XP'si ve beceri yıldızı için kullanır (sözlük: sozlesme/ekonomi.md "Beceriler").
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Taş defteri
-- ---------------------------------------------------------------------
create table if not exists public.sun_stone_ledger (
  id          bigserial primary key,
  family_id   uuid not null references public.families (id) on delete cascade,
  child_id    uuid not null references public.children (id) on delete cascade,
  amount      integer not null check (amount <> 0),
  reason      text not null check (reason in ('task', 'task_undo', 'adjust')),
  ref         text not null,              -- '<tamamlama kimliği>:<epoch>'
  created_at  timestamptz not null default now(),
  unique (child_id, reason, ref)
);
create index if not exists sun_stone_ledger_child_idx on public.sun_stone_ledger (child_id);
alter table public.sun_stone_ledger enable row level security;
drop policy if exists "taş: ebeveyn okur" on public.sun_stone_ledger;
create policy "taş: ebeveyn okur" on public.sun_stone_ledger for select to authenticated
  using (family_id = public.my_family_id());
drop policy if exists "taş: çocuk okur" on public.sun_stone_ledger;
create policy "taş: çocuk okur" on public.sun_stone_ledger for select to authenticated
  using (child_id = public.my_child_id());
-- Yazma politikası yok: defter yalnızca aşağıdaki tetikleyiciyle yazılır.
revoke insert, update, delete on public.sun_stone_ledger from anon, authenticated;

create or replace function public.sun_stone_balance(p_child_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(coalesce(sum(amount), 0), 0)::integer from public.sun_stone_ledger where child_id = p_child_id
$$;

create or replace function public.stones_for_difficulty(p_difficulty text)
returns integer language sql immutable set search_path = '' as $$
  select case p_difficulty when 'hard' then 3 when 'medium' then 2 else 1 end
$$;

create or replace function public.completions_sun_stone_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  n integer;
  diff text;
  was_approved boolean := tg_op in ('UPDATE', 'DELETE') and old.status = 'approved';
  is_approved boolean := tg_op in ('INSERT', 'UPDATE') and new.status = 'approved';
  row_ public.completions%rowtype;
begin
  if tg_op = 'DELETE' then row_ := old; else row_ := new; end if;
  if is_approved = was_approved then
    return null;
  end if;
  if is_approved then
    select a.difficulty into diff from public.task_assignments a where a.task_id = row_.task_id and a.child_id = row_.child_id;
    if not found then
      return null;
    end if;
    insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, public.stones_for_difficulty(diff), 'task',
            row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  else
    select coalesce(sum(l.amount), 0) into n from public.sun_stone_ledger l
      where l.child_id = row_.child_id and l.reason in ('task', 'task_undo') and split_part(l.ref, ':', 1) = row_.id::text;
    if n <= 0 then
      return null;
    end if;
    insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, -n, 'task_undo', row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  end if;
  return null;
end $$;

drop trigger if exists completions_sun_stone on public.completions;
create trigger completions_sun_stone after insert or update of status or delete on public.completions
  for each row execute function public.completions_sun_stone_trigger();

-- ---------------------------------------------------------------------
-- 2. child_me: + sun_stones
-- ---------------------------------------------------------------------
create or replace function public.child_me()
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  c public.children%rowtype;
begin
  select * into c from public.children where user_id = auth.uid();
  if not found then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  return json_build_object('child_id', c.id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)),
                           'balance', public.coin_balance(c.id),
                           'sun_stones', public.sun_stone_balance(c.id));
end $$;

-- ---------------------------------------------------------------------
-- 3. child_tasks: + skill, difficulty (dönüş tipi değiştiği için önce kaldırılır)
-- ---------------------------------------------------------------------
drop function if exists public.child_tasks(date, date);
create function public.child_tasks(p_from date, p_to date)
returns table (task_id uuid, date date, title text, description text, emoji text, coins integer,
               recurring boolean, repeat_kind text, requires_review boolean, status text, parent_note text,
               skill text, difficulty text)
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
           coalesce(c.status, 'assigned'), c.parent_note, t.skill, a.difficulty
    from public.task_assignments a
    join public.tasks t on t.id = a.task_id
    cross join generate_series(p_from, p_to, interval '1 day') as d
    left join public.completions c on c.task_id = t.id and c.child_id = me and c.date = d::date
    where a.child_id = me and public.task_occurs_on(t, d::date)
    order by d, t.sort_order;
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.sun_stone_balance(uuid) from public, anon, authenticated;
revoke execute on function public.completions_sun_stone_trigger() from public, anon, authenticated;
revoke execute on function public.stones_for_difficulty(text) from public, anon;
revoke execute on function public.child_me() from public, anon;
revoke execute on function public.child_tasks(date, date) from public, anon;
grant execute on function public.stones_for_difficulty(text) to authenticated;
grant execute on function public.child_me() to authenticated;
grant execute on function public.child_tasks(date, date) to authenticated;
