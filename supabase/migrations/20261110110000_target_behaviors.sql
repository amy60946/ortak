-- Hedef davranışlar ve bildirilen olaylar (kullanıcı isteği 9 Kasım 2026: rakibin "Target behaviors & reported incidents" ekranlarına sadık kal;
-- mevcut "Davranış hedefi" (clinic_goals) ve "Davranış kaydı" (abc_events) ile BİRLEŞTİRİLMEDİ, kullanıcı "sonra değerlendiririz" dedi).
-- Akış akislar.md 24, şema veritabani.md 33, durumlar.md P22.
--
-- 1. clinic_target_behaviors: uzman hedef davranışı tanımlar: ad, açıklama (aileden istenen), stratejiler (ailenin uygulayacağı / seçebileceği),
--    durum (baselining Başlangıç ölçümü · stable Durağan · improving İyileşiyor · regressing Geriliyor · mastered Ustalaştı),
--    ebeveyn kaydı açık mı, kayıt türü (frequency sıklık · abc öncül-sonuç · duration süre).
-- 2. behavior_incidents: ebeveynin bildirdiği olay. Bir hedef davranışa bağlı ya da değil ("Diğer bildirilen olaylar": davranışın adı serbest metin).
--    Olay tarihi, kayıt türüne göre sayı / öncül + sonuç / süre, denenen strateji ve çocuğun bu uygulamaya tepkisi (1 Kötü … 5 Çok iyi).
--    Aile yalnız family_incident_report ile yazar; uzman yalnız okur. Yeni olayda paylaşımın uzmanlarına behavior_incident bildirimi.
-- Sınır: tepki ebeveynin gözlemidir, puan ya da tanı değildir. Tekrar çalıştırılabilir.

