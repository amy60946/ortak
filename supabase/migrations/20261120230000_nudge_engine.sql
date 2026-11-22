-- =====================================================================
-- Sunucu taraflı kişiselleştirilmiş bildirim motoru (aşama 2) (ÖNERİ, 20 Kasım 2026; uygulanmadı)
--   Kullanıcı isteği (20 Kasım 2026): "Kişiselleştirilmiş, otomatik bildirim sistemi." Tasarım akislar.md 25 (aşama 2 bu dosya),
--   sınırlar kullanıcı kararları 20 Kasım 2026, hukuk_notlari N (metinde çocuk / ebeveyn adı ve davranış ayrıntısı yok,
--   kampanya / indirim yok). Sözleşme: akislar.md 25 "Sunucu motoru (aşama 2)", admin.md, veritabani.md 36, durumlar.md 8.
--
--   nudge_rules  kural: hangi adımda takılı kişiye, kaç saat sonra, hangi sabit metin (yer tutucu yok), hedef huni adımı.
--   nudge_log    karar kaydı: sent / skipped_limit / skipped_quiet / skipped_pref / holdout; açılma (okundu) ve 72 saatte
--                hedefe geçiş (converted_at). Gönderilen ve holdout kaydı kural + kişi + ref başına bir kez.
--   nudge_pauses üç yanıtsız hatırlatmadan sonraki 14 günlük ara.
--   nudge_run()  tek karar adımı (pg_cron her 15 dakikada; yoksa Edge Function + dış zamanlayıcı, akislar.md 25).
--                Bayrak nudges_server (ürüne özel nudges_server_parent / nudges_server_clinic tanımlıysa o geçer),
--                varsayılan KAPALI; kapalıyken hiçbir şey yapmaz.
--   Sınırlar (Türkiye saati): Moyo 21:00–08:00 yok ve günde en çok 1 anlık bildirim (o gün telefona giden başka bildirim
--   varsa ipucu yok); Moyo Mercek yalnız hafta içi 08:30–19:00. İpucu (tip): günde 1, kayan 7 günde 2, o gün uygulama
--   açıldıysa yok, son 3 ipucuna yanıt yoksa 14 gün ara, %10 karşılaştırma grubu (holdout) hiç almaz (yalnız kayıt).
--   Hesap bilgisi (account: deneme bitişi) bu sınırların, tercihin ve karşılaştırma grubunun dışında; sessiz saate uyar.
--   Karşılaştırma grubu Moyo Mercek'in cihaz içi kuralıyla aynı (kimliğin FNV-1a özeti % 10 = 0; clinic-app nudgeCore.ts).
--   Tercih: "Hatırlatmalar ve ipuçları" = tercih anahtarı tips (Moyo: parent_notification_prefs.tips, Moyo Mercek:
--   clinician_notification_prefs.tips; ikisi de varsayılan açık).
--   Gönderim mevcut yol: notifications satırı (kind 'nudge', data.nudge = açılacak yer) → notifications_push → push-apns / Expo.
-- Önkoşul: migrations/20261120210000_parent_notification_prefs.sql (notifications.push, parent_notification_prefs) ve
--          migrations/20261120220000_funnel_analytics.sql (funnel_parent_steps / funnel_clinic_steps). Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tercih: "Hatırlatmalar ve ipuçları" (tips)
-- ---------------------------------------------------------------------
-- Sıra denetimi: önkoşul dosyalar çalışmadıysa hiçbir şey yazmadan anlaşılır bir hatayla durur.
do $$ begin
  if to_regclass('public.parent_notification_prefs') is null then
    raise exception 'Önce 20261120210000_parent_notification_prefs.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
  if to_regclass('public.store_funnel_daily') is null then
    raise exception 'Önce 20261120220000_funnel_analytics.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
end $$;

-- Moyo: parent_notification_prefs'e üçüncü anahtar. Son tanım burada (önceki: migrations/20261120210000).
alter table public.parent_notification_prefs add column if not exists tips boolean not null default true;

