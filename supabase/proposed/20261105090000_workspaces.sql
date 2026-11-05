-- ClinicApp çalışma alanları: bir uzman birden çok klinikte ve kendi danışanlarıyla çalışır (kullanıcı kararı 5 Kasım 2026).
-- Her uzmanın tek kalıcı kişisel kodu var; klinik sahibi bu kodla ekibe ekleme isteği gönderir, uzman kabul eder.
-- Danışan, davetin gönderildiği çalışma alanınındır (klinik ya da uzmanın bireysel alanı); alanlar birbirini görmez.
-- Hangi alanda çalışıldığını ClinicApp her REST isteğinde `x-clinic-id` başlığıyla söyler; sunucu etkin üyeliği denetler
-- (başlık yoksa uzmanın varsayılan alanı: eski uygulama sürümleri aynen çalışır).
-- Klinikteki uzmanlar aile davet edebilir (varsayılan açık, sahip kapatabilir; kullanıcı kararı 5 Kasım 2026).
-- Eski ekip kodu yolu (clinic_create_invite('clinician'), clinic_join_team, kayıtta team_code) eski uygulama sürümleri için
-- çalışır ve üyelik tablosunu da yazar; yeni ClinicApp göstermez (kaldırılması: DURUM Açık işler).
-- Sözleşme: veritabani.md 30, akislar.md 21, durumlar.md P19. Tekrar çalıştırılabilir.
-- Sıra: bu dosya seans önerisinden (20261105100000_sessions.sql) önce uygulanır; seans önerisi üyelik tablosunu kullanır.

-- ---------------------------------------------------------------- tablolar
alter table public.clinics add column if not exists personal_of uuid references public.clinicians (id) on delete cascade;
create unique index if not exists clinics_personal_uq on public.clinics (personal_of) where personal_of is not null;
alter table public.clinics add column if not exists members_can_invite boolean not null default true;

create table if not exists public.clinic_members (
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  clinician_id  uuid not null references public.clinicians (id) on delete cascade,
  role          text not null default 'member' check (role in ('owner', 'member')),
  status        text not null default 'active' check (status in ('active', 'left')),
  invited_by    uuid references public.clinicians (id) on delete set null,
  joined_at     timestamptz not null default now(),
  left_at       timestamptz,
  primary key (clinic_id, clinician_id)
);
create index if not exists clinic_members_clinician_idx on public.clinic_members (clinician_id) where status = 'active';
alter table public.clinic_members enable row level security;
revoke all on public.clinic_members from anon, authenticated;
grant select on public.clinic_members to authenticated;

create table if not exists public.clinician_codes (
  clinician_id  uuid primary key references public.clinicians (id) on delete cascade,
  code          text not null unique check (code ~ '^[A-Z0-9]{8}$'),
  created_at    timestamptz not null default now()
);
alter table public.clinician_codes enable row level security;
revoke all on public.clinician_codes from anon, authenticated;   -- yalnız işlevlerle

create table if not exists public.clinic_member_requests (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  clinician_id  uuid not null references public.clinicians (id) on delete cascade,
  requested_by  uuid references public.clinicians (id) on delete set null,
  status        text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default now() + interval '7 days',
  decided_at    timestamptz
);
create unique index if not exists clinic_member_requests_open_uq on public.clinic_member_requests (clinic_id, clinician_id)
  where status = 'pending';
create index if not exists clinic_member_requests_clinician_idx on public.clinic_member_requests (clinician_id) where status = 'pending';
alter table public.clinic_member_requests enable row level security;
revoke all on public.clinic_member_requests from anon, authenticated;
grant select on public.clinic_member_requests to authenticated;

-- Eski tek alanlı yazımlar (clinicians.clinic_id / role değişimi: eski ekip kodu, yönetim araçları) üyeliğe yansır:
-- yeni alan etkin üyelik olur, eskisinden ayrılınmış sayılır.
create or replace function public.clinicians_member_sync() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.clinic_id is distinct from old.clinic_id then
    update public.clinic_members set status = 'left', left_at = now()
     where clinic_id = old.clinic_id and clinician_id = new.id and status = 'active';
  end if;
  if tg_op = 'INSERT' or new.clinic_id is distinct from old.clinic_id or new.role is distinct from old.role then
    insert into public.clinic_members (clinic_id, clinician_id, role) values (new.clinic_id, new.id, new.role)
    on conflict (clinic_id, clinician_id) do update set role = excluded.role, status = 'active', left_at = null;
  end if;
  return null;
end $$;
revoke execute on function public.clinicians_member_sync() from public, anon, authenticated;
drop trigger if exists clinicians_member_sync on public.clinicians;
create trigger clinicians_member_sync after insert or update of clinic_id, role on public.clinicians
  for each row execute function public.clinicians_member_sync();

-- ---------------------------------------------------------------- mevcut hesaplar
insert into public.clinic_members (clinic_id, clinician_id, role, joined_at)
select m.clinic_id, m.id, m.role, m.created_at from public.clinicians m
on conflict (clinic_id, clinician_id) do nothing;
update public.clinic_members cm set invited_by = v.clinician_id
  from (select distinct on (used_by, clinic_id) used_by, clinic_id, clinician_id
          from public.clinic_invites where kind = 'clinician' and used_by is not null
         order by used_by, clinic_id, used_at desc) v
 where cm.clinician_id = v.used_by and cm.clinic_id = v.clinic_id and cm.invited_by is null and v.clinician_id <> v.used_by;
-- Bireysel hesaplar kendi alanı olur (kayıtta "Bireysel uzman" ya da eski hesapta klinik adı = uzman adı, tek kişi)
update public.clinics c set personal_of = m.id
  from public.clinicians m join auth.users u on u.id = m.id
 where m.clinic_id = c.id and m.role = 'owner' and c.personal_of is null
   and not exists (select 1 from public.clinicians x where x.clinic_id = c.id and x.id <> m.id)
   and not exists (select 1 from public.clinics p where p.personal_of = m.id)
   and (u.raw_user_meta_data ->> 'practice' = 'solo'
        or (coalesce(u.raw_user_meta_data ->> 'practice', '') = '' and lower(btrim(c.name)) = lower(btrim(m.name))));

-- ---------------------------------------------------------------- çalışma alanı
-- Oturumun çalışma alanı: `x-clinic-id` başlığı + etkin üyelik; başlık yoksa varsayılan alan (üyelik etkinse). Başlık
-- geçersizse null: hiçbir klinik satırı görünmez (uygulama clinician_me().workspace_invalid ile anlar ve alanı değiştirir).
create or replace function public.my_clinic_id()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  h text;
  cid uuid;
