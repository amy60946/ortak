-- =====================================================================
-- Kodlar 15 dakika + "süresi doldu / kullanıldı" ayrımı + IP sınırı (öneri, 22 Ekim 2026; kullanıcı isteği)
-- Önkoşul: migrations/20261021300000_security_pentest.sql (deneme sınırı: code_attempts, code_throttled, code_failed).
--   1. Bütün kodlar 15 dakika geçerli: ikinci ebeveyn daveti, çocuğun oyun kodu, uzmanın aile kodu, klinik ekip kodu
--      (önce 24 saat / 7 gün / 48 saat). Aynı çocuğa yeni kod üretilince eskisi silinmez, süresi biter.
--   2. Kod kullanılamazsa nedeni ayrı söylenir. Yanıt biçimi aynı kalır (geriye uyumlu):
--        {"error":"invalid_code","reason":"expired|used|not_found","hint":"<reason>","message":"<Türkçe metin>"} + HTTP 400
--      Çok deneme: {"error":"too_many_attempts","hint":"too_many_attempts","message":…} + HTTP 429.
--      Süresi dolan kod 1 gün tabloda kalır ki "süresi doldu" denebilsin.
--   3. Deneme sınırı oturuma ek olarak IP adresine de uygulanır (15 dakikada 30): çocuk oyunu her açılışta yeni
--      anonim oturum alabildiği için yalnız oturum sınırı aşılabiliyordu.
-- Tekrar çalıştırılabilir.
-- =====================================================================

alter table public.code_attempts add column if not exists ip text;
create index if not exists code_attempts_ip_idx on public.code_attempts (ip, at);

-- İstemcinin IP adresi (Supabase ağ geçidinin eklediği başlıklardan)
create or replace function public.request_ip()
returns text language plpgsql stable set search_path = '' as $$
declare
  h json;
begin
  begin
    h := nullif(current_setting('request.headers', true), '')::json;
  exception when others then
    return null;
  end;
  if h is null then return null; end if;
  return nullif(trim(coalesce(h ->> 'cf-connecting-ip', h ->> 'x-real-ip', split_part(h ->> 'x-forwarded-for', ',', 1))), '');
end $$;

-- Çok hatalı deneme (oturum 10 ya da IP 30, son 15 dakika) → HTTP 429 gövdesi; yoksa null
create or replace function public.code_throttled()
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_ip text := public.request_ip();
begin
  delete from public.code_attempts where at < now() - interval '1 day';
  if (select count(*) from public.code_attempts where user_id = auth.uid() and at > now() - interval '15 minutes') >= 10
     or (v_ip is not null and (select count(*) from public.code_attempts where ip = v_ip and at > now() - interval '15 minutes') >= 30) then
    perform set_config('response.status', '429', true);
    return json_build_object('error', 'too_many_attempts', 'hint', 'too_many_attempts',
                             'message', 'Çok fazla hatalı deneme. 15 dakika sonra tekrar dene.');
  end if;
  return null;
end $$;

-- Eski çağrılar için (nedensiz): deneme kaydı + 400
create or replace function public.code_failed(p_message text default 'Kod geçersiz ya da süresi dolmuş')
returns json language plpgsql security definer set search_path = '' as $$
begin
  insert into public.code_attempts (user_id, ip) values (auth.uid(), public.request_ip());
  perform set_config('response.status', '400', true);
  return json_build_object('error', 'invalid_code', 'message', p_message);
end $$;

