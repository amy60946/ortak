-- Aile daveti e-postayla, 3 gün (proposed/20261027000000_invite_email.sql)
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
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
create or replace function tst.take(c text, u text) returns jsonb language sql as $$
  select public.clinic_invite_email_take(c, u::uuid) $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

-- d1 sahip (Mavi), d2 üye (Mavi), d3 başka klinik (Yeşil); a1 aile
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Ece Kaya","title":"Klinik Psikolog"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Yeşil","name":"Can"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'team', public.clinic_create_invite('clinician', '') ->> 'code';
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', false, jsonb_build_object('account', 'clinician', 'name', 'Mert', 'team_code', tst.v('team')));

-- ---------------------------------------------------------------- 1. 3 gün
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'c1', public.clinic_create_invite('family', 'not', '', 'aile@ornek.com', 'Efe', 'A') ->> 'code';
insert into tst.kv select 'c2', public.clinic_create_invite('family', '', '', null) ->> 'code';
select tst.check((select expires_at - created_at from public.clinic_invites where code = tst.v('c1'))
                 between interval '71 hours 59 minutes' and interval '72 hours 1 minute', 'aile daveti 72 saat');
reset role;
select tst.check(public.clinic_invite_rejected('expired') ->> 'message' like '%3 gün%', 'ret metni 3 gün');

-- ---------------------------------------------------------------- 2. yetki
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.clinic_invite_email_take('X', '00000000-0000-0000-0000-0000000000d1')$$, 'uzman oturumu e-posta hakkını doğrudan alamaz');
select tst.fails($$select public.clinic_invite_email_done('X', true)$$, 'uzman oturumu sonucu yazamaz');
reset role;
set role anon;
select tst.fails($$select public.clinic_invite_email_take('X', '00000000-0000-0000-0000-0000000000d1')$$, 'anon e-posta gönderemez');
reset role;

set role service_role;
select tst.check(tst.take(tst.v('c1'), '00000000-0000-0000-0000-0000000000d3') ->> 'error' = 'not_found', 'başka klinikteki uzman gönderemez');
select tst.check(tst.take(tst.v('c1'), '00000000-0000-0000-0000-0000000000a1') ->> 'error' = 'not_found', 'ebeveyn hesabı gönderemez');
select tst.check(tst.take(tst.v('c1'), '00000000-0000-0000-0000-0000000000d2') ->> 'error' = 'not_found', 'ekip üyesi başkasının davetini gönderemez');
select tst.check(tst.take(tst.v('c2'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'no_email', 'e-postasız davet');

-- ---------------------------------------------------------------- 3. gönderim ve sınırlar
insert into tst.kv select 't1', tst.take(tst.v('c1'), '00000000-0000-0000-0000-0000000000d1')::text;
select tst.check((tst.v('t1')::jsonb) ->> 'to' = 'aile@ornek.com' and (tst.v('t1')::jsonb) ->> 'clinician' = 'Ece Kaya'
                 and (tst.v('t1')::jsonb) ->> 'title' = 'Klinik Psikolog' and (tst.v('t1')::jsonb) ->> 'code' = tst.v('c1'), 'e-posta bilgileri');
select tst.check(not ((tst.v('t1')::jsonb) ? 'child_name') and not ((tst.v('t1')::jsonb) ? 'label'), 'çocuk önerisi ve uzman notu e-postaya girmez');
select tst.check((select email_status = 'sending' and email_count = 1 and channel = 'email' from public.clinic_invites where code = tst.v('c1')), 'gönderiliyor');
select tst.check(tst.take(tst.v('c1'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'too_soon', '60 sn dolmadan yeniden gönderilmez');
select public.clinic_invite_email_done(tst.v('c1'), false);
select tst.check((select email_status = 'failed' and email_count = 0 from public.clinic_invites where code = tst.v('c1')), 'gönderilemeyen sayılmaz');
update public.clinic_invites set email_sent_at = now() - interval '2 minutes' where code = tst.v('c1');
select tst.check(tst.take(tst.v('c1'), '00000000-0000-0000-0000-0000000000d1') ->> 'to' is not null, 'yeniden gönderim');
select public.clinic_invite_email_done(tst.v('c1'), true);
select public.clinic_invite_email_done(tst.v('c1'), false);
select tst.check((select email_status = 'sent' and email_count = 1 from public.clinic_invites where code = tst.v('c1')), 'gönderildi; sonuç bir kez yazılır');
update public.clinic_invites set email_count = 3, email_sent_at = now() - interval '2 minutes' where code = tst.v('c1');
select tst.check(tst.take(tst.v('c1'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'limit_invite', 'davet başına en çok 3 e-posta');
reset role;

-- ekip sahibi üyenin davetini gönderebilir
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d2');
insert into tst.kv select 'c3', public.clinic_create_invite('family', '', '', 'uye@ornek.com') ->> 'code';
reset role;
set role service_role;
select tst.check(tst.take(tst.v('c3'), '00000000-0000-0000-0000-0000000000d1') ->> 'to' = 'uye@ornek.com', 'sahip ekip üyesinin davetini gönderebilir');
reset role;

-- günlük sınır: 30 davete e-posta
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at, parent_email, email_sent_at, email_count, email_status)
  select 'LIM' || lpad(g::text, 3, '0'), clinic_id, id, 'family', '', now() + interval '1 day', 'x@ornek.com', now() - interval '1 hour', 1, 'sent'
    from public.clinicians, generate_series(1, 30) g where id = '00000000-0000-0000-0000-0000000000d1';
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv select 'c4', public.clinic_create_invite('family', '', '', 'yeni@ornek.com') ->> 'code';
reset role;
set role service_role;
select tst.check(tst.take(tst.v('c4'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'limit_day', 'uzman başına günde 30 davet');
reset role;
delete from public.clinic_invites where code like 'LIM%';

-- kapanmış, süresi dolmuş davet ve üyeliği bitmiş klinik
set role service_role;
update public.clinic_invites set claimed_at = now() where code = tst.v('c4');
select tst.check(tst.take(tst.v('c4'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'closed', 'aile bağladıktan sonra e-posta gitmez');
update public.clinic_invites set claimed_at = null, revoked_at = now() where code = tst.v('c4');
select tst.check(tst.take(tst.v('c4'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'closed', 'iptal edilen davete e-posta gitmez');
update public.clinic_invites set revoked_at = null, expires_at = now() - interval '1 minute' where code = tst.v('c4');
select tst.check(tst.take(tst.v('c4'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'expired', 'süresi dolan davete e-posta gitmez');
update public.clinic_invites set expires_at = now() + interval '1 day' where code = tst.v('c4');
update public.clinics set trial_ends_at = now() - interval '1 day' where id = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.take(tst.v('c4'), '00000000-0000-0000-0000-0000000000d1') ->> 'error' = 'no_access', 'üyeliği biten klinik gönderemez');
update public.clinics set trial_ends_at = now() + interval '7 days' where id = (select clinic_id from public.clinicians where id = '00000000-0000-0000-0000-0000000000d1');
reset role;

-- ---------------------------------------------------------------- 4. liste
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select email_status = 'sent' and email_count = 3 and email_sent_at is not null from public.clinic_invites_list(30) where code = tst.v('c1')), 'listede e-posta durumu');
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
select tst.check((select count(*) from public.clinic_invites_list(30) where code = tst.v('c1')) = 0, 'başka klinik listede görmez');
reset role;