begin
  if uid is null then return null; end if;
  begin
    h := nullif(current_setting('request.headers', true), '')::json ->> 'x-clinic-id';
  exception when others then h := null;
  end;
  if coalesce(btrim(h), '') <> '' then
    begin
      cid := btrim(h)::uuid;
    exception when others then return null;
    end;
    if exists (select 1 from public.clinic_members where clinic_id = cid and clinician_id = uid and status = 'active') then
      return cid;
    end if;
    return null;
  end if;
  select m.clinic_id into cid from public.clinicians m
   where m.id = uid
     and exists (select 1 from public.clinic_members x where x.clinic_id = m.clinic_id and x.clinician_id = uid and x.status = 'active');
  return cid;
end $$;

create or replace function public.clinic_member_role(p_clinic uuid, p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select role from public.clinic_members where clinic_id = p_clinic and clinician_id = p_user and status = 'active'
$$;
revoke execute on function public.clinic_member_role(uuid, uuid) from public, anon, authenticated;

create or replace function public.my_clinic_role()
returns text language sql stable security definer set search_path = '' as $$
  select role from public.clinic_members
   where clinic_id = public.my_clinic_id() and clinician_id = auth.uid() and status = 'active'
$$;
revoke execute on function public.my_clinic_role() from public, anon;
grant execute on function public.my_clinic_role() to authenticated;

create or replace function public.clinic_is_owner()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.my_clinic_role() = 'owner', false)
$$;

create or replace function public.clinician_access()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinic_members m join public.clinics c on c.id = m.clinic_id
    where m.clinician_id = auth.uid() and m.status = 'active' and m.clinic_id = public.my_clinic_id()
      and public.clinic_active(c.id) and (m.role = 'owner' or c.seat_limit > 1)
  )
$$;

create or replace function public.clinic_link_visible(p_link_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinic_links l
    join public.clinic_members m on m.clinician_id = auth.uid() and m.clinic_id = l.clinic_id and m.status = 'active'
    where l.id = p_link_id
      and (m.role = 'owner' or l.clinician_id = m.clinician_id
           or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.clinician_id))
  )
$$;

-- Ses kaydı gibi istek başlığı taşımayan okumalar için: uzman çocuğu herhangi bir etkin alanında görüyor mu?
create or replace function public.clinic_sees_child_any(p_child_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinic_links l
    join public.clinic_members m on m.clinician_id = auth.uid() and m.clinic_id = l.clinic_id and m.status = 'active'
    join public.clinics c on c.id = l.clinic_id
    where l.child_id = p_child_id and l.status = 'active'
      and public.clinic_active(c.id) and (m.role = 'owner' or c.seat_limit > 1)
      and public.clinic_link_visible(l.id)
  )
$$;
revoke execute on function public.clinic_sees_child_any(uuid) from public, anon;
grant execute on function public.clinic_sees_child_any(uuid) to authenticated;

drop policy if exists "zor an sesi: bağlı uzman dinler" on storage.objects;
create policy "zor an sesi: bağlı uzman dinler" on storage.objects for select to authenticated
  using (bucket_id = 'abc' and exists (
    select 1 from public.abc_events e where e.audio_path = storage.objects.name and public.clinic_sees_child_any(e.child_id)));

create or replace function public.clinic_link_recipients(p_link_id uuid)
returns setof uuid language sql stable security definer set search_path = '' as $$
  with l as (select * from public.clinic_links where id = p_link_id),
  act as (select m.clinician_id, m.role from l join public.clinic_members m on m.clinic_id = l.clinic_id and m.status = 'active'),
  r as (
    select a.clinician_id as id from l join act a on a.clinician_id = l.clinician_id
    union
    select x.clinician_id from public.clinic_link_access x join act a on a.clinician_id = x.clinician_id where x.link_id = p_link_id
  )
  select id from r
  union
  select a.clinician_id from act a where a.role = 'owner' and not exists (select 1 from r)
$$;

create or replace function public.clinic_links_guard_responsible() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.clinician_id is distinct from old.clinician_id and auth.uid() is not null
     and not exists (select 1 from public.clinic_members where clinician_id = auth.uid() and clinic_id = new.clinic_id
                       and role = 'owner' and status = 'active')
     and not exists (select 1 from public.profiles where id = auth.uid())
     and not (new.clinician_id is null and old.clinician_id = auth.uid()) then
    raise exception 'Sorumlu uzmanı yalnız klinik sahibi değiştirir';
  end if;
  return new;
end $$;

create or replace function public.notify_clinic(p_clinic uuid, p_clinician uuid, p_kind text, p_title text, p_body text,
                                                p_data jsonb default '{}', p_child uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select m.clinician_id as id from public.clinic_members m
            where m.clinic_id = p_clinic and m.status = 'active' and (p_clinician is null or m.clinician_id = p_clinician) loop
    perform public.notify(r.id, 'clinic', p_kind, p_title, p_body,
                          coalesce(p_data, '{}'::jsonb) || jsonb_build_object('clinic_id', p_clinic), null, p_child);
  end loop;
end $$;

-- Uzman bildirimine alanı yazar: dokununca uygulama o alana geçer (paylaşım, davet kodu, seans ya da çocuk üzerinden)
create or replace function public.notifications_clinic_scope() returns trigger
language plpgsql security definer set search_path = '' as $$
declare cid uuid;
begin
  if new.app <> 'clinic' or new.data ? 'clinic_id' or new.data ? 'request_id' then return new; end if;
  begin
    if new.data ? 'link_id' then
      select clinic_id into cid from public.clinic_links where id = (new.data ->> 'link_id')::uuid;
    end if;
    if cid is null and new.data ? 'code' then
      select clinic_id into cid from public.clinic_invites where code = new.data ->> 'code';
    end if;
    if cid is null and new.data ? 'session_id' and to_regclass('public.clinic_sessions') is not null then
      execute 'select clinic_id from public.clinic_sessions where id = $1' into cid using (new.data ->> 'session_id')::uuid;
    end if;
  exception when others then cid := null;
  end;
  if cid is null and new.child_id is not null then
    select l.clinic_id into cid from public.clinic_links l
      join public.clinic_members m on m.clinic_id = l.clinic_id and m.clinician_id = new.user_id and m.status = 'active'
     where l.child_id = new.child_id and l.status = 'active' order by l.consent_at desc limit 1;
  end if;
  if cid is not null then new.data := new.data || jsonb_build_object('clinic_id', cid); end if;
  return new;
end $$;
revoke execute on function public.notifications_clinic_scope() from public, anon, authenticated;
drop trigger if exists notifications_clinic_scope on public.notifications;
create trigger notifications_clinic_scope before insert on public.notifications
  for each row execute function public.notifications_clinic_scope();

create or replace function public.suggestions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('suggestion_id', new.id, 'child_id', new.child_id, 'link_id', new.link_id);
  rid uuid;
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform public.notify_parents(new.family_id, 'clinic_suggestion',
        case when new.kind = 'change' then 'Uzmanın ' || nm || ' için değişiklik önerdi' else 'Uzmanın ' || nm || ' için görev önerdi' end,
        coalesce(new.emoji || ' ', '') || new.title, d - 'link_id', new.child_id);
    end if;
  elsif old.status = 'pending' and new.status in ('accepted', 'declined') then
    -- öneriyi yazan uzman hâlâ danışanı görüyorsa ona; görmüyorsa danışanın alıcılarına
    for rid in
      select new.created_by where new.created_by is not null and exists (
        select 1 from public.clinic_members m join public.clinic_links l on l.id = new.link_id
         where m.clinician_id = new.created_by and m.clinic_id = l.clinic_id and m.status = 'active'
           and (m.role = 'owner' or l.clinician_id = m.clinician_id
                or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.clinician_id)))
      union
      select x from public.clinic_link_recipients(new.link_id) x
       where new.created_by is null or not exists (
         select 1 from public.clinic_members m join public.clinic_links l on l.id = new.link_id
          where m.clinician_id = new.created_by and m.clinic_id = l.clinic_id and m.status = 'active'
            and (m.role = 'owner' or l.clinician_id = m.clinician_id
                 or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.clinician_id)))
    loop
      perform public.notify(rid, 'clinic', 'suggestion_decided',
        case when new.kind = 'change' then
               case when new.status = 'accepted' then 'Değişiklik uygulandı: ' else 'Değişiklik şimdilik uygulanmadı: ' end
             else case when new.status = 'accepted' then 'Öneri kabul edildi: ' else 'Öneri şimdilik eklenmedi: ' end end || new.title,
        nm, d, null, new.child_id);
    end loop;
  end if;
  return null;
