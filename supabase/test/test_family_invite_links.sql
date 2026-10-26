-- Aile davet bağlantısı, geçmiş aktarımı, takip planı (proposed/20261026100000_family_invite_links.sql)
\set ON_ERROR_STOP on

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
create or replace function tst.cnt(t text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute format('select count(*) from %s', t) into n;
  return n;
exception when insufficient_privilege then return 0;
end $$;
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- d1 sahip (Mavi), d2 üye (Mavi), d3 başka klinik (Yeşil); a1 aile (Nazlı)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false, jsonb_build_object('account', 'clinician', 'name', 'Mert', 'team_code', tst.v('team')));

-- ---------------------------------------------------------------- 1. davet oluşturma
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'i1', (public.clinic_create_invite('family', 'Nazlı', 'Ayşe', 'Ayse@Ornek.com')) ::text;
insert into tst.kv values ('c1', (tst.v('i1')::json) ->> 'code'), ('t1', (tst.v('i1')::json) ->> 'token');
select tst.check(tst.v('t1') ~ '^[0-9a-f]{32}$', 'bağlantı anahtarı 32 karakter');
select tst.check(char_length(tst.v('c1')) = 6, 'yazılabilir kod 6 karakter');
select tst.check((select expires_at - created_at from public.clinic_invites where code = tst.v('c1')) between interval '47 hours 59 minutes' and interval '48 hours 1 minute', 'aile daveti 48 saat');
select tst.check((select parent_email from public.clinic_invites where code = tst.v('c1')) = 'ayse@ornek.com', 'e-posta küçük harfe');
select tst.fails($$select public.clinic_create_invite('family', '', '', 'bozuk')$$, 'geçersiz e-posta reddedilir');
select public.clinic_invite_mark(tst.v('c1'), 'whatsapp');
select tst.check((select channel from public.clinic_invites where code = tst.v('c1')) = 'whatsapp', 'kanal kaydı');
-- taslak plan (davete bağlı)
insert into public.clinic_goals (invite_code, clinic_id, title, domain, measure, baseline, target, weeks, home_support, shared)
  values (tst.v('c1'), public.my_clinic_id(), 'Sabah rutinini hatırlatmasız bitirir', 'Günlük rutin', 'percent', '%30', '%80', 8, 'Görsel çizelge', true),
         (tst.v('c1'), public.my_clinic_id(), 'Gizli klinik hedefi', 'Duygu', 'level', '', '', null, '', false);
insert into public.care_modules (invite_code, clinic_id, title, aim, practice, checklist, status)
  values (tst.v('c1'), public.my_clinic_id(), 'Olumlu ilgi', 'Günde 10 dakika özel zaman', 'Çocuk seçer, sen eşlik edersin', '["Telefon kapalı","Övgü ver"]', 'active');
select tst.check((select created_by from public.care_modules limit 1) = auth.uid(), 'oluşturan sunucudan');

