-- Klinik SaaS önerisinin testi (yerel PostgreSQL). Çalıştırma: bash supabase/test/run.sh
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
  begin execute sql;
  exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return;
  end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
-- Kodları testler arasında taşımak için
create table tst.kv (k text primary key, v text);
grant usage on schema tst to authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated;

-- Kimlikler: ebeveyn a1, yabancı ebeveyn e1, uzman (sahip) d1, ekip üyesi d2, başka klinik d9
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece","title":"Klinik Psikolog"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Başka Klinik","name":"Dr. Can"}');

select tst.check((select count(*) from public.profiles where id = '00000000-0000-0000-0000-0000000000a1') = 1, 'ebeveyn kaydı eskisi gibi aile + profil oluşturur');
select tst.check((select count(*) from public.profiles where id = '00000000-0000-0000-0000-0000000000d1') = 0, 'uzman kaydı aile/profil oluşturmaz');
select tst.check((select role from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1') = 'owner', 'uzman kaydı klinik açar, sahibi olur');
select tst.check((select c.name from public.clinics c join public.clinicians m on m.clinic_id = c.id where m.id = '00000000-0000-0000-0000-0000000000d1') = 'Mavi Klinik', 'klinik adı kayıttan gelir');

-- Veri: ebeveyn çocuk + görev + tamamlama (kurulum sahibi olarak)
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c0de', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'flamingo'),
         ('00000000-0000-0000-0000-00000000c0d2', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Efe', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, requires_review)
  values ('00000000-0000-0000-0000-000000007a51', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Odanı topla', current_date - 3, true, 'daily', true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  select '00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', family_id, 'medium', 10
  from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.completions (task_id, child_id, family_id, date, status)
  select '00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c0de', family_id, current_date, 'pending'
  from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
select tst.check((select child_done_at is not null from public.completions limit 1), 'tamamlamada çocuğun "Yaptım" anı kaydedilir');

set role authenticated;

-- ------------------------------------------------ rıza öncesi: uzman hiçbir şey görmez
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.children) = 0, 'bağlantı yokken uzman çocuğu görmez');
select tst.check((select count(*) from public.tasks) = 0, 'bağlantı yokken uzman görevi görmez');
select tst.check((select count(*) from public.completions) = 0, 'bağlantı yokken uzman tamamlamayı görmez');
select tst.check((select count(*) from public.families) = 0, 'uzman aile tablosunu görmez');
select tst.check((public.clinician_me() ->> 'role') = 'owner', 'clinician_me sahibi döndürür');
select tst.check((public.clinician_me() ->> 'active')::boolean, 'deneme süresinde klinik etkin');
select tst.fails($$update public.clinics set plan = 'business'$$, 'uzman planı kendisi değiştiremez');
update public.clinics set name = 'Mavi Çocuk Kliniği';
select tst.check((select name from public.clinics) = 'Mavi Çocuk Kliniği', 'sahip klinik adını değiştirir');

insert into tst.kv values ('fam', public.clinic_create_invite('family', 'N. (8)') ->> 'code');
insert into tst.kv values ('team', public.clinic_create_invite('clinician', '') ->> 'code');
select tst.check((select count(*) from public.clinic_invites) = 2, 'uzman kendi davetlerini görür');

-- ------------------------------------------------ ekip: kod ile katılım, koltuk sınırı
reset role;
insert into auth.users (id, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', jsonb_build_object('account', 'clinician', 'team_code', lower((select v from tst.kv where k = 'team')), 'name', 'Ayşe'));
select tst.check((select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2')
               = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1'), 'ekip kodu ile aynı kliniğe üye olunur');
select tst.check((select role from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2') = 'member', 'ekip üyesi sahip değildir');
select tst.fails($$insert into auth.users (id, raw_user_meta_data) values ('00000000-0000-0000-0000-0000000000d3',
  jsonb_build_object('account', 'clinician', 'team_code', (select v from tst.kv where k = 'team')))$$, 'kullanılmış ekip kodu reddedilir');
update public.clinics set seat_limit = 2 where id = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('team2', public.clinic_create_invite('clinician', '') ->> 'code');
reset role;
select tst.fails($$insert into auth.users (id, raw_user_meta_data) values ('00000000-0000-0000-0000-0000000000d4',
  jsonb_build_object('account', 'clinician', 'team_code', (select v from tst.kv where k = 'team2')))$$, 'koltuk doluysa katılım reddedilir');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.fails($$select public.clinic_create_invite('clinician', '')$$, 'üye ekibe davet edemez');
select tst.check((select count(*) from public.clinicians) = 2, 'üye ekibi görür');

-- ------------------------------------------------ ebeveyn rızası
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$select public.redeem_clinic_invite((select v from tst.kv where k = 'fam'), '00000000-0000-0000-0000-00000000c0de')$$, 'yabancı ebeveyn başkasının çocuğunu bağlayamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.fails($$select public.clinic_invite_preview((select v from tst.kv where k = 'fam'))$$, 'uzman aile kodunu önizleyemez');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((public.clinic_invite_preview((select v from tst.kv where k = 'fam')) ->> 'clinician') = 'Dr. Ece', 'ebeveyn rızadan önce uzmanı görür');
select tst.check(not public.family_premium(), 'bağlantıdan önce aile premium değil');
insert into tst.kv values ('link', public.redeem_clinic_invite(lower((select v from tst.kv where k = 'fam')), '00000000-0000-0000-0000-00000000c0de') ->> 'link_id');
select tst.check((select count(*) from public.family_clinic_links()) = 1, 'ebeveyn etkin paylaşımı listeler');
select tst.check(public.family_premium(), 'etkin kliniğe bağlı aile premium (klinik üzerinden)');
select tst.fails($$select public.redeem_clinic_invite((select v from tst.kv where k = 'fam'), '00000000-0000-0000-0000-00000000c0d2')$$, 'aile kodu bir kez kullanılır');

-- ------------------------------------------------ rıza sonrası: uzman yalnız bağlı çocuğu okur
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((select count(*) from public.children) = 1, 'ekip üyesi bağlı çocuğu görür');
select tst.check((select name from public.children) = 'Nazlı', 'yalnız rıza verilen çocuk görünür');
select tst.check((select count(*) from public.tasks) = 1, 'uzman çocuğun görevini görür');
select tst.check((select count(*) from public.completions) = 1, 'uzman tamamlamaları görür');
select tst.check((select count(*) from public.messages) = 0, 'posta uzmanla paylaşılmaz');
update public.tasks set title = 'x';
select tst.check((select title from public.tasks) = 'Odanı topla', 'uzman görevi değiştiremez');
update public.completions set status = 'approved';
select tst.check((select status from public.completions) = 'pending', 'uzman tamamlamayı onaylayamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check((select count(*) from public.children) = 0, 'başka klinik çocuğu görmez');
select tst.check((select count(*) from public.clinic_links) = 0, 'başka klinik bağlantıyı görmez');

-- ------------------------------------------------ not, hedef, puan (yalnız klinik)
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_notes (link_id, clinic_id, author_id, body)
  values ((select v from tst.kv where k = 'link')::uuid, public.my_clinic_id(), auth.uid(), 'İlk görüşme.');
insert into public.clinic_goals (id, link_id, clinic_id, title)
  values ('00000000-0000-0000-0000-00000000600a', (select v from tst.kv where k = 'link')::uuid, public.my_clinic_id(), 'Sabah rutinini kendi başlatır');
insert into public.goal_ratings (goal_id, clinic_id, week, rating)
  values ('00000000-0000-0000-0000-00000000600a', public.my_clinic_id(), date_trunc('week', now())::date, 1);
select tst.fails($$insert into public.goal_ratings (goal_id, clinic_id, week, rating)
  values ('00000000-0000-0000-0000-00000000600a', public.my_clinic_id(), date_trunc('week', now())::date - 7, 3)$$, 'GAS puanı -2..2 dışında olamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.fails($$insert into public.clinic_notes (link_id, clinic_id, author_id, body)
  values ((select v from tst.kv where k = 'link')::uuid, public.my_clinic_id(), auth.uid(), 'x')$$, 'başka klinik bu bağlantıya not yazamaz');
select tst.fails($$insert into public.goal_ratings (goal_id, clinic_id, week, rating)
  values ('00000000-0000-0000-0000-00000000600a', public.my_clinic_id(), current_date, 0)$$, 'başka klinik bu hedefe puan veremez');
select tst.check((select count(*) from public.clinic_notes) = 0, 'başka klinik notları görmez');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_notes) = 0, 'aile uzman notlarını görmez');
select tst.check((select count(*) from public.clinic_goals) = 0, 'aile hedefleri görmez');

-- ------------------------------------------------ ABC kaydı
insert into public.abc_events (family_id, child_id, antecedent, behavior, consequence, intensity, created_by)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'Tablet kapatıldı', 'Ağladı, kapıyı çarptı', 'Sakinleşme köşesi', 4, auth.uid());
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$insert into public.abc_events (family_id, child_id, behavior)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c0de', 'x')$$, 'yabancı ebeveyn başkasının çocuğuna ABC yazamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.abc_events) >= 1, 'bağlı uzman ABC kaydını okur');
select tst.fails($$insert into public.abc_events (family_id, child_id, behavior)
  select family_id, child_id, 'x' from public.clinic_links$$, 'uzman ABC kaydı yazamaz');

-- ------------------------------------------------ görev önerisi
insert into public.clinic_task_suggestions (id, link_id, clinic_id, family_id, child_id, title, created_by)
  select '00000000-0000-0000-0000-00000000500a', l.id, l.clinic_id, l.family_id, l.child_id, 'Kıyafetini akşamdan hazırla', auth.uid()
  from public.clinic_links l;
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title)
  select l.id, l.clinic_id, l.family_id, '00000000-0000-0000-0000-00000000c0d2', 'x' from public.clinic_links l$$, 'öneri bağlantıdaki çocuktan başkasına yazılamaz');
select tst.fails($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, status)
  select l.id, l.clinic_id, l.family_id, l.child_id, 'x', 'accepted' from public.clinic_links l$$, 'uzman öneriyi kabul edilmiş yazamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check((select count(*) from public.clinic_task_suggestions where status = 'pending') = 1, 'aile bekleyen öneriyi görür');
select tst.fails($$update public.clinic_task_suggestions set title = 'x'$$, 'aile öneri metnini değiştiremez');
update public.clinic_task_suggestions set status = 'accepted', decided_at = now();
select tst.check((select status from public.clinic_task_suggestions) = 'accepted', 'aile öneriyi kabul eder');

-- ------------------------------------------------ rızanın geri alınması
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.fails($$select public.revoke_clinic_link((select v from tst.kv where k = 'link')::uuid)$$, 'yabancı paylaşımı sonlandıramaz');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link((select v from tst.kv where k = 'link')::uuid);
select tst.check((select count(*) from public.family_clinic_links()) = 0, 'geri alınan paylaşım listeden düşer');
select tst.check(not public.family_premium(), 'geri alınca klinik premiumu biter');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.children) = 0, 'rıza geri alınınca uzman çocuğu görmez');
select tst.check((select count(*) from public.completions) = 0, 'rıza geri alınınca tamamlamalar kapanır');
select tst.check((select count(*) from public.abc_events) = 0, 'rıza geri alınınca ABC kapanır');
select tst.fails($$insert into public.clinic_notes (link_id, clinic_id, author_id, body)
  values ((select v from tst.kv where k = 'link')::uuid, public.my_clinic_id(), auth.uid(), 'x')$$, 'kapalı bağlantıya not yazılamaz');
select tst.check((select count(*) from public.clinic_notes) = 1, 'uzman geçmiş notlarını korur');
