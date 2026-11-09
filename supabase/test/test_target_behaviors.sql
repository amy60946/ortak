-- Hedef davranışlar ve olaylar (proposed/20261110110000_target_behaviors.sql): uzman hedef davranış ve strateji yazar, aile görür;
-- ebeveyn kayıt türüne göre olay bildirir (zorunlu alanlar), hedefe bağlı olmayan "diğer" olay; uzmana bildirim; aile tabloya yazamaz;
-- başka aile / klinik görmez; ebeveyn kaydı kapalı ya da arşivli hedef aileye görünmez; paylaşım bitince kapanır.
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false); end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000b1', false, '{"nickname":"Komşu"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can"}');
update public.profiles set name = 'Ayşe' where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Mira', 'tavşan' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c
  where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';

set role authenticated;
-- 1. uzman hedef davranış yazar
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_target_behaviors (id, clinic_id, link_id, title, description, strategies, log_type) values
  ('00000000-0000-0000-0000-0000000080a1', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', 'Ekranı kapatırken ağlama',
   'Tablet kapatılırken ne olduğunu kaydedin.', '["Önce–sonra cümlesi", "5 dakika önce uyarı"]', 'abc'),
  ('00000000-0000-0000-0000-0000000080a2', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', 'Vurma',
   '', '["Sakin kal, güvenliği sağla"]', 'frequency'),
  ('00000000-0000-0000-0000-0000000080a3', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', 'Uyku saati',
   '', '[]', 'duration');
update public.clinic_target_behaviors set parent_logging = false where id = '00000000-0000-0000-0000-0000000080a3';
do $$ begin
  insert into public.clinic_target_behaviors (clinic_id, link_id, title, strategies) values
    (public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', 'Boş strateji', '[""]');
  raise exception 'TEST BAŞARISIZ: boş strateji kabul edildi';
exception when check_violation then raise notice 'ok: boş strateji yazılmaz'; end $$;
do $$ begin
  insert into public.clinic_target_behaviors (clinic_id, link_id, title) values (public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', '  ');
  raise exception 'TEST BAŞARISIZ: başlıksız hedef kabul edildi';
exception when check_violation then raise notice 'ok: başlık zorunlu'; end $$;

-- 2. aile görür (ebeveyn kaydı kapalı olanı görmez), tabloya yazamaz
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(jsonb_array_length(public.family_target_behaviors()->0->'behaviors') = 2, 'aile ebeveyn kaydı açık iki hedefi görür');
do $$ begin
  insert into public.behavior_incidents (link_id, family_id, child_id, other_behavior)
    select id, family_id, child_id, 'x' from public.clinic_links where id = '00000000-0000-0000-0000-0000000011a1';
  raise exception 'TEST BAŞARISIZ: aile tabloya yazdı';
exception when insufficient_privilege then raise notice 'ok: aile olay tablosuna doğrudan yazamaz'; end $$;

-- 3. olay bildirimi: türe göre zorunlu alanlar
select public.family_incident_report('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000080a1', now() - interval '1 hour',
  null, null, 'Tableti kapatması istendi', 'Ağladı, 5 dakika verildi', 'Önce–sonra cümlesi', 4);
select public.family_incident_report('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000080a2', null, 3, null, '', '', '', 2);
select public.family_incident_report('00000000-0000-0000-0000-0000000011a1', null, now() - interval '2 hours', 1, 10, 'Kardeşi oyuncağı aldı', 'Ayırdım', 'Ayırma', 3, 'Kardeşle kavga');
select tst.check((select count(*) from public.behavior_incidents) = 3, 'üç olay bildirildi, aile görür');
select tst.check((select reporter_name from public.behavior_incidents limit 1) = 'Ayşe', 'bildiren adı sunucudan');
select tst.check((select antecedent from public.behavior_incidents where behavior_id = '00000000-0000-0000-0000-0000000080a2') = '', 'sıklık türünde öncül yazılmaz');
do $$ begin
  perform public.family_incident_report('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000080a1', null, null, null, 'Önce', '', '', 3);
  raise exception 'TEST BAŞARISIZ: ABC türünde sonuçsuz olay';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: ABC türünde öncül ve sonuç zorunlu'; end $$;
do $$ begin
  perform public.family_incident_report('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000080a2', null, null, null, '', '', '', 3);
  raise exception 'TEST BAŞARISIZ: sıklık türünde sayısız olay';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: sıklık türünde sayı zorunlu'; end $$;
do $$ begin
  perform public.family_incident_report('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000080a3', null, null, 5, '', '', '', 3);
  raise exception 'TEST BAŞARISIZ: ebeveyn kaydı kapalı hedefe olay';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: ebeveyn kaydı kapalı hedefe olay bildirilemez'; end $$;
do $$ begin
  perform public.family_incident_report('00000000-0000-0000-0000-0000000011a1', null, null, null, null, '', '', '', 3, '');
  raise exception 'TEST BAŞARISIZ: adsız diğer olay';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: diğer olayda davranışın adı zorunlu'; end $$;
do $$ begin
  perform public.family_incident_report('00000000-0000-0000-0000-0000000011a1', null, now() + interval '1 day', 1, null, '', '', '', 3, 'Gelecek');
  raise exception 'TEST BAŞARISIZ: ileri tarihli olay';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: ileri tarihli olay yok'; end $$;

-- 4. başka aile bildiremez ve görmez
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check(jsonb_array_length(public.family_target_behaviors()) = 0 and (select count(*) from public.behavior_incidents) = 0, 'başka aile görmez');
do $$ begin
  perform public.family_incident_report('00000000-0000-0000-0000-0000000011a1', null, null, 1, null, '', '', '', 3, 'X');
  raise exception 'TEST BAŞARISIZ: başka aile olay bildirdi';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: başka aile bildiremez'; end $$;

-- 5. uzman görür ve bildirim aldı; başka klinik görmez
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.behavior_incidents) = 3, 'uzman olayları görür');
select tst.check((select count(*) from public.behavior_incidents where behavior_id is null) = 1, 'diğer olay hedefsiz kaydedildi');
reset role;
select tst.check((select count(*) from public.notifications where kind = 'behavior_incident' and user_id = '00000000-0000-0000-0000-0000000000d1') = 3, 'uzmana her olayda bildirim');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.behavior_incidents) = 0 and (select count(*) from public.clinic_target_behaviors) = 0, 'başka klinik görmez');

-- 6. arşivlenen hedef aileye kapanır; paylaşım bitince her şey kapanır
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.clinic_target_behaviors set archived = true where id = '00000000-0000-0000-0000-0000000080a2';
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(jsonb_array_length(public.family_target_behaviors()->0->'behaviors') = 1, 'arşivlenen hedef aileye görünmez');
reset role;
update public.clinic_links set status = 'revoked', revoked_at = now() where id = '00000000-0000-0000-0000-0000000011a1';
set role authenticated;
select tst.check(jsonb_array_length(public.family_target_behaviors()) = 0, 'paylaşım bitince aile hedefleri görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.behavior_incidents) = 0, 'paylaşım bitince uzman olayları görmez');
reset role;
