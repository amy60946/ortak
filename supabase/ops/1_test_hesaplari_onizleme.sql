-- =====================================================================
-- TEST HESAPLARI — 1) ÖNİZLEME (hiçbir şeyi değiştirmez)
-- Kullanıcı isteği 26 Ekim 2026: üç uygulamadaki bütün test hesapları silinecek (hepsi kullanıcının), sonra sıfırdan.
-- Yönetim paneli hesapları (admin_users) KORUNUR. Bu dosya yalnız ne silineceğini gösterir.
-- Sonraki adım: 2_test_hesaplari_sil.sql
-- =====================================================================
with u as (
  select a.id, a.email,
         exists (select 1 from public.admin_users x where x.user_id = a.id) as yonetici,
         exists (select 1 from public.profiles p where p.id = a.id) as ebeveyn,
         exists (select 1 from public.clinicians c where c.id = a.id) as uzman,
         exists (select 1 from public.children k where k.user_id = a.id) as cocuk_cihazi
    from auth.users a
)
select case when yonetici then '1 KORUNUR (yönetim paneli)' else '2 SİLİNİR' end as sonuc,
       case when ebeveyn then 'ParentApp (ebeveyn)' when uzman then 'ClinicApp (uzman)'
            when cocuk_cihazi then 'GameApp (çocuk cihazı)' else 'uygulama verisi yok' end as tur,
       count(*) as hesap,
       string_agg(coalesce(email, '(e-postasız)'), ', ' order by email) filter (where yonetici or email is not null) as e_postalar
  from u group by 1, 2
union all
select '3 SİLİNİR (veri)', 'aile', count(*), null from public.families
union all
select '3 SİLİNİR (veri)', 'çocuk', count(*), null from public.children
union all
select '3 SİLİNİR (veri)', 'klinik', count(*), null from public.clinics
order by 1, 2;
