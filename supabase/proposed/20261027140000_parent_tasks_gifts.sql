-- Ebeveyn görevleri, ebeveynin Güneş Taşı ve hediye dükkânı (kullanıcı isteği 27 Ekim 2026; sozlesme/akislar.md 17,
-- ekonomi.md 5C). Joon "parent quests + gift shop" örnekleri, kopya değil.
--
-- 1. Görev ebeveyne de atanabilir (kendisine ya da ailedeki diğer ebeveyne): parent_assignments. Aynı görev çocuğa da
--    atanırsa "ailece" görevdir (çocuk tarafı değişmez: task_assignments + child_tasks aynen).
-- 2. Ebeveyn kendi görevini ParentApp'te "Yaptım" diye işaretler (inceleme yok): parent_task_done(görev, gün, yapıldı).
--    Yalnız kendisine atanmış, o gün geçerli görev; gün bugün − 7 … bugün + 1 (saat dilimi payı).
--    Her işaret zorluğa göre taş: kolay 1 / orta 2 / zor 3 (çocukla aynı tablo). Geri alınırsa verilen düşer.
-- 3. Ebeveynin taşı ayrı defterde (parent_stone_ledger; çocuğun sun_stone_ledger'ına karışmaz). Aile okur, istemci yazamaz.
-- 4. Hediye dükkânı: gift_items = oyunun kalıcı eşyaları (giyilebilir, ev, süs; yiyecek/temizlik/tohum ve özel setler yok).
--    Taş fiyatı = coin fiyatı / 10 (yukarı yuvarlanır, en az 1). send_gift(çocuk, eşya, not) taşı düşer, child_gifts'e yazar,
--    çocuğa "gift" bildirimi gider. Oyun child_gifts_pending() ile alır, envantere ekler, claim_child_gift(id) ile kapatır.
--    Eski oyun sürümü hediyeyi görmez; kayıt bekler (kaybolmaz).
-- Tekrar çalıştırılabilir.

-- ---------------------------------------------------------------- 1. ebeveyn atamaları
create table if not exists public.parent_assignments (
  task_id    uuid not null references public.tasks (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  family_id  uuid not null references public.families (id) on delete cascade,
  difficulty text not null default 'easy' check (difficulty in ('easy', 'medium', 'hard')),
  created_at timestamptz not null default now(),
  primary key (task_id, user_id)
);
create index if not exists parent_assignments_family_idx on public.parent_assignments (family_id);
alter table public.parent_assignments enable row level security;

-- Ebeveyn yalnız kendi ailesinin görevini, yalnız ailesindeki bir ebeveyne atar
create or replace function public.parent_assignments_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and (new.task_id <> old.task_id or new.user_id <> old.user_id or new.family_id <> old.family_id) then
    raise exception 'Atama değiştirilemez; silip yeniden ekle';
  end if;
  if public.task_family(new.task_id) is distinct from new.family_id then
    raise exception 'Görev bu ailenin değil';
  end if;
  if not exists (select 1 from public.profiles p where p.id = new.user_id and p.family_id = new.family_id) then
    raise exception 'Yalnız ailedeki bir ebeveyne atanabilir' using hint = 'not_family_parent';
  end if;
  return new;
end $$;
drop trigger if exists parent_assignments_guard on public.parent_assignments;
create trigger parent_assignments_guard before insert or update on public.parent_assignments
  for each row execute function public.parent_assignments_guard();

drop policy if exists "ebeveyn ataması: aile" on public.parent_assignments;
create policy "ebeveyn ataması: aile" on public.parent_assignments for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id());
revoke truncate on public.parent_assignments from anon, authenticated;

-- ---------------------------------------------------------------- 2. ebeveyn işaretleri
create table if not exists public.parent_completions (
  task_id   uuid not null references public.tasks (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  date      date not null,
  family_id uuid not null references public.families (id) on delete cascade,
  done_at   timestamptz not null default now(),
  primary key (task_id, user_id, date)
);
create index if not exists parent_completions_family_idx on public.parent_completions (family_id, date);
alter table public.parent_completions enable row level security;
drop policy if exists "ebeveyn işareti: aile okur" on public.parent_completions;
create policy "ebeveyn işareti: aile okur" on public.parent_completions for select to authenticated
  using (family_id = public.my_family_id());
revoke insert, update, delete, truncate on public.parent_completions from anon, authenticated;

-- ---------------------------------------------------------------- 3. ebeveynin taş defteri
create table if not exists public.parent_stone_ledger (
  id         bigserial primary key,
  family_id  uuid not null references public.families (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  amount     integer not null check (amount <> 0 and amount between -10000 and 10000),
  reason     text not null check (reason in ('task', 'task_undo', 'gift')),
  ref        text not null,
  item_id    text,
  child_id   uuid references public.children (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, reason, ref)
);
create index if not exists parent_stone_ledger_user_idx on public.parent_stone_ledger (user_id, created_at desc);
alter table public.parent_stone_ledger enable row level security;
drop policy if exists "ebeveyn taşı: aile okur" on public.parent_stone_ledger;
create policy "ebeveyn taşı: aile okur" on public.parent_stone_ledger for select to authenticated
  using (family_id = public.my_family_id());
revoke insert, update, delete, truncate on public.parent_stone_ledger from anon, authenticated;

create or replace function public.parent_stone_balance(p_user uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(coalesce(sum(amount), 0), 0)::integer from public.parent_stone_ledger where user_id = p_user
$$;

-- ---------------------------------------------------------------- 4. hediye dükkânı
create table if not exists public.gift_items (
  item_id text primary key references public.game_items (item_id) on delete cascade,
  stones  integer not null check (stones between 1 and 500),
  sort    integer not null default 0
);
alter table public.gift_items enable row level security;
drop policy if exists "hediye: herkes okur" on public.gift_items;
create policy "hediye: herkes okur" on public.gift_items for select to authenticated using (true);
revoke insert, update, delete, truncate on public.gift_items from anon, authenticated;

-- Oyunun kalıcı eşyaları (game-app items.json, 27 Ekim 2026): giyilebilir, ev, süs. Fiyat = ceil(coin / 10).
insert into public.gift_items (item_id, stones, sort)
select g.item_id, greatest(1, ceil(g.price / 10.0))::integer, s.sort
from (values
  ('glasses_round', 1), ('glasses_sun', 2), ('glasses_star', 3),
  ('hat_cap', 4), ('hat_straw', 5), ('hat_beanie', 6), ('hat_crown', 7), ('headphones', 8),
  ('shirt_stripes', 9), ('shirt_hawaii', 10), ('apron_sailor', 11), ('hoodie_soft', 12), ('vest_explorer', 13), ('raincoat', 14),
  ('scarf_knit', 15), ('sash_belt', 16), ('backpack_small', 17), ('cape_hero', 18), ('badge_patch', 19),
  ('glove_mitten', 20), ('hand_flag', 21),
  ('home_bed', 22), ('home_rug', 23), ('home_lamp', 24), ('home_bookshelf', 25), ('home_aquarium', 26),
  ('decor_umbrella', 27), ('decor_sandcastle', 28), ('decor_palm', 29), ('decor_lanterns', 30)
) as s (item_id, sort)
join public.game_items g on g.item_id = s.item_id
on conflict (item_id) do update set stones = excluded.stones, sort = excluded.sort;

create table if not exists public.child_gifts (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.families (id) on delete cascade,
  child_id   uuid not null references public.children (id) on delete cascade,
  item_id    text not null references public.game_items (item_id),
  from_user  uuid references auth.users (id) on delete set null,
  from_name  text not null default '',
  note       text check (char_length(note) <= 140),
  stones     integer not null,
  created_at timestamptz not null default now(),
  claimed_at timestamptz
);
create index if not exists child_gifts_child_idx on public.child_gifts (child_id, claimed_at);
alter table public.child_gifts enable row level security;
drop policy if exists "hediye: aile okur" on public.child_gifts;
create policy "hediye: aile okur" on public.child_gifts for select to authenticated using (family_id = public.my_family_id());
drop policy if exists "hediye: çocuk kendi okur" on public.child_gifts;
create policy "hediye: çocuk kendi okur" on public.child_gifts for select to authenticated using (child_id = public.my_child_id());
revoke insert, update, delete, truncate on public.child_gifts from anon, authenticated;

-- ---------------------------------------------------------------- 5. işlevler
-- Ebeveyn kendi görevini işaretler / geri alır. Yanıt: yeni bakiye.
create or replace function public.parent_task_done(p_task_id uuid, p_date date, p_done boolean default true)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  fam uuid := public.my_family_id();
  t public.tasks%rowtype;
  diff text;
  k text := p_task_id::text || '|' || p_date::text;
  n integer;
begin
  if uid is null or fam is null then
    raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501';
  end if;
  select a.difficulty into diff from public.parent_assignments a where a.task_id = p_task_id and a.user_id = uid and a.family_id = fam;
  if not found then
    raise exception 'Bu görev sana atanmamış' using hint = 'not_assigned';
  end if;
  select * into t from public.tasks where id = p_task_id;
  if not public.task_occurs_on(t, p_date) then
    raise exception 'Görev o gün yok' using hint = 'not_on_date';
  end if;
  if p_date > current_date + 1 or p_date < current_date - 7 then
    raise exception 'Yalnız son bir haftanın görevi işaretlenebilir' using hint = 'date_range';
  end if;
  if p_done then
    insert into public.parent_completions (task_id, user_id, date, family_id) values (p_task_id, uid, p_date, fam)
    on conflict do nothing;
    if found then
      insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
      values (fam, uid, public.stones_for_difficulty(diff), 'task', k || ':' || extract(epoch from clock_timestamp())::text);
    end if;
  else
    delete from public.parent_completions where task_id = p_task_id and user_id = uid and date = p_date;
    if found then
      select coalesce(sum(amount), 0) into n from public.parent_stone_ledger
        where user_id = uid and reason in ('task', 'task_undo') and split_part(ref, ':', 1) = k;
      if n > 0 then
        insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
        values (fam, uid, -n, 'task_undo', k || ':' || extract(epoch from clock_timestamp())::text);
      end if;
    end if;
  end if;
  return public.parent_stone_balance(uid);
end $$;

-- Hediye gönder: {ok, balance, gift_id, error ('unknown_item' | 'not_enough_stones')}
create or replace function public.send_gift(p_child_id uuid, p_item_id text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  fam uuid := public.my_family_id();
  price integer;
  bal integer;
  nm text;
  gid uuid;
  note_ text := nullif(left(trim(coalesce(p_note, '')), 140), '');
begin
  if uid is null or fam is null then
    raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501';
  end if;
  if public.child_family(p_child_id) is distinct from fam then
    raise exception 'Yetki yok' using errcode = '42501';
  end if;
  select stones into price from public.gift_items where item_id = p_item_id;
  if not found then
    return jsonb_build_object('ok', false, 'balance', public.parent_stone_balance(uid), 'gift_id', null, 'error', 'unknown_item');
  end if;
  perform pg_advisory_xact_lock(hashtext('parent_stones:' || uid::text));
  bal := public.parent_stone_balance(uid);
  if bal < price then
    return jsonb_build_object('ok', false, 'balance', bal, 'gift_id', null, 'error', 'not_enough_stones');
  end if;
  select coalesce(nullif(trim(nickname), ''), nullif(trim(name), ''), 'Ailen') into nm from public.profiles where id = uid;
  insert into public.child_gifts (family_id, child_id, item_id, from_user, from_name, note, stones)
  values (fam, p_child_id, p_item_id, uid, nm, note_, price) returning id into gid;
  insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref, item_id, child_id)
  values (fam, uid, -price, 'gift', gid::text, p_item_id, p_child_id);
  perform public.notify_child(p_child_id, 'gift', nm || ' sana bir hediye gönderdi!', coalesce(note_, 'Posta kutuna bak.'),
    jsonb_build_object('gift_id', gid, 'item_id', p_item_id));
  return jsonb_build_object('ok', true, 'balance', bal - price, 'gift_id', gid, 'error', null);
end $$;

-- Oyun: bekleyen hediyeler (en eski önce)
create or replace function public.child_gifts_pending()
returns table (id uuid, item_id text, from_name text, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := public.my_child_id();
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  return query select g.id, g.item_id, g.from_name, g.note, g.created_at from public.child_gifts g
    where g.child_id = me and g.claimed_at is null order by g.created_at;
end $$;

-- Oyun: hediyeyi envantere ekledikten sonra kapatır. İlk çağrı true, sonrakiler false (oyun hediye kimliğiyle tekilleştirir).
create or replace function public.claim_child_gift(p_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare me uuid := public.my_child_id();
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  update public.child_gifts set claimed_at = now() where id = p_id and child_id = me and claimed_at is null;
  return found;
end $$;

-- ---------------------------------------------------------------- Realtime (ParentApp: eşin işaretleri ve atamaları anında)
do $$
declare t text;
begin
  foreach t in array array['parent_assignments', 'parent_completions', 'parent_stone_ledger'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------- yetkiler
revoke execute on function public.parent_assignments_guard() from public, anon, authenticated;
revoke execute on function public.parent_stone_balance(uuid) from public, anon, authenticated;
revoke execute on function public.parent_task_done(uuid, date, boolean) from public, anon;
grant execute on function public.parent_task_done(uuid, date, boolean) to authenticated;
revoke execute on function public.send_gift(uuid, text, text) from public, anon;
grant execute on function public.send_gift(uuid, text, text) to authenticated;
revoke execute on function public.child_gifts_pending() from public, anon;
grant execute on function public.child_gifts_pending() to authenticated;
revoke execute on function public.claim_child_gift(uuid) from public, anon;
grant execute on function public.claim_child_gift(uuid) to authenticated;
