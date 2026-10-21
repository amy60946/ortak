-- =====================================================================
-- Sunucu kuralları: oyunla sunucu arasındaki farklar kapatılır (karar: 19 Ekim 2026, kullanıcı).
--   1. Görev ödülü en çok 50 coin (oyunun sahte arka ucuyla aynı).            [ekonomi.md E1]
--   2. Dükkân seviye kilidi sunucuda da denetlenir (seviye = kayıttaki XP).   [ekonomi.md E4]
--   3. Geçmiş gün: çocuk yalnız bugünü ve dünü işaretleyebilir.              [durumlar.md D3]
--   4. Kod deneme sınırı: 15 dakikada 10 hatalı deneme → 429.                [durumlar.md §3]
--   5. Onay geri alınınca, onaylanırken verilen coin düşülür.               [ekonomi.md E6]
--   6. Fiyat sıfır olamaz (oyunla aynı).                                     [ekonomi.md E2]
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Görev ödülü üst sınırı. NOT VALID: var olan kayıtlar bozulmaz; yeni/düzenlenen atamalar denetlenir.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'task_assignments_coins_max') then
    alter table public.task_assignments add constraint task_assignments_coins_max check (coins <= 50) not valid;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 6. Fiyat sıfır olamaz
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'game_items_price_positive') then
    alter table public.game_items add constraint game_items_price_positive check (price > 0) not valid;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Seviye kilidi. Seviye eşikleri oyunun Resources/Data/levels.json dosyasıyla aynıdır
--    (Sv n için gereken toplam XP). Seviye oyun kaydındaki Xp.TotalXp'den hesaplanır; kayıt yoksa 1.
-- ---------------------------------------------------------------------
create table if not exists public.game_levels (
  level     integer primary key check (level >= 1),
  total_xp  integer not null check (total_xp >= 0)
);
alter table public.game_levels enable row level security;
drop policy if exists "seviye: herkes okur" on public.game_levels;
create policy "seviye: herkes okur" on public.game_levels for select to authenticated using (true);
revoke insert, update, delete on public.game_levels from anon, authenticated;

insert into public.game_levels (level, total_xp) values
  (1, 0), (2, 100), (3, 235), (4, 417), (5, 663), (6, 995), (7, 1443), (8, 2048), (9, 2865), (10, 3968),
  (11, 5457), (12, 7467), (13, 10181), (14, 13845), (15, 18791)
on conflict (level) do update set total_xp = excluded.total_xp;

