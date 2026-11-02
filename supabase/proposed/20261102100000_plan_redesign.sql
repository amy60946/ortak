-- Takip planı yeniden tasarımı (kullanıcı kararları 30 Ekim ve 2 Kasım 2026; akislar.md 12.1, veritabani.md 20):
--   1) Aile programı ↔ hedef bağı, çoklu (bir program birden çok hedefi destekler): care_module_goals.
--      Aileye gönderilen sürüm (pub) programın bağlı olduğu, aileye açık hedefleri de taşır; family_care_plan hedefe göre gruplanabilir.
--   2) Şablonlarım: hedef + bağlı programlar + rutinler, uzmanın verdiği adla; paylaşımı uzman seçer (yalnız ben / ekibim).
--   3) Tek gönderim: rutin ve görev önerileri önce TASLAK ('draft') yazılır, aile görmez; "Aileye gönder" (care_plan_publish)
--      taslakları 'pending' yapar ve plan + öneriler için TEK bildirim gider.
--   4) Ailede ekli görev için değişiklik önerisi (kind = 'change', target_task_id): uzman doğrudan değiştirmez,
--      ebeveyn "Uygula" derse ParentApp görevi günceller (görev çıkarma = bitiş tarihi). Geçmiş onaylar ve coin korunur.
--   5) family_care_plan: programların hedefleri (goal_ids) ve kabul edilen rutinlerin hedefi (routines).
-- Uzmanın kendi programı (serbest içerik) bu sürümde YOK (kullanıcı kararı 2 Kasım 2026: sistem içerikleri kalsın).
-- Tekrar çalıştırılabilir.

