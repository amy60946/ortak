-- Saldırgan gözüyle tarama düzeltmeleri (20261022140000_whitehat_fixes.sql).
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
-- Hata metnini döndürür (hata yoksa null)
create or replace function tst.err(sql text) returns text language plpgsql as $$
begin
  execute sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, '{"account":"clinician","name":"Dr. Can"}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, requires_review) values
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Diş', current_date - 30, true, false);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'easy', 50);
insert into tst.kv select 'k', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.fails($$update public.profiles set nickname = repeat('x', 41) where id = auth.uid()$$, 'takma ad 40 karakteri aşamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k'));

-- H1: doğrudan INSERT ile coin basılamaz
select tst.fails($$insert into public.completions (family_id, task_id, child_id, date, status)
  values (public.my_any_family_id(), '00000000-0000-0000-0000-000000007a52', public.my_child_id(), '2000-01-01', 'approved')$$, 'çocuk tamamlamayı doğrudan ekleyemez');
select public.child_set_status('00000000-0000-0000-0000-000000007a52', current_date, 'pending');
select tst.check(public.child_balance(public.my_child_id()) = 50, 'yalnız izinli günler coin verdi');

-- L1: push anahtarı en çok 5
select public.register_push_token('tok-' || x || '-abcdefgh', 'child', 'ios') from generate_series(1, 8) x;
select tst.check((select count(*) from public.push_tokens) = 5, 'kullanıcı başına 5 push anahtarı');

-- L6: hedefi başkası adına yazamaz
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
reset role;
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-00000000111a', c.clinic_id, c.id, ch.family_id, ch.id, '00000000-0000-0000-0000-0000000000a1'
    from public.clinicians c, public.children ch where c.id = '00000000-0000-0000-0000-0000000000d1';
set role authenticated;
insert into public.clinic_goals (id, link_id, clinic_id, title, created_by)
  values ('00000000-0000-0000-0000-00000000600a', '00000000-0000-0000-0000-00000000111a', public.my_clinic_id(), 'Hedef', '00000000-0000-0000-0000-0000000000d2');
select tst.check((select created_by from public.clinic_goals) = '00000000-0000-0000-0000-0000000000d1', 'hedefi yazan sunucuda oturumdaki uzman');
select tst.fails($$update public.clinic_links set clinician_id = '00000000-0000-0000-0000-0000000000d2'$$, 'sorumlu uzman başka klinikten seçilemez');

-- L7
select tst.fails($$select public.redeem_child_code('ABCDEF')$$, 'uzman çocuk kodu kullanamaz');

reset role;
select tst.check(not exists (select 1 from pg_policies where tablename = 'completions' and policyname = 'tamamlama: çocuk işaretler'), 'çocuk ekleme politikası yok');
select 'TARAMA DÜZELTMELERİ GEÇTİ' as sonuc;
