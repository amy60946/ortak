-- Beyaz şapka taraması 2 (migrations/20261025000000_whitehat2.sql, uygulandı 25 Ekim 2026) + doğru engellenen saldırılar (gerileme testleri).
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
grant usage on schema tst to authenticated, anon;
grant all on tst.kv to authenticated, anon;
grant execute on all functions in schema tst to authenticated, anon;
create or replace function tst.v(key text) returns text language sql as $$ select v from tst.kv where k = key $$;
grant execute on function tst.v(text) to authenticated, anon;

-- a1 saldırgan ebeveyn (kendi ailesi), c9 saldırganın anonim cihazı; a2 kurban ebeveyn, c2 kurban çocuğun cihazı;
-- d1 uzman (başka klinik)
insert into auth.users (id, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', false, '{"nickname":"Saldırgan"}'),
  ('00000000-0000-0000-0000-0000000000a2', false, '{"nickname":"Kurban"}'),
  ('00000000-0000-0000-0000-0000000000c9', true, '{}'),
  ('00000000-0000-0000-0000-0000000000c2', true, '{}'),
  ('00000000-0000-0000-0000-0000000000d1', false, '{"account":"clinician","clinic_name":"Başka","name":"Dr. X"}');

set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000ca01', public.my_family_id(), 'Kendi', 'kedi');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
insert into public.children (id, family_id, name, avatar) values ('00000000-0000-0000-0000-00000000cb01', public.my_family_id(), 'Kurban', 'kedi');
insert into public.tasks (id, family_id, title, start_date, recurring, requires_review) values
  ('00000000-0000-0000-0000-000000007b01', public.my_family_id(), 'Diş', current_date - 30, true, false);
insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins) values
  ('00000000-0000-0000-0000-000000007b01', '00000000-0000-0000-0000-00000000cb01', public.my_family_id(), 'easy', 10);
insert into tst.kv select 'victim_code', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000cb01');
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.check(public.redeem_child_code(tst.v('victim_code')) ->> 'child_id' is not null, 'kurban cihazı bağlandı');
select tst.as_user('00000000-0000-0000-0000-0000000000a2');
insert into tst.kv select 'victim_fid', public.my_family_id()::text;

-- =====================================================================
-- W2-1: deneme sayacı saldırganın kendi geçerli koduyla sıfırlanamaz (oturum + IP)
-- =====================================================================
select set_config('request.headers', '{"cf-connecting-ip":"203.0.113.50"}', false);
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select public.redeem_child_code('ZZZZZ' || x) from generate_series(2, 9) x;   -- 9 hatalı deneme
select public.redeem_child_code('YYYYYY');
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'own1', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000ca01');
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.check(public.redeem_child_code(tst.v('own1')) ->> 'child_id' is not null, 'W2-1: saldırgan kendi koduyla bağlanır');
reset role;
select tst.check((select count(*) from public.code_attempts where user_id = '00000000-0000-0000-0000-0000000000c9') = 9,
  'W2-1: başarılı kendi kodu hatalı denemeleri silmez (oturum sayacı)');
select tst.check((select count(*) from public.code_attempts where ip = '203.0.113.50') = 9,
  'W2-1: başarılı kendi kodu IP sayacını da silmez');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select public.redeem_child_code('XXXXXX');   -- 10. hata
select tst.check(public.redeem_child_code('WWWWWW') ->> 'error' = 'too_many_attempts',
  'W2-1: sıfırlama hilesinden sonra da 10 hatada 429');
-- IP sınırı: aynı IP'den yeni anonim oturum + kendi kodu döngüsü 30 hatayı aşamaz
reset role;
insert into public.code_attempts (user_id, ip) select gen_random_uuid(), '203.0.113.50' from generate_series(1, 20);
insert into auth.users (id, is_anonymous) values ('00000000-0000-0000-0000-0000000000c8', true);
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
insert into tst.kv select 'own2', code from public.create_invite_code('child', '00000000-0000-0000-0000-00000000ca01');
select tst.as_user('00000000-0000-0000-0000-0000000000c8');
select tst.check(public.redeem_child_code(tst.v('own2')) ->> 'error' = 'too_many_attempts',
  'W2-1: IP 30 hatayı geçtiyse kendi kodu da sayacı temizlemek için kullanılamaz');
select set_config('request.headers', '', false);
reset role;
delete from public.code_attempts;
set role authenticated;

