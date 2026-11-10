-- Ebeveyn eğitimi (kullanıcı isteği 9 Kasım 2026: rakibin "Parent training" ekranlarına ve kütüphanesine sadık kal; mevcut aile programı
-- (care_modules) ve 5 Kasım ders düzeniyle (parent_lessons) BİRLEŞTİRİLMEDİ, kullanıcı "sonra değerlendiririz" dedi). Akış akislar.md 23,
-- şema veritabani.md 32, durumlar.md P21.
--
-- 1. parent_trainings: uzmanın bir danışanın ebeveynine verdiği eğitim. Durum draft (Taslak, aile görmez) → active (Etkin) → mastered (Ustalaştı).
-- 2. parent_training_modules: öğrenme modülleri = kaynak kütüphanesi öğeleri (anahtar; içerik veri/ebeveyn_egitimi_kutuphane.json, uygulamalarda).
--    Ebeveyn modülü bitirince tamamlanma zamanı, test doğru sayısı ve yanıtları yazılır (family_training_module_complete).
-- 3. parent_training_tasks: uygulama görevleri; ölçüm frequency (sıklık) / accuracy (başarılı ve toplam deneme) / duration (dakika) / none.
-- 4. parent_training_logs: ebeveynin uygulama kaydı (family_training_log; bugün ve önceki 14 gün, Türkiye günü).
-- 5. parent_training_todos: hızlı yapılacaklar; ebeveyn işaretler (family_training_todo_set).
-- 6. parent_training_data: uzmanın seans gözlem verisi (ustalık ölçütüne doğru %); aile görmez.
-- Aile tablolara yazamaz, yalnız işlevlerle. Uzman tablolara RLS ile yazar (klinik, görebildiği etkin paylaşım).
-- Bildirim: eğitim Etkin olunca atanan ebeveyne (yoksa ailedeki ebeveynlere) training_assigned, Ustalaştı olunca training_mastered.
-- Sınır: eğitim içeriği bilgi amaçlıdır; test doğru sayısı ebeveynin kendi bilgi yoklamasıdır, çocuğa ait puan değildir.
-- Tekrar çalıştırılabilir.

