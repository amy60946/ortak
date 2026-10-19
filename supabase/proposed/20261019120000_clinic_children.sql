-- =====================================================================
-- Uzman paylaşımı: birden fazla çocuk + çocuk ekle/çıkar (öneri, 19 Ekim 2026)
--   Sorun: uzman kodu tek kullanımlık; ikinci çocuk aynı kodla paylaşılamıyordu.
--   1. redeem_clinic_invite_children(kod, çocuklar[]): tek kodla seçilen bütün çocuklar aynı anda paylaşılır.
--   2. clinic_share_child(klinik, çocuk): ailenin o klinikle etkin paylaşımı varsa yeni kod gerekmeden
--      başka bir çocuk da eklenir (ebeveynin açık rızasıyla, ParentApp'te düğmeyle).
--   3. Çocuğu çıkarmak: mevcut revoke_clinic_link (değişmedi).
--   4. family_clinic_links artık clinic_id de döndürür (ParentApp klinik başına gruplar).
-- Tekrar çalıştırılabilir.
-- =====================================================================

create or replace function public.redeem_clinic_invite_children(p_code text, p_child_ids uuid[])
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  ids uuid[] := '{}';
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if coalesce(array_length(p_child_ids, 1), 0) = 0 then raise exception 'En az bir çocuk seç'; end if;
  if exists (select 1 from unnest(p_child_ids) x where not exists (
    select 1 from public.children c where c.id = x and c.family_id = fid)) then
    raise exception 'Çocuk bulunamadı';
  end if;
  select * into inv from public.clinic_invites
    where code = upper(trim(p_code)) and kind = 'family' and used_at is null and expires_at > now()
    for update;
  if not found then raise exception 'Kod geçersiz ya da süresi dolmuş'; end if;
  -- tek INSERT: uzmana tek bildirim gider (bildirim tetikleyicisi deyim düzeyinde); zaten paylaşılan çocuk atlanır
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

create or replace function public.clinic_share_child(p_clinic_id uuid, p_child_id uuid)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  base public.clinic_links%rowtype;
  lid uuid;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if not exists (select 1 from public.children where id = p_child_id and family_id = fid) then
    raise exception 'Çocuk bulunamadı';
  end if;
  select * into base from public.clinic_links
    where family_id = fid and clinic_id = p_clinic_id and status = 'active'
    order by consent_at limit 1;
  if not found then raise exception 'Bu uzmanla etkin paylaşım yok; uzmandan yeni kod iste'; end if;
  select id into lid from public.clinic_links where clinic_id = p_clinic_id and child_id = p_child_id and status = 'active';
  if lid is not null then return json_build_object('link_id', lid); end if;
  insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id, label, consent_by)
  values (p_clinic_id, base.clinician_id, fid, p_child_id, '', auth.uid())
  returning id into lid;
  return json_build_object('link_id', lid);
end $$;

drop function if exists public.family_clinic_links();
create function public.family_clinic_links()
returns table (link_id uuid, clinic_id uuid, child_id uuid, clinic text, clinician text, title text, consent_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.child_id, c.name, coalesce(m.name, ''), coalesce(m.title, ''), l.consent_at
  from public.clinic_links l
  join public.clinics c on c.id = l.clinic_id
  left join public.clinicians m on m.id = l.clinician_id
  where l.family_id = public.my_family_id() and l.status = 'active'
  order by l.consent_at
$$;

revoke execute on function public.redeem_clinic_invite_children(text, uuid[]) from public, anon;
revoke execute on function public.clinic_share_child(uuid, uuid) from public, anon;
revoke execute on function public.family_clinic_links() from public, anon;
grant execute on function public.redeem_clinic_invite_children(text, uuid[]) to authenticated;
grant execute on function public.clinic_share_child(uuid, uuid) to authenticated;
grant execute on function public.family_clinic_links() to authenticated;
