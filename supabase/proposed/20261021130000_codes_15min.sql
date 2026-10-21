-- =====================================================================
-- Kodlar: 15 dakika geçerli + sunucu tarafı deneme sınırı (öneri, 21 Ekim 2026; kullanıcı onayı)
--   1. Bütün kodlar 15 dakika geçerli: ikinci ebeveyn daveti, çocuğun oyun giriş kodu, uzmanın aile kodu,
--      klinik ekip kodu. (Önce 24 saat / 7 gün.)
--   2. Kod kullanılamazsa nedeni ayrı söylenir: süresi doldu / daha önce kullanıldı / bulunamadı / çok deneme.
--      Süresi dolan kodlar 1 gün daha tabloda kalır ki "süresi doldu" denebilsin; aynı çocuğa yeni kod
--      üretilince eskisi silinmez, süresi bitirilir.
--   3. Deneme sınırı: bir oturum 15 dakikada en çok 10, bir IP adresi en çok 30 hatalı deneme yapabilir;
--      sonra 15 dakika "çok fazla deneme" (HTTP 429).
--   Yöntem: hata artık exception değil. Fonksiyon denemeyi kaydeder, HTTP durumunu 400/429 yapar
--   (PostgREST `response.status`) ve PostgREST hata biçiminde yanıt döner:
--     {"code":"P0001","message":"<Türkçe metin>","details":null,"hint":"code_expired","error":"code_expired"}
--   İşlem exception olmadığı için kaydedilir (PostgREST: hata olmayan işlem COMMIT ile biter), deneme kaydı
--   kalır. supabase-js bu yanıtı `error` olarak verir: error.message = metin, error.hint = neden kodu.
--   Hata kodları: code_invalid, code_expired, code_used, too_many_attempts.
--   join_family artık uuid yerine json döner ({family_id}) — 400 yanıtında gövde gerekiyor.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Deneme kaydı
-- ---------------------------------------------------------------------
create table if not exists public.code_attempts (
  id          bigserial primary key,
  user_id     uuid,
  ip          text,
  kind        text not null,
  created_at  timestamptz not null default now()
);
create index if not exists code_attempts_user_idx on public.code_attempts (user_id, created_at);
create index if not exists code_attempts_ip_idx on public.code_attempts (ip, created_at);
create index if not exists code_attempts_created_idx on public.code_attempts (created_at);
alter table public.code_attempts enable row level security;
-- Politika yok: istemci okuyamaz, yazamaz. Yalnız aşağıdaki fonksiyonlar.
revoke all on public.code_attempts from anon, authenticated;
revoke all on sequence public.code_attempts_id_seq from anon, authenticated;

-- İstemcinin IP adresi (Supabase API ağ geçidinin eklediği başlıklardan; Cloudflare başlığı önce)
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

-- Bu oturum / IP şu an engelli mi?
create or replace function public.code_blocked()
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_ip text := public.request_ip();
begin
  if auth.uid() is not null and (select count(*) from public.code_attempts a
       where a.user_id = auth.uid() and a.created_at > now() - interval '15 minutes') >= 10 then
    return true;
  end if;
  if v_ip is not null and (select count(*) from public.code_attempts a
       where a.ip = v_ip and a.created_at > now() - interval '15 minutes') >= 30 then
    return true;
  end if;
  return false;
end $$;

-- Hata yanıtı: denemeyi kaydet (engel yanıtı kaydedilmez), HTTP durumunu ayarla, PostgREST hata biçiminde dön
create or replace function public.code_error(p_kind text, p_error text)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare
  msg text := case p_error
    when 'code_expired' then 'Kodun süresi doldu (kodlar 15 dakika geçerli). Yeni kod iste.'
    when 'code_used' then 'Bu kod daha önce kullanıldı. Yeni kod iste.'
    when 'too_many_attempts' then 'Çok fazla hatalı deneme yapıldı. 15 dakika sonra tekrar dene.'
    else 'Kod bulunamadı. Harfleri kontrol et ya da yeni kod iste.' end;