-- =====================================================================
-- 1. Aile programı ↔ hedef (çoklu)
-- =====================================================================
create table if not exists public.care_module_goals (
  module_id  uuid not null references public.care_modules (id) on delete cascade,
  goal_id    uuid not null references public.clinic_goals (id) on delete cascade,
  clinic_id  uuid not null references public.clinics (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (module_id, goal_id)
);
create index if not exists care_module_goals_goal_idx on public.care_module_goals (goal_id);
alter table public.care_module_goals enable row level security;

-- Program ve hedef aynı plana (aynı paylaşım ya da aynı davet taslağı) ait olmalı; klinik programdan alınır
create or replace function public.care_module_goals_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare m record; g record;
begin
  select clinic_id, link_id, invite_code into m from public.care_modules where id = new.module_id;
  select clinic_id, link_id, invite_code into g from public.clinic_goals where id = new.goal_id;
  if m.clinic_id is null or g.clinic_id is null or m.clinic_id <> g.clinic_id
     or m.link_id is distinct from g.link_id or m.invite_code is distinct from g.invite_code then
    raise exception 'Program ve hedef aynı takip planına ait olmalı';
  end if;
  new.clinic_id := m.clinic_id;
  return new;
end $$;
revoke execute on function public.care_module_goals_guard() from public, anon, authenticated;
drop trigger if exists care_module_goals_guard on public.care_module_goals;
create trigger care_module_goals_guard before insert or update on public.care_module_goals
  for each row execute function public.care_module_goals_guard();

-- Uzman: programı görebildiği/yazabildiği kadar (care_modules "modül: klinik" ile aynı koşul)
drop policy if exists "program hedefi: klinik" on public.care_module_goals;
create policy "program hedefi: klinik" on public.care_module_goals for all to authenticated
  using (exists (select 1 from public.care_modules m where m.id = module_id and m.clinic_id = public.my_clinic_id() and public.clinician_access()
                 and ((m.link_id is not null and public.clinic_link_visible(m.link_id)) or (m.invite_code is not null and public.clinic_invite_mine(m.invite_code)))))
  with check (exists (select 1 from public.care_modules m where m.id = module_id and m.clinic_id = public.my_clinic_id()
                 and ((m.link_id is not null and m.invite_code is null and public.clinic_link_mine(m.link_id))
                      or (m.link_id is null and m.invite_code is not null and public.clinic_invite_mine(m.invite_code)))));
revoke all on public.care_module_goals from anon;
grant select, insert, delete on public.care_module_goals to authenticated;

-- Aileye gönderilen sürüm: programın bağlı olduğu ve aileye açık hedefler de yazılır
create or replace function public.care_plan_snapshot(p_link_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  perform set_config('ortak.care_snapshot', 'on', true);
  update public.clinic_goals set pub = case when shared and not archived then jsonb_build_object(
           'title', title, 'description', description, 'domain', domain, 'measure', measure, 'baseline', baseline,
           'target', target, 'weeks', weeks, 'home_support', home_support, 'status', status, 'position', position) end
   where link_id = p_link_id;
  update public.care_modules m set pub = case when m.status <> 'planned' then jsonb_build_object(
           'title', m.title, 'aim', m.aim, 'practice', m.practice, 'checklist', m.checklist, 'status', m.status, 'position', m.position,
           'goal_ids', coalesce((select jsonb_agg(x.goal_id order by g.position, g.created_at)
                                   from public.care_module_goals x join public.clinic_goals g on g.id = x.goal_id
                                  where x.module_id = m.id and g.shared and not g.archived), '[]'::jsonb)) end
   where m.link_id = p_link_id;
  perform set_config('ortak.care_snapshot', 'off', true);
  select (select count(*) from public.clinic_goals where link_id = p_link_id and pub is not null)
       + (select count(*) from public.care_modules where link_id = p_link_id and pub is not null) into n;
  update public.clinic_links set plan_published_at = now() where id = p_link_id;
  return n;
end $$;
revoke execute on function public.care_plan_snapshot(uuid) from public, anon, authenticated;

-- =====================================================================
-- 2. Şablonlarım (hedef + programlar + rutinler)
-- =====================================================================
create table if not exists public.clinic_plan_templates (
  id          uuid primary key default gen_random_uuid(),
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  created_by  uuid references public.clinicians (id) on delete set null,
  title       text not null check (char_length(title) between 1 and 80),
  shared      boolean not null default false,          -- false: yalnız ben · true: ekibim (kliniğin uzmanları kullanır, düzenleyemez)
  content     jsonb not null,                          -- {"goal": {...}, "modules": [...], "routines": [...]}
  archived    boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists clinic_plan_templates_clinic_idx on public.clinic_plan_templates (clinic_id) where not archived;
alter table public.clinic_plan_templates enable row level security;

-- İçerik yalnız sistem kataloğunun alanlarını taşır; çocuğa ait kayıt (onay, GAS, not) şablona girmez.
-- goal: title (1–120), template_key, domain, measure, target, weeks (1–52), home_support, description
-- modules (≤ 12): template_key, title (1–120), aim, practice, checklist (≤ 8), weeks
-- routines (≤ 6): key (katalog kimliği ya da own:<clinic_routines.id>), title (1–60), icon
create or replace function public.clinic_plan_templates_check() returns trigger
language plpgsql security definer set search_path = '' as $$
declare c jsonb := new.content; g jsonb; x jsonb;
begin
  if tg_op = 'INSERT' then
    new.clinic_id := public.my_clinic_id();
    new.created_by := auth.uid();
    if new.clinic_id is null then raise exception 'Uzman hesabı gerekli'; end if;
  else
    new.clinic_id := old.clinic_id;
    new.created_by := old.created_by;
  end if;
  new.updated_at := now();
  if jsonb_typeof(c) <> 'object' or octet_length(c::text) > 20000 then raise exception 'Şablon içeriği geçersiz'; end if;
  g := c -> 'goal';
  if jsonb_typeof(g) <> 'object' or coalesce(char_length(g ->> 'title'), 0) not between 1 and 120
     or coalesce(char_length(g ->> 'home_support'), 0) > 600 or coalesce(char_length(g ->> 'description'), 0) > 600
     or (g ? 'weeks' and coalesce((g ->> 'weeks')::int, 0) not between 1 and 52) then
    raise exception 'Şablonun hedefi geçersiz';
  end if;
  if jsonb_typeof(coalesce(c -> 'modules', '[]')) <> 'array' or jsonb_array_length(coalesce(c -> 'modules', '[]')) > 12 then
    raise exception 'Şablonda en çok 12 program olur';
  end if;
  for x in select * from jsonb_array_elements(coalesce(c -> 'modules', '[]')) loop
    if jsonb_typeof(x) <> 'object' or coalesce(char_length(x ->> 'title'), 0) not between 1 and 120
       or (x ? 'checklist' and (jsonb_typeof(x -> 'checklist') <> 'array' or jsonb_array_length(x -> 'checklist') > 8)) then
      raise exception 'Şablondaki program geçersiz';
    end if;
  end loop;
  if jsonb_typeof(coalesce(c -> 'routines', '[]')) <> 'array' or jsonb_array_length(coalesce(c -> 'routines', '[]')) > 6 then
    raise exception 'Şablonda en çok 6 rutin olur';
  end if;
  for x in select * from jsonb_array_elements(coalesce(c -> 'routines', '[]')) loop
    if jsonb_typeof(x) <> 'object' or coalesce(char_length(x ->> 'key'), 0) not between 1 and 60
       or coalesce(char_length(x ->> 'title'), 0) not between 1 and 60 then
      raise exception 'Şablondaki rutin geçersiz';
    end if;
  end loop;
  return new;
end $$;
revoke execute on function public.clinic_plan_templates_check() from public, anon, authenticated;
drop trigger if exists clinic_plan_templates_check on public.clinic_plan_templates;
create trigger clinic_plan_templates_check before insert or update on public.clinic_plan_templates
  for each row execute function public.clinic_plan_templates_check();

-- Okur: kendi şablonları + ekibe açılanlar; sahip hepsini. Yazar: oluşturan ya da klinik sahibi (clinic_routines ile aynı)
drop policy if exists "şablon: klinik okur" on public.clinic_plan_templates;
create policy "şablon: klinik okur" on public.clinic_plan_templates for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or shared
              or exists (select 1 from public.clinicians m where m.id = auth.uid() and m.role = 'owner')));
drop policy if exists "şablon: uzman ekler" on public.clinic_plan_templates;
create policy "şablon: uzman ekler" on public.clinic_plan_templates for insert to authenticated
  with check (public.my_clinic_id() is not null and public.clinician_access());
drop policy if exists "şablon: sahibi düzenler" on public.clinic_plan_templates;
create policy "şablon: sahibi düzenler" on public.clinic_plan_templates for update to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or exists (select 1 from public.clinicians m where m.id = auth.uid() and m.role = 'owner')));
drop policy if exists "şablon: sahibi siler" on public.clinic_plan_templates;
create policy "şablon: sahibi siler" on public.clinic_plan_templates for delete to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and (created_by = auth.uid() or exists (select 1 from public.clinicians m where m.id = auth.uid() and m.role = 'owner')));
revoke all on public.clinic_plan_templates from anon;
grant select, insert, update, delete on public.clinic_plan_templates to authenticated;