-- ---------------------------------------------------------------- 1. hedef davranış
create table if not exists public.clinic_target_behaviors (
  id             uuid primary key default gen_random_uuid(),
  clinic_id      uuid not null references public.clinics (id) on delete cascade,
  link_id        uuid not null references public.clinic_links (id) on delete cascade,
  title          text not null check (char_length(trim(title)) between 1 and 80),
  description    text not null default '' check (char_length(description) <= 1000),
  strategies     jsonb not null default '[]' check (jsonb_typeof(strategies) = 'array' and jsonb_array_length(strategies) <= 10
                                                    and pg_column_size(strategies) <= 4000),
  status         text not null default 'baselining' check (status in ('baselining', 'stable', 'improving', 'regressing', 'mastered')),
  parent_logging boolean not null default true,
  log_type       text not null default 'frequency' check (log_type in ('frequency', 'abc', 'duration')),
  started_at     timestamptz not null default now(),
  archived       boolean not null default false,
  created_by     uuid references auth.users (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists clinic_target_behaviors_link_idx on public.clinic_target_behaviors (link_id);
alter table public.clinic_target_behaviors enable row level security;
revoke all on public.clinic_target_behaviors from anon, authenticated;
grant select, insert, update, delete on public.clinic_target_behaviors to authenticated;

-- ---------------------------------------------------------------- 2. olay
create table if not exists public.behavior_incidents (
  id             uuid primary key default gen_random_uuid(),
  link_id        uuid not null references public.clinic_links (id) on delete cascade,
  family_id      uuid not null references public.families (id) on delete cascade,
  child_id       uuid not null references public.children (id) on delete cascade,
  behavior_id    uuid references public.clinic_target_behaviors (id) on delete set null,   -- boş = "Diğer bildirilen olaylar"
  log_type       text check (log_type in ('frequency', 'abc', 'duration')),               -- bildirim anındaki tür (hedefe bağlıysa)
  other_behavior text not null default '' check (char_length(other_behavior) <= 120),     -- hedefe bağlı değilse davranışın adı
  occurred_at    timestamptz not null default now(),
  count          integer check (count between 1 and 1000),
  duration_min   integer check (duration_min between 0 and 1440),
  antecedent     text not null default '' check (char_length(antecedent) <= 500),
  consequence    text not null default '' check (char_length(consequence) <= 500),
  strategy       text not null default '' check (char_length(strategy) <= 200),            -- denenen stratejinin metni ("" = hiçbiri)
  response       smallint check (response between 1 and 5),                               -- çocuğun tepkisi: 1 Kötü … 5 Çok iyi
  reporter_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  reporter_name  text not null default '' check (char_length(reporter_name) <= 80),
  created_at     timestamptz not null default now()
);
create index if not exists behavior_incidents_link_idx on public.behavior_incidents (link_id, occurred_at desc);
create index if not exists behavior_incidents_behavior_idx on public.behavior_incidents (behavior_id, occurred_at desc);
create index if not exists behavior_incidents_family_idx on public.behavior_incidents (family_id);
alter table public.behavior_incidents enable row level security;
revoke all on public.behavior_incidents from anon, authenticated;
grant select on public.behavior_incidents to authenticated;

-- ---------------------------------------------------------------- 3. kurallar
-- Sunucu doldurur: oluşturan, güncelleme zamanı; hedef başka danışana / kliniğe taşınamaz; stratejiler kısa metin listesi
create or replace function public.clinic_target_behaviors_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select clinic_id from public.clinic_links where id = new.link_id) is distinct from new.clinic_id then
    raise exception 'Hedef davranış bu kliniğin paylaşımına ait değil' using errcode = 'check_violation';
  end if;
  if exists (select 1 from jsonb_array_elements(new.strategies) e
             where jsonb_typeof(e) <> 'string' or char_length(trim(e #>> '{}')) = 0 or char_length(e #>> '{}') > 200) then
    raise exception 'Strateji 1–200 karakterlik metin olmalı' using errcode = 'check_violation';
  end if;
  new.title := trim(new.title);
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  else
    if new.link_id is distinct from old.link_id or new.clinic_id is distinct from old.clinic_id then
      raise exception 'Hedef davranış başka bir danışana taşınamaz' using errcode = 'check_violation';
    end if;
    new.created_by := old.created_by;
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.clinic_target_behaviors_guard() from public, anon, authenticated;
drop trigger if exists clinic_target_behaviors_guard on public.clinic_target_behaviors;
create trigger clinic_target_behaviors_guard before insert or update on public.clinic_target_behaviors
  for each row execute function public.clinic_target_behaviors_guard();

-- Yeni olay → paylaşımın uzmanlarına (sorumlu + erişimi olanlar) bildirim
create or replace function public.behavior_incidents_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare rid uuid; v_name text;
begin
  select coalesce(nullif(b.title, ''), nullif(new.other_behavior, ''), 'Davranış olayı') into v_name
  from (select 1) x left join public.clinic_target_behaviors b on b.id = new.behavior_id;
  for rid in select * from public.clinic_link_recipients(new.link_id) loop
    perform public.notify(rid, 'clinic', 'behavior_incident', left('Yeni davranış olayı: ' || v_name, 120),
      left(coalesce(nullif(new.reporter_name, ''), 'Ebeveyn') || ' yeni bir davranış olayı bildirdi.', 300),
      jsonb_build_object('incident_id', new.id, 'behavior_id', new.behavior_id, 'link_id', new.link_id, 'child_id', new.child_id),
      null, new.child_id);
  end loop;
  return null;
end $$;
revoke execute on function public.behavior_incidents_notify() from public, anon, authenticated;
drop trigger if exists behavior_incidents_notify on public.behavior_incidents;
create trigger behavior_incidents_notify after insert on public.behavior_incidents
  for each row execute function public.behavior_incidents_notify();

-- ---------------------------------------------------------------- 4. RLS
drop policy if exists "hedef davranış: klinik" on public.clinic_target_behaviors;
create policy "hedef davranış: klinik" on public.clinic_target_behaviors for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_mine(link_id) and public.clinic_link_visible(link_id))
  with check (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_mine(link_id));
drop policy if exists "hedef davranış: aile okur" on public.clinic_target_behaviors;
create policy "hedef davranış: aile okur" on public.clinic_target_behaviors for select to authenticated
  using (not archived and parent_logging and public.family_link_active(link_id));

drop policy if exists "olay: klinik okur" on public.behavior_incidents;
create policy "olay: klinik okur" on public.behavior_incidents for select to authenticated
  using (exists (select 1 from public.clinic_links l where l.id = link_id and l.status = 'active'
                 and l.clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(l.id)));
drop policy if exists "olay: aile okur" on public.behavior_incidents;
create policy "olay: aile okur" on public.behavior_incidents for select to authenticated
  using (family_id = public.my_family_id());

-- ---------------------------------------------------------------- 5. işlevler
-- Aile: bildirebileceğim hedef davranışlar (etkin paylaşımlar; ebeveyn kaydı açık, arşivlenmemiş). Paylaşım başına liste.
create or replace function public.family_target_behaviors()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'link_id', l.id, 'child_id', l.child_id, 'child_name', c.name, 'clinic_id', l.clinic_id,
      'behaviors', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'title', b.title, 'description', b.description,
                     'strategies', b.strategies, 'log_type', b.log_type, 'status', b.status) order by b.started_at)
                   from public.clinic_target_behaviors b where b.link_id = l.id and not b.archived and b.parent_logging), '[]'::jsonb)
    ) order by l.consent_at), '[]'::jsonb)
  from public.clinic_links l left join public.children c on c.id = l.child_id
  where l.status = 'active' and l.family_id = public.my_family_id()
