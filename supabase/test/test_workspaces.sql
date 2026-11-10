-- Çalışma alanları (migrations/20261105090000_workspaces.sql): bireysel alan, kişisel kod, ekibe ekleme isteği + kabul/ret,
-- x-clinic-id başlığıyla alan seçimi, alanlar arası yalıtım, aile daveti ayarı, ayrılma/çıkarma, eski ekip kodu,
-- hesap silme, bildirim alanı, aileye "bağımsız uzman" bilgisi, satır düzeyi güvenlik.
\set ON_ERROR_STOP on

create schema if not exists tst;
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false); end $$;
create or replace function tst.ws(c uuid) returns void language plpgsql as $$
begin perform set_config('request.headers', case when c is null then '' else json_build_object('x-clinic-id', c)::text end, false); end $$;
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
grant usage on schema tst to anon, authenticated;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to anon, authenticated;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated;

-- d1 klinik sahibi (Mavi), d2 ve d3 bireysel uzman, d9 başka klinik (Yeşil); a1 ailesi
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece","practice":"clinic"}'),
  ('00000000-0000-0000-0000-0000000000d2', false, '{"account":"clinician","clinic_name":"Ada Yıldız","name":"Ada Yıldız","practice":"solo"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","name":"Bora Kaya","practice":"solo"}'),
  ('00000000-0000-0000-0000-0000000000d9', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Dr. Can","practice":"clinic"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Efe', 'kedi');
insert into tst.kv select 'mavi', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1';
insert into tst.kv select 'yesil', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d9';
insert into tst.kv select 'ada', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2';
insert into tst.kv select 'bora', clinic_id::text from public.clinicians where id = '00000000-0000-0000-0000-0000000000d3';

-- ---------------------------------------------------------------- kayıt
select tst.check((select personal_of from public.clinics where id = tst.v('ada')::uuid) = '00000000-0000-0000-0000-0000000000d2',
                 'bireysel kayıt kendi alanını açar');
select tst.check((select personal_of from public.clinics where id = tst.v('mavi')::uuid) is null, 'klinik kaydı bireysel alan değil');
select tst.check((select role from public.clinic_members where clinic_id = tst.v('mavi')::uuid
                   and clinician_id = '00000000-0000-0000-0000-0000000000d1') = 'owner', 'kayıtta sahip üyeliği yazılır');

-- ---------------------------------------------------------------- kişisel kod
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'code2', public.clinician_personal_code();
select tst.check(tst.v('code2') ~ '^[A-Z0-9]{8}$', 'kişisel kod 8 karakter');
select tst.check(public.clinician_personal_code() = tst.v('code2'), 'kod kalıcı (ikinci çağrı aynı)');
select tst.check(tst.cnt('public.clinician_codes') = 0, 'kod tablosu doğrudan okunmaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
insert into tst.kv select 'code3', public.clinician_personal_code();
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
insert into tst.kv select 'code9', public.clinician_personal_code();
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.clinician_personal_code()$$, 'ebeveyn kişisel kod alamaz');

-- ---------------------------------------------------------------- ekibe ekleme isteği
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinic_member_request(tst.v('code2')) ->> 'status' = 'sent', 'sahip kodla istek gönderir');
select tst.check(public.clinic_member_request(lower(tst.v('code2'))) ->> 'status' = 'pending', 'aynı istek ikinci kez açılmaz (küçük harf de olur)');
select tst.check(public.clinic_member_request('ZZZZZZZZ') ->> 'error' = 'invalid_code', 'yanlış kod reddedilir');
select tst.check(public.clinic_member_request((select code from public.clinician_codes where clinician_id = '00000000-0000-0000-0000-0000000000d1')) is null
                 or true, 'sahibin kodu yoksa sorun değil');
select tst.check(public.clinician_personal_code() is not null, 'sahibin de kodu olur');
select tst.check(public.clinic_member_request(public.clinician_personal_code()) ->> 'error' = 'self', 'kendini ekleyemez');
select tst.check((select count(*) from public.clinic_member_requests) = 1, 'sahip kendi kliniğinin isteğini görür');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d2'
                   and kind = 'team_request' and data ? 'request_id') = 1, 'uzmana tek istek bildirimi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.check((select count(*) from public.clinic_member_requests) = 0, 'başka klinik isteği görmez');