begin
  if p_error <> 'too_many_attempts' then
    insert into public.code_attempts (user_id, ip, kind) values (auth.uid(), public.request_ip(), p_kind);
    delete from public.code_attempts where created_at < now() - interval '1 day';
  end if;
  perform set_config('response.status', case when p_error = 'too_many_attempts' then '429' else '400' end, true);
  return json_build_object('code', 'P0001', 'message', msg, 'details', null, 'hint', p_error, 'error', p_error);
end $$;

-- Kullanılmış / süresi dolmuş kodun nedeni (geçerliyse null)
create or replace function public.code_problem(p_used_at timestamptz, p_expires_at timestamptz)
returns text language sql immutable set search_path = '' as $$
  select case when p_used_at is not null then 'code_used' when p_expires_at <= now() then 'code_expired' end
$$;

-- ---------------------------------------------------------------------
-- Aile kodları (ikinci ebeveyn, çocuk girişi)
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
    -- Aynı çocuğun kullanılmamış eski kodlarının süresi biter (silinmez: kullanılırsa "süresi doldu" denir)
    update public.invite_codes i set expires_at = now()
      where i.child_id = p_child_id and i.used_at is null and i.expires_at > now();
  else
    p_child_id := null;
  end if;

  -- 1 günden eski, kullanılmamış kodları temizle
  delete from public.invite_codes i
    where i.family_id = fid and i.used_at is null and i.expires_at < now() - interval '1 day';

  loop
    new_code := public.random_code();
    exit when not exists (select 1 from public.clinic_invites ci where ci.code = new_code);
  end loop;
  loop
    begin
      insert into public.invite_codes (code, family_id, kind, child_id, created_by, expires_at)
      values (new_code, fid, p_kind, p_child_id, auth.uid(), exp);
      exit;
    exception when unique_violation then
      new_code := public.random_code();
    end;
  end loop;

  return query select new_code, exp;
end $$;

-- İkinci ebeveyn: davet koduyla aileye katıl. Dönüş: {family_id}; kod hatasında 400/429 + hata gövdesi.
drop function if exists public.join_family(text);
create function public.join_family(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  old_fid uuid;
  problem text;
begin
  if uid is null or not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  if public.code_blocked() then return public.code_error('parent', 'too_many_attempts'); end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'parent'
    for update;
  if not found then return public.code_error('parent', 'code_invalid'); end if;
  problem := public.code_problem(inv.used_at, inv.expires_at);
  if problem is not null then return public.code_error('parent', problem); end if;

  select family_id into old_fid from public.profiles where id = uid;
  if old_fid = inv.family_id then
    raise exception 'Zaten bu ailedesin';
  end if;

  -- Tek ebeveynli eski ailede kayıt varsa katılım onu sileceği için durdur
  if old_fid is not null
     and not exists (select 1 from public.profiles where family_id = old_fid and id <> uid)
     and (exists (select 1 from public.children where family_id = old_fid)
          or exists (select 1 from public.tasks where family_id = old_fid)) then
    raise exception 'Kendi hesabında kayıtlı çocuk ya da görev var; katılırsan silinir. Önce onları sil ya da başka bir e-postayla katıl.';
  end if;

  update public.profiles set family_id = inv.family_id, invited_by = inv.created_by where id = uid;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;

  if old_fid is not null and not exists (select 1 from public.profiles where family_id = old_fid) then
    delete from public.families where id = old_fid;
  end if;

  return json_build_object('family_id', inv.family_id);
end $$;

-- Çocuk (oyun): giriş koduyla bağlan. Başarı yanıtı aynı; kod hatasında 400/429 + hata gövdesi
-- (önceden exception: oyun yine HTTP hatası görür, metin "message" alanında).
create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  c public.children%rowtype;
  problem text;
begin
  if uid is null then
    raise exception 'Oturum gerekli' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles where id = uid) then
    raise exception 'Ebeveyn hesabıyla çocuk girişi yapılamaz';
  end if;
  if public.code_blocked() then return public.code_error('child', 'too_many_attempts'); end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'child'
    for update;
  if not found then return public.code_error('child', 'code_invalid'); end if;
  problem := public.code_problem(inv.used_at, inv.expires_at);
  if problem is not null then return public.code_error('child', problem); end if;

  update public.children set user_id = null where user_id = uid;
  update public.children set user_id = uid where id = inv.child_id returning * into c;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;

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
  if p_kind = 'clinician' and me.role <> 'owner' then raise exception 'Ekibe yalnızca klinik sahibi davet eder'; end if;
  delete from public.clinic_invites where clinic_id = me.clinic_id and used_at is null and expires_at < now() - interval '1 day';
  loop
    new_code := public.random_code();
    exit when not exists (select 1 from public.clinic_invites where code = new_code)
          and not exists (select 1 from public.invite_codes where code = new_code);
  end loop;
  insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at)
  values (new_code, me.clinic_id, me.id, p_kind, left(coalesce(p_label, ''), 60), exp);
  return json_build_object('code', new_code, 'expires_at', exp);
