-- Güvenlik (22 Ekim 2026, oyun penceresi denetimi C1): çocuk hesabı completions tablosuna DOĞRUDAN yazamaz.
-- Sorun: "tamamlama: çocuk işaretler" politikası (init) çocuk cihazına doğrudan insert izni veriyordu.
--   Değiştirilmiş bir istemci, inceleme gerektirmeyen görevi istediği kadar GEÇMİŞ/GELECEK güne "approved"
--   yazıp her satır için coin + Güneş Taşı alabiliyor, parent_note / reviewed_by alanlarını da uydurabiliyordu.
-- Düzeltme: çocuk yazımı yalnız child_set_status RPC'si ile (dün/bugün/yarın sınırı, görev günü, ebeveyn kararı korunur).
--   Oyun zaten yalnız RPC kullanıyor; ParentApp'teki çocuk ekranı 16 Ekim'de kaldırıldı. Ebeveynin doğrudan yazımı
--   ("tamamlama: ebeveyn" politikası) değişmez.
-- H2: çocuk kodu tahmini. Kullanıcı başına sınır (15 dk'da 10) yeni anonim hesap açarak aşılabiliyordu.
--   Ek olarak GENEL sınır: son 10 dakikada tüm hesaplardan 200 hatalı çocuk kodu denemesi varsa, daha önce yanılmış hesabın
--   yeni denemesi 429 alır (ilk deneme serbest: saldırgan gerçek bağlanmaları kilitleyemez; saldırgana hesap başına 1 deneme kalır).
-- Not (M5, değişiklik yok): incelemesiz görevde çocuğun "Yaptım"ı ebeveynin önceden verdiği onaydır ve Güneş Taşı verir
--   (19 Ekim kararı, test_sun_stones). C1 kapanınca bu yol yalnız dün/bugün/yarın ve görevin gerçek günleri için çalışır.
-- Tekrar çalıştırılabilir.

drop policy if exists "tamamlama: çocuk işaretler" on public.completions;
drop policy if exists "tamamlama: çocuk geri alır" on public.completions;

-- Artık hiçbir politika kullanmıyor; iç yardımcı olarak kalır (kimse çağıramaz).
revoke execute on function public.child_may_complete(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- H2. Genel kod deneme sınırı
-- ---------------------------------------------------------------------
create index if not exists code_attempts_at_idx on public.code_attempts (at);

create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  c public.children%rowtype;
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

  delete from public.code_attempts where at < now() - interval '1 day';
  if (select count(*) from public.code_attempts where user_id = uid and at > now() - interval '15 minutes') >= 10
     or ((select count(*) from public.code_attempts where at > now() - interval '10 minutes') >= 200
         and exists (select 1 from public.code_attempts where user_id = uid and at > now() - interval '15 minutes')) then
    -- genel sınır yalnız daha önce yanılmış hesaba: saldırgan herkesi kilitleyemez, doğru kodla ilk deneme hep çalışır
    perform set_config('response.status', '429', true);
    return json_build_object('error', 'too_many_attempts');
  end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'child'
    for update;

  if not found or inv.used_at is not null or inv.expires_at < now() then
    insert into public.code_attempts (user_id) values (uid);
    perform set_config('response.status', '400', true);
    return json_build_object('error', 'invalid_code');
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


-- ---------------------------------------------------------------------
-- L4. Kod rastgeleliği: mod sapması yok (31 harf; 248 üstü bayt atılır), UUID'nin sabit sürüm/varyant baytları kullanılmaz
-- ---------------------------------------------------------------------
create or replace function public.random_code(p_len integer)
returns text language plpgsql volatile set search_path = '' as $$
declare
  chars constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  n integer := least(greatest(p_len, 4), 16);
  result text := '';
  bytes bytea;
  b integer;
begin
  while char_length(result) < n loop
    bytes := uuid_send(gen_random_uuid());
    for i in 0..15 loop
      continue when i in (6, 8);                 -- sürüm ve varyant bitleri sabit
      b := get_byte(bytes, i);
      continue when b >= 248;                    -- 248 = 31 × 8: eşit olasılık
      result := result || substr(chars, (b % 31) + 1, 1);
      exit when char_length(result) = n;
    end loop;
  end loop;
  return result;
end $$;
revoke execute on function public.random_code(integer) from public, anon, authenticated;

create or replace function public.random_code()
returns text language sql volatile set search_path = '' as $$ select public.random_code(6) $$;
revoke execute on function public.random_code() from public, anon, authenticated;
