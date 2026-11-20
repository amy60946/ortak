-- =====================================================================
-- App Review için kalıcı çocuk kodu (10 Kasım 2026, GameApp penceresi; kullanıcı onayı "1-3 ok",
-- CANLIYA_ALMA 2.1 "App Review deneme hesabı + kalıcı inceleme çocuk kodu + not")
--   Sorun: çocuk kodları 15 dakikalık ve tek kullanımlık; ebeveyn yeni kod üretince eskiler de biter.
--          Apple inceleyicisi oyuna giremez.
--   Çözüm: ayrı tablo review_child_codes (istemciye kapalı: RLS açık, politika yok).
--          redeem_child_code önce aile kodlarına (invite_codes) bakar; bulamazsa etkin inceleme koduna bakar:
--          çocuğu o cihaza bağlar, kod tükenmez (kullanım sayacı + son kullanım tutulur).
--          Aile kodu üretmek (create_invite_code) inceleme kodunu geçersiz kılmaz.
--   Kod biçimi: "O" + 5 karakter. Aile kodlarının alfabesinde (random_code) O, I, L, 0, 1 yoktur, bu yüzden
--          inceleme kodu hiçbir aile koduyla çakışamaz. İnceleyici O yerine 0 (sıfır) yazarsa da kabul edilir.
--   Yönetim yalnız SQL Editor'den (sunucu yetkisi): review_code_set(ebeveyn e-postası, çocuk adı) yeni kod verir
--          (o çocuğun eski inceleme kodu kapanır), review_code_off(kod) kapatır. İstemci çağıramaz.
--   Deneme sınırları (code_throttled, genel sınır) inceleme kodunda da aynen geçerlidir.
-- Tekrar çalıştırılabilir.
-- =====================================================================

create table if not exists public.review_child_codes (
  code          text primary key check (code ~ '^O[A-Z0-9]{5}$'),
  child_id      uuid not null references public.children (id) on delete cascade,
  active        boolean not null default true,
  note          text not null default '',
  created_at    timestamptz not null default now(),
  last_used_at  timestamptz,
  use_count     integer not null default 0
);
create index if not exists review_child_codes_child_idx on public.review_child_codes (child_id);
alter table public.review_child_codes enable row level security;
-- politika yok: anon/authenticated okuyamaz, yazamaz
revoke all on public.review_child_codes from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Çocuk kodu: 20261025000000_whitehat2.sql gövdesi aynen + inceleme kodu dalı
-- ---------------------------------------------------------------------
create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  v_ip text := public.request_ip();
  inv public.invite_codes%rowtype;
  rc public.review_child_codes%rowtype;
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
  if not found then
    -- App Review kalıcı kodu (O ile başlar; O yerine 0 yazılmışsa da tanınır)
    select * into rc from public.review_child_codes
      where code = translate(upper(trim(p_code)), '0', 'O') and active
      for update;
    if not found then return public.code_rejected('not_found'); end if;
    update public.children set user_id = null where user_id = uid;
    update public.children set user_id = uid where id = rc.child_id returning * into c;
    update public.review_child_codes set use_count = use_count + 1, last_used_at = now() where code = rc.code;
    return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar,
                             'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)));
  end if;
  if public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.code_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;

  update public.children set user_id = null where user_id = uid;
  update public.children set user_id = uid where id = inv.child_id returning * into c;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;

  return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)));
end $$;
revoke execute on function public.redeem_child_code(text) from public, anon;
grant execute on function public.redeem_child_code(text) to authenticated;

-- ---------------------------------------------------------------------
-- Yönetim (yalnız SQL Editor / sunucu yetkisi)
-- ---------------------------------------------------------------------
create or replace function public.review_code_set(p_parent_email text, p_child_name text,
                                                  p_note text default 'App Review')
returns text language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  cid uuid;
  n integer;
  new_code text;
begin
  select p.family_id into fid
    from auth.users u join public.profiles p on p.id = u.id
    where lower(u.email) = lower(trim(p_parent_email));
  if fid is null then
    raise exception 'Bu e-postayla ebeveyn hesabı bulunamadı: %', p_parent_email;
  end if;
  select count(*) into n from public.children
    where family_id = fid and lower(name) = lower(trim(p_child_name));
  if n = 0 then raise exception 'Bu ailede "%" adlı çocuk yok', p_child_name; end if;
  if n > 1 then raise exception 'Bu ailede "%" adlı birden çok çocuk var', p_child_name; end if;
  select id into cid from public.children
    where family_id = fid and lower(name) = lower(trim(p_child_name));
  update public.review_child_codes set active = false where child_id = cid and active;
  loop
    new_code := 'O' || substr(public.random_code(), 1, 5);
    exit when not exists (select 1 from public.review_child_codes r where r.code = new_code);
  end loop;
  insert into public.review_child_codes (code, child_id, note) values (new_code, cid, coalesce(p_note, ''));
  return new_code;
end $$;

create or replace function public.review_code_off(p_code text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  update public.review_child_codes set active = false
    where code = translate(upper(trim(p_code)), '0', 'O') and active;
  return found;
end $$;

revoke execute on function public.review_code_set(text, text, text) from public, anon, authenticated;
revoke execute on function public.review_code_off(text) from public, anon, authenticated;
