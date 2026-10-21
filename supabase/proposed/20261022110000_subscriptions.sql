-- =====================================================================
-- Aile aboneliği: 7 günlük deneme + Aylık / Yıllık plan + ücretsiz plan sınırları (öneri, 22 Ekim 2026)
-- Önkoşul: migrations/20261021200000_security_hardening.sql (family_premium kimlik kuralı korunur).
--   Deneme: aileyi kuran ebeveyn e-postasını doğruladığı an başlar (auth.users.email_confirmed_at), 7 gün sürer.
--           İkinci ebeveynin katılması denemeyi yeniden başlatmaz. Aynı e-postayla silip yeniden kayıt olan
--           yeni deneme almaz (trial_history: e-postanın SHA-256 özeti; e-postanın kendisi saklanmaz).
--   Planlar: monthly (her ay yenilenir, aylık ödenir) / yearly (bir yıllık tutar peşin). Fiyat ve ödeme mağazada;
--           family_subscriptions'ı yalnız sunucu (service role: ödeme webhook'u) yazar → set_family_subscription.
--   Durumlar (family_access().state): trial / premium / clinic (ücretli klinik planına bağlı çocuk) /
--           pending (e-posta henüz doğrulanmadı) / expired (deneme bitti, abonelik yok → ücretsiz plan).
--   Ücretsiz plan (expired): onay/ret, görevleri görme, oyun ve uzman paylaşımı çalışır; sınırlar:
--           en çok 3 etkin görev, 1 çocuk; ödül, güneş taşı düşme, ebeveyn mesajı, zor an kaydı kapalı.
--   Uygulama anahtarı: app_config 'billing'.enforce = false iken kimse kısıtlanmaz (ödeme altyapısı bağlanınca
--           true yapılır; hatırlatıcı DURUM'da). Deneme yine sayılır ve uygulamada gösterilir.
--   Kural: klinik denemesi (trial) aileye premium vermez; yalnız etkin ve ücretli klinik (güvenlik denetimi L3:
--   herkes uzman hesabı açıp deneme kliniğiyle aileye bedava premium alabiliyordu). ClinicApp üyeliğiyle uyumlu
--   (clinic_active: small/business/custom ya da süresi dolmamış solo/clinic).
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tablolar ve alanlar
-- ---------------------------------------------------------------------
alter table public.families add column if not exists trial_started_at timestamptz;

create table if not exists public.trial_history (
  email_hash  text primary key,
  started_at  timestamptz not null
);
alter table public.trial_history enable row level security;
revoke all on public.trial_history from anon, authenticated;

alter table public.family_subscriptions add column if not exists billing text;
alter table public.family_subscriptions add column if not exists status text not null default 'active';
alter table public.family_subscriptions add column if not exists product_id text;
alter table public.family_subscriptions add column if not exists store_transaction_id text;
alter table public.family_subscriptions add column if not exists auto_renew boolean not null default true;
alter table public.family_subscriptions add column if not exists started_at timestamptz;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'family_subscriptions_billing_check') then
    alter table public.family_subscriptions add constraint family_subscriptions_billing_check
      check (billing is null or billing in ('monthly', 'yearly'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'family_subscriptions_status_check') then
    alter table public.family_subscriptions add constraint family_subscriptions_status_check
      check (status in ('active', 'grace', 'canceled', 'expired', 'refunded'));
  end if;
end $$;
revoke insert, update, delete on public.family_subscriptions from anon, authenticated;

create table if not exists public.app_config (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);
alter table public.app_config enable row level security;
drop policy if exists "ayar: herkes okur" on public.app_config;
create policy "ayar: herkes okur" on public.app_config for select to authenticated using (key in ('billing'));
revoke insert, update, delete on public.app_config from anon, authenticated;
insert into public.app_config (key, value) values
  ('billing', '{"enforce": false, "trial_days": 7, "free_max_tasks": 3, "free_max_children": 1}')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- Deneme başlangıcı
-- ---------------------------------------------------------------------
-- E-posta özeti: küçük harf, Gmail'deki gibi "+etiket" atılır (aynı kutuya yeniden deneme almasın)
create or replace function public.email_hash(p_email text)
returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest(regexp_replace(lower(trim(p_email)), '\+[^@]*@', '@'), 'sha256'), 'hex')
$$;

