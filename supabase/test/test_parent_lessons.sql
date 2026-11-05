-- Ebeveyn eğitimi: ders kataloğu, uzman önerisi, ebeveynin dersi, uygulama günü ve haftalık taş
-- (proposed/20261105200000_parent_lessons.sql; akislar.md 22, ekonomi.md 5C).
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
create or replace function tst.fails(sql text, msg text, hint text default null) returns void language plpgsql as $$
declare h text;
begin
  begin
    execute sql;
  exception when others then
    get stacked diagnostics h = pg_exception_hint;
    if hint is not null and h is distinct from hint then
      raise exception 'TEST BAŞARISIZ (yanlış hata): % → % (ipucu %, beklenen %)', msg, sqlerrm, h, hint;
    end if;
    raise notice 'ok (beklenen hata): % → %', msg, sqlerrm;
    return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
-- Her hafta için: defterdeki ders taşı = min(3, o hafta uygulanan farklı gün)
create or replace function tst.weeks_ok(u uuid) returns boolean language sql security definer set search_path = '' as $$
  select not exists (
    select 1 from (
      select date_trunc('week', day::timestamp)::date ws, least(3, count(distinct day)) want
        from public.parent_lesson_practice where user_id = u group by 1) w
    where w.want <> (select coalesce(sum(amount), 0) from public.parent_stone_ledger l
                      where l.user_id = u and l.reason in ('lesson', 'lesson_undo') and split_part(l.ref, '|', 2) = w.ws::text))
  and not exists (
    select 1 from (select split_part(l.ref, '|', 2) wk, sum(l.amount) s from public.parent_stone_ledger l
                    where l.user_id = u and l.reason in ('lesson', 'lesson_undo') group by 1) t
    where t.s <> 0 and not exists (select 1 from public.parent_lesson_practice x where x.user_id = u
                                   and date_trunc('week', x.day::timestamp)::date::text = t.wk))
$$;
create or replace function tst.lesson_stones(u uuid) returns integer language sql security definer set search_path = '' as $$
  select coalesce(sum(amount), 0)::int from public.parent_stone_ledger where user_id = u and reason in ('lesson', 'lesson_undo') $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Başka","name":"Dr. Can"}');

-- katalog (içerik sonra; burada örnek satırlar)
insert into public.parent_lessons (key, title, summary, minutes, body_md, try_text, status, position) values
  ('ovgu', 'Fark et ve söyle', 'Olumlu davranışı adıyla söyle', 4, '## Ders\nMetin', 'Günde 3 kez fark et', 'published', 1),
  ('talimat', 'Kısa ve net iste', 'Tek adımlı istek', 3, '## Ders', 'Bir isteği tek cümleyle söyle', 'published', 2),
  ('taslak', 'Henüz hazır değil', '', 5, '', '', 'draft', 3),
  ('eski', 'Kaldırılan ders', '', 5, '', '', 'retired', 4);

insert into public.children (id, family_id, name, avatar)
  select '00000000-0000-0000-0000-00000000c0de', family_id, 'Mira', 'tavşan' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.clinic_links (id, clinic_id, clinician_id, family_id, child_id, consent_by)
  select '00000000-0000-0000-0000-0000000011a1', m.clinic_id, m.id, c.family_id, c.id, '00000000-0000-0000-0000-0000000000a1'
  from public.clinicians m, public.children c where m.id = '00000000-0000-0000-0000-0000000000d1' and c.id = '00000000-0000-0000-0000-00000000c0de';

set role authenticated;

-- ---------------------------------------------------------------- kurulum: Baba aileye, çocuk cihazı bağlanır
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'code', code from public.create_invite_code('parent', null);
insert into tst.kv select 'child', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c0de');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family((select v from tst.kv where k = 'code'));
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select v from tst.kv where k = 'child'));

-- ---------------------------------------------------------------- 1. katalog
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.parent_lessons) = 3, 'taslak ders görünmez (yayımlanan + kaldırılan)');
select tst.check(jsonb_array_length(public.family_lessons() -> 'catalog') = 3, 'family_lessons: katalog');
select tst.check(jsonb_array_length(public.family_lessons() -> 'mine') = 0 and (public.family_lessons() ->> 'week_cap')::int = 3,
  'family_lessons: henüz ders yok, haftalık tavan 3');
