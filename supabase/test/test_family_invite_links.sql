-- Aile davet bağlantısı, geçmiş aktarımı, takip planı (migrations/20261026100000_family_invite_links.sql)
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
insert into tst.kv select 'i1', (public.clinic_create_invite('family', 'Nazlı', 'Ayşe', 'Ayse@Ornek.com', ' Deniz ', 'a')) ::text;
insert into tst.kv values ('c1', (tst.v('i1')::json) ->> 'code'), ('t1', (tst.v('i1')::json) ->> 'token');
select tst.check(tst.v('t1') ~ '^[0-9a-f]{32}$', 'bağlantı anahtarı 32 karakter');
select tst.check(char_length(tst.v('c1')) = 6, 'yazılabilir kod 6 karakter');
select tst.check((select expires_at - created_at from public.clinic_invites where code = tst.v('c1')) between interval '47 hours 59 minutes' and interval '48 hours 1 minute', 'aile daveti 48 saat');
select tst.check((select parent_email from public.clinic_invites where code = tst.v('c1')) = 'ayse@ornek.com', 'e-posta küçük harfe');
select tst.fails($$select public.clinic_create_invite('family', '', '', 'bozuk')$$, 'geçersiz e-posta reddedilir');
select tst.check((select child_name = 'Deniz' and child_age_group = 'A' from public.clinic_invites where code = tst.v('c1')), 'çocuk önerisi: ad + yaş grubu');
select tst.fails($$select public.clinic_create_invite('family', '', '', null, 'Efe', 'X')$$, 'geçersiz yaş grubu reddedilir');
select tst.check((select child_name from public.clinic_invites_list(30) where code = tst.v('c1')) = 'Deniz', 'uzman listesinde çocuk önerisi');
insert into tst.kv select 'c7', public.clinic_create_invite('family', '', '', null, 'Gizli', 'K') ->> 'code';
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
insert into tst.kv select 'c2', public.clinic_create_invite('family', 'Efe', '', null, 'Efe', 'B') ->> 'code';
select tst.check(tst.cnt('public.clinic_invites') = 1, 'üye yalnız kendi davetini görür');
select tst.check((select count(*) from public.clinic_invites_list(30)) = 1, 'üye listesi yalnız kendi daveti');
select tst.check(tst.cnt('public.clinic_goals') = 0 and tst.cnt('public.care_modules') = 0, 'üye sahibin taslak planını görmez');
select tst.fails($$select public.clinic_invite_mark(tst.v('c1'), null, true)$$, 'üye sahibin davetini iptal edemez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_invites_list(30)) = 3, 'sahip ekibin davetlerini listeler');
select tst.check((select status from public.clinic_invites_list(30) where code = tst.v('c1')) = 'sent', 'durum: gönderildi');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(tst.cnt('public.clinic_invites') = 0 and (select count(*) from public.clinic_invites_list(30)) = 0, 'başka klinik görmez');

-- bağlantı sayfası: yalnız sunucu
select tst.fails($$select public.clinic_invite_open(tst.v('t1'))$$, 'istemci bağlantı sayfası işlevini çağıramaz');
reset role;
set role service_role;
select tst.check(public.clinic_invite_open(tst.v('t1')) ->> 'clinician' = 'Dr. Ece', 'sayfa uzmanı gösterir');
select tst.check(position('Deniz' in public.clinic_invite_open(tst.v('t1'))::text) = 0, 'açılış sayfasında çocuk adı yok');
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
-- 20261026300000: e-postayla eşleşme yalnız e-posta GERÇEKTEN doğrulanınca (kayıtla aynı anda kendiliğinden onay eşleşmez)
insert into auth.users (id, is_anonymous, email, raw_user_meta_data, created_at) values
  ('00000000-0000-0000-0000-0000000000b2', false, 'YENI@ornek.com', '{"nickname":"Veli"}', now() - interval '10 minutes');
select tst.check((select claimed_at is null from public.clinic_invites where code = tst.v('c3')), 'doğrulanmamış e-postayla davet bağlanmaz');
update auth.users set email_confirmed_at = created_at + interval '2 seconds' where id = '00000000-0000-0000-0000-0000000000b2';
select tst.check((select claimed_at is null from public.clinic_invites where code = tst.v('c3')), 'kayıtla aynı anda kendiliğinden onay eşleşmez');
update auth.users set email_confirmed_at = null where id = '00000000-0000-0000-0000-0000000000b2';
update auth.users set email_confirmed_at = now() where id = '00000000-0000-0000-0000-0000000000b2';
select tst.check((select claimed_at is not null from public.clinic_invites where code = tst.v('c3')), 'e-postası doğrulanınca davet bağlanır');
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
select tst.check(public.clinic_invite_preview(tst.v('c7')) ->> 'clinician' = 'Dr. Ece'
                 and public.clinic_invite_preview(tst.v('c7')) ->> 'child_name' is null, 'bağlamamış aile kodla çocuk adını göremez');
select tst.check(tst.cnt('public.clinic_invites') = 0, 'aile davet tablosunu okumaz');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select tst.check(public.clinic_invite_preview(tst.v('c1')) ->> 'clinician' = 'Dr. Ece', 'bağlayan aile 48 saatten sonra da önizler');
select tst.check(public.clinic_invite_preview(tst.v('c1')) ->> 'child_name' = 'Deniz', 'bağlayan aile çocuk önerisini görür');
select tst.check(public.claim_clinic_invite(tst.v('t1')) ->> 'child_name' = 'Deniz'
                 and public.claim_clinic_invite(tst.v('t1')) ->> 'label' is null, 'uzmanın kendi notu aileye dönmez');
select tst.check((select child_name = 'Deniz' and child_age_group = 'A' from public.family_pending_invites()), 'bekleyen davette çocuk önerisi');
select tst.check((select count(*) from public.family_pending_invites()) = 1 and (select has_plan from public.family_pending_invites()), 'bekleyen davet + plan var');
select tst.check(public.redeem_clinic_invite_children(tst.v('t1'), array['00000000-0000-0000-0000-00000000c009'::uuid]) -> 'link_ids' is not null, 'bağlantı anahtarıyla çocuk paylaşılır');
insert into tst.kv select 'L1', link_id::text from public.family_clinic_links() limit 1;
select tst.check((select count(*) from public.family_pending_invites()) = 0, 'bekleyen davet kalmaz');
-- aile: paylaşılan hedef + modül görünür, gizli hedef görünmez
-- 20261026300000: aile tablolara bakmaz, yalnız gönderilen sürümü işlevle okur; davet taslağı paylaşımla gönderilir
select tst.check(tst.cnt('public.clinic_goals') = 0 and tst.cnt('public.care_modules') = 0, 'aile plan tablolarını doğrudan okumaz');
select tst.check(json_array_length(public.family_care_plan(tst.v('L1')::uuid) -> 'goals') = 1
                 and json_array_length(public.family_care_plan(tst.v('L1')::uuid) -> 'modules') = 1, 'aile paylaşılan hedefi ve modülü görür');
insert into tst.kv select 'M1', (public.family_care_plan(tst.v('L1')::uuid) -> 'modules') -> 0 ->> 'id';
select tst.check(not exists (select 1 from public.notifications where user_id = auth.uid() and kind = 'care_plan_shared'), 'paylaşan ebeveyn kendine bildirim almaz');
-- uygulama kaydı
insert into public.care_module_logs (module_id, difficulty, note) values (tst.v('M1')::uuid, 2, 'iyi gitti');
insert into public.care_module_logs (module_id, day, practiced, barrier) values (tst.v('M1')::uuid, current_date - 1, false, 'forgot');
select tst.fails($$insert into public.care_module_logs (module_id, day) values (tst.v('M1')::uuid, current_date + 5)$$, 'ileri tarihli kayıt yok');
select tst.check((select bool_and(family_id = public.my_family_id()) from public.care_module_logs), 'aile kimliği sunucudan');
select tst.check(((public.family_care_plan(tst.v('L1')::uuid) -> 'modules') -> 0 ->> 'practiced_week')::int = 1, 'haftalık uygulama sayısı');
select tst.fails($$insert into public.care_module_logs (module_id) values (tst.v('M1')::uuid)$$, 'aynı gün ikinci kayıt yok');
update public.clinic_goals set title = 'x';
reset role;
select tst.check((select title from public.clinic_goals where link_id = tst.v('L1')::uuid and shared) = 'Sabah rutinini hatırlatmasız bitirir', 'hedef değişmedi');
select tst.check(not exists (select 1 from public.clinic_goals where invite_code = tst.v('c1')), 'taslak silindi');
select tst.check((select child_name is null and child_age_group is null from public.clinic_invites where code = tst.v('c1')), 'paylaşınca çocuk önerisi silinir');
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
reset role;
select tst.check((select child_name is null from public.clinic_invites where code = tst.v('c2')), 'süresi dolunca çocuk önerisi silinir');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.fails($$select public.clinic_invites_expire()$$, 'zamanlayıcı işlevi istemciye kapalı');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'c4', public.clinic_create_invite('family', 'İptal') ->> 'code';
insert into public.care_modules (invite_code, clinic_id, title) values (tst.v('c4'), public.my_clinic_id(), 'Taslak');
select public.clinic_invite_mark(tst.v('c7'), null, true);
reset role;
select tst.check((select child_name is null from public.clinic_invites where code = tst.v('c7')), 'iptalde çocuk önerisi silinir');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
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
select tst.check(public.clinic_link_history_set(tst.v('L2')::uuid, true, 'uzman-gecis-v1') = 1, 'aile önceki kayıtları açar');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(tst.cnt('public.clinic_notes') = 0 and tst.cnt('public.clinic_task_suggestions') = 0 and tst.cnt('public.clinic_goals') = 0
                 and tst.cnt('public.care_modules') = 0 and tst.cnt('public.clinic_link_history') = 0,
                 'yeni uzman tablolara doğrudan erişmez (kimlik sütunları görünmez)');
insert into tst.kv select 'R', public.clinic_inherited_records(tst.v('L2')::uuid)::text;
select tst.check(jsonb_array_length(tst.v('R')::jsonb) = 1 and tst.v('R')::jsonb -> 0 ->> 'label' = 'Önceki uzman 1', 'önceki uzman adsız: "Önceki uzman 1"');
select tst.check(tst.v('R')::jsonb -> 0 -> 'notes' -> 0 ->> 'body' = 'Eski uzmanın notu'
                 and tst.v('R')::jsonb -> 0 -> 'suggestions' -> 0 ->> 'title' = 'Eski öneri', 'yeni uzman eski not ve öneriyi okur');
select tst.check(jsonb_array_length(tst.v('R')::jsonb -> 0 -> 'goals') = 2
                 and (select sum(jsonb_array_length(g -> 'ratings')) from jsonb_array_elements(tst.v('R')::jsonb -> 0 -> 'goals') g) = 1
                 and jsonb_array_length(tst.v('R')::jsonb -> 0 -> 'modules') = 1
                 and jsonb_array_length(tst.v('R')::jsonb -> 0 -> 'modules' -> 0 -> 'logs') = 2,
                 'hedefler, puanlar, aile programı ve uygulama kaydı aktarılır');
select tst.check(position('Dr. Ece' in tst.v('R')) = 0 and position('Mavi' in tst.v('R')) = 0
                 and tst.v('R') !~ '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-',
                 'önceki uzmanın adı, kliniği ve kimlikleri dönmez');
-- metinde geçen ad gizlenir; başka kelimelere dokunulmaz
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
reset role;
-- (önceki dönemin son anında yazılmış not: dönem bittikten sonraki kayıtlar aktarılmaz)
insert into public.clinic_notes (link_id, clinic_id, author_id, body, created_at)
  select tst.v('L1')::uuid, clinic_id, id, 'Ece Hanım görüştü (Mavi Klinik değil, Mavi). Becerisi arttı; ece; ece@ornek.com 0532 123 45 67',
         (select revoked_at from public.clinic_links where id = tst.v('L1')::uuid)
    from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(public.clinic_inherited_records(tst.v('L2')::uuid) -> 0 -> 'notes' -> 0 ->> 'body'
                 = '[önceki uzman] Hanım görüştü ([önceki uzman] Klinik değil, [önceki uzman]). Becerisi arttı; [önceki uzman]; [iletişim] [iletişim]',
                 'metindeki uzman ve klinik adı, e-posta ve telefon gizlenir, "Becerisi" bozulmaz');
select tst.fails($$select public.clinic_redact('x', array['x'])$$, 'gizleme işlevi istemciye kapalı');
update public.clinic_notes set body = 'değişti';
delete from public.clinic_notes;
reset role;
select tst.check((select count(*) from public.clinic_notes where body = 'Eski uzmanın notu') = 1, 'devralınan kayıt salt okunur');
select tst.check((select consent_version from public.clinic_link_history where link_id = tst.v('L2')::uuid) = 'uzman-gecis-v1', 'onaylanan metin sürümü kaydedilir');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(tst.cnt('public.clinic_notes') = 0, 'eski kliniğin başka üyesi görmez (paylaşım bitti, atanmamış)');
select tst.check(jsonb_array_length(public.clinic_inherited_records(tst.v('L2')::uuid)) = 0, 'başka klinik devralınan kayıtları okuyamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.clinic_link_history_set(tst.v('L2')::uuid, true)$$, 'başka aile aktarımı açamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
select public.clinic_link_history_set(tst.v('L2')::uuid, false);
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(jsonb_array_length(public.clinic_inherited_records(tst.v('L2')::uuid)) = 0, 'aile geri alınca erişim biter');

-- paylaşırken birlikte açma
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'c6', public.clinic_create_invite('family', '') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000b1');
-- 20261026300000: yalnız BİTEN paylaşımlar "önceki uzman"dır; çocuğun hâlâ gördüğü uzman (L2) aktarılmaz
select public.revoke_clinic_link(tst.v('L2')::uuid);
select public.redeem_clinic_invite_children(tst.v('c6'), array['00000000-0000-0000-0000-00000000c009'::uuid], true, 'uzman-gecis-v1');
select tst.check((select count(*) from public.family_clinic_links() where history_shared) = 1, 'paylaşırken geçmiş birlikte açılır');

-- ---------------------------------------------------------------- 6. ebeveyn uzmanın önerdiği çocuğu kontrol eder, düzeltir, onaylar
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'i8', public.clinic_create_invite('family', '', 'Zeynep', null, 'Ela', 'B')::text;
insert into tst.kv values ('t8', (tst.v('i8')::json) ->> 'token'), ('c8', (tst.v('i8')::json) ->> 'code');
insert into tst.kv select 'c9', public.clinic_create_invite('family', 'Yanlış aile', '', null, 'Mert', 'A') ->> 'code';
insert into tst.kv select 'c10', public.clinic_create_invite('family', '', '', null, 'Can', 'A') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b4', false, jsonb_build_object('nickname', 'Zeynep', 'clinic_invite', tst.v('t8')));
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c041', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b4'), 'ela ', 'kedi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000b4');
select public.claim_clinic_invite(tst.v('c9'));
select public.claim_clinic_invite(tst.v('c10'));
select tst.check((select count(*) from public.family_pending_invites()) = 3, 'üç bekleyen davet');
select tst.check(public.family_accept_invite(tst.v('t8'), '{"name":"Ela","age_group":"B"}') ->> 'error' = 'duplicate_child', 'aynı adda çocuk varsa önce sorulur');
select tst.check((public.family_accept_invite(tst.v('t8'), '{"name":"Ela","age_group":"B"}') ->> 'child_id')::uuid = '00000000-0000-0000-0000-00000000c041', 'var olan çocuk gösterilir');
select tst.fails($$select public.family_accept_invite(tst.v('t8'), '{"name":"Ela","age_group":"X"}')$$, 'geçersiz yaş grubu');
select tst.fails($$select public.family_accept_invite(tst.v('t8'), null, array['00000000-0000-0000-0000-00000000c001'::uuid])$$, 'başka ailenin çocuğu seçilemez');
insert into tst.kv select 'A8', public.family_accept_invite(tst.v('t8'), '{"name":"Elanur","age_group":"C","birthday":"2014-05-01","gender":"kız"}',
                                                          null, false, 'uzman-paylasim-v1')::text;
