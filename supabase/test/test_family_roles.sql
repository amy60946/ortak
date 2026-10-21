-- İkinci ebeveyn (20261021000000_family_roles.sql): eksiksiz erişim, sahibi çıkaramaz, davet kaydı, kayıt kaybı koruması.
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
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000a3', false, '{"nickname":"Teyze"}');
set role authenticated;

-- Anne aileyi kurar, çocuk + görev ekler, Baba'yı davet eder
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('fid', public.my_family_id()::text);
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi');
insert into public.tasks (id, family_id, title, start_date) values ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Dişler', current_date);
insert into tst.kv select 'code', code from public.create_invite_code('parent', null);

-- Baba katılır: eksiksiz erişim
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family((select v from tst.kv where k = 'code'));
select tst.check(public.my_family_id()::text = (select v from tst.kv where k = 'fid'), 'davet edilen aynı aileye katılır');
select tst.check((select count(*) from public.children) = 1 and (select count(*) from public.tasks) = 1, 'çocuk ve görevleri görür');
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  values ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'easy', 5);
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c001') = 5, 'onaylar, coin verir');
insert into tst.kv select 'code2', code from public.create_invite_code('parent', null);
select tst.check(exists (select 1 from tst.kv where k = 'code2'), 'o da davet kodu üretebilir');
select tst.check((select count(*) from public.profiles) = 2, 'iki ebeveyni görür');

-- Baba, Anne'yi çıkaramaz / değiştiremez
update public.profiles set nickname = 'x' where id = '00000000-0000-0000-0000-0000000000a1';
select tst.fails($$update public.profiles set family_id = null where id = '00000000-0000-0000-0000-0000000000a1'$$, 'başka ebeveynin ailesini değiştiremez');
select tst.fails($$delete from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'$$, 'başka ebeveyni silemez');
select tst.fails($$update public.families set created_by = auth.uid()$$, 'aile sahibini değiştiremez');
reset role;
select tst.check((select nickname from public.profiles where id = '00000000-0000-0000-0000-0000000000a1') = 'Anne', 'Anne''nin profili değişmedi');
select tst.check((select created_by from public.families where id = (select v::uuid from tst.kv where k = 'fid')) = '00000000-0000-0000-0000-0000000000a1', 'aile sahibi Anne kalır');
select tst.check((select invited_by from public.profiles where id = '00000000-0000-0000-0000-0000000000a2') = '00000000-0000-0000-0000-0000000000a1', 'kim davet etti kaydı');
set role authenticated;

-- Baba hesabını silerse aile ve Anne kalır
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.delete_account();
reset role;
select tst.check(exists (select 1 from public.families where id = (select v::uuid from tst.kv where k = 'fid')), 'aile kalır');
select tst.check(exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Anne kalır');
set role authenticated;

-- Teyze'nin kendi ailesinde çocuk var: katılım reddedilir (kayıt kaybı yok)
select tst.as_user('00000000-0000-0000-0000-0000000000a3');
insert into public.children (family_id, name, avatar) values (public.my_family_id(), 'Ece', 'kedi');
select tst.fails($$select public.join_family((select v from tst.kv where k = 'code2'))$$, 'kendi kaydı olan ebeveyn katılamaz (silinmesin)');
select tst.check((select count(*) from public.children where name = 'Ece') = 1, 'Teyze''nin çocuğu duruyor');

reset role;
select 'TÜM AİLE ROL TESTLERİ GEÇTİ' as sonuc;