-- ---------------------------------------------------------------- 1. eğitim
create table if not exists public.parent_trainings (
  id           uuid primary key default gen_random_uuid(),
  clinic_id    uuid not null references public.clinics (id) on delete cascade,
  link_id      uuid not null references public.clinic_links (id) on delete cascade,
  parent_id    uuid references auth.users (id) on delete set null,          -- atanan ebeveyn (boşsa ailedeki ebeveynler)
  parent_name  text not null default '' check (char_length(parent_name) <= 80),
  title        text not null default 'Adsız eğitim' check (char_length(title) between 1 and 200),   -- "Eğitim hedefi" (oluştururken yazılır, başlık olur)
  status       text not null default 'draft' check (status in ('draft', 'active', 'mastered')),
  criterion    text check (char_length(criterion) <= 400),                  -- ustalık ölçütü (uzman)
  started_at   timestamptz not null default now(),
  activated_at timestamptz,
  mastered_at  timestamptz,
  seen_at      timestamptz,                                                 -- uzmanın son bakışı ("Yeni etkinlik" noktası)
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists parent_trainings_link_idx on public.parent_trainings (link_id, status);
alter table public.parent_trainings enable row level security;
revoke all on public.parent_trainings from anon, authenticated;
grant select, insert, update, delete on public.parent_trainings to authenticated;

-- ---------------------------------------------------------------- 2. öğrenme modülleri
create table if not exists public.parent_training_modules (
  id           uuid primary key default gen_random_uuid(),
  training_id  uuid not null references public.parent_trainings (id) on delete cascade,
  item_key     text not null check (item_key ~ '^[a-z0-9_]{2,60}$'),
  position     integer not null default 0,
  archived     boolean not null default false,
  completed_at timestamptz,
  completed_by uuid references auth.users (id) on delete set null,
  reviewed_at  timestamptz,                                                -- uzman "incele" penceresini açtı (incelemeye hazır sayısı)
  correct      smallint check (correct between 0 and 50),
  total        smallint check (total between 0 and 50),
  answers      jsonb check (answers is null or (jsonb_typeof(answers) = 'array' and pg_column_size(answers) <= 20000)),
  created_at   timestamptz not null default now()
);
create unique index if not exists parent_training_modules_item_uq on public.parent_training_modules (training_id, item_key) where not archived;
alter table public.parent_training_modules enable row level security;
revoke all on public.parent_training_modules from anon, authenticated;
grant select, insert, update, delete on public.parent_training_modules to authenticated;

-- ---------------------------------------------------------------- 3. uygulama görevleri
create table if not exists public.parent_training_tasks (
  id           uuid primary key default gen_random_uuid(),
  training_id  uuid not null references public.parent_trainings (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 80),
  description  text not null default '' check (char_length(description) <= 600),
  measure      text not null default 'none' check (measure in ('frequency', 'accuracy', 'duration', 'none')),
  position     integer not null default 0,
  archived     boolean not null default false,
  created_at   timestamptz not null default now()
);
alter table public.parent_training_tasks enable row level security;
revoke all on public.parent_training_tasks from anon, authenticated;
grant select, insert, update, delete on public.parent_training_tasks to authenticated;

-- ---------------------------------------------------------------- 4. ebeveynin uygulama kaydı
create table if not exists public.parent_training_logs (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references public.parent_training_tasks (id) on delete cascade,
  training_id  uuid not null references public.parent_trainings (id) on delete cascade,
  family_id    uuid not null references public.families (id) on delete cascade,
  day          date not null,
  count        integer check (count between 0 and 10000),
  successes    integer check (successes between 0 and 10000),
  attempts     integer check (attempts between 0 and 10000),
  minutes      integer check (minutes between 0 and 1440),
  reflection   text not null default '' check (char_length(reflection) <= 255),
  created_by   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  check (successes is null or attempts is null or successes <= attempts)
);
create index if not exists parent_training_logs_task_idx on public.parent_training_logs (task_id, day desc);
create index if not exists parent_training_logs_training_idx on public.parent_training_logs (training_id);
alter table public.parent_training_logs enable row level security;
revoke all on public.parent_training_logs from anon, authenticated;
grant select on public.parent_training_logs to authenticated;

-- ---------------------------------------------------------------- 5. hızlı yapılacaklar
create table if not exists public.parent_training_todos (
  id           uuid primary key default gen_random_uuid(),
  training_id  uuid not null references public.parent_trainings (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 80),
  description  text not null default '' check (char_length(description) <= 255),
  position     integer not null default 0,
  archived     boolean not null default false,
  done_at      timestamptz,
  done_by      uuid references auth.users (id) on delete set null,
  rating       smallint check (rating between 1 and 5),                    -- "Nasıl geçti?" 1 Çok kötü … 5 Harika (ebeveyn)
  reflection   text not null default '' check (char_length(reflection) <= 140),
  reviewed_at  timestamptz,                                                -- uzman inceledi
  created_at   timestamptz not null default now()
);
alter table public.parent_training_todos enable row level security;
revoke all on public.parent_training_todos from anon, authenticated;
grant select, insert, update, delete on public.parent_training_todos to authenticated;

-- ---------------------------------------------------------------- 6. uzmanın gözlem verisi
create table if not exists public.parent_training_data (
  id           uuid primary key default gen_random_uuid(),
  training_id  uuid not null references public.parent_trainings (id) on delete cascade,
  day          date not null,
  value        smallint not null check (value between 0 and 100),
  created_by   uuid default auth.uid() references auth.users (id) on delete set null,
  created_at   timestamptz not null default now()
);
alter table public.parent_training_data enable row level security;
revoke all on public.parent_training_data from anon, authenticated;
grant select, insert, update, delete on public.parent_training_data to authenticated;

-- ---------------------------------------------------------------- 7. yardımcılar ve kurallar
-- Uzman bu eğitimi görebilir mi (kendi kliniği, görebildiği ETKİN paylaşım, üyelik açık)? Paylaşım bitince ebeveyn kayıtları kapanır.
create or replace function public.training_clinic_visible(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_trainings t join public.clinic_links l on l.id = t.link_id
                 where t.id = p_training and l.status = 'active' and t.clinic_id = public.my_clinic_id() and public.clinician_access()
                   and public.clinic_link_visible(t.link_id))
$$;
revoke execute on function public.training_clinic_visible(uuid) from public, anon;
grant execute on function public.training_clinic_visible(uuid) to authenticated;

-- Uzman bu eğitime yazabilir mi (etkin paylaşım kendi kliniğinde)?
create or replace function public.training_clinic_mine(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_trainings t
                 where t.id = p_training and t.clinic_id = public.my_clinic_id() and public.clinician_access()
                   and public.clinic_link_mine(t.link_id))
$$;
revoke execute on function public.training_clinic_mine(uuid) from public, anon;
grant execute on function public.training_clinic_mine(uuid) to authenticated;

-- Aile bu eğitimi görür mü (taslak değil, etkin paylaşım kendi ailesinde)?
create or replace function public.training_family_visible(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_trainings t
                 where t.id = p_training and t.status <> 'draft' and public.family_link_active(t.link_id))
$$;
revoke execute on function public.training_family_visible(uuid) from public, anon;
grant execute on function public.training_family_visible(uuid) to authenticated;

-- Sunucu doldurur: oluşturan, ebeveyn adı, durum zamanları; eğitim başka danışana / kliniğe taşınamaz; ebeveyn o ailedendir
create or replace function public.parent_trainings_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_family uuid; v_clinic uuid;
begin
  select l.family_id, l.clinic_id into v_family, v_clinic from public.clinic_links l where l.id = new.link_id;
  if v_clinic is distinct from new.clinic_id then raise exception 'Eğitim bu kliniğin paylaşımına ait değil' using errcode = 'check_violation'; end if;
  if new.parent_id is not null then
    if not exists (select 1 from public.profiles p where p.id = new.parent_id and p.family_id = v_family) then
      raise exception 'Ebeveyn bu aileden değil' using errcode = 'check_violation';
    end if;
    select coalesce(nullif(trim(p.name), ''), p.nickname) into new.parent_name from public.profiles p where p.id = new.parent_id;
  end if;
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    if new.status = 'active' then new.activated_at := now(); end if;
    if new.status = 'mastered' then new.activated_at := now(); new.mastered_at := now(); end if;
  else
    if new.link_id is distinct from old.link_id or new.clinic_id is distinct from old.clinic_id then
      raise exception 'Eğitim başka bir danışana taşınamaz' using errcode = 'check_violation';
    end if;
    new.created_by := old.created_by;
    if new.status = 'active' and old.status <> 'active' and new.activated_at is null then new.activated_at := now(); end if;
    if new.status = 'mastered' and old.status <> 'mastered' then new.mastered_at := now(); end if;
    if new.status <> 'mastered' then new.mastered_at := null; end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.parent_trainings_guard() from public, anon, authenticated;
drop trigger if exists parent_trainings_guard on public.parent_trainings;
create trigger parent_trainings_guard before insert or update on public.parent_trainings
  for each row execute function public.parent_trainings_guard();

-- Bildirim: Etkin → atanan ebeveyn (yoksa ailedeki ebeveynler); Ustalaştı → aynı kişiler
create or replace function public.parent_trainings_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_kind text; v_title text; v_body text; l record;
begin
  if tg_op = 'UPDATE' and new.status = old.status then return new; end if;
  if new.status = 'active' and (tg_op = 'INSERT' or old.status = 'draft') then
    v_kind := 'training_assigned'; v_title := 'Uzmanından yeni bir eğitim'; v_body := format('"%s" eğitimin hazır.', new.title);
  elsif new.status = 'mastered' then
    v_kind := 'training_mastered'; v_title := 'Eğitimi tamamladın'; v_body := format('Uzmanın "%s" eğitimini tamamlandı olarak işaretledi.', new.title);
  else
    return new;
  end if;
  select * into l from public.clinic_links where id = new.link_id;
  if l.status <> 'active' then return new; end if;
  insert into public.notifications (user_id, app, kind, title, body, data, family_id, child_id)
  select p.id, 'parent', v_kind, left(v_title, 120), left(v_body, 300),
         jsonb_build_object('training_id', new.id, 'link_id', new.link_id), l.family_id, l.child_id
  from public.profiles p
  where p.family_id = l.family_id and (new.parent_id is null or p.id = new.parent_id);
  return new;
end $$;
revoke execute on function public.parent_trainings_notify() from public, anon, authenticated;
drop trigger if exists parent_trainings_notify on public.parent_trainings;
create trigger parent_trainings_notify after insert or update of status on public.parent_trainings
  for each row execute function public.parent_trainings_notify();

-- Alt tablolarda eğitim değişmez; modülün tamamlama alanları ve yapılacağın işareti yalnız ebeveyn işleviyle (ortak.training_family_write) değişir
create or replace function public.parent_training_rows_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.training_id is distinct from old.training_id then
    raise exception 'Kayıt başka bir eğitime taşınamaz' using errcode = 'check_violation';
  end if;
  return new;
end $$;
revoke execute on function public.parent_training_rows_guard() from public, anon, authenticated;

create or replace function public.parent_training_modules_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('ortak.training_family_write', true) is not distinct from 'on' then return new; end if;
  if tg_op = 'INSERT' then
    new.completed_at := null; new.completed_by := null; new.answers := null; new.correct := null; new.total := null;
  else
    if new.training_id is distinct from old.training_id then raise exception 'Kayıt başka bir eğitime taşınamaz' using errcode = 'check_violation'; end if;
    if new.completed_at is distinct from old.completed_at or new.answers is distinct from old.answers or new.correct is distinct from old.correct
       or new.total is distinct from old.total or new.completed_by is distinct from old.completed_by then
      raise exception 'Modülün tamamlama bilgisini yalnız ebeveyn yazar' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.parent_training_modules_guard() from public, anon, authenticated;

create or replace function public.parent_training_todos_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('ortak.training_family_write', true) is not distinct from 'on' then return new; end if;
  if tg_op = 'INSERT' then
    new.done_at := null; new.done_by := null; new.rating := null; new.reflection := '';
  else
    if new.training_id is distinct from old.training_id then raise exception 'Kayıt başka bir eğitime taşınamaz' using errcode = 'check_violation'; end if;
    if new.done_at is distinct from old.done_at or new.done_by is distinct from old.done_by or new.rating is distinct from old.rating
       or new.reflection is distinct from old.reflection then
      raise exception 'Yapılacağı yalnız ebeveyn işaretler' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.parent_training_todos_guard() from public, anon, authenticated;

drop trigger if exists parent_training_modules_guard on public.parent_training_modules;
create trigger parent_training_modules_guard before insert or update on public.parent_training_modules
  for each row execute function public.parent_training_modules_guard();
drop trigger if exists parent_training_tasks_guard on public.parent_training_tasks;
create trigger parent_training_tasks_guard before update on public.parent_training_tasks
  for each row execute function public.parent_training_rows_guard();
drop trigger if exists parent_training_todos_guard on public.parent_training_todos;
create trigger parent_training_todos_guard before insert or update on public.parent_training_todos
  for each row execute function public.parent_training_todos_guard();
drop trigger if exists parent_training_data_guard on public.parent_training_data;
create trigger parent_training_data_guard before update on public.parent_training_data
  for each row execute function public.parent_training_rows_guard();

-- ---------------------------------------------------------------- 8. RLS
drop policy if exists "eğitim: klinik" on public.parent_trainings;
create policy "eğitim: klinik" on public.parent_trainings for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_mine(link_id) and public.clinic_link_visible(link_id))
  with check (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_mine(link_id));