select tst.check(json_array_length(tst.v('A8')::json -> 'link_ids') = 1, 'düzeltilen çocuk oluşur ve paylaşılır');
select tst.check((select name = 'Elanur' and age_band is null and birthday = '2014-05-01' from public.children
                   where id = ((tst.v('A8')::json -> 'child_ids') ->> 0)::uuid), 'ebeveynin düzelttiği bilgi kaydedilir (doğum günü var: yaş grubu otomatik)');
select tst.check((select consent_version from public.clinic_links where id = ((tst.v('A8')::json -> 'link_ids') ->> 0)::uuid) = 'uzman-paylasim-v1',
                 'paylaşım onayı metin sürümü kaydedilir');
select tst.check(public.family_accept_invite(tst.v('c10'), '{"name":"Can","age_group":"A"}') -> 'link_ids' is not null, 'öneri aynen onaylanır');
select tst.check((select age_band from public.children where name = 'Can') = 'A', 'doğum günü yoksa önerilen yaş grubu (K/A/B/C) aynen');
select tst.check(public.family_accept_invite(tst.v('c10'), '{"name":"Can 2"}') ->> 'reason' = 'accepted'
                 and not exists (select 1 from public.children where name = 'Can 2'), 'kullanılan davet yeniden onaylanamaz, çocuk oluşmaz');
