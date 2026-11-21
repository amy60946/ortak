-- Destek formu ve davet e-postası sınırları (öneri, 21 Kasım 2026; güvenlik denetimi bulguları
-- support.global-hourly-cap-shared-exhaustion ve invite-email.clinician-text-relay.unverified-signup). Tekrar çalıştırılabilir.
-- Önkoşul: migrations/20261102210000_support.sql, migrations/20261027000000_invite_email.sql, migrations/20261105090000_workspaces.sql.
--
-- 1) Destek (support_request_create): tek kişinin farklı e-postalarla saatlik genel sınırı (60) doldurup formu herkese
--    kapatması engellenir.
--    · Kaynak başına sınır: Edge Function `support` gönderenin adresini p_source ile verir (Worker'dan gelen istekte
--      SUPPORT_FORWARD_KEY eşleşirse Worker'ın ilettiği adres, yoksa işlevin gördüğü adres; Worker'dan anahtarsız gelen istek
--      kaynak bilinmiyor sayılır). Adres düz saklanmaz: günlük rastgele tuzla SHA-256 özeti (support_requests.source_hash);
--      tuz 2 gün sonra silinir, özet 2 gün sonra boşaltılır. Adres inet ile ayrıştırılır; IPv4'e eşlenmiş IPv6 IPv4 sayılır,
--      öteki IPv6 /64 ağına indirgenir. Sayımda bugünün ve dünün tuzuyla iki özet aranır (gün dönümünde sayaç sıfırlanmaz).
--      Sınır: aynı kaynaktan saatte 5, 24 saatte 15 → {"error":"too_many_source"}.
--    · E-posta başına 24 saatte 3 → too_many. Kaynak biliniyorsa yalnız aynı kaynaktan o adresle açılanlar sayılır (başkası
--      bir kişinin adresini yazarak onun formunu kapatamaz); kaynak bilinmiyorsa adres başına. KVKK (topic 'privacy') muaf.
--    · Genel sınır yalnız son çare: saatte 300 ("istenmeyen" işaretlenenler ve KVKK talepleri sayılmaz) → busy. Dolunca son
--      bir saatte hiç yazmamış bilinen kaynak yine bir talep açar (sert tavan saatte 600).
--      "Kişisel verilerim (KVKK)" (topic 'privacy') ayrı paydan: saatte 100 KVKK talebi (genel sınır dolsa da kabul).
--    · Eski 5 parametreli imza durur (kaynak yok sayılır; yayındaki eski işlev çalışmaya devam eder).
-- 2) Davet e-postası (clinic_invite_email_take): mevcut sınırlara (davet başına 3, 60 sn, uzman başına günde 30 davet) ek
--    olarak her gönderim invite_email_sends'e yazılır (alıcı adres yalnız özet olarak; özet büyük/küçük harf, "+etiket" ve
--    Gmail'de nokta ve googlemail.com farkı atılarak: aynı gelen kutusunun takma adları tek alıcı sayılır):
--    · aynı alıcı adrese (bütün kliniklerden) 24 saatte 2, 7 günde 4 → rate_recipient
--    · uzman başına 24 saatte 20 gönderim; hesabın ilk 24 saatinde 5 → rate_clinician
--    · sistem payı saatte 200 yerleşik hesaplara; yerleşik olmayan (7 günden yeni ve ücretli paketi olmayan klinikte) hesaplar
--      ayrı küçük paydan saatte 60 ve yerleşiklerin payına sayılmaz → rate_global
--    Gönderilemeyen e-posta (clinic_invite_email_done p_ok=false) kayıttan düşer (hak geri verilir). Kayıt 8 gün tutulur;
--    uzman hesabı silinse de satır kalır (uzman bağı boşalır), silip yeniden kaydolmak alıcı sınırını sıfırlamaz.
--    Bütün sayaçlar (destek ve davet) danışma kilitleriyle (pg_advisory_xact_lock) sıraya alınır: paralel istekler aşamaz.

-- =====================================================================
-- 1. Destek
-- =====================================================================
alter table public.support_requests add column if not exists source_hash text;
create index if not exists support_requests_source_idx on public.support_requests (source_hash, created_at) where source_hash is not null;

-- Günlük tuz (yalnız sunucu; kimse okuyamaz)
create table if not exists public.support_source_salts (
  day  date primary key,
  salt text not null
);
alter table public.support_source_salts enable row level security;
revoke all on public.support_source_salts from public, anon, authenticated;

