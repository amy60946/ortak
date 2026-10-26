-- Aile daveti e-postayla (26 Ekim 2026, kullanıcı kararı; sozlesme/akislar.md 10).
-- Uzman ebeveynin e-postasını yazar (ClinicApp'te zorunlu), "E-posta gönder"e basar; e-postayı sistem uzman adına gönderir:
-- Edge Function `invite-email` (test: kullanıcının Gmail hesabı, SMTP; canlı: alan adı + Resend). Yedek: uzman kodu kopyalar.
--
-- 1) Aile daveti 3 gün (72 saat) geçerli (önce 48 saat). Açık (bağlanmamış, bitmemiş) davetler 72 saate uzar.
-- 2) clinic_invites: email_count (gönderilen e-posta), email_sent_at (son gönderim), email_status (sending / sent / failed).
-- 3) clinic_invite_email_take / clinic_invite_email_done: yalnız sunucu (service role). İşlev oturumu doğrular, uzmanı p_user ile geçer.
--    Sınırlar (kötüye kullanım): davet başına en çok 3 e-posta, aynı davete 60 sn'de bir, uzman başına günde en çok 30 davete e-posta.
--    Gönderilemeyen e-posta sayılmaz (hak geri verilir), 60 sn beklemesi kalır.
-- 4) clinic_invites_list e-posta durumunu da döndürür.
-- Tekrar çalıştırılabilir.

-- =====================================================================
-- 1. E-posta alanları
-- =====================================================================
alter table public.clinic_invites add column if not exists email_count integer not null default 0;
alter table public.clinic_invites add column if not exists email_sent_at timestamptz;
alter table public.clinic_invites add column if not exists email_status text;
do $$ begin
  alter table public.clinic_invites add constraint clinic_invites_email_status_check
    check (email_status is null or email_status in ('sending', 'sent', 'failed'));
exception when duplicate_object then null; end $$;
create index if not exists clinic_invites_email_sent_idx on public.clinic_invites (clinician_id, email_sent_at) where email_sent_at is not null;

-- =====================================================================
-- 2. Davet 3 gün
-- =====================================================================
-- Açık davetler 72 saate uzar (bağlanmış davetin 30 günü ayrı kuraldır)
update public.clinic_invites set expires_at = created_at + interval '72 hours'
 where kind = 'family' and used_at is null and revoked_at is null and declined_at is null and claimed_at is null
   and expires_at > now() and expires_at < created_at + interval '72 hours';

-- Davet oluştur. Aile: 72 saat, bağlantı anahtarı + 6 karakter kod. Ekip: 15 dakika, 8 karakter (değişmedi).
create or replace function public.clinic_create_invite(p_kind text default 'family', p_label text default '',
                                                        p_parent_name text default '', p_parent_email text default null,
                                                        p_child_name text default '', p_child_age_group text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  new_code text;
  new_token text;
  exp timestamptz;
  email text := nullif(lower(trim(coalesce(p_parent_email, ''))), '');
  kid text := nullif(left(btrim(coalesce(p_child_name, '')), 40), '');
  grp text := nullif(upper(btrim(coalesce(p_child_age_group, ''))), '');
begin
  select * into me from public.clinicians where id = auth.uid();
  if not found then raise exception 'Yalnızca uzman hesabı'; end if;
  if p_kind not in ('family', 'clinician') then raise exception 'Geçersiz davet türü'; end if;
  if not public.clinician_access() then raise exception 'Üyelik etkin değil' using errcode = 'P0402'; end if;
  if p_kind = 'clinician' and me.role <> 'owner' then raise exception 'Ekibe yalnızca klinik sahibi davet eder'; end if;
  if p_kind = 'clinician' and (select seat_limit from public.clinics where id = me.clinic_id) <= 1 then
    raise exception 'Bireysel pakette ekip yok; Klinik paketine geçin';
  end if;
  if email is not null and email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-posta adresi geçersiz'; end if;
  if grp is not null and grp not in ('K', 'A', 'B', 'C') then raise exception 'Geçersiz yaş grubu'; end if;
  if p_kind <> 'family' then kid := null; grp := null; end if;
  -- günde en çok 100 aile daveti (kötüye kullanım sınırı)
  if p_kind = 'family' and (select count(*) from public.clinic_invites
                             where clinician_id = me.id and kind = 'family' and created_at > now() - interval '1 day') >= 100 then
    raise exception 'Bugün çok fazla davet oluşturdun; yarın tekrar dene';
  end if;
  delete from public.clinic_invites
   where clinic_id = me.clinic_id and kind = 'clinician' and used_at is null and expires_at < now() - interval '1 day';
  exp := now() + case when p_kind = 'family' then interval '72 hours' else interval '15 minutes' end;
  loop
    new_code := public.random_code(case when p_kind = 'clinician' then 8 else 6 end);
    exit when not exists (select 1 from public.clinic_invites where code = new_code)
          and not exists (select 1 from public.invite_codes where code = new_code);
  end loop;
  if p_kind = 'family' then new_token := replace(gen_random_uuid()::text, '-', ''); end if;
  insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at, token, parent_name, parent_email,
                                     child_name, child_age_group)
  values (new_code, me.clinic_id, me.id, p_kind, left(coalesce(p_label, ''), 60), exp, new_token,
          left(trim(coalesce(p_parent_name, '')), 60), email, kid, grp);
  return json_build_object('code', new_code, 'token', new_token, 'expires_at', exp);