-- =====================================================================
-- Doğru engellenen saldırılar (gerileme)
-- =====================================================================
-- Çocuk cihazı: kimlik/aile alanları yazılamaz, başka aile görünmez
select tst.as_user('00000000-0000-0000-0000-0000000000c9');
select tst.fails($$update public.children set user_id = auth.uid() where id = '00000000-0000-0000-0000-00000000cb01'$$, 'çocuk user_id yazamaz');
select tst.check((select count(*) from public.children where id = '00000000-0000-0000-0000-00000000cb01') = 0, 'çocuk başka ailenin çocuğunu görmez');
select tst.fails($$select public.sun_stones_spendable('00000000-0000-0000-0000-00000000cb01')$$, 'çocuk başka çocuğun taş bakiyesini soramaz');
select tst.fails($$select public.child_balance('00000000-0000-0000-0000-00000000cb01')$$, 'çocuk başka çocuğun coin bakiyesini soramaz');
select tst.fails($$insert into public.messages (family_id, child_id, sender, sender_id, kind, body)
  values (tst.v('victim_fid')::uuid, '00000000-0000-0000-0000-00000000cb01', 'child', auth.uid(), 'text', 'merhaba')$$, 'çocuk başka çocuğun adına mesaj yazamaz');
select tst.fails($$insert into storage.objects (bucket_id, name) values ('mail', tst.v('victim_fid') || '/x.jpg')$$, 'çocuk başka ailenin posta klasörüne yükleyemez');
select tst.fails($$insert into public.coin_ledger (family_id, child_id, amount, reason, ref) values (public.my_any_family_id(), public.my_child_id(), 999, 'adjust', 'x')$$, 'coin defterine doğrudan yazılamaz');
select tst.fails($$insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref) values (public.my_any_family_id(), public.my_child_id(), 99, 'adjust', 'x')$$, 'taş defterine doğrudan yazılamaz');

-- Çocuk ekonomisi: negatif/aşırı adet, idempotent harcama, XP coin'e dönüşmez, hoş geldin bir kez
select tst.check((public.claim_welcome_coins() ->> 'coins')::int = 20, 'hoş geldin coini ilk çağrıda');
select tst.check((public.claim_welcome_coins() ->> 'error') = 'already_claimed', 'hoş geldin coini ikinci kez yok');
select tst.check(public.spend_coins('tx-negatif-01', 'glasses_round', -5) ->> 'error' = 'unknown_item', 'negatif adet reddedilir');
select tst.check(public.spend_coins('tx-asiri-0001', 'glasses_round', 100000) ->> 'error' = 'unknown_item', 'aşırı adet reddedilir (taşma yok)');
select tst.check((public.spend_coins('tx-tekrar-001', 'glasses_round', 1) ->> 'balance')::int = 5, 'harcama bir kez düşer');
select tst.check((public.spend_coins('tx-tekrar-001', 'glasses_round', 1) ->> 'balance')::int = 5, 'aynı işlem kimliği ikinci kez düşmez');
select public.game_save_put('{"Xp":{"TotalXp":999999999,"BestLevel":99},"Coins":99999,"SunStones":999}'::jsonb);
select tst.check((public.child_me() ->> 'balance')::int = 5 and (public.child_me() ->> 'sun_stones')::int = 0, 'oyun kaydındaki XP/coin/taş sunucu bakiyesine geçmez');

-- Kurban çocuğun cihazı: tarih hilesi
select tst.as_user('00000000-0000-0000-0000-0000000000c2');
select tst.fails($$select public.child_set_status('00000000-0000-0000-0000-000000007b01', current_date - 2, 'pending')$$, 'iki gün önceki görev işaretlenemez');
select tst.fails($$select public.child_set_status('00000000-0000-0000-0000-000000007b01', current_date + 2, 'pending')$$, 'iki gün sonraki görev işaretlenemez');
select tst.fails($$insert into public.completions (family_id, task_id, child_id, date, status)
  values (public.my_any_family_id(), '00000000-0000-0000-0000-000000007b01', public.my_child_id(), current_date - 10, 'approved')$$, 'çocuk tamamlamayı doğrudan yazamaz');

