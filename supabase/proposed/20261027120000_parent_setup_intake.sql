-- ParentApp ilk kurulum ve tanışma soruları (kullanıcı kararları 27 Ekim 2026; sozlesme/akislar.md 16)
--
-- Akış: Başla → uzman kodu var mı → kayıt → aile soruları → çocuk ekle (uzman taslağıyla ya da elle) → çocuk soruları
--       → çocukların → takma ad + avatar → üç "tanıdık geliyor mu?" → uygulama (+ çocuğun cihazını kur).
-- intake_answers: kim yanıtladı (user_id), hangi aile, hangi çocuk (null = aile/ebeveyn sorusu), soru anahtarı, yanıt
--   (seçenek anahtarları dizisi). Soru metinleri uygulamada; anahtarlar ve seçenekler sozlesme/durumlar.md 15.
-- Görünürlük: aile üyeleri kendi ailesinin yanıtlarını okur; yalnız yanıtlayan kendi satırını yazar/değiştirir/siler.
--   Uzman: bu sürümde erişim yok (ileride ebeveyn izniyle; paylaşım onay metni sürümü değişir).
-- Sağlık soruları (child_diagnosis, child_medication): isteğe bağlı; "belirtmek istemiyorum" dışında bir yanıt
--   consent_version ister (açık rıza metni sürümü, ör. 'saglik-yanit-v1').
-- Yönetim paneli (kullanıcı kararı: kişi bazlı): admin_intake(aile, gerekçe) yalnız support/owner, her açılış admin_audit'e
--   yazılır; admin_intake_summary(gün) yalnız sayılar (kimlik yok), okuyan her rol. Canlıdan önce avukat onayı (hukuk_notlari.md).
-- profiles.setup_completed_at: ilk kurulum bitti mi; bu göçten önceki ebeveynler bitmiş sayılır. parent_setup_complete() ile yazılır.

-- ---------------------------------------------------------------- profiles.setup_completed_at
do $$ begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'profiles' and column_name = 'setup_completed_at') then
    alter table public.profiles add column setup_completed_at timestamptz;
    -- yalnız ilk çalıştırmada: mevcut ebeveynler kurulumu yapmış sayılır (tekrar çalıştırınca yeni kayıtlara dokunmaz)
    update public.profiles set setup_completed_at = coalesce(created_at, now());
  end if;
end $$;

create or replace function public.parent_setup_complete()
returns timestamptz language plpgsql security definer set search_path = '' as $$
declare t timestamptz;
begin
  update public.profiles set setup_completed_at = coalesce(setup_completed_at, now())
   where id = auth.uid() returning setup_completed_at into t;
  if t is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501'; end if;
  return t;
end $$;
revoke execute on function public.parent_setup_complete() from public, anon;
grant execute on function public.parent_setup_complete() to authenticated;

-- ---------------------------------------------------------------- intake_answers
create table if not exists public.intake_answers (
  id               uuid primary key default gen_random_uuid(),
  family_id        uuid not null references public.families (id) on delete cascade,
  user_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
  child_id         uuid references public.children (id) on delete cascade,
  question_key     text not null check (question_key ~ '^[a-z][a-z0-9_]{1,40}$'),
  answer           jsonb not null check (jsonb_typeof(answer) = 'array' and jsonb_array_length(answer) between 1 and 12),
  version          text not null default 'v1' check (char_length(version) between 1 and 20),
  consent_version  text check (consent_version is null or char_length(consent_version) between 1 and 40),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint intake_answers_one unique nulls not distinct (user_id, child_id, question_key)
);
create index if not exists intake_answers_family_idx on public.intake_answers (family_id);
create index if not exists intake_answers_child_idx on public.intake_answers (child_id) where child_id is not null;
alter table public.intake_answers enable row level security;
revoke all on public.intake_answers from anon, authenticated;
grant select, insert, update, delete on public.intake_answers to authenticated;

