-- Uzman önerisi ayrıntıları, uzmanın güncellemesi ve danışan listesi (proposed/20261019140000_clinic_suggestion_details.sql)
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false); end $$;
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
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

-- ebeveyn a1 (Ayşe Yılmaz), ikinci ebeveyn a2 (aynı aile), yabancı ebeveyn e1, uzman d1, başka klinik d9
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne","name":"Ayşe Yılmaz"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı","name":"Can Demir"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Başka","name":"Dr. Can"}');
update public.profiles set family_id = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'),
  created_at = now() + interval '1 minute'
  where id = '00000000-0000-0000-0000-0000000000a2';
insert into public.children (id, family_id, name, avatar, birthday)
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Nazlı', 'flamingo', '2018-04-12'
  from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0e1', family_id, 'Nazlı', 'kedi'
  from public.profiles where id = '00000000-0000-0000-0000-0000000000e1';
-- iki aile de aynı kliniğe rıza verdi
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by, consent_at)
  select '00000000-0000-0000-0000-0000000011e1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000e1', now() - interval '1 day'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0e1';

set role authenticated;

-- ------------------------------------------------ danışan listesi + ebeveyn adı
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_clients()) = 2, 'uzman iki danışanı görür');
select tst.check((select parents from public.clinic_clients() where link_id = '00000000-0000-0000-0000-0000000011a1') = 'Ayşe Yılmaz, Baba',
  'aynı adlı çocuklar ebeveyn adıyla ayrılır (ad yoksa takma ad)');
select tst.check((select parents from public.clinic_clients() where link_id = '00000000-0000-0000-0000-0000000011e1') = 'Can Demir', 'ikinci ailenin ebeveyni');
select tst.check((select count(*) from public.profiles) = 0, 'profiles tablosu uzmana açılmadı');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check((select count(*) from public.clinic_clients()) = 0, 'başka klinik danışanları görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_clients()) = 0, 'ebeveyn uzman listesini görmez');
reset role;
update public.clinic_links set status = 'revoked' where id = '00000000-0000-0000-0000-0000000011e1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_clients()) = 1, 'rıza geri alınan aile listeden düşer');

-- ------------------------------------------------ ParentApp görev alanlarıyla öneri
insert into public.clinic_task_suggestions (id, link_id, clinic_id, family_id, child_id, title, emoji, skill, difficulty,
    description, category, template_key, coins, start_date, recurring, repeat_kind, repeat_days, end_date, reminder, requires_review, note, created_by)
  select '00000000-0000-0000-0000-00000000500a', l.id, l.clinic_id, l.family_id, l.child_id, 'Dişlerini fırçala', '🪥', 'Öz Bakım', 'easy',
    'Akşam yemekten sonra', 'self', 't9', 8, current_date + 1, true, 'weekly', '{1,3,5}', current_date + 60, '20:30', false, 'Rutin kartıyla', auth.uid()
  from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1';
select tst.check((select repeat_days = '{1,3,5}' and reminder = '20:30' and coins = 8 and not requires_review
  from public.clinic_task_suggestions where id = '00000000-0000-0000-0000-00000000500a'), 'öneri görev ayarlarını taşır');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, coins)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', 99 from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'ödül 50 üstü olamaz');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, reminder)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', '25:00' from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'geçersiz saat');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, repeat_days)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', '{0}' from public.clinic_links l where l.id = '00000000-0000-0000-0000-0000000011a1'$$, 'geçersiz gün');

-- ------------------------------------------------ uzman bekleyen öneriyi günceller
select public.clinic_update_suggestion('00000000-0000-0000-0000-00000000500a',
  '{"title":"Dişlerini iki dakika fırçala","coins":10,"repeat_days":[2,4],"reminder":null,"requires_review":true}');
select tst.check((select title = 'Dişlerini iki dakika fırçala' and coins = 10 and repeat_days = '{2,4}' and reminder is null
  and requires_review and updated_at is not null and emoji = '🪥' and description = 'Akşam yemekten sonra'
  from public.clinic_task_suggestions where id = '00000000-0000-0000-0000-00000000500a'), 'uzman güncellemesi yalnız gönderilen alanları değiştirir');
select tst.fails($$select public.clinic_update_suggestion('00000000-0000-0000-0000-00000000500a', '{"coins":70}')$$, 'güncellemede de ödül sınırı');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.fails($$select public.clinic_update_suggestion('00000000-0000-0000-0000-00000000500a', '{"title":"x"}')$$, 'başka klinik güncelleyemez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.clinic_update_suggestion('00000000-0000-0000-0000-00000000500a', '{"title":"x"}')$$, 'ebeveyn RPC ile metni değiştiremez');
select tst.fails($$update public.clinic_task_suggestions set title = 'x'$$, 'ebeveyn tablodan metni değiştiremez (sütun izni)');
select tst.check((select description from public.clinic_task_suggestions where id = '00000000-0000-0000-0000-00000000500a') = 'Akşam yemekten sonra',
  'ebeveyn yeni alanları okur');
update public.clinic_task_suggestions set status = 'accepted', decided_at = now() where id = '00000000-0000-0000-0000-00000000500a';
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.clinic_update_suggestion('00000000-0000-0000-0000-00000000500a', '{"title":"x"}')$$, 'karar verilmiş öneri değişmez');

reset role;
select 'TÜM ÖNERİ AYRINTISI TESTLERİ GEÇTİ' as sonuc;
