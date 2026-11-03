-- Davet ödülü Apple teklif kodu havuzu (kullanıcı kararı 3 Kasım 2026: seçenek B "kod havuzu", elle giriş yedek).
-- Önce: migrations/20261028120000_guest_pass.sql (referral_rewards). Sözleşme: sozlesme/admin.md "Davet ödülleri",
-- sozlesme/veritabani.md "Davet ödülü kod havuzu", akislar.md 19 adım 7, hukuk/46 Ek A.
--
-- Ekip App Store Connect'te tek kullanımlık kod üretir (aylık ve yıllık ürün için ayrı, "1 ay ücretsiz", en çok 6 ay
-- geçerli), dosyayı panele yükler. App Store'dan ödeyen davet edene ödül yazılınca ailenin ürününe (aylık/yıllık) uygun,
-- en erken süresi dolacak (en az 14 gün kalan) kod kendiliğinden atanır ve tek bildirim gider. Havuzda uygun kod yoksa
-- ödül `code_pending` kalır; kod yüklenince bekleyenlere sırayla atanır; panelden tek tek elle de kod girilebilir.
-- Atanmamış kod hiçbir yere dönmez (panel yalnız sayı ve son 4 karakteri görür); denetim kaydına kod yazılmaz.
-- Tekrar çalıştırılabilir.

-- 1) Havuz: kişisel veri yok (aileye bağ referral_rewards.offer_code üzerinden)
create table if not exists public.offer_code_pool (
  code        text primary key check (code ~ '^[A-Z0-9]{6,64}$'),
  billing     text not null check (billing in ('monthly', 'yearly')),
  batch       text not null check (char_length(batch) between 1 and 60),
  expires_at  timestamptz not null,
  added_at    timestamptz not null default now(),
  added_by    uuid references auth.users (id) on delete set null,
  assigned_at timestamptz
);
create index if not exists offer_code_pool_free_idx on public.offer_code_pool (billing, expires_at) where assigned_at is null;
alter table public.offer_code_pool enable row level security;
revoke all on public.offer_code_pool from anon, authenticated;

-- 2) Ödüle kod ata (iç). p_code boşsa havuzdan; doluysa elle girilen kod (havuzdaysa atanmış işaretlenir).
--    Döner: atanan kod ya da null (havuzda uygun kod yok). p_notify: ebeveyne "kod hazır" bildirimi.
create or replace function public.referral_assign(p_reward uuid, p_code text default null, p_notify boolean default true)
returns text language plpgsql security definer set search_path = '' as $$
declare
  rw public.referral_rewards%rowtype;
  bill text;
  c text := upper(regexp_replace(coalesce(p_code, ''), '\s', '', 'g'));
begin
  select * into rw from public.referral_rewards where id = p_reward for update;
  if not found or rw.status <> 'code_pending' then return null; end if;
  if c = '' then
    select coalesce(s.billing, 'monthly') into bill from public.family_subscriptions s where s.family_id = rw.family_id;
    update public.offer_code_pool set assigned_at = now()
     where code = (select p.code from public.offer_code_pool p
                    where p.assigned_at is null and p.billing = coalesce(bill, 'monthly') and p.expires_at > now() + interval '14 days'
                    order by p.expires_at, p.added_at limit 1 for update skip locked)
    returning code into c;
    if c is null then return null; end if;
  else
    if c !~ '^[A-Z0-9]{4,64}$' then raise exception 'Kod yalnız harf ve rakam olmalı (4–64)'; end if;
    if exists (select 1 from public.referral_rewards where offer_code = c) then raise exception 'Bu kod başka bir aileye gönderildi'; end if;
    if exists (select 1 from public.offer_code_pool where code = c and assigned_at is not null) then
      raise exception 'Bu kod havuzda kullanılmış görünüyor';
    end if;
    update public.offer_code_pool set assigned_at = now() where code = c;
  end if;
  update public.referral_rewards set status = 'code_sent', offer_code = c, code_sent_at = now() where id = p_reward;
  if p_notify then
    perform public.notify_parents(rw.family_id, 'referral_reward', 'Hediye kodun hazır',
      'Davet ödülün olan 1 aylık App Store kodu hazır. Davet sayfasında "Kodu kullan"a dokun.',
      jsonb_build_object('status', 'code_sent'), null);
  end if;
  return c;
end $$;

-- Bekleyen ödüllere sırayla havuzdan kod (iç). Döner: atanan sayı.
create or replace function public.referral_assign_pending()
returns int language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  for r in select id from public.referral_rewards where status = 'code_pending' order by created_at loop
    if public.referral_assign(r.id, null, true) is not null then n := n + 1; end if;
  end loop;
  return n;
