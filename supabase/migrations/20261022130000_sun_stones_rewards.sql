-- =====================================================================
-- Güneş Taşı ile gerçek ödüller ve taş düşme (öneri, 22 Ekim 2026)
-- Önkoşul: migrations/20261019030000_sun_stones.sql (GameApp: defter + onayda kolay 1 / orta 2 / zor 3 taş).
--   İki sayı:
--     kazanılan (sun_stone_balance → child_me.sun_stones): görev/geri alma/düzeltme. Oyun adaya yerleştirmede bunu
--       kullanır; ödül ve ceza ADADAKİ İLERLEMEYİ DEĞİŞTİRMEZ (oyunda değişiklik gerekmez).
--     harcanabilir (stone_balance → sun_stones_spendable, child_me.sun_stones_spendable): kazanılan − ödüller −
--       düşülenler. Ödüller bununla alınır.
--   Güneş Taşı: coin'den ayrı ikinci para. Yalnız gerçek görevden gelir: onaylanan her görev zorluğa göre
--   kolay 1 / orta 2 / zor 3 taş (omurga analizi Ö1). Onay geri alınırsa verilen taş düşülür; görev silinirse kalır.
--   Ödül: ebeveynin koyduğu gerçek hayat ödülü. İki tür:
--     item     : eşya / etkinlik (ör. "Parkta 30 dakika"), fiyatı 1–500 taş.
--     exchange : değişim; "cost taş = unit_amount birim" (birim: minute = ekran süresi dakikası, money = TL harçlık),
--                adet adet alınır (1–20 kez). Ör. 1 taş = 10 dakika; 3 kez → 3 taş, 30 dakika.
--   Hangi çocuklar: child_ids (boş = hepsi). Simge: icon (uygulamanın simge anahtarı, ör. "film").
--   Ödül verme: ebeveyn doğrudan verir (give_reward) ya da çocuk oyunda ister (request_reward) → ebeveyn
--   onaylar/reddeder (decide_reward_request). Onayda taş düşülür; bakiye eksiye düşmez.
--   Taş düşme (ceza): ebeveyn 1–100 taş, isteğe bağlı nedenle (deduct_sun_stones); bakiyeden fazla düşülemez.
--   Bütün hareketler sun_stone_ledger'da (istemci yazamaz). Çocuğa ve diğer ebeveyne bildirim gider.
--   Ücretsiz planda: ödül ekleme/düzenleme, doğrudan verme ve taş düşme kapalı; çocuğun isteğine karar verilebilir.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Defter
-- ---------------------------------------------------------------------
alter table public.sun_stone_ledger add column if not exists note text;
alter table public.sun_stone_ledger add column if not exists created_by uuid references auth.users (id) on delete set null;
alter table public.sun_stone_ledger drop constraint if exists sun_stone_ledger_reason_check;
alter table public.sun_stone_ledger add constraint sun_stone_ledger_reason_check
  check (reason in ('task', 'task_undo', 'adjust', 'reward', 'penalty'));
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'sun_stone_ledger_note_check') then
    alter table public.sun_stone_ledger add constraint sun_stone_ledger_note_check check (char_length(note) <= 200);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'sun_stone_ledger_amount_range') then
    alter table public.sun_stone_ledger add constraint sun_stone_ledger_amount_range check (amount between -10000 and 10000) not valid;
  end if;
end $$;
create index if not exists sun_stone_ledger_child_created_idx on public.sun_stone_ledger (child_id, created_at desc);
revoke insert, update, delete, truncate on public.sun_stone_ledger from anon, authenticated;

