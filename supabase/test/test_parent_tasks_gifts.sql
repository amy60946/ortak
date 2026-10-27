-- Ebeveyn görevleri, ebeveyn taşı, hediye dükkânı (proposed/20261027140000_parent_tasks_gifts.sql).
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
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.bal() returns integer language sql as $$
  select coalesce(sum(amount), 0)::int from public.parent_stone_ledger where user_id = auth.uid() $$;
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}');
set role authenticated;

-- ---------------------------------------------------------------- kurulum: Anne aile, çocuk, görevler; Baba katılır
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('fid', public.my_family_id()::text);
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Efe', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Mutfağı topla', current_date - 10, true, 'daily'),
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Ailece yürüyüş', current_date, false, 'daily');
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'medium', 10);
insert into tst.kv select 'code', code from public.create_invite_code('parent', null);
insert into tst.kv select 'child', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');

select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family((select v from tst.kv where k = 'code'));
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select v from tst.kv where k = 'child'));

-- ---------------------------------------------------------------- atama
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.parent_assignments (task_id, user_id, family_id, difficulty) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-0000000000a1', public.my_family_id(), 'medium'),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-0000000000a1', public.my_family_id(), 'easy'),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-0000000000a2', public.my_family_id(), 'hard');
select tst.check((select count(*) from public.parent_assignments) = 3, 'kendine ve eşine atar (ailece görev: çocuk + iki ebeveyn)');
select tst.fails($$insert into public.parent_assignments (task_id, user_id, family_id) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-0000000000e1', public.my_family_id())$$, 'aileden olmayan kişiye atanamaz');
select tst.fails($$update public.parent_assignments set user_id = '00000000-0000-0000-0000-0000000000a2'
  where task_id = '00000000-0000-0000-0000-000000007a51'$$, 'atanan kişi değiştirilemez');
update public.parent_assignments set difficulty = 'hard' where task_id = '00000000-0000-0000-0000-000000007a51';
update public.parent_assignments set difficulty = 'medium' where task_id = '00000000-0000-0000-0000-000000007a51';
select tst.check((select difficulty from public.parent_assignments where task_id = '00000000-0000-0000-0000-000000007a51') = 'medium', 'zorluk değişir');

select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.parent_assignments) = 0, 'yabancı aile atamaları göremez');
select tst.fails($$insert into public.parent_assignments (task_id, user_id, family_id) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-0000000000e1', public.my_family_id())$$, 'başka ailenin görevine atama yapılamaz');

-- ---------------------------------------------------------------- işaretleme ve taş
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date) = 2, 'orta görev: +2 taş');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date) = 2, 'aynı gün ikinci işaret taş vermez');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date - 1) = 4, 'dünün görevi de işaretlenir (+2)');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date - 1, false) = 2, 'geri al: verilen 2 düşer');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date - 1, false) = 2, 'ikinci geri alma bir şey yapmaz');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date - 1) = 4, 'yeniden işaret: +2');
select tst.fails($$select public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date - 9)$$, 'bir haftadan eski gün işaretlenemez');
select tst.fails($$select public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date + 3)$$, 'gelecek gün işaretlenemez');
select tst.fails($$select public.parent_task_done('00000000-0000-0000-0000-000000007a52', current_date + 1)$$, 'görev o gün yoksa işaretlenemez');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a52', current_date) = 5, 'ailece görev (kolay): +1');
select tst.check((select count(*) from public.parent_completions) = 3, 'aile işaretleri okur');
select tst.check(tst.bal() = 5, 'defter toplamı = bakiye');
select tst.fails($$insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
  values (public.my_family_id(), auth.uid(), 100, 'task', 'hile')$$, 'deftere doğrudan yazılamaz');