-- Nedenli ret: deneme kaydı + 400
create or replace function public.code_rejected(p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  msg text := case p_reason
    when 'expired' then 'Kodun süresi doldu (kodlar 15 dakika geçerli). Yeni kod iste.'
    when 'used' then 'Bu kod daha önce kullanıldı. Yeni kod iste.'
    else 'Kod bulunamadı. Harfleri kontrol et ya da yeni kod iste.' end;
begin
  insert into public.code_attempts (user_id, ip) values (auth.uid(), public.request_ip());
  perform set_config('response.status', '400', true);
  return json_build_object('error', 'invalid_code', 'reason', coalesce(p_reason, 'not_found'),
                           'hint', coalesce(p_reason, 'not_found'), 'message', msg);
end $$;

-- Kullanılmış / süresi dolmuş (geçerliyse null; kod yoksa çağıran 'not_found' der)
create or replace function public.code_problem(p_used_at timestamptz, p_expires_at timestamptz)
returns text language sql stable set search_path = '' as $$
  select case when p_used_at is not null then 'used' when p_expires_at <= now() then 'expired' end
$$;

-- ---------------------------------------------------------------------
-- Aile kodları
-- ---------------------------------------------------------------------
create or replace function public.create_invite_code(p_kind text default 'parent', p_child_id uuid default null)
returns table (code text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  fid uuid := public.my_family_id();
  new_code text;
  exp timestamptz := now() + interval '15 minutes';
begin
  if fid is null then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  if p_kind not in ('parent', 'child') then
    raise exception 'Geçersiz kod türü';
  end if;
  if p_kind = 'child' then
    if p_child_id is null or not exists (
      select 1 from public.children c where c.id = p_child_id and c.family_id = fid
    ) then
      raise exception 'Çocuk bulunamadı';
    end if;
    -- Aynı çocuğun kullanılmamış eski kodlarının süresi biter (kullanılırsa "süresi doldu" denir)
    update public.invite_codes i set expires_at = now()
      where i.child_id = p_child_id and i.used_at is null and i.expires_at > now();
  else
    p_child_id := null;
  end if;
  delete from public.invite_codes i
    where i.family_id = fid and i.used_at is null and i.expires_at < now() - interval '1 day';
  loop
    new_code := public.random_code();
    exit when not exists (select 1 from public.invite_codes ic where ic.code = new_code)
          and not exists (select 1 from public.clinic_invites ci where ci.code = new_code);
  end loop;
  insert into public.invite_codes (code, family_id, kind, child_id, created_by, expires_at)
  values (new_code, fid, p_kind, p_child_id, auth.uid(), exp);
  return query select new_code, exp;
end $$;

create or replace function public.join_family(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  old_fid uuid;
  t json;
begin
  if uid is null or not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  t := public.code_throttled();
  if t is not null then return t; end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'parent'
    for update;
  if not found then return public.code_rejected('not_found'); end if;
  if public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.code_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;

  select family_id into old_fid from public.profiles where id = uid;
  if old_fid = inv.family_id then
    raise exception 'Zaten bu ailedesin';
  end if;
  if old_fid is not null
     and not exists (select 1 from public.profiles where family_id = old_fid and id <> uid)
     and (exists (select 1 from public.children where family_id = old_fid)
          or exists (select 1 from public.tasks where family_id = old_fid)) then
    raise exception 'Kendi hesabında kayıtlı çocuk ya da görev var; katılırsan silinir. Önce onları sil ya da başka bir e-postayla katıl.';
  end if;

  update public.profiles set family_id = inv.family_id, invited_by = inv.created_by where id = uid;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;
  delete from public.code_attempts where user_id = uid;
  if old_fid is not null and not exists (select 1 from public.profiles where family_id = old_fid) then
    delete from public.families where id = old_fid;
  end if;
  return json_build_object('family_id', inv.family_id);
end $$;

create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  c public.children%rowtype;
  t json;
begin
  if uid is null then
    raise exception 'Oturum gerekli' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles where id = uid) then
    raise exception 'Ebeveyn hesabıyla çocuk girişi yapılamaz';
  end if;
  if exists (select 1 from public.clinicians where id = uid) then
    raise exception 'Uzman hesabıyla çocuk girişi yapılamaz';
  end if;
  t := public.code_throttled();
  if t is not null then return t; end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'child'
    for update;
  if not found then return public.code_rejected('not_found'); end if;
  if public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.code_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;

  update public.children set user_id = null where user_id = uid;
  update public.children set user_id = uid where id = inv.child_id returning * into c;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;
  delete from public.code_attempts where user_id = uid;

  return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)));
end $$;