-- Kazanılan (ada ilerlemesi): ödül/ceza hariç. child_me.sun_stones bunu döndürür (oyun için anlam aynı kalır).
create or replace function public.sun_stone_balance(p_child_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(coalesce(sum(amount), 0), 0)::integer from public.sun_stone_ledger
   where child_id = p_child_id and reason in ('task', 'task_undo', 'adjust')
$$;

-- Harcanabilir: bütün hareketler
create or replace function public.stone_balance(p_child_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select greatest(coalesce(sum(amount), 0), 0)::integer from public.sun_stone_ledger where child_id = p_child_id
$$;

-- child_me: + sun_stones_spendable (önceki alanlar aynı)
create or replace function public.child_me()
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  c public.children%rowtype;
begin
  select * into c from public.children where user_id = auth.uid();
  if not found then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  return json_build_object('child_id', c.id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)),
                           'balance', public.coin_balance(c.id),
                           'sun_stones', public.sun_stone_balance(c.id),
                           'sun_stones_spendable', public.stone_balance(c.id));
end $$;

-- ---------------------------------------------------------------------
-- Ödüller ve istekler
-- ---------------------------------------------------------------------
create table if not exists public.rewards (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  title        text not null check (char_length(trim(title)) between 1 and 60),
  kind         text not null default 'item' check (kind in ('item', 'exchange')),
  cost         integer not null check (cost between 1 and 500),
  unit         text check (unit in ('minute', 'money')),
  unit_amount  integer check (unit_amount between 1 and 1000),
  child_ids    uuid[] not null default '{}',   -- boş: bütün çocuklar
  icon         text not null default 'gift' check (icon ~ '^[a-z][a-z-]{0,29}$'),
  active       boolean not null default true,
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check ((kind = 'item' and unit is null and unit_amount is null)
      or (kind = 'exchange' and unit is not null and unit_amount is not null)),
  check (cardinality(child_ids) <= 20)
);
create index if not exists rewards_family_idx on public.rewards (family_id);
alter table public.rewards enable row level security;
drop policy if exists "ödül: ebeveyn" on public.rewards;
create policy "ödül: ebeveyn" on public.rewards for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id());
drop policy if exists "ödül: çocuk okur" on public.rewards;
create policy "ödül: çocuk okur" on public.rewards for select to authenticated
  using (public.my_child_id() is not null and family_id = public.my_any_family_id() and active
    and (cardinality(child_ids) = 0 or public.my_child_id() = any (child_ids)));
revoke insert, update on public.rewards from anon, authenticated;
grant insert (id, family_id, title, kind, cost, unit, unit_amount, child_ids, icon, active) on public.rewards to authenticated;
grant update (title, kind, cost, unit, unit_amount, child_ids, icon, active) on public.rewards to authenticated;
drop trigger if exists rewards_updated_at on public.rewards;
create trigger rewards_updated_at before update on public.rewards
  for each row execute function public.set_updated_at();

create or replace function public.rewards_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_full_access(new.family_id, 'ödüller');
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    if (select count(*) from public.rewards r where r.family_id = new.family_id) >= 100 then
      raise exception 'En çok 100 ödül eklenebilir';
    end if;
  end if;
  -- seçilen çocuklar bu aileden olmalı (tekrarlar atılır)
  new.child_ids := coalesce((select array_agg(distinct x) from unnest(new.child_ids) x), '{}');
  if exists (select 1 from unnest(new.child_ids) x where public.child_family(x) is distinct from new.family_id) then
    raise exception 'Çocuk bulunamadı';
  end if;
  new.title := trim(new.title);
  return new;
end $$;
drop trigger if exists rewards_guard on public.rewards;
create trigger rewards_guard before insert or update on public.rewards
  for each row execute function public.rewards_guard();

-- Ödülün kısa adı: değişimde miktarla ("Ekran süresi · 30 dakika")
create or replace function public.reward_label(p_title text, p_unit text, p_amount integer)
returns text language sql immutable set search_path = '' as $$
  select p_title || case p_unit when 'minute' then ' · ' || p_amount || ' dakika'
                                when 'money' then ' · ' || p_amount || ' TL' else '' end
$$;

