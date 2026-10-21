-- Bildirim sistemi (20261019130000_notifications.sql): olaylar, alıcılar, RLS, push (net.http_post taklidi).
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

-- pg_net taklidi: push çağrılarını kaydeder
create schema if not exists net;
create table tst.push_calls (url text, body jsonb);
grant select on tst.push_calls to authenticated;
create or replace function net.http_post(url text, body jsonb, headers jsonb) returns bigint language plpgsql security definer as $$
begin insert into tst.push_calls values (url, body); return 1; end $$;

create or replace function tst.n(u text, k text) returns integer language sql security definer as $$
  select count(*)::integer from public.notifications where user_id = u::uuid and kind = k $$;
grant execute on function tst.n(text, text) to authenticated;

-- a1, a2 ebeveyn (aynı aile, a2 sonradan katılır), c1 çocuk cihazı, d1 uzman (sahip), d2 ekip üyesi
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}');
insert into tst.kv select 'fid', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c001', (select v::uuid from tst.kv where k = 'fid'), 'Nazlı', 'kedi'),
         ('00000000-0000-0000-0000-00000000c002', (select v::uuid from tst.kv where k = 'fid'), 'Efe', 'kedi');

set role authenticated;

-- ikinci ebeveyn katılır → Anne'ye
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'pcode', code from public.create_invite_code('parent', null);
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family((select v from tst.kv where k = 'pcode'));
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'parent_joined') = 1, 'ebeveyn katılınca diğer ebeveyne bildirim');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a2', 'parent_joined') = 0, 'katılan kendine bildirim almaz');

-- push anahtarı (Anne)
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.register_push_token('ExponentPushToken[anne-telefon]', 'parent', 'ios');
select public.register_push_token('a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4', 'parent', 'ios');
select tst.check((select count(*) from public.push_tokens) = 2, 'kendi push anahtarlarını görür');
select tst.fails($$insert into public.push_tokens (token, user_id, app) values ('ExponentPushToken[x]', auth.uid(), 'parent')$$, 'tabloya doğrudan yazılamaz');

-- çocuk cihazı bağlanır → iki ebeveyne
insert into tst.kv select 'ccode', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select v from tst.kv where k = 'ccode'));
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'device_linked') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'device_linked') = 1, 'cihaz bağlanınca iki ebeveyne');
select tst.check(exists (select 1 from tst.push_calls where body -> 0 ->> 'to' = 'ExponentPushToken[anne-telefon]' and body -> 0 ->> 'title' like 'Nazlı oyuna%'), 'Anne''ye push gönderildi (Expo)');
select tst.check(exists (select 1 from tst.push_calls where url like '%/functions/v1/push-apns' and (body ->> 'notification_id') is not null), 'Apple anahtarı için push-apns çağrıldı');

-- görev atanır → çocuğa; düzenleme (upsert) yeni bildirim üretmez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.tasks (id, family_id, title, emoji, start_date, recurring, repeat_kind, requires_review)
  values ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Odanı topla', '🧹', current_date - 1, true, 'daily', true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  values ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'medium', 10);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  values ('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'hard', 20)
  on conflict (task_id, child_id) do update set coins = excluded.coins, difficulty = excluded.difficulty;
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'task_assigned') = 1, 'yeni görev çocuğa bir kez bildirilir');

-- çocuk "Yaptım" → ebeveynlere; "Yapamam" → ebeveynlere
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date, 'pending');
select public.child_set_status('00000000-0000-0000-0000-000000007a51', current_date - 1, 'declined');
select tst.check((select count(*) from public.notifications) = 1, 'çocuk yalnız kendi bildirimini görür (RLS)');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'task_done') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'task_done') = 1, 'Yaptım → iki ebeveyne');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'task_declined') = 1, 'Yapamam → ebeveyne');
select tst.check((select title from public.notifications where kind = 'task_done') = 'Nazlı görevi yaptı: Odanı topla', 'başlık çocuğun adı + görev');
select tst.check((select count(*) from public.notifications) = (select count(*) from public.notifications where user_id = auth.uid()), 'ebeveyn yalnız kendi bildirimlerini görür');

-- ebeveyn onayı/reddi → çocuğa; onaylayan ebeveyn kendine almaz
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date, 'approved');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date - 1, 'rejected', 'Yarın birlikte yapalım');
select public.review_completion('00000000-0000-0000-0000-000000007a51', '00000000-0000-0000-0000-00000000c001', current_date - 1, 'rejected', 'Yarın birlikte yapalım');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'task_approved') = 1, 'onay çocuğa');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'task_rejected') = 1, 'ret çocuğa (aynı durum tekrarı yeni bildirim üretmez)');
select tst.check((select body from public.notifications where kind = 'task_approved') is null, 'ebeveyn çocuğun bildirimini göremez');

