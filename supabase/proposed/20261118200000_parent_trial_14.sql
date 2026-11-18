-- Moyo (ParentApp) ücretsiz denemesi 7 → 14 gün; davet koduyla gelen ailenin denemesi 14 → 21 gün (14 + 7).
-- Kullanıcı kararı 18 Kasım 2026 ("14 gün uygula"); araştırma ve gerekçe: https://claude.ai/artifact/DbmzVu1K8GxUhwh4sTVQPc
-- (sozlesme/akislar.md 18–19, durumlar.md). Tekrar çalıştırılabilir.
--
-- Deneme sonu başlangıç tarihinden hesaplandığı için (family_access_of: trial_started_at + gün):
--   · denemesi süren ailelerin süresi 14 güne tamamlanır;
--   · son 7 gün içinde denemesi bitmiş ailelerin denemesi kalan günleri kadar yeniden açılır (lansman öncesi, bilinçli);
--   · davet koduyla 14 gün almış ailelerin süresi 21 güne çıkar (davetin +7 gün avantajı korunur).
-- Deneme kartsız kalır: süre bitince aile ücretsiz plana düşer, kendiliğinden ücret alınmaz (değişmedi).

-- 1) Varsayılan süre: işlevin tabanı ve kayıtlı ayar (başka bir değere elle çekilmişse dokunulmaz)
create or replace function public.billing_config()
returns jsonb language sql stable security definer set search_path = '' as $$
  select '{"enforce": false, "trial_days": 14, "free_max_tasks": 3, "free_max_children": 1}'::jsonb
         || coalesce((select value from public.app_config where key = 'billing'), '{}'::jsonb)
$$;
revoke execute on function public.billing_config() from public, anon, authenticated;

update public.app_config set value = value || '{"trial_days": 14}'::jsonb
 where key = 'billing' and (value ->> 'trial_days')::int = 7;

-- 2) Davet koduyla 14 gün almış aileler (families.trial_days'i yalnız redeem_guest_pass yazar): +7 gün avantajı korunur
update public.families set trial_days = 21 where trial_days = 14;

-- 3) Davet kodu: "yeni aile" = varsayılan deneme süresi içinde (önce 7 gün); kullanınca varsayılan + 7 gün (önce sabit 14)
--    Son tanım: 20261110120000_moyo_name_texts.sql. Dönüş ve hata anahtarları aynı.
create or replace function public.redeem_guest_pass(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  f public.families%rowtype;
  g public.guest_passes%rowtype;
  t json;
  err text;
  base int := (public.billing_config() ->> 'trial_days')::int;
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
    when f.trial_started_at is not null and f.trial_started_at < now() - make_interval(days => base) then 'not_new'
  end;
  if err is not null then return json_build_object('ok', false, 'error', err); end if;

  update public.families set trial_days = base + 7, trial_started_at = coalesce(trial_started_at, now()) where id = fid returning * into f;
  update public.guest_passes set redeemed_family = fid, redeemed_at = now() where code = g.code;
  delete from public.code_attempts where user_id = auth.uid();
  perform public.notify_parents(g.family_id, 'guest_pass_used', 'Davetin kullanıldı',
    'Bir aile davetinle Moyo''ya başladı. Abone olurlarsa sen 1 ay ücretsiz kazanırsın.', jsonb_build_object('code', g.code), null);
  return json_build_object('ok', true, 'trial_ends_at', f.trial_started_at + make_interval(days => base + 7));
end $$;
revoke execute on function public.redeem_guest_pass(text) from public, anon;
grant execute on function public.redeem_guest_pass(text) to authenticated;
