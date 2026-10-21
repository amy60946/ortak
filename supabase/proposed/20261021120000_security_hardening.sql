-- =====================================================================
-- Güvenlik sıkılaştırma (öneri, 21 Ekim 2026 — genel güvenlik denetimi)
--   1. Girişsiz (anon) kullanıcı hiçbir uygulama fonksiyonunu çağıramaz (hepsi zaten girişi denetliyordu;
--      bu, savunmayı katmanlı yapar). Giriş yapmış kullanıcının yetkileri değişmez.
--   2. family_premium(başka aile) artık bilgi sızdırmaz: yalnız kendi ailesi ya da rızalı bağlantısı olan klinik sorar.
--   3. TRUNCATE yetkisi anon/authenticated'dan alınır (TRUNCATE satır düzeyi güvenliği atlar; API'de kullanılmıyor).
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- 2. family_premium: başka ailenin abonelik durumu sorulamaz
create or replace function public.family_premium(p_family_id uuid default null)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  fid uuid := coalesce(p_family_id, public.my_family_id());
begin
  if fid is null then return false; end if;
  if fid is distinct from public.my_family_id() and not exists (
    select 1 from public.clinic_links l
     where l.family_id = fid and l.status = 'active' and l.clinic_id = public.my_clinic_id()) then
    return false;
  end if;
  return exists (
      select 1 from public.family_subscriptions s
      where s.family_id = fid and s.plan = 'premium' and (s.period_end is null or s.period_end > now())
    ) or exists (
      select 1 from public.clinic_links l
      where l.family_id = fid and l.status = 'active' and public.clinic_active(l.clinic_id)
    );
end $$;

-- 1. anon hiçbir public fonksiyonu çalıştıramaz (eklenti fonksiyonları hariç); authenticated'ın yetkisi korunur
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig, has_function_privilege('authenticated', p.oid, 'execute') as auth_ok
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
       and has_function_privilege('anon', p.oid, 'execute')
  loop
    if r.auth_ok then execute format('grant execute on function %s to authenticated', r.sig); end if;
    execute format('revoke execute on function %s from public, anon', r.sig);
  end loop;
end $$;

-- 3. TRUNCATE yalnız sunucu yönetiminde
do $$
declare r record;
begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' loop
    execute format('revoke truncate on table public.%I from anon, authenticated', r.relname);
  end loop;
end $$;
