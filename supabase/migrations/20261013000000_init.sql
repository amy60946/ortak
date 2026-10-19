-- =====================================================================
-- ParentApp – ilk veritabanı şeması
-- Supabase panelinde: SQL Editor > New query > bu dosyanın tamamını
-- yapıştır > Run. Boş bir projede BİR KEZ çalıştırılmak üzere yazıldı.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------

create table public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'Ailem',
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

-- Ebeveyn profili (auth.users ile bire bir)
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  family_id   uuid references public.families (id) on delete set null,
  nickname    text not null default 'Ben',
  name        text not null default '',
  avatar      text not null default 'erkek',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index profiles_family_idx on public.profiles (family_id);

create table public.children (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 60),
  avatar      text not null,
  gender      text check (gender in ('kız', 'erkek')),
  birthday    date,
  -- Çocuk uygulamasında giriş kodu kullanılınca oluşan (anonim) oturum
  user_id     uuid unique references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index children_family_idx on public.children (family_id);

-- Tekrarlayan görev TEK kayıttır; düzenleme tüm günlere yansır.
create table public.tasks (
  id               uuid primary key default gen_random_uuid(),
  family_id        uuid not null references public.families (id) on delete cascade,
  title            text not null check (char_length(title) between 1 and 120),
  emoji            text not null default '⭐',
  skill            text not null default '',
  description      text not null default '',
  start_date       date not null,
  recurring        boolean not null default false,
  end_date         date,
  reminder         text check (reminder ~ '^[0-2][0-9]:[0-5][0-9]$'),
  requires_review  boolean not null default true,
  created_by       uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);
create index tasks_family_idx on public.tasks (family_id);

create table public.task_assignments (
  task_id     uuid not null references public.tasks (id) on delete cascade,
  child_id    uuid not null references public.children (id) on delete cascade,
  family_id   uuid not null references public.families (id) on delete cascade,
  difficulty  text not null check (difficulty in ('easy', 'medium', 'hard')),
  coins       integer not null default 0 check (coins >= 0),
  primary key (task_id, child_id)
);
create index task_assignments_family_idx on public.task_assignments (family_id);
create index task_assignments_child_idx on public.task_assignments (child_id);

create table public.completions (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  task_id      uuid not null references public.tasks (id) on delete cascade,
  child_id     uuid not null references public.children (id) on delete cascade,
  date         date not null,
  status       text not null check (status in ('pending', 'approved')),
  created_at   timestamptz not null default now(),
  reviewed_at  timestamptz,
  reviewed_by  uuid references auth.users (id) on delete set null,
  unique (task_id, child_id, date)
);
create index completions_family_date_idx on public.completions (family_id, date);
create index completions_child_idx on public.completions (child_id);

create table public.messages (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  child_id     uuid not null references public.children (id) on delete cascade,
  sender       text not null default 'parent' check (sender in ('parent', 'child')),
  sender_id    uuid references auth.users (id) on delete set null,
  kind         text not null default 'text' check (kind in ('text', 'image', 'audio')),
  body         text check (char_length(body) <= 2000),
  media_path   text,          -- Storage 'mail' kovasında: <family_id>/<dosya>
  duration_ms  integer,       -- sesli mesaj süresi
  created_at   timestamptz not null default now(),
  check ((kind = 'text' and body is not null) or (kind <> 'text' and media_path is not null))
);
create index messages_family_created_idx on public.messages (family_id, created_at);
create index messages_child_idx on public.messages (child_id);

