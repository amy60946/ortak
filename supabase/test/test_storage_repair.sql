-- Storage onarımı (proposed/20261028090000_storage_repair.sql): kovalar var, politikalar tek kopya, aile kuralı aynı.
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
  begin
    execute sql;
  exception when others then
    raise notice 'ok (beklenen hata): % → %', msg, sqlerrm;
    return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

select tst.check((select count(*) from storage.buckets where id in ('mail', 'abc')) = 2, 'mail ve abc kovaları var');
select tst.check((select public from storage.buckets where id = 'mail') = false, 'mail gizli kova');
select tst.check((select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'posta:%') = 3,
  'posta politikaları tek kopya (3)');
select tst.check((select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'zor an sesi:%') = 4,
  'zor an politikaları tek kopya (4)');

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into storage.objects (bucket_id, name) values ('mail', public.my_family_id()::text || '/avatars/a.jpg');
select tst.check((select count(*) from storage.objects where bucket_id = 'mail') = 1, 'ebeveyn kendi aile klasörüne çocuk fotoğrafı yükler ve görür');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('mail', '00000000-0000-0000-0000-000000000000/avatars/b.jpg')$$,
  'başka ailenin klasörüne yüklenemez');
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from storage.objects where bucket_id = 'mail') = 0, 'yabancı aile fotoğrafı göremez');