select tst.fails($$insert into public.parent_lessons (key, title) values ('x1', 'X')$$, 'istemci ders ekleyemez');
select tst.fails($$select public.parent_lesson_start('taslak')$$, 'taslak derse başlanamaz', 'lesson_not_found');
select tst.fails($$select public.parent_lesson_start('eski')$$, 'kaldırılan derse yeni başlanamaz', 'lesson_not_found');

-- ---------------------------------------------------------------- 2. başla, aç, uygula
select tst.fails($$select public.parent_lesson_practice('ovgu')$$, 'başlamadan uygulanamaz', 'lesson_not_started');
select tst.check((public.parent_lesson_start('ovgu') -> 'mine' -> 0 ->> 'status') = 'current', 'derse başlandı: bu haftanın becerisi');
select public.parent_lesson_open('ovgu');
select tst.check((select opened_at is not null from public.parent_lesson_progress where lesson_key = 'ovgu'), 'ders açıldı kaydı');
select tst.check(tst.lesson_stones(auth.uid()) = 0, 'dersi açmak taş getirmez');
select tst.check((public.parent_lesson_practice('ovgu') ->> 'stone_given')::int = 1, 'bugün uyguladım: 1 taş');
select tst.check((public.parent_lesson_practice('ovgu') ->> 'stone_given')::int = 0, 'aynı gün ikinci kez: taş yok');
select tst.check((public.family_lessons() ->> 'balance')::int = 1, 'bakiye 1');
select tst.fails($$select public.parent_lesson_practice('ovgu', public.tr_today() + 1)$$, 'ileri gün yok', 'date_range');
select tst.fails($$select public.parent_lesson_practice('ovgu', public.tr_today() - 7)$$, 'bir haftadan eski gün yok', 'date_range');
-- son 7 günün hepsi: her hafta en çok 3 taş
select public.parent_lesson_practice('ovgu', public.tr_today() - g) from generate_series(0, 6) g;
select tst.check(tst.weeks_ok(auth.uid()), 'her hafta taş = min(3, uygulanan gün)');
select tst.check(tst.lesson_stones(auth.uid()) between 3 and 6, 'iki haftaya yayılan 7 gün: 3–6 taş');
select tst.check((public.family_lessons() ->> 'week_stones')::int = least(3, extract(isodow from public.tr_today())::int),
  'bu haftanın taşı = min(3, haftanın geçen günü)');
-- geri al: hafta yeniden hesaplanır
select public.parent_lesson_practice('ovgu', public.tr_today(), false);
select tst.check(tst.weeks_ok(auth.uid()), 'geri alınca hafta yeniden hesaplandı');
select public.parent_lesson_practice('ovgu', public.tr_today(), true);
select tst.check(tst.weeks_ok(auth.uid()), 'yeniden işaret');

-- ---------------------------------------------------------------- 3. ikinci ders: önceki öğrenildi, aynı gün yeni taş yok
select tst.check((select count(*) from jsonb_array_elements(public.parent_lesson_start('talimat') -> 'mine') e
                  where e ->> 'lesson_key' = 'ovgu' and e ->> 'status' = 'learned') = 1, 'uygulanan ders öğrenildi');
insert into tst.kv values ('stones_before', tst.lesson_stones(auth.uid())::text);
select tst.check((public.parent_lesson_practice('talimat') ->> 'stone_given')::int = 0, 'aynı gün başka ders: taş yok (gün başına)');
select tst.check(tst.lesson_stones(auth.uid()) = (select v::int from tst.kv where k = 'stones_before'), 'taş değişmedi');
select tst.check((select count(*) from public.parent_lesson_progress where user_id = auth.uid() and status = 'current') = 1, 'tek "bu haftanın becerisi"');
select tst.fails($$insert into public.parent_lesson_practice (user_id, lesson_key, family_id, day)
                   values (auth.uid(), 'ovgu', public.my_family_id(), current_date - 30)$$, 'istemci uygulama günü yazamaz');
select tst.fails($$insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
                   values (public.my_family_id(), auth.uid(), 5, 'lesson', 'lesson|x|1')$$, 'istemci taş yazamaz');
