-- 26 Ekim 2026 denetimi düzeltmeleri (kullanıcı isteği: "bugün kurduğumuz sistemleri baştan sona kontrol et, sorun varsa düzelt").
-- 20261026050000_clinician_verification.sql ve 20261026100000_family_invite_links.sql'den sonra çalışır. Tekrar çalıştırılabilir.
--
-- A. Aile daveti
--   A1. Kod deneme sayacı yeniden sıfırlanabiliyordu (whitehat2 W2-1'in geri gelişi): claim ve redeem başarıda code_attempts
--       siliyordu; ailenin zaten bağladığı davet her seferinde "başarı" döndüğü için 9 hatalı denemede bir sıfırlanabiliyordu.
--       Artık başarı sayacı silmez; bağlanmış/kullanılmış davet için ayrı neden döner.
--   A2. E-postayla kendiliğinden eşleşme doğrulanmamış e-postayla da oluyordu (biri ebeveynin e-postasıyla kayıt olup daveti,
--       çocuk önerisini ve taslak planı alabiliyordu). Artık yalnız e-posta GERÇEKTEN doğrulanınca (doğrulama kayıttan en az
--       1 dakika sonra; "Confirm email" kapalıyken kendiliğinden onay eşleşme yapmaz). Kod/bağlantıyla kayıt değişmedi.
--   A3. Ret yalnız daveti kendine bağlamış aile içindir (kodu bilen herkes başkasının davetini kapatamaz); satır kilitlenir.
--   A4. Yarış: iki aile aynı anda bağlarsa kaybeden çocuk önerisini görmez (satır kilidi + yeniden okuma).
--   A5. Nedenler: 'accepted' (bu daveti zaten kabul ettin), 'declined' (bu daveti kapattın), 'revoked' (uzman iptal etti).
--   A6. Paylaşılacak çocuklar bu uzmanla zaten paylaşılıyorsa davet harcanmaz, taslak plan kaybolmaz (hata döner).
--   A7. Davetle oluşan çocuğun yaş grubu: doğum günü verildiyse otomatik (null), yoksa önerilen grup (K/A/B/C; eskiden K→A, C→B).
--   A8. Taslak plan yalnız önerilen çocuğa taşınır (ebeveyn kardeşleri de seçerse planı kopyalanmaz); öneri yoksa seçilenlerin hepsine.
--   A9. Bağlanıp 30 günde çocuk paylaşılmayan davet listede "Süresi doldu"; reddedilen davet istatistikte "kayıt" sayılmaz.
-- B. Uzmanın özel notu (etiket) aileye açıktı: clinic_links.label'ı aile tablodan okuyabiliyordu. Not artık yalnız kliniğin
--    okuyabildiği clinic_link_labels tablosunda; uygulamalar eskisi gibi clinic_links.label yazar, sunucu taşır.
-- C. Takip planı
--   C1. Aile planı uzman "Planı aileye gönder" deyince görür (önceden her kayıtta anında görüyordu). Gönderilen sürüm
--       satırlarda `pub` olarak saklanır; aile yalnız bunu okur (tablolara doğrudan okuma yok). Davet taslağı aile çocuğu
--       paylaşınca kendiliğinden gönderilir. Boş plan gönderilmez; 10 dakikada bir bildirim.
--   C2. Paylaşım bitince uzman ailenin uygulama kayıtlarını artık göremez (erişim hemen biter).
--   C3. Kayıt günü Türkiye saatine göre; ileri tarihli kayıt yok.
--   C4. Ekipten silinen uzmanın yazar kimliği boşaltılır (yabancı anahtar "set null" artık geri alınmaz).
-- D. Önceki uzmanın kayıtları
--   D1. Yalnız BİTMİŞ paylaşımlar "önceki uzman" sayılır (çocuğun hâlâ gördüğü uzmanın notları aktarılmaz); dönem bitiş tarihine kadar.
--   D2. Ad gizleme: en uzun ad önce, klinik adının parçaları da, e-posta ve telefon "[iletişim]"; çocuğun kendi adı gizlenmez.
--   D3. Aynı klinik iki kez geçerse aynı "Önceki uzman n".
-- E. Uzman belge incelemesi (bayrak kapalıyken de doğru olsun diye)
--   E1. Bayrak gönderimde de denetlenir; kova yalnız açık başvurunun tek dosya yoluna yükleme kabul eder.
--   E2. Başka uzmanın bekleyen başvurusunda aynı barkod kesin ret değil uyarı; onaylı/askıdaki barkod yine ret.
--       Yönetici onayında barkod denetimi başvurudaki barkodu da kapsar.
--   E3. Elle incelenen meslekler (hekim, diğer) ve BCBA kendiliğinden reddedilmez. Her başvuru bir kez ön kontrol edilir.
--   E4. Belge saklama: karar verilen, kendiliğinden reddedilen, geri çekilen ve hesabı silinen başvuruların dosyaları
--       storage_trash kuyruğuna girer; Edge Function her çağrıda kovadan siler. Karar sonrası ön kontrol ayrıntısı silinir.
--   E5. Başvurudan sonra ad değişirse onay verilemez. Yalnız büyük/küçük harf değişikliği rozeti düşürmez.
--   E6. Rozet bayrağı uzmana göre değerlendirilir (kişiye istisna tutarlı); "Diğer" meslekte rozet "Uzman".
--   E7. Liste yalnız support/owner; onay/ret kararı boş olamaz.

-- =====================================================================
-- A. Aile daveti
-- =====================================================================
create or replace function public.clinic_invite_rejected(p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
begin
  insert into public.code_attempts (user_id, ip) values (auth.uid(), public.request_ip());
  perform set_config('response.status', '400', true);
  return json_build_object('error', 'invalid_code', 'reason', coalesce(p_reason, 'not_found'), 'hint', coalesce(p_reason, 'not_found'),
    'message', case p_reason
      when 'expired' then 'Davetin süresi doldu (davetler 48 saat geçerli). Uzmanından yeni davet iste.'
      when 'used' then 'Bu davet başka bir ailede kullanıldı. Uzmanından yeni davet iste.'
      when 'accepted' then 'Bu daveti zaten kabul ettin; paylaşım Uzmanım bölümünde.'
      when 'declined' then 'Bu daveti kapattın. Yanlışlıkla olduysa uzmanından yeni davet iste.'
      when 'revoked' then 'Bu davet iptal edildi. Uzmanından yeni davet iste.'
      else 'Davet bulunamadı. Kodu kontrol et ya da uzmanından yeni davet iste.' end);
end $$;
revoke execute on function public.clinic_invite_rejected(text) from public, anon, authenticated;

-- Ailenin bu davetle ilgili durumu (null: kullanılabilir). İç işlev; satır kilitli okunmuş olmalı.
create or replace function public.clinic_invite_problem(inv public.clinic_invites, p_family uuid)
returns text language sql stable set search_path = '' as $$
  select case
    when inv.declined_at is not null then case when inv.claimed_family = p_family then 'declined' else 'revoked' end
    when inv.revoked_at is not null then 'revoked'
    when inv.claimed_at is not null and inv.claimed_family is distinct from p_family then 'used'
    when inv.used_at is not null then case when inv.claimed_family = p_family then 'accepted' else 'used' end
    when inv.claimed_at is not null and inv.claimed_at <= now() - interval '30 days' then 'expired'
    when inv.claimed_at is null and inv.expires_at <= now() then 'expired'
  end
$$;
revoke execute on function public.clinic_invite_problem(public.clinic_invites, uuid) from public, anon, authenticated;

create or replace function public.clinic_invite_status(i public.clinic_invites)
returns text language sql stable set search_path = '' as $$
  select case
    when i.declined_at is not null then 'declined'
    when i.revoked_at is not null then 'revoked'
    when i.used_at is not null then 'shared'
    when i.claimed_at is not null and i.claimed_at <= now() - interval '30 days' then 'expired'
    when i.claimed_at is not null then 'claimed'
    when i.expires_at <= now() then 'expired'
    when i.opened_at is not null then 'opened'
    else 'sent' end
$$;
revoke execute on function public.clinic_invite_status(public.clinic_invites) from public, anon;

-- Ebeveyn: bağlantıyla geldi ya da kodu yazdı → davet ailesine bağlanır. Başarı deneme sayacını silmez (W2-1).
create or replace function public.claim_clinic_invite(p_key text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  t json;
  why text;
  is_token boolean := lower(trim(coalesce(p_key, ''))) ~ '^[0-9a-f]{32}$';
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if not is_token then
    t := public.code_throttled();
    if t is not null then return t; end if;
  end if;
  inv := public.clinic_family_invite_find(p_key);
  if inv.code is null then return public.clinic_invite_rejected('not_found'); end if;
  select * into inv from public.clinic_invites where code = inv.code for update;
  why := public.clinic_invite_problem(inv, fid);
  if why is not null then return public.clinic_invite_rejected(why); end if;
  if inv.claimed_at is null then
    perform public.clinic_invite_claim_for(inv.code, fid, auth.uid());
    select * into inv from public.clinic_invites where code = inv.code;
    if inv.claimed_family is distinct from fid then return public.clinic_invite_rejected('used'); end if;
  end if;
  -- `label` uzmanın kendi notudur, aileye dönmez; çocuk önerisi yalnız daveti bu aileye bağlanmışsa
  return (select json_build_object('code', inv.code, 'clinic_id', inv.clinic_id, 'clinic', c.name, 'clinician', m.name, 'title', m.title,
                                   'verified_as', public.clinician_badge(m.id),
                                   'child_name', inv.child_name, 'child_age_group', inv.child_age_group,
                                   'has_plan', exists (select 1 from public.clinic_goals where invite_code = inv.code)
                                            or exists (select 1 from public.care_modules where invite_code = inv.code))
            from public.clinics c, public.clinicians m where c.id = inv.clinic_id and m.id = inv.clinician_id);
end $$;
revoke execute on function public.claim_clinic_invite(text) from public, anon;
grant execute on function public.claim_clinic_invite(text) to authenticated;

create or replace function public.clinic_invite_preview(p_code text)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  t json;
  why text;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  inv := public.clinic_family_invite_find(p_code);
  if inv.code is null then return public.clinic_invite_rejected('not_found'); end if;
  why := public.clinic_invite_problem(inv, fid);
  if why is not null then return public.clinic_invite_rejected(why); end if;
  return (select json_build_object('clinic', c.name, 'clinician', m.name, 'title', m.title, 'expires_at', inv.expires_at, 'code', inv.code,
                                   'verified_as', public.clinician_badge(m.id),
                                   'child_name', case when inv.claimed_family = fid then inv.child_name end,
                                   'child_age_group', case when inv.claimed_family = fid then inv.child_age_group end,
                                   'has_plan', exists (select 1 from public.clinic_goals where invite_code = inv.code)
                                            or exists (select 1 from public.care_modules where invite_code = inv.code))
            from public.clinics c, public.clinicians m where c.id = inv.clinic_id and m.id = inv.clinician_id);
end $$;
revoke execute on function public.clinic_invite_preview(text) from public, anon;
grant execute on function public.clinic_invite_preview(text) to authenticated;

-- Çocuk paylaşımı (kod ya da bağlantı anahtarı). p_plan_child: taslak plan yalnız bu çocuğun paylaşımına (null: hepsine).
-- p_share_consent: paylaşım onayı metni sürümü (uzman doğrulanmaz uyarısı + veli beyanı); p_consent_version: geçmiş aktarımı.
drop function if exists public.redeem_clinic_invite_children(text, uuid[], boolean, text);
create or replace function public.redeem_clinic_invite_children(p_code text, p_child_ids uuid[], p_share_history boolean default false,
                                                               p_consent_version text default null, p_plan_child uuid default null,
                                                               p_share_consent text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  ids uuid[] := '{}';
  plan_links uuid[];
  lid uuid;
  t json;
  why text;
  visible integer := 0;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if coalesce(array_length(p_child_ids, 1), 0) = 0 then raise exception 'En az bir çocuk seç'; end if;
  if exists (select 1 from unnest(p_child_ids) x where not exists (
    select 1 from public.children c where c.id = x and c.family_id = fid)) then
    raise exception 'Çocuk bulunamadı';
  end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  inv := public.clinic_family_invite_find(p_code);
  if inv.code is null then return public.clinic_invite_rejected('not_found'); end if;
  select * into inv from public.clinic_invites where code = inv.code for update;
  why := public.clinic_invite_problem(inv, fid);
  if why is not null then return public.clinic_invite_rejected(why); end if;
  with ins as (
    insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id, label, consent_by, consent_version)
    select inv.clinic_id, inv.clinician_id, fid, x, inv.label, auth.uid(), left(nullif(btrim(p_share_consent), ''), 40)
      from (select distinct unnest(p_child_ids) as x) u
     where not exists (select 1 from public.clinic_links l where l.clinic_id = inv.clinic_id and l.child_id = u.x and l.status = 'active')
    returning id, child_id)
  select coalesce(array_agg(id), '{}'), coalesce(array_agg(id) filter (where p_plan_child is null or child_id = p_plan_child), '{}')
    into ids, plan_links from ins;
  -- hepsi zaten bu uzmanla paylaşılıyorsa davet harcanmaz (taslak plan kaybolmasın)
  if coalesce(array_length(ids, 1), 0) = 0 then
    raise exception 'Seçtiğin çocuklar bu uzmanla zaten paylaşılıyor';
  end if;
  if coalesce(array_length(plan_links, 1), 0) = 0 then plan_links := ids; end if;
  foreach lid in array plan_links loop
    insert into public.clinic_goals (link_id, clinic_id, title, description, created_by, domain, measure, baseline, target, weeks,
                                     home_support, shared, status, position, template_key)
    select lid, clinic_id, title, description, created_by, domain, measure, baseline, target, weeks, home_support, shared, status, position, template_key
      from public.clinic_goals where invite_code = inv.code;
    insert into public.care_modules (link_id, clinic_id, title, aim, practice, checklist, position, status, template_key, created_by)
    select lid, clinic_id, title, aim, practice, checklist, position, status, template_key, created_by
      from public.care_modules where invite_code = inv.code;
    visible := visible + public.care_plan_snapshot(lid);   -- davet taslağı paylaşımla birlikte aileye gönderilir
  end loop;
  if p_share_history then
    foreach lid in array ids loop perform public.clinic_link_history_set(lid, true, p_consent_version); end loop;
  end if;
  delete from public.clinic_goals where invite_code = inv.code;
  delete from public.care_modules where invite_code = inv.code;
  update public.clinic_invites
     set used_at = now(), used_by = auth.uid(), claimed_at = coalesce(claimed_at, now()), claimed_family = coalesce(claimed_family, fid),
         child_name = null, child_age_group = null
   where code = inv.code;
  if visible > 0 then
    perform public.notify_parents(fid, 'care_plan_shared', 'Takip planın hazır',
      'Uzmanının hazırladığı hedefler ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_ids', to_jsonb(plan_links)), null);
  end if;
  return json_build_object('link_ids', ids, 'clinic_id', inv.clinic_id);
end $$;
revoke execute on function public.redeem_clinic_invite_children(text, uuid[], boolean, text, uuid, text) from public, anon;
grant execute on function public.redeem_clinic_invite_children(text, uuid[], boolean, text, uuid, text) to authenticated;

create or replace function public.redeem_clinic_invite(p_code text, p_child_id uuid)
returns json language plpgsql security definer set search_path = '' as $$
declare r json;
begin
  r := public.redeem_clinic_invite_children(p_code, array[p_child_id], false);
  if r ->> 'error' is not null then return r; end if;
  return json_build_object('link_id', (r -> 'link_ids') ->> 0);
end $$;
revoke execute on function public.redeem_clinic_invite(text, uuid) from public, anon;
grant execute on function public.redeem_clinic_invite(text, uuid) to authenticated;

create or replace function public.family_accept_invite(p_key text, p_child jsonb default null, p_child_ids uuid[] default null,
                                                      p_share_history boolean default false, p_consent_version text default null,
                                                      p_history_version text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  ids uuid[] := coalesce(p_child_ids, '{}');
  nm text;
  grp text;
  bday date;
  dup record;
  cid uuid;
  r json;
  t json;
  why text;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  inv := public.clinic_family_invite_find(p_key);
  if inv.code is null then return public.clinic_invite_rejected('not_found'); end if;
  select * into inv from public.clinic_invites where code = inv.code for update;
  why := public.clinic_invite_problem(inv, fid);
  if why is not null then return public.clinic_invite_rejected(why); end if;
  if exists (select 1 from unnest(ids) x where not exists (select 1 from public.children c where c.id = x and c.family_id = fid)) then
    raise exception 'Çocuk bulunamadı';
  end if;
  if p_child is not null then
    nm := btrim(coalesce(p_child ->> 'name', ''));
    if nm = '' or char_length(nm) > 40 then raise exception 'Çocuğun adını yaz (en çok 40 harf)'; end if;
    grp := nullif(upper(btrim(coalesce(p_child ->> 'age_group', ''))), '');
    if grp is not null and grp not in ('K', 'A', 'B', 'C') then raise exception 'Geçersiz yaş grubu'; end if;
    bday := nullif(p_child ->> 'birthday', '')::date;
    if not coalesce((p_child ->> 'allow_duplicate')::boolean, false) then
      select c.id, c.name into dup from public.children c
       where c.family_id = fid and lower(btrim(c.name)) = lower(nm) and not (c.id = any(ids)) limit 1;
      if found then
        return json_build_object('error', 'duplicate_child', 'child_id', dup.id, 'name', dup.name,
          'message', 'Kayıtlarında bu isimde bir çocuk var. Aynı çocuksa onu seç; değilse yine de ekleyebilirsin.');
      end if;
    end if;
    -- yaş grubu: doğum günü varsa otomatik (null), yoksa önerilen grup (durumlar.md §4)
    insert into public.children (family_id, name, avatar, gender, birthday, age_band)
    values (fid, nm, left(coalesce(nullif(p_child ->> 'avatar', ''), 'kedi'), 200), nullif(p_child ->> 'gender', ''), bday,
            case when bday is null then grp end)
    returning id into cid;
    ids := ids || cid;
  end if;
  if coalesce(array_length(ids, 1), 0) = 0 then raise exception 'En az bir çocuk seç'; end if;
  -- taslak plan uzmanın önerdiği çocuğa (öneri yoksa seçilen bütün çocuklara)
  r := public.redeem_clinic_invite_children(inv.code, ids, p_share_history, p_history_version,
         case when cid is not null and (inv.child_name is not null or inv.child_age_group is not null) then cid end, p_consent_version);
  if r ->> 'error' is not null then raise exception '%', coalesce(r ->> 'message', 'Davet kullanılamadı'); end if;
  if cid is not null and (inv.child_name is not null or inv.child_age_group is not null)
     and (nm is distinct from inv.child_name or grp is distinct from inv.child_age_group) then
    perform public.notify(inv.clinician_id, 'clinic', 'invite_child_updated', 'Ebeveyn çocuk bilgisini düzeltti',
      left(coalesce(inv.child_name, '—') || coalesce(' (' || inv.child_age_group || ')', '') || ' → ' || nm || coalesce(' (' || grp || ')', ''), 300),
      jsonb_build_object('code', inv.code), fid, cid);
  end if;
  return json_build_object('link_ids', r -> 'link_ids', 'child_ids', to_json(ids), 'clinic_id', inv.clinic_id);
end $$;
revoke execute on function public.family_accept_invite(text, jsonb, uuid[], boolean, text, text) from public, anon;
grant execute on function public.family_accept_invite(text, jsonb, uuid[], boolean, text, text) to authenticated;

-- Ret: yalnız daveti kendine bağlamış aile (bağlama kod denemesi sınırlı); satır kilitli
create or replace function public.family_decline_invite(p_key text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  inv := public.clinic_family_invite_find(p_key);
  if inv.code is not null then
    select * into inv from public.clinic_invites where code = inv.code for update;
  end if;
  if inv.code is null or inv.claimed_family is distinct from fid or public.clinic_invite_problem(inv, fid) is not null then
    raise exception 'Davet bulunamadı';
  end if;
  update public.clinic_invites
     set declined_at = now(), revoked_at = now(), child_name = null, child_age_group = null
   where code = inv.code and used_at is null;
  delete from public.clinic_goals where invite_code = inv.code;
  delete from public.care_modules where invite_code = inv.code;
  perform public.notify(inv.clinician_id, 'clinic', 'invite_declined', 'Aile davetini kabul etmedi',
    left(case when inv.label <> '' then inv.label || ' · ' when inv.parent_name <> '' then inv.parent_name || ' · ' else '' end
         || 'Bilgileri kontrol edip gerekirse yeni davet gönder.', 300),
    jsonb_build_object('code', inv.code));
end $$;
revoke execute on function public.family_decline_invite(text) from public, anon;
grant execute on function public.family_decline_invite(text) to authenticated;

-- Kayıt: bağlantıdaki davet (meta `clinic_invite`) aileye bağlanır. E-postayla eşleşme burada değil, doğrulamada (aşağıda).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  cid uuid;
  inv public.clinic_invites%rowtype;
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  if meta ->> 'account' = 'clinician' then
    if nullif(trim(meta ->> 'team_code'), '') is not null then
      select * into inv from public.clinic_invites
        where code = upper(trim(meta ->> 'team_code')) and kind = 'clinician'
          and used_at is null and expires_at > now()
        for update;
      if not found then
        raise exception 'Ekip kodu geçersiz ya da süresi dolmuş';
      end if;
      perform 1 from public.clinics where id = inv.clinic_id for update;
      if (select count(*) from public.clinicians where clinic_id = inv.clinic_id)
         >= (select seat_limit from public.clinics where id = inv.clinic_id) then
        raise exception 'Kliniğin uzman koltuğu dolu';
      end if;
      cid := inv.clinic_id;
      update public.clinic_invites set used_at = now(), used_by = new.id where code = inv.code;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, left(coalesce(trim(meta ->> 'name'), ''), 80), left(coalesce(trim(meta ->> 'title'), ''), 80), 'member');
    else
      insert into public.clinics (name, created_by)
      values (left(coalesce(nullif(trim(meta ->> 'clinic_name'), ''), 'Kliniğim'), 120), new.id)
      returning id into cid;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, left(coalesce(trim(meta ->> 'name'), ''), 80), left(coalesce(trim(meta ->> 'title'), ''), 80), 'owner');
    end if;
    return new;
  end if;

  insert into public.families (created_by) values (new.id) returning id into fid;
  insert into public.profiles (id, family_id, nickname, name, avatar)
  values (
    new.id,
    fid,
    coalesce(nullif(trim(meta ->> 'nickname'), ''), 'Ben'),
    coalesce(trim(meta ->> 'name'), ''),
    coalesce(nullif(meta ->> 'avatar', ''), 'erkek')
  );

  -- Uzman daveti (bağlantı anahtarı ya da kod); hata kaydı engellemez
  begin
    inv := public.clinic_family_invite_find(meta ->> 'clinic_invite');
    if inv.code is not null and inv.claimed_at is null and inv.used_at is null and inv.revoked_at is null and inv.expires_at > now() then
      perform public.clinic_invite_claim_for(inv.code, fid, new.id);
    end if;
  exception when others then null;
  end;
  return new;
end $$;

-- E-posta doğrulanınca: davetteki e-postayla eşleşen açık davet aileye bağlanır. "Confirm email" kapalıyken Supabase hesabı
-- kayıtla aynı anda onaylar (kimse e-postayı doğrulamamıştır): doğrulama kayıttan en az 1 dakika sonra değilse eşleşme yok.
create or replace function public.handle_user_email_confirmed()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  inv public.clinic_invites%rowtype;
begin
  if old.email_confirmed_at is not null or new.email_confirmed_at is null or new.email is null
     or new.email_confirmed_at < new.created_at + interval '1 minute' then
    return new;
  end if;
  select family_id into fid from public.profiles where id = new.id;
  if fid is null then return new; end if;
  begin
    select * into inv from public.clinic_invites
     where kind = 'family' and lower(parent_email) = lower(new.email)
       and claimed_at is null and used_at is null and revoked_at is null and expires_at > now()
     order by created_at desc limit 1;
    if inv.code is not null then perform public.clinic_invite_claim_for(inv.code, fid, new.id); end if;
  exception when others then null;
  end;
  return new;
end $$;
revoke execute on function public.handle_user_email_confirmed() from public, anon, authenticated;
drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed after update of email_confirmed_at on auth.users
  for each row execute function public.handle_user_email_confirmed();

drop function if exists public.clinic_invite_stats(integer);
create function public.clinic_invite_stats(p_days integer default 30)
returns table (clinician_id uuid, clinician text, sent bigint, opened bigint, claimed bigint, shared bigint, expired bigint, open_now bigint)
language sql stable security definer set search_path = '' as $$
  select m.id, coalesce(m.name, ''),
         count(i.code),
         count(i.code) filter (where i.opened_at is not null),
         count(i.code) filter (where i.claimed_at is not null and i.declined_at is null),
         count(i.code) filter (where i.used_at is not null),
         count(i.code) filter (where public.clinic_invite_status(i) = 'expired'),
         count(i.code) filter (where public.clinic_invite_status(i) in ('sent', 'opened', 'claimed'))
    from public.clinicians m
    left join public.clinic_invites i on i.clinician_id = m.id and i.kind = 'family'
         and i.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 730)))
   where m.clinic_id = public.my_clinic_id() and (m.id = auth.uid() or public.clinic_is_owner())
   group by m.id, m.name
   order by count(i.code) desc
