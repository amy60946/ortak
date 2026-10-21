-- =====================================================================
-- Klinik ekibi + kullanıcı kaydı/takibi (öneri, 21 Ekim 2026)
--   1. clinician_me: davet eden uzmanın ve klinik sahibinin adı da döner (ekip üyesi profilinde görünür).
--   2. clinic_join_team(kod): giriş yapmış uzman ekip koduyla kliniğe katılır. Yanlışlıkla "Yeni klinik" açmış biri
--      için: eski kliniği boşsa (başka uzman, paylaşım, not, hedef yok) silinir; doluysa katılım reddedilir.
--   3. Kullanıcı takibi (birinci taraf; üçüncü taraf analitik SDK'si yok):
--        user_activity : kullanıcı × uygulama başına ilk/son görülme, sürüm, platform, oturum ve aktif gün sayısı
--        app_events    : uygulama olayları (ekran açıldı, rapor yazdırıldı …). Kişisel veri/serbest metin yazılmaz.
--      İstemci yalnız track_session / track_events RPC'leriyle yazar; tabloları OKUYAMAZ.
--   4. analytics şeması: iş için özet görünümler (hesaplar, günlük aktif, kayıtlar, klinik/aile özeti).
--      API'ye açık değildir (anon/authenticated erişemez); Supabase SQL Editor'den okunur.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Uzmanın kendi bilgisi (+ davet eden, klinik sahibi)
-- ---------------------------------------------------------------------
create or replace function public.clinician_me()
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'id', m.id, 'name', m.name, 'title', m.title, 'role', m.role,
    'clinic_id', c.id, 'clinic', c.name, 'plan', c.plan, 'seat_limit', c.seat_limit,
    'trial_ends_at', c.trial_ends_at, 'active', public.clinic_active(c.id),
    'joined_at', m.created_at,
    'owner_name', (select o.name from public.clinicians o where o.clinic_id = c.id and o.role = 'owner' order by o.created_at limit 1),
    'invited_by_name', (select i.name from public.clinic_invites v join public.clinicians i on i.id = v.clinician_id
                         where v.used_by = m.id and v.kind = 'clinician' and v.clinic_id = c.id
                         order by v.used_at desc limit 1))
  from public.clinicians m join public.clinics c on c.id = m.clinic_id
  where m.id = auth.uid()
$$;