drop policy if exists "eğitim: aile okur" on public.parent_trainings;
create policy "eğitim: aile okur" on public.parent_trainings for select to authenticated
  using (status <> 'draft' and public.family_link_active(link_id));

drop policy if exists "eğitim modülü: klinik" on public.parent_training_modules;
create policy "eğitim modülü: klinik" on public.parent_training_modules for all to authenticated
  using (public.training_clinic_visible(training_id)) with check (public.training_clinic_mine(training_id));
drop policy if exists "eğitim modülü: aile okur" on public.parent_training_modules;
create policy "eğitim modülü: aile okur" on public.parent_training_modules for select to authenticated
  using (not archived and public.training_family_visible(training_id));

drop policy if exists "eğitim görevi: klinik" on public.parent_training_tasks;
create policy "eğitim görevi: klinik" on public.parent_training_tasks for all to authenticated
  using (public.training_clinic_visible(training_id)) with check (public.training_clinic_mine(training_id));
drop policy if exists "eğitim görevi: aile okur" on public.parent_training_tasks;
create policy "eğitim görevi: aile okur" on public.parent_training_tasks for select to authenticated
  using (not archived and public.training_family_visible(training_id));

drop policy if exists "eğitim kaydı: klinik okur" on public.parent_training_logs;
create policy "eğitim kaydı: klinik okur" on public.parent_training_logs for select to authenticated
  using (public.training_clinic_visible(training_id));
