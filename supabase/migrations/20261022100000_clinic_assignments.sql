-- =====================================================================
-- Klinik içinde danışan ataması (öneri, 22 Ekim 2026; kullanıcı isteği)
--   * Klinik sahibi kliniğin bütün danışanlarını görür (ekip üyelerinin eklediği aileler dahil).
--   * Ekip üyesi yalnız kendi davet ettiği (sorumlusu olduğu) ve sahibin ona atadığı danışanları görür.
--     Davet edilir edilmez sahibin danışanlarını görmez.
--   * Sahip bir danışanı bir ya da birkaç ekip üyesine atar / atamayı kaldırır; sorumlu uzmanı değiştirir.
--   * Bildirimler: danışanın sorumlusu + atanan üyeler; sorumlu yoksa klinik sahibi.
--     Birden çok çocuklu bildirimler kişi başına yalnız görebildiği çocukları içerir.
--   Görünürlük bütün klinik verisine uygulanır: çocuk, görev, tamamlama, zor an + ses, not, hedef, öneri.
-- Önkoşul: migrations/20261021300000_security_pentest.sql (clinician_access). Üyelik önerisinden bağımsız.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Atama tablosu
-- ---------------------------------------------------------------------
create table if not exists public.clinic_link_access (
  link_id       uuid not null references public.clinic_links (id) on delete cascade,
  clinician_id  uuid not null references public.clinicians (id) on delete cascade,
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  granted_by    uuid references public.clinicians (id) on delete set null,
  created_at    timestamptz not null default now(),
  primary key (link_id, clinician_id)
);
create index if not exists clinic_link_access_clinician_idx on public.clinic_link_access (clinician_id);
alter table public.clinic_link_access enable row level security;
revoke all on public.clinic_link_access from anon, authenticated;

create or replace function public.clinic_is_owner()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.clinicians where id = auth.uid() and role = 'owner')
$$;
revoke execute on function public.clinic_is_owner() from public, anon;
grant execute on function public.clinic_is_owner() to authenticated;

-- Bu paylaşım oturumdaki uzmana görünür mü? (durumdan bağımsız; etkinlik ayrıca denetlenir)
create or replace function public.clinic_link_visible(p_link_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinic_links l
    join public.clinicians m on m.id = auth.uid() and m.clinic_id = l.clinic_id
    where l.id = p_link_id
      and (m.role = 'owner' or l.clinician_id = m.id
           or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.id))
  )
$$;
revoke execute on function public.clinic_link_visible(uuid) from public, anon;
grant execute on function public.clinic_link_visible(uuid) to authenticated;

drop policy if exists "atama: klinik okur" on public.clinic_link_access;
create policy "atama: klinik okur" on public.clinic_link_access for select to authenticated
  using (clinic_id = public.my_clinic_id() and (public.clinic_is_owner() or clinician_id = auth.uid()));
grant select on public.clinic_link_access to authenticated;

-- ---------------------------------------------------------------------
-- 2. Görünürlük kuralları
-- ---------------------------------------------------------------------
create or replace function public.clinic_sees_child(p_child_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.clinician_access() and exists (
    select 1 from public.clinic_links l
    where l.child_id = p_child_id and l.status = 'active' and l.clinic_id = public.my_clinic_id()
      and public.clinic_link_visible(l.id)
  )
$$;

create or replace function public.clinic_link_mine(p_link_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.clinician_access() and exists (
    select 1 from public.clinic_links l
    where l.id = p_link_id and l.clinic_id = public.my_clinic_id() and l.status = 'active'
  ) and public.clinic_link_visible(p_link_id)
$$;

drop policy if exists "bağlantı: klinik okur" on public.clinic_links;
create policy "bağlantı: klinik okur" on public.clinic_links for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinic_link_visible(id));
drop policy if exists "bağlantı: klinik etiketi" on public.clinic_links;
create policy "bağlantı: klinik etiketi" on public.clinic_links for update to authenticated
  using (clinic_id = public.my_clinic_id() and status = 'active' and public.clinician_access() and public.clinic_link_visible(id))
  with check (clinic_id = public.my_clinic_id()
    and (clinician_id is null or exists (select 1 from public.clinicians m
                                          where m.id = clinic_links.clinician_id and m.clinic_id = public.my_clinic_id())));

-- Sorumlu uzmanı yalnız klinik sahibi değiştirir
create or replace function public.clinic_links_guard_responsible() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.clinician_id is distinct from old.clinician_id and auth.uid() is not null
     and not exists (select 1 from public.clinicians where id = auth.uid() and role = 'owner' and clinic_id = new.clinic_id)
     and not exists (select 1 from public.profiles where id = auth.uid())
     and not (new.clinician_id is null and old.clinician_id = auth.uid()) then
    raise exception 'Sorumlu uzmanı yalnız klinik sahibi değiştirir';
  end if;
  return new;
end $$;
revoke execute on function public.clinic_links_guard_responsible() from public, anon, authenticated;
drop trigger if exists clinic_links_guard_responsible on public.clinic_links;
create trigger clinic_links_guard_responsible before update of clinician_id on public.clinic_links
  for each row execute function public.clinic_links_guard_responsible();

drop policy if exists "not: klinik okur" on public.clinic_notes;
create policy "not: klinik okur" on public.clinic_notes for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id));
drop policy if exists "not: yazarı düzeltir" on public.clinic_notes;
create policy "not: yazarı düzeltir" on public.clinic_notes for update to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id)
         and (author_id = auth.uid() or public.clinic_is_owner()))
  with check (clinic_id = public.my_clinic_id() and public.clinic_link_mine(link_id));
