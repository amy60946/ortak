-- Güneş Taşı defteri + child_tasks beceri/zorluk (proposed/20261019030000_sun_stones.sql).
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
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}');
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;
set role authenticated;

-- ---------------------------------------------------------------- ebeveyn kurulumu
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deneme', 'kedi');
insert into public.tasks (id, family_id, title, skill, start_date, recurring, repeat_kind, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Dişlerini fırçala', 'Öz Bakım', current_date - 3, true, 'daily', true),
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Ödevini bitir', 'Sorumluluk', current_date, false, 'daily', false);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'hard', 0);
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
grant select on codes to authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select code from codes));
select tst.check((public.child_me() ->> 'sun_stones')::int = 0, 'başlangıçta taş yok');
select tst.check((select skill || '/' || difficulty from public.child_tasks(current_date, current_date)
                    where task_id = '00000000-0000-0000-0000-000000007a51') = 'Öz Bakım/easy', 'child_tasks beceri ve zorluk döndürür');

-- incelemesiz zor görev: "yaptım" = onay → 3 taş (coin 0 olsa da)
select public.child_set_status('00000000-0000-0000-0000-000000007a52', current_date, 'pending');
select tst.check((public.child_me() ->> 'sun_stones')::int = 3, 'zor görev onayı +3 taş (coin 0 iken de)');
select tst.check((public.child_me() ->> 'balance')::int = 0, 'coin 0');

-- incelemeli kolay görev: bekliyor → taş yok; onay → +1
select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending');
select tst.check((public.child_me() ->> 'sun_stones')::int = 3, 'bekleyen görev taş vermez');
select tst.fails($$insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref)
  values ((select family_id from public.children limit 1), '00000000-0000-0000-0000-00000000c0de', 99, 'adjust', 'hile')$$, 'çocuk defter yazamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved');
select tst.check((select sum(amount) from public.sun_stone_ledger) = 4, 'ebeveyn defteri okur: 3 + 1');
-- zorluk sonradan değişse de geri alma verileni düşer
update public.task_assignments set difficulty = 'hard' where task_id = '00000000-0000-0000-0000-000000007a51';
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'rejected', 'tekrar dene');
select tst.check((select sum(amount) from public.sun_stone_ledger) = 3, 'ret: verilen 1 taş düşer');

select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.sun_stone_ledger) = 0, 'yabancı aile defteri göremez');
select tst.fails($$select public.sun_stone_balance('00000000-0000-0000-0000-00000000c0de')$$, 'sun_stone_balance istemciye kapalı');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.child_me() ->> 'sun_stones')::int = 3, 'çocuk toplamı görür');
select tst.check((select count(*) from public.sun_stone_ledger) = 3, 'çocuk kendi defterini okur (+3, +1, −1)');