end $$;

-- 3) Ödül tetiği (20261028120000_guest_pass.sql'deki sürüm + havuz): kod hemen atanırsa tek bildirim "kod hazır".
create or replace function public.referral_on_paid()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  g public.guest_passes%rowtype;
  f public.families%rowtype;
  paying boolean;
  n int;
  until timestamptz;
  st text;
  rid uuid;
  sent text;
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
  insert into public.referral_rewards (family_id, pass_code, status, bonus_until) values (g.family_id, g.code, st, until)
  returning id into rid;
  if st = 'code_pending' then sent := public.referral_assign(rid, null, false); end if;
  if st = 'applied' then
    perform public.notify_parents(g.family_id, 'referral_reward', '1 ay hediye kazandın',
      'Davet ettiğin aile ParentApp''e abone oldu. ParentApp 1 ay daha ücretsiz. Teşekkürler!', jsonb_build_object('status', st), null);
  elsif sent is not null then
    perform public.notify_parents(g.family_id, 'referral_reward', '1 ay hediye kazandın',
      'Davet ettiğin aile abone oldu. 1 aylık App Store hediye kodun hazır: davet sayfasında "Kodu kullan"a dokun.',
      jsonb_build_object('status', 'code_sent'), null);
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

-- 4) Panel: özet (her admin okur). Kod yok; gönderilenlerde yalnız son 4 karakter.
create or replace function public.admin_referral_overview()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare since timestamptz := now() - interval '30 days';
begin
  perform public.admin_require();
  return jsonb_build_object(
    'invites', (select jsonb_build_object(
        'created', count(*), 'redeemed', count(*) filter (where redeemed_at is not null),
        'paid', count(*) filter (where rewarded_at is not null),
        'created_30', count(*) filter (where created_at > since),
        'redeemed_30', count(*) filter (where redeemed_at > since),
        'paid_30', count(*) filter (where rewarded_at > since)) from public.guest_passes),
    'rewards', (select jsonb_build_object(
        'applied', count(*) filter (where status = 'applied'), 'code_sent', count(*) filter (where status = 'code_sent'),
        'code_pending', count(*) filter (where status = 'code_pending'), 'capped', count(*) filter (where status = 'capped'),
        'months_30', count(*) filter (where status in ('applied', 'code_sent') and created_at > since)) from public.referral_rewards),
    'pending', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'family_id', r.family_id, 'family_name', f.name,
        'created_at', r.created_at, 'billing', coalesce(s.billing, 'monthly')) order by r.created_at)
      from public.referral_rewards r join public.families f on f.id = r.family_id
      left join public.family_subscriptions s on s.family_id = r.family_id where r.status = 'code_pending'), '[]'::jsonb),
    'sent', coalesce((select jsonb_agg(x order by x ->> 'code_sent_at' desc) from (
        select jsonb_build_object('id', r.id, 'family_id', r.family_id, 'family_name', f.name, 'code_sent_at', r.code_sent_at,
                                  'code_tail', right(r.offer_code, 4)) x
          from public.referral_rewards r join public.families f on f.id = r.family_id
         where r.status = 'code_sent' order by r.code_sent_at desc limit 20) t), '[]'::jsonb),
    'pool', (select jsonb_build_object(
        'monthly', count(*) filter (where billing = 'monthly' and assigned_at is null and expires_at > now() + interval '14 days'),
        'yearly', count(*) filter (where billing = 'yearly' and assigned_at is null and expires_at > now() + interval '14 days'),
        'expiring_30', count(*) filter (where assigned_at is null and expires_at > now() and expires_at <= now() + interval '30 days'),
        'expired', count(*) filter (where assigned_at is null and expires_at <= now()),
        'assigned', count(*) filter (where assigned_at is not null)) from public.offer_code_pool),
    'batches', coalesce((select jsonb_agg(jsonb_build_object('batch', batch, 'billing', billing, 'expires_at', expires_at,
        'added_at', added_at, 'total', total, 'assigned', assigned) order by added_at desc)
      from (select batch, billing, min(expires_at) expires_at, min(added_at) added_at, count(*) total,
                   count(*) filter (where assigned_at is not null) assigned
              from public.offer_code_pool group by batch, billing) b), '[]'::jsonb)
  );
end $$;

-- 5) Panel: kod dosyası yükle (finance/owner). Geçersiz ve tekrar edenler atlanır; ardından bekleyen ödüllere atanır.
create or replace function public.admin_offer_codes_add(p_codes text[], p_billing text, p_expires date, p_batch text, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['finance']);
  total int := coalesce(cardinality(p_codes), 0);
  valid text[];
  bad int;
  added int;
  b text := nullif(trim(coalesce(p_batch, '')), '');
  given int;