end $$;
revoke execute on function public.clinic_create_invite(text, text, text, text, text, text) from public, anon;
grant execute on function public.clinic_create_invite(text, text, text, text, text, text) to authenticated;

-- Aile davetinde nedenli ret (deneme kaydı + 400); metin 3 güne göre
create or replace function public.clinic_invite_rejected(p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
begin
  insert into public.code_attempts (user_id, ip) values (auth.uid(), public.request_ip());
  perform set_config('response.status', '400', true);
  return json_build_object('error', 'invalid_code', 'reason', coalesce(p_reason, 'not_found'), 'hint', coalesce(p_reason, 'not_found'),
    'message', case p_reason
      when 'expired' then 'Davetin süresi doldu (davetler 3 gün geçerli). Uzmanından yeni davet iste.'
      when 'used' then 'Bu davet başka bir ailede kullanıldı. Uzmanından yeni davet iste.'
      when 'accepted' then 'Bu daveti zaten kabul ettin; paylaşım Uzmanım bölümünde.'
      when 'declined' then 'Bu daveti kapattın. Yanlışlıkla olduysa uzmanından yeni davet iste.'
      when 'revoked' then 'Bu davet iptal edildi. Uzmanından yeni davet iste.'
      else 'Davet bulunamadı. Kodu kontrol et ya da uzmanından yeni davet iste.' end);
end $$;
revoke execute on function public.clinic_invite_rejected(text) from public, anon, authenticated;

-- =====================================================================
-- 3. E-posta gönderimi (Edge Function invite-email)
-- =====================================================================
-- Gönderim hakkı al: davet açık, e-postası var, uzman paneli kullanabiliyor, sınırlar aşılmadı → e-posta için gereken bilgiler.
-- Hata: {error: not_found | no_email | closed | expired | no_access | limit_invite | too_soon | limit_day}
create or replace function public.clinic_invite_email_take(p_code text, p_user uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  inv public.clinic_invites%rowtype;
  c public.clinics%rowtype;
begin
  select * into me from public.clinicians where id = p_user;
  if not found then return jsonb_build_object('error', 'not_found'); end if;
  select * into inv from public.clinic_invites where code = upper(trim(coalesce(p_code, ''))) and kind = 'family' for update;
  if not found or inv.clinic_id is distinct from me.clinic_id or not (inv.clinician_id = me.id or me.role = 'owner') then
    return jsonb_build_object('error', 'not_found');
  end if;
  select * into c from public.clinics where id = me.clinic_id;
  if not (public.clinic_active(c.id) and (me.role = 'owner' or c.seat_limit > 1)) then return jsonb_build_object('error', 'no_access'); end if;
  if inv.parent_email is null then return jsonb_build_object('error', 'no_email'); end if;
  if inv.revoked_at is not null or inv.declined_at is not null or inv.used_at is not null or inv.claimed_at is not null then
    return jsonb_build_object('error', 'closed');
  end if;
  if inv.expires_at <= now() then return jsonb_build_object('error', 'expired'); end if;
  if inv.email_count >= 3 then return jsonb_build_object('error', 'limit_invite'); end if;
  if inv.email_sent_at > now() - interval '60 seconds' then return jsonb_build_object('error', 'too_soon'); end if;
  if (select count(*) from public.clinic_invites
       where clinician_id = me.id and code <> inv.code and email_sent_at > now() - interval '1 day') >= 30 then
    return jsonb_build_object('error', 'limit_day');
  end if;
  update public.clinic_invites
     set email_count = email_count + 1, email_sent_at = now(), email_status = 'sending', channel = 'email'
   where code = inv.code;
  -- davetli aile kendi ailesine bağlamadan çocuk önerisi ve uzmanın notu e-postaya girmez
  return jsonb_build_object('code', inv.code, 'token', inv.token, 'expires_at', inv.expires_at, 'to', inv.parent_email,
                            'clinician', me.name, 'title', me.title, 'clinic', c.name);
end $$;
revoke execute on function public.clinic_invite_email_take(text, uuid) from public, anon, authenticated;
grant execute on function public.clinic_invite_email_take(text, uuid) to service_role;

-- Gönderim sonucu: gönderilemeyen e-posta hakkı geri verilir (60 sn beklemesi kalır)
create or replace function public.clinic_invite_email_done(p_code text, p_ok boolean)
returns void language sql security definer set search_path = '' as $$
  update public.clinic_invites
     set email_status = case when p_ok then 'sent' else 'failed' end,
         email_count = case when p_ok then email_count else greatest(email_count - 1, 0) end
   where code = upper(trim(coalesce(p_code, ''))) and kind = 'family' and email_status = 'sending'
$$;
revoke execute on function public.clinic_invite_email_done(text, boolean) from public, anon, authenticated;
grant execute on function public.clinic_invite_email_done(text, boolean) to service_role;

-- =====================================================================
-- 4. Davet listesi: e-posta durumu
-- =====================================================================
drop function if exists public.clinic_invites_list(integer);
create function public.clinic_invites_list(p_days integer default 90)
returns table (code text, token text, clinician_id uuid, clinician text, label text, parent_name text, parent_email text,
               channel text, status text, created_at timestamptz, expires_at timestamptz, opened_at timestamptz,
               claimed_at timestamptz, used_at timestamptz, has_plan boolean, child_name text, child_age_group text,
               email_status text, email_count integer, email_sent_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select i.code, case when i.used_at is null and i.revoked_at is null then i.token end, i.clinician_id, coalesce(m.name, ''), i.label,
         i.parent_name, i.parent_email, i.channel, public.clinic_invite_status(i), i.created_at, i.expires_at, i.opened_at,
         i.claimed_at, i.used_at,
         exists (select 1 from public.clinic_goals g where g.invite_code = i.code)
         or exists (select 1 from public.care_modules x where x.invite_code = i.code),
         i.child_name, i.child_age_group, i.email_status, i.email_count, i.email_sent_at
    from public.clinic_invites i
    left join public.clinicians m on m.id = i.clinician_id
   where i.kind = 'family' and i.clinic_id = public.my_clinic_id()
     and (i.clinician_id = auth.uid() or public.clinic_is_owner())
     and i.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 90), 730)))
   order by i.created_at desc
   limit 200
$$;
revoke execute on function public.clinic_invites_list(integer) from public, anon;
grant execute on function public.clinic_invites_list(integer) to authenticated;
