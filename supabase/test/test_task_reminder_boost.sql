-- Y5 child_tasks.reminder + Y2 task_boosts (proposed/20261022210000_task_reminder_boost.sql).
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

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deneme', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review, reminder) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Dişlerini fırçala', current_date - 3, true, 'daily', true, '08:30'),
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Ödevini bitir', current_date, false, 'daily', true, null);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'hard', 10);
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
grant select on codes to authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select code from codes));
select tst.check((select left(reminder, 5) from public.child_tasks(current_date, current_date)
                    where task_id = '00000000-0000-0000-0000-000000007a51') = '08:30', 'child_tasks hatırlatma saatini döndürür');
select tst.check((select reminder is null from public.child_tasks(current_date, current_date)
                    where task_id = '00000000-0000-0000-0000-000000007a52'), 'hatırlatmasız görevde null');
select tst.check((select difficulty = 'hard' and coins = 10 from public.child_tasks(current_date, current_date)
                    where task_id = '00000000-0000-0000-0000-000000007a52'), 'eski alanlar aynı');

-- Y2: Yapamam → teklif → Deneyeceğim
select public.child_set_status('00000000-0000-0000-0000-000000007a52', current_date, 'declined');
select public.child_record_boost('00000000-0000-0000-0000-000000007a52', current_date, 'accepted');
select public.child_set_status('00000000-0000-0000-0000-000000007a52', current_date, 'assigned');
select tst.check((select choice from public.task_boosts) = 'accepted', 'çocuk kendi teklif kaydını okur');
select public.child_record_boost('00000000-0000-0000-0000-000000007a52', current_date, 'skipped');
select tst.check((select count(*) = 1 and min(choice) = 'skipped' from public.task_boosts), 'aynı görev için tek kayıt, son seçim');
select tst.fails($$select public.child_record_boost('00000000-0000-0000-0000-000000007a52', current_date, 'cheat')$$, 'geçersiz seçim');
select tst.fails($$select public.child_record_boost('00000000-0000-0000-0000-000000007a52', current_date - 5, 'accepted')$$, 'eski gün');
select tst.fails($$select public.child_record_boost('00000000-0000-0000-0000-000000000bad', current_date, 'accepted')$$, 'atanmamış görev');
select tst.fails($$insert into public.task_boosts (child_id, task_id, date, family_id, choice)
  values ('00000000-0000-0000-0000-00000000c0de', '00000000-0000-0000-0000-000000007a51', current_date,
          (select family_id from public.children limit 1), 'accepted')$$, 'çocuk tabloya doğrudan yazamaz');
-- kötüye kullanım sınırı: 7 günde en çok 3 farklı teklif
select public.child_record_boost('00000000-0000-0000-0000-000000007a51', current_date, 'accepted');
select public.child_record_boost('00000000-0000-0000-0000-000000007a51', current_date - 1, 'skipped');
select tst.fails($$select public.child_record_boost('00000000-0000-0000-0000-000000007a52', current_date - 1, 'accepted')$$, '7 günde 3 teklif sınırı');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.task_boosts) = 3, 'ebeveyn ailesinin teklif kayıtlarını görür');
select tst.fails($$select public.child_record_boost('00000000-0000-0000-0000-000000007a52', current_date, 'accepted')$$, 'ebeveyn çocuk adına yazamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.task_boosts) = 0, 'yabancı aile göremez');
