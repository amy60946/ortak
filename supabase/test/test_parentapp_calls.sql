\set ON_ERROR_STOP on
-- ParentApp istemcisinin çağrıları birebir (parent-app/src/lib/clinic.ts): davet, aynı ad, ret, geçmiş, takip planı, kayıt meta'sı
create or replace function tst.as_user(u uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claim.sub', coalesce(u::text, ''), false); end $$;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if; raise notice 'ok: %', msg; end $$;
create table if not exists tst.kv (k text primary key, v text);
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant usage on schema tst to anon, authenticated, service_role;
grant all on tst.kv to authenticated, service_role;
grant execute on all functions in schema tst to anon, authenticated, service_role;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000d3', false, '{"account":"clinician","clinic_name":"Eski","name":"Dr. Eski"}'),
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}');
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c001', (select family_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Nazlı', 'kedi');

-- önceki uzman (d3) Nazlı ile paylaşılmış, sonra durdurulmuş
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d3');
insert into tst.kv values ('old', public.clinic_create_invite('family', '', '', '', '', null) ->> 'code');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('oldr', public.redeem_clinic_invite_children(tst.v('old'), array['00000000-0000-0000-0000-00000000c001'::uuid])::text);
select public.revoke_clinic_link(((tst.v('oldr')::json -> 'link_ids') ->> 0)::uuid);

-- yeni uzman (d1) Efe önerisiyle davet
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('i', public.clinic_create_invite('family', 'not', '', '', 'Nazlı', 'A')::text);
insert into tst.kv values ('tok', (tst.v('i')::json) ->> 'token'), ('code', (tst.v('i')::json) ->> 'code');

-- ParentApp: claimInvite(token)
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('claim', public.claim_clinic_invite(tst.v('tok'))::text);
select tst.check((tst.v('claim')::json ->> 'code') = tst.v('code'), 'claim: code döner');
select tst.check((tst.v('claim')::json ->> 'child_name') = 'Nazlı' and (tst.v('claim')::json ->> 'child_age_group') = 'A', 'claim: çocuk önerisi döner');
select tst.check((tst.v('claim')::json ->> 'clinician') = 'Dr. Ece', 'claim: uzman adı');
select tst.check(not (tst.v('claim')::jsonb ? 'label'), 'claim: label yok');
select tst.check((tst.v('claim')::json ->> 'verified_as') is null, 'claim: bayrak kapalı → verified_as null');
-- pendingInvites
select tst.check((select count(*) from public.family_pending_invites()) = 1, 'bekleyen davet 1');
select tst.check((select child_name from public.family_pending_invites()) = 'Nazlı', 'bekleyen davette çocuk adı');
-- acceptInvite: aynı ad → duplicate_child (200)
insert into tst.kv values ('dup', public.family_accept_invite(tst.v('code'), '{"name":"Nazlı","age_group":"A","avatar":"kedi"}'::jsonb, null, false, 'uzman-paylasim-v1', null)::text);
select tst.check((tst.v('dup')::json ->> 'error') = 'duplicate_child', 'aynı ad: duplicate_child');
select tst.check((tst.v('dup')::json ->> 'child_id') = '00000000-0000-0000-0000-00000000c001', 'aynı ad: mevcut çocuk kimliği');
-- "Bu o çocuk": p_child null, p_child_ids [Nazlı], geçmiş açık
insert into tst.kv values ('acc', public.family_accept_invite(tst.v('code'), null, array['00000000-0000-0000-0000-00000000c001'::uuid], true, 'uzman-paylasim-v1', 'uzman-gecis-v1')::text);
select tst.check(json_array_length(tst.v('acc')::json -> 'link_ids') = 1, 'kabul: 1 paylaşım');
insert into tst.kv values ('link', (tst.v('acc')::json -> 'link_ids') ->> 0);
select tst.check((select consent_version from public.clinic_links where id = tst.v('link')::uuid) = 'uzman-paylasim-v1', 'onay sürümü kaydedildi');
-- family_clinic_links alanları
select tst.check((select history_shared and history_available from public.family_clinic_links() where link_id = tst.v('link')::uuid), 'geçmiş açık ve mevcut');
select public.clinic_link_history_set(tst.v('link')::uuid, false, null);
select tst.check((select not history_shared from public.family_clinic_links() where link_id = tst.v('link')::uuid), 'geçmiş kapandı');
select public.clinic_link_history_set(tst.v('link')::uuid, true, 'uzman-gecis-v1');
select tst.check((select history_shared from public.family_clinic_links() where link_id = tst.v('link')::uuid), 'geçmiş yeniden açıldı');
select tst.check((select count(*) from public.family_pending_invites()) = 0, 'kabul sonrası bekleyen yok');

-- takip planı: uzman modül + paylaşılan hedef
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into public.care_modules (clinic_id, link_id, title, checklist, status)
  values ((select clinic_id from public.clinic_links where id = tst.v('link')::uuid), tst.v('link')::uuid, 'Rutin', '["a","b"]', 'active');