-- Kaynağın sayılan biçimi: gerçek adres ayrıştırıcısıyla (inet) denetlenir. IPv4 tam adres; IPv4'e eşlenmiş IPv6
-- (::ffff:a.b.c.d) IPv4'e çevrilir (yoksa bütün bu adresler tek /64 kovasına düşerdi); öteki IPv6 /64 ağı.
-- Adres biçiminde olmayan her değer (ör. Edge Function'ın 'unknown'u) tek ortak kovadır ('invalid'): değiştirerek sınır aşılmaz.
create or replace function public.support_source_net(p_source text)
returns text language plpgsql immutable set search_path = '' as $$
declare
  raw text := nullif(left(trim(coalesce(p_source, '')), 100), '');
  a inet;
begin
  if raw is null then return null; end if;
  begin
    a := host(raw::inet)::inet;
  exception when others then
    return 'invalid';
  end;
  if family(a) = 6 and a <<= '::ffff:0.0.0.0/96'::inet then
    a := '0.0.0.0'::inet + (a - '::ffff:0.0.0.0'::inet);
  end if;
  return case when family(a) = 6 then host(network(set_masklen(a, 64))) || '/64' else host(a) end;
end $$;
revoke execute on function public.support_source_net(text) from public, anon, authenticated;

-- Kaynağın özetleri: [bugünün tuzuyla, dünün tuzuyla (varsa)]. Sayımlar ikisine de bakar: gün dönümünde (UTC) sayaç
-- sıfırlanmaz (eskiden tek özet olduğu için gece yarısında aynı kaynak bir saatte 10 talep açabiliyordu).
-- Tuz 2 günden fazla tutulmaz; adres düz yazılmaz.
create or replace function public.support_source_hashes(p_source text)
returns text[] language plpgsql security definer set search_path = '' as $$
declare
  net text := public.support_source_net(p_source);
  today date := (now() at time zone 'utc')::date;
  s text;
  y text;
begin
  if net is null then return null; end if;
  insert into public.support_source_salts (day, salt) values (today, gen_random_uuid()::text || gen_random_uuid()::text)
    on conflict (day) do nothing;
  delete from public.support_source_salts where day < today - 1;
  select salt into s from public.support_source_salts where day = today;
  select salt into y from public.support_source_salts where day = today - 1;
  return array_remove(array[encode(extensions.digest(s || '|' || net, 'sha256'), 'hex'),
                            case when y is not null then encode(extensions.digest(y || '|' || net, 'sha256'), 'hex') end], null);
end $$;
revoke execute on function public.support_source_hashes(text) from public, anon, authenticated;

-- Adresin bugünkü özeti (kayda yazılan); adres yoksa null.
create or replace function public.support_source_hash(p_source text)
returns text language sql security definer set search_path = '' as $$
  select (public.support_source_hashes(p_source))[1]
$$;
revoke execute on function public.support_source_hash(text) from public, anon, authenticated;

-- Formdan yeni talep (yalnız sunucu: Edge Function `support`).
-- Dönüş: {"ref"} ya da {"error": "invalid" | "too_many" | "too_many_source" | "busy"}.
-- Sıra: kaynak sınırı (5/saat, 15/24 saat) → e-posta sınırı (KVKK hariç) → pay (KVKK ayrı; genel 300, ilk kez yazan kaynağa 600'e kadar).
create or replace function public.support_request_create(p_app text, p_topic text, p_email text, p_name text, p_message text,
                                                         p_source text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  em text := lower(trim(coalesce(p_email, '')));
  msg text := trim(coalesce(p_message, ''));
  nm text := left(trim(coalesce(p_name, '')), 80);
  srcs text[];
  src text;
  pool integer;
  r text;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   -- karışan harf/rakam yok (I, O, 0, 1)
  i integer;
begin
  if p_app not in ('parent', 'child', 'clinic', 'other') or p_topic not in ('account', 'subscription', 'bug', 'privacy', 'clinic', 'other')
     or char_length(em) not between 6 and 254 or em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
     or char_length(msg) not between 10 and 3000 then
    return jsonb_build_object('error', 'invalid');
  end if;
  srcs := public.support_source_hashes(p_source);
  src := srcs[1];
  -- Sayım ve kayıt yarışsız: paralel istekler birbirinin henüz işlenmemiş kaydını göremez, bu yüzden her sayaç kilitlenir.
  -- Sıra sabit (kaynak → e-posta → pay; kilitlenme yok). Pay kilidi her talepte alınır: bütün form talepleri sıraya girer
  -- (hacim saatte en çok birkaç yüz; aşım payı yok). Kilit anahtarları bellekte; özetin kendisi ya da adres yazılmaz.
  if src is not null then perform pg_advisory_xact_lock(hashtext('support:src'), hashtext(src)); end if;
  perform pg_advisory_xact_lock(hashtext('support:email'), hashtext(em));
  perform pg_advisory_xact_lock(hashtext('support:pool'), 0);
  -- 2 günden eski özetler boşaltılır (tuzu silindiği için zaten geri çevrilemez; kişisel veri azaltma)
  update public.support_requests set source_hash = null
   where source_hash is not null and created_at < now() - interval '2 days';
  if src is not null and (
       (select count(*) from public.support_requests where source_hash = any(srcs) and created_at > now() - interval '1 hour') >= 5
    or (select count(*) from public.support_requests where source_hash = any(srcs) and created_at > now() - interval '24 hours') >= 15) then
    return jsonb_build_object('error', 'too_many_source');
  end if;
  -- E-posta sınırı (24 saatte 3). Adres doğrulanmadığı için başkası da yazabilir: kaynak biliniyorsa yalnız AYNI kaynaktan
  -- bu adresle açılanlar sayılır (bir kaynak başkasının hakkını harcayamaz; "too_many" yalnız kendi gönderdiklerini söyler).
  -- Kaynak bilinmiyorsa (secret yok ya da eski 5 parametreli çağrı) adres başına. KVKK (privacy) bu sınırdan muaf: yasal
  -- başvuru yolu üçüncü kişi tarafından kapatılamasın (kaynak sınırı ve KVKK payı sürer).
  if p_topic <> 'privacy' and (
       (src is not null and (select count(*) from public.support_requests
                              where lower(email) = em and source_hash = any(srcs) and created_at > now() - interval '24 hours') >= 3)
    or (src is null and (select count(*) from public.support_requests
                          where lower(email) = em and created_at > now() - interval '24 hours') >= 3)) then
    return jsonb_build_object('error', 'too_many');
  end if;
  if p_topic = 'privacy' then
    -- KVKK başvurusu ayrı paydan: genel sınır dolsa da kabul (yasal başvuru yolu kapanmasın)
    if (select count(*) from public.support_requests
         where topic = 'privacy' and status <> 'spam' and created_at > now() - interval '1 hour') >= 100 then
      return jsonb_build_object('error', 'busy');
    end if;
  else
    select count(*) into pool from public.support_requests
     where topic <> 'privacy' and status <> 'spam' and created_at > now() - interval '1 hour';
    -- Genel pay (300) yalnız son çare. Dolunca herkes eşit reddedilmez: son bir saatte hiç yazmamış, bilinen bir kaynak
    -- yine bir talep açar (sert tavan 600), böylece birkaç kaynaktan gelen sel ilk kez yazanları dışarıda bırakmaz.
    -- Kalan risk: 600'ü doldurmak için en az ~360 ayrı kaynak (adres ya da /64) gerekir; tam koruma ancak bir doğrulamayla (Turnstile).
    if pool >= 300 and (src is null or pool >= 600
        or exists (select 1 from public.support_requests where source_hash = any(srcs) and created_at > now() - interval '1 hour')) then
      return jsonb_build_object('error', 'busy');
    end if;
  end if;
  loop
    r := 'D-';
    for i in 1..6 loop
      r := r || substr(alphabet, 1 + floor(random() * length(alphabet))::integer, 1);
    end loop;
    exit when not exists (select 1 from public.support_requests where ref = r);
  end loop;
  insert into public.support_requests (ref, app, topic, email, name, message, source_hash) values (r, p_app, p_topic, em, nm, msg, src);
  return jsonb_build_object('ref', r);
end $$;
revoke execute on function public.support_request_create(text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.support_request_create(text, text, text, text, text, text) to service_role;

-- Eski imza (yayındaki eski Edge Function): kaynak bilinmez, yalnız e-posta ve genel sınırlar
create or replace function public.support_request_create(p_app text, p_topic text, p_email text, p_name text, p_message text)
returns jsonb language sql security definer set search_path = '' as $$
  select public.support_request_create(p_app, p_topic, p_email, p_name, p_message, null::text)
$$;
revoke execute on function public.support_request_create(text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.support_request_create(text, text, text, text, text) to service_role;

-- =====================================================================
-- 2. Davet e-postası
-- =====================================================================
create table if not exists public.invite_email_sends (
  id           bigint generated always as identity primary key,
  at           timestamptz not null default now(),
  clinician_id uuid references public.clinicians (id) on delete set null,   -- hesap silinince satır kalır (sınır sıfırlanmasın)
  code         text,                                   -- davet kodu (rastgele; davet silinince hiçbir şeye bağlanmaz)
  to_hash      text not null,                           -- alıcı adresin özeti (adres düz yazılmaz)
  pool         text not null default 'main' check (pool in ('main', 'new'))   -- sistem payı: yerleşik / yeni hesap
);
alter table public.invite_email_sends add column if not exists pool text not null default 'main' check (pool in ('main', 'new'));
-- Hesabını silip yeniden kaydolan uzman alıcı sınırını sıfırlayamasın: uzman silinince gönderim satırı kalır (uzman boşalır),
-- 8 günlük saklamayla silinir. Satırda kişisel veri yok (alıcı yalnız özet; uzman bağı boşalır).
alter table public.invite_email_sends drop constraint if exists invite_email_sends_clinician_id_fkey;
alter table public.invite_email_sends add constraint invite_email_sends_clinician_id_fkey
  foreign key (clinician_id) references public.clinicians (id) on delete set null;
alter table public.invite_email_sends enable row level security;
revoke all on public.invite_email_sends from public, anon, authenticated;
create index if not exists invite_email_sends_to_idx on public.invite_email_sends (to_hash, at);
create index if not exists invite_email_sends_clinician_idx on public.invite_email_sends (clinician_id, at);
create index if not exists invite_email_sends_at_idx on public.invite_email_sends (at);
create index if not exists invite_email_sends_pool_idx on public.invite_email_sends (pool, at);

-- Alıcı sınırının anahtarı: aynı gelen kutusuna giden takma adlar tek alıcı. Küçük harf + kırpma; tam bir "@" varsa yerel
-- kısımdaki "+etiket" (her alan adında) atılır; gmail.com / googlemail.com'da noktalar da atılır ve googlemail.com → gmail.com.
-- Saklanan yalnız bu anahtarın özetidir (invite_email_to_hash). Eski anahtarla yazılmış satırlar (canlıda yok) dönüştürülmez.
create or replace function public.invite_email_key(p_email text)
returns text language sql immutable set search_path = '' as $$
  with e as (select lower(trim(coalesce(p_email, ''))) as v),
       p as (select v,
                    case when char_length(v) - char_length(replace(v, '@', '')) = 1 then split_part(v, '@', 1) end as l,
                    split_part(v, '@', 2) as d
               from e),
       q as (select v, d, l, coalesce(nullif(split_part(l, '+', 1), ''), l) as base from p)
  select case when l is null then v
              when d in ('gmail.com', 'googlemail.com') then coalesce(nullif(replace(base, '.', ''), ''), base) || '@gmail.com'
              else base || '@' || d end
    from q
$$;
revoke execute on function public.invite_email_key(text) from public, anon, authenticated;

create or replace function public.invite_email_to_hash(p_email text)
returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest('invite|' || public.invite_email_key(p_email), 'sha256'), 'hex')
$$;
revoke execute on function public.invite_email_to_hash(text) from public, anon, authenticated;

-- Edge Function invite-email çağırır (hizmet rolü, istek başlığı yok): uzmanın davetin alanındaki üyeliği denetlenir
create or replace function public.clinic_invite_email_take(p_code text, p_user uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  inv public.clinic_invites%rowtype;
  c public.clinics%rowtype;
  rl text;
  th text;
  pl text;
  cap integer;
begin
  select * into me from public.clinicians where id = p_user;
  if not found then return jsonb_build_object('error', 'not_found'); end if;
  select * into inv from public.clinic_invites where code = upper(trim(coalesce(p_code, ''))) and kind = 'family' for update;
  if found then rl := public.clinic_member_role(inv.clinic_id, me.id); end if;
  if not found or rl is null or not (inv.clinician_id = me.id or rl = 'owner') then
    return jsonb_build_object('error', 'not_found');
  end if;
  select * into c from public.clinics where id = inv.clinic_id;
  if not (public.clinic_active(c.id) and (rl = 'owner' or c.seat_limit > 1)) then return jsonb_build_object('error', 'no_access'); end if;
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
  -- Gönderim sınırları (bütün kliniklerden bağımsız; kötüye kullanım: sistem göndericisiyle toplu e-posta)
  delete from public.invite_email_sends where at < now() - interval '8 days';
  th := public.invite_email_to_hash(inv.parent_email);
  -- Sistem payı ikiye ayrılır: yeni açılmış hesaplar (ucuza çoğaltılabilir) yerleşik hesapların payını tüketemez.
  -- Yerleşik = uzman hesabı 7 günden eski (clinicians.created_at; uzman değiştiremez, yalnız ad ve unvan yazılabilir) YA DA
  -- davetin kliniği ücretli pakette (plan small/business/custom yönetimden, solo/clinic süresi işleyen mağaza aboneliği;
  -- bu sütunları yalnız sunucu yazar). Kabul edilmiş aile bağı ölçüt DEĞİL: saldırgan kendi ebeveyn hesabıyla kendi davetini
  -- kabul ederek ucuza üretebilir. Ücretsiz deneme (trial) yerleşik sayılmaz.
  pl := case when me.created_at <= now() - interval '7 days'
               or c.plan in ('small', 'business', 'custom')
               or (c.plan in ('solo', 'clinic') and c.period_end > now())
             then 'main' else 'new' end;
  cap := case when pl = 'main' then 200 else 60 end;
  -- Sayım ve kayıt yarışsız: davet satırı kilidi yalnız aynı daveti korur; farklı davetlerden paralel gönderimler sayaçları
  -- aşmasın diye alıcı, uzman ve pay kilitlenir. Sıra sabit (davet satırı → alıcı → uzman → pay; kilitlenme yok). Pay kilidi
  -- her gönderimde alınır (gönderimler sıraya girer, hacim saatte en çok ~260; aşım payı yok).
  perform pg_advisory_xact_lock(hashtext('invite:to'), hashtext(th));
  perform pg_advisory_xact_lock(hashtext('invite:clinician'), hashtext(me.id::text));
  perform pg_advisory_xact_lock(hashtext('invite:pool'), hashtext(pl));
  if (select count(*) from public.invite_email_sends where pool = pl and at > now() - interval '1 hour') >= cap then
    return jsonb_build_object('error', 'rate_global');
  end if;
  if (select count(*) from public.invite_email_sends where to_hash = th and at > now() - interval '24 hours') >= 2
     or (select count(*) from public.invite_email_sends where to_hash = th and at > now() - interval '7 days') >= 4 then
    return jsonb_build_object('error', 'rate_recipient');
  end if;
  if (select count(*) from public.invite_email_sends where clinician_id = me.id and at > now() - interval '24 hours') >= 20
     or (me.created_at > now() - interval '24 hours'
         and (select count(*) from public.invite_email_sends where clinician_id = me.id) >= 5) then
    return jsonb_build_object('error', 'rate_clinician');
  end if;
  insert into public.invite_email_sends (clinician_id, code, to_hash, pool) values (me.id, inv.code, th, pl);
  update public.clinic_invites
     set email_count = email_count + 1, email_sent_at = now(), email_status = 'sending', channel = 'email'
   where code = inv.code;
  -- davetli aile kendi ailesine bağlamadan çocuk önerisi ve uzmanın notu e-postaya girmez
  return jsonb_build_object('code', inv.code, 'token', inv.token, 'expires_at', inv.expires_at, 'to', inv.parent_email,
                            'clinician', me.name, 'title', me.title, 'clinic', c.name, 'independent', c.personal_of is not null);
end $$;
revoke execute on function public.clinic_invite_email_take(text, uuid) from public, anon, authenticated;
grant execute on function public.clinic_invite_email_take(text, uuid) to service_role;

-- Sonuç: gönderilemeyen e-posta sayılmaz (davet hakkı ve gönderim kaydı geri verilir); sonuç bir kez yazılır
create or replace function public.clinic_invite_email_done(p_code text, p_ok boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  c text := upper(trim(coalesce(p_code, '')));
begin
  update public.clinic_invites
     set email_status = case when p_ok then 'sent' else 'failed' end,
         email_count = case when p_ok then email_count else greatest(email_count - 1, 0) end
   where code = c and kind = 'family' and email_status = 'sending';
  if found and not coalesce(p_ok, false) then
    delete from public.invite_email_sends
     where id = (select max(id) from public.invite_email_sends where code = c and at > now() - interval '1 hour');
  end if;
end $$;
revoke execute on function public.clinic_invite_email_done(text, boolean) from public, anon, authenticated;
grant execute on function public.clinic_invite_email_done(text, boolean) to service_role;

-- Bu dosyanın eklediği tablolar da sonsuz tarih korumasını alır (20261121100000'deki yardımcı; önce o dosya çalışmış olmalı).
do $$ begin
  if to_regprocedure('public.finite_time_guard_attach()') is null then
    raise exception 'Önce 20261121100000_security_audit_fixes.sql çalıştırılmalı';
  end if;
  perform public.finite_time_guard_attach();
end $$;
