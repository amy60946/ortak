-- =====================================================================
-- Ö7 Gerçek ödül dükkânı (22 Ekim 2026; öneri — uygulanmadı)
--   Ebeveyn coin fiyatlı gerçek ödüller koyar (park, film gecesi, ekstra oyun süresi …). Çocuk oyunda "İsteğim" der;
--   ebeveyn ödülü verince coin düşer ("ebeveyn verince düşer", omurga analizi Ö7). Reddedilirse ya da çocuk vazgeçerse coin
--   hiç düşmemiştir. Bekleyen isteklerin toplamı çocuğun "kullanılabilir" coin'inden ayrılır (aynı coin iki kez istenemez).
--
--   rewards           : ailenin ödülleri (başlık ≤ 60, simge, fiyat 1–500, etkin mi, isteğe bağlı tek çocuk).
--   reward_requests   : istekler (pending → given | declined | cancelled), başlık ve fiyat istek anındaki kopyası.
--   coin_ledger       : yeni neden 'reward' (ref = istek kimliği; aynı istek iki kez düşülemez).
--   RPC (çocuk)       : child_rewards(), child_request_reward(reward, tx), child_cancel_reward_request(id)
--   RPC (ebeveyn)     : review_reward_request(id, give boolean)
--   Bildirim          : istek → ebeveynlere 'reward_request'; verildi/reddedildi → çocuğa 'reward_given' / 'reward_declined'.
--   Sınırlar          : çocuk başına en çok 3 bekleyen istek; aile başına en çok 40 etkin ödül.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------
create table if not exists public.rewards (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families (id) on delete cascade,
  child_id    uuid references public.children (id) on delete cascade,     -- null = ailenin bütün çocukları
  title       text not null check (char_length(btrim(title)) between 1 and 60),
  icon        text not null default 'gift' check (icon in ('gift', 'park', 'movie', 'game', 'treat', 'book', 'toy', 'trip', 'star')),
  price       integer not null check (price between 1 and 500),
  active      boolean not null default true,
  created_by  uuid references auth.users (id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists rewards_family_idx on public.rewards (family_id);
alter table public.rewards enable row level security;

drop policy if exists "ödül: ebeveyn okur" on public.rewards;
create policy "ödül: ebeveyn okur" on public.rewards for select to authenticated using (family_id = public.my_family_id());
drop policy if exists "ödül: ebeveyn ekler" on public.rewards;
create policy "ödül: ebeveyn ekler" on public.rewards for insert to authenticated
  with check (family_id = public.my_family_id()
              and (child_id is null or exists (select 1 from public.children c where c.id = child_id and c.family_id = public.my_family_id())));
drop policy if exists "ödül: ebeveyn günceller" on public.rewards;
create policy "ödül: ebeveyn günceller" on public.rewards for update to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id()
              and (child_id is null or exists (select 1 from public.children c where c.id = child_id and c.family_id = public.my_family_id())));
drop policy if exists "ödül: ebeveyn siler" on public.rewards;
create policy "ödül: ebeveyn siler" on public.rewards for delete to authenticated using (family_id = public.my_family_id());
drop policy if exists "ödül: çocuk okur" on public.rewards;
create policy "ödül: çocuk okur" on public.rewards for select to authenticated
  using (active and family_id = public.child_family(public.my_child_id()) and (child_id is null or child_id = public.my_child_id()));
revoke all on public.rewards from anon;
-- sütun düzeyi: ebeveyn ailesini / oluşturanı değiştiremez
revoke update on public.rewards from authenticated;
grant update (title, icon, price, active, child_id, updated_at) on public.rewards to authenticated;

create or replace function public.rewards_limit_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.title := btrim(new.title);
  new.updated_at := now();
  if new.active and (select count(*) from public.rewards r where r.family_id = new.family_id and r.active and r.id <> new.id) >= 40 then
    raise exception 'En çok 40 etkin ödül olabilir';
  end if;
  return new;
end $$;
drop trigger if exists rewards_limit on public.rewards;
create trigger rewards_limit before insert or update on public.rewards for each row execute function public.rewards_limit_trigger();

create table if not exists public.reward_requests (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  child_id     uuid not null references public.children (id) on delete cascade,
  reward_id    uuid references public.rewards (id) on delete set null,
  title        text not null,
  icon         text not null default 'gift',
  price        integer not null check (price between 1 and 500),
  status       text not null default 'pending' check (status in ('pending', 'given', 'declined', 'cancelled')),
  tx           text not null check (char_length(tx) between 8 and 64),          -- istemci işlem kimliği (tekrar gönderim güvenli)
  requested_at timestamptz not null default now(),
  decided_at   timestamptz,
  decided_by   uuid references auth.users (id) on delete set null,
  unique (child_id, tx)
);
create index if not exists reward_requests_family_idx on public.reward_requests (family_id, requested_at desc);
create index if not exists reward_requests_child_idx on public.reward_requests (child_id, requested_at desc);
alter table public.reward_requests enable row level security;
drop policy if exists "ödül isteği: ebeveyn okur" on public.reward_requests;
create policy "ödül isteği: ebeveyn okur" on public.reward_requests for select to authenticated using (family_id = public.my_family_id());
drop policy if exists "ödül isteği: çocuk okur" on public.reward_requests;
create policy "ödül isteği: çocuk okur" on public.reward_requests for select to authenticated using (child_id = public.my_child_id());
-- Yazma yalnız RPC'lerle.
revoke insert, update, delete on public.reward_requests from anon, authenticated;
revoke all on public.reward_requests from anon;

-- coin defteri: yeni neden
alter table public.coin_ledger drop constraint if exists coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check check (reason in ('task', 'task_undo', 'spend', 'adjust', 'reward'));

-- Realtime: uygulamalar açıkken istek durumu anında güncellenir
do $$ begin
  alter publication supabase_realtime add table public.reward_requests;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- ---------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------
create or replace function public.reward_pending_total(p_child uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(sum(price), 0)::integer from public.reward_requests where child_id = p_child and status = 'pending'
$$;
revoke execute on function public.reward_pending_total(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Çocuk RPC'leri
-- ---------------------------------------------------------------------
create or replace function public.child_rewards()
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  me public.children%rowtype;
  bal integer;
  held integer;
begin
  select * into me from public.children where user_id = auth.uid();
  if not found then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  bal := public.coin_balance(me.id); held := public.reward_pending_total(me.id);
  return json_build_object(
    'balance', bal, 'held', held, 'available', greatest(bal - held, 0),
    'rewards', coalesce((select json_agg(json_build_object('id', r.id, 'title', r.title, 'icon', r.icon, 'price', r.price) order by r.price, r.title)
                           from public.rewards r
                          where r.family_id = me.family_id and r.active and (r.child_id is null or r.child_id = me.id)), '[]'::json),
    'requests', coalesce((select json_agg(json_build_object('id', q.id, 'title', q.title, 'icon', q.icon, 'price', q.price, 'status', q.status,
                                                          'requested_at', q.requested_at, 'decided_at', q.decided_at) order by q.requested_at desc)
                            from (select * from public.reward_requests where child_id = me.id order by requested_at desc limit 20) q), '[]'::json));
end $$;

create or replace function public.child_request_reward(p_reward uuid, p_tx text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.children%rowtype;
  r public.rewards%rowtype;
  q public.reward_requests%rowtype;
  bal integer; held integer;
begin
  select * into me from public.children where user_id = auth.uid() for update;   -- aynı çocuğun istekleri sıraya girer
  if not found then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  if p_tx is null or char_length(p_tx) not between 8 and 64 then raise exception 'Geçersiz işlem kimliği'; end if;
  select * into q from public.reward_requests where child_id = me.id and tx = p_tx;
  if found then                                                                     -- tekrar gönderim: aynı sonuç
    return json_build_object('ok', true, 'error', null, 'id', q.id);
  end if;
  select * into r from public.rewards
   where id = p_reward and family_id = me.family_id and active and (child_id is null or child_id = me.id);
  if not found then return json_build_object('ok', false, 'error', 'unknown_reward'); end if;
  if (select count(*) from public.reward_requests where child_id = me.id and status = 'pending') >= 3 then
    return json_build_object('ok', false, 'error', 'too_many_pending');
  end if;
  bal := public.coin_balance(me.id); held := public.reward_pending_total(me.id);
  if bal - held < r.price then
    return json_build_object('ok', false, 'error', 'not_enough_coins', 'available', greatest(bal - held, 0));
  end if;
  insert into public.reward_requests (family_id, child_id, reward_id, title, icon, price, tx)
  values (me.family_id, me.id, r.id, r.title, r.icon, r.price, p_tx) returning * into q;
  perform public.notify_parents(me.family_id, 'reward_request', me.name || ' bir ödül istiyor',
                                r.title || ' · ' || r.price || ' coin', json_build_object('request_id', q.id)::jsonb, me.id);
  return json_build_object('ok', true, 'error', null, 'id', q.id);
end $$;

create or replace function public.child_cancel_reward_request(p_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare me uuid := public.my_child_id(); n integer;
begin
  if me is null then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  update public.reward_requests set status = 'cancelled', decided_at = now()
   where id = p_id and child_id = me and status = 'pending';
  get diagnostics n = row_count;
  return n > 0;
end $$;

-- ---------------------------------------------------------------------
-- Ebeveyn RPC'si: ver ya da reddet
-- ---------------------------------------------------------------------
create or replace function public.review_reward_request(p_id uuid, p_give boolean)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fam uuid := public.my_family_id();
  q public.reward_requests%rowtype;
  bal integer;
begin
  if fam is null then raise exception 'Ebeveyn girişi gerekli' using errcode = '42501'; end if;
  select * into q from public.reward_requests where id = p_id and family_id = fam for update;
  if not found then raise exception 'İstek bulunamadı'; end if;
  if q.status <> 'pending' then
    return json_build_object('ok', q.status = case when p_give then 'given' else 'declined' end, 'error', 'already_' || q.status, 'status', q.status);
  end if;
  perform 1 from public.children where id = q.child_id for update;                 -- harcamalarla aynı sıraya gir
  if p_give then
    bal := public.coin_balance(q.child_id);
    if bal < q.price then
      return json_build_object('ok', false, 'error', 'not_enough_coins', 'balance', bal, 'status', q.status);
    end if;
    insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
    values (q.family_id, q.child_id, -q.price, 'reward', q.id::text);
    update public.reward_requests set status = 'given', decided_at = now(), decided_by = auth.uid() where id = q.id;
    perform public.notify_child(q.child_id, 'reward_given', 'Ödülün hazır!', q.title, json_build_object('request_id', q.id)::jsonb);
    return json_build_object('ok', true, 'error', null, 'status', 'given', 'balance', bal - q.price);
  else
    update public.reward_requests set status = 'declined', decided_at = now(), decided_by = auth.uid() where id = q.id;
    perform public.notify_child(q.child_id, 'reward_declined', 'Ödül şimdilik bekleyecek', q.title || ' · coinlerin sende kaldı',
                                json_build_object('request_id', q.id)::jsonb);
    return json_build_object('ok', true, 'error', null, 'status', 'declined');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.child_rewards() from public, anon;
revoke execute on function public.child_request_reward(uuid, text) from public, anon;
revoke execute on function public.child_cancel_reward_request(uuid) from public, anon;
revoke execute on function public.review_reward_request(uuid, boolean) from public, anon;
revoke execute on function public.rewards_limit_trigger() from public, anon, authenticated;
grant execute on function public.child_rewards() to authenticated;
grant execute on function public.child_request_reward(uuid, text) to authenticated;
grant execute on function public.child_cancel_reward_request(uuid) to authenticated;
grant execute on function public.review_reward_request(uuid, boolean) to authenticated;
-- TRUNCATE satır güvenliğini atlar (bkz. 20261021300000_security_pentest.sql 11)
revoke truncate on table public.rewards, public.reward_requests from anon, authenticated;
