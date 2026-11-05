-- Gelişim › aile üyesi: ebeveyn eğitimi (kullanıcı kararları 5 Kasım 2026; sozlesme/akislar.md 22, ekonomi.md 5C,
-- durumlar.md P20). Benchmark (Triple P, PCIT ev ödevi, Good Inside, Kinedu, Lovevery, NOCD, Manatee, Duolingo/Khan,
-- Joon Health) ParentApp penceresinde; işleyiş referansı, içerik kopyalanmaz.
--
-- 1. parent_lessons: kısa ders kataloğu (sistem içeriği, kişisel veri yok). İçerik sonra hazırlanır; o zamana kadar boş,
--    ParentApp "Yakında" kartı gösterir. Yalnız 'published' (ve öğrenilmiş satırların adı için 'retired') okunur.
-- 2. parent_lesson_assignments: uzmanın aileye önerdiği ders (paylaşım = clinic_links satırı). Uzman RPC ile atar/geri çeker;
--    aile etkin paylaşımdaki atamayı görür ("Uzmanının önerisi"). Ebeveynlere lesson_assigned bildirimi.
-- 3. parent_lesson_progress: ebeveynin dersi (kendi seçtiği ya da önerilen). Kişi başına en çok bir 'current'
--    ("Bu haftanın becerisi"); yenisi başlayınca eskisi uygulandıysa 'learned' ("Öğrendiğin beceriler"), uygulanmadıysa 'paused'.
-- 4. parent_lesson_practice: "Bugün uyguladım" günleri (Türkiye saatiyle; bugün ve önceki 6 gün; ileri tarih yok).
--    Güneş Taşı uygulanan GÜNE verilir: o hafta (Pzt–Paz) uygulanan farklı gün sayısı kadar, haftada en çok 3
--    (parent_stone_ledger 'lesson' / 'lesson_undo'; her işaretten sonra hafta yeniden hesaplanır). Dersi açmak taş getirmez.
-- 5. Uzman yalnız KENDİ önerdiği derslerde, öneri tarihinden sonraki açılma / uygulama günlerini görür (clinic_parent_lessons);
--    ebeveynin kendi seçtiği dersler uzmana gitmez. Paylaşım bitince uzman göremez.
-- Sınır: dersler bilgi amaçlıdır, tanı ya da tedavi değildir; puan, seri ya da "kaçırdın" yok.
-- Tekrar çalıştırılabilir.

-- ---------------------------------------------------------------- 1. ders kataloğu
create table if not exists public.parent_lessons (
  key        text primary key check (key ~ '^[a-z0-9_]{2,40}$'),
  title      text not null check (char_length(title) between 1 and 80),       -- becerinin adı
  summary    text not null default '' check (char_length(summary) <= 200),   -- kartta tek satır
  minutes    smallint not null default 4 check (minutes between 1 and 15),   -- okuma süresi (3–5 dk hedef)
  body_md    text not null default '' check (char_length(body_md) <= 8000),  -- ders (sade markdown: başlık, liste, kalın)
  try_text   text not null default '' check (char_length(try_text) <= 400),  -- "Bu hafta dene"
  domain     text not null default 'general' check (domain ~ '^[a-z_]{2,30}$'),
  sources    text not null default '' check (char_length(sources) <= 1000), -- içeriğin dayandığı kaynaklar
  position   integer not null default 0,
  status     text not null default 'draft' check (status in ('draft', 'published', 'retired')),
  updated_at timestamptz not null default now()
);
alter table public.parent_lessons enable row level security;
drop policy if exists "ders: yayımlananı herkes okur" on public.parent_lessons;
create policy "ders: yayımlananı herkes okur" on public.parent_lessons for select to authenticated
  using (status in ('published', 'retired'));
revoke insert, update, delete, truncate on public.parent_lessons from anon, authenticated;

-- ---------------------------------------------------------------- 2. uzmanın önerisi
create table if not exists public.parent_lesson_assignments (
  id           uuid primary key default gen_random_uuid(),
  clinic_id    uuid not null references public.clinics (id) on delete cascade,
  link_id      uuid not null references public.clinic_links (id) on delete cascade,
  family_id    uuid not null references public.families (id) on delete cascade,
  lesson_key   text not null references public.parent_lessons (key) on delete cascade,
  note         text not null default '' check (char_length(note) <= 300),   -- uzmanın aileye kısa notu
  status       text not null default 'active' check (status in ('active', 'withdrawn')),
  assigned_by  uuid references public.clinicians (id) on delete set null,
  created_at   timestamptz not null default now(),
  withdrawn_at timestamptz
);
create unique index if not exists parent_lesson_assignments_active_uq
  on public.parent_lesson_assignments (link_id, lesson_key) where status = 'active';
