-- Yasal metinler, onay kaydı, KVKK başvuruları (proposed/20261027200000_legal.sql)
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
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated, anon;
grant select on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated, anon;

insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', '{"nickname":"Destek"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c9', true, null, '{}'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'uzman@example.com', '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f1', 'owner'), ('00000000-0000-0000-0000-0000000000f2', 'support');
insert into public.children (id, family_id, name, avatar, user_id)
select '00000000-0000-0000-0000-00000000c001', family_id, 'Efe', 'bear', '00000000-0000-0000-0000-0000000000c9' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';

insert into public.legal_documents (key, version, title, apps, requires_acceptance, body_md, status, published_at) values
  ('kosullar-parentapp', 'v1', 'ParentApp Kullanım Koşulları', '{parent}', true, '# Koşullar v1', 'published', now()),
  ('aydinlatma-ebeveyn', 'v1', 'Ebeveyn Aydınlatma Metni', '{parent}', true, '# Aydınlatma', 'draft', null),
  ('gizlilik', 'v1', 'Gizlilik Politikası', '{parent,child,clinic,web}', false, '# Gizlilik', 'draft', null),
  ('kosullar-gameapp', 'v1', 'Pofi Adası Koşulları', '{child}', true, '# Oyun', 'draft', null),
  ('sozlesme-uzman', 'v1', 'Uzman Hizmet Sözleşmesi', '{clinic}', true, '# Uzman', 'draft', null);

-- anon hiçbir şeye erişemez
set role anon;
select tst.fails($$select count(*) from public.legal_documents$$, 'anon metin tablosunu okuyamaz');
select tst.fails($$select public.legal_pending('parent')$$, 'anon onay listesini çağıramaz');
reset role;

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select count(*) from public.legal_documents$$, 'kullanıcı tabloyu doğrudan okuyamaz');
select tst.check(json_array_length(public.legal_documents_for('parent')) = 3, 'ParentApp metinleri (koşullar, aydınlatma, gizlilik)');
select tst.check(json_array_length(public.legal_pending('parent')) = 2, 'onay bekleyen: koşullar + aydınlatma (gizlilik onay istemez)');
select tst.fails($$select public.legal_accept('parent', '[{"key":"kosullar-parentapp","version":"v9"}]')$$, 'güncel olmayan sürüm onaylanamaz');
select tst.fails($$select public.legal_accept('parent', '[{"key":"sozlesme-uzman","version":"v1"}]')$$, 'başka uygulamanın metni onaylanamaz');
select tst.fails($$select public.legal_accept('parent', '[{"key":"gizlilik","version":"v1"}]')$$, 'onay istemeyen metin onaylanmaz');
select tst.check(json_array_length(public.legal_accept('parent', '[{"key":"kosullar-parentapp","version":"v1"},{"key":"aydinlatma-ebeveyn","version":"v1"}]')) = 0, 'onaydan sonra bekleyen yok');
select tst.check((select count(*) from public.legal_acceptances) = 2, 'kendi onaylarını görür');
select tst.check(json_array_length(public.legal_accept('child', '[{"key":"kosullar-gameapp","version":"v1"}]')) = 0, 'veli GameApp koşullarını çocuk adına onaylar');
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.fails($$select public.legal_accept('child', '[{"key":"kosullar-gameapp","version":"v1"}]')$$, 'çocuk cihazı onay veremez');
select tst.check((select count(*) from public.legal_acceptances) = 0, 'başkasının onayını göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(json_array_length(public.legal_pending('clinic')) = 1, 'uzman: sözleşme bekliyor');

-- yayımla: yeni sürüm herkesten yeniden onay ister; yayındaki metin değişmez
reset role;
insert into public.legal_documents (key, version, title, apps, requires_acceptance, summary, body_md)
values ('kosullar-parentapp', 'v2', 'ParentApp Kullanım Koşulları', '{parent}', true, 'Abonelik maddesi açıklandı', '# Koşullar v2');
select tst.fails($$update public.legal_documents set body_md = 'x' where key = 'kosullar-parentapp' and version = 'v1'$$, 'yayımlanmış metin değiştirilemez');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(json_array_length(public.legal_pending('parent')) = 0, 'taslak v2 yayımlanana dek yayındaki v1 geçerli');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.fails($$select public.admin_legal_publish('kosullar-parentapp', 'v2', 'avukat onayı')$$, 'yalnız sahip yayımlar');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal1');
select tst.fails($$select public.admin_legal_publish('kosullar-parentapp', 'v2', 'avukat onayı')$$, 'iki adımlı doğrulama şart');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
select public.admin_legal_publish('kosullar-parentapp', 'v2', 'avukat onayı');
select tst.check((select x ->> 'status' from json_array_elements(public.admin_legal_documents()) x where x ->> 'key' = 'kosullar-parentapp' and x ->> 'version' = 'v1') = 'retired', 'eski sürüm emekliye');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.legal_pending('parent') -> 0 ->> 'version') = 'v2', 'yeni sürüm yeniden onay ister');
select tst.check((public.legal_pending('parent') -> 0 ->> 'summary') = 'Abonelik maddesi açıklandı', 'değişiklik özeti gelir');

