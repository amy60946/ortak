-- Güvenlik matrisi (21 Ekim 2026): her rol yalnız görmesi gerekeni görür, yazamayacağını yazamaz.
-- Roller: girişsiz (anon), ebeveyn (kendi ailesi / başka aile), çocuk cihazı, uzman (bağlı klinik sahibi / ekip üyesi / başka klinik).
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
-- Yazma denemesi: ya hata verir ya da hiçbir satırı değiştirmez (RLS sessizce süzer)
create or replace function tst.no_effect(sql text, msg text) returns void language plpgsql as $$
declare n integer;
begin
  begin
    execute sql;
    get diagnostics n = row_count;
  exception when others then
    raise notice 'ok (reddedildi): % → %', msg, sqlerrm;
    return;
  end;
  if n > 0 then raise exception 'TEST BAŞARISIZ (% satır değişti): %', n, msg; end if;
  raise notice 'ok (etkisiz): %', msg;
end $$;
-- Çağıranın gördüğü satır sayısı (tabloya hiç yetkisi yoksa 0: göremiyor demektir)
create or replace function tst.cnt(t text) returns integer language plpgsql as $$
declare n integer;
begin
  execute format('select count(*) from %s', t) into n;
  return n;
exception when insufficient_privilege then
  return 0;
end $$;
create table if not exists tst.kv (k text primary key, v text);
grant usage on schema tst to anon, authenticated;
grant all on tst.kv to anon, authenticated;
grant execute on all functions in schema tst to anon, authenticated;

-- ---------------------------------------------------------------- kurulum (yönetici)
-- p1 ebeveyn (aile 1: Nazlı c1 cihazlı, Efe c2), p2 başka aile (Deniz c3); u1 Nazlı'nın cihazı
-- d1 klinik sahibi, d2 aynı klinikte üye, d3 başka klinik
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne","name":"Ayşe"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba","name":"Ali"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can"}');
insert into tst.kv select 'f1', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into tst.kv select 'f2', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a2';
insert into tst.kv select 'k1', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into public.children (id, family_id, name, avatar, user_id) values
  ('00000000-0000-0000-0000-00000000c001', (select v::uuid from tst.kv where k = 'f1'), 'Nazlı', 'kedi', '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-00000000c002', (select v::uuid from tst.kv where k = 'f1'), 'Efe', 'kedi', null),
  ('00000000-0000-0000-0000-00000000c003', (select v::uuid from tst.kv where k = 'f2'), 'Deniz', 'kedi', null);
insert into public.tasks (id, family_id, title, start_date, recurring, requires_review) values
  ('00000000-0000-0000-0000-0000000007a1', (select v::uuid from tst.kv where k = 'f1'), 'Yatak', current_date - 3, true, true),
  ('00000000-0000-0000-0000-0000000007a2', (select v::uuid from tst.kv where k = 'f1'), 'Bitki', current_date - 3, true, true),
  ('00000000-0000-0000-0000-0000000007a3', (select v::uuid from tst.kv where k = 'f2'), 'Kitap', current_date - 3, true, true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-0000000007a1', '00000000-0000-0000-0000-00000000c001', (select v::uuid from tst.kv where k = 'f1'), 'easy', 5),
  ('00000000-0000-0000-0000-0000000007a2', '00000000-0000-0000-0000-00000000c002', (select v::uuid from tst.kv where k = 'f1'), 'easy', 5),
  ('00000000-0000-0000-0000-0000000007a3', '00000000-0000-0000-0000-00000000c003', (select v::uuid from tst.kv where k = 'f2'), 'easy', 5);
insert into public.messages (family_id, child_id, sender, sender_id, kind, body)
  values ((select v::uuid from tst.kv where k = 'f1'), '00000000-0000-0000-0000-00000000c001', 'parent', '00000000-0000-0000-0000-0000000000a1', 'text', 'Aferin');
insert into storage.objects (bucket_id, name) values
  ('abc', (select v from tst.kv where k = 'f1') || '/ses1.m4a'),
  ('mail', (select v from tst.kv where k = 'f1') || '/foto.jpg');

set role authenticated;

-- ekip üyesi d2 (ekip koduyla)
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
insert into tst.kv select 'fam', public.clinic_create_invite('family', 'Sabah') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false,
   jsonb_build_object('account', 'clinician', 'name', 'Mert', 'team_code', (select v from tst.kv where k = 'team')));
