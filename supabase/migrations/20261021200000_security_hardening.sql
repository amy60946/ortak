-- =====================================================================
-- Güvenlik sertleştirmesi (öneri, 21 Ekim 2026; genel güvenlik denetiminden)
--   1. Girişsiz (anon) rol hiçbir public fonksiyonu çağıramaz. Uygulamaların hepsi girişten sonra çalışır
--      (GameApp'in çocuk cihazı da anonim oturumla 'authenticated' roldedir). Supabase'in varsayılanı
--      yeni fonksiyonları anon'a açar; bundan sonrakiler için de kapatılır.
--   2. family_premium(p_family_id): giriş yapmış kullanıcı yalnız kendi ailesini sorabilir (başka ailenin
--      kimliği verilirse false). SQL Editor / service_role (auth.uid() boş) bütün aileleri sorabilir
--      (analytics.families_overview bunu kullanır).
-- Tekrar çalıştırılabilir. Davranış değişikliği yok: hiçbir uygulama bu fonksiyonları girişsiz ya da
-- başka aile için çağırmıyor.
-- =====================================================================

create or replace function public.family_premium(p_family_id uuid default null)
returns boolean language sql stable security definer set search_path = '' as $$
  with f as (
    select case
      when p_family_id is null then public.my_family_id()
      when auth.uid() is null or p_family_id = public.my_any_family_id() then p_family_id
    end as id)
  select f.id is not null and (
    exists (
      select 1 from public.family_subscriptions s
      where s.family_id = f.id and s.plan = 'premium' and (s.period_end is null or s.period_end > now())
    ) or exists (
      select 1 from public.clinic_links l
      where l.family_id = f.id and l.status = 'active' and public.clinic_active(l.clinic_id)
    ))
  from f
$$;

-- Var olan bütün public fonksiyonlar (uzantılar hariç): giriş yapmış kullanıcının ve service_role'ün bugünkü erişimi
-- açık yetkiyle korunur, sonra anon'dan ve herkese açık (PUBLIC) yetkiden geri alınır.
do $$
declare
  r record;
  has_service boolean := exists (select 1 from pg_roles where rolname = 'service_role');
begin
  for r in
    select p.oid, p.oid::regprocedure as fn
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    if has_function_privilege('authenticated', r.oid, 'execute') then
      execute format('grant execute on function %s to authenticated', r.fn);
    end if;
    if has_service and has_function_privilege('service_role', r.oid, 'execute') then
      execute format('grant execute on function %s to service_role', r.fn);
    end if;
    execute format('revoke execute on function %s from public', r.fn);
    execute format('revoke execute on function %s from anon', r.fn);
  end loop;
end $$;

-- Bundan sonra oluşturulacak fonksiyonlar da anon'a kapalı başlasın
alter default privileges in schema public revoke execute on functions from anon;
alter default privileges in schema public revoke execute on functions from public;
