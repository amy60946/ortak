-- Oyunda rutin kartı: child_tasks rutin alanları (migrations/20261028210000_child_tasks_routine.sql, uygulandı 28 Ekim 2026).
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

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}');
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deneme', 'kedi');
-- sabah rutini: iki adım (sıra 0, 1) + rutinsiz bir görev
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review,
                          routine_id, routine_title, routine_icon, routine_position) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Dişlerini fırçala', current_date, true, 'daily', true,
   '00000000-0000-0000-0000-00000000aa01', 'Güne hazır sabah', 'sun', 0),
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Yatağını topla', current_date, true, 'daily', true,
   '00000000-0000-0000-0000-00000000aa01', 'Güne hazır sabah', 'sun', 1),
  ('00000000-0000-0000-0000-000000007a53', public.my_family_id(), 'Kitap oku', current_date, false, 'daily', true,
   null, null, null, null);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a53', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'medium', 10);
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
grant select on codes to authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select code from codes));
select tst.check((select count(*) = 2 from public.child_tasks(current_date, current_date)
                   where routine_id = '00000000-0000-0000-0000-00000000aa01'), 'rutinin iki adımı aynı routine_id ile gelir');
select tst.check((select routine_title = 'Güne hazır sabah' and routine_icon = 'sun' and routine_position = 1
                    from public.child_tasks(current_date, current_date) where task_id = '00000000-0000-0000-0000-000000007a52'),
                 'rutin adı, simgesi ve sırası döner');
select tst.check((select routine_id is null and routine_title is null and routine_position is null
                    from public.child_tasks(current_date, current_date) where task_id = '00000000-0000-0000-0000-000000007a53'),
                 'rutinsiz görevde rutin alanları boş');
select tst.check((select coins = 10 and difficulty = 'medium' and status = 'assigned'
                    from public.child_tasks(current_date, current_date) where task_id = '00000000-0000-0000-0000-000000007a53'),
                 'eski alanlar aynen');

-- her adım ayrı görev: biri yapıldı diye diğeri değişmez
select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending');
select tst.check((select status = 'pending' from public.child_tasks(current_date, current_date)
                   where task_id = '00000000-0000-0000-0000-000000007a51'), 'rutin adımı ayrı Yaptım alır');
select tst.check((select status = 'assigned' from public.child_tasks(current_date, current_date)
                   where task_id = '00000000-0000-0000-0000-000000007a52'), 'diğer adım etkilenmez');
