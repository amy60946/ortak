-- =====================================================================
-- Beyaz şapka taraması 2 (öneri, 25 Ekim 2026)
--   W2-1: Kod deneme sayacı saldırganın KENDİ geçerli koduyla sıfırlanabiliyordu.
--         Başarılı kod kullanımı (redeem_child_code, join_family, redeem_clinic_invite_children, clinic_join_team)
--         "delete from code_attempts where user_id = …" yapıyordu; bu satırlar IP damgasını da taşıdığı için
--         oturum sınırı (10) ile birlikte IP sınırı (30) ve genel sınır (200) da sıfırlanıyordu.
--         Kendi ailesi/kliniği için sınırsız kod üretebilen biri her 9 hatalı denemeden sonra kendi kodunu kullanıp
--         sayacı temizleyerek başka ailelerin çocuk/davet kodlarını sınırsız deneyebiliyordu.
--   Düzeltme: başarı sayacı silmez. Eski denemeler code_throttled içindeki 1 günlük temizlikle gider; 15 dakikalık
--         pencere kendiliğinden kayar. Gövdeler öncekiyle aynı, yalnız bu satır çıkarıldı.
-- Tekrar çalıştırılabilir (create or replace).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.redeem_child_code(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid := auth.uid();
  v_ip text := public.request_ip();
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
  -- genel sınır (yeni anonim hesaplarla toplu tahmin): yalnız daha önce yanılmış oturum/IP için
  if (select count(*) from public.code_attempts where at > now() - interval '10 minutes') >= 200
     and exists (select 1 from public.code_attempts
                  where at > now() - interval '15 minutes' and (user_id = uid or (v_ip is not null and ip = v_ip))) then
    perform set_config('response.status', '429', true);
    return json_build_object('error', 'too_many_attempts', 'hint', 'too_many_attempts',
                             'message', 'Çok fazla hatalı deneme. 15 dakika sonra tekrar dene.');
  end if;

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

  return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)));
end $function$

;

CREATE OR REPLACE FUNCTION public.join_family(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if old_fid is not null and not exists (select 1 from public.profiles where family_id = old_fid) then
    delete from public.families where id = old_fid;
  end if;
  return json_build_object('family_id', inv.family_id);
end $function$

;

CREATE OR REPLACE FUNCTION public.redeem_clinic_invite_children(p_code text, p_child_ids uuid[])
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  return json_build_object('link_ids', ids, 'clinic_id', inv.clinic_id);
end $function$

;

CREATE OR REPLACE FUNCTION public.clinic_join_team(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  delete from public.clinic_invites where clinic_id = old_clinic;
  delete from public.clinics where id = old_clinic;
  return json_build_object('clinic_id', inv.clinic_id);
end $function$

;

revoke execute on function public.redeem_child_code(text), public.join_family(text),
  public.redeem_clinic_invite_children(text, uuid[]), public.clinic_join_team(text) from public, anon;
grant execute on function public.redeem_child_code(text), public.join_family(text),
  public.redeem_clinic_invite_children(text, uuid[]), public.clinic_join_team(text) to authenticated;