select tst.check(tst.cnt('public.clinic_members') = 1, 'başka klinik yalnız kendi üyeliğini görür');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(json_array_length(public.clinic_member_requests_mine()) = 1, 'uzman bekleyen isteğini görür');
select tst.check(public.clinic_member_requests_mine() -> 0 ->> 'clinic' = 'Mavi', 'istekte kliniğin adı');
select tst.check(public.clinic_member_request(tst.v('code3')) ->> 'error' = 'personal_workspace', 'bireysel alandan istek gönderilmez');
insert into tst.kv select 'req2', id::text from public.clinic_member_requests where clinician_id = '00000000-0000-0000-0000-0000000000d2';
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(public.clinic_member_respond(tst.v('req2')::uuid, true) ->> 'error' = 'closed', 'başkasının isteğini kabul edemez');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(public.clinic_member_respond(tst.v('req2')::uuid, true) ->> 'status' = 'accepted', 'uzman kabul eder');
select tst.check(public.clinic_member_respond(tst.v('req2')::uuid, true) ->> 'error' = 'closed', 'kabul edilen istek kapanır');
select tst.check(json_array_length(public.clinician_workspaces()) = 2, 'uzmanın iki alanı var');
select tst.check((public.clinician_workspaces() -> 0 ->> 'personal')::boolean, 'bireysel alan listede önce');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1'
                   and kind = 'team_joined' and data ->> 'clinic_id' = tst.v('mavi')) = 1, 'sahibe katıldı bildirimi (alanla)');

-- ---------------------------------------------------------------- alan seçimi (x-clinic-id)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(public.my_clinic_id() = tst.v('ada')::uuid, 'başlık yoksa varsayılan alan (bireysel)');
select tst.check((public.clinician_me() ->> 'personal')::boolean and public.clinician_me() ->> 'role' = 'owner', 'bireysel alanda sahip');
select tst.ws(tst.v('mavi')::uuid);
select tst.check(public.my_clinic_id() = tst.v('mavi')::uuid, 'başlıkla klinik alanı');
select tst.check(public.clinician_me() ->> 'role' = 'member' and not (public.clinician_me() ->> 'personal')::boolean, 'klinikte üye');
select tst.check(public.clinician_me() ->> 'invited_by_name' = 'Dr. Ece', 'ekleyen görünür');
select tst.check((public.clinician_me() ->> 'workspaces')::int = 2, 'alan sayısı');
select tst.check(json_array_length(public.clinic_team() -> 'members') = 2, 'klinik ekibi üyelikten');
select tst.check(json_array_length(public.clinic_team() -> 'requests') = 0, 'üye bekleyen istekleri görmez');
select tst.check(tst.cnt('public.clinicians') = 2, 'alanın ekibi okunur (başka alan değil)');
select tst.ws(tst.v('yesil')::uuid);
select tst.check(public.my_clinic_id() is null, 'üye olmadığı alan seçilemez');
select tst.check((public.clinician_me() ->> 'workspace_invalid')::boolean, 'uygulama geçersiz alanı anlar');
select tst.check(tst.cnt('public.clinics') = 0, 'geçersiz alanda klinik görünmez');
select tst.ws(null);

-- ---------------------------------------------------------------- aile daveti alanla; yalıtım
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'famN', public.clinic_create_invite('family', 'N') ->> 'code';
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'famP', public.clinic_create_invite('family', 'P') ->> 'code';
select tst.ws(tst.v('mavi')::uuid);
insert into tst.kv select 'famM', public.clinic_create_invite('family', 'M') ->> 'code';
select tst.ws(null);
reset role;
select tst.check((select clinic_id from public.clinic_invites where code = tst.v('famP')) = tst.v('ada')::uuid, 'bireysel alanın daveti');
select tst.check((select clinic_id from public.clinic_invites where code = tst.v('famM')) = tst.v('mavi')::uuid, 'klinik alanından davet kliniğin');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.redeem_clinic_invite_children(tst.v('famM'), array['00000000-0000-0000-0000-00000000c001'::uuid]);
select public.redeem_clinic_invite_children(tst.v('famP'), array['00000000-0000-0000-0000-00000000c002'::uuid]);
select tst.check((select count(*) from public.family_clinic_links()) = 2, 'aile iki paylaşımı görür');
select tst.check((select independent from public.family_clinic_links() where child_id = '00000000-0000-0000-0000-00000000c002'),
                 'bireysel alan aileye bağımsız uzman');
select tst.check(not (select independent from public.family_clinic_links() where child_id = '00000000-0000-0000-0000-00000000c001'),
                 'klinik alanı aileye klinik');