$$;
revoke execute on function public.clinic_invite_stats(integer) from public, anon;
grant execute on function public.clinic_invite_stats(integer) to authenticated;

-- Biten davetlerde kalan veri: çocuk önerisi ve kullanılmadan biten davetin taslak planı silinir (zamanlayıcı + açılış)
create or replace function public.clinic_invites_expire(p_clinic uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  r record;
  n integer := 0;
begin
  update public.clinic_invites set child_name = null, child_age_group = null
   where (child_name is not null or child_age_group is not null) and (p_clinic is null or clinic_id = p_clinic)
     and (used_at is not null or revoked_at is not null or (claimed_at is null and expires_at <= now())
          or claimed_at <= now() - interval '30 days');
  delete from public.clinic_goals g using public.clinic_invites i
   where g.invite_code = i.code and (p_clinic is null or i.clinic_id = p_clinic) and i.used_at is null
     and ((i.claimed_at is null and i.expires_at <= now() - interval '7 days') or i.claimed_at <= now() - interval '37 days');
  delete from public.care_modules x using public.clinic_invites i
   where x.invite_code = i.code and (p_clinic is null or i.clinic_id = p_clinic) and i.used_at is null
     and ((i.claimed_at is null and i.expires_at <= now() - interval '7 days') or i.claimed_at <= now() - interval '37 days');
  for r in select * from public.clinic_invites
            where kind = 'family' and expires_at <= now() and claimed_at is null and used_at is null
              and revoked_at is null and expired_notified_at is null
              and (p_clinic is null or clinic_id = p_clinic)
            for update skip locked loop
    update public.clinic_invites set expired_notified_at = now() where code = r.code;
    insert into public.notifications (user_id, app, kind, title, body, data)
    values (r.clinician_id, 'clinic', 'invite_expired', 'Davetin kullanılmadı, süresi doldu',
            left(case when r.label <> '' then r.label || ' · ' when r.parent_name <> '' then r.parent_name || ' · ' else '' end
                 || 'İstersen yeni bir davet gönder.', 300),
            jsonb_build_object('code', r.code));
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.clinic_invites_expire(uuid) from public, anon, authenticated;
grant execute on function public.clinic_invites_expire(uuid) to service_role;

-- =====================================================================
-- B. Uzmanın özel notu (etiket) yalnız klinikte
-- =====================================================================
create table if not exists public.clinic_link_labels (
  link_id     uuid primary key references public.clinic_links (id) on delete cascade deferrable initially deferred,
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  label       text not null default '' check (char_length(label) <= 60),
  updated_at  timestamptz not null default now()
);
alter table public.clinic_link_labels enable row level security;
revoke all on public.clinic_link_labels from anon, authenticated;
grant select on public.clinic_link_labels to authenticated;
drop policy if exists "etiket: klinik okur" on public.clinic_link_labels;
create policy "etiket: klinik okur" on public.clinic_link_labels for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinic_link_visible(link_id));

