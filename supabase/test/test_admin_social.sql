-- Pazarlama paylaşımı yetkisi (proposed/20261028300000_admin_social.sql)
\set ON_ERROR_STOP on
create schema if not exists tst;
create or replace function tst.as_user(u uuid, aal text default 'aal1') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false);
  perform set_config('request.jwt.claims', json_build_object('aal', aal)::text, false);
end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;
create or replace function tst.fails(sql text, msg text) returns void language plpgsql as $$
begin
  begin execute sql; exception when others then raise notice 'ok (beklenen hata): % → %', msg, sqlerrm; return; end;
  raise exception 'TEST BAŞARISIZ (hata bekleniyordu): %', msg;
end $$;
create or replace function tst.audits() returns bigint language sql security definer as $$
  select count(*) from public.admin_audit where action like 'social.%' $$;
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, email) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com'),
  ('00000000-0000-0000-0000-0000000000f2', false, 'viewer@example.com'),
  ('00000000-0000-0000-0000-0000000000f3', false, 'support@example.com'),
  ('00000000-0000-0000-0000-0000000000a1', false, 'anne@example.com');
insert into public.admin_users (user_id, role) values
  ('00000000-0000-0000-0000-0000000000f1', 'owner'),
  ('00000000-0000-0000-0000-0000000000f2', 'viewer'),
  ('00000000-0000-0000-0000-0000000000f3', 'support');

set role authenticated;

-- Admin olmayan ve iki adımsız giriş
select tst.as_user('00000000-0000-0000-0000-0000000000a1', 'aal2');
select tst.fails($$ select public.admin_social_check('view') $$, 'admin olmayan okuyamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal1');
select tst.fails($$ select public.admin_social_check('view') $$, 'iki adımlı doğrulama olmadan okunmaz');

-- Okuma: her admin
select tst.as_user('00000000-0000-0000-0000-0000000000f2', 'aal2');
select tst.check(public.admin_social_check('view') = 'viewer', 'viewer okur, rolü döner');
select tst.fails($$ select public.admin_social_check('approve', 'abc123', 'içerik uygun', null, true) $$, 'viewer onaylayamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000f3', 'aal2');
select tst.fails($$ select public.admin_social_check('delete', 'abc123', 'yanlış video', null, false) $$, 'support silemez');

-- Owner: önce kuru denetim (kayıt yok), sonra kayıt
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
select tst.check(public.admin_social_check('view') = 'owner', 'owner okur');
select tst.check(public.admin_social_check('approve', '65f0c0ffee0123456789abcd', 'içerik kurallara uygun') = 'owner', 'kuru denetim geçer');
select tst.check(tst.audits() = 0, 'kuru denetim kayıt yazmaz');
select tst.fails($$ select public.admin_social_check('approve', '65f0c0ffee0123456789abcd', 'ok') $$, 'kısa gerekçe reddedilir');
select tst.fails($$ select public.admin_social_check('approve', 'a b;drop', 'içerik uygun') $$, 'geçersiz kimlik reddedilir');
select tst.fails($$ select public.admin_social_check('approve', null, 'içerik uygun') $$, 'kimliksiz değişiklik reddedilir');
select tst.fails($$ select public.admin_social_check('publish_now', 'abc', 'hemen at') $$, 'bilinmeyen işlem reddedilir');
select public.admin_social_check('approve', '65f0c0ffee0123456789abcd', 'içerik kurallara uygun',
                                 '{"scheduled_for":"2026-11-01T17:00:00Z","platforms":["instagram","tiktok"]}', false);
select public.admin_social_check('request_changes', '65f0c0ffee0123456789abce', 'kaynak eksik, sağlık iddiası var', null, false);
select tst.check(tst.audits() = 2, 'onay ve düzeltme isteği denetim kaydında');
reset role;
select tst.check((select after ->> 'scheduled_for' from public.admin_audit where action = 'social.approve') = '2026-11-01T17:00:00Z',
                 'onay kaydı planlanan saati taşır');
select tst.check((select target_type || ' ' || target_id from public.admin_audit where action = 'social.request_changes')
                 = 'system social:65f0c0ffee0123456789abce', 'hedef: system / social:<gönderi>');