drop policy if exists "not: yazarı siler" on public.clinic_notes;
create policy "not: yazarı siler" on public.clinic_notes for delete to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id)
         and (author_id = auth.uid() or public.clinic_is_owner()));

drop policy if exists "hedef: klinik" on public.clinic_goals;
create policy "hedef: klinik" on public.clinic_goals for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id))
  with check (clinic_id = public.my_clinic_id() and public.clinic_link_mine(link_id));
drop policy if exists "hedef puanı: klinik" on public.goal_ratings;
create policy "hedef puanı: klinik" on public.goal_ratings for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
    and exists (select 1 from public.clinic_goals g where g.id = goal_ratings.goal_id and public.clinic_link_visible(g.link_id)))
  with check (clinic_id = public.my_clinic_id() and public.clinician_access()
    and exists (select 1 from public.clinic_goals g where g.id = goal_ratings.goal_id and g.clinic_id = public.my_clinic_id()
                and public.clinic_link_mine(g.link_id)));

drop policy if exists "öneri: klinik" on public.clinic_task_suggestions;
create policy "öneri: klinik" on public.clinic_task_suggestions for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id));
drop policy if exists "öneri: klinik geri çeker" on public.clinic_task_suggestions;
create policy "öneri: klinik geri çeker" on public.clinic_task_suggestions for delete to authenticated
  using (clinic_id = public.my_clinic_id() and status = 'pending' and public.clinician_access() and public.clinic_link_visible(link_id));

