-- Kişisel haftalık hedef (proposed/20261022230000_weekly_goal.sql).
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

-- geçmiş: 2 ve 1 hafta önce onaylı görevler; bu hafta günlük görev (7 örnek)
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deneme', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Dişlerini fırçala', date_trunc('week', current_date)::date - 21, true, 'daily', true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 5);
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
grant select on codes to authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select code from codes));
select tst.check((public.child_weekly_goal() ->> 'target') is null, 'geçmiş yok: hedef yok (yalnız ölçüm)');
select tst.check((public.child_weekly_goal() ->> 'assigned')::int = 7, 'bu hafta 7 görev örneği');
select tst.check((public.claim_weekly_goal() ->> 'error') = 'no_goal', 'hedef yokken ödül yok');

-- geçmiş haftalar (sunucu tarafında: test kurulumu)
reset role;
insert into public.completions (family_id, task_id, child_id, date, status)
select ch.family_id, '00000000-0000-0000-0000-000000007a51', ch.id, d::date, 'approved'
from public.children ch, generate_series(date_trunc('week', current_date)::date - 14, date_trunc('week', current_date)::date - 10, interval '1 day') d
where ch.id = '00000000-0000-0000-0000-00000000c0de';   -- 2 hafta önce 5
insert into public.completions (family_id, task_id, child_id, date, status)
select ch.family_id, '00000000-0000-0000-0000-000000007a51', ch.id, d::date, 'approved'
from public.children ch, generate_series(date_trunc('week', current_date)::date - 7, date_trunc('week', current_date)::date - 5, interval '1 day') d
where ch.id = '00000000-0000-0000-0000-00000000c0de';   -- geçen hafta 3
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
-- (5 + 3) / 2 × 1,2 = 4,8 → 5; üst sınır floor(7 × 0,9) = 6
select tst.check((public.child_weekly_goal() ->> 'target')::int = 5, 'hedef = ortalama × 1,2 yukarı (5)');
select tst.check((public.claim_weekly_goal() ->> 'error') = 'not_reached', 'ulaşılmadan ödül yok');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.set_weekly_goal_cap('00000000-0000-0000-0000-00000000c0de', 4);
select tst.check((public.weekly_goal('00000000-0000-0000-0000-00000000c0de') ->> 'target')::int = 4, 'ebeveyn hedefi düşürür (4)');
select tst.fails($$select public.set_weekly_goal_cap('00000000-0000-0000-0000-00000000c0de', 0)$$, 'geçersiz sınır');

-- bu hafta 4 onaylı görev (bugüne kadar olan günlerde değil: test için haftanın günleri)
reset role;
insert into public.completions (family_id, task_id, child_id, date, status)
select ch.family_id, '00000000-0000-0000-0000-000000007a51', ch.id, d::date, 'approved'
from public.children ch, generate_series(date_trunc('week', current_date)::date, date_trunc('week', current_date)::date + 3, interval '1 day') d
where ch.id = '00000000-0000-0000-0000-00000000c0de'
on conflict do nothing;
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.child_weekly_goal() ->> 'done')::int = 4, 'bu hafta 4 onaylı');
select tst.check((public.claim_weekly_goal() ->> 'stones')::int = 2, 'hedefe ulaşınca +2 Güneş Taşı');
select tst.check((public.claim_weekly_goal() ->> 'error') = 'already_claimed', 'haftada bir kez');
select tst.check((public.child_me() ->> 'sun_stones')::int >= 2, 'hedef taşı ada ilerlemesine sayılır');
select tst.check((select count(*) from public.weekly_goal_claims) = 1, 'çocuk kendi hedef kaydını okur');
select tst.fails($$select public.weekly_goal('00000000-0000-0000-0000-00000000c0de')$$, 'çocuk ebeveyn fonksiyonunu kullanamaz');
select tst.fails($$select public.set_weekly_goal_cap('00000000-0000-0000-0000-00000000c0de', 50)$$, 'çocuk sınırı değiştiremez');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.notifications where kind = 'weekly_goal') = 1, 'ebeveyne kutlama bildirimi');
select tst.check((select weekly_cap from public.child_goal_settings) = 4, 'ebeveyn ayarı okur');

select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.weekly_goal_claims) + (select count(*) from public.child_goal_settings) = 0, 'yabancı aile göremez');
select tst.fails($$select public.weekly_goal('00000000-0000-0000-0000-00000000c0de')$$, 'yabancı hedefi okuyamaz');
select tst.fails($$select public.set_weekly_goal_cap('00000000-0000-0000-0000-00000000c0de', 3)$$, 'yabancı sınır koyamaz');
