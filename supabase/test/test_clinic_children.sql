-- Uzman paylaşımı: tek kodla birden çok çocuk, sonradan çocuk ekle/çıkar (20261019120000_clinic_children.sql).
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
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}');
insert into public.children (id, family_id, name, avatar)
  select x.id, p.family_id, x.name, 'kedi' from public.profiles p,
    (values ('00000000-0000-0000-0000-00000000c001'::uuid, 'Nazlı'), ('00000000-0000-0000-0000-00000000c002'::uuid, 'Efe'),
            ('00000000-0000-0000-0000-00000000c003'::uuid, 'Can')) x(id, name)
  where p.id = '00000000-0000-0000-0000-0000000000a1';

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('fam', public.clinic_create_invite('family', '') ->> 'code');
insert into tst.kv values ('clinic', public.clinician_me() ->> 'clinic_id');

select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$select public.redeem_clinic_invite_children((select v from tst.kv where k = 'fam'), array['00000000-0000-0000-0000-00000000c001'::uuid])$$, 'yabancı ebeveyn başkasının çocuğunu paylaşamaz');
select tst.fails($$select public.clinic_share_child((select v from tst.kv where k = 'clinic')::uuid, '00000000-0000-0000-0000-00000000c001')$$, 'yabancı ebeveyn kodsuz ekleyemez');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.redeem_clinic_invite_children((select v from tst.kv where k = 'fam'), '{}')$$, 'çocuk seçmeden olmaz');
select tst.fails($$select public.clinic_share_child((select v from tst.kv where k = 'clinic')::uuid, '00000000-0000-0000-0000-00000000c003')$$, 'etkin paylaşım yokken kodsuz eklenemez');
select tst.check(json_array_length(public.redeem_clinic_invite_children((select v from tst.kv where k = 'fam'),
  array['00000000-0000-0000-0000-00000000c001'::uuid, '00000000-0000-0000-0000-00000000c002'::uuid, '00000000-0000-0000-0000-00000000c001'::uuid]) -> 'link_ids') = 2,
  'tek kodla iki çocuk paylaşılır (tekrar eden çocuk bir kez)');
select tst.check((select count(*) from public.family_clinic_links()) = 2, 'iki paylaşım listelenir');
select tst.check((select count(distinct clinic_id) from public.family_clinic_links()) = 1, 'listede clinic_id var');
select tst.check(public.redeem_clinic_invite_children((select v from tst.kv where k = 'fam'), array['00000000-0000-0000-0000-00000000c003'::uuid]) ->> 'error' = 'code_used', 'kod yine tek kullanımlık');

-- kodsuz üçüncü çocuk (aynı klinik, etkin paylaşım var)
select public.clinic_share_child((select v from tst.kv where k = 'clinic')::uuid, '00000000-0000-0000-0000-00000000c003');
select public.clinic_share_child((select v from tst.kv where k = 'clinic')::uuid, '00000000-0000-0000-0000-00000000c003');
select tst.check((select count(*) from public.family_clinic_links()) = 3, 'kodsuz eklenir; ikinci kez eklemek çoğaltmaz');

select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.children) = 3, 'uzman üç çocuğu da görür');

-- çıkar: bir çocuğun paylaşımı durdurulur, diğerleri sürer
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link((select link_id from public.family_clinic_links() where child_id = '00000000-0000-0000-0000-00000000c002'));
select tst.check((select count(*) from public.family_clinic_links()) = 2, 'çıkarılan çocuk listeden düşer');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.children) = 2, 'uzman çıkarılan çocuğu artık görmez');
select tst.check(not exists (select 1 from public.children where name = 'Efe'), 'Efe görünmez');

-- yeniden ekle
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.clinic_share_child((select v from tst.kv where k = 'clinic')::uuid, '00000000-0000-0000-0000-00000000c002');
select tst.check((select count(*) from public.family_clinic_links()) = 3, 'çıkarılan çocuk kodsuz yeniden eklenir');

reset role;
select 'TÜM ÇOKLU ÇOCUK PAYLAŞIM TESTLERİ GEÇTİ' as sonuc;
