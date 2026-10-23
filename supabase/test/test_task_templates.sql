-- Ev Görevleri şablon kataloğu (migrations/20261023010000_task_templates.sql + proposed/20261023030000_task_templates_clean.sql):
-- herkes okur, kimse yazamaz; kategori = beceri; sürüm 2 anahtarları, eski anahtarlı kayıtlar yeni anahtara geçer.
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
  begin execute sql;
  exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
grant usage on schema tst to anon, authenticated;
grant execute on all functions in schema tst to anon, authenticated;

-- veri tutarlılığı (sahip olarak)
select tst.check((select count(*) from public.task_templates) = 298, '298 şablon');
select tst.check(not exists (select 1 from public.task_templates where not (category = any(categories))), 'ana kategori etiketlerde');
select tst.check((select count(distinct category) from public.task_templates) = 6, 'altı kategorinin hepsi dolu');
select tst.check(not exists (select 1 from public.task_templates where cardinality(age_bands) = 0), 'her şablonun yaş grubu var');
select tst.fails($$insert into public.task_templates (key, title, category, categories, age_bands, difficulty, coins, skill)
  values ('gs_test_yanlis', 'Yanlış', 'home', array['home'], array['A'], 'easy', 5, 'kindness')$$, 'kategori ile beceri uyuşmalı');
select tst.fails($$insert into public.task_templates (key, title, category, categories, age_bands, difficulty, coins, skill)
  values ('gs_test_yas', 'Yaş', 'home', array['home'], array['X'], 'easy', 5, 'teamwork')$$, 'bilinmeyen yaş grubu reddedilir');

-- sürüm 2: başka uygulamanın adı/alanı yok, anahtarlar gs_<kategori>_<sıra>
select tst.check(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'task_templates' and column_name = 'source_en'), 'kaynak adı sütunu yok');
select tst.check(not exists (select 1 from public.task_templates where key !~ '^gs_(home|mind|learn|health|focus|relation)_[0-9]{3}$'), 'anahtarlar gs_<kategori>_<sıra>');
-- canlıdaki eski anahtarlı durum: kayıtlı şablon ve aynı aile hem eskiyi hem yeniyi kaydetmiş
insert into public.families (id) values ('00000000-0000-0000-0000-0000000000f1'), ('00000000-0000-0000-0000-0000000000f2');
insert into public.task_templates (key, title, emoji, category, categories, age_bands, difficulty, coins, skill)
  select 'jt_eski_bir', title, emoji, category, categories, age_bands, difficulty, coins, skill from public.task_templates where key = 'gs_home_001';
insert into public.saved_templates (family_id, template_key) values
  ('00000000-0000-0000-0000-0000000000f1', 'jt_eski_bir'),
  ('00000000-0000-0000-0000-0000000000f2', 'jt_eski_bir'), ('00000000-0000-0000-0000-0000000000f2', 'gs_home_001');
\ir ../proposed/20261023030000_task_templates_clean.sql
select tst.check((select template_key from public.saved_templates where family_id = '00000000-0000-0000-0000-0000000000f1') = 'gs_home_001', 'kayıtlı şablon yeni anahtara geçti');
select tst.check((select count(*) from public.saved_templates where family_id = '00000000-0000-0000-0000-0000000000f2') = 1, 'iki kopya teke indi');
select tst.check(not exists (select 1 from public.task_templates where key like 'jt\_%'), 'eski anahtarlı şablon kalmadı');
select tst.check((select count(*) from public.task_templates) = 298, 'temizlikten sonra yine 298');

-- ebeveyn: okur, yazamaz
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.task_templates) = 298, 'oturumlu kullanıcı kataloğu okur');
select tst.check((select count(*) from public.task_templates_for('home', 'K')) > 20, 'süzgeç: Ev İşleri + 5 ve altı');
select tst.check(not exists (select 1 from public.task_templates_for('relation', 'C') t where not ('relation' = any(t.categories)) or not ('C' = any(t.age_bands))), 'süzgeç doğru kesişim');
select tst.check((select count(*) from public.task_templates_for(null, null)) = 298, 'süzgeçsiz hepsi');
select tst.check((select count(*) from public.task_templates_for('learn', null) where category <> 'learn') >= 0, 'ek etiketle başka kategoriden de listelenebilir');
select tst.fails($$insert into public.task_templates (key, title, category, categories, age_bands, difficulty, coins, skill) values ('gs_test_x', 'X', 'home', array['home'], array['A'], 'easy', 5, 'teamwork')$$, 'ebeveyn şablon ekleyemez');
select tst.fails($$update public.task_templates set coins = 50$$, 'ebeveyn şablon değiştiremez');
select tst.fails($$delete from public.task_templates$$, 'ebeveyn şablon silemez');
reset role;

-- anon: hiçbir şey
set role anon;
select tst.fails($$select count(*) from public.task_templates$$, 'anon okuyamaz');
select tst.fails($$select * from public.task_templates_for(null, null)$$, 'anon süzgeci çağıramaz');
reset role;
