-- Destek formu kaynak sınırı ve davet e-postası gönderim sınırları (migrations/20261121110000_support_invite_limits.sql)
\set ON_ERROR_STOP on
create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
create or replace function tst.fails(sql text, msg text) returns void language plpgsql as $$
begin
  begin execute sql; exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return; end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
create or replace function tst.sr(e text, src text, topic text default 'bug') returns jsonb language sql as $$
  select public.support_request_create('parent', topic, e, '', 'Uygulama açılmıyor, yardım lütfen', src) $$;
create or replace function tst.take(c text, u text) returns jsonb language sql as $$
  select public.clinic_invite_email_take(c, u::uuid) $$;
-- hata metni (hata yoksa null)
create or replace function tst.err(sql text) returns text language plpgsql as $$
begin
  begin execute sql; exception when others then return sqlerrm; end;
  return null;
end $$;
create or replace function tst.ok(r jsonb) returns integer language sql as $$ select case when r ? 'ref' or r ? 'to' then 1 else 0 end $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- =====================================================================
-- 1. Destek
-- =====================================================================
-- yetki ve RLS
set role anon;
select tst.fails($$select public.support_request_create('parent', 'bug', 'a@b.co', '', 'Uygulama açılmıyor lütfen', '1.2.3.4')$$, 'anon 6 parametreli işlevi çağıramaz');
select tst.fails($$select public.support_source_hash('1.2.3.4')$$, 'anon özet işlevini çağıramaz');
select tst.fails($$select public.support_source_wide_hashes('1.2.3.4')$$, 'anon geniş ağ özetini çağıramaz');
select tst.fails($$select public.support_salted_hashes('x')$$, 'anon tuzlu özet işlevini çağıramaz');
select tst.fails($$select count(*) from public.support_source_salts$$, 'anon tuzu okuyamaz');
reset role;
set role authenticated;
select tst.fails($$select public.support_request_create('parent', 'bug', 'a@b.co', '', 'Uygulama açılmıyor lütfen', '1.2.3.4')$$, 'kullanıcı doğrudan talep açamaz');
select tst.fails($$select count(*) from public.support_source_salts$$, 'kullanıcı tuzu okuyamaz');
select tst.fails($$select count(*) from public.invite_email_sends$$, 'kullanıcı gönderim kaydını okuyamaz');
select tst.fails($$select public.support_source_wide_hashes('1.2.3.4')$$, 'kullanıcı geniş ağ özetini çağıramaz');
select tst.fails($$select public.clinic_invites_email_check()$$, 'kullanıcı tetikleyici işlevini çağıramaz');
reset role;
select tst.check((select relrowsecurity from pg_class where oid = 'public.support_source_salts'::regclass), 'tuz tablosunda RLS');
select tst.check((select relrowsecurity from pg_class where oid = 'public.invite_email_sends'::regclass), 'gönderim kaydında RLS');

set role service_role;
-- adres düz saklanmaz; IPv6 /64 tek kaynak
select tst.check(tst.sr('k1@example.com', '203.0.113.7') ? 'ref', 'kaynaklı talep');
reset role;
select tst.check((select source_hash ~ '^[0-9a-f]{64}$' and source_hash <> '203.0.113.7' from public.support_requests where email = 'k1@example.com'), 'kaynak özet olarak saklanır');
select tst.check(not exists (select 1 from public.support_requests where support_requests::text like '%203.0.113.%'), 'adres ve ağ düz yazılmaz');
select tst.check((select source_wide_hash ~ '^[0-9a-f]{64}$' and source_wide_hash <> source_hash from public.support_requests where email = 'k1@example.com'),
                 'geniş ağ ayrı özet olarak saklanır');
-- geniş ağ: IPv4 /24, IPv6 /48 (eşlenmiş IPv6 IPv4 sayılır); adres olmayan değer tek ortak kova
select tst.check(public.support_source_wide('203.0.113.7') = '203.0.113.0/24' and public.support_source_wide('::ffff:203.0.113.7') = '203.0.113.0/24'
                 and public.support_source_wide('2001:DB8:1:2::7') = '2001:db8:1::/48' and public.support_source_wide('<script>') = 'invalid'
                 and public.support_source_wide(null) is null, 'geniş ağ /24 ve /48');
select tst.check((public.support_source_wide_hashes('192.0.2.1'))[1] = (public.support_source_wide_hashes('192.0.2.250'))[1]
                 and (public.support_source_wide_hashes('192.0.2.1'))[1] <> (public.support_source_wide_hashes('192.0.3.1'))[1]
                 and (public.support_source_wide_hashes('2001:db8:1:2::1'))[1] = (public.support_source_wide_hashes('2001:db8:1:ffff::1'))[1]
                 and (public.support_source_wide_hashes('2001:db8:1:2::1'))[1] <> (public.support_source_wide_hashes('2001:db8:2:2::1'))[1],
                 'aynı /24 ve /48 tek geniş ağ, komşusu ayrı');
select tst.check((public.support_source_wide_hashes('203.0.113.7'))[1] <> public.support_source_hash('203.0.113.7'), 'geniş ağ özeti kaynak özetiyle karışmaz');
select tst.check(public.support_source_hash('2001:db8:1:2::1') = public.support_source_hash('2001:db8:1:2:ffff::9'), 'IPv6 aynı /64 ağı tek kaynak');
select tst.check(public.support_source_hash('2001:db8:1:2::1') <> public.support_source_hash('2001:db8:1:3::1'), 'başka /64 ayrı kaynak');
select tst.check(public.support_source_hash('') is null and public.support_source_hash(null) is null, 'adres yoksa özet yok');
-- IPv4'e eşlenmiş IPv6 IPv4 sayılır (hepsi tek /64 kovasına düşmez); adres gerçek ayrıştırıcıyla denetlenir
select tst.check(public.support_source_hash('::ffff:203.0.113.7') = public.support_source_hash('203.0.113.7'), 'eşlenmiş IPv6 = IPv4');
select tst.check(public.support_source_hash('::ffff:203.0.113.7') <> public.support_source_hash('::ffff:198.51.100.9'), 'eşlenmiş iki IPv4 ayrı kaynak');
select tst.check(public.support_source_net('::FFFF:1.2.3.4') = '1.2.3.4' and public.support_source_net('1.2.3.4/8') = '1.2.3.4', 'eşlenmiş adres ve maske ayıklanır');
select tst.check(public.support_source_net('2001:DB8:1:2::7') = '2001:db8:1:2::/64', 'IPv6 /64 ağı');
select tst.check(public.support_source_hash('unknown') = public.support_source_hash('<script>') and public.support_source_hash('unknown') = public.support_source_hash('1.2.3.999'),
                 'adres biçiminde olmayan her değer tek ortak kova (değiştirerek sınır aşılmaz)');

-- tek kaynaktan sel: saatte 5; başka kaynak etkilenmez
set role service_role;
select tst.sr('k' || g || '@example.com', '203.0.113.7') from generate_series(2, 5) g;
select tst.check(tst.sr('k6@example.com', '203.0.113.7') ->> 'error' = 'too_many_source', 'aynı kaynaktan saatte 5');
select tst.check(tst.sr('k7@example.com', '198.51.100.9') ? 'ref', 'başka kaynak etkilenmez');
reset role;
-- günde 15: saatlik pencere dışına itilmiş 14 kayıt + 1
update public.support_requests set created_at = now() - interval '2 hours' where email like 'k%@example.com' and email <> 'k7@example.com';
insert into public.support_requests (ref, app, topic, email, message, created_at, source_hash)
select 'D-G' || lpad(g::text, 5, '0'), 'other', 'other', 'gun' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '3 hours',
       public.support_source_hash('203.0.113.7')
  from generate_series(1, 9) g;
set role service_role;
select tst.check(tst.sr('g15@example.com', '203.0.113.7') ? 'ref', 'günün 15. talebi');
select tst.check(tst.sr('g16@example.com', '203.0.113.7') ->> 'error' = 'too_many_source', 'aynı kaynaktan günde 15');
reset role;
delete from public.support_requests;

-- gün dönümü: dünün tuzuyla yazılmış özetler de sayılır (gece yarısında sayaç sıfırlanmaz)
insert into public.support_source_salts (day, salt) values ((now() at time zone 'utc')::date - 1, 'dun-tuzu-deneme')
  on conflict (day) do update set salt = excluded.salt;
