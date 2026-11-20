-- Moyo Ebeveyn bildirim tercihleri ve "günün adımları tamamlandı" bildirimi (kullanıcı kararı 20 Kasım 2026, bildirim sınırı 5a:
-- "Moyo Ebeveyn'de günde 1 bildirimi geçmemeye çalışalım. Çocuğun oyun içinde yaptığı rutinleri ebeveynine bildiren bildirimleri
-- ebeveyn uygulamadan açıp kapatabilsin. Bütün görevler yapılırsa gün sonu (son görev de yapıldığında) bütün görevlerin tamamlandığı
-- bildirimi gidebilir. Sistem tam işlevle bildirim atabilsin, ancak ebeveyn uygulama içinden ayarlama yapabilsin.").
-- ÖNERİ; tekrar çalıştırılabilir. Önkoşul: 20261019130000_notifications.sql, 20261021300000_security_pentest.sql (notifications_push),
-- 20261105200000_parent_lessons.sql (tr_today) — hepsi canlıda.
--
-- Kural:
--   * Ebeveyn başına iki anahtar (parent_notification_prefs; satır yoksa varsayılan):
--       step_done    — çocuk oyunda bir adımı işaretleyince ("Yaptım" → task_done, "Yapamam" → task_declined) anlık bildirim. Varsayılan KAPALI.
--       day_complete — çocuğun o gün planlı bütün adımları işaretlenince (son işaretle, onay beklemeden) tek bildirim. Varsayılan AÇIK.
--   * Tercih yalnız anlık bildirimi (telefona push) etkiler. notifications satırı her durumda yazılır: uygulama içi liste ve rozet aynı kalır.
--     Karar satıra yazılır: notifications.push (varsayılan true; tetikleyici notifications_push_pref ebeveyn tercihine göre false yapar).
--     notifications_push (pg_net → Edge Function push-apns / Expo) push = false satırda hiç çağrılmaz.
--   * day_complete (kind 'day_complete', app 'parent'): yalnız çocuğun kendi işareti (oyun) tetikler, yalnız Türkiye günü bugün olan adımda
--     (geçmiş günün geç işareti tetiklemez), planlı adım hesabı child_tasks ile aynı (task_assignments + task_occurs_on), "işaretli" =
--     pending ya da approved. Çocuk başına günde en çok bir kez: children.day_complete_on (son gönderilen gün; istemci yazamaz). Çocuk satırı
--     kilitlenerek sayılır: arka arkaya gelen iki son işaretten biri mutlaka bildirimi üretir, ikisi birden üretmez. Geri alıp yeniden
--     işaretlemek, sonradan eklenen adım ya da ebeveynin onayı ikinci bildirim üretmez.
--   * Başka bildirim türleri (haftalık hedef, posta, ödül isteği, uzman, hesap …) değişmez; push'ları sürer.
-- RPC: parent_notification_prefs() → {step_done, day_complete}; parent_notification_prefs_set(p_key, p_on) → aynı biçim. Yalnız ebeveyn
-- (profiles satırı olan hesap); başkasının tercihi okunamaz.
-- Sözleşme: sozlesme/veritabani.md 5 ve 34, akislar.md 7 ve 25, durumlar.md 8. Test: test_parent_notification_prefs.sql.

-- ---------------------------------------------------------------- 1. tercih tablosu
-- Varsayılanlar iki yerde durur ve birlikte değişir: bu tablonun sütun varsayılanı ve parent_notification_prefs_of().
create table if not exists public.parent_notification_prefs (
  user_id       uuid primary key references public.profiles (id) on delete cascade,
  step_done     boolean not null default false,
  day_complete  boolean not null default true,
  updated_at    timestamptz not null default now()
);
alter table public.parent_notification_prefs enable row level security;
drop policy if exists "bildirim tercihi: kendi okur" on public.parent_notification_prefs;
create policy "bildirim tercihi: kendi okur" on public.parent_notification_prefs for select to authenticated
  using (user_id = auth.uid());
revoke all on public.parent_notification_prefs from anon;
revoke insert, update, delete, truncate on public.parent_notification_prefs from authenticated;

-- ---------------------------------------------------------------- 2. sütunlar
alter table public.notifications add column if not exists push boolean not null default true;   -- false: yalnız uygulama içi
alter table public.children add column if not exists day_complete_on date;                      -- son "günün adımları tamamlandı" günü

-- ---------------------------------------------------------------- 3. iç: tercih okuma ve push kararı
create or replace function public.parent_notification_prefs_of(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('step_done', coalesce(p.step_done, false), 'day_complete', coalesce(p.day_complete, true))
    from (select 1) x left join public.parent_notification_prefs p on p.user_id = p_user
$$;
revoke execute on function public.parent_notification_prefs_of(uuid) from public, anon, authenticated;

-- Hangi tür hangi anahtara bağlı: yalnız ebeveyn uygulamasının task_done / task_declined (step_done) ve day_complete (day_complete) satırları.
create or replace function public.notifications_push_pref() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.push and new.app = 'parent' then
    if new.kind in ('task_done', 'task_declined') then
      new.push := (public.parent_notification_prefs_of(new.user_id) ->> 'step_done')::boolean;
    elsif new.kind = 'day_complete' then
      new.push := (public.parent_notification_prefs_of(new.user_id) ->> 'day_complete')::boolean;
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.notifications_push_pref() from public, anon, authenticated;
drop trigger if exists notifications_push_pref on public.notifications;
create trigger notifications_push_pref before insert on public.notifications
  for each row execute function public.notifications_push_pref();

-- notifications_push (önceki tanım: migrations/20261021300000_security_pentest.sql): aynı, yalnız push = false satırda çıkar.
create or replace function public.notifications_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  msgs jsonb;
  unread integer;
  secret text;
  hdrs jsonb := '{"Content-Type": "application/json"}'::jsonb;
begin
  if not new.push then
    return null;   -- yalnız uygulama içi (ebeveynin bildirim tercihi)
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace s on s.oid = p.pronamespace
                  where s.nspname = 'net' and p.proname = 'http_post') then
    return null;
  end if;
  select count(*) into unread from public.notifications where user_id = new.user_id and read_at is null;
  if exists (select 1 from public.push_tokens where user_id = new.user_id and platform = 'ios' and token not like 'ExponentPushToken[%') then
    begin
      if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                  where n.nspname = 'vault' and c.relname = 'decrypted_secrets') then
        execute 'select decrypted_secret from vault.decrypted_secrets where name = ''push_secret'' limit 1' into secret;
      end if;
      if secret is not null then hdrs := hdrs || jsonb_build_object('x-push-secret', secret); end if;
      execute 'select net.http_post(url := $1, body := $2, headers := $3)'
        using 'https://uhelhxqgpcjemadhsifx.supabase.co/functions/v1/push-apns',
              jsonb_build_object('notification_id', new.id), hdrs;
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
revoke execute on function public.notifications_push() from public, anon, authenticated;