end $$;

-- Ebeveyn: rıza vermeden önce kimin isteği olduğunu görür (deneme sayılır)
create or replace function public.clinic_invite_preview(p_code text)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare
  r record;
  problem text;
begin
  if public.my_family_id() is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if public.code_blocked() then return public.code_error('clinic_family', 'too_many_attempts'); end if;
  select c.name as clinic, m.name as clinician, m.title, i.expires_at, i.used_at into r
  from public.clinic_invites i
  join public.clinics c on c.id = i.clinic_id
  join public.clinicians m on m.id = i.clinician_id
  where i.code = upper(trim(p_code)) and i.kind = 'family';
  if not found then return public.code_error('clinic_family', 'code_invalid'); end if;
  problem := public.code_problem(r.used_at, r.expires_at);
  if problem is not null then return public.code_error('clinic_family', problem); end if;
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
  problem text;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if coalesce(array_length(p_child_ids, 1), 0) = 0 then raise exception 'En az bir çocuk seç'; end if;
  if exists (select 1 from unnest(p_child_ids) x where not exists (
    select 1 from public.children c where c.id = x and c.family_id = fid)) then
    raise exception 'Çocuk bulunamadı';
  end if;
  if public.code_blocked() then return public.code_error('clinic_family', 'too_many_attempts'); end if;
  select * into inv from public.clinic_invites
    where code = upper(trim(p_code)) and kind = 'family'
    for update;
  if not found then return public.code_error('clinic_family', 'code_invalid'); end if;
  problem := public.code_problem(inv.used_at, inv.expires_at);
  if problem is not null then return public.code_error('clinic_family', problem); end if;
  -- tek INSERT: uzmana tek bildirim gider; zaten paylaşılan çocuk atlanır
  with ins as (
    insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id, label, consent_by)
    select inv.clinic_id, inv.clinician_id, fid, x, inv.label, auth.uid()
      from (select distinct unnest(p_child_ids) as x) u
     where not exists (select 1 from public.clinic_links l where l.clinic_id = inv.clinic_id and l.child_id = u.x and l.status = 'active')
    returning id)
  select coalesce(array_agg(id), '{}') into ids from ins;
  update public.clinic_invites set used_at = now(), used_by = auth.uid() where code = inv.code;
  return json_build_object('link_ids', ids, 'clinic_id', inv.clinic_id);
end $$;

-- ClinicApp kayıt ekranı: ekip kodu, hesap açılmadan ÖNCE denetlenir (kayıt tetikleyicisi hata nedenini
-- iletemez). Girişsiz çağrılabilen TEK fonksiyon; IP başına deneme sınırı geçerli.
-- Dönüş: {status:'valid', clinic} ya da hata gövdesi (400/429).
create or replace function public.clinic_team_code_status(p_code text)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare
  r record;
  problem text;
begin
  if public.code_blocked() then return public.code_error('clinician', 'too_many_attempts'); end if;
  select i.used_at, i.expires_at, c.name as clinic into r
    from public.clinic_invites i join public.clinics c on c.id = i.clinic_id
   where i.code = upper(trim(p_code)) and i.kind = 'clinician';
  if not found then return public.code_error('clinician', 'code_invalid'); end if;
  problem := public.code_problem(r.used_at, r.expires_at);
  if problem is not null then return public.code_error('clinician', problem); end if;
  return json_build_object('status', 'valid', 'clinic', r.clinic, 'expires_at', r.expires_at);
end $$;

