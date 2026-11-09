-- Ebeveyn eğitimi (proposed/20261110100000_parent_trainings.sql): uzman eğitim kurar, taslağı aile görmez, Etkin olunca atanan ebeveyne
-- bildirim gider; ebeveyn modülü tamamlar, uygulama kaydı girer, yapılacağı işaretler (yalnız işlevle); öteki ebeveyn ve başka aile
-- işlem yapamaz; gözlem verisini aile görmez; başka klinik görmez; paylaşım bitince aile ve uzman erişimi kapanır.
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

-- anne a1 + baba a2 (aynı aile), başka aile b1; klinik sahibi d1, başka klinik e1
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000b1', false, '{"nickname":"Komşu"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can"}');
update public.profiles set family_id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), name = 'Ayşe'
  where id = '00000000-0000-0000-0000-0000000000a2';
update public.profiles set name = 'Ayşe Anne' where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set name = 'Mehmet Baba' where id = '00000000-0000-0000-0000-0000000000a2';
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Mira', 'tavşan' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c
  where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';

set role authenticated;
-- 1. uzman ebeveynleri görür, eğitimi anneye atar (taslak)
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_link_parents('00000000-0000-0000-0000-0000000011a1')) = 2, 'uzman paylaşımdaki iki ebeveyni görür');
insert into public.parent_trainings (id, clinic_id, link_id, parent_id, title) values
  ('00000000-0000-0000-0000-0000000070a1', public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1',
   '00000000-0000-0000-0000-0000000000a1', 'ABC ile anlamak');
select tst.check((select parent_name from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a1') = 'Ayşe Anne', 'ebeveyn adı sunucudan yazıldı');
insert into public.parent_training_modules (id, training_id, item_key, position) values
  ('00000000-0000-0000-0000-0000000071a1', '00000000-0000-0000-0000-0000000070a1', 'abc_r', 0),
  ('00000000-0000-0000-0000-0000000071a2', '00000000-0000-0000-0000-0000000070a1', 'abc_q', 1);
insert into public.parent_training_tasks (id, training_id, title, measure) values
  ('00000000-0000-0000-0000-0000000072a1', '00000000-0000-0000-0000-0000000070a1', 'ABC kaydı', 'frequency'),
  ('00000000-0000-0000-0000-0000000072a2', '00000000-0000-0000-0000-0000000070a1', 'Geçiş uyarısı', 'accuracy');
insert into public.parent_training_todos (id, training_id, title, done_at) values
  ('00000000-0000-0000-0000-0000000073a1', '00000000-0000-0000-0000-0000000070a1', 'Zamanlayıcı hazırla', now());
select tst.check((select done_at from public.parent_training_todos where id = '00000000-0000-0000-0000-0000000073a1') is null, 'uzman yapılacağı tamamlanmış ekleyemez');
insert into public.parent_training_data (training_id, day, value) values ('00000000-0000-0000-0000-0000000070a1', current_date, 60);

-- 2. taslağı aile görmez, bildirim yok
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.parent_trainings) = 0, 'taslak eğitimi aile görmez');
select tst.check(jsonb_array_length(public.family_trainings()) = 0, 'family_trainings taslağı döndürmez');
do $$ begin
  perform public.family_training_module_complete('00000000-0000-0000-0000-0000000071a1');
  raise exception 'TEST BAŞARISIZ: taslakta modül tamamlandı';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: taslakta modül tamamlanamaz'; end $$;

-- 3. Etkin → anneye bildirim (babaya değil)
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
update public.parent_trainings set status = 'active' where id = '00000000-0000-0000-0000-0000000070a1';
reset role;
select tst.check((select count(*) from public.notifications where kind = 'training_assigned' and user_id = '00000000-0000-0000-0000-0000000000a1') = 1, 'Etkin olunca anneye bildirim');
select tst.check((select count(*) from public.notifications where kind = 'training_assigned' and user_id = '00000000-0000-0000-0000-0000000000a2') = 0, 'babaya bildirim yok (anneye atandı)');
select tst.check((select activated_at from public.parent_trainings where id = '00000000-0000-0000-0000-0000000070a1') is not null, 'etkinleşme zamanı yazıldı');
set role authenticated;

-- 4. anne görür ve işlem yapar
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(jsonb_array_length(public.family_trainings()) = 1 and (public.family_trainings()->0->>'mine')::boolean, 'anne eğitimini görür (mine)');
select tst.check(jsonb_array_length(public.family_trainings()->0->'modules') = 2 and jsonb_array_length(public.family_trainings()->0->'tasks') = 2, 'modüller ve görevler gelir');
select tst.check((select count(*) from public.parent_training_data) = 0, 'gözlem verisini aile görmez');
select public.family_training_module_complete('00000000-0000-0000-0000-0000000071a1');
select public.family_training_module_complete('00000000-0000-0000-0000-0000000071a2', '[{"pick":1},{"pick":0},{"pick":2}]', 2, 3);
select tst.check((select correct from public.parent_training_modules where id = '00000000-0000-0000-0000-0000000071a2') = 2, 'test doğru sayısı yazıldı');
select public.family_training_module_complete('00000000-0000-0000-0000-0000000071a2', '[{"pick":0}]', 0, 3);
select tst.check((select correct from public.parent_training_modules where id = '00000000-0000-0000-0000-0000000071a2') = 2, 'tamamlanmış modül yeniden yazılmaz');
select public.family_training_log('00000000-0000-0000-0000-0000000072a1', null, 3, null, null, null, 'Akşam iki kez');
select public.family_training_log('00000000-0000-0000-0000-0000000072a2', null, null, 2, 3, null, '');
select tst.check((select count(*) from public.parent_training_logs) = 2, 'anne iki kayıt girdi ve görür');
do $$ begin
  perform public.family_training_log('00000000-0000-0000-0000-0000000072a2', null, null, 4, 3, null, '');
  raise exception 'TEST BAŞARISIZ: başarılı > deneme kabul edildi';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: başarılı deneme toplamı aşamaz'; end $$;
