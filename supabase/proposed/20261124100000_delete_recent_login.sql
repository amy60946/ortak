-- =====================================================================
-- Hesap silmeden önce şifre yeniden sorulur: sunucu tarafı (ÖNERİ, 24 Kasım 2026; kullanıcı isteği 24 Kasım 2026: "hesap silerken son
-- adım olarak tekrar şifre talep edilsin, doğru girerse silinsin"). Tekrar çalıştırılabilir.
--   Uygulamalar (Moyo, Moyo Mercek) silmeden hemen önce şifreyi sorar ve signInWithPassword ile yeniden giriş yapar; şifre yanlışsa
--   silme hiç çağrılmaz. Bu öneri aynı kuralı sunucuda da uygular: delete_account() yalnız son 10 dakikada ŞİFREYLE giriş yapılmış
--   bir oturumdan çalışır (oturum belirtecindeki `amr` kaydı; şifre SQL'e hiç gönderilmez, günlüklere düşmez). Böylece ele geçirilmiş
--   eski bir oturumla hesap silinemez.
--   Bayrak `delete_recent_login` (satır yoksa KAPALI): önce uygulamaların şifre soran sürümleri yayınlanır, sonra bayrak önce tek
--   kişiye (admin_set_user_flag), sonra herkese açılır. Kapalıyken davranış bugünküyle aynıdır (eski sürümler bozulmaz).
--   Şifresi olmayan anonim hesap (çocuk cihazı) bu denetimin dışındadır.
-- Önkoşul (canlıda): migrations/20261023000000_admin.sql (delete_account, account_delete_of, flag_on).
-- Sözleşme: sozlesme/akislar.md 28, veritabani.md 42, admin.md (bayrak), durumlar.md (recent_login_required). Test: test_delete_recent_login.sql.
-- =====================================================================

do $$ begin
  if to_regprocedure('public.account_delete_of(uuid)') is null or to_regprocedure('public.flag_on(uuid, text)') is null then
    raise exception 'Önce migrations/20261023000000_admin.sql çalıştırılmalı (account_delete_of / flag_on yok)';
  end if;
end $$;

-- Oturum son p_minutes dakika içinde şifreyle mi açıldı? (Supabase oturum belirteci: amr = [{"method":"password","timestamp":<epoch sn>}, …];
-- belirteç yenilense de kayıt ilk giriş anını taşır.)
create or replace function public.recent_password_login(p_minutes integer default 10)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
      from jsonb_array_elements(case when jsonb_typeof(auth.jwt() -> 'amr') = 'array' then auth.jwt() -> 'amr' else '[]'::jsonb end) a
     where jsonb_typeof(a) = 'object'
       and a ->> 'method' = 'password'
       and (a ->> 'timestamp') ~ '^[0-9]{9,11}$'
       and (a ->> 'timestamp')::bigint >= extract(epoch from now())::bigint - greatest(coalesce(p_minutes, 10), 1) * 60
       and (a ->> 'timestamp')::bigint <= extract(epoch from now())::bigint + 120)
$$;
revoke execute on function public.recent_password_login(integer) from public, anon;
grant execute on function public.recent_password_login(integer) to authenticated;   -- uygulama "yeniden giriş gerekli mi" diye sorabilir; yalnız kendi oturumunu söyler

-- Hesabı sil (önceki tanım: migrations/20261023000000_admin.sql; yalnız yeni giriş denetimi eklendi)
create or replace function public.delete_account()
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  anon boolean;
begin
  if uid is null then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  select coalesce(u.is_anonymous, false) into anon from auth.users u where u.id = uid;
  if public.flag_on(uid, 'delete_recent_login') and not coalesce(anon, false) and not public.recent_password_login(10) then
    raise exception 'Hesabı silmek için şifreni yeniden girmelisin' using errcode = '42501', hint = 'recent_login_required';
  end if;
  perform public.account_delete_of(uid);
end $$;
revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