-- ---------------------------------------------------------------------
-- Klinik kodları (aile paylaşımı, ekip)
-- ---------------------------------------------------------------------
alter table public.clinic_invites alter column expires_at set default now() + interval '15 minutes';

create or replace function public.clinic_create_invite(p_kind text default 'family', p_label text default '')
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  new_code text;
  exp timestamptz := now() + interval '15 minutes';
begin
  select * into me from public.clinicians where id = auth.uid();
  if not found then raise exception 'Yalnızca uzman hesabı'; end if;
  if p_kind not in ('family', 'clinician') then raise exception 'Geçersiz davet türü'; end if;
  if not public.clinician_access() then raise exception 'Üyelik etkin değil' using errcode = 'P0402'; end if;
  if p_kind = 'clinician' and me.role <> 'owner' then raise exception 'Ekibe yalnızca klinik sahibi davet eder'; end if;
  if p_kind = 'clinician' and (select seat_limit from public.clinics where id = me.clinic_id) <= 1 then
    raise exception 'Bireysel pakette ekip yok; Klinik paketine geçin';
  end if;
  delete from public.clinic_invites where clinic_id = me.clinic_id and used_at is null and expires_at < now() - interval '1 day';
  loop
    new_code := public.random_code(case when p_kind = 'clinician' then 8 else 6 end);
    exit when not exists (select 1 from public.clinic_invites where code = new_code)
          and not exists (select 1 from public.invite_codes where code = new_code);
  end loop;
  insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at)
  values (new_code, me.clinic_id, me.id, p_kind, left(coalesce(p_label, ''), 60), exp);
  return json_build_object('code', new_code, 'expires_at', exp);
end $$;

create or replace function public.clinic_invite_preview(p_code text)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare
  r record;
  t json;
begin
  if public.my_family_id() is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  select c.name as clinic, m.name as clinician, m.title, i.expires_at, i.used_at into r
  from public.clinic_invites i
  join public.clinics c on c.id = i.clinic_id
  join public.clinicians m on m.id = i.clinician_id
  where i.code = upper(trim(p_code)) and i.kind = 'family';
  if not found then return public.code_rejected('not_found'); end if;
  if public.code_problem(r.used_at, r.expires_at) is not null then
    return public.code_rejected(public.code_problem(r.used_at, r.expires_at));
  end if;
  return json_build_object('clinic', r.clinic, 'clinician', r.clinician, 'title', r.title, 'expires_at', r.expires_at);
end $$;

create or replace function public.redeem_clinic_invite(p_code text, p_child_id uuid)
returns json language plpgsql security definer set search_path = '' as $$
declare
  r json;
begin
  r := public.redeem_clinic_invite_children(p_code, array[p_child_id]);
  if r ->> 'error' is not null then return r; end if;
  return json_build_object('link_id', (r -> 'link_ids') ->> 0);
end $$;

create or replace function public.redeem_clinic_invite_children(p_code text, p_child_ids uuid[])
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  ids uuid[] := '{}';
  t json;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if coalesce(array_length(p_child_ids, 1), 0) = 0 then raise exception 'En az bir çocuk seç'; end if;
  if exists (select 1 from unnest(p_child_ids) x where not exists (
    select 1 from public.children c where c.id = x and c.family_id = fid)) then
    raise exception 'Çocuk bulunamadı';
  end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  select * into inv from public.clinic_invites
    where code = upper(trim(p_code)) and kind = 'family'
    for update;
  if not found then return public.code_rejected('not_found'); end if;
  if public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.code_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;
  with ins as (
    insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id, label, consent_by)
    select inv.clinic_id, inv.clinician_id, fid, x, inv.label, auth.uid()
      from (select distinct unnest(p_child_ids) as x) u
     where not exists (select 1 from public.clinic_links l where l.clinic_id = inv.clinic_id and l.child_id = u.x and l.status = 'active')
    returning id)
  select coalesce(array_agg(id), '{}') into ids from ins;
  update public.clinic_invites set used_at = now(), used_by = auth.uid() where code = inv.code;
  delete from public.code_attempts where user_id = auth.uid();
  return json_build_object('link_ids', ids, 'clinic_id', inv.clinic_id);
