-- Paylaşım kaydı ya da klinik silinince ailenin kayıtları ailede kalır (migrations/20261120200000_family_keeps_records.sql; kullanıcı kararı
-- 20 Kasım 2026, hukuk kararı 3A): uzman hesabını silince (tek kişilik klinik) Etkin / Ustalaştı eğitimler, ebeveynin yanıtları,
-- uygulama kayıtları, yapılacakları ve davranış olayları kalır; taslak, gözlem verisi, ölçüt ve ailenin girdisi olmayan arşivli parçalar
-- silinir; aile salt okur, yeni kayıt giremez; aynı çocukla etkin paylaşımı olan başka uzman ve kliniği duran uzman göremez;
-- KVKK dökümü eğitimin adını taşır; imha işi dokunmaz; çocuk ya da aile silinince hepsi silinir.
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false); end $$;
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
    if sqlerrm like 'TEST%' then raise; end if;
    raise notice 'ok (beklenen hata): % → %', msg, sqlerrm;
    return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
create table if not exists tst.kv (k text primary key, v jsonb);
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

-- Aile F: anne a1 + baba a2, çocuklar Mira (c001) ve Efe (c002). Aile G: komşu b1, çocuk Can (c003).
-- Klinik D: tek kişilik uzman d1 (Mira, Efe, Can ile paylaşım). Klinik E: uzman e1 (Mira ile etkin paylaşım).
insert into public.feature_flags (key, enabled, rollout_pct) values ('parent_training', true, 100)
  on conflict (key) do update set enabled = true, rollout_pct = 100;   -- ebeveyn eğitimi bayrağı (migrations/20261123210000; kapalı hâli testin sonunda)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000b1', false, '{"nickname":"Komşu"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can"}');
update public.profiles set family_id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1')
 where id = '00000000-0000-0000-0000-0000000000a2';
update public.profiles set name = 'Ayşe' where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set name = 'Mehmet' where id = '00000000-0000-0000-0000-0000000000a2';
update public.profiles set name = 'Zeynep' where id = '00000000-0000-0000-0000-0000000000b1';
insert into public.children (id, family_id, name, avatar)
  select x.id, p.family_id, x.name, 'tavşan' from public.profiles p,
    (values ('00000000-0000-0000-0000-00000000c001'::uuid, 'Mira', '00000000-0000-0000-0000-0000000000a1'::uuid),
            ('00000000-0000-0000-0000-00000000c002'::uuid, 'Efe', '00000000-0000-0000-0000-0000000000a1'::uuid),
            ('00000000-0000-0000-0000-00000000c003'::uuid, 'Can', '00000000-0000-0000-0000-0000000000b1'::uuid)) x(id, name, parent)
   where p.id = x.parent;
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select x.id, m.clinic_id, m.id, c.family_id, c.id, x.parent
    from (values ('00000000-0000-0000-0000-0000000011a1'::uuid, '00000000-0000-0000-0000-0000000000d1'::uuid, '00000000-0000-0000-0000-00000000c001'::uuid, '00000000-0000-0000-0000-0000000000a1'::uuid),
                 ('00000000-0000-0000-0000-0000000011a2'::uuid, '00000000-0000-0000-0000-0000000000e1'::uuid, '00000000-0000-0000-0000-00000000c001'::uuid, '00000000-0000-0000-0000-0000000000a1'::uuid),
                 ('00000000-0000-0000-0000-0000000011a3'::uuid, '00000000-0000-0000-0000-0000000000d1'::uuid, '00000000-0000-0000-0000-00000000c002'::uuid, '00000000-0000-0000-0000-0000000000a1'::uuid),
                 ('00000000-0000-0000-0000-0000000011a4'::uuid, '00000000-0000-0000-0000-0000000000d1'::uuid, '00000000-0000-0000-0000-00000000c003'::uuid, '00000000-0000-0000-0000-0000000000b1'::uuid)
         ) x(id, clinician, child, parent)
    join public.clinicians m on m.id = x.clinician
    join public.children c on c.id = x.child;
insert into tst.kv values
  ('famF', to_jsonb((select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'))),
  ('famG', to_jsonb((select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'))),
  ('clinicD', to_jsonb((select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1'))),
  ('clinicE', to_jsonb((select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000e1')));
create or replace function tst.id(k text) returns uuid language sql as $$ select (v #>> '{}')::uuid from tst.kv where kv.k = id.k $$;
grant execute on function tst.id(text) to authenticated;

-- ---------------------------------------------------------------- 1. uzman D eğitimleri ve hedef davranışları kurar
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.parent_trainings (id, clinic_id, link_id, family_id, parent_id, title, status) values
  ('00000000-0000-0000-0000-0000000070a1', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', tst.id('famG'),
   '00000000-0000-0000-0000-0000000000a1', 'ABC ile anlamak', 'active'),
  ('00000000-0000-0000-0000-0000000070a2', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', null, null, 'Taslak eğitim', 'draft'),
  ('00000000-0000-0000-0000-0000000070a3', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a3', null,
   '00000000-0000-0000-0000-0000000000a1', 'Efe için rutin', 'active'),
  ('00000000-0000-0000-0000-0000000070a4', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a4', null, null, 'Can için sakinleşme', 'active');
select tst.check((select family_id from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a1') = tst.id('famF')
                 and (select child_id from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a1') = '00000000-0000-0000-0000-00000000c001',
                 'eğitimin ailesi ve çocuğu paylaşımdan yazılır (gönderilen family_id yok sayılır)');
update public.parent_trainings set criterion = '3 uygulama kaydı', seen_at = now() where id = '00000000-0000-0000-0000-0000000070a1';
insert into public.parent_training_modules (id, training_id, item_key, position, archived) values
  ('00000000-0000-0000-0000-0000000071a1', '00000000-0000-0000-0000-0000000070a1', 'abc_q', 0, false),
  ('00000000-0000-0000-0000-0000000071a2', '00000000-0000-0000-0000-0000000070a1', 'abc_r', 1, true),
  ('00000000-0000-0000-0000-0000000071a3', '00000000-0000-0000-0000-0000000070a1', 'abc_s', 2, false),
  ('00000000-0000-0000-0000-0000000071a4', '00000000-0000-0000-0000-0000000070a3', 'rutin_r', 0, false);
insert into public.parent_training_tasks (id, training_id, title, measure, archived) values
  ('00000000-0000-0000-0000-0000000072a1', '00000000-0000-0000-0000-0000000070a1', 'ABC kaydı', 'frequency', false),
  ('00000000-0000-0000-0000-0000000072a2', '00000000-0000-0000-0000-0000000070a1', 'Eski görev', 'none', true),
  ('00000000-0000-0000-0000-0000000072a4', '00000000-0000-0000-0000-0000000070a4', 'Nefes egzersizi', 'frequency', false);
insert into public.parent_training_todos (id, training_id, title, archived) values
  ('00000000-0000-0000-0000-0000000073a1', '00000000-0000-0000-0000-0000000070a1', 'Zamanlayıcı hazırla', false),
  ('00000000-0000-0000-0000-0000000073a2', '00000000-0000-0000-0000-0000000070a1', 'Eski yapılacak', true),
  ('00000000-0000-0000-0000-0000000073a3', '00000000-0000-0000-0000-0000000070a3', 'Rutin kartı as', false);
insert into public.parent_training_data (training_id, day, value) values ('00000000-0000-0000-0000-0000000070a1', current_date, 60);
insert into public.clinic_target_behaviors (id, clinic_id, link_id, title, log_type) values
  ('00000000-0000-0000-0000-0000000080a1', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', 'Vurma', 'frequency'),
  ('00000000-0000-0000-0000-0000000080a4', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a4', 'Bağırma', 'frequency');

-- uzman E de Mira için etkin bir eğitim kurar
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
insert into public.parent_trainings (id, clinic_id, link_id, title, status) values
  ('00000000-0000-0000-0000-0000000070a5', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a2', 'Yeşil eğitimi', 'active');
insert into public.parent_training_modules (id, training_id, item_key, position) values
  ('00000000-0000-0000-0000-0000000071a5', '00000000-0000-0000-0000-0000000070a5', 'abc_q', 0);

-- ---------------------------------------------------------------- 2. aile yanıtlar, kayıtlar, olaylar
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.family_training_module_complete('00000000-0000-0000-0000-0000000071a1', '[{"pick":1},{"text":"annenin yanıtı"}]', 1, 2);
select public.family_training_module_complete('00000000-0000-0000-0000-0000000071a3');
select public.family_training_log('00000000-0000-0000-0000-0000000072a1', null, 3, null, null, null, 'Akşam üç kez');
select public.family_training_todo_set('00000000-0000-0000-0000-0000000073a1', true, 4, 'İyi geçti');
select public.family_training_todo_set('00000000-0000-0000-0000-0000000073a3', true, 5, '');
select public.family_training_module_complete('00000000-0000-0000-0000-0000000071a4', '[{"text":"Efe için yanıt"}]');
insert into tst.kv values ('i1', to_jsonb(public.family_incident_report('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000080a1', null, 2, null, '', '', 'Ayırdım', 3)));
insert into tst.kv values ('i2', to_jsonb(public.family_incident_report('00000000-0000-0000-0000-0000000011a1', null, null, 1, null, '', '', '', 2, 'Kapıyı çarptı')));
insert into tst.kv values ('i3', to_jsonb(public.family_incident_report('00000000-0000-0000-0000-0000000011a3', null, null, 1, null, '', '', '', 4, 'Uykuya direndi')));
select tst.check((select behavior_title from public.behavior_incidents where id = tst.id('i1')) = 'Vurma', 'olayda hedef davranışın adı yazılır');
select tst.check((select behavior_title from public.behavior_incidents where id = tst.id('i2')) = '', 'diğer olayda hedef adı boş (ad other_behavior''da)');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select public.family_training_log('00000000-0000-0000-0000-0000000072a4', null, 2, null, null, null, 'komşunun kaydı');
select public.family_incident_report('00000000-0000-0000-0000-0000000011a4', '00000000-0000-0000-0000-0000000080a4', null, 1, null, '', '', '', 3);

-- uzman D: modülü arşivler (ebeveyn tamamlamıştı), Efe'nin eğitimini Ustalaştı yapar, hedefin adını değiştirir
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.parent_training_modules set archived = true where id = '00000000-0000-0000-0000-0000000071a3';
update public.parent_trainings set status = 'mastered' where id = '00000000-0000-0000-0000-0000000070a3';
update public.clinic_target_behaviors set title = 'Kardeşine vurma' where id = '00000000-0000-0000-0000-0000000080a1';
select tst.check((select behavior_title from public.behavior_incidents where id = tst.id('i1')) = 'Kardeşine vurma', 'hedefin adı değişince olaydaki ad da değişir');
select tst.check((select count(*) from public.behavior_incidents) = 4, 'uzman D paylaşımlarının olaylarını görür (önce)');

-- önce: uzman E yalnız kendi eğitimini görür
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.parent_trainings) = 1 and (select count(*) from public.behavior_incidents) = 0, 'uzman E başka kliniğin kayıtlarını görmez (önce)');

-- ---------------------------------------------------------------- 3. uzman D hesabını siler → tek kişilik klinik silinir
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.delete_account();
reset role;
select tst.check(not exists (select 1 from public.clinics where id = tst.id('clinicD')), 'klinik D silindi');
select tst.check(not exists (select 1 from public.clinic_links where id in ('00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000011a3',
                                                                          '00000000-0000-0000-0000-0000000011a4')), 'D''nin paylaşım kayıtları silindi');
select tst.check(exists (select 1 from public.clinic_links where id = '00000000-0000-0000-0000-0000000011a2' and status = 'active'), 'E''nin paylaşımı duruyor');
select tst.check(not exists (select 1 from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a2'), 'taslak eğitim silindi');
select tst.check((select count(*) from public.parent_trainings where id in ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000070a3',
                                                                         '00000000-0000-0000-0000-0000000070a4')
                    and link_id is null and clinic_id is null and detached_at is not null) = 3, 'Etkin ve Ustalaştı eğitimler ailede kaldı (bağ boş)');
select tst.check((select criterion is null and seen_at is null and created_by is null and status = 'active' and title = 'ABC ile anlamak'
                    and parent_id = '00000000-0000-0000-0000-0000000000a1' and parent_name = 'Ayşe'
                    from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a1'), 'uzmanın ölçütü ve son bakışı silindi, gerisi aynı');
select tst.check((select status from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a3') = 'mastered', 'Ustalaştı durumu korundu');
select tst.check(not exists (select 1 from public.parent_training_data), 'uzmanın gözlem verisi silindi');
select tst.check((select array_agg(id::text order by id) from public.parent_training_modules where training_id = '00000000-0000-0000-0000-0000000070a1')
                 = array['00000000-0000-0000-0000-0000000071a1', '00000000-0000-0000-0000-0000000071a3'],
                 'tamamlanan modüller kaldı (arşivli olan da), ailenin girdisi olmayan arşivli modül silindi');
select tst.check((select answers::text from public.parent_training_modules where id = '00000000-0000-0000-0000-0000000071a1') like '%annenin yanıtı%', 'ebeveynin yanıtı duruyor');
select tst.check((select array_agg(id::text) from public.parent_training_tasks where training_id = '00000000-0000-0000-0000-0000000070a1')
                 = array['00000000-0000-0000-0000-0000000072a1'], 'kaydı olan görev kaldı, kaydı olmayan arşivli görev silindi');
select tst.check((select array_agg(id::text) from public.parent_training_todos where training_id = '00000000-0000-0000-0000-0000000070a1')
                 = array['00000000-0000-0000-0000-0000000073a1'], 'işaretli yapılacak kaldı, işaretsiz arşivli yapılacak silindi');
select tst.check((select count(*) from public.parent_training_logs) = 2, 'uygulama kayıtları kaldı (anne + komşu)');
select tst.check((select count(*) from public.behavior_incidents where link_id is null) = 4 and (select count(*) from public.behavior_incidents) = 4,
                 'dört davranış olayı ailede kaldı (bağ boş)');
select tst.check((select behavior_id is null and behavior_title = 'Kardeşine vurma' and count = 2 and strategy = 'Ayırdım'
                    from public.behavior_incidents where id = tst.id('i1')), 'hedef davranış silindi, adı ve olayın ayrıntısı olayda kaldı');
select tst.check(not exists (select 1 from public.clinic_target_behaviors where clinic_id = tst.id('clinicD') or clinic_id is null), 'hedef davranışlar (uzmanın kaydı) silindi');

-- ---------------------------------------------------------------- 4. aile okur, yazamaz
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('kept', public.family_kept_trainings());
select tst.check(jsonb_array_length((select v from tst.kv where k = 'kept')) = 2, 'anne ailede kalan iki eğitimi görür (Mira, Efe)');
select tst.check((select count(*) from jsonb_array_elements((select v from tst.kv where k = 'kept')) e
                   where e->>'id' = '00000000-0000-0000-0000-0000000070a1' and e->>'child_name' = 'Mira' and e->>'link_id' is null
                     and e->>'detached_at' is not null and (e->>'mine')::boolean
                     and jsonb_array_length(e->'modules') = 1 and jsonb_array_length(e->'tasks') = 1
                     and jsonb_array_length(e->'logs') = 1 and jsonb_array_length(e->'todos') = 1
                     and e #>> '{modules,0,answers,1,text}' = 'annenin yanıtı' and e #>> '{todos,0,reflection}' = 'İyi geçti') = 1,
                 'ailede kalan eğitim: modül yanıtı, görev, kayıt, yapılacak (arşivli gizli)');
select tst.check(jsonb_array_length(public.family_trainings()) = 1 and public.family_trainings()->0->>'id' = '00000000-0000-0000-0000-0000000070a5',
                 'family_trainings yalnız etkin paylaşımdakini döndürür (E)');
select tst.check((select count(*) from public.parent_trainings) = 3 and (select count(*) from public.parent_training_logs) = 1
                 and (select count(*) from public.parent_training_modules where training_id = '00000000-0000-0000-0000-0000000070a1') = 1
                 and (select count(*) from public.parent_training_todos where training_id = '00000000-0000-0000-0000-0000000070a1') = 1,
                 'tabloda da okur: iki kalan + E''nin eğitimi, kendi kaydı');
select tst.check((select count(*) from public.behavior_incidents) = 3 and (select behavior_title from public.behavior_incidents where id = tst.id('i1')) = 'Kardeşine vurma',
                 'anne ailesinin olaylarını hedefin adıyla okur');
select tst.check((select count(*) from public.behavior_incidents where link_id is null) = 3, 'olaylarda bağ boş');
select tst.fails($$select public.family_training_log('00000000-0000-0000-0000-0000000072a1', null, 1, null, null, null, '')$$, 'ailede kalan eğitime yeni kayıt girilemez');
select tst.fails($$select public.family_training_todo_set('00000000-0000-0000-0000-0000000073a1', false)$$, 'ailede kalan yapılacak değiştirilemez');
select tst.fails($$select public.family_incident_report('00000000-0000-0000-0000-0000000011a1', null, null, 1, null, '', '', '', 3, 'X')$$, 'silinen paylaşıma olay bildirilemez');
do $$ begin
  update public.parent_trainings set title = 'x' where id = '00000000-0000-0000-0000-0000000070a1';
  update public.behavior_incidents set strategy = 'x' where id = tst.id('i1');
exception when insufficient_privilege then null; end $$;
select tst.check((select title from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a1') = 'ABC ile anlamak'
                 and (select strategy from public.behavior_incidents where id = tst.id('i1')) = 'Ayırdım', 'aile tabloya yazamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(jsonb_array_length(public.family_kept_trainings()) = 2
                 and not (select (e->>'mine')::boolean from jsonb_array_elements(public.family_kept_trainings()) e where e->>'id' = '00000000-0000-0000-0000-0000000070a1'),
                 'baba da görür (anneye atanmış: mine yok)');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check(jsonb_array_length(public.family_kept_trainings()) = 1 and public.family_kept_trainings()->0->>'id' = '00000000-0000-0000-0000-0000000070a4'
                 and (select count(*) from public.behavior_incidents) = 1 and (select count(*) from public.parent_trainings) = 1,
                 'komşu yalnız kendi ailesinde kalanı görür');

-- ---------------------------------------------------------------- 5. uzman tarafı kapalı
-- uzman E'nin Mira ile etkin paylaşımı var: D'den kalan eğitim, kayıt ve olayları yine göremez
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.parent_trainings) = 1 and (select id from public.parent_trainings) = '00000000-0000-0000-0000-0000000070a5',
                 'aynı çocukla paylaşımı olan başka uzman ailede kalan eğitimi görmez');
select tst.check((select count(*) from public.parent_training_modules) = 1 and (select count(*) from public.parent_training_logs) = 0
                 and (select count(*) from public.parent_training_tasks) = 0 and (select count(*) from public.parent_training_todos) = 0,
                 'başka uzman ailede kalan modül, kayıt, görev ve yapılacakları görmez');
select tst.check((select count(*) from public.behavior_incidents) = 0, 'başka uzman ailede kalan olayları görmez');
select tst.check(jsonb_array_length(public.family_kept_trainings()) = 0, 'uzman family_kept_trainings ile bir şey almaz');
select tst.check(not public.training_clinic_visible('00000000-0000-0000-0000-0000000070a1') and not public.training_clinic_mine('00000000-0000-0000-0000-0000000070a1'),
                 'yardımcı işlevler ailede kalan eğitimi uzmana kapatır');
do $$ begin
  update public.parent_trainings set link_id = '00000000-0000-0000-0000-0000000011a2', clinic_id = public.my_clinic_id()
   where id = '00000000-0000-0000-0000-0000000070a1';
  delete from public.parent_training_modules where training_id = '00000000-0000-0000-0000-0000000070a1';
exception when insufficient_privilege or check_violation then null; end $$;
reset role;
select tst.check((select link_id is null from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a1')
                 and (select count(*) from public.parent_training_modules where training_id = '00000000-0000-0000-0000-0000000070a1') = 2,
                 'başka uzman ailede kalan eğitimi sahiplenemez ve silemez');
-- sunucu tarafında bile ailede kalan eğitim başka paylaşıma taşınamaz, değiştirilemez
select tst.fails($$update public.parent_trainings set link_id = '00000000-0000-0000-0000-0000000011a2' where id = '00000000-0000-0000-0000-0000000070a1'$$,
                 'ailede kalan eğitim başka paylaşıma bağlanamaz');
select tst.fails($$update public.parent_trainings set status = 'draft' where id = '00000000-0000-0000-0000-0000000070a1'$$, 'ailede kalan eğitimin durumu değişmez');
select tst.fails($$insert into public.parent_trainings (title, status) values ('bağsız', 'active')$$, 'paylaşımsız yeni eğitim kurulamaz');

-- ---------------------------------------------------------------- 6. klinik duruyorken paylaşım kaydı silinirse (ileride imha işi): aynı kural
delete from public.clinic_links where id = '00000000-0000-0000-0000-0000000011a2';
select tst.check(exists (select 1 from public.clinics where id = tst.id('clinicE')), 'klinik E duruyor');
select tst.check((select link_id is null and clinic_id is null and detached_at is not null from public.parent_trainings
                   where id = '00000000-0000-0000-0000-0000000070a5'), 'E''nin eğitimi ailede kaldı (klinik bağı da boşaldı)');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.parent_trainings) = 0 and (select count(*) from public.parent_training_modules) = 0,
                 'kliniği duran uzman paylaşımı silinen eğitimi görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(jsonb_array_length(public.family_kept_trainings()) = 3 and jsonb_array_length(public.family_trainings()) = 0, 'anne üç kalan eğitimi görür');

-- ---------------------------------------------------------------- 7. KVKK dökümü ve imha işi
insert into tst.kv values ('export', public.my_data_export());
reset role;
select tst.check((select count(*) from jsonb_array_elements((select v from tst.kv where k = 'export') #> '{ebeveyn_egitimi,moduller}') e
                   where e->>'egitim' = 'ABC ile anlamak' and (e->>'ailede_kalan')::boolean) = 2, 'dökümde modüller eğitimin adıyla (ailede kalan)');
select tst.check((select (v #>> '{ebeveyn_egitimi,uygulama_kayitlari,0,uygulama}') = 'ABC kaydı' and (v #>> '{ebeveyn_egitimi,uygulama_kayitlari,0,egitim}') = 'ABC ile anlamak'
                    from tst.kv where k = 'export'), 'dökümde uygulama kaydı görevin adıyla');
select tst.check((select count(*) from jsonb_array_elements((select v from tst.kv where k = 'export') #> '{ebeveyn_egitimi,yapilacaklar}')) = 2
                 and (select count(*) from jsonb_array_elements((select v from tst.kv where k = 'export') -> 'davranis_olaylari') e
                       where e->>'behavior_title' = 'Kardeşine vurma' and e->>'link_id' is null) = 1, 'dökümde yapılacaklar ve olay hedefin adıyla');
select tst.check(((public.retention_run('admin', false)) -> 'errors') = '[]'::jsonb, 'imha işi hatasız çalıştı');
select tst.check((select count(*) from public.parent_trainings) = 4 and (select count(*) from public.behavior_incidents) = 4
                 and (select count(*) from public.parent_training_logs) = 2, 'imha işi ailede kalan kayıtlara dokunmadı');

-- ---------------------------------------------------------------- 8. çocuk silinince o çocuğun her şeyi silinir
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
delete from public.children where id = '00000000-0000-0000-0000-00000000c001';
reset role;
select tst.check(not exists (select 1 from public.parent_trainings where child_id = '00000000-0000-0000-0000-00000000c001')
                 and not exists (select 1 from public.parent_training_modules where training_id in ('00000000-0000-0000-0000-0000000070a1', '00000000-0000-0000-0000-0000000070a5'))
                 and not exists (select 1 from public.parent_training_logs where training_id = '00000000-0000-0000-0000-0000000070a1')
                 and not exists (select 1 from public.parent_training_todos where training_id = '00000000-0000-0000-0000-0000000070a1')
                 and not exists (select 1 from public.behavior_incidents where child_id = '00000000-0000-0000-0000-00000000c001'),
                 'Mira silinince eğitimleri, yanıtları, kayıtları ve olayları silindi');
select tst.check(exists (select 1 from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a3')
                 and exists (select 1 from public.parent_training_todos where id = '00000000-0000-0000-0000-0000000073a3')
                 and exists (select 1 from public.behavior_incidents where id = tst.id('i3')), 'Efe''nin kalan kayıtları duruyor');

-- ---------------------------------------------------------------- 9. aile silinince (son ebeveyn hesabını siler) her şey silinir
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select public.delete_account();
reset role;
select tst.check(not exists (select 1 from public.families where id = tst.id('famG'))
                 and not exists (select 1 from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a4')
                 and not exists (select 1 from public.parent_training_tasks where id = '00000000-0000-0000-0000-0000000072a4')
                 and not exists (select 1 from public.parent_training_logs where family_id = tst.id('famG'))
                 and not exists (select 1 from public.behavior_incidents where family_id = tst.id('famG')),
                 'komşu ailesi silinince ailede kalan eğitim, kayıt ve olay silindi');
-- iki ebeveynli aile: anne ve baba hesaplarını silince aile ve Efe'nin kalan kayıtları gider
select public.account_delete_of('00000000-0000-0000-0000-0000000000a1');
select tst.check((select parent_id is null and parent_name = 'Ayşe' and link_id is null from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a3'),
                 'tek ebeveyn silinince ailede kalan eğitim öteki ebeveynde kalır (atanan ebeveyn bağı boşalır)');
select tst.check((select completed_by is null and completed_at is not null from public.parent_training_modules where id = '00000000-0000-0000-0000-0000000071a4')
                 and (select done_by is null and done_at is not null from public.parent_training_todos where id = '00000000-0000-0000-0000-0000000073a3'),
                 'hesabı silinen ebeveynin tamamlama ve işaretinde kişi bağı boşalır (hesap silme takılmaz)');
select public.account_delete_of('00000000-0000-0000-0000-0000000000a2');
select tst.check(not exists (select 1 from public.parent_trainings) and not exists (select 1 from public.parent_training_todos)
                 and not exists (select 1 from public.behavior_incidents), 'son ebeveyn de silinince hiçbir şey kalmaz');

-- ---------------------------------------------------------------- 10. eğitimi kuran uzmanın hesabı silinince (klinik duruyor) silinmiş kişiye bağ kalmaz
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', false, '{"nickname":"Veli"}'),
  ('00000000-0000-0000-0000-0000000000f1', false, '{"account":"clinician","clinic_name":"Ekip Klinik","name":"Dr. Ali","practice":"clinic"}');
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c004', family_id, 'Ela', 'kedi' from public.profiles where id = '00000000-0000-0000-0000-0000000000c1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a5', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000c1'
    from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000f1' and c.id = '00000000-0000-0000-0000-00000000c004';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000f1');
insert into public.parent_trainings (id, clinic_id, link_id, title, status) values
  ('00000000-0000-0000-0000-0000000070a6', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a5', 'Ela için', 'active');
reset role;
select tst.check((select created_by from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a6') = '00000000-0000-0000-0000-0000000000f1', 'oluşturan yazıldı');
delete from auth.users where id = '00000000-0000-0000-0000-0000000000f1';
select tst.check((select created_by is null and link_id is not null and detached_at is null from public.parent_trainings
                   where id = '00000000-0000-0000-0000-0000000070a6'), 'uzmanın hesabı silinince oluşturan boşalır, eğitim paylaşımda kalır');