-- =====================================================================
-- 3. Öneri taslağı + 4. değişiklik önerisi (alanlar)
-- =====================================================================
alter table public.clinic_task_suggestions drop constraint if exists clinic_task_suggestions_status_check;
alter table public.clinic_task_suggestions add constraint clinic_task_suggestions_status_check
  check (status in ('draft', 'pending', 'accepted', 'declined'));
alter table public.clinic_task_suggestions
  add column if not exists kind           text not null default 'new',
  add column if not exists target_task_id uuid references public.tasks (id) on delete cascade,
  add column if not exists change_remove  boolean not null default false;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'cts_kind_check') then
    alter table public.clinic_task_suggestions add constraint cts_kind_check check (
      (kind = 'new' and target_task_id is null and not change_remove) or (kind = 'change' and target_task_id is not null));
  end if;
end $$;
-- Bir görev için aynı anda tek açık (taslak ya da bekleyen) değişiklik önerisi
create unique index if not exists cts_one_open_change on public.clinic_task_suggestions (target_task_id)
  where kind = 'change' and status in ('draft', 'pending');
create index if not exists cts_link_draft_idx on public.clinic_task_suggestions (link_id) where status = 'draft';

-- Değişiklik önerisi yalnız bu paylaşımın çocuğuna atanmış, bu ailenin görevine yapılır
create or replace function public.cts_change_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'change' and not exists (
       select 1 from public.tasks t join public.task_assignments a on a.task_id = t.id
        where t.id = new.target_task_id and t.family_id = new.family_id and a.child_id = new.child_id) then
    raise exception 'Değişiklik önerisi yalnız bu çocuğun görevine yapılır';
  end if;
  return new;
