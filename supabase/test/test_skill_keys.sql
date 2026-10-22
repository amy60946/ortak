-- Beceri anahtarı ve altı kategori (proposed/20261023020000_skill_keys.sql)
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
create or replace function tst.fails(sql text, msg text) returns void language plpgsql as $$
begin
  begin execute sql;
  exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;

select tst.check(public.skill_key('Sorumluluk') = 'teamwork', 'eski etiket → teamwork');
select tst.check(public.skill_key('İletişim') = 'kindness', 'büyük İ ile başlayan Türkçe etiket');
select tst.check(public.skill_key('Independence') = 'teamwork', 'İngilizce ad (büyük I)');
select tst.check(public.skill_key('Öz Bakım') = 'strength', 'Öz Bakım → strength');
select tst.check(public.skill_key('focus') = 'focus' and public.skill_key('relation') = 'kindness', 'anahtar ve kategori anahtarı');
select tst.check(public.skill_key(' Okuma ') = 'knowledge', 'boşluklu');
select tst.check(public.skill_key('Özel') = 'Özel' and public.skill_key('') = '', 'eşleşmeyen olduğu gibi');

insert into auth.users (id, is_anonymous, raw_user_meta_data) values ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
insert into public.tasks (id, family_id, title, skill, start_date)
  select '00000000-0000-0000-0000-0000000000f1', family_id, 'Kitap oku', 'Okuma', current_date from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
select tst.check((select skill from public.tasks where id = '00000000-0000-0000-0000-0000000000f1') = 'knowledge', 'görev yazılırken anahtara çevrilir');
update public.tasks set skill = 'Empati' where id = '00000000-0000-0000-0000-0000000000f1';
select tst.check((select skill from public.tasks where id = '00000000-0000-0000-0000-0000000000f1') = 'kindness', 'güncellemede de');
update public.tasks set skill = 'Özel' where id = '00000000-0000-0000-0000-0000000000f1';
select tst.check((select skill from public.tasks where id = '00000000-0000-0000-0000-0000000000f1') = 'Özel', 'Özel olduğu gibi kalır');

select tst.check((select pg_get_constraintdef(oid) from pg_constraint where conname = 'cts_category_check') like '%relation%', 'uzman önerisi altı kategoriye açık');
select tst.check((select pg_get_constraintdef(oid) from pg_constraint where conname = 'cts_category_check') not like '%self%', 'eski self kategorisi kalktı');
select tst.check((select prosrc from pg_proc where proname = 'cts_skill_key_normalize') like '%health%', 'eski self kategorisi health olur (tetikleyici)');