-- posta: iki yön
insert into public.messages (family_id, child_id, sender, sender_id, kind, body)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'parent', auth.uid(), 'text', 'Seni seviyorum');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000c1', 'message') = 1, 'ebeveyn mesajı çocuğa');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'message') = 0, 'gönderen kendine almaz');
reset role;
select tst.as_user(null);
insert into public.messages (family_id, child_id, sender, kind, media_path)
  values ((select v::uuid from tst.kv where k = 'fid'), '00000000-0000-0000-0000-00000000c001', 'child', 'image', 'x/y.jpg');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'message') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'message') = 1, 'çocuk mesajı iki ebeveyne');
select tst.check((select body from public.notifications where kind = 'message' and user_id = '00000000-0000-0000-0000-0000000000a1') = '📷 Fotoğraf', 'fotoğraf önizlemesi');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');

-- uzman: ekip üyesi katılır → sahibe
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('team', public.clinic_create_invite('clinician', '') ->> 'code');
insert into tst.kv values ('fam', public.clinic_create_invite('family', '') ->> 'code');
insert into tst.kv values ('clinic', public.clinician_me() ->> 'clinic_id');
reset role;
select tst.as_user(null);
insert into auth.users (id, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d2', jsonb_build_object('account', 'clinician', 'team_code', (select v from tst.kv where k = 'team'), 'name', 'Ayşe'));
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'team_joined') = 1, 'ekibe katılım sahibe bildirilir');
set role authenticated;

-- aile iki çocuğu paylaşır → sorumlu uzmana TEK bildirim, iki çocuk adıyla; ekip üyesine gitmez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.redeem_clinic_invite_children((select v from tst.kv where k = 'fam'),
  array['00000000-0000-0000-0000-00000000c001'::uuid, '00000000-0000-0000-0000-00000000c002'::uuid]);
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'clinic_shared') = 1, 'paylaşım uzmana tek bildirim');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d2', 'clinic_shared') = 0, 'sorumlu olmayan ekip üyesine gitmez');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select body from public.notifications where kind = 'clinic_shared') like '%Efe, Nazlı%', 'bildirimde iki çocuğun adı');
select tst.check((select title from public.notifications where kind = 'clinic_shared') = '2 çocuk paylaşıldı', 'başlık çocuk sayısı');

-- uzman görev önerir → ebeveynlere; aile karar verir → uzmana
insert into public.clinic_task_suggestions (id, link_id, clinic_id, family_id, child_id, title, created_by)
  select '00000000-0000-0000-0000-00000000500a', l.id, l.clinic_id, l.family_id, l.child_id, 'Nefes egzersizi', auth.uid()
  from public.clinic_links l where l.child_id = '00000000-0000-0000-0000-00000000c001';
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'clinic_suggestion') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'clinic_suggestion') = 1, 'öneri iki ebeveyne');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
update public.clinic_task_suggestions set status = 'accepted', decided_at = now();
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'suggestion_decided') = 1, 'karar öneriyi yapan uzmana');

-- zor an kaydı → bağlı uzmana; posta/coin uzmana gitmez
insert into public.abc_events (family_id, child_id, behavior, intensity, created_by)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000c002', 'Ağladı', 4, auth.uid());
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'abc_event') = 1, 'zor an uzmana');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'message') = 0, 'posta uzmana bildirilmez');

-- aile bir çocuğun paylaşımını durdurur → uzmana; uzman durdurursa → ebeveynlere
select public.revoke_clinic_link((select link_id from public.family_clinic_links() where child_id = '00000000-0000-0000-0000-00000000c002'));
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'clinic_revoked') = 1, 'aile durdurunca uzmana');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select public.revoke_clinic_link((select id from public.clinic_links where child_id = '00000000-0000-0000-0000-00000000c001' and status = 'active'));
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'clinic_revoked') = 1, 'uzman durdurunca ebeveyne');
-- paylaşım bitince zor an uzmana gitmez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.abc_events (family_id, child_id, behavior, created_by) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c002', 'Kızdı', auth.uid());
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'abc_event') = 1, 'rıza bitince uzmana bildirim yok');

-- okundu / silme / yazma yasağı
select tst.check(public.mark_notifications_read() >= 1, 'hepsini okundu yap');
select tst.check((select count(*) from public.notifications where read_at is null) = 0, 'okunmamış kalmadı');
select tst.fails($$insert into public.notifications (user_id, app, kind, title) values (auth.uid(), 'parent', 'x', 'hile')$$, 'kullanıcı bildirim yazamaz');
select tst.fails($$update public.notifications set title = 'değişti'$$, 'başlık değiştirilemez (yalnız read_at)');
delete from public.notifications where kind = 'parent_joined';
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'parent_joined') = 0, 'kendi bildirimini siler');
select public.unregister_push_token('ExponentPushToken[anne-telefon]');
select public.unregister_push_token('a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4');
select tst.check((select count(*) from public.push_tokens) = 0, 'push anahtarı kaldırılır');

reset role;
select 'TÜM BİLDİRİM TESTLERİ GEÇTİ' as sonuc;