end $$;

create or replace function public.clinic_redact_names(p_clinic uuid, p_clinician uuid, p_child uuid)
returns text[] language sql stable security definer set search_path = '' as $$
  with ppl as (
    select m.name from public.clinicians m
     where m.id = p_clinician or m.id in (select x.clinician_id from public.clinic_members x where x.clinic_id = p_clinic)
  ), raw as (
    select c.name as x from public.clinics c where c.id = p_clinic
    union all select t from public.clinics c, regexp_split_to_table(c.name, '[\s''’.,-]+') t where c.id = p_clinic and char_length(t) >= 4
    union all select name from ppl
    union all select t from ppl, regexp_split_to_table(ppl.name, '[\s.]+') t where char_length(t) >= 3
  ), kid as (
    select lower(translate(t, 'İIı', 'iii')) as k from public.children ch, regexp_split_to_table(ch.name, '\s+') t where ch.id = p_child
  )
  select coalesce(array_agg(distinct btrim(x)), '{}') from raw
   where char_length(btrim(x)) >= 3 and btrim(x) ~ '[[:alpha:]]'
     and lower(translate(btrim(x), 'İIı', 'iii')) not in (select k from kid)
     and lower(translate(btrim(x), 'İIı', 'iii')) not in ('dr', 'doç', 'doc', 'prof', 'uzm', 'psk', 'klinik', 'kliniği', 'klinigi',
       'merkez', 'merkezi', 'çocuk', 'cocuk', 'aile', 'özel', 'ozel', 'terapi', 'terapist', 'danışmanlık', 'danismanlik', 'danışma',
       'psikoloji', 'psikolojik', 'psikolog', 'gelişim', 'gelisim', 'eğitim', 'egitim', 'ergoterapi', 'konuşma', 'konusma', 'sağlık',
       'saglik', 'enstitü', 'enstitüsü', 'akademi', 'destek', 'grup', 'ofis', 'uzman', 'davranış', 'davranis', 've', 'and')
$$;

create or replace function public.clinic_assign(p_link_id uuid, p_clinician_id uuid, p_assigned boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
begin
  if not public.clinic_is_owner() then raise exception 'Danışanı yalnız klinik sahibi atar'; end if;
  if not public.clinician_access() then raise exception 'Üyelik etkin değil' using errcode = 'P0402'; end if;
  select * into l from public.clinic_links where id = p_link_id and clinic_id = public.my_clinic_id() and status = 'active';
  if not found then raise exception 'Paylaşım bulunamadı'; end if;
  if public.clinic_member_role(l.clinic_id, p_clinician_id) is null then
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

create or replace function public.clinic_set_responsible(p_link_id uuid, p_clinician_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
begin
  if not public.clinic_is_owner() then raise exception 'Sorumlu uzmanı yalnız klinik sahibi değiştirir'; end if;
  select * into l from public.clinic_links where id = p_link_id and clinic_id = public.my_clinic_id() and status = 'active';
  if not found then raise exception 'Paylaşım bulunamadı'; end if;
  if public.clinic_member_role(l.clinic_id, p_clinician_id) is null then
    raise exception 'Uzman bu kliniğin ekibinde değil';
  end if;
  update public.clinic_links set clinician_id = p_clinician_id where id = l.id;
  delete from public.clinic_link_access where link_id = l.id and clinician_id = p_clinician_id;
end $$;

-- ---------------------------------------------------------------- politikalar
drop policy if exists "uzman: ekip okur" on public.clinicians;
create policy "uzman: ekip okur" on public.clinicians for select to authenticated
  using (id = auth.uid() or exists (select 1 from public.clinic_members x
                                     where x.clinician_id = clinicians.id and x.clinic_id = public.my_clinic_id()));
drop policy if exists "klinik: sahip adını değiştirir" on public.clinics;
create policy "klinik: sahip adını değiştirir" on public.clinics for update to authenticated
  using (id = public.my_clinic_id() and public.clinic_is_owner())
  with check (id = public.my_clinic_id());
drop policy if exists "üyelik: kendi ve alanın ekibi" on public.clinic_members;
create policy "üyelik: kendi ve alanın ekibi" on public.clinic_members for select to authenticated
  using (clinician_id = auth.uid() or clinic_id = public.my_clinic_id());
drop policy if exists "ekip isteği: hedef uzman ve sahip" on public.clinic_member_requests;
create policy "ekip isteği: hedef uzman ve sahip" on public.clinic_member_requests for select to authenticated
  using (clinician_id = auth.uid() or (clinic_id = public.my_clinic_id() and public.clinic_is_owner()));

drop policy if exists "rutin: klinik okur" on public.clinic_routines;
create policy "rutin: klinik okur" on public.clinic_routines for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or shared or public.clinic_is_owner()));
drop policy if exists "rutin: sahibi düzenler" on public.clinic_routines;
create policy "rutin: sahibi düzenler" on public.clinic_routines for update to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or public.clinic_is_owner()));
drop policy if exists "rutin: sahibi siler" on public.clinic_routines;
create policy "rutin: sahibi siler" on public.clinic_routines for delete to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or public.clinic_is_owner()));
drop policy if exists "şablon: klinik okur" on public.clinic_plan_templates;
create policy "şablon: klinik okur" on public.clinic_plan_templates for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or shared or public.clinic_is_owner()));
drop policy if exists "şablon: sahibi düzenler" on public.clinic_plan_templates;
create policy "şablon: sahibi düzenler" on public.clinic_plan_templates for update to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or public.clinic_is_owner()));
drop policy if exists "şablon: sahibi siler" on public.clinic_plan_templates;
create policy "şablon: sahibi siler" on public.clinic_plan_templates for delete to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or public.clinic_is_owner()));