-- başlanmamış ders "paused" olur
select public.parent_lesson_start('ovgu');
select tst.check((select status from public.parent_lesson_progress where user_id = auth.uid() and lesson_key = 'talimat') = 'learned',
  'uygulanan ikinci ders de öğrenildi');
select tst.check((public.parent_lesson_finish('ovgu') -> 'mine' -> 0 ->> 'status') = 'learned', 'Öğrendim');
select tst.check((select count(*) from public.parent_lesson_progress where user_id = auth.uid() and status = 'current') = 0, 'bu haftanın becerisi boş');
select tst.fails($$select public.parent_lesson_finish('taslak')$$, 'başlanmamış ders bitirilemez', 'lesson_not_started');

-- ---------------------------------------------------------------- 4. diğer ebeveyn: ayrı cüzdan; yabancı ve çocuk
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(jsonb_array_length(public.family_lessons() -> 'mine') = 0, 'Baba: kendi dersleri yok');
select tst.check((select count(*) from public.parent_lesson_progress) = 2, 'Baba: ailenin ders kayıtlarını okur');
select public.parent_lesson_start('ovgu');
select tst.check((public.parent_lesson_practice('ovgu') ->> 'stone_given')::int = 1, 'Baba: kendi taşı');
select tst.check((public.family_lessons() ->> 'balance')::int = 1, 'Baba bakiyesi ayrı');
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.parent_lesson_progress) = 0 and (select count(*) from public.parent_lesson_practice) = 0,
  'yabancı aile göremez');
select tst.check(jsonb_array_length(public.family_lessons() -> 'mine') = 0, 'yabancı: kendi listesi boş');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.fails($$select public.family_lessons()$$, 'çocuk cihazı ebeveyn derslerini açamaz');
select tst.fails($$select public.parent_lesson_start('ovgu')$$, 'çocuk derse başlayamaz');

-- ---------------------------------------------------------------- 5. uzman önerisi
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'asg', public.clinic_assign_lesson('00000000-0000-0000-0000-0000000011a1', 'talimat', 'Bu hafta akşam rutininde dene')::text;
select tst.check(public.clinic_assign_lesson('00000000-0000-0000-0000-0000000011a1', 'talimat', 'Not güncel')::text
  = (select v from tst.kv where k = 'asg'), 'aynı ders ikinci kez: aynı öneri (not güncellenir)');