end $$;

create or replace function public.clinic_join_team(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  me public.clinicians%rowtype;
  inv public.clinic_invites%rowtype;
  old_clinic uuid;
  t json;
begin
  if uid is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  select * into me from public.clinicians where id = uid;
  if not found then raise exception 'Yalnızca uzman hesabı ekibe katılabilir'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;

  select * into inv from public.clinic_invites
    where code = upper(trim(p_code)) and kind = 'clinician'
    for update;
  if not found then return public.code_rejected('not_found'); end if;
  if public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.code_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;
  if inv.clinic_id = me.clinic_id then raise exception 'Zaten bu kliniğin ekibindesin'; end if;
  perform 1 from public.clinics where id = inv.clinic_id for update;
  if (select count(*) from public.clinicians where clinic_id = inv.clinic_id)
     >= (select seat_limit from public.clinics where id = inv.clinic_id) then
    raise exception 'Kliniğin uzman koltuğu dolu';
  end if;

  old_clinic := me.clinic_id;
  if exists (select 1 from public.clinicians where clinic_id = old_clinic and id <> uid)
     or exists (select 1 from public.clinic_links where clinic_id = old_clinic)
     or exists (select 1 from public.clinic_notes where clinic_id = old_clinic)
     or exists (select 1 from public.clinic_goals where clinic_id = old_clinic)
     or (to_regclass('public.billing_subscriptions') is not null
         and public.clinic_has_billing(old_clinic)) then
    raise exception 'Mevcut kliniğinde danışan, not, üyelik ya da başka uzman var; katılırsan kaybolur. Başka bir e-postayla kayıt olup ekip koduyla katıl.';
  end if;

  update public.clinicians set clinic_id = inv.clinic_id, role = 'member' where id = uid;
  update public.clinic_invites set used_at = now(), used_by = uid where code = inv.code;
  delete from public.code_attempts where user_id = uid;
  delete from public.clinic_invites where clinic_id = old_clinic;
  delete from public.clinics where id = old_clinic;
  return json_build_object('clinic_id', inv.clinic_id);
end $$;

-- Var olan açık kodlar: kalan süre 15 dakikayı aşmasın
update public.invite_codes set expires_at = least(expires_at, created_at + interval '15 minutes')
 where used_at is null and expires_at > created_at + interval '15 minutes';
update public.clinic_invites set expires_at = least(expires_at, created_at + interval '15 minutes')
 where used_at is null and expires_at > created_at + interval '15 minutes';

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.request_ip() from public, anon, authenticated;
revoke execute on function public.code_throttled() from public, anon, authenticated;
revoke execute on function public.code_failed(text) from public, anon, authenticated;
revoke execute on function public.code_rejected(text) from public, anon, authenticated;
revoke execute on function public.code_problem(timestamptz, timestamptz) from public, anon, authenticated;
revoke execute on function public.create_invite_code(text, uuid) from public, anon;
revoke execute on function public.join_family(text) from public, anon;
revoke execute on function public.redeem_child_code(text) from public, anon;
revoke execute on function public.clinic_create_invite(text, text) from public, anon;
revoke execute on function public.clinic_invite_preview(text) from public, anon;
revoke execute on function public.redeem_clinic_invite(text, uuid) from public, anon;
revoke execute on function public.redeem_clinic_invite_children(text, uuid[]) from public, anon;
revoke execute on function public.clinic_join_team(text) from public, anon;
grant execute on function public.create_invite_code(text, uuid) to authenticated;
grant execute on function public.join_family(text) to authenticated;
grant execute on function public.redeem_child_code(text) to authenticated;
grant execute on function public.clinic_create_invite(text, text) to authenticated;
grant execute on function public.clinic_invite_preview(text) to authenticated;
grant execute on function public.redeem_clinic_invite(text, uuid) to authenticated;
grant execute on function public.redeem_clinic_invite_children(text, uuid[]) to authenticated;
grant execute on function public.clinic_join_team(text) to authenticated;