-- ---------------------------------------------------------------- hesap: kayıt, profil, alanlar
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  cid uuid;
  inv public.clinic_invites%rowtype;
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  nm text := left(coalesce(trim(meta ->> 'name'), ''), 80);
  cname text := nullif(trim(meta ->> 'clinic_name'), '');
  solo boolean;
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;
  if meta ->> 'account' = 'clinician' then
    if nullif(trim(meta ->> 'team_code'), '') is not null then
      -- eski uygulama sürümü: ekip koduyla kayıt (yeni ClinicApp göstermez)
      select * into inv from public.clinic_invites
        where code = upper(trim(meta ->> 'team_code')) and kind = 'clinician'
          and used_at is null and expires_at > now()
        for update;
      if not found then
        raise exception 'Ekip kodu geçersiz ya da süresi dolmuş';
      end if;
      perform 1 from public.clinics where id = inv.clinic_id for update;
      if (select count(*) from public.clinic_members where clinic_id = inv.clinic_id and status = 'active')
         >= (select seat_limit from public.clinics where id = inv.clinic_id) then
        raise exception 'Kliniğin uzman koltuğu dolu';
      end if;
      cid := inv.clinic_id;
      update public.clinic_invites set used_at = now(), used_by = new.id where code = inv.code;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, nm, left(coalesce(trim(meta ->> 'title'), ''), 80), 'member');
      insert into public.clinic_members (clinic_id, clinician_id, role, invited_by)
      values (cid, new.id, 'member', inv.clinician_id)
      on conflict (clinic_id, clinician_id) do update set invited_by = excluded.invited_by;
    else
      solo := coalesce(meta ->> 'practice', '') <> 'clinic'
              and (meta ->> 'practice' = 'solo' or cname is null or lower(cname) = lower(nm));
      insert into public.clinics (name, created_by)
      values (left(coalesce(cname, nullif(nm, ''), 'Kliniğim'), 120), new.id)
      returning id into cid;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, nm, left(coalesce(trim(meta ->> 'title'), ''), 80), 'owner');
      if solo then update public.clinics set personal_of = new.id where id = cid; end if;
      insert into public.clinic_members (clinic_id, clinician_id, role)
      values (cid, new.id, 'owner') on conflict (clinic_id, clinician_id) do nothing;
    end if;
    return new;
  end if;
  insert into public.families (created_by) values (new.id) returning id into fid;
  insert into public.profiles (id, family_id, nickname, name, avatar)
  values (
    new.id,
    fid,
    coalesce(nullif(trim(meta ->> 'nickname'), ''), 'Ben'),
    coalesce(trim(meta ->> 'name'), ''),
    coalesce(nullif(meta ->> 'avatar', ''), 'erkek')
  );
  -- Uzman daveti (bağlantı anahtarı ya da kod); hata kaydı engellemez
  begin
    inv := public.clinic_family_invite_find(meta ->> 'clinic_invite');
    if inv.code is not null and inv.claimed_at is null and inv.used_at is null and inv.revoked_at is null and inv.expires_at > now() then
      perform public.clinic_invite_claim_for(inv.code, fid, new.id);
    end if;
  exception when others then null;
  end;
  return new;
end $$;

create or replace function public.clinician_me()
returns json language sql stable security definer set search_path = '' as $$
  with ws as (select public.my_clinic_id() as cid),
  mem as (select cm.* from public.clinic_members cm, ws
           where cm.clinic_id = ws.cid and cm.clinician_id = auth.uid() and cm.status = 'active')
  select json_build_object(
    'id', m.id, 'name', m.name, 'title', m.title, 'role', mem.role,
    'clinic_id', c.id, 'clinic', c.name, 'plan', c.plan, 'seat_limit', c.seat_limit,
    'trial_ends_at', c.trial_ends_at, 'active', case when c.id is null then false else public.clinic_active(c.id) end,
    'access', coalesce(public.clinic_active(c.id) and (mem.role = 'owner' or c.seat_limit > 1), false),
    'status', case when c.id is null then null
                   when c.plan = 'trial' and c.trial_ends_at > now() then 'trial'
                   when public.clinic_active(c.id) then 'active' else 'expired' end,
    'billing_period', c.billing_period, 'period_end', c.period_end,
    'billing_source', c.billing_source, 'auto_renew', c.auto_renew,
    'member_count', (select count(*) from public.clinic_members x where x.clinic_id = c.id and x.status = 'active'),
    'joined_at', coalesce(mem.joined_at, m.created_at),
    'owner_name', (select o.name from public.clinic_members x join public.clinicians o on o.id = x.clinician_id
                    where x.clinic_id = c.id and x.role = 'owner' and x.status = 'active' order by x.joined_at limit 1),
    'invited_by_name', coalesce((select i.name from public.clinicians i where i.id = mem.invited_by),
                                (select i.name from public.clinic_invites v join public.clinicians i on i.id = v.clinician_id
                                  where v.used_by = m.id and v.kind = 'clinician' and v.clinic_id = c.id
                                  order by v.used_at desc limit 1)),
    'personal', coalesce(c.personal_of = m.id, false),
    'members_can_invite', coalesce(c.members_can_invite, true),
    'default_clinic_id', m.clinic_id,
    'workspace_invalid', c.id is null,
    'workspaces', (select count(*) from public.clinic_members x where x.clinician_id = m.id and x.status = 'active'),
    'has_personal', exists (select 1 from public.clinics p where p.personal_of = m.id),
    'requests', (select count(*) from public.clinic_member_requests q
                  where q.clinician_id = m.id and q.status = 'pending' and q.expires_at > now()))
  from public.clinicians m
  cross join ws
  left join public.clinics c on c.id = ws.cid
  left join mem on true
  where m.id = auth.uid()
$$;

-- Uzmanın etkin alanları (alan seçici)
create or replace function public.clinician_workspaces()
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(json_build_object(
      'clinic_id', c.id, 'name', c.name, 'role', x.role, 'personal', coalesce(c.personal_of = x.clinician_id, false),
      'active', public.clinic_active(c.id),
      'access', public.clinic_active(c.id) and (x.role = 'owner' or c.seat_limit > 1),
      'default', c.id = m.clinic_id,
      'members', (select count(*) from public.clinic_members y where y.clinic_id = c.id and y.status = 'active'),
      'joined_at', x.joined_at)
    order by coalesce(c.personal_of = x.clinician_id, false) desc, x.joined_at), '[]')
  from public.clinic_members x
  join public.clinics c on c.id = x.clinic_id
  join public.clinicians m on m.id = x.clinician_id
  where x.clinician_id = auth.uid() and x.status = 'active'