-- KVKK başvurusu
select tst.fails($$select public.kvkk_request_create('parent', 'correct', '')$$, 'düzeltme talebi açıklama ister');
select tst.check((public.kvkk_request_create('parent', 'access', '') ->> 'status') = 'received', 'erişim başvurusu alınır');
select tst.check(json_array_length(public.my_kvkk_requests()) = 1, 'kendi başvurusunu görür');
select tst.fails($$select answer_note from public.kvkk_requests$$, 'iç notu göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(json_array_length(public.my_kvkk_requests()) = 0, 'başkasının başvurusunu görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.check(json_array_length(public.admin_kvkk_requests('open', 50)) = 1, 'destek açık başvuruları görür');
select tst.check((public.admin_kvkk_requests('open', 50) -> 0 ->> 'email') = 'anne@example.com', 'yanıt adresi');
select tst.check(public.admin_kvkk_request_log('dis@example.com', 'other', 'email', 'info', 'bilgi', now() - interval '3 days', 'e-postayla geldi') is not null, 'e-postayla gelen kayda alınır');
select tst.check((select (x ->> 'due_at')::timestamptz < now() + interval '28 days' from json_array_elements(public.admin_kvkk_requests('open', 50)) x where x ->> 'email' = 'dis@example.com'), 'süre alınış tarihinden işler');
reset role;
insert into tst.kv select 'rid', id::text from public.kvkk_requests where email = 'anne@example.com';
set role authenticated;
select tst.fails($$select public.admin_kvkk_request_update((select v::uuid from tst.kv where k = 'rid'), 'rejected', '', 'ret')$$, 'ret gerekçe ister');
select public.admin_kvkk_request_update((select v::uuid from tst.kv where k = 'rid'), 'answered', 'veri kopyası e-postayla gönderildi', 'yanıtlandı');
reset role;
select tst.check(exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000a1' and kind = 'kvkk_answered'), 'yanıtlanınca bildirim');
select tst.check(exists (select 1 from public.admin_audit where action = 'kvkk.update'), 'denetim kaydı');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.fails($$select public.admin_kvkk_request_update((select v::uuid from tst.kv where k = 'rid'), 'in_progress', '', 'yeniden')$$, 'kapanan yeniden açılmaz');
select tst.check(json_array_length(public.admin_user_legal('00000000-0000-0000-0000-0000000000a1') -> 'acceptances') = 3, 'kullanıcı kartında onaylar');
reset role;
-- hesap silinince onaylar gider, başvuru kişisiz kalır (e-posta kapanana dek)
select public.account_delete_of('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.legal_acceptances where user_id = '00000000-0000-0000-0000-0000000000a1') = 0, 'silmede onaylar gider');
select tst.check((select user_id from public.kvkk_requests where email = 'anne@example.com') is null, 'başvuru kayıtta kalır, hesaba bağı kopar');
select 'YASAL METİN TESTLERİ GEÇTİ' as sonuc;