create index if not exists parent_lesson_assignments_family_idx on public.parent_lesson_assignments (family_id, status);
alter table public.parent_lesson_assignments enable row level security;
drop policy if exists "ders önerisi: aile okur" on public.parent_lesson_assignments;
create policy "ders önerisi: aile okur" on public.parent_lesson_assignments for select to authenticated
  using (status = 'active' and public.family_link_active(link_id));
drop policy if exists "ders önerisi: klinik okur" on public.parent_lesson_assignments;
create policy "ders önerisi: klinik okur" on public.parent_lesson_assignments for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(link_id));
revoke insert, update, delete, truncate on public.parent_lesson_assignments from anon, authenticated;

-- ---------------------------------------------------------------- 3. ebeveynin dersleri
create table if not exists public.parent_lesson_progress (
  user_id       uuid not null references auth.users (id) on delete cascade,
  lesson_key    text not null references public.parent_lessons (key) on delete cascade,
  family_id     uuid not null references public.families (id) on delete cascade,
  assignment_id uuid references public.parent_lesson_assignments (id) on delete set null,
  status        text not null default 'current' check (status in ('current', 'learned', 'paused')),
  started_at    timestamptz not null default now(),
  opened_at     timestamptz,
  learned_at    timestamptz,
  primary key (user_id, lesson_key)
);
create unique index if not exists parent_lesson_progress_current_uq on public.parent_lesson_progress (user_id) where status = 'current';
create index if not exists parent_lesson_progress_family_idx on public.parent_lesson_progress (family_id);
alter table public.parent_lesson_progress enable row level security;
drop policy if exists "ders kaydı: aile okur" on public.parent_lesson_progress;
create policy "ders kaydı: aile okur" on public.parent_lesson_progress for select to authenticated
  using (family_id = public.my_family_id());
revoke insert, update, delete, truncate on public.parent_lesson_progress from anon, authenticated;

-- ---------------------------------------------------------------- 4. uygulama günleri
create table if not exists public.parent_lesson_practice (
  user_id    uuid not null references auth.users (id) on delete cascade,
  lesson_key text not null references public.parent_lessons (key) on delete cascade,
  family_id  uuid not null references public.families (id) on delete cascade,
  day        date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, lesson_key, day)
);
create index if not exists parent_lesson_practice_user_day_idx on public.parent_lesson_practice (user_id, day);
create index if not exists parent_lesson_practice_family_idx on public.parent_lesson_practice (family_id);
alter table public.parent_lesson_practice enable row level security;
drop policy if exists "uygulama günü: aile okur" on public.parent_lesson_practice;
create policy "uygulama günü: aile okur" on public.parent_lesson_practice for select to authenticated
  using (family_id = public.my_family_id());
revoke insert, update, delete, truncate on public.parent_lesson_practice from anon, authenticated;

-- ---------------------------------------------------------------- 5. ebeveyn taşı: yeni nedenler
alter table public.parent_stone_ledger drop constraint if exists parent_stone_ledger_reason_check;
alter table public.parent_stone_ledger add constraint parent_stone_ledger_reason_check
  check (reason in ('task', 'task_undo', 'gift', 'lesson', 'lesson_undo'));

-- ---------------------------------------------------------------- 6. yardımcılar
create or replace function public.tr_today() returns date
language sql stable set search_path = '' as $$ select (now() at time zone 'Europe/Istanbul')::date $$;
revoke execute on function public.tr_today() from public, anon;
grant execute on function public.tr_today() to authenticated;

-- Haftanın taşını yeniden hesaplar: hedef = min(3, o hafta uygulanan farklı gün); fark deftere yazılır. Yanıt: haftanın taşı.
create or replace function public.parent_lesson_week_stones(p_user uuid, p_family uuid, p_week date)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  target integer;
  have integer;
begin
  select least(3, count(distinct day))::integer into target from public.parent_lesson_practice
    where user_id = p_user and day between p_week and p_week + 6;
  select coalesce(sum(amount), 0)::integer into have from public.parent_stone_ledger
    where user_id = p_user and reason in ('lesson', 'lesson_undo') and split_part(ref, '|', 2) = p_week::text;
  if target <> have then
    insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
    values (p_family, p_user, target - have, case when target > have then 'lesson' else 'lesson_undo' end,
            'lesson|' || p_week::text || '|' || extract(epoch from clock_timestamp())::text);
  end if;
  return target;
end $$;
revoke execute on function public.parent_lesson_week_stones(uuid, uuid, date) from public, anon, authenticated;

