-- =====================================================================
-- Seans planlama ve takip (öneri, 5 Kasım 2026; kullanıcı isteği "önerdiğin beş alternatifin geliştirmesini yap")
-- Belge ve benchmark: https://claude.ai/artifact/TiMrtycSVdzbeNTiii6oNP · önizleme: https://claude.ai/artifact/DpcEfMzky7SqNWfrivbAVd
-- Akış: sozlesme/akislar.md 20. Tablolar: sozlesme/veritabani.md 28. Durumlar: sozlesme/durumlar.md 13.
--   A  uzmanın takvimi, tek ya da tekrarlayan seans, durum (Yapıldı / Gelmedi / Geç iptal / İptal / Ertelendi)
--   B  aileye görünür randevu (ParentApp "Uzmanım › Randevular"), aile yanıtı (Uygun / Uygun değil), bildirimler;
--      hatırlatmayı ParentApp cihazda kurar (ayardaki dakikalar, family_sessions().reminders)
--   C  seans kaydı (yalnız klinik: katılanlar, gözlem / çalışılan / sonraki adım, gündem, aileye ev ödevi listesi)
--   D  odalar ve şubeler, çalışma saatleri, ailenin uygun saatten randevu alması, bekleme listesi ve boşalan saat
--      teklifi, geç iptal süresi, seans paketi (seans sayısı; ödeme yok)
--   E  takvim aboneliği (uzmanın Google / Apple / Outlook takvimine tek yönlü, adsız .ics; Edge Function calendar-feed)
--      ve dış takvimi okuma (uzmanın gizli iCal adresi; Edge Function calendar-import, seansa çevirme)
-- Kurallar: seans uzmanın kendi kaydıdır; aile yalnız "aileye göster" açık ve paylaşım etkinken tarih, saat, yer,
-- tür ve uzman adını görür. Not, gündem, ev ödevi listesi, paket, bekleme listesi aileye kapalı. Yazma yalnız
-- işlevlerle (tablolara doğrudan yazma yok; çalışma saatleri hariç). Paylaşım bitince gelecekteki seanslar iptal olur.
-- Ödeme / e-fatura ve herkese açık (yeni aile) randevu sayfası bu öneride yok (karar ve hesap bekliyor).
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tablolar
-- ---------------------------------------------------------------------
create table if not exists public.clinic_rooms (
  id          uuid primary key default gen_random_uuid(),
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 60),
  location    text check (location is null or char_length(location) <= 80),   -- şube
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists clinic_rooms_clinic_idx on public.clinic_rooms (clinic_id);

create table if not exists public.clinic_session_settings (
  clinic_id             uuid primary key references public.clinics (id) on delete cascade,
  cancel_hours          int not null default 24 check (cancel_hours between 0 and 168),
  count_late_cancel     boolean not null default true,     -- geç iptal paketten düşer
  count_no_show         boolean not null default true,     -- gelmeme paketten düşer
  reminders             int[] not null default '{1440,120}', -- aileye hatırlatma: seanstan kaç dakika önce
  booking_enabled       boolean not null default false,    -- aile uygun saatten randevu alabilir
  booking_notice_hours  int not null default 24 check (booking_notice_hours between 0 and 336),
  booking_horizon_days  int not null default 21 check (booking_horizon_days between 1 and 90),
  slot_minutes          int not null default 45 check (slot_minutes between 15 and 240),
  updated_at            timestamptz not null default now()
);

create table if not exists public.clinic_availability (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  clinician_id  uuid not null references public.clinicians (id) on delete cascade,
  weekday       smallint not null check (weekday between 1 and 7),   -- ISO: 1 = Pazartesi
  start_time    time not null,
  end_time      time not null,
  room_id       uuid references public.clinic_rooms (id) on delete set null,
  bookable      boolean not null default false,                     -- aile bu saatlerden randevu alabilir
  created_at    timestamptz not null default now(),
  check (end_time > start_time)
);
create index if not exists clinic_availability_clinician_idx on public.clinic_availability (clinician_id, weekday);

