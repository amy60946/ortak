-- =====================================================================
-- Bildirim sistemi: üç uygulama (öneri, 19 Ekim 2026)
--   notifications : kime (user_id), hangi uygulama (app), tür (kind), başlık/metin, veri (data), okundu (read_at).
--                   Satırları YALNIZ sunucu tetikleyicileri yazar; kullanıcı kendi satırını okur, okundu işaretler, siler.
--                   Realtime yayınında: uygulama açıkken anında gelir.
--   push_tokens   : cihazın anlık bildirim (push) anahtarı. Apple (APNs) cihaz anahtarlarına Edge Function `push-apns`
--                   gönderir (ortak/supabase/functions/push-apns; .p8 anahtarı Supabase secret'ında). pg_net yalnız bildirim
--                   kimliğini o fonksiyona iletir. Expo anahtarları (ExponentPushToken[...]) gelirse Expo Push API'ye gider.
--   Kural: işlemi yapan kişiye bildirim gitmez (auth.uid() = alıcı ise atlanır).
--   Klinik sınırı: uzmana giden bildirimlerde yalnız rızalı (active) paylaşım; posta ve coin uzmana bildirilmez.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- pg_net (Supabase'de hazır eklenti). Yoksa push atlanır, bildirim satırları yine yazılır.
do $$ begin
  create extension if not exists pg_net;
exception when others then
  raise notice 'pg_net yok; anlık bildirim (push) gönderilmeyecek';
end $$;

-- ---------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------
create table if not exists public.notifications (
  id          bigserial primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  app         text not null check (app in ('parent', 'child', 'clinic')),
  kind        text not null,
  title       text not null check (char_length(title) <= 120),
  body        text not null default '' check (char_length(body) <= 300),
  data        jsonb not null default '{}',
  family_id   uuid references public.families (id) on delete cascade,
  child_id    uuid references public.children (id) on delete cascade,
  created_at  timestamptz not null default now(),
  read_at     timestamptz,
  apns_sent_at timestamptz   -- push-apns gönderdi (aynı bildirim iki kez gönderilmez)
);
alter table public.notifications add column if not exists apns_sent_at timestamptz;
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
alter table public.notifications enable row level security;
drop policy if exists "bildirim: kendi okur" on public.notifications;
create policy "bildirim: kendi okur" on public.notifications for select to authenticated using (user_id = auth.uid());
drop policy if exists "bildirim: kendi okundu" on public.notifications;
create policy "bildirim: kendi okundu" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "bildirim: kendi siler" on public.notifications;
create policy "bildirim: kendi siler" on public.notifications for delete to authenticated using (user_id = auth.uid());
revoke insert, update, delete on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;
grant delete on public.notifications to authenticated;

create table if not exists public.push_tokens (
  token       text primary key check (char_length(token) between 8 and 300),
  user_id     uuid not null references auth.users (id) on delete cascade,
  app         text not null check (app in ('parent', 'child', 'clinic')),
  platform    text not null default 'ios' check (platform in ('ios', 'android', 'web')),
  updated_at  timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
drop policy if exists "push: kendi okur" on public.push_tokens;
create policy "push: kendi okur" on public.push_tokens for select to authenticated using (user_id = auth.uid());
-- Yazma yalnız aşağıdaki RPC'lerle (aynı cihaz başka hesaba geçerse anahtar taşınır).
revoke insert, update, delete on public.push_tokens from anon, authenticated;

create or replace function public.register_push_token(p_token text, p_app text, p_platform text default 'ios')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  insert into public.push_tokens (token, user_id, app, platform, updated_at)
  values (p_token, auth.uid(), p_app, coalesce(p_platform, 'ios'), now())
  on conflict (token) do update set user_id = excluded.user_id, app = excluded.app, platform = excluded.platform, updated_at = now();
end $$;

create or replace function public.unregister_push_token(p_token text)
returns void language sql security definer set search_path = '' as $$
  delete from public.push_tokens where token = p_token and user_id = auth.uid()
$$;

-- Kullanıcı: hepsini okundu yap
create or replace function public.mark_notifications_read(p_ids bigint[] default null)
returns integer language sql security definer set search_path = '' as $$
  with u as (
    update public.notifications set read_at = now()
     where user_id = auth.uid() and read_at is null and (p_ids is null or id = any (p_ids))
    returning 1)
  select count(*)::integer from u
$$;

-- ---------------------------------------------------------------------
-- Yazıcılar (yalnız tetikleyiciler kullanır)
-- ---------------------------------------------------------------------
create or replace function public.notify(p_user uuid, p_app text, p_kind text, p_title text, p_body text,
                                         p_data jsonb default '{}', p_family uuid default null, p_child uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null or p_user is not distinct from auth.uid() then return; end if;   -- işlemi yapan kendine bildirim almaz
  insert into public.notifications (user_id, app, kind, title, body, data, family_id, child_id)
  values (p_user, p_app, p_kind, left(p_title, 120), left(coalesce(p_body, ''), 300), coalesce(p_data, '{}'), p_family, p_child);
end $$;

create or replace function public.notify_parents(p_family uuid, p_kind text, p_title text, p_body text,
                                                 p_data jsonb default '{}', p_child uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select id from public.profiles where family_id = p_family loop
    perform public.notify(r.id, 'parent', p_kind, p_title, p_body, p_data, p_family, p_child);
  end loop;
end $$;

create or replace function public.notify_child(p_child uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}')
returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  select user_id, family_id into r from public.children where id = p_child;
  if r.user_id is not null then
    perform public.notify(r.user_id, 'child', p_kind, p_title, p_body, p_data, r.family_id, p_child);
  end if;
end $$;

-- Klinik alıcıları: sorumlu uzman; yoksa kliniğin bütün uzmanları
create or replace function public.notify_clinic(p_clinic uuid, p_clinician uuid, p_kind text, p_title text, p_body text,
                                                p_data jsonb default '{}', p_child uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select id from public.clinicians
            where clinic_id = p_clinic and (p_clinician is null or id = p_clinician) loop
    perform public.notify(r.id, 'clinic', p_kind, p_title, p_body, p_data, null, p_child);
  end loop;
end $$;

create or replace function public.child_name(p_child uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((select name from public.children where id = p_child), 'Çocuk')
$$;

-- ---------------------------------------------------------------------
-- Olaylar
-- ---------------------------------------------------------------------

-- 1. Görev durumu (oyun ↔ ParentApp)
create or replace function public.completions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  t record;
  coins integer;
  by_child boolean;
  nm text := public.child_name(new.child_id);
  d jsonb;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return null; end if;
  select title, emoji into t from public.tasks where id = new.task_id;
  select a.coins into coins from public.task_assignments a where a.task_id = new.task_id and a.child_id = new.child_id;
  by_child := exists (select 1 from public.children where id = new.child_id and user_id = auth.uid());
  d := jsonb_build_object('task_id', new.task_id, 'child_id', new.child_id, 'date', new.date, 'status', new.status);
  if by_child then
    if new.status = 'pending' then
      perform public.notify_parents(new.family_id, 'task_done', nm || ' görevi yaptı: ' || coalesce(t.title, ''),
        'Onayını bekliyor.', d, new.child_id);
    elsif new.status = 'approved' then
      perform public.notify_parents(new.family_id, 'task_done', nm || ' görevi yaptı: ' || coalesce(t.title, ''),
        case when coalesce(coins, 0) > 0 then '+' || coins || ' coin kazandı.' else '' end, d, new.child_id);
    elsif new.status = 'declined' then
      perform public.notify_parents(new.family_id, 'task_declined', nm || ' yapamadı: ' || coalesce(t.title, ''),
        'Konuşmak isteyebilirsin.', d, new.child_id);
    end if;
  else
    if new.status = 'approved' then
      perform public.notify_child(new.child_id, 'task_approved', 'Aferin! ' || coalesce(t.title, '') || ' onaylandı',
        case when coalesce(coins, 0) > 0 then '+' || coins || ' coin kazandın.' else '' end, d);
    elsif new.status = 'rejected' then
      perform public.notify_child(new.child_id, 'task_rejected', coalesce(t.title, '') || ' bir daha denenmeli',
        coalesce(new.parent_note, ''), d);
    end if;
  end if;
  return null;
end $$;
drop trigger if exists completions_notify on public.completions;
create trigger completions_notify after insert or update of status on public.completions
  for each row execute function public.completions_notify();

-- 2. Yeni görev atandı (ParentApp → oyun). Düzenlemede upsert var olan atamayı günceller, yeni bildirim gitmez.
create or replace function public.task_assignments_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare t record;
begin
  select title, emoji into t from public.tasks where id = new.task_id;
  perform public.notify_child(new.child_id, 'task_assigned', 'Yeni görev: ' || coalesce(t.emoji || ' ', '') || coalesce(t.title, ''),
    case when new.coins > 0 then new.coins || ' coin değerinde.' else '' end,
    jsonb_build_object('task_id', new.task_id, 'child_id', new.child_id));
  return null;
end $$;
drop trigger if exists task_assignments_notify on public.task_assignments;
create trigger task_assignments_notify after insert on public.task_assignments
  for each row execute function public.task_assignments_notify();

-- 3. Posta (ParentApp ↔ oyun). Uzmana gitmez.
create or replace function public.messages_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  preview text := case new.kind when 'image' then '📷 Fotoğraf' when 'audio' then '🎤 Sesli mesaj' else left(coalesce(new.body, ''), 120) end;
  d jsonb := jsonb_build_object('message_id', new.id, 'child_id', new.child_id);
begin
  if new.sender = 'child' then
    perform public.notify_parents(new.family_id, 'message', public.child_name(new.child_id) || ' mesaj gönderdi', preview, d, new.child_id);
  else
    perform public.notify_child(new.child_id, 'message', 'Yeni mektubun var!', preview, d);
  end if;
  return null;
end $$;
drop trigger if exists messages_notify on public.messages;
create trigger messages_notify after insert on public.messages
  for each row execute function public.messages_notify();

-- 4. Uzman paylaşımı başladı (ParentApp → ClinicApp). Aynı anda paylaşılan çocuklar tek bildirimde.
create or replace function public.clinic_links_notify_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in
    select n.clinic_id, n.clinician_id, n.family_id, count(*) as n_children,
           string_agg(c.name, ', ' order by c.name) as names, (array_agg(n.child_id))[1] as first_child,
           jsonb_agg(jsonb_build_object('link_id', n.id, 'child_id', n.child_id)) as links
      from new_rows n join public.children c on c.id = n.child_id
     group by n.clinic_id, n.clinician_id, n.family_id
  loop
    perform public.notify_clinic(r.clinic_id, r.clinician_id, 'clinic_shared',
      case when r.n_children = 1 then 'Yeni paylaşım: ' || r.names else r.n_children || ' çocuk paylaşıldı' end,
      'Aile rıza verdi: ' || r.names || '. Görev ve kayıtları artık görebilirsin.',
      jsonb_build_object('links', r.links, 'family_id', r.family_id),
      case when r.n_children = 1 then r.first_child end);
  end loop;
  return null;
end $$;
drop trigger if exists clinic_links_notify_insert on public.clinic_links;
create trigger clinic_links_notify_insert after insert on public.clinic_links
  referencing new table as new_rows for each statement execute function public.clinic_links_notify_insert();

-- 5. Paylaşım durduruldu: aile durdurduysa uzmana, uzman durdurduysa aileye
create or replace function public.clinic_links_notify_revoke() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('link_id', new.id, 'child_id', new.child_id);
begin
  if old.status = 'active' and new.status = 'revoked' then
    if exists (select 1 from public.profiles where id = new.revoked_by and family_id = new.family_id) then
      perform public.notify_clinic(new.clinic_id, new.clinician_id, 'clinic_revoked', 'Paylaşım durduruldu: ' || nm,
        'Aile bu çocuğun paylaşımını sonlandırdı.', d, new.child_id);
    else
      perform public.notify_parents(new.family_id, 'clinic_revoked', 'Uzman paylaşımı sonlandırdı: ' || nm,
        coalesce((select name from public.clinics where id = new.clinic_id), ''), d, new.child_id);
    end if;
  end if;
  return null;
end $$;
drop trigger if exists clinic_links_notify_revoke on public.clinic_links;
create trigger clinic_links_notify_revoke after update of status on public.clinic_links
  for each row execute function public.clinic_links_notify_revoke();

-- 6. Uzman görev önerdi (ClinicApp → ParentApp); ebeveyn karar verdi (ParentApp → ClinicApp)
create or replace function public.suggestions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('suggestion_id', new.id, 'child_id', new.child_id);
begin
  if tg_op = 'INSERT' then
    perform public.notify_parents(new.family_id, 'clinic_suggestion', 'Uzmanın ' || nm || ' için görev önerdi',
      coalesce(new.emoji || ' ', '') || new.title, d, new.child_id);
  elsif old.status = 'pending' and new.status in ('accepted', 'declined') then
    perform public.notify_clinic(new.clinic_id, new.created_by, 'suggestion_decided',
      case when new.status = 'accepted' then 'Öneri kabul edildi: ' else 'Öneri şimdilik eklenmedi: ' end || new.title,
      nm, d, new.child_id);
  end if;
  return null;
end $$;
drop trigger if exists suggestions_notify on public.clinic_task_suggestions;
create trigger suggestions_notify after insert or update of status on public.clinic_task_suggestions
  for each row execute function public.suggestions_notify();

-- 7. Zor an kaydı (ParentApp → ClinicApp): yalnız rızalı bağlantıların uzmanlarına
create or replace function public.abc_events_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select clinic_id, clinician_id from public.clinic_links where child_id = new.child_id and status = 'active' loop
    perform public.notify_clinic(r.clinic_id, r.clinician_id, 'abc_event', 'Yeni zor an kaydı: ' || public.child_name(new.child_id),
      'Şiddet ' || new.intensity || '/5', jsonb_build_object('abc_id', new.id, 'child_id', new.child_id), new.child_id);
  end loop;
  return null;
end $$;
drop trigger if exists abc_events_notify on public.abc_events;
create trigger abc_events_notify after insert on public.abc_events
  for each row execute function public.abc_events_notify();

-- 8. Çocuğun cihazı bağlandı (oyun → ParentApp)
create or replace function public.children_notify_device() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.user_id is null and new.user_id is not null then
    perform public.notify_parents(new.family_id, 'device_linked', new.name || ' oyuna bağlandı',
      'Görevler artık oyunda görünüyor.', jsonb_build_object('child_id', new.id), new.id);
  end if;
  return null;
end $$;
drop trigger if exists children_notify_device on public.children;
create trigger children_notify_device after update of user_id on public.children
  for each row execute function public.children_notify_device();

-- 9. İkinci ebeveyn aileye katıldı (ParentApp)
create or replace function public.profiles_notify_join() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.family_id is not null and new.family_id is distinct from old.family_id then
    perform public.notify_parents(new.family_id, 'parent_joined', coalesce(nullif(new.nickname, ''), 'Bir ebeveyn') || ' aileye katıldı',
      '', jsonb_build_object('profile_id', new.id));
  end if;
  return null;
end $$;
drop trigger if exists profiles_notify_join on public.profiles;
create trigger profiles_notify_join after update of family_id on public.profiles
  for each row execute function public.profiles_notify_join();

-- 10. Ekibe yeni uzman katıldı (ClinicApp): klinik sahiplerine
create or replace function public.clinicians_notify_join() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if new.role = 'member' then
    for r in select id from public.clinicians where clinic_id = new.clinic_id and role = 'owner' loop
      perform public.notify(r.id, 'clinic', 'team_joined', coalesce(nullif(new.name, ''), 'Yeni uzman') || ' ekibe katıldı', '',
        jsonb_build_object('clinician_id', new.id));
    end loop;
  end if;
  return null;
end $$;
drop trigger if exists clinicians_notify_join on public.clinicians;
create trigger clinicians_notify_join after insert on public.clinicians
  for each row execute function public.clinicians_notify_join();

-- ---------------------------------------------------------------------
-- Anlık bildirim (push), arka planda (pg_net, işlem bittikten sonra; hata işlemi bozmaz):
--   Apple cihaz anahtarı varsa → Edge Function push-apns'e yalnız bildirim kimliği; Expo anahtarı varsa → Expo Push API.
-- ---------------------------------------------------------------------
create or replace function public.notifications_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  msgs jsonb;
  unread integer;
begin
  if not exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
                  where s.nspname = 'net' and p.proname = 'http_post') then
    return null;
  end if;
  select count(*) into unread from public.notifications where user_id = new.user_id and read_at is null;
  if exists (select 1 from public.push_tokens where user_id = new.user_id and platform = 'ios' and token not like 'ExponentPushToken[%') then
    begin
      execute 'select net.http_post(url := $1, body := $2, headers := $3)'
        using 'https://uhelhxqgpcjemadhsifx.supabase.co/functions/v1/push-apns',
              jsonb_build_object('notification_id', new.id), '{"Content-Type": "application/json"}'::jsonb;
    exception when others then
      raise warning 'push-apns çağrılamadı: %', sqlerrm;
    end;
  end if;
  select jsonb_agg(jsonb_build_object('to', token, 'title', new.title, 'body', new.body, 'sound', 'default', 'badge', unread,
                                      'data', new.data || jsonb_build_object('kind', new.kind, 'notification_id', new.id)))
    into msgs
    from public.push_tokens where user_id = new.user_id and token like 'ExponentPushToken[%';
  if msgs is null then return null; end if;
  begin
    execute 'select net.http_post(url := $1, body := $2, headers := $3)'
      using 'https://exp.host/--/api/v2/push/send', msgs, '{"Content-Type": "application/json", "Accept": "application/json"}'::jsonb;
  exception when others then
    raise warning 'push gönderilemedi: %', sqlerrm;
  end;
  return null;
end $$;
drop trigger if exists notifications_push on public.notifications;
create trigger notifications_push after insert on public.notifications
  for each row execute function public.notifications_push();

-- ---------------------------------------------------------------------
-- Realtime + yetkiler
-- ---------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

revoke execute on function public.notify(uuid, text, text, text, text, jsonb, uuid, uuid) from public, anon, authenticated;
revoke execute on function public.notify_parents(uuid, text, text, text, jsonb, uuid) from public, anon, authenticated;
revoke execute on function public.notify_child(uuid, text, text, text, jsonb) from public, anon, authenticated;
revoke execute on function public.notify_clinic(uuid, uuid, text, text, text, jsonb, uuid) from public, anon, authenticated;
revoke execute on function public.child_name(uuid) from public, anon, authenticated;
revoke execute on function public.completions_notify() from public, anon, authenticated;
revoke execute on function public.task_assignments_notify() from public, anon, authenticated;
revoke execute on function public.messages_notify() from public, anon, authenticated;
revoke execute on function public.clinic_links_notify_insert() from public, anon, authenticated;
revoke execute on function public.clinic_links_notify_revoke() from public, anon, authenticated;
revoke execute on function public.suggestions_notify() from public, anon, authenticated;
revoke execute on function public.abc_events_notify() from public, anon, authenticated;
revoke execute on function public.children_notify_device() from public, anon, authenticated;
revoke execute on function public.profiles_notify_join() from public, anon, authenticated;
revoke execute on function public.clinicians_notify_join() from public, anon, authenticated;
revoke execute on function public.notifications_push() from public, anon, authenticated;
revoke execute on function public.register_push_token(text, text, text) from public, anon;
revoke execute on function public.unregister_push_token(text) from public, anon;
revoke execute on function public.mark_notifications_read(bigint[]) from public, anon;
grant execute on function public.register_push_token(text, text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;
grant execute on function public.mark_notifications_read(bigint[]) to authenticated;
