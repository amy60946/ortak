-- Ebeveyn bildirim tercihleri ve "günün adımları tamamlandı" (proposed/20261120210000_parent_notification_prefs.sql; bildirim sınırı 5a).
-- Varsayılanlar, aç/kapat, başkası okuyamaz, anon çağıramaz; step_done kapalıyken satır var ama push yok; day_complete günde bir kez.
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

-- pg_net taklidi: push çağrılarını kaydeder
create schema if not exists net;
create table tst.push_calls (url text, body jsonb);
create or replace function net.http_post(url text, body jsonb, headers jsonb) returns bigint language plpgsql security definer as $$
begin insert into tst.push_calls values (url, body); return 1; end $$;

-- yardımcılar (satır güvenliğini aşar: yalnız test)
create or replace function tst.n(u text, k text, c text default null) returns integer language sql security definer as $$
  select count(*)::integer from public.notifications
   where user_id = u::uuid and kind = k and (c is null or child_id = c::uuid) $$;
create or replace function tst.last(u text, k text, c text default null) returns public.notifications language sql security definer as $$
  select * from public.notifications
   where user_id = u::uuid and kind = k and (c is null or child_id = c::uuid) order by id desc limit 1 $$;
create or replace function tst.pushed(nid bigint) returns boolean language sql security definer as $$
  select exists (select 1 from tst.push_calls where url like '%/functions/v1/push-apns' and (body ->> 'notification_id')::bigint = nid)
      or exists (select 1 from tst.push_calls p,
                        jsonb_array_elements(case when jsonb_typeof(p.body) = 'array' then p.body else '[]' end) e
                  where p.url like 'https://exp.host/%' and (e -> 'data' ->> 'notification_id')::bigint = nid) $$;
create or replace function tst.day() returns date language sql security definer as $$ select v::date from tst.kv where k = 'd' $$;
create or replace function tst.marked(c text) returns date language sql security definer as $$
  select day_complete_on from public.children where id = c::uuid $$;
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated;
grant execute on all functions in schema tst to authenticated, anon;

-- a1 Anne, a2 Baba (aynı aile), e1 başka aile, d1 uzman; c1, c2, c3 çocuk cihazları (Nazlı, Efe, Can)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Baba"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}'),
  ('00000000-0000-0000-0000-0000000000c1', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c3', true, '{}');
insert into tst.kv select 'fid', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into tst.kv values ('d', public.tr_today()::text);   -- Türkiye günü (bildirim yalnız bugünün adımında)
insert into public.family_subscriptions (family_id, plan) values ((select v::uuid from tst.kv where k = 'fid'), 'premium');

set role authenticated;

-- ---------------------------------------------------------------- kurulum
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'pcode', code from public.create_invite_code('parent', null);
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select public.join_family((select v from tst.kv where k = 'pcode'));
-- push anahtarları: Anne Apple + Expo, Baba Apple
select public.register_push_token('a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2', 'parent', 'ios');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.register_push_token('a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1', 'parent', 'ios');
select public.register_push_token('ExponentPushToken[anne-telefon]', 'parent', 'ios');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values
  ('00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'Nazlı', 'kedi'),
  ('00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'Efe', 'kedi'),
  ('00000000-0000-0000-0000-00000000c003', public.my_family_id(), 'Can', 'kedi');
-- Nazlı: iki günlük adım (biri incelemeli, biri incelemesiz) + bugün olmayan haftalık adım; Efe ve Can: kendi adımları
insert into public.tasks (id, family_id, title, start_date, recurring, repeat_kind, repeat_days, requires_review) values
  ('00000000-0000-0000-0000-000000007a01', public.my_family_id(), 'Dişlerini fırçala', tst.day() - 3, true, 'daily', '{}', true),
  ('00000000-0000-0000-0000-000000007a02', public.my_family_id(), 'Çantanı hazırla', tst.day() - 3, true, 'daily', '{}', false),
  ('00000000-0000-0000-0000-000000007a03', public.my_family_id(), 'Bitkiyi sula', tst.day() - 3, true, 'weekly',
     array[extract(isodow from tst.day() + 1)::smallint], true),
  ('00000000-0000-0000-0000-000000007a04', public.my_family_id(), 'Odanı topla', tst.day() - 3, true, 'daily', '{}', true),
  ('00000000-0000-0000-0000-000000007a05', public.my_family_id(), 'Kitap oku', tst.day() - 3, true, 'daily', '{}', true),
  ('00000000-0000-0000-0000-000000007a06', public.my_family_id(), 'Masayı kur', tst.day() - 3, true, 'daily', '{}', true);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007a01', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a02', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a03', '00000000-0000-0000-0000-00000000c001', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a04', '00000000-0000-0000-0000-00000000c002', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a05', '00000000-0000-0000-0000-00000000c003', public.my_family_id(), 'easy', 5),
  ('00000000-0000-0000-0000-000000007a06', '00000000-0000-0000-0000-00000000c003', public.my_family_id(), 'easy', 5);
insert into tst.kv select 'k1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c001');
insert into tst.kv select 'k2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c002');
insert into tst.kv select 'k3', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000c003');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.redeem_child_code((select v from tst.kv where k = 'k1'));
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.redeem_child_code((select v from tst.kv where k = 'k2'));
select tst.as_user('00000000-0000-0000-0000-0000000000c3');
select public.redeem_child_code((select v from tst.kv where k = 'k3'));

select tst.check(tst.pushed((tst.last('00000000-0000-0000-0000-0000000000a1', 'device_linked')).id), 'öteki türler (cihaz bağlandı) push ile gider');

-- ---------------------------------------------------------------- varsayılanlar, aç / kapat, yetki
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.parent_notification_prefs()::jsonb = '{"step_done": false, "day_complete": true, "tips": true}', 'varsayılan: adım bildirimi kapalı, gün bildirimi açık');
select tst.check((select count(*) from public.parent_notification_prefs) = 0, 'okumak satır açmaz');