-- Sunucu doldurur ve denetler: aile/kişi kimliği, çocuğun aileye ait olması, seçenek biçimi, sağlık yanıtında rıza sürümü
create or replace function public.intake_answers_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v jsonb;
begin
  if tg_op = 'INSERT' then
    new.user_id := auth.uid();
    new.family_id := public.my_family_id();
    new.created_at := now();
  else
    new.user_id := old.user_id;
    new.family_id := old.family_id;
    new.child_id := old.child_id;
    new.question_key := old.question_key;
    new.created_at := old.created_at;
  end if;
  if new.user_id is null or new.family_id is null then
    raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501';
  end if;
  if new.child_id is not null and not exists (
    select 1 from public.children c where c.id = new.child_id and c.family_id = new.family_id) then
    raise exception 'Çocuk bulunamadı';
  end if;
  for v in select * from jsonb_array_elements(new.answer) loop
    if jsonb_typeof(v) <> 'string' or (v #>> '{}') !~ '^[a-z0-9_]{1,40}$' then
      raise exception 'Geçersiz yanıt';
    end if;
  end loop;
  if new.question_key in ('child_diagnosis', 'child_medication') and new.answer <> '["prefer_not"]'::jsonb
     and nullif(btrim(coalesce(new.consent_version, '')), '') is null then
    raise exception 'Sağlık yanıtı için onay gerekli' using hint = 'consent_required';
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.intake_answers_guard() from public, anon, authenticated;
drop trigger if exists intake_answers_guard on public.intake_answers;
create trigger intake_answers_guard before insert or update on public.intake_answers
  for each row execute function public.intake_answers_guard();

drop policy if exists "tanışma: aile okur" on public.intake_answers;
create policy "tanışma: aile okur" on public.intake_answers for select to authenticated
  using (family_id = public.my_family_id());
drop policy if exists "tanışma: kendi yanıtı" on public.intake_answers;
create policy "tanışma: kendi yanıtı" on public.intake_answers for all to authenticated
  using (user_id = auth.uid() and family_id = public.my_family_id())
  with check (user_id = auth.uid() and family_id = public.my_family_id());

-- ---------------------------------------------------------------- yönetim paneli
-- Kişi bazlı (aile seçilir): kim, hangi çocuk için, hangi soru, hangi yanıt. Her açılış denetim kaydına yazılır.
create or replace function public.admin_intake(p_family uuid, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['support']);
begin
  if not exists (select 1 from public.families where id = p_family) then raise exception 'Aile bulunamadı'; end if;
  perform public.admin_log(me, 'intake.view', 'family', p_family::text, p_reason);
  return coalesce((
    select json_agg(json_build_object(
             'user_id', a.user_id, 'member', coalesce(nullif(p.name, ''), p.nickname, ''), 'nickname', p.nickname,
             'child_id', a.child_id, 'child', c.name,
             'question', a.question_key, 'answer', a.answer, 'version', a.version, 'consent_version', a.consent_version,
             'updated_at', a.updated_at)
           order by a.child_id nulls first, a.user_id, a.question_key)
      from public.intake_answers a
      left join public.profiles p on p.id = a.user_id
      left join public.children c on c.id = a.child_id
     where a.family_id = p_family), '[]'::json);
end $$;
revoke execute on function public.admin_intake(uuid, text) from public, anon;
grant execute on function public.admin_intake(uuid, text) to authenticated;

-- Yalnız sayılar: soru × seçenek başına kaç yanıt (son p_days gün); kimlik yok
create or replace function public.admin_intake_summary(p_days integer default 90)
returns json language plpgsql stable security definer set search_path = '' as $$
declare me uuid := public.admin_require();
begin
  return coalesce((
    select json_agg(json_build_object('question', q, 'option', o, 'count', n, 'families', f) order by q, n desc)
      from (select a.question_key q, opt o, count(*) n, count(distinct a.family_id) f
              from public.intake_answers a, jsonb_array_elements_text(a.answer) opt
             where a.updated_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 90), 3650)))
             group by 1, 2) s), '[]'::json);
end $$;
revoke execute on function public.admin_intake_summary(integer) from public, anon;
grant execute on function public.admin_intake_summary(integer) to authenticated;