-- ---------------------------------------------------------------------
-- 2. Giriş yapmış uzman ekip koduyla katılır
-- ---------------------------------------------------------------------
create or replace function public.clinic_join_team(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  me public.clinicians%rowtype;
  inv public.clinic_invites%rowtype;
  old_clinic uuid;
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  select * into me from public.clinicians where id = uid;
  if not found then raise exception 'Yalnızca uzman hesabı ekibe katılabilir'; end if;

  select * into inv from public.clinic_invites
    where code = upper(trim(p_code)) and kind = 'clinician' and used_at is null and expires_at > now()
    for update;
  if not found then raise exception 'Ekip kodu geçersiz ya da süresi dolmuş'; end if;
  if inv.clinic_id = me.clinic_id then raise exception 'Zaten bu kliniğin ekibindesin'; end if;
  if (select count(*) from public.clinicians where clinic_id = inv.clinic_id)
     >= (select seat_limit from public.clinics where id = inv.clinic_id) then
    raise exception 'Kliniğin uzman koltuğu dolu';
  end if;

  old_clinic := me.clinic_id;
  -- Eski klinikte veri varsa taşınmaz, silinmez: katılım durur
  if exists (select 1 from public.clinicians where clinic_id = old_clinic and id <> uid)
     or exists (select 1 from public.clinic_links where clinic_id = old_clinic)
     or exists (select 1 from public.clinic_notes where clinic_id = old_clinic)
     or exists (select 1 from public.clinic_goals where clinic_id = old_clinic) then
    raise exception 'Mevcut kliniğinde danışan, not ya da başka uzman var; katılırsan kaybolur. Başka bir e-postayla kayıt olup ekip koduyla katıl.';
  end if;

  update public.clinicians set clinic_id = inv.clinic_id, role = 'member' where id = uid;
  update public.clinic_invites set used_at = now(), used_by = uid where code = inv.code;
  delete from public.clinic_invites where clinic_id = old_clinic;
  delete from public.clinics where id = old_clinic;
  return json_build_object('clinic_id', inv.clinic_id);
end $$;

-- Ekibe sonradan katılan da (UPDATE) sahibe bildirilsin; kayıtla katılma (INSERT) zaten bildiriliyor
create or replace function public.clinicians_notify_move() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if new.clinic_id is distinct from old.clinic_id and new.role = 'member' then
    for r in select id from public.clinicians where clinic_id = new.clinic_id and role = 'owner' loop
      perform public.notify(r.id, 'clinic', 'team_joined', coalesce(nullif(new.name, ''), 'Yeni uzman') || ' ekibe katıldı', '',
        jsonb_build_object('clinician_id', new.id));
    end loop;
  end if;
  return null;
end $$;
drop trigger if exists clinicians_notify_move on public.clinicians;
create trigger clinicians_notify_move after update of clinic_id on public.clinicians
  for each row execute function public.clinicians_notify_move();

-- ---------------------------------------------------------------------
-- 3. Kullanıcı takibi
-- ---------------------------------------------------------------------
create table if not exists public.user_activity (
  user_id          uuid not null references auth.users (id) on delete cascade,
  app              text not null check (app in ('parent', 'child', 'clinic')),
  first_seen_at    timestamptz not null default now(),
  last_seen_at     timestamptz not null default now(),
  last_active_date date not null default current_date,
  sessions         integer not null default 0,
  active_days      integer not null default 0,
  platform         text check (platform in ('ios', 'android', 'web')),
  app_version      text check (char_length(app_version) <= 30),
  primary key (user_id, app)
);
create index if not exists user_activity_seen_idx on public.user_activity (app, last_seen_at desc);
alter table public.user_activity enable row level security;   -- politika yok: istemci okuyamaz/yazamaz
revoke all on public.user_activity from anon, authenticated;

create table if not exists public.app_events (
  id          bigserial primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  app         text not null check (app in ('parent', 'child', 'clinic')),
  event       text not null check (event ~ '^[a-z][a-z0-9_.]{1,59}$'),
  props       jsonb not null default '{}' check (jsonb_typeof(props) = 'object' and length(props::text) <= 1000),
  session_id  uuid,
  platform    text check (platform in ('ios', 'android', 'web')),
  app_version text check (char_length(app_version) <= 30),
  occurred_at timestamptz not null default now(),
  created_at  timestamptz not null default now()
);
create index if not exists app_events_user_idx on public.app_events (user_id, created_at desc);
create index if not exists app_events_event_idx on public.app_events (app, event, created_at desc);
alter table public.app_events enable row level security;      -- politika yok
revoke all on public.app_events from anon, authenticated;
revoke all on sequence public.app_events_id_seq from anon, authenticated;

-- Uygulama açılışında / öne gelişinde (en çok dakikada bir sayılır)
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
end $$;

-- Olaylar toplu gelir: [{"event": "screen.client", "props": {...}, "at": "...", "session_id": "..."}], en çok 50.
-- Kullanıcı başına günde en çok 2000 olay saklanır; fazlası sessizce atlanır. Dönen: yazılan olay sayısı.
create or replace function public.track_events(p_app text, p_events jsonb, p_platform text default null, p_version text default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  room integer;
  n integer;
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 50 then
    raise exception 'En çok 50 olaylık dizi gönder';
  end if;
  room := 2000 - (select count(*) from public.app_events where user_id = uid and created_at >= current_date);
  if room <= 0 then return 0; end if;
  insert into public.app_events (user_id, app, event, props, session_id, platform, app_version, occurred_at)
  select uid, p_app, e ->> 'event',
         case when jsonb_typeof(e -> 'props') = 'object' then e -> 'props' else '{}'::jsonb end,
         case when (e ->> 'session_id') ~ '^[0-9a-f-]{36}$' then (e ->> 'session_id')::uuid end,
         nullif(p_platform, ''), left(nullif(p_version, ''), 30),
         -- istemci saati en çok 2 gün geriye / 5 dk ileriye kabul edilir
         least(now() + interval '5 minutes', greatest(now() - interval '2 days',
           coalesce(case when (e ->> 'at') ~ '^\d{4}-\d{2}-\d{2}T' then (e ->> 'at')::timestamptz end, now())))
    from jsonb_array_elements(p_events) e
   limit room;
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function public.clinician_me() from public, anon;
revoke execute on function public.clinic_join_team(text) from public, anon;
revoke execute on function public.clinicians_notify_move() from public, anon, authenticated;
revoke execute on function public.track_session(text, text, text) from public, anon;
revoke execute on function public.track_events(text, jsonb, text, text) from public, anon;
grant execute on function public.clinician_me() to authenticated;
grant execute on function public.clinic_join_team(text) to authenticated;
grant execute on function public.track_session(text, text, text) to authenticated;
grant execute on function public.track_events(text, jsonb, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. İş görünümleri (yalnız SQL Editor / service_role)
-- ---------------------------------------------------------------------
create schema if not exists analytics;
revoke all on schema analytics from public, anon, authenticated;

-- Bütün hesaplar: tür, aile/klinik, kayıt ve son görülme
create or replace view analytics.accounts as
select u.id as user_id,
       u.email,
       u.created_at as signed_up_at,
       u.last_sign_in_at,
       case when m.id is not null then 'clinician'
            when p.id is not null then 'parent'
            when c.id is not null then 'child'
            else 'other' end as kind,
       coalesce(p.family_id, c.family_id) as family_id,
       m.clinic_id, m.role as clinic_role,
       (select max(a.last_seen_at) from public.user_activity a where a.user_id = u.id) as last_seen_at,
       (select string_agg(a.app || ':' || coalesce(a.app_version, '?'), ', ') from public.user_activity a where a.user_id = u.id) as apps
  from auth.users u
  left join public.clinicians m on m.id = u.id
  left join public.profiles p on p.id = u.id
  left join public.children c on c.user_id = u.id;

-- Günlük kayıt sayısı (tür bazında)
create or replace view analytics.signups_daily as
select date_trunc('day', signed_up_at)::date as day, kind, count(*) as signups
  from analytics.accounts group by 1, 2;

-- Günlük aktif kullanıcı (olay ya da oturum)
create or replace view analytics.daily_active as
select day, app, count(distinct user_id) as active_users
  from (select created_at::date as day, app, user_id from public.app_events
        union all
        select last_active_date, app, user_id from public.user_activity) x
 group by 1, 2;

-- Olay sayıları
create or replace view analytics.events_daily as
select created_at::date as day, app, event, count(*) as events, count(distinct user_id) as users
  from public.app_events group by 1, 2, 3;

-- Klinik özeti: plan, uzman, etkin danışan, son 30 gün öneri/not, son görülme
create or replace view analytics.clinics_overview as
select k.id as clinic_id, k.name, k.plan, k.trial_ends_at, k.created_at,
       (select count(*) from public.clinicians m where m.clinic_id = k.id) as clinicians,
       (select count(*) from public.clinic_links l where l.clinic_id = k.id and l.status = 'active') as active_clients,
       (select count(*) from public.clinic_links l where l.clinic_id = k.id and l.status = 'revoked') as revoked_clients,
       (select count(*) from public.clinic_task_suggestions s where s.clinic_id = k.id and s.created_at > now() - interval '30 days') as suggestions_30d,
       (select count(*) from public.clinic_notes n where n.clinic_id = k.id and n.created_at > now() - interval '30 days') as notes_30d,
       (select max(a.last_seen_at) from public.user_activity a join public.clinicians m on m.id = a.user_id where m.clinic_id = k.id) as last_seen_at
  from public.clinics k;

-- Aile özeti: ebeveyn, çocuk, bağlı cihaz, görev, son 30 gün tamamlama, uzman bağlantısı, premium
create or replace view analytics.families_overview as
select f.id as family_id, f.created_at,
       (select count(*) from public.profiles p where p.family_id = f.id) as parents,
       (select count(*) from public.children c where c.family_id = f.id) as children,
       (select count(*) from public.children c where c.family_id = f.id and c.user_id is not null) as linked_devices,
       (select count(*) from public.tasks t where t.family_id = f.id) as tasks,
       (select count(*) from public.completions x where x.family_id = f.id and x.date > current_date - 30 and x.status = 'approved') as approved_30d,
       (select count(*) from public.clinic_links l where l.family_id = f.id and l.status = 'active') as clinic_links,
       public.family_premium(f.id) as premium,
       (select max(a.last_seen_at) from public.user_activity a join public.profiles p on p.id = a.user_id where p.family_id = f.id) as last_seen_at
  from public.families f;

revoke all on all tables in schema analytics from public, anon, authenticated;