select tst.as_user('00000000-0000-0000-0000-0000000000a2');
select tst.check(public.parent_notification_prefs_set('step_done', true)::jsonb = '{"step_done": true, "day_complete": true, "tips": true}', 'Baba adım bildirimini açar (öteki anahtar varsayılanda kalır)');
select tst.check(public.parent_notification_prefs()::jsonb ->> 'step_done' = 'true', 'açık kalır');
select tst.check((select count(*) from public.parent_notification_prefs where user_id = auth.uid()) = 1, 'kendi satırını görür');
select tst.fails($$select public.parent_notification_prefs_set('weekly_goal', false)$$, 'bilinmeyen anahtar reddedilir');
select tst.fails($$select public.parent_notification_prefs_set('step_done', null)$$, 'boş değer reddedilir');
select tst.fails($$insert into public.parent_notification_prefs (user_id, step_done) values (auth.uid(), true)$$, 'tabloya doğrudan yazılamaz');
select tst.fails($$update public.parent_notification_prefs set step_done = false$$, 'tablo doğrudan güncellenemez');

select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.parent_notification_prefs()::jsonb ->> 'step_done' = 'false', 'Baba''nın ayarı Anne''yi etkilemez (ebeveyn başına)');
select tst.check((select count(*) from public.parent_notification_prefs) = 0, 'aynı ailedeki öteki ebeveynin tercihi okunamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.parent_notification_prefs) = 0, 'başka aile tercih okuyamaz');
select tst.check(public.parent_notification_prefs()::jsonb ->> 'step_done' = 'false', 'başka aile yalnız kendi (varsayılan) tercihini alır');
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.fails($$select public.parent_notification_prefs()$$, 'uzman hesabı ebeveyn tercihi okuyamaz');
select tst.fails($$select public.parent_notification_prefs_set('step_done', true)$$, 'uzman hesabı ebeveyn tercihi yazamaz');
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select tst.fails($$select public.parent_notification_prefs_set('day_complete', false)$$, 'çocuk cihazı tercih yazamaz');

reset role;
select tst.check(not has_function_privilege('anon', 'public.parent_notification_prefs()', 'execute')
             and not has_function_privilege('anon', 'public.parent_notification_prefs_set(text, boolean)', 'execute'), 'anon iki RPC''yi çağıramaz');
select tst.check(not has_function_privilege('authenticated', 'public.parent_notification_prefs_of(uuid)', 'execute')
             and not has_function_privilege('authenticated', 'public.completions_notify_day()', 'execute')
             and not has_function_privilege('authenticated', 'public.notifications_push_pref()', 'execute'), 'iç işlevler istemciye kapalı');
select tst.check((select relrowsecurity from pg_class where oid = 'public.parent_notification_prefs'::regclass), 'tercih tablosunda RLS açık');
set role anon;
select tst.as_user(null);
select tst.fails($$select public.parent_notification_prefs()$$, 'anon okuyamaz');
select tst.fails($$select public.parent_notification_prefs_set('step_done', true)$$, 'anon yazamaz');
select tst.fails($$select count(*) from public.parent_notification_prefs$$, 'anon tabloyu okuyamaz');
reset role;
set role authenticated;

-- ---------------------------------------------------------------- adım bildirimi: satır her zaman, push tercihe göre
select tst.as_user('00000000-0000-0000-0000-0000000000c1');
select public.child_set_status('00000000-0000-0000-0000-000000007a01', tst.day(), 'pending');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'task_done') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'task_done') = 1,
  'adım bildirimi iki ebeveynin listesine yazılır');
