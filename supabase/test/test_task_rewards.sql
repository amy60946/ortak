-- Görev ödülü kuralları (öneri 20261019100000_task_rewards.sql): geri alma tutarı, silme, üst sınır.
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

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Nazlı', 'flamingo');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review)
  values ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Odanı topla', current_date - 3, true, 'daily', true),
         ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Kitap oku', current_date - 3, true, 'daily', true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'medium', 10),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 5);

-- üst sınır 50
select tst.fails($$update public.task_assignments set coins = 51 where task_id = '00000000-0000-0000-0000-000000007a51'$$, '50 üstü ödül reddedilir');
select tst.fails($$update public.task_assignments set coins = -1 where task_id = '00000000-0000-0000-0000-000000007a51'$$, 'eksi ödül reddedilir');
update public.task_assignments set coins = 50 where task_id = '00000000-0000-0000-0000-000000007a52';
update public.task_assignments set coins = 5 where task_id = '00000000-0000-0000-0000-000000007a52';
select tst.check(true, '0–50 arası ödül kabul edilir');

-- onay → +10; ödül sonradan 30'a çıksa da geri alma 10 düşer
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 10, 'onay +10');
update public.task_assignments set coins = 30 where task_id = '00000000-0000-0000-0000-000000007a51';
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'rejected', 'Tekrar bakalım');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 0, 'geri alma verilen kadar düşer (30 değil 10)');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'rejected', 'Yine ret');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 0, 'ikinci ret bir şey düşmez');
-- yeniden onay: yeni ödül (30)
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 30, 'yeniden onay o anki ödülü verir');
-- ödül 0'a inse de geri alma 30 düşer
update public.task_assignments set coins = 0 where task_id = '00000000-0000-0000-0000-000000007a51';
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'pending');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 0, 'ödül 0 olsa da verilen geri alınır');

-- ebeveyn kaydı silerse (atama duruyor) coin geri alınır
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 5, 'ikinci görev +5');
delete from public.completions where task_id = '00000000-0000-0000-0000-000000007a52' and date = current_date;
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 0, 'onaylı kayıt silinince coin düşer');

-- görev silinirse kazanılmış coin kalır
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', current_date - 1, 'approved');
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', current_date - 2, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 10, 'iki onay +10');
delete from public.tasks where id = '00000000-0000-0000-0000-000000007a52';
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 10, 'görev silinince kazanılmış coin kalır');

-- çocuk görevden çıkarılırsa (atama silinir), sonra kayıt silinse de coin kalır
update public.task_assignments set coins = 7 where task_id = '00000000-0000-0000-0000-000000007a51';
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date - 1, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 17, 'onay +7');
delete from public.task_assignments where task_id = '00000000-0000-0000-0000-000000007a51';
delete from public.completions where task_id = '00000000-0000-0000-0000-000000007a51';
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 17, 'atama silindiyse coin kalır');

reset role;
select 'TÜM GÖREV ÖDÜLÜ TESTLERİ GEÇTİ' as sonuc;
