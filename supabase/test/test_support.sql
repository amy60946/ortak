-- Destek talepleri (proposed/20261102210000_support.sql) + imha ve sağlık bağlantısı (20261102200000_kvkk_ops.sql)
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
grant usage on schema tst to authenticated, anon, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to authenticated, anon, service_role;

insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'destek@example.com', '{"nickname":"Destek"}'),
  ('00000000-0000-0000-0000-0000000000f3', false, 'izleyici@example.com', '{"nickname":"İzleyici"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}');
insert into public.admin_users (user_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'owner'), ('00000000-0000-0000-0000-0000000000f2', 'support'),
  ('00000000-0000-0000-0000-0000000000f3', 'viewer');

-- yalnız sunucu (Edge Function) talep açar
set role anon;
select tst.fails($$select public.support_request_create('parent', 'bug', 'a@b.co', '', 'Uygulama açılmıyor lütfen yardım')$$, 'anon talep açamaz (yalnız işlev)');
reset role;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.support_request_create('parent', 'bug', 'a@b.co', '', 'Uygulama açılmıyor lütfen yardım')$$, 'kullanıcı doğrudan talep açamaz');
select tst.fails($$select count(*) from public.support_requests$$, 'tablo doğrudan okunamaz');
reset role;

set role service_role;
insert into tst.kv values ('r1', public.support_request_create('parent', 'subscription', ' Veli@Example.com ', 'Ayşe', 'Aboneliğim görünmüyor, yardım eder misiniz?'));
select tst.check((select v ->> 'ref' ~ '^D-[A-Z0-9]{6}$' from tst.kv where k = 'r1'), 'talep numarası D-XXXXXX');
select tst.check((select email = 'veli@example.com' and status = 'new' from public.support_requests), 'e-posta küçük harfe, durum yeni');
select tst.check(public.support_request_create('parent', 'bug', 'yanlis-adres', '', 'Uygulama açılmıyor lütfen') ->> 'error' = 'invalid', 'geçersiz e-posta reddedilir');
select tst.check(public.support_request_create('parent', 'bug', 'a@b.co', '', 'kısa') ->> 'error' = 'invalid', 'çok kısa mesaj reddedilir');
select tst.check(public.support_request_create('hacker', 'bug', 'a@b.co', '', 'Uygulama açılmıyor lütfen') ->> 'error' = 'invalid', 'bilinmeyen uygulama reddedilir');
select tst.check(public.support_request_create('parent', 'bug', 'veli@example.com', '', 'İkinci mesajım burada') ? 'ref', 'aynı e-postadan 2. talep');
select tst.check(public.support_request_create('parent', 'bug', 'VELI@example.com', '', 'Üçüncü mesajım burada') ? 'ref', 'aynı e-postadan 3. talep');
select tst.check(public.support_request_create('parent', 'bug', 'veli@example.com', '', 'Dördüncü mesajım burada') ->> 'error' = 'too_many', '24 saatte en çok 3');
reset role;
insert into public.support_requests (ref, app, topic, email, message, created_at)
select 'D-' || lpad(g::text, 6, '0'), 'other', 'other', 'toplu' || g || '@example.com', 'Toplu deneme mesajı', now() - interval '10 minutes'
  from generate_series(1, 60) g;
set role service_role;
select tst.check(public.support_request_create('clinic', 'clinic', 'uzman@example.com', '', 'Ekibe nasıl üye eklerim?') ->> 'error' = 'busy', 'saatte 60 üstü: meşgul');
reset role;
delete from public.support_requests where email like 'toplu%';

-- panel: destek okur ve günceller, izleyici okuyamaz
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
select tst.fails($$select public.admin_support_requests('open', 50)$$, 'izleyici destek kuyruğunu göremez (e-posta ve mesaj içerir)');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal1');
select tst.fails($$select public.admin_support_requests('open', 50)$$, 'iki adımlı doğrulama şart');
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.check(jsonb_array_length(public.admin_support_requests('open', 50)) = 3, 'açık talepler');
select tst.check((public.admin_support_requests('open', 50) -> 0 ->> 'message') like 'Aboneliğim%', 'en eski önce');
reset role;
insert into tst.kv values ('id1', to_jsonb((select id from public.support_requests where name = 'Ayşe')));
set role authenticated;
select tst.fails($$select public.admin_support_update((select (v #>> '{}')::uuid from tst.kv where k = 'id1'), 'answered', '', '')$$, 'gerekçesiz güncellenmez');
select tst.fails($$select public.admin_support_update((select (v #>> '{}')::uuid from tst.kv where k = 'id1'), 'bitti', '', 'yanıtlandı')$$, 'geçersiz durum');
select public.admin_support_update((select (v #>> '{}')::uuid from tst.kv where k = 'id1'), 'answered', 'RevenueCat geri yükleme anlatıldı', 'e-postayla yanıtlandı');
select tst.check(jsonb_array_length(public.admin_support_requests('open', 50)) = 2, 'yanıtlanan açıklardan çıktı');
select tst.check((select a.action = 'support.update' and a.target_id like 'support:D-%' and not (a::text like '%veli@%') and not (a::text like '%Aboneliğim%')
                    from public.admin_audit_list('system', null, 10) a where a.action = 'support.update'), 'denetim kaydında e-posta ve mesaj yok');
reset role;
select tst.check((select answered_at is not null and handled_by = '00000000-0000-0000-0000-0000000000f2' from public.support_requests where name = 'Ayşe'), 'yanıt zamanı ve ilgilenen');

-- sağlık: 2 günden eski yeni talep sarı
update public.support_requests set created_at = now() - interval '3 days' where status = 'new';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
select tst.check((select c ->> 'level' from jsonb_array_elements(public.admin_health() -> 'checks') c where c ->> 'key' = 'support') = 'warn', 'yanıtsız eski talep: sarı');
select tst.check(not (public.admin_health()::text like '%@%'), 'sağlıkta e-posta yok');
reset role;

-- imha: spam 30 gün, kapanan 2 yıl (kuru sayar, gerçek siler)
update public.support_requests set status = 'spam', updated_at = now() - interval '40 days' where message like 'İkinci%';
update public.support_requests set updated_at = now() - interval '800 days' where name = 'Ayşe';
insert into tst.kv values ('dry', public.retention_run('admin', true));
select tst.check((select (v -> 'results' ->> '25_support_requests')::int from tst.kv where k = 'dry') = 2, 'kuru: eski spam + 2 yıllık kapanan');
select tst.check((select count(*) from public.support_requests) = 3, 'kuru çalıştırma silmedi');
select public.retention_run('cron', false);
select tst.check((select array_agg(message) from public.support_requests) = '{"Üçüncü mesajım burada"}', 'yalnız açık talep kaldı');
