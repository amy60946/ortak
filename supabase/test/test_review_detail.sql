-- İnceleme ayrıntısı (proposed/20261027130000_review_detail.sql): motivasyon, taş ayarı, not, tekrar dene.
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
create or replace function tst.stones() returns integer language sql as $$ select (public.child_me() ->> 'sun_stones')::int $$;
create or replace function tst.coins() returns integer language sql as $$ select (public.child_me() ->> 'balance')::int $$;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}');
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;
set role authenticated;

-- ---------------------------------------------------------------- kurulum
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Efe', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Odanı topla', current_date - 3, true, 'daily', true),
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Dişlerini fırçala', current_date, false, 'daily', true),
  ('00000000-0000-0000-0000-000000007a53', public.my_family_id(), 'Ödevini bitir', current_date, false, 'daily', true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'medium', 10),
  ('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a53', '00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'hard', 0);
create temp table codes as select * from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
grant select on codes to authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select code from codes));
select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending');
select public.child_set_status('00000000-0000-0000-0000-000000007a52', current_date, 'pending');
select public.child_set_status('00000000-0000-0000-0000-000000007a53', current_date, 'pending');
update public.completions set motivation = 1, stones = 6, status = 'approved';
select tst.check((select count(*) from public.completions where motivation is not null or stones is not null or status = 'approved') = 0,
  'çocuk tamamlama kaydını doğrudan değiştiremez (RLS: satır güncellenmez)');

-- ---------------------------------------------------------------- onay + motivasyon + taş ayarı
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved', null, 6)$$, 'motivasyon 1–5');
select tst.fails($$select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved', null, 0)$$, 'motivasyon 0 olmaz');
select tst.fails($$select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved', null, null, 7)$$, 'taş 0–6');
select tst.fails($$select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'bogus')$$, 'bilinmeyen durum');
select public.review_completion(p_task_id => '00000000-0000-0000-0000-000000007a51', p_child_id => '00000000-0000-0000-0000-00000000c0de',
  p_date => current_date, p_status => 'approved', p_note => 'Harika toplamışsın', p_motivation => 4, p_stones => 5);
select tst.check((select motivation = 4 and stones = 5 and parent_note = 'Harika toplamışsın' from public.completions
                   where task_id = '00000000-0000-0000-0000-000000007a51'), 'onay: motivasyon, taş ve not kaydedilir');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(tst.stones() = 5, 'orta görevde ebeveyn 5 taş seçti → +5 (zorluk 2 yerine)');
select tst.check(tst.coins() = 10, 'coin ödülü değişmez (+10)');
select tst.check((select parent_note from public.child_tasks(current_date, current_date)
                   where task_id = '00000000-0000-0000-0000-000000007a51') = 'Harika toplamışsın', 'onay notu oyuna gider');

-- ---------------------------------------------------------------- tekrar dene
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion(p_task_id => '00000000-0000-0000-0000-000000007a52', p_child_id => '00000000-0000-0000-0000-00000000c0de',
  p_date => current_date, p_status => 'retry', p_note => 'Arka dişleri unutma', p_motivation => 3, p_stones => 4);
select tst.check((select status = 'retry' and stones is null and motivation = 3 from public.completions
                   where task_id = '00000000-0000-0000-0000-000000007a52'), 'tekrar dene: durum retry, taş yalnız onayda saklanır');
select tst.fails($$select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date - 3, 'retry')$$,
  'geçmiş günün görevi tekrar denenemez');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select status || '/' || parent_note from public.child_tasks(current_date, current_date)
                   where task_id = '00000000-0000-0000-0000-000000007a52') = 'retry/Arka dişleri unutma', 'oyun retry durumunu ve notu alır');
select tst.check((select count(*) from public.notifications where kind = 'task_retry' and body = 'Arka dişleri unutma') = 1, 'çocuğa tekrar dene bildirimi');
select tst.check(tst.stones() = 5 and tst.coins() = 10, 'tekrar dene coin/taş vermez');
select tst.check(public.child_set_status('00000000-0000-0000-0000-000000007a52', current_date, 'pending') = 'pending', 'çocuk yeniden "Yaptım" diyebilir');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.notifications where kind = 'task_done') >= 4, 'yeniden yapınca ebeveyne yine bildirim');
select public.review_completion('00000000-0000-0000-0000-000000007a52', '00000000-0000-0000-0000-00000000c0de', current_date, 'approved');
select tst.check((select motivation is null and stones is null from public.completions
                   where task_id = '00000000-0000-0000-0000-000000007a52'), 'eski biçim çağrı (5 parametre): motivasyon/taş boş');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(tst.stones() = 6 and tst.coins() = 15, 'taş verilmeyince zorluğa göre: kolay +1, coin +5');

-- ---------------------------------------------------------------- onaydan sonra tekrar dene: geri alınır
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'retry', 'Yatağı da topla');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(tst.stones() = 1 and tst.coins() = 5, 'onay geri alınınca verilen 5 taş ve 10 coin düşer');
select tst.check(public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending') = 'pending', 'geri alınan görev yeniden işaretlenir');

-- ---------------------------------------------------------------- 0 taş, ret
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion(p_task_id => '00000000-0000-0000-0000-000000007a53', p_child_id => '00000000-0000-0000-0000-00000000c0de',
  p_date => current_date, p_status => 'approved', p_stones => 0);
select tst.check((select count(*) from public.sun_stone_ledger where split_part(ref, ':', 1) =
                   (select id::text from public.completions where task_id = '00000000-0000-0000-0000-000000007a53')) = 0, '0 taş: defter satırı yazılmaz');
select public.review_completion('00000000-0000-0000-0000-000000007a53', '00000000-0000-0000-0000-00000000c0de', current_date, 'rejected', 'Yarın birlikte yapalım');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(tst.stones() = 1, 'ret: verilmemiş taş düşülmez');
select tst.check((select title from public.notifications where kind = 'task_rejected') = 'Ödevini bitir onaylanmadı', 'ret bildirimi nihai dille');
select tst.fails($$select public.child_set_status('00000000-0000-0000-0000-000000007a53', current_date, 'pending')$$, 'ret nihai: çocuk değiştiremez');

-- ---------------------------------------------------------------- yetki
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', current_date, 'retry')$$,
  'başka aile karar veremez');
select tst.check((select count(*) from public.completions) = 0, 'başka aile tamamlamaları göremez');
