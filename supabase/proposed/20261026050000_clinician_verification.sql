-- Uzman doğrulama (kullanıcı kararı 26 Ekim 2026; kriterler ve kaynaklar sozlesme/akislar.md 14, meslek eşlemesi veri/uzman_meslekleri.json).
-- 1) Uzman ClinicApp'te mesleğini seçer, e-Devlet "Yükseköğretim Mezun Belgesi"ni (barkodlu PDF) yükler; BCBA ise BACB sicil no.
-- 2) Edge Function `clinician-verify` belgeyi okur (metin katmanı, dışarıya veri gitmez), ad / bölüm / derece / barkod / öğrenci
--    belgesi ön kontrolünü yazar; yalnız kesin durumlarda (okunamayan belge, başka hesabın barkodu) kendiliğinden geri çevirir.
-- 3) Yönetim panelinde (support/owner, iki adımlı doğrulama) kişi barkodu turkiye.gov.tr/belge-dogrulama'da, BCBA'yı BACB
--    sicilinde sorgular ve onaylar ya da nedenle reddeder. Karar sonrası belge dosyası silinir; yalnız özet kalır.
-- 4) Onaylanan uzmanda rozet "Belgesi incelendi: <meslek>" (doğrulandı değil). Ad değişince rozet düşer.
-- 5) Görünürlük bayrağı `clinician_verification` (kullanıcı kararı 26 Ekim 2026): ilk sürümde KAPALI. Kapalıyken uzman başvuramaz,
--    ailelere rozet dönmez; ClinicApp ve ParentApp `client_config` bayrağına göre ekranı gizler. Yönetim panelinden açılır
--    (`admin_set_flag`; önce kişiye istisna `admin_set_user_flag` ile denenebilir). Karar hatırlatması DURUM.md.
-- Bu dosya 20261026100000_family_invite_links.sql'den ÖNCE çalışır (o dosyadaki aile yanıtları rozeti okur). Tekrar çalıştırılabilir.

-- ---------------------------------------------------------------------
-- 1. Tablolar
-- ---------------------------------------------------------------------
alter table public.clinicians add column if not exists verified_profession text;   -- rozet: onaylanan meslek anahtarı
alter table public.clinicians add column if not exists verified_at timestamptz;
-- (uzman bu iki sütunu yazamaz: authenticated yalnız (name, title) güncelleyebilir)

create or replace function public.clinician_profession_label(p_key text)
returns text language sql immutable set search_path = '' as $$
  select case p_key
    when 'psikolog' then 'Psikolog'
    when 'klinik_psikolog' then 'Klinik psikolog'
    when 'pdr' then 'Psikolojik danışman (PDR)'
    when 'ergoterapist' then 'Ergoterapist'
    when 'dil_konusma' then 'Dil ve konuşma terapisti'
    when 'ozel_egitim' then 'Özel eğitim öğretmeni'
    when 'cocuk_gelisimi' then 'Çocuk gelişimci'
    when 'bcba' then 'Davranış analisti (BCBA)'
    when 'hekim' then 'Çocuk ve ergen psikiyatristi'
    when 'diger' then 'Diğer'
  end
$$;
revoke execute on function public.clinician_profession_label(text) from public, anon;
grant execute on function public.clinician_profession_label(text) to authenticated;

-- Görünürlük bayrağı: ilk sürümde kapalı (var olan değer korunur)
insert into public.feature_flags (key, enabled, rollout_pct, description)
values ('clinician_verification', false, 100, 'Uzman belge incelemesi: ClinicApp "Belgeni yükle" + ailelere "Belgesi incelendi" rozeti')
on conflict (key) do nothing;

-- Aile yanıtlarındaki rozet metni: "Klinik psikolog" ya da null (bayrak kapalıysa null; açılış sayfasında oturum yok → genel bayrak)
create or replace function public.clinician_badge(p_clinician uuid)
returns text language sql stable security definer set search_path = '' as $$
  select public.clinician_profession_label(m.verified_profession)
    from public.clinicians m
   where m.id = p_clinician and m.verified_at is not null and public.flag_on(auth.uid(), 'clinician_verification')