$$;
revoke execute on function public.family_target_behaviors() from public, anon;
grant execute on function public.family_target_behaviors() to authenticated;

-- Aile: olay bildir. p_behavior boşsa "diğer" olay (p_other_behavior zorunlu). Kayıt türüne göre: frequency → p_count,
-- abc → p_antecedent + p_consequence, duration → p_duration_min; diğer olayda hepsi isteğe bağlı. Olay zamanı ileri olamaz, en çok 30 gün geri.
create or replace function public.family_incident_report(p_link uuid, p_behavior uuid default null, p_occurred_at timestamptz default null,
  p_count int default null, p_duration_min int default null, p_antecedent text default '', p_consequence text default '',
  p_strategy text default '', p_response int default null, p_other_behavior text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare l record; v_bid uuid; v_type text; v_at timestamptz := coalesce(p_occurred_at, now()); v_id uuid; v_name text;
begin
  select * into l from public.clinic_links where id = p_link and status = 'active' and family_id = public.my_family_id();
  if l.id is null then raise exception 'link_not_found'; end if;
  if v_at > now() + interval '5 minutes' or v_at < now() - interval '30 days' then raise exception 'date_out_of_range'; end if;
  if p_response is not null and (p_response < 1 or p_response > 5) then raise exception 'response_invalid'; end if;
  if p_behavior is not null then
    select b.id, b.log_type into v_bid, v_type from public.clinic_target_behaviors b
     where b.id = p_behavior and b.link_id = l.id and not b.archived and b.parent_logging;
    if v_bid is null then raise exception 'behavior_not_found'; end if;
    if v_type = 'frequency' and (p_count is null or p_count < 1) then raise exception 'count_required'; end if;
    if v_type = 'abc' and (char_length(trim(coalesce(p_antecedent, ''))) = 0 or char_length(trim(coalesce(p_consequence, ''))) = 0) then
      raise exception 'abc_required';
    end if;
    if v_type = 'duration' and p_duration_min is null then raise exception 'duration_required'; end if;
  elsif char_length(trim(coalesce(p_other_behavior, ''))) = 0 then
    raise exception 'behavior_required';
  end if;
  select coalesce(nullif(trim(p.name), ''), p.nickname) into v_name from public.profiles p where p.id = auth.uid();
  insert into public.behavior_incidents (link_id, family_id, child_id, behavior_id, log_type, other_behavior, occurred_at, count, duration_min,
                                         antecedent, consequence, strategy, response, reporter_id, reporter_name)
  values (l.id, l.family_id, l.child_id, v_bid, v_type,
          case when v_bid is null then left(trim(p_other_behavior), 120) else '' end, v_at,
          case when v_bid is null or v_type = 'frequency' then p_count end,
          case when v_bid is null or v_type = 'duration' then p_duration_min end,
          case when v_bid is null or v_type = 'abc' then left(trim(coalesce(p_antecedent, '')), 500) else '' end,
          case when v_bid is null or v_type = 'abc' then left(trim(coalesce(p_consequence, '')), 500) else '' end,
          left(trim(coalesce(p_strategy, '')), 200), p_response, auth.uid(), left(coalesce(v_name, ''), 80))
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.family_incident_report(uuid, uuid, timestamptz, int, int, text, text, text, int, text) from public, anon;
grant execute on function public.family_incident_report(uuid, uuid, timestamptz, int, int, text, text, text, int, text) to authenticated;
