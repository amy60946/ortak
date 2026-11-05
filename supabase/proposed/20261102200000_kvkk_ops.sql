-- KVKK işletme + izleme (öneri, 2 Kasım 2026; yönetim paneli ve ortak işler penceresi). Tekrar çalıştırılabilir.
--   1) Saklama ve imha işi (hukuk/42-saklama-imha-politikasi.md §4, §8, §10.1–10.3): gece çalışır (pg_cron),
--      varsayılan KURU ÇALIŞTIRMA (yalnız sayar). Süreler app_config 'retention'da; avukat onaylayınca panelden
--      "live" açılır. Her çalışma kişisel veri içermeyen imha kaydına (retention_runs) yazılır.
--   2) "Verimi indir" (KVKK md. 11; CANLIYA_ALMA.md 1.6): ebeveyn ve uzman kendi verisinin okunabilir dökümünü
--      (JSON) alır; destek rolü KVKK başvurusu için panelden alır (gerekçeli, denetim kaydında).
--   3) Sistem sağlığı (izleme ve alarm): ops_health() yalnız sayı ve durum döner; panel (admin_health) ve
--      Edge Function `health` (dış izleme servisi için) okur.
--   4) Panelden dışa aktarma kaydı (hukuk/42 §10.8): müşteri listesi CSV'si gerekçeyle denetim kaydına yazılır.
-- Sözleşme: sozlesme/admin.md ("KVKK işletme"), sozlesme/veritabani.md, hukuk/46-veri-envanteri.md.

-- ---------------------------------------------------------------------------------------------------------------
-- 1) Saklama ve imha
-- ---------------------------------------------------------------------------------------------------------------

-- Süreler (gün; kod denemesi saat). Öneri değerleri hukuk/42 §4'ten; avukat onayına kadar live = false.
insert into public.app_config (key, value) values ('retention', jsonb_build_object(
  'live', false,
  'trial_history_days', 730,      -- 16 deneme geçmişi: 2 yıl
  'code_attempts_hours', 24,      -- 17 kod deneme kayıtları: 1 gün
  'notifications_days', 365,      -- 19 uygulama içi bildirimler: 12 ay
  'usage_days', 760,              -- 20 kullanım kayıtları: 25 ay, sonra yalnız günlük toplam
  'anon_orphan_days', 30,         -- 21 hiçbir çocuğa bağlı olmayan anonim oyun oturumu: 30 gün girişsiz
  'audit_days', 1825,             -- 22 ekip işlemleri denetim kaydı: 5 yıl
  'kvkk_closed_days', 1095,       -- 24 kapanmış KVKK başvurusu: 3 yıl
  'invite_pii_days', 30,          -- 10 biten davetteki ebeveyn adı/e-postası: 30 gün sonra boşaltılır
  'runs_days', 1095,              -- 27 imha kayıtları: en az 3 yıl (Yönetmelik)
  'support_days', 730             -- 25 kapanan destek talepleri: 2 yıl (spam 30 gün)
)) on conflict (key) do nothing;
-- sonradan eklenen anahtar (önceki sürüm uygulanmışsa): eksikse eklenir, var olana dokunulmaz
update public.app_config set value = jsonb_build_object('support_days', 730) || value
 where key = 'retention' and not value ? 'support_days';

-- İmha kaydı: yalnız sayılar ve adım adları (kişisel veri yok). Yalnız sunucu yazar; panel admin_retention_status ile okur.
create table if not exists public.retention_runs (
  id           bigint generated always as identity primary key,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  trigger      text not null check (trigger in ('cron', 'admin')),
  dry          boolean not null,
  results      jsonb not null default '{}'::jsonb,   -- {"16_trial_history": 3, …}
  errors       jsonb not null default '[]'::jsonb,   -- [{"step", "error"}] (SQLSTATE + kısa ileti)
  ok           boolean
);
alter table public.retention_runs enable row level security;
revoke all on public.retention_runs from anon, authenticated;
create index if not exists retention_runs_started_idx on public.retention_runs (started_at desc);

-- Kullanım kayıtlarının anonim günlük toplamları (satır 20): kişi bazlı satırlar silinmeden önce buraya eklenir.
create table if not exists public.usage_daily_totals (
  day     date not null,
  app     text not null check (app in ('parent', 'child', 'clinic')),
  metric  text not null check (metric ~ '^[a-z][a-z0-9_.:]{1,70}$'),   -- 'active' ya da 'event:<olay>'
  users   integer not null default 0,
  events  integer not null default 0,
  primary key (day, app, metric)
);
alter table public.usage_daily_totals enable row level security;
revoke all on public.usage_daily_totals from anon, authenticated;

-- Denetim kaydı yalnız eklenir; tek istisna: imha işinin, en az 1 yıl eski kesim tarihinden önceki satırları silmesi.
-- Kesim tarihi yalnız işlem (transaction) içinde ayarlanır (retention_run); başka her güncelleme/silme reddedilir.
create or replace function public.admin_audit_immutable() returns trigger language plpgsql as $$
declare
  cutoff timestamptz := nullif(current_setting('ortak.audit_purge_before', true), '')::timestamptz;