$$;
revoke execute on function public.clinician_badge(uuid) from public, anon, authenticated;

create table if not exists public.clinician_verifications (
  id            uuid primary key default gen_random_uuid(),
  clinician_id  uuid not null references public.clinicians (id) on delete cascade,
  profession    text not null check (profession in ('psikolog', 'klinik_psikolog', 'pdr', 'ergoterapist', 'dil_konusma',
                                                     'ozel_egitim', 'cocuk_gelisimi', 'bcba', 'hekim', 'diger')),
  bacb_number   text check (bacb_number is null or bacb_number ~ '^[0-9A-Za-z-]{4,20}$'),
  file_path     text,                                  -- verify/<uzman>/<id>.pdf; karar sonrası null (dosya silinir)
  status        text not null default 'pending'
                check (status in ('pending', 'auto_rejected', 'approved', 'rejected', 'withdrawn', 'suspended')),
  auto          jsonb not null default '{}',           -- ön kontrol sonucu (Edge Function)
  checked_at    timestamptz,
  barcode       text check (barcode is null or char_length(barcode) <= 60),
  reason        text check (reason is null or reason in ('name_mismatch', 'barcode_invalid', 'program_mismatch', 'degree_mismatch',
                                                         'unreadable', 'student_doc', 'duplicate', 'bacb_inactive', 'name_changed', 'other')),
  note          text check (note is null or char_length(note) <= 300),   -- yöneticinin uzmana açıklaması
  summary       jsonb,                                 -- onayda kalan özet: üniversite, bölüm, derece, mezuniyet yılı (ad yok)
  submitted_at  timestamptz,
  decided_at    timestamptz,
  decided_by    uuid references auth.users (id) on delete set null,
  recheck_at    timestamptz,                           -- BCBA: yıllık yeniden bakış
  created_at    timestamptz not null default now()
);
create index if not exists clinician_verifications_clinician_idx on public.clinician_verifications (clinician_id, created_at desc);
create index if not exists clinician_verifications_status_idx on public.clinician_verifications (status, submitted_at);
create index if not exists clinician_verifications_barcode_idx on public.clinician_verifications (barcode) where barcode is not null;
alter table public.clinician_verifications enable row level security;
revoke all on public.clinician_verifications from anon, authenticated;
-- tabloya doğrudan erişim yok; uzman clinician_verification_me(), panel admin_* ile

-- Belgeyi okuyabilen: support/owner rolü + iki adımlı doğrulama (kova kuralında kullanılır)
create or replace function public.admin_can_review()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.admin_role_of(auth.uid()) in ('owner', 'support'), false) and coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
$$;
revoke execute on function public.admin_can_review() from public, anon;
grant execute on function public.admin_can_review() to authenticated;

-- Belge kovası: yalnız PDF, en çok 10 MB; uzman kendi klasörüne yükler; okuma yalnız yönetici (support/owner, iki adımlı)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('verify', 'verify', false, 10485760, array['application/pdf'])
on conflict (id) do nothing;
drop policy if exists "doğrulama belgesi: uzman yükler" on storage.objects;
create policy "doğrulama belgesi: uzman yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'verify' and (storage.foldername(name))[1] = auth.uid()::text
              and exists (select 1 from public.clinicians m where m.id = auth.uid()));
