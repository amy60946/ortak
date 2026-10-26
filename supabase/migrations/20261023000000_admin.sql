-- =====================================================================
-- Admin paneli + KPI (öneri, 23 Ekim 2026; kullanıcı isteği 22 Ekim: "admin paneli ve KPI tracking")
--   Panel ayrı depoda (amy60946/admin-panel, web). Panel yalnız bu dosyadaki admin_* fonksiyonlarını çağırır;
--   tablolara doğrudan erişemez (RLS açık, politika yok).
--   Güvenlik: her admin_* çağrısı (admin_me hariç) admin_users'ta rol + iki adımlı doğrulama (JWT aal2) ister;
--   değiştiren her işlem gerekçesiyle admin_audit'e yazılır (silinemez, değiştirilemez).
--   Roller: owner (her şey), finance (premium/klinik üyeliği), support (bildirim, deneme uzatma, kişiye bayrak,
--           oturum kapatma), viewer (yalnız okuma). Her rol okuyabilir.
--   Gizlilik: mesaj içerikleri, fotoğraflar, uzman notlarının metni panelde YOK (yalnız sayılar).
--   İlk owner SQL Editor'den eklenir (e-posta depoya yazılmaz):
--     insert into public.admin_users (user_id, role) select id, 'owner' from auth.users where email = '<e-posta>';
--   KPI: activity_days (track_session her gün bir satır) + mevcut tablolardan hesap; fiyatlar app_config 'kpi'.
-- Önkoşul: proposed/20261022200000_clinic_billing.sql (billing_apply, billing_subscriptions). Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tablolar
-- ---------------------------------------------------------------------
create table if not exists public.admin_users (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  role        text not null check (role in ('owner', 'finance', 'support', 'viewer')),
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users (id) on delete set null
);
alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;

create table if not exists public.admin_audit (
  id           bigserial primary key,
  at           timestamptz not null default now(),
  admin_id     uuid,                                  -- silinen admin hesabında da kayıt kalır
  action       text not null check (action ~ '^[a-z][a-z0-9_.]{1,59}$'),
  target_type  text not null check (target_type in ('user', 'family', 'clinic', 'flag', 'config', 'admin', 'system')),
  target_id    text,
  reason       text not null check (char_length(reason) between 3 and 500),
  before       jsonb,
  after        jsonb
);
create index if not exists admin_audit_target on public.admin_audit (target_type, target_id, at desc);
alter table public.admin_audit enable row level security;
revoke all on public.admin_audit from anon, authenticated;

-- Denetim kaydı yalnız eklenir (owner dahil kimse değiştiremez/silemez)
create or replace function public.admin_audit_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'Denetim kaydı değiştirilemez' using errcode = '42501';
end $$;
drop trigger if exists admin_audit_immutable on public.admin_audit;
create trigger admin_audit_immutable before update or delete on public.admin_audit
  for each row execute function public.admin_audit_immutable();
revoke execute on function public.admin_audit_immutable() from public, anon, authenticated;

-- Özellik bayrakları: genel (yüzde ile açılış) + kişiye istisna (bitiş tarihli)
create table if not exists public.feature_flags (
  key          text primary key check (key ~ '^[a-z][a-z0-9_.]{1,59}$'),
  enabled      boolean not null default false,
  rollout_pct  integer not null default 100 check (rollout_pct between 0 and 100),
  description  text not null default '' check (char_length(description) <= 200),
  updated_at   timestamptz not null default now()
);
alter table public.feature_flags enable row level security;
revoke all on public.feature_flags from anon, authenticated;

create table if not exists public.user_flags (
  user_id     uuid not null references auth.users (id) on delete cascade,
  key         text not null check (key ~ '^[a-z][a-z0-9_.]{1,59}$'),
  enabled     boolean not null,
  expires_at  timestamptz,
  reason      text not null check (char_length(reason) between 3 and 500),
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  primary key (user_id, key)
);
alter table public.user_flags enable row level security;
revoke all on public.user_flags from anon, authenticated;

-- Günlük etkinlik (KPI: günlük/haftalık/aylık aktif, elde tutma). track_session yazar.
create table if not exists public.activity_days (
  user_id  uuid not null references auth.users (id) on delete cascade,
  app      text not null check (app in ('parent', 'child', 'clinic')),
  day      date not null,
  primary key (user_id, app, day)
);
create index if not exists activity_days_day on public.activity_days (day, app);
alter table public.activity_days enable row level security;
revoke all on public.activity_days from anon, authenticated;
-- Geçmiş: bugüne kadarki son aktif günler (tek gün; geçmiş seri bundan sonra birikir)
insert into public.activity_days (user_id, app, day)
select user_id, app, last_active_date from public.user_activity on conflict do nothing;
insert into public.activity_days (user_id, app, day)
select user_id, app, first_seen_at::date from public.user_activity on conflict do nothing;

-- KPI fiyatları (gelir tahmini için; TL, KDV dahil). ParentApp fiyatları kesinleşince güncellenir.
insert into public.app_config (key, value) values
  ('kpi', '{"parent_monthly_try": 0, "parent_yearly_try": 0, "store_fee_pct": 15, "revenuecat_pct": 1}'::jsonb)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 2. Yetki yardımcıları