create or replace function public.parent_notification_prefs_of(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('step_done', coalesce(p.step_done, false), 'day_complete', coalesce(p.day_complete, true),
                            'tips', coalesce(p.tips, true))
    from (select 1) x left join public.parent_notification_prefs p on p.user_id = p_user
$$;
revoke execute on function public.parent_notification_prefs_of(uuid) from public, anon, authenticated;

create or replace function public.parent_notification_prefs_set(p_key text, p_on boolean)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null or not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Ebeveyn hesabı gerekli' using errcode = '42501';
  end if;
  if p_key is null or p_key not in ('step_done', 'day_complete', 'tips') then
    raise exception 'Geçersiz bildirim ayarı' using errcode = '22023';
  end if;
  if p_on is null then
    raise exception 'Açık ya da kapalı seç' using errcode = '22023';
  end if;
  insert into public.parent_notification_prefs (user_id) values (uid) on conflict (user_id) do nothing;   -- varsayılanlarla
  update public.parent_notification_prefs
     set step_done    = case when p_key = 'step_done' then p_on else step_done end,
         day_complete = case when p_key = 'day_complete' then p_on else day_complete end,
         tips         = case when p_key = 'tips' then p_on else tips end,
         updated_at   = now()
   where user_id = uid;
  return public.parent_notification_prefs_of(uid)::json;
end $$;
revoke execute on function public.parent_notification_prefs_set(text, boolean) from public, anon;
grant execute on function public.parent_notification_prefs_set(text, boolean) to authenticated;

-- Moyo Mercek: uzman başına tercih (cihazdaki Ayarlar › Bildirimler › "Hatırlatmalar ve ipuçları" anahtarı buraya da yazar)
create table if not exists public.clinician_notification_prefs (
  user_id     uuid primary key references public.clinicians (id) on delete cascade,
  tips        boolean not null default true,
  updated_at  timestamptz not null default now()
);
alter table public.clinician_notification_prefs enable row level security;
drop policy if exists "uzman bildirim tercihi: kendi okur" on public.clinician_notification_prefs;
create policy "uzman bildirim tercihi: kendi okur" on public.clinician_notification_prefs for select to authenticated
  using (user_id = auth.uid());
revoke all on public.clinician_notification_prefs from anon;
revoke insert, update, delete, truncate on public.clinician_notification_prefs from authenticated;

create or replace function public.clinician_notification_prefs()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists (select 1 from public.clinicians where id = auth.uid()) then
    raise exception 'Uzman hesabı gerekli' using errcode = '42501';
  end if;
  return json_build_object('tips', coalesce((select p.tips from public.clinician_notification_prefs p where p.user_id = auth.uid()), true));
end $$;
revoke execute on function public.clinician_notification_prefs() from public, anon;
grant execute on function public.clinician_notification_prefs() to authenticated;

create or replace function public.clinician_notification_prefs_set(p_key text, p_on boolean)
returns json language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null or not exists (select 1 from public.clinicians where id = uid) then
    raise exception 'Uzman hesabı gerekli' using errcode = '42501';
  end if;
  if p_key is null or p_key <> 'tips' then raise exception 'Geçersiz bildirim ayarı' using errcode = '22023'; end if;
  if p_on is null then raise exception 'Açık ya da kapalı seç' using errcode = '22023'; end if;
  insert into public.clinician_notification_prefs (user_id, tips, updated_at) values (uid, p_on, now())
  on conflict (user_id) do update set tips = excluded.tips, updated_at = now();
  return json_build_object('tips', p_on);
end $$;
revoke execute on function public.clinician_notification_prefs_set(text, boolean) from public, anon;
grant execute on function public.clinician_notification_prefs_set(text, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Tablolar (istemciye kapalı: RLS açık, politika yok; kişi kendi kaydını da doğrudan okumaz)
-- ---------------------------------------------------------------------
-- trigger ve bekleme:
--   step            from_step'e (ve requires'a) ulaşmış, target_step'e ve stops'a ulaşmamış; wait_hours bu andan, max_age_hours
--                   sonra bayat (bayrak açılınca eski hesaplara bildirim yağmasın). Adımlar admin_funnel ile aynı tanım.
--   review_waiting  onay bekleyen "Yaptım" wait_hours'tır bekliyor (çocuğun işaretinden); ebeveyne o işaretten sonra
--                   telefona task_done / day_complete gittiyse atlanır (anlık bildirimle çakışmasın). ref = en eski bekleyen.
--   inactive        aileden kimse wait_hours'tır uygulamayı açmadı (en az bir rutini / adımı var). ref = son görülme günü.
--   trial_ending    deneme bitişinden 3 gün önce (Moyo: o gün; Moyo Mercek: hafta sonuysa önceki cuma), local_from'dan sonra.
--   invite_expiring açık aile davetinin süresi wait_hours içinde doluyor (en geç 2 saat kala). ref = davet kodu.
--   training_none   paylaşım wait_hours önce başladı, hiç eğitim yok. ref = paylaşım kimliği.
--   training_draft  eğitim wait_hours'tır taslakta. ref = eğitim kimliği.
create table if not exists public.nudge_rules (
  key            text primary key check (key ~ '^[a-z][a-z0-9_]{1,59}$'),
  product        text not null check (product in ('parent', 'clinic')),
  label          text not null check (char_length(label) between 1 and 120),            -- panelde kısa ad
  trigger        text not null check (trigger in ('step', 'review_waiting', 'inactive', 'trial_ending', 'invite_expiring',
                                                  'training_none', 'training_draft')),
  from_step      text,
  requires       text[] not null default '{}',
  stops          text[] not null default '{}',
  target_step    text not null check (target_step ~ '^[a-z][a-z0-9_]{1,39}$'),        -- dönüşüm: 72 saatte bu hedef
  wait_hours     integer not null check (wait_hours between 0 and 2160),
  max_age_hours  integer not null check (max_age_hours between 1 and 4320),
  local_from     time,                                                                   -- en erken Türkiye saati (boş = sınır yok)
  category       text not null default 'tip' check (category in ('tip', 'account')),
  title          text not null check (char_length(title) between 1 and 120),
  body           text not null check (char_length(body) between 1 and 300),
  route          text not null check (route ~ '^[a-z][a-z0-9_]{1,39}$'),               -- notifications.data.nudge (açılacak yer)
  sort           integer not null default 0,
  enabled        boolean not null default true,
  updated_at     timestamptz not null default now(),
  check (trigger <> 'step' or from_step is not null)
);
alter table public.nudge_rules enable row level security;
revoke all on public.nudge_rules from anon, authenticated;

create table if not exists public.nudge_log (
  id               bigserial primary key,
  user_id          uuid not null references auth.users (id) on delete cascade,
  product          text not null check (product in ('parent', 'clinic')),
  rule_key         text not null references public.nudge_rules (key) on delete cascade,
  ref              text not null default '' check (char_length(ref) <= 80),
  result           text not null check (result in ('sent', 'skipped_limit', 'skipped_quiet', 'skipped_pref', 'holdout')),
  detail           text check (detail in ('opened_today', 'daily', 'weekly', 'pause')),
  day              date not null,                                                       -- Türkiye günü
  at               timestamptz not null default now(),
  notification_id  bigint references public.notifications (id) on delete set null,
  opened_at        timestamptz,
  converted_at     timestamptz
);
-- gönderim ve karşılaştırma kaydı kural + kişi + ref başına bir kez; atlama kaydı aynı gün bir kez
create unique index if not exists nudge_log_once on public.nudge_log (user_id, rule_key, ref) where result in ('sent', 'holdout');
create unique index if not exists nudge_log_skip_day on public.nudge_log (user_id, rule_key, ref, result, day)
  where result not in ('sent', 'holdout');
create index if not exists nudge_log_user_at on public.nudge_log (user_id, at desc);
create index if not exists nudge_log_rule_at on public.nudge_log (rule_key, at);
create index if not exists nudge_log_notification on public.nudge_log (notification_id) where notification_id is not null;
alter table public.nudge_log enable row level security;
revoke all on public.nudge_log from anon, authenticated;
revoke all on sequence public.nudge_log_id_seq from anon, authenticated;

create table if not exists public.nudge_pauses (
  user_id       uuid primary key references auth.users (id) on delete cascade,
  paused_until  timestamptz not null,
  started_at    timestamptz not null default now()
);
alter table public.nudge_pauses enable row level security;
revoke all on public.nudge_pauses from anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Kurallar (metinler sabit, kısa, nötr; ad, davranış ayrıntısı, indirim, çocuğa çağrı, sağlık iddiası yok).
--    Yeniden çalıştırınca metin ve ayar güncellenir; owner'ın aç / kapat seçimi (enabled) korunur.
-- ---------------------------------------------------------------------
insert into public.nudge_rules (key, product, label, trigger, from_step, requires, stops, target_step, wait_hours, max_age_hours,
                                local_from, category, title, body, route, sort) values
  ('parent_trial_ending', 'parent', 'Deneme bitişinden 3 gün önce', 'trial_ending', null, '{}', '{}', 'paid', 0, 24, '10:00', 'account',
   'Moyo', 'Ücretsiz denemen 3 gün sonra bitiyor. Kendiliğinden ücret alınmaz; planları Moyo''da görebilirsin.', 'trial_ending', 0),
  ('parent_review_waiting', 'parent', 'Onay bekleyen "Yaptım" (24 saat)', 'review_waiting', null, '{}', '{}', 'review', 24, 168, null, 'tip',
   'Moyo', 'Onayını bekleyen adımlar var. İnceleme ekranından birkaç dakikada bakabilirsin.', 'review_waiting', 10),
  ('parent_game_link_1', 'parent', 'Çocuk eklendi, oyun bağlanmadı (24 saat)', 'step', 'child_added', '{}', '{}', 'game_linked', 24, 336, null, 'tip',
   'Moyo', 'Çocuğunun tabletinde Moyo Oyun''u açıp giriş kodunu yazdığında rutinler oyunda görünür.', 'game_link', 20),
  ('parent_game_link_2', 'parent', 'Çocuk eklendi, oyun bağlanmadı (72 saat)', 'step', 'child_added', '{}', '{}', 'game_linked', 72, 336, null, 'tip',
   'Moyo', 'Moyo Oyun henüz bağlanmadı. Moyo''dan yeni bir giriş kodu alabilirsin; kod 15 dakika geçerli.', 'game_link', 21),
  ('parent_routine_none', 'parent', 'Oyun bağlandı, rutin yok (24 saat)', 'step', 'game_linked', '{}', '{}', 'first_routine', 24, 336, null, 'tip',
   'Moyo', 'Moyo Oyun bağlandı. Hazır rutinlerden birini seçip adımlarını düzenleyerek başlayabilirsin.', 'routine_none', 30),
  ('parent_done_none', 'parent', 'Rutin var, ilk "Yaptım" yok (48 saat)', 'step', 'first_routine', '{game_linked}', '{}', 'first_done', 48, 336, null, 'tip',
   'Moyo', 'Rutin hazır. Çocuğun bir adımı oyunda işaretlediğinde onayın için burada görünür.', 'done_none', 40),
  ('parent_child_none', 'parent', 'Kayıt oldu, çocuk eklemedi (24 saat)', 'step', 'signup', '{}', '{}', 'child_added', 24, 336, null, 'tip',
   'Moyo', 'Moyo''yu kurmanın ilk adımı çocuğunu eklemek. Adı ve yaş grubu yeterli.', 'child_none', 50),
  ('parent_inactive_7d', 'parent', '7 gündür etkin değil', 'inactive', null, '{}', '{}', 'active', 168, 336, null, 'tip',
   'Moyo', 'Bir haftadır Moyo''yu açmadın. Rutinleri ve bu haftanın adımlarını tek ekranda görebilirsin.', 'inactive', 60),
  ('clinic_trial_ending', 'clinic', 'Deneme bitişinden 3 gün önce (hafta sonuysa cuma)', 'trial_ending', null, '{}', '{}', 'paid', 0, 24, '10:00', 'account',
   'Moyo Mercek', 'Denemen birkaç gün içinde bitiyor. Paketleri iPhone ya da iPad''deki uygulamadan görebilirsin.', 'trial_ending', 0),
  ('clinic_invite_expiring', 'clinic', 'Süresi dolmak üzere olan davet', 'invite_expiring', null, '{}', '{}', 'invite_answered', 24, 72, null, 'tip',
   'Moyo Mercek', 'Gönderdiğin bir davetin süresi dolmak üzere. İstersen yeniden gönderebilirsin.', 'invite_expiring', 10),
  ('clinic_training_none', 'clinic', 'Aile bağlandı, eğitim yok (48 saat)', 'training_none', null, '{}', '{}', 'training_for_link', 48, 384, null, 'tip',
   'Moyo Mercek', 'Yeni bir aile bağlandı. İlk eğitimi oluşturmak ister misin?', 'training_none', 20),
  ('clinic_training_draft', 'clinic', 'Eğitim taslakta (72 saat)', 'training_draft', null, '{}', '{}', 'training_active', 72, 408, null, 'tip',
   'Moyo Mercek', 'Taslakta bekleyen bir eğitimin var. Etkin yaptığında ebeveyn görmeye başlar.', 'training_draft', 30),
  ('clinic_invite_none_1', 'clinic', 'İlk davet yok (24 saat)', 'step', 'signup', '{}', '{family_linked}', 'first_invite', 24, 720, null, 'tip',
   'Moyo Mercek', 'İlk aileni davet etmeye hazır mısın? Ebeveynin e-postasını yazman yeterli; daveti biz göndeririz.', 'invite_none', 40),
  ('clinic_invite_none_2', 'clinic', 'İlk davet yok (5. gün)', 'step', 'signup', '{}', '{family_linked}', 'first_invite', 120, 720, null, 'tip',
   'Moyo Mercek', 'İlk aileni davet etmeye hazır mısın? Ebeveynin e-postasını yazman yeterli; daveti biz göndeririz.', 'invite_none', 41)
on conflict (key) do update set
  product = excluded.product, label = excluded.label, trigger = excluded.trigger, from_step = excluded.from_step,
  requires = excluded.requires, stops = excluded.stops, target_step = excluded.target_step, wait_hours = excluded.wait_hours,
  max_age_hours = excluded.max_age_hours, local_from = excluded.local_from, category = excluded.category,
  title = excluded.title, body = excluded.body, route = excluded.route, sort = excluded.sort, updated_at = now();

-- ---------------------------------------------------------------------
-- 4. Yardımcılar (istemciye kapalı)
-- ---------------------------------------------------------------------
-- Kimliğin 32 bit FNV-1a özeti (Moyo Mercek nudgeCore.ts inHoldout ile aynı: uuid metni, küçük harf)
create or replace function public.nudge_hash(p_user uuid)
returns bigint language plpgsql immutable set search_path = '' as $$
declare
  h bigint := 2166136261;
  s text := lower(p_user::text);
  i integer;
begin
  for i in 1 .. length(s) loop
    h := h # ascii(substr(s, i, 1));
    h := (h * 16777619) & 4294967295;
  end loop;
  return h;
end $$;

create or replace function public.nudge_holdout(p_user uuid)
returns boolean language sql immutable set search_path = '' as $$
  select public.nudge_hash(p_user) % 10 = 0
$$;

-- Bayrak: ürüne özel anahtar (nudges_server_parent / nudges_server_clinic) genel bayrak ya da kişi istisnası olarak
-- tanımlıysa o geçer; değilse nudges_server. Kişiye istisna ve yüzde ile açılış flag_on ile (admin.md "Bayraklar").
create or replace function public.nudge_flag_on(p_user uuid, p_product text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case when exists (select 1 from public.feature_flags f where f.key = 'nudges_server_' || p_product)
                or exists (select 1 from public.user_flags u where u.user_id = p_user and u.key = 'nudges_server_' || p_product
                             and (u.expires_at is null or u.expires_at > now()))
              then public.flag_on(p_user, 'nudges_server_' || p_product)
              else public.flag_on(p_user, 'nudges_server') end
$$;

-- Hızlı ön denetim: bu ürün için açık olabilecek bir bayrak var mı (yoksa motor hiç çalışmaz)
create or replace function public.nudge_flag_any(p_product text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.feature_flags f
                  where f.key in ('nudges_server', 'nudges_server_' || p_product) and f.enabled and f.rollout_pct > 0)
      or exists (select 1 from public.user_flags u
                  where u.key in ('nudges_server', 'nudges_server_' || p_product) and u.enabled
                    and (u.expires_at is null or u.expires_at > now()))
$$;

create or replace function public.nudge_tips_on(p_user uuid, p_product text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case when p_product = 'parent'
              then coalesce((select p.tips from public.parent_notification_prefs p where p.user_id = p_user), true)
              else coalesce((select p.tips from public.clinician_notification_prefs p where p.user_id = p_user), true) end
$$;

-- Ailede bildirimi alan ebeveyn: aileyi açan (hâlâ ailedeyse), yoksa ailedeki ilk ebeveyn
create or replace function public.family_primary_parent(p_family uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select p.id from public.profiles p join public.families f on f.id = p.family_id where f.id = p_family and p.id = f.created_by),
    (select p.id from public.profiles p where p.family_id = p_family order by p.created_at, p.id limit 1))
$$;

-- Moyo Mercek deneme hatırlatmasının günü: bitişten 3 gün önce, hafta sonuysa önceki cuma (nudgeCore.ts ile aynı)
create or replace function public.nudge_clinic_trial_day(p_end timestamptz)
returns date language sql immutable set search_path = '' as $$
  select d - case extract(isodow from d)::int when 6 then 1 when 7 then 2 else 0 end
    from (select (p_end at time zone 'Europe/Istanbul')::date - 3 as d) x
$$;

-- ---------------------------------------------------------------------
-- 5. Adaylar: kim hangi kurala şu an uygun (karar nudge_try'da)
-- ---------------------------------------------------------------------
create or replace function public.nudge_candidates(p_now timestamptz, p_parent boolean, p_clinic boolean)
returns table (user_id uuid, rule_key text, ref text, extra jsonb)
language plpgsql stable security definer set search_path = '' as $$
declare
  t timestamptz := p_now;
  today date := (p_now at time zone 'Europe/Istanbul')::date;
  tdays integer := (public.billing_config() ->> 'trial_days')::int;
begin
  -- A. Huni adımında takılı (ilk 60 gün)
  return query
  with ppl as (
    select 'parent'::text as product, public.family_primary_parent(f.id) as uid, public.funnel_parent_steps(f.id, t) as s
      from public.families f where p_parent and f.created_at > t - interval '60 days' and f.created_at <= t
    union all
    select 'clinic'::text, m.id, public.funnel_clinic_steps(m.id, t)
      from public.clinicians m where p_clinic and m.created_at > t - interval '60 days' and m.created_at <= t
  )
  select p.uid, r.key, ''::text, '{}'::jsonb
    from ppl p
    join public.nudge_rules r on r.product = p.product and r.trigger = 'step' and r.enabled
    cross join lateral (select max((p.s ->> k)::timestamptz) as since from unnest(array[r.from_step] || r.requires) k) w
   where p.uid is not null and p.s ? r.from_step and p.s ?& r.requires
     and not p.s ? r.target_step and not p.s ?| r.stops
     and w.since + make_interval(hours => r.wait_hours) <= t
     and w.since + make_interval(hours => r.max_age_hours) > t;

  -- B. Moyo: onay bekleyen "Yaptım"
  return query
  select pp.uid, r.key, x.id::text, '{}'::jsonb
    from public.nudge_rules r
    cross join lateral (
      select distinct on (c.family_id) c.family_id, c.id, c.child_done_at
        from public.completions c
       where c.status = 'pending' and c.child_done_at is not null
         and c.child_done_at <= t - make_interval(hours => r.wait_hours)
         and c.child_done_at > t - make_interval(hours => r.max_age_hours)
       order by c.family_id, c.child_done_at, c.id) x
    cross join lateral (select public.family_primary_parent(x.family_id) as uid) pp
   where p_parent and r.trigger = 'review_waiting' and r.enabled and pp.uid is not null
     and not exists (select 1 from public.notifications n
                      where n.user_id = pp.uid and n.app = 'parent' and n.kind in ('task_done', 'day_complete') and n.push
                        and n.created_at >= x.child_done_at - interval '1 minute' and n.created_at <= t);

  -- C. Moyo: aileden kimse wait_hours'tır açmadı (rutini / adımı olan aile)
  return query
  select pp.uid, r.key, to_char(ls.seen at time zone 'Europe/Istanbul', 'YYYY-MM-DD'), '{}'::jsonb
    from public.nudge_rules r
    cross join lateral (
      select f.id as fid, (select max(a.last_seen_at) from public.user_activity a join public.profiles p on p.id = a.user_id
                            where p.family_id = f.id and a.app = 'parent') as seen
        from public.families f where exists (select 1 from public.tasks x where x.family_id = f.id)) ls
    cross join lateral (select public.family_primary_parent(ls.fid) as uid) pp
   where p_parent and r.trigger = 'inactive' and r.enabled and pp.uid is not null
     and ls.seen <= t - make_interval(hours => r.wait_hours)
     and ls.seen > t - make_interval(hours => r.max_age_hours);

  -- D. Moyo: deneme bitişinden 3 gün önce (abone ya da ücretli kliniğe bağlı aile almaz)
  return query
  select pp.uid, r.key, to_char(te.te at time zone 'Europe/Istanbul', 'YYYY-MM-DD'), '{}'::jsonb
    from public.nudge_rules r
    cross join lateral (
      select f.id as fid, greatest(f.trial_started_at + make_interval(days => coalesce(f.trial_days::int, tdays)),
                                   coalesce(f.bonus_until, '-infinity'::timestamptz)) as te
        from public.families f where f.trial_started_at is not null and f.trial_started_at > t - interval '200 days') te
    cross join lateral (select public.family_primary_parent(te.fid) as uid) pp
   where p_parent and r.product = 'parent' and r.trigger = 'trial_ending' and r.enabled and pp.uid is not null
     and te.te > t and (te.te at time zone 'Europe/Istanbul')::date - 3 = today
     and not exists (select 1 from public.family_subscriptions s
                      where s.family_id = te.fid and s.plan = 'premium' and s.status in ('active', 'grace', 'canceled')
                        and (s.period_end is null or s.period_end > t))
     and not exists (select 1 from public.clinic_links l join public.clinics c on c.id = l.clinic_id
                      where l.family_id = te.fid and l.status = 'active' and c.plan <> 'trial' and public.clinic_active(c.id));

  -- E. Moyo Mercek: deneme bitişi (kendi açtığı alanların en geç deneme sonu; hâlâ denemede, mağaza üyeliği yok)
  return query
  select k.uid, r.key, to_char(k.te at time zone 'Europe/Istanbul', 'YYYY-MM-DD'), '{}'::jsonb
    from public.nudge_rules r
    cross join lateral (
      select m.id as uid, (select max(c.trial_ends_at) from public.clinics c where c.created_by = m.id and c.plan = 'trial') as te
        from public.clinicians m) k
   where p_clinic and r.product = 'clinic' and r.trigger = 'trial_ending' and r.enabled
     and k.te > t and public.nudge_clinic_trial_day(k.te) = today
     and not exists (select 1 from public.billing_subscriptions b join public.clinics c on c.id = b.clinic_id
                      where c.created_by = k.uid and b.source <> 'manual' and b.status in ('active', 'canceled') and b.period_end > t);

  -- F. Moyo Mercek: süresi dolmak üzere olan açık aile daveti
  return query
  select i.clinician_id, r.key, i.code, jsonb_build_object('code', i.code)
    from public.nudge_rules r
    join public.clinic_invites i on i.kind = 'family'
   where p_clinic and r.trigger = 'invite_expiring' and r.enabled
     and i.used_at is null and i.claimed_at is null and i.revoked_at is null and i.declined_at is null
     and i.expires_at > t + interval '2 hours' and i.expires_at <= t + make_interval(hours => r.wait_hours);

  -- G. Moyo Mercek: aile bağlandı, eğitim yok (sorumlu uzman; yoksa kliniği açan)
  return query
  select coalesce(l.clinician_id, k.created_by), r.key, l.id::text, jsonb_build_object('link_id', l.id)
    from public.nudge_rules r
    join public.clinic_links l on l.status = 'active'
    join public.clinics k on k.id = l.clinic_id
   where p_clinic and r.trigger = 'training_none' and r.enabled
     and l.created_at <= t - make_interval(hours => r.wait_hours) and l.created_at > t - make_interval(hours => r.max_age_hours)
     and not exists (select 1 from public.parent_trainings x where x.link_id = l.id)
     and exists (select 1 from public.clinicians m where m.id = coalesce(l.clinician_id, k.created_by));

  -- H. Moyo Mercek: eğitim taslakta bekliyor (oluşturan uzman; yoksa sorumlu uzman)
  return query
  select coalesce(m.id, l.clinician_id), r.key, x.id::text, jsonb_build_object('link_id', x.link_id, 'training_id', x.id)
    from public.nudge_rules r
    join public.parent_trainings x on x.status = 'draft'
    join public.clinic_links l on l.id = x.link_id and l.status = 'active'
    left join public.clinicians m on m.id = x.created_by
   where p_clinic and r.trigger = 'training_draft' and r.enabled
     and x.created_at <= t - make_interval(hours => r.wait_hours) and x.created_at > t - make_interval(hours => r.max_age_hours)
     and coalesce(m.id, l.clinician_id) is not null;
end $$;

-- ---------------------------------------------------------------------
-- 6. Ölçüm: hedefe ulaşma zamanı (p_since'den sonra ilk), açılma tetikleyicisi, 72 saatlik dönüşüm
-- ---------------------------------------------------------------------
create or replace function public.nudge_goal_at(p_rule public.nudge_rules, p_user uuid, p_ref text, p_since timestamptz,
                                                p_now timestamptz default null)
returns timestamptz language plpgsql stable security definer set search_path = '' as $$
declare
  fid uuid;
  v timestamptz;
begin
  if p_rule.product = 'parent' then
    select p.family_id into fid from public.profiles p where p.id = p_user;
    if fid is null then return null; end if;
    if p_rule.target_step = 'review' then
      return (select min(c.reviewed_at) from public.completions c where c.family_id = fid and c.reviewed_at > p_since);
    elsif p_rule.target_step = 'active' then
      return (select min(e.occurred_at) from public.app_events e join public.profiles p on p.id = e.user_id
               where p.family_id = fid and e.app = 'parent' and e.occurred_at > p_since);
    end if;
    v := (public.funnel_parent_steps(fid, p_now) ->> p_rule.target_step)::timestamptz;
  else
    if p_rule.target_step = 'invite_answered' then
      return least(
        (select min(i.created_at) from public.clinic_invites i
          where i.clinician_id = p_user and i.kind = 'family' and i.created_at > p_since),
        (select min(x) from public.clinic_invites i, unnest(array[i.claimed_at, i.used_at, i.email_sent_at]) x
          where i.code = p_ref and x > p_since));
    elsif p_rule.target_step = 'training_for_link' then
      return (select min(x.created_at) from public.parent_trainings x where x.link_id::text = p_ref and x.created_at > p_since);
    elsif p_rule.target_step = 'training_active' then
      return (select x.activated_at from public.parent_trainings x where x.id::text = p_ref and x.activated_at > p_since);
    end if;
    v := (public.funnel_clinic_steps(p_user, p_now) ->> p_rule.target_step)::timestamptz;
  end if;
  return case when v > p_since then v end;
end $$;

create or replace function public.nudge_convert(p_now timestamptz default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  t timestamptz := coalesce(p_now, now());
  n integer;
begin
  update public.nudge_log l set converted_at = g.at
    from (select l2.id, l2.at as sent_at, public.nudge_goal_at(q, l2.user_id, l2.ref, l2.at, t) as at
            from public.nudge_log l2 join public.nudge_rules q on q.key = l2.rule_key
           where l2.result in ('sent', 'holdout') and l2.converted_at is null
             and l2.at > t - interval '73 hours' and l2.at <= t) g
   where l.id = g.id and g.at is not null and g.at <= g.sent_at + interval '72 hours';
  get diagnostics n = row_count;
  return n;
end $$;

-- Açılma: bildirim okundu işaretlenince (mark_notifications_read ya da okundu güncellemesi) gönderim kaydına
create or replace function public.notifications_nudge_read() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'nudge' and old.read_at is null and new.read_at is not null then
    update public.nudge_log set opened_at = new.read_at where notification_id = new.id and opened_at is null;
  end if;
  return null;
end $$;
drop trigger if exists notifications_nudge_read on public.notifications;
create trigger notifications_nudge_read after update of read_at on public.notifications
  for each row execute function public.notifications_nudge_read();

-- ---------------------------------------------------------------------
-- 7. Karar: tek kişi + tek kural
-- ---------------------------------------------------------------------
create or replace function public.nudge_skip(p_user uuid, p_rule public.nudge_rules, p_ref text, p_result text, p_detail text,
                                             p_now timestamptz)
returns text language plpgsql security definer set search_path = '' as $$
begin
  insert into public.nudge_log (user_id, product, rule_key, ref, result, detail, day, at)
  values (p_user, p_rule.product, p_rule.key, coalesce(p_ref, ''), p_result, p_detail, (p_now at time zone 'Europe/Istanbul')::date, p_now)
  on conflict do nothing;
  return p_result;
end $$;

-- Son 3 ipucuna (önceki aradan sonra) dokunulmadı ve 24 saatte hedefe de geçilmediyse en sonuncusundan 14 gün ara
create or replace function public.nudge_paused(p_user uuid, p_now timestamptz)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  pu timestamptz;
  n integer;
  newest timestamptz;
  silent boolean;
begin
  select paused_until into pu from public.nudge_pauses where user_id = p_user;
  if pu > p_now then return true; end if;
  select count(*), max(l.at),
         bool_and(l.opened_at is null and (l.converted_at is null or l.converted_at > l.at + interval '24 hours')
                  and l.at <= p_now - interval '24 hours')
    into n, newest, silent
    from (select l.* from public.nudge_log l join public.nudge_rules q on q.key = l.rule_key
           where l.user_id = p_user and q.category = 'tip' and l.result in ('sent', 'holdout')
             and l.at > coalesce(pu, '-infinity'::timestamptz) and l.at <= p_now
           order by l.at desc limit 3) l;
  if n = 3 and silent and newest + interval '14 days' > p_now then
    insert into public.nudge_pauses (user_id, paused_until, started_at) values (p_user, newest + interval '14 days', p_now)
    on conflict (user_id) do update set paused_until = excluded.paused_until, started_at = excluded.started_at;
    return true;
  end if;
  return false;
end $$;

-- Dönen: sent / holdout / skipped_* / done (zaten gönderildi) / flag_off / wait (saati gelmedi)
create or replace function public.nudge_try(p_user uuid, p_rule public.nudge_rules, p_ref text, p_extra jsonb, p_now timestamptz)
returns text language plpgsql security definer set search_path = '' as $$
declare
  loc timestamp := p_now at time zone 'Europe/Istanbul';
  d date := (p_now at time zone 'Europe/Istanbul')::date;
  tod time := (p_now at time zone 'Europe/Istanbul')::time;
  dow integer := extract(isodow from (p_now at time zone 'Europe/Istanbul'))::int;
  rf text := coalesce(p_ref, '');
  lid bigint;
  nid bigint;
begin
  if exists (select 1 from public.nudge_log l where l.user_id = p_user and l.rule_key = p_rule.key and l.ref = rf
               and l.result in ('sent', 'holdout')) then
    return 'done';
  end if;
  if not public.nudge_flag_on(p_user, p_rule.product) then return 'flag_off'; end if;
  if p_rule.category = 'tip' and not public.nudge_tips_on(p_user, p_rule.product) then
    return public.nudge_skip(p_user, p_rule, rf, 'skipped_pref', null, p_now);
  end if;
  if (p_rule.product = 'parent' and (tod >= time '21:00' or tod < time '08:00'))
     or (p_rule.product = 'clinic' and (dow > 5 or tod < time '08:30' or tod > time '19:00')) then
    return public.nudge_skip(p_user, p_rule, rf, 'skipped_quiet', null, p_now);
  end if;
  if p_rule.local_from is not null and tod < p_rule.local_from then return 'wait'; end if;
  if p_rule.category = 'tip' then
    if exists (select 1 from public.user_activity a where a.user_id = p_user and a.app = p_rule.product
                 and (a.last_seen_at at time zone 'Europe/Istanbul')::date = d and a.last_seen_at <= p_now) then
      return public.nudge_skip(p_user, p_rule, rf, 'skipped_limit', 'opened_today', p_now);
    end if;
    if exists (select 1 from public.nudge_log l where l.user_id = p_user and l.day = d and l.result in ('sent', 'holdout'))
       or (p_rule.product = 'parent' and exists (
             select 1 from public.notifications n where n.user_id = p_user and n.app = 'parent' and n.push
                and n.created_at <= p_now and n.created_at > p_now - interval '1 day'
                and (n.created_at at time zone 'Europe/Istanbul')::date = d)) then
      return public.nudge_skip(p_user, p_rule, rf, 'skipped_limit', 'daily', p_now);
    end if;
    if (select count(*) from public.nudge_log l join public.nudge_rules q on q.key = l.rule_key
         where l.user_id = p_user and q.category = 'tip' and l.result in ('sent', 'holdout')
           and l.at > p_now - interval '7 days' and l.at <= p_now) >= 2 then
      return public.nudge_skip(p_user, p_rule, rf, 'skipped_limit', 'weekly', p_now);
    end if;
    if public.nudge_paused(p_user, p_now) then
      return public.nudge_skip(p_user, p_rule, rf, 'skipped_limit', 'pause', p_now);
    end if;
    if public.nudge_holdout(p_user) then
      insert into public.nudge_log (user_id, product, rule_key, ref, result, day, at)
      values (p_user, p_rule.product, p_rule.key, rf, 'holdout', d, p_now) on conflict do nothing;
      return 'holdout';
    end if;
  end if;
  insert into public.nudge_log (user_id, product, rule_key, ref, result, day, at)
  values (p_user, p_rule.product, p_rule.key, rf, 'sent', d, p_now) on conflict do nothing
  returning id into lid;
  if lid is null then return 'done'; end if;
  insert into public.notifications (user_id, app, kind, title, body, data, family_id, created_at)
  values (p_user, p_rule.product, 'nudge', p_rule.title, p_rule.body,
          coalesce(p_extra, '{}'::jsonb) || jsonb_build_object(
            'nudge', p_rule.route, 'rule', p_rule.key, 'ref', nullif(rf, ''),
            'id', 'nudge.' || p_rule.route || case when rf <> '' then '.' || rf else '' end),
          case when p_rule.product = 'parent' then (select p.family_id from public.profiles p where p.id = p_user) end, p_now)
  returning id into nid;
  update public.nudge_log set notification_id = nid where id = lid;
  return 'sent';
end $$;

-- ---------------------------------------------------------------------
-- 8. Tek karar adımı (zamanlayıcı çağırır; anon ve authenticated çağıramaz)
-- ---------------------------------------------------------------------
create or replace function public.nudge_run(p_now timestamptz default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  t timestamptz := coalesce(p_now, now());
  op boolean;
  oc boolean;
  c record;
  res text;
  counts jsonb := '{}'::jsonb;
  conv integer;
begin
  if not pg_try_advisory_xact_lock(hashtext('public.nudge_run')) then
    return jsonb_build_object('ran', false, 'reason', 'busy');
  end if;
  op := public.nudge_flag_any('parent');
  oc := public.nudge_flag_any('clinic');
  if not op and not oc then return jsonb_build_object('ran', false, 'reason', 'flag_off'); end if;
  conv := public.nudge_convert(t);
  for c in
    select x.user_id, x.ref, x.extra, r as rule
      from public.nudge_candidates(t, op, oc) x join public.nudge_rules r on r.key = x.rule_key
     where x.user_id is not null
     order by x.user_id, (r.category = 'account') desc, r.sort, x.ref
  loop
    res := public.nudge_try(c.user_id, c.rule, c.ref, c.extra, t);
    counts := counts || jsonb_build_object(res, coalesce((counts ->> res)::int, 0) + 1);
  end loop;
  return jsonb_build_object('ran', true, 'at', t, 'converted', conv, 'results', counts);
end $$;

-- ---------------------------------------------------------------------
-- 9. Panel (admin.md "Bildirim motoru")
-- ---------------------------------------------------------------------
-- Kural başına: gönderilen, açılan, 72 saatte hedefe geçen; karşılaştırma grubu ve fark (lift_pct = gönderilenlerin dönüşüm
-- yüzdesi − karşılaştırma grubunun dönüşüm yüzdesi, yüzde puanı; ikisinden biri yoksa null). Her admin rolü okur.
create or replace function public.admin_nudge_stats(p_product text, p_from date, p_to date)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  a timestamptz := p_from;
  b timestamptz := p_to + 1;
begin
  perform public.admin_require();
  perform public.funnel_check_args(p_product, p_from, p_to);
  return (select coalesce(json_agg(json_build_object(
            'rule', r.key, 'label', r.label, 'enabled', r.enabled, 'category', r.category,
            'sent', z.sent, 'opened', z.opened, 'converted', z.converted,
            'holdout', z.holdout, 'holdout_converted', z.holdout_converted,
            'lift_pct', case when z.sent > 0 and z.holdout > 0
                             then round(z.converted * 100.0 / z.sent - z.holdout_converted * 100.0 / z.holdout, 1) end,
            'skipped', json_build_object('limit', z.s_limit, 'quiet', z.s_quiet, 'pref', z.s_pref))
            order by r.sort, r.key), '[]')
            from public.nudge_rules r
            cross join lateral (
              select count(*) filter (where l.result = 'sent') as sent,
                     count(*) filter (where l.result = 'sent' and l.opened_at is not null) as opened,
                     count(*) filter (where l.result = 'sent' and l.converted_at is not null) as converted,
                     count(*) filter (where l.result = 'holdout') as holdout,
                     count(*) filter (where l.result = 'holdout' and l.converted_at is not null) as holdout_converted,
                     count(distinct (l.user_id, l.ref)) filter (where l.result = 'skipped_limit') as s_limit,
                     count(distinct (l.user_id, l.ref)) filter (where l.result = 'skipped_quiet') as s_quiet,
                     count(distinct (l.user_id, l.ref)) filter (where l.result = 'skipped_pref') as s_pref
                from public.nudge_log l where l.rule_key = r.key and l.at >= a and l.at < b) z
           where r.product = p_product);
end $$;

-- Kural listesi (metinler dahil; kişisel veri yok). Her admin rolü okur.
create or replace function public.admin_nudge_rules()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return (select coalesce(json_agg(json_build_object(
            'key', r.key, 'product', r.product, 'label', r.label, 'trigger', r.trigger, 'from_step', r.from_step,
            'target_step', r.target_step, 'wait_hours', r.wait_hours, 'category', r.category, 'title', r.title, 'body', r.body,
            'route', r.route, 'sort', r.sort, 'enabled', r.enabled, 'updated_at', r.updated_at)
            order by r.product, r.sort, r.key), '[]')
            from public.nudge_rules r);
end $$;

-- Kuralı aç / kapat (metin değişmez; metin yalnız SQL ile). Yalnız owner, gerekçeli, denetim kaydına.
create or replace function public.admin_nudge_rule_set(p_key text, p_enabled boolean, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  old boolean;
begin
  if p_enabled is null then raise exception 'Açık ya da kapalı seç'; end if;
  select enabled into old from public.nudge_rules where key = p_key for update;
  if not found then raise exception 'Bilinmeyen kural: %', p_key; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Gerekçe yaz (en az 3 harf)'; end if;
  update public.nudge_rules set enabled = p_enabled, updated_at = now() where key = p_key;
  perform public.admin_log(me, 'nudge.rule', 'config', 'nudge:' || p_key, p_reason,
                           jsonb_build_object('enabled', old), jsonb_build_object('enabled', p_enabled));
  return json_build_object('key', p_key, 'enabled', p_enabled);
end $$;

-- ---------------------------------------------------------------------
-- 10. Yetkiler
-- ---------------------------------------------------------------------
do $$
declare fn text;
begin
  foreach fn in array array[
    'public.nudge_hash(uuid)', 'public.nudge_holdout(uuid)', 'public.nudge_flag_on(uuid, text)', 'public.nudge_flag_any(text)',
    'public.nudge_tips_on(uuid, text)', 'public.family_primary_parent(uuid)', 'public.nudge_clinic_trial_day(timestamptz)',
    'public.nudge_candidates(timestamptz, boolean, boolean)',
    'public.nudge_goal_at(public.nudge_rules, uuid, text, timestamptz, timestamptz)', 'public.nudge_convert(timestamptz)',
    'public.notifications_nudge_read()', 'public.nudge_skip(uuid, public.nudge_rules, text, text, text, timestamptz)',
    'public.nudge_paused(uuid, timestamptz)', 'public.nudge_try(uuid, public.nudge_rules, text, jsonb, timestamptz)',
    'public.nudge_run(timestamptz)'] loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn);
  end loop;
  foreach fn in array array['public.admin_nudge_stats(text, date, date)', 'public.admin_nudge_rules()',
                            'public.admin_nudge_rule_set(text, boolean, text)'] loop
    execute format('revoke execute on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.nudge_run(timestamptz) to service_role;   -- Edge Function yolu (pg_cron yoksa)
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 11. Zamanlama: pg_cron açıksa her 15 dakikada (:07, :22, :37, :52; saat başı değil). Eklentiyi bu dosya açmaz.
--     Aynı adla yeniden çalıştırmak işi günceller. pg_cron yoksa: Edge Function (service role ile rpc('nudge_run'))
--     + dış zamanlayıcı (ör. GitHub Actions her 15 dakikada; akislar.md 25 "Zamanlama").
--     Motor bayrak kapalıyken anında döner; iş kurulu kalabilir.
-- ---------------------------------------------------------------------
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('nudge-run', '7,22,37,52 * * * *', $c$select public.nudge_run()$c$);
  else
    raise notice 'pg_cron yok: nudge_run zamanlanmadı (Edge Function + dış zamanlayıcı; akislar.md 25)';
  end if;
exception when others then
  raise notice 'nudge_run zamanlanamadı: %', sqlerrm;
end $$;
