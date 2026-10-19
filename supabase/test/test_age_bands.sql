-- Yaş bantları (öneri 20261019110000_age_bands.sql): A 6–8, B 9–12; C yok.
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

-- öneri kuralı (sınırlar)
select tst.check(public.suggest_age_band(null) = 'A', 'doğum günü yok → A');
select tst.check(public.suggest_age_band((current_date - interval '6 years')::date) = 'A', '6 yaş → A');
select tst.check(public.suggest_age_band((current_date - interval '9 years' + interval '1 day')::date) = 'A', '9 yaşına bir gün var → A');
select tst.check(public.suggest_age_band((current_date - interval '9 years')::date) = 'B', '9 yaş → B');
select tst.check(public.suggest_age_band((current_date - interval '12 years')::date) = 'B', '12 yaş → B');
select tst.check(public.suggest_age_band((current_date - interval '14 years')::date) = 'B', '13+ → B (C yok)');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar, birthday)
  values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Nazlı', 'flamingo', current_date - interval '7 years');
select tst.fails($$update public.children set age_band = 'C' where id = '00000000-0000-0000-0000-00000000c0de'$$, 'C artık yazılamaz');
select tst.fails($$select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', 'C')$$, 'set_child_age_band C reddeder');
select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', 'B');
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'B', 'B yazılır');
select public.set_child_age_band('00000000-0000-0000-0000-00000000c0de', null);
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') is null, 'boşaltılabilir (doğum gününden önerilir)');

reset role;
-- var olan C kaydı göçle B olur (göç ikinci kez çalıştırılınca da)
alter table public.children drop constraint children_age_band_check;
update public.children set age_band = 'C' where id = '00000000-0000-0000-0000-00000000c0de';
\ir ../proposed/20261019110000_age_bands.sql
select tst.check((select age_band from public.children where id = '00000000-0000-0000-0000-00000000c0de') = 'B', 'eski C kaydı B olur');
select tst.check(public.child_age_band('00000000-0000-0000-0000-00000000c0de') = 'B', 'child_age_band B');

select 'TÜM YAŞ BANDI TESTLERİ GEÇTİ' as sonuc;