drop policy if exists "eğitim kaydı: aile okur" on public.parent_training_logs;
create policy "eğitim kaydı: aile okur" on public.parent_training_logs for select to authenticated
  using (family_id = public.my_family_id());

drop policy if exists "eğitim yapılacağı: klinik" on public.parent_training_todos;
create policy "eğitim yapılacağı: klinik" on public.parent_training_todos for all to authenticated
  using (public.training_clinic_visible(training_id)) with check (public.training_clinic_mine(training_id));
drop policy if exists "eğitim yapılacağı: aile okur" on public.parent_training_todos;
create policy "eğitim yapılacağı: aile okur" on public.parent_training_todos for select to authenticated
  using (not archived and public.training_family_visible(training_id));

drop policy if exists "eğitim gözlemi: klinik" on public.parent_training_data;
create policy "eğitim gözlemi: klinik" on public.parent_training_data for all to authenticated
  using (public.training_clinic_visible(training_id)) with check (public.training_clinic_mine(training_id));

-- ---------------------------------------------------------------- 9. işlevler
-- Uzman: paylaşımdaki ailenin ebeveynleri (eğitimi kime atayacağını seçer). Yalnız ad; iletişim bilgisi yok.
create or replace function public.clinic_link_parents(p_link uuid)
returns table (user_id uuid, name text) language sql stable security definer set search_path = '' as $$
  select p.id, coalesce(nullif(trim(p.name), ''), p.nickname)
  from public.clinic_links l join public.profiles p on p.family_id = l.family_id
  where l.id = p_link and l.status = 'active' and l.clinic_id = public.my_clinic_id() and public.clinician_access()
    and public.clinic_link_visible(l.id)
  order by p.created_at