create table if not exists public.clinic_session_packages (
  id          uuid primary key default gen_random_uuid(),
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  link_id     uuid not null references public.clinic_links (id) on delete cascade,
  title       text not null check (char_length(btrim(title)) between 1 and 60),
  total       int not null check (total between 1 and 200),
  starts_on   date,
  ends_on     date,
  note        text check (note is null or char_length(note) <= 300),
  closed_at   timestamptz,
  created_by  uuid references public.clinicians (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists clinic_session_packages_link_idx on public.clinic_session_packages (link_id);

create table if not exists public.clinic_waitlist (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  link_id       uuid not null references public.clinic_links (id) on delete cascade,
  clinician_id  uuid references public.clinicians (id) on delete set null,
  note          text check (note is null or char_length(note) <= 300),     -- uygun günler / saatler
  status        text not null default 'waiting' check (status in ('waiting', 'offered', 'booked', 'removed')),
  created_by    uuid references public.clinicians (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index if not exists clinic_waitlist_open_idx on public.clinic_waitlist (link_id) where status in ('waiting', 'offered');

create table if not exists public.clinic_sessions (
  id                  uuid primary key default gen_random_uuid(),
  clinic_id           uuid not null references public.clinics (id) on delete cascade,
  clinician_id        uuid references public.clinicians (id) on delete set null,
  link_id             uuid references public.clinic_links (id) on delete cascade,   -- boş: danışansız blok
  title               text check (title is null or char_length(title) <= 80),       -- danışansız bloğun adı
  series_id           uuid,
  starts_at           timestamptz not null,
  duration_min        int not null default 45 check (duration_min between 5 and 480),
  kind                text not null default 'individual'
                        check (kind in ('individual', 'family', 'parent', 'group', 'intake', 'other')),
  mode                text not null default 'in_person' check (mode in ('in_person', 'online', 'home')),
  room_id             uuid references public.clinic_rooms (id) on delete set null,
  status              text not null default 'planned'
                        check (status in ('planned', 'done', 'no_show', 'late_cancel', 'cancelled', 'postponed', 'offered')),
  status_at           timestamptz,
  status_by           uuid,
  cancel_reason       text check (cancel_reason is null or char_length(cancel_reason) <= 200),
  visible_to_family   boolean not null default false,
  booked_by           text not null default 'clinic' check (booked_by in ('clinic', 'family')),
  family_response     text check (family_response in ('ok', 'unavailable')),
  family_note         text check (family_note is null or char_length(family_note) <= 300),
  family_responded_at timestamptz,
  package_id          uuid references public.clinic_session_packages (id) on delete set null,
  waitlist_id         uuid references public.clinic_waitlist (id) on delete set null,
  offer_expires_at    timestamptz,
  external_uid        text check (external_uid is null or char_length(external_uid) <= 300),
  created_by          uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists clinic_sessions_clinic_time_idx on public.clinic_sessions (clinic_id, starts_at);
create index if not exists clinic_sessions_link_idx on public.clinic_sessions (link_id, starts_at);
create index if not exists clinic_sessions_series_idx on public.clinic_sessions (series_id) where series_id is not null;

create table if not exists public.clinic_session_records (
  session_id   uuid primary key references public.clinic_sessions (id) on delete cascade,
  clinic_id    uuid not null references public.clinics (id) on delete cascade,
  attendees    text[] not null default '{}',
  observation  text check (observation is null or char_length(observation) <= 4000),
  worked       text check (worked is null or char_length(worked) <= 4000),
  next_step    text check (next_step is null or char_length(next_step) <= 4000),
  agenda       jsonb not null default '[]',     -- [{text, done, source}]
  homework     jsonb not null default '[]',     -- [{kind, id, title}] aileye gönderilenlerin listesi
  author_id    uuid references public.clinicians (id) on delete set null,
  updated_at   timestamptz not null default now()
);

create table if not exists public.clinic_calendar_feeds (
  clinician_id   uuid primary key references public.clinicians (id) on delete cascade,
  clinic_id      uuid not null references public.clinics (id) on delete cascade,
  token          text not null unique,
  show_initials  boolean not null default false,
  created_at     timestamptz not null default now(),
  rotated_at     timestamptz
);

create table if not exists public.clinic_calendar_sources (
  id              uuid primary key default gen_random_uuid(),
  clinician_id    uuid not null references public.clinicians (id) on delete cascade,
  clinic_id       uuid not null references public.clinics (id) on delete cascade,
  label           text check (label is null or char_length(label) <= 40),
  url             text not null check (char_length(url) <= 600),
  last_synced_at  timestamptz,
  last_error      text check (last_error is null or char_length(last_error) <= 200),
  created_at      timestamptz not null default now()
);

create table if not exists public.clinic_external_events (
  id            uuid primary key default gen_random_uuid(),
  source_id     uuid not null references public.clinic_calendar_sources (id) on delete cascade,
  clinician_id  uuid not null references public.clinicians (id) on delete cascade,
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  uid           text not null check (char_length(uid) <= 300),
  starts_at     timestamptz not null,
  ends_at       timestamptz not null,
  summary       text check (summary is null or char_length(summary) <= 200),
  session_id    uuid references public.clinic_sessions (id) on delete set null,
  ignored       boolean not null default false,
  synced_at     timestamptz not null default now(),
  unique (source_id, uid, starts_at)
);
create index if not exists clinic_external_events_clinician_idx on public.clinic_external_events (clinician_id, starts_at);

-- ---------------------------------------------------------------------
-- 2. Satır düzeyi güvenlik: okuma politikalarla, yazma işlevlerle
-- ---------------------------------------------------------------------
alter table public.clinic_rooms enable row level security;
alter table public.clinic_session_settings enable row level security;
alter table public.clinic_availability enable row level security;
alter table public.clinic_session_packages enable row level security;
alter table public.clinic_waitlist enable row level security;
alter table public.clinic_sessions enable row level security;
alter table public.clinic_session_records enable row level security;
alter table public.clinic_calendar_feeds enable row level security;
alter table public.clinic_calendar_sources enable row level security;
alter table public.clinic_external_events enable row level security;
revoke all on public.clinic_rooms, public.clinic_session_settings, public.clinic_availability, public.clinic_session_packages,
  public.clinic_waitlist, public.clinic_sessions, public.clinic_session_records, public.clinic_calendar_feeds,
  public.clinic_calendar_sources, public.clinic_external_events from anon, authenticated;

-- Oturumdaki uzman bu seansı görür mü? (danışanlı: paylaşım görünürlüğü; danışansız blok: kendisi ya da sahip)
create or replace function public.clinic_session_visible(p_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.clinician_access() and exists (
    select 1 from public.clinic_sessions s
    where s.id = p_id and s.clinic_id = public.my_clinic_id()
      and case when s.link_id is null then s.clinician_id = auth.uid() or public.clinic_is_owner()
               else public.clinic_link_visible(s.link_id) end)
$$;
revoke execute on function public.clinic_session_visible(uuid) from public, anon;
grant execute on function public.clinic_session_visible(uuid) to authenticated;

drop policy if exists "oda: klinik okur" on public.clinic_rooms;
create policy "oda: klinik okur" on public.clinic_rooms for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access());
grant select on public.clinic_rooms to authenticated;

drop policy if exists "seans ayarı: klinik okur" on public.clinic_session_settings;
create policy "seans ayarı: klinik okur" on public.clinic_session_settings for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access());
grant select on public.clinic_session_settings to authenticated;

drop policy if exists "çalışma saati: klinik okur" on public.clinic_availability;
create policy "çalışma saati: klinik okur" on public.clinic_availability for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access());
drop policy if exists "çalışma saati: kendisi ya da sahip yazar" on public.clinic_availability;
create policy "çalışma saati: kendisi ya da sahip yazar" on public.clinic_availability for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and (clinician_id = auth.uid() or public.clinic_is_owner()))
  with check (clinic_id = public.my_clinic_id() and public.clinician_access() and (clinician_id = auth.uid() or public.clinic_is_owner())
    and exists (select 1 from public.clinic_members m where m.clinician_id = clinic_availability.clinician_id
                  and m.clinic_id = public.my_clinic_id() and m.status = 'active')
    and (room_id is null or exists (select 1 from public.clinic_rooms r where r.id = room_id and r.clinic_id = public.my_clinic_id())));
grant select, insert, update, delete on public.clinic_availability to authenticated;

drop policy if exists "paket: klinik okur" on public.clinic_session_packages;
create policy "paket: klinik okur" on public.clinic_session_packages for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id));
grant select on public.clinic_session_packages to authenticated;

drop policy if exists "bekleme: klinik okur" on public.clinic_waitlist;
create policy "bekleme: klinik okur" on public.clinic_waitlist for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id));
grant select on public.clinic_waitlist to authenticated;

drop policy if exists "seans: klinik okur" on public.clinic_sessions;
create policy "seans: klinik okur" on public.clinic_sessions for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
    and case when link_id is null then clinician_id = auth.uid() or public.clinic_is_owner()
             else public.clinic_link_visible(link_id) end);
grant select on public.clinic_sessions to authenticated;

drop policy if exists "seans kaydı: klinik okur" on public.clinic_session_records;
create policy "seans kaydı: klinik okur" on public.clinic_session_records for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinic_session_visible(session_id));
grant select on public.clinic_session_records to authenticated;

drop policy if exists "takvim beslemesi: kendisi" on public.clinic_calendar_feeds;
create policy "takvim beslemesi: kendisi" on public.clinic_calendar_feeds for select to authenticated
  using (clinician_id = auth.uid());
grant select on public.clinic_calendar_feeds to authenticated;

drop policy if exists "dış takvim: kendisi" on public.clinic_calendar_sources;
create policy "dış takvim: kendisi" on public.clinic_calendar_sources for select to authenticated
  using (clinician_id = auth.uid() and public.clinician_access());
grant select on public.clinic_calendar_sources to authenticated;

drop policy if exists "dış etkinlik: kendisi" on public.clinic_external_events;
create policy "dış etkinlik: kendisi" on public.clinic_external_events for select to authenticated
  using (clinician_id = auth.uid() and public.clinician_access());
grant select on public.clinic_external_events to authenticated;

-- ---------------------------------------------------------------------
-- 3. Yardımcılar
-- ---------------------------------------------------------------------
create or replace function public.clinic_session_settings_row(p_clinic uuid)
returns public.clinic_session_settings language sql stable security definer set search_path = '' as $$
  select coalesce((select s from public.clinic_session_settings s where s.clinic_id = p_clinic),
                  row(p_clinic, 24, true, true, '{1440,120}'::int[], false, 24, 21, 45, now())::public.clinic_session_settings)
$$;
revoke execute on function public.clinic_session_settings_row(uuid) from public, anon, authenticated;

