-- Yönetim paneli davet hunisi (proposed/20261026200000_admin_invite_funnel.sql)
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
grant usage on schema tst to authenticated;
grant execute on all functions in schema tst to authenticated;

insert into auth.users (id, is_anonymous, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', false, 'owner@example.com', '{"nickname":"Owner"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, 'uzman@example.com', '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}');
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000f1', 'viewer');

-- d1'in 6 aile daveti: gönderildi, açıldı, kayıt, paylaşıldı, süresi doldu, reddedildi; 1 eski (dönem dışı); 1 ekip daveti (sayılmaz)
insert into public.clinic_invites (code, clinic_id, clinician_id, kind, created_at, expires_at, opened_at, claimed_at, used_at, declined_at, revoked_at, channel)
select v.code, m.clinic_id, m.id, v.kind, now() - v.age, now() + v.left_, v.op, v.cl, v.us, v.de, v.re, v.ch
  from public.clinicians m,
  (values ('F00001', 'family', interval '1 day',  interval '1 day',  null::timestamptz, null::timestamptz, null::timestamptz, null::timestamptz, null::timestamptz, 'whatsapp'),
          ('F00002', 'family', interval '1 day',  interval '1 day',  now(), null, null, null, null, 'whatsapp'),
          ('F00003', 'family', interval '1 day',  interval '1 day',  now(), now(), null, null, null, 'email'),
          ('F00004', 'family', interval '1 day',  interval '1 day',  now(), now(), now(), null, null, 'whatsapp'),
          ('F00005', 'family', interval '3 days', interval '-1 day', null, null, null, null, null, 'sms'),
          ('F00006', 'family', interval '1 day',  interval '1 day',  now(), now(), null, now(), now(), null),
          ('F00007', 'family', interval '90 days', interval '-80 days', now(), now(), now(), null, null, 'copy'),
          ('T00001', 'clinician', interval '1 day', interval '1 day', null, null, null, null, null, null)
  ) as v(code, kind, age, left_, op, cl, us, de, re, ch)
 where m.id = '00000000-0000-0000-0000-0000000000d1';

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1', 'aal2');
select tst.fails($$select public.admin_kpi_invites(30)$$, 'admin olmayan göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal1');
select tst.fails($$select public.admin_kpi_invites(30)$$, 'iki adımlı doğrulama olmadan göremez');
select tst.as_user('00000000-0000-0000-0000-0000000000f1', 'aal2');
select tst.check((public.admin_kpi_invites(30) -> 'totals' ->> 'sent')::int = 6, 'dönemdeki aile davetleri (eski ve ekip daveti sayılmaz)');
select tst.check((public.admin_kpi_invites(30) -> 'totals' ->> 'opened')::int = 4, 'açılan (sonraki adıma geçenler dahil)');
select tst.check((public.admin_kpi_invites(30) -> 'totals' ->> 'claimed')::int = 2, 'kayıt/kod (reddeden hariç)');
select tst.check((public.admin_kpi_invites(30) -> 'totals' ->> 'shared')::int = 1, 'paylaşılan');
select tst.check((public.admin_kpi_invites(30) -> 'totals' ->> 'expired')::int = 1, 'süresi dolan');
select tst.check((public.admin_kpi_invites(30) -> 'totals' ->> 'declined')::int = 1, 'reddeden');
select tst.check((public.admin_kpi_invites(30) -> 'totals' ->> 'revoked')::int = 0, 'uzman iptali (red iptal sayılmaz)');
select tst.check((select (x ->> 'sent')::int from json_array_elements(public.admin_kpi_invites(30) -> 'by_channel') x
                   where x ->> 'channel' = 'whatsapp') = 3, 'paylaşım yoluna göre');
select tst.check((select (x ->> 'shared')::int from json_array_elements(public.admin_kpi_invites(30) -> 'by_clinician') x
                   where x ->> 'clinician' = 'Dr. Ece') = 1, 'uzmana göre');
select tst.check((public.admin_kpi_invites(120) -> 'totals' ->> 'sent')::int = 7, 'dönem uzayınca eski davet de sayılır');
reset role;
select 'DAVET HUNİSİ TESTLERİ GEÇTİ' as sonuc;