-- ---------------------------------------------------------------- 4. günün adımları tamamlandı
-- completions_notify'dan sonra çalışır (ad sırası): satırda önce adımın kendi bildirimi, sonra günün bildirimi.
create or replace function public.completions_notify_day() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  marked date;
  planned integer;
  done integer;
  waiting integer;
begin
  if new.status not in ('pending', 'approved') then return null; end if;
  if tg_op = 'UPDATE' and old.status in ('pending', 'approved') then return null; end if;   -- zaten işaretliydi
  if new.date is distinct from public.tr_today() then return null; end if;                  -- yalnız bugünün adımı
  -- yalnız çocuğun kendi işareti (oyun); ebeveynin onayı ya da kaydı değil
  if not exists (select 1 from public.children where id = new.child_id and user_id = auth.uid()) then return null; end if;
  -- çocuk satırını kilitle: aynı çocuğun eşzamanlı son işaretleri sırayla sayılır, gün bir kez işaretlenir
  select day_complete_on into marked from public.children where id = new.child_id for no key update;
  if marked is not distinct from new.date then return null; end if;
  select count(*)::integer,
         count(*) filter (where c.status in ('pending', 'approved'))::integer,
         count(*) filter (where c.status = 'pending')::integer
    into planned, done, waiting
    from public.task_assignments a
    join public.tasks t on t.id = a.task_id
    left join public.completions c on c.task_id = a.task_id and c.child_id = a.child_id and c.date = new.date
   where a.child_id = new.child_id and public.task_occurs_on(t, new.date);
  if planned = 0 or done < planned then return null; end if;
  update public.children set day_complete_on = new.date where id = new.child_id;
  perform public.notify_parents(new.family_id, 'day_complete',
    public.child_name(new.child_id) || ' bugünün adımlarını tamamladı',
    case when waiting > 0 then 'Onayını bekleyen ' || waiting || ' adım var.' else '' end,
    jsonb_build_object('child_id', new.child_id, 'date', new.date, 'steps', planned, 'pending', waiting), new.child_id);
  return null;
end $$;
revoke execute on function public.completions_notify_day() from public, anon, authenticated;
drop trigger if exists completions_notify_day on public.completions;
create trigger completions_notify_day after insert or update of status on public.completions
  for each row execute function public.completions_notify_day();

-- ---------------------------------------------------------------- 5. RPC (Moyo Ebeveyn › Bildirimler › ayarlar)
create or replace function public.parent_notification_prefs()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Ebeveyn hesabı gerekli' using errcode = '42501';
  end if;
  return public.parent_notification_prefs_of(auth.uid())::json;
end $$;
revoke execute on function public.parent_notification_prefs() from public, anon;
grant execute on function public.parent_notification_prefs() to authenticated;

create or replace function public.parent_notification_prefs_set(p_key text, p_on boolean)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null or not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Ebeveyn hesabı gerekli' using errcode = '42501';
  end if;
  if p_key is null or p_key not in ('step_done', 'day_complete') then
    raise exception 'Geçersiz bildirim ayarı' using errcode = '22023';
  end if;
  if p_on is null then
    raise exception 'Açık ya da kapalı seç' using errcode = '22023';
  end if;
  insert into public.parent_notification_prefs (user_id) values (uid) on conflict (user_id) do nothing;   -- varsayılanlarla
  update public.parent_notification_prefs
     set step_done    = case when p_key = 'step_done' then p_on else step_done end,
         day_complete = case when p_key = 'day_complete' then p_on else day_complete end,
         updated_at   = now()
   where user_id = uid;
  return public.parent_notification_prefs_of(uid)::json;
end $$;
revoke execute on function public.parent_notification_prefs_set(text, boolean) from public, anon;
grant execute on function public.parent_notification_prefs_set(text, boolean) to authenticated;
