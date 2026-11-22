-- Destek formu ve davet e-postası sınırları (öneri, 21 Kasım 2026; güvenlik denetimi bulguları
-- support.global-hourly-cap-shared-exhaustion ve invite-email.clinician-text-relay.unverified-signup). Tekrar çalıştırılabilir.
-- Önkoşul: migrations/20261102210000_support.sql, migrations/20261027000000_invite_email.sql, migrations/20261105090000_workspaces.sql.
--
-- 1) Destek (support_request_create): tek kişinin farklı e-postalarla saatlik genel sınırı (60) doldurup formu herkese
--    kapatması engellenir.
--    · Kaynak başına sınır: Edge Function `support` gönderenin adresini p_source ile verir (Worker'dan gelen istekte
--      SUPPORT_FORWARD_KEY eşleşirse Worker'ın ilettiği adres, yoksa işlevin kendi gördüğü adres; secret tanımlı değilse
--      kaynak yok). Adres düz saklanmaz: günlük rastgele tuzla SHA-256 özeti (support_requests.source_hash) ve geniş ağının
--      (IPv4 /24, IPv6 /48) aynı tuzla ikinci özeti (source_wide_hash); tuz 2 gün sonra silinir, iki özet 2 gün sonra
--      boşaltılır. Adres inet ile ayrıştırılır; IPv4'e eşlenmiş IPv6 IPv4 sayılır, öteki IPv6 /64 ağına indirgenir. Sayımda
--      bugünün ve dünün tuzuyla iki özet aranır (gün dönümünde sayaç sıfırlanmaz).
--      Sınır: aynı kaynaktan saatte 5, 24 saatte 15 → {"error":"too_many_source"}.
--    · E-posta başına 24 saatte 3 → too_many. Kaynak biliniyorsa yalnız aynı kaynaktan o adresle açılanlar sayılır (başkası
--      bir kişinin adresini yazarak onun formunu kapatamaz); kaynak yoksa yalnız kaynaksız açılanlar. KVKK (topic 'privacy') muaf.
--    · Genel sınır yalnız son çare: saatte 300 ("istenmeyen" işaretlenenler ve KVKK talepleri sayılmaz) → busy. Dolunca son
--      bir saatte hiç yazmamış ve geniş ağından da (/24, /48) yazılmamış bilinen kaynak yine bir talep açar (sert tavan 600).
--      "Kişisel verilerim (KVKK)" (topic 'privacy') ayrı paydan: saatte 100 KVKK talebi (genel sınır dolsa da kabul); doluyken
--      aynı kuralla ilk kez yazan kaynak bir KVKK talebi açar (sert tavan 200).
--    · Kaynaksız talepler (eski 5 parametreli çağrı, secret ya da adres yok) bu paylara ek olarak kendi küçük ortak kovasında:
--      saatte 30 (KVKK dışı) ve 10 (KVKK), yalnız kaynaksız satırlar sayılır → busy.
--    · Eski 5 parametreli imza durur (kaynak yok sayılır; yayındaki eski işlev çalışmaya devam eder).
-- 2) Davet e-postası (clinic_invite_email_take): mevcut sınırlara (davet başına 3, 60 sn, uzman başına günde 30 davet) ek
--    olarak her gönderim invite_email_sends'e yazılır (alıcı adres yalnız özet olarak; özet NFKC, görünmez karakterler,
--    büyük/küçük harf, tırnaklı yerel kısım, alan adı sonundaki nokta, "+etiket", Gmail'de nokta ve googlemail.com, Proton'da
--    . - _ ve alan adı farkı, Yandex'te alan adı farkı ve . = -, Apple'da me.com / mac.com = icloud.com; Türkçe karakterli
--    (IDN) ya da xn-- alan adı parçası tek parça sayılarak: aynı gelen kutusunun takma adları tek alıcı sayılır):
--    · aynı alıcı adrese (bütün kliniklerden) 24 saatte 3, 7 günde 6 → rate_recipient (bir davetin 3 gönderimi sığar)
--    · uzman başına 24 saatte 20 gönderim; hesabın ilk 24 saatinde 5 → rate_clinician
--    · sistem payı saatte 200 yerleşik hesaplara; yerleşik olmayan (7 günden yeni ve ücretli paketi olmayan klinikte) hesaplar
--      ayrı küçük paydan saatte 60 ve yerleşiklerin payına sayılmaz → rate_global. Yerleşik olmayan hesabın kayan 24 saatteki
--      ilk 2 gönderimi küçük pay dolu diye reddedilmez (paya sayılır; küçük payın sert tavanı saatte 150).
--    · Davet adresi oluşturulurken denetlenir (clinic_invites tetikleyicisi, invite_email_valid): küçük harf, kırpılmış; yerel
--      kısım ASCII (RFC atext, baştaki / sondaki / çift nokta yok), alan adı harf (her alfabe), rakam ve tire parçaları, son
--      parça en az 2 karakter ('E-posta adresi geçersiz'); eski satırlar değiştirilmez.
--    Gönderilemeyen e-posta (clinic_invite_email_done p_ok=false) kayıttan düşer (hak geri verilir). Kayıt 8 gün tutulur;
--    uzman hesabı silinse de satır kalır (uzman bağı boşalır), silip yeniden kaydolmak alıcı sınırını sıfırlamaz.
--    Bütün sayaçlar (destek ve davet) danışma kilitleriyle (pg_advisory_xact_lock) sıraya alınır: paralel istekler aşamaz.