-- Kaydedilen hazır şablonlar (template_key = 't1' gibi) ve aileye özel
-- şablonlar (is_custom = true, template_key = kendi id'si).
create table public.saved_templates (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families (id) on delete cascade,
  template_key  text not null,
  is_custom     boolean not null default false,
  saved         boolean not null default true,
  title         text,
  emoji         text,
  category      text check (category in ('home', 'mind', 'learn', 'self')),
  difficulty    text check (difficulty in ('easy', 'medium', 'hard')),
  skill         text,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (family_id, template_key),
  check (not is_custom or (title is not null and category is not null and difficulty is not null))
);

-- Ebeveyn davet kodu ve çocuk giriş kodu. Tek kullanımlık, süreli.
-- İstemci doğrudan yazamaz; yalnızca aşağıdaki fonksiyonlarla üretilir/kullanılır.
create table public.invite_codes (
  code        text primary key check (code ~ '^[A-Z0-9]{6}$'),
  family_id   uuid not null references public.families (id) on delete cascade,
  kind        text not null check (kind in ('parent', 'child')),
  child_id    uuid references public.children (id) on delete cascade,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  used_at     timestamptz,
  used_by     uuid references auth.users (id) on delete set null,
  check ((kind = 'child') = (child_id is not null))
);
create index invite_codes_family_idx on public.invite_codes (family_id);

-- ---------------------------------------------------------------------
-- Yardımcı fonksiyonlar
-- ---------------------------------------------------------------------

-- Oturumdaki ebeveynin ailesi
create or replace function public.my_family_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select family_id from public.profiles where id = auth.uid()
$$;

-- Oturumdaki çocuk (çocuk uygulaması)
create or replace function public.my_child_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select id from public.children where user_id = auth.uid()
$$;

-- Ebeveyn ya da çocuk fark etmeksizin oturumun ailesi
create or replace function public.my_any_family_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select family_id from public.profiles where id = auth.uid()),
    (select family_id from public.children where user_id = auth.uid())
  )
$$;