$$;
revoke execute on function public.clinician_workspaces() from public, anon;
grant execute on function public.clinician_workspaces() to authenticated;

-- Bireysel alan (yoksa açılır). Deneme süresi uzmanın daha önce açtığı alanlarla ortaktır (yeni alan yeni deneme vermez).
create or replace function public.clinician_personal_workspace_for(p_user uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  cid uuid;
  t timestamptz;
begin
  select * into me from public.clinicians where id = p_user;
  if not found then raise exception 'Yalnızca uzman hesabı' using errcode = '42501'; end if;
  select id into cid from public.clinics where personal_of = p_user;
  if cid is null then
    t := (select max(trial_ends_at) from public.clinics where created_by = p_user);
    insert into public.clinics (name, created_by, trial_ends_at)
    values (left(coalesce(nullif(btrim(me.name), ''), 'Bireysel çalışmam'), 120), p_user, coalesce(t, now() + interval '7 days'))
    returning id into cid;
    update public.clinics set personal_of = p_user where id = cid;
  end if;
  insert into public.clinic_members (clinic_id, clinician_id, role) values (cid, p_user, 'owner')
  on conflict (clinic_id, clinician_id) do update set status = 'active', role = 'owner', left_at = null;
  return cid;
end $$;
revoke execute on function public.clinician_personal_workspace_for(uuid) from public, anon, authenticated;

create or replace function public.clinician_personal_workspace()
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  return public.clinician_personal_workspace_for(auth.uid());
end $$;
revoke execute on function public.clinician_personal_workspace() from public, anon;
grant execute on function public.clinician_personal_workspace() to authenticated;

-- Yeni klinik alanı (uzman kendi kliniğini açar; sahibi olur). En çok 3 klinik; deneme süresi ortak.
create or replace function public.clinic_workspace_create(p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  nm text := left(btrim(coalesce(p_name, '')), 120);
  cid uuid;
  t timestamptz;
begin
  if uid is null or not exists (select 1 from public.clinicians where id = uid) then
    raise exception 'Yalnızca uzman hesabı' using errcode = '42501';
  end if;
  if nm = '' then raise exception 'name_required'; end if;
  if (select count(*) from public.clinics where created_by = uid and personal_of is null) >= 3 then
    raise exception 'too_many_clinics';
  end if;
  t := (select max(trial_ends_at) from public.clinics where created_by = uid);
  insert into public.clinics (name, created_by, trial_ends_at)
  values (nm, uid, coalesce(t, now() + interval '7 days')) returning id into cid;
  insert into public.clinic_members (clinic_id, clinician_id, role) values (cid, uid, 'owner');
  return cid;
end $$;
revoke execute on function public.clinic_workspace_create(text) from public, anon;
grant execute on function public.clinic_workspace_create(text) to authenticated;

-- ---------------------------------------------------------------- kişisel kod ve ekibe ekleme isteği
create or replace function public.clinician_personal_code(p_rotate boolean default false)
returns text language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  cur text;
  nc text;
begin
  if uid is null or not exists (select 1 from public.clinicians where id = uid) then
    raise exception 'Yalnızca uzman hesabı' using errcode = '42501';
  end if;
  select code into cur from public.clinician_codes where clinician_id = uid;
  if cur is not null and not coalesce(p_rotate, false) then return cur; end if;
  loop
    nc := public.random_code(8);
    exit when not exists (select 1 from public.clinician_codes where code = nc)
          and not exists (select 1 from public.clinic_invites where code = nc)
          and not exists (select 1 from public.invite_codes where code = nc);
  end loop;
  insert into public.clinician_codes (clinician_id, code) values (uid, nc)
  on conflict (clinician_id) do update set code = excluded.code, created_at = now();
  return nc;
end $$;
revoke execute on function public.clinician_personal_code(boolean) from public, anon;
grant execute on function public.clinician_personal_code(boolean) to authenticated;

-- Klinik sahibi uzmanın kişisel koduyla ekibe ekleme isteği gönderir; uzman kabul edene kadar hiçbir şey açılmaz
create or replace function public.clinic_member_request(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  cid uuid := public.my_clinic_id();
  c public.clinics%rowtype;
  target public.clinicians%rowtype;
  rq public.clinic_member_requests%rowtype;
  t json;
  k text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  if cid is null or not public.clinic_is_owner() then raise exception 'only_owner' using errcode = '42501'; end if;
  select * into c from public.clinics where id = cid for update;
  if c.personal_of is not null then return json_build_object('error', 'personal_workspace'); end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  select m.* into target from public.clinician_codes x join public.clinicians m on m.id = x.clinician_id where x.code = k;
  if not found then return public.code_rejected('not_found'); end if;
  if target.id = uid then return json_build_object('error', 'self'); end if;
  if public.clinic_member_role(cid, target.id) is not null then
    return json_build_object('error', 'already_member', 'name', target.name);
  end if;
  update public.clinic_member_requests set status = 'cancelled', decided_at = now()
   where clinic_id = cid and clinician_id = target.id and status = 'pending' and expires_at <= now();
  select * into rq from public.clinic_member_requests where clinic_id = cid and clinician_id = target.id and status = 'pending';
  if found then
    return json_build_object('status', 'pending', 'id', rq.id, 'name', target.name, 'title', target.title, 'expires_at', rq.expires_at);
  end if;
  if (select count(*) from public.clinic_members where clinic_id = cid and status = 'active')
     + (select count(*) from public.clinic_member_requests where clinic_id = cid and status = 'pending' and expires_at > now())
     >= c.seat_limit then
    return json_build_object('error', 'seat_full');
  end if;
  insert into public.clinic_member_requests (clinic_id, clinician_id, requested_by)
  values (cid, target.id, uid) returning * into rq;
  perform public.notify(target.id, 'clinic', 'team_request', left(c.name, 80) || ' seni ekibine eklemek istiyor',
    coalesce((select name from public.clinicians where id = uid), ''), jsonb_build_object('request_id', rq.id));
  return json_build_object('status', 'sent', 'id', rq.id, 'name', target.name, 'title', target.title, 'expires_at', rq.expires_at);
end $$;
revoke execute on function public.clinic_member_request(text) from public, anon;
grant execute on function public.clinic_member_request(text) to authenticated;

create or replace function public.clinic_member_requests_mine()
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(json_build_object(
      'id', q.id, 'clinic_id', q.clinic_id, 'clinic', c.name, 'by', coalesce(r.name, ''), 'by_title', coalesce(r.title, ''),
      'members', (select count(*) from public.clinic_members y where y.clinic_id = q.clinic_id and y.status = 'active'),
      'created_at', q.created_at, 'expires_at', q.expires_at) order by q.created_at desc), '[]')
  from public.clinic_member_requests q
  join public.clinics c on c.id = q.clinic_id
  left join public.clinicians r on r.id = q.requested_by
  where q.clinician_id = auth.uid() and q.status = 'pending' and q.expires_at > now()
$$;
revoke execute on function public.clinic_member_requests_mine() from public, anon;
grant execute on function public.clinic_member_requests_mine() to authenticated;

create or replace function public.clinic_member_respond(p_request uuid, p_accept boolean)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  rq public.clinic_member_requests%rowtype;
  c public.clinics%rowtype;
  nm text;
  r record;
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  select * into rq from public.clinic_member_requests where id = p_request and clinician_id = uid for update;
  if not found or rq.status <> 'pending' or rq.expires_at <= now() then return json_build_object('error', 'closed'); end if;
  nm := coalesce(nullif((select name from public.clinicians where id = uid), ''), 'Uzman');
  if not coalesce(p_accept, false) then
    update public.clinic_member_requests set status = 'declined', decided_at = now() where id = rq.id;
    perform public.notify(rq.requested_by, 'clinic', 'team_request_declined', nm || ' ekibe katılma isteğini kabul etmedi', '',
      jsonb_build_object('clinic_id', rq.clinic_id, 'clinician_id', uid));
    return json_build_object('status', 'declined');
  end if;
  select * into c from public.clinics where id = rq.clinic_id for update;
  if (select count(*) from public.clinic_members where clinic_id = rq.clinic_id and status = 'active') >= c.seat_limit then
    return json_build_object('error', 'seat_full');
  end if;
  insert into public.clinic_members (clinic_id, clinician_id, role, status, invited_by, joined_at)
  values (rq.clinic_id, uid, 'member', 'active', rq.requested_by, now())
  on conflict (clinic_id, clinician_id) do update
    set status = 'active', left_at = null, joined_at = now(), invited_by = excluded.invited_by;
  update public.clinic_member_requests set status = 'accepted', decided_at = now() where id = rq.id;
  for r in select clinician_id from public.clinic_members where clinic_id = rq.clinic_id and role = 'owner' and status = 'active' loop
    perform public.notify(r.clinician_id, 'clinic', 'team_joined', nm || ' ekibe katıldı', '',
      jsonb_build_object('clinic_id', rq.clinic_id, 'clinician_id', uid));
  end loop;
  return json_build_object('status', 'accepted', 'clinic_id', rq.clinic_id, 'clinic', c.name);
end $$;
revoke execute on function public.clinic_member_respond(uuid, boolean) from public, anon;
grant execute on function public.clinic_member_respond(uuid, boolean) to authenticated;

create or replace function public.clinic_member_request_cancel(p_request uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.clinic_is_owner() then raise exception 'only_owner' using errcode = '42501'; end if;
  update public.clinic_member_requests set status = 'cancelled', decided_at = now()
   where id = p_request and clinic_id = public.my_clinic_id() and status = 'pending';
end $$;
revoke execute on function public.clinic_member_request_cancel(uuid) from public, anon;
grant execute on function public.clinic_member_request_cancel(uuid) to authenticated;

-- Etkin alanın ekibi (rol üyelikten) ve sahip için bekleyen istekler
create or replace function public.clinic_team()
returns json language sql stable security definer set search_path = '' as $$
  with ws as (select public.my_clinic_id() as cid, public.clinic_is_owner() as own)
  select json_build_object(
    'members', (select coalesce(json_agg(json_build_object(
        'id', m.id, 'name', m.name, 'title', m.title, 'role', x.role, 'joined_at', x.joined_at,
        'invited_by_name', (select i.name from public.clinicians i where i.id = x.invited_by),
        'verified_as', public.clinician_badge(m.id))
        order by (x.role <> 'owner'), x.joined_at), '[]')
      from public.clinic_members x join public.clinicians m on m.id = x.clinician_id
      where x.clinic_id = ws.cid and x.status = 'active'),
    'requests', case when ws.own then (select coalesce(json_agg(json_build_object(
        'id', q.id, 'name', m.name, 'title', m.title, 'created_at', q.created_at, 'expires_at', q.expires_at)
        order by q.created_at desc), '[]')
      from public.clinic_member_requests q join public.clinicians m on m.id = q.clinician_id
      where q.clinic_id = ws.cid and q.status = 'pending' and q.expires_at > now()) else '[]'::json end,
    'seat_limit', c.seat_limit, 'members_can_invite', c.members_can_invite, 'personal', c.personal_of is not null)
  from ws join public.clinics c on c.id = ws.cid
$$;
revoke execute on function public.clinic_team() from public, anon;
grant execute on function public.clinic_team() to authenticated;

-- Üyelik biter (ayrılma ya da çıkarılma): danışan atamaları, sorumluluk, bekleyen davetler, gelecek seanslar ve
-- çalışma saatleri o klinikte kapanır; danışanlar ve uzmanın yazdıkları klinikte kalır. Varsayılan alan buysa
-- uzmanın bireysel alanına geçer.
create or replace function public.clinic_member_end(p_clinic uuid, p_clinician uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.clinic_members set status = 'left', left_at = now()
   where clinic_id = p_clinic and clinician_id = p_clinician and status = 'active';
  delete from public.clinic_link_access where clinic_id = p_clinic and clinician_id = p_clinician;
  update public.clinic_links set clinician_id = null where clinic_id = p_clinic and clinician_id = p_clinician;
  update public.clinic_invites set revoked_at = now()
   where clinic_id = p_clinic and clinician_id = p_clinician and kind = 'family'
     and used_at is null and revoked_at is null and declined_at is null;
  if to_regclass('public.clinic_sessions') is not null then
    execute 'update public.clinic_sessions set clinician_id = null where clinic_id = $1 and clinician_id = $2
               and starts_at > now() and status in (''planned'', ''offered'')' using p_clinic, p_clinician;
  end if;
  if to_regclass('public.clinic_availability') is not null then
    execute 'delete from public.clinic_availability where clinic_id = $1 and clinician_id = $2' using p_clinic, p_clinician;
  end if;
  if (select clinic_id from public.clinicians where id = p_clinician) = p_clinic then
    update public.clinicians set clinic_id = public.clinician_personal_workspace_for(p_clinician), role = 'owner'
     where id = p_clinician;
  end if;
end $$;
revoke execute on function public.clinic_member_end(uuid, uuid) from public, anon, authenticated;

create or replace function public.clinic_member_remove(p_clinician uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare cid uuid := public.my_clinic_id();
begin
  if not public.clinic_is_owner() then raise exception 'only_owner' using errcode = '42501'; end if;
  if p_clinician = auth.uid() then raise exception 'owner_cannot_leave'; end if;
  if public.clinic_member_role(cid, p_clinician) is distinct from 'member' then raise exception 'not_member'; end if;
  perform public.clinic_member_end(cid, p_clinician);
  perform public.notify(p_clinician, 'clinic', 'team_removed',
    left((select name from public.clinics where id = cid), 80) || ' ekibinden çıkarıldın',
    'Bu kliniğin danışanlarını artık görmüyorsun.', '{}'::jsonb);
end $$;
revoke execute on function public.clinic_member_remove(uuid) from public, anon;
grant execute on function public.clinic_member_remove(uuid) to authenticated;

create or replace function public.clinic_leave()
returns void language plpgsql security definer set search_path = '' as $$
declare
  cid uuid := public.my_clinic_id();
  nm text := coalesce(nullif((select name from public.clinicians where id = auth.uid()), ''), 'Bir uzman');
  r record;
begin
  if cid is null then raise exception 'not_member'; end if;
  if (select personal_of from public.clinics where id = cid) is not null then raise exception 'personal_workspace'; end if;
  if public.my_clinic_role() = 'owner' then raise exception 'owner_cannot_leave'; end if;
  perform public.clinic_member_end(cid, auth.uid());
  for r in select clinician_id from public.clinic_members where clinic_id = cid and role = 'owner' and status = 'active' loop
    perform public.notify(r.clinician_id, 'clinic', 'team_left', nm || ' ekipten ayrıldı', '',
      jsonb_build_object('clinic_id', cid, 'clinician_id', auth.uid()));
  end loop;
end $$;
revoke execute on function public.clinic_leave() from public, anon;
grant execute on function public.clinic_leave() to authenticated;

-- Klinikteki uzmanlar aile davet edebilir mi (varsayılan evet; sahip değiştirir)
create or replace function public.clinic_invite_policy_set(p_members_can_invite boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.clinic_is_owner() then raise exception 'only_owner' using errcode = '42501'; end if;
  update public.clinics set members_can_invite = coalesce(p_members_can_invite, true) where id = public.my_clinic_id();
end $$;
revoke execute on function public.clinic_invite_policy_set(boolean) from public, anon;
grant execute on function public.clinic_invite_policy_set(boolean) to authenticated;

-- ---------------------------------------------------------------- davetler alanla
create or replace function public.clinic_create_invite(p_kind text default 'family', p_label text default '',
                                                        p_parent_name text default '', p_parent_email text default null,
                                                        p_child_name text default '', p_child_age_group text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  cid uuid := public.my_clinic_id();
  rl text := public.my_clinic_role();
  new_code text;
  new_token text;
  exp timestamptz;
  email text := nullif(lower(trim(coalesce(p_parent_email, ''))), '');
  kid text := nullif(left(btrim(coalesce(p_child_name, '')), 40), '');
  grp text := nullif(upper(btrim(coalesce(p_child_age_group, ''))), '');
begin
  if cid is null or rl is null then raise exception 'Yalnızca uzman hesabı'; end if;
  if p_kind not in ('family', 'clinician') then raise exception 'Geçersiz davet türü'; end if;
  if not public.clinician_access() then raise exception 'Üyelik etkin değil' using errcode = 'P0402'; end if;
  if p_kind = 'clinician' and rl <> 'owner' then raise exception 'Ekibe yalnızca klinik sahibi davet eder'; end if;
  if p_kind = 'clinician' and (select seat_limit from public.clinics where id = cid) <= 1 then
    raise exception 'Bireysel pakette ekip yok; Klinik paketine geçin';
  end if;
  if p_kind = 'family' and rl <> 'owner' and not (select members_can_invite from public.clinics where id = cid) then
    raise exception 'invite_owner_only';
  end if;
  if email is not null and email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-posta adresi geçersiz'; end if;
  if grp is not null and grp not in ('K', 'A', 'B', 'C') then raise exception 'Geçersiz yaş grubu'; end if;
  if p_kind <> 'family' then kid := null; grp := null; end if;
  -- günde en çok 100 aile daveti (kötüye kullanım sınırı)
  if p_kind = 'family' and (select count(*) from public.clinic_invites
                             where clinician_id = uid and kind = 'family' and created_at > now() - interval '1 day') >= 100 then
    raise exception 'Bugün çok fazla davet oluşturdun; yarın tekrar dene';
  end if;
  delete from public.clinic_invites
   where clinic_id = cid and kind = 'clinician' and used_at is null and expires_at < now() - interval '1 day';
  exp := now() + case when p_kind = 'family' then interval '72 hours' else interval '15 minutes' end;
  loop
    new_code := public.random_code(case when p_kind = 'clinician' then 8 else 6 end);
    exit when not exists (select 1 from public.clinic_invites where code = new_code)
          and not exists (select 1 from public.invite_codes where code = new_code)
          and not exists (select 1 from public.clinician_codes where code = new_code);
  end loop;
  if p_kind = 'family' then new_token := replace(gen_random_uuid()::text, '-', ''); end if;
  insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at, token, parent_name, parent_email,
                                     child_name, child_age_group)
  values (new_code, cid, uid, p_kind, left(coalesce(p_label, ''), 60), exp, new_token,
          left(trim(coalesce(p_parent_name, '')), 60), email, kid, grp);
  return json_build_object('code', new_code, 'token', new_token, 'expires_at', exp);
end $$;

-- Edge Function invite-email çağırır (hizmet rolü, istek başlığı yok): uzmanın davetin alanındaki üyeliği denetlenir
create or replace function public.clinic_invite_email_take(p_code text, p_user uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  inv public.clinic_invites%rowtype;
  c public.clinics%rowtype;
  rl text;
begin
  select * into me from public.clinicians where id = p_user;
  if not found then return jsonb_build_object('error', 'not_found'); end if;
  select * into inv from public.clinic_invites where code = upper(trim(coalesce(p_code, ''))) and kind = 'family' for update;
  if found then rl := public.clinic_member_role(inv.clinic_id, me.id); end if;
  if not found or rl is null or not (inv.clinician_id = me.id or rl = 'owner') then
    return jsonb_build_object('error', 'not_found');
  end if;
  select * into c from public.clinics where id = inv.clinic_id;
  if not (public.clinic_active(c.id) and (rl = 'owner' or c.seat_limit > 1)) then return jsonb_build_object('error', 'no_access'); end if;
  if inv.parent_email is null then return jsonb_build_object('error', 'no_email'); end if;
  if inv.revoked_at is not null or inv.declined_at is not null or inv.used_at is not null or inv.claimed_at is not null then
    return jsonb_build_object('error', 'closed');
  end if;
  if inv.expires_at <= now() then return jsonb_build_object('error', 'expired'); end if;
  if inv.email_count >= 3 then return jsonb_build_object('error', 'limit_invite'); end if;
  if inv.email_sent_at > now() - interval '60 seconds' then return jsonb_build_object('error', 'too_soon'); end if;
  if (select count(*) from public.clinic_invites
       where clinician_id = me.id and code <> inv.code and email_sent_at > now() - interval '1 day') >= 30 then
    return jsonb_build_object('error', 'limit_day');
  end if;
  update public.clinic_invites
     set email_count = email_count + 1, email_sent_at = now(), email_status = 'sending', channel = 'email'
   where code = inv.code;
  -- davetli aile kendi ailesine bağlamadan çocuk önerisi ve uzmanın notu e-postaya girmez
  return jsonb_build_object('code', inv.code, 'token', inv.token, 'expires_at', inv.expires_at, 'to', inv.parent_email,
                            'clinician', me.name, 'title', me.title, 'clinic', c.name, 'independent', c.personal_of is not null);
end $$;

-- Eski uygulama sürümü: ekip koduyla katılma (yeni ClinicApp göstermez). Üyeliği de yazar.
create or replace function public.clinic_join_team(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  me public.clinicians%rowtype;
  inv public.clinic_invites%rowtype;
  old_clinic uuid;
  t json;
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  select * into me from public.clinicians where id = uid;
  if not found then raise exception 'Yalnızca uzman hesabı ekibe katılabilir'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  select * into inv from public.clinic_invites
    where code = upper(trim(p_code)) and kind = 'clinician'
    for update;
  if not found then return public.code_rejected('not_found'); end if;
  if public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.code_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;
  if public.clinic_member_role(inv.clinic_id, uid) is not null then raise exception 'Zaten bu kliniğin ekibindesin'; end if;
  perform 1 from public.clinics where id = inv.clinic_id for update;
  if (select count(*) from public.clinic_members where clinic_id = inv.clinic_id and status = 'active')
     >= (select seat_limit from public.clinics where id = inv.clinic_id) then
    raise exception 'Kliniğin uzman koltuğu dolu';
  end if;
  old_clinic := me.clinic_id;
  if exists (select 1 from public.clinic_members where clinic_id = old_clinic and clinician_id <> uid)
     or exists (select 1 from public.clinic_links where clinic_id = old_clinic)
     or exists (select 1 from public.clinic_notes where clinic_id = old_clinic)
     or exists (select 1 from public.clinic_goals where clinic_id = old_clinic)
     or (to_regclass('public.billing_subscriptions') is not null
         and public.clinic_has_billing(old_clinic)) then
    raise exception 'Mevcut kliniğinde danışan, not, üyelik ya da başka uzman var; katılırsan kaybolur. Başka bir e-postayla kayıt olup ekip koduyla katıl.';
  end if;
  update public.clinicians set clinic_id = inv.clinic_id, role = 'member' where id = uid;
  insert into public.clinic_members (clinic_id, clinician_id, role, invited_by)
  values (inv.clinic_id, uid, 'member', inv.clinician_id)
  on conflict (clinic_id, clinician_id) do update set status = 'active', left_at = null, role = 'member', invited_by = excluded.invited_by;
  update public.clinic_invites set used_at = now(), used_by = uid where code = inv.code;
  delete from public.clinic_invites where clinic_id = old_clinic;
  delete from public.clinics where id = old_clinic;
  return json_build_object('clinic_id', inv.clinic_id);
end $$;

-- ---------------------------------------------------------------- hesap silme: her alanda ayrı karar
create or replace function public.account_delete_of(p_uid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  r record;
  heir uuid;
  sole uuid[] := '{}';
begin
  select family_id into fid from public.profiles where id = p_uid;
  if fid is not null and not exists (select 1 from public.profiles where family_id = fid and id <> p_uid) then
    delete from public.families where id = fid;
  end if;
  if exists (select 1 from public.clinicians where id = p_uid) then
    for r in select x.clinic_id, x.role from public.clinic_members x where x.clinician_id = p_uid and x.status = 'active' loop
      select y.clinician_id into heir from public.clinic_members y
       where y.clinic_id = r.clinic_id and y.status = 'active' and y.clinician_id <> p_uid
       order by (y.role <> 'owner'), y.joined_at limit 1;
      if heir is null then
        sole := sole || r.clinic_id;
      elsif r.role = 'owner' then
        update public.clinic_members set role = 'owner' where clinic_id = r.clinic_id and clinician_id = heir;
        update public.clinicians set role = 'owner' where id = heir and clinic_id = r.clinic_id;
        update public.clinic_links set clinician_id = heir where clinic_id = r.clinic_id and clinician_id = p_uid;
      else
        update public.clinic_links set clinician_id = null where clinic_id = r.clinic_id and clinician_id = p_uid;
      end if;
    end loop;
    -- kimsenin varsayılan alanı silinecek alanda kalmasın (başka uzmanın satırı silinmesin)
    update public.clinicians m set clinic_id = public.clinician_personal_workspace_for(m.id), role = 'owner'
     where m.id <> p_uid and m.clinic_id = any (sole);
    delete from public.clinics where id = any (sole) or personal_of = p_uid;
  end if;
  delete from auth.users where id = p_uid;
end $$;

-- ---------------------------------------------------------------- aileye görünen: bağımsız uzman mı?
drop function if exists public.family_clinic_links();
create function public.family_clinic_links()
returns table (link_id uuid, clinic_id uuid, child_id uuid, clinic text, clinician text, title text, consent_at timestamptz,
               history_shared boolean, history_available boolean, verified_as text, independent boolean)
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.child_id, c.name, coalesce(m.name, ''), coalesce(m.title, ''), l.consent_at,
         exists (select 1 from public.clinic_link_history h where h.link_id = l.id),
         exists (select 1 from public.clinic_links o where o.child_id = l.child_id and o.clinic_id <> l.clinic_id
                 and o.status <> 'active' and o.consent_at <= l.consent_at),
         public.clinician_badge(m.id),
         c.personal_of is not null
  from public.clinic_links l
  join public.clinics c on c.id = l.clinic_id
  left join public.clinicians m on m.id = l.clinician_id
  where l.family_id = public.my_family_id() and l.status = 'active'
  order by l.consent_at
$$;
revoke execute on function public.family_clinic_links() from public, anon;
grant execute on function public.family_clinic_links() to authenticated;

create or replace function public.clinic_invite_preview(p_code text)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  t json;
  why text;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  inv := public.clinic_family_invite_find(p_code);
  if inv.code is null then return public.clinic_invite_rejected('not_found'); end if;
  why := public.clinic_invite_problem(inv, fid);
  if why is not null then return public.clinic_invite_rejected(why); end if;
  return (select json_build_object('clinic', c.name, 'clinician', m.name, 'title', m.title, 'expires_at', inv.expires_at, 'code', inv.code,
                                   'verified_as', public.clinician_badge(m.id),
                                   'independent', c.personal_of is not null,
                                   'child_name', case when inv.claimed_family = fid then inv.child_name end,
                                   'child_age_group', case when inv.claimed_family = fid then inv.child_age_group end,
                                   'has_plan', exists (select 1 from public.clinic_goals where invite_code = inv.code)
                                            or exists (select 1 from public.care_modules where invite_code = inv.code))
            from public.clinics c, public.clinicians m where c.id = inv.clinic_id and m.id = inv.clinician_id);
end $$;