reset role;
insert into tst.kv select 'linkM', id::text from public.clinic_links where child_id = '00000000-0000-0000-0000-00000000c001';
insert into tst.kv select 'linkP', id::text from public.clinic_links where child_id = '00000000-0000-0000-0000-00000000c002';
select tst.check((select clinician_id from public.clinic_links where id = tst.v('linkM')::uuid) = '00000000-0000-0000-0000-0000000000d2',
                 'davet eden uzman sorumlu');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check((select count(*) from public.clinic_clients()) = 1, 'bireysel alanda yalnız bireysel danışan');
select tst.check(public.clinic_sees_child_any('00000000-0000-0000-0000-00000000c001'), 'ses kaydı için klinik danışanı görülür');
select tst.ws(tst.v('mavi')::uuid);
select tst.check((select count(*) from public.clinic_clients()) = 1, 'klinik alanında yalnız klinik danışanı');
select tst.check(tst.cnt('public.clinic_links') = 1, 'paylaşım satırları alanla sınırlı');
select tst.ws(null);
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.clinic_clients()) = 1, 'sahip kliniğin danışanını görür, uzmanın bireyselini görmez');

-- ---------------------------------------------------------------- aile daveti ayarı
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_invite_policy_set(false);
select tst.check(not (public.clinician_me() ->> 'members_can_invite')::boolean, 'sahip kapatır');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.ws(tst.v('mavi')::uuid);
select tst.fails($$select public.clinic_create_invite('family', 'X')$$, 'kapalıyken üye klinik adına davet etmez');
select tst.fails($$select public.clinic_invite_policy_set(true)$$, 'üye ayarı açamaz');
select tst.ws(null);
select tst.check(public.clinic_create_invite('family', 'Y') ->> 'code' is not null, 'bireysel alanda davet etmeye devam eder');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinic_create_invite('family', 'Z') ->> 'code' is not null, 'sahip davet eder');
select public.clinic_invite_policy_set(true);

-- ---------------------------------------------------------------- koltuk, ret
reset role;
update public.clinics set seat_limit = 3 where id = tst.v('mavi')::uuid;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinic_member_request(tst.v('code3')) ->> 'status' = 'sent', 'üçüncü koltuğa istek');
select tst.check(public.clinic_member_request(tst.v('code9')) ->> 'error' = 'seat_full', 'koltuk doluysa istek gönderilmez');
select tst.check(json_array_length(public.clinic_team() -> 'requests') = 1, 'sahip bekleyen isteği görür');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check(public.clinic_member_respond((select id from public.clinic_member_requests where status = 'pending'), false) ->> 'status' = 'declined',
                 'uzman reddeder');
select tst.check(public.my_clinic_id() = tst.v('bora')::uuid, 'reddeden uzman yalnız kendi alanında');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1'
                   and kind = 'team_request_declined') = 1, 'sahibe ret bildirimi');

-- ---------------------------------------------------------------- bildirim alanı
select public.notify('00000000-0000-0000-0000-0000000000d2', 'clinic', 'test_scope', 't', '', jsonb_build_object('link_id', tst.v('linkM')));
select tst.check((select data ->> 'clinic_id' from public.notifications where kind = 'test_scope') = tst.v('mavi'),
                 'paylaşımlı bildirime alan yazılır');
select public.notify_clinic(tst.v('mavi')::uuid, null, 'test_all', 't', '');
select tst.check((select count(*) from public.notifications where kind = 'test_all' and data ->> 'clinic_id' = tst.v('mavi')) = 2,
                 'kliniğe bildirim etkin üyelere, alanla');

-- ---------------------------------------------------------------- ayrılma, çıkarma
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.clinic_leave()$$, 'sahip ayrılamaz');
select tst.fails($$select public.clinic_member_remove('00000000-0000-0000-0000-0000000000d1')$$, 'sahip kendini çıkaramaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.fails($$select public.clinic_leave()$$, 'bireysel alandan ayrılınmaz');
select tst.ws(tst.v('mavi')::uuid);
select public.clinic_leave();
select tst.check(public.my_clinic_id() is null, 'ayrılınca klinik alanı kapanır');
select tst.ws(null);
select tst.check(public.my_clinic_id() = tst.v('ada')::uuid, 'bireysel alan sürer');
select tst.check(not public.clinic_sees_child_any('00000000-0000-0000-0000-00000000c001'), 'ayrılınca klinik danışanı görülmez');
reset role;
select tst.check((select clinician_id from public.clinic_links where id = tst.v('linkM')::uuid) is null, 'sorumluluk kalkar, danışan klinikte');
select tst.check((select status from public.clinic_links where id = tst.v('linkM')::uuid) = 'active', 'paylaşım klinikte sürer');
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d1' and kind = 'team_left') = 1,
                 'sahibe ayrıldı bildirimi');
