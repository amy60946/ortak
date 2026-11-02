-- Çocuğa anlık bildirim (proposed/20261102200000_child_push.sql): varsayılan kapalı, yalnız ebeveyn açar, günde en çok 1, sessiz saatler.
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

-- a1 ebeveyn, a3 başka ailenin ebeveyni, c1 çocuk cihazı
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a3', false, '{"nickname":"Komşu"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}');
insert into tst.kv select 'fid', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c001', (select v::uuid from tst.kv where k = 'fid'), 'Nazlı', 'kedi');

-- saat kuralı (Türkiye saati = UTC+3)
select tst.check(public.child_push_quiet('2026-11-07 18:00+00', '20:30', '08:00', true), 'Cumartesi 21:00 gece sessiz');
select tst.check(public.child_push_quiet('2026-11-07 04:30+00', '20:30', '08:00', true), 'Cumartesi 07:30 gece sessiz');
select tst.check(not public.child_push_quiet('2026-11-07 09:00+00', '20:30', '08:00', true), 'Cumartesi 12:00 sessiz değil');
select tst.check(public.child_push_quiet('2026-11-04 09:00+00', '20:30', '08:00', true), 'Çarşamba 12:00 okul saati sessiz');
select tst.check(not public.child_push_quiet('2026-11-04 09:00+00', '20:30', '08:00', false), 'okul sessizliği kapalıysa Çarşamba 12:00 gönderilir');
select tst.check(not public.child_push_quiet('2026-11-04 13:00+00', '20:30', '08:00', true), 'Çarşamba 16:00 sessiz değil');
select tst.check(public.child_push_quiet('2026-11-04 13:00+00', '13:00', '18:00', false), 'gün içi aralık (13:00–18:00) sessiz');

set role authenticated;

-- çocuk cihazı bağlanır
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'ccode', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select v from tst.kv where k = 'ccode'));

-- varsayılan kapalı
select tst.check((public.child_push_settings_me() ->> 'enabled')::boolean = false, 'çocuğa bildirim varsayılan kapalı');
select tst.fails($$select public.parent_set_child_push('00000000-0000-0000-0000-00000000c001', true)$$, 'çocuk kendi bildirimini açamaz');
select tst.fails($$select public.child_push_claim('00000000-0000-0000-0000-0000000000c1')$$, 'istemci gönderim iznini çağıramaz');
select public.register_push_token('c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1', 'child', 'ios');

-- başka ailenin ebeveyni açamaz, göremez
select tst.as_user('00000000-0000-0000-0000-0000000000a3');
select tst.fails($$select public.parent_set_child_push('00000000-0000-0000-0000-00000000c001', true)$$, 'başka aile açamaz');

-- ebeveyn açar
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$select public.parent_set_child_push('00000000-0000-0000-0000-00000000c001', true, '20:00', '20:00')$$, 'aynı başlangıç/bitiş reddedilir');
select tst.check((public.parent_set_child_push('00000000-0000-0000-0000-00000000c001', true, '21:00', '07:30', true) ->> 'quiet_from') = '21:00', 'ebeveyn açar, sessiz saat 21:00');
select tst.check((select count(*) from public.child_push_settings) = 1, 'ebeveyn kendi çocuğunun ayarını görür');
select tst.fails($$insert into public.child_push_settings (child_id, family_id, enabled) values ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), true)$$, 'tabloya doğrudan yazılamaz');

select tst.as_user('00000000-0000-0000-0000-0000000000a3');
select tst.check((select count(*) from public.child_push_settings) = 0, 'başka aile ayarı göremez');

select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.check((public.child_push_settings_me() ->> 'enabled')::boolean, 'çocuk açık olduğunu görür');
select tst.check(public.child_push_settings_me() ->> 'quiet_to' = '07:30', 'çocuk sessiz saati görür');
select tst.check((select count(*) from public.child_push_settings) = 0, 'çocuk tabloyu doğrudan okuyamaz (yalnız RPC)');

-- sunucu tarafı (service_role yerine sahip): günde en çok 1, sessiz saatte yok
reset role;
select tst.check(public.child_push_claim('00000000-0000-0000-0000-0000000000c1', '2026-11-07 09:00+00'), 'Cumartesi 12:00 ilk bildirim gider');
select tst.check(not public.child_push_claim('00000000-0000-0000-0000-0000000000c1', '2026-11-07 12:00+00'), 'aynı gün ikincisi gitmez');
select tst.check(not public.child_push_claim('00000000-0000-0000-0000-0000000000c1', '2026-11-08 03:00+00'), 'Pazar 06:00 sessiz saatte gitmez');
select tst.check(public.child_push_claim('00000000-0000-0000-0000-0000000000c1', '2026-11-08 10:00+00'), 'Pazar 13:00 yeni gün, gider');
select tst.check(not public.child_push_claim('00000000-0000-0000-0000-0000000000c1', '2026-11-09 09:00+00'), 'Pazartesi 12:00 okul saati, gitmez');
select tst.check(not public.child_push_claim('00000000-0000-0000-0000-0000000000a1'), 'çocuk olmayan kullanıcıya gitmez');

-- kapatınca gönderim durur, cihaz anahtarı silinir
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.parent_set_child_push('00000000-0000-0000-0000-00000000c001', false);
reset role;
select tst.check(not public.child_push_claim('00000000-0000-0000-0000-0000000000c1', '2026-11-10 14:00+00'), 'kapalıyken gitmez');
select tst.check((select count(*) from public.push_tokens where app = 'child') = 0, 'kapatınca çocuğun cihaz anahtarı silinir');
