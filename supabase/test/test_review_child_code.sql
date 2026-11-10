-- App Review kalıcı çocuk kodu (proposed/20261110200000_review_child_code.sql).
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
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

-- a1 inceleme ailesinin ebeveyni, b1 başka aile, c1/c2/c3 çocuk cihazları (anonim)
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, 'Inceleme@Example.com', '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000b1', false, 'baska@example.com', '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, null, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, null, '{}'),
  ('00000000-0000-0000-0000-0000000000c3', true, null, '{}');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Deniz', 'okti'),
  ('00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'Ada', 'okti');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c009', public.my_family_id(), 'Deniz', 'okti');

-- istemci yönetemez, tabloyu göremez
select tst.fails($q$select public.review_code_set('inceleme@example.com', 'Deniz')$q$, 'ebeveyn inceleme kodu üretemez');
select tst.fails($q$select count(*) from public.review_child_codes$q$, 'istemci inceleme kodlarını okuyamaz');
reset role;

-- SQL Editor (sunucu yetkisi): e-posta büyük/küçük harf ve boşluk duyarsız, çocuk adı da
insert into tst.kv select 'r1', public.review_code_set('  inceleme@example.com ', 'deniz');
select tst.check(tst.v('r1') ~ '^O[A-Z0-9]{5}$', 'inceleme kodu O ile başlar, 6 karakter');
select tst.check((select child_id from public.review_child_codes where code = tst.v('r1')) = '00000000-0000-0000-0000-00000000c001',
                 'kod doğru ailenin çocuğuna bağlı (başka ailedeki aynı adlı çocuğa değil)');
select tst.fails($q$select public.review_code_set('yok@example.com', 'Deniz')$q$, 'bilinmeyen e-posta');
select tst.fails($q$select public.review_code_set('inceleme@example.com', 'Mert')$q$, 'ailede olmayan çocuk');

-- inceleyici cihazı: anonim oturumla kodu kullanır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.redeem_child_code(lower(tst.v('r1'))) ->> 'child_id') = '00000000-0000-0000-0000-00000000c001',
                 'inceleme kodu küçük harfle de bağlar');
reset role;
select tst.check((select user_id from public.children where id = '00000000-0000-0000-0000-00000000c001') = '00000000-0000-0000-0000-0000000000c1',
                 'çocuk inceleyici cihazına bağlandı');

-- kod tükenmez: ikinci cihaz da girer (O yerine 0 yazarak)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check((public.redeem_child_code(replace(tst.v('r1'), 'O', '0')) ->> 'child_id') = '00000000-0000-0000-0000-00000000c001',
                 'kod ikinci kez kullanılabilir, O yerine 0 kabul');
reset role;
select tst.check((select use_count from public.review_child_codes where code = tst.v('r1')) = 2, 'kullanım sayacı 2');
select tst.check((select user_id from public.children where id = '00000000-0000-0000-0000-00000000c001') = '00000000-0000-0000-0000-0000000000c2',
                 'çocuk son giren cihaza geçti');

-- ebeveynin yeni aile kodu üretmesi inceleme kodunu bozmaz; aile kodu da çalışmaya devam eder
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'fam', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.check(tst.v('fam') !~ '[OIL01]', 'aile kodlarında O, I, L, 0, 1 yok (çakışma olamaz)');
select tst.as_user('00000000-0000-0000-0000-0000000000c3');
select tst.check((public.redeem_child_code(tst.v('r1')) ->> 'child_id') = '00000000-0000-0000-0000-00000000c001',
                 'aile kodu üretildikten sonra inceleme kodu hâlâ geçerli');
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check((public.redeem_child_code(tst.v('fam')) ->> 'child_id') = '00000000-0000-0000-0000-00000000c001',
                 'aile kodu normal çalışır');
select tst.check((public.redeem_child_code(tst.v('fam')) ->> 'error') is not null, 'aile kodu yine tek kullanımlık');
reset role;

-- yeni kod eskisini kapatır; kapatılan kod reddedilir
insert into tst.kv select 'r2', public.review_code_set('inceleme@example.com', 'Deniz', 'App Review 2');
select tst.check((select active from public.review_child_codes where code = tst.v('r1')) = false, 'yeni kod eskisini kapatır');
select tst.check(public.review_code_off(tst.v('r2')), 'kod kapatılır');
select tst.check(not public.review_code_off(tst.v('r2')), 'zaten kapalı kod: false');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.redeem_child_code(tst.v('r2')) ->> 'error') is not null, 'kapatılmış inceleme kodu reddedilir');
select tst.check((public.redeem_child_code(tst.v('r1')) ->> 'error') is not null, 'eski inceleme kodu reddedilir');
reset role;

-- çocuk silinince kodu da gider
delete from public.children where id = '00000000-0000-0000-0000-00000000c001';
select tst.check(not exists (select 1 from public.review_child_codes where child_id = '00000000-0000-0000-0000-00000000c001'),
                 'çocuk silinince inceleme kodları silinir');