drop policy if exists "doğrulama belgesi: uzman siler" on storage.objects;
create policy "doğrulama belgesi: uzman siler" on storage.objects for delete to authenticated
  using (bucket_id = 'verify' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "doğrulama belgesi: yönetici okur" on storage.objects;
create policy "doğrulama belgesi: yönetici okur" on storage.objects for select to authenticated
  using (bucket_id = 'verify' and public.admin_can_review());
drop policy if exists "doğrulama belgesi: yönetici siler" on storage.objects;
create policy "doğrulama belgesi: yönetici siler" on storage.objects for delete to authenticated
  using (bucket_id = 'verify' and public.admin_can_review());

-- ---------------------------------------------------------------------
-- 2. Uzman (ClinicApp)
-- ---------------------------------------------------------------------
-- Başvuru aç: önceki açık başvuru geri çekilir. Dönüş: {id, upload_path} (BCBA'da belge isteğe bağlı).
create or replace function public.clinician_verification_start(p_profession text, p_bacb_number text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  vid uuid;
  b text := nullif(upper(btrim(coalesce(p_bacb_number, ''))), '');
begin
  select * into me from public.clinicians where id = auth.uid();
  if not found then raise exception 'Yalnızca uzman hesabı'; end if;
  if not public.flag_on(me.id, 'clinician_verification') then raise exception 'Belge incelemesi henüz açık değil'; end if;
  if public.clinician_profession_label(p_profession) is null then raise exception 'Meslek seç'; end if;
  if p_profession = 'bcba' and b is null then raise exception 'BACB sicil numarasını yaz'; end if;
  if b is not null and b !~ '^[0-9A-Z-]{4,20}$' then raise exception 'BACB sicil numarası geçersiz'; end if;
  if (select count(*) from public.clinician_verifications where clinician_id = me.id and created_at > now() - interval '1 day') >= 5 then
    raise exception 'Bugün çok fazla başvuru yaptın; yarın tekrar dene';
  end if;
  update public.clinician_verifications set status = 'withdrawn' where clinician_id = me.id and status = 'pending';
  insert into public.clinician_verifications (clinician_id, profession, bacb_number)
  values (me.id, p_profession, case when p_profession = 'bcba' then b end)
  returning id into vid;
  return json_build_object('id', vid, 'upload_path', me.id::text || '/' || vid::text || '.pdf');
end $$;
revoke execute on function public.clinician_verification_start(text, text) from public, anon;
grant execute on function public.clinician_verification_start(text, text) to authenticated;

-- Belge yüklendi (ya da BCBA'da belgesiz): incelemeye gönder. Ön kontrolü ClinicApp ardından Edge Function'a yaptırır.
create or replace function public.clinician_verification_submit(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v public.clinician_verifications%rowtype;
  path text;
begin
  select * into v from public.clinician_verifications where id = p_id and clinician_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Başvuru bulunamadı'; end if;
  path := v.clinician_id::text || '/' || v.id::text || '.pdf';
  if exists (select 1 from storage.objects where bucket_id = 'verify' and name = path) then
    update public.clinician_verifications set file_path = path, submitted_at = now() where id = v.id;
  elsif v.profession = 'bcba' then
    update public.clinician_verifications set submitted_at = now() where id = v.id;
  else
    raise exception 'Önce belgeni yükle';
  end if;
end $$;
revoke execute on function public.clinician_verification_submit(uuid) from public, anon;
grant execute on function public.clinician_verification_submit(uuid) to authenticated;

-- Uzmanın kendi durumu: rozet + son başvuru (yönetici adı, belge yolu ve ön kontrol ayrıntısı dönmez)
create or replace function public.clinician_verification_me()
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'enabled', public.flag_on(m.id, 'clinician_verification'),
    'verified_profession', m.verified_profession,
    'verified_label', public.clinician_profession_label(m.verified_profession),
    'verified_at', m.verified_at,
    'last', (select json_build_object('id', v.id, 'profession', v.profession, 'status', v.status, 'reason', v.reason, 'note', v.note,
                                      'submitted', v.submitted_at is not null, 'checked', v.checked_at is not null,
                                      'created_at', v.created_at, 'decided_at', v.decided_at)
               from public.clinician_verifications v where v.clinician_id = m.id and v.status <> 'withdrawn'
              order by v.created_at desc limit 1))
  from public.clinicians m where m.id = auth.uid()
$$;
revoke execute on function public.clinician_verification_me() from public, anon;
grant execute on function public.clinician_verification_me() to authenticated;

-- ---------------------------------------------------------------------
-- 3. Ön kontrol (yalnız Edge Function, service_role)
-- ---------------------------------------------------------------------
-- p_auto: {checks: {...}, extracted: {...}}; p_hard: 'unreadable' | 'student_doc' | null (kesin durum → kendiliğinden ret).
-- Barkod başka bir uzmanın bekleyen ya da onaylı başvurusunda varsa 'duplicate'.
create or replace function public.clinician_verification_autocheck(p_id uuid, p_auto jsonb, p_barcode text default null, p_hard text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v public.clinician_verifications%rowtype;
  bc text := nullif(left(btrim(coalesce(p_barcode, '')), 60), '');
  hard text := p_hard;
begin
  select * into v from public.clinician_verifications where id = p_id for update;
  if not found or v.status <> 'pending' then return 'skipped'; end if;
  if bc is not null and exists (select 1 from public.clinician_verifications o
                                 where o.barcode = bc and o.clinician_id <> v.clinician_id and o.status in ('pending', 'approved')) then
    hard := 'duplicate';
  end if;
  if hard is not null and hard not in ('unreadable', 'student_doc', 'duplicate') then hard := null; end if;
  update public.clinician_verifications
     set auto = coalesce(p_auto, '{}'), barcode = bc, checked_at = now(),
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

-- Edge Function'ın okuyacağı başvuru (sahibi doğrulanır)
create or replace function public.clinician_verification_for_check(p_id uuid, p_user uuid)
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object('id', v.id, 'profession', v.profession, 'file_path', v.file_path, 'name', m.name, 'status', v.status)
    from public.clinician_verifications v join public.clinicians m on m.id = v.clinician_id
   where v.id = p_id and v.clinician_id = p_user
$$;
revoke execute on function public.clinician_verification_for_check(uuid, uuid) from public, anon, authenticated;
grant execute on function public.clinician_verification_for_check(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------
-- 4. Yönetim paneli (sozlesme/admin.md)
-- ---------------------------------------------------------------------
-- Liste: bekleyenler en eskiden; ön kontrol sonucu ve BACB no ile
create or replace function public.admin_verifications(p_status text default 'pending', p_limit integer default 50)
returns table (id uuid, clinician_id uuid, clinician text, title text, email text, clinic text, profession text, profession_label text,
               bacb_number text, status text, reason text, note text, auto jsonb, barcode text, has_file boolean,
               submitted_at timestamptz, checked_at timestamptz, decided_at timestamptz, created_at timestamptz, previous integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require(null);
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

-- Belgeyi aç: görüntüleme denetim kaydına yazılır; panel dönen yolla imzalı bağlantı ister (kova kuralı yönetici okur)
create or replace function public.admin_verification_open(p_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  v public.clinician_verifications%rowtype;
begin
  select * into v from public.clinician_verifications where id = p_id;
  if not found or v.file_path is null then raise exception 'Belge yok'; end if;
  perform public.admin_log(me, 'verification.view', 'user', v.clinician_id::text, 'belge incelemesi', null,
                           jsonb_build_object('verification_id', v.id));
  return v.file_path;
end $$;
revoke execute on function public.admin_verification_open(uuid) from public, anon;
grant execute on function public.admin_verification_open(uuid) to authenticated;

-- Karar: onay ya da ret (neden kodu + uzmana açıklama). Dönüş: silinecek belge yolu (panel kovadan siler).
-- p_summary: onayda kalacak özet {university, program, degree, graduation_year} — ad ve kimlik numarası yazılmaz.
create or replace function public.admin_verification_decide(p_id uuid, p_approve boolean, p_reason_code text, p_note text,
                                                            p_barcode text, p_summary jsonb, p_reason text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  v public.clinician_verifications%rowtype;
  bc text := nullif(left(btrim(coalesce(p_barcode, '')), 60), '');
  s jsonb;
begin
  select * into v from public.clinician_verifications where id = p_id for update;
  if not found or v.status not in ('pending', 'auto_rejected') then raise exception 'Başvuru karar beklemiyor'; end if;
  if not p_approve and (p_reason_code is null or p_reason_code not in ('name_mismatch', 'barcode_invalid', 'program_mismatch',
       'degree_mismatch', 'unreadable', 'student_doc', 'duplicate', 'bacb_inactive', 'other')) then
    raise exception 'Ret nedeni seç';
  end if;
  if char_length(coalesce(p_note, '')) > 300 then raise exception 'Açıklama en çok 300 karakter'; end if;
  if p_approve and bc is not null and exists (select 1 from public.clinician_verifications o
       where o.barcode = bc and o.clinician_id <> v.clinician_id and o.status = 'approved') then
    raise exception 'Bu barkod başka bir uzmanda onaylı';
  end if;
  s := case when p_approve then jsonb_strip_nulls(jsonb_build_object(
         'university', left(p_summary ->> 'university', 120), 'program', left(p_summary ->> 'program', 120),
         'degree', left(p_summary ->> 'degree', 40), 'graduation_year', left(p_summary ->> 'graduation_year', 4))) end;
  update public.clinician_verifications
     set status = case when p_approve then 'approved' else 'rejected' end,
         reason = case when p_approve then null else p_reason_code end,
         note = nullif(btrim(coalesce(p_note, '')), ''), barcode = coalesce(bc, barcode), summary = s,
         decided_at = now(), decided_by = me, file_path = null,
         recheck_at = case when p_approve and v.profession = 'bcba' then now() + interval '1 year' end
   where id = v.id;
  if p_approve then
    update public.clinicians set verified_profession = v.profession, verified_at = now() where id = v.clinician_id;
    update public.clinician_verifications set status = 'withdrawn'
     where clinician_id = v.clinician_id and status = 'approved' and id <> v.id;
    perform public.notify(v.clinician_id, 'clinic', 'verification_approved', 'Belgen incelendi',
      'Ailelerin davet ekranında "Belgesi incelendi: ' || public.clinician_profession_label(v.profession) || '" görünür.',
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

-- Rozeti askıya al (şikâyet, BCBA süresi, yanlış beyan)
create or replace function public.admin_verification_suspend(p_clinician uuid, p_note text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
begin
  if not exists (select 1 from public.clinicians where id = p_clinician and verified_at is not null) then
    raise exception 'Uzmanın rozeti yok';
  end if;
  update public.clinicians set verified_profession = null, verified_at = null where id = p_clinician;
  update public.clinician_verifications set status = 'suspended', reason = 'other', note = left(nullif(btrim(coalesce(p_note, '')), ''), 300)
   where clinician_id = p_clinician and status = 'approved';
  perform public.notify(p_clinician, 'clinic', 'verification_suspended', 'Belge rozetin askıya alındı',
    left(coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'Ayrıntı için destek ekibine yaz.'), 300), '{}'::jsonb);
  perform public.admin_log(me, 'verification.suspend', 'user', p_clinician::text, p_reason, null, null);
end $$;
revoke execute on function public.admin_verification_suspend(uuid, text, text) from public, anon;
grant execute on function public.admin_verification_suspend(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Ad değişince rozet düşer (belgedeki adla eşleşme bozulur)
-- ---------------------------------------------------------------------
create or replace function public.clinicians_verified_name_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.verified_at is not null and lower(btrim(new.name)) is distinct from lower(btrim(old.name)) then
    new.verified_at := null;
    new.verified_profession := null;
    update public.clinician_verifications set status = 'suspended', reason = 'name_changed'
     where clinician_id = new.id and status = 'approved';
    -- bildirim yok (işlemi yapan kendisi); ClinicApp durumu clinician_verification_me() ile gösterir
  end if;
  return new;
end $$;
revoke execute on function public.clinicians_verified_name_guard() from public, anon, authenticated;
drop trigger if exists clinicians_verified_name_guard on public.clinicians;
create trigger clinicians_verified_name_guard before update of name on public.clinicians
  for each row execute function public.clinicians_verified_name_guard();
