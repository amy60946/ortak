-- Güvenlik (22 Ekim 2026, oyun penceresi denetimi C1): çocuk hesabı completions tablosuna DOĞRUDAN yazamaz.
-- Sorun: "tamamlama: çocuk işaretler" politikası (init) çocuk cihazına doğrudan insert izni veriyordu.
--   Değiştirilmiş bir istemci, inceleme gerektirmeyen görevi istediği kadar GEÇMİŞ/GELECEK güne "approved"
--   yazıp her satır için coin + Güneş Taşı alabiliyor, parent_note / reviewed_by alanlarını da uydurabiliyordu.
-- Düzeltme: çocuk yazımı yalnız child_set_status RPC'si ile (dün/bugün/yarın sınırı, görev günü, ebeveyn kararı korunur).
--   Oyun zaten yalnız RPC kullanıyor; ParentApp'teki çocuk ekranı 16 Ekim'de kaldırıldı. Ebeveynin doğrudan yazımı
--   ("tamamlama: ebeveyn" politikası) değişmez.
-- H2: çocuk kodu tahmini. Kullanıcı başına sınır (15 dk'da 10) yeni anonim hesap açarak aşılabiliyordu.
--   Ek olarak GENEL sınır: son 10 dakikada tüm hesaplardan 200 hatalı çocuk kodu denemesi varsa yeni deneme 429 alır
--   (gerçek kullanımda neredeyse hiç hatalı deneme olmaz; saldırı birkaç dakikada söner, kodlar 24 saat geçerli).
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
     or (select count(*) from public.code_attempts where at > now() - interval '10 minutes') >= 200 then
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
