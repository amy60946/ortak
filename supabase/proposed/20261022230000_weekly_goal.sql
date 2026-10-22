-- =====================================================================
-- Kişisel haftalık hedef (XP takibi Y6; kullanıcı onayı 22 Ekim 2026; ÖNERİ)
--   Hedef = son 2 haftanın onaylı görev ortalaması × 1,2 (yukarı yuvarlanır), en az 3, en çok o haftaki görevlerin
--   %90'ı (aşağı). Geçmişi olmayan çocukta (bu haftadan önce hiç kaydı yok) hedef yok, yalnız ölçüm. Bu hafta 3'ten az
--   görev varsa hedef yok. Ebeveyn hedefi düşürebilir (üst sınır; null = otomatik). Ulaşamazsa ceza yok.
--   Hedefe ulaşan çocuk ödülü bir kez alır: +2 Güneş Taşı (defter nedeni 'goal', ada ilerlemesine sayılır) + ebeveyne
--   kutlama bildirimi; XP oyunda hesaplanır. Hafta pazartesi başlar.
-- Tablolar: weekly_goal_claims (alınan ödüller), child_goal_settings (ebeveyn üst sınırı). RLS: aile okur, çocuk kendi okur;
-- yazan yalnız fonksiyonlar.
-- Tekrar çalıştırılabilir.
-- =====================================================================

create table if not exists public.weekly_goal_claims (
  child_id    uuid not null references public.children (id) on delete cascade,
  week_start  date not null,
  family_id   uuid not null references public.families (id) on delete cascade,
  target      integer not null check (target between 1 and 500),
  claimed_at  timestamptz not null default now(),
  primary key (child_id, week_start)
);
alter table public.weekly_goal_claims enable row level security;
drop policy if exists "haftalık hedef: aile okur" on public.weekly_goal_claims;
create policy "haftalık hedef: aile okur" on public.weekly_goal_claims for select to authenticated using (family_id = public.my_family_id());
drop policy if exists "haftalık hedef: çocuk kendi okur" on public.weekly_goal_claims;
create policy "haftalık hedef: çocuk kendi okur" on public.weekly_goal_claims for select to authenticated using (child_id = public.my_child_id());
revoke insert, update, delete, truncate on public.weekly_goal_claims from anon, authenticated;

create table if not exists public.child_goal_settings (
  child_id    uuid primary key references public.children (id) on delete cascade,
  family_id   uuid not null references public.families (id) on delete cascade,
  weekly_cap  integer check (weekly_cap between 1 and 200),
  updated_at  timestamptz not null default now()
);
alter table public.child_goal_settings enable row level security;
drop policy if exists "hedef ayarı: aile okur" on public.child_goal_settings;
create policy "hedef ayarı: aile okur" on public.child_goal_settings for select to authenticated using (family_id = public.my_family_id());
revoke insert, update, delete, truncate on public.child_goal_settings from anon, authenticated;

-- defter: hedef ödülü nedeni; ada ilerlemesine (sun_stone_balance) sayılır
alter table public.sun_stone_ledger drop constraint if exists sun_stone_ledger_reason_check;
alter table public.sun_stone_ledger add constraint sun_stone_ledger_reason_check
  check (reason in ('task', 'task_undo', 'adjust', 'reward', 'penalty', 'goal'));