set role authenticated;

-- aile 1 Nazlı ile Efe'yi kliniğe paylaşır, zor an (sesli) ve görev onayı
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.redeem_clinic_invite_children((select v from tst.kv where k = 'fam'),
  array['00000000-0000-0000-0000-00000000c001', '00000000-0000-0000-0000-00000000c002']::uuid[]);
insert into public.abc_events (family_id, child_id, behavior, intensity, created_by, audio_path)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'Ağladı', 4, auth.uid(), public.my_family_id()::text || '/ses1.m4a');
select public.review_completion('00000000-0000-0000-0000-0000000007a1', '00000000-0000-0000-0000-00000000c001', current_date - 1, 'approved');
-- uzman notu, hedef ve öneri
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'link1', id::text from public.clinic_links where child_id = '00000000-0000-0000-0000-00000000c001';
insert into tst.kv select 'link2', id::text from public.clinic_links where child_id = '00000000-0000-0000-0000-00000000c002';
insert into public.clinic_notes (link_id, clinic_id, author_id, body)
  values ((select v::uuid from tst.kv where k = 'link1'), public.my_clinic_id(), auth.uid(), 'Gizli klinik notu');
insert into public.clinic_goals (link_id, clinic_id, title, created_by)
  values ((select v::uuid from tst.kv where k = 'link1'), public.my_clinic_id(), 'Hedef', auth.uid());
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, created_by)
  select id, clinic_id, family_id, child_id, 'Öneri', auth.uid() from public.clinic_links where id = (select v::uuid from tst.kv where k = 'link1');

-- ---------------------------------------------------------------- girişsiz (anon)
reset role;
set role anon;
select tst.as_user(null);
select tst.check(tst.cnt('public.children') + tst.cnt('public.tasks') + tst.cnt('public.completions') + tst.cnt('public.abc_events')
  + tst.cnt('public.clinic_notes') + tst.cnt('public.clinic_links') + tst.cnt('public.clinicians') + tst.cnt('public.clinics')
  + tst.cnt('public.profiles') + tst.cnt('public.messages') + tst.cnt('public.notifications') + tst.cnt('public.clinic_task_suggestions')
  + tst.cnt('storage.objects') = 0, 'girişsiz kimse hiçbir satırı görmez');
select tst.fails($$select count(*) from public.app_events$$, 'girişsiz: olay tablosu kapalı');
select tst.fails($$select count(*) from analytics.accounts$$, 'girişsiz: iş görünümleri kapalı');
select tst.fails($$select public.clinic_clients()$$, 'girişsiz: danışan listesi çağrılamaz');
select tst.fails($$select public.track_session('clinic', 'web', '1')$$, 'girişsiz: takip yazılamaz');
select tst.no_effect($$insert into public.abc_events (family_id, child_id, behavior) values ((select v::uuid from tst.kv where k = 'f1'), '00000000-0000-0000-0000-00000000c001', 'x')$$, 'girişsiz: zor an yazılamaz');
reset role;
set role authenticated;