create or replace function public.start_family_trial(p_user uuid, p_email text, p_confirmed timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare
  h text;
  prev timestamptz;
begin
  if p_confirmed is null then return; end if;
  if p_email is not null then
    h := public.email_hash(p_email);
    select started_at into prev from public.trial_history where email_hash = h;
    if prev is null then
      insert into public.trial_history (email_hash, started_at) values (h, p_confirmed) on conflict do nothing;
    end if;
  end if;
  update public.families set trial_started_at = coalesce(prev, p_confirmed)
   where created_by = p_user and trial_started_at is null;
end $$;

-- Aile oluşunca (kayıt anı e-posta zaten doğrulanmışsa) ve e-posta sonradan doğrulanınca
create or replace function public.families_trial_on_create()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  u record;
begin
  select email, email_confirmed_at into u from auth.users where id = new.created_by;
  if u.email_confirmed_at is not null then
    perform public.start_family_trial(new.created_by, u.email, u.email_confirmed_at);
  end if;
  return null;
end $$;
drop trigger if exists families_trial_on_create on public.families;
create trigger families_trial_on_create after insert on public.families
  for each row execute function public.families_trial_on_create();

create or replace function public.auth_user_confirmed()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.email_confirmed_at is not null and old.email_confirmed_at is null then
    perform public.start_family_trial(new.id, new.email, new.email_confirmed_at);
  end if;
  return new;
end $$;
drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed after update of email_confirmed_at on auth.users
  for each row execute function public.auth_user_confirmed();

-- Var olan aileler (deneme kullanıcıları): deneme bugünden başlar
update public.families f set trial_started_at = now()
 where trial_started_at is null
   and exists (select 1 from auth.users u where u.id = f.created_by and u.email_confirmed_at is not null);

-- ---------------------------------------------------------------------
-- Erişim durumu
-- ---------------------------------------------------------------------
create or replace function public.billing_config()
returns jsonb language sql stable security definer set search_path = '' as $$
  select '{"enforce": false, "trial_days": 7, "free_max_tasks": 3, "free_max_children": 1}'::jsonb
         || coalesce((select value from public.app_config where key = 'billing'), '{}'::jsonb)
$$;

-- İç: ailenin durumu (yetki denetimi çağırana aittir)
create or replace function public.family_access_of(p_family uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  cfg jsonb := public.billing_config();
  f public.families%rowtype;
  s public.family_subscriptions%rowtype;
  premium boolean;
  clinic boolean;
  trial_end timestamptz;
  st text;
begin
  select * into f from public.families where id = p_family;
  if not found then return null; end if;
  select * into s from public.family_subscriptions where family_id = p_family;
  premium := found and s.plan = 'premium' and s.status in ('active', 'grace', 'canceled')
             and (s.period_end is null or s.period_end > now());
  clinic := exists (select 1 from public.clinic_links l join public.clinics c on c.id = l.clinic_id
                     where l.family_id = p_family and l.status = 'active' and c.plan <> 'trial' and public.clinic_active(c.id));
  trial_end := f.trial_started_at + make_interval(days => (cfg ->> 'trial_days')::int);
  st := case when premium then 'premium' when clinic then 'clinic' when f.trial_started_at is null then 'pending'
             when trial_end > now() then 'trial' else 'expired' end;
  return json_build_object(
    'state', st,
    'enforced', (cfg ->> 'enforce')::boolean,
    'full', st <> 'expired' or not (cfg ->> 'enforce')::boolean,
    'trial_started_at', f.trial_started_at,
    'trial_ends_at', trial_end,
    'days_left', case when st = 'trial' then greatest(0, ceil(extract(epoch from trial_end - now()) / 86400))::int end,
    'plan', case when premium then s.billing end,
    'period_end', case when premium then s.period_end end,
    'auto_renew', case when premium then s.auto_renew end,
    'subscription_status', case when premium then s.status end,
    'limits', json_build_object('max_tasks', (cfg ->> 'free_max_tasks')::int, 'max_children', (cfg ->> 'free_max_children')::int)
  );
end $$;

-- Ebeveyn: kendi ailesinin durumu
create or replace function public.family_access()
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
begin
  if fid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  return public.family_access_of(fid);
end $$;

create or replace function public.family_full_access(p_family uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((public.family_access_of(p_family) ->> 'full')::boolean, true)
$$;

-- Ücretsiz planda kapalı özellik: açık hata (uygulama hint='premium_required' görünce üyelik ekranını açar)
create or replace function public.require_full_access(p_family uuid, p_feature text)
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.family_full_access(p_family) then
    raise exception 'Bu özellik Premium üyelikte: %', p_feature using errcode = 'P0001', hint = 'premium_required';
  end if;
end $$;

-- family_premium (eski çağrılar, analytics): premium ya da ücretli klinik ya da deneme sürüyor.
-- Kimlik kuralı 20261021200000_security_hardening.sql ile aynı: giriş yapmış kullanıcı yalnız kendi ailesini sorar;
-- SQL Editor / service_role (auth.uid() boş) bütün aileleri sorabilir.
create or replace function public.family_premium(p_family_id uuid default null)
returns boolean language sql stable security definer set search_path = '' as $$
  with f as (
    select case
      when p_family_id is null then public.my_family_id()
      when auth.uid() is null or p_family_id = public.my_any_family_id() then p_family_id
    end as id)
  select f.id is not null
     and coalesce(public.family_access_of(f.id) ->> 'state', 'expired') in ('premium', 'clinic', 'trial')
  from f
$$;

-- ---------------------------------------------------------------------
-- Ücretsiz plan sınırları (sunucuda; uygulama da önceden uyarır)
-- ---------------------------------------------------------------------
create or replace function public.tasks_free_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := public.billing_config();
begin
  if public.family_full_access(new.family_id) then return new; end if;
  if (select count(*) from public.tasks t where t.family_id = new.family_id
        and (t.end_date is null or t.end_date >= current_date)
        and (t.recurring or t.start_date >= current_date)) >= (cfg ->> 'free_max_tasks')::int then
    raise exception 'Ücretsiz planda en çok % etkin görev olabilir', cfg ->> 'free_max_tasks'
      using errcode = 'P0001', hint = 'premium_required';
  end if;
  return new;
end $$;
drop trigger if exists tasks_free_limit on public.tasks;
create trigger tasks_free_limit before insert on public.tasks
  for each row execute function public.tasks_free_limit();

create or replace function public.children_free_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := public.billing_config();
begin
  if public.family_full_access(new.family_id) then return new; end if;
  if (select count(*) from public.children c where c.family_id = new.family_id) >= (cfg ->> 'free_max_children')::int then
    raise exception 'Ücretsiz planda en çok % çocuk eklenebilir', cfg ->> 'free_max_children'
      using errcode = 'P0001', hint = 'premium_required';
  end if;
  return new;
end $$;
drop trigger if exists children_free_limit on public.children;
create trigger children_free_limit before insert on public.children
  for each row execute function public.children_free_limit();

create or replace function public.abc_events_free_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_full_access(new.family_id, 'zor an kaydı');
  return new;
end $$;
drop trigger if exists abc_events_free_limit on public.abc_events;
create trigger abc_events_free_limit before insert on public.abc_events
  for each row execute function public.abc_events_free_limit();

create or replace function public.messages_free_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.sender = 'parent' then perform public.require_full_access(new.family_id, 'mesaj gönderme'); end if;
  return new;
end $$;
drop trigger if exists messages_free_limit on public.messages;
create trigger messages_free_limit before insert on public.messages
  for each row execute function public.messages_free_limit();

-- ---------------------------------------------------------------------
-- Ödeme olayı → abonelik (yalnız service role: Edge Function billing-webhook)
-- ---------------------------------------------------------------------
create or replace function public.set_family_subscription(
  p_family uuid, p_plan text, p_billing text, p_status text, p_period_end timestamptz,
  p_auto_renew boolean, p_product_id text, p_transaction_id text, p_source text default 'store')
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.family_subscriptions (family_id, plan, billing, status, period_end, auto_renew, product_id,
                                           store_transaction_id, source, started_at, updated_at)
  values (p_family, p_plan, p_billing, p_status, p_period_end, coalesce(p_auto_renew, true), p_product_id,
          p_transaction_id, coalesce(p_source, 'store'), now(), now())
  on conflict (family_id) do update set
    plan = excluded.plan, billing = excluded.billing, status = excluded.status, period_end = excluded.period_end,
    auto_renew = excluded.auto_renew, product_id = excluded.product_id,
    store_transaction_id = coalesce(excluded.store_transaction_id, public.family_subscriptions.store_transaction_id),
    source = excluded.source,
    started_at = coalesce(public.family_subscriptions.started_at, excluded.started_at), updated_at = now();
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.email_hash(text) from public, anon, authenticated;
revoke execute on function public.start_family_trial(uuid, text, timestamptz) from public, anon, authenticated;
revoke execute on function public.families_trial_on_create() from public, anon, authenticated;
revoke execute on function public.auth_user_confirmed() from public, anon, authenticated;
revoke execute on function public.billing_config() from public, anon, authenticated;
revoke execute on function public.family_access_of(uuid) from public, anon, authenticated;
revoke execute on function public.family_full_access(uuid) from public, anon, authenticated;
revoke execute on function public.require_full_access(uuid, text) from public, anon, authenticated;
revoke execute on function public.tasks_free_limit() from public, anon, authenticated;
revoke execute on function public.children_free_limit() from public, anon, authenticated;
revoke execute on function public.abc_events_free_limit() from public, anon, authenticated;
revoke execute on function public.messages_free_limit() from public, anon, authenticated;
revoke execute on function public.set_family_subscription(uuid, text, text, text, timestamptz, boolean, text, text, text) from public, anon, authenticated;
revoke execute on function public.family_access() from public, anon;
revoke execute on function public.family_premium(uuid) from public, anon;
grant execute on function public.family_access() to authenticated;
grant execute on function public.family_premium(uuid) to authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.set_family_subscription(uuid, text, text, text, timestamptz, boolean, text, text, text) to service_role;
  end if;
end $$;