-- Var olan notlar taşınır (tetikleyiciden önce; tekrar çalıştırmada boş geçer)
drop trigger if exists clinic_links_label_private on public.clinic_links;
insert into public.clinic_link_labels (link_id, clinic_id, label)
select id, clinic_id, label from public.clinic_links where label <> ''
on conflict (link_id) do update set label = excluded.label, updated_at = now();
update public.clinic_links set label = '' where label <> '';

-- Uygulamalar clinic_links.label yazmaya devam eder (eski sürümler dahil); not ayrı tabloya geçer, sütun boş kalır
create or replace function public.clinic_links_label_private() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and coalesce(new.label, '') = '' then return new; end if;
  insert into public.clinic_link_labels (link_id, clinic_id, label)
  values (new.id, new.clinic_id, left(coalesce(new.label, ''), 60))
  on conflict (link_id) do update set label = excluded.label, updated_at = now();
  new.label := '';
  return new;
end $$;
revoke execute on function public.clinic_links_label_private() from public, anon, authenticated;
create trigger clinic_links_label_private before insert or update of label on public.clinic_links
  for each row execute function public.clinic_links_label_private();

create or replace function public.clinic_clients()
returns table (link_id uuid, clinic_id uuid, family_id uuid, child_id uuid, child_name text, avatar text,
               birthday date, label text, consent_at timestamptz, parents text,
               clinician_id uuid, clinician_name text, assigned uuid[])
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.family_id, l.child_id, c.name, c.avatar, c.birthday,
         coalesce((select x.label from public.clinic_link_labels x where x.link_id = l.id), ''), l.consent_at,
         coalesce((select string_agg(coalesce(nullif(trim(p.name), ''), p.nickname), ', ' order by p.created_at)
                   from public.profiles p where p.family_id = l.family_id), ''),
         l.clinician_id, coalesce(m.name, ''),
         coalesce((select array_agg(a.clinician_id order by a.created_at) from public.clinic_link_access a where a.link_id = l.id), '{}')
  from public.clinic_links l
  join public.children c on c.id = l.child_id
  left join public.clinicians m on m.id = l.clinician_id
  where l.clinic_id = public.my_clinic_id() and l.status = 'active' and public.clinician_access()
    and public.clinic_link_visible(l.id)
  order by l.consent_at desc
