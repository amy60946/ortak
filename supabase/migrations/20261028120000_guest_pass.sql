-- Aile davet et (önce "30 günlük misafir kartı", kullanıcı isteği 28 Ekim 2026; 3 Kasım 2026 kullanıcı kararıyla davet
-- ödülüne dönüştü). Bir aile, ParentApp'i henüz kullanmayan bir aileye davet kodu gönderir (8 karakter, kurulumda "Kodum var"
-- ya da Aile › Hesap › Kod gir). Kullanan ailenin denemesi 7 + 7 = 14 gün olur (families.trial_days). Davet edilen aile ilk kez
-- mağazadan ücretli aboneliğe geçince davet eden aile 1 ay kazanır (yılda en çok 12; ödemeye bağlı ödül: benchmark YNAB / Babbel,
-- sahte hesapla sömürülemez). Davet eden abone değilse ay hemen eklenir (families.bonus_until); App Store'dan ödüyorsa sunucu
-- Apple aboneliğini uzatamaz: ödül "kod bekliyor" olur, ekip Apple teklif kodu (offer code, 1 ay ücretsiz) gönderir.
-- Kural: kod yalnız yeni aileye (deneme başlayalı en çok 7 gün, daha önce kod kullanmamış, abonesi olmayan), kendi ailesine
-- kullanılamaz; tek kullanımlık; 60 gün geçerli. Kod denemesi ortak sınıra tabidir (code_throttled). Davet edenle edilen
-- birbirinin kimliğini görmez. Tekrar çalıştırılabilir.

-- 1) Ailenin deneme süresi (null = ayar: billing.trial_days) ve davet ödülüyle kazanılan ücretsiz sürenin sonu
alter table public.families add column if not exists trial_days smallint check (trial_days between 1 and 90);
alter table public.families add column if not exists bonus_until timestamptz;

