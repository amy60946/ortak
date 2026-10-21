-- Sunucu kuralları (proposed/20261019020000_server_rules.sql): ödül sınırı, seviye kilidi, geçmiş gün,
-- kod deneme sınırı, onay geri alma tutarı, sıfır fiyat.
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
-- redeem_child_code yanıtı + PostgREST'e verilen HTTP durumu (aynı işlem içinde okunur)
create or replace function tst.redeem(p_code text) returns text language plpgsql as $$
declare j json;
begin
  j := public.redeem_child_code(p_code);
  return coalesce(j ->> 'error', 'ok') || '/' || coalesce(current_setting('response.status', true), '');
end $$;

-- sıfır fiyat (sunucu verisi; yalnız yönetici yazar)
select tst.fails($$insert into public.game_items (item_id, price, min_level) values ('x_free', 0, 1)$$, 'fiyat sıfır olamaz');

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}');

grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;
set role authenticated;

-- ---------------------------------------------------------------- ebeveyn kurulumu + ödül sınırı
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Deneme', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review)
  values ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Odanı topla', current_date - 5, true, 'daily', true);
select tst.fails($$insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  values ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 51)$$, 'ödül 50 coin''i geçemez');
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  values ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 10);
select tst.check((select coins from public.task_assignments) = 10, 'ödül 10 yazılır');
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
grant select on codes to authenticated;

-- ---------------------------------------------------------------- kod deneme sınırı
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(tst.redeem('ZZZZZZ') = 'invalid_code/400', 'hatalı kod: 400 + invalid_code (hata fırlatmaz)');
select tst.redeem('ZZZZZZ') from generate_series(1, 9);
select tst.check(tst.redeem((select code from codes)) = 'too_many_attempts/429', '10 hatadan sonra doğru kod da 429');
select tst.check((select user_id from public.children where id = '00000000-0000-0000-0000-00000000c0de') is null, 'kilitliyken bağlanmaz');
reset role;
select tst.check((select count(*) from public.code_attempts) = 10, 'hatalı denemeler kayıtlı');
set role authenticated;
select tst.fails($$select * from public.code_attempts$$, 'çocuk deneme tablosunu okuyamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check(tst.redeem((select code from codes)) = 'ok/', 'başka oturum doğru kodla girer');

-- ---------------------------------------------------------------- geçmiş gün
select tst.fails($$select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date - 2, 'pending')$$, 'iki gün önce işaretlenemez');
select tst.check(public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date - 1, 'pending') = 'pending', 'dün işaretlenebilir');
select tst.check(public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending') = 'pending', 'bugün işaretlenebilir');

-- ---------------------------------------------------------------- onay geri alma: verilen tutar düşer
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 10, 'onay +10');
update public.task_assignments set coins = 30 where child_id = '00000000-0000-0000-0000-00000000c0de';
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'rejected', 'yarım kalmış');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 0, 'geri alma onaydaki 10''u düşer (yeni ödül 30 değil)');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 30, 'yeniden onay o anki ödülü verir (30)');
delete from public.completions where child_id = '00000000-0000-0000-0000-00000000c0de' and date = current_date;
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 0, 'kayıt silinince 30 düşer');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date - 1, 'approved');
select tst.check(public.child_balance('00000000-0000-0000-0000-00000000c0de') = 30, 'dünkü görev onayı +30');

-- ---------------------------------------------------------------- seviye kilidi
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check((public.spend_coins('tx-level-0001', 'food_watermelon', 1) ->> 'error') = 'level_locked', 'kayıt yok → Sv 1, Sv 2 eşyası kilitli');
select tst.check((public.spend_coins('tx-level-0002', 'food_apple', 1) ->> 'ok')::boolean, 'Sv 1 eşyası alınır');
select public.game_save_put('{"Xp": {"TotalXp": 99}}');
select tst.check((public.spend_coins('tx-level-0003', 'food_watermelon', 1) ->> 'error') = 'level_locked', '99 XP hâlâ Sv 1');
select public.game_save_put('{"Xp": {"TotalXp": 100}}');
select tst.check((public.spend_coins('tx-level-0004', 'food_watermelon', 1) ->> 'ok')::boolean, '100 XP = Sv 2, eşya alınır');
select public.game_save_put('{"Xp": {"TotalXp": "çok"}}');
select tst.check((public.spend_coins('tx-level-0005', 'food_watermelon', 1) ->> 'error') = 'level_locked', 'bozuk XP değeri Sv 1 sayılır');
select tst.check((public.child_me() ->> 'balance')::int = 22, 'bakiye 30 − 3 − 5 = 22');
select tst.fails($$select public.child_level('00000000-0000-0000-0000-00000000c0de')$$, 'child_level istemciye kapalı');