$$;
revoke execute on function public.clinic_clients() from public, anon;
grant execute on function public.clinic_clients() to authenticated;

-- =====================================================================
-- C. Takip planı: aile gönderilen sürümü görür
-- =====================================================================
alter table public.clinic_goals add column if not exists pub jsonb;     -- aileye gönderilen sürüm (null: ailede görünmez)
alter table public.care_modules add column if not exists pub jsonb;
alter table public.clinic_links add column if not exists plan_published_at timestamptz;

-- Yazar: istemci değiştiremez; uzman silinince yabancı anahtar boşaltır (tetikleyici içi güncelleme, derinlik > 1)
create or replace function public.care_rows_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if exists (select 1 from public.clinicians where id = auth.uid()) then new.created_by := auth.uid(); end if;
    if auth.uid() is not null and current_setting('ortak.care_snapshot', true) is distinct from 'on' then new.pub := null; end if;
  else
    if auth.uid() is not null and (new.link_id is distinct from old.link_id or new.invite_code is distinct from old.invite_code
                                   or new.clinic_id is distinct from old.clinic_id) then
      raise exception 'Plan başka bir danışana taşınamaz';
    end if;
    if not (pg_trigger_depth() > 1 and new.created_by is null) then new.created_by := old.created_by; end if;
    if auth.uid() is not null and new.pub is distinct from old.pub and pg_trigger_depth() = 1
       and current_setting('ortak.care_snapshot', true) is distinct from 'on' then
      new.pub := old.pub;   -- gönderilen sürümü yalnız sunucu yazar (care_plan_snapshot)
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.care_rows_guard() from public, anon, authenticated;