end $$;
revoke execute on function public.cts_change_guard() from public, anon, authenticated;
drop trigger if exists cts_change_guard on public.clinic_task_suggestions;
create trigger cts_change_guard before insert or update of kind, target_task_id, family_id, child_id on public.clinic_task_suggestions
  for each row execute function public.cts_change_guard();

-- Uzman: taslak ya da bekleyen öneri ekler; taslak ya da bekleyeni geri çeker
drop policy if exists "öneri: klinik ekler" on public.clinic_task_suggestions;
create policy "öneri: klinik ekler" on public.clinic_task_suggestions for insert to authenticated
  with check (clinic_id = public.my_clinic_id() and public.clinic_link_mine(link_id) and status in ('draft', 'pending')
    and created_by = auth.uid() and task_id is null and decided_at is null
    and exists (select 1 from public.clinic_links l where l.id = clinic_task_suggestions.link_id
      and l.child_id = clinic_task_suggestions.child_id and l.family_id = clinic_task_suggestions.family_id));
drop policy if exists "öneri: klinik geri çeker" on public.clinic_task_suggestions;
create policy "öneri: klinik geri çeker" on public.clinic_task_suggestions for delete to authenticated
  using (clinic_id = public.my_clinic_id() and status in ('draft', 'pending') and public.clinician_access()
         and public.clinic_link_visible(link_id));
-- Aile taslağı görmez, taslağa karar veremez
drop policy if exists "öneri: aile okur" on public.clinic_task_suggestions;
create policy "öneri: aile okur" on public.clinic_task_suggestions for select to authenticated
  using (family_id = public.my_family_id() and status <> 'draft');
drop policy if exists "öneri: aile karar verir" on public.clinic_task_suggestions;
create policy "öneri: aile karar verir" on public.clinic_task_suggestions for update to authenticated
  using (family_id = public.my_family_id() and status <> 'draft')
  with check (family_id = public.my_family_id() and status <> 'draft'
    and (task_id is null or public.task_family(task_id) = family_id));