create or replace function public.sun_stone_balance(p_child_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(coalesce(sum(amount), 0), 0)::integer from public.sun_stone_ledger
   where child_id = p_child_id and reason in ('task', 'task_undo', 'adjust', 'goal')
$$;
revoke execute on function public.sun_stone_balance(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Hesap (iç): json {week_start, target (null = hedef yok), auto, cap, done, assigned, claimed}
-- ---------------------------------------------------------------------
create or replace function public.weekly_goal_calc(p_child uuid, p_week date)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  w date := date_trunc('week', p_week)::date;
  assigned integer;
  done integer;
  prev1 integer;
  prev2 integer;
  history boolean;
  cap integer;
  auto integer;
  target integer;
begin
  select count(*) into assigned
    from public.task_assignments a
    join public.tasks t on t.id = a.task_id
    cross join generate_series(w, w + 6, interval '1 day') as d
    where a.child_id = p_child and public.task_occurs_on(t, d::date);
  select count(*) filter (where c.date between w and w + 6),
         count(*) filter (where c.date between w - 7 and w - 1),
         count(*) filter (where c.date between w - 14 and w - 8)
    into done, prev1, prev2
    from public.completions c where c.child_id = p_child and c.status = 'approved' and c.date between w - 14 and w + 6;
  select exists (select 1 from public.completions c where c.child_id = p_child and c.date < w) into history;
  select s.weekly_cap into cap from public.child_goal_settings s where s.child_id = p_child;
  auto := ceil((prev1 + prev2) / 2.0 * 1.2)::integer;
  if history and assigned >= 3 then
    target := least(greatest(3, auto), floor(assigned * 0.9)::integer);
    if target < 3 then target := null; end if;
    if target is not null and cap is not null then target := least(target, cap); end if;
  end if;
  return json_build_object('week_start', w, 'target', target, 'auto', auto, 'cap', cap, 'done', done, 'assigned', assigned,
    'claimed', exists (select 1 from public.weekly_goal_claims g where g.child_id = p_child and g.week_start = w));
end $$;
revoke execute on function public.weekly_goal_calc(uuid, date) from public, anon, authenticated;

-- Çocuk (oyun): bu haftanın hedefi
create or replace function public.child_weekly_goal()
returns json language plpgsql stable security definer set search_path = '' as $$
declare me uuid := public.my_child_id();
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  return public.weekly_goal_calc(me, current_date);
end $$;
revoke execute on function public.child_weekly_goal() from public, anon;
grant execute on function public.child_weekly_goal() to authenticated;

-- Ebeveyn (ParentApp): çocuğun bu haftaki hedefi
create or replace function public.weekly_goal(p_child_id uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.children c where c.id = p_child_id and c.family_id = public.my_family_id()) then
    raise exception 'Çocuk bulunamadı' using errcode = '42501';
  end if;
  return public.weekly_goal_calc(p_child_id, current_date);
end $$;
revoke execute on function public.weekly_goal(uuid) from public, anon;
grant execute on function public.weekly_goal(uuid) to authenticated;

-- Ebeveyn: üst sınır (hedefi düşürmek için; null = otomatik)
create or replace function public.set_weekly_goal_cap(p_child_id uuid, p_cap integer)
returns void language plpgsql security definer set search_path = '' as $$
declare fam uuid;
begin
  select c.family_id into fam from public.children c where c.id = p_child_id and c.family_id = public.my_family_id();
  if fam is null then
    raise exception 'Çocuk bulunamadı' using errcode = '42501';
  end if;
  if p_cap is not null and (p_cap < 1 or p_cap > 200) then
    raise exception 'Geçersiz hedef';
  end if;
  insert into public.child_goal_settings (child_id, family_id, weekly_cap, updated_at) values (p_child_id, fam, p_cap, now())
  on conflict (child_id) do update set weekly_cap = excluded.weekly_cap, updated_at = now();
end $$;
revoke execute on function public.set_weekly_goal_cap(uuid, integer) from public, anon;
grant execute on function public.set_weekly_goal_cap(uuid, integer) to authenticated;

-- Çocuk: hedefe ulaştıysa ödülü al (haftada bir kez). json {ok, error, stones}
create or replace function public.claim_weekly_goal()
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
  fam uuid;
  nm text;
  g json;
  w date;
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  g := public.weekly_goal_calc(me, current_date);
  w := (g ->> 'week_start')::date;
  if (g ->> 'target') is null then
    return json_build_object('ok', false, 'error', 'no_goal', 'stones', 0);
  end if;
  if (g ->> 'claimed')::boolean then
    return json_build_object('ok', false, 'error', 'already_claimed', 'stones', 0);
  end if;
  if (g ->> 'done')::int < (g ->> 'target')::int then
    return json_build_object('ok', false, 'error', 'not_reached', 'stones', 0);
  end if;
  select c.family_id, c.name into fam, nm from public.children c where c.id = me;
  insert into public.weekly_goal_claims (child_id, week_start, family_id, target) values (me, w, fam, (g ->> 'target')::int)
  on conflict (child_id, week_start) do nothing;
  if not found then
    return json_build_object('ok', false, 'error', 'already_claimed', 'stones', 0);
  end if;
  insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref)
  values (fam, me, 2, 'goal', 'goal:' || w::text);
  perform public.notify_parents(fam, 'weekly_goal', left(nm || ' haftalık hedefine ulaştı!', 120),
    (g ->> 'done') || ' görev tamamladı. Birlikte kutlayın!', json_build_object('week_start', w, 'target', g -> 'target')::jsonb, me);
  return json_build_object('ok', true, 'error', null, 'stones', 2);
end $$;
revoke execute on function public.claim_weekly_goal() from public, anon;
grant execute on function public.claim_weekly_goal() to authenticated;
