-- =====================================================================
-- Hoş geldin coini + ilk ödül talebi bilgisi (öneri, 24 Ekim 2026; kullanıcı kararı)
--
-- 1. Hoş geldin coini (coin kuralının TEK istisnası):
--    "İlk oyuna giren için, ilk aksesuarını alabileceği bir coin kazandırt, istisna olsun … dükkânı kullanma
--    için alışkanlık olsun." Çocuk başına bir kez 20 coin (defter nedeni 'welcome'). Oyun (GameApp) ilk
--    beslemede claim_welcome_coins() çağırır. 20 = en ucuz Sv1 giyilebilir eşya (glasses_round 15) alınabilsin.
--    İkinci ve sonraki çağrılar yazmaz: {ok:false, error:'already_claimed'}.
--    Bakiye (coin_balance → child_me.balance, child_balance) bütün nedenleri toplar: 'welcome' kendiliğinden dahil.
--    Onay geri alma (completions_coin_trigger) yalnız 'task'/'task_undo' satırlarına bakar: hoş geldin coini
--    görev geri alınınca düşmez.
-- 2. İlk ödül talebi: çocuğun oyundaki İLK ödül isteğinde (reward_requests'te bu çocuğun source='child' hiçbir
--    satırı yokken; durum fark etmez) ebeveyn bildirimi kind 'reward_request' kalır, data'ya "first": true
--    eklenir ve başlık "İlk ödül talebi: …" olur. Sonraki isteklerde bildirim eskisi gibi (data'da "first" yok).
--    Ebeveynin doğrudan verdiği ödül (give_reward, source='parent') çocuğun talebi sayılmaz.
--    Yanıta "first" (boolean) eklendi; önceki alanlar aynı.
--
-- Uygulama: Supabase → SQL Editor → bu dosyanın tamamı → Run. Tekrar çalıştırılabilir.
-- Test: supabase/test/test_welcome_coins.sql, test_reward_first.sql (bash supabase/test/run.sh).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Coin defteri: yeni neden 'welcome' (çocuk başına en çok bir satır)
-- ---------------------------------------------------------------------
alter table public.coin_ledger drop constraint if exists coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check
  check (reason in ('task', 'task_undo', 'spend', 'adjust', 'welcome'));
create unique index if not exists coin_ledger_welcome_once on public.coin_ledger (child_id) where reason = 'welcome';

-- Çocuk (oyun): hoş geldin coinini al. Çocuk başına bir kez. jsonb {ok, coins, balance, error}
--   coins   = bu çağrıda eklenen coin (ilk çağrıda 20, sonra 0)
--   balance = yeni bakiye (child_me().balance ile aynı hesap: coin_balance)
--   error   = null | 'already_claimed'
-- Oturumda çocuk yoksa (ebeveyn hesabı, kaldırılmış bağlantı) hata 42501 "Bağlantı yok" (diğer çocuk RPC'leri gibi).
create or replace function public.claim_welcome_coins()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  welcome_coins constant integer := 20;   -- tek sabit; ekonomi.md §1 ve §2.4 ile aynı tutulur
  me public.children%rowtype;
  n integer;
begin
  select * into me from public.children where user_id = auth.uid() for update;   -- aynı çocuğun eşzamanlı çağrıları sıraya girer
  if not found then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
  values (me.family_id, me.id, welcome_coins, 'welcome', 'welcome')
  on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then
    return jsonb_build_object('ok', false, 'coins', 0, 'balance', public.coin_balance(me.id), 'error', 'already_claimed');
  end if;
  return jsonb_build_object('ok', true, 'coins', welcome_coins, 'balance', public.coin_balance(me.id), 'error', null);
end $$;

-- ---------------------------------------------------------------------
-- 2. Çocuk (oyun): ödül iste — 20261022130000_sun_stones_rewards.sql'deki gövde + ilk talep bilgisi.
--    Bakiye yetmeli; en çok 5 bekleyen istek; aynı ödül için bekleyen istek varsa o döner.
-- ---------------------------------------------------------------------
create or replace function public.request_reward(p_reward_id uuid, p_quantity integer default 1)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.children%rowtype;
  rw public.rewards%rowtype;
  rid uuid;
  q integer := coalesce(p_quantity, 1);
  label text;
  is_first boolean;
begin
  select * into me from public.children where user_id = auth.uid();
  if not found then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  select * into rw from public.rewards where id = p_reward_id and family_id = me.family_id and active
     and (cardinality(child_ids) = 0 or me.id = any (child_ids));
  if not found then raise exception 'Ödül bulunamadı'; end if;
  if q not between 1 and 20 or (rw.kind = 'item' and q <> 1) then raise exception 'Geçersiz adet'; end if;
  perform 1 from public.children where id = me.id for update;
  select id into rid from public.reward_requests where child_id = me.id and reward_id = rw.id and status = 'pending';
  if rid is not null then return json_build_object('request_id', rid, 'status', 'pending', 'first', false); end if;
  if (select count(*) from public.reward_requests where child_id = me.id and status = 'pending') >= 5 then
    raise exception 'Bekleyen 5 isteğin var; önce onlara karar verilsin' using hint = 'too_many_requests';
  end if;
  if public.stone_balance(me.id) < rw.cost * q then
    raise exception 'Yeterli Güneş Taşı yok' using errcode = 'P0001', hint = 'not_enough_stones';
  end if;
  label := public.reward_label(rw.title, rw.unit, rw.unit_amount * q);
  -- İlk talep: bu çocuğun daha önce oyundan hiçbir isteği yok (bekleyen, onaylanan, reddedilen, geri çekilen fark etmez)
  is_first := not exists (select 1 from public.reward_requests where child_id = me.id and source = 'child');
  insert into public.reward_requests (family_id, child_id, reward_id, title, quantity, cost, unit, amount, source, status)
  values (me.family_id, me.id, rw.id, rw.title, q, rw.cost * q, rw.unit, rw.unit_amount * q, 'child', 'pending') returning id into rid;
  if is_first then
    perform public.notify_parents(me.family_id, 'reward_request', 'İlk ödül talebi: ' || me.name || ' bir ödül istiyor',
                                  label || ' · ' || (rw.cost * q) || ' Güneş Taşı',
                                  jsonb_build_object('request_id', rid, 'child_id', me.id, 'first', true), me.id);
  else
    perform public.notify_parents(me.family_id, 'reward_request', me.name || ' bir ödül istiyor',
                                  label || ' · ' || (rw.cost * q) || ' Güneş Taşı', jsonb_build_object('request_id', rid, 'child_id', me.id), me.id);
  end if;
  return json_build_object('request_id', rid, 'status', 'pending', 'first', is_first);
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.claim_welcome_coins() from public, anon;
grant execute on function public.claim_welcome_coins() to authenticated;
revoke execute on function public.request_reward(uuid, integer) from public, anon;
grant execute on function public.request_reward(uuid, integer) to authenticated;