-- ---------------------------------------------------------------------
create or replace function public.admin_role_of(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select role from public.admin_users where user_id = p_user
$$;

-- Çağıranın admin olduğunu, iki adımlı doğrulamayı ve rolünü denetler; admin kimliğini döner.
create or replace function public.admin_require(p_roles text[] default null)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  r text;
begin
  r := public.admin_role_of(uid);
  if uid is null or r is null then raise exception 'Yetkisiz' using errcode = '42501'; end if;
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'İki adımlı doğrulama gerekli' using errcode = '42501';
  end if;
  if p_roles is not null and r <> 'owner' and not (r = any (p_roles)) then
    raise exception 'Bu işlem için rolün yetmiyor (%)', r using errcode = '42501';
  end if;
  return uid;
end $$;

create or replace function public.admin_log(p_admin uuid, p_action text, p_type text, p_target text, p_reason text,
                                            p_before jsonb default null, p_after jsonb default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if char_length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'Gerekçe yaz (en az 3 harf)';
  end if;
  insert into public.admin_audit (admin_id, action, target_type, target_id, reason, before, after)
  values (p_admin, p_action, p_type, p_target, left(trim(p_reason), 500), p_before, p_after);
end $$;

-- Kullanıcının türü: clinician / parent / child / other
create or replace function public.account_kind(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case when exists (select 1 from public.clinicians where id = p_user) then 'clinician'
              when exists (select 1 from public.profiles where id = p_user) then 'parent'
              when exists (select 1 from public.children where user_id = p_user) then 'child'
              else 'other' end
$$;

-- Hesap silmenin ortak gövdesi (delete_account ve admin_delete_user kullanır)
create or replace function public.account_delete_of(p_uid uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  me public.clinicians%rowtype;
  heir uuid;
begin
  select family_id into fid from public.profiles where id = p_uid;
  if fid is not null and not exists (select 1 from public.profiles where family_id = fid and id <> p_uid) then
    delete from public.families where id = fid;
  end if;
  select * into me from public.clinicians where id = p_uid;
  if found then
    select id into heir from public.clinicians where clinic_id = me.clinic_id and id <> p_uid order by created_at limit 1;
    if heir is null then
      delete from public.clinics where id = me.clinic_id;
    elsif me.role = 'owner' then
      update public.clinicians set role = 'owner' where id = heir;
      update public.clinic_links set clinician_id = heir where clinician_id = p_uid;
    else
      update public.clinic_links set clinician_id = null where clinician_id = p_uid;
    end if;
  end if;
  delete from auth.users where id = p_uid;
end $$;

create or replace function public.delete_account()
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  perform public.account_delete_of(uid);
end $$;

-- Oturumları kapat (Supabase: auth.sessions; yerel testte tablo yoksa atlanır)
create or replace function public.account_signout_of(p_uid uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if to_regclass('auth.sessions') is not null then
    execute 'delete from auth.sessions where user_id = $1' using p_uid;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. Uygulamaların okuduğu ayar: zorunlu güncelleme, bakım, duyuru, bayraklar
-- ---------------------------------------------------------------------
create or replace function public.flag_on(p_user uuid, p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select u.enabled from public.user_flags u
      where u.user_id = p_user and u.key = p_key and (u.expires_at is null or u.expires_at > now())),
    (select f.enabled and (f.rollout_pct = 100
                           or (p_user is not null and abs(hashtext(p_user::text || ':' || f.key)) % 100 < f.rollout_pct))
       from public.feature_flags f where f.key = p_key),
    false)
$$;

create or replace function public.client_config(p_app text)
returns json language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  return json_build_object(
    'app', coalesce((select value from public.app_config where key = 'app.' || p_app), '{}'::jsonb),
    'flags', coalesce((select json_object_agg(k.key, public.flag_on(uid, k.key))
                         from (select key from public.feature_flags
                               union select key from public.user_flags where user_id = uid) k), '{}'::json)
  );
end $$;

-- track_session: günlük etkinlik de yazılır (KPI)
create or replace function public.track_session(p_app text, p_platform text default null, p_version text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  insert into public.user_activity as a (user_id, app, sessions, active_days, platform, app_version)
  values (uid, p_app, 1, 1, nullif(p_platform, ''), left(nullif(p_version, ''), 30))
  on conflict (user_id, app) do update set
    sessions = a.sessions + case when a.last_seen_at < now() - interval '1 minute' then 1 else 0 end,
    active_days = a.active_days + case when a.last_active_date < current_date then 1 else 0 end,
    last_active_date = current_date,
    last_seen_at = now(),
    platform = coalesce(excluded.platform, a.platform),
    app_version = coalesce(excluded.app_version, a.app_version);
  insert into public.activity_days (user_id, app, day) values (uid, p_app, current_date) on conflict do nothing;
end $$;

-- ---------------------------------------------------------------------
-- 4. Okuma: ben, arama, kartlar, denetim kaydı
-- ---------------------------------------------------------------------
create or replace function public.admin_me()
returns json language sql stable security definer set search_path = '' as $$
  select case when r.role is null then null else
    json_build_object('role', r.role, 'mfa', coalesce(auth.jwt() ->> 'aal', '') = 'aal2') end
  from (select public.admin_role_of(auth.uid()) as role) r
$$;

create or replace function public.admin_search(p_q text, p_limit integer default 25)
returns table (kind text, user_id uuid, family_id uuid, clinic_id uuid, child_id uuid, label text, email text,
               created_at timestamptz, last_seen_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare
  q text := trim(coalesce(p_q, ''));
  pat text;
  v_id uuid;
  n integer := least(greatest(coalesce(p_limit, 25), 1), 100);
begin
  perform public.admin_require();
  if char_length(q) < 2 then return; end if;
  pat := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  if q ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then v_id := q::uuid; end if;
  return query
  with hits as (
    select public.account_kind(u.id) as kind, u.id as user_id, coalesce(p.family_id, c.family_id) as family_id,
           m.clinic_id, c.id as child_id,
           coalesce(nullif(m.name, ''), nullif(p.name, ''), p.nickname, c.name, u.email) as label, u.email,
           u.created_at, (select max(a.last_seen_at) from public.user_activity a where a.user_id = u.id) as last_seen_at
      from auth.users u
      left join public.profiles p on p.id = u.id
      left join public.clinicians m on m.id = u.id
      left join public.children c on c.user_id = u.id
     where u.id = v_id or u.email ilike pat or p.name ilike pat or p.nickname ilike pat or m.name ilike pat
        or p.family_id = v_id or c.family_id = v_id or m.clinic_id = v_id
    union all
    -- cihazı bağlanmamış çocuklar (hesapsız)
    select 'child', null, c.family_id, null, c.id, c.name, null, c.created_at, null
      from public.children c
     where c.user_id is null and (c.name ilike pat or c.id = v_id or c.family_id = v_id)
    union all
    select 'child', c.user_id, c.family_id, null, c.id, c.name, null, c.created_at,
           (select max(a.last_seen_at) from public.user_activity a where a.user_id = c.user_id)
      from public.children c
     where c.user_id is not null and (c.name ilike pat or c.id = v_id)
    union all
    select 'clinic', null, null, k.id, null, k.name, null, k.created_at, null
      from public.clinics k
     where k.name ilike pat or k.id = v_id
  )
  select distinct on (h.kind, h.user_id, h.child_id, h.clinic_id) h.*
    from hits h
   order by h.kind, h.user_id, h.child_id, h.clinic_id, h.last_seen_at desc nulls last
   limit n;
end $$;

create or replace function public.admin_audit_list(p_type text default null, p_target text default null, p_limit integer default 50)
returns setof public.admin_audit language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return query select * from public.admin_audit a
   where (p_type is null or a.target_type = p_type) and (p_target is null or a.target_id = p_target)
   order by a.at desc limit least(greatest(coalesce(p_limit, 50), 1), 500);
end $$;

create or replace function public.admin_user(p_user uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  u jsonb;
begin
  perform public.admin_require();
  select to_jsonb(x) into u from auth.users x where x.id = p_user;
  if u is null then return null; end if;
  return json_build_object(
    'account', jsonb_build_object('id', u -> 'id', 'email', u -> 'email', 'created_at', u -> 'created_at',
                                  'last_sign_in_at', u -> 'last_sign_in_at', 'email_confirmed_at', u -> 'email_confirmed_at',
                                  'is_anonymous', u -> 'is_anonymous', 'banned_until', u -> 'banned_until'),
    'kind', public.account_kind(p_user),
    'admin_role', public.admin_role_of(p_user),
    'profile', (select json_build_object('name', p.name, 'nickname', p.nickname, 'family_id', p.family_id)
                  from public.profiles p where p.id = p_user),
    'clinician', (select json_build_object('clinic_id', m.clinic_id, 'role', m.role, 'name', m.name, 'title', m.title)
                    from public.clinicians m where m.id = p_user),
    'child', (select json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'age_band', c.age_band)
                from public.children c where c.user_id = p_user),
    'activity', (select coalesce(json_agg(json_build_object('app', a.app, 'first_seen_at', a.first_seen_at,
                   'last_seen_at', a.last_seen_at, 'sessions', a.sessions, 'active_days', a.active_days,
                   'platform', a.platform, 'app_version', a.app_version)), '[]')
                   from public.user_activity a where a.user_id = p_user),
    'events', (select coalesce(json_agg(e order by e.occurred_at desc), '[]') from (
                 select ev.app, ev.event, ev.props, ev.occurred_at from public.app_events ev
                  where ev.user_id = p_user order by ev.occurred_at desc limit 50) e),
    'notifications', (select coalesce(json_agg(n order by n.created_at desc), '[]') from (
                 select x.app, x.kind, x.title, x.created_at, x.read_at, x.apns_sent_at from public.notifications x
                  where x.user_id = p_user order by x.created_at desc limit 20) n),
    'push_tokens', (select count(*) from public.push_tokens t where t.user_id = p_user),
    'flags', (select coalesce(json_agg(json_build_object('key', f.key, 'enabled', f.enabled, 'expires_at', f.expires_at,
                'reason', f.reason)), '[]') from public.user_flags f where f.user_id = p_user),
    'audit', (select coalesce(json_agg(a order by a.at desc), '[]') from (
                 select * from public.admin_audit x where x.target_type = 'user' and x.target_id = p_user::text
                  order by x.at desc limit 20) a)
  );
end $$;

create or replace function public.admin_family(p_family uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
declare f public.families%rowtype;
begin
  perform public.admin_require();
  select * into f from public.families where id = p_family;
  if not found then return null; end if;
  return json_build_object(
    'family', json_build_object('id', f.id, 'name', f.name, 'created_at', f.created_at, 'trial_started_at', f.trial_started_at),
    'access', public.family_access_of(f.id),
    'subscription', (select row_to_json(s) from public.family_subscriptions s where s.family_id = f.id),
    'parents', (select coalesce(json_agg(json_build_object('user_id', p.id, 'name', coalesce(nullif(p.name, ''), p.nickname),
                   'email', u.email, 'last_seen_at', (select max(a.last_seen_at) from public.user_activity a where a.user_id = p.id))), '[]')
                  from public.profiles p join auth.users u on u.id = p.id where p.family_id = f.id),
    'children', (select coalesce(json_agg(json_build_object('child_id', c.id, 'user_id', c.user_id, 'name', c.name,
                   'age_band', c.age_band, 'linked', c.user_id is not null,
                   'last_seen_at', (select a.last_seen_at from public.user_activity a where a.user_id = c.user_id and a.app = 'child'),
                   'save_updated_at', (select g.updated_at from public.game_saves g where g.child_id = c.id))), '[]')
                   from public.children c where c.family_id = f.id),
    'stats', json_build_object(
       'tasks', (select count(*) from public.tasks t where t.family_id = f.id),
       'approved_30d', (select count(*) from public.completions x where x.family_id = f.id and x.status = 'approved' and x.date > current_date - 30),
       'pending', (select count(*) from public.completions x where x.family_id = f.id and x.status = 'pending')),
    'clinic_links', (select coalesce(json_agg(json_build_object('clinic_id', l.clinic_id, 'clinic', k.name, 'status', l.status,
                       'consent_at', l.consent_at, 'revoked_at', l.revoked_at)), '[]')
                       from public.clinic_links l join public.clinics k on k.id = l.clinic_id where l.family_id = f.id),
    'audit', (select coalesce(json_agg(a order by a.at desc), '[]') from (
                 select * from public.admin_audit x where x.target_type = 'family' and x.target_id = f.id::text
                  order by x.at desc limit 20) a)
  );
end $$;

create or replace function public.admin_clinic(p_clinic uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
declare k jsonb;
begin
  perform public.admin_require();
  select to_jsonb(x) into k from public.clinics x where x.id = p_clinic;
  if k is null then return null; end if;
  return json_build_object(
    'clinic', k, 'active', public.clinic_active(p_clinic),
    'members', (select coalesce(json_agg(json_build_object('user_id', m.id, 'name', m.name, 'role', m.role, 'email', u.email,
                  'last_seen_at', (select a.last_seen_at from public.user_activity a where a.user_id = m.id and a.app = 'clinic'))), '[]')
                  from public.clinicians m join auth.users u on u.id = m.id where m.clinic_id = p_clinic),
    'links', json_build_object(
       'active', (select count(*) from public.clinic_links l where l.clinic_id = p_clinic and l.status = 'active'),
       'revoked', (select count(*) from public.clinic_links l where l.clinic_id = p_clinic and l.status = 'revoked')),
    'subscriptions', (select coalesce(json_agg(s order by s.updated_at desc), '[]') from (
                        select b.source, b.external_id, b.plan_id, b.status, b.period_end, b.auto_renew, b.updated_at
                          from public.billing_subscriptions b where b.clinic_id = p_clinic) s),
    'billing_events', (select coalesce(json_agg(e order by e.created_at desc), '[]') from (
                        select b.source, b.kind, b.external_id, b.created_at from public.billing_events b
                         where b.clinic_id = p_clinic order by b.created_at desc limit 20) e),
    'audit', (select coalesce(json_agg(a order by a.at desc), '[]') from (
                 select * from public.admin_audit x where x.target_type = 'clinic' and x.target_id = p_clinic::text
                  order by x.at desc limit 20) a)
  );
end $$;

-- ---------------------------------------------------------------------
-- 5. Kişiye özel işlemler (hepsi gerekçeli ve denetim kayıtlı)
-- ---------------------------------------------------------------------
-- Aileye elle premium (istisna). Etkin mağaza aboneliği varsa reddedilir (tek satır: mağazanınki ezilmez).
create or replace function public.admin_grant_premium(p_family uuid, p_until timestamptz, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['finance']);
  cur public.family_subscriptions%rowtype;
begin
  if not exists (select 1 from public.families where id = p_family) then raise exception 'Aile bulunamadı'; end if;
  if p_until is null or p_until <= now() or p_until > now() + interval '2 years' then
    raise exception 'Bitiş tarihi bugünden sonra ve en çok 2 yıl içinde olmalı';
  end if;
  select * into cur from public.family_subscriptions where family_id = p_family;
  if found and cur.source = 'store' and cur.plan = 'premium' and cur.status in ('active', 'grace', 'canceled')
     and (cur.period_end is null or cur.period_end > now()) then
    raise exception 'Ailenin etkin mağaza aboneliği var';
  end if;
  perform public.set_family_subscription(p_family, 'premium', null, 'active', p_until, false, null, null, 'manual');
  perform public.admin_log(me, 'family.premium_grant', 'family', p_family::text, p_reason,
                           case when cur.family_id is null then null else to_jsonb(cur) end,
                           jsonb_build_object('until', p_until));
  return public.family_access_of(p_family);
end $$;

create or replace function public.admin_revoke_premium(p_family uuid, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['finance']);
  cur public.family_subscriptions%rowtype;
begin
  select * into cur from public.family_subscriptions where family_id = p_family;
  if not found or cur.source <> 'manual' or cur.plan <> 'premium' or (cur.period_end is not null and cur.period_end <= now()) then
    raise exception 'Elle verilmiş premium yok';
  end if;
  perform public.set_family_subscription(p_family, 'free', null, 'expired', now(), false, null, null, 'manual');
  perform public.admin_log(me, 'family.premium_revoke', 'family', p_family::text, p_reason, to_jsonb(cur), null);
  return public.family_access_of(p_family);
end $$;

-- Ailenin denemesini N gün uzat (bitmişse bugünden itibaren N gün açılır)
create or replace function public.admin_extend_trial(p_family uuid, p_days integer, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support', 'finance']);
  days integer := (public.billing_config() ->> 'trial_days')::int;
  f public.families%rowtype;
  old_end timestamptz;
  new_end timestamptz;
begin
  if p_days is null or p_days not between 1 and 90 then raise exception 'Gün 1–90 arası olmalı'; end if;
  select * into f from public.families where id = p_family for update;
  if not found then raise exception 'Aile bulunamadı'; end if;
  old_end := f.trial_started_at + make_interval(days => days);
  new_end := greatest(coalesce(old_end, now()), now()) + make_interval(days => p_days);
  update public.families set trial_started_at = new_end - make_interval(days => days) where id = p_family;
  perform public.admin_log(me, 'family.trial_extend', 'family', p_family::text, p_reason,
                           jsonb_build_object('trial_ends_at', old_end), jsonb_build_object('trial_ends_at', new_end));
  return public.family_access_of(p_family);
end $$;

create or replace function public.admin_clinic_extend_trial(p_clinic uuid, p_days integer, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support', 'finance']);
  k public.clinics%rowtype;
begin
  if p_days is null or p_days not between 1 and 90 then raise exception 'Gün 1–90 arası olmalı'; end if;
  select * into k from public.clinics where id = p_clinic for update;
  if not found then raise exception 'Klinik bulunamadı'; end if;
  if k.plan <> 'trial' then raise exception 'Klinik denemede değil (%)', k.plan; end if;
  update public.clinics set trial_ends_at = greatest(trial_ends_at, now()) + make_interval(days => p_days) where id = p_clinic;
  perform public.admin_log(me, 'clinic.trial_extend', 'clinic', p_clinic::text, p_reason,
                           jsonb_build_object('trial_ends_at', k.trial_ends_at),
                           jsonb_build_object('trial_ends_at', greatest(k.trial_ends_at, now()) + make_interval(days => p_days)));
  return json_build_object('active', public.clinic_active(p_clinic));
end $$;

-- Kliniğe elle üyelik (pilot, istisna); kaldırma: elle verilenlerin hepsi bugün biter
create or replace function public.admin_clinic_grant(p_clinic uuid, p_plan_id text, p_until timestamptz, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['finance']);
  res json;
begin
  if p_until is null or p_until <= now() or p_until > now() + interval '2 years' then
    raise exception 'Bitiş tarihi bugünden sonra ve en çok 2 yıl içinde olmalı';
  end if;
  res := public.billing_apply('manual', 'admin:' || gen_random_uuid()::text, p_clinic, p_plan_id, 'active', p_until, false,
                              'PRODUCTION', jsonb_build_object('admin', me));
  perform public.admin_log(me, 'clinic.grant', 'clinic', p_clinic::text, p_reason, null,
                           jsonb_build_object('plan_id', p_plan_id, 'until', p_until));
  return res;
end $$;

create or replace function public.admin_clinic_revoke(p_clinic uuid, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['finance']);
  s record;
  n integer := 0;
begin
  for s in select external_id, plan_id from public.billing_subscriptions
            where clinic_id = p_clinic and source = 'manual' and status in ('active', 'canceled') loop
    perform public.billing_apply('manual', s.external_id, p_clinic, s.plan_id, 'expired', now(), false);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Elle verilmiş üyelik yok'; end if;
  perform public.admin_log(me, 'clinic.revoke', 'clinic', p_clinic::text, p_reason, jsonb_build_object('count', n), null);
  return json_build_object('revoked', n, 'active', public.clinic_active(p_clinic));
end $$;

-- Kişiye özel bildirim (uygulama içi + push; push-apns tetikleyicisi gönderir)
create or replace function public.admin_notify(p_user uuid, p_title text, p_body text, p_reason text, p_app text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  k text := public.account_kind(p_user);
  app text;
  nid bigint;
begin
  app := coalesce(p_app, case k when 'clinician' then 'clinic' when 'parent' then 'parent' when 'child' then 'child' end);
  if app is null or app not in ('parent', 'child', 'clinic') then raise exception 'Uygulama belirlenemedi'; end if;
  if char_length(trim(coalesce(p_title, ''))) not between 1 and 120 then raise exception 'Başlık 1–120 karakter'; end if;
  if char_length(coalesce(p_body, '')) > 300 then raise exception 'Metin en çok 300 karakter'; end if;
  insert into public.notifications (user_id, app, kind, title, body, data, family_id, child_id)
  values (p_user, app, 'admin_message', trim(p_title), coalesce(p_body, ''), '{"from": "admin"}'::jsonb,
          (select coalesce(p.family_id, c.family_id) from auth.users u
             left join public.profiles p on p.id = u.id left join public.children c on c.user_id = u.id where u.id = p_user),
          (select c.id from public.children c where c.user_id = p_user))
  returning id into nid;
  perform public.admin_log(me, 'user.notify', 'user', p_user::text, p_reason, null,
                           jsonb_build_object('notification_id', nid, 'app', app, 'title', trim(p_title)));
  return nid;
end $$;

create or replace function public.admin_set_user_flag(p_user uuid, p_key text, p_enabled boolean, p_until timestamptz, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  old jsonb;
begin
  if not exists (select 1 from auth.users where id = p_user) then raise exception 'Kullanıcı bulunamadı'; end if;
  select to_jsonb(f) into old from public.user_flags f where f.user_id = p_user and f.key = p_key;
  if p_enabled is null then
    delete from public.user_flags where user_id = p_user and key = p_key;
  else
    insert into public.user_flags (user_id, key, enabled, expires_at, reason, created_by)
    values (p_user, p_key, p_enabled, p_until, left(trim(p_reason), 500), me)
    on conflict (user_id, key) do update set enabled = excluded.enabled, expires_at = excluded.expires_at,
      reason = excluded.reason, created_by = excluded.created_by, created_at = now();
  end if;
  perform public.admin_log(me, 'user.flag', 'user', p_user::text, p_reason, old,
                           jsonb_build_object('key', p_key, 'enabled', p_enabled, 'until', p_until));
end $$;

create or replace function public.admin_signout(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['support']);
begin
  perform public.account_signout_of(p_user);
  perform public.admin_log(me, 'user.signout', 'user', p_user::text, p_reason);
end $$;

-- Panelin istemciden yaptığı işlemlerin kaydı (ör. şifre sıfırlama e-postası gönderildi)
create or replace function public.admin_log_client(p_action text, p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['support']);
begin
  if p_action not in ('user.password_reset_email') then raise exception 'Geçersiz işlem'; end if;
  perform public.admin_log(me, p_action, 'user', p_user::text, p_reason);
end $$;

-- Askıya al / aç: giriş ve oturum yenileme kapanır (Supabase auth.users.banned_until), oturumlar kapanır
create or replace function public.admin_suspend(p_user uuid, p_until timestamptz, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  until_ts timestamptz := coalesce(p_until, now() + interval '100 years');
begin
  if p_user = me then raise exception 'Kendini askıya alamazsın'; end if;
  if public.admin_role_of(p_user) is not null then raise exception 'Önce admin yetkisini kaldır'; end if;
  if until_ts <= now() then raise exception 'Bitiş geçmişte olamaz'; end if;
  update auth.users set banned_until = until_ts where id = p_user;
  if not found then raise exception 'Kullanıcı bulunamadı'; end if;
  perform public.account_signout_of(p_user);
  perform public.admin_log(me, 'user.suspend', 'user', p_user::text, p_reason, null, jsonb_build_object('until', until_ts));
end $$;

create or replace function public.admin_unsuspend(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['owner']);
begin
  update auth.users set banned_until = null where id = p_user;
  if not found then raise exception 'Kullanıcı bulunamadı'; end if;
  perform public.admin_log(me, 'user.unsuspend', 'user', p_user::text, p_reason);
end $$;

-- Hesabı sil (KVKK silme talebi ya da kural ihlali). Geri alınamaz.
create or replace function public.admin_delete_user(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  snap jsonb;
begin
  if p_user = me then raise exception 'Kendi hesabını panelden silemezsin'; end if;
  if public.admin_role_of(p_user) is not null then raise exception 'Önce admin yetkisini kaldır'; end if;
  select jsonb_build_object('kind', public.account_kind(p_user), 'created_at', u.created_at) into snap
    from auth.users u where u.id = p_user;
  if snap is null then raise exception 'Kullanıcı bulunamadı'; end if;
  perform public.admin_log(me, 'user.delete', 'user', p_user::text, p_reason, snap, null);   -- e-posta kayda yazılmaz
  perform public.account_delete_of(p_user);
end $$;

-- ---------------------------------------------------------------------
-- 6. Genel ayarlar (yalnız owner)
-- ---------------------------------------------------------------------
create or replace function public.admin_set_flag(p_key text, p_enabled boolean, p_rollout integer, p_description text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  old jsonb;
begin
  select to_jsonb(f) into old from public.feature_flags f where f.key = p_key;
  insert into public.feature_flags (key, enabled, rollout_pct, description, updated_at)
  values (p_key, coalesce(p_enabled, false), coalesce(p_rollout, 100), coalesce(p_description, ''), now())
  on conflict (key) do update set enabled = excluded.enabled, rollout_pct = excluded.rollout_pct,
    description = case when p_description is null then public.feature_flags.description else excluded.description end,
    updated_at = now();
  perform public.admin_log(me, 'flag.set', 'flag', p_key, p_reason, old,
                           jsonb_build_object('enabled', p_enabled, 'rollout_pct', p_rollout));
end $$;

create or replace function public.admin_flags()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return json_build_object(
    'flags', (select coalesce(json_agg(f order by f.key), '[]') from public.feature_flags f),
    'user_overrides', (select count(*) from public.user_flags u where u.expires_at is null or u.expires_at > now()));
end $$;

-- Uygulama ayarı: en düşük sürüm (zorunlu güncelleme), bakım modu, duyuru bandı
create or replace function public.admin_set_app_config(p_app text, p_min_version text, p_maintenance boolean, p_banner text, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  old jsonb;
  val jsonb;
begin
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  if p_min_version is not null and p_min_version !~ '^[0-9]+(\.[0-9]+){0,2}$' then raise exception 'Sürüm biçimi 1.2.3'; end if;
  if char_length(coalesce(p_banner, '')) > 200 then raise exception 'Duyuru en çok 200 karakter'; end if;
  select value into old from public.app_config where key = 'app.' || p_app;
  val := jsonb_strip_nulls(jsonb_build_object('min_version', p_min_version, 'maintenance', coalesce(p_maintenance, false),
                                              'banner', nullif(trim(coalesce(p_banner, '')), '')));
  insert into public.app_config (key, value) values ('app.' || p_app, val)
  on conflict (key) do update set value = excluded.value;
  perform public.admin_log(me, 'config.app', 'config', 'app.' || p_app, p_reason, old, val);
  return val::json;
end $$;

create or replace function public.admin_app_config()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return (select coalesce(json_object_agg(key, value), '{}') from public.app_config where key like 'app.%' or key in ('billing', 'kpi'));
end $$;

create or replace function public.admin_set_kpi_config(p_value jsonb, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner', 'finance']);
  old jsonb;
begin
  if jsonb_typeof(p_value) <> 'object' then raise exception 'Nesne olmalı'; end if;
  select value into old from public.app_config where key = 'kpi';
  update public.app_config set value = coalesce(old, '{}'::jsonb) || p_value where key = 'kpi';
  perform public.admin_log(me, 'config.kpi', 'config', 'kpi', p_reason, old, p_value);
end $$;

-- Admin listesi ve yetki verme (yalnız owner; son owner düşürülemez)
create or replace function public.admin_list_admins()
returns table (user_id uuid, email text, role text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require(array['owner']);
  return query select a.user_id, u.email::text, a.role, a.created_at
                 from public.admin_users a join auth.users u on u.id = a.user_id order by a.created_at;
end $$;

create or replace function public.admin_set_admin(p_email text, p_role text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  target uuid;
  old text;
begin
  select id into target from auth.users where lower(email) = lower(trim(p_email)) and not is_anonymous;
  if target is null then raise exception 'Bu e-postayla hesap yok'; end if;
  old := public.admin_role_of(target);
  if old = 'owner' and coalesce(p_role, '') <> 'owner'
     and (select count(*) from public.admin_users where role = 'owner') <= 1 then
    raise exception 'Son owner kaldırılamaz';
  end if;
  if p_role is null then
    delete from public.admin_users where user_id = target;
  else
    if p_role not in ('owner', 'finance', 'support', 'viewer') then raise exception 'Geçersiz rol'; end if;
    insert into public.admin_users (user_id, role, created_by) values (target, p_role, me)
    on conflict (user_id) do update set role = excluded.role;
  end if;
  perform public.admin_log(me, 'admin.set', 'admin', target::text, p_reason,
                           jsonb_build_object('role', old), jsonb_build_object('role', p_role));
end $$;

-- ---------------------------------------------------------------------
-- 7. KPI (okuma; her admin rolü)
-- ---------------------------------------------------------------------
-- Özet: kullanıcılar, aktiflik, yeni kayıt, gelir tahmini, deneme→ücretli, kayıp, etkileşim, klinik
create or replace function public.admin_kpi_summary(p_days integer default 30)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  d integer := least(greatest(coalesce(p_days, 30), 1), 365);
  since timestamptz := now() - make_interval(days => d);
  cfg jsonb := coalesce((select value from public.app_config where key = 'kpi'), '{}'::jsonb);
  bcfg jsonb := public.billing_config();
  fee numeric := 1 - coalesce((cfg ->> 'store_fee_pct')::numeric, 15) / 100;
  rc numeric := 1 - coalesce((cfg ->> 'revenuecat_pct')::numeric, 1) / 100;
  pm integer; py integer; mrr_parent numeric; mrr_clinic numeric;
  trial_ended integer; trial_paid integer;
begin
  perform public.admin_require();
  select count(*) filter (where billing = 'monthly'), count(*) filter (where billing = 'yearly') into pm, py
    from public.family_subscriptions
   where source = 'store' and plan = 'premium' and status in ('active', 'grace', 'canceled') and (period_end is null or period_end > now());
  mrr_parent := pm * coalesce((cfg ->> 'parent_monthly_try')::numeric, 0) + py * coalesce((cfg ->> 'parent_yearly_try')::numeric, 0) / 12;
  select coalesce(sum(case when p.period = 'monthly' then p.price_try else p.price_try / 12 end), 0) into mrr_clinic
    from public.billing_subscriptions s join public.billing_plans p on p.id = s.plan_id
   where s.source <> 'manual' and s.status in ('active', 'canceled') and s.period_end > now();
  -- Denemesi son d günde biten aileler ve bunlardan bugün mağaza premium olanlar
  select count(*), count(*) filter (where exists (select 1 from public.family_subscriptions s where s.family_id = f.id
                                                    and s.source = 'store' and s.plan = 'premium'))
    into trial_ended, trial_paid
    from public.families f
   where f.trial_started_at is not null
     and f.trial_started_at + make_interval(days => (bcfg ->> 'trial_days')::int) between since and now();

  return json_build_object(
    'days', d,
    'totals', json_build_object(
      'families', (select count(*) from public.families),
      'parents', (select count(*) from public.profiles),
      'children', (select count(*) from public.children),
      'children_linked', (select count(*) from public.children where user_id is not null),
      'clinics', (select count(*) from public.clinics),
      'clinicians', (select count(*) from public.clinicians)),
    'active', (select coalesce(json_object_agg(x.app, json_build_object('dau', x.dau, 'wau', x.wau, 'mau', x.mau,
                 'stickiness', case when x.mau > 0 then round(x.dau::numeric / x.mau, 3) end)), '{}')
                 from (select a.app,
                              count(distinct a.user_id) filter (where a.day = current_date) as dau,
                              count(distinct a.user_id) filter (where a.day > current_date - 7) as wau,
                              count(distinct a.user_id) filter (where a.day > current_date - 30) as mau
                         from public.activity_days a where a.day > current_date - 30 group by a.app) x),
    'new', json_build_object(
      'families', (select count(*) from public.families where created_at >= since),
      'children_linked', (select count(*) from public.user_activity where app = 'child' and first_seen_at >= since),
      'clinics', (select count(*) from public.clinics where created_at >= since),
      'clinicians', (select count(*) from public.clinicians where created_at >= since)),
    'revenue', json_build_object(
      'parent_monthly', pm, 'parent_yearly', py,
      'parent_manual', (select count(*) from public.family_subscriptions where source = 'manual' and plan = 'premium'
                          and (period_end is null or period_end > now())),
      'clinic_paid', (select count(distinct s.clinic_id) from public.billing_subscriptions s
                        where s.source <> 'manual' and s.status in ('active', 'canceled') and s.period_end > now()),
      'clinic_manual', (select count(distinct s.clinic_id) from public.billing_subscriptions s
                          where s.source = 'manual' and s.status in ('active', 'canceled') and s.period_end > now()),
      'clinic_trial', (select count(*) from public.clinics where plan = 'trial' and trial_ends_at > now()),
      'mrr_gross_try', round(mrr_parent + mrr_clinic, 2),
      'mrr_net_try', round((mrr_parent + mrr_clinic) * fee * rc, 2),
      'parent_prices_set', coalesce((cfg ->> 'parent_monthly_try')::numeric, 0) > 0),
    'trial', json_build_object(
      'families_in_trial', (select count(*) from public.families f where f.trial_started_at is not null
                              and f.trial_started_at + make_interval(days => (bcfg ->> 'trial_days')::int) > now()),
      'ended', trial_ended, 'converted', trial_paid,
      'conversion', case when trial_ended > 0 then round(trial_paid::numeric / trial_ended, 3) end),
    'churn', json_build_object(
      'parent', (select count(*) from public.family_subscriptions where source = 'store' and status in ('expired', 'refunded')
                   and updated_at >= since),
      'parent_refunds', (select count(*) from public.family_subscriptions where source = 'store' and status = 'refunded'
                           and updated_at >= since),
      'clinic', (select count(distinct clinic_id) from public.billing_events where kind in ('apply:expired', 'apply:refunded')
                   and source <> 'manual' and created_at >= since)),
    'engagement', json_build_object(
      'tasks_created', (select count(*) from public.tasks where created_at >= since),
      'completions', (select count(*) from public.completions where created_at >= since),
      'approved', (select count(*) from public.completions where created_at >= since and status = 'approved'),
      'approval_rate', (select case when count(*) > 0 then round(count(*) filter (where status = 'approved')::numeric / count(*), 3) end
                          from public.completions where created_at >= since),
      'median_review_minutes', (select round((percentile_cont(0.5) within group (
                                   order by extract(epoch from reviewed_at - coalesce(child_done_at, created_at)) / 60))::numeric, 1)
                                  from public.completions where reviewed_at is not null and created_at >= since),
      'active_children', (select count(distinct user_id) from public.activity_days where app = 'child' and day >= since::date),
      'notifications_read_rate', (select case when count(*) > 0 then round(count(read_at)::numeric / count(*), 3) end
                                    from public.notifications where created_at >= since),
      'push_users', (select count(distinct user_id) from public.push_tokens)),
    'clinic', json_build_object(
      'active_links', (select count(*) from public.clinic_links where status = 'active'),
      'clinics_with_clients', (select count(distinct clinic_id) from public.clinic_links where status = 'active'),
      'suggestions', (select count(*) from public.clinic_task_suggestions where created_at >= since),
      'notes', (select count(*) from public.clinic_notes where created_at >= since),
      'consent_revoked', (select count(*) from public.clinic_links where revoked_at >= since))
  );
end $$;

-- Günlük seri (grafik): uygulama başına aktif ve yeni kullanıcı
create or replace function public.admin_kpi_daily(p_from date, p_to date)
returns table (day date, app text, active_users bigint, new_users bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then raise exception 'Tarih aralığı en çok 1 yıl'; end if;
  return query
  select g.day::date, x.app,
         (select count(*) from public.activity_days a where a.day = g.day::date and a.app = x.app),
         (select count(*) from public.user_activity u where u.first_seen_at::date = g.day::date and u.app = x.app)
    from generate_series(p_from, p_to, interval '1 day') g(day)
   cross join (values ('parent'), ('child'), ('clinic')) x(app)
   order by 1, 2;
end $$;

-- Elde tutma: ilk görülme haftasına göre kohortlar; G1/G7/G30 = o gün yeniden aktif olanların oranı
create or replace function public.admin_kpi_retention(p_weeks integer default 8)
returns table (app text, cohort_week date, users bigint, d1 numeric, d7 numeric, d30 numeric)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return query
  with c as (
    select u.app, u.user_id, u.first_seen_at::date as d0, date_trunc('week', u.first_seen_at)::date as wk
      from public.user_activity u
     where u.first_seen_at >= date_trunc('week', now()) - make_interval(weeks => least(greatest(coalesce(p_weeks, 8), 1), 52))
  )
  select c.app, c.wk, count(*),
         case when max(c.d0) + 1 < current_date then round(avg((exists (select 1 from public.activity_days a
              where a.user_id = c.user_id and a.app = c.app and a.day = c.d0 + 1))::int), 3) end,
         case when max(c.d0) + 7 < current_date then round(avg((exists (select 1 from public.activity_days a
              where a.user_id = c.user_id and a.app = c.app and a.day = c.d0 + 7))::int), 3) end,
         case when max(c.d0) + 30 < current_date then round(avg((exists (select 1 from public.activity_days a
              where a.user_id = c.user_id and a.app = c.app and a.day = c.d0 + 30))::int), 3) end
    from c group by c.app, c.wk order by c.app, c.wk;
end $$;

-- Huniler: kullanıcı nerede bırakıyor (kohort: aralıkta açılan aile / eklenen çocuk / açılan klinik)
create or replace function public.admin_kpi_funnel(p_app text, p_from date, p_to date)
returns table (step integer, name text, count bigint)
language plpgsql stable security definer set search_path = '' as $$
declare a timestamptz := p_from; b timestamptz := p_to + 1;
begin
  perform public.admin_require();
  if p_from is null or p_to is null or p_to < p_from then raise exception 'Tarih aralığı geçersiz'; end if;
  if p_app = 'parent' then
    return query
    with f as (select * from public.families where created_at >= a and created_at < b)
    select * from (values
      (1, 'Kayıt (aile açıldı)', (select count(*) from f)),
      (2, 'E-posta onaylandı (deneme başladı)', (select count(*) from f where trial_started_at is not null)),
      (3, 'Çocuk eklendi', (select count(*) from f where exists (select 1 from public.children c where c.family_id = f.id))),
      (4, 'Çocuk cihazı bağlandı', (select count(*) from f where exists (select 1 from public.children c where c.family_id = f.id and c.user_id is not null))),
      (5, 'İlk görev', (select count(*) from f where exists (select 1 from public.tasks t where t.family_id = f.id))),
      (6, 'İlk onay', (select count(*) from f where exists (select 1 from public.completions x where x.family_id = f.id and x.status = 'approved'))),
      (7, 'Ücretli (mağaza)', (select count(*) from f where exists (select 1 from public.family_subscriptions s where s.family_id = f.id
                                                                       and s.source = 'store' and s.plan = 'premium')))
    ) v(step, name, count);
  elsif p_app = 'child' then
    return query
    with c as (select * from public.children where created_at >= a and created_at < b)
    select * from (values
      (1, 'Çocuk eklendi', (select count(*) from c)),
      (2, 'Cihaz bağlandı', (select count(*) from c where c.user_id is not null)),
      (3, 'Oyunu açtı', (select count(*) from c where exists (select 1 from public.user_activity u where u.user_id = c.user_id and u.app = 'child'))),
      (4, 'İlk "Yaptım"', (select count(*) from c where exists (select 1 from public.completions x where x.child_id = c.id))),
      (5, 'İlk onay', (select count(*) from c where exists (select 1 from public.completions x where x.child_id = c.id and x.status = 'approved'))),
      (6, '7. gün yeniden aktif', (select count(*) from c where exists (
            select 1 from public.user_activity u join public.activity_days d on d.user_id = u.user_id and d.app = 'child'
             where u.user_id = c.user_id and u.app = 'child' and d.day >= u.first_seen_at::date + 7)))
    ) v(step, name, count);
  elsif p_app = 'clinic' then
    return query
    with k as (select * from public.clinics where created_at >= a and created_at < b)
    select * from (values
      (1, 'Klinik açıldı', (select count(*) from k)),
      (2, 'İlk aile bağlandı', (select count(*) from k where exists (select 1 from public.clinic_links l where l.clinic_id = k.id))),
      (3, 'İlk öneri', (select count(*) from k where exists (select 1 from public.clinic_task_suggestions s where s.clinic_id = k.id))),
      (4, 'İlk not', (select count(*) from k where exists (select 1 from public.clinic_notes n where n.clinic_id = k.id))),
      (5, 'Ücretli', (select count(*) from k where exists (select 1 from public.billing_subscriptions s where s.clinic_id = k.id and s.source <> 'manual')))
    ) v(step, name, count);
  else
    raise exception 'Geçersiz uygulama';
  end if;
end $$;

-- En çok kullanılan olaylar (ekran/özellik kullanımı)
create or replace function public.admin_kpi_events(p_app text, p_days integer default 30, p_limit integer default 30)
returns table (event text, events bigint, users bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return query
  select e.event, count(*), count(distinct e.user_id) from public.app_events e
   where e.app = p_app and e.occurred_at >= now() - make_interval(days => least(greatest(coalesce(p_days, 30), 1), 365))
   group by e.event order by 2 desc limit least(greatest(coalesce(p_limit, 30), 1), 200);
end $$;

-- ---------------------------------------------------------------------
-- 8. Yetkiler
-- ---------------------------------------------------------------------
do $$
declare fn text;
begin
  -- iç yardımcılar: istemciye kapalı
  foreach fn in array array[
    'public.admin_role_of(uuid)', 'public.admin_require(text[])',
    'public.admin_log(uuid, text, text, text, text, jsonb, jsonb)', 'public.account_kind(uuid)',
    'public.account_delete_of(uuid)', 'public.account_signout_of(uuid)', 'public.flag_on(uuid, text)'] loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn);
  end loop;
  -- panel ve uygulamalar: giriş yapmış kullanıcı (admin denetimi fonksiyonun içinde)
  foreach fn in array array[
    'public.client_config(text)', 'public.track_session(text, text, text)', 'public.delete_account()',
    'public.admin_me()', 'public.admin_search(text, integer)', 'public.admin_audit_list(text, text, integer)',
    'public.admin_user(uuid)', 'public.admin_family(uuid)', 'public.admin_clinic(uuid)',
    'public.admin_grant_premium(uuid, timestamptz, text)', 'public.admin_revoke_premium(uuid, text)',
    'public.admin_extend_trial(uuid, integer, text)', 'public.admin_clinic_extend_trial(uuid, integer, text)',
    'public.admin_clinic_grant(uuid, text, timestamptz, text)', 'public.admin_clinic_revoke(uuid, text)',
    'public.admin_notify(uuid, text, text, text, text)', 'public.admin_set_user_flag(uuid, text, boolean, timestamptz, text)',
    'public.admin_signout(uuid, text)', 'public.admin_log_client(text, uuid, text)',
    'public.admin_suspend(uuid, timestamptz, text)', 'public.admin_unsuspend(uuid, text)', 'public.admin_delete_user(uuid, text)',
    'public.admin_set_flag(text, boolean, integer, text, text)', 'public.admin_flags()',
    'public.admin_set_app_config(text, text, boolean, text, text)', 'public.admin_app_config()',
    'public.admin_set_kpi_config(jsonb, text)', 'public.admin_list_admins()', 'public.admin_set_admin(text, text, text)',
    'public.admin_kpi_summary(integer)', 'public.admin_kpi_daily(date, date)', 'public.admin_kpi_retention(integer)',
    'public.admin_kpi_funnel(text, date, date)', 'public.admin_kpi_events(text, integer, integer)'] loop
    execute format('revoke execute on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end $$;
