-- =====================================================================
-- Çocuk kodu: iki pencerenin değişikliği birleştirilir (22 Ekim 2026, GameApp penceresi)
--   Sorun: migrations/20261022150000_security_game.sql (GameApp, codes_15min'den SONRA uygulandı) redeem_child_code'u
--   eski gövdeyle yeniden tanımladı → codes_15min'deki "süresi doldu / kullanıldı / bulunamadı" ayrımı ve IP sınırı
--   çocuk kodunda kayboldu (aile, klinik ve ekip kodları etkilenmedi).
--   Düzeltme: codes_15min gövdesi aynen (code_throttled: oturum 10 + IP 30, code_rejected: nedenli ret) +
--   security_game'in genel sınırı (son 10 dk tüm hesaplardan ≥ 200 hatalı çocuk kodu denemesi varsa, bu oturum ya da
--   IP daha önce yanılmışsa 429; ilk deneme hep serbest — saldırgan gerçek bağlanmaları kilitleyemez).
-- Tekrar çalıştırılabilir.
-- =====================================================================

create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
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
  delete from public.code_attempts where user_id = uid;

  return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)));
end $$;
revoke execute on function public.redeem_child_code(text) from public, anon;
grant execute on function public.redeem_child_code(text) to authenticated;