create or replace function public.child_level(p_child_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce((
    select max(l.level) from public.game_levels l
    where l.total_xp <= coalesce((
      select case when jsonb_typeof(s.data -> 'Xp' -> 'TotalXp') = 'number' then (s.data -> 'Xp' ->> 'TotalXp')::numeric end
      from public.game_saves s where s.child_id = p_child_id), 0)
  ), 1)
$$;

-- Harcama: öncekiyle aynı + seviye kilidi ('level_locked').
create or replace function public.spend_coins(p_tx text, p_item_id text, p_quantity integer)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.children%rowtype;
  it public.game_items%rowtype;
  total integer;
  bal integer;
begin
  select * into me from public.children where user_id = auth.uid() for update;   -- aynı çocuğun eşzamanlı harcamaları sıraya girer
  if not found then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  if p_tx is null or char_length(p_tx) not between 8 and 64 then
    raise exception 'Geçersiz işlem kimliği';
  end if;
  if exists (select 1 from public.coin_ledger where child_id = me.id and reason = 'spend' and ref = p_tx) then
    return json_build_object('ok', true, 'error', null, 'balance', public.coin_balance(me.id));
  end if;
  select * into it from public.game_items where item_id = p_item_id;
  if not found or p_quantity is null or p_quantity not between 1 and 20 then
    return json_build_object('ok', false, 'error', 'unknown_item', 'balance', public.coin_balance(me.id));
  end if;
  if it.min_level > public.child_level(me.id) then
    return json_build_object('ok', false, 'error', 'level_locked', 'balance', public.coin_balance(me.id));
  end if;
  total := it.price * p_quantity;
  bal := public.coin_balance(me.id);
  if total > bal then
    return json_build_object('ok', false, 'error', 'not_enough_coins', 'balance', bal);
  end if;
  if total > 0 then
    insert into public.coin_ledger (family_id, child_id, amount, reason, ref, item_id, quantity)
    values (me.family_id, me.id, -total, 'spend', p_tx, p_item_id, p_quantity);
  end if;
  return json_build_object('ok', true, 'error', null, 'balance', bal - total);
end $$;

-- ---------------------------------------------------------------------
-- 3. Geçmiş gün: bugün ve dün (saat dilimi payı) işaretlenebilir; daha eskisi değil. Öncekiyle aynı + bir denetim.
-- ---------------------------------------------------------------------
create or replace function public.child_set_status(p_task_id uuid, p_date date, p_status text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
  t public.tasks%rowtype;
  cur public.completions%rowtype;
  target text := p_status;
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'declined', 'assigned') then
    raise exception 'Geçersiz durum';
  end if;
  select tk.* into t from public.tasks tk
    join public.task_assignments a on a.task_id = tk.id and a.child_id = me
    where tk.id = p_task_id;
  if not found or not public.task_occurs_on(t, p_date) then
    raise exception 'Görev bulunamadı';
  end if;
  if p_date > current_date + 1 then
    raise exception 'Gelecek günün görevi işaretlenemez';
  end if;
  if p_date < current_date - 1 then
    raise exception 'Geçmiş günün görevi işaretlenemez';
  end if;

  select * into cur from public.completions where task_id = p_task_id and child_id = me and date = p_date for update;
  if found and cur.status in ('approved', 'rejected') then
    raise exception 'Ebeveyn karar verdi' using errcode = 'P0001';
  end if;

  if p_status = 'assigned' then
    delete from public.completions where task_id = p_task_id and child_id = me and date = p_date;
    return 'assigned';
  end if;
  if p_status = 'pending' and not t.requires_review then
    target := 'approved';
  end if;
  insert into public.completions (family_id, task_id, child_id, date, status)
  values (t.family_id, p_task_id, me, p_date, target)
  on conflict (task_id, child_id, date) do update set status = excluded.status, created_at = now();
  return target;
end $$;

-- ---------------------------------------------------------------------
-- 4. Kod deneme sınırı. Hatalı deneme artık hata fırlatmaz (fırlatırsa kayıt geri alınır, sayılamaz):
--    yanıt gövdesi {"error": "..."} ve HTTP durumu PostgREST'in response.status ayarıyla 400 / 429.
--    İstemci için değişen yalnız gövde: oyun ve eski sürümler zaten "400 ve üstü = geçersiz kod" sayar.
-- ---------------------------------------------------------------------
create table if not exists public.code_attempts (
  id       bigserial primary key,
  user_id  uuid not null,
  at       timestamptz not null default now()
);
create index if not exists code_attempts_user_idx on public.code_attempts (user_id, at);
alter table public.code_attempts enable row level security;
-- Politika yok: yalnız redeem_child_code yazar/okur.
revoke all on public.code_attempts from anon, authenticated;

create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  c public.children%rowtype;
begin
  if uid is null then
    raise exception 'Oturum gerekli' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles where id = uid) then
    raise exception 'Ebeveyn hesabıyla çocuk girişi yapılamaz';
  end if;

  delete from public.code_attempts where user_id = uid and at < now() - interval '1 day';
  if (select count(*) from public.code_attempts where user_id = uid and at > now() - interval '15 minutes') >= 10 then
    perform set_config('response.status', '429', true);
    return json_build_object('error', 'too_many_attempts');
  end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'child'
    for update;

  if not found or inv.used_at is not null or inv.expires_at < now() then
    insert into public.code_attempts (user_id) values (uid);
    perform set_config('response.status', '400', true);
    return json_build_object('error', 'invalid_code');
  end if;

  update public.children set user_id = null where user_id = uid;
  update public.children set user_id = uid where id = inv.child_id returning * into c;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;
  delete from public.code_attempts where user_id = uid;

  return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)));
end $$;

-- ---------------------------------------------------------------------
-- 5. Onay geri alınınca: o tamamlama için defterde kalan net tutar düşülür (atamadaki o anki ödül değil).
-- ---------------------------------------------------------------------
create or replace function public.completions_coin_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  coins integer;
  was_approved boolean := tg_op in ('UPDATE', 'DELETE') and old.status = 'approved';
  is_approved boolean := tg_op in ('INSERT', 'UPDATE') and new.status = 'approved';
  row_ public.completions%rowtype;
begin
  if tg_op = 'DELETE' then row_ := old; else row_ := new; end if;
  if is_approved = was_approved then
    return null;
  end if;
  if is_approved then
    select a.coins into coins from public.task_assignments a where a.task_id = row_.task_id and a.child_id = row_.child_id;
    coins := coalesce(coins, 0);
    if coins = 0 then
      return null;
    end if;
    insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, coins, 'task', row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  else
    select coalesce(sum(l.amount), 0) into coins from public.coin_ledger l
      where l.child_id = row_.child_id and l.reason in ('task', 'task_undo') and split_part(l.ref, ':', 1) = row_.id::text;
    if coins <= 0 then
      return null;
    end if;
    insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, -coins, 'task_undo', row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.child_level(uuid) from public, anon, authenticated;
revoke execute on function public.completions_coin_trigger() from public, anon, authenticated;
revoke execute on function public.spend_coins(text, text, integer) from public, anon;
revoke execute on function public.child_set_status(uuid, date, text) from public, anon;
revoke execute on function public.redeem_child_code(text) from public, anon;
grant execute on function public.spend_coins(text, text, integer) to authenticated;
grant execute on function public.child_set_status(uuid, date, text) to authenticated;
grant execute on function public.redeem_child_code(text) to authenticated;
