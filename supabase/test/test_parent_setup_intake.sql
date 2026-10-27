-- ParentApp ilk kurulum ve tanışma soruları (proposed/20261027120000_parent_setup_intake.sql)
\set ON_ERROR_STOP on
create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', '{"aal":"aal1"}', false);
end $$;
create or replace function tst.as_mfa(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', '{"aal":"aal2"}', false);
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
create or replace function tst.v(key text) returns uuid language sql as $$ select v::uuid from tst.kv where k = key $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- a1 + a3 aynı aile (Anne, Baba), a2 başka aile; f1 support admin
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com', '{"nickname":"Anne","name":"Ayşe"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, 'diger@example.com', '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000f1', false, 'destek@example.com', '{"nickname":"Destek"}');
insert into tst.kv select 'fam', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a3', false, 'baba@example.com', '{"nickname":"Baba"}');
update public.profiles set family_id = tst.v('fam')
 where id = '00000000-0000-0000-0000-0000000000a3';
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', tst.v('fam'), 'Efe', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a2'), 'Başka', 'kedi');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f1', 'support');

-- ---------------------------------------------------------------- kurulum durumu
select tst.check((select setup_completed_at is null from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'),
  'yeni ebeveynde kurulum bitmemiş');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.parent_setup_complete() is not null, 'kurulum bitti olarak yazıldı');
select tst.check((select setup_completed_at is not null from public.profiles where id = auth.uid()), 'profil okunur');
select tst.fails($$update public.profiles set setup_completed_at = null where id = auth.uid()$$, 'alan istemciden değişmez');
reset role;

-- ---------------------------------------------------------------- yanıtlar
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.intake_answers (question_key, answer) values ('main_goal', '["motivation"]');
insert into public.intake_answers (child_id, question_key, answer) values ('00000000-0000-0000-0000-00000000c001', 'child_routine', '["struggle"]');
-- PostgREST upsert ile aynı: kişi + çocuk + soru tek satır
insert into public.intake_answers (question_key, answer) values ('main_goal', '["structure"]')
  on conflict (user_id, child_id, question_key) do update set answer = excluded.answer;
select tst.check((select count(*) from public.intake_answers where question_key = 'main_goal') = 1, 'aynı soru tek satır (çocuksuz)');
select tst.check((select answer from public.intake_answers where question_key = 'main_goal') = '["structure"]', 'yanıt güncellendi');
select tst.check((select family_id from public.intake_answers where question_key = 'main_goal') = public.my_family_id(), 'aile kimliği sunucudan');
select tst.fails($$insert into public.intake_answers (child_id, question_key, answer) values ('00000000-0000-0000-0000-00000000c002', 'child_routine', '["yes"]')$$,
  'başka ailenin çocuğuna yanıt yazılamaz');
select tst.fails($$insert into public.intake_answers (question_key, answer) values ('main_goal2', '["Büyük harf"]')$$, 'seçenek biçimi denetlenir');
select tst.fails($$insert into public.intake_answers (question_key, answer) values ('x', '[]')$$, 'boş yanıt ve kısa anahtar reddedilir');
select tst.fails($$insert into public.intake_answers (child_id, question_key, answer) values ('00000000-0000-0000-0000-00000000c001', 'child_diagnosis', '["adhd"]')$$,
  'sağlık yanıtı onaysız reddedilir');
insert into public.intake_answers (child_id, question_key, answer) values ('00000000-0000-0000-0000-00000000c001', 'child_medication', '["prefer_not"]');
insert into public.intake_answers (child_id, question_key, answer, consent_version)
  values ('00000000-0000-0000-0000-00000000c001', 'child_diagnosis', '["adhd"]', 'saglik-yanit-v1');
select tst.check((select consent_version from public.intake_answers where question_key = 'child_diagnosis') = 'saglik-yanit-v1', 'rıza sürümü kaydedildi');
-- diğer ebeveyn okur ama değiştiremez
select tst.as_user('00000000-0000-0000-0000-0000000000a3');
select tst.check((select count(*) from public.intake_answers) = 4, 'aynı ailedeki ebeveyn okur');
update public.intake_answers set answer = '["no"]' where question_key = 'child_routine';
select tst.check((select answer from public.intake_answers where question_key = 'child_routine') = '["struggle"]', 'başkasının yanıtı değişmez');
delete from public.intake_answers where question_key = 'child_routine';
select tst.check((select count(*) from public.intake_answers) = 4, 'başkasının yanıtı silinmez');
insert into public.intake_answers (question_key, answer) values ('main_goal', '["relationship"]');
select tst.check((select count(*) from public.intake_answers where question_key = 'main_goal') = 2, 'her ebeveynin kendi yanıtı');
-- başka aile göremez
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check((select count(*) from public.intake_answers) = 0, 'başka aile göremez');
-- kimliği taşıma girişimi: sunucu ezer
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
update public.intake_answers set user_id = '00000000-0000-0000-0000-0000000000a2', child_id = null where question_key = 'child_routine';
select tst.check((select user_id from public.intake_answers where question_key = 'child_routine') = '00000000-0000-0000-0000-0000000000a1'
  and (select child_id from public.intake_answers where question_key = 'child_routine') is not null, 'kimlik ve çocuk değişmez');
reset role;

-- ---------------------------------------------------------------- yönetim paneli
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.admin_intake(tst.v('fam'), 'deneme')$$, 'ebeveyn admin işlevini çağıramaz');
select tst.as_user('00000000-0000-0000-0000-0000000000f1');
select tst.fails($$select public.admin_intake(tst.v('fam'), 'deneme')$$, 'iki adımlı doğrulama gerekli');
select tst.as_mfa('00000000-0000-0000-0000-0000000000f1');
select tst.fails($$select public.admin_intake(tst.v('fam'), '')$$, 'gerekçe zorunlu');
select tst.check(json_array_length(public.admin_intake(tst.v('fam'), 'destek talebi')) = 5,
  'kişi bazlı yanıtlar');
select tst.check(exists (select 1 from json_array_elements(public.admin_intake(tst.v('fam'), 'destek talebi')) e
  where e ->> 'member' = 'Ayşe' and e ->> 'question' = 'main_goal'), 'yanıtlayan kişi görünür');
select tst.check(json_array_length(public.admin_intake_summary(30)) >= 4, 'özet yalnız sayılar');
reset role;
select tst.check((select count(*) from public.admin_audit where action = 'intake.view') = 2, 'her açılış denetim kaydında');