create table if not exists public.reward_requests (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  child_id     uuid not null references public.children (id) on delete cascade,
  reward_id    uuid references public.rewards (id) on delete set null,
  title        text not null,
  quantity     integer not null default 1 check (quantity between 1 and 20),
  cost         integer not null check (cost between 1 and 10000),        -- toplam taş
  unit         text check (unit in ('minute', 'money')),
  amount       integer check (amount between 1 and 20000),               -- toplam dakika / TL
  source       text not null check (source in ('child', 'parent')),
  status       text not null check (status in ('pending', 'approved', 'rejected', 'canceled')),
  note         text check (char_length(note) <= 200),
  created_at   timestamptz not null default now(),
  decided_at   timestamptz,
  decided_by   uuid references auth.users (id) on delete set null
);
create index if not exists reward_requests_family_idx on public.reward_requests (family_id, created_at desc);
create index if not exists reward_requests_child_idx on public.reward_requests (child_id, status);
alter table public.reward_requests enable row level security;
drop policy if exists "istek: ebeveyn okur" on public.reward_requests;
create policy "istek: ebeveyn okur" on public.reward_requests for select to authenticated
  using (family_id = public.my_family_id());
drop policy if exists "istek: çocuk okur" on public.reward_requests;
create policy "istek: çocuk okur" on public.reward_requests for select to authenticated
  using (child_id = public.my_child_id());
revoke insert, update, delete, truncate on public.reward_requests from anon, authenticated;

-- ---------------------------------------------------------------------
-- RPC'ler
-- ---------------------------------------------------------------------
-- Harcanabilir bakiye: ebeveyn (kendi ailesinin çocuğu) ya da çocuk (yalnız kendisi)
create or replace function public.sun_stones_spendable(p_child_id uuid)
returns integer language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.child_family(p_child_id) is not distinct from public.my_family_id() and public.my_family_id() is not null)
     and p_child_id is distinct from public.my_child_id() then
    raise exception 'Yetki yok' using errcode = '42501';
  end if;
  return public.stone_balance(p_child_id);
end $$;

-- İç: ödülü onayla/ver (bakiye kilitli denetlenir)
create or replace function public.stone_spend(p_child uuid, p_family uuid, p_amount integer, p_reason text, p_ref text, p_note text)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  bal integer;
begin
  perform 1 from public.children where id = p_child for update;   -- aynı çocuğa eşzamanlı düşmeleri sırala
  bal := public.stone_balance(p_child);
  if bal < p_amount then
    raise exception 'Yeterli Güneş Taşı yok (bakiye %, gereken %)', bal, p_amount using errcode = 'P0001', hint = 'not_enough_stones';
  end if;
  insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref, note, created_by)
  values (p_family, p_child, -p_amount, p_reason, p_ref, nullif(left(trim(coalesce(p_note, '')), 200), ''), auth.uid());
  return bal - p_amount;
end $$;

-- Ebeveyn: ödülü doğrudan ver (değişimde p_quantity kez)
create or replace function public.give_reward(p_child_id uuid, p_reward_id uuid, p_quantity integer default 1)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  rw public.rewards%rowtype;
  rid uuid := gen_random_uuid();
  q integer := coalesce(p_quantity, 1);
  label text;
  bal integer;
