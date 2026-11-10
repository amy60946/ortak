-- Görünen ad Moyo (kullanıcı kararı 9 Kasım 2026: "Uygulama için Moyo kullan"). Ebeveyne giden üç bildirim metnindeki "ParentApp"
-- adı Moyo olur; işlevlerin geri kalanı değişmez (son tanımlarının birebir kopyası: guest_pass, referral_codes, sessions göçleri).
-- Yasal metinler (legal_seed) bu dosyada değil: ad değişikliği yeni sürüm ve yeniden onay demek (hukuk_notlari.md). Tekrar çalıştırılabilir.

-- redeem_guest_pass: son tanım 20261028120000_guest_pass.sql
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
    'Bir aile davetinle Moyo''ya başladı. Abone olurlarsa sen 1 ay ücretsiz kazanırsın.', jsonb_build_object('code', g.code), null);
  return json_build_object('ok', true, 'trial_ends_at', f.trial_started_at + interval '14 days');
end $$;

-- referral_on_paid: son tanım 20261103200000_referral_codes.sql
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
      'Davet ettiğin aile Moyo''ya abone oldu. Moyo 1 ay daha ücretsiz. Teşekkürler!', jsonb_build_object('status', st), null);
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

-- clinic_waitlist_offer: son tanım 20261105100000_sessions.sql
create or replace function public.clinic_waitlist_offer(p_waitlist uuid, p_starts_at timestamptz, p_duration int default 45,
                                                        p_room uuid default null, p_hours int default 24)
returns uuid language plpgsql security definer set search_path = '' as $$
declare w public.clinic_waitlist; v uuid; v_clin uuid;
begin
  select * into w from public.clinic_waitlist where id = p_waitlist and status in ('waiting', 'offered');
  if w.id is null or not public.clinic_link_mine(w.link_id) then raise exception 'waitlist_not_found' using errcode = 'P0002'; end if;
  if p_starts_at <= now() then raise exception 'offer_in_past' using errcode = '22023'; end if;
  v_clin := coalesce(w.clinician_id, auth.uid());
  perform public.session_check_refs(w.link_id, null, p_room, null);
  insert into public.clinic_sessions (clinic_id, clinician_id, link_id, starts_at, duration_min, room_id, status, visible_to_family,
                                      waitlist_id, offer_expires_at, created_by)
  values (w.clinic_id, v_clin, w.link_id, p_starts_at, coalesce(p_duration, 45), p_room, 'offered', true, w.id,
          least(now() + make_interval(hours => greatest(coalesce(p_hours, 24), 1)), p_starts_at), auth.uid())
  returning id into v;
  update public.clinic_waitlist set status = 'offered', updated_at = now() where id = w.id;
  perform public.session_notify_family(v, 'session_offer', 'Boşalan saat önerisi',
    public.session_when(p_starts_at) || ' · yanıtlamak için Moyo › Uzmanım');
  return v;
end $$;