begin
  if tg_op = 'DELETE' and cutoff is not null and cutoff <= now() - interval '365 days' and old.at < cutoff then
    return old;
  end if;
  raise exception 'Denetim kaydı değiştirilemez' using errcode = '42501';
end $$;
revoke execute on function public.admin_audit_immutable() from public, anon, authenticated;

-- Ayardan gün sayısı: sayı değilse varsayılan; [en az, 7300] aralığına çekilir.
create or replace function public.retention_cfg_int(p_cfg jsonb, p_key text, p_default integer, p_min integer)
returns integer language sql immutable set search_path = '' as $$
  select greatest(p_min, least(7300, case when jsonb_typeof(p_cfg -> p_key) = 'number'
                                          then (p_cfg ->> p_key)::numeric::integer else p_default end))
$$;
revoke execute on function public.retention_cfg_int(jsonb, text, integer, integer) from public, anon, authenticated;

-- Basit adım: kuru çalıştırmada sayar, gerçekte siler. Tablo ve koşul sabit metinlerdir (kullanıcı girdisi yok).
create or replace function public.retention_step(p_dry boolean, p_table text, p_where text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare n bigint;
begin
  if p_dry then
    execute format('select count(*) from %s where %s', p_table, p_where) into n;
  else
    execute format('delete from %s where %s', p_table, p_where);
    get diagnostics n = row_count;
  end if;
  return n;
end $$;
revoke execute on function public.retention_step(boolean, text, text) from public, anon, authenticated;

-- İmha işi. p_dry null → ayardaki live'a göre (live değilse kuru). Her adım ayrı; biri hata verirse diğerleri sürer.
create or replace function public.retention_run(p_trigger text default 'cron', p_dry boolean default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := coalesce((select value from public.app_config where key = 'retention'), '{}'::jsonb);
  dry boolean := coalesce(p_dry, not coalesce((cfg ->> 'live')::boolean, false));
  run_id bigint;
  res jsonb := '{}'::jsonb;
  errs jsonb := '[]'::jsonb;
  n bigint;
  m bigint;
  d integer;
  cut date;
  step text;
begin
  if p_trigger not in ('cron', 'admin') then raise exception 'Geçersiz tetikleyici'; end if;
  insert into public.retention_runs (trigger, dry) values (p_trigger, dry) returning id into run_id;

  -- 10 biten davetlerde ebeveyn adı ve e-postası (çocuk alanlarını clinic_invites_expire zaten boşaltır)
  step := '10_invite_parent_fields';
  begin
    d := public.retention_cfg_int(cfg, 'invite_pii_days', 30, 3);
    if dry then
      select count(*) into n from public.clinic_invites
       where (parent_name <> '' or parent_email is not null)
         and coalesce(used_at, revoked_at, declined_at, case when claimed_at is null then expires_at end) < now() - make_interval(days => d);
    else
      update public.clinic_invites set parent_name = '', parent_email = null
       where (parent_name <> '' or parent_email is not null)
         and coalesce(used_at, revoked_at, declined_at, case when claimed_at is null then expires_at end) < now() - make_interval(days => d);
      get diagnostics n = row_count;
    end if;
    res := res || jsonb_build_object(step, n);
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 16 deneme geçmişi (e-posta özeti)
  step := '16_trial_history';
  begin
    d := public.retention_cfg_int(cfg, 'trial_history_days', 730, 30);
    res := res || jsonb_build_object(step, public.retention_step(dry, 'public.trial_history',
             format('started_at < now() - interval %L', d || ' days')));
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 17 kod deneme kayıtları
  step := '17_code_attempts';
  begin
    d := least(48, public.retention_cfg_int(cfg, 'code_attempts_hours', 24, 1));
    res := res || jsonb_build_object(step, public.retention_step(dry, 'public.code_attempts',
             format('at < now() - interval %L', d || ' hours')));
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 19 uygulama içi bildirimler
  step := '19_notifications';
  begin
    d := public.retention_cfg_int(cfg, 'notifications_days', 365, 30);
    res := res || jsonb_build_object(step, public.retention_step(dry, 'public.notifications',
             format('created_at < now() - interval %L', d || ' days')));
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 20 kullanım kayıtları: kesimden eski günler önce günlük toplamlara eklenir, sonra kişi bazlı satırlar silinir
  step := '20_usage';
  begin
    d := public.retention_cfg_int(cfg, 'usage_days', 760, 400);
    cut := (now() at time zone 'Europe/Istanbul')::date - d;
    if dry then
      select (select count(*) from public.activity_days where day < cut)
           + (select count(*) from public.app_events where (occurred_at at time zone 'Europe/Istanbul')::date < cut) into n;
    else
      insert into public.usage_daily_totals (day, app, metric, users, events)
      select day, app, 'active', count(*), 0 from public.activity_days where day < cut group by day, app
      on conflict (day, app, metric) do update set users = public.usage_daily_totals.users + excluded.users;
      insert into public.usage_daily_totals (day, app, metric, users, events)
      select (occurred_at at time zone 'Europe/Istanbul')::date, app, 'event:' || event, count(distinct user_id), count(*)
        from public.app_events where (occurred_at at time zone 'Europe/Istanbul')::date < cut group by 1, 2, 3
      on conflict (day, app, metric) do update set users = public.usage_daily_totals.users + excluded.users,
                                                   events = public.usage_daily_totals.events + excluded.events;
      delete from public.activity_days where day < cut;
      get diagnostics n = row_count;
      delete from public.app_events where (occurred_at at time zone 'Europe/Istanbul')::date < cut;
      get diagnostics m = row_count;
      n := n + m;
    end if;
    res := res || jsonb_build_object(step, n);
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 21 hiçbir çocuğa bağlı olmayan, uzun süredir girişsiz anonim oyun oturumları (bağlı tablolar zincirleme silinir)
  step := '21_anon_orphans';
  begin
    d := public.retention_cfg_int(cfg, 'anon_orphan_days', 30, 7);
    res := res || jsonb_build_object(step, public.retention_step(dry, 'auth.users u',
             format('u.is_anonymous and coalesce(u.last_sign_in_at, u.created_at) < now() - interval %L
                     and not exists (select 1 from public.children c where c.user_id = u.id)
                     and not exists (select 1 from public.admin_users a where a.user_id = u.id)', d || ' days')));
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 22 denetim kaydı (tetikleyici yalnız bu kesimden eskiyi ve yalnız bu işlem içinde siler)
  step := '22_admin_audit';
  begin
    d := public.retention_cfg_int(cfg, 'audit_days', 1825, 365);
    perform set_config('ortak.audit_purge_before', (now() - make_interval(days => d))::text, true);
    res := res || jsonb_build_object(step, public.retention_step(dry, 'public.admin_audit',
             format('at < now() - interval %L', d || ' days')));
    perform set_config('ortak.audit_purge_before', '', true);
  exception when others then
    perform set_config('ortak.audit_purge_before', '', true);
    errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 24 kapanmış KVKK başvuruları
  step := '24_kvkk_requests';
  begin
    d := public.retention_cfg_int(cfg, 'kvkk_closed_days', 1095, 365);
    res := res || jsonb_build_object(step, public.retention_step(dry, 'public.kvkk_requests',
             format('status in (''answered'', ''rejected'') and coalesce(answered_at, updated_at) < now() - interval %L', d || ' days')));
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- 25 destek talepleri (20261102210000_support.sql uygulanmışsa): kapanan/yanıtlanan süre sonunda, spam 30 günde
  if to_regclass('public.support_requests') is not null then
    step := '25_support_requests';
    begin
      d := public.retention_cfg_int(cfg, 'support_days', 730, 30);
      res := res || jsonb_build_object(step, public.retention_step(dry, 'public.support_requests',
               format('(status in (''answered'', ''closed'') and updated_at < now() - interval %L)
                       or (status = ''spam'' and updated_at < now() - interval ''30 days'')', d || ' days')));
    exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
    end;
  end if;

  -- 27 imha kayıtları (en az 3 yıl; bu çalışmanın satırı hiç silinmez)
  step := '27_retention_runs';
  begin
    d := public.retention_cfg_int(cfg, 'runs_days', 1095, 1095);
    res := res || jsonb_build_object(step, public.retention_step(dry, 'public.retention_runs',
             format('started_at < now() - interval %L and id <> %s', d || ' days', run_id)));
  exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
  end;

  -- zamanlayıcının kendi çalışma geçmişi (cron.job_run_details kendiliğinden temizlenmez; Supabase önerisi: 7 gün).
  -- Yalnız iş adı/zaman/durum tutar; imha kaydı ayrı (retention_runs). pg_cron yoksa adım atlanır.
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    step := 'cron_history';
    begin
      res := res || jsonb_build_object(step, public.retention_step(dry, 'cron.job_run_details', 'end_time < now() - interval ''7 days'''));
    exception when others then errs := errs || jsonb_build_array(jsonb_build_object('step', step, 'error', sqlstate || ' ' || left(sqlerrm, 200)));
    end;
  end if;

  update public.retention_runs set finished_at = now(), results = res, errors = errs, ok = jsonb_array_length(errs) = 0
   where id = run_id;
  return jsonb_build_object('id', run_id, 'dry', dry, 'results', res, 'errors', errs);
end $$;
revoke execute on function public.retention_run(text, boolean) from public, anon, authenticated;
grant execute on function public.retention_run(text, boolean) to service_role;

-- Gece 03.17 (Türkiye; cron UTC; saat başı değil: Supabase/Mastodon önerisi). Aynı adla yeniden çalıştırmak günceller.
do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('retention-nightly', '17 0 * * *', $c$select public.retention_run('cron')$c$);
exception when others then
  raise notice 'pg_cron yok: imha işi panelden (kuru) ya da SQL Editor''den çalıştırılır';
end $$;

-- Panel: ayar + son çalışmalar (okur)
create or replace function public.admin_retention_status(p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return jsonb_build_object(
    'config', coalesce((select value from public.app_config where key = 'retention'), '{}'::jsonb),
    'cron', exists (select 1 from pg_namespace where nspname = 'cron'),
    'runs', coalesce((select jsonb_agg(to_jsonb(r) order by r.started_at desc)
                        from (select * from public.retention_runs order by started_at desc
                               limit greatest(1, least(coalesce(p_limit, 30), 200))) r), '[]'::jsonb));
end $$;
revoke execute on function public.admin_retention_status(integer) from public, anon;
grant execute on function public.admin_retention_status(integer) to authenticated;

-- Panel: şimdi kuru çalıştır (yalnız sayar; owner). Gerçek silme yalnız gece işinde ve live açıkken.
create or replace function public.admin_retention_dry_run(p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['owner']); out jsonb;
begin
  out := public.retention_run('admin', true);
  perform public.admin_log(me, 'retention.dry_run', 'system', 'retention', p_reason, null, out -> 'results');
  return out;
end $$;
revoke execute on function public.admin_retention_dry_run(text) from public, anon;
grant execute on function public.admin_retention_dry_run(text) to authenticated;

-- Panel: süreler ve live (owner). Bilinmeyen anahtar ve alt sınırın altı reddedilir.
create or replace function public.admin_set_retention_config(p_value jsonb, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  old jsonb := coalesce((select value from public.app_config where key = 'retention'), '{}'::jsonb);
  mins constant jsonb := '{"trial_history_days":30,"code_attempts_hours":1,"notifications_days":30,"usage_days":400,
                           "anon_orphan_days":7,"audit_days":365,"kvkk_closed_days":365,"invite_pii_days":3,"runs_days":1095,
                           "support_days":30}';
  k text; v jsonb; nv jsonb;
begin
  if p_value is null or jsonb_typeof(p_value) <> 'object' then raise exception 'Ayar bir nesne olmalı'; end if;
  for k, v in select * from jsonb_each(p_value) loop
    if k = 'live' then
      if jsonb_typeof(v) <> 'boolean' then raise exception 'live doğru/yanlış olmalı'; end if;
    elsif mins ? k then
      if jsonb_typeof(v) <> 'number' or v::text !~ '^\d+$' then raise exception '% tam sayı olmalı', k; end if;
      if (v::text)::integer < (mins ->> k)::integer or (v::text)::integer > (case when k = 'code_attempts_hours' then 48 else 7300 end) then
        raise exception '% izinli aralıkta değil (en az %)', k, mins ->> k;
      end if;
    else
      raise exception 'Bilinmeyen ayar: %', k;
    end if;
  end loop;
  nv := old || p_value;
  insert into public.app_config (key, value, updated_at) values ('retention', nv, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
  perform public.admin_log(me, 'config.retention', 'config', 'retention', p_reason, old, nv);
  return nv;
end $$;
revoke execute on function public.admin_set_retention_config(jsonb, text) from public, anon;
grant execute on function public.admin_set_retention_config(jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 2) Verimi indir
-- ---------------------------------------------------------------------------------------------------------------
-- Kişinin kendi verisi + velisi olduğu çocukların verisi. Diğer ebeveynin yazdıkları (mesaj, davranış kaydı,
-- ev programı notu, onay/ret notu, taş düşürme nedeni) ayıklanır, yalnız sayısı yazılır. Uzmanın danışan kayıtları
-- kliniğin kaydıdır, buraya girmez (uzman sözleşmesi 14.5). Dosyalar (fotoğraf, ses) yol olarak listelenir; uygulama
-- kısa süreli bağlantı üretir. Kimlik doğrulama sağlayıcısındaki şifre özeti ve bildirim jetonu verilmez.
create or replace function public.data_export_of(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  u record;
  fam uuid;
  kids uuid[];
  cl record;
  out jsonb;
begin
  select id, email, created_at, last_sign_in_at, email_confirmed_at, is_anonymous into u from auth.users where id = p_user;
  if not found or u.is_anonymous then raise exception 'Hesap bulunamadı'; end if;

  out := jsonb_build_object(
    'bicim', 'veri-disa-aktarma-v1',
    'olusturulma', now(),
    'aciklama', 'Hesabına ve velisi olduğun çocuklara ait kayıtların dökümüdür. Diğer ebeveynin yazdıkları ayıklanmış, '
             || 'yalnız sayıları yazılmıştır. Fotoğraf ve ses dosyaları "dosyalar" listesindedir. Sorular için KVKK başvuru '
             || 'yolunu kullanabilirsin.',
    'hesap', jsonb_build_object('id', u.id, 'eposta', u.email, 'kayit', u.created_at,
                                'eposta_dogrulama', u.email_confirmed_at, 'son_giris', u.last_sign_in_at));

  -- Ebeveyn: profil, aile, çocuklar ve aile kayıtları
  select family_id into fam from public.profiles where id = p_user;
  if fam is not null then
    select coalesce(array_agg(id), '{}') into kids from public.children where family_id = fam;
    out := out || jsonb_build_object(
      'profil', (select to_jsonb(p) - 'family_id' from public.profiles p where p.id = p_user),
      'aile', (select jsonb_build_object('id', f.id, 'ad', f.name, 'olusturulma', f.created_at, 'deneme_baslangici', f.trial_started_at,
                                         'diger_ebeveyn_sayisi', (select count(*) from public.profiles x where x.family_id = fam and x.id <> p_user))
                 from public.families f where f.id = fam),
      'abonelik', (select to_jsonb(s) - 'family_id' - 'store_transaction_id' from public.family_subscriptions s where s.family_id = fam),
      'cocuklar', coalesce((select jsonb_agg(to_jsonb(c) - 'family_id' - 'user_id' || jsonb_build_object('oyun_cihazi_bagli', c.user_id is not null)
                                             order by c.created_at) from public.children c where c.family_id = fam), '[]'),
      'gorevler', coalesce((select jsonb_agg(to_jsonb(t) - 'family_id'
                                             || jsonb_build_object('atamalar', coalesce((select jsonb_agg(to_jsonb(a) - 'family_id' - 'task_id')
                                                                                          from public.task_assignments a where a.task_id = t.id), '[]'))
                                             order by t.created_at) from public.tasks t where t.family_id = fam), '[]'),
      'tamamlamalar', coalesce((select jsonb_agg(case when c.reviewed_by is not null and c.reviewed_by <> p_user
                                                      then to_jsonb(c) - 'family_id' - 'parent_note' - 'decline_reason'
                                                      else to_jsonb(c) - 'family_id' end order by c.date, c.created_at)
                                  from public.completions c where c.family_id = fam), '[]'),
      'oduller', coalesce((select jsonb_agg(to_jsonb(r) - 'family_id' order by r.created_at) from public.rewards r where r.family_id = fam), '[]'),
      'odul_istekleri', coalesce((select jsonb_agg(to_jsonb(r) - 'family_id' order by r.created_at) from public.reward_requests r where r.family_id = fam), '[]'),
      'coin_defteri', coalesce((select jsonb_agg(to_jsonb(l) - 'family_id' order by l.created_at) from public.coin_ledger l where l.family_id = fam), '[]'),
      'gunes_tasi_defteri', coalesce((select jsonb_agg(case when l.created_by is not null and l.created_by <> p_user
                                                            then to_jsonb(l) - 'family_id' - 'note' else to_jsonb(l) - 'family_id' end
                                                       order by l.created_at) from public.sun_stone_ledger l where l.family_id = fam), '[]'),
      'haftalik_hedefler', coalesce((select jsonb_agg(to_jsonb(w) - 'family_id' order by w.week_start) from public.weekly_goal_claims w where w.family_id = fam), '[]'),
      'oyun_kayitlari', coalesce((select jsonb_agg(jsonb_build_object('child_id', g.child_id, 'guncelleme', g.updated_at, 'veri', g.data))
                                    from public.game_saves g where g.family_id = fam), '[]'),
      'mesajlar', coalesce((select jsonb_agg(to_jsonb(m) - 'family_id' order by m.created_at) from public.messages m
                             where m.family_id = fam and (m.sender = 'child' or m.sender_id = p_user)), '[]'),
      'davranis_kayitlari', coalesce((select jsonb_agg(to_jsonb(e) - 'family_id' order by e.occurred_at) from public.abc_events e
                                       where e.family_id = fam and (e.created_by is null or e.created_by = p_user)), '[]'),
      'ev_programi_kayitlari', coalesce((select jsonb_agg(to_jsonb(l) - 'family_id' order by l.day) from public.care_module_logs l
                                          where l.family_id = fam and (l.created_by is null or l.created_by = p_user)), '[]'),
      'uzman_paylasimlari', coalesce((select jsonb_agg(jsonb_build_object('child_id', k.child_id, 'klinik', cl2.name, 'durum', k.status,
                                                                         'riza_surumu', k.consent_version, 'riza_zamani', k.consent_at,
                                                                         'geri_alinma', k.revoked_at, 'olusturulma', k.created_at) order by k.created_at)
                                         from public.clinic_links k left join public.clinics cl2 on cl2.id = k.clinic_id
                                        where k.family_id = fam), '[]'),
      'ayiklanan', jsonb_build_object(
        'diger_ebeveynin_mesajlari', (select count(*) from public.messages m where m.family_id = fam and m.sender <> 'child' and m.sender_id is distinct from p_user),
        'diger_ebeveynin_davranis_kayitlari', (select count(*) from public.abc_events e where e.family_id = fam and e.created_by is not null and e.created_by <> p_user),
        'diger_ebeveynin_ev_programi_kayitlari', (select count(*) from public.care_module_logs l where l.family_id = fam and l.created_by is not null and l.created_by <> p_user)),
      'dosyalar', coalesce((select jsonb_agg(x order by x ->> 'yol') from (
          select jsonb_build_object('kova', 'mail', 'yol', m.media_path, 'tur', m.kind, 'kaynak', 'mesaj') x
            from public.messages m where m.family_id = fam and m.media_path is not null and (m.sender = 'child' or m.sender_id = p_user)
          union all
          select jsonb_build_object('kova', 'abc', 'yol', e.audio_path, 'tur', 'audio', 'kaynak', 'davranis_kaydi')
            from public.abc_events e where e.family_id = fam and e.audio_path is not null and (e.created_by is null or e.created_by = p_user)) s), '[]'));
  end if;

  -- Uzman: kendi hesabı, kliniği, belge incelemesi, anket (danışan kayıtları kliniğin kaydıdır, ayrı dışa aktarılır)
  select c.*, k.name as clinic_name, k.plan as clinic_plan, k.created_by as clinic_owner into cl
    from public.clinicians c left join public.clinics k on k.id = c.clinic_id where c.id = p_user;
  if found then
    out := out || jsonb_build_object(
      'uzman', jsonb_build_object('ad', cl.name, 'unvan', cl.title, 'rol', cl.role, 'kayit', cl.created_at,
                                  'dogrulanan_meslek', cl.verified_profession, 'dogrulama', cl.verified_at,
                                  'klinik', jsonb_build_object('id', cl.clinic_id, 'ad', cl.clinic_name, 'plan', cl.clinic_plan,
                                                               'sahibi_benim', cl.clinic_owner = p_user)),
      'klinik_uyeligi', case when cl.clinic_owner = p_user then
                          coalesce((select jsonb_agg(jsonb_build_object('plan', b.plan_id, 'durum', b.status, 'bitis', b.period_end,
                                                                        'kaynak', b.source, 'olusturulma', b.created_at) order by b.created_at)
                                      from public.billing_subscriptions b where b.clinic_id = cl.clinic_id), '[]') end,
      'belge_incelemeleri', coalesce((select jsonb_agg(to_jsonb(v) - 'clinician_id' - 'file_path' - 'decided_by' order by v.created_at)
                                        from public.clinician_verifications v where v.clinician_id = p_user), '[]'),
      'karsilama_anketi', (select to_jsonb(s) - 'clinician_id' from public.clinician_surveys s where s.clinician_id = p_user),
      'danisan_kayitlari_notu', 'Danışanlarla ilgili notlar, hedefler ve takip planı kliniğin kaydıdır; ClinicApp''ten ya da destek talebiyle ayrıca dışa aktarılır.');
  end if;

  -- Herkes: bildirimler, yasal onaylar, KVKK başvuruları, kullanım özeti, cihazlar, ekip işlemleri
  out := out || jsonb_build_object(
    'bildirimler', coalesce((select jsonb_agg(jsonb_build_object('uygulama', n.app, 'tur', n.kind, 'baslik', n.title, 'metin', n.body,
                                                                 'zaman', n.created_at, 'okunma', n.read_at) order by n.created_at)
                               from public.notifications n where n.user_id = p_user), '[]'),
    'yasal_onaylar', coalesce((select jsonb_agg(jsonb_build_object('metin', a.doc_key, 'surum', a.version, 'uygulama', a.app, 'zaman', a.accepted_at)
                                                order by a.accepted_at) from public.legal_acceptances a where a.user_id = p_user), '[]'),
    'kvkk_basvurulari', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'tur', r.kind, 'kanal', r.channel, 'ayrinti', r.detail,
                                                                      'durum', r.status, 'alinis', r.received_at, 'son_gun', r.due_at,
                                                                      'yanit', r.answered_at) order by r.received_at)
                                    from public.kvkk_requests r where r.user_id = p_user), '[]'),
    'kullanim', jsonb_build_object(
      'uygulamalar', coalesce((select jsonb_agg(to_jsonb(a) - 'user_id') from public.user_activity a where a.user_id = p_user), '[]'),
      'olaylar', coalesce((select jsonb_agg(jsonb_build_object('uygulama', e.app, 'olay', e.event, 'sayi', e.n, 'ilk', e.first_at, 'son', e.last_at)
                                            order by e.app, e.event)
                             from (select app, event, count(*) n, min(occurred_at) first_at, max(occurred_at) last_at
                                     from public.app_events where user_id = p_user group by app, event) e), '[]'),
      'aciklama', 'Uygulama açma günleri ve ekran/özellik olay adları; içerik yok. Satır satır döküm KVKK başvurusuyla istenebilir.'),
    'cihazlar', coalesce((select jsonb_agg(jsonb_build_object('uygulama', t.app, 'platform', t.platform, 'guncelleme', t.updated_at))
                            from public.push_tokens t where t.user_id = p_user), '[]'),
    'ozel_ayarlar', coalesce((select jsonb_agg(jsonb_build_object('anahtar', f.key, 'acik', f.enabled, 'bitis', f.expires_at))
                                from public.user_flags f where f.user_id = p_user), '[]'),
    'ekip_islemleri', coalesce((select jsonb_agg(jsonb_build_object('islem', a.action, 'zaman', a.at) order by a.at)
                                  from public.admin_audit a where a.target_type = 'user' and a.target_id = p_user::text), '[]'));
  return out;
end $$;
revoke execute on function public.data_export_of(uuid) from public, anon, authenticated;

-- Uygulamadan "Verimi indir": günde en çok 5 kez (her indirme kullanım kaydına yazılır)
create or replace function public.my_data_export()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  app text;
begin
  if me is null or coalesce((select is_anonymous from auth.users where id = me), true) then
    raise exception 'Giriş gerekli' using errcode = '42501';
  end if;
  if (select count(*) from public.app_events where user_id = me and event = 'kvkk.data_export'
        and occurred_at > now() - interval '1 day') >= 5 then
    raise exception 'Bugün en çok 5 kez indirebilirsin; yarın yeniden dene';
  end if;
  app := case when exists (select 1 from public.clinicians where id = me) then 'clinic' else 'parent' end;
  insert into public.app_events (user_id, app, event) values (me, app, 'kvkk.data_export');
  return public.data_export_of(me);
end $$;
revoke execute on function public.my_data_export() from public, anon;
grant execute on function public.my_data_export() to authenticated;

-- Panel: KVKK erişim başvurusu için dışa aktarma (destek; gerekçeli, denetim kaydında)
create or replace function public.admin_user_export(p_user uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['support']); out jsonb;
begin
  out := public.data_export_of(p_user);
  perform public.admin_log(me, 'user.data_export', 'user', p_user::text, p_reason);
  return out;
end $$;
revoke execute on function public.admin_user_export(uuid, text) from public, anon;
grant execute on function public.admin_user_export(uuid, text) to authenticated;

-- Panelden yapılan toplu dışa aktarmaların kaydı (müşteri listesi CSV'si; hukuk/42 §10.8)
create or replace function public.admin_log_export(p_what text, p_rows integer, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require();
begin
  if p_what is null or p_what !~ '^[a-z][a-z0-9_.:]{1,60}$' then raise exception 'Geçersiz dışa aktarma'; end if;
  perform public.admin_log(me, 'export.csv', 'system', p_what, p_reason, null,
                           jsonb_build_object('rows', greatest(0, coalesce(p_rows, 0))));
end $$;
revoke execute on function public.admin_log_export(text, integer, text) from public, anon;
grant execute on function public.admin_log_export(text, integer, text) to authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 3) Sistem sağlığı
-- ---------------------------------------------------------------------------------------------------------------
-- Düzey: ok · info · warn (bakılmalı) · fail (hemen bakılmalı). Kişisel veri yok; yalnız sayı ve zaman.
create or replace function public.ops_health()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  checks jsonb := '[]'::jsonb;
  r record;
  n bigint;
  m bigint;
  k bigint;
  t timestamptz;
  cfg jsonb := coalesce((select value from public.app_config where key = 'retention'), '{}'::jsonb);
  worst text := 'ok';
  lvl text;
begin
  -- zamanlayıcı (pg_cron): son çalışması hata veren iş
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    begin
      execute $q$select count(*) filter (where d.status = 'failed'), count(*) from cron.job j
                   left join lateral (select status from cron.job_run_details x where x.jobid = j.jobid
                                       order by x.start_time desc limit 1) d on true$q$ into n, m;
      checks := checks || jsonb_build_array(jsonb_build_object('key', 'cron', 'level', case when n > 0 then 'fail' else 'ok' end,
        'label', 'Zamanlayıcı', 'detail', case when n > 0 then n || ' işin son çalışması hata verdi' else m || ' iş tanımlı' end));
    exception when others then
      checks := checks || jsonb_build_array(jsonb_build_object('key', 'cron', 'level', 'warn', 'label', 'Zamanlayıcı',
        'detail', 'İş listesi okunamadı'));
    end;
  else
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'cron', 'level', 'warn', 'label', 'Zamanlayıcı',
      'detail', 'pg_cron açık değil: gece imha işi ve davet süresi bildirimi kendiliğinden çalışmaz'));
  end if;

  -- imha işi: son gece çalışması
  select * into r from public.retention_runs where trigger = 'cron' order by started_at desc limit 1;
  if not found then
    lvl := 'warn';
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'retention', 'level', lvl, 'label', 'İmha işi',
      'detail', 'Gece işi henüz hiç çalışmadı'));
  else
    lvl := case when r.ok is false then 'fail'
                when r.finished_at is null and r.started_at < now() - interval '1 hour' then 'fail'
                when r.started_at < now() - interval '26 hours' then 'warn' else 'ok' end;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'retention', 'level', lvl, 'label', 'İmha işi',
      'detail', case when r.ok is false then 'Son çalışmada hata: ' || jsonb_array_length(r.errors) || ' adım'
                     when lvl = 'warn' then 'Son 26 saatte çalışmadı'
                     else 'Son çalışma ' || to_char(r.started_at at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') end
                || case when coalesce((cfg ->> 'live')::boolean, false) then '' else ' · kuru çalıştırma (yalnız sayıyor)' end,
      'at', r.started_at));
  end if;

  -- KVKK başvuruları: 30 günlük yasal süre
  select count(*) filter (where due_at < now()), count(*) filter (where due_at < now() + interval '7 days'), count(*)
    into n, m, k from public.kvkk_requests where status in ('received', 'in_progress');
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'kvkk', 'label', 'KVKK başvuruları',
    'level', case when n > 0 then 'fail' when m > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' başvurunun yasal süresi geçti'
                   when m > 0 then m || ' başvurunun süresi 7 gün içinde doluyor'
                   else k || ' açık başvuru' end));

  -- uzman belgeleri: 3 günden uzun bekleyen
  select count(*) into n from public.clinician_verifications
   where status = 'pending' and coalesce(submitted_at, created_at) < now() - interval '3 days';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'verifications', 'label', 'Uzman belgeleri',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' belge 3 günden uzun süredir bekliyor' else 'Bekleyen eski belge yok' end));

  -- klinik denemeleri: 3 gün içinde biten (üyelik ödemesi canlı değilse panelden uzatılır)
  select count(*) into n from public.clinics where plan = 'trial' and trial_ends_at between now() and now() + interval '3 days';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'clinic_trials', 'label', 'Klinik denemeleri',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' kliniğin denemesi 3 gün içinde bitiyor' else '3 gün içinde biten deneme yok' end));

  -- abonelik olayları (billing-webhook): son olay; ödeme açıkken 14 gün sessizlik uyarı
  select greatest((select max(created_at) from public.billing_events where source = 'revenuecat'),
                  (select max(updated_at) from public.family_subscriptions where source = 'revenuecat')) into t;
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'billing', 'label', 'Abonelik bildirimleri',
    'level', case when coalesce((select (value ->> 'enforce')::boolean from public.app_config where key = 'billing'), false)
                       and (t is null or t < now() - interval '14 days') then 'warn'
                  when t is null then 'info' else 'ok' end,
    'detail', case when t is null then 'Henüz RevenueCat olayı gelmedi'
                   else 'Son olay ' || to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI') end,
    'at', t));

  -- anlık bildirim: Apple anahtarı olan kullanıcıya 10 dakikadır gönderilmemiş bildirim (son 24 saat)
  select count(*) into n from public.notifications x
   where x.created_at between now() - interval '24 hours' and now() - interval '10 minutes' and x.apns_sent_at is null
     and exists (select 1 from public.push_tokens p where p.user_id = x.user_id and p.app = x.app and p.token not like 'ExponentPushToken%');
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'push', 'label', 'Anlık bildirim',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' bildirim Apple''a gönderilmemiş (push-apns / PUSH_SECRET)' else 'Bekleyen gönderim yok' end));

  -- sunucu işlevi çağrıları (pg_net): son 6 saatte hata
  if exists (select 1 from pg_namespace where nspname = 'net') then
    begin
      execute $q$select count(*) filter (where status_code >= 500 or error_msg is not null), count(*) from net._http_response$q$ into n, m;
      checks := checks || jsonb_build_array(jsonb_build_object('key', 'net', 'label', 'Sunucu işlevi çağrıları',
        'level', case when n > 0 then 'warn' else 'ok' end,
        'detail', case when n > 0 then n || ' / ' || m || ' çağrı hata verdi (son 6 saat)' else m || ' çağrı, hata yok (son 6 saat)' end));
    exception when others then null;
    end;
  end if;

  -- destek talepleri (20261102210000_support.sql uygulanmışsa): 2 günden uzun yanıtsız
  if to_regclass('public.support_requests') is not null then
    execute $q$select count(*) filter (where status = 'new' and created_at < now() - interval '2 days'),
                      count(*) filter (where status in ('new', 'in_progress'))
                 from public.support_requests$q$ into n, m;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'support', 'label', 'Destek talepleri',
      'level', case when n > 0 then 'warn' else 'ok' end,
      'detail', case when n > 0 then n || ' talep 2 günden uzun süredir yanıtsız' else m || ' açık talep' end));
  end if;

  -- davet ödülü kodları (20261103200000_referral_codes.sql uygulanmışsa): kod bekleyen ödül, havuz azaldı, süre yaklaşıyor
  if to_regclass('public.offer_code_pool') is not null then
    execute $q$select (select count(*) from public.referral_rewards where status = 'code_pending'),
                      (select count(*) from public.offer_code_pool where assigned_at is null and billing = 'monthly'
                          and expires_at > now() + interval '14 days'),
                      (select count(*) from public.offer_code_pool),
                      (select min(expires_at) from public.offer_code_pool where assigned_at is null and expires_at > now() + interval '14 days')
               $q$ into n, m, k, t;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'referral', 'label', 'Davet ödülü kodları',
      'level', case when n > 0 or (k > 0 and m < 5) then 'warn' when k = 0 or t < now() + interval '30 days' then 'info' else 'ok' end,
      'detail', case when n > 0 then n || ' ödül kod bekliyor: kod dosyası yükle'
                     when k = 0 then 'Kod havuzu boş: App Store Connect''ten kod üretip yükle'
                     when m < 5 then 'Aylık ürün için ' || m || ' kod kaldı'
                     when t < now() + interval '30 days' then 'Kodların bir kısmının süresi ' || to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY') || ' bitiyor'
                     else m || ' aylık kod hazır' end));
  end if;

  -- silinmeyi bekleyen dosyalar
  select count(*) into n from public.storage_trash where created_at < now() - interval '2 days';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'storage_trash', 'label', 'Silinecek dosyalar',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' dosya 2 günden uzun süredir silinmeyi bekliyor' else 'Bekleyen yok' end));

  -- yayındaki yasal metin
  select count(*) into n from public.legal_documents where status = 'published';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'legal', 'label', 'Yasal metinler',
    'level', case when n = 0 then 'warn' else 'ok' end, 'detail', n || ' metin yayında'));

  select case when bool_or(c ->> 'level' = 'fail') then 'fail' when bool_or(c ->> 'level' = 'warn') then 'warn' else 'ok' end
    into worst from jsonb_array_elements(checks) c;
  return jsonb_build_object('status', worst, 'checked_at', now(), 'checks', checks);
end $$;
revoke execute on function public.ops_health() from public, anon, authenticated;
grant execute on function public.ops_health() to service_role;

create or replace function public.admin_health()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return public.ops_health();
end $$;
revoke execute on function public.admin_health() from public, anon;
grant execute on function public.admin_health() to authenticated;