-- =====================================================================
-- 1. Destek
-- =====================================================================
alter table public.support_requests add column if not exists source_hash text;
create index if not exists support_requests_source_idx on public.support_requests (source_hash, created_at) where source_hash is not null;
-- Geniş ağın (IPv4 /24, IPv6 /48) özeti: yalnız "ilk kez yazan kaynak" istisnasında bakılır (tek /48'deki binlerce /64 ya da
-- tek /24'teki adresler payı istisnayla dolduramasın). Aynı tuz, aynı 2 günlük saklama; adres ya da ağ düz yazılmaz.
alter table public.support_requests add column if not exists source_wide_hash text;
create index if not exists support_requests_wide_idx on public.support_requests (source_wide_hash, created_at) where source_wide_hash is not null;
create index if not exists support_requests_nosource_idx on public.support_requests (created_at) where source_hash is null;

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

-- Kaynağın geniş ağı: IPv4 /24, IPv6 /48 (support_source_net'ten türetilir; adres olmayan değer yine 'invalid').
create or replace function public.support_source_wide(p_source text)
returns text language plpgsql immutable set search_path = '' as $$
declare
  n text := public.support_source_net(p_source);
  a inet;
begin
  if n is null or n = 'invalid' then return n; end if;
  a := n::inet;
  return case when family(a) = 6 then host(network(set_masklen(a, 48))) || '/48'
              else host(network(set_masklen(a, 24))) || '/24' end;
end $$;
revoke execute on function public.support_source_wide(text) from public, anon, authenticated;

-- Bir değerin günlük tuzlu özetleri: [bugünün tuzuyla, dünün tuzuyla (varsa)]. Sayımlar ikisine de bakar: gün dönümünde
-- (UTC) sayaç sıfırlanmaz (eskiden tek özet olduğu için gece yarısında aynı kaynak bir saatte 10 talep açabiliyordu).
-- Tuz 2 günden fazla tutulmaz; adres düz yazılmaz.
create or replace function public.support_salted_hashes(p_value text)
returns text[] language plpgsql security definer set search_path = '' as $$
declare
  today date := (now() at time zone 'utc')::date;
  s text;
  y text;
begin
  if p_value is null then return null; end if;
  insert into public.support_source_salts (day, salt) values (today, gen_random_uuid()::text || gen_random_uuid()::text)
    on conflict (day) do nothing;
  delete from public.support_source_salts where day < today - 1;
  select salt into s from public.support_source_salts where day = today;
  select salt into y from public.support_source_salts where day = today - 1;
  return array_remove(array[encode(extensions.digest(s || '|' || p_value, 'sha256'), 'hex'),
                            case when y is not null then encode(extensions.digest(y || '|' || p_value, 'sha256'), 'hex') end], null);
end $$;
revoke execute on function public.support_salted_hashes(text) from public, anon, authenticated;

-- Kaynağın özetleri (adres ya da /64): tuz || '|' || ağ
create or replace function public.support_source_hashes(p_source text)
returns text[] language sql security definer set search_path = '' as $$
  select public.support_salted_hashes(public.support_source_net(p_source))
$$;
revoke execute on function public.support_source_hashes(text) from public, anon, authenticated;

-- Geniş ağın özetleri (/24, /48): tuz || '|wide|' || ağ (kaynak özetiyle karışmaz)
create or replace function public.support_source_wide_hashes(p_source text)
returns text[] language sql security definer set search_path = '' as $$
  select public.support_salted_hashes('wide|' || public.support_source_wide(p_source))
$$;
revoke execute on function public.support_source_wide_hashes(text) from public, anon, authenticated;

-- Adresin bugünkü özeti (kayda yazılan); adres yoksa null.
create or replace function public.support_source_hash(p_source text)
returns text language sql security definer set search_path = '' as $$
  select (public.support_source_hashes(p_source))[1]
$$;
revoke execute on function public.support_source_hash(text) from public, anon, authenticated;

-- Formdan yeni talep (yalnız sunucu: Edge Function `support`).
-- Dönüş: {"ref"} ya da {"error": "invalid" | "too_many" | "too_many_source" | "busy"}.
-- Sıra: kaynak sınırı (5/saat, 15/24 saat) → e-posta sınırı (KVKK hariç) → kaynaksız kova (30/saat, KVKK 10/saat)
-- → pay (KVKK 100, ilk kez yazan kaynağa 200'e kadar; genel 300, ilk kez yazan kaynağa 600'e kadar).
create or replace function public.support_request_create(p_app text, p_topic text, p_email text, p_name text, p_message text,
                                                         p_source text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  em text := lower(trim(coalesce(p_email, '')));
  msg text := trim(coalesce(p_message, ''));
  nm text := left(trim(coalesce(p_name, '')), 80);
  kvkk boolean := p_topic = 'privacy';
  srcs text[];
  wides text[];
  src text;
  pool integer;
  soft integer;
  hard integer;
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
  wides := public.support_source_wide_hashes(p_source);
  src := srcs[1];
  -- Sayım ve kayıt yarışsız: paralel istekler birbirinin henüz işlenmemiş kaydını göremez, bu yüzden her sayaç kilitlenir.
  -- Sıra sabit (kaynak → e-posta → pay; kilitlenme yok). Pay kilidi her talepte alınır: bütün form talepleri sıraya girer
  -- (hacim saatte en çok birkaç yüz; aşım payı yok); kaynaksız kova, KVKK payı ve geniş ağ sayımı da bu kilidin içinde.
  -- Kilit anahtarları bellekte; özetin kendisi ya da adres yazılmaz.
  if src is not null then perform pg_advisory_xact_lock(hashtext('support:src'), hashtext(src)); end if;
  perform pg_advisory_xact_lock(hashtext('support:email'), hashtext(em));
  perform pg_advisory_xact_lock(hashtext('support:pool'), 0);
  -- 2 günden eski özetler boşaltılır (tuzu silindiği için zaten geri çevrilemez; kişisel veri azaltma)
  update public.support_requests set source_hash = null, source_wide_hash = null
   where (source_hash is not null or source_wide_hash is not null) and created_at < now() - interval '2 days';
  if src is not null and (
       (select count(*) from public.support_requests where source_hash = any(srcs) and created_at > now() - interval '1 hour') >= 5
    or (select count(*) from public.support_requests where source_hash = any(srcs) and created_at > now() - interval '24 hours') >= 15) then
    return jsonb_build_object('error', 'too_many_source');
  end if;
  -- E-posta sınırı (24 saatte 3). Adres doğrulanmadığı için başkası da yazabilir: kaynak biliniyorsa yalnız AYNI kaynaktan
  -- bu adresle açılanlar sayılır (bir kaynak başkasının hakkını harcayamaz; "too_many" yalnız kendi gönderdiklerini söyler).
  -- Kaynak yoksa (secret yok ya da eski 5 parametreli çağrı) yalnız kaynaksız açılanlar sayılır: bilinen kaynaklardan bir
  -- kişinin adresiyle açılan talepler onu kaynaksız yolda da kilitlemesin. KVKK (privacy) bu sınırdan muaf: yasal başvuru
  -- yolu üçüncü kişi tarafından kapatılamasın (kaynak sınırı, kaynaksız kova ve KVKK payı sürer).
  if not kvkk and (
       (src is not null and (select count(*) from public.support_requests
                              where lower(email) = em and source_hash = any(srcs) and created_at > now() - interval '24 hours') >= 3)
    or (src is null and (select count(*) from public.support_requests
                          where lower(email) = em and source_hash is null and created_at > now() - interval '24 hours') >= 3)) then
    return jsonb_build_object('error', 'too_many');
  end if;
  -- Kaynaksız kova (paylara ek): kaynaksız yol (Worker'ın anahtarsız isteği artık kendi adresiyle sayılır; kalan: eski imza,
  -- secret ya da adres yok) tek başına bir payı tüketemesin. Yalnız kaynaksız satırlar sayılır; "istenmeyen" sayılmaz.
  if src is null then
    select count(*) into pool from public.support_requests
     where source_hash is null and (topic = 'privacy') = kvkk and status <> 'spam' and created_at > now() - interval '1 hour';
    if pool >= (case when kvkk then 10 else 30 end) then
      return jsonb_build_object('error', 'busy');
    end if;
  end if;
  -- Paylar yalnız son çare: KVKK 100 (genel sınır dolsa da kabul; yasal başvuru yolu kapanmasın), genel 300 ("istenmeyen"
  -- ve KVKK sayılmaz). Dolunca herkes eşit reddedilmez: son bir saatte hiç yazmamış bilinen bir kaynak, geniş ağından
  -- (IPv4 /24, IPv6 /48) da son bir saatte yazılmamışsa, yine bir talep açar (sert tavan KVKK 200, genel 600). Geniş ağ
  -- koşulu tek /48'deki binlerce /64 ya da tek /24 ile istisnanın doldurulmasını önler.
  -- Kalan risk: tavanı doldurmak için yüzlerce ayrı /24 ya da /48 gerekir; tam koruma ancak bir doğrulamayla (Turnstile).
  select count(*) into pool from public.support_requests
   where (topic = 'privacy') = kvkk and status <> 'spam' and created_at > now() - interval '1 hour';
  soft := case when kvkk then 100 else 300 end;
  hard := case when kvkk then 200 else 600 end;
  if pool >= soft and (src is null or pool >= hard
      or exists (select 1 from public.support_requests where source_hash = any(srcs) and created_at > now() - interval '1 hour')
      or exists (select 1 from public.support_requests where source_wide_hash = any(wides) and created_at > now() - interval '1 hour')) then
    return jsonb_build_object('error', 'busy');
  end if;
  loop
    r := 'D-';
    for i in 1..6 loop
      r := r || substr(alphabet, 1 + floor(random() * length(alphabet))::integer, 1);
    end loop;
    exit when not exists (select 1 from public.support_requests where ref = r);
  end loop;
  insert into public.support_requests (ref, app, topic, email, name, message, source_hash, source_wide_hash)
  values (r, p_app, p_topic, em, nm, msg, src, case when src is not null then wides[1] end);
  return jsonb_build_object('ref', r);
end $$;
revoke execute on function public.support_request_create(text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.support_request_create(text, text, text, text, text, text) to service_role;

-- Eski imza (yayındaki eski Edge Function): kaynak yok; e-posta sınırı (kaynaksız talepler), kaynaksız kova ve paylar
create or replace function public.support_request_create(p_app text, p_topic text, p_email text, p_name text, p_message text)
returns jsonb language sql security definer set search_path = '' as $$
  select public.support_request_create(p_app, p_topic, p_email, p_name, p_message, null::text)
$$;
revoke execute on function public.support_request_create(text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.support_request_create(text, text, text, text, text) to service_role;

-- Panel kuyruğu: kaynak özetleri panele gitmez (aynı kaynaktan gelen talepleri 2 gün boyunca birbirine bağlamaya yarardı;
-- panelde kullanılmıyor). Gövde migrations/20261102210000_support.sql ile aynı, yalnız iki özet çıkarılır.
create or replace function public.admin_support_requests(p_status text default 'open', p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require(array['support']);
  return coalesce((
    select jsonb_agg(to_jsonb(s) - 'handled_by' - 'source_hash' - 'source_wide_hash'
                     order by case when p_status = 'open' then s.created_at end asc, s.created_at desc)
      from (select * from public.support_requests
             where case when coalesce(p_status, 'open') = 'open' then status in ('new', 'in_progress')
                        when p_status = 'all' then true else status = p_status end
             order by created_at desc limit greatest(1, least(coalesce(p_limit, 100), 500))) s), '[]'::jsonb);
end $$;
revoke execute on function public.admin_support_requests(text, integer) from public, anon;
grant execute on function public.admin_support_requests(text, integer) to authenticated;

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

-- Alıcı sınırının anahtarı: aynı gelen kutusuna giden takma adlar tek alıcı. Önce NFKC (tam genişlikli harf, "․" gibi
-- benzer noktalar), görünmez ve biçim karakterleri (Unicode Cf: yumuşak tire, sıfır genişlikli, yön işaretleri, BOM …;
-- birleştirici ve değişim seçicileri, Hangul dolgu harfleri) ve bölünmez boşluklar atılır, küçük harf, bütün boşluklar
-- atılır. Tam bir "@" varsa: yerel kısmı saran çift tırnak ve alan adı sonundaki noktalar atılır, "+etiket" (her alan adında)
-- atılır; gmail.com / googlemail.com'da noktalar atılır ve googlemail.com → gmail.com; proton.me / protonmail.com /
-- protonmail.ch / pm.me'de . - _ atılır ve alan adı proton.me; yandex.ru / yandex.com / yandex.com.tr / yandex.ua /
-- yandex.by / yandex.kz / ya.ru'da "." "-" olur (Yandex ikisini aynı sayar) ve alan adı yandex.ru; me.com / mac.com →
-- icloud.com. ASCII olmayan karakter içeren ya da xn-- ile başlayan alan adı parçası "*" olur (ali@şirket.com.tr,
-- ali@ŞİRKET.com.tr ve ali@xn--irket-ova.com.tr tek alıcı; veritabanının yerel ayarına ve Punycode'a bağlı değil; başka
-- IDN alan adlarındaki aynı yerel kısım da aynı alıcı sayılır, yalnız sıkılaştırır). Kalan: Fastmail alt alan adı adreslemesi
-- (x@kullanici.fastmail.com) birleşmez. Anahtar yalnız sayım içindir (gönderim davetteki adresle); fazladan birleştirme
-- sınırı yalnız sıkılaştırır. Saklanan yalnız bu anahtarın özetidir (invite_email_to_hash). Eski anahtarla yazılmış satırlar
-- (canlıda yok) dönüştürülmez.
create or replace function public.invite_email_key(p_email text)
returns text language sql immutable set search_path = '' as $$
  with e as (select regexp_replace(lower(regexp_replace(normalize(coalesce(p_email, ''), NFKC),
                      '[ ­͏؀-؅؜۝܏࢐࢑࣢ᅟᅠ᠋-᠏ '
                      '​-‏ - ⁠-⁤⁦-⁯ㅤ︀-️﻿ﾠ￹-￻'
                      '\U000110BD\U000110CD\U00013430-\U0001343F\U0001BCA0-\U0001BCA3\U0001D173-\U0001D17A'
                      '\U000E0001\U000E0020-\U000E007F\U000E0100-\U000E01EF]', '', 'g')),
                    '[[:space:]]', '', 'g') as v),
       p as (select v,
                    case when char_length(v) - char_length(replace(v, '@', '')) = 1 then split_part(v, '@', 1) end as l0,
                    rtrim(split_part(v, '@', 2), '.') as d
               from e),
       q as (select v, d, case when l0 ~ '^".*"$' and char_length(l0) >= 2 then substr(l0, 2, char_length(l0) - 2) else l0 end as l
               from p),
       r as (select v, d, l, coalesce(nullif(split_part(l, '+', 1), ''), l) as base,
                    -- IDN parçası (ASCII olmayan ya da xn--) "*": Unicode / Punycode / büyük harf yazımları birleşir
                    coalesce((select string_agg(case when octet_length(x) <> char_length(x) or x like 'xn--%' then '*' else x end,
                                                '.' order by n)
                                from unnest(string_to_array(d, '.')) with ordinality t(x, n)), d) as dk
               from q)
  select case when l is null then v
              when d in ('gmail.com', 'googlemail.com') then coalesce(nullif(replace(base, '.', ''), ''), base) || '@gmail.com'
              when d in ('proton.me', 'protonmail.com', 'protonmail.ch', 'pm.me')
                then coalesce(nullif(regexp_replace(base, '[._-]', '', 'g'), ''), base) || '@proton.me'
              when d in ('yandex.ru', 'yandex.com', 'yandex.com.tr', 'yandex.ua', 'yandex.by', 'yandex.kz', 'ya.ru')
                then replace(base, '.', '-') || '@yandex.ru'
              when d in ('icloud.com', 'me.com', 'mac.com') then base || '@icloud.com'
              else base || '@' || dk end
    from r
$$;
revoke execute on function public.invite_email_key(text) from public, anon, authenticated;

create or replace function public.invite_email_to_hash(p_email text)
returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest('invite|' || public.invite_email_key(p_email), 'sha256'), 'hex')
$$;
revoke execute on function public.invite_email_to_hash(text) from public, anon, authenticated;

-- Davet adresinin biçimi (tetikleyici çağırır; adres önce kırpılır, küçük harfe ve NFC'ye çevrilir):
--   · yerel kısım: ASCII harf, rakam ve RFC 5322 atext işaretleri  . ! # $ % & ' * + / = ? ^ _ ` { | } ~ -  (baştaki,
--     sondaki ve art arda nokta yok; ASCII olmayan yerel kısım bilerek reddedilir);
--   · alan adı: noktayla ayrılmış parçalar; parça ASCII harf, rakam, tire ya da ASCII olmayan harf (her alfabe:
--     ali@şirket.com.tr); son parça en az 2 karakter; sonda nokta yok;
--   · her yerde reddedilen: boşluk (her tür), tırnak, köşeli ayraç, , ; : < > \ ( ), görünmez ve biçim karakterleri
--     (Unicode Cf, bölünmez boşluk, dolgu harfleri, değişim seçicileri), denetim karakterleri, 。 ． ｡ (IDN'de nokta sayılır)
--     ve NFKC'ye göre değişen her karakter (tam genişlikli harf, ․ ﹒ gibi benzer noktalar).
--   Yerel ayara bağlı değil ([[:alpha:]] C yerel ayarında ASCII dışını tanımaz): ASCII dışı karakterler yasak listesi dışında
--   kabul edilir (karakter aralıkları kod noktasına göre). Alıcı sınırı ayrıca invite_email_key'de (IDN parçaları tek parça).
create or replace function public.invite_email_valid(p_email text)
returns boolean language sql immutable set search_path = '' as $f$
  -- L = alan adı parçasının bir karakteri: ASCII harf / rakam / tire ya da yasak listesinde olmayan ASCII dışı karakter
  with c as (select '([a-z0-9-]|[^\u0001-\u00a0\u00ad\u034f\u0600-\u0605\u061c\u06dd\u070f\u0890\u0891\u08e2\u115f\u1160\u1680'
                    '\u180b-\u180f\u2000-\u200f\u2028-\u202f\u205f-\u206f\u3000\u3002\u3164\ufe00-\ufe0f\ufeff\uff0e\uff61\uffa0'
                    '\ufff9-\ufffb\U000110bd\U000110cd\U00013430-\U0001343f\U0001bca0-\U0001bca3\U0001d173-\U0001d17a'
                    '\U000e0001\U000e0020-\U000e007f\U000e0100-\U000e01ef])' as l)
  select coalesce(p_email is nfkc normalized
                  and p_email ~ replace('^[a-z0-9!#$%&''*+/=?^_`{|}~-]+(\.[a-z0-9!#$%&''*+/=?^_`{|}~-]+)*@L+(\.L+)*\.L{2,}$', 'L', l),
                  false)
    from c
$f$;
revoke execute on function public.invite_email_valid(text) from public, anon, authenticated;

-- Davet adresi oluşturulurken denetlenir: kırpılır, küçük harfe ve NFC'ye çevrilir, biçimi invite_email_valid denetler
-- (tırnaklı yerel kısım, alan adı sonunda nokta, görünmez karakter, bölünmez boşluk, birden çok adres, tam genişlikli harf
-- reddedilir; bunlar alıcı sınırını aşmanın yoluydu). Hata metni clinic_create_invite'ınkiyle aynı (ClinicApp metni olduğu
-- gibi gösterir). Yalnız yeni ya da değişen adres denetlenir: eski satırlar değiştirilmez (adresin boşaltılması, ör. KVKK
-- işlemi, serbest).
create or replace function public.clinic_invites_email_check()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.parent_email is not null and (tg_op = 'INSERT' or new.parent_email is distinct from old.parent_email) then
    new.parent_email := normalize(lower(btrim(new.parent_email, E' \t\r\n ﻿')), NFC);
    if not public.invite_email_valid(new.parent_email) then
      raise exception 'E-posta adresi geçersiz';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.clinic_invites_email_check() from public, anon, authenticated;
drop trigger if exists clinic_invites_email_check on public.clinic_invites;
create trigger clinic_invites_email_check before insert or update of parent_email on public.clinic_invites
  for each row execute function public.clinic_invites_email_check();

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
  used integer;
  mine integer;
  mine_day integer;
  fresh boolean;
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
  fresh := me.created_at > now() - interval '24 hours';
  -- Sayım ve kayıt yarışsız: davet satırı kilidi yalnız aynı daveti korur; farklı davetlerden paralel gönderimler sayaçları
  -- aşmasın diye alıcı, uzman ve pay kilitlenir. Sıra sabit (davet satırı → alıcı → uzman → pay; kilitlenme yok). Pay kilidi
  -- her gönderimde alınır (gönderimler sıraya girer, hacim saatte en çok ~350; aşım payı yok). Bütün sayımlar pay kilidinden sonra.
  perform pg_advisory_xact_lock(hashtext('invite:to'), hashtext(th));
  perform pg_advisory_xact_lock(hashtext('invite:clinician'), hashtext(me.id::text));
  perform pg_advisory_xact_lock(hashtext('invite:pool'), hashtext(pl));
  select count(*) into used from public.invite_email_sends where pool = pl and at > now() - interval '1 hour';
  select count(*) into mine from public.invite_email_sends where clinician_id = me.id;
  select count(*) into mine_day from public.invite_email_sends where clinician_id = me.id and at > now() - interval '24 hours';
  -- Yeni hesap payı (60) birkaç kendi açılmış hesapla doldurulabilir: yerleşik olmayan hesabın (deneme süresindeki gerçek
  -- uzman da: 1.–7. gün) kayan 24 saatteki ilk 2 gönderimi pay dolu diye reddedilmez (gerçek yeni uzman her gün davetini
  -- gönderebilsin); paya sayılır, sert tavan saatte 150. Sonrası olağan 60. Hesap başına sınırlar (ilk 24 saatte 5, sonra
  -- 24 saatte 20) aşağıda, değişmedi.
  if used >= cap and not (pl = 'new' and mine_day < 2 and used < 150) then
    return jsonb_build_object('error', 'rate_global');
  end if;
  -- Alıcı: 24 saatte 3 (bir davet en çok 3 kez gönderilir, hepsi sığar), 7 günde 6
  if (select count(*) from public.invite_email_sends where to_hash = th and at > now() - interval '24 hours') >= 3
     or (select count(*) from public.invite_email_sends where to_hash = th and at > now() - interval '7 days') >= 6 then
    return jsonb_build_object('error', 'rate_recipient');
  end if;
  if mine_day >= 20 or (fresh and mine >= 5) then
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