-- Uzman taslağı ya da bekleyen öneriyi günceller (karar verilmiş öneri değişmez); değişiklik önerisinde "görevi bitir" de
create or replace function public.clinic_update_suggestion(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  s public.clinic_task_suggestions%rowtype;
begin
  select * into s from public.clinic_task_suggestions where id = p_id for update;
  if not found or s.clinic_id is distinct from public.my_clinic_id() then raise exception 'Öneri bulunamadı'; end if;
  if s.status not in ('draft', 'pending') then raise exception 'Ebeveyn karar verdi; öneri artık değiştirilemez'; end if;
  if not public.clinic_link_mine(s.link_id) then raise exception 'Paylaşım sona erdi'; end if;
  update public.clinic_task_suggestions set
    title           = coalesce(nullif(trim(p ->> 'title'), ''), title),
    emoji           = coalesce(nullif(p ->> 'emoji', ''), emoji),
    skill           = coalesce(p ->> 'skill', skill),
    description     = coalesce(p ->> 'description', description),
    category        = case when p ? 'category' then p ->> 'category' else category end,
    template_key    = case when p ? 'template_key' then p ->> 'template_key' else template_key end,
    difficulty      = coalesce(p ->> 'difficulty', difficulty),
    coins           = case when p ? 'coins' then (p ->> 'coins')::integer else coins end,
    start_date      = case when p ? 'start_date' then (p ->> 'start_date')::date else start_date end,
    recurring       = coalesce((p ->> 'recurring')::boolean, recurring),
    repeat_kind     = coalesce(p ->> 'repeat_kind', repeat_kind),
    repeat_days     = case when p ? 'repeat_days'
                        then coalesce(array(select jsonb_array_elements_text(p -> 'repeat_days')::smallint), '{}') else repeat_days end,
    end_date        = case when p ? 'end_date' then (p ->> 'end_date')::date else end_date end,
    reminder        = case when p ? 'reminder' then p ->> 'reminder' else reminder end,
    requires_review = coalesce((p ->> 'requires_review')::boolean, requires_review),
    note            = coalesce(p ->> 'note', note),
    goal_id         = case when p ? 'goal_id' then (p ->> 'goal_id')::uuid else goal_id end,
    change_remove   = case when s.kind = 'change' and p ? 'change_remove' then (p ->> 'change_remove')::boolean else change_remove end,
    updated_at      = now()
  where id = p_id;
end $$;
revoke execute on function public.clinic_update_suggestion(uuid, jsonb) from public, anon;
grant execute on function public.clinic_update_suggestion(uuid, jsonb) to authenticated;

-- Bildirim: taslak sessiz; tek tek eklenen bekleyen öneri eskisi gibi bildirir (eski ClinicApp sürümleri);
-- taslaktan gönderilenleri care_plan_publish tek bildirimle duyurur. Karar bildirimi değişiklik önerisinde farklı metinle.
create or replace function public.suggestions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('suggestion_id', new.id, 'child_id', new.child_id);
  rid uuid;
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform public.notify_parents(new.family_id, 'clinic_suggestion',
        case when new.kind = 'change' then 'Uzmanın ' || nm || ' için değişiklik önerdi' else 'Uzmanın ' || nm || ' için görev önerdi' end,
        coalesce(new.emoji || ' ', '') || new.title, d, new.child_id);
    end if;
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
        case when new.kind = 'change' then
               case when new.status = 'accepted' then 'Değişiklik uygulandı: ' else 'Değişiklik şimdilik uygulanmadı: ' end
             else case when new.status = 'accepted' then 'Öneri kabul edildi: ' else 'Öneri şimdilik eklenmedi: ' end end || new.title,
        nm, d, null, new.child_id);
    end loop;
  end if;
  return null;
end $$;
revoke execute on function public.suggestions_notify() from public, anon, authenticated;

-- Paylaşım bitince gönderilmemiş taslaklar silinir (önceki uzmanın kayıtlarına girmesin)
create or replace function public.clinic_links_drop_drafts() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status <> 'active' and old.status = 'active' then
    delete from public.clinic_task_suggestions where link_id = new.id and status = 'draft';
  end if;
  return null;
end $$;
revoke execute on function public.clinic_links_drop_drafts() from public, anon, authenticated;
drop trigger if exists clinic_links_drop_drafts on public.clinic_links;
create trigger clinic_links_drop_drafts after update of status on public.clinic_links
  for each row execute function public.clinic_links_drop_drafts();