-- üye sahibin davetini görmez; sahip üyenin davetini görür
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'c2', public.clinic_create_invite('family', 'Efe') ->> 'code';
select tst.check(tst.cnt('public.clinic_invites') = 1, 'üye yalnız kendi davetini görür');
select tst.check(tst.cnt('public.clinic_goals') = 0 and tst.cnt('public.care_modules') = 0, 'üye sahibin taslak planını görmez');
select tst.fails($$select public.clinic_invite_mark(tst.v('c1'), null, true)$$, 'üye sahibin davetini iptal edemez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_invites_list(30)) = 2, 'sahip ekibin davetlerini listeler');
select tst.check((select status from public.clinic_invites_list(30) where code = tst.v('c1')) = 'sent', 'durum: gönderildi');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(tst.cnt('public.clinic_invites') = 0 and (select count(*) from public.clinic_invites_list(30)) = 0, 'başka klinik görmez');

-- bağlantı sayfası: yalnız sunucu
select tst.fails($$select public.clinic_invite_open(tst.v('t1'))$$, 'istemci bağlantı sayfası işlevini çağıramaz');
reset role;
set role service_role;
select tst.check(public.clinic_invite_open(tst.v('t1')) ->> 'clinician' = 'Dr. Ece', 'sayfa uzmanı gösterir');
select tst.check(public.clinic_invite_open('0000') ->> 'status' = 'not_found', 'bilinmeyen anahtar');
reset role;
select tst.check((select opened_at is not null from public.clinic_invites where code = tst.v('c1')), 'açıldı işaretlenir');

-- ---------------------------------------------------------------- 2. bağlantıyla kayıt → davet aileye bağlanır
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b1', false, 'baba@ornek.com', jsonb_build_object('nickname', 'Baba', 'clinic_invite', tst.v('t1')));
select tst.check((select claimed_family from public.clinic_invites where code = tst.v('c1'))
                 = (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'), 'kayıtta bağlantı daveti bağlanır');
select tst.check(exists (select 1 from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'invite_claimed'), 'uzmana: davet kabul edildi');
select tst.check(not exists (select 1 from public.clinic_links where clinic_id = (select clinic_id from public.clinic_invites where code = tst.v('c1'))), 'çocuk verisi henüz paylaşılmaz');

-- e-postayla eşleşme
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'c3', public.clinic_create_invite('family', 'Ali', '', 'yeni@ornek.com') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b2', false, 'YENI@ornek.com', '{"nickname":"Veli"}');
select tst.check((select claimed_at is not null from public.clinic_invites where code = tst.v('c3')), 'e-postası eşleşen kayıtta davet bağlanır');
-- bozuk anahtar kaydı engellemez
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b3', false, '{"nickname":"X","clinic_invite":"YOKKOD"}');
select tst.check(exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000b3'), 'geçersiz davetle kayıt yine açılır');

-- ---------------------------------------------------------------- 3. 48 saat sonra: bağlı aile kullanır, başkası kullanamaz
update public.clinic_invites set expires_at = now() - interval '1 hour' where code in (tst.v('c1'), tst.v('c3'));
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c009', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b1'), 'Deniz', 'kedi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.claim_clinic_invite(tst.v('t1')) ->> 'reason' = 'used', 'başka ailenin bağladığı davet kullanılamaz');
select tst.check(public.clinic_invite_preview(tst.v('c1')) ->> 'reason' = 'used', 'önizleme de reddeder');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check(public.clinic_invite_preview(tst.v('c1')) ->> 'clinician' = 'Dr. Ece', 'bağlayan aile 48 saatten sonra da önizler');
select tst.check((select count(*) from public.family_pending_invites()) = 1 and (select has_plan from public.family_pending_invites()), 'bekleyen davet + plan var');
select tst.check(public.redeem_clinic_invite_children(tst.v('t1'), array['00000000-0000-0000-0000-00000000c009'::uuid]) -> 'link_ids' is not null, 'bağlantı anahtarıyla çocuk paylaşılır');
insert into tst.kv select 'L1', link_id::text from public.family_clinic_links() limit 1;
select tst.check((select count(*) from public.family_pending_invites()) = 0, 'bekleyen davet kalmaz');
-- aile: paylaşılan hedef + modül görünür, gizli hedef görünmez
select tst.check(tst.cnt('public.clinic_goals') = 1 and tst.cnt('public.care_modules') = 1, 'aile paylaşılan hedefi ve modülü görür');
select tst.check(json_array_length(public.family_care_plan(tst.v('L1')::uuid) -> 'goals') = 1, 'aile plan özeti');
select tst.check(not exists (select 1 from public.notifications where user_id = auth.uid() and kind = 'care_plan_shared'), 'paylaşan ebeveyn kendine bildirim almaz');
-- uygulama kaydı
insert into public.care_module_logs (module_id, difficulty, note) select id, 2, 'iyi gitti' from public.care_modules;
insert into public.care_module_logs (module_id, day, practiced, barrier) select id, current_date - 1, false, 'forgot' from public.care_modules;
select tst.check((select bool_and(family_id = public.my_family_id()) from public.care_module_logs), 'aile kimliği sunucudan');
select tst.check(((public.family_care_plan(tst.v('L1')::uuid) -> 'modules') -> 0 ->> 'practiced_week')::int = 1, 'haftalık uygulama sayısı');
select tst.fails($$insert into public.care_module_logs (module_id) select id from public.care_modules$$, 'aynı gün ikinci kayıt yok');
update public.clinic_goals set title = 'x';
reset role;
select tst.check((select title from public.clinic_goals where link_id = tst.v('L1')::uuid and shared) = 'Sabah rutinini hatırlatmasız bitirir', 'hedef değişmedi');
select tst.check(not exists (select 1 from public.clinic_goals where invite_code = tst.v('c1')), 'taslak silindi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.cnt('public.care_module_logs') = 2, 'uzman ebeveynin uygulama kaydını görür');
select tst.check((select status from public.clinic_invites_list(30) where code = tst.v('c1')) = 'shared', 'durum: paylaşıldı');
select tst.check((select shared from public.clinic_invite_stats(30) where clinician_id = auth.uid()) = 1, 'istatistik: 1 paylaşım');
insert into public.goal_ratings (goal_id, clinic_id, week, rating) select id, clinic_id, date_trunc('week', now())::date, 1 from public.clinic_goals where shared;
select public.care_plan_publish(tst.v('L1')::uuid);
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check(tst.cnt('public.goal_ratings') = 0, 'aile haftalık puanı görmez');

-- ---------------------------------------------------------------- 4. süre bildirimi
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
reset role;
update public.clinic_invites set expires_at = now() - interval '1 minute' where code = tst.v('c2');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(public.clinic_invites_sweep() = 0, 'başka klinik süpürmez');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(public.clinic_invites_sweep() = 1, 'süresi dolan davet bildirilir');
select tst.check(public.clinic_invites_sweep() = 0, 'bir kez bildirilir');
select tst.check(exists (select 1 from public.notifications where user_id = auth.uid() and kind = 'invite_expired'), 'uzmana: kullanılmadı');
select tst.fails($$select public.clinic_invites_expire()$$, 'zamanlayıcı işlevi istemciye kapalı');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'c4', public.clinic_create_invite('family', 'İptal') ->> 'code';
insert into public.care_modules (invite_code, clinic_id, title) values (tst.v('c4'), public.my_clinic_id(), 'Taslak');
select public.clinic_invite_mark(tst.v('c4'), null, true);
select tst.check((select status from public.clinic_invites_list(30) where code = tst.v('c4')) = 'revoked', 'iptal');
reset role;
select tst.check(not exists (select 1 from public.care_modules where invite_code = tst.v('c4')), 'iptalde taslak silinir');

-- ---------------------------------------------------------------- 5. uzman değişimi: geçmiş aktarımı
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.clinic_notes (link_id, clinic_id, author_id, body) values (tst.v('L1')::uuid, public.my_clinic_id(), auth.uid(), 'Eski uzmanın notu');
insert into public.clinic_task_suggestions (link_id, clinic_id, family_id, child_id, title, created_by)
  select id, clinic_id, family_id, child_id, 'Eski öneri', auth.uid() from public.clinic_links where id = tst.v('L1')::uuid;
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
insert into tst.kv select 'c5', public.clinic_create_invite('family', 'Deniz') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select public.revoke_clinic_link(tst.v('L1')::uuid);
select public.redeem_clinic_invite_children(tst.v('c5'), array['00000000-0000-0000-0000-00000000c009'::uuid]);
insert into tst.kv select 'L2', link_id::text from public.family_clinic_links();
select tst.check((select history_available and not history_shared from public.family_clinic_links()), 'önceki kayıt aktarılabilir, henüz kapalı');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(tst.cnt('public.clinic_notes') = 0 and tst.cnt('public.clinic_goals') = 0, 'rıza yokken yeni uzman eski kayıtları görmez');
select tst.check(tst.cnt('public.children') = 1, 'çocuğun görev/kayıt verisini zaten görür');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check(public.clinic_link_history_set(tst.v('L2')::uuid, true) = 1, 'aile önceki kayıtları açar');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(tst.cnt('public.clinic_notes') = 1 and tst.cnt('public.clinic_task_suggestions') = 1, 'yeni uzman eski not ve öneriyi okur');
select tst.check(tst.cnt('public.clinic_goals') = 2 and tst.cnt('public.goal_ratings') = 1 and tst.cnt('public.care_modules') = 1
                 and tst.cnt('public.care_module_logs') = 2, 'hedefler, puanlar, aile programı ve uygulama kaydı aktarılır');
select tst.check((select clinician from public.clinic_link_history_of(tst.v('L2')::uuid)) = 'Dr. Ece', 'kimden geldiği görünür');
update public.clinic_notes set body = 'değişti';
delete from public.clinic_notes;
reset role;
select tst.check((select body from public.clinic_notes) = 'Eski uzmanın notu', 'devralınan kayıt salt okunur');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(tst.cnt('public.clinic_notes') = 0, 'eski kliniğin başka üyesi görmez (paylaşım bitti, atanmamış)');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.clinic_link_history_set(tst.v('L2')::uuid, true)$$, 'başka aile aktarımı açamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select public.clinic_link_history_set(tst.v('L2')::uuid, false);
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(tst.cnt('public.clinic_notes') = 0, 'aile geri alınca erişim biter');

-- paylaşırken birlikte açma
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'c6', public.clinic_create_invite('family', '') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select public.redeem_clinic_invite_children(tst.v('c6'), array['00000000-0000-0000-0000-00000000c009'::uuid], true);
select tst.check((select count(*) from public.family_clinic_links() where history_shared) = 1, 'paylaşırken geçmiş birlikte açılır');

-- anon
reset role;
set role anon;
select tst.fails($$select public.claim_clinic_invite('ABCDEF')$$, 'anon davet bağlayamaz');
select tst.fails($$select * from public.clinic_invites_list(30)$$, 'anon liste göremez');
reset role;
select 'AİLE DAVET BAĞLANTISI TESTLERİ GEÇTİ' as sonuc;