begin
  if p_billing not in ('monthly', 'yearly') then raise exception 'Ürün aylık ya da yıllık olmalı'; end if;
  if p_expires is null or p_expires <= current_date + 14 or p_expires > current_date + 186 then
    raise exception 'Son kullanma tarihi 15 gün ile 6 ay arasında olmalı (App Store Connect''teki tarih)';
  end if;
  if total = 0 or total > 25000 then raise exception 'Bir seferde 1–25000 kod'; end if;
  if b is not null and char_length(b) > 60 then raise exception 'Parti adı en çok 60 karakter'; end if;
  b := coalesce(b, to_char(now(), 'YYYY-MM-DD') || ' ' || case p_billing when 'monthly' then 'aylık' else 'yıllık' end);
  select count(*) filter (where x !~ '^[A-Z0-9]{6,64}$'), coalesce(array_agg(distinct x) filter (where x ~ '^[A-Z0-9]{6,64}$'), '{}')
    into bad, valid from (select upper(regexp_replace(coalesce(c, ''), '\s', '', 'g')) x from unnest(p_codes) c) t;
  with ins as (
    insert into public.offer_code_pool (code, billing, batch, expires_at, added_by)
    select v, p_billing, b, (p_expires::timestamp at time zone 'Europe/Istanbul'), me from unnest(valid) v
     where not exists (select 1 from public.referral_rewards r where r.offer_code = v)
    on conflict (code) do nothing returning 1)
  select count(*) into added from ins;
  given := public.referral_assign_pending();
  perform public.admin_log(me, 'referral.codes_add', 'system', 'offer_codes:' || b, p_reason, null,
    jsonb_build_object('billing', p_billing, 'expires', p_expires, 'added', added, 'skipped', total - added, 'assigned', given));
  return jsonb_build_object('batch', b, 'added', added, 'invalid', bad, 'duplicate', total - bad - added, 'assigned', given);
end $$;

-- 6) Panel: partideki atanmamış kodları sil (yanlış dosya); p_batch boşsa süresi geçmiş atanmamış kodlar
create or replace function public.admin_offer_codes_remove(p_batch text, p_reason text)
returns int language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['finance']); n int; b text := nullif(trim(coalesce(p_batch, '')), '');
begin
  delete from public.offer_code_pool where assigned_at is null and (case when b is null then expires_at <= now() else batch = b end);
  get diagnostics n = row_count;
  perform public.admin_log(me, 'referral.codes_remove', 'system', 'offer_codes:' || coalesce(b, 'expired'), p_reason, null,
                           jsonb_build_object('removed', n));
  return n;
end $$;

-- 7) Panel: tek ödüle kod gönder (finance/support/owner). p_code boşsa havuzdan; doluysa elle (yedek yol).
create or replace function public.admin_referral_send_code(p_reward uuid, p_code text, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['finance', 'support']); rw public.referral_rewards%rowtype; c text;
begin
  select * into rw from public.referral_rewards where id = p_reward;
  if not found then raise exception 'Ödül bulunamadı'; end if;
  if rw.status <> 'code_pending' then raise exception 'Bu ödül kod beklemiyor'; end if;
  c := public.referral_assign(p_reward, p_code, true);
  if c is null then raise exception 'Havuzda bu ürün için uygun kod yok: kod dosyası yükle ya da kodu elle yaz'; end if;
  perform public.admin_log(me, 'referral.send_code', 'family', rw.family_id::text, p_reason, jsonb_build_object('status', 'code_pending'),
    jsonb_build_object('status', 'code_sent', 'from_pool', nullif(trim(coalesce(p_code, '')), '') is null, 'code_tail', right(c, 4)));
  return jsonb_build_object('ok', true, 'code_tail', right(c, 4));
end $$;

revoke execute on function public.referral_assign(uuid, text, boolean) from public, anon, authenticated;
revoke execute on function public.referral_assign_pending() from public, anon, authenticated;
revoke execute on function public.referral_on_paid() from public, anon, authenticated;
revoke execute on function public.admin_referral_overview() from public, anon;
grant execute on function public.admin_referral_overview() to authenticated;
revoke execute on function public.admin_offer_codes_add(text[], text, date, text, text) from public, anon;
grant execute on function public.admin_offer_codes_add(text[], text, date, text, text) to authenticated;
revoke execute on function public.admin_offer_codes_remove(text, text) from public, anon;
grant execute on function public.admin_offer_codes_remove(text, text) to authenticated;
revoke execute on function public.admin_referral_send_code(uuid, text, text) from public, anon;
grant execute on function public.admin_referral_send_code(uuid, text, text) to authenticated;
