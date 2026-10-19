-- =====================================================================
-- Klinik SaaS (ClinicApp) – sunucu eklemeleri (ÖNERİ, henüz uygulanmadı)
-- Üç ürün aynı Supabase projesini kullanır: Pofi Adası (çocuk), ParentApp (ebeveyn), ClinicApp (uzman).
-- Önkoşul: supabase/migrations/* ve pofi-adasi M4 SQL'i (20261015000000_pofi_game.sql) uygulanmış olmalı.
-- Uygulama: Supabase panelinde SQL Editor > New query > bu dosyanın tamamı > Run. Tekrar çalıştırmak zarar vermez.
--
-- İlkeler
--  * Uzman bir çocuğun verisini YALNIZCA ebeveynin verdiği açık rızayla (clinic_links.status = 'active') görür.
--    Rıza ebeveyn tarafından her an geri alınabilir; geri alınınca erişim hemen biter.
--  * Uzman yalnızca OKUR: görev, tamamlama, ABC kaydı. Aileye görev ÖNERİR; ekleme kararı ebeveynindir.
--  * Posta (messages) ve coin defteri uzmanla paylaşılmaz.
--  * Klinik notları ve hedef puanları ailede görünmez (uzmanın çalışma alanı).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------

create table if not exists public.clinics (
  id             uuid primary key default gen_random_uuid(),
  name           text not null check (char_length(name) between 1 and 120),
  -- Gelir modeli 2: klinisyen başına aylık abonelik. Ödeme entegrasyonu gelince sunucu (service role) yazar.
  plan           text not null default 'trial' check (plan in ('trial', 'small', 'business', 'custom', 'inactive')),
  seat_limit     integer not null default 3 check (seat_limit between 1 and 1000),
  trial_ends_at  timestamptz not null default now() + interval '14 days',
  created_by     uuid references auth.users (id) on delete set null,
  created_at     timestamptz not null default now()
);

create table if not exists public.clinicians (
  id          uuid primary key references auth.users (id) on delete cascade,
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  name        text not null default '' check (char_length(name) <= 80),
  title       text not null default '' check (char_length(title) <= 80),   -- ör. Klinik Psikolog, Ergoterapist
  role        text not null default 'member' check (role in ('owner', 'member')),
  created_at  timestamptz not null default now()
);
create index if not exists clinicians_clinic_idx on public.clinicians (clinic_id);

-- Davet kodları: 'family' = aile bağlantısı (ebeveyn ParentApp'te girer), 'clinician' = ekibe katılım
create table if not exists public.clinic_invites (
  code          text primary key,
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  clinician_id  uuid not null references public.clinicians (id) on delete cascade,
  kind          text not null check (kind in ('family', 'clinician')),
  label         text not null default '' check (char_length(label) <= 60),  -- uzmanın kendi notu (ör. danışanın takma adı)
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default now() + interval '7 days',
  used_at       timestamptz,
  used_by       uuid references auth.users (id) on delete set null
);

-- Ebeveyn rızası: klinik ↔ çocuk bağlantısı
create table if not exists public.clinic_links (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  clinician_id  uuid references public.clinicians (id) on delete set null,   -- sorumlu uzman
  family_id     uuid not null references public.families (id) on delete cascade,
  child_id      uuid not null references public.children (id) on delete cascade,
  label         text not null default '',
  status        text not null default 'active' check (status in ('active', 'revoked')),
  consent_by    uuid references auth.users (id) on delete set null,
  consent_at    timestamptz not null default now(),
  revoked_at    timestamptz,
  revoked_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now()
);
create unique index if not exists clinic_links_active_uq on public.clinic_links (clinic_id, child_id) where status = 'active';
create index if not exists clinic_links_child_idx on public.clinic_links (child_id);
create index if not exists clinic_links_family_idx on public.clinic_links (family_id);

-- Uzman notları (ailede görünmez)
create table if not exists public.clinic_notes (
  id          uuid primary key default gen_random_uuid(),
  link_id     uuid not null references public.clinic_links (id) on delete cascade,
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  author_id   uuid references public.clinicians (id) on delete set null,
  body        text not null check (char_length(body) between 1 and 4000),
  created_at  timestamptz not null default now()
);
create index if not exists clinic_notes_link_idx on public.clinic_notes (link_id);

-- Hedefe ulaşma ölçeği (GAS): hedef + haftalık -2 … +2 puan
create table if not exists public.clinic_goals (
  id           uuid primary key default gen_random_uuid(),
  link_id      uuid not null references public.clinic_links (id) on delete cascade,
  clinic_id    uuid not null references public.clinics (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 120),
  description  text not null default '' check (char_length(description) <= 600),
  archived     boolean not null default false,
  created_by   uuid references public.clinicians (id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists clinic_goals_link_idx on public.clinic_goals (link_id);

create table if not exists public.goal_ratings (
  goal_id     uuid not null references public.clinic_goals (id) on delete cascade,
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  week        date not null,             -- haftanın pazartesisi
  rating      smallint not null check (rating between -2 and 2),
  note        text not null default '' check (char_length(note) <= 300),
  rated_by    uuid references public.clinicians (id) on delete set null,
  created_at  timestamptz not null default now(),
  primary key (goal_id, week)
);

-- ABC olay kaydı: ebeveyn zor bir anı kaydeder (Öncesi – Davranış – Sonucu). Bağlı uzman okur.
create table if not exists public.abc_events (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  child_id     uuid not null references public.children (id) on delete cascade,
  occurred_at  timestamptz not null default now(),
  antecedent   text not null default '' check (char_length(antecedent) <= 400),
  behavior     text not null check (char_length(behavior) between 1 and 400),
  consequence  text not null default '' check (char_length(consequence) <= 400),
  intensity    smallint not null default 3 check (intensity between 1 and 5),
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists abc_events_child_idx on public.abc_events (child_id, occurred_at);

-- Uzmanın aileye görev önerisi; ebeveyn kabul ederse ParentApp görevi kendisi oluşturur
create table if not exists public.clinic_task_suggestions (
  id          uuid primary key default gen_random_uuid(),
  link_id     uuid not null references public.clinic_links (id) on delete cascade,
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  family_id   uuid not null references public.families (id) on delete cascade,
  child_id    uuid not null references public.children (id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 120),
  emoji       text not null default '⭐',
  skill       text not null default '',
  difficulty  text not null default 'easy' check (difficulty in ('easy', 'medium', 'hard')),
  recurring   boolean not null default true,
  note        text not null default '' check (char_length(note) <= 300),
  status      text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_by  uuid references public.clinicians (id) on delete set null,
  created_at  timestamptz not null default now(),
  decided_at  timestamptz
);
create index if not exists clinic_task_suggestions_family_idx on public.clinic_task_suggestions (family_id, status);

-- Gelir modeli 1: aile aboneliği. Mağaza/ödeme olayları sunucu tarafında (service role) yazılır.
create table if not exists public.family_subscriptions (
  family_id   uuid primary key references public.families (id) on delete cascade,
  plan        text not null default 'free' check (plan in ('free', 'premium')),
  source      text not null default 'store' check (source in ('store', 'web', 'manual')),
  period_end  timestamptz,
  updated_at  timestamptz not null default now()
);

-- Raporlama: çocuğun "Yaptım" dediği an ve "Yapamam" nedeni (analiz belgesi, bölüm 6)
alter table public.completions add column if not exists child_done_at timestamptz;
alter table public.completions add column if not exists decline_reason text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'completions_decline_reason_check') then
    alter table public.completions add constraint completions_decline_reason_check
      check (decline_reason is null or decline_reason in ('hard', 'no_time', 'did_not_want', 'other'));
  end if;
end $$;

create or replace function public.completions_child_done_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.status in ('pending', 'approved', 'declined') and new.child_done_at is null
     and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    new.child_done_at := now();
  end if;
  return new;
end $$;
drop trigger if exists completions_child_done_at on public.completions;
create trigger completions_child_done_at before insert or update of status on public.completions
  for each row execute function public.completions_child_done_at();

-- ---------------------------------------------------------------------
-- Yardımcı fonksiyonlar
-- ---------------------------------------------------------------------

create or replace function public.my_clinic_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select clinic_id from public.clinicians where id = auth.uid()
$$;

-- Oturumdaki uzmanın kliniği bu çocuğa etkin rızayla bağlı mı?
create or replace function public.clinic_sees_child(p_child_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinic_links l
    join public.clinicians m on m.clinic_id = l.clinic_id
    where m.id = auth.uid() and l.child_id = p_child_id and l.status = 'active'
  )
$$;

create or replace function public.clinic_sees_task(p_task_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.task_assignments a
    where a.task_id = p_task_id and public.clinic_sees_child(a.child_id)
  )
$$;

create or replace function public.clinic_link_mine(p_link_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinic_links l
    where l.id = p_link_id and l.clinic_id = public.my_clinic_id() and l.status = 'active'
  )
$$;

-- Klinik aboneliği etkin mi (deneme süresi içinde ya da ücretli plan)?
create or replace function public.clinic_active(p_clinic_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.clinics c
    where c.id = p_clinic_id
      and (c.plan in ('small', 'business', 'custom') or (c.plan = 'trial' and c.trial_ends_at > now()))
  )
$$;

-- Aile premium mu? Kendi aboneliği ya da etkin bir kliniğe bağlı çocuğu varsa (Joon modeli: klinik üzerinden ücretsiz)
create or replace function public.family_premium(p_family_id uuid default null)
returns boolean language sql stable security definer set search_path = '' as $$
  with f as (select coalesce(p_family_id, public.my_family_id()) as id)
  select exists (
      select 1 from public.family_subscriptions s, f
      where s.family_id = f.id and s.plan = 'premium' and (s.period_end is null or s.period_end > now())
    ) or exists (
      select 1 from public.clinic_links l, f
      where l.family_id = f.id and l.status = 'active' and public.clinic_active(l.clinic_id)
    )
$$;

-- ---------------------------------------------------------------------
-- Kayıt: uzman hesabı aile oluşturmaz, klinik oluşturur ya da ekibe katılır
-- (handle_new_user'ın ebeveyn davranışı aynen korunur)
-- ---------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  cid uuid;
  inv public.clinic_invites%rowtype;
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  if meta ->> 'account' = 'clinician' then
    if nullif(trim(meta ->> 'team_code'), '') is not null then
      select * into inv from public.clinic_invites
        where code = upper(trim(meta ->> 'team_code')) and kind = 'clinician'
          and used_at is null and expires_at > now()
        for update;
      if not found then
        raise exception 'Ekip kodu geçersiz ya da süresi dolmuş';
      end if;
      if (select count(*) from public.clinicians where clinic_id = inv.clinic_id)
         >= (select seat_limit from public.clinics where id = inv.clinic_id) then
        raise exception 'Kliniğin uzman koltuğu dolu';
      end if;
      cid := inv.clinic_id;
      update public.clinic_invites set used_at = now(), used_by = new.id where code = inv.code;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, coalesce(trim(meta ->> 'name'), ''), coalesce(trim(meta ->> 'title'), ''), 'member');
    else
      insert into public.clinics (name, created_by)
      values (coalesce(nullif(trim(meta ->> 'clinic_name'), ''), 'Kliniğim'), new.id)
      returning id into cid;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, coalesce(trim(meta ->> 'name'), ''), coalesce(trim(meta ->> 'title'), ''), 'owner');
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
  return new;
end $$;

-- ---------------------------------------------------------------------
-- RPC'ler
-- ---------------------------------------------------------------------

-- Uzman: aile ya da ekip daveti kodu üretir
create or replace function public.clinic_create_invite(p_kind text default 'family', p_label text default '')
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  new_code text;
  exp timestamptz := now() + interval '7 days';
begin
  select * into me from public.clinicians where id = auth.uid();
  if not found then raise exception 'Yalnızca uzman hesabı'; end if;
  if p_kind not in ('family', 'clinician') then raise exception 'Geçersiz davet türü'; end if;
  if p_kind = 'clinician' and me.role <> 'owner' then raise exception 'Ekibe yalnızca klinik sahibi davet eder'; end if;
  loop
    new_code := public.random_code();
    exit when not exists (select 1 from public.clinic_invites where code = new_code)
          and not exists (select 1 from public.invite_codes where code = new_code);
  end loop;
  insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at)
  values (new_code, me.clinic_id, me.id, p_kind, left(coalesce(p_label, ''), 60), exp);
  return json_build_object('code', new_code, 'expires_at', exp);
end $$;

-- Ebeveyn: kodu girince rıza vermeden önce kimin isteği olduğunu görür
create or replace function public.clinic_invite_preview(p_code text)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  r record;
begin
  if public.my_family_id() is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  select c.name as clinic, m.name as clinician, m.title, i.expires_at into r
  from public.clinic_invites i
  join public.clinics c on c.id = i.clinic_id
  join public.clinicians m on m.id = i.clinician_id
  where i.code = upper(trim(p_code)) and i.kind = 'family' and i.used_at is null and i.expires_at > now();
  if not found then raise exception 'Kod geçersiz ya da süresi dolmuş'; end if;
  return json_build_object('clinic', r.clinic, 'clinician', r.clinician, 'title', r.title);
end $$;

-- Ebeveyn: açık rıza ile çocuğunu kliniğe bağlar
create or replace function public.redeem_clinic_invite(p_code text, p_child_id uuid)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  lid uuid;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if not exists (select 1 from public.children where id = p_child_id and family_id = fid) then
    raise exception 'Çocuk bulunamadı';
  end if;
  select * into inv from public.clinic_invites
    where code = upper(trim(p_code)) and kind = 'family' and used_at is null and expires_at > now()
    for update;
  if not found then raise exception 'Kod geçersiz ya da süresi dolmuş'; end if;
  if exists (select 1 from public.clinic_links where clinic_id = inv.clinic_id and child_id = p_child_id and status = 'active') then
    raise exception 'Bu çocuk bu klinikle zaten paylaşılıyor';
  end if;
  insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id, label, consent_by)
  values (inv.clinic_id, inv.clinician_id, fid, p_child_id, inv.label, auth.uid())
  returning id into lid;
  update public.clinic_invites set used_at = now(), used_by = auth.uid() where code = inv.code;
  return json_build_object('link_id', lid);
end $$;

-- Ebeveyn ya da uzman: paylaşımı sonlandırır
create or replace function public.revoke_clinic_link(p_link_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.clinic_links
     set status = 'revoked', revoked_at = now(), revoked_by = auth.uid()
   where id = p_link_id and status = 'active'
     and (family_id = public.my_family_id() or clinic_id = public.my_clinic_id());
  if not found then raise exception 'Paylaşım bulunamadı'; end if;
end $$;

-- Ebeveyn: ailemin etkin paylaşımları (klinik ve uzman adıyla)
create or replace function public.family_clinic_links()
returns table (link_id uuid, child_id uuid, clinic text, clinician text, title text, consent_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select l.id, l.child_id, c.name, coalesce(m.name, ''), coalesce(m.title, ''), l.consent_at
  from public.clinic_links l
  join public.clinics c on c.id = l.clinic_id
  left join public.clinicians m on m.id = l.clinician_id
  where l.family_id = public.my_family_id() and l.status = 'active'
  order by l.consent_at
$$;

-- Uzman: kendi kaydı ve kliniği (ilk açılışta)
create or replace function public.clinician_me()
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'id', m.id, 'name', m.name, 'title', m.title, 'role', m.role,
    'clinic_id', c.id, 'clinic', c.name, 'plan', c.plan, 'seat_limit', c.seat_limit,
    'trial_ends_at', c.trial_ends_at, 'active', public.clinic_active(c.id))
  from public.clinicians m join public.clinics c on c.id = m.clinic_id
  where m.id = auth.uid()
$$;

-- ---------------------------------------------------------------------
-- Satır düzeyi güvenlik
-- ---------------------------------------------------------------------

alter table public.clinics                  enable row level security;
alter table public.clinicians               enable row level security;
alter table public.clinic_invites           enable row level security;
alter table public.clinic_links             enable row level security;
alter table public.clinic_notes             enable row level security;
alter table public.clinic_goals             enable row level security;
alter table public.goal_ratings             enable row level security;
alter table public.abc_events               enable row level security;
alter table public.clinic_task_suggestions  enable row level security;
alter table public.family_subscriptions     enable row level security;

drop policy if exists "klinik: üyeler okur" on public.clinics;
create policy "klinik: üyeler okur" on public.clinics for select to authenticated
  using (id = public.my_clinic_id());
drop policy if exists "klinik: sahip adını değiştirir" on public.clinics;
create policy "klinik: sahip adını değiştirir" on public.clinics for update to authenticated
  using (id = public.my_clinic_id() and exists (select 1 from public.clinicians where id = auth.uid() and role = 'owner'))
  with check (id = public.my_clinic_id());
-- Plan/koltuk sütunlarını istemci değiştiremez
revoke update on public.clinics from authenticated;
grant update (name) on public.clinics to authenticated;

drop policy if exists "uzman: ekip okur" on public.clinicians;
create policy "uzman: ekip okur" on public.clinicians for select to authenticated
  using (clinic_id = public.my_clinic_id());
drop policy if exists "uzman: kendini günceller" on public.clinicians;
create policy "uzman: kendini günceller" on public.clinicians for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.clinicians from authenticated;
grant update (name, title) on public.clinicians to authenticated;

drop policy if exists "davet: klinik okur" on public.clinic_invites;
create policy "davet: klinik okur" on public.clinic_invites for select to authenticated
  using (clinic_id = public.my_clinic_id());

drop policy if exists "bağlantı: klinik okur" on public.clinic_links;
create policy "bağlantı: klinik okur" on public.clinic_links for select to authenticated
  using (clinic_id = public.my_clinic_id());
drop policy if exists "bağlantı: aile okur" on public.clinic_links;
create policy "bağlantı: aile okur" on public.clinic_links for select to authenticated
  using (family_id = public.my_family_id());
drop policy if exists "bağlantı: klinik etiketi" on public.clinic_links;
create policy "bağlantı: klinik etiketi" on public.clinic_links for update to authenticated
  using (clinic_id = public.my_clinic_id() and status = 'active')
  with check (clinic_id = public.my_clinic_id());
revoke update on public.clinic_links from authenticated;
grant update (label, clinician_id) on public.clinic_links to authenticated;

drop policy if exists "not: klinik" on public.clinic_notes;
create policy "not: klinik" on public.clinic_notes for all to authenticated
  using (clinic_id = public.my_clinic_id())
  with check (clinic_id = public.my_clinic_id() and public.clinic_link_mine(link_id) and author_id = auth.uid());

drop policy if exists "hedef: klinik" on public.clinic_goals;
create policy "hedef: klinik" on public.clinic_goals for all to authenticated
  using (clinic_id = public.my_clinic_id())
  with check (clinic_id = public.my_clinic_id() and public.clinic_link_mine(link_id));

drop policy if exists "hedef puanı: klinik" on public.goal_ratings;
create policy "hedef puanı: klinik" on public.goal_ratings for all to authenticated
  using (clinic_id = public.my_clinic_id())
  with check (clinic_id = public.my_clinic_id()
    and exists (select 1 from public.clinic_goals g where g.id = goal_ratings.goal_id and g.clinic_id = public.my_clinic_id()));

drop policy if exists "abc: aile" on public.abc_events;
create policy "abc: aile" on public.abc_events for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id() and public.child_family(child_id) = family_id);
drop policy if exists "abc: bağlı klinik okur" on public.abc_events;
create policy "abc: bağlı klinik okur" on public.abc_events for select to authenticated
  using (public.clinic_sees_child(child_id));

drop policy if exists "öneri: klinik" on public.clinic_task_suggestions;
create policy "öneri: klinik" on public.clinic_task_suggestions for select to authenticated
  using (clinic_id = public.my_clinic_id());
drop policy if exists "öneri: klinik ekler" on public.clinic_task_suggestions;
create policy "öneri: klinik ekler" on public.clinic_task_suggestions for insert to authenticated
  with check (clinic_id = public.my_clinic_id() and public.clinic_link_mine(link_id) and status = 'pending'
    and exists (select 1 from public.clinic_links l where l.id = clinic_task_suggestions.link_id
      and l.child_id = clinic_task_suggestions.child_id and l.family_id = clinic_task_suggestions.family_id));
drop policy if exists "öneri: klinik geri çeker" on public.clinic_task_suggestions;
create policy "öneri: klinik geri çeker" on public.clinic_task_suggestions for delete to authenticated
  using (clinic_id = public.my_clinic_id() and status = 'pending');
drop policy if exists "öneri: aile okur" on public.clinic_task_suggestions;
create policy "öneri: aile okur" on public.clinic_task_suggestions for select to authenticated
  using (family_id = public.my_family_id());
drop policy if exists "öneri: aile karar verir" on public.clinic_task_suggestions;
create policy "öneri: aile karar verir" on public.clinic_task_suggestions for update to authenticated
  using (family_id = public.my_family_id()) with check (family_id = public.my_family_id());
revoke update on public.clinic_task_suggestions from authenticated;
grant update (status, decided_at) on public.clinic_task_suggestions to authenticated;

drop policy if exists "abonelik: aile okur" on public.family_subscriptions;
create policy "abonelik: aile okur" on public.family_subscriptions for select to authenticated
  using (family_id = public.my_family_id());

-- Bağlı uzmanın OKUMA erişimi (mevcut aile politikalarına ek; politikalar VEYA ile birleşir)
drop policy if exists "çocuk: bağlı klinik okur" on public.children;
create policy "çocuk: bağlı klinik okur" on public.children for select to authenticated
  using (public.clinic_sees_child(id));
drop policy if exists "görev: bağlı klinik okur" on public.tasks;
create policy "görev: bağlı klinik okur" on public.tasks for select to authenticated
  using (public.clinic_sees_task(id));
drop policy if exists "atama: bağlı klinik okur" on public.task_assignments;
create policy "atama: bağlı klinik okur" on public.task_assignments for select to authenticated
  using (public.clinic_sees_child(child_id));
drop policy if exists "tamamlama: bağlı klinik okur" on public.completions;
create policy "tamamlama: bağlı klinik okur" on public.completions for select to authenticated
  using (public.clinic_sees_child(child_id));

-- Yeni tablolar Realtime'a (uzman paneli ve ParentApp canlı güncellensin)
do $$
declare t text;
begin
  foreach t in array array['clinic_links', 'clinic_task_suggestions', 'abc_events'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