begin
  if fid is null or public.child_family(p_child_id) is distinct from fid then
    raise exception 'Çocuk bulunamadı' using errcode = '42501';
  end if;
  perform public.require_full_access(fid, 'ödül verme');
  select * into rw from public.rewards where id = p_reward_id and family_id = fid and active;
  if not found or (cardinality(rw.child_ids) > 0 and not p_child_id = any (rw.child_ids)) then raise exception 'Ödül bulunamadı'; end if;
  if q not between 1 and 20 or (rw.kind = 'item' and q <> 1) then raise exception 'Geçersiz adet'; end if;
  label := public.reward_label(rw.title, rw.unit, rw.unit_amount * q);
  bal := public.stone_spend(p_child_id, fid, rw.cost * q, 'reward', rid::text, label);
  insert into public.reward_requests (id, family_id, child_id, reward_id, title, quantity, cost, unit, amount, source, status, decided_at, decided_by)
  values (rid, fid, p_child_id, rw.id, rw.title, q, rw.cost * q, rw.unit, rw.unit_amount * q, 'parent', 'approved', now(), auth.uid());
  perform public.notify_child(p_child_id, 'reward_given', 'Ödül kazandın: ' || label,
                              (rw.cost * q) || ' Güneş Taşı karşılığında', jsonb_build_object('request_id', rid));
  perform public.notify_parents(fid, 'reward_given', public.child_name(p_child_id) || ' ödül aldı', label,
                                jsonb_build_object('request_id', rid, 'child_id', p_child_id), p_child_id);
  return json_build_object('request_id', rid, 'balance', bal);
end $$;

