-- Pazarlama paylaşımı (sozlesme/paylasim.md, hukuk/45-pazarlama-kurallari.md §8): sosyal medya gönderileri paylaşım servisinde
-- (Zernio) durur; bu veritabanında içerik ya da hesap bilgisi TUTULMAZ. `social` Edge Function'ı panel isteğinde yöneticinin
-- kendi oturumuyla bunu çağırır: okuma her admin, onay / düzeltme isteme / silme yalnız owner (iki adımlı). Değişiklik, servis
-- işlemi başarılı olduktan sonra p_dry = false ile denetim kaydına yazılır (önce p_dry = true ile rol ve gerekçe denetlenir).
create or replace function public.admin_social_check(p_action text, p_ref text default null, p_reason text default null,
                                                     p_after jsonb default null, p_dry boolean default true)
returns text language plpgsql security definer set search_path = '' as $$
declare me uuid;
begin
  if p_action = 'view' then
    me := public.admin_require(null);
    return public.admin_role_of(me);
  end if;
  if p_action is null or p_action not in ('approve', 'request_changes', 'delete') then raise exception 'Geçersiz işlem'; end if;
  me := public.admin_require(array['owner']);
  if p_ref is null or p_ref !~ '^[A-Za-z0-9_-]{1,64}$' then raise exception 'Gönderi kimliği geçersiz'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Gerekçe yaz (en az 3 harf)'; end if;
  if not coalesce(p_dry, true) then
    perform public.admin_log(me, 'social.' || p_action, 'system', 'social:' || p_ref, p_reason, null, p_after);
  end if;
  return 'owner';
end $$;
revoke execute on function public.admin_social_check(text, text, text, jsonb, boolean) from public, anon;
grant execute on function public.admin_social_check(text, text, text, jsonb, boolean) to authenticated;