-- =====================================================================
-- 3b. Tek gönderim: plan + taslak öneriler birlikte, tek bildirim
-- =====================================================================
create or replace function public.care_plan_publish(p_link_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  before integer;
  n integer;
  k integer;
  ch integer;
  nm text;
begin
  if not public.clinic_link_mine(p_link_id) then raise exception 'Paylaşım bulunamadı'; end if;
  select * into l from public.clinic_links where id = p_link_id for update;
  nm := public.child_name(l.child_id);
  select (select count(*) from public.clinic_goals where link_id = p_link_id and pub is not null)
       + (select count(*) from public.care_modules where link_id = p_link_id and pub is not null) into before;
  n := public.care_plan_snapshot(p_link_id);
  -- taslak öneriler aileye açılır (bildirim burada tek seferde)
  select count(*) filter (where kind = 'new'), count(*) filter (where kind = 'change') into k, ch
    from public.clinic_task_suggestions where link_id = p_link_id and status = 'draft';
  update public.clinic_task_suggestions set status = 'pending', updated_at = now() where link_id = p_link_id and status = 'draft';
  if n = 0 and before = 0 and k + ch = 0 then
    raise exception 'Aileye gösterilecek bir şey yok: "Aile görür" açık bir hedef, etkin bir program ya da bir öneri ekle';
  end if;
  if k + ch > 0 then
    perform public.notify_parents(l.family_id, case when n > 0 then 'care_plan_shared' else 'clinic_suggestion' end,
      case when n > 0 then 'Takip planı güncellendi: ' || nm else 'Uzmanın ' || nm || ' için öneri gönderdi' end,
      concat_ws(' · ', case when n > 0 then 'Hedefler ve aile programı' end,
                       case when k > 0 then k || ' görev önerisi' end,
                       case when ch > 0 then ch || ' değişiklik önerisi' end) || ' Uzmanım bölümünde.',
      jsonb_build_object('link_id', l.id), l.child_id);
  elsif n > 0 and (l.plan_published_at is null or l.plan_published_at < now() - interval '10 minutes') then
    perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || nm,
      'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
  end if;
end $$;
revoke execute on function public.care_plan_publish(uuid) from public, anon;
grant execute on function public.care_plan_publish(uuid) to authenticated;

-- =====================================================================
-- 5. Ebeveynin gördüğü plan: programların hedefleri + kabul edilen rutinlerin hedefi
-- =====================================================================
create or replace function public.family_care_plan(p_link_id uuid)
returns json language sql stable security definer set search_path = '' as $$
  select case when public.family_link_active(p_link_id) then json_build_object(
    'goals', coalesce((select json_agg(json_build_object('id', g.id, 'title', g.pub ->> 'title', 'description', g.pub ->> 'description',
                         'domain', g.pub ->> 'domain', 'measure', g.pub ->> 'measure', 'baseline', g.pub ->> 'baseline',
                         'target', g.pub ->> 'target', 'weeks', g.pub -> 'weeks', 'home_support', g.pub ->> 'home_support',
                         'status', g.pub ->> 'status') order by (g.pub ->> 'position')::int, g.created_at)
                         from public.clinic_goals g where g.link_id = p_link_id and g.pub is not null), '[]'),
    'modules', coalesce((select json_agg(json_build_object('id', m.id, 'title', m.pub ->> 'title', 'aim', m.pub ->> 'aim',
                         'practice', m.pub ->> 'practice', 'checklist', m.pub -> 'checklist', 'status', m.pub ->> 'status',
                         'goal_ids', coalesce(m.pub -> 'goal_ids', '[]'::jsonb),
                         'practiced_week', (select count(*) from public.care_module_logs x where x.module_id = m.id
                                             and x.family_id = public.my_family_id() and x.practiced
                                             and x.day > (now() at time zone 'Europe/Istanbul')::date - 7
                                             and x.day <= (now() at time zone 'Europe/Istanbul')::date))
                         order by (m.pub ->> 'position')::int, m.created_at)
                         from public.care_modules m where m.link_id = p_link_id and m.pub is not null), '[]'),
    -- kabul edilmiş öneriler: rutin (aynı routine_group) ya da tek görev; hedef yalnız aileye gönderilmişse
    'routines', coalesce((select json_agg(r order by r.title) from (
                  select coalesce(s.routine_group, s.id) as id,
                         max(coalesce(s.routine_title, s.title)) as title,
                         max(coalesce(s.routine_icon, s.emoji)) as icon,
                         bool_or(s.routine_group is null) as single,
                         (array_agg(s.goal_id) filter (where s.goal_id is not null and exists (
                            select 1 from public.clinic_goals g where g.id = s.goal_id and g.pub is not null)))[1] as goal_id,
                         coalesce(array_agg(s.task_id) filter (where s.task_id is not null), '{}') as task_ids
                    from public.clinic_task_suggestions s
                   where s.link_id = p_link_id and s.status = 'accepted' and s.kind = 'new'
                   group by coalesce(s.routine_group, s.id)) r), '[]'))
  else null end
$$;
revoke execute on function public.family_care_plan(uuid) from public, anon;
grant execute on function public.family_care_plan(uuid) to authenticated;