select tst.check(not (tst.last('00000000-0000-0000-0000-0000000000a1', 'task_done')).push, 'Anne (varsayılan): push işareti yok');
select tst.check(not tst.pushed((tst.last('00000000-0000-0000-0000-0000000000a1', 'task_done')).id), 'Anne''ye push gitmedi (Apple ve Expo)');
select tst.check((tst.last('00000000-0000-0000-0000-0000000000a2', 'task_done')).push
             and tst.pushed((tst.last('00000000-0000-0000-0000-0000000000a2', 'task_done')).id), 'Baba (açtı): push gitti');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'day_complete') = 0, 'bir adım açıkken gün bildirimi yok');

-- ---------------------------------------------------------------- gün tamam: son işaretle bir kez
select public.child_set_status('00000000-0000-0000-0000-000000007a02', tst.day(), 'pending');   -- incelemesiz: hemen onaylı
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'day_complete') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'day_complete') = 1,
  'son adım işaretlenince iki ebeveyne gün bildirimi (bugün olmayan haftalık adım sayılmaz)');
select tst.check((tst.last('00000000-0000-0000-0000-0000000000a1', 'day_complete')).title = 'Nazlı bugünün adımlarını tamamladı', 'başlık');
select tst.check((tst.last('00000000-0000-0000-0000-0000000000a1', 'day_complete')).body = 'Onayını bekleyen 1 adım var.', 'metin: onay bekleyen sayısı');
select tst.check((tst.last('00000000-0000-0000-0000-0000000000a1', 'day_complete')).data
                 = jsonb_build_object('child_id', '00000000-0000-0000-0000-00000000c001', 'date', tst.day(), 'steps', 2, 'pending', 1), 'veri: çocuk, gün, sayılar');
select tst.check((tst.last('00000000-0000-0000-0000-0000000000a1', 'day_complete')).push
             and tst.pushed((tst.last('00000000-0000-0000-0000-0000000000a1', 'day_complete')).id), 'gün bildirimi varsayılanda push ile gider');
select tst.check(tst.marked('00000000-0000-0000-0000-00000000c001') = tst.day(), 'çocukta gün işaretlendi');
select tst.check((select count(*) from public.notifications where kind = 'day_complete') = 0, 'çocuk cihazı gün bildirimini görmez');