-- Saldırgan ebeveyn: başka aileye dokunamaz, yetki alanları yazılamaz
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select tst.fails($$update public.profiles set family_id = tst.v('victim_fid')::uuid where id = auth.uid()$$, 'ebeveyn family_id yazamaz');
select tst.fails($$update public.families set trial_started_at = now() + interval '10 years'$$, 'ebeveyn deneme başlangıcını yazamaz');
select tst.fails($$insert into public.family_subscriptions (family_id, plan) values (public.my_family_id(), 'premium')$$, 'ebeveyn kendine premium yazamaz');
select tst.fails($$select public.review_completion('00000000-0000-0000-0000-000000007b01', '00000000-0000-0000-0000-00000000cb01', current_date, 'approved')$$, 'başka ailenin görevini onaylayamaz');
select tst.fails($$select public.deduct_sun_stones('00000000-0000-0000-0000-00000000cb01', 1)$$, 'başka ailenin çocuğundan taş düşemez');
select tst.fails($$select public.unlink_child_device('00000000-0000-0000-0000-00000000cb01')$$, 'başka ailenin cihaz bağlantısını kesemez');
select tst.fails($$select public.weekly_goal('00000000-0000-0000-0000-00000000cb01')$$, 'başka ailenin haftalık hedefini okuyamaz');
select tst.fails($$insert into public.abc_events (family_id, child_id, behavior, audio_path)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000ca01', 'x', tst.v('victim_fid') || '/ses.m4a')$$, 'zor an sesi başka ailenin klasörünü gösteremez');
select tst.fails($$insert into public.messages (family_id, child_id, sender, sender_id, kind, media_path)
  values (public.my_family_id(), '00000000-0000-0000-0000-00000000ca01', 'parent', auth.uid(), 'image', tst.v('victim_fid') || '/foto.jpg')$$, 'ebeveyn mesajı başka ailenin dosyasını gösteremez');
select tst.fails($$insert into public.task_assignments (task_id, child_id, family_id, difficulty, coins)
  values ('00000000-0000-0000-0000-000000007b01', '00000000-0000-0000-0000-00000000ca01', public.my_family_id(), 'easy', 10)$$, 'başka ailenin görevi kendi çocuğuna atanamaz');
select tst.check((select count(*) from public.notifications where user_id <> auth.uid()) = 0, 'başkasının bildirimleri görünmez');

-- Admin yükseltmesi
select tst.fails($$insert into public.admin_users (user_id, role) values (auth.uid(), 'owner')$$, 'admin tablosuna yazılamaz');
select tst.check(public.admin_me() is null, 'admin olmayan için admin_me boş');
select tst.fails($$select * from public.admin_search('Kurban', 10)$$, 'admin olmayan arama yapamaz');
select tst.fails($$select public.admin_grant_premium(public.my_family_id(), now() + interval '1 year', 'kendime')$$, 'admin olmayan premium veremez');
reset role;
insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-0000000000a1', 'viewer');
set role authenticated;
select tst.as_user('00000000-0000-0000-0000-0000000000a1');
select set_config('request.jwt.claims', '{"aal":"aal1"}', false);
select tst.fails($$select * from public.admin_search('Kurban', 10)$$, 'admin de iki adımlı doğrulamasız okuyamaz');
select set_config('request.jwt.claims', '{"aal":"aal2"}', false);
select tst.fails($$select public.admin_grant_premium(public.my_family_id(), now() + interval '1 year', 'kendime')$$, 'viewer rolü premium veremez');
select tst.fails($$select public.admin_set_admin('x@example.com', 'owner', 'yükselt')$$, 'viewer rolü admin atayamaz');
select set_config('request.jwt.claims', '', false);

-- Başka klinik: kurban çocuğun verisi kapalı
select tst.as_user('00000000-0000-0000-0000-0000000000d1');
select tst.check((select count(*) from public.children) + (select count(*) from public.completions) + (select count(*) from public.abc_events) = 0, 'bağlantısız uzman çocuk verisi görmez');
select tst.fails($$select public.clinic_share_child(public.my_clinic_id(), '00000000-0000-0000-0000-00000000cb01')$$, 'uzman aile adına paylaşım açamaz');
select tst.fails($$update public.clinics set plan = 'business'$$, 'uzman klinik planını yazamaz');

-- Girişsiz
reset role;
set role anon;
select tst.fails($$select public.redeem_child_code('ABCDEF')$$, 'girişsiz kod deneyemez');
select tst.check((select count(*) from public.children) + (select count(*) from public.messages) + (select count(*) from public.completions) = 0, 'girişsiz satır göremez (RLS)');
reset role;

select 'BEYAZ ŞAPKA 2 TESTLERİ GEÇTİ' as sonuc;
