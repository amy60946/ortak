-- =====================================================================
-- ClinicApp üyeliği (öneri, 22 Ekim 2026)
--   Paketler: "Bireysel" (solo, 1 uzman) ve "Klinik" (clinic, ekip dahil en çok 10 uzman); aylık ya da yıllık.
--   Yeni klinik 7 gün ücretsiz dener (kart istenmez; denemede ekip de denenebilir, 10 koltuk).
--   Deneme ya da üyelik bitince uzman çocuk verisine erişemez (sunucu kuralı); uygulama üyelik ekranını gösterir.
--   Ödeme: iPhone/iPad'de App Store aboneliği, web'de iyzico. İkisini de Edge Function `clinic-billing`
--   doğrular ve yalnız service role ile `billing_apply` çağırır. İstemci plan/süre yazamaz.
--   Eski planlar (small/business/custom) etkin sayılmaya devam eder (elle verilmiş).
-- Önkoşul: 20261021300000_security_pentest.sql. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Klinik: yeni plan değerleri ve üyelik alanları
-- ---------------------------------------------------------------------
alter table public.clinics drop constraint if exists clinics_plan_check;
alter table public.clinics add constraint clinics_plan_check
  check (plan in ('trial', 'solo', 'clinic', 'small', 'business', 'custom', 'inactive'));
alter table public.clinics add column if not exists billing_period text check (billing_period in ('monthly', 'yearly'));
alter table public.clinics add column if not exists period_end timestamptz;
alter table public.clinics add column if not exists billing_source text check (billing_source in ('app_store', 'iyzico', 'manual'));
alter table public.clinics add column if not exists auto_renew boolean not null default false;
alter table public.clinics alter column trial_ends_at set default now() + interval '7 days';
alter table public.clinics alter column seat_limit set default 10;
-- Denemedeki klinikler ekibi de deneyebilsin
update public.clinics set seat_limit = 10 where plan = 'trial' and seat_limit < 10;

-- ---------------------------------------------------------------------
-- 2. Paket kataloğu (fiyatlar web ekranında gösterilir; App Store fiyatı mağazadan okunur)
-- ---------------------------------------------------------------------
create table if not exists public.billing_plans (
  id                text primary key,
  package           text not null check (package in ('solo', 'clinic')),
  period            text not null check (period in ('monthly', 'yearly')),
  seat_limit        integer not null check (seat_limit between 1 and 1000),
  price_try         numeric(10, 2) not null check (price_try > 0),
  apple_product_id  text unique,
  iyzico_plan_ref   text,
  sort              integer not null default 0,
  active            boolean not null default true
);
insert into public.billing_plans (id, package, period, seat_limit, price_try, apple_product_id, sort) values
  ('solo_monthly',   'solo',   'monthly', 1,  749.99,   'com.clinicapp.uzman.solo.monthly',   1),
  ('solo_yearly',    'solo',   'yearly',  1,  7499.99,  'com.clinicapp.uzman.solo.yearly',    2),
  ('clinic_monthly', 'clinic', 'monthly', 10, 2999.99,  'com.clinicapp.uzman.clinic.monthly', 3),
  ('clinic_yearly',  'clinic', 'yearly',  10, 29999.99, 'com.clinicapp.uzman.clinic.yearly',  4)
on conflict (id) do nothing;

alter table public.billing_plans enable row level security;
drop policy if exists "paketler: herkes okur" on public.billing_plans;
create policy "paketler: herkes okur" on public.billing_plans for select to authenticated using (active);
revoke all on public.billing_plans from anon, authenticated;
grant select on public.billing_plans to authenticated;

-- ---------------------------------------------------------------------
-- 3. Abonelik kayıtları, ödeme sayfası oturumları, olay günlüğü (istemci okuyamaz)
-- ---------------------------------------------------------------------
create table if not exists public.billing_subscriptions (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  source        text not null check (source in ('app_store', 'iyzico', 'manual')),
  external_id   text not null check (char_length(external_id) between 1 and 200),  -- App Store originalTransactionId / iyzico abonelik referansı
  plan_id       text not null references public.billing_plans (id),
  status        text not null check (status in ('active', 'canceled', 'expired', 'refunded', 'pending')),
  period_end    timestamptz,
  auto_renew    boolean not null default false,
  environment   text,                                                             -- Production / Sandbox
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (source, external_id)
);
create index if not exists billing_subscriptions_clinic_idx on public.billing_subscriptions (clinic_id);

create table if not exists public.billing_checkouts (
  token         text primary key,
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  plan_id       text not null references public.billing_plans (id),
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  completed_at  timestamptz
);

