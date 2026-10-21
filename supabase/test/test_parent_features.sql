-- ParentApp istekleri (20261019140000_parent_features.sql): kategoriler, gün bölümü, çok çocuklu zor an, ses kovası.
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
create or replace function tst.n(u text, k text) returns integer language sql security definer as $$
  select count(*)::integer from public.notifications where user_id = u::uuid and kind = k $$;
grant execute on function tst.n(text, text) to authenticated;

insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Anne"}'),
  ('00000000-0000-0000-0000-0000000000e1', false, '{"nickname":"Yabancı"}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Mavi Klinik","name":"Dr. Ece"}');
insert into tst.kv select 'fid', family_id::text from public.profiles where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.children (id, family_id, name, avatar)
  values ('00000000-0000-0000-0000-00000000c001', (select v::uuid from tst.kv where k = 'fid'), 'Nazlı', 'kedi'),
         ('00000000-0000-0000-0000-00000000c002', (select v::uuid from tst.kv where k = 'fid'), 'Efe', 'kedi');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');

-- kategoriler
insert into public.saved_templates (family_id, template_key, saved, is_custom, title, emoji, category, difficulty)
  values (public.my_family_id(), 'c1', true, true, 'Koşu', '🏃', 'health', 'easy'),
         (public.my_family_id(), 'c2', true, true, 'Sıra bekle', '⏳', 'focus', 'easy'),
         (public.my_family_id(), 'c3', true, true, 'Kardeşine sarıl', '🤗', 'relation', 'easy');
select tst.check((select count(*) from public.saved_templates) = 3, 'yeni kategoriler kaydedilir');
select tst.fails($$insert into public.saved_templates (family_id, template_key, saved, is_custom, title, emoji, category, difficulty)
  values (public.my_family_id(), 'c4', true, true, 'x', 'x', 'self', 'easy')$$, 'eski self kategorisi artık yok');

-- görevin gün bölümü
insert into public.tasks (id, family_id, title, start_date, day_part) values
  ('00000000-0000-0000-0000-000000007a51', public.my_family_id(), 'Dişler', current_date, 'morning'),
  ('00000000-0000-0000-0000-000000007a52', public.my_family_id(), 'Kitap', current_date, null);
select tst.fails($$update public.tasks set day_part = 'night' where title = 'Dişler'$$, 'görevde gece yok (sabah/öğle/akşam/herhangi)');

-- uzman iki çocuğu görür
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
insert into tst.kv values ('fam', public.clinic_create_invite('family', '') ->> 'code');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.redeem_clinic_invite_children((select v from tst.kv where k = 'fam'),
  array['00000000-0000-0000-0000-00000000c001'::uuid, '00000000-0000-0000-0000-00000000c002'::uuid]);

-- ses dosyası: yalnız kendi aile klasörüne
insert into storage.objects (bucket_id, name) values ('abc', (select v from tst.kv where k = 'fid') || '/kavga.m4a');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('abc', 'baska-aile/x.m4a')$$, 'başka klasöre ses yüklenemez');
select tst.fails($$insert into public.abc_events (family_id, child_id, behavior, audio_path) values
  (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'x', 'baska-aile/x.m4a')$$, 'kayıttaki ses yolu ailenin klasöründe olmalı');

-- iki çocuklu tek olay: tek INSERT, ortak group_id → uzmana tek bildirim
insert into public.abc_events (family_id, child_id, group_id, occurred_at, day_part, antecedent, behavior, consequence, intensity, audio_path, duration_ms, created_by)
  select public.my_family_id(), c, '00000000-0000-0000-0000-00000000aaaa', current_date + time '19:00', 'evening',
         'Oyuncak paylaşımı', 'Kavga ettiler', 'Ayrı odalara gittiler', 4,
         (select v from tst.kv where k = 'fid') || '/kavga.m4a', 42000, auth.uid()
  from unnest(array['00000000-0000-0000-0000-00000000c001'::uuid, '00000000-0000-0000-0000-00000000c002'::uuid]) c;
select tst.check((select count(*) from public.abc_events where group_id = '00000000-0000-0000-0000-00000000aaaa') = 2, 'olay iki çocuğun kaydına da girer');
select tst.fails($$insert into public.abc_events (family_id, child_id, behavior, day_part) values (public.my_family_id(), '00000000-0000-0000-0000-00000000c001', 'x', 'gece')$$, 'geçersiz gün bölümü');

select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check(tst.n('00000000-0000-0000-0000-0000000000d1', 'abc_event') = 1, 'iki çocuklu olay uzmana tek bildirim');
select tst.check((select title from public.notifications where kind = 'abc_event') = 'Yeni zor an kaydı: Efe, Nazlı', 'bildirimde iki ad');
select tst.check((select body from public.notifications where kind = 'abc_event') like '%sesli kayıt%', 'bildirimde sesli kayıt notu');
select tst.check((select count(*) from public.abc_events where group_id = '00000000-0000-0000-0000-00000000aaaa') = 2, 'uzman iki kaydı görür');
select tst.check((select count(*) from storage.objects where bucket_id = 'abc') = 1, 'bağlı uzman sesi dinleyebilir');

-- yabancı aile sesi göremez
select tst.as_user('00000000-0000-0000-0000-0000000000e1');
select tst.check((select count(*) from storage.objects where bucket_id = 'abc') = 0, 'başka aile sesi göremez');

-- paylaşım iki çocuk için de bitince uzman sesi göremez
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select public.revoke_clinic_link(link_id) from public.family_clinic_links();
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from storage.objects where bucket_id = 'abc') = 0, 'rıza bitince uzman sesi göremez');
select tst.check((select count(*) from public.abc_events) = 0, 'rıza bitince uzman kaydı göremez');

reset role;
select 'TÜM EBEVEYN ÖZELLİK TESTLERİ GEÇTİ' as sonuc;