insert into public.support_requests (ref, app, topic, email, message, created_at, source_hash)
select 'D-Y' || lpad(g::text, 5, '0'), 'other', 'other', 'dun' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '20 minutes',
       encode(extensions.digest('dun-tuzu-deneme|203.0.113.50', 'sha256'), 'hex')
  from generate_series(1, 5) g;
select tst.check(public.support_source_hash('203.0.113.50') <> encode(extensions.digest('dun-tuzu-deneme|203.0.113.50', 'sha256'), 'hex'), 'bugünün tuzu farklı');
select tst.check((public.support_source_wide_hashes('203.0.113.50'))[2] = encode(extensions.digest('dun-tuzu-deneme|wide|203.0.113.0/24', 'sha256'), 'hex'),
                 'geniş ağ özeti de dünün tuzuyla aranır');
set role service_role;
select tst.check(tst.sr('dun6@example.com', '::ffff:203.0.113.50') ->> 'error' = 'too_many_source', 'dünün tuzuyla sayılan 5 talep + 1 → kaynak sınırı (eşlenmiş adresle de)');
select tst.check(tst.sr('dun7@example.com', '203.0.113.51') ? 'ref', 'komşu adres etkilenmez');
reset role;
select tst.check(exists (select 1 from public.support_source_salts where day = (now() at time zone 'utc')::date - 1)
                 and not exists (select 1 from public.support_source_salts where day < (now() at time zone 'utc')::date - 1), 'tuz en çok 2 gün');
delete from public.support_requests;

-- hedefli kilit: başkası bir kişinin adresiyle 3 talep açsa da o kişi kendi bağlantısından yazabilir; KVKK e-posta sınırından muaf
set role service_role;
select tst.check(tst.sr('Kurban@Example.org', '192.0.2.201') ? 'ref', 'saldırgan 1');
select tst.check(tst.sr(' kurban@example.org ', '192.0.2.201', 'account') ? 'ref', 'saldırgan 2');
select tst.check(tst.sr('kurban@example.org', '192.0.2.201', 'other') ? 'ref', 'saldırgan 3');
select tst.check(tst.sr('kurban@example.org', '192.0.2.201') ->> 'error' = 'too_many', 'aynı kaynaktan aynı adrese 24 saatte 3');
select tst.check(tst.sr('kurban@example.org', '198.51.100.77', 'privacy') ? 'ref', 'kurbanın KVKK talebi kabul');
select tst.check(tst.sr('kurban@example.org', '198.51.100.77', 'account') ? 'ref', 'kurbanın normal talebi kabul (başka kaynak)');
select tst.check(tst.sr('kurban@example.org', '192.0.2.201', 'privacy') ? 'ref', 'KVKK e-posta sınırından muaf (kaynak sınırı sürer)');
select tst.check(tst.sr('kurban@example.org', '192.0.2.201', 'privacy') ? 'ref', 'kaynağın 5. talebi');
select tst.check(tst.sr('kurban@example.org', '192.0.2.201', 'privacy') ->> 'error' = 'too_many_source', 'KVKK kaynak sınırında');
reset role;
delete from public.support_requests;
-- kaynak bilinmiyorsa (eski imza) adres başına sınır sürer
set role service_role;
select public.support_request_create('parent', 'bug', 'yalin@example.com', '', 'Eski işlevden gelen talep ' || g) from generate_series(1, 3) g;
select tst.check(tst.sr('yalin@example.com', null) ->> 'error' = 'too_many', 'kaynaksız: e-posta başına 3');
select tst.check(tst.sr('yalin@example.com', null, 'privacy') ? 'ref', 'kaynaksız da KVKK muaf');
reset role;
delete from public.support_requests;

-- B2: kaynaksız yolda e-posta sınırı yalnız kaynaksız talepleri sayar; saldırganın bilinen kaynaklardan kurbanın adresiyle
-- açtığı talepler kurbanı kaynaksız yolda (eski işlev, secret yok) kilitlemez
set role service_role;
select tst.check(tst.sr('kurban2@example.org', '192.0.2.9', 'other') ? 'ref' and tst.sr('kurban2@example.org', '192.0.2.10', 'bug') ? 'ref'
                 and tst.sr('Kurban2@example.org', '198.51.100.9', 'account') ? 'ref', 'saldırgan 3 bilinen kaynaktan kurbanın adresiyle');
select tst.check(tst.sr('kurban2@example.org', null) ? 'ref', 'kaynaksız kurban kilitlenmez (B2)');
select tst.check(public.support_request_create('parent', 'bug', 'kurban2@example.org', '', 'Eski işlevden kurbanın talebi') ? 'ref', 'eski imzayla kurban kilitlenmez (B2)');
select tst.check(public.support_request_create('parent', 'bug', 'kurban2@example.org', '', 'Eski işlevden kurbanın talebi 3') ? 'ref', 'kaynaksız 3. talep');
select tst.check(tst.sr('kurban2@example.org', null) ->> 'error' = 'too_many', 'kaynaksız yolda e-posta başına 3 sürer');
reset role;
delete from public.support_requests;

-- B1/B2: kaynaksız kova (paylara ek): kaynaksız yol tek başına payı tüketemez (saatte 30, KVKK 10; yalnız kaynaksız satırlar)
set role service_role;
insert into tst.kv select 'nosrc', sum(tst.ok(tst.sr('n' || g || '@example.com', null)))::text from generate_series(1, 400) g;
select tst.check(tst.v('nosrc') = '30', 'kaynaksız 400 talepten 30''u girer (yeniden test 2a: önce 300)');
select tst.check(public.support_request_create('parent', 'bug', 'eski-yol@example.com', '', 'Eski işlevden gelen talep') ->> 'error' = 'busy', 'eski imza da kaynaksız kovada');
select tst.check(tst.sr('legit1@example.com', '203.0.113.10') ? 'ref', 'kaynaksız kova doluyken bilinen kaynak yazar');
insert into tst.kv select 'nosrc_kvkk', sum(tst.ok(tst.sr('kvkk-bot@example.com', null, 'privacy')))::text from generate_series(1, 150) g;
select tst.check(tst.v('nosrc_kvkk') = '10', 'kaynaksız 150 KVKK talebinden (tek e-posta) 10''u girer (yeniden test 2a: önce 100)');
select tst.check(tst.sr('gercek@example.com', '203.0.113.11', 'privacy') ? 'ref', 'kaynaksız sel sonrası gerçek KVKK talebi kabul');
reset role;
-- istenmeyen işaretlenen kaynaksız talepler kovaya sayılmaz
update public.support_requests set status = 'spam' where source_hash is null and topic <> 'privacy';
set role service_role;
select tst.check(tst.sr('n-yeni@example.com', null) ? 'ref', 'istenmeyen işaretlenince kaynaksız kova boşalır');
reset role;
delete from public.support_requests;
-- kova paylara ektir: genel pay doluysa kaynaksız talep kova boşken de reddedilir
insert into public.support_requests (ref, app, topic, email, message, created_at, source_hash)
select 'D-K' || lpad(g::text, 5, '0'), 'other', 'other', 'kay' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes', md5(g::text)
  from generate_series(1, 300) g;
set role service_role;
select tst.check(tst.sr('ek@example.com', null) ->> 'error' = 'busy', 'genel pay doluyken kaynaksız talep (kova boş) reddedilir');
reset role;
delete from public.support_requests;

-- 60 farklı e-posta tek kaynaktan: yalnız ilk 5'i girer, öteki kaynaklar ve genel sınır etkilenmez
set role service_role;
insert into tst.kv select 'flood', count(*) filter (where r ? 'ref')::text
  from (select tst.sr('sel' || g || '@example.com', '192.0.2.66') r from generate_series(1, 60) g) x;
select tst.check(tst.v('flood') = '5', '60 e-postalık selden 5 talep');
select tst.check(tst.sr('baska@example.com', '192.0.2.77') ? 'ref', 'selden sonra başka kişi talep açar');
reset role;
delete from public.support_requests;

-- genel sınır: 300 (istenmeyen sayılmaz); KVKK ayrı paydan
insert into public.support_requests (ref, app, topic, email, message, created_at, status)
select 'D-S' || lpad(g::text, 5, '0'), 'other', 'other', 'spam' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes', 'spam'
  from generate_series(1, 400) g;