create or replace function public.parent_lesson_require() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare fam uuid := public.my_family_id();
begin
  if auth.uid() is null or fam is null then
    raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501';
  end if;
  return fam;
end $$;
revoke execute on function public.parent_lesson_require() from public, anon, authenticated;

-- ---------------------------------------------------------------- 7. ebeveyn işlevleri
-- Ebeveynin bütün görünümü: katalog, uzman önerileri, kendi dersleri, bu haftanın günleri ve taşı.
create or replace function public.family_lessons()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  fam uuid := public.parent_lesson_require();
  today date := public.tr_today();
  ws date := date_trunc('week', public.tr_today()::timestamp)::date;
begin
  return jsonb_build_object(
    'today', today,
    'week_start', ws,
    'catalog', coalesce((select jsonb_agg(jsonb_build_object('key', l.key, 'title', l.title, 'summary', l.summary,
                          'minutes', l.minutes, 'try_text', l.try_text, 'domain', l.domain, 'status', l.status)
                          order by l.position, l.title)
                        from public.parent_lessons l where l.status in ('published', 'retired')), '[]'),
    'assigned', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'lesson_key', a.lesson_key, 'link_id', a.link_id,
                           'note', a.note, 'created_at', a.created_at) order by a.created_at desc)
                         from public.parent_lesson_assignments a
                         join public.parent_lessons l on l.key = a.lesson_key and l.status = 'published'
                         where a.family_id = fam and a.status = 'active'
                           and exists (select 1 from public.clinic_links k where k.id = a.link_id and k.status = 'active')), '[]'),
    'mine', coalesce((select jsonb_agg(jsonb_build_object('lesson_key', p.lesson_key, 'status', p.status,
                       'assignment_id', p.assignment_id, 'started_at', p.started_at, 'opened_at', p.opened_at,
                       'learned_at', p.learned_at,
                       'days', (select count(*) from public.parent_lesson_practice x where x.user_id = uid and x.lesson_key = p.lesson_key),
                       'week_days', coalesce((select jsonb_agg(x.day order by x.day) from public.parent_lesson_practice x
                                     where x.user_id = uid and x.lesson_key = p.lesson_key and x.day >= ws), '[]'))
                       order by p.started_at desc)
                     from public.parent_lesson_progress p where p.user_id = uid), '[]'),
    'week_practiced', (select count(distinct day) from public.parent_lesson_practice where user_id = uid and day >= ws),
    'week_stones', (select coalesce(sum(amount), 0) from public.parent_stone_ledger
                    where user_id = uid and reason in ('lesson', 'lesson_undo') and split_part(ref, '|', 2) = ws::text),
    'week_cap', 3,
    'balance', public.parent_stone_balance(uid));
end $$;
revoke execute on function public.family_lessons() from public, anon;
grant execute on function public.family_lessons() to authenticated;

