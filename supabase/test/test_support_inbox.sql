-- Destek kutusu (proposed/20261122100000_support_inbox.sql): gelen e-posta, konuşma, yanıt, iç not, konu ve KVKK süresi,
-- hazır yanıtlar, gönderim sonucu, sınırlar, yetki, sistem sağlığı ve saklama.
\set ON_ERROR_STOP on
create schema if not exists tst;
create or replace function tst.as_user(u uuid, aal text default 'aal1') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', json_build_object('aal', aal)::text, false);
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
create table if not exists tst.kv (k text primary key, v jsonb);
create or replace function tst.v(key text) returns jsonb language sql as $$ select v from tst.kv where k = key $$;
create or replace function tst.put(key text, val jsonb) returns jsonb language sql as $$
  insert into tst.kv values (key, val) on conflict (k) do update set v = excluded.v returning v $$;
create or replace function tst.id(key text) returns uuid language sql as $$ select (v ->> 'request_id')::uuid from tst.kv where k = key $$;
-- gelen e-posta (Edge Function'ın çağrısı)
create or replace function tst.mail(f text, subj text, body text, mid text default null, refs text default '',
                                    auto boolean default false, au text default 'pass', att jsonb default null, nm text default '')
returns jsonb language sql as $$
  select public.support_inbound_email(f, nm, subj, body, mid, refs, att, auto, au) $$;
-- tablo okuyan test yardımcıları (istemci rolündeyken de çalışsın diye tanımlayanın yetkisiyle)
create or replace function tst.nmsg(rid uuid) returns integer language sql security definer as $$
  select count(*)::integer from public.support_messages where request_id = rid $$;
create or replace function tst.rid(r text) returns uuid language sql security definer as $$
  select id from public.support_requests where ref = r $$;
create or replace function tst.nreq(sts text[] default null) returns integer language sql security definer as $$
  select count(*)::integer from public.support_requests where sts is null or status = any (sts) $$;
create or replace function tst.mail_check() returns jsonb language sql as $$
  select c from jsonb_array_elements(public.ops_health() -> 'checks') c where c ->> 'key' = 'support_mail' $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', '{"name":"Deniz Destek"}'),
  ('00000000-0000-0000-0000-0000000000f3', false, 'izleyici@example.com', '{"nickname":"İzleyici"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'veli@example.com', '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', false, 'uzman@example.com', '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000b1', false, 'iki@example.com', '{"nickname":"İkisi"}');
insert into public.clinicians (id, clinic_id, name)
select '00000000-0000-0000-0000-0000000000b1', clinic_id, 'İki Hesap' from public.clinicians where id = '00000000-0000-0000-0000-0000000000c1';
insert into public.admin_users (user_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'owner'), ('00000000-0000-0000-0000-0000000000f2', 'support'),
  ('00000000-0000-0000-0000-0000000000f3', 'viewer');

-- =====================================================================
-- 1. Yetki ve RLS
-- =====================================================================
select tst.check((select bool_and(relrowsecurity) from pg_class
                   where oid in ('public.support_messages'::regclass, 'public.support_canned_replies'::regclass,
                                 'public.support_inbound_drops'::regclass)), 'yeni tablolarda RLS açık');
select tst.check(not exists (select 1 from pg_policy where polrelid in ('public.support_messages'::regclass,
                   'public.support_canned_replies'::regclass, 'public.support_inbound_drops'::regclass)), 'yeni tablolarda politika yok (istemciye kapalı)');
select tst.check((select count(*) from pg_trigger where tgname = 'finite_time_guard' and tgrelid in
                   ('public.support_messages'::regclass, 'public.support_canned_replies'::regclass, 'public.support_inbound_drops'::regclass)) = 3,
                 'yeni tablolar sonsuz tarih denetiminde');
select tst.check(position('last_message_at' in (select encode(tgargs, 'escape') from pg_trigger
                   where tgname = 'finite_time_guard' and tgrelid = 'public.support_requests'::regclass)) > 0, 'yeni tarih sütunu da denetimde');
select tst.check(not has_function_privilege('authenticated', 'public.support_inbound_email(text, text, text, text, text, text, jsonb, boolean, text)', 'execute')
                 and not has_function_privilege('authenticated', 'public.support_message_sent(uuid, boolean, text)', 'execute')
                 and has_function_privilege('service_role', 'public.support_inbound_email(text, text, text, text, text, text, jsonb, boolean, text)', 'execute')
                 and has_function_privilege('service_role', 'public.support_message_sent(uuid, boolean, text)', 'execute'),
                 'sunucu işlevlerini yalnız service_role çağırır');
select tst.check(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname in ('support_clean_line', 'support_clean_body', 'support_clean_attachments',
                         'support_reply_subject', 'support_new_ref', 'support_own_domain', 'support_ack_body', 'support_request_row',
                         'support_requests_defaults', 'support_requests_first_message')
                     and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute'))),
                 'yardımcı ve tetikleyici işlevleri istemci çağıramaz');
select tst.check(not exists (select 1 from information_schema.role_table_grants where grantee in ('anon', 'authenticated')
                   and table_schema = 'public' and table_name in ('support_messages', 'support_canned_replies', 'support_inbound_drops')),
                 'istemci rollerinin yeni tablolarda yetkisi yok');

set role anon;
select tst.fails($$select tst.mail('a@example.com', 'x', 'y')$$, 'anon gelen e-posta yazamaz');
select tst.fails($$select public.support_message_sent(gen_random_uuid(), true, null)$$, 'anon gönderim sonucu yazamaz');
select tst.fails($$select public.admin_support_thread(gen_random_uuid())$$, 'anon konuşma okuyamaz');
select tst.fails($$select public.admin_support_canned()$$, 'anon hazır yanıt okuyamaz');
select tst.fails($$select count(*) from public.support_messages$$, 'anon mesaj tablosunu okuyamaz');
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1', 'aal2');
select tst.fails($$select tst.mail('a@example.com', 'x', 'y')$$, 'kullanıcı gelen e-posta yazamaz');
select tst.fails($$select public.support_message_sent(gen_random_uuid(), false, 'x')$$, 'kullanıcı gönderim sonucu yazamaz');
select tst.fails($$select count(*) from public.support_messages$$, 'kullanıcı mesaj tablosunu okuyamaz');
select tst.fails($$select count(*) from public.support_canned_replies$$, 'kullanıcı hazır yanıt tablosunu okuyamaz');
select tst.fails($$select count(*) from public.support_inbound_drops$$, 'kullanıcı sayaç tablosunu okuyamaz');
select tst.fails($$select public.admin_support_requests('open', 10)$$, 'yönetici olmayan kuyruğu göremez');
select tst.fails($$select public.admin_support_thread(gen_random_uuid())$$, 'yönetici olmayan konuşma açamaz');
select tst.fails($$select public.admin_support_reply(gen_random_uuid(), 'Merhaba', false)$$, 'yönetici olmayan yanıt yazamaz');
select tst.fails($$select public.admin_support_canned()$$, 'yönetici olmayan hazır yanıt okuyamaz');
reset role;

-- =====================================================================
-- 2. Form talebi: ilk ileti, KVKK süresi
-- =====================================================================
set role service_role;
select tst.put('f1', public.support_request_create('parent', 'privacy', 'veli@example.com', 'Ayşe', 'Verilerimin silinmesini istiyorum lütfen', '203.0.113.7'));
select tst.put('f2', public.support_request_create('clinic', 'bug', 'uzman@example.com', '', 'Takvim açılmıyor, yardım lütfen', '203.0.113.8'));
select tst.check(public.support_request_create('parent', 'bug', 'a@example.com', '', 'kısa', '203.0.113.9') ->> 'error' = 'invalid', 'formda 10 karakter kuralı sürer');
reset role;
select tst.check((select channel = 'form' and subject is null and kvkk_due_at = created_at + interval '30 days' and last_message_at = created_at
                    from public.support_requests where ref = tst.v('f1') ->> 'ref'), 'form KVKK talebi: kanal form, 30 gün sayacı, son ileti = açılış');
select tst.check((select kvkk_due_at is null from public.support_requests where ref = tst.v('f2') ->> 'ref'), 'KVKK dışı form talebinde sayaç yok');
select tst.check((select count(*) = 1 and bool_and(m.direction = 'in' and m.auth is null and m.body = r.message and m.from_email = r.email
                                                    and m.created_at = r.created_at)
                    from public.support_messages m join public.support_requests r on r.id = m.request_id where r.ref = tst.v('f1') ->> 'ref'),
                 'form iletisi konuşmanın ilk gelen iletisi (doğrulama sonucu yok)');

-- =====================================================================
-- 3. Gelen e-posta: yeni talep, otomatik yanıt, yinelenen teslim
-- =====================================================================
set role service_role;
select tst.put('e1', tst.mail(' Veli@Example.com ', E'Aboneliği iptal\r\netmek istiyorum', E'Merhaba,\r\nDeneme bitmeden iptal etmek istiyorum.\r\n',
                              '<m1@mail.example.com>', '', false, 'pass',
                              '[{"name":"kimlik-on-yuz.jpg","size":1200000,"type":"image/jpeg","content":"QUJD"},"bozuk",{"name":"x.pdf","size":-5,"type":"<b>"}]',
                              'Ayşe Örnek'));
reset role;
select tst.check(tst.v('e1') @> '{"ok":true,"new":true,"reopened":false,"ack":true,"notify":true}'
                 and tst.v('e1') ->> 'ref' ~ '^D-[A-Z0-9]{6}$' and (tst.v('e1') ->> 'ack_message_id') is not null
                 and tst.v('e1') ->> 'ack_body' like '%' || (tst.v('e1') ->> 'ref') || '%', 'yeni e-posta talebi: alındı yanıtı ve uyarı');
select tst.check((select channel = 'email' and app = 'other' and topic = 'other' and status = 'new' and email = 'veli@example.com'
                         and name = 'Ayşe Örnek' and subject = 'Aboneliği iptal etmek istiyorum' and message like 'Merhaba,%iptal etmek istiyorum.'
                         and kvkk_due_at is null
                    from public.support_requests where id = tst.id('e1')), 'talep alanları: kanal, uygulama, konu, ad, konu satırı (tek satır), mesaj');
select tst.check((select message_id = 'm1@mail.example.com' and auth = 'pass' and from_email = 'veli@example.com'
                         and attachments = '[{"name":"kimlik-on-yuz.jpg","size":1200000,"type":"image/jpeg"},{"name":"x.pdf","size":null,"type":""}]'::jsonb
                         and body = E'Merhaba,\nDeneme bitmeden iptal etmek istiyorum.'
                    from public.support_messages where request_id = tst.id('e1') and direction = 'in'),
                 'gelen ileti: Message-ID köşesiz, doğrulama sonucu, eklerin yalnız adı/boyutu/türü (içerik yok), satır sonları düz');
select tst.check((select auto and send_status = 'pending' and author is null and body = tst.v('e1') ->> 'ack_body'
                         and created_at > (select created_at from public.support_messages where request_id = tst.id('e1') and direction = 'in')
                    from public.support_messages where id = (tst.v('e1') ->> 'ack_message_id')::uuid), 'otomatik yanıt giden ileti olarak bekliyor, gelen iletiden sonra');
select tst.check(not exists (select 1 from public.support_messages where support_messages::text like '%QUJD%'), 'ek içeriği hiçbir yerde yok');
-- yinelenen teslim
set role service_role;
select tst.put('dup', tst.mail('veli@example.com', 'Aboneliği iptal etmek istiyorum', 'Merhaba başka gövde', 'm1@mail.example.com'));
reset role;
select tst.check(tst.v('dup') @> '{"ok":true,"duplicate":true}' and tst.v('dup') ->> 'ref' = tst.v('e1') ->> 'ref'
                 and tst.nmsg(tst.id('e1')) = 2 and (select count(*) from public.support_requests where channel = 'email') = 1,
                 'aynı Message-ID: hiçbir şey yazılmaz, aynı numara döner');
-- otomatik ileti, bizim alan adımız, doğrulanmamış gönderen: yanıt yok
set role service_role;
select tst.put('auto', tst.mail('mailer-daemon@example.net', 'Tatildeyim', 'Ofis dışındayım', null, '', true, 'pass'));
select tst.put('own', tst.mail('ekip@moyoapp.com.tr', 'Deneme', 'İç deneme iletisi'));
select tst.put('own2', tst.mail('a@posta.MOYOAPP.com.tr', 'Deneme', 'Alt alan adı'));
select tst.put('fail', tst.mail('sahte@example.org', 'Hesabım', 'Şifremi unuttum', null, '', false, 'fail'));
select tst.put('bad', tst.mail('adres-degil', 'x', 'y'));
select tst.put('empty', tst.mail('bos@example.com', '', E'  \r\n  '));
select tst.put('one', tst.mail('tek@example.com', 'Kısa', 'a'));
reset role;
select tst.check(tst.v('auto') @> '{"ok":true,"new":true,"ack":false,"notify":true}' and tst.v('auto') -> 'ack_message_id' = 'null'::jsonb
                 and tst.nmsg(tst.id('auto')) = 1, 'otomatik iletiye alındı yanıtı yok (uyarı var)');
select tst.check(tst.v('own') @> '{"ack":false}' and tst.v('own2') @> '{"ack":false}', 'bizim alan adımıza (alt alan adı dahil) otomatik yanıt yok');
select tst.check(tst.v('fail') @> '{"ok":true,"new":true,"ack":false}', 'doğrulaması başarısız gönderene otomatik yanıt yok (geri saçılma)');
select tst.check(tst.v('bad') = '{"ok":false,"error":"invalid"}'::jsonb, 'geçersiz gönderen reddedilir');
select tst.check((select message = '(boş ileti)' and subject is null from public.support_requests where id = tst.id('empty'))
                 and (select message = 'a' from public.support_requests where id = tst.id('one')), 'boş ileti ve tek karakter e-posta talep olur');
-- aynı adrese 24 saatte en çok 3 otomatik yanıt
set role service_role;
select tst.put('c' || g, tst.mail('cok@example.com', 'Soru ' || g, 'Bir sorum var ' || g)) from generate_series(1, 4) g;
reset role;
select tst.check((select array_agg((tst.v('c' || g) ->> 'ack')::boolean order by g) from generate_series(1, 4) g) = '{t,t,t,f}',
                 'aynı adrese 24 saatte en çok 3 otomatik yanıt');

-- =====================================================================
-- 4. Panel: kuyruk, konuşma, yanıt, iç not
-- =====================================================================
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal1');
select tst.fails($$select public.admin_support_thread(tst.id('e1'))$$, 'iki adımlı doğrulama şart');
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
select tst.fails($$select public.admin_support_thread(tst.id('e1'))$$, 'izleyici konuşma açamaz');
select tst.fails($$select public.admin_support_reply(tst.id('e1'), 'Merhaba', false)$$, 'izleyici yanıt yazamaz');
select tst.fails($$select public.admin_support_note(tst.id('e1'), 'not')$$, 'izleyici not yazamaz');
select tst.fails($$select public.admin_support_canned_save(null, 'Başlık', 'Metin', null, 'deneme gerekçe')$$, 'izleyici hazır yanıt ekleyemez');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.put('open', public.admin_support_requests('open', 100));
select tst.check(jsonb_array_length(tst.v('open')) = tst.nreq(array['new', 'in_progress']),
                 'açık sekme: yeni + işlemde');
select tst.check((select bool_and(e ? 'channel' and e ? 'subject' and e ? 'last_message_at' and e ? 'kvkk_due_at' and e ? 'message_count'
                                  and e ? 'note' and not e ? 'source_hash' and not e ? 'source_wide_hash' and not e ? 'handled_by' and not e ? 'k')
                    from jsonb_array_elements(tst.v('open')) e), 'liste alanları: kanal, konu satırı, son ileti, KVKK süresi, mesaj sayısı; özet yok');
select tst.check((select bool_and(a.v >= b.v) from (select (e ->> 'last_message_at')::timestamptz v, n from jsonb_array_elements(tst.v('open')) with ordinality t(e, n)) a
                    join (select (e ->> 'last_message_at')::timestamptz v, n from jsonb_array_elements(tst.v('open')) with ordinality t(e, n)) b on b.n = a.n + 1),
                 'sıra: son iletiye göre en yeni önce');
select tst.check((select (e ->> 'message_count')::int = 2 from jsonb_array_elements(tst.v('open')) e where e ->> 'id' = tst.id('e1')::text), 'mesaj sayısı');
-- konuşma
select tst.put('th', public.admin_support_thread(tst.id('e1')));
select tst.check(tst.v('th') ? 'request' and tst.v('th') ? 'messages' and tst.v('th') ? 'previous' and tst.v('th') ? 'account'
                 and tst.v('th') -> 'request' ->> 'ref' = tst.v('e1') ->> 'ref' and tst.v('th') -> 'request' ? 'note'
                 and not (tst.v('th') -> 'request' ? 'source_hash'), 'konuşma: talep (iç not dahil, özet yok), iletiler, önceki talepler, hesap');
select tst.check((select array_agg(e ->> 'direction' order by n) = '{in,out}'
                         and bool_and(e ?& array['id', 'created_at', 'direction', 'auto', 'author_name', 'from_email', 'body', 'attachments',
                                                 'auth', 'send_status', 'send_error'])
                    from jsonb_array_elements(tst.v('th') -> 'messages') with ordinality t(e, n)), 'iletiler eskiden yeniye, sözleşmedeki alanlarla');
select tst.check(tst.v('th') -> 'messages' -> 0 ->> 'author_name' = 'Ayşe Örnek' and tst.v('th') -> 'messages' -> 1 ->> 'author_name' = 'Moyo Destek'
                 and (tst.v('th') -> 'messages' -> 1 ->> 'auto')::boolean and tst.v('th') -> 'messages' -> 0 ->> 'auth' = 'pass'
                 and tst.v('th') -> 'messages' -> 0 -> 'attachments' -> 0 ->> 'name' = 'kimlik-on-yuz.jpg', 'gönderen adı, otomatik yanıt, doğrulama ve ek adı');
select tst.check(jsonb_array_length(tst.v('th') -> 'previous') = 1 and tst.v('th') -> 'previous' -> 0 ->> 'ref' = tst.v('f1') ->> 'ref'
                 and tst.v('th') -> 'previous' -> 0 ?& array['id', 'ref', 'created_at', 'status', 'subject'], 'aynı adresten önceki talep (form)');
select tst.check(tst.v('th') -> 'account' = jsonb_build_object('kind', 'parent', 'user_id', '00000000-0000-0000-0000-0000000000a1'), 'hesap: ebeveyn');
select tst.check(public.admin_support_thread(tst.rid(tst.v('f2') ->> 'ref')) -> 'account'
                   = jsonb_build_object('kind', 'clinician', 'user_id', '00000000-0000-0000-0000-0000000000c1'), 'hesap: uzman');
select tst.check(public.admin_support_thread(tst.id('fail')) -> 'account' = '{"kind":null,"user_id":null}'::jsonb, 'hesap yoksa boş');
select tst.fails($$select public.admin_support_thread(gen_random_uuid())$$, 'olmayan talep');
-- yanıt
select tst.put('r1', public.admin_support_reply(tst.id('e1'), E'Merhaba,\n\nApp Store › Abonelikler.\n\nMoyo Destek', false));
select tst.check(tst.v('r1') ->> 'to' = 'veli@example.com' and tst.v('r1') ->> 'name' = 'Ayşe Örnek' and tst.v('r1') ->> 'ref' = tst.v('e1') ->> 'ref'
                 and tst.v('r1') ->> 'subject' = 'Re: Aboneliği iptal etmek istiyorum [' || (tst.v('e1') ->> 'ref') || ']'
                 and tst.v('r1') ->> 'body' like 'Merhaba,%Moyo Destek' and (tst.v('r1') ->> 'message_id') is not null,
                 'yanıt: alıcı, ad, konu "Re: … [D-…]", gövde, ileti kimliği');
select tst.fails($$select public.admin_support_reply(tst.id('e1'), E'  \n ', false)$$, 'boş yanıt reddedilir');
select tst.fails($$select public.admin_support_reply(tst.id('e1'), repeat('x', 20001), false)$$, '20 000 karakterden uzun yanıt reddedilir');
select tst.put('r2', public.admin_support_reply(tst.rid(tst.v('f2') ->> 'ref'), 'Takvim düzeldi.', true));
select tst.check(tst.v('r2') ->> 'subject' = 'Re: Destek talebiniz [' || (tst.v('f2') ->> 'ref') || ']' and tst.v('r2') -> 'name' = 'null'::jsonb,
                 'konu satırı olmayan (form) talep: "Re: Destek talebiniz [D-…]"');
select tst.put('n1', public.admin_support_note(tst.id('e1'), 'App Store makbuzunu soralım.'));
select tst.check((tst.v('n1') ->> 'message_id') is not null, 'iç not kaydedildi');
select tst.fails($$select public.admin_support_note(tst.id('e1'), '')$$, 'boş not reddedilir');
reset role;
select tst.check((select status = 'answered' and answered_at is not null and handled_by = '00000000-0000-0000-0000-0000000000f2'
                    from public.support_requests where id = tst.id('e1')), 'yanıt: durum yanıtlandı, yanıt zamanı, ilgilenen');
select tst.check((select status = 'closed' from public.support_requests where ref = tst.v('f2') ->> 'ref'), 'gönder ve kapat');
select tst.check((select direction = 'out' and not auto and author = '00000000-0000-0000-0000-0000000000f2' and send_status = 'pending' and from_email is null
                    from public.support_messages where id = (tst.v('r1') ->> 'message_id')::uuid), 'giden ileti bekliyor, yazan ekip üyesi');
select tst.check((select direction = 'note' and send_status is null from public.support_messages where id = (tst.v('n1') ->> 'message_id')::uuid), 'iç not');
select tst.check((select count(*) = 2 from public.admin_audit where action = 'support.reply' and target_id like 'support:D-%')
                 and (select count(*) = 1 from public.admin_audit where action = 'support.note')
                 and not exists (select 1 from public.admin_audit a where a.action like 'support.%'
                                   and (a::text like '%veli@%' or a::text like '%Abonelikler%' or a::text like '%makbuz%' or a::text like '%Ayşe%')),
                 'denetim kaydı: yanıt ve not; e-posta, ad ve metin yok');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.put('th2', public.admin_support_thread(tst.id('e1')));
reset role;
select tst.check((select array_agg(e ->> 'direction' order by n) = '{in,out,out,note}'
                         and (array_agg(e ->> 'author_name' order by n))[3:4] = '{"Deniz Destek","Deniz Destek"}'
                    from jsonb_array_elements(tst.v('th2') -> 'messages') with ordinality t(e, n)), 'konuşmada yanıt ve not, yazanın adıyla');

-- =====================================================================
-- 5. Gönderim sonucu
-- =====================================================================
set role service_role;
select public.support_message_sent((tst.v('r1') ->> 'message_id')::uuid, true, null);
select public.support_message_sent((tst.v('r1') ->> 'message_id')::uuid, false, 'geç gelen hata');
select public.support_message_sent((tst.v('e1') ->> 'ack_message_id')::uuid, false, 'resend 422');
select public.support_message_sent((tst.v('r2') ->> 'message_id')::uuid, false, E'resend 500: <b>ayse@example.com</b>\n' || repeat('z', 200));
select public.support_message_sent((tst.v('n1') ->> 'message_id')::uuid, false, 'not');
reset role;
select tst.check((select send_status = 'sent' and sent_at is not null and send_error is null
                    from public.support_messages where id = (tst.v('r1') ->> 'message_id')::uuid), 'gönderildi; sonuç bir kez yazılır');
select tst.check((select send_status = 'failed' and send_error = 'resend_422' from public.support_messages where id = (tst.v('e1') ->> 'ack_message_id')::uuid)
                 and (select status = 'answered' from public.support_requests where id = tst.id('e1')), 'otomatik yanıt gönderilemedi: talep durumu değişmez');
select tst.check((select send_status = 'failed' and char_length(send_error) <= 80 and send_error !~ '[@<> ]'
                    from public.support_messages where id = (tst.v('r2') ->> 'message_id')::uuid)
                 and (select status = 'in_progress' from public.support_requests where ref = tst.v('f2') ->> 'ref'),
                 'insan yanıtı gönderilemedi: talep işlemde, hata kısa kod');
select tst.check((select send_status is null from public.support_messages where id = (tst.v('n1') ->> 'message_id')::uuid), 'iç nota gönderim sonucu yazılmaz');
select tst.check(tst.mail_check() ->> 'level' = 'warn' and tst.mail_check() ->> 'detail' like '2 giden ileti gönderilemedi%'
                 and tst.mail_check()::text !~ '@|D-[A-Z0-9]|resend', 'sağlık: gönderilemeyen ileti sarı, yalnız sayı');
update public.support_messages set created_at = now() - interval '25 hours' where send_status = 'failed';
update public.support_messages set created_at = now() - interval '20 minutes' where id = (tst.v('c1') ->> 'ack_message_id')::uuid;
select tst.check(tst.mail_check() ->> 'detail' = '1 giden ileti 15 dakikadır bekliyor (son 24 saat)', 'sağlık: 15 dakikadır bekleyen giden ileti');
update public.support_messages set send_status = 'sent', sent_at = now() where send_status = 'pending';
select tst.check(tst.mail_check() ->> 'level' = 'ok' and tst.mail_check() ->> 'label' = 'Destek e-postası', 'sağlık: sorun yoksa yeşil');

-- =====================================================================
-- 6. Konuşmaya yanıt: eşleşme, yeniden açılma, başkasının numarası
-- =====================================================================
update public.support_requests set updated_at = now() - interval '3 days', created_at = now() - interval '5 days' where id = tst.id('e1');
set role service_role;
select tst.put('t1', tst.mail('VELI@example.com', 'Ynt: Re: Aboneliği iptal etmek istiyorum [' || lower(tst.v('e1') ->> 'ref') || ']',
                              'Teşekkürler, ama bulamadım.', '<m2@mail.example.com>'));
reset role;
select tst.check(tst.v('t1') @> '{"ok":true,"new":false,"reopened":true,"ack":false,"notify":true}' and tst.id('t1') = tst.id('e1'),
                 'aynı gönderenin [D-…] numaralı yanıtı aynı konuşmaya, yanıtlanmış talep yeniden açılır');
select tst.check((select status = 'new' and updated_at > now() - interval '1 minute' and last_message_at > now() - interval '1 minute'
                    from public.support_requests where id = tst.id('e1')), 'yeniden açılan: durum yeni, son ileti ve güncelleme zamanı yenilendi');
select tst.check((select c ->> 'level' from jsonb_array_elements(public.ops_health() -> 'checks') c where c ->> 'key' = 'support') = 'ok',
                 'sağlık: 5 günlük talep yeni iletiyle yeniden açılınca "2 günden uzun yanıtsız" sayılmaz');
set role service_role;
select tst.put('t2', tst.mail('veli@example.com', 'Bir şey daha [' || (tst.v('e1') ->> 'ref') || ']', 'Ek bilgi', '<m3@mail.example.com>'));
-- References ile (konuda numara yok): aynı gönderenin iletisine yanıt
select tst.put('t3', tst.mail('veli@example.com', 'Konu yok', 'Kendi iletime yanıt', '<m4@mail.example.com>', '<x@y> <m1@mail.example.com>'));
-- başkasının numarası ve References'ı: yeni talep
select tst.put('x1', tst.mail('saldirgan@example.net', 'Re: [' || (tst.v('e1') ->> 'ref') || ']', 'Araya girme denemesi', '<m5@evil.example>',
                              '<m1@mail.example.com>'));
reset role;
select tst.check(tst.v('t2') @> '{"new":false,"reopened":false,"notify":false}' and tst.id('t2') = tst.id('e1'), 'açık konuşmaya ek ileti: uyarı yok');
select tst.check(tst.v('t3') @> '{"new":false}' and tst.id('t3') = tst.id('e1'), 'References başlığındaki Message-ID ile aynı konuşma');
select tst.check(tst.v('x1') @> '{"ok":true,"new":true}' and tst.id('x1') <> tst.id('e1') and tst.nmsg(tst.id('e1')) = 7
                 and not exists (select 1 from public.support_messages where request_id = tst.id('e1') and from_email = 'saldirgan@example.net'),
                 'başka gönderen aynı numarayı yazsa da yeni talep açılır (başkasının konuşmasına ileti eklenemez)');
-- yanıt konusu: numara bir kez (başkasının numarası da atılır)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.put('r3', public.admin_support_reply(tst.id('x1'), 'Merhaba', false));
reset role;
select tst.check(tst.v('r3') ->> 'subject' = 'Re: Destek talebiniz [' || (tst.v('x1') ->> 'ref') || ']'
                 and (select count(*) from regexp_matches(tst.v('r3') ->> 'subject', '\[D-', 'g')) = 1, 'yanıt konusunda numara bir kez');
select tst.check(public.support_reply_subject('RE: Fwd: AW: İlt: Fatura [D-ABC234]  [d-xyz789]', 'D-ABC234') = 'Re: Fatura [D-ABC234]'
                 and public.support_reply_subject('Re:', 'D-ABC234') = 'Re: Destek talebiniz [D-ABC234]'
                 and char_length(public.support_reply_subject(repeat('ç', 300), 'D-ABC234')) <= 200, 'konu kuralı: önekler ve numaralar atılır, en çok 200');
-- kapanmış konuşma da yeniden açılır
update public.support_requests set status = 'closed' where id = tst.id('e1');
set role service_role;
select tst.put('t4', tst.mail('veli@example.com', 'Re: [' || (tst.v('e1') ->> 'ref') || ']', 'Tekrar ben', '<m6@mail.example.com>'));
reset role;
select tst.check(tst.v('t4') @> '{"reopened":true,"notify":true}' and (select status = 'new' from public.support_requests where id = tst.id('e1')),
                 'kapanmış konuşma yeniden açılır');

-- =====================================================================
-- 7. Sınırlar: 20 → istenmeyen, 100 ve sistem 2000 → alınmaz
-- =====================================================================
set role service_role;
select tst.put('s' || g, tst.mail('spam@example.com', 'Kampanya ' || g, 'İndirim ' || g)) from generate_series(1, 20) g;
select tst.put('s21', tst.mail('spam@example.com', 'Kampanya 21 [' || (tst.v('s1') ->> 'ref') || ']', repeat('ğ', 3000), '<s21@x>'));
select tst.put('s22', tst.mail('spam@example.com', 'Kampanya 22', 'İndirim 22'));
reset role;
select tst.check((select bool_and(tst.v('s' || g) @> '{"ok":true,"new":true}') from generate_series(1, 20) g)
                 and (select count(*) from public.support_requests where email = 'spam@example.com' and status = 'new') = 20, 'ilk 20 ileti olağan');
select tst.check(tst.v('s21') @> '{"ok":true,"new":true,"ack":false,"notify":false}' and tst.id('s21') <> tst.id('s1')
                 and (select status = 'spam' and char_length(message) = 2000 from public.support_requests where id = tst.id('s21'))
                 and (select char_length(body) = 2000 from public.support_messages where message_id = 's21@x'),
                 '21. ileti istenmeyen talebe (numaralı olsa da konuşmaya eklenmez), gövde 2000, yanıt ve uyarı yok');
select tst.check(tst.v('s22') @> '{"ok":true,"new":false,"ack":false,"notify":false}' and tst.id('s22') = tst.id('s21') and tst.nmsg(tst.id('s21')) = 2,
                 'sonraki ileti aynı günün istenmeyen talebine eklenir');
-- istenmeyen olarak işaretli talebe yanıt verilmez; ona gelen ileti istenmeyen kalır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.fails($$select public.admin_support_reply(tst.id('s21'), 'Merhaba', false)$$, 'istenmeyen talebe yanıt reddedilir');
select public.admin_support_update(tst.id('x1'), 'spam', null, 'araya girme denemesi');
reset role;
set role service_role;
select tst.put('x2', tst.mail('saldirgan@example.net', 'Re: [' || (tst.v('x1') ->> 'ref') || ']', 'Yine ben'));
reset role;
select tst.check(tst.v('x2') @> '{"new":false,"reopened":false,"notify":false}' and (select status = 'spam' from public.support_requests where id = tst.id('x1')),
                 'istenmeyen talebe gelen ileti istenmeyen kalır, uyarı yok');
-- aynı adresten 100: alınmaz
insert into public.support_messages (request_id, direction, from_email, body, auth)
select tst.id('s21'), 'in', 'spam@example.com', 'dolgu', 'none' from generate_series(1, 78);
select tst.check((select count(*) from public.support_messages where from_email = 'spam@example.com' and auth is not null) = 100, 'hazırlık: 100 ileti');
insert into tst.kv values ('n_before', to_jsonb((select count(*) from public.support_messages)));
set role service_role;
select tst.put('s101', tst.mail('Spam@Example.com', 'Kampanya 101', 'İndirim', '<s101@x>'));
reset role;
select tst.check(tst.v('s101') = '{"ok":false,"error":"dropped"}'::jsonb and (select count(*) from public.support_messages) = (tst.v('n_before'))::bigint
                 and not exists (select 1 from public.support_messages where message_id = 's101@x'), 'aynı adresten 24 saatte 100: yazılmaz');
select tst.check((select sum(dropped) from public.support_inbound_drops) = 1, 'sayaç: alınmayan 1');
select tst.check(tst.mail_check() ->> 'level' = 'warn' and tst.mail_check() ->> 'detail' = '1 gelen e-posta sınır nedeniyle alınmadı (son 24 saat)',
                 'sağlık: sınır nedeniyle alınmayan ileti sarı');
-- formdan gelen ileti e-posta sınırına sayılmaz; 24 saatten eski ileti sayılmaz
update public.support_messages set created_at = now() - interval '25 hours' where from_email = 'spam@example.com';
set role service_role;
select tst.put('s102', tst.mail('spam@example.com', 'Kampanya 102', 'İndirim'));
reset role;
select tst.check(tst.v('s102') @> '{"ok":true,"new":true,"ack":false}', '24 saatten eski iletiler sayılmaz (otomatik yanıt sınırı 3 sürer)');
-- bütün sistemde 2000
insert into public.support_messages (request_id, direction, from_email, body, auth)
select tst.id('s21'), 'in', 'dolgu' || g || '@example.com', 'dolgu', 'none'
  from generate_series(1, 2000 - (select count(*) from public.support_messages where direction = 'in' and auth is not null
                                     and created_at > now() - interval '24 hours')) g;
set role service_role;
select tst.put('g1', tst.mail('yepyeni@example.com', 'Merhaba', 'İlk iletim'));
reset role;
select tst.check(tst.v('g1') = '{"ok":false,"error":"dropped"}'::jsonb and not exists (select 1 from public.support_requests where email = 'yepyeni@example.com')
                 and (select sum(dropped) from public.support_inbound_drops) = 2, 'bütün sistemde 24 saatte 2000: yazılmaz, sayaç artar');
update public.support_messages set created_at = now() - interval '25 hours' where from_email like 'dolgu%@example.com';
set role service_role;
select tst.put('g2', tst.mail('yepyeni@example.com', 'Merhaba', 'İlk iletim'));
reset role;
select tst.check(tst.v('g2') @> '{"ok":true,"new":true}', 'sistem sayacı 24 saatte boşalır');
delete from public.support_messages where from_email like 'dolgu%@example.com' or (from_email = 'spam@example.com' and body = 'dolgu');
update public.support_inbound_drops set hour = hour - interval '2 days';
select tst.check(tst.mail_check() ->> 'level' = 'ok', 'sağlık: 24 saatten eski sayaç yeşil');

-- =====================================================================
-- 8. Konu, KVKK sekmesi
-- =====================================================================
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.fails($$select public.admin_support_update(tst.id('fail'), 'in_progress', null, 'deneme', 'hukuk')$$, 'geçersiz konu');
select public.admin_support_update(tst.id('fail'), 'in_progress', 'kimlik soralım', 'KVKK başvurusu', 'privacy');
select public.admin_support_update(tst.id('one'), null, null, 'yalnız konu', 'privacy');
select public.admin_support_update(tst.id('own'), 'answered', null, 'eski çağrı biçimi');   -- 4 parametreli eski çağrı
select tst.put('kv', public.admin_support_requests('kvkk', 50));
reset role;
select tst.check((select topic = 'privacy' and status = 'in_progress' and note = 'kimlik soralım' and kvkk_due_at = created_at + interval '30 days'
                    from public.support_requests where id = tst.id('fail')), 'konu KVKK: 30 gün sayacı açılıştan');
select tst.check((select status = 'new' and topic = 'privacy' from public.support_requests where id = tst.id('one')), 'durum boşsa değişmez');
select tst.check((select status = 'answered' and topic = 'other' from public.support_requests where id = tst.id('own')), 'eski 4 parametreli çağrı çalışır');
select tst.check((select a.after = '{"status":"in_progress","topic":"privacy"}'::jsonb and a.before ->> 'topic' = 'other'
                    from public.admin_audit a where a.action = 'support.update' and a.target_id = 'support:' || (tst.v('fail') ->> 'ref')),
                 'denetim kaydında konu değişikliği');
select tst.check((select array_agg(e ->> 'ref' order by n) from jsonb_array_elements(tst.v('kv')) with ordinality t(e, n))
                   = array[tst.v('f1') ->> 'ref', tst.v('fail') ->> 'ref', tst.v('one') ->> 'ref'], 'KVKK sekmesi: konu KVKK, süresi en yakın önce');
update public.support_requests set status = 'closed' where id = tst.id('one');
update public.support_requests set topic = 'account' where id = tst.id('fail');
select tst.check((select kvkk_due_at is null from public.support_requests where id = tst.id('fail')), 'konu KVKK değilse sayaç kalkar');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.check((select array_agg(e ->> 'ref') from jsonb_array_elements(public.admin_support_requests('kvkk', 50)) e) = array[tst.v('f1') ->> 'ref'],
                 'kapanan ve konusu değişen KVKK sekmesinden çıkar');
select tst.check((select bool_and(e ->> 'status' = 'spam') and count(*) = 2 from jsonb_array_elements(public.admin_support_requests('spam', 50)) e),
                 'istenmeyen sekmesi');
select tst.check(jsonb_array_length(public.admin_support_requests('all', 500)) = tst.nreq(), 'tümü sekmesi');
reset role;

-- hesap: ebeveyn ve uzman ikisi
set role service_role;
select tst.put('both', tst.mail('iki@example.com', 'Soru', 'İki hesabım var'));
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
select tst.check(public.admin_support_thread(tst.id('both')) -> 'account' = jsonb_build_object('kind', 'both', 'user_id', '00000000-0000-0000-0000-0000000000b1'),
                 'hesap: ebeveyn ve uzman (sahip de görür)');
reset role;

-- =====================================================================
-- 9. Hazır yanıtlar
-- =====================================================================
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.put('cn', public.admin_support_canned());
select tst.check((select array_agg(e ->> 'title' order by n) from jsonb_array_elements(tst.v('cn')) with ordinality t(e, n))
                   = '{"Şifre sıfırlama","Aboneliği iptal etme","Uygulama hatası","Uzman hesabı","KVKK başvurusu alındı"}'
                 and (select bool_and(e ->> 'body' like 'Merhaba,%Moyo Destek' and e ?& array['id', 'title', 'body', 'position', 'updated_at'])
                        from jsonb_array_elements(tst.v('cn')) e), 'beş hazır yanıt tohumlandı, sırayla');
select tst.put('cid', to_jsonb(public.admin_support_canned_save(null, 'Ekip daveti', E'Merhaba,\n\nAyarlar › Ekip.\n\nMoyo Destek', null, 'yeni hazır yanıt')));
select tst.check((select e ->> 'title' = 'Ekip daveti' and (e ->> 'position')::int = 6 from jsonb_array_elements(public.admin_support_canned()) e
                   where e ->> 'id' = tst.v('cid') #>> '{}'), 'yeni hazır yanıt sona eklenir');
select tst.check(public.admin_support_canned_save((tst.v('cid') #>> '{}')::uuid, 'Ekip daveti (uzman)', 'Merhaba, yeni metin', 0, 'metin güncellendi')
                   = (tst.v('cid') #>> '{}')::uuid, 'düzenleme aynı kimliği döner');
select tst.check(public.admin_support_canned() -> 0 ->> 'title' = 'Ekip daveti (uzman)', 'sıra değişti');
select tst.fails($$select public.admin_support_canned_save(null, '', 'Metin', null, 'gerekçe yazıldı')$$, 'boş başlık reddedilir');
select tst.fails($$select public.admin_support_canned_save(null, repeat('b', 81), 'Metin', null, 'gerekçe yazıldı')$$, '80 karakterden uzun başlık reddedilir');
select tst.fails($$select public.admin_support_canned_save(null, 'Başlık', repeat('m', 5001), null, 'gerekçe yazıldı')$$, '5000 karakterden uzun metin reddedilir');
select tst.fails($$select public.admin_support_canned_save(null, 'Başlık', 'Metin', null, '')$$, 'gerekçesiz eklenmez');
select tst.fails($$select public.admin_support_canned_save(gen_random_uuid(), 'Başlık', 'Metin', null, 'gerekçe yazıldı')$$, 'olmayan hazır yanıt');
select tst.fails($$select public.admin_support_canned_delete((tst.v('cid') #>> '{}')::uuid, '')$$, 'gerekçesiz silinmez');
select public.admin_support_canned_delete((tst.v('cid') #>> '{}')::uuid, 'artık gerekmiyor');
select tst.check(jsonb_array_length(public.admin_support_canned()) = 5, 'silindi');
select tst.fails($$select public.admin_support_canned_delete((tst.v('cid') #>> '{}')::uuid, 'ikinci kez')$$, 'silinmiş hazır yanıt yeniden silinmez');
reset role;
select tst.check((select count(*) from public.admin_audit where action in ('support.canned_save', 'support.canned_delete')) = 3
                 and not exists (select 1 from public.admin_audit where action like 'support.canned%' and after::text like '%Ayarlar%'),
                 'hazır yanıt işlemleri denetim kaydında (metin yok)');

-- =====================================================================
-- 10. Saklama: mesajlar taleple birlikte silinir
-- =====================================================================
update public.support_requests set status = 'closed', updated_at = now() - interval '800 days' where id = tst.id('e1');
update public.support_requests set updated_at = now() - interval '40 days' where id = tst.id('s21');
insert into tst.kv values ('dry', public.retention_run('admin', true));
select tst.check((tst.v('dry') -> 'results' ->> '25_support_requests')::int = 2 and tst.nmsg(tst.id('e1')) > 0, 'kuru: eski kapanan + eski istenmeyen sayılır, silinmez');
select public.retention_run('cron', false);
select tst.check(not exists (select 1 from public.support_requests where id in (tst.id('e1'), tst.id('s21')))
                 and tst.nmsg(tst.id('e1')) = 0 and tst.nmsg(tst.id('s21')) = 0, 'imha: talep ve bütün iletileri (ekler, gövde) silindi');
-- yeni ileti istenmeyen talebin saklama süresini yeniler
update public.support_requests set updated_at = now() - interval '40 days' where id = tst.id('x1');
set role service_role;
select tst.mail('saldirgan@example.net', 'Re: [' || (tst.v('x1') ->> 'ref') || ']', 'Bir daha');
reset role;
select tst.check((select updated_at > now() - interval '1 minute' from public.support_requests where id = tst.id('x1')), 'yeni ileti saklama süresini yeniler');
select 'DESTEK KUTUSU TESTLERİ GEÇTİ' as sonuc;