do $$ begin
  perform public.family_training_log('00000000-0000-0000-0000-0000000072a1', current_date - 30, 1, null, null, null, '');
  raise exception 'TEST BAŞARISIZ: 30 gün önceye kayıt girildi';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: 14 günden eskiye kayıt yok'; end $$;
do $$ begin
  perform public.family_training_log('00000000-0000-0000-0000-0000000072a1', null, null, null, null, null, '');
  raise exception 'TEST BAŞARISIZ: sıklık görevine sayısız kayıt girildi';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: sıklık görevinde sayı zorunlu'; end $$;
select public.family_training_todo_set('00000000-0000-0000-0000-0000000073a1', true, 2, 'Biraz zorlandık');
select tst.check((select rating from public.parent_training_todos where id = '00000000-0000-0000-0000-0000000073a1') = 2, 'yapılacak puanı ve düşüncesi yazıldı');
select tst.check((select done_at from public.parent_training_todos where id = '00000000-0000-0000-0000-0000000073a1') is not null, 'anne yapılacağı işaretledi');
do $$ begin
  update public.parent_training_modules set completed_at = null;
  if exists (select 1 from public.parent_training_modules where completed_at is null) then raise exception 'TEST BAŞARISIZ: aile tabloya yazdı'; end if;
  raise notice 'ok: aile tabloya doğrudan yazamaz';
end $$;

-- 5. baba görür ama işlem yapamaz (anneye atanmış)
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(jsonb_array_length(public.family_trainings()) = 1 and not (public.family_trainings()->0->>'mine')::boolean, 'baba eğitimi görür, kendisine değil');
do $$ begin
  perform public.family_training_todo_set('00000000-0000-0000-0000-0000000073a1', false);
  raise exception 'TEST BAŞARISIZ: baba anneninkini değiştirdi';
exception when others then if sqlerrm like 'TEST%' then raise; end if; raise notice 'ok: öteki ebeveyn işlem yapamaz'; end $$;

-- 6. başka aile ve başka klinik görmez
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check(jsonb_array_length(public.family_trainings()) = 0 and (select count(*) from public.parent_trainings) = 0, 'başka aile görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.parent_trainings) = 0 and (select count(*) from public.parent_training_logs) = 0, 'başka klinik görmez');
select tst.check((select count(*) from public.clinic_link_parents('00000000-0000-0000-0000-0000000011a1')) = 0, 'başka klinik ebeveyn listesini göremez');

-- 7. uzman ebeveynin kayıtlarını görür, tamamlamayı değiştiremez; başka ailenin ebeveynini atayamaz
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.parent_training_logs) = 2 and (select count(*) from public.parent_training_modules where completed_at is not null) = 2, 'uzman kayıtları ve tamamlamaları görür');
do $$ begin
  update public.parent_training_modules set completed_at = null where id = '00000000-0000-0000-0000-0000000071a1';
  raise exception 'TEST BAŞARISIZ: uzman tamamlamayı sildi';
exception when check_violation then raise notice 'ok: uzman tamamlamayı değiştiremez'; end $$;
do $$ begin
  insert into public.parent_trainings (clinic_id, link_id, parent_id) values
    (public.my_clinic_id(), '00000000-0000-0000-0000-0000000011a1', '00000000-0000-0000-0000-0000000000b1');
  raise exception 'TEST BAŞARISIZ: başka ailenin ebeveynine eğitim';
exception when check_violation then raise notice 'ok: yalnız o ailenin ebeveynine atanır'; end $$;
update public.parent_training_modules set reviewed_at = now() where id = '00000000-0000-0000-0000-0000000071a1';
select tst.check((select reviewed_at from public.parent_training_modules where id = '00000000-0000-0000-0000-0000000071a1') is not null, 'uzman modülü incelendi işaretler');
select tst.check(public.clinic_training_remind('00000000-0000-0000-0000-0000000070a1'), 'hatırlatma gönderildi');
select tst.check(not public.clinic_training_remind('00000000-0000-0000-0000-0000000070a1'), 'hatırlatma 12 saatte bir');
update public.parent_trainings set status = 'mastered' where id = '00000000-0000-0000-0000-0000000070a1';
reset role;
select tst.check((select count(*) from public.notifications where kind = 'training_activity' and user_id = '00000000-0000-0000-0000-0000000000d1') = 5, 'uzmana ebeveyn etkinliği bildirimi (2 modül, 2 kayıt, 1 yapılacak)');
select tst.check((select count(*) from public.notifications where kind = 'training_reminder' and user_id = '00000000-0000-0000-0000-0000000000a1') = 1, 'hatırlatma anneye gitti');
select tst.check((select count(*) from public.notifications where kind = 'training_mastered') = 1, 'Ustalaştı bildirimi');

-- 8. paylaşım bitince aile ve uzman görmez
update public.clinic_links set status = 'revoked', revoked_at = now() where id = '00000000-0000-0000-0000-0000000011a1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(jsonb_array_length(public.family_trainings()) = 0, 'paylaşım bitince aile eğitimi görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.parent_training_logs) = 0, 'paylaşım bitince uzman kayıtları görmez');
reset role;
