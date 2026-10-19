-- Yaş bandı önerisi: A 6–8 · B 9–12 · C 13–15 (migrations/20261019010000_age_bands.sql).
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;

select tst.check(public.suggest_age_band(null) = 'A', 'doğum günü yok → A');
select tst.check(public.suggest_age_band((current_date - interval '6 years')::date) = 'A', '6 yaş → A');
select tst.check(public.suggest_age_band((current_date - interval '9 years' + interval '1 day')::date) = 'A', '9 yaşına bir gün var → A');
select tst.check(public.suggest_age_band((current_date - interval '9 years')::date) = 'B', 'tam 9 yaş → B');
select tst.check(public.suggest_age_band((current_date - interval '12 years')::date) = 'B', '12 yaş → B');
select tst.check(public.suggest_age_band((current_date - interval '13 years')::date) = 'C', '13 yaş → C');
select tst.check(public.suggest_age_band((current_date - interval '15 years')::date) = 'C', '15 yaş → C');

-- Ebeveynin elle seçtiği bant öneriden önce gelir.
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;
set role authenticated;
insert into public.children (id, family_id, name, avatar, birthday, age_band)
  values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deneme', 'kedi', current_date - interval '7 years', 'B'),
         ('00000000-0000-0000-0000-00000000c0d2', public.my_family_id(), 'Deneme 2', 'kedi', current_date - interval '10 years', null);
reset role;
select tst.check(public.child_age_band('00000000-0000-0000-0000-00000000c0de') = 'B', 'elle seçilen bant korunur (7 yaş, B)');
select tst.check(public.child_age_band('00000000-0000-0000-0000-00000000c0d2') = 'B', 'bant boşsa öneri: 10 yaş → B');