-- 2) Kartlar
create table if not exists public.guest_passes (
  code            text primary key check (code ~ '^[A-Z2-9]{8}$'),
  family_id       uuid not null references public.families (id) on delete cascade,
  created_by      uuid not null references auth.users (id) on delete cascade,
  created_at      timestamptz not null default now(),
  expires_at      timestamptz not null default now() + interval '60 days',
  redeemed_family uuid references public.families (id) on delete set null,
  redeemed_at     timestamptz,
  rewarded_at     timestamptz   -- davet edilen aile ücretli aboneliğe geçti, ödül yazıldı (bir kez)
);
alter table public.guest_passes add column if not exists rewarded_at timestamptz;
create index if not exists guest_passes_redeemed_idx on public.guest_passes (redeemed_family) where redeemed_family is not null;
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
  -- Davet ödülüyle kazanılan süre denemenin sonunu uzatır (durum yine 'trial'; bonus_until ayrıca döner)
  if f.bonus_until is not null and (trial_end is null or f.bonus_until > trial_end) then trial_end := f.bonus_until; end if;
  st := case when premium then 'premium' when clinic then 'clinic' when f.trial_started_at is null and f.bonus_until is null then 'pending'
             when trial_end > now() then 'trial' else 'expired' end;
  return json_build_object(
    'state', st,
    'enforced', (cfg ->> 'enforce')::boolean,
    'full', st <> 'expired' or not (cfg ->> 'enforce')::boolean,
    'trial_started_at', f.trial_started_at,
    'trial_ends_at', trial_end,
    'trial_days', coalesce(f.trial_days::int, (cfg ->> 'trial_days')::int),
    'guest_pass', f.trial_days is not null,
    'bonus_until', f.bonus_until,
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

  update public.families set trial_days = 14, trial_started_at = coalesce(trial_started_at, now()) where id = fid returning * into f;
  update public.guest_passes set redeemed_family = fid, redeemed_at = now() where code = g.code;
  delete from public.code_attempts where user_id = auth.uid();
  perform public.notify_parents(g.family_id, 'guest_pass_used', 'Davetin kullanıldı',
    'Bir aile davetinle ParentApp''e başladı. Abone olurlarsa sen 1 ay ücretsiz kazanırsın.', jsonb_build_object('code', g.code), null);
  return json_build_object('ok', true, 'trial_ends_at', f.trial_started_at + interval '14 days');
end $$;

-- 6) Davet ödülü: davet edilen aile ilk kez mağazadan ücretli aboneliğe geçince (family_subscriptions'a webhook yazar)
--    davet eden aileye 1 ay. Yılda (son 365 gün) en çok 12 ödül; fazlası 'capped' kaydedilir, uygulanmaz.
--    status: applied (bonus_until uzatıldı) · code_pending (davet eden App Store'dan ödüyor; ekip Apple teklif kodu gönderecek)
--            · code_sent (kod gönderildi; offer_code dolu) · capped (yıllık sınır). Aile tabloyu okumaz: my_referrals().
--    Not: ürünlerde App Store ücretsiz denemesi (intro offer) yoktur, deneme sunucudadır. Eklenirse webhook dönem türünü
--    (TRIAL / NORMAL) geçirmeli, ödül yalnız NORMAL'de yazılmalı. İade edilen abonelikte ödül geri alınmaz (karar 3 Kasım 2026).
create table if not exists public.referral_rewards (
  id              uuid primary key default gen_random_uuid(),
  family_id       uuid not null references public.families (id) on delete cascade,   -- davet eden
  pass_code       text not null unique references public.guest_passes (code) on delete cascade,
  created_at      timestamptz not null default now(),
  status          text not null check (status in ('applied', 'code_pending', 'code_sent', 'capped')),
  days            smallint not null default 30 check (days between 1 and 90),
  bonus_until     timestamptz,           -- applied: yeni ücretsiz süre sonu
  offer_code      text check (offer_code is null or char_length(offer_code) between 4 and 64),
  code_sent_at    timestamptz
);
create index if not exists referral_rewards_family_idx on public.referral_rewards (family_id, created_at desc);
alter table public.referral_rewards enable row level security;
revoke all on public.referral_rewards from anon, authenticated;

create or replace function public.referral_on_paid()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  g public.guest_passes%rowtype;
  f public.families%rowtype;
  paying boolean;
  n int;
  until timestamptz;
  st text;
begin
  if not (new.plan = 'premium' and new.status in ('active', 'grace') and new.source = 'store') then return new; end if;
  if tg_op = 'UPDATE' and old.plan = 'premium' and old.status in ('active', 'grace') then return new; end if;
  select * into g from public.guest_passes where redeemed_family = new.family_id and rewarded_at is null for update;
  if not found then return new; end if;
  update public.guest_passes set rewarded_at = now() where code = g.code;
  select * into f from public.families where id = g.family_id for update;
  if not found then return new; end if;
  select count(*) into n from public.referral_rewards where family_id = g.family_id and created_at > now() - interval '365 days' and status <> 'capped';
  paying := exists (select 1 from public.family_subscriptions s where s.family_id = g.family_id and s.plan = 'premium'
                      and s.status in ('active', 'grace') and s.source = 'store' and (s.period_end is null or s.period_end > now()));
  if n >= 12 then
    st := 'capped';
  elsif paying then
    st := 'code_pending';
  else
    -- Davet eden abone değil: kalan ücretsiz süresinin (deneme ya da önceki ödül) sonuna 30 gün; süresi bittiyse bugünden
    until := greatest(now(), coalesce(f.bonus_until, now()),
                      coalesce(f.trial_started_at + make_interval(days => coalesce(f.trial_days::int, (public.billing_config() ->> 'trial_days')::int)), now()))
             + interval '30 days';
    update public.families set bonus_until = until where id = g.family_id;
    st := 'applied';
  end if;
  insert into public.referral_rewards (family_id, pass_code, status, bonus_until) values (g.family_id, g.code, st, until);
  if st = 'applied' then
    perform public.notify_parents(g.family_id, 'referral_reward', '1 ay hediye kazandın',
      'Davet ettiğin aile ParentApp''e abone oldu. ParentApp 1 ay daha ücretsiz. Teşekkürler!', jsonb_build_object('status', st), null);
  elsif st = 'code_pending' then
    perform public.notify_parents(g.family_id, 'referral_reward', '1 ay hediye kazandın',
      'Davet ettiğin aile abone oldu. Aboneliğin App Store''da olduğu için 1 aylık hediye kodunu birkaç gün içinde buradan göndereceğiz.',
      jsonb_build_object('status', st), null);
  end if;
  return new;
end $$;
drop trigger if exists referral_on_paid on public.family_subscriptions;
create trigger referral_on_paid after insert or update of plan, status on public.family_subscriptions
  for each row execute function public.referral_on_paid();

-- 7) Ailenin davet özeti (kimlik yok): kaç kod kullanıldı, kaçı abone oldu, kazanılan aylar, bekleyen / gönderilen Apple kodları
create or replace function public.my_referrals()
returns json language plpgsql stable security definer set search_path = '' as $$
declare fid uuid := public.my_family_id();
begin
  if fid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  return json_build_object(
    'joined', (select count(*) from public.guest_passes where family_id = fid and redeemed_at is not null),
    'paid', (select count(*) from public.guest_passes where family_id = fid and rewarded_at is not null),
    'months', (select count(*) from public.referral_rewards where family_id = fid and status in ('applied', 'code_pending', 'code_sent')),
    'year_left', greatest(0, 12 - (select count(*) from public.referral_rewards where family_id = fid
                                     and created_at > now() - interval '365 days' and status <> 'capped')),
    'pending_codes', (select count(*) from public.referral_rewards where family_id = fid and status = 'code_pending'),
    'codes', coalesce((select json_agg(json_build_object('code', offer_code, 'sent_at', code_sent_at) order by code_sent_at desc)
                         from public.referral_rewards where family_id = fid and status = 'code_sent'), '[]'::json),
    'bonus_until', (select bonus_until from public.families where id = fid)
  );
end $$;

revoke execute on function public.referral_on_paid() from public, anon, authenticated;
revoke execute on function public.my_referrals() from public, anon;
grant execute on function public.my_referrals() to authenticated;
revoke execute on function public.create_guest_pass() from public, anon;
grant execute on function public.create_guest_pass() to authenticated;
revoke execute on function public.redeem_guest_pass(text) from public, anon;
grant execute on function public.redeem_guest_pass(text) to authenticated;