create table if not exists public.billing_events (
  id           bigint generated always as identity primary key,
  clinic_id    uuid references public.clinics (id) on delete set null,
  source       text not null,
  kind         text not null,
  external_id  text,
  payload      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

alter table public.billing_subscriptions enable row level security;
alter table public.billing_checkouts     enable row level security;
alter table public.billing_events        enable row level security;
revoke all on public.billing_subscriptions, public.billing_checkouts, public.billing_events from anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Erişim: klinik etkin mi, bu uzman kullanabilir mi?
-- ---------------------------------------------------------------------
create or replace function public.clinic_active(p_clinic_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinics c
    where c.id = p_clinic_id
      and (c.plan in ('small', 'business', 'custom')
           or (c.plan = 'trial' and c.trial_ends_at > now())
           or (c.plan in ('solo', 'clinic') and c.period_end > now()))
  )
$$;

-- Oturumdaki uzman paneli kullanabilir mi? Klinik etkin ve (sahip ya da paket ekibe izin veriyor)
create or replace function public.clinician_access()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinicians m join public.clinics c on c.id = m.clinic_id
    where m.id = auth.uid() and public.clinic_active(c.id) and (m.role = 'owner' or c.seat_limit > 1)
  )
$$;
revoke execute on function public.clinician_access() from public, anon;
grant execute on function public.clinician_access() to authenticated;