-- ---------------------------------------------------------------- başka klinik (d3)
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(tst.cnt('public.children') = 0, 'başka klinik: çocuk görmez');
select tst.check(tst.cnt('public.tasks') + tst.cnt('public.task_assignments') + tst.cnt('public.completions') = 0, 'başka klinik: görev/tamamlama görmez');
select tst.check(tst.cnt('public.abc_events') = 0, 'başka klinik: zor an görmez');
select tst.check(tst.cnt('public.clinic_notes') + tst.cnt('public.clinic_goals') + tst.cnt('public.clinic_task_suggestions') = 0, 'başka klinik: not/hedef/öneri görmez');
select tst.check(tst.cnt('public.clinic_links') = 0, 'başka klinik: paylaşım görmez');
select tst.check((select count(*) from public.clinic_clients()) = 0, 'başka klinik: danışan listesi boş');
select tst.check(tst.cnt('public.clinicians') = 1, 'başka klinik: yalnız kendi ekibi');
select tst.check(tst.cnt('storage.objects') = 0, 'başka klinik: ses/fotoğraf dosyası görmez');
select tst.check(tst.cnt('public.notifications') = 0, 'başka klinik: başkasının bildirimi yok');
select tst.fails($$select public.clinic_update_suggestion((select id from public.clinic_task_suggestions limit 1), '{"title":"x"}')$$, 'başka klinik: öneri değiştiremez (görmediği kimlik)');
reset role;
insert into tst.kv select 'sug', id::text from public.clinic_task_suggestions limit 1;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.fails($$select public.clinic_update_suggestion((select v::uuid from tst.kv where k = 'sug'), '{"title":"x"}')$$, 'başka klinik: bilinen kimlikle de öneri değiştiremez');
select tst.fails($$select public.revoke_clinic_link((select v::uuid from tst.kv where k = 'link1'))$$, 'başka klinik: paylaşımı sonlandıramaz');
select tst.no_effect($$insert into public.clinic_notes (link_id, clinic_id, author_id, body) values ((select v::uuid from tst.kv where k = 'link1'), (select v::uuid from tst.kv where k = 'k1'), auth.uid(), 'x')$$, 'başka klinik: başka kliniğe not yazamaz');
select tst.no_effect($$insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, created_by) values ((select v::uuid from tst.kv where k = 'link1'), public.my_clinic_id(), (select v::uuid from tst.kv where k = 'f1'), '00000000-0000-0000-0000-00000000c001', 'spam', auth.uid())$$, 'başka klinik: aileye öneri gönderemez');
select tst.fails($$select public.clinic_join_team((select v from tst.kv where k = 'team'))$$, 'kullanılmış ekip kodu ikinci kez kullanılamaz');

-- ---------------------------------------------------------------- bağlı klinik sahibi (d1)
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.children') = 2, 'uzman: yalnız paylaşılan iki çocuk');
select tst.check(tst.cnt('public.tasks') = 2, 'uzman: yalnız paylaşılan çocukların görevleri');
select tst.check(tst.cnt('public.abc_events') = 1, 'uzman: paylaşılan çocuğun zor anı');
select tst.check(tst.cnt('storage.objects') = 1, 'uzman: zor an sesini görür, posta fotoğrafını görmez');
select tst.check(tst.cnt('public.messages') + tst.cnt('public.coin_ledger') + tst.cnt('public.sun_stone_ledger') = 0, 'uzman: posta ve coin/taş defteri paylaşılmaz');
select tst.check(tst.cnt('public.profiles') + tst.cnt('public.families') + tst.cnt('public.invite_codes') + tst.cnt('public.game_saves') = 0, 'uzman: aile kayıtları, kodlar, oyun kaydı kapalı');
select tst.check((select parents from public.clinic_clients() limit 1) = 'Ayşe', 'uzman: ebeveyn adı yalnız RPC ile');
select tst.no_effect($$update public.clinic_links set child_id = '00000000-0000-0000-0000-00000000c003'$$, 'uzman: paylaşımı başka çocuğa çeviremez');
select tst.no_effect($$update public.clinic_links set status = 'active', family_id = (select v::uuid from tst.kv where k = 'f2')$$, 'uzman: paylaşım durum/aile değiştiremez');
select tst.no_effect($$update public.clinicians set role = 'owner', clinic_id = gen_random_uuid() where id = auth.uid()$$, 'uzman: rol/klinik değiştiremez');
select tst.no_effect($$update public.clinics set plan = 'business', seat_limit = 99$$, 'sahip: plan/koltuk değiştiremez');
select tst.no_effect($$insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id) values (public.my_clinic_id(), auth.uid(), (select v::uuid from tst.kv where k = 'f2'), '00000000-0000-0000-0000-00000000c003')$$, 'uzman: kendi kendine paylaşım açamaz');
select tst.no_effect($$insert into public.abc_events (family_id, child_id, behavior) values ((select v::uuid from tst.kv where k = 'f1'), '00000000-0000-0000-0000-00000000c001', 'x')$$, 'uzman: zor an yazamaz (yalnız okur)');
select tst.no_effect($$update public.tasks set title = 'x'$$, 'uzman: görevi değiştiremez');
select tst.no_effect($$update public.completions set status = 'rejected'$$, 'uzman: tamamlamayı değiştiremez');
select tst.no_effect($$update public.clinic_task_suggestions set status = 'accepted'$$, 'uzman: öneriyi kendi kabul edemez');
select tst.no_effect($$update public.family_subscriptions set plan = 'premium'$$, 'uzman: abonelik yazamaz');
select tst.no_effect($$insert into public.notifications (user_id, app, kind, title) values (auth.uid(), 'clinic', 'x', 'x')$$, 'uzman: bildirim uyduramaz');
select tst.fails($$select public.clinic_share_child((select v::uuid from tst.kv where k = 'k1'), '00000000-0000-0000-0000-00000000c003')$$, 'uzman: aile adına çocuk paylaşamaz');
select tst.check(tst.cnt('public.notifications') >= 2, 'uzman: kendi bildirimleri (paylaşım + zor an)');

