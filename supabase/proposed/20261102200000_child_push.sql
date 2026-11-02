-- Çocuğa anlık bildirim (K7 B, kullanıcı kararı 2 Kasım 2026; benchmark: Apple App Review 4.5.4 / 5.1.1 / 5.1.4, HIG Notifications,
-- Greenlight, Joon; kaçınılacaklar Duolingo geri çağırma, Finch suçluluk, Radesky 2022; AB DSA 28. madde kılavuzu, ICO oyun önerileri).
--
-- Kural:
--   * Varsayılan KAPALI. Yalnız ebeveyn ParentApp'te açar (çocuk başına).
--   * Açıkken oyun, ebeveyn kapısı + kısa açıklamadan sonra iOS izni ister ve cihaz anahtarını register_push_token(…, 'child', 'ios') ile kaydeder.
--   * Gönderim (Edge Function push-apns, yalnız app = 'child'): child_push_claim() izin verirse; günde en çok 1 (Türkiye günü),
--     sessiz saatlerde hiç (gece aralığı veli seçer, varsayılan 20:30–08:00; isteğe bağlı hafta içi okul saati 08:00–15:30).
--     Gönderilmeyen haber kaybolmaz: oyun açılınca Mavi ve posta kutusuyla gösterir.
--   * Metin genel ve sakin ("Adada yeni bir haber var!"); görev başlığı, ad, not gibi içerik bildirimde yer almaz (push-apns yazar).
-- Tekrar çalıştırılabilir.

create table if not exists public.child_push_settings (
  child_id      uuid primary key references public.children (id) on delete cascade,
  family_id     uuid not null references public.families (id) on delete cascade,
  enabled       boolean not null default false,
  quiet_from    time not null default '20:30',
  quiet_to      time not null default '08:00',
  school_quiet  boolean not null default true,      -- hafta içi 08:00–15:30 gönderme
  last_sent_at  timestamptz,                         -- son gönderilen çocuk bildirimi (günde en çok 1)
  updated_by    uuid references auth.users (id) on delete set null,
  updated_at    timestamptz not null default now(),
  check (quiet_from <> quiet_to)
);
create index if not exists child_push_settings_family_idx on public.child_push_settings (family_id);

alter table public.child_push_settings enable row level security;
revoke all on public.child_push_settings from anon, authenticated;
grant select on public.child_push_settings to authenticated;
drop policy if exists child_push_settings_family_read on public.child_push_settings;
create policy child_push_settings_family_read on public.child_push_settings
  for select to authenticated using (family_id = public.my_family_id());

-- Saat kuralı (saf; test edilebilir): Türkiye saatine göre sessiz mi?
create or replace function public.child_push_quiet(p_at timestamptz, p_from time, p_to time, p_school boolean)
returns boolean language sql stable set search_path = '' as $$
  with l as (select (p_at at time zone 'Europe/Istanbul') as ts)
  select
    (case when p_from > p_to then (l.ts::time >= p_from or l.ts::time < p_to)
          else (l.ts::time >= p_from and l.ts::time < p_to) end)
    or (coalesce(p_school, false) and extract(isodow from l.ts) between 1 and 5
        and l.ts::time >= time '08:00' and l.ts::time < time '15:30')
  from l
$$;

-- Ebeveyn: çocuğun bildirim ayarı (ParentApp). Dönen: güncel ayar.
create or replace function public.parent_set_child_push(
  p_child uuid, p_enabled boolean, p_quiet_from time default '20:30', p_quiet_to time default '08:00', p_school_quiet boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  fam uuid := public.my_family_id();
  r public.child_push_settings;
begin
  if auth.uid() is null or fam is null then raise exception 'Yalnız ebeveyn' using errcode = '42501'; end if;
  if not exists (select 1 from public.children c where c.id = p_child and c.family_id = fam) then
    raise exception 'Çocuk bulunamadı' using errcode = '42501';
  end if;
  if p_quiet_from is null or p_quiet_to is null or p_quiet_from = p_quiet_to then
    raise exception 'Sessiz saat aralığı geçersiz' using errcode = '22023';
  end if;
  insert into public.child_push_settings as s (child_id, family_id, enabled, quiet_from, quiet_to, school_quiet, updated_by, updated_at)
  values (p_child, fam, coalesce(p_enabled, false), p_quiet_from, p_quiet_to, coalesce(p_school_quiet, true), auth.uid(), now())
  on conflict (child_id) do update
    set enabled = excluded.enabled, quiet_from = excluded.quiet_from, quiet_to = excluded.quiet_to,
        school_quiet = excluded.school_quiet, updated_by = excluded.updated_by, updated_at = now()
  returning * into r;
  -- kapatılınca çocuğun cihaz anahtarları silinir (telefon artık bildirim almaz; oyun yeniden açarsa yeniden kaydeder)
  if not r.enabled then
    delete from public.push_tokens t
     where t.app = 'child' and t.user_id = (select c.user_id from public.children c where c.id = p_child);
  end if;
  return jsonb_build_object('child_id', r.child_id, 'enabled', r.enabled, 'quiet_from', to_char(r.quiet_from, 'HH24:MI'),
    'quiet_to', to_char(r.quiet_to, 'HH24:MI'), 'school_quiet', r.school_quiet);
end $$;

-- Oyun: kendi ayarı (izin akışını yalnız açıksa gösterir). Satır yoksa kapalı.
create or replace function public.child_push_settings_me()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'enabled', coalesce(s.enabled, false),
    'quiet_from', to_char(coalesce(s.quiet_from, time '20:30'), 'HH24:MI'),
    'quiet_to', to_char(coalesce(s.quiet_to, time '08:00'), 'HH24:MI'),
    'school_quiet', coalesce(s.school_quiet, true))
  from public.children c
  left join public.child_push_settings s on s.child_id = c.id
  where c.user_id = auth.uid()
$$;

-- Sunucu (push-apns, service_role): bu çocuğa şimdi bildirim gidebilir mi? Gidebilirse günü işaretler (aynı gün ikincisi gitmez).
create or replace function public.child_push_claim(p_user uuid, p_now timestamptz default now())
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  s public.child_push_settings;
begin
  select ps.* into s
    from public.child_push_settings ps join public.children c on c.id = ps.child_id
   where c.user_id = p_user
   for update of ps;
  if not found or not s.enabled then return false; end if;
  if public.child_push_quiet(p_now, s.quiet_from, s.quiet_to, s.school_quiet) then return false; end if;
  if s.last_sent_at is not null
     and (s.last_sent_at at time zone 'Europe/Istanbul')::date >= (p_now at time zone 'Europe/Istanbul')::date then
    return false;
  end if;
  update public.child_push_settings set last_sent_at = p_now where child_id = s.child_id;
  return true;
end $$;

revoke execute on function public.child_push_quiet(timestamptz, time, time, boolean) from public, anon, authenticated;
revoke execute on function public.parent_set_child_push(uuid, boolean, time, time, boolean) from public, anon;
revoke execute on function public.child_push_settings_me() from public, anon;
revoke execute on function public.child_push_claim(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.parent_set_child_push(uuid, boolean, time, time, boolean) to authenticated;
grant execute on function public.child_push_settings_me() to authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.child_push_claim(uuid, timestamptz) to service_role;
  end if;
end $$;