-- yanlış aile reddeder
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.family_decline_invite(tst.v('c9'))$$, 'başka aile reddedemez');
select tst.as_user('00000000-0000-0000-0000-0000000000b4');
select public.family_decline_invite(tst.v('c9'));
select tst.check(public.claim_clinic_invite(tst.v('c9')) ->> 'reason' = 'declined', 'reddedilen davet kapanır (neden: kapattın)');
select tst.check((select count(*) from public.family_pending_invites()) = 0, 'bekleyen davet kalmaz');
-- uzman tarafı
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.notifications where kind = 'invite_child_updated' and user_id = auth.uid()) = 1
                 and (select body from public.notifications where kind = 'invite_child_updated' and user_id = auth.uid()) = 'Ela (B) → Elanur (C)',
                 'ebeveyn düzeltince uzmana bildirim (aynen onayda yok)');
select tst.check((select child_id is not null from public.notifications where kind = 'invite_child_updated' and user_id = auth.uid()), 'bildirim çocuğa gider');
select tst.check(exists (select 1 from public.notifications where kind = 'invite_declined' and user_id = auth.uid()), 'reddedince uzmana bildirim');
select tst.check((select status from public.clinic_invites_list(30) where code = tst.v('c9')) = 'declined', 'durum: aile reddetti');
select tst.check((select child_name from public.clinic_clients() where child_id = ((tst.v('A8')::json -> 'child_ids') ->> 0)::uuid) = 'Elanur',
                 'onaylanan ad uzmanın danışan listesinde');
reset role;
select tst.check((select count(*) from public.clinic_invites where code in (tst.v('c8'), tst.v('c9'), tst.v('c10')) and child_name is not null) = 0,
                 'davet bitince öneri silinir');
set role authenticated;

-- anon
reset role;
set role anon;
select tst.fails($$select public.claim_clinic_invite('ABCDEF')$$, 'anon davet bağlayamaz');
select tst.fails($$select * from public.clinic_invites_list(30)$$, 'anon liste göremez');
reset role;
select 'AİLE DAVET BAĞLANTISI TESTLERİ GEÇTİ' as sonuc;