-- Politikalarda tablolar arası kontrol (RLS özyinelemesini önler)
create or replace function public.task_family(p_task_id uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select family_id from public.tasks where id = p_task_id
$$;

create or replace function public.child_family(p_child_id uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select family_id from public.children where id = p_child_id
$$;

create or replace function public.task_assigned_to_me(p_task_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.task_assignments a
    join public.children c on c.id = a.child_id
    where a.task_id = p_task_id and c.user_id = auth.uid()
  )
$$;

-- Çocuk, inceleme gerektiren görevi kendisi "onaylandı" yapamaz
create or replace function public.child_may_complete(p_task_id uuid, p_status text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.task_assigned_to_me(p_task_id)
     and (p_status = 'pending' or not (select requires_review from public.tasks where id = p_task_id))
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger tasks_updated_at before update on public.tasks
  for each row execute function public.set_updated_at();

-- Yeni ebeveyn kaydında aile + profil oluştur (anonim çocuk oturumları hariç)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;
  insert into public.families (created_by) values (new.id) returning id into fid;
  insert into public.profiles (id, family_id, nickname, name, avatar)
  values (
    new.id,
    fid,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nickname'), ''), 'Ben'),
    coalesce(trim(new.raw_user_meta_data ->> 'name'), ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'avatar', ''), 'erkek')
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 6 haneli, karışması kolay karakterler olmadan rastgele kod
create or replace function public.random_code()
returns text language plpgsql volatile set search_path = '' as $$
declare
  chars constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea := uuid_send(gen_random_uuid());
  result text := '';
begin
  for i in 0..5 loop
    result := result || substr(chars, (get_byte(bytes, i) % length(chars)) + 1, 1);
  end loop;
  return result;
end $$;

-- ---------------------------------------------------------------------
-- Davet / giriş kodu fonksiyonları
-- ---------------------------------------------------------------------

-- Kod üret. p_kind: 'parent' (ikinci ebeveyn daveti) ya da 'child' (çocuk girişi)
create or replace function public.create_invite_code(p_kind text default 'parent', p_child_id uuid default null)
returns table (code text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  fid uuid := public.my_family_id();
  new_code text;
  exp timestamptz := now() + interval '24 hours';
begin
  if fid is null then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  if p_kind not in ('parent', 'child') then
    raise exception 'Geçersiz kod türü';
  end if;
  if p_kind = 'child' then
    if p_child_id is null or not exists (
      select 1 from public.children c where c.id = p_child_id and c.family_id = fid
    ) then
      raise exception 'Çocuk bulunamadı';
    end if;
    -- Aynı çocuk için kullanılmamış eski kodlar geçersiz olsun
    delete from public.invite_codes i
      where i.child_id = p_child_id and i.used_at is null;
  else
    p_child_id := null;
  end if;

  -- Süresi dolmuş, kullanılmamış kodları temizle
  delete from public.invite_codes i
    where i.family_id = fid and i.used_at is null and i.expires_at < now();

  loop
    new_code := public.random_code();
    begin
      insert into public.invite_codes (code, family_id, kind, child_id, created_by, expires_at)
      values (new_code, fid, p_kind, p_child_id, auth.uid(), exp);
      exit;
    exception when unique_violation then
      -- çakışma: yeni kod dene
    end;
  end loop;

  return query select new_code, exp;
end $$;

-- İkinci ebeveyn: davet koduyla aileye katıl.
-- Kullanıcının önceki ailesinde başka ebeveyn yoksa o aile (ve verisi) silinir.
create or replace function public.join_family(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  old_fid uuid;
begin
  if uid is null or not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'parent'
    for update;

  if not found or inv.used_at is not null or inv.expires_at < now() then
    raise exception 'Kod geçersiz ya da süresi dolmuş';
  end if;

  select family_id into old_fid from public.profiles where id = uid;
  if old_fid = inv.family_id then
    raise exception 'Zaten bu ailedesin';
  end if;

  update public.profiles set family_id = inv.family_id where id = uid;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;

  if old_fid is not null and not exists (select 1 from public.profiles where family_id = old_fid) then
    delete from public.families where id = old_fid;
  end if;

  return inv.family_id;
end $$;

-- Çocuk uygulaması: (anonim) oturum açtıktan sonra giriş koduyla çocuğa bağlan.
create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  c public.children%rowtype;
begin
  if uid is null then
    raise exception 'Oturum gerekli' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles where id = uid) then
    raise exception 'Ebeveyn hesabıyla çocuk girişi yapılamaz';
  end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'child'
    for update;

  if not found or inv.used_at is not null or inv.expires_at < now() then
    raise exception 'Kod geçersiz ya da süresi dolmuş';
  end if;

  update public.children set user_id = null where user_id = uid;
  update public.children set user_id = uid where id = inv.child_id returning * into c;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;

  return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar);
end $$;

-- Hesabı sil. Ailede başka ebeveyn yoksa ailenin tüm verisi de silinir.
-- (Storage dosyaları uygulama tarafından bu çağrıdan önce silinir.)
create or replace function public.delete_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  fid uuid;
begin
  if uid is null then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  select family_id into fid from public.profiles where id = uid;
  if fid is not null and not exists (
    select 1 from public.profiles where family_id = fid and id <> uid
  ) then
    delete from public.families where id = fid;
  end if;
  delete from auth.users where id = uid;  -- profiles satırı da silinir
end $$;

revoke execute on function public.create_invite_code(text, uuid) from public, anon;
revoke execute on function public.join_family(text) from public, anon;
revoke execute on function public.redeem_child_code(text) from public, anon;
revoke execute on function public.delete_account() from public, anon;
revoke execute on function public.random_code() from public, anon, authenticated;
revoke execute on function public.task_family(uuid) from public, anon;
revoke execute on function public.child_family(uuid) from public, anon;
revoke execute on function public.task_assigned_to_me(uuid) from public, anon;
revoke execute on function public.child_may_complete(uuid, text) from public, anon;
grant execute on function public.create_invite_code(text, uuid) to authenticated;
grant execute on function public.join_family(text) to authenticated;
grant execute on function public.redeem_child_code(text) to authenticated;
grant execute on function public.delete_account() to authenticated;

-- ---------------------------------------------------------------------
-- Row Level Security: her ebeveyn yalnızca kendi ailesinin verisini görür
-- ---------------------------------------------------------------------

alter table public.families         enable row level security;
alter table public.profiles         enable row level security;
alter table public.children         enable row level security;
alter table public.tasks            enable row level security;
alter table public.task_assignments enable row level security;
alter table public.completions      enable row level security;
alter table public.messages         enable row level security;
alter table public.saved_templates  enable row level security;
alter table public.invite_codes     enable row level security;

-- Aile
create policy "aile: okuma" on public.families for select to authenticated
  using (id = public.my_any_family_id());
create policy "aile: güncelleme" on public.families for update to authenticated
  using (id = public.my_family_id()) with check (id = public.my_family_id());
revoke insert, update, delete on public.families from anon, authenticated;
grant update (name) on public.families to authenticated;

-- Profil: kendi profilin + aynı ailedeki ebeveynler. family_id yalnızca
-- join_family ile değişebilir.
create policy "profil: okuma" on public.profiles for select to authenticated
  using (id = auth.uid() or family_id = public.my_family_id());
create policy "profil: kendi profilini güncelle" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (nickname, name, avatar) on public.profiles to authenticated;

-- Çocuklar
create policy "çocuk: ebeveyn" on public.children for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id());
create policy "çocuk: kendi kaydı" on public.children for select to authenticated
  using (user_id = auth.uid());
revoke insert, update on public.children from anon, authenticated;
grant insert (id, family_id, name, avatar, gender, birthday) on public.children to authenticated;
grant update (name, avatar, gender, birthday) on public.children to authenticated;

-- Görevler
create policy "görev: ebeveyn" on public.tasks for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id());
create policy "görev: çocuk okur" on public.tasks for select to authenticated
  using (public.task_assigned_to_me(id));

-- Görev atamaları
create policy "atama: ebeveyn" on public.task_assignments for all to authenticated
  using (family_id = public.my_family_id())
  with check (
    family_id = public.my_family_id()
    and public.task_family(task_id) = family_id
    and public.child_family(child_id) = family_id
  );
create policy "atama: çocuk okur" on public.task_assignments for select to authenticated
  using (child_id = public.my_child_id());

-- Tamamlananlar
create policy "tamamlama: ebeveyn" on public.completions for all to authenticated
  using (family_id = public.my_family_id())
  with check (
    family_id = public.my_family_id()
    and public.task_family(task_id) = family_id
    and public.child_family(child_id) = family_id
  );
create policy "tamamlama: çocuk okur" on public.completions for select to authenticated
  using (child_id = public.my_child_id());
create policy "tamamlama: çocuk işaretler" on public.completions for insert to authenticated
  with check (
    child_id = public.my_child_id()
    and family_id = public.my_any_family_id()
    and public.child_may_complete(task_id, status)
  );
create policy "tamamlama: çocuk geri alır" on public.completions for delete to authenticated
  using (child_id = public.my_child_id() and status = 'pending');

-- Posta
create policy "mesaj: ebeveyn okur" on public.messages for select to authenticated
  using (family_id = public.my_family_id());
create policy "mesaj: ebeveyn gönderir" on public.messages for insert to authenticated
  with check (
    family_id = public.my_family_id()
    and sender = 'parent' and sender_id = auth.uid()
    and public.child_family(child_id) = family_id
  );
create policy "mesaj: ebeveyn siler" on public.messages for delete to authenticated
  using (family_id = public.my_family_id());
create policy "mesaj: çocuk okur" on public.messages for select to authenticated
  using (child_id = public.my_child_id());
create policy "mesaj: çocuk gönderir" on public.messages for insert to authenticated
  with check (
    child_id = public.my_child_id() and family_id = public.my_any_family_id()
    and sender = 'child' and sender_id = auth.uid()
  );

-- Şablonlar
create policy "şablon: ebeveyn" on public.saved_templates for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id());

-- Kodlar: yalnızca okunur; üretme/kullanma fonksiyonlarla
create policy "kod: ebeveyn okur" on public.invite_codes for select to authenticated
  using (family_id = public.my_family_id());
revoke insert, update, delete on public.invite_codes from anon, authenticated;

-- ---------------------------------------------------------------------
-- Realtime (Posta anlık gelsin; görev/tamamlama değişiklikleri senkron)
-- ---------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array['messages', 'completions', 'tasks', 'task_assignments', 'children'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Storage: Posta fotoğrafları ve sesli mesajlar (gizli kova)
-- Dosya yolu: <family_id>/<dosya>
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'mail', 'mail', false, 10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp',
        'audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mpeg']
)
on conflict (id) do nothing;

create policy "posta: aile okur" on storage.objects for select to authenticated
  using (bucket_id = 'mail' and (storage.foldername(name))[1] = public.my_any_family_id()::text);
create policy "posta: aile yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'mail' and (storage.foldername(name))[1] = public.my_any_family_id()::text);
create policy "posta: ebeveyn siler" on storage.objects for delete to authenticated
  using (bucket_id = 'mail' and (storage.foldername(name))[1] = public.my_family_id()::text);