select tst.fails($$insert into public.parent_completions (task_id, user_id, date, family_id)
  values ('00000000-0000-0000-0000-000000007a51', auth.uid(), current_date - 2, public.my_family_id())$$, 'işaret doğrudan yazılamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.fails($$select public.parent_task_done('00000000-0000-0000-0000-000000007a51', current_date)$$, 'atanmamış görev işaretlenemez');
select tst.check(public.parent_task_done('00000000-0000-0000-0000-000000007a52', current_date) = 3, 'Baba ailece görevde zor: +3');
select tst.check((select count(*) from public.parent_stone_ledger) = 6, 'aile iki ebeveynin defterini görür (Anne 5 satır, Baba 1)');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.fails($$select public.parent_task_done('00000000-0000-0000-0000-000000007a52', current_date)$$, 'çocuk ebeveyn görevi işaretleyemez');
select tst.check((select count(*) from public.parent_stone_ledger) = 0, 'çocuk ebeveyn defterini görmez');
select tst.check((select count(*) from public.child_tasks(current_date, current_date)) = 1, 'çocuğun görev listesi değişmez (ailece görev tek satır)');

-- ---------------------------------------------------------------- hediye
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select stones from public.gift_items where item_id = 'glasses_round') = 2, 'fiyat: 15 coin → 2 taş');
select tst.check((select stones from public.gift_items where item_id = 'home_aquarium') = 10, 'fiyat: 100 coin → 10 taş');
select tst.check(not exists (select 1 from public.gift_items where item_id like 'food_%' or item_id like 'set_%'), 'yiyecek ve özel set dükkânda yok');
select tst.check((public.send_gift('00000000-0000-0000-0000-00000000c0de', 'food_apple') ->> 'error') = 'unknown_item', 'dükkânda olmayan eşya');
select tst.check((public.send_gift('00000000-0000-0000-0000-00000000c0de', 'home_aquarium') ->> 'error') = 'not_enough_stones', 'taş yetmezse gönderilmez');
select tst.check(tst.bal() = 5, 'başarısız denemeler taş düşmez');
insert into tst.kv select 'gift', public.send_gift('00000000-0000-0000-0000-00000000c0de', 'glasses_round', '  Yeni gözlüğün!  ') ->> 'gift_id';
select tst.check(tst.bal() = 3, 'hediye: 2 taş düşer');
select tst.check((select from_name || '/' || note from public.child_gifts) = 'Anne/Yeni gözlüğün!', 'hediye kaydı: gönderen adı ve not');
select tst.check((public.send_gift('00000000-0000-0000-0000-00000000c0de', 'glasses_round', repeat('x', 200)) ->> 'ok')::boolean, 'uzun not 140 karaktere kısaltılır');
select tst.check((select max(char_length(note)) from public.child_gifts) = 140, 'not 140 karakter');
select tst.check(tst.bal() = 1, 'ikinci hediye: 1 taş kaldı');

select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$select public.send_gift('00000000-0000-0000-0000-00000000c0de', 'glasses_round')$$, 'başka ailenin çocuğuna hediye gönderilemez');
select tst.check((select count(*) from public.child_gifts) = 0, 'yabancı hediyeleri göremez');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select count(*) from public.child_gifts_pending()) = 2, 'oyun bekleyen iki hediyeyi alır');
select tst.check((select count(*) from public.notifications where kind = 'gift') = 2, 'çocuğa hediye bildirimi');
select tst.check(public.claim_child_gift((select v::uuid from tst.kv where k = 'gift')), 'hediye kapatılır');
select tst.check(not public.claim_child_gift((select v::uuid from tst.kv where k = 'gift')), 'ikinci kapatma false');
select tst.check((select count(*) from public.child_gifts_pending()) = 1, 'kapatılan listeden çıkar');
select tst.fails($$select public.send_gift('00000000-0000-0000-0000-00000000c0de', 'glasses_round')$$, 'çocuk hediye gönderemez');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.child_gifts_pending()$$, 'ebeveyn çocuk işlevini çağıramaz');
-- görev silinince işaretler gider, kazanılan taş kalır
delete from public.tasks where id = '00000000-0000-0000-0000-000000007a51';
select tst.check((select count(*) from public.parent_completions where user_id = auth.uid()) = 1, 'silinen görevin işaretleri gider');
select tst.check(tst.bal() = 1, 'kazanılmış taş kalır');