set role service_role;
select tst.check(tst.sr('a1@example.com', '192.0.2.1') ? 'ref', 'istenmeyen işaretlenenler genel sınıra sayılmaz');
reset role;
insert into public.support_requests (ref, app, topic, email, message, created_at)
select 'D-T' || lpad(g::text, 5, '0'), 'other', 'other', 'top' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes'
  from generate_series(1, 300) g;
set role service_role;
select tst.check(public.support_request_create('parent', 'bug', 'a2@example.com', '', 'Kaynaksız talep burada') ->> 'error' = 'busy', 'genel sınır 300 (son çare): kaynaksız reddedilir');
select tst.check(tst.sr('a2@example.com', '192.0.2.1') ->> 'error' = 'busy', 'pay doluyken son saatte yazmış kaynak reddedilir');
-- (önceki sürümde burada 192.0.2.2 kabul ediliyordu; B4: aynı /24'ten yazılmış olduğu için artık istisna yok)
select tst.check(tst.sr('ilk@example.com', '192.0.2.2') ->> 'error' = 'busy', 'pay doluyken aynı /24''ten ilk kez yazan reddedilir (geniş ağ)');
select tst.check(tst.sr('ilk@example.com', '198.51.100.2') ? 'ref', 'pay doluyken başka ağdan ilk kez yazan kaynak bir talep açar');
select tst.check(tst.sr('ilk2@example.com', '198.51.100.2') ->> 'error' = 'busy', 'ilk kez yazanın ikinci talebi reddedilir');
select tst.check(tst.sr('a3@example.com', '192.0.2.3', 'privacy') ? 'ref', 'KVKK talebi genel sınır dolsa da kabul');
reset role;
-- sert tavan 600: saldırgan yeni kaynaklarla da sınırsız giremez
insert into public.support_requests (ref, app, topic, email, message, created_at)
select 'D-U' || lpad(g::text, 5, '0'), 'other', 'other', 'tav' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes'
  from generate_series(1, 298) g;
set role service_role;
select tst.check(tst.sr('son@example.com', '203.0.113.40') ->> 'error' = 'busy', 'saatte 600 sert tavan (başka ağdan ilk kez yazana da)');
reset role;
insert into public.support_requests (ref, app, topic, email, message, created_at)
select 'D-P' || lpad(g::text, 5, '0'), 'other', 'privacy', 'kvkk' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes'
  from generate_series(1, 99) g;
set role service_role;
select tst.check(tst.sr('a4@example.com', '192.0.2.3', 'privacy') ->> 'error' = 'busy', 'KVKK payı saatte 100: son saatte yazmış kaynak reddedilir');
select tst.check(tst.sr('a4@example.com', '192.0.2.4', 'privacy') ->> 'error' = 'busy', 'KVKK payı doluyken aynı /24''ten ilk kez yazan reddedilir');
-- B3: KVKK payı doluyken başka ağdan ilk kez yazan kaynak bir KVKK talebi açar; sert tavan 200
select tst.check(tst.sr('a5@example.com', '203.0.113.41', 'privacy') ? 'ref', 'KVKK payı doluyken ilk kez yazan kaynak bir KVKK talebi açar (B3)');
select tst.check(tst.sr('a5@example.com', '203.0.113.41', 'privacy') ->> 'error' = 'busy', 'ilk kez yazanın ikinci KVKK talebi reddedilir');
reset role;
insert into public.support_requests (ref, app, topic, email, message, created_at)
select 'D-R' || lpad(g::text, 5, '0'), 'other', 'privacy', 'kvkk2-' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '5 minutes'
  from generate_series(1, 98) g;
set role service_role;
select tst.check(tst.sr('a6@example.com', '233.252.0.1', 'privacy') ? 'ref', 'KVKK 200. talep (ilk kez yazan)');
select tst.check(tst.sr('a7@example.com', '233.252.1.1', 'privacy') ->> 'error' = 'busy', 'KVKK sert tavan saatte 200');
reset role;
select tst.check((select count(*) from public.support_requests where topic = 'privacy') = 200, 'KVKK toplamı 200');
delete from public.support_requests;

-- B4: tek /48'deki çok sayıda /64 "ilk kez yazan" istisnasıyla genel payı dolduramaz (yeniden test 2b/2d)
set role service_role;
insert into tst.kv select 'v6fill', sum(tst.ok(tst.sr('v' || g || '-' || k || '@example.com', '2001:db8:0:' || to_hex(g) || '::1')))::text
  from generate_series(1, 60) g, generate_series(1, 5) k;
select tst.check(tst.v('v6fill') = '300', 'tek /48''de 60 /64 × 5 = 300 (kaynak sınırları değişmedi)');
insert into tst.kv select 'v6fresh', sum(tst.ok(tst.sr('f' || g || '@example.com', '2001:db8:0:' || to_hex(1000 + g) || '::1')))::text
  from generate_series(1, 300) g;
select tst.check(tst.v('v6fresh') = '0', 'aynı /48''deki 300 yeni /64''ten hiçbiri istisnayla giremez (önce 300)');
insert into tst.kv select 'v4fresh', sum(tst.ok(tst.sr('f4-' || g || '@example.com', '10.1.0.' || g)))::text from generate_series(1, 5) g;
select tst.check(tst.v('v4fresh') = '1', 'aynı /24''ten yalnız ilk yeni adres istisnayla girer');
select tst.check(tst.sr('legit2@example.com', '2a02:ff0:1:2::5') ? 'ref', 'saldırıdan sonra başka /48''den normal talep kabul');
select tst.check(tst.sr('legit3@example.com', '198.18.0.7') ? 'ref', 'saldırıdan sonra başka /24''ten normal talep kabul');
-- aynı /48'den KVKK payı da doldurulur; yeni /64'ler istisnayla giremez, başka ağdan gerçek KVKK talebi girer
insert into tst.kv select 'v6kvkk', sum(tst.ok(tst.sr('kv' || g || '@example.com', '2001:db8:0:' || to_hex(2000 + g) || '::1', 'privacy')))::text
  from generate_series(1, 20) g, generate_series(1, 5) k;
select tst.check(tst.v('v6kvkk') = '100', 'tek /48''den KVKK payı 100');
insert into tst.kv select 'v6kvkk2', sum(tst.ok(tst.sr('kv2-' || g || '@example.com', '2001:db8:0:' || to_hex(3000 + g) || '::1', 'privacy')))::text
  from generate_series(1, 100) g;
select tst.check(tst.v('v6kvkk2') = '0', 'aynı /48''deki 100 yeni /64''ten hiçbiri KVKK istisnasıyla giremez');
select tst.check(tst.sr('legit-kvkk@example.com', '2a02:ff0:9:1::5', 'privacy') ? 'ref', 'tek /48''den iki pay dolsa da başka ağdan KVKK talebi kabul');
select tst.check(tst.sr('legit4@example.com', '2a02:ff0:9:1::5', 'account') ->> 'error' = 'busy', 'aynı kaynağın ikinci (genel) talebi istisna dışında');
select tst.check(tst.sr('legit5@example.com', '203.0.113.99', 'account') ? 'ref', 'başka ağdan normal talep yine kabul');
reset role;
delete from public.support_requests;
-- B3+B4: KVKK payı tek ağdan doldurulsa da gerçek KVKK talebi girer (yeniden test 2c)
set role service_role;
insert into tst.kv select 'k4fill', sum(tst.ok(tst.sr('k@example.com', '10.2.0.' || g, 'privacy')))::text from generate_series(1, 20) g, generate_series(1, 5) k;
select tst.check(tst.v('k4fill') = '100', '20 kaynak × 5 KVKK = 100 (tek /24)');
insert into tst.kv select 'k6fill', sum(tst.ok(tst.sr('k6@example.com', '2001:db8:5:' || to_hex(g) || '::1', 'privacy')))::text
  from generate_series(1, 50) g;
select tst.check(tst.v('k6fill') = '1', 'KVKK payı doluyken tek /48''deki 50 yeni /64''ten yalnız biri girer');
insert into tst.kv select 'k4fresh', sum(tst.ok(tst.sr('k4@example.com', '10.2.0.' || (100 + g), 'privacy')))::text from generate_series(1, 20) g;
select tst.check(tst.v('k4fresh') = '0', 'aynı /24''ün yeni adresleri KVKK istisnasıyla giremez');
select tst.check(tst.sr('gercek@example.com', '203.0.113.13', 'privacy') ? 'ref', 'KVKK seli sonrası başka ağdan gerçek KVKK talebi kabul (önce busy)');
select tst.check(tst.sr('gercek-bug@example.com', '203.0.113.14') ? 'ref', 'KVKK seli genel formu etkilemez');
reset role;
delete from public.support_requests;

-- KVKK talebi kaynak sınırına tabidir
set role service_role;
select tst.sr('p' || g || '@example.com', '192.0.2.5', 'privacy') from generate_series(1, 5) g;
select tst.check(tst.sr('p6@example.com', '192.0.2.5', 'privacy') ->> 'error' = 'too_many_source', 'KVKK talebi de kaynak sınırında');
-- eski imza (kaynaksız) çalışır; e-posta sınırı sürer
select tst.check(public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep') ? 'ref', 'eski 5 parametreli imza');
reset role;
select tst.check((select source_hash is null from public.support_requests where email = 'eski@example.com'), 'eski imzada kaynak yok');
set role service_role;
select public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep 2');
select public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep 3');
select tst.check(public.support_request_create('parent', 'bug', 'eski@example.com', '', 'Eski işlevden gelen talep 4') ->> 'error' = 'too_many', 'e-posta başına 24 saatte 3 sürüyor');
reset role;
-- 2 günden eski özet boşaltılır
update public.support_requests set created_at = now() - interval '3 days' where email like 'p%@example.com';
set role service_role;
select tst.sr('yeni@example.com', '192.0.2.9');
reset role;
select tst.check(not exists (select 1 from public.support_requests where email like 'p%@example.com' and (source_hash is not null or source_wide_hash is not null)),
                 'eski özetler (kaynak ve geniş ağ) boşaltıldı');
select tst.check((select source_wide_hash is not null from public.support_requests where email = 'yeni@example.com'), 'yeni talebin geniş ağ özeti durur');
-- panel kuyruğu kaynak özetlerini göstermez
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', '{"nickname":"Destek"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f2', 'support');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f2', false), set_config('request.jwt.claims', '{"aal":"aal2"}', false);
set role authenticated;
insert into tst.kv values ('adm', public.admin_support_requests('all', 50)::text);
reset role;
select set_config('request.jwt.claims', '', false);
select tst.check(jsonb_array_length(tst.v('adm')::jsonb) > 0 and tst.v('adm') like '%yeni@example.com%'
                 and not (tst.v('adm')::jsonb -> 0 ? 'source_hash') and not (tst.v('adm')::jsonb -> 0 ? 'source_wide_hash'), 'panel kuyruğunda kaynak özeti yok');
delete from public.support_requests;

-- =====================================================================
-- 2. Davet e-postası
-- =====================================================================
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Can"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Mor","name":"Ali"}');
-- d1 ve d2 eski hesap; d3 yeni (ilk 24 saat)
update public.clinicians set created_at = now() - interval '10 days' where id in ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d2');

create or replace function tst.inv(u text, e text) returns text language plpgsql as $$
declare c text;
begin
  perform tst.as_user(u::uuid);
  set local role authenticated;
  c := public.clinic_create_invite('family', '', '', e) ->> 'code';
  reset role;
  return c;
end $$;

-- aynı alıcıya iki klinikten: günde 3 (R1: bir davetin 3 gönderimi sığsın; önce 2)
insert into tst.kv values ('i1', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
insert into tst.kv values ('i2', tst.inv('00000000-0000-0000-0000-0000000000d2', 'Hedef@Example.com'));
insert into tst.kv values ('i3', tst.inv('00000000-0000-0000-0000-0000000000d2', 'hedef@example.com'));
insert into tst.kv values ('i3b', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef+b@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i1'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'alıcıya 1. e-posta');
select tst.check(tst.take(tst.v('i2'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'alıcıya 2. e-posta (başka klinik)');
select tst.check(tst.take(tst.v('i3'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'alıcıya 3. e-posta');
select tst.check(tst.take(tst.v('i3b'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'rate_recipient', 'aynı alıcıya günde en çok 3 (kliniklerden bağımsız)');
-- gönderilemeyen sayılmaz
select public.clinic_invite_email_done(tst.v('i2'), false);
select tst.check(tst.take(tst.v('i3b'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'gönderilemeyen e-posta alıcı sınırına sayılmaz');
select public.clinic_invite_email_done(tst.v('i3b'), true);
reset role;
select tst.check(not exists (select 1 from public.invite_email_sends where to_hash like '%hedef%'), 'alıcı adres düz yazılmaz');
-- haftada 6: günlük pencere dışına itilmiş 3 gönderim + 3
update public.invite_email_sends set at = now() - interval '3 days';
insert into tst.kv values ('i4', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
insert into tst.kv values ('i5', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
insert into tst.kv values ('i6', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
insert into tst.kv values ('i7', tst.inv('00000000-0000-0000-0000-0000000000d1', 'hedef@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i4'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'haftanın 4. e-postası');
select tst.check(tst.take(tst.v('i5'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'haftanın 5. e-postası');
select tst.check(tst.take(tst.v('i6'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'haftanın 6. e-postası');
reset role;
update public.invite_email_sends set at = now() - interval '2 days' where at > now() - interval '1 day';
set role service_role;
select tst.check(tst.take(tst.v('i7'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'rate_recipient', 'aynı alıcıya haftada en çok 6');
reset role;
delete from public.invite_email_sends;

-- R1: bir davet 3 kez gönderilebilir (ClinicApp "en çok 3 e-posta"); 4. gönderim davet sınırında (limit_invite)
insert into tst.kv values ('r1', tst.inv('00000000-0000-0000-0000-0000000000d1', 'uc-gonderim@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('r1'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'davetin 1. gönderimi');
select public.clinic_invite_email_done(tst.v('r1'), true);
select tst.check(tst.take(tst.v('r1'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'too_soon', '60 saniye içinde yeniden gönderilmez');
reset role;
update public.clinic_invites set email_sent_at = now() - interval '2 minutes' where code = tst.v('r1');
set role service_role;
select tst.check(tst.take(tst.v('r1'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'davetin 2. gönderimi');
select public.clinic_invite_email_done(tst.v('r1'), true);
reset role;
update public.clinic_invites set email_sent_at = now() - interval '2 minutes' where code = tst.v('r1');
set role service_role;
select tst.check(tst.take(tst.v('r1'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'davetin 3. gönderimi (önce rate_recipient)');
select public.clinic_invite_email_done(tst.v('r1'), true);
reset role;
update public.clinic_invites set email_sent_at = now() - interval '2 minutes' where code = tst.v('r1');
set role service_role;
select tst.check(tst.take(tst.v('r1'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'limit_invite', 'davet başına en çok 3');
reset role;
delete from public.invite_email_sends;

-- uzman başına günde 20 (eski hesap)
insert into public.invite_email_sends (clinician_id, code, to_hash)
select '00000000-0000-0000-0000-0000000000d1', 'X', md5(g::text) from generate_series(1, 20) g;
insert into tst.kv values ('i8x', tst.inv('00000000-0000-0000-0000-0000000000d1', 'u7@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i8x'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'rate_clinician', 'uzman başına günde 20 e-posta');
reset role;
delete from public.invite_email_sends;

-- yeni hesap ilk 24 saatte 5
insert into public.invite_email_sends (clinician_id, code, to_hash)
select '00000000-0000-0000-0000-0000000000d3', 'X', md5(g::text) from generate_series(1, 4) g;
insert into tst.kv values ('i8', tst.inv('00000000-0000-0000-0000-0000000000d3', 'u8@example.com'));
insert into tst.kv values ('i9', tst.inv('00000000-0000-0000-0000-0000000000d3', 'u9@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i8'), '00000000-0000-0000-0000-0000000000d3') ? 'to', 'yeni hesabın 5. e-postası');
select tst.check(tst.take(tst.v('i9'), '00000000-0000-0000-0000-0000000000d3') ->> 'error' = 'rate_clinician', 'yeni hesap ilk 24 saatte en çok 5');
reset role;
delete from public.invite_email_sends;

-- sistem genelinde saatte 200
insert into public.invite_email_sends (clinician_id, code, to_hash)
select null, 'X', md5(g::text) from generate_series(1, 200) g;
insert into tst.kv values ('i10', tst.inv('00000000-0000-0000-0000-0000000000d2', 'u10@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('i10'), '00000000-0000-0000-0000-0000000000d2') ->> 'error' = 'rate_global', 'sistem genelinde saatte 200');
reset role;
-- 8 günden eski kayıt silinir
update public.invite_email_sends set at = now() - interval '9 days';
set role service_role;
select tst.check(tst.take(tst.v('i10'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'eski kayıt sayılmaz');
reset role;
select tst.check((select count(*) from public.invite_email_sends) = 1, '8 günden eski kayıt silindi');
delete from public.invite_email_sends;

-- alıcı anahtarı: aynı gelen kutusunun takma adları tek alıcı
select tst.check(public.invite_email_key(' J.Doe+kampanya@GoogleMail.com ') = 'jdoe@gmail.com', 'Gmail: nokta, +etiket, googlemail');
select tst.check(public.invite_email_to_hash('j.d.o.e@gmail.com') = public.invite_email_to_hash('jdoe+1@googlemail.com'), 'Gmail takma adları aynı özet');
select tst.check(public.invite_email_key('ali+x@example.com') = 'ali@example.com', 'her alan adında +etiket atılır');
select tst.check(public.invite_email_key('a.li@example.com') = 'a.li@example.com', 'Gmail dışında nokta kalır');
select tst.check(public.invite_email_key('ali_veli-x@example.com') = 'ali_veli-x@example.com', 'Proton dışında _ ve - kalır');
select tst.check(public.invite_email_key('a+b@c@gmail.com') = 'a+b@c@gmail.com', 'birden çok @ varsa olduğu gibi');
select tst.check(public.invite_email_key('+x@example.com') = '+x@example.com', 'yerel kısım boşalmaz');
-- B5: yeniden testin takma adları (tırnak, sondaki nokta, görünmez karakter, bölünmez boşluk, tam genişlikli harf, benzer nokta)
select tst.check((select count(distinct public.invite_email_to_hash(e)) from unnest(array[
                    'jdoe@gmail.com', 'j.doe+1@googlemail.com', 'jdoe@gmail.com.', 'j.doe@gmail.com.', '"jdoe"@gmail.com', '"j.doe"@gmail.com',
                    E'jdoe​@gmail.com', E'j doe@gmail.com', E'jdoe@gmail.com ', E'jdoe@ｇmail.com', E'j․doe@gmail.com',
                    E'‮jdoe@gmail.com', E'jd­oe@gmail.com', E'j⁦do⁩e@gmail.com', E'﻿jdoe@gmail.com', E'j؜doe@gmail.com',
                    ' JDOE@GMAIL.COM ', E'"j.doe+x"@GoogleMail.com..', E'jdoe@gmail．com', E'jd⁠oe@gmail.com']) e) = 1,
                 'Gmail takma adlarının hepsi tek alıcı');
select tst.check(public.invite_email_key('john.doe@proton.me') = 'johndoe@proton.me', 'Proton: . - _ atılır');
select tst.check((select count(distinct public.invite_email_to_hash(e)) from unnest(array[
                    'john.doe@proton.me', 'john-doe@proton.me', 'john_doe@proton.me', 'johndoe@proton.me', 'John.Doe+x@protonmail.com',
                    'johndoe@protonmail.ch', 'j.o.h.n-d_o.e@pm.me', '"john.doe"@proton.me.']) e) = 1, 'Proton takma adlarının hepsi tek alıcı');
-- yeniden test 4 (satır 26–27): Yandex (alan adları tek, . = -) ve Apple (me.com / mac.com = icloud.com)
select tst.check((select count(distinct public.invite_email_to_hash(e)) from unnest(array[
                    'ali.veli@yandex.com.tr', 'ali-veli@yandex.ru', 'ali.veli@ya.ru', 'ali.veli@yandex.com', 'ali-veli@yandex.ua',
                    'ali.veli@yandex.kz', 'ali.veli@yandex.by', 'Ali.Veli+x@Yandex.Com.TR', 'ali-veli@yandex.ru.']) e) = 1, 'Yandex takma adlarının hepsi tek alıcı');
select tst.check(public.invite_email_key('ali.veli@ya.ru') = 'ali-veli@yandex.ru'
                 and public.invite_email_key('aliveli@yandex.ru') = 'aliveli@yandex.ru', 'Yandex: nokta tireye döner, atılmaz (aliveli ayrı kutu)');
select tst.check((select count(distinct public.invite_email_to_hash(e)) from unnest(array[
                    'jdoe@icloud.com', 'jdoe@me.com', 'jdoe@mac.com', 'JDoe+x@Me.com']) e) = 1, 'Apple takma adlarının hepsi tek alıcı');
select tst.check(public.invite_email_key('j.doe@icloud.com') <> public.invite_email_key('jdoe@icloud.com')
                 and public.invite_email_key('ali.veli@example.ru') = 'ali.veli@example.ru', 'Apple ve öteki alan adlarında nokta kalır');
-- IDN: Unicode, Punycode ve büyük harf yazımı (veritabanının yerel ayarından bağımsız) tek alıcı; ASCII komşu alan adı ayrı
select tst.check((select count(distinct public.invite_email_to_hash(e)) from unnest(array[
                    'ali@şirket.com.tr', 'ali@xn--irket-ova.com.tr', 'ALI@ŞİRKET.COM.TR', 'ali+x@Şirket.com.tr.', 'ali@XN--IRKET-OVA.com.tr']) e) = 1
                 and public.invite_email_key('ALI@ŞİRKET.COM.TR' collate "C") = public.invite_email_key('ali@şirket.com.tr')
                 and public.invite_email_key('ali@sirket.com.tr') = 'ali@sirket.com.tr', 'IDN alan adı yazımları tek alıcı (C yerel ayarında da)');
insert into tst.kv values ('g1', tst.inv('00000000-0000-0000-0000-0000000000d1', 'gelen.kutu@gmail.com'));
insert into tst.kv values ('g2', tst.inv('00000000-0000-0000-0000-0000000000d1', 'gelenkutu+1@googlemail.com'));
insert into tst.kv values ('g3', tst.inv('00000000-0000-0000-0000-0000000000d2', 'G.e.l.e.n.k.u.t.u+2@gmail.com'));
insert into tst.kv values ('g4', tst.inv('00000000-0000-0000-0000-0000000000d2', 'gelenkutu@GMAIL.com'));
-- tetikleyiciden önce yazılmış (eski) bozuk biçimli satır da aynı alıcı sayılır
set session_replication_role = replica;
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at, parent_email)
select 'ESKI98', clinic_id, id, 'family', '', now() + interval '1 day', '"gelen.kutu"@gmail.com.'
  from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
set session_replication_role = origin;
set role service_role;
select tst.check(tst.take(tst.v('g1'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'takma ad 1');
select tst.check(tst.take(tst.v('g2'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'takma ad 2');
select tst.check(tst.take(tst.v('g3'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'takma ad 3');
select tst.check(tst.take(tst.v('g4'), '00000000-0000-0000-0000-0000000000d2') ->> 'error' = 'rate_recipient', 'Gmail takma adı aynı alıcı sayılır');
select tst.check(tst.take('ESKI98', '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'rate_recipient', 'eski satırdaki tırnaklı / noktalı takma ad aynı alıcı');
reset role;
delete from public.invite_email_sends;
insert into tst.kv values ('pm1', tst.inv('00000000-0000-0000-0000-0000000000d1', 'john.doe@proton.me'));
insert into tst.kv values ('pm2', tst.inv('00000000-0000-0000-0000-0000000000d1', 'john-doe@proton.me'));
insert into tst.kv values ('pm3', tst.inv('00000000-0000-0000-0000-0000000000d2', 'john_doe@protonmail.com'));
insert into tst.kv values ('pm4', tst.inv('00000000-0000-0000-0000-0000000000d2', 'johndoe+x@pm.me'));
set role service_role;
insert into tst.kv select 'pm', sum(tst.ok(tst.take(tst.v(k), u)))::text
  from (values ('pm1', '00000000-0000-0000-0000-0000000000d1'), ('pm2', '00000000-0000-0000-0000-0000000000d1'),
               ('pm3', '00000000-0000-0000-0000-0000000000d2'), ('pm4', '00000000-0000-0000-0000-0000000000d2')) x(k, u);
select tst.check(tst.v('pm') = '3', 'Proton takma adlarından yalnız 3 gönderim (yeniden test 6a: önce 4/4)');
reset role;
delete from public.invite_email_sends;
-- uçtan uca: Yandex, Apple ve IDN yazımlarıyla aynı kutuya yalnız 3 gönderim (yeniden test 4: önce 7/7 ve 3/3)
insert into tst.kv select 'yx' || n, tst.inv(case when n % 2 = 0 then '00000000-0000-0000-0000-0000000000d1' else '00000000-0000-0000-0000-0000000000d2' end, e)
  from unnest(array['ali.veli@yandex.com.tr', 'ali-veli@yandex.ru', 'ali.veli@ya.ru', 'ali.veli@yandex.com', 'ali-veli@yandex.ua',
                    'ali.veli@yandex.kz', 'ali.veli@yandex.by']) with ordinality x(e, n);
insert into tst.kv select 'ap' || n, tst.inv('00000000-0000-0000-0000-0000000000d1', e)
  from unnest(array['elma.kutu@icloud.com', 'elma.kutu@me.com', 'elma.kutu@mac.com', 'elma.kutu+x@icloud.com']) with ordinality x(e, n);
insert into tst.kv select 'idn' || n, tst.inv('00000000-0000-0000-0000-0000000000d2', e)
  from unnest(array['ali@şirket.com.tr', 'ali@xn--irket-ova.com.tr', 'ALI@ŞİRKET.COM.TR', 'ali@s' || chr(807) || 'irket.com.tr']) with ordinality x(e, n);
set role service_role;
insert into tst.kv select 'yx', sum(tst.ok(tst.take(tst.v('yx' || n), case when n % 2 = 0 then '00000000-0000-0000-0000-0000000000d1'
                                                                           else '00000000-0000-0000-0000-0000000000d2' end)))::text
  from generate_series(1, 7) n;
insert into tst.kv select 'ap', sum(tst.ok(tst.take(tst.v('ap' || n), '00000000-0000-0000-0000-0000000000d1')))::text from generate_series(1, 4) n;
insert into tst.kv select 'idn', sum(tst.ok(tst.take(tst.v('idn' || n), '00000000-0000-0000-0000-0000000000d2')))::text from generate_series(1, 4) n;
reset role;
select tst.check(tst.v('yx') = '3' and tst.v('ap') = '3' and tst.v('idn') = '3', 'Yandex 7, Apple 4, IDN 4 yazımdan her birinde yalnız 3 gönderim');
delete from public.invite_email_sends;

-- B5: davet adresi oluşturulurken denetlenir; olağan adresler kabul, bozuk biçimler aynı hatayla reddedilir
insert into tst.kv values ('o1', tst.inv('00000000-0000-0000-0000-0000000000d1', 'Ayse.Yilmaz+klinik@Gmail.com'));
insert into tst.kv values ('o2', tst.inv('00000000-0000-0000-0000-0000000000d1', 'o''brien@example.co.uk'));
insert into tst.kv values ('o3', tst.inv('00000000-0000-0000-0000-0000000000d1', 'ali@sirket.com.tr'));
insert into tst.kv values ('o4', tst.inv('00000000-0000-0000-0000-0000000000d1', ' Veli_Anne-1%x@Alt.Ornek-Site.com '));
select tst.check((select array_agg(parent_email order by code) from public.clinic_invites where code in (tst.v('o1'))) = array['ayse.yilmaz+klinik@gmail.com']
                 and (select parent_email from public.clinic_invites where code = tst.v('o2')) = 'o''brien@example.co.uk'
                 and (select parent_email from public.clinic_invites where code = tst.v('o3')) = 'ali@sirket.com.tr'
                 and (select parent_email from public.clinic_invites where code = tst.v('o4')) = 'veli_anne-1%x@alt.ornek-site.com',
                 'olağan adresler kabul (küçük harf, kırpılmış)');
set role service_role;
select tst.check(tst.take(tst.v('o1'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'olağan adrese e-posta gider');
reset role;
select tst.check((select count(*) = 0 from unnest(array[
                    '"jdoe"@gmail.com', 'jdoe@gmail.com.', E'jdoe​@gmail.com', E'j doe@gmail.com', E'jdoe@ｇmail.com',
                    E'j․doe@gmail.com', E'‮jdoe@gmail.com', 'a@b.com;x', 'a@b.com,c@d.com', 'jdoe@gmail..com', 'jdoe@.gmail.com',
                    'jdoe@gmail', 'j doe@gmail.com', 'jdoe@gm_ail.com', '<jdoe@gmail.com>', 'jdoe@[127.0.0.1]', E'jdoe@gmail.com\nBcc: x@y.co']) e
                  where tst.err(format('select tst.inv(%L, %L)', '00000000-0000-0000-0000-0000000000d1', e)) is distinct from 'E-posta adresi geçersiz'),
                 'bozuk biçimler oluşturulurken reddedilir, hata metni aynı ("E-posta adresi geçersiz")');
select tst.check(not exists (select 1 from public.clinic_invites where parent_email like '%jdoe%'), 'reddedilen adresle davet oluşmadı');
-- yeniden test 4 (satır 32): Türkçe karakterli (IDN) alan adı ve RFC atext işaretleri (& = …) kabul; ayrıştırılmış (NFD)
-- yazım NFC'ye çevrilir. ASCII olmayan yerel kısım bilerek reddedilir.
insert into tst.kv values ('o5', tst.inv('00000000-0000-0000-0000-0000000000d1', 'ali@şirket.com.tr'));
insert into tst.kv values ('o6', tst.inv('00000000-0000-0000-0000-0000000000d1', 'a&b=c@example.com'));
insert into tst.kv values ('o7', tst.inv('00000000-0000-0000-0000-0000000000d1', 'veli@s' || chr(807) || 'irket.com.tr'));
insert into tst.kv values ('o8', tst.inv('00000000-0000-0000-0000-0000000000d1', 'x!#$%*/?^_`{|}~-y@alt.örnek.org'));
select tst.check((select parent_email from public.clinic_invites where code = tst.v('o5')) = 'ali@şirket.com.tr'
                 and (select parent_email from public.clinic_invites where code = tst.v('o6')) = 'a&b=c@example.com'
                 and (select parent_email from public.clinic_invites where code = tst.v('o7')) = 'veli@şirket.com.tr'
                 and (select parent_email from public.clinic_invites where code = tst.v('o8')) = 'x!#$%*/?^_`{|}~-y@alt.örnek.org',
                 'IDN alan adı ve atext işaretleri kabul, NFD yazım NFC (önce reddediliyordu)');
set role service_role;
select tst.check(tst.take(tst.v('o5'), '00000000-0000-0000-0000-0000000000d1') ? 'to', 'IDN adrese e-posta gider');
reset role;
select tst.check((select count(*) = 0 from unnest(array[
                    'a..b@x.com', '.a@x.com', 'a.@x.com', 'a@x.com.', '"a"@x.com', 'a@x', 'a@x.c', E'a\u200b@x.com', E'a@x\u200b.com',
                    E'a@\u200bx.com', E'a\u00a0b@x.com', E'a@x\u00a0.com', E'a@ş\u00adirket.com', E'a@x.co\u2028m', E'a@\u1680x.com',
                    E'a@x\u2060.com', E'a@x.com\u0085', E'a@gmail\u3002com', E'a@gmail\uff61com', E'a@x\ufe0f.com', E'a@x\u3164.com',
                    'ayşe@example.com', 'a(b)@x.com', 'a@x.com,b@y.com', 'a;b@x.com', 'a:b@x.com', 'a\b@x.com', 'a[b]@x.com',
                    'a@x..com', 'a@.x.com', 'a@x_y.com', 'a@x/y.com', E'a@x\u2024com']) e
                  where tst.err(format('select tst.inv(%L, %L)', '00000000-0000-0000-0000-0000000000d1', e)) is distinct from 'E-posta adresi geçersiz'),
                 'nokta, tırnak, görünmez karakter, bölünmez boşluk, IDN noktası ve ayraç biçimleri reddedilir (aynı hata metni)');
-- biçim denetimi veritabanının yerel ayarına bağlı değil: C sıralamasında da aynı sonuç
select tst.check((select bool_and(public.invite_email_valid(e) = public.invite_email_valid(e collate "C")) from unnest(array[
                    'ali@şirket.com.tr', 'a&b=c@example.com', 'ayse.yilmaz+klinik@gmail.com', 'o''brien@example.co.uk', 'x@alt.örnek.org',
                    'a..b@x.com', E'a@x\u200b.com', E'a@x\u00a0.com', 'a@x', 'ayşe@example.com', E'a@gmail\u3002com']) e)
                 and public.invite_email_valid('ali@şirket.com.tr' collate "C") and not public.invite_email_valid(E'a@x\u00a0.com' collate "C"),
                 'biçim denetimi C yerel ayarında da aynı');
-- eski satırlar değiştirilmez; adresi değişen satır denetlenir; adres boşaltılabilir
set session_replication_role = replica;
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at, parent_email)
select 'ESKI99', clinic_id, id, 'family', '', now() + interval '1 day', 'Eski "Biçim"@Ornek.com.'
  from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
set session_replication_role = origin;
update public.clinic_invites set label = 'not' where code = 'ESKI99';
select tst.check((select parent_email from public.clinic_invites where code = 'ESKI99') = 'Eski "Biçim"@Ornek.com.', 'eski satırın adresi değiştirilmez (başka sütun güncellenir)');
select tst.check(tst.err($$update public.clinic_invites set parent_email = 'kotu"@ornek.com' where code = 'ESKI99'$$) = 'E-posta adresi geçersiz', 'bozuk adrese güncellenemez');
update public.clinic_invites set parent_email = ' Yeni@Ornek.com ' where code = 'ESKI99';
select tst.check((select parent_email from public.clinic_invites where code = 'ESKI99') = 'yeni@ornek.com', 'güncellenen adres kırpılır ve küçük harfe');
update public.clinic_invites set parent_email = null where code = 'ESKI99';
select tst.check((select parent_email is null from public.clinic_invites where code = 'ESKI99'), 'adres boşaltılabilir (KVKK işlemi)');
select tst.check((select count(*) from pg_trigger where tgname = 'clinic_invites_email_check' and tgrelid = 'public.clinic_invites'::regclass) = 1, 'tetikleyici tek');

-- sistem payı ikiye ayrılır: yeni hesaplar (saatte 60) yerleşiklerin payını (200) tüketemez
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d4', false, '{"account":"clinician","clinic_name":"Sarı","name":"Efe"}');
insert into tst.kv values ('n1', tst.inv('00000000-0000-0000-0000-0000000000d3', 'yeni1@example.com'));
insert into tst.kv values ('n2', tst.inv('00000000-0000-0000-0000-0000000000d3', 'yeni2@example.com'));
insert into tst.kv values ('n3', tst.inv('00000000-0000-0000-0000-0000000000d3', 'yeni3@example.com'));
insert into tst.kv values ('e1', tst.inv('00000000-0000-0000-0000-0000000000d2', 'yerlesik1@example.com'));
insert into tst.kv values ('p1', tst.inv('00000000-0000-0000-0000-0000000000d4', 'ucretli1@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('n1'), '00000000-0000-0000-0000-0000000000d3') ? 'to', 'yeni hesap gönderir');
reset role;
select tst.check((select pool from public.invite_email_sends where code = tst.v('n1')) = 'new', 'yeni hesap küçük paydan');
-- saldırganın yeni hesapları küçük payı doldurur
insert into public.invite_email_sends (clinician_id, code, to_hash, pool)
select null, 'X', md5('n' || g), 'new' from generate_series(1, 59) g;
set role service_role;
-- (önceki sürümde n2 burada rate_global alıyordu; B6: ilk 24 saatindeki hesabın ilk 2 gönderimi pay dolu diye reddedilmez)
select tst.check(tst.take(tst.v('n2'), '00000000-0000-0000-0000-0000000000d3') ? 'to', 'yeni hesabın 2. gönderimi pay dolu olsa da gider (B6)');
select tst.check(tst.take(tst.v('n3'), '00000000-0000-0000-0000-0000000000d3') ->> 'error' = 'rate_global', 'yeni hesap payı saatte 60 (ilk 2 gönderimden sonra)');
select tst.check(tst.take(tst.v('e1'), '00000000-0000-0000-0000-0000000000d2') ? 'to', 'yerleşik uzman yeni hesap payı dolsa da gönderir');
reset role;
select tst.check((select pool from public.invite_email_sends where code = tst.v('e1')) = 'main', 'yerleşik uzman ana paydan');
select tst.check((select count(*) from public.invite_email_sends where pool = 'new') = 61, 'güvenceli gönderim de küçük paya sayılır');
-- ücretli paketteki yeni hesap yerleşik sayılır
update public.clinics set plan = 'solo', period_end = now() + interval '30 days'
 where id = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d4');
set role service_role;
select tst.check(tst.take(tst.v('p1'), '00000000-0000-0000-0000-0000000000d4') ? 'to', 'ücretli klinikteki yeni hesap ana paydan gönderir');
reset role;
select tst.check((select pool from public.invite_email_sends where code = tst.v('p1')) = 'main', 'ücretli klinik ana pay');
-- ana pay dolunca yerleşik de reddedilir, yeni hesap payı ana paya sayılmaz
delete from public.invite_email_sends where pool = 'new';
insert into public.invite_email_sends (clinician_id, code, to_hash, pool)
select null, 'X', md5('m' || g), 'main' from generate_series(1, 198) g;
insert into tst.kv values ('e2', tst.inv('00000000-0000-0000-0000-0000000000d2', 'yerlesik2@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('e2'), '00000000-0000-0000-0000-0000000000d2') ->> 'error' = 'rate_global', 'ana pay saatte 200');
select tst.check(tst.take(tst.v('n3'), '00000000-0000-0000-0000-0000000000d3') ? 'to', 'yeni hesap payı ana paydan bağımsız');
reset role;
delete from public.invite_email_sends;

-- B6: 12 kendi açılmış hesap küçük payı doldursa da gerçek yeni uzman ilk davetlerini gönderir (yeniden test 6c); sert tavan 150
insert into auth.users (id, is_anonymous, raw_user_meta_data)
select ('00000000-0000-0000-0000-0000000001' || lpad(g::text, 2, '0'))::uuid, false,
       jsonb_build_object('account', 'clinician', 'clinic_name', 'F' || g, 'name', 'F' || g) from generate_series(1, 13) g;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', false, '{"account":"clinician","clinic_name":"Gerçek","name":"Yeni Uzman"}'),
  ('00000000-0000-0000-0000-0000000000e2', false, '{"account":"clinician","clinic_name":"Gerçek 2","name":"Yeni Uzman 2"}');
insert into tst.kv select 'f' || g || '-' || k, tst.inv('00000000-0000-0000-0000-0000000001' || lpad(g::text, 2, '0'), 'spam' || g || '-' || k || '@catchall.example')
  from generate_series(1, 12) g, generate_series(1, 6) k;
insert into tst.kv values ('v1', tst.inv('00000000-0000-0000-0000-0000000000e1', 'veli-yeni1@example.com'));
insert into tst.kv values ('v2', tst.inv('00000000-0000-0000-0000-0000000000e1', 'veli-yeni2@example.com'));
insert into tst.kv values ('v3', tst.inv('00000000-0000-0000-0000-0000000000e1', 'veli-yeni3@example.com'));
insert into tst.kv values ('w1', tst.inv('00000000-0000-0000-0000-0000000000e2', 'veli-yeni4@example.com'));
insert into tst.kv values ('w2', tst.inv('00000000-0000-0000-0000-0000000000e2', 'veli-yeni5@example.com'));
insert into tst.kv values ('x1', tst.inv('00000000-0000-0000-0000-000000000113', 'spam13@catchall.example'));
set role service_role;
insert into tst.kv select 'flood6c', sum(tst.ok(tst.take(tst.v('f' || g || '-' || k), '00000000-0000-0000-0000-0000000001' || lpad(g::text, 2, '0'))))::text
  from generate_series(1, 12) g, generate_series(1, 6) k;
select tst.check(tst.v('flood6c') = '60', '12 hesap × 6 denemeden 60 gönderim (her hesap 5)');
select tst.check(tst.take(tst.v('v1'), '00000000-0000-0000-0000-0000000000e1') ? 'to', 'gerçek yeni uzmanın ilk daveti pay dolu olsa da gider (önce rate_global)');
select tst.check(tst.take(tst.v('v2'), '00000000-0000-0000-0000-0000000000e1') ? 'to', 'gerçek yeni uzmanın 2. daveti');
select tst.check(tst.take(tst.v('v3'), '00000000-0000-0000-0000-0000000000e1') ->> 'error' = 'rate_global', 'güvence ilk 2 gönderim');
reset role;
-- sert tavan: küçük pay 150'ye dolunca güvence de biter
insert into public.invite_email_sends (clinician_id, code, to_hash, pool)
select null, 'X', md5('t' || g), 'new' from generate_series(1, 149 - (select count(*) from public.invite_email_sends where pool = 'new')) g;
set role service_role;
select tst.check(tst.take(tst.v('w1'), '00000000-0000-0000-0000-0000000000e2') ? 'to', 'küçük payın 150. gönderimi (güvenceli)');
select tst.check(tst.take(tst.v('w2'), '00000000-0000-0000-0000-0000000000e2') ->> 'error' = 'rate_global', 'küçük payın sert tavanı saatte 150');
select tst.check(tst.take(tst.v('x1'), '00000000-0000-0000-0000-000000000113') ->> 'error' = 'rate_global', '150''den sonra yeni hesap da reddedilir');
reset role;
select tst.check((select count(*) from public.invite_email_sends where pool = 'new' and at > now() - interval '1 hour') = 150, 'küçük pay en çok 150');
-- Yeniden test 4 (satır 36): güvence yerleşik olmayan her hesaba, kayan 24 saatte ilk 2 gönderim (deneme süresindeki gerçek
-- uzman 2.–7. günde de). (Önceki sürümde burada 2 günlük hesap rate_global alıyordu: güvence yalnız ilk 24 saatti; bu test
-- eski sınırı bilerek kodluyordu, yeni kurala göre değişti.)
update public.clinicians set created_at = now() - interval '2 days' where id = '00000000-0000-0000-0000-000000000113';
delete from public.invite_email_sends where code = 'X';
select tst.check((select count(*) from public.invite_email_sends where pool = 'new') = 63, 'küçük payda 63 gerçek gönderim kaldı');
insert into tst.kv select 'x' || g, tst.inv('00000000-0000-0000-0000-000000000113', 'gun3-' || g || '@example.com') from generate_series(2, 4) g;
set role service_role;
select tst.check(tst.take(tst.v('x1'), '00000000-0000-0000-0000-000000000113') ? 'to', '2 günlük (yerleşik olmayan) hesabın 1. gönderimi pay doluyken gider');
select tst.check(tst.take(tst.v('x2'), '00000000-0000-0000-0000-000000000113') ? 'to', '2 günlük hesabın 2. gönderimi');
select tst.check(tst.take(tst.v('x3'), '00000000-0000-0000-0000-000000000113') ->> 'error' = 'rate_global', '24 saatte yalnız 2 güvenceli gönderim');
reset role;
-- kayan 24 saat: önceki iki gönderim 24 saatten eskiye düşünce yeniden 2
update public.invite_email_sends set at = now() - interval '25 hours' where clinician_id = '00000000-0000-0000-0000-000000000113';
insert into public.invite_email_sends (clinician_id, code, to_hash, pool)
select null, 'X', md5('y' || g), 'new' from generate_series(1, 60) g;
set role service_role;
select tst.check(tst.take(tst.v('x3'), '00000000-0000-0000-0000-000000000113') ? 'to', 'kayan 24 saat dolunca güvence yeniden (pay dolu)');
reset role;
-- yeniden testin biçimi: 12 kendi açılmış hesap payı doldurduktan sonra deneme süresinin 3. günündeki gerçek uzman
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e3', false, '{"account":"clinician","clinic_name":"Deneme","name":"Üçüncü Gün"}');
update public.clinicians set created_at = now() - interval '2 days 6 hours' where id = '00000000-0000-0000-0000-0000000000e3';
select tst.check((select plan from public.clinics where id = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000e3')) = 'trial',
                 'deneme kliniği (yerleşik değil)');
insert into tst.kv select 't' || g, tst.inv('00000000-0000-0000-0000-0000000000e3', 'veli-deneme' || g || '@example.com') from generate_series(1, 3) g;
set role service_role;
select tst.check(tst.take(tst.v('t1'), '00000000-0000-0000-0000-0000000000e3') ? 'to', 'deneme 3. gün: 1. davet pay dolu olsa da gider (önce rate_global)');
select tst.check(tst.take(tst.v('t2'), '00000000-0000-0000-0000-0000000000e3') ? 'to', 'deneme 3. gün: 2. davet');
select tst.check(tst.take(tst.v('t3'), '00000000-0000-0000-0000-0000000000e3') ->> 'error' = 'rate_global', 'deneme 3. gün: 3. davet pay dolu, güvence bitti');
reset role;
select tst.check((select pool from public.invite_email_sends where code = tst.v('t1')) = 'new', 'güvenceli gönderim küçük paya sayılır');
-- sert tavan 150 güvenceyi de durdurur (yerleşik olmayan eski hesapta da)
update public.invite_email_sends set at = now() - interval '25 hours' where clinician_id = '00000000-0000-0000-0000-0000000000e3';
insert into public.invite_email_sends (clinician_id, code, to_hash, pool)
select null, 'X', md5('z' || g), 'new' from generate_series(1, 150 - (select count(*) from public.invite_email_sends where pool = 'new' and at > now() - interval '1 hour')) g;
set role service_role;
select tst.check(tst.take(tst.v('t3'), '00000000-0000-0000-0000-0000000000e3') ->> 'error' = 'rate_global', 'küçük pay 150''de: güvenceli hesap da reddedilir');
reset role;
select tst.check((select count(*) from public.invite_email_sends where pool = 'new' and at > now() - interval '1 hour') = 150, 'küçük pay yine en çok 150');
-- 7 günden eski hesap yerleşiktir (ana pay; küçük paydan ve güvenceden bağımsız)
update public.clinicians set created_at = now() - interval '8 days' where id = '00000000-0000-0000-0000-0000000000e3';
set role service_role;
select tst.check(tst.take(tst.v('t3'), '00000000-0000-0000-0000-0000000000e3') ? 'to', '7 günden eski hesap ana paydan gönderir');
reset role;
select tst.check((select pool from public.invite_email_sends where code = tst.v('t3') order by id desc limit 1) = 'main', 'yerleşik hesap ana pay');
delete from public.invite_email_sends;

-- hesap silip yeniden kaydolmak alıcı sınırını sıfırlamaz
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d5', false, '{"account":"clinician","clinic_name":"Gri","name":"Nur"}');
insert into tst.kv values ('s1', tst.inv('00000000-0000-0000-0000-0000000000d5', 'silinen@example.com'));
insert into tst.kv values ('s2', tst.inv('00000000-0000-0000-0000-0000000000d5', 'Silinen+b@example.com'));
insert into tst.kv values ('s2b', tst.inv('00000000-0000-0000-0000-0000000000d5', 'SILINEN+c@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('s1'), '00000000-0000-0000-0000-0000000000d5') ? 'to', 'silinecek hesap 1');
select tst.check(tst.take(tst.v('s2'), '00000000-0000-0000-0000-0000000000d5') ? 'to', 'silinecek hesap 2');
select tst.check(tst.take(tst.v('s2b'), '00000000-0000-0000-0000-0000000000d5') ? 'to', 'silinecek hesap 3');
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000d5';
select tst.check(not exists (select 1 from public.clinicians where id = '00000000-0000-0000-0000-0000000000d5'), 'uzman silindi');
select tst.check((select count(*) from public.invite_email_sends where clinician_id is null) = 3, 'gönderim satırları kalır, uzman bağı boşalır');
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d6', false, '{"account":"clinician","clinic_name":"Gri","name":"Nur"}');
insert into tst.kv values ('s3', tst.inv('00000000-0000-0000-0000-0000000000d6', 'silinen@example.com'));
set role service_role;
select tst.check(tst.take(tst.v('s3'), '00000000-0000-0000-0000-0000000000d6') ->> 'error' = 'rate_recipient', 'yeniden kayıttan sonra aynı alıcı yine sınırda');
reset role;
select tst.check((select confdeltype from pg_constraint where conname = 'invite_email_sends_clinician_id_fkey') = 'n', 'yabancı anahtar on delete set null');