-- ---------------------------------------------------------------- ekip üyesi (d2)
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(tst.cnt('public.children') = 2, 'ekip üyesi: kliniğin danışanlarını görür');
select tst.check(tst.cnt('public.clinic_notes') = 1, 'ekip üyesi: klinik notlarını görür (aynı klinik)');
select tst.check(tst.cnt('public.notifications') = 0, 'ekip üyesi: sorumlu olmadığı danışanın bildirimi gelmez');
select tst.no_effect($$update public.clinics set name = 'x'$$, 'ekip üyesi: klinik adını değiştiremez');
select tst.fails($$select public.clinic_create_invite('clinician', '')$$, 'ekip üyesi: ekibe davet edemez');

-- ---------------------------------------------------------------- ebeveyn (kendi ailesi, p1)
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(tst.cnt('public.clinic_notes') + tst.cnt('public.clinic_goals') + tst.cnt('public.goal_ratings') = 0, 'ebeveyn: klinik notu/hedefi görmez');
select tst.check(tst.cnt('public.clinicians') + tst.cnt('public.clinics') + tst.cnt('public.clinic_invites') = 0, 'ebeveyn: klinik tablolarını doğrudan görmez');
select tst.check(tst.cnt('public.clinic_task_suggestions') = 1, 'ebeveyn: kendi ailesine gelen öneri');
select tst.check(tst.cnt('public.children') = 2, 'ebeveyn: yalnız kendi çocukları');
select tst.no_effect($$update public.clinic_task_suggestions set title = 'x', clinic_id = gen_random_uuid()$$, 'ebeveyn: önerinin içeriğini değiştiremez');
select tst.no_effect($$update public.profiles set family_id = (select v::uuid from tst.kv where k = 'f2') where id = auth.uid()$$, 'ebeveyn: başka aileye kendini taşıyamaz');
select tst.no_effect($$update public.children set user_id = gen_random_uuid(), family_id = (select v::uuid from tst.kv where k = 'f2')$$, 'ebeveyn: çocuğun cihaz/aile alanını doğrudan değiştiremez');
select tst.no_effect($$insert into public.clinic_notes (link_id, clinic_id, author_id, body) values ((select v::uuid from tst.kv where k = 'link1'), (select v::uuid from tst.kv where k = 'k1'), auth.uid(), 'x')$$, 'ebeveyn: klinik notu yazamaz');
select tst.no_effect($$insert into public.abc_events (family_id, child_id, behavior) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c003', 'x')$$, 'ebeveyn: başka ailenin çocuğuna zor an yazamaz');

-- ---------------------------------------------------------------- başka aile (p2)
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(tst.cnt('public.children') = 1, 'başka aile: yalnız kendi çocuğu');
select tst.check(tst.cnt('public.tasks') + tst.cnt('public.abc_events') + tst.cnt('public.messages') = 1, 'başka aile: yalnız kendi görevi');
select tst.check(tst.cnt('public.clinic_task_suggestions') + tst.cnt('public.clinic_links') = 0, 'başka aile: başka ailenin uzman kayıtlarını görmez');
select tst.check(tst.cnt('storage.objects') = 0, 'başka aile: başka ailenin dosyalarını görmez');
select tst.check(tst.cnt('public.profiles') = 1, 'başka aile: yalnız kendi profili');
select tst.fails($$select public.clinic_share_child((select v::uuid from tst.kv where k = 'k1'), '00000000-0000-0000-0000-00000000c003')$$, 'başka aile: o klinikle paylaşımı yokken kodsuz ekleyemez');
select tst.fails($$select public.revoke_clinic_link((select v::uuid from tst.kv where k = 'link1'))$$, 'başka aile: başkasının paylaşımını sonlandıramaz');

-- ---------------------------------------------------------------- çocuk cihazı (u1)
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(tst.cnt('public.abc_events') = 0, 'çocuk: ebeveynin zor an kayıtlarını görmez');
select tst.check(tst.cnt('public.clinic_notes') + tst.cnt('public.clinic_goals') + tst.cnt('public.clinic_task_suggestions') + tst.cnt('public.clinic_links') = 0, 'çocuk: uzman kayıtlarını görmez');
select tst.check(tst.cnt('public.tasks') = 1, 'çocuk: yalnız kendine atanan görev');
select tst.check(tst.cnt('public.profiles') = 0, 'çocuk: ebeveyn profillerini görmez');
select tst.check((select count(*) from storage.objects where bucket_id = 'abc') = 0, 'çocuk: zor an sesini dinleyemez');
select tst.check((select count(*) from public.clinic_clients()) = 0, 'çocuk: danışan listesi boş');

-- ---------------------------------------------------------------- rıza geri alınınca (aile Efe'yi çıkarır, sonra Nazlı'yı)
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link((select v::uuid from tst.kv where k = 'link2'));
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.children') = 1, 'rıza: çıkarılan çocuk hemen görünmez');
select tst.check((select count(*) from public.clinic_clients()) = 1, 'rıza: danışan listesinden düşer');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link((select v::uuid from tst.kv where k = 'link1'));
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.children') + tst.cnt('public.tasks') + tst.cnt('public.completions') + tst.cnt('public.abc_events') = 0, 'rıza: bütün çocuk verisi kapanır');
select tst.check(tst.cnt('storage.objects') = 0, 'rıza: ses dosyası da kapanır');
select tst.check(tst.cnt('public.clinic_notes') = 1, 'rıza: uzmanın kendi notu klinikte kalır');
select tst.no_effect($$insert into public.clinic_notes (link_id, clinic_id, author_id, body) values ((select v::uuid from tst.kv where k = 'link1'), public.my_clinic_id(), auth.uid(), 'x')$$, 'rıza: bitmiş paylaşıma not eklenemez');
select tst.fails($$select public.clinic_update_suggestion((select v::uuid from tst.kv where k = 'sug'), '{"title":"x"}')$$, 'rıza: bitmiş paylaşımda öneri güncellenemez');
select tst.check(exists (select 1 from public.notifications where kind = 'clinic_revoked'), 'rıza: uzmana "paylaşım durduruldu" bildirimi');

-- ---------------------------------------------------------------- sertleştirme (öneri 20261021200000)
reset role;
select tst.check(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')), 'girişsiz rol hiçbir public fonksiyonu çağıramaz');
select tst.check(has_function_privilege('authenticated', 'public.my_family_id()', 'execute')
  and has_function_privilege('authenticated', 'public.clinic_clients()', 'execute')
  and has_function_privilege('authenticated', 'public.child_set_status(uuid, date, text)', 'execute'), 'giriş yapmış kullanıcının fonksiyonları açık kalır');
select tst.check(not has_function_privilege('authenticated', 'public.notify(uuid, text, text, text, text, jsonb, uuid, uuid)', 'execute'), 'iç bildirim fonksiyonu kapalı kalır');
-- premium: kendi ailesi sorulur, başka aile sorulamaz; SQL Editor her aileyi görür
update public.clinic_links set status = 'active' where id = (select v::uuid from tst.kv where k = 'link1');
select tst.as_user(null);   -- SQL Editor gibi: oturum yok
select tst.check(public.family_premium((select v::uuid from tst.kv where k = 'f1')), 'yönetici: aile 1 premium (etkin klinik)');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.family_premium(), 'ebeveyn: kendi ailesi premium');
select tst.check(public.family_premium((select v::uuid from tst.kv where k = 'f1')), 'ebeveyn: kendi aile kimliğiyle de');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check(public.family_premium((select v::uuid from tst.kv where k = 'f1')), 'çocuk cihazı: kendi ailesini sorabilir');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(not public.family_premium((select v::uuid from tst.kv where k = 'f1')), 'başka aile: aile 1 sorulamaz (false)');
reset role;
select tst.as_user(null);
select tst.check((select premium from analytics.families_overview where family_id = (select v::uuid from tst.kv where k = 'f1')), 'iş görünümü premium doğru');

select 'TÜM GÜVENLİK MATRİSİ TESTLERİ GEÇTİ' as sonuc;
