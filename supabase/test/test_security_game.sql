-- C1 (proposed/20261022110000_security_game.sql): çocuk completions'a doğrudan yazamaz; RPC yolu çalışır.
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
create or replace function tst.no_effect(sql text, msg text) returns void language plpgsql as $$
declare n integer;
begin
  begin
    execute sql;
    get diagnostics n = row_count;
  exception when others then
    raise notice 'ok (reddedildi): % → %', msg, sqlerrm;
    return;
  end;
  if n > 0 then raise exception 'TEST BAŞARISIZ (% satır değişti): %', n, msg; end if;
  raise notice 'ok (etkisiz): %', msg;
end $$;
create or replace function tst.bal(c uuid) returns integer language sql security definer as $$ select public.coin_balance(c) $$;
create or replace function tst.stones(c uuid) returns integer language sql security definer as $$
  select coalesce(sum(amount), 0)::integer from public.sun_stone_ledger where child_id = c $$;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}');
grant usage on schema tst to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deniz', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Oda topla', current_date - 30, true, 'daily', false);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'hard', 50);
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
grant select on codes to authenticated;
create temp table fam as select public.my_family_id() as id;
grant select on fam to authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select code from codes));

-- Saldırı: geçmiş 20 güne doğrudan "approved" yazmak
select tst.fails($$insert into public.completions (family_id, task_id, child_id, date, status)
  select (select id from fam), '00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date - g, 'approved'
  from generate_series(2, 21) g$$, 'çocuk geçmiş günlere doğrudan onaylı tamamlama yazamaz');
select tst.fails($$insert into public.completions (family_id, task_id, child_id, date, status, reviewed_by, parent_note)
  values ((select id from fam), '00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'pending',
          '00000000-0000-0000-0000-0000000000a1', 'aferin')$$, 'çocuk ebeveyn notu/onaylayan uyduramaz');
select tst.check(tst.bal('00000000-0000-0000-0000-00000000c0de') = 0 and tst.stones('00000000-0000-0000-0000-00000000c0de') = 0, 'saldırıdan coin/taş çıkmaz');
select tst.fails($$select public.child_may_complete('00000000-0000-0000-0000-000000007a51', 'approved')$$, 'iç yardımcı çağrılamaz');

-- Olağan yol: RPC
select tst.check(public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending') = 'approved', 'RPC: incelemesiz görev onaylanır');
select tst.check(tst.bal('00000000-0000-0000-0000-00000000c0de') = 50 and tst.stones('00000000-0000-0000-0000-00000000c0de') = 3, 'RPC: coin + taş bir kez');
select tst.fails($$select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date - 5, 'pending')$$, 'RPC: eski gün reddedilir');
select tst.no_effect($$delete from public.completions$$, 'çocuk tamamlamayı doğrudan silemez');
select tst.no_effect($$update public.completions set status = 'approved'$$, 'çocuk tamamlamayı doğrudan değiştiremez');
select tst.fails($$select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'assigned')$$, 'RPC: onaylanmış günü çocuk geri alamaz');
select tst.check(public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date - 1, 'declined') = 'declined', 'RPC: dün için "yapamam"');
select tst.check(public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date - 1, 'assigned') = 'assigned', 'RPC: "yapamam" geri alınır');

-- Ebeveyn doğrudan yazımı değişmedi
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.completions (family_id, task_id, child_id, date, status)
  values (public.my_family_id(), '00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date - 3, 'approved');
select tst.check(tst.bal('00000000-0000-0000-0000-00000000c0de') = 100, 'ebeveyn doğrudan onay yazabilir');


-- H2: genel deneme sınırı (199 sahte hatalı deneme başka hesaplardan)
reset role;
insert into public.code_attempts (user_id, at) select gen_random_uuid(), now() from generate_series(1, 199);
insert into auth.users (id, is_anonymous, raw_user_meta_data) values ('00000000-0000-0000-0000-0000000000c9', true, '{}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.check((public.redeem_child_code('ZZZZZZ') ->> 'error') = 'invalid_code', 'genel sınırın altında: olağan hata');
select tst.check((public.redeem_child_code('ZZZZZY') ->> 'error') = 'too_many_attempts', 'genel sınır aşılınca 429');
reset role;