$$;
revoke execute on function public.clinic_link_parents(uuid) from public, anon;
grant execute on function public.clinic_link_parents(uuid) to authenticated;

-- Aile: eğitimlerim. Taslaklar yok; mine = bana atanmış (ya da kimseye özel değil). Kayıtlar yalnız bu ailenin, son 120 gün.
create or replace function public.family_trainings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x->>'started_at' desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', t.id, 'link_id', t.link_id, 'child_id', l.child_id, 'child_name', c.name, 'title', t.title, 'status', t.status,
      'started_at', t.started_at, 'activated_at', t.activated_at, 'mastered_at', t.mastered_at,
      'parent_id', t.parent_id, 'parent_name', t.parent_name, 'mine', (t.parent_id is null or t.parent_id = auth.uid()),
      'modules', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'item_key', m.item_key, 'position', m.position,
                  'completed_at', m.completed_at, 'correct', m.correct, 'total', m.total, 'answers', m.answers) order by m.position, m.created_at)
                  from public.parent_training_modules m where m.training_id = t.id and not m.archived), '[]'::jsonb),
      'tasks', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'title', k.title, 'description', k.description,
                  'measure', k.measure, 'position', k.position) order by k.position, k.created_at)
                  from public.parent_training_tasks k where k.training_id = t.id and not k.archived), '[]'::jsonb),
      'logs', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'task_id', g.task_id, 'day', g.day, 'count', g.count,
                  'successes', g.successes, 'attempts', g.attempts, 'minutes', g.minutes, 'reflection', g.reflection,
                  'created_by', g.created_by, 'created_at', g.created_at) order by g.day desc, g.created_at desc)
                  from public.parent_training_logs g where g.training_id = t.id and g.day >= current_date - 120), '[]'::jsonb),
      'todos', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'title', d.title, 'description', d.description,
                  'done_at', d.done_at, 'rating', d.rating, 'reflection', d.reflection, 'created_at', d.created_at) order by d.position, d.created_at)
                  from public.parent_training_todos d where d.training_id = t.id and not d.archived), '[]'::jsonb)
    ) as x
    from public.parent_trainings t
    join public.clinic_links l on l.id = t.link_id
    left join public.children c on c.id = l.child_id
    where t.status <> 'draft' and l.status = 'active' and l.family_id = public.my_family_id()
  ) s
$$;
revoke execute on function public.family_trainings() from public, anon;
grant execute on function public.family_trainings() to authenticated;

-- Ebeveyn bu eğitimde işlem yapabilir mi: etkin eğitim, kendi ailesinin etkin paylaşımı, kendisine (ya da herkese) atanmış
create or replace function public.training_family_actor(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_trainings t
                 where t.id = p_training and t.status = 'active' and public.family_link_active(t.link_id)
                   and (t.parent_id is null or t.parent_id = auth.uid()))