-- Kayıt tetikleyicisi: ekip kodunun nedeni ayrı metinle (davranış aynı; süre artık 15 dakika)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  cid uuid;
  inv public.clinic_invites%rowtype;
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  if meta ->> 'account' = 'clinician' then
    if nullif(trim(meta ->> 'team_code'), '') is not null then
      select * into inv from public.clinic_invites
        where code = upper(trim(meta ->> 'team_code')) and kind = 'clinician'
        for update;
      if not found then
        raise exception 'Ekip kodu bulunamadı';
      end if;
      if inv.used_at is not null then
        raise exception 'Ekip kodu daha önce kullanıldı; klinik sahibinden yeni kod iste';
      end if;
      if inv.expires_at <= now() then
        raise exception 'Ekip kodunun süresi doldu (15 dakika); klinik sahibinden yeni kod iste';
      end if;
      if (select count(*) from public.clinicians where clinic_id = inv.clinic_id)
         >= (select seat_limit from public.clinics where id = inv.clinic_id) then
        raise exception 'Kliniğin uzman koltuğu dolu';
      end if;
      cid := inv.clinic_id;
      update public.clinic_invites set used_at = now(), used_by = new.id where code = inv.code;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, left(coalesce(trim(meta ->> 'name'), ''), 80), left(coalesce(trim(meta ->> 'title'), ''), 80), 'member');
    else
      insert into public.clinics (name, created_by)
      values (left(coalesce(nullif(trim(meta ->> 'clinic_name'), ''), 'Kliniğim'), 120), new.id)
      returning id into cid;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, left(coalesce(trim(meta ->> 'name'), ''), 80), left(coalesce(trim(meta ->> 'title'), ''), 80), 'owner');
    end if;
    return new;
  end if;

  insert into public.families (created_by) values (new.id) returning id into fid;
  insert into public.profiles (id, family_id, nickname, name, avatar)
  values (
    new.id,
    fid,
    left(coalesce(nullif(trim(meta ->> 'nickname'), ''), 'Ben'), 40),
    left(coalesce(trim(meta ->> 'name'), ''), 80),
    left(coalesce(nullif(meta ->> 'avatar', ''), 'erkek'), 200)
  );
  return new;
end $$;

-- Var olan kodlar: kalan süreleri 15 dakikayı aşmasın
update public.invite_codes set expires_at = least(expires_at, created_at + interval '15 minutes')
 where used_at is null and expires_at > created_at + interval '15 minutes';
update public.clinic_invites set expires_at = least(expires_at, created_at + interval '15 minutes')
 where used_at is null and expires_at > created_at + interval '15 minutes';

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke execute on function public.request_ip() from public, anon, authenticated;
revoke execute on function public.code_blocked() from public, anon, authenticated;
revoke execute on function public.code_error(text, text) from public, anon, authenticated;
revoke execute on function public.code_problem(timestamptz, timestamptz) from public, anon, authenticated;
revoke execute on function public.create_invite_code(text, uuid) from public, anon;
revoke execute on function public.join_family(text) from public, anon;
revoke execute on function public.redeem_child_code(text) from public, anon;
revoke execute on function public.clinic_create_invite(text, text) from public, anon;
revoke execute on function public.clinic_invite_preview(text) from public, anon;
revoke execute on function public.redeem_clinic_invite(text, uuid) from public, anon;
revoke execute on function public.redeem_clinic_invite_children(text, uuid[]) from public, anon;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.create_invite_code(text, uuid) to authenticated;
grant execute on function public.join_family(text) to authenticated;
grant execute on function public.redeem_child_code(text) to authenticated;
grant execute on function public.clinic_create_invite(text, text) to authenticated;
grant execute on function public.clinic_invite_preview(text) to authenticated;
grant execute on function public.redeem_clinic_invite(text, uuid) to authenticated;
grant execute on function public.redeem_clinic_invite_children(text, uuid[]) to authenticated;
-- Bilerek girişsiz: kayıt öncesi ekip kodu denetimi (deneme sınırlı). test_security.sql izin listesinde.
revoke execute on function public.clinic_team_code_status(text) from public;
grant execute on function public.clinic_team_code_status(text) to anon, authenticated;
