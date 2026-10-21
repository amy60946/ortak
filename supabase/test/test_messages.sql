-- Ebeveyn ↔ çocuk mesajlaşması (20261021150000_messages.sql).
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
-- Hata metnini döndürür (hata yoksa null)
create or replace function tst.err(sql text) returns text language plpgsql as $$
begin
  execute sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

-- a1 anne, a2 baba, c1 Nazlı'nın cihazı, c2 Efe'nin cihazı, e1 yabancı ebeveyn, d1 uzman
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","name":"Dr. Ece"}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('fid', public.my_family_id()::text);
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'Efe', 'kedi');
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
insert into tst.kv select 'k2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c002');
insert into tst.kv select 'p', code from public.create_invite_code('parent', null);
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family(tst.v('p'));
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code(tst.v('k1'));
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code(tst.v('k2'));

reset role;
create or replace function tst.n(u uuid, k text) returns bigint language sql security definer as
  $$ select count(*) from public.notifications where user_id = u and kind = k $$;
grant execute on function tst.n(uuid, text) to authenticated;
create or replace function tst.last(u uuid, k text, col text) returns text language plpgsql security definer as
  $$ declare r text; begin execute format('select %I from public.notifications where user_id = $1 and kind = $2 order by id desc limit 1', col) into r using u, k; return r; end $$;
grant execute on function tst.last(uuid, text, text) to authenticated;
set role authenticated;

-- ebeveyn → çocuk (yazı)
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.messages (id, family_id, child_id, sender, sender_id, kind, body)
  values ('00000000-0000-0000-0000-00000000aa01', public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'parent', auth.uid(), 'text', 'Akşam yemeği hazır');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'message') = 1, 'çocuğa bildirim gitti');
select tst.check(tst.last('00000000-0000-0000-0000-0000000000c1', 'message', 'title') = 'Yeni mesajın var', 'bildirim başlığı');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c2', 'message') = 0, 'kardeşe bildirim gitmez');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a2', 'message') = 0, 'ebeveyn mesajı diğer ebeveyne bildirim olmaz');
select tst.fails($$insert into public.messages (family_id, child_id, sender, sender_id, kind, media_path)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'parent', auth.uid(), 'image', 'baska-aile/x.jpg')$$, 'başka klasöre işaret eden dosya yolu reddedilir');
select tst.fails($$insert into public.messages (family_id, child_id, sender, sender_id, kind, body)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'child', auth.uid(), 'text', 'sahte')$$, 'ebeveyn çocuk adına yazamaz');
select tst.fails($$update public.messages set body = 'değişti'$$, 'mesaj düzenlenemez');

-- çocuk okur ve yanıtlar
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(json_array_length(public.child_messages()) = 1, 'çocuk sohbetini görür');
select tst.check(public.child_messages() -> 0 ->> 'from_name' = 'Anne', 'kimden geldiği görünür');
select tst.check(public.mark_messages_read() = 1, 'çocuk okundu işaretler');
select tst.check((select read_at is not null from public.messages where id = '00000000-0000-0000-0000-00000000aa01'), 'ebeveyn mesajı okundu');
select public.child_send_message('text', 'Geliyorum!');
select public.child_send_message('sticker', 'thumbs_up');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'message') = 2 and tst.n('00000000-0000-0000-0000-0000000000a2', 'message') = 2, 'çocuk yanıtı iki ebeveyne bildirim');
select tst.check(tst.last('00000000-0000-0000-0000-0000000000a1', 'message', 'body') = 'Çıkartma gönderdi', 'çıkartma bildirimi');
select tst.fails($$select public.child_send_message('sticker', 'kötü_söz')$$, 'listede olmayan çıkartma reddedilir');
select tst.fails($$select public.child_send_message('image', 'x')$$, 'çocuk dosya gönderemez');
select tst.fails($$select public.child_send_message('text', repeat('a', 501))$$, '500 karakterden uzun yazı reddedilir');
select tst.fails($$insert into public.messages (family_id, child_id, sender, sender_id, kind, media_path)
  values (public.my_any_family_id(), public.my_child_id(), 'child', auth.uid(), 'image', public.my_any_family_id() || '/x.jpg')$$, 'çocuk doğrudan da dosya mesajı ekleyemez');
select tst.fails($$insert into public.messages (family_id, child_id, sender, sender_id, kind, body)
  values (public.my_any_family_id(), '00000000-0000-0000-0000-00000000c002', 'child', auth.uid(), 'text', 'kardeşim adına')$$, 'çocuk kardeşinin sohbetine yazamaz');

-- kardeş öbürünün sohbetini göremez
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check(json_array_length(public.child_messages()) = 0, 'kardeş sohbeti ayrı');
select tst.check((select count(*) from public.messages) = 0, 'kardeş mesajları tablodan da göremez');

-- ebeveyn okundu
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check((select count(*) from public.messages where child_id = '00000000-0000-0000-0000-00000000c001') = 3, 'diğer ebeveyn bütün sohbeti görür');
select tst.check(public.mark_messages_read('00000000-0000-0000-0000-00000000c001') = 2, 'ebeveyn çocuğun iki mesajını okundu yapar');
select tst.check((select count(*) from public.messages where sender = 'child' and read_at is null) = 0, 'çocuk mesajları okundu');

-- yabancılar
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.messages) = 0, 'yabancı ebeveyn göremez');
select tst.fails($$select public.mark_messages_read('00000000-0000-0000-0000-00000000c001')$$, 'yabancı okundu işaretleyemez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.messages) = 0, 'uzman mesajları göremez');
select tst.fails($$select public.child_messages()$$, 'uzman çocuk sohbetini çağıramaz');

-- sel koruması: çocuk saatte 60
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.child_send_message('sticker', 'heart') from generate_series(1, 58);
select tst.check(tst.err($$select public.child_send_message('sticker', 'star')$$) like 'Çok fazla mesaj%', '61. mesaj reddedilir');

set role anon;
select tst.fails($$select public.child_messages()$$, 'anon çağıramaz');
reset role;
select 'MESAJ TESTLERİ GEÇTİ' as sonuc;
