-- =====================================================================
-- TEST HESAPLARI — 2) SİL (GERİ ALINAMAZ)
-- Kullanıcı isteği 26 Ekim 2026 (28 Ekim'de yeniden; yeni tablolar eklendi): üç uygulamanın (GameApp, ParentApp, ClinicApp) bütün hesapları ve verileri silinir.
--   * Yönetim paneli hesabı (admin_users) KORUNUR: giriş, şifre ve iki adımlı doğrulama aynen kalır.
--     O hesabın uygulama verisi (aile/çocuk/klinik/uzman kaydı) varsa o da silinir; hesap yalnız panel hesabı olarak kalır.
--   * Önce bütün aileler ve klinikler (bağlı her şeyle), sonra yönetici olmayan bütün hesaplar silinir.
--   * Deneme geçmişi (trial_history) silinir: aynı e-postayla yeniden kayıt olan hesap yeniden deneme süresi alır.
--   * Denetim kaydı (admin_audit) silinemez, kalır. Ortak ayarlar (bayraklar, app_config, fiyatlar, katalog) kalır.
--   * Kovalardaki dosyalar (mail, abc, verify) SQL ile silinemez: Supabase → Storage'dan elle boşaltılır.
-- Tek işlem: bir hata olursa hiçbir şey silinmez.
-- =====================================================================
do $$
declare
  n_users int := 0;
  n_admin_data int := 0;
begin
  if not exists (select 1 from public.admin_users where role = 'owner') then
    raise exception 'Durdu: sahip (owner) yönetici bulunamadı; panel hesabı kaybolmasın diye hiçbir şey silinmedi';
  end if;

  -- 1) Bütün aile ve klinik verisi (çocuklar, görevler, ödüller, mesajlar, davetler, takip planları, abonelik satırları birlikte gider)
  delete from public.families;
  delete from public.clinics;
  -- 2) Yönetim paneli hesaplarının uygulama kaydı (hesabın kendisi, şifresi ve iki adımlı doğrulaması kalır)
  select count(*) into n_admin_data from public.admin_users a
   where exists (select 1 from public.profiles p where p.id = a.user_id) or exists (select 1 from public.clinicians c where c.id = a.user_id);
  delete from public.profiles p where exists (select 1 from public.admin_users a where a.user_id = p.id);
  delete from public.clinicians c where exists (select 1 from public.admin_users a where a.user_id = c.id);
  -- 3) Diğer bütün hesaplar (ebeveyn, uzman, çocuk cihazı, yarım kalmış kayıtlar)
  delete from auth.users u where not exists (select 1 from public.admin_users a where a.user_id = u.id);
  get diagnostics n_users = row_count;
  -- 4) Aynı e-postalarla yeniden kayıt + yeni deneme süresi için: deneme geçmişi (e-posta özeti) ve kod deneme sınırı sıfırlanır
  delete from public.trial_history;
  delete from public.code_attempts;
  -- 5) Test sıfırlamasında hesaba bağı kopan kayıtlar (28 Ekim 2026 eki; tablo yoksa atlanır):
  --    silinen hesapların yasal onay kayıtları (gerçek kullanımda ispat için kalır; test sıfırlamasında silinir),
  --    KVKK başvuruları, dosya silme kuyruğu (kovalar elle boşaltılıyor), hediye kartları
  if to_regclass('public.legal_acceptances') is not null then
    execute 'delete from public.legal_acceptances l where not exists (select 1 from auth.users u where u.id = l.user_id)';
  end if;
  if to_regclass('public.kvkk_requests') is not null then execute 'delete from public.kvkk_requests'; end if;
  if to_regclass('public.storage_trash') is not null then execute 'delete from public.storage_trash'; end if;
  if to_regclass('public.guest_passes') is not null then execute 'delete from public.guest_passes'; end if;

  raise notice 'Silinen hesap: %, verisi temizlenen yönetici hesabı: %', n_users, n_admin_data;
end $$;

-- Sonuç (hepsi 0 olmalı; "yönetici" satırı korunan panel hesabı sayısıdır)
select 'kalan hesap (yönetici dışı)' as ne, count(*) from auth.users a
 where not exists (select 1 from public.admin_users x where x.user_id = a.id)
union all select 'aile', count(*) from public.families
union all select 'çocuk', count(*) from public.children
union all select 'klinik', count(*) from public.clinics
union all select 'uzman', count(*) from public.clinicians
union all select 'deneme geçmişi', count(*) from public.trial_history
union all select 'yasal onay (silinen hesaplar)', count(*) from public.legal_acceptances l where not exists (select 1 from auth.users u where u.id = l.user_id)
union all select 'KVKK başvurusu', count(*) from public.kvkk_requests
union all select 'yönetici (korundu)', count(*) from public.admin_users;
