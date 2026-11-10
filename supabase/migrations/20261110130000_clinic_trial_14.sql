-- ClinicApp ücretsiz deneme 7 → 14 gün (kullanıcı kararı 10 Kasım 2026: "Clinic app ücretsiz deneme süresi 14 gün yapalım").
-- Önkoşul: migrations/20261022200000_clinic_billing.sql (varsayılan 7 gün) ve migrations/20261105090000_workspaces.sql (alan açan işlevler).
-- Tekrar çalıştırılabilir. Sözleşme: veritabani.md 8, akislar.md (üyelik 1. adım), durumlar.md (clinics.plan, trial).
--   1. Yeni klinik: kayıtta açılan kliniğin varsayılan denemesi 14 gün.
--   2. Bireysel alan ve yeni klinik alanı: uzmanın önceki alanı yoksa 14 gün (varsa deneme eskisi gibi ortak; yeni alan yeni deneme vermez).
--   3. Denemesi süren ya da son 14 günde açılmış klinikler 14 güne tamamlanır (uzmanın ilk alanının açılışından); panelden daha uzun verilmiş deneme kısalmaz.
-- Uzman Hizmet Sözleşmesi 10.4 "7 (yedi) gün … (Platform süreyi uzatabilir)" der; 14 gün bu hükmün içinde. Metin bir sonraki yasal sürümde 14 gün yazılır.

alter table public.clinics alter column trial_ends_at set default now() + interval '14 days';

-- Bireysel alan (yoksa açılır). Deneme süresi uzmanın daha önce açtığı alanlarla ortaktır (yeni alan yeni deneme vermez).
create or replace function public.clinician_personal_workspace_for(p_user uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  cid uuid;
  t timestamptz;
begin
  select * into me from public.clinicians where id = p_user;
  if not found then raise exception 'Yalnızca uzman hesabı' using errcode = '42501'; end if;
  select id into cid from public.clinics where personal_of = p_user;
  if cid is null then
    t := (select max(trial_ends_at) from public.clinics where created_by = p_user);
    insert into public.clinics (name, created_by, trial_ends_at)
    values (left(coalesce(nullif(btrim(me.name), ''), 'Bireysel çalışmam'), 120), p_user, coalesce(t, now() + interval '14 days'))
    returning id into cid;
    update public.clinics set personal_of = p_user where id = cid;
  end if;
  insert into public.clinic_members (clinic_id, clinician_id, role) values (cid, p_user, 'owner')
  on conflict (clinic_id, clinician_id) do update set status = 'active', role = 'owner', left_at = null;
  return cid;
end $$;
revoke execute on function public.clinician_personal_workspace_for(uuid) from public, anon, authenticated;

-- Yeni klinik alanı (uzman kendi kliniğini açar; sahibi olur). En çok 3 klinik; deneme süresi ortak.
create or replace function public.clinic_workspace_create(p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  nm text := left(btrim(coalesce(p_name, '')), 120);
  cid uuid;
  t timestamptz;
begin
  if uid is null or not exists (select 1 from public.clinicians where id = uid) then
    raise exception 'Yalnızca uzman hesabı' using errcode = '42501';
  end if;
  if nm = '' then raise exception 'name_required'; end if;
  if (select count(*) from public.clinics where created_by = uid and personal_of is null) >= 3 then
    raise exception 'too_many_clinics';
  end if;
  t := (select max(trial_ends_at) from public.clinics where created_by = uid);
  insert into public.clinics (name, created_by, trial_ends_at)
  values (nm, uid, coalesce(t, now() + interval '14 days')) returning id into cid;
  insert into public.clinic_members (clinic_id, clinician_id, role) values (cid, uid, 'owner');
  return cid;
end $$;
revoke execute on function public.clinic_workspace_create(text) from public, anon;
grant execute on function public.clinic_workspace_create(text) to authenticated;

-- Süren denemeler 14 güne: uzmanın ilk alanının açılışından 14 gün (alanların denemesi ortak kalır);
-- panelden daha uzun verilmiş deneme kısalmaz; ikinci çalıştırmada değişecek satır kalmaz.
update public.clinics c
   set trial_ends_at = f.first_at + interval '14 days'
  from (select created_by, min(created_at) as first_at from public.clinics where created_by is not null group by created_by) f
 where f.created_by = c.created_by
   and c.plan = 'trial'
   and c.trial_ends_at < f.first_at + interval '14 days'
   and f.first_at + interval '14 days' > now();