-- Dersi "Bu haftanın becerisi" yapar. Önceki 'current' uygulandıysa 'learned', uygulanmadıysa 'paused' olur.
-- Uzman önerisi olan derste atama bağlanır (uzman ilerlemeyi bu bağla görür). Yanıt: family_lessons().
create or replace function public.parent_lesson_start(p_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  fam uuid := public.parent_lesson_require();
  asg uuid;
begin
  if not exists (select 1 from public.parent_lessons where key = p_key and status = 'published') then
    raise exception 'Ders bulunamadı' using hint = 'lesson_not_found';
  end if;
  select a.id into asg from public.parent_lesson_assignments a
    where a.family_id = fam and a.lesson_key = p_key and a.status = 'active'
      and exists (select 1 from public.clinic_links k where k.id = a.link_id and k.status = 'active')
    order by a.created_at desc limit 1;
  update public.parent_lesson_progress p
     set status = case when exists (select 1 from public.parent_lesson_practice x where x.user_id = uid and x.lesson_key = p.lesson_key)
                       then 'learned' else 'paused' end,
         learned_at = case when exists (select 1 from public.parent_lesson_practice x where x.user_id = uid and x.lesson_key = p.lesson_key)
                           then coalesce(p.learned_at, now()) else p.learned_at end
   where p.user_id = uid and p.status = 'current' and p.lesson_key <> p_key;
  insert into public.parent_lesson_progress (user_id, lesson_key, family_id, assignment_id, status, started_at)
  values (uid, p_key, fam, asg, 'current', now())
  on conflict (user_id, lesson_key) do update
    set status = 'current', family_id = excluded.family_id,
        assignment_id = coalesce(excluded.assignment_id, public.parent_lesson_progress.assignment_id),
        started_at = case when public.parent_lesson_progress.status = 'current' then public.parent_lesson_progress.started_at else now() end;
  return public.family_lessons();
end $$;
revoke execute on function public.parent_lesson_start(text) from public, anon;
grant execute on function public.parent_lesson_start(text) to authenticated;

-- Ders açıldı (ilk açılış kaydedilir; taş yok). Başlanmamış ders açılınca kayıt açılmaz (yalnız okuma).
create or replace function public.parent_lesson_open(p_key text)
returns void language plpgsql security definer set search_path = '' as $$
declare fam uuid := public.parent_lesson_require();
begin
  update public.parent_lesson_progress set opened_at = coalesce(opened_at, now())
   where user_id = auth.uid() and lesson_key = p_key and family_id = fam;
end $$;
revoke execute on function public.parent_lesson_open(text) from public, anon;
grant execute on function public.parent_lesson_open(text) to authenticated;

-- "Öğrendim": dersi 'learned' yapar (bu haftanın becerisi boşalır). Yanıt: family_lessons().
create or replace function public.parent_lesson_finish(p_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare fam uuid := public.parent_lesson_require();
begin
  update public.parent_lesson_progress set status = 'learned', learned_at = coalesce(learned_at, now())
   where user_id = auth.uid() and lesson_key = p_key and family_id = fam;
  if not found then raise exception 'Bu derse başlamadın' using hint = 'lesson_not_started'; end if;
  return public.family_lessons();
end $$;
revoke execute on function public.parent_lesson_finish(text) from public, anon;
grant execute on function public.parent_lesson_finish(text) to authenticated;

-- "Bugün uyguladım" / geri al. Gün boşsa bugün (Türkiye). Yanıt:
-- {ok, day, week_start, week_days (bu ders), week_practiced (bütün dersler, farklı gün), week_stones, week_cap, stone_given, balance}
create or replace function public.parent_lesson_practice(p_key text, p_day date default null, p_done boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  fam uuid := public.parent_lesson_require();
  today date := public.tr_today();
  d date := coalesce(p_day, public.tr_today());
  ws date := date_trunc('week', coalesce(p_day, public.tr_today())::timestamp)::date;
  before integer;
  after integer;
begin
  if not exists (select 1 from public.parent_lesson_progress where user_id = uid and lesson_key = p_key and family_id = fam) then
    raise exception 'Önce bu derse başla' using hint = 'lesson_not_started';
  end if;
  if d > today then raise exception 'İleri bir gün işaretlenemez' using hint = 'date_range'; end if;
  if d < today - 6 then raise exception 'Yalnız son bir haftanın günü işaretlenebilir' using hint = 'date_range'; end if;
  select coalesce(sum(amount), 0)::integer into before from public.parent_stone_ledger
    where user_id = uid and reason in ('lesson', 'lesson_undo') and split_part(ref, '|', 2) = ws::text;
  if p_done then
    insert into public.parent_lesson_practice (user_id, lesson_key, family_id, day) values (uid, p_key, fam, d)
    on conflict do nothing;
  else
    delete from public.parent_lesson_practice where user_id = uid and lesson_key = p_key and day = d;
  end if;
  after := public.parent_lesson_week_stones(uid, fam, ws);
  return jsonb_build_object('ok', true, 'day', d, 'week_start', ws,
    'week_days', coalesce((select jsonb_agg(x.day order by x.day) from public.parent_lesson_practice x
                           where x.user_id = uid and x.lesson_key = p_key and x.day between ws and ws + 6), '[]'),
    'week_practiced', (select count(distinct day) from public.parent_lesson_practice where user_id = uid and day between ws and ws + 6),
    'week_stones', after, 'week_cap', 3, 'stone_given', after - before,
    'balance', public.parent_stone_balance(uid));
end $$;
revoke execute on function public.parent_lesson_practice(text, date, boolean) from public, anon;
grant execute on function public.parent_lesson_practice(text, date, boolean) to authenticated;

-- ---------------------------------------------------------------- 8. uzman işlevleri
-- Kütüphaneden ders öner (paylaşım başına aynı ders bir kez etkin). Ebeveynlere lesson_assigned. Yanıt: atama kimliği.
create or replace function public.clinic_assign_lesson(p_link_id uuid, p_key text, p_note text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  t text;
  rid uuid;
begin
  if not public.clinician_access() or not public.clinic_link_mine(p_link_id) then
    raise exception 'Paylaşım bulunamadı' using hint = 'link_not_visible';
  end if;
  select * into l from public.clinic_links where id = p_link_id;
  if l.status <> 'active' then raise exception 'Paylaşım etkin değil' using hint = 'link_not_active'; end if;
  select title into t from public.parent_lessons where key = p_key and status = 'published';
  if t is null then raise exception 'Ders bulunamadı' using hint = 'lesson_not_found'; end if;
  select id into rid from public.parent_lesson_assignments where link_id = p_link_id and lesson_key = p_key and status = 'active';
  if rid is not null then
    update public.parent_lesson_assignments set note = left(coalesce(p_note, ''), 300) where id = rid;
    return rid;
  end if;
  insert into public.parent_lesson_assignments (clinic_id, link_id, family_id, lesson_key, note, assigned_by)
  values (l.clinic_id, l.id, l.family_id, p_key, left(coalesce(p_note, ''), 300), auth.uid())
  returning id into rid;
  -- ebeveyn bu dersi zaten yapıyorsa uzman ilerlemeyi görsün diye bağla
  update public.parent_lesson_progress set assignment_id = rid
   where family_id = l.family_id and lesson_key = p_key and assignment_id is null;
  perform public.notify_parents(l.family_id, 'lesson_assigned', 'Uzmanın sana bir ders önerdi',
    t || ' · Gelişim › Ben bölümünde.', jsonb_build_object('assignment_id', rid, 'lesson_key', p_key, 'link_id', l.id), l.child_id);
  return rid;
end $$;
revoke execute on function public.clinic_assign_lesson(uuid, text, text) from public, anon;
grant execute on function public.clinic_assign_lesson(uuid, text, text) to authenticated;

-- Öneriyi geri çek (aile artık "Uzmanının önerisi" görmez; ebeveynin başladığı ders ve günleri kendisinde kalır).
create or replace function public.clinic_withdraw_lesson(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare lk uuid;
begin
  select link_id into lk from public.parent_lesson_assignments where id = p_id and status = 'active';
  if lk is null or not public.clinician_access() or not public.clinic_link_mine(lk) then
    raise exception 'Öneri bulunamadı' using hint = 'assignment_not_found';
  end if;
  update public.parent_lesson_assignments set status = 'withdrawn', withdrawn_at = now() where id = p_id;
end $$;
revoke execute on function public.clinic_withdraw_lesson(uuid) from public, anon;
grant execute on function public.clinic_withdraw_lesson(uuid) to authenticated;

-- Uzmanın gördüğü: bu paylaşımda önerdiği dersler ve her ebeveynin o dersteki durumu ile öneri tarihinden (geri çekildiyse
-- o güne kadar) sonraki uygulama günleri. Ebeveynin kendi seçtiği başka dersler ve öneriden önceki günler gelmez.
-- Paylaşım bittiyse (clinic_links.status <> 'active') yalnız öneri listesi döner, ebeveyn bilgisi gelmez.
-- [{id, lesson_key, title, note, status, created_at, withdrawn_at, parents: [{name, status, opened, days[]}]}]
create or replace function public.clinic_parent_lessons(p_link_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.clinician_access() or not public.clinic_link_visible(p_link_id) then
    raise exception 'Paylaşım bulunamadı' using hint = 'link_not_visible';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'lesson_key', a.lesson_key, 'title', l.title, 'note', a.note, 'status', a.status,
      'created_at', a.created_at, 'withdrawn_at', a.withdrawn_at,
      'parents', coalesce((
        select jsonb_agg(jsonb_build_object(
          'name', coalesce(nullif(pr.nickname, ''), 'Ebeveyn'), 'status', p.status, 'opened', p.opened_at is not null,
          'days', coalesce((select jsonb_agg(x.day order by x.day) from public.parent_lesson_practice x
                            where x.user_id = p.user_id and x.lesson_key = a.lesson_key
                              and x.day >= (a.created_at at time zone 'Europe/Istanbul')::date
                              and (a.withdrawn_at is null or x.day <= (a.withdrawn_at at time zone 'Europe/Istanbul')::date)), '[]'))
          order by pr.created_at)
        from public.parent_lesson_progress p
        join public.profiles pr on pr.id = p.user_id
        where p.family_id = a.family_id and p.lesson_key = a.lesson_key
          and (p.assignment_id = a.id or p.started_at >= a.created_at)
          and exists (select 1 from public.clinic_links k where k.id = a.link_id and k.status = 'active')), '[]'))
      order by a.created_at desc)
    from public.parent_lesson_assignments a
    join public.parent_lessons l on l.key = a.lesson_key
    where a.link_id = p_link_id), '[]');
end $$;
revoke execute on function public.clinic_parent_lessons(uuid) from public, anon;
grant execute on function public.clinic_parent_lessons(uuid) to authenticated;