-- Uzman yalnız görebildiği paylaşımı sonlandırır; aile kendi paylaşımını
create or replace function public.revoke_clinic_link(p_link_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.clinic_links
     set status = 'revoked', revoked_at = now(), revoked_by = auth.uid()
   where id = p_link_id and status = 'active'
     and (family_id = public.my_family_id()
          or (clinic_id = public.my_clinic_id() and public.clinic_link_visible(id)));
  if not found then raise exception 'Paylaşım bulunamadı'; end if;
end $$;

-- Danışan listesi: + sorumlu uzman ve atananlar
drop function if exists public.clinic_clients();
create function public.clinic_clients()
returns table (link_id uuid, clinic_id uuid, family_id uuid, child_id uuid, child_name text, avatar text,
               birthday date, label text, consent_at timestamptz, parents text,
               clinician_id uuid, clinician_name text, assigned uuid[])
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.family_id, l.child_id, c.name, c.avatar, c.birthday, l.label, l.consent_at,
         coalesce((select string_agg(coalesce(nullif(trim(p.name), ''), p.nickname), ', ' order by p.created_at)
                   from public.profiles p where p.family_id = l.family_id), ''),
         l.clinician_id, coalesce(m.name, ''),
         coalesce((select array_agg(a.clinician_id order by a.created_at) from public.clinic_link_access a where a.link_id = l.id), '{}')
  from public.clinic_links l
  join public.children c on c.id = l.child_id
  left join public.clinicians m on m.id = l.clinician_id
  where l.clinic_id = public.my_clinic_id() and l.status = 'active' and public.clinician_access()
    and public.clinic_link_visible(l.id)
  order by l.consent_at desc
$$;
revoke execute on function public.clinic_clients() from public, anon;
grant execute on function public.clinic_clients() to authenticated;

-- ---------------------------------------------------------------------
-- 3. Sahip: ata / atamayı kaldır / sorumluyu değiştir
-- ---------------------------------------------------------------------
create or replace function public.clinic_assign(p_link_id uuid, p_clinician_id uuid, p_assigned boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
begin
  if not public.clinic_is_owner() then raise exception 'Danışanı yalnız klinik sahibi atar'; end if;
  if not public.clinician_access() then raise exception 'Üyelik etkin değil' using errcode = 'P0402'; end if;
  select * into l from public.clinic_links where id = p_link_id and clinic_id = public.my_clinic_id() and status = 'active';
  if not found then raise exception 'Paylaşım bulunamadı'; end if;
  if not exists (select 1 from public.clinicians where id = p_clinician_id and clinic_id = l.clinic_id) then
    raise exception 'Uzman bu kliniğin ekibinde değil';
  end if;
  if p_assigned then
    insert into public.clinic_link_access (link_id, clinician_id, clinic_id, granted_by)
    values (l.id, p_clinician_id, l.clinic_id, auth.uid()) on conflict do nothing;
    if found and p_clinician_id <> auth.uid() then
      perform public.notify(p_clinician_id, 'clinic', 'client_assigned', 'Yeni danışan atandı: ' || public.child_name(l.child_id),
        'Klinik sahibi bu danışanı sana atadı.', jsonb_build_object('link_id', l.id, 'child_id', l.child_id), null, l.child_id);
    end if;
  else
    delete from public.clinic_link_access where link_id = l.id and clinician_id = p_clinician_id;
  end if;
end $$;
revoke execute on function public.clinic_assign(uuid, uuid, boolean) from public, anon;
grant execute on function public.clinic_assign(uuid, uuid, boolean) to authenticated;

-- Sorumlu değişince eski sorumlu görmeye devam etsin diye atanmış sayılır (veri kaybolmaz)
create or replace function public.clinic_set_responsible(p_link_id uuid, p_clinician_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
begin
  if not public.clinic_is_owner() then raise exception 'Sorumlu uzmanı yalnız klinik sahibi değiştirir'; end if;
  select * into l from public.clinic_links where id = p_link_id and clinic_id = public.my_clinic_id() and status = 'active';
  if not found then raise exception 'Paylaşım bulunamadı'; end if;
  if not exists (select 1 from public.clinicians where id = p_clinician_id and clinic_id = l.clinic_id) then
    raise exception 'Uzman bu kliniğin ekibinde değil';
  end if;
  update public.clinic_links set clinician_id = p_clinician_id where id = l.id;
  delete from public.clinic_link_access where link_id = l.id and clinician_id = p_clinician_id;
end $$;
revoke execute on function public.clinic_set_responsible(uuid, uuid) from public, anon;
grant execute on function public.clinic_set_responsible(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Bildirimler: kişi başına yalnız görebildiği çocuklar
-- ---------------------------------------------------------------------
create or replace function public.clinic_link_recipients(p_link_id uuid)
returns setof uuid language sql stable security definer set search_path = '' as $$
  with l as (select * from public.clinic_links where id = p_link_id),
  r as (
    select m.id from l join public.clinicians m on m.id = l.clinician_id and m.clinic_id = l.clinic_id
    union
    select a.clinician_id from public.clinic_link_access a where a.link_id = p_link_id
  )
  select id from r
  union
  select m.id from l join public.clinicians m on m.clinic_id = l.clinic_id and m.role = 'owner'
   where not exists (select 1 from r)
$$;
revoke execute on function public.clinic_link_recipients(uuid) from public, anon, authenticated;

create or replace function public.clinic_links_notify_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in
    select n.clinic_id, rc.rid, n.family_id, count(*) as n_children,
           string_agg(c.name, ', ' order by c.name) as names, (array_agg(n.child_id))[1] as first_child,
           jsonb_agg(jsonb_build_object('link_id', n.id, 'child_id', n.child_id)) as links
      from new_rows n
      join public.children c on c.id = n.child_id
      cross join lateral public.clinic_link_recipients(n.id) as rc(rid)
     group by n.clinic_id, rc.rid, n.family_id
  loop
    perform public.notify(r.rid, 'clinic', 'clinic_shared',
      case when r.n_children = 1 then 'Yeni paylaşım: ' || r.names else r.n_children || ' çocuk paylaşıldı' end,
      'Aile rıza verdi: ' || r.names || '. Görev ve kayıtları artık görebilirsin.',
      jsonb_build_object('links', r.links, 'family_id', r.family_id), null,
      case when r.n_children = 1 then r.first_child end);
  end loop;
  return null;
end $$;

create or replace function public.abc_events_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in
    select l.clinic_id, rc.rid, count(*) as n, string_agg(c.name, ', ' order by c.name) as names,
           max(n.intensity) as intensity, bool_or(n.audio_path is not null) as has_audio,
           (array_agg(n.child_id))[1] as first_child,
           jsonb_agg(jsonb_build_object('abc_id', n.id, 'child_id', n.child_id)) as items
      from new_rows n
      join public.clinic_links l on l.child_id = n.child_id and l.status = 'active'
      join public.children c on c.id = n.child_id
      cross join lateral public.clinic_link_recipients(l.id) as rc(rid)
     group by l.clinic_id, rc.rid
  loop
    perform public.notify(r.rid, 'clinic', 'abc_event', 'Yeni zor an kaydı: ' || r.names,
      'Şiddet ' || r.intensity || '/5' || case when r.has_audio then ' · 🎤 sesli kayıt' else '' end,
      jsonb_build_object('items', r.items, 'abc_id', (r.items -> 0 ->> 'abc_id'), 'child_id', r.first_child), null,
      case when r.n = 1 then r.first_child end);
  end loop;
  return null;
end $$;

create or replace function public.clinic_links_notify_revoke() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('link_id', new.id, 'child_id', new.child_id);
  rid uuid;
begin
  if old.status = 'active' and new.status = 'revoked' then
    if exists (select 1 from public.profiles where id = new.revoked_by and family_id = new.family_id) then
      for rid in select * from public.clinic_link_recipients(new.id) loop
        perform public.notify(rid, 'clinic', 'clinic_revoked', 'Paylaşım durduruldu: ' || nm,
          'Aile bu çocuğun paylaşımını sonlandırdı.', d, null, new.child_id);
      end loop;
    else
      perform public.notify_parents(new.family_id, 'clinic_revoked', 'Uzman paylaşımı sonlandırdı: ' || nm,
        coalesce((select name from public.clinics where id = new.clinic_id), ''), d, new.child_id);
    end if;
  end if;
  return null;
end $$;

create or replace function public.suggestions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('suggestion_id', new.id, 'child_id', new.child_id);
  rid uuid;
begin
  if tg_op = 'INSERT' then
    perform public.notify_parents(new.family_id, 'clinic_suggestion', 'Uzmanın ' || nm || ' için görev önerdi',
      coalesce(new.emoji || ' ', '') || new.title, d, new.child_id);
  elsif old.status = 'pending' and new.status in ('accepted', 'declined') then
    -- öneriyi yazan uzman hâlâ danışanı görüyorsa ona; görmüyorsa danışanın alıcılarına
    for rid in
      select new.created_by where new.created_by is not null and exists (
        select 1 from public.clinicians m join public.clinic_links l on l.id = new.link_id
         where m.id = new.created_by and m.clinic_id = l.clinic_id
           and (m.role = 'owner' or l.clinician_id = m.id
                or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.id)))
      union
      select x from public.clinic_link_recipients(new.link_id) x
       where new.created_by is null or not exists (
         select 1 from public.clinicians m join public.clinic_links l on l.id = new.link_id
          where m.id = new.created_by and m.clinic_id = l.clinic_id
            and (m.role = 'owner' or l.clinician_id = m.id
                 or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.id)))
    loop
      perform public.notify(rid, 'clinic', 'suggestion_decided',
        case when new.status = 'accepted' then 'Öneri kabul edildi: ' else 'Öneri şimdilik eklenmedi: ' end || new.title,
        nm, d, null, new.child_id);
    end loop;
  end if;
  return null;
end $$;

revoke execute on function public.clinic_links_notify_insert(), public.abc_events_notify(), public.clinic_links_notify_revoke(),
  public.suggestions_notify(), public.clinic_links_guard_responsible() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Hesap silme: sahiplik devrinde atamalar korunur (değişiklik yok); ekip üyesi silinince atamaları cascade ile gider.
-- ---------------------------------------------------------------------
