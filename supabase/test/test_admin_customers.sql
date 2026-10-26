-- Yönetim paneli müşteri listeleri (proposed/20261026600000_admin_customers.sql)
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
create or replace function tst.c(app text, seg text default 'all', q text default '', srt text default 'created_at', dsc boolean default true)
returns json language sql as $$ select public.admin_customers(app, seg, q, srt, dsc, 50, 0) $$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000b1', false, 'baba@example.com', '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c9', true, null, '{}'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'uzman@example.com', '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f1', 'viewer');
update public.families set name = 'Yılmaz ailesi' where id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1');
update public.families set name = 'Kaya ailesi', created_at = now() - interval '20 days'
 where id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b1');
insert into public.family_subscriptions (family_id, plan, source, period_end)
select family_id, 'premium', 'manual', now() + interval '30 days' from public.profiles where id = '00000000-0000-0000-0000-0000000000b1';
insert into public.children (id, family_id, name, avatar, user_id)
select '00000000-0000-0000-0000-00000000c001', family_id, 'Efe', 'bear', '00000000-0000-0000-0000-0000000000c9'
  from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
select '00000000-0000-0000-0000-00000000c002', family_id, 'Zeynep', 'cat' from public.profiles where id = '00000000-0000-0000-0000-0000000000b1';
insert into public.user_activity (user_id, app, last_seen_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'parent', now()),
  ('00000000-0000-0000-0000-0000000000c9', 'child', now() - interval '1 day');
insert into public.coin_ledger (family_id, child_id, amount, reason, ref)
select family_id, id, 25, 'task', 'test-1' from public.children where id = '00000000-0000-0000-0000-00000000c001';

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1', 'aal2');
select tst.fails($$select tst.c('parent')$$, 'admin olmayan göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal1');
select tst.fails($$select tst.c('parent')$$, 'iki adımlı doğrulama olmadan göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
select tst.fails($$select tst.c('baska')$$, 'geçersiz uygulama');
select tst.fails($$select tst.c('parent', 'all', '', 'email')$$, 'sıralama yalnız izinli alanlarla');
select tst.fails($$select tst.c('parent', 'yok')$$, 'geçersiz kesim');

-- ParentApp
select tst.check((tst.c('parent') ->> 'total')::int = 3, 'bütün aileler (yöneticinin, annenin, babanın)');
select tst.check((tst.c('parent', 'premium') ->> 'total')::int = 1, 'premium kesimi');
select tst.check((tst.c('parent') -> 'segments' ->> 'premium')::int = 1, 'kesim sayıları');
select tst.check((tst.c('parent', 'all', 'ANNE@example') -> 'rows' -> 0 ->> 'name') = 'Yılmaz ailesi', 'e-postayla arama (büyük/küçük harf)');
select tst.check((tst.c('parent', 'all', '%') ->> 'total')::int = 0, '% joker sayılmaz');
select tst.check((tst.c('parent', 'all', 'Yılmaz') -> 'rows' -> 0 ->> 'children')::int = 1, 'çocuk sayısı');
select tst.check((tst.c('parent', 'all', 'Yılmaz') -> 'rows' -> 0 ->> 'linked')::int = 1, 'bağlı cihaz');
select tst.check((tst.c('parent', 'all', 'Yılmaz') -> 'rows' -> 0 -> 'parents' -> 0 ->> 'email') = 'anne@example.com', 'ebeveyn e-postası');
select tst.check((tst.c('parent', 'no_device') ->> 'total')::int = 1, 'cihazı bağlanmamış aile');
select tst.check((tst.c('parent', 'new', 'ailesi') ->> 'total')::int = 1, 'son 7 günde açılan (20 günlük aile değil)');
select tst.check((tst.c('parent', 'all', 'ailesi', 'name', false) -> 'rows' -> 0 ->> 'name') = 'Kaya ailesi', 'ada göre artan');
select tst.check((tst.c('parent', 'inactive', 'ailesi') -> 'rows' -> 0 ->> 'name') = 'Kaya ailesi', 'pasif (14 gün görünmeyen)');

-- GameApp
select tst.check((tst.c('child') ->> 'total')::int = 2, 'bütün çocuklar');
select tst.check((tst.c('child', 'linked') -> 'rows' -> 0 ->> 'name') = 'Efe', 'bağlı çocuk');
select tst.check((tst.c('child', 'unlinked') -> 'rows' -> 0 ->> 'name') = 'Zeynep', 'bağlanmamış çocuk');
select tst.check((tst.c('child', 'active_7') -> 'rows' -> 0 ->> 'coins')::int = 25, 'coin bakiyesi');
select tst.check((tst.c('child', 'all', 'baba@') -> 'rows' -> 0 ->> 'name') = 'Zeynep', 'ebeveyn e-postasıyla çocuk arama');

-- ClinicApp
select tst.check((tst.c('clinic') ->> 'total')::int = 1, 'bütün klinikler');
select tst.check((tst.c('clinic') -> 'rows' -> 0 -> 'owner' ->> 'email') = 'uzman@example.com', 'sahip e-postası');
select tst.check((tst.c('clinic', 'no_clients') ->> 'total')::int = 1, 'danışanı olmayan klinik');
select tst.check((tst.c('clinic', 'trial') ->> 'total')::int = 1, 'denemedeki klinik');
reset role;
select 'MÜŞTERİ LİSTESİ TESTLERİ GEÇTİ' as sonuc;