create or replace function public.session_when(p_at timestamptz)
returns text language sql immutable set search_path = '' as $$
  select to_char(p_at at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')
$$;
revoke execute on function public.session_when(timestamptz) from public, anon, authenticated;

create or replace function public.session_kind_label(p_kind text)
returns text language sql immutable set search_path = '' as $$
  select case p_kind when 'individual' then 'Bireysel seans' when 'family' then 'Aile görüşmesi'
                     when 'parent' then 'Ebeveyn görüşmesi' when 'group' then 'Grup seansı'
                     when 'intake' then 'İlk görüşme' else 'Görüşme' end
$$;
revoke execute on function public.session_kind_label(text) from public, anon, authenticated;

-- Aileye bildirim (paylaşım etkin ve "aileye göster" açıksa)
create or replace function public.session_notify_family(p_session uuid, p_kind text, p_title text, p_body text)
returns void language plpgsql security definer set search_path = '' as $$
declare s record;
begin
  select x.id, x.visible_to_family, l.family_id, l.child_id, l.status into s
    from public.clinic_sessions x join public.clinic_links l on l.id = x.link_id where x.id = p_session;
  if s.id is null or not s.visible_to_family or s.status <> 'active' then return; end if;
  perform public.notify_parents(s.family_id, p_kind, p_title || ': ' || public.child_name(s.child_id), p_body,
                                jsonb_build_object('session_id', p_session), s.child_id);
end $$;
revoke execute on function public.session_notify_family(uuid, text, text, text) from public, anon, authenticated;

-- Seansın uzmanına (yoksa kliniğe) bildirim
create or replace function public.session_notify_clinician(p_session uuid, p_kind text, p_title text, p_body text)
returns void language plpgsql security definer set search_path = '' as $$
declare s record;
begin
  select x.clinic_id, x.clinician_id, x.link_id, l.child_id into s
    from public.clinic_sessions x left join public.clinic_links l on l.id = x.link_id where x.id = p_session;
  if s.clinic_id is null then return; end if;
  perform public.notify_clinic(s.clinic_id, s.clinician_id, p_kind,
    p_title || coalesce(': ' || public.child_name(s.child_id), ''), p_body,
    jsonb_build_object('session_id', p_session, 'link_id', s.link_id), s.child_id);
end $$;
revoke execute on function public.session_notify_clinician(uuid, text, text, text) from public, anon, authenticated;

-- Oda ve uzman çakışmaları (iptal / ertelenmiş seanslar hariç)
create or replace function public.session_conflicts(p_clinic uuid, p_clinician uuid, p_room uuid, p_start timestamptz,
                                                    p_minutes int, p_except uuid default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('starts_at', s.starts_at, 'room', s.room_id is not distinct from p_room and p_room is not null,
                                               'clinician', s.clinician_id is not distinct from p_clinician)), '[]')
  from public.clinic_sessions s
  where s.clinic_id = p_clinic and s.id is distinct from p_except
    and s.status in ('planned', 'offered', 'done')
    and ((p_room is not null and s.room_id = p_room) or s.clinician_id = p_clinician)
    and s.starts_at < p_start + make_interval(mins => p_minutes)
    and p_start < s.starts_at + make_interval(mins => s.duration_min)
$$;
revoke execute on function public.session_conflicts(uuid, uuid, uuid, timestamptz, int, uuid) from public, anon, authenticated;

-- Seans girdisini doğrular (paylaşım, uzman, oda, paket kliniğe ait mi)
create or replace function public.session_check_refs(p_link uuid, p_clinician uuid, p_room uuid, p_package uuid)
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if p_link is not null and not public.clinic_link_mine(p_link) then raise exception 'link_not_visible' using errcode = '42501'; end if;
  if p_clinician is not null and public.clinic_member_role(public.my_clinic_id(), p_clinician) is null then
    raise exception 'clinician_not_in_clinic' using errcode = '42501';
  end if;
  if p_clinician is not null and p_clinician <> auth.uid() and not public.clinic_is_owner() then
    raise exception 'only_owner_assigns' using errcode = '42501';
  end if;
  if p_room is not null and not exists (select 1 from public.clinic_rooms r where r.id = p_room and r.clinic_id = public.my_clinic_id()) then
    raise exception 'room_not_in_clinic' using errcode = '42501';
  end if;
  if p_package is not null and not exists (select 1 from public.clinic_session_packages k where k.id = p_package and k.link_id = p_link) then
    raise exception 'package_link_mismatch' using errcode = '23514';
  end if;
