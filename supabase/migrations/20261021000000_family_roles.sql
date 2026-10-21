-- =====================================================================
-- İkinci ebeveyn (21 Ekim 2026; uygulandı)
--   1. Davet edilen ebeveyn uygulamayı eksiksiz kullanır (aynı family_id; bütün RLS buna bakar — değişiklik yok).
--   2. Aileyi kuran ebeveyn (families.created_by) aileden çıkarılamaz: başka bir ebeveynin profilini, aile sahibini
--      değiştiren ya da birini aileden çıkaran hiçbir yetki/RPC yoktur (profiles yalnız kendi satırı; families yalnız name).
--   3. Kim kimi davet etti kayıtlarda kalır: profiles.invited_by (uygulamada gösterilmez).
--   4. Koruma: kendi ailesinde çocuk/görev kaydı olan ebeveyn başka aileye katılırsa eski ailesi sessizce siliniyordu
--      → artık katılım reddedilir, açık mesaj verilir.
-- Tekrar çalıştırılabilir.
-- =====================================================================

alter table public.profiles add column if not exists invited_by uuid references auth.users (id) on delete set null;

create or replace function public.join_family(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  old_fid uuid;
begin
  if uid is null or not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'parent'
    for update;

  if not found or inv.used_at is not null or inv.expires_at < now() then
    raise exception 'Kod geçersiz ya da süresi dolmuş';
  end if;

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

  return inv.family_id;
end $$;