insert into public.clinic_goals (clinic_id, link_id, title, shared) values ((select clinic_id from public.clinic_links where id = tst.v('link')::uuid), tst.v('link')::uuid, 'Hedef', true);
-- kabulde plan anlık görüntüsü alınmış olabilir: 10 dakikalık bildirim aralığını sıfırla (review_fixes)
reset role;
update public.clinic_links set plan_published_at = null where id = tst.v('link')::uuid;
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.care_plan_publish(tst.v('link')::uuid);
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv values ('plan', public.family_care_plan(tst.v('link')::uuid)::text);
select tst.check(json_array_length(tst.v('plan')::json -> 'modules') = 1 and json_array_length(tst.v('plan')::json -> 'goals') = 1, 'plan: modül + hedef');
select tst.check(((tst.v('plan')::json -> 'modules') -> 0 -> 'checklist') ->> 0 = 'a', 'plan: kontrol listesi metin dizisi');
insert into tst.kv values ('mod', (tst.v('plan')::json -> 'modules') -> 0 ->> 'id');
-- saveLog: PostgREST upsert (aile kimliği gönderilmez)
insert into public.care_module_logs (module_id, created_by, day, practiced, difficulty, barrier)
  values (tst.v('mod')::uuid, '00000000-0000-0000-0000-0000000000a1', current_date, true, null, null)
  on conflict (module_id, created_by, day) do update set practiced = excluded.practiced, difficulty = excluded.difficulty, barrier = excluded.barrier;
insert into public.care_module_logs (module_id, created_by, day, practiced, difficulty, barrier)
  values (tst.v('mod')::uuid, '00000000-0000-0000-0000-0000000000a1', current_date, true, 4, null)
  on conflict (module_id, created_by, day) do update set practiced = excluded.practiced, difficulty = excluded.difficulty, barrier = excluded.barrier;
select tst.check((select count(*) from public.care_module_logs where module_id = tst.v('mod')::uuid) = 1, 'günde tek kayıt');
select tst.check((select difficulty from public.care_module_logs where module_id = tst.v('mod')::uuid) = 4, 'zorluk güncellendi');
insert into public.care_module_logs (module_id, created_by, day, practiced, difficulty, barrier)
  values (tst.v('mod')::uuid, '00000000-0000-0000-0000-0000000000a1', current_date, false, null, 'forgot')
  on conflict (module_id, created_by, day) do update set practiced = excluded.practiced, difficulty = excluded.difficulty, barrier = excluded.barrier;
select tst.check((select barrier from public.care_module_logs where module_id = tst.v('mod')::uuid) = 'forgot', 'uygulayamadım + neden');
select tst.check((select ((public.family_care_plan(tst.v('link')::uuid) -> 'modules') -> 0 ->> 'practiced_week')::int) = 0, 'uygulamadı → hafta 0');
-- bildirim: care_plan_shared ve link verisi
select tst.check(exists (select 1 from public.notifications where kind = 'care_plan_shared' and user_id = '00000000-0000-0000-0000-0000000000a1'
  and (data ? 'link_id' or data ? 'link_ids')), 'care_plan_shared bildirimi link verisiyle');

-- yeni çocuk önerisiyle ikinci davet + ret
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('i2', public.clinic_create_invite('family', '', '', '', 'Efe', 'B')::text);
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.claim_clinic_invite((tst.v('i2')::json) ->> 'code');
insert into tst.kv values ('acc2', public.family_accept_invite((tst.v('i2')::json) ->> 'code', '{"name":"Efecan","age_group":"C","gender":"erkek","avatar":"kurt"}'::jsonb, null, false, 'uzman-paylasim-v1', null)::text);
select tst.check((select age_band from public.children where name = 'Efecan') = 'C', 'yaş grubu aynen yazılır (review_fixes: C kalır)');
reset role;
select tst.check(exists (select 1 from public.notifications where kind = 'invite_child_updated' and user_id = '00000000-0000-0000-0000-0000000000d1'), 'düzeltme uzmana bildirildi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('i3', public.clinic_create_invite('family', '', '', '', '', null)::text);
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.claim_clinic_invite((tst.v('i3')::json) ->> 'code');
select public.family_decline_invite((tst.v('i3')::json) ->> 'code');
select tst.check((select count(*) from public.family_pending_invites()) = 0, 'ret sonrası bekleyen yok');
-- kullanılmış davet → reason used
insert into tst.kv values ('used', public.claim_clinic_invite(tst.v('code'))::text);
-- review_fixes (ortak#51): aynı ailenin kullandığı davet reason 'accepted' döner (ParentApp: "Bu daveti zaten kabul ettin")
select tst.check((tst.v('used')::json ->> 'reason') = 'accepted', 'kendi kullandığın davet: accepted');
select tst.check(not exists (select 1 from public.family_pending_invites() where code = tst.v('code')), 'kullanılmış davet bekleyenlerde yok');
reset role;

-- kayıt meta'sında clinic_invite (bağlantı anahtarı) → davet aileye bağlanır
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('i4', public.clinic_create_invite('family', '', '', '', 'Deniz', 'K')::text);
reset role;
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a2', false, jsonb_build_object('name', 'Baba', 'clinic_invite', (tst.v('i4')::json) ->> 'token'));
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check((select count(*) from public.family_pending_invites()) = 1, 'kayıtta bağlantı anahtarı → bekleyen davet');
select tst.check((select (public.claim_clinic_invite((tst.v('i4')::json) ->> 'token') ->> 'code')) = (tst.v('i4')::json) ->> 'code', 'aynı aile yeniden claim edebilir');
reset role;