-- Çocuk verisi yalnız etkin üyelikle görünür
create or replace function public.clinic_sees_child(p_child_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.clinician_access() and exists (
    select 1 from public.clinic_links l
    join public.clinicians m on m.clinic_id = l.clinic_id
    where m.id = auth.uid() and l.child_id = p_child_id and l.status = 'active'
  )
$$;

create or replace function public.clinic_link_mine(p_link_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.clinician_access() and exists (
    select 1 from public.clinic_links l
    where l.id = p_link_id and l.clinic_id = public.my_clinic_id() and l.status = 'active'
  )
$$;

create or replace function public.clinic_clients()
returns table (link_id uuid, clinic_id uuid, family_id uuid, child_id uuid, child_name text, avatar text,
               birthday date, label text, consent_at timestamptz, parents text)
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.family_id, l.child_id, c.name, c.avatar, c.birthday, l.label, l.consent_at,
         coalesce((select string_agg(coalesce(nullif(trim(p.name), ''), p.nickname), ', ' order by p.created_at)
                   from public.profiles p where p.family_id = l.family_id), '')
  from public.clinic_links l
  join public.children c on c.id = l.child_id
  where l.clinic_id = public.my_clinic_id() and l.status = 'active' and public.clinician_access()
  order by l.consent_at desc
$$;

-- Davet ve ekibe katılma: 20261021300000_security_pentest.sql'deki clinic_create_invite / clinic_join_team zaten
-- clinician_access() (yukarıda yeniden tanımlandı) ve Bireysel paket koltuğunu (seat_limit = 1) denetler.

-- ---------------------------------------------------------------------
-- 5. Uzmanın kendi bilgisi + üyelik durumu
-- ---------------------------------------------------------------------
create or replace function public.clinician_me()
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'id', m.id, 'name', m.name, 'title', m.title, 'role', m.role,
    'clinic_id', c.id, 'clinic', c.name, 'plan', c.plan, 'seat_limit', c.seat_limit,
    'trial_ends_at', c.trial_ends_at, 'active', public.clinic_active(c.id),
    'access', public.clinic_active(c.id) and (m.role = 'owner' or c.seat_limit > 1),
    'status', case when c.plan = 'trial' and c.trial_ends_at > now() then 'trial'
                   when public.clinic_active(c.id) then 'active' else 'expired' end,
    'billing_period', c.billing_period, 'period_end', c.period_end,
    'billing_source', c.billing_source, 'auto_renew', c.auto_renew,
    'member_count', (select count(*) from public.clinicians x where x.clinic_id = c.id),
    'joined_at', m.created_at,
    'owner_name', (select o.name from public.clinicians o where o.clinic_id = c.id and o.role = 'owner' order by o.created_at limit 1),
    'invited_by_name', (select i.name from public.clinic_invites v join public.clinicians i on i.id = v.clinician_id
                         where v.used_by = m.id and v.kind = 'clinician' and v.clinic_id = c.id
                         order by v.used_at desc limit 1))
  from public.clinicians m join public.clinics c on c.id = m.clinic_id
  where m.id = auth.uid()
$$;

-- ---------------------------------------------------------------------
-- 6. Sunucu (Edge Function, service role): doğrulanmış ödemeyi kliniğe yazar
-- ---------------------------------------------------------------------
create or replace function public.billing_recompute(p_clinic_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  best record;
  last record;
begin
  select s.*, p.package, p.period, p.seat_limit into best
    from public.billing_subscriptions s join public.billing_plans p on p.id = s.plan_id
   where s.clinic_id = p_clinic_id and s.status in ('active', 'canceled') and s.period_end > now()
   order by p.seat_limit desc, s.period_end desc limit 1;
  if found then
    update public.clinics set plan = best.package, seat_limit = best.seat_limit, billing_period = best.period,
           period_end = best.period_end, billing_source = best.source,
           auto_renew = (best.status = 'active' and best.auto_renew)
     where id = p_clinic_id;
    return;
  end if;
  -- Etkin abonelik yok: ücretli plandaysa süresi geçmiş olarak kalır (erişim kapanır)
  select s.*, p.package, p.period into last
    from public.billing_subscriptions s join public.billing_plans p on p.id = s.plan_id
   where s.clinic_id = p_clinic_id order by s.updated_at desc, s.created_at desc limit 1;
  if found and not exists (select 1 from public.clinics where id = p_clinic_id and plan = 'trial' and trial_ends_at > now()) then
    update public.clinics set plan = last.package, billing_period = last.period,
           period_end = least(coalesce(last.period_end, now()), now()), billing_source = last.source, auto_renew = false
     where id = p_clinic_id and plan in ('trial', 'solo', 'clinic');
  end if;
end $$;
revoke execute on function public.billing_recompute(uuid) from public, anon, authenticated;

create or replace function public.billing_apply(
  p_source text, p_external_id text, p_clinic_id uuid, p_plan_id text, p_status text,
  p_period_end timestamptz, p_auto_renew boolean, p_environment text default null, p_payload jsonb default '{}'::jsonb)
returns json language plpgsql security definer set search_path = '' as $$
declare
  cur public.billing_subscriptions%rowtype;
  cid uuid;
begin
  if p_source not in ('app_store', 'iyzico', 'manual') then raise exception 'Geçersiz kaynak'; end if;
  if not exists (select 1 from public.billing_plans where id = p_plan_id) then raise exception 'Geçersiz paket'; end if;
  select * into cur from public.billing_subscriptions where source = p_source and external_id = p_external_id for update;
  if found and p_clinic_id is not null and cur.clinic_id <> p_clinic_id then
    -- Aynı mağaza aboneliği başka bir kliniğe taşınamaz (makbuz yeniden kullanımı)
    raise exception 'Bu abonelik başka bir kliniğe bağlı' using errcode = 'P0409';
  end if;
  cid := coalesce(cur.clinic_id, p_clinic_id);
  if cid is null or not exists (select 1 from public.clinics where id = cid) then raise exception 'Klinik bulunamadı'; end if;

  insert into public.billing_subscriptions (clinic_id, source, external_id, plan_id, status, period_end, auto_renew, environment, updated_at)
  values (cid, p_source, p_external_id, p_plan_id, p_status, p_period_end, coalesce(p_auto_renew, false), p_environment, clock_timestamp())
  on conflict (source, external_id) do update
     set plan_id = excluded.plan_id, status = excluded.status, period_end = excluded.period_end,
         auto_renew = excluded.auto_renew, environment = coalesce(excluded.environment, billing_subscriptions.environment),
         updated_at = clock_timestamp();
  insert into public.billing_events (clinic_id, source, kind, external_id, payload)
  values (cid, p_source, 'apply:' || p_status, p_external_id, coalesce(p_payload, '{}'::jsonb));
  perform public.billing_recompute(cid);
  return (select json_build_object('clinic_id', c.id, 'plan', c.plan, 'period_end', c.period_end, 'active', public.clinic_active(c.id))
            from public.clinics c where c.id = cid);
end $$;
revoke execute on function public.billing_apply(text, text, uuid, text, text, timestamptz, boolean, text, jsonb) from public, anon, authenticated;
grant execute on function public.billing_apply(text, text, uuid, text, text, timestamptz, boolean, text, jsonb) to service_role;
grant execute on function public.billing_recompute(uuid) to service_role;
grant all on public.billing_subscriptions, public.billing_checkouts, public.billing_events to service_role;
grant select, update on public.billing_plans to service_role;
grant usage on all sequences in schema public to service_role;

-- ---------------------------------------------------------------------
-- 7. İş özeti: üyelik görünümü (yalnız SQL Editor)
-- ---------------------------------------------------------------------
create schema if not exists analytics;
create or replace view analytics.clinic_billing as
select c.id as clinic_id, c.name, c.plan, c.billing_period, c.billing_source, c.period_end, c.auto_renew,
       c.trial_ends_at, c.seat_limit, public.clinic_active(c.id) as active,
       (select count(*) from public.clinicians m where m.clinic_id = c.id) as clinicians,
       (select count(*) from public.clinic_links l where l.clinic_id = c.id and l.status = 'active') as clients,
       c.created_at
  from public.clinics c;
revoke all on analytics.clinic_billing from anon, authenticated;