$$;
revoke execute on function public.training_family_actor(uuid) from public, anon;
grant execute on function public.training_family_actor(uuid) to authenticated;

-- Ebeveyn: modülü tamamla (okuma: yanıtsız; test: seçilen şıklar + doğru sayısı; açık uçlu: yanıt metinleri ≤ 1000).
-- Tamamlanmış modül yeniden tamamlanmaz (rakipteki gibi bitmiş öğe salt okunur açılır). Dönüş: modül kimliği.
create or replace function public.family_training_module_complete(p_module uuid, p_answers jsonb default null, p_correct int default null, p_total int default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare m record;
begin
  select * into m from public.parent_training_modules where id = p_module and not archived;
  if m.id is null or not public.training_family_actor(m.training_id) then raise exception 'training_not_found'; end if;
  if m.completed_at is not null then return m.id; end if;
  if p_answers is not null and (jsonb_typeof(p_answers) <> 'array' or exists (
       select 1 from jsonb_array_elements(p_answers) e where char_length(coalesce(e->>'text', '')) > 1000)) then
    raise exception 'answers_invalid';
  end if;
  if p_total is not null and (p_total < 0 or p_total > 50 or coalesce(p_correct, 0) < 0 or coalesce(p_correct, 0) > p_total) then
    raise exception 'score_invalid';
  end if;
  perform set_config('ortak.training_family_write', 'on', true);
  update public.parent_training_modules set completed_at = now(), completed_by = auth.uid(), answers = p_answers,
    correct = case when p_total is null then null else coalesce(p_correct, 0) end, total = p_total
  where id = m.id;
  perform set_config('ortak.training_family_write', 'off', true);
  return m.id;
end $$;
revoke execute on function public.family_training_module_complete(uuid, jsonb, int, int) from public, anon;
grant execute on function public.family_training_module_complete(uuid, jsonb, int, int) to authenticated;

-- Ebeveyn: uygulama kaydı (ölçüme göre alanlar; gün Türkiye saatiyle bugün ya da önceki 14 gün). Dönüş: kayıt kimliği.
create or replace function public.family_training_log(p_task uuid, p_day date default null, p_count int default null,
  p_successes int default null, p_attempts int default null, p_minutes int default null, p_reflection text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare k record; v_day date := coalesce(p_day, (now() at time zone 'Europe/Istanbul')::date); v_id uuid;
begin
  select * into k from public.parent_training_tasks where id = p_task and not archived;
  if k.id is null or not public.training_family_actor(k.training_id) then raise exception 'training_not_found'; end if;
  if v_day > (now() at time zone 'Europe/Istanbul')::date or v_day < (now() at time zone 'Europe/Istanbul')::date - 14 then
    raise exception 'day_out_of_range';
  end if;
  if k.measure = 'frequency' and p_count is null then raise exception 'count_required'; end if;
  if k.measure = 'accuracy' and (p_successes is null or p_attempts is null) then raise exception 'attempts_required'; end if;
  if k.measure = 'duration' and p_minutes is null then raise exception 'minutes_required'; end if;
  insert into public.parent_training_logs (task_id, training_id, family_id, day, count, successes, attempts, minutes, reflection, created_by)
  values (k.id, k.training_id, public.my_family_id(), v_day,
          case when k.measure = 'frequency' then p_count end,
          case when k.measure = 'accuracy' then p_successes end,
          case when k.measure = 'accuracy' then p_attempts end,
          case when k.measure = 'duration' then p_minutes end,
          left(coalesce(p_reflection, ''), 255), auth.uid())
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.family_training_log(uuid, date, int, int, int, int, text) from public, anon;
grant execute on function public.family_training_log(uuid, date, int, int, int, int, text) to authenticated;

-- Ebeveyn: hızlı yapılacağı tamamla ("Tamamlandı olarak işaretle" → "Nasıl geçti?" 1–5 + düşünce ≤ 140) ya da geri al (p_done false)
drop function if exists public.family_training_todo_set(uuid, boolean);
create or replace function public.family_training_todo_set(p_todo uuid, p_done boolean, p_rating int default null, p_reflection text default '')
returns void language plpgsql security definer set search_path = '' as $$
declare d record;
begin
  select * into d from public.parent_training_todos where id = p_todo and not archived;
  if d.id is null or not public.training_family_actor(d.training_id) then raise exception 'training_not_found'; end if;
  if p_rating is not null and (p_rating < 1 or p_rating > 5) then raise exception 'rating_invalid'; end if;
  perform set_config('ortak.training_family_write', 'on', true);
  update public.parent_training_todos
    set done_at = case when p_done then coalesce(done_at, now()) end,
        done_by = case when p_done then coalesce(done_by, auth.uid()) end,
        rating = case when p_done then p_rating end,
        reflection = case when p_done then left(coalesce(p_reflection, ''), 140) else '' end
  where id = d.id;
  perform set_config('ortak.training_family_write', 'off', true);
end $$;
revoke execute on function public.family_training_todo_set(uuid, boolean, int, text) from public, anon;
grant execute on function public.family_training_todo_set(uuid, boolean, int, text) to authenticated;

-- ---------------------------------------------------------------- 10. uzmana bildirim ve hatırlatma
-- Ebeveyn modülü tamamlayınca, uygulama kaydı girince, yapılacağı tamamlayınca paylaşımın uzmanlarına training_activity
create or replace function public.parent_training_activity_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare t record; l record; rid uuid; v_what text; v_who text;
begin
  if tg_table_name = 'parent_training_modules' then
    if new.completed_at is null or old.completed_at is not null then return null; end if;
    v_what := 'bir öğrenme modülünü tamamladı';
  elsif tg_table_name = 'parent_training_todos' then
    if new.done_at is null or old.done_at is not null then return null; end if;
    v_what := 'bir yapılacağı tamamladı';
  else
    v_what := 'bir uygulama kaydı girdi';
  end if;
  select * into t from public.parent_trainings where id = new.training_id;
  select * into l from public.clinic_links where id = t.link_id;
  if l.status <> 'active' then return null; end if;
  select coalesce(nullif(trim(p.name), ''), p.nickname) into v_who from public.profiles p where p.id = auth.uid();
  for rid in select * from public.clinic_link_recipients(l.id) loop
    perform public.notify(rid, 'clinic', 'training_activity', left('Ebeveyn eğitimi: ' || t.title, 120),
      left(coalesce(v_who, 'Ebeveyn') || ' ' || v_what || '.', 300),
      jsonb_build_object('training_id', t.id, 'link_id', l.id, 'child_id', l.child_id), null, l.child_id);
  end loop;
  return null;
end $$;
revoke execute on function public.parent_training_activity_notify() from public, anon, authenticated;
drop trigger if exists parent_training_modules_notify on public.parent_training_modules;
create trigger parent_training_modules_notify after update of completed_at on public.parent_training_modules
  for each row execute function public.parent_training_activity_notify();
drop trigger if exists parent_training_todos_notify on public.parent_training_todos;
create trigger parent_training_todos_notify after update of done_at on public.parent_training_todos
  for each row execute function public.parent_training_activity_notify();
drop trigger if exists parent_training_logs_notify on public.parent_training_logs;
create trigger parent_training_logs_notify after insert on public.parent_training_logs
  for each row execute function public.parent_training_activity_notify();

-- Uzman: "Hatırlatma gönder" (uygulama görevleri) → atanan ebeveyne (yoksa ailedeki ebeveynlere) training_reminder; eğitim başına 12 saatte bir.
-- Dönüş: true gönderildi, false 12 saat dolmadı.
create or replace function public.clinic_training_remind(p_training uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare t record; l record;
begin
  select * into t from public.parent_trainings where id = p_training and status = 'active';
  if t.id is null or not public.training_clinic_mine(t.id) then raise exception 'training_not_found'; end if;
  select * into l from public.clinic_links where id = t.link_id;
  if exists (select 1 from public.notifications n where n.kind = 'training_reminder' and n.data->>'training_id' = t.id::text
             and n.created_at > now() - interval '12 hours') then
    return false;
  end if;
  insert into public.notifications (user_id, app, kind, title, body, data, family_id, child_id)
  select p.id, 'parent', 'training_reminder', 'Uygulama görevlerin seni bekliyor',
         left(format('"%s" eğitimindeki uygulama görevlerini kaydetmeyi unutma.', t.title), 300),
         jsonb_build_object('training_id', t.id, 'link_id', t.link_id), l.family_id, l.child_id
  from public.profiles p where p.family_id = l.family_id and (t.parent_id is null or p.id = t.parent_id);
  return true;
end $$;
revoke execute on function public.clinic_training_remind(uuid) from public, anon;
grant execute on function public.clinic_training_remind(uuid) to authenticated;