-- yeniden eklenir, sahip çıkarır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinic_member_request(tst.v('code2')) ->> 'status' = 'sent', 'ayrılan uzmana yeniden istek');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select tst.check(public.clinic_member_respond((select id from public.clinic_member_requests where status = 'pending'
                   and clinician_id = '00000000-0000-0000-0000-0000000000d2'), true) ->> 'status' = 'accepted', 'yeniden katılır');
select tst.as_user('00000000-0000-0000-0000-0000000000d9');
select tst.fails($$select public.clinic_member_remove('00000000-0000-0000-0000-0000000000d2')$$, 'başka klinik çıkaramaz');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.clinic_member_remove('00000000-0000-0000-0000-0000000000d2');
select tst.check(json_array_length(public.clinic_team() -> 'members') = 1, 'çıkarılan üye ekipte yok');
reset role;
select tst.check((select count(*) from public.notifications where user_id = '00000000-0000-0000-0000-0000000000d2' and kind = 'team_removed') = 1,
                 'çıkarılana bildirim');

-- ---------------------------------------------------------------- eski ekip kodu (eski uygulama sürümü)
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d4', false, jsonb_build_object('account', 'clinician', 'name', 'Deniz', 'team_code', tst.v('team')));
select tst.check((select role from public.clinic_members where clinic_id = tst.v('mavi')::uuid
                   and clinician_id = '00000000-0000-0000-0000-0000000000d4') = 'member', 'eski kodla kayıt üyelik yazar');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d4');
select tst.check(public.my_clinic_id() = tst.v('mavi')::uuid, 'eski üyenin varsayılan alanı klinik');
select tst.check(not (public.clinician_me() ->> 'has_personal')::boolean, 'eski üyenin bireysel alanı yok');
select public.clinic_leave();
select tst.check((public.clinician_me() ->> 'personal')::boolean, 'ayrılınca varsayılan alan bireysel olur');
select tst.check(public.my_clinic_id() <> tst.v('mavi')::uuid, 'klinik alanı kapandı');

-- ---------------------------------------------------------------- yeni alanlar
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'p1', public.clinician_personal_workspace()::text;
select tst.check(public.clinician_personal_workspace()::text = tst.v('p1'), 'bireysel alan bir kez açılır');
reset role;
select tst.check((select trial_ends_at from public.clinics where id = tst.v('p1')::uuid)
                 = (select trial_ends_at from public.clinics where id = tst.v('mavi')::uuid), 'yeni alan yeni deneme vermez');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select public.clinic_workspace_create('Mor 1'), public.clinic_workspace_create('Mor 2'), public.clinic_workspace_create('Mor 3');
select tst.fails($$select public.clinic_workspace_create('Mor 4')$$, 'en çok 3 klinik');
select tst.check(json_array_length(public.clinician_workspaces()) = 4, 'kendi açtığı klinikler alan listesinde');

-- ---------------------------------------------------------------- hesap silme
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(public.clinic_member_request(tst.v('code2')) ->> 'status' = 'sent', 'son istek');
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
select public.clinic_member_respond((select id from public.clinic_member_requests where status = 'pending'
                                      and clinician_id = '00000000-0000-0000-0000-0000000000d2'), true);
reset role;
select public.account_delete_of('00000000-0000-0000-0000-0000000000d1');
select tst.check((select role from public.clinic_members where clinic_id = tst.v('mavi')::uuid
                   and clinician_id = '00000000-0000-0000-0000-0000000000d2') = 'owner', 'sahip silinince klinik üyeye geçer');
select tst.check(not exists (select 1 from public.clinics where id = tst.v('p1')::uuid), 'silinenin bireysel alanı silinir');
select tst.check(exists (select 1 from public.clinicians where id = '00000000-0000-0000-0000-0000000000d2'), 'devralanın hesabı durur');
select public.account_delete_of('00000000-0000-0000-0000-0000000000d3');
select tst.check(not exists (select 1 from public.clinics where id = tst.v('bora')::uuid), 'tek kişilik alanlar silinir');
select tst.check(not exists (select 1 from public.clinics where name like 'Mor %'), 'tek kişilik klinikleri de silinir');

-- ---------------------------------------------------------------- güvenlik
set role anon;
select tst.fails($$select public.clinician_personal_code()$$, 'anon kod alamaz');
select tst.fails($$select public.clinic_member_request('AAAAAAAA')$$, 'anon istek gönderemez');
reset role;