-- Ebeveyn: Güneş Taşı düş (ceza). Bakiyeden fazla düşülemez.
create or replace function public.deduct_sun_stones(p_child_id uuid, p_amount integer, p_note text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  bal integer;
  n text := nullif(left(trim(coalesce(p_note, '')), 200), '');
begin
  if fid is null or public.child_family(p_child_id) is distinct from fid then
    raise exception 'Çocuk bulunamadı' using errcode = '42501';
  end if;
  if p_amount is null or p_amount not between 1 and 100 then raise exception 'Düşülecek taş 1–100 arası olmalı'; end if;
  perform public.require_full_access(fid, 'Güneş Taşı düşme');
  bal := public.stone_spend(p_child_id, fid, p_amount, 'penalty', gen_random_uuid()::text, n);
  perform public.notify_child(p_child_id, 'stones_deducted', p_amount || ' Güneş Taşı düşüldü',
                              coalesce(n, ''), jsonb_build_object('amount', p_amount));
  perform public.notify_parents(fid, 'stones_deducted', public.child_name(p_child_id) || ': ' || p_amount || ' Güneş Taşı düşüldü',
                                coalesce(n, ''), jsonb_build_object('child_id', p_child_id, 'amount', p_amount), p_child_id);
  return json_build_object('balance', bal);
end $$;

-- Çocuk (oyun): ödül iste (değişimde p_quantity kez). Bakiye yetmeli; en çok 5 bekleyen istek;
-- aynı ödül için bekleyen istek varsa o döner.
create or replace function public.request_reward(p_reward_id uuid, p_quantity integer default 1)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.children%rowtype;
  rw public.rewards%rowtype;
  rid uuid;
  q integer := coalesce(p_quantity, 1);
  label text;
begin
  select * into me from public.children where user_id = auth.uid();
  if not found then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  select * into rw from public.rewards where id = p_reward_id and family_id = me.family_id and active
     and (cardinality(child_ids) = 0 or me.id = any (child_ids));
  if not found then raise exception 'Ödül bulunamadı'; end if;
  if q not between 1 and 20 or (rw.kind = 'item' and q <> 1) then raise exception 'Geçersiz adet'; end if;
  perform 1 from public.children where id = me.id for update;
  select id into rid from public.reward_requests where child_id = me.id and reward_id = rw.id and status = 'pending';
  if rid is not null then return json_build_object('request_id', rid, 'status', 'pending'); end if;
  if (select count(*) from public.reward_requests where child_id = me.id and status = 'pending') >= 5 then
    raise exception 'Bekleyen 5 isteğin var; önce onlara karar verilsin' using hint = 'too_many_requests';
  end if;
  if public.stone_balance(me.id) < rw.cost * q then
    raise exception 'Yeterli Güneş Taşı yok' using errcode = 'P0001', hint = 'not_enough_stones';
  end if;
  label := public.reward_label(rw.title, rw.unit, rw.unit_amount * q);
  insert into public.reward_requests (family_id, child_id, reward_id, title, quantity, cost, unit, amount, source, status)
  values (me.family_id, me.id, rw.id, rw.title, q, rw.cost * q, rw.unit, rw.unit_amount * q, 'child', 'pending') returning id into rid;
  perform public.notify_parents(me.family_id, 'reward_request', me.name || ' bir ödül istiyor',
                                label || ' · ' || (rw.cost * q) || ' Güneş Taşı', jsonb_build_object('request_id', rid, 'child_id', me.id), me.id);
  return json_build_object('request_id', rid, 'status', 'pending');
end $$;

-- Çocuk: bekleyen isteğini geri çeker
create or replace function public.cancel_reward_request(p_request_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.reward_requests set status = 'canceled', decided_at = now()
   where id = p_request_id and child_id = public.my_child_id() and status = 'pending';
  if not found then raise exception 'İstek bulunamadı'; end if;
end $$;

-- Ebeveyn: çocuğun isteğine karar (onayda taş düşülür)
create or replace function public.decide_reward_request(p_request_id uuid, p_approve boolean, p_note text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  rq public.reward_requests%rowtype;
  bal integer;
  n text := nullif(left(trim(coalesce(p_note, '')), 200), '');
begin
  if fid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  select * into rq from public.reward_requests where id = p_request_id and family_id = fid for update;
  if not found then raise exception 'İstek bulunamadı'; end if;
  if rq.status <> 'pending' then raise exception 'Bu isteğe zaten karar verildi'; end if;
  if p_approve then
    bal := public.stone_spend(rq.child_id, fid, rq.cost, 'reward', rq.id::text, public.reward_label(rq.title, rq.unit, rq.amount));
  else
    bal := public.stone_balance(rq.child_id);
  end if;
  update public.reward_requests set status = case when p_approve then 'approved' else 'rejected' end,
         note = n, decided_at = now(), decided_by = auth.uid() where id = rq.id;
  perform public.notify_child(rq.child_id, 'reward_decided',
    case when p_approve then 'İsteğin onaylandı: ' else 'İsteğin şimdilik olmadı: ' end || public.reward_label(rq.title, rq.unit, rq.amount),
    coalesce(n, ''), jsonb_build_object('request_id', rq.id, 'approved', p_approve));
  return json_build_object('status', case when p_approve then 'approved' else 'rejected' end, 'balance', bal);
end $$;

-- ---------------------------------------------------------------------
-- Realtime + yetkiler
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['sun_stone_ledger', 'rewards', 'reward_requests'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

revoke execute on function public.stone_balance(uuid) from public, anon, authenticated;
revoke execute on function public.sun_stone_balance(uuid) from public, anon, authenticated;
revoke execute on function public.child_me() from public, anon;
grant execute on function public.child_me() to authenticated;
revoke execute on function public.rewards_guard() from public, anon, authenticated;
revoke execute on function public.reward_label(text, text, integer) from public, anon, authenticated;
revoke execute on function public.stone_spend(uuid, uuid, integer, text, text, text) from public, anon, authenticated;
revoke execute on function public.sun_stones_spendable(uuid) from public, anon;
revoke execute on function public.give_reward(uuid, uuid, integer) from public, anon;
revoke execute on function public.deduct_sun_stones(uuid, integer, text) from public, anon;
revoke execute on function public.request_reward(uuid, integer) from public, anon;
revoke execute on function public.cancel_reward_request(uuid) from public, anon;
revoke execute on function public.decide_reward_request(uuid, boolean, text) from public, anon;
grant execute on function public.sun_stones_spendable(uuid) to authenticated;
grant execute on function public.give_reward(uuid, uuid, integer) to authenticated;
grant execute on function public.deduct_sun_stones(uuid, integer, text) to authenticated;
grant execute on function public.request_reward(uuid, integer) to authenticated;
grant execute on function public.cancel_reward_request(uuid) to authenticated;
grant execute on function public.decide_reward_request(uuid, boolean, text) to authenticated;