select tst.fails($$select public.clinic_assign_lesson('00000000-0000-0000-0000-0000000011a1', 'taslak')$$, 'taslak ders önerilemez', 'lesson_not_found');
select tst.check((select count(*) from public.parent_lesson_assignments) = 1, 'uzman kendi önerisini okur');
select tst.check(jsonb_array_length(public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1')) = 1, 'uzman: öneri listesi');
-- Anne talimat'a öneriden önce başlamıştı: öneriye bağlandı, öneri gününden sonraki günler görünür; ovgu hiç görünmez
select tst.check((select count(*) from jsonb_array_elements(public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1') -> 0 -> 'parents')) = 1,
  'uzman: dersi yapan ebeveyn (Anne)');
select tst.check((public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1') -> 0 -> 'parents' -> 0 ->> 'name') = 'Anne'
  and jsonb_array_length(public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1') -> 0 -> 'parents' -> 0 -> 'days') = 1,
  'uzman: yalnız öneri gününden sonraki uygulama günü');
select tst.check(position('ovgu' in public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1')::text) = 0,
  'uzman ebeveynin kendi seçtiği dersi görmez');
select tst.fails($$select count(*) from public.parent_lesson_progress where false or public.clinic_parent_lessons('00000000-0000-0000-0000-000000000000') is null$$,
  'uzman başka paylaşımı göremez', 'link_not_visible');
select tst.check((select count(*) from public.parent_lesson_progress) = 0, 'uzman tablolara doğrudan bakamaz');
reset role;
select tst.check((select count(*) from public.notifications where kind = 'lesson_assigned') = 2, 'iki ebeveyne bildirim (bir kez)');
set role authenticated;

select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.fails($$select public.clinic_assign_lesson('00000000-0000-0000-0000-0000000011a1', 'ovgu')$$, 'başka klinik öneremez', 'link_not_visible');
select tst.fails($$select public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1')$$, 'başka klinik göremez', 'link_not_visible');
select tst.check((select count(*) from public.parent_lesson_assignments) = 0, 'başka klinik öneriyi okuyamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(jsonb_array_length(public.family_lessons() -> 'assigned') = 1, 'Baba: Uzmanının önerisi görünür');
select tst.check((public.family_lessons() -> 'assigned' -> 0 ->> 'link_id') = '00000000-0000-0000-0000-0000000011a1', 'öneride paylaşım kimliği');
select public.parent_lesson_start('talimat');
select tst.check((select assignment_id::text from public.parent_lesson_progress where user_id = auth.uid() and lesson_key = 'talimat')
  = (select v from tst.kv where k = 'asg'), 'öneriden başlanan ders öneriye bağlı');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from jsonb_array_elements(public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1') -> 0 -> 'parents')) = 2,
  'uzman: iki ebeveyn');

-- ---------------------------------------------------------------- 6. paylaşım biter / öneri geri çekilir
reset role;
update public.clinic_links set status = 'revoked', revoked_at = now() where id = '00000000-0000-0000-0000-0000000011a1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(jsonb_array_length(public.family_lessons() -> 'assigned') = 0, 'paylaşım bitince öneri aileden kalkar');
select tst.check((select count(*) from public.parent_lesson_progress where user_id = auth.uid()) = 2, 'ebeveynin dersleri kendisinde kalır');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(coalesce(jsonb_array_length(public.clinic_parent_lessons('00000000-0000-0000-0000-0000000011a1') -> 0 -> 'parents'), 0) = 0,
  'paylaşım bitince uzman ebeveyn bilgisini görmez');
select tst.fails($$select public.clinic_assign_lesson('00000000-0000-0000-0000-0000000011a1', 'ovgu')$$, 'bitmiş paylaşıma öneri yok');
reset role;
update public.clinic_links set status = 'active', revoked_at = null where id = '00000000-0000-0000-0000-0000000011a1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_withdraw_lesson((select v from tst.kv where k = 'asg')::uuid);
select tst.fails($$select public.clinic_withdraw_lesson((select v from tst.kv where k = 'asg')::uuid)$$, 'iki kez geri çekilmez', 'assignment_not_found');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(jsonb_array_length(public.family_lessons() -> 'assigned') = 0, 'geri çekilen öneri aileden kalkar');

-- ---------------------------------------------------------------- 7. haftalık hesap (sabit hafta)
reset role;
insert into public.parent_lesson_practice (user_id, lesson_key, family_id, day)
select '00000000-0000-0000-0000-0000000000a1', 'ovgu', p.family_id, date '2026-10-05' + g
  from public.profiles p, generate_series(0, 4) g where p.id = '00000000-0000-0000-0000-0000000000a1';
select tst.check(public.parent_lesson_week_stones('00000000-0000-0000-0000-0000000000a1',
  (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), date '2026-10-05') = 3, '5 gün → 3 taş');
delete from public.parent_lesson_practice where user_id = '00000000-0000-0000-0000-0000000000a1' and day >= date '2026-10-07' and day <= date '2026-10-09';
select tst.check(public.parent_lesson_week_stones('00000000-0000-0000-0000-0000000000a1',
  (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), date '2026-10-05') = 2, '2 güne inince 2 taş');
select tst.check((select sum(amount) from public.parent_stone_ledger where user_id = '00000000-0000-0000-0000-0000000000a1'
                   and split_part(ref, '|', 2) = '2026-10-05') = 2, 'defter: 3 − 1 = 2');
select tst.check(tst.weeks_ok('00000000-0000-0000-0000-0000000000a1'), 'Anne: bütün haftalar tutarlı');
select tst.fails($$insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
                   select family_id, id, 1, 'baska', 'x' from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'$$,
  'bilinmeyen taş nedeni reddedilir');
select tst.check(not has_function_privilege('anon', 'public.family_lessons()', 'execute')
  and not has_function_privilege('authenticated', 'public.parent_lesson_week_stones(uuid, uuid, date)', 'execute'),
  'anon çağıramaz; iç hesap istemciye kapalı');
