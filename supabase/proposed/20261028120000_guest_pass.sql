-- 30 günlük misafir kartı (kullanıcı isteği 28 Ekim 2026; Joon "30-Day All Access Guest Pass"): bir aile, ParentApp'i henüz
-- kullanmayan bir aileye 30 günlük tam erişim hediye eder. Kart kodla taşınır (8 karakter, "Kodun var mı?" ve Aile › Hesap ›
-- Kod gir kutusundan yazılır). Kullanan ailenin deneme süresi 30 güne çıkar (families.trial_days); ödeme yok, Apple aboneliğine
-- dokunmaz. Kural: kart yalnız yeni aileye (deneme başlayalı en çok 7 gün, daha önce kart kullanmamış, abonesi olmayan),
-- kendi ailesine kullanılamaz; tek kullanımlık; 60 gün geçerli. Kod denemesi ortak sınıra tabidir (code_throttled).
-- Tekrar çalıştırılabilir.

-- 1) Ailenin deneme süresi (null = ayar: billing.trial_days)
alter table public.families add column if not exists trial_days smallint check (trial_days between 1 and 90);

-- 2) Kartlar
create table if not exists public.guest_passes (
  code            text primary key check (code ~ '^[A-Z2-9]{8}$'),
  family_id       uuid not null references public.families (id) on delete cascade,
  created_by      uuid not null references auth.users (id) on delete cascade,
  created_at      timestamptz not null default now(),
  expires_at      timestamptz not null default now() + interval '60 days',
  redeemed_family uuid references public.families (id) on delete set null,
  redeemed_at     timestamptz
);
create index if not exists guest_passes_family_idx on public.guest_passes (family_id, created_at desc);
alter table public.guest_passes enable row level security;
drop policy if exists "misafir kartı: aile okur" on public.guest_passes;
create policy "misafir kartı: aile okur" on public.guest_passes for select to authenticated
  using (family_id = public.my_family_id());
revoke insert, update, delete on public.guest_passes from anon, authenticated;
grant select on public.guest_passes to authenticated;

-- 3) Erişim: deneme süresi ailenin kendi süresiyle (karttan) hesaplanır; başka kural değişmedi (20261022110000)
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
  trial_end := f.trial_started_at + make_interval(days => coalesce(f.trial_days::int, (cfg ->> 'trial_days')::int));
  st := case when premium then 'premium' when clinic then 'clinic' when f.trial_started_at is null then 'pending'
             when trial_end > now() then 'trial' else 'expired' end;
  return json_build_object(
    'state', st,
    'enforced', (cfg ->> 'enforce')::boolean,
    'full', st <> 'expired' or not (cfg ->> 'enforce')::boolean,
    'trial_started_at', f.trial_started_at,
    'trial_ends_at', trial_end,
    'trial_days', coalesce(f.trial_days::int, (cfg ->> 'trial_days')::int),
    'guest_pass', f.trial_days is not null,
    'days_left', case when st = 'trial' then greatest(0, ceil(extract(epoch from trial_end - now()) / 86400))::int end,
    'plan', case when premium then s.billing end,
    'period_end', case when premium then s.period_end end,
    'auto_renew', case when premium then s.auto_renew end,
    'subscription_status', case when premium then s.status end,
    'limits', json_build_object('max_tasks', (cfg ->> 'free_max_tasks')::int, 'max_children', (cfg ->> 'free_max_children')::int)
  );
end $$;

-- 4) Kart oluştur: ailenin kullanılmamış ve süresi dolmamış kartı varsa o döner (paylaşılan kod değişmesin); yoksa yeni.
--    Aile başına en çok 20 kart (kötüye kullanım sınırı).
create or replace function public.create_guest_pass()
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  g public.guest_passes%rowtype;
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text;
  i int;
begin
  if fid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  select * into g from public.guest_passes
   where family_id = fid and redeemed_at is null and expires_at > now() order by created_at desc limit 1;
  if found then return json_build_object('code', g.code, 'expires_at', g.expires_at, 'new', false); end if;
  if (select count(*) from public.guest_passes where family_id = fid) >= 20 then
    raise exception 'Bu aile en çok 20 misafir kartı oluşturabilir' using errcode = 'P0001', hint = 'limit';
  end if;
  loop
    c := '';
    for i in 1..8 loop c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1); end loop;
    exit when not exists (select 1 from public.guest_passes where code = c);
  end loop;
  insert into public.guest_passes (code, family_id, created_by) values (c, fid, auth.uid()) returning * into g;
  return json_build_object('code', g.code, 'expires_at', g.expires_at, 'new', true);
end $$;

-- 5) Kartı kullan (yeni aile). Dönüş {ok, trial_ends_at} ya da {ok:false, error}; hatalı kod deneme sayılır.
--    error: not_found / expired / used / own / not_new / already / premium
create or replace function public.redeem_guest_pass(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  f public.families%rowtype;
  g public.guest_passes%rowtype;
  t json;
  err text;
begin
  if fid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  select * into g from public.guest_passes where code = upper(trim(coalesce(p_code, ''))) for update;
  if not found then
    insert into public.code_attempts (user_id, ip) values (auth.uid(), public.request_ip());
    return json_build_object('ok', false, 'error', 'not_found');
  end if;
  select * into f from public.families where id = fid for update;
  err := case
    when g.redeemed_at is not null then 'used'
    when g.expires_at <= now() then 'expired'
    when g.family_id = fid then 'own'
    when f.trial_days is not null then 'already'
    when exists (select 1 from public.family_subscriptions s where s.family_id = fid and s.plan = 'premium'
                   and s.status in ('active', 'grace', 'canceled') and (s.period_end is null or s.period_end > now())) then 'premium'
    when f.trial_started_at is not null and f.trial_started_at < now() - interval '7 days' then 'not_new'
  end;
  if err is not null then return json_build_object('ok', false, 'error', err); end if;

  update public.families set trial_days = 30, trial_started_at = coalesce(trial_started_at, now()) where id = fid returning * into f;
  update public.guest_passes set redeemed_family = fid, redeemed_at = now() where code = g.code;
  delete from public.code_attempts where user_id = auth.uid();
  perform public.notify_parents(g.family_id, 'guest_pass_used', 'Hediye kartın kullanıldı',
    'Bir aile ParentApp''i 30 gün ücretsiz kullanmaya başladı. Teşekkürler!', jsonb_build_object('code', g.code), null);
  return json_build_object('ok', true, 'trial_ends_at', f.trial_started_at + interval '30 days');
end $$;

revoke execute on function public.create_guest_pass() from public, anon;
grant execute on function public.create_guest_pass() to authenticated;
revoke execute on function public.redeem_guest_pass(text) from public, anon;
grant execute on function public.redeem_guest_pass(text) to authenticated;
