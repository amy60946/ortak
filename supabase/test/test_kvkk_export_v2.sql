-- "Verimi indir" kapsamı (proposed/20261110120000_kvkk_export_v2.sql): ebeveyn dersleri, ebeveyn eğitimi, davranış olayları,
-- tanışma yanıtları, ebeveyn görevleri/taşı, hediyeler, haftalık hedef, hatırlatma, şablon, misafir geçişi, davet ödülü, açılış
-- günleri. Diğer ebeveynin yazdıkları ayıklanır (sayı); eğitim/olay tabloları yoksa da döküm çalışır.
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
create table if not exists tst.kv (k text primary key, v jsonb);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated, anon;

-- a1 anne, a2 baba (aynı aile), b1 komşu (başka aile), d1 uzman
insert into auth.users (id, is_anonymous, email, raw_user_meta_data, created_at, last_sign_in_at) values
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000a2', false, 'baba@example.com', '{"nickname":"Baba"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000b1', false, 'komsu@example.com', '{"nickname":"Komşu"}', now(), now()),
  ('00000000-0000-0000-0000-0000000000d1', false, 'uzman@example.com', '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}', now(), now());
update public.profiles set family_id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1')
 where id = '00000000-0000-0000-0000-0000000000a2';
insert into tst.kv values
  ('fam', to_jsonb((select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'))),
  ('komsu', to_jsonb((select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b1')));
create or replace function tst.fam() returns uuid language sql as $$ select (v #>> '{}')::uuid from tst.kv where k = 'fam' $$;
create or replace function tst.komsu() returns uuid language sql as $$ select (v #>> '{}')::uuid from tst.kv where k = 'komsu' $$;
grant execute on function tst.fam(), tst.komsu() to authenticated;
insert into public.children (id, family_id, name, avatar)
values ('00000000-0000-0000-0000-00000000c001', tst.fam(), 'Efe', 'bear');
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, tst.fam(), '00000000-0000-0000-0000-00000000c001',
       '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m where m.id = '00000000-0000-0000-0000-0000000000d1';

-- Kayıtlar doğrudan yazılır (sunucu korumaları bu dosyanın konusu değil; ilgili testlerde denetlenir)
set session_replication_role = replica;
insert into public.parent_lessons (key, title, status) values ('sakin_kal', 'Sakin kalmak', 'published');
insert into public.parent_lesson_progress (user_id, lesson_key, family_id) values
  ('00000000-0000-0000-0000-0000000000a1', 'sakin_kal', tst.fam()), ('00000000-0000-0000-0000-0000000000a2', 'sakin_kal', tst.fam());
insert into public.parent_lesson_practice (user_id, lesson_key, family_id, day) values
  ('00000000-0000-0000-0000-0000000000a1', 'sakin_kal', tst.fam(), current_date),
  ('00000000-0000-0000-0000-0000000000a2', 'sakin_kal', tst.fam(), current_date);

insert into public.parent_trainings (id, clinic_id, link_id, parent_id, title, status)
select t.id, m.clinic_id, '00000000-0000-0000-0000-0000000011a1', t.parent_id, t.title, 'active'
  from public.clinicians m,
       (values ('00000000-0000-0000-0000-0000000070a1'::uuid, '00000000-0000-0000-0000-0000000000a1'::uuid, 'Annenin eğitimi'),
               ('00000000-0000-0000-0000-0000000070a2'::uuid, '00000000-0000-0000-0000-0000000000a2'::uuid, 'Babanın eğitimi')) t(id, parent_id, title)
 where m.id = '00000000-0000-0000-0000-0000000000d1';
insert into public.parent_training_modules (training_id, item_key, position, completed_at, completed_by, answers) values
  ('00000000-0000-0000-0000-0000000070a1', 'abc_q', 0, now(), '00000000-0000-0000-0000-0000000000a1', '[{"q":"1","a":"annenin yanıtı"}]'),
  ('00000000-0000-0000-0000-0000000070a2', 'abc_q', 0, now(), '00000000-0000-0000-0000-0000000000a2', '[{"q":"1","a":"babanın yanıtı"}]'),
  ('00000000-0000-0000-0000-0000000070a1', 'abc_r', 1, null, null, null);
insert into public.parent_training_tasks (id, training_id, title, measure) values
  ('00000000-0000-0000-0000-0000000072a1', '00000000-0000-0000-0000-0000000070a1', 'ABC kaydı', 'frequency'),
  ('00000000-0000-0000-0000-0000000072a2', '00000000-0000-0000-0000-0000000070a2', 'ABC kaydı', 'frequency');
insert into public.parent_training_logs (task_id, training_id, family_id, day, count, reflection, created_by) values
  ('00000000-0000-0000-0000-0000000072a1', '00000000-0000-0000-0000-0000000070a1', tst.fam(), current_date, 2, 'annenin günlüğü', '00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000072a2', '00000000-0000-0000-0000-0000000070a2', tst.fam(), current_date, 3, 'babanın günlüğü', '00000000-0000-0000-0000-0000000000a2');
insert into public.parent_training_todos (training_id, title, done_at, done_by, reflection) values
  ('00000000-0000-0000-0000-0000000070a1', 'Zamanlayıcı', now(), '00000000-0000-0000-0000-0000000000a1', 'anne hazırladı'),
  ('00000000-0000-0000-0000-0000000070a2', 'Zamanlayıcı', now(), '00000000-0000-0000-0000-0000000000a2', 'baba hazırladı');

insert into public.clinic_target_behaviors (id, clinic_id, link_id, title)
select '00000000-0000-0000-0000-0000000080a1', clinic_id, '00000000-0000-0000-0000-0000000011a1', 'Bağırma'
  from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into public.behavior_incidents (link_id, family_id, child_id, behavior_id, log_type, occurred_at, count, antecedent, reporter_id, reporter_name) values
  ('00000000-0000-0000-0000-0000000011a1', tst.fam(), '00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000080a1',
   'frequency', now(), 1, 'annenin bildirdiği olay', '00000000-0000-0000-0000-0000000000a1', 'Anne'),
  ('00000000-0000-0000-0000-0000000011a1', tst.fam(), '00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000080a1',
   'frequency', now(), 1, 'babanın bildirdiği olay', '00000000-0000-0000-0000-0000000000a2', 'Baba');

insert into public.intake_answers (family_id, user_id, child_id, question_key, answer, version) values
  (tst.fam(), '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000c001', 'uyku', '["annenin cevabı"]', 'v1'),
  (tst.fam(), '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000c001', 'uyku', '["babanın cevabı"]', 'v1');
insert into public.parent_assignments (task_id, user_id, family_id, difficulty) values
  ('00000000-0000-0000-0000-0000000090a1', '00000000-0000-0000-0000-0000000000a1', tst.fam(), 'easy'),
  ('00000000-0000-0000-0000-0000000090a2', '00000000-0000-0000-0000-0000000000a2', tst.fam(), 'easy');
insert into public.parent_completions (task_id, user_id, date, family_id) values
  ('00000000-0000-0000-0000-0000000090a1', '00000000-0000-0000-0000-0000000000a1', current_date, tst.fam()),
  ('00000000-0000-0000-0000-0000000090a2', '00000000-0000-0000-0000-0000000000a2', current_date, tst.fam());
insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref) values
  (tst.fam(), '00000000-0000-0000-0000-0000000000a1', 1, 'lesson', 'sakin_kal'), (tst.fam(), '00000000-0000-0000-0000-0000000000a2', 1, 'task', 'gorev');
insert into public.child_gifts (family_id, child_id, item_id, from_user, from_name, note, stones) values
  (tst.fam(), '00000000-0000-0000-0000-00000000c001', 'hat', '00000000-0000-0000-0000-0000000000a1', 'Anne', 'anneden sevgiyle', 3),
  (tst.fam(), '00000000-0000-0000-0000-00000000c001', 'kite', '00000000-0000-0000-0000-0000000000a2', 'Babacık', 'babanın gizli notu', 2);
insert into public.child_goal_settings (child_id, family_id, weekly_cap) values ('00000000-0000-0000-0000-00000000c001', tst.fam(), 20);
insert into public.task_boosts (child_id, task_id, date, family_id, choice) values
  ('00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-0000000090a1', current_date, tst.fam(), 'accepted');
insert into public.saved_templates (family_id, template_key, created_by) values (tst.fam(), 'dis_fircala', '00000000-0000-0000-0000-0000000000a1');
insert into public.guest_passes (code, family_id, created_by, redeemed_family, redeemed_at) values
  ('ANNE2345', tst.fam(), '00000000-0000-0000-0000-0000000000a1', tst.komsu(), now()),
  ('KOMSU234', tst.komsu(), '00000000-0000-0000-0000-0000000000b1', tst.fam(), now());
insert into public.referral_rewards (family_id, pass_code, status, days) values (tst.fam(), 'ANNE2345', 'applied', 30);
insert into public.activity_days (user_id, app, day) values
  ('00000000-0000-0000-0000-0000000000a1', 'parent', current_date), ('00000000-0000-0000-0000-0000000000a2', 'parent', current_date);
set session_replication_role = origin;

-- --- anne ---------------------------------------------------------------------------------------------------------
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('anne', public.my_data_export());
reset role;
create or replace function tst.e(k text) returns jsonb language sql as $$ select v from tst.kv where kv.k = e.k $$;
select tst.check(tst.e('anne') #>> '{ebeveyn_dersleri,dersler,0,baslik}' = 'Sakin kalmak'
                 and jsonb_array_length(tst.e('anne') #> '{ebeveyn_dersleri,dersler}') = 1
                 and jsonb_array_length(tst.e('anne') #> '{ebeveyn_dersleri,uygulama_gunleri}') = 1, 'ebeveyn dersleri: yalnız kendi dersi ve uygulama günü');
select tst.check(jsonb_array_length(tst.e('anne') #> '{ebeveyn_egitimi,moduller}') = 1
                 and (tst.e('anne') -> 'ebeveyn_egitimi')::text like '%annenin yanıtı%', 'eğitim: kendi tamamladığı modül ve yanıtı');
select tst.check(jsonb_array_length(tst.e('anne') #> '{ebeveyn_egitimi,uygulama_kayitlari}') = 1
                 and jsonb_array_length(tst.e('anne') #> '{ebeveyn_egitimi,yapilacaklar}') = 1, 'eğitim: kendi uygulama kaydı ve yapılacağı');
select tst.check(jsonb_array_length(tst.e('anne') -> 'davranis_olaylari') = 1
                 and (tst.e('anne') #>> '{ayiklanan,diger_ebeveynin_davranis_olaylari}')::int = 1, 'davranış olayı: kendi bildirdiği, ötekinin sayısı');
select tst.check(jsonb_array_length(tst.e('anne') -> 'tanisma_yanitlari') = 1
                 and (tst.e('anne') #>> '{ayiklanan,diger_ebeveynin_tanisma_yanitlari}')::int = 1, 'tanışma yanıtı: kendisininki, ötekinin sayısı');
select tst.check(jsonb_array_length(tst.e('anne') -> 'ebeveyn_gorevleri') = 1 and jsonb_array_length(tst.e('anne') -> 'ebeveyn_tamamlamalari') = 1
                 and jsonb_array_length(tst.e('anne') -> 'ebeveyn_tasi_defteri') = 1, 'ebeveyn görevi, Yaptım ve taş cüzdanı: yalnız kendi');
select tst.check(jsonb_array_length(tst.e('anne') -> 'hediyeler') = 2 and (tst.e('anne') -> 'hediyeler')::text like '%anneden sevgiyle%'
                 and (tst.e('anne') -> 'hediyeler')::text like '%diğer ebeveyn%'
                 and (tst.e('anne') #>> '{ayiklanan,diger_ebeveynin_hediye_notlari}')::int = 1, 'hediyeler: ikisi de var, ötekinin notu ve adı ayıklandı');
select tst.check(tst.e('anne')::text not like '%babanın%' and tst.e('anne')::text not like '%baba hazırladı%'
                 and tst.e('anne')::text not like '%Babacık%' and tst.e('anne')::text not like '%baba@example.com%', 'babanın yazdığı hiçbir metin annenin dökümünde yok');
select tst.check(jsonb_array_length(tst.e('anne') -> 'haftalik_hedef_ayarlari') = 1 and jsonb_array_length(tst.e('anne') -> 'gorev_hatirlatmalari') = 1
                 and jsonb_array_length(tst.e('anne') -> 'kayitli_sablonlar') = 1 and jsonb_array_length(tst.e('anne') -> 'davet_odulleri') = 1, 'hedef ayarı, hatırlatma, şablon, davet ödülü');
select tst.check((tst.e('anne') #>> '{misafir_gecisleri,0,kullanildi}')::boolean and not (tst.e('anne') -> 'misafir_gecisleri' -> 0 ? 'redeemed_family')
                 and tst.e('anne') #>> '{kullanilan_misafir_gecisi,0,kod}' = 'KOMSU234'
                 and tst.e('anne')::text not like '%' || tst.komsu() || '%'
                 and tst.e('anne')::text not like '%00000000-0000-0000-0000-0000000000b1%', 'misafir geçişi: öteki ailenin ve kişinin kimliği yok');
select tst.check(jsonb_array_length(tst.e('anne') #> '{kullanim,acilis_gunleri}') = 1, 'açılış günleri: yalnız kendi');
select tst.check(not (tst.e('anne')::text like '%"family_id"%'), 'aile kimliği satırlarda tekrar edilmez');

-- --- baba, komşu, uzman --------------------------------------------------------------------------------------------
insert into tst.kv values ('baba', public.data_export_of('00000000-0000-0000-0000-0000000000a2')),
                          ('komsu_e', public.data_export_of('00000000-0000-0000-0000-0000000000b1')),
                          ('uzman', public.data_export_of('00000000-0000-0000-0000-0000000000d1'));
select tst.check((tst.e('baba') -> 'ebeveyn_egitimi')::text like '%babanın yanıtı%' and tst.e('baba')::text not like '%annenin%'
                 and (tst.e('baba') #>> '{ayiklanan,diger_ebeveynin_davranis_olaylari}')::int = 1, 'baba: kendi kayıtları, annenin metni yok');
select tst.check(jsonb_array_length(tst.e('komsu_e') #> '{ebeveyn_dersleri,dersler}') = 0 and jsonb_array_length(tst.e('komsu_e') -> 'hediyeler') = 0
                 and jsonb_array_length(tst.e('komsu_e') -> 'davranis_olaylari') = 0
                 and tst.e('komsu_e') #>> '{kullanilan_misafir_gecisi,0,kod}' = 'ANNE2345'
                 and tst.e('komsu_e')::text not like '%' || tst.fam() || '%', 'komşu: başka ailenin kaydı ve kimliği yok');
select tst.check(not (tst.e('uzman') ? 'ebeveyn_egitimi') and not (tst.e('uzman') ? 'davranis_olaylari') and not (tst.e('uzman') ? 'hediyeler'),
                 'uzman dökümünde aile bölümleri yok');

-- --- eğitim ve olay tabloları henüz yoksa (öneriler uygulanmadan) -----------------------------------------------------
drop table public.behavior_incidents, public.parent_training_todos, public.parent_training_logs, public.parent_training_modules cascade;
insert into tst.kv values ('eski', public.data_export_of('00000000-0000-0000-0000-0000000000a1'));
select tst.check(not (tst.e('eski') ? 'ebeveyn_egitimi') and not (tst.e('eski') ? 'davranis_olaylari')
                 and not (tst.e('eski') -> 'ayiklanan' ? 'diger_ebeveynin_davranis_olaylari')
                 and jsonb_array_length(tst.e('eski') #> '{ebeveyn_dersleri,dersler}') = 1, 'tablolar yokken döküm çalışır, bölümler yazılmaz');
