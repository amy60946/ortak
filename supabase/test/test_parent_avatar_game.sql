-- Ebeveynin oyundaki yüzü: child_messages / child_gifts_pending from_avatar (proposed/20261027220000_parent_avatar_game.sql).
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
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}');
set role authenticated;

-- kurulum: Anne aile + çocuk; Baba katılır; çocuk cihazı bağlanır
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000c0de', public.my_family_id(), 'Efe', 'kedi');
insert into tst.kv select 'code', code from public.create_invite_code('parent', null);
insert into tst.kv select 'child', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
update public.profiles set avatar = 'okti_anne_2' where id = auth.uid();
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family((select v from tst.kv where k = 'code'));
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select v from tst.kv where k = 'child'));

-- mesajlar: Anne (okti_anne_2) ve Baba (varsayılan avatar) yazar, çocuk bir yanıt verir
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.messages (family_id, child_id, sender, sender_id, kind, body, created_at)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'parent', auth.uid(), 'text', 'Akşam yemeği hazır', now() - interval '3 minutes');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
insert into public.messages (family_id, child_id, sender, sender_id, kind, body, created_at)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'parent', auth.uid(), 'text', 'Geliyorum', now() - interval '2 minutes');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.child_send_message('text', 'Tamam');

select tst.check(json_array_length(public.child_messages()) = 3, 'çocuk üç mesajı görür');
select tst.check(public.child_messages() -> 0 ->> 'from_avatar' = 'okti_anne_2', 'Anne mesajında avatar');
select tst.check(public.child_messages() -> 0 ->> 'from_name' = 'Anne', 'Anne mesajında ad (eski alan aynı)');
select tst.check(public.child_messages() -> 1 ->> 'from_avatar' = 'erkek', 'Baba mesajında varsayılan avatar (oyun okti_baba_1 gösterir)');
select tst.check((select count(*) from public.profiles) = 0, 'çocuk profilleri yine okuyamaz');
select tst.check(public.child_messages() -> 1 ->> 'from_name' = 'Baba', 'Baba mesajında ad');
select tst.check(public.child_messages() -> 2 ->> 'from_avatar' is null and public.child_messages() -> 2 ->> 'from_name' is null,
  'çocuğun kendi mesajında gönderen alanları boş');

-- hediye: Anne avatarını değiştirdikten sonra gönderir
-- taş: defter yalnız sunucu işlevleriyle yazılır; testte sunucu rolüyle 10 taş verilir
reset role;
insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
  select family_id, id, 10, 'task', 'test:1' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
update public.profiles set avatar = 'okti_anne_3' where id = auth.uid();
select tst.check((public.send_gift('00000000-0000-0000-0000-00000000c0de', 'glasses_round', 'Senin için') ->> 'ok')::boolean, 'hediye gönderilir');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((select count(*) from public.child_gifts_pending()) = 1, 'oyun bekleyen hediyeyi alır');
select tst.check((select from_avatar from public.child_gifts_pending()) = 'okti_anne_3', 'hediyede gönderenin avatarı');
select tst.check((select from_name || '/' || note from public.child_gifts_pending()) = 'Anne/Senin için', 'hediyede ad ve not aynı');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.child_gifts_pending()$$, 'ebeveyn çocuk işlevini çağıramaz');
select tst.fails($$select public.child_messages()$$, 'ebeveyn çocuk sohbet işlevini çağıramaz');
reset role;
select tst.check(not has_function_privilege('anon', 'public.child_gifts_pending()', 'execute'), 'anon hediye işlevini çağıramaz');
select tst.check(not has_function_privilege('anon', 'public.child_messages(integer)', 'execute'), 'anon sohbet işlevini çağıramaz');