create or replace function public.clinic_set_author()
returns trigger language plpgsql security definer set search_path = '' as $$
declare is_clinician boolean := exists (select 1 from public.clinicians where id = auth.uid());
begin
  if tg_table_name = 'goal_ratings' then
    new.rated_by := case when tg_op = 'INSERT' then auth.uid()
                         when pg_trigger_depth() > 1 and new.rated_by is null then null else old.rated_by end;
  else
    new.created_by := case when tg_op = 'INSERT' then (case when is_clinician or auth.uid() is null then auth.uid() else new.created_by end)
                           when pg_trigger_depth() > 1 and new.created_by is null then null
                           else old.created_by end;
  end if;
  return new;
end $$;
revoke execute on function public.clinic_set_author() from public, anon, authenticated;

-- Paylaşımın aileye görünen sürümünü bugünkü hâliyle yazar; görünen öğe sayısını döndürür. İç işlev.
-- Tetikleyiciye kendini bildirir (istemci `pub` yazamaz).
create or replace function public.care_plan_snapshot(p_link_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  perform set_config('ortak.care_snapshot', 'on', true);
  update public.clinic_goals set pub = case when shared and not archived then jsonb_build_object(
           'title', title, 'description', description, 'domain', domain, 'measure', measure, 'baseline', baseline,
           'target', target, 'weeks', weeks, 'home_support', home_support, 'status', status, 'position', position) end
   where link_id = p_link_id;
  update public.care_modules set pub = case when status <> 'planned' then jsonb_build_object(
           'title', title, 'aim', aim, 'practice', practice, 'checklist', checklist, 'status', status, 'position', position) end
   where link_id = p_link_id;
  perform set_config('ortak.care_snapshot', 'off', true);
  select (select count(*) from public.clinic_goals where link_id = p_link_id and pub is not null)
       + (select count(*) from public.care_modules where link_id = p_link_id and pub is not null) into n;
  update public.clinic_links set plan_published_at = now() where id = p_link_id;
  return n;
end $$;
revoke execute on function public.care_plan_snapshot(uuid) from public, anon, authenticated;

-- Var olan paylaşımlar: bugüne kadar ailenin gördüğü hâli korunur (bir kez)
do $$
declare r record;
begin
  for r in select l.id from public.clinic_links l where l.plan_published_at is null and l.status = 'active'
             and (exists (select 1 from public.clinic_goals g where g.link_id = l.id and g.shared and not g.archived)
                  or exists (select 1 from public.care_modules m where m.link_id = l.id and m.status <> 'planned')) loop
    perform public.care_plan_snapshot(r.id);
  end loop;
end $$;

-- Uzman planı aileye gönderir: boş plan gönderilmez (önceden gönderilmiş planı boşaltmak serbest, bildirimsiz);
-- bildirim en çok 10 dakikada bir
create or replace function public.care_plan_publish(p_link_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  before integer;
  n integer;
begin
  if not public.clinic_link_mine(p_link_id) then raise exception 'Paylaşım bulunamadı'; end if;
  select * into l from public.clinic_links where id = p_link_id for update;
  select (select count(*) from public.clinic_goals where link_id = p_link_id and pub is not null)
       + (select count(*) from public.care_modules where link_id = p_link_id and pub is not null) into before;
  n := public.care_plan_snapshot(p_link_id);
  if n = 0 and before = 0 then
    raise exception 'Aileye gösterilecek bir şey yok: "Aile görür" açık bir hedef ya da etkin bir modül ekle';
  end if;
  if n > 0 and (l.plan_published_at is null or l.plan_published_at < now() - interval '10 minutes') then
    perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || public.child_name(l.child_id),
      'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
  end if;
end $$;
revoke execute on function public.care_plan_publish(uuid) from public, anon;
grant execute on function public.care_plan_publish(uuid) to authenticated;

-- Ebeveynin gördüğü plan: yalnız gönderilen sürüm + bu haftaki kaydı (Türkiye günü)
create or replace function public.family_care_plan(p_link_id uuid)
returns json language sql stable security definer set search_path = '' as $$
  select case when public.family_link_active(p_link_id) then json_build_object(
    'goals', coalesce((select json_agg(json_build_object('id', g.id, 'title', g.pub ->> 'title', 'description', g.pub ->> 'description',
                         'domain', g.pub ->> 'domain', 'measure', g.pub ->> 'measure', 'baseline', g.pub ->> 'baseline',
                         'target', g.pub ->> 'target', 'weeks', g.pub -> 'weeks', 'home_support', g.pub ->> 'home_support',
                         'status', g.pub ->> 'status') order by (g.pub ->> 'position')::int, g.created_at)
                         from public.clinic_goals g where g.link_id = p_link_id and g.pub is not null), '[]'),
    'modules', coalesce((select json_agg(json_build_object('id', m.id, 'title', m.pub ->> 'title', 'aim', m.pub ->> 'aim',
                         'practice', m.pub ->> 'practice', 'checklist', m.pub -> 'checklist', 'status', m.pub ->> 'status',
                         'practiced_week', (select count(*) from public.care_module_logs x where x.module_id = m.id
                                             and x.family_id = public.my_family_id() and x.practiced
                                             and x.day > (now() at time zone 'Europe/Istanbul')::date - 7
                                             and x.day <= (now() at time zone 'Europe/Istanbul')::date))
                         order by (m.pub ->> 'position')::int, m.created_at)
                         from public.care_modules m where m.link_id = p_link_id and m.pub is not null), '[]'))
  else null end
$$;
revoke execute on function public.family_care_plan(uuid) from public, anon;
grant execute on function public.family_care_plan(uuid) to authenticated;

-- Aile tablolara doğrudan bakmaz (gönderilmemiş düzenlemeler görünmesin); kayıt yalnız gönderilmiş etkin modüle
drop policy if exists "hedef: aile okur" on public.clinic_goals;
drop policy if exists "modül: aile okur" on public.care_modules;

create or replace function public.care_module_loggable(p_module_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.care_modules m where m.id = p_module_id and m.link_id is not null
                 and m.pub ->> 'status' = 'active' and public.family_link_active(m.link_id))
$$;
revoke execute on function public.care_module_loggable(uuid) from public, anon;
grant execute on function public.care_module_loggable(uuid) to authenticated;

drop policy if exists "uygulama: aile" on public.care_module_logs;
create policy "uygulama: aile" on public.care_module_logs for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id() and created_by = auth.uid() and public.care_module_loggable(module_id));
-- Paylaşım bitince uzman ailenin kayıtlarını görmez
drop policy if exists "uygulama: klinik okur" on public.care_module_logs;
create policy "uygulama: klinik okur" on public.care_module_logs for select to authenticated
  using (exists (select 1 from public.care_modules m where m.id = module_id and m.link_id is not null
                 and m.clinic_id = public.my_clinic_id() and public.clinic_link_mine(m.link_id)));

alter table public.care_module_logs alter column day set default ((now() at time zone 'Europe/Istanbul')::date);
create or replace function public.care_logs_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.family_id := public.my_family_id();
  new.created_by := auth.uid();
  -- Türkiye günü; cihaz saat farkı için bir gün pay; geriye en çok 14 gün
  if auth.uid() is not null and (new.day > (now() at time zone 'Europe/Istanbul')::date + 1
                                 or new.day < (now() at time zone 'Europe/Istanbul')::date - 14) then
    raise exception 'Kayıt günü geçersiz';
  end if;
  return new;
end $$;
revoke execute on function public.care_logs_guard() from public, anon, authenticated;

-- =====================================================================
-- D. Önceki uzmanın kayıtları: yalnız biten paylaşımlar, daha iyi ad gizleme
-- =====================================================================
create or replace function public.clinic_link_history_set(p_link_id uuid, p_on boolean, p_consent_version text default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  n integer;
begin
  select * into l from public.clinic_links where id = p_link_id;
  if not found or l.family_id is distinct from public.my_family_id() then raise exception 'Paylaşım bulunamadı'; end if;
  if p_on then
    if l.status <> 'active' then raise exception 'Paylaşım sona erdi'; end if;
    insert into public.clinic_link_history (link_id, from_link_id, granted_by, consent_version)
    select l.id, o.id, auth.uid(), left(nullif(btrim(p_consent_version), ''), 40) from public.clinic_links o
     where o.child_id = l.child_id and o.clinic_id <> l.clinic_id and o.status <> 'active' and o.consent_at <= l.consent_at
    on conflict do nothing;
  else
    delete from public.clinic_link_history where link_id = l.id;
  end if;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.clinic_link_history_set(uuid, boolean, text) from public, anon;
grant execute on function public.clinic_link_history_set(uuid, boolean, text) to authenticated;

-- Ad gizleme: en uzun ad önce, tam kelime, büyük/küçük harf duyarsız; e-posta ve telefon "[iletişim]". İç işlev.
create or replace function public.clinic_redact(p_text text, p_names text[])
returns text language plpgsql immutable set search_path = '' as $$
declare
  r text := coalesce(p_text, '');
  n text;
  w constant text := '[^[:alnum:]çğıöşüÇĞİÖŞÜâîûÂÎÛ]';
begin
  r := regexp_replace(r, '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}', '[iletişim]', 'g');
  r := regexp_replace(r, '(\+?90[\s.-]*)?\(?0?[2-5][0-9]{2}\)?[\s.-]*[0-9]{3}[\s.-]*[0-9]{2}[\s.-]*[0-9]{2}', '[iletişim]', 'g');
  for n in select x from unnest(coalesce(p_names, '{}'::text[])) x order by char_length(x) desc loop
    n := btrim(n);
    continue when char_length(n) < 3;
    r := regexp_replace(r, '(^|' || w || ')(' || regexp_replace(n, '([^[:alnum:][:space:]])', '\\\1', 'g') || ')(?=$|' || w || ')',
                        '\1[önceki uzman]', 'gi');
  end loop;
  return r;
end $$;
revoke execute on function public.clinic_redact(text, text[]) from public, anon, authenticated;

-- Gizlenecek adlar: klinik adı ve anlamlı parçaları, o kliniğin uzmanlarının adı ve parçaları; çocuğun kendi adı hariç. İç işlev.
create or replace function public.clinic_redact_names(p_clinic uuid, p_clinician uuid, p_child uuid)
returns text[] language sql stable security definer set search_path = '' as $$
  with raw as (
    select c.name as x from public.clinics c where c.id = p_clinic
    union all select t from public.clinics c, regexp_split_to_table(c.name, '[\s''’.,-]+') t where c.id = p_clinic and char_length(t) >= 4
    union all select m.name from public.clinicians m where m.clinic_id = p_clinic or m.id = p_clinician
    union all select t from public.clinicians m, regexp_split_to_table(m.name, '[\s.]+') t
     where (m.clinic_id = p_clinic or m.id = p_clinician) and char_length(t) >= 3
  ), kid as (
    select lower(translate(t, 'İIı', 'iii')) as k from public.children ch, regexp_split_to_table(ch.name, '\s+') t where ch.id = p_child
  )
  select coalesce(array_agg(distinct btrim(x)), '{}') from raw
   where char_length(btrim(x)) >= 3 and btrim(x) ~ '[[:alpha:]]'
     and lower(translate(btrim(x), 'İIı', 'iii')) not in (select k from kid)
     and lower(translate(btrim(x), 'İIı', 'iii')) not in ('dr', 'doç', 'doc', 'prof', 'uzm', 'psk', 'klinik', 'kliniği', 'klinigi',
       'merkez', 'merkezi', 'çocuk', 'cocuk', 'aile', 'özel', 'ozel', 'terapi', 'terapist', 'danışmanlık', 'danismanlik', 'danışma',
       'psikoloji', 'psikolojik', 'psikolog', 'gelişim', 'gelisim', 'eğitim', 'egitim', 'ergoterapi', 'konuşma', 'konusma', 'sağlık',
       'saglik', 'enstitü', 'enstitüsü', 'akademi', 'destek', 'grup', 'ofis', 'uzman', 'davranış', 'davranis', 've', 'and')
$$;
revoke execute on function public.clinic_redact_names(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.clinic_inherited_records(p_link_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  res jsonb := '[]'::jsonb;
  o public.clinic_links%rowtype;
  nm text[];
  seen uuid[] := '{}';
  k integer;
  upto timestamptz;
begin
  if not public.clinic_link_mine(p_link_id) then return res; end if;
  for o in select ol.* from public.clinic_link_history h join public.clinic_links ol on ol.id = h.from_link_id
            where h.link_id = p_link_id and ol.status <> 'active' order by ol.consent_at loop
    -- aynı klinik aynı numara
    if not (o.clinic_id = any(seen)) then seen := seen || o.clinic_id; end if;
    k := array_position(seen, o.clinic_id);
    upto := coalesce(o.revoked_at, now());
    nm := public.clinic_redact_names(o.clinic_id, o.clinician_id, o.child_id);
    res := res || jsonb_build_array(jsonb_build_object(
      'n', k,
      'label', 'Önceki uzman ' || k,
      'from', to_char(o.consent_at, 'YYYY-MM'),
      'to', case when o.revoked_at is null then null else to_char(o.revoked_at, 'YYYY-MM') end,
      'notes', coalesce((select jsonb_agg(jsonb_build_object('body', public.clinic_redact(x.body, nm), 'created_at', x.created_at)
                                          order by x.created_at desc)
                           from public.clinic_notes x where x.link_id = o.id and x.created_at <= upto), '[]'::jsonb),
      'suggestions', coalesce((select jsonb_agg(jsonb_build_object(
                                 'title', public.clinic_redact(x.title, nm), 'emoji', x.emoji, 'skill', x.skill, 'category', x.category,
                                 'description', public.clinic_redact(x.description, nm), 'note', public.clinic_redact(x.note, nm),
                                 'recurring', x.recurring, 'status', x.status, 'created_at', x.created_at, 'decided_at', x.decided_at)
                                 order by x.created_at desc)
                           from public.clinic_task_suggestions x where x.link_id = o.id and x.created_at <= upto), '[]'::jsonb),
      'goals', coalesce((select jsonb_agg(jsonb_build_object(
                           'title', public.clinic_redact(g.title, nm), 'description', public.clinic_redact(g.description, nm),
                           'domain', g.domain, 'measure', g.measure, 'baseline', public.clinic_redact(g.baseline, nm),
                           'target', public.clinic_redact(g.target, nm), 'weeks', g.weeks,
                           'home_support', public.clinic_redact(g.home_support, nm), 'status', g.status, 'archived', g.archived,
                           'created_at', g.created_at,
                           'ratings', coalesce((select jsonb_agg(jsonb_build_object('week', r.week, 'rating', r.rating) order by r.week)
                                                  from public.goal_ratings r where r.goal_id = g.id), '[]'::jsonb))
                           order by g.position, g.created_at)
                     from public.clinic_goals g where g.link_id = o.id and g.created_at <= upto), '[]'::jsonb),
      'modules', coalesce((select jsonb_agg(jsonb_build_object(
                             'title', public.clinic_redact(m.title, nm), 'aim', public.clinic_redact(m.aim, nm),
                             'practice', public.clinic_redact(m.practice, nm),
                             'checklist', coalesce((select jsonb_agg(public.clinic_redact(c, nm)) from jsonb_array_elements_text(m.checklist) c), '[]'::jsonb),
                             'status', m.status, 'created_at', m.created_at,
                             'logs', coalesce((select jsonb_agg(jsonb_build_object('day', x.day, 'practiced', x.practiced,
                                                 'difficulty', x.difficulty, 'barrier', x.barrier) order by x.day desc)
                                                from public.care_module_logs x where x.module_id = m.id and x.created_at <= upto), '[]'::jsonb))
                             order by m.position, m.created_at)
                       from public.care_modules m where m.link_id = o.id and m.created_at <= upto), '[]'::jsonb)
    ));
  end loop;
  return res;
end $$;
revoke execute on function public.clinic_inherited_records(uuid) from public, anon;
grant execute on function public.clinic_inherited_records(uuid) to authenticated;

create or replace function public.family_clinic_links()
returns table (link_id uuid, clinic_id uuid, child_id uuid, clinic text, clinician text, title text, consent_at timestamptz,
               history_shared boolean, history_available boolean, verified_as text)
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.child_id, c.name, coalesce(m.name, ''), coalesce(m.title, ''), l.consent_at,
         exists (select 1 from public.clinic_link_history h where h.link_id = l.id),
         exists (select 1 from public.clinic_links o where o.child_id = l.child_id and o.clinic_id <> l.clinic_id
                 and o.status <> 'active' and o.consent_at <= l.consent_at),
         public.clinician_badge(m.id)
  from public.clinic_links l
  join public.clinics c on c.id = l.clinic_id
  left join public.clinicians m on m.id = l.clinician_id
  where l.family_id = public.my_family_id() and l.status = 'active'
  order by l.consent_at
$$;
revoke execute on function public.family_clinic_links() from public, anon;
grant execute on function public.family_clinic_links() to authenticated;

-- =====================================================================
-- E. Uzman belge incelemesi
-- =====================================================================
-- Ad karşılaştırma anahtarı (Türkçe büyük/küçük harf, fazla boşluk)
create or replace function public.name_key(p text)
returns text language sql immutable set search_path = '' as $$
  select lower(translate(regexp_replace(btrim(coalesce(p, '')), '\s+', ' ', 'g'), 'İIı', 'iii'))
$$;
revoke execute on function public.name_key(text) from public, anon;
grant execute on function public.name_key(text) to authenticated;

-- Rozet: bayrak uzmana göre (kişiye istisna tutarlı); "Diğer" meslekte "Uzman"
create or replace function public.clinician_badge(p_clinician uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case when m.verified_profession = 'diger' then 'Uzman' else public.clinician_profession_label(m.verified_profession) end
    from public.clinicians m
   where m.id = p_clinician and m.verified_at is not null and public.flag_on(m.id, 'clinician_verification')
$$;
revoke execute on function public.clinician_badge(uuid) from public, anon, authenticated;

alter table public.clinician_verifications add column if not exists submitted_name text;   -- gönderimdeki ad (onayda karşılaştırılır)

-- Silinecek belge kuyruğu (Edge Function boşaltır; SQL kova dosyasını silemez)
create table if not exists public.storage_trash (
  id          bigserial primary key,
  bucket      text not null,
  path        text not null,
  created_at  timestamptz not null default now()
);
alter table public.storage_trash enable row level security;
revoke all on public.storage_trash from anon, authenticated;

create or replace function public.clinician_verifications_trash() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'pending' or old.file_path is not null then
      insert into public.storage_trash (bucket, path)
      values ('verify', coalesce(old.file_path, old.clinician_id::text || '/' || old.id::text || '.pdf'));
    end if;
    return old;
  end if;
  if old.status = 'pending' and new.status <> 'pending' then
    insert into public.storage_trash (bucket, path)
    values ('verify', coalesce(old.file_path, old.clinician_id::text || '/' || old.id::text || '.pdf'));
    if new.status in ('auto_rejected', 'withdrawn') then new.file_path := null; end if;
  end if;
  return new;
end $$;
revoke execute on function public.clinician_verifications_trash() from public, anon, authenticated;
drop trigger if exists clinician_verifications_trash on public.clinician_verifications;
create trigger clinician_verifications_trash before update of status or delete on public.clinician_verifications
  for each row execute function public.clinician_verifications_trash();

-- Var olan artıklar bir kez kuyruğa (kendiliğinden reddedilen / geri çekilen başvuruların dosyaları)
insert into public.storage_trash (bucket, path)
select 'verify', v.clinician_id::text || '/' || v.id::text || '.pdf' from public.clinician_verifications v
 where v.status in ('auto_rejected', 'withdrawn')
   and not exists (select 1 from public.storage_trash t where t.bucket = 'verify' and t.path = v.clinician_id::text || '/' || v.id::text || '.pdf');
update public.clinician_verifications set file_path = null where status in ('auto_rejected', 'withdrawn') and file_path is not null;

create or replace function public.storage_trash_take(p_bucket text, p_limit integer default 50)
returns table (id bigint, path text) language sql stable security definer set search_path = '' as $$
  select t.id, t.path from public.storage_trash t where t.bucket = p_bucket order by t.id limit greatest(1, least(coalesce(p_limit, 50), 200))
$$;
revoke execute on function public.storage_trash_take(text, integer) from public, anon, authenticated;
grant execute on function public.storage_trash_take(text, integer) to service_role;

create or replace function public.storage_trash_done(p_ids bigint[])
returns void language sql security definer set search_path = '' as $$
  delete from public.storage_trash where id = any(p_ids)
$$;
revoke execute on function public.storage_trash_done(bigint[]) from public, anon, authenticated;
grant execute on function public.storage_trash_done(bigint[]) to service_role;

-- Yükleme yalnız açık (gönderilmemiş) başvurunun tek dosya yoluna ve bayrak açıkken
create or replace function public.verify_upload_ok(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.flag_on(auth.uid(), 'clinician_verification') and exists (
    select 1 from public.clinician_verifications v
     where v.clinician_id = auth.uid() and v.status = 'pending' and v.submitted_at is null
       and p_name = auth.uid()::text || '/' || v.id::text || '.pdf')
$$;
revoke execute on function public.verify_upload_ok(text) from public, anon;
grant execute on function public.verify_upload_ok(text) to authenticated;
drop policy if exists "doğrulama belgesi: uzman yükler" on storage.objects;
create policy "doğrulama belgesi: uzman yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'verify' and public.verify_upload_ok(name));
drop policy if exists "doğrulama belgesi: uzman siler" on storage.objects;   -- işlemiyordu (okuma kuralı yok); silme kuyrukla

create or replace function public.clinician_verification_submit(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v public.clinician_verifications%rowtype;
  path text;
begin
  if not public.flag_on(auth.uid(), 'clinician_verification') then raise exception 'Belge incelemesi henüz açık değil'; end if;
  select * into v from public.clinician_verifications where id = p_id and clinician_id = auth.uid() and status = 'pending' for update;
  if not found then raise exception 'Başvuru bulunamadı'; end if;
  if v.submitted_at is not null then raise exception 'Başvuru zaten gönderildi'; end if;
  path := v.clinician_id::text || '/' || v.id::text || '.pdf';
  if exists (select 1 from storage.objects where bucket_id = 'verify' and name = path) then
    update public.clinician_verifications set file_path = path, submitted_at = now(),
           submitted_name = (select name from public.clinicians where id = v.clinician_id) where id = v.id;
  elsif v.profession = 'bcba' then
    update public.clinician_verifications set submitted_at = now(),
           submitted_name = (select name from public.clinicians where id = v.clinician_id) where id = v.id;
  else
    raise exception 'Önce belgeni yükle';
  end if;
end $$;
revoke execute on function public.clinician_verification_submit(uuid) from public, anon;
grant execute on function public.clinician_verification_submit(uuid) to authenticated;

-- Ön kontrol: her başvuru bir kez; barkod başka uzmanda onaylı/askıdaysa ret, bekleyende uyarı;
-- elle incelenen meslekler ve BCBA kendiliğinden reddedilmez (barkod çakışması hariç)
create or replace function public.clinician_verification_autocheck(p_id uuid, p_auto jsonb, p_barcode text default null, p_hard text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v public.clinician_verifications%rowtype;
  bc text := nullif(left(btrim(coalesce(p_barcode, '')), 60), '');
  hard text := p_hard;
  a jsonb := coalesce(p_auto, '{}');
begin
  select * into v from public.clinician_verifications where id = p_id for update;
  if not found or v.status <> 'pending' or v.submitted_at is null or v.checked_at is not null then return 'skipped'; end if;
  if hard is not null and (hard not in ('unreadable', 'student_doc') or v.profession in ('hekim', 'diger', 'bcba')) then hard := null; end if;
  if bc is not null then
    if exists (select 1 from public.clinician_verifications o
                where o.barcode = bc and o.clinician_id <> v.clinician_id and o.status in ('approved', 'suspended')) then
      hard := 'duplicate';
    elsif exists (select 1 from public.clinician_verifications o
                   where o.barcode = bc and o.clinician_id <> v.clinician_id and o.status = 'pending') then
      a := jsonb_set(a, '{checks}', coalesce(a -> 'checks', '{}'::jsonb) || '{"duplicate": "warn"}'::jsonb);
    end if;
  end if;
  update public.clinician_verifications
     set auto = a, barcode = bc, checked_at = now(),
         status = case when hard is not null then 'auto_rejected' else status end,
         reason = coalesce(hard, reason), decided_at = case when hard is not null then now() end
   where id = v.id;
  if hard is not null then
    perform public.notify(v.clinician_id, 'clinic', 'verification_rejected', 'Belge incelemesi: yeniden yükle',
      case hard when 'unreadable' then 'Belge okunamadı. e-Devlet''ten indirdiğin PDF''i değiştirmeden yükle.'
                when 'student_doc' then 'Bu bir öğrenci belgesi. Mezuniyet belgesi gerekiyor.'
                else 'Bu belge başka bir hesapta kullanılmış.' end,
      jsonb_build_object('verification_id', v.id, 'reason', hard));
  end if;
  return coalesce(hard, 'pending');
end $$;
revoke execute on function public.clinician_verification_autocheck(uuid, jsonb, text, text) from public, anon, authenticated;
grant execute on function public.clinician_verification_autocheck(uuid, jsonb, text, text) to service_role;

create or replace function public.clinician_verification_for_check(p_id uuid, p_user uuid)
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object('id', v.id, 'profession', v.profession, 'file_path', v.file_path, 'name', m.name, 'status', v.status,
                           'submitted', v.submitted_at is not null, 'checked', v.checked_at is not null)
    from public.clinician_verifications v join public.clinicians m on m.id = v.clinician_id
   where v.id = p_id and v.clinician_id = p_user
$$;
revoke execute on function public.clinician_verification_for_check(uuid, uuid) from public, anon, authenticated;
grant execute on function public.clinician_verification_for_check(uuid, uuid) to service_role;

-- Liste yalnız belgeleri inceleyen roller (support/owner): barkod, BACB no ve e-posta içerir
create or replace function public.admin_verifications(p_status text default 'pending', p_limit integer default 50)
returns table (id uuid, clinician_id uuid, clinician text, title text, email text, clinic text, profession text, profession_label text,
               bacb_number text, status text, reason text, note text, auto jsonb, barcode text, has_file boolean,
               submitted_at timestamptz, checked_at timestamptz, decided_at timestamptz, created_at timestamptz, previous integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require(array['support']);
  return query
  select v.id, m.id, m.name, m.title, u.email::text, c.name, v.profession, public.clinician_profession_label(v.profession),
         v.bacb_number, v.status, v.reason, v.note, v.auto, v.barcode, v.file_path is not null,
         v.submitted_at, v.checked_at, v.decided_at, v.created_at,
         (select count(*)::int from public.clinician_verifications o where o.clinician_id = v.clinician_id and o.id <> v.id
           and o.status in ('rejected', 'auto_rejected'))
    from public.clinician_verifications v
    join public.clinicians m on m.id = v.clinician_id
    join public.clinics c on c.id = m.clinic_id
    left join auth.users u on u.id = m.id
   where (p_status is null or v.status = p_status) and (v.status <> 'pending' or v.submitted_at is not null)
   order by case when v.status = 'pending' then v.submitted_at end asc nulls last, v.created_at desc
   limit greatest(1, least(coalesce(p_limit, 50), 200));
end $$;
revoke execute on function public.admin_verifications(text, integer) from public, anon;
grant execute on function public.admin_verifications(text, integer) to authenticated;

create or replace function public.admin_verification_decide(p_id uuid, p_approve boolean, p_reason_code text, p_note text,
                                                            p_barcode text, p_summary jsonb, p_reason text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  v public.clinician_verifications%rowtype;
  bc text := nullif(left(btrim(coalesce(p_barcode, '')), 60), '');
  s jsonb;
begin
  if p_approve is null then raise exception 'Onay ya da ret seç'; end if;
  select * into v from public.clinician_verifications where id = p_id for update;
  if not found or v.status not in ('pending', 'auto_rejected') then raise exception 'Başvuru karar beklemiyor'; end if;
  if not p_approve and (p_reason_code is null or p_reason_code not in ('name_mismatch', 'barcode_invalid', 'program_mismatch',
       'degree_mismatch', 'unreadable', 'student_doc', 'duplicate', 'bacb_inactive', 'other')) then
    raise exception 'Ret nedeni seç';
  end if;
  if char_length(coalesce(p_note, '')) > 300 then raise exception 'Açıklama en çok 300 karakter'; end if;
  if p_approve and coalesce(bc, v.barcode) is not null and exists (select 1 from public.clinician_verifications o
       where o.barcode = coalesce(bc, v.barcode) and o.clinician_id <> v.clinician_id and o.status in ('approved', 'suspended')) then
    raise exception 'Bu barkod başka bir uzmanda onaylı';
  end if;
  if p_approve and v.submitted_name is not null
     and public.name_key(v.submitted_name) <> public.name_key((select name from public.clinicians where id = v.clinician_id)) then
    raise exception 'Uzman başvurudan sonra adını değiştirdi; belgeyi yeniden yüklemesini iste';
  end if;
  s := case when p_approve then jsonb_strip_nulls(jsonb_build_object(
         'university', left(p_summary ->> 'university', 120), 'program', left(p_summary ->> 'program', 120),
         'degree', left(p_summary ->> 'degree', 40), 'graduation_year', left(p_summary ->> 'graduation_year', 4))) end;
  update public.clinician_verifications
     set status = case when p_approve then 'approved' else 'rejected' end,
         reason = case when p_approve then null else p_reason_code end,
         note = nullif(btrim(coalesce(p_note, '')), ''), barcode = coalesce(bc, barcode), summary = s,
         auto = auto - 'extracted',   -- karar sonrası yalnız özet kalır
         decided_at = now(), decided_by = me, file_path = null,
         recheck_at = case when p_approve and v.profession = 'bcba' then now() + interval '1 year' end
   where id = v.id;
  if p_approve then
    update public.clinicians set verified_profession = v.profession, verified_at = now() where id = v.clinician_id;
    update public.clinician_verifications set status = 'withdrawn'
     where clinician_id = v.clinician_id and status = 'approved' and id <> v.id;
    perform public.notify(v.clinician_id, 'clinic', 'verification_approved', 'Belgen incelendi',
      'Ailelerin davet ekranında "Belgesi incelendi: ' || coalesce(public.clinician_badge(v.clinician_id),
        case when v.profession = 'diger' then 'Uzman' else public.clinician_profession_label(v.profession) end) || '" görünür.',
      jsonb_build_object('verification_id', v.id));
  else
    perform public.notify(v.clinician_id, 'clinic', 'verification_rejected', 'Belge incelemesi: yeniden yükle',
      left(coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'Ayrıntı ClinicApp''te.'), 300),
      jsonb_build_object('verification_id', v.id, 'reason', p_reason_code));
  end if;
  perform public.admin_log(me, case when p_approve then 'verification.approve' else 'verification.reject' end,
                           'user', v.clinician_id::text, p_reason, jsonb_build_object('status', v.status),
                           jsonb_build_object('verification_id', v.id, 'profession', v.profession, 'reason_code', p_reason_code));
  return v.file_path;
end $$;
revoke execute on function public.admin_verification_decide(uuid, boolean, text, text, text, jsonb, text) from public, anon;
grant execute on function public.admin_verification_decide(uuid, boolean, text, text, text, jsonb, text) to authenticated;

-- Ad değişince rozet düşer; yalnız büyük/küçük harf ya da boşluk değişikliği düşürmez
create or replace function public.clinicians_verified_name_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.verified_at is not null and public.name_key(new.name) is distinct from public.name_key(old.name) then
    new.verified_at := null;
    new.verified_profession := null;
    update public.clinician_verifications set status = 'suspended', reason = 'name_changed'
     where clinician_id = new.id and status = 'approved';
  end if;
  return new;
end $$;
revoke execute on function public.clinicians_verified_name_guard() from public, anon, authenticated;