end $$;
revoke execute on function public.session_check_refs(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Uzman işlevleri
-- ---------------------------------------------------------------------
create or replace function public.clinic_session_settings()
returns json language sql stable security definer set search_path = '' as $$
  select case when public.clinician_access() then (
    select json_build_object('cancel_hours', s.cancel_hours, 'count_late_cancel', s.count_late_cancel, 'count_no_show', s.count_no_show,
      'reminders', s.reminders, 'booking_enabled', s.booking_enabled, 'booking_notice_hours', s.booking_notice_hours,
      'booking_horizon_days', s.booking_horizon_days, 'slot_minutes', s.slot_minutes)
    from public.clinic_session_settings_row(public.my_clinic_id()) s) end
$$;
revoke execute on function public.clinic_session_settings() from public, anon;
grant execute on function public.clinic_session_settings() to authenticated;

create or replace function public.clinic_session_settings_save(p jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare k uuid := public.my_clinic_id(); cur public.clinic_session_settings;
begin
  if not public.clinician_access() or not public.clinic_is_owner() then raise exception 'only_owner' using errcode = '42501'; end if;
  cur := public.clinic_session_settings_row(k);
  insert into public.clinic_session_settings as t (clinic_id, cancel_hours, count_late_cancel, count_no_show, reminders,
      booking_enabled, booking_notice_hours, booking_horizon_days, slot_minutes, updated_at)
  values (k, coalesce((p ->> 'cancel_hours')::int, cur.cancel_hours), coalesce((p ->> 'count_late_cancel')::boolean, cur.count_late_cancel),
      coalesce((p ->> 'count_no_show')::boolean, cur.count_no_show),
      coalesce((select array_agg(x::int order by x::int desc) from jsonb_array_elements_text(p -> 'reminders') x
                where x::int between 5 and 10080), case when p ? 'reminders' then '{}'::int[] else cur.reminders end),
      coalesce((p ->> 'booking_enabled')::boolean, cur.booking_enabled), coalesce((p ->> 'booking_notice_hours')::int, cur.booking_notice_hours),
      coalesce((p ->> 'booking_horizon_days')::int, cur.booking_horizon_days), coalesce((p ->> 'slot_minutes')::int, cur.slot_minutes), now())
  on conflict (clinic_id) do update set cancel_hours = excluded.cancel_hours, count_late_cancel = excluded.count_late_cancel,
      count_no_show = excluded.count_no_show, reminders = excluded.reminders, booking_enabled = excluded.booking_enabled,
      booking_notice_hours = excluded.booking_notice_hours, booking_horizon_days = excluded.booking_horizon_days,
      slot_minutes = excluded.slot_minutes, updated_at = now();
end $$;
revoke execute on function public.clinic_session_settings_save(jsonb) from public, anon;
grant execute on function public.clinic_session_settings_save(jsonb) to authenticated;

-- Oda ekle / düzelt (sahip)
create or replace function public.clinic_room_save(p_id uuid, p_name text, p_location text default null, p_active boolean default true)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  if not public.clinician_access() or not public.clinic_is_owner() then raise exception 'only_owner' using errcode = '42501'; end if;
  if p_id is null then
    insert into public.clinic_rooms (clinic_id, name, location, active) values (public.my_clinic_id(), btrim(p_name), nullif(btrim(p_location), ''), p_active)
    returning id into v;
  else
    update public.clinic_rooms set name = btrim(p_name), location = nullif(btrim(p_location), ''), active = p_active
     where id = p_id and clinic_id = public.my_clinic_id() returning id into v;
    if v is null then raise exception 'room_not_found' using errcode = 'P0002'; end if;
  end if;
  return v;
end $$;
revoke execute on function public.clinic_room_save(uuid, text, text, boolean) from public, anon;
grant execute on function public.clinic_room_save(uuid, text, text, boolean) to authenticated;

-- Seans oluştur: tek ya da tekrarlayan (her hafta / iki haftada bir, en çok 52). Döner: {ids, conflicts}
create or replace function public.clinic_session_create(p jsonb)
returns json language plpgsql security definer set search_path = '' as $$
declare
  k uuid := public.my_clinic_id();
  v_link uuid := nullif(p ->> 'link_id', '')::uuid;
  v_clin uuid := coalesce(nullif(p ->> 'clinician_id', '')::uuid, auth.uid());
  v_room uuid := nullif(p ->> 'room_id', '')::uuid;
  v_pkg uuid := nullif(p ->> 'package_id', '')::uuid;
  v_start timestamptz := (p ->> 'starts_at')::timestamptz;
  v_min int := coalesce((p ->> 'duration_min')::int, 45);
  v_rep text := coalesce(p ->> 'repeat', 'none');
  v_count int := least(greatest(coalesce((p ->> 'count')::int, 1), 1), 52);
  v_step interval;
  v_series uuid;
  v_vis boolean := coalesce((p ->> 'visible_to_family')::boolean, false) and v_link is not null;
  v_ids uuid[] := '{}';
  v_conf jsonb := '[]';
  v_id uuid;
  i int;
begin
  if not public.clinician_access() then raise exception 'no_access' using errcode = '42501'; end if;
  if v_start is null then raise exception 'starts_at_required' using errcode = '23502'; end if;
  perform public.session_check_refs(v_link, v_clin, v_room, v_pkg);
  if v_rep = 'none' then v_count := 1; end if;
  v_step := case v_rep when 'biweekly' then interval '14 days' else interval '7 days' end;
  if v_count > 1 then v_series := gen_random_uuid(); end if;
  for i in 0 .. v_count - 1 loop
    v_conf := v_conf || public.session_conflicts(k, v_clin, v_room, v_start + v_step * i, v_min);
    insert into public.clinic_sessions (clinic_id, clinician_id, link_id, title, series_id, starts_at, duration_min, kind, mode, room_id,
                                        visible_to_family, package_id, created_by)
    values (k, v_clin, v_link, nullif(btrim(p ->> 'title'), ''), v_series, v_start + v_step * i, v_min,
            coalesce(p ->> 'kind', 'individual'), coalesce(p ->> 'mode', 'in_person'), v_room, v_vis, v_pkg, auth.uid())
    returning id into v_id;
    v_ids := v_ids || v_id;
  end loop;
  if v_vis then
    perform public.session_notify_family(v_ids[1], 'session_scheduled', 'Yeni randevu',
      case when v_count > 1 then v_count || ' seans, ' || public.session_when(v_start) || ' başlayarak '
             || case v_rep when 'biweekly' then 'iki haftada bir' else 'her hafta' end
           else public.session_when(v_start) end);
  end if;
  return json_build_object('ids', to_json(v_ids), 'conflicts', v_conf);
end $$;
revoke execute on function public.clinic_session_create(jsonb) from public, anon;
grant execute on function public.clinic_session_create(jsonb) to authenticated;

-- Seansı düzelt; p_scope 'following' = bu ve serideki sonraki planlı seanslar (saat kayması aynı ölçüde)
create or replace function public.clinic_session_update(p_id uuid, p jsonb, p_scope text default 'one')
returns json language plpgsql security definer set search_path = '' as $$
declare
  s public.clinic_sessions;
  v_delta interval := interval '0';
  v_room uuid; v_clin uuid; v_pkg uuid; v_vis boolean; v_min int;
  v_n int := 0; v_conf jsonb := '[]'; r record;
begin
  select * into s from public.clinic_sessions where id = p_id;
  if s.id is null or not public.clinic_session_visible(p_id) then raise exception 'session_not_found' using errcode = 'P0002'; end if;
  v_room := case when p ? 'room_id' then nullif(p ->> 'room_id', '')::uuid else s.room_id end;
  v_clin := case when p ? 'clinician_id' then coalesce(nullif(p ->> 'clinician_id', '')::uuid, s.clinician_id) else s.clinician_id end;
  v_pkg := case when p ? 'package_id' then nullif(p ->> 'package_id', '')::uuid else s.package_id end;
  v_vis := case when p ? 'visible_to_family' then coalesce((p ->> 'visible_to_family')::boolean, false) and s.link_id is not null
                else s.visible_to_family end;
  v_min := coalesce((p ->> 'duration_min')::int, s.duration_min);
  perform public.session_check_refs(s.link_id, case when v_clin is distinct from s.clinician_id then v_clin end, v_room, v_pkg);
  if p ? 'starts_at' then v_delta := (p ->> 'starts_at')::timestamptz - s.starts_at; end if;
  for r in select x.* from public.clinic_sessions x
            where x.id = p_id or (p_scope = 'following' and s.series_id is not null and x.series_id = s.series_id
                                  and x.starts_at > s.starts_at and x.status = 'planned')
            order by x.starts_at loop
    update public.clinic_sessions set
      starts_at = r.starts_at + v_delta, duration_min = v_min,
      kind = coalesce(p ->> 'kind', r.kind), mode = coalesce(p ->> 'mode', r.mode), room_id = v_room, clinician_id = v_clin,
      title = case when p ? 'title' then nullif(btrim(p ->> 'title'), '') else r.title end,
      visible_to_family = v_vis, package_id = v_pkg,
      family_response = case when v_delta <> interval '0' then null else r.family_response end,
      family_note = case when v_delta <> interval '0' then null else r.family_note end,
      updated_at = now()
    where id = r.id;
    v_conf := v_conf || public.session_conflicts(r.clinic_id, v_clin, v_room, r.starts_at + v_delta, v_min, r.id);
    v_n := v_n + 1;
  end loop;
  if v_vis and (v_delta <> interval '0' or (v_vis and not s.visible_to_family)) and s.status = 'planned' then
    perform public.session_notify_family(p_id, case when s.visible_to_family then 'session_changed' else 'session_scheduled' end,
      case when s.visible_to_family then 'Randevu değişti' else 'Yeni randevu' end,
      public.session_when(s.starts_at + v_delta) || case when v_n > 1 then ' (ve sonraki ' || (v_n - 1) || ' seans)' else '' end);
  end if;
  return json_build_object('updated', v_n, 'conflicts', v_conf);
end $$;
revoke execute on function public.clinic_session_update(uuid, jsonb, text) from public, anon;
grant execute on function public.clinic_session_update(uuid, jsonb, text) to authenticated;

-- Durum: done / no_show / cancelled (süre içindeyse late_cancel; p_waive ile cancelled kalır) / postponed / planned
create or replace function public.clinic_session_set_status(p_id uuid, p_status text, p_reason text default null, p_waive boolean default false)
returns text language plpgsql security definer set search_path = '' as $$
declare s public.clinic_sessions; v text := p_status; st public.clinic_session_settings;
begin
  select * into s from public.clinic_sessions where id = p_id;
  if s.id is null or not public.clinic_session_visible(p_id) then raise exception 'session_not_found' using errcode = 'P0002'; end if;
  if p_status not in ('planned', 'done', 'no_show', 'cancelled', 'late_cancel', 'postponed') then
    raise exception 'bad_status' using errcode = '22023';
  end if;
  if p_status in ('done', 'no_show') and s.starts_at > now() + interval '30 minutes' then
    raise exception 'session_not_started' using errcode = '22023';
  end if;
  if p_status = 'cancelled' and not p_waive then
    st := public.clinic_session_settings_row(s.clinic_id);
    if now() > s.starts_at - make_interval(hours => st.cancel_hours) then v := 'late_cancel'; end if;
  end if;
  update public.clinic_sessions set status = v, status_at = now(), status_by = auth.uid(),
         cancel_reason = case when v in ('cancelled', 'late_cancel', 'postponed') then nullif(btrim(p_reason), '') else null end,
         updated_at = now()
   where id = p_id;
  if v in ('cancelled', 'late_cancel', 'postponed') and s.status in ('planned', 'offered') and s.starts_at > now() then
    perform public.session_notify_family(p_id, 'session_cancelled', case v when 'postponed' then 'Randevu ertelendi' else 'Randevu iptal edildi' end,
                                         public.session_when(s.starts_at));
  end if;
  return v;
end $$;
revoke execute on function public.clinic_session_set_status(uuid, text, text, boolean) from public, anon;
grant execute on function public.clinic_session_set_status(uuid, text, text, boolean) to authenticated;

-- Sil (kaydı olan seans silinmez); p_scope 'following' = bu ve serideki sonraki planlı seanslar
create or replace function public.clinic_session_delete(p_id uuid, p_scope text default 'one')
returns int language plpgsql security definer set search_path = '' as $$
declare s public.clinic_sessions; v_n int;
begin
  select * into s from public.clinic_sessions where id = p_id;
  if s.id is null or not public.clinic_session_visible(p_id) then raise exception 'session_not_found' using errcode = 'P0002'; end if;
  if exists (select 1 from public.clinic_session_records r where r.session_id = p_id) then
    raise exception 'session_has_record' using errcode = '23503';
  end if;
  if s.visible_to_family and s.status in ('planned', 'offered') and s.starts_at > now() then
    perform public.session_notify_family(p_id, 'session_cancelled', 'Randevu iptal edildi',
      public.session_when(s.starts_at) || case when p_scope = 'following' and s.series_id is not null then ' ve sonraki seanslar' else '' end);
  end if;
  delete from public.clinic_sessions x
   where (x.id = p_id or (p_scope = 'following' and s.series_id is not null and x.series_id = s.series_id
                          and x.starts_at > s.starts_at and x.status = 'planned'))
     and not exists (select 1 from public.clinic_session_records r where r.session_id = x.id);
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke execute on function public.clinic_session_delete(uuid, text) from public, anon;
grant execute on function public.clinic_session_delete(uuid, text) to authenticated;

-- Seans kaydı (yalnız klinik görür)
create or replace function public.clinic_session_record_save(p_session uuid, p jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare s public.clinic_sessions;
begin
  select * into s from public.clinic_sessions where id = p_session;
  if s.id is null or not public.clinic_session_visible(p_session) or (s.link_id is not null and not public.clinic_link_mine(s.link_id)) then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;
  insert into public.clinic_session_records as t (session_id, clinic_id, attendees, observation, worked, next_step, agenda, homework, author_id, updated_at)
  values (p_session, s.clinic_id,
          coalesce((select array_agg(left(x, 40)) from jsonb_array_elements_text(p -> 'attendees') x), '{}'),
          nullif(btrim(p ->> 'observation'), ''), nullif(btrim(p ->> 'worked'), ''), nullif(btrim(p ->> 'next_step'), ''),
          coalesce(case when jsonb_typeof(p -> 'agenda') = 'array' then p -> 'agenda' end, '[]'),
          coalesce(case when jsonb_typeof(p -> 'homework') = 'array' then p -> 'homework' end, '[]'),
          auth.uid(), now())
  on conflict (session_id) do update set attendees = excluded.attendees, observation = excluded.observation, worked = excluded.worked,
          next_step = excluded.next_step, agenda = excluded.agenda, homework = excluded.homework, author_id = excluded.author_id, updated_at = now();
end $$;
revoke execute on function public.clinic_session_record_save(uuid, jsonb) from public, anon;
grant execute on function public.clinic_session_record_save(uuid, jsonb) to authenticated;

-- Klinikteki dolu saatler (oda ve uzman), danışan bilgisi olmadan: ekip üyesi başkasının seansını görmeden çakışmayı görür
create or replace function public.clinic_busy(p_from timestamptz, p_to timestamptz)
returns table (clinician_id uuid, room_id uuid, starts_at timestamptz, ends_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select s.clinician_id, s.room_id, s.starts_at, s.starts_at + make_interval(mins => s.duration_min)
  from public.clinic_sessions s
  where public.clinician_access() and s.clinic_id = public.my_clinic_id() and s.status in ('planned', 'offered', 'done')
    and s.starts_at < p_to and s.starts_at + make_interval(mins => s.duration_min) > p_from
    and p_to - p_from <= interval '62 days'
$$;
revoke execute on function public.clinic_busy(timestamptz, timestamptz) from public, anon;
grant execute on function public.clinic_busy(timestamptz, timestamptz) to authenticated;

-- Çalışma alanları (20261105090000_workspaces.sql): etkin alanın uzmanlarının BAŞKA alanlardaki seansları. Uzman kendi
-- seanslarında alanın adını görür; başkasının seansında yalnız "dolu" (alan, danışan, oda gelmez).
create or replace function public.clinic_busy_elsewhere(p_from timestamptz, p_to timestamptz)
returns table (clinician_id uuid, starts_at timestamptz, ends_at timestamptz, clinic text)
language sql stable security definer set search_path = '' as $$
  select s.clinician_id, s.starts_at, s.starts_at + make_interval(mins => s.duration_min),
         case when s.clinician_id = auth.uid() then c.name end
  from public.clinic_sessions s
  join public.clinics c on c.id = s.clinic_id
  where public.my_clinic_id() is not null and s.clinic_id <> public.my_clinic_id()
    and s.status in ('planned', 'offered', 'done')
    and s.clinician_id in (select m.clinician_id from public.clinic_members m
                            where m.clinic_id = public.my_clinic_id() and m.status = 'active')
    and (s.clinician_id = auth.uid() or public.clinic_is_owner())
    and s.starts_at < p_to and s.starts_at + make_interval(mins => s.duration_min) > p_from
    and p_to - p_from <= interval '62 days'
$$;
revoke execute on function public.clinic_busy_elsewhere(timestamptz, timestamptz) from public, anon;
grant execute on function public.clinic_busy_elsewhere(timestamptz, timestamptz) to authenticated;

-- Seans paketi (yalnız seans sayısı; ödeme yok)
create or replace function public.clinic_package_save(p_id uuid, p_link uuid, p_title text, p_total int,
                                                      p_starts date default null, p_ends date default null, p_note text default null,
                                                      p_closed boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  if p_id is null then
    if not public.clinic_link_mine(p_link) then raise exception 'link_not_visible' using errcode = '42501'; end if;
    insert into public.clinic_session_packages (clinic_id, link_id, title, total, starts_on, ends_on, note, created_by)
    values (public.my_clinic_id(), p_link, btrim(p_title), p_total, p_starts, p_ends, nullif(btrim(p_note), ''), auth.uid())
    returning id into v;
  else
    update public.clinic_session_packages set title = btrim(p_title), total = p_total, starts_on = p_starts, ends_on = p_ends,
           note = nullif(btrim(p_note), ''), closed_at = case when p_closed then coalesce(closed_at, now()) else null end
     where id = p_id and clinic_id = public.my_clinic_id() and public.clinic_link_mine(link_id) returning id into v;
    if v is null then raise exception 'package_not_found' using errcode = 'P0002'; end if;
  end if;
  return v;
end $$;
revoke execute on function public.clinic_package_save(uuid, uuid, text, int, date, date, text, boolean) from public, anon;
grant execute on function public.clinic_package_save(uuid, uuid, text, int, date, date, text, boolean) to authenticated;

-- Bekleme listesi
create or replace function public.clinic_waitlist_save(p_link uuid, p_note text default null, p_remove boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  if not public.clinic_link_mine(p_link) then raise exception 'link_not_visible' using errcode = '42501'; end if;
  if p_remove then
    update public.clinic_waitlist set status = 'removed', updated_at = now() where link_id = p_link and status in ('waiting', 'offered')
    returning id into v;
    return v;
  end if;
  select id into v from public.clinic_waitlist where link_id = p_link and status in ('waiting', 'offered');
  if v is null then
    insert into public.clinic_waitlist (clinic_id, link_id, clinician_id, note, created_by)
    values (public.my_clinic_id(), p_link, (select clinician_id from public.clinic_links where id = p_link), nullif(btrim(p_note), ''), auth.uid())
    returning id into v;
  else
    update public.clinic_waitlist set note = nullif(btrim(p_note), ''), updated_at = now() where id = v;
  end if;
  return v;
end $$;
revoke execute on function public.clinic_waitlist_save(uuid, text, boolean) from public, anon;
grant execute on function public.clinic_waitlist_save(uuid, text, boolean) to authenticated;

-- Boşalan saati bekleme listesindeki aileye teklif et (aile kabul edene kadar "offered"; süre dolunca geçersiz)
create or replace function public.clinic_waitlist_offer(p_waitlist uuid, p_starts_at timestamptz, p_duration int default 45,
                                                        p_room uuid default null, p_hours int default 24)
returns uuid language plpgsql security definer set search_path = '' as $$
declare w public.clinic_waitlist; v uuid; v_clin uuid;
begin
  select * into w from public.clinic_waitlist where id = p_waitlist and status in ('waiting', 'offered');
  if w.id is null or not public.clinic_link_mine(w.link_id) then raise exception 'waitlist_not_found' using errcode = 'P0002'; end if;
  if p_starts_at <= now() then raise exception 'offer_in_past' using errcode = '22023'; end if;
  v_clin := coalesce(w.clinician_id, auth.uid());
  perform public.session_check_refs(w.link_id, null, p_room, null);
  insert into public.clinic_sessions (clinic_id, clinician_id, link_id, starts_at, duration_min, room_id, status, visible_to_family,
                                      waitlist_id, offer_expires_at, created_by)
  values (w.clinic_id, v_clin, w.link_id, p_starts_at, coalesce(p_duration, 45), p_room, 'offered', true, w.id,
          least(now() + make_interval(hours => greatest(coalesce(p_hours, 24), 1)), p_starts_at), auth.uid())
  returning id into v;
  update public.clinic_waitlist set status = 'offered', updated_at = now() where id = w.id;
  perform public.session_notify_family(v, 'session_offer', 'Boşalan saat önerisi',
    public.session_when(p_starts_at) || ' · yanıtlamak için ParentApp › Uzmanım');
  return v;
end $$;
revoke execute on function public.clinic_waitlist_offer(uuid, timestamptz, int, uuid, int) from public, anon;
grant execute on function public.clinic_waitlist_offer(uuid, timestamptz, int, uuid, int) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Aile işlevleri (ParentApp)
-- ---------------------------------------------------------------------
-- Ailenin görebildiği randevular (etkin paylaşım + "aileye göster"); süresi dolan teklifler görünmez
create or replace function public.family_sessions(p_from timestamptz default null, p_to timestamptz default null)
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(json_build_object(
      'id', s.id, 'link_id', s.link_id, 'child_id', l.child_id, 'child', public.child_name(l.child_id),
      'clinician', coalesce(m.name, ''), 'clinic', c.name,
      'starts_at', s.starts_at, 'duration_min', s.duration_min, 'kind', s.kind, 'kind_label', public.session_kind_label(s.kind),
      'mode', s.mode, 'room', r.name, 'location', r.location, 'status', s.status,
      'family_response', s.family_response, 'family_note', s.family_note, 'booked_by', s.booked_by,
      'offer_expires_at', s.offer_expires_at, 'series', s.series_id is not null,
      'reminders', (public.clinic_session_settings_row(s.clinic_id)).reminders)
    order by s.starts_at), '[]')
  from public.clinic_sessions s
  join public.clinic_links l on l.id = s.link_id and l.status = 'active' and l.family_id = public.my_family_id()
  join public.clinics c on c.id = s.clinic_id
  left join public.clinicians m on m.id = s.clinician_id
  left join public.clinic_rooms r on r.id = s.room_id
  where s.visible_to_family
    and (s.status <> 'offered' or s.offer_expires_at > now())
    and s.starts_at >= coalesce(p_from, now() - interval '60 days')
    and s.starts_at <= coalesce(p_to, now() + interval '180 days')
$$;
revoke execute on function public.family_sessions(timestamptz, timestamptz) from public, anon;
grant execute on function public.family_sessions(timestamptz, timestamptz) to authenticated;

-- Aile yanıtı: 'ok' (geleceğiz) ya da 'unavailable' (uygun değil, isteğe bağlı not); yalnız gelecekteki planlı seans
create or replace function public.family_session_respond(p_id uuid, p_response text, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare s public.clinic_sessions;
begin
  select x.* into s from public.clinic_sessions x
    join public.clinic_links l on l.id = x.link_id and l.status = 'active' and l.family_id = public.my_family_id()
   where x.id = p_id and x.visible_to_family;
  if s.id is null then raise exception 'session_not_found' using errcode = 'P0002'; end if;
  if s.status <> 'planned' or s.starts_at <= now() then raise exception 'session_closed' using errcode = '22023'; end if;
  if p_response not in ('ok', 'unavailable') then raise exception 'bad_response' using errcode = '22023'; end if;
  update public.clinic_sessions set family_response = p_response, family_note = left(nullif(btrim(p_note), ''), 300),
         family_responded_at = now(), updated_at = now() where id = p_id;
  if p_response = 'unavailable' then
    perform public.session_notify_clinician(p_id, 'session_family_response', 'Aile seansa gelemiyor',
      public.session_when(s.starts_at) || coalesce(' · ' || left(nullif(btrim(p_note), ''), 120), ''));
  end if;
end $$;
revoke execute on function public.family_session_respond(uuid, text, text) from public, anon;
grant execute on function public.family_session_respond(uuid, text, text) to authenticated;

-- Boşalan saat teklifine yanıt
create or replace function public.family_offer_respond(p_id uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare s public.clinic_sessions; v text;
begin
  select x.* into s from public.clinic_sessions x
    join public.clinic_links l on l.id = x.link_id and l.status = 'active' and l.family_id = public.my_family_id()
   where x.id = p_id and x.status = 'offered';
  if s.id is null then raise exception 'offer_not_found' using errcode = 'P0002'; end if;
  if s.offer_expires_at <= now() then raise exception 'offer_expired' using errcode = '22023'; end if;
  v := case when p_accept then 'planned' else 'cancelled' end;
  update public.clinic_sessions set status = v, status_at = now(), status_by = auth.uid(), offer_expires_at = null,
         family_response = case when p_accept then 'ok' end, family_responded_at = now(),
         cancel_reason = case when p_accept then null else 'Aile teklifi kabul etmedi' end, updated_at = now()
   where id = p_id;
  update public.clinic_waitlist set status = case when p_accept then 'booked' else 'waiting' end, updated_at = now() where id = s.waitlist_id;
  perform public.session_notify_clinician(p_id, 'session_offer_answered',
    case when p_accept then 'Aile boşalan saati aldı' else 'Aile boşalan saati almadı' end, public.session_when(s.starts_at));
  return v;
end $$;
revoke execute on function public.family_offer_respond(uuid, boolean) from public, anon;
grant execute on function public.family_offer_respond(uuid, boolean) to authenticated;

-- Ailenin alabileceği saatler: klinik randevu almayı açtıysa, sorumlu uzmanın "aileye açık" çalışma saatlerinden,
-- uzmanın ve odanın dolu saatleri, bildirim süresi ve ufuk dışında kalanlar çıkarılarak (en çok 60 saat)
create or replace function public.family_booking_slots(p_link_id uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
declare l record; st public.clinic_session_settings; v_clin uuid; v json;
begin
  if not public.family_link_active(p_link_id) then return '[]'; end if;
  select * into l from public.clinic_links where id = p_link_id;
  st := public.clinic_session_settings_row(l.clinic_id);
  if not st.booking_enabled then return '[]'; end if;
  v_clin := coalesce(l.clinician_id, (select clinician_id from public.clinic_members where clinic_id = l.clinic_id and role = 'owner' and status = 'active' order by joined_at limit 1));
  with days as (
    select d::date as day from generate_series((now() at time zone 'Europe/Istanbul')::date,
                                               (now() at time zone 'Europe/Istanbul')::date + st.booking_horizon_days, interval '1 day') d
  ), slots as (
    select ((dd.day + a.start_time + make_interval(mins => st.slot_minutes * g)) at time zone 'Europe/Istanbul') as starts_at, a.room_id
    from days dd
    join public.clinic_availability a on a.clinician_id = v_clin and a.bookable and a.weekday = extract(isodow from dd.day)
    cross join lateral generate_series(0, greatest(0, (extract(epoch from (a.end_time - a.start_time)) / 60)::int / st.slot_minutes - 1)) g
    where a.start_time + make_interval(mins => st.slot_minutes * (g + 1)) <= a.end_time
  )
  select coalesce(json_agg(json_build_object('starts_at', x.starts_at, 'duration_min', st.slot_minutes) order by x.starts_at), '[]') into v
  from (select distinct on (s.starts_at) s.starts_at from slots s
        where s.starts_at > now() + make_interval(hours => st.booking_notice_hours)
          and not exists (select 1 from public.clinic_sessions x
                          where x.clinic_id = l.clinic_id and x.status in ('planned', 'offered')
                            and (x.clinician_id = v_clin or (s.room_id is not null and x.room_id = s.room_id))
                            and x.starts_at < s.starts_at + make_interval(mins => st.slot_minutes)
                            and s.starts_at < x.starts_at + make_interval(mins => x.duration_min))
        order by s.starts_at limit 60) x;
  return v;
end $$;
revoke execute on function public.family_booking_slots(uuid) from public, anon;
grant execute on function public.family_booking_slots(uuid) to authenticated;

-- Aile uygun saatten randevu alır (en çok 2 gelecek aile randevusu); uzmana bildirim
create or replace function public.family_book_slot(p_link_id uuid, p_starts_at timestamptz)
returns uuid language plpgsql security definer set search_path = '' as $$
declare l record; st public.clinic_session_settings; v uuid; v_room uuid;
begin
  if not public.family_link_active(p_link_id) then raise exception 'link_not_active' using errcode = '42501'; end if;
  if not exists (select 1 from json_array_elements(public.family_booking_slots(p_link_id)) e
                 where (e ->> 'starts_at')::timestamptz = p_starts_at) then
    raise exception 'slot_not_available' using errcode = '22023';
  end if;
  if (select count(*) from public.clinic_sessions where link_id = p_link_id and booked_by = 'family' and status = 'planned'
        and starts_at > now()) >= 2 then
    raise exception 'too_many_bookings' using errcode = '22023';
  end if;
  select * into l from public.clinic_links where id = p_link_id;
  st := public.clinic_session_settings_row(l.clinic_id);
  select a.room_id into v_room from public.clinic_availability a
   where a.clinician_id = coalesce(l.clinician_id, (select clinician_id from public.clinic_members where clinic_id = l.clinic_id and role = 'owner' and status = 'active' order by joined_at limit 1))
     and a.bookable and a.weekday = extract(isodow from (p_starts_at at time zone 'Europe/Istanbul'))
     and (p_starts_at at time zone 'Europe/Istanbul')::time >= a.start_time and (p_starts_at at time zone 'Europe/Istanbul')::time < a.end_time
   limit 1;
  insert into public.clinic_sessions (clinic_id, clinician_id, link_id, starts_at, duration_min, room_id, status, visible_to_family,
                                      booked_by, family_response, family_responded_at, created_by)
  values (l.clinic_id, coalesce(l.clinician_id, (select clinician_id from public.clinic_members where clinic_id = l.clinic_id and role = 'owner' and status = 'active' order by joined_at limit 1)),
          p_link_id, p_starts_at, st.slot_minutes, v_room, 'planned', true, 'family', 'ok', now(), auth.uid())
  returning id into v;
  perform public.session_notify_clinician(v, 'session_booked', 'Aile randevu aldı', public.session_when(p_starts_at));
  return v;
end $$;
revoke execute on function public.family_book_slot(uuid, timestamptz) from public, anon;
grant execute on function public.family_book_slot(uuid, timestamptz) to authenticated;

-- Paylaşım bitince gelecekteki planlı seanslar ve açık teklifler iptal olur, bekleme listesinden çıkar
create or replace function public.clinic_sessions_on_link_end() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status <> 'active' and old.status = 'active' then
    update public.clinic_sessions set status = 'cancelled', status_at = now(), cancel_reason = 'Paylaşım sona erdi', updated_at = now()
     where link_id = new.id and status in ('planned', 'offered') and starts_at > now();
    update public.clinic_waitlist set status = 'removed', updated_at = now() where link_id = new.id and status in ('waiting', 'offered');
  end if;
  return new;
end $$;
revoke execute on function public.clinic_sessions_on_link_end() from public, anon, authenticated;
drop trigger if exists clinic_sessions_on_link_end on public.clinic_links;
create trigger clinic_sessions_on_link_end after update of status on public.clinic_links
  for each row execute function public.clinic_sessions_on_link_end();

-- ---------------------------------------------------------------------
-- 6. Takvim aboneliği (E): uzmanın kendi takvimine tek yönlü, adsız .ics (Edge Function calendar-feed?t=<token>)
-- ---------------------------------------------------------------------
create or replace function public.clinic_calendar_feed(p_action text default 'get', p_initials boolean default null)
returns json language plpgsql security definer set search_path = '' as $$
declare f public.clinic_calendar_feeds;
begin
  if not public.clinician_access() then raise exception 'no_access' using errcode = '42501'; end if;
  if p_action = 'delete' then
    delete from public.clinic_calendar_feeds where clinician_id = auth.uid();
    return null;
  end if;
  select * into f from public.clinic_calendar_feeds where clinician_id = auth.uid();
  if f.clinician_id is null and p_action in ('get', 'rotate', 'set') then
    insert into public.clinic_calendar_feeds (clinician_id, clinic_id, token, show_initials)
    values (auth.uid(), public.my_clinic_id(), encode(extensions.gen_random_bytes(24), 'hex'), coalesce(p_initials, false))
    returning * into f;
  elsif p_action = 'rotate' then
    update public.clinic_calendar_feeds set token = encode(extensions.gen_random_bytes(24), 'hex'), rotated_at = now()
     where clinician_id = auth.uid() returning * into f;
  elsif p_action = 'set' and p_initials is not null then
    update public.clinic_calendar_feeds set show_initials = p_initials where clinician_id = auth.uid() returning * into f;
  end if;
  return json_build_object('token', f.token, 'show_initials', f.show_initials);
end $$;
revoke execute on function public.clinic_calendar_feed(text, boolean) from public, anon;
grant execute on function public.clinic_calendar_feed(text, boolean) to authenticated;

-- Yalnız Edge Function (service_role): belirteçle -30 … +180 gün; ad yerine tür, isteğe bağlı baş harf
create or replace function public.calendar_feed_events(p_token text)
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(json_build_object(
      'uid', s.id, 'start', s.starts_at, 'end', s.starts_at + make_interval(mins => s.duration_min),
      'summary', case when s.link_id is null then coalesce(nullif(s.title, ''), 'Takvim bloğu')
                      else public.session_kind_label(s.kind)
                           || case when f.show_initials then ' · ' || upper(left(public.child_name(l.child_id), 1)) || '.' else '' end end,
      'location', case s.mode when 'online' then 'Online' when 'home' then 'Ev ziyareti'
                    else coalesce(r.name || coalesce(' · ' || r.location, ''), '') end,
      'cancelled', s.status in ('cancelled', 'late_cancel', 'postponed')) order by s.starts_at), '[]')
  from public.clinic_calendar_feeds f
  join public.clinic_sessions s on s.clinician_id = f.clinician_id and s.status <> 'offered'
  left join public.clinic_links l on l.id = s.link_id
  left join public.clinic_rooms r on r.id = s.room_id
  where f.token = p_token and char_length(p_token) >= 32
    and s.starts_at between now() - interval '30 days' and now() + interval '180 days'
$$;
revoke execute on function public.calendar_feed_events(text) from public, anon, authenticated;
grant execute on function public.calendar_feed_events(text) to service_role;

-- ---------------------------------------------------------------------
-- 7. Dış takvimi okuma (E): uzmanın gizli iCal adresi (Google / Apple / Outlook), Edge Function calendar-import
-- ---------------------------------------------------------------------
create or replace function public.calendar_url_allowed(p_url text)
returns boolean language sql immutable set search_path = '' as $$
  select p_url ~* '^https://(calendar\.google\.com|p[0-9]{1,3}-caldav\.icloud\.com|outlook\.office365\.com|outlook\.live\.com)/[^\s]+$'
$$;
revoke execute on function public.calendar_url_allowed(text) from public, anon, authenticated;

create or replace function public.clinic_calendar_source_save(p_url text, p_label text default null, p_remove uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v uuid; u text := regexp_replace(btrim(coalesce(p_url, '')), '^webcal://', 'https://', 'i');
begin
  if not public.clinician_access() then raise exception 'no_access' using errcode = '42501'; end if;
  if p_remove is not null then
    delete from public.clinic_calendar_sources where id = p_remove and clinician_id = auth.uid() returning id into v;
    return v;
  end if;
  if not public.calendar_url_allowed(u) then raise exception 'calendar_url_not_allowed' using errcode = '22023'; end if;
  if (select count(*) from public.clinic_calendar_sources where clinician_id = auth.uid()) >= 3 then
    raise exception 'too_many_sources' using errcode = '22023';
  end if;
  insert into public.clinic_calendar_sources (clinician_id, clinic_id, label, url)
  values (auth.uid(), public.my_clinic_id(), nullif(btrim(p_label), ''), u) returning id into v;
  return v;
end $$;
revoke execute on function public.clinic_calendar_source_save(text, text, uuid) from public, anon;
grant execute on function public.clinic_calendar_source_save(text, text, uuid) to authenticated;

-- Yalnız Edge Function: uzmanın kaynakları
create or replace function public.calendar_import_sources(p_clinician uuid)
returns table (id uuid, url text) language sql stable security definer set search_path = '' as $$
  select s.id, s.url from public.clinic_calendar_sources s where s.clinician_id = p_clinician and public.calendar_url_allowed(s.url)
$$;
revoke execute on function public.calendar_import_sources(uuid) from public, anon, authenticated;
grant execute on function public.calendar_import_sources(uuid) to service_role;

-- Yalnız Edge Function: bir kaynağın penceredeki etkinliklerini yazar ([{uid, start, end, summary}]); seansa çevrilenler kalır
create or replace function public.calendar_import_store(p_source uuid, p_events jsonb, p_from timestamptz, p_to timestamptz, p_error text default null)
returns int language plpgsql security definer set search_path = '' as $$
declare src public.clinic_calendar_sources; v_n int := 0;
begin
  select * into src from public.clinic_calendar_sources where id = p_source;
  if src.id is null then return 0; end if;
  if p_error is not null then
    update public.clinic_calendar_sources set last_error = left(p_error, 200), last_synced_at = now() where id = p_source;
    return 0;
  end if;
  delete from public.clinic_external_events e
   where e.source_id = p_source and e.starts_at >= p_from and e.starts_at < p_to and e.session_id is null
     and not exists (select 1 from jsonb_array_elements(p_events) x
                     where x ->> 'uid' = e.uid and (x ->> 'start')::timestamptz = e.starts_at);
  insert into public.clinic_external_events (source_id, clinician_id, clinic_id, uid, starts_at, ends_at, summary, synced_at)
  select p_source, src.clinician_id, src.clinic_id, left(x ->> 'uid', 300), (x ->> 'start')::timestamptz,
         greatest((x ->> 'end')::timestamptz, (x ->> 'start')::timestamptz), left(x ->> 'summary', 200), now()
  from jsonb_array_elements(p_events) x
  where x ->> 'uid' is not null and (x ->> 'start') is not null
  limit 1000
  on conflict (source_id, uid, starts_at) do update set ends_at = excluded.ends_at, summary = excluded.summary, synced_at = now();
  get diagnostics v_n = row_count;
  update public.clinic_calendar_sources set last_synced_at = now(), last_error = null where id = p_source;
  return v_n;
end $$;
revoke execute on function public.calendar_import_store(uuid, jsonb, timestamptz, timestamptz, text) from public, anon, authenticated;
grant execute on function public.calendar_import_store(uuid, jsonb, timestamptz, timestamptz, text) to service_role;

-- Dış etkinliği seansa çevir ya da yok say
create or replace function public.clinic_external_event_mark(p_event uuid, p_link uuid default null, p_kind text default 'individual',
                                                             p_mode text default 'in_person', p_ignore boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare e public.clinic_external_events; v uuid;
begin
  select * into e from public.clinic_external_events where id = p_event and clinician_id = auth.uid();
  if e.id is null or not public.clinician_access() then raise exception 'event_not_found' using errcode = 'P0002'; end if;
  if p_ignore then
    update public.clinic_external_events set ignored = true where id = p_event;
    return null;
  end if;
  if e.session_id is not null then return e.session_id; end if;
  perform public.session_check_refs(p_link, null, null, null);
  insert into public.clinic_sessions (clinic_id, clinician_id, link_id, title, starts_at, duration_min, kind, mode, external_uid, created_by)
  values (e.clinic_id, e.clinician_id, p_link, case when p_link is null then left(e.summary, 80) end, e.starts_at,
          least(greatest((extract(epoch from (e.ends_at - e.starts_at)) / 60)::int, 5), 480),
          coalesce(p_kind, 'individual'), coalesce(p_mode, 'in_person'), e.uid, auth.uid())
  returning id into v;
  update public.clinic_external_events set session_id = v, ignored = false where id = p_event;
  return v;
end $$;
revoke execute on function public.clinic_external_event_mark(uuid, uuid, text, text, boolean) from public, anon;
grant execute on function public.clinic_external_event_mark(uuid, uuid, text, text, boolean) to authenticated;