-- geri alıp yeniden işaretlemek, "Yapamam" → "Yaptım", ebeveyn onayı: ikinci gün bildirimi yok
select public.child_set_status('00000000-0000-0000-0000-000000007a01', tst.day(), 'assigned');   -- incelemeli adım geri alınabilir
select public.child_set_status('00000000-0000-0000-0000-000000007a01', tst.day(), 'pending');
select public.child_set_status('00000000-0000-0000-0000-000000007a01', tst.day(), 'declined');
select public.child_set_status('00000000-0000-0000-0000-000000007a01', tst.day(), 'pending');
select tst.check(not (tst.last('00000000-0000-0000-0000-0000000000a1', 'task_declined')).push
             and (tst.last('00000000-0000-0000-0000-0000000000a2', 'task_declined')).push, '"Yapamam" da adım anahtarına bağlı');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.review_completion('00000000-0000-0000-0000-000000007a01', '00000000-0000-0000-0000-00000000c001', tst.day(), 'approved');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'day_complete') = 1 and tst.n('00000000-0000-0000-0000-0000000000a2', 'day_complete') = 1,
  'aynı gün ikinci kez gitmez');

-- başka aile bildirimi göremez
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from public.notifications where kind in ('day_complete', 'task_done')) = 0, 'başka aile gün ve adım bildirimini göremez');

-- ---------------------------------------------------------------- gün bildirimi kapalı: satır var, push yok
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.parent_notification_prefs_set('day_complete', false)::jsonb = '{"step_done": false, "day_complete": false, "tips": true}', 'Anne gün bildirimini kapatır');
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select public.child_set_status('00000000-0000-0000-0000-000000007a04', tst.day() - 1, 'pending');   -- dünün geç işareti
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a2', 'day_complete', '00000000-0000-0000-0000-00000000c002') = 0, 'geçmiş günün işareti gün bildirimi üretmez');
select public.child_set_status('00000000-0000-0000-0000-000000007a04', tst.day(), 'pending');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a1', 'day_complete', '00000000-0000-0000-0000-00000000c002') = 1
             and not (tst.last('00000000-0000-0000-0000-0000000000a1', 'day_complete', '00000000-0000-0000-0000-00000000c002')).push
             and not tst.pushed((tst.last('00000000-0000-0000-0000-0000000000a1', 'day_complete', '00000000-0000-0000-0000-00000000c002')).id),
  'kapalıyken Anne''nin listesinde var, push yok');
select tst.check((tst.last('00000000-0000-0000-0000-0000000000a2', 'day_complete', '00000000-0000-0000-0000-00000000c002')).push, 'Baba''ya push (çocuk başına ayrı gün)');

-- "Yapamam" olan gün tamamlanmış sayılmaz
select tst.as_user('00000000-0000-0000-0000-0000000000c3');
select public.child_set_status('00000000-0000-0000-0000-000000007a05', tst.day(), 'pending');
select public.child_set_status('00000000-0000-0000-0000-000000007a06', tst.day(), 'declined');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000a2', 'day_complete', '00000000-0000-0000-0000-00000000c003') = 0, '"Yapamam" varken gün bildirimi yok');
select tst.check(tst.marked('00000000-0000-0000-0000-00000000c003') is null, 'gün işaretlenmedi');

-- açınca yeniden push; öteki türler etkilenmez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.check(public.parent_notification_prefs_set('day_complete', true)::jsonb ->> 'day_complete' = 'true', 'yeniden açılır');
reset role;
select tst.as_user(null);
insert into public.messages (family_id, child_id, sender, kind, media_path)
  values ((select v::uuid from tst.kv where k = 'fid'), '00000000-0000-0000-0000-00000000c001', 'child', 'image', 'x/y.jpg');
select tst.check((tst.last('00000000-0000-0000-0000-0000000000a1', 'message')).push
             and tst.pushed((tst.last('00000000-0000-0000-0000-0000000000a1', 'message')).id), 'posta bildirimi tercihten etkilenmez');
select tst.check((select bool_and(push) from public.notifications where app <> 'parent'), 'çocuk ve uzman bildirimleri push ile kalır');
select tst.check((select count(*) from public.parent_notification_prefs) = 2, 'satır yalnız ayar değiştirenlerde (Anne, Baba)');

-- ebeveyn hesabı silinince tercihi de silinir
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a2';
select tst.check(not exists (select 1 from public.parent_notification_prefs where user_id = '00000000-0000-0000-0000-0000000000a2'), 'hesapla birlikte silinir');

select 'TÜM EBEVEYN BİLDİRİM TERCİHİ TESTLERİ GEÇTİ' as sonuc;
