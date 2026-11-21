-- Güvenlik denetimi düzeltmeleri (21 Kasım 2026; bağımsız doğrulanmış bulgular, koordinatör penceresi). ÖNERİ: uygulanmadı.
-- Test: supabase/test/test_security_audit_fixes.sql. Tekrar çalıştırılabilir (create or replace, drop … if exists).
-- Bu dosya 20261120200000_family_keeps_records, …210000, …220000, …230000, …231000 önerilerinden SONRA çalışır.
--
--  1. Paylaşım bitince (clinic_links.status <> 'active') eski uzman o bağın planını, hedeflerini, önerilerini okuyamaz,
--     yazamaz, silemez; öneri kararı bildirimi almaz (clinic_link_open). Ailenin uygulama kaydı olan program uzmanın silmesiyle
--     zincirleme yok olmaz (care_modules_keep_family_logs). Seans takvimi (clinic_sessions) uzmanın kendi randevu geçmişi olarak kalır.
--  2. 'mail' kovası: ebeveyn aile önekinin tamamını, çocuk cihazı yalnız kendi mesajının dosyasını ve kendi fotoğrafını okur;
--     yalnız ebeveyn yükler (oyun dosya yüklemez, çocuk mesajı dosya taşıyamaz).
--  3. İstemcinin doğrudan yazabildiği zaman alanları sonlu ve makul aralıkta (client_time_guard); KPI medyanı sonsuz değere dayanıklı.
--  4. Ücretsiz plan adım sınırı güncellemede de (biten adım yeniden etkin olunca) uygulanır.
--  5. Klinik üyeliği bitince o kliniğin takvim beslemesi, dış takvimleri ve etkinlikleri silinir; besleme ve dönüştürme güncel üyeliğe bakar.
--  6. KVKK başvurusu yalnız anonim olmayan hesaptan (ebeveyn / uzman); sistem genelinde saatlik üst sınır.
--  7. Deneme tekrarını engelleyen e-posta özeti Gmail nokta ve googlemail.com biçimlerini aynı adres sayar.
--  8. redeem_guest_pass deneme sayaçlarını silmez; anon rolünün public tablolardaki yetkileri kalkar; clinic_notes_goal_check search_path ''.
--  9. Bildirim seli: aynı gönderen → aynı alıcı → aynı tür için kayan 1 saatte en çok 6 anlık bildirim; aynı kayıt için 10 dakikada
--     yinelenen bildirim push'suz. Kayıt ve uygulama içi bildirim yazılmaya devam eder.

-- Sıra denetimi: önkoşul dosyalar çalışmadıysa hiçbir şey yazmadan anlaşılır bir hatayla durur.
do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'parent_trainings'
                   and column_name = 'detached_at') then
    raise exception 'Önce 20261120200000_family_keeps_records.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
  if to_regclass('public.parent_notification_prefs') is null then
    raise exception 'Önce 20261120210000_parent_notification_prefs.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
  if to_regclass('public.store_funnel_daily') is null then
    raise exception 'Önce 20261120220000_funnel_analytics.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
  if to_regclass('public.nudge_log') is null then
    raise exception 'Önce 20261120230000_nudge_engine.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
  if to_regprocedure('public.nudge_log_prune()') is null then
    raise exception 'Önce 20261120231000_nudge_kvkk.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
end $$;

-- =====================================================================
-- 1. Paylaşım bitince eski uzmanın erişimi
-- =====================================================================
-- clinic_link_visible bağın durumuna bakmaz (seans geçmişi, uzmanın kendi notları ve bağ kaydı için öyle kalır). Plan, hedef, öneri,
-- etiket, paket, bekleme listesi ve ders önerisi politikaları bundan sonra yalnız ETKİN paylaşımda açılır.
create or replace function public.clinic_link_open(p_link_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.clinic_links l where l.id = p_link_id and l.status = 'active')
     and public.clinic_link_visible(p_link_id)
$$;
revoke execute on function public.clinic_link_open(uuid) from public, anon;
grant execute on function public.clinic_link_open(uuid) to authenticated;

drop policy if exists "modül: klinik" on public.care_modules;
create policy "modül: klinik" on public.care_modules for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and ((link_id is not null and public.clinic_link_open(link_id)) or (invite_code is not null and public.clinic_invite_mine(invite_code))))
  with check (clinic_id = public.my_clinic_id()
         and ((link_id is not null and invite_code is null and public.clinic_link_mine(link_id))
              or (link_id is null and invite_code is not null and public.clinic_invite_mine(invite_code))));

drop policy if exists "hedef: klinik" on public.clinic_goals;
create policy "hedef: klinik" on public.clinic_goals for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and ((link_id is not null and public.clinic_link_open(link_id)) or (invite_code is not null and public.clinic_invite_mine(invite_code))))
  with check (clinic_id = public.my_clinic_id()
         and ((link_id is not null and invite_code is null and public.clinic_link_mine(link_id))
              or (link_id is null and invite_code is not null and public.clinic_invite_mine(invite_code))));

drop policy if exists "program hedefi: klinik" on public.care_module_goals;
create policy "program hedefi: klinik" on public.care_module_goals for all to authenticated
  using (exists (select 1 from public.care_modules m
                  where m.id = care_module_goals.module_id and m.clinic_id = public.my_clinic_id() and public.clinician_access()
                    and ((m.link_id is not null and public.clinic_link_open(m.link_id))
                         or (m.invite_code is not null and public.clinic_invite_mine(m.invite_code)))))
  with check (exists (select 1 from public.care_modules m
                  where m.id = care_module_goals.module_id and m.clinic_id = public.my_clinic_id()
                    and ((m.link_id is not null and m.invite_code is null and public.clinic_link_mine(m.link_id))
                         or (m.link_id is null and m.invite_code is not null and public.clinic_invite_mine(m.invite_code)))));

drop policy if exists "hedef puanı: klinik" on public.goal_ratings;
create policy "hedef puanı: klinik" on public.goal_ratings for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and exists (select 1 from public.clinic_goals g where g.id = goal_ratings.goal_id and public.clinic_link_open(g.link_id)))
  with check (clinic_id = public.my_clinic_id() and public.clinician_access()
         and exists (select 1 from public.clinic_goals g where g.id = goal_ratings.goal_id and g.clinic_id = public.my_clinic_id()
                       and public.clinic_link_mine(g.link_id)));

drop policy if exists "öneri: klinik" on public.clinic_task_suggestions;
create policy "öneri: klinik" on public.clinic_task_suggestions for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_open(link_id));
drop policy if exists "öneri: klinik geri çeker" on public.clinic_task_suggestions;
create policy "öneri: klinik geri çeker" on public.clinic_task_suggestions for delete to authenticated
  using (clinic_id = public.my_clinic_id() and status in ('draft', 'pending') and public.clinician_access()
         and public.clinic_link_open(link_id));

-- clinic_notes bilerek değişmedi: uzmanın kendi notu paylaşım bitince klinikte kalır ve okunur (ürün kararı; test_clinic,
-- test_security_matrix). Yeni not yazılamaz, düzeltilemez (WITH CHECK etkin paylaşım ister).

drop policy if exists "etiket: klinik okur" on public.clinic_link_labels;
create policy "etiket: klinik okur" on public.clinic_link_labels for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinic_link_open(link_id));

drop policy if exists "paket: klinik okur" on public.clinic_session_packages;
create policy "paket: klinik okur" on public.clinic_session_packages for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_open(link_id));

drop policy if exists "bekleme: klinik okur" on public.clinic_waitlist;
create policy "bekleme: klinik okur" on public.clinic_waitlist for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_open(link_id));

drop policy if exists "ders önerisi: klinik okur" on public.parent_lesson_assignments;
create policy "ders önerisi: klinik okur" on public.parent_lesson_assignments for select to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_open(link_id));

-- Ailenin uygulama kaydı (care_module_logs) olan program doğrudan silinemez (zincirleme silme aile kaydını yok ederdi);
-- uzman "Tamamlandı" yapar. Klinik, paylaşım, çocuk ya da aile silinirken (zincirleme silme, tetikleyici derinliği > 1) dokunulmaz.
create or replace function public.care_modules_keep_family_logs() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if pg_trigger_depth() <= 1 and exists (select 1 from public.care_module_logs x where x.module_id = old.id) then
    raise exception 'Ailenin uygulama kaydı olan program silinemez; durumunu "Tamamlandı" yapabilirsin'
      using errcode = 'P0001', hint = 'module_has_family_logs';
  end if;
  return old;
end $$;
revoke execute on function public.care_modules_keep_family_logs() from public, anon, authenticated;
drop trigger if exists care_modules_keep_family_logs on public.care_modules;
create trigger care_modules_keep_family_logs before delete on public.care_modules
  for each row execute function public.care_modules_keep_family_logs();


-- Öneri kararı bildirimi yalnız paylaşım sürerken (son tanım burada; önceki: migrations/20261120100000_rutin_server_texts.sql).
create or replace function public.suggestions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('suggestion_id', new.id, 'child_id', new.child_id, 'link_id', new.link_id);
  rid uuid;
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform public.notify_parents(new.family_id, 'clinic_suggestion',
        case when new.kind = 'change' then 'Uzmanın ' || nm || ' için değişiklik önerdi' else 'Uzmanın ' || nm || ' için adım önerdi' end,
        coalesce(new.emoji || ' ', '') || new.title, d - 'link_id', new.child_id);
    end if;
  elsif old.status = 'pending' and new.status in ('accepted', 'declined')
        and exists (select 1 from public.clinic_links l where l.id = new.link_id and l.status = 'active') then   -- paylaşım bittiyse uzmana bildirim yok
    -- öneriyi yazan uzman hâlâ danışanı görüyorsa ona; görmüyorsa danışanın alıcılarına
    for rid in
      select new.created_by where new.created_by is not null and exists (
        select 1 from public.clinic_members m join public.clinic_links l on l.id = new.link_id
         where m.clinician_id = new.created_by and m.clinic_id = l.clinic_id and m.status = 'active'
           and (m.role = 'owner' or l.clinician_id = m.clinician_id
                or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.clinician_id)))
      union
      select x from public.clinic_link_recipients(new.link_id) x
       where new.created_by is null or not exists (
         select 1 from public.clinic_members m join public.clinic_links l on l.id = new.link_id
          where m.clinician_id = new.created_by and m.clinic_id = l.clinic_id and m.status = 'active'
            and (m.role = 'owner' or l.clinician_id = m.clinician_id
                 or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.clinician_id)))
    loop
      perform public.notify(rid, 'clinic', 'suggestion_decided',
        case when new.kind = 'change' then
               case when new.status = 'accepted' then 'Değişiklik uygulandı: ' else 'Değişiklik şimdilik uygulanmadı: ' end
             else case when new.status = 'accepted' then 'Öneri kabul edildi: ' else 'Öneri şimdilik eklenmedi: ' end end || new.title,
        nm, d, null, new.child_id);
    end loop;
  end if;
  return null;
end $$;
revoke execute on function public.suggestions_notify() from public, anon, authenticated;

-- =====================================================================
-- 2. 'mail' kovası: çocuk cihazı yalnız kendi mesajının dosyasını okur
-- =====================================================================
-- Ebeveyn: aile önekinin tamamı (gönderdiği dosyalar, çocuk fotoğrafları). Çocuk cihazı: alıcısı olduğu mesajın dosyası
-- (messages.media_path; çocuk mesajı dosya taşıyamaz) ve kendi fotoğrafı (children.avatar = 'photo:<yol>'). Kardeşin dosyası görünmez,
-- listede de çıkmaz.
create or replace function public.mail_object_readable(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when public.my_family_id() is not null then (storage.foldername(p_name))[1] = public.my_family_id()::text
    when public.my_child_id() is not null then
      exists (select 1 from public.messages m where m.media_path = p_name and m.child_id = public.my_child_id())
      or exists (select 1 from public.children c where c.id = public.my_child_id() and c.avatar = 'photo:' || p_name)
    else false end
$$;
revoke execute on function public.mail_object_readable(text) from public, anon;
grant execute on function public.mail_object_readable(text) to authenticated;

drop policy if exists "posta: aile okur" on storage.objects;
create policy "posta: aile okur" on storage.objects for select to authenticated
  using (bucket_id = 'mail' and public.mail_object_readable(name));
-- Yalnız ebeveyn yükler (oyun dosya yüklemez; çocuğun gönderdiği mesaj dosya taşıyamaz).
drop policy if exists "posta: aile yükler" on storage.objects;
create policy "posta: aile yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'mail' and (storage.foldername(name))[1] = public.my_family_id()::text);
-- "posta: ebeveyn siler" (yalnız my_family_id) değişmedi.

-- =====================================================================
-- 3. İstemcinin yazabildiği zaman alanları sonlu ve makul aralıkta
-- =====================================================================
-- Yalnız istemcinin doğrudan yazması denetlenir (current_user authenticated/anon); sunucu işlevleri (security definer) ve
-- service_role etkilenmez. Yalnız değişen alan denetlenir (eski satırı başka alanda düzeltmek engellenmez).
-- Bağımsız değişkenler: 'alan' = olay zamanı (2020-01-01 … şimdi + 1 gün); 'alan:plan' = plan tarihi (2020-01-01 … bugün + 10 yıl).
create or replace function public.client_time_guard() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  a text; col text; plan boolean; v text; ov text; t timestamptz;
  nj jsonb := to_jsonb(new);
  oj jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else null end;
begin
  if current_user not in ('authenticated', 'anon') then return new; end if;   -- invoker: tanımlayıcı işlevin içinden çağrı atlanır
  foreach a in array tg_argv loop
    col := split_part(a, ':', 1);
    plan := split_part(a, ':', 2) = 'plan';
    v := nj ->> col;
    ov := oj ->> col;
    continue when v is null or v is not distinct from ov;
    t := v::timestamptz;
    if not isfinite(t) or t < '2020-01-01'::timestamptz
       or t > (case when plan then now() + interval '3660 days' else now() + interval '1 day' end) then
      raise exception 'Geçersiz tarih: %', col using errcode = '22008', hint = 'invalid_time';
    end if;
  end loop;
  return new;
end $$;
revoke execute on function public.client_time_guard() from public, anon, authenticated;

drop trigger if exists completions_client_time on public.completions;
create trigger completions_client_time before insert or update on public.completions
  for each row execute function public.client_time_guard('created_at', 'reviewed_at', 'child_done_at', 'date:plan');
drop trigger if exists tasks_client_time on public.tasks;
create trigger tasks_client_time before insert or update on public.tasks
  for each row execute function public.client_time_guard('created_at', 'updated_at', 'start_date:plan', 'end_date:plan');
drop trigger if exists clinic_notes_client_time on public.clinic_notes;
create trigger clinic_notes_client_time before insert or update on public.clinic_notes
  for each row execute function public.client_time_guard('created_at');
drop trigger if exists clinic_task_suggestions_client_time on public.clinic_task_suggestions;
create trigger clinic_task_suggestions_client_time before insert or update on public.clinic_task_suggestions
  for each row execute function public.client_time_guard('created_at', 'updated_at', 'decided_at', 'start_date:plan', 'end_date:plan');


-- KPI medyanı sonsuz / bozuk zamana dayanıklı (son tanımlar burada; önceki: migrations/20261023000000_admin.sql ve
-- migrations/20261024000000_admin_fixes.sql; yalnız medyan süzgecine isfinite eklendi).
create or replace function public.admin_kpi_summary(p_days integer default 30)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  d integer := least(greatest(coalesce(p_days, 30), 1), 365);
  since timestamptz := now() - make_interval(days => d);
  cfg jsonb := coalesce((select value from public.app_config where key = 'kpi'), '{}'::jsonb);
  bcfg jsonb := public.billing_config();
  fee numeric := 1 - coalesce((cfg ->> 'store_fee_pct')::numeric, 15) / 100;
  rc numeric := 1 - coalesce((cfg ->> 'revenuecat_pct')::numeric, 1) / 100;
  pm integer; py integer; mrr_parent numeric; mrr_clinic numeric;
  trial_ended integer; trial_paid integer;
begin
  perform public.admin_require();
  select count(*) filter (where billing = 'monthly'), count(*) filter (where billing = 'yearly') into pm, py
    from public.family_subscriptions
   where source = 'store' and plan = 'premium' and status in ('active', 'grace', 'canceled') and (period_end is null or period_end > now());
  mrr_parent := pm * coalesce((cfg ->> 'parent_monthly_try')::numeric, 0) + py * coalesce((cfg ->> 'parent_yearly_try')::numeric, 0) / 12;
  select coalesce(sum(case when p.period = 'monthly' then p.price_try else p.price_try / 12 end), 0) into mrr_clinic
    from public.billing_subscriptions s join public.billing_plans p on p.id = s.plan_id
   where s.source <> 'manual' and s.status in ('active', 'canceled') and s.period_end > now();
  -- Denemesi son d günde biten aileler ve bunlardan bugün mağaza premium olanlar
  select count(*), count(*) filter (where exists (select 1 from public.family_subscriptions s where s.family_id = f.id
                                                    and s.source = 'store' and s.plan = 'premium'))
    into trial_ended, trial_paid
    from public.families f
   where f.trial_started_at is not null
     and f.trial_started_at + make_interval(days => (bcfg ->> 'trial_days')::int) between since and now();

  return json_build_object(
    'days', d,
    'totals', json_build_object(
      'families', (select count(*) from public.families),
      'parents', (select count(*) from public.profiles),
      'children', (select count(*) from public.children),
      'children_linked', (select count(*) from public.children where user_id is not null),
      'clinics', (select count(*) from public.clinics),
      'clinicians', (select count(*) from public.clinicians)),
    'active', (select coalesce(json_object_agg(x.app, json_build_object('dau', x.dau, 'wau', x.wau, 'mau', x.mau,
                 'stickiness', case when x.mau > 0 then round(x.dau::numeric / x.mau, 3) end)), '{}')
                 from (select a.app,
                              count(distinct a.user_id) filter (where a.day = current_date) as dau,
                              count(distinct a.user_id) filter (where a.day > current_date - 7) as wau,
                              count(distinct a.user_id) filter (where a.day > current_date - 30) as mau
                         from public.activity_days a where a.day > current_date - 30 group by a.app) x),
    'new', json_build_object(
      'families', (select count(*) from public.families where created_at >= since),
      'children_linked', (select count(*) from public.user_activity where app = 'child' and first_seen_at >= since),
      'clinics', (select count(*) from public.clinics where created_at >= since),
      'clinicians', (select count(*) from public.clinicians where created_at >= since)),
    'revenue', json_build_object(
      'parent_monthly', pm, 'parent_yearly', py,
      'parent_manual', (select count(*) from public.family_subscriptions where source = 'manual' and plan = 'premium'
                          and (period_end is null or period_end > now())),
      'clinic_paid', (select count(distinct s.clinic_id) from public.billing_subscriptions s
                        where s.source <> 'manual' and s.status in ('active', 'canceled') and s.period_end > now()),
      'clinic_manual', (select count(distinct s.clinic_id) from public.billing_subscriptions s
                          where s.source = 'manual' and s.status in ('active', 'canceled') and s.period_end > now()),
      'clinic_trial', (select count(*) from public.clinics where plan = 'trial' and trial_ends_at > now()),
      'mrr_gross_try', round(mrr_parent + mrr_clinic, 2),
      'mrr_net_try', round((mrr_parent + mrr_clinic) * fee * rc, 2),
      'parent_prices_set', coalesce((cfg ->> 'parent_monthly_try')::numeric, 0) > 0),
    'trial', json_build_object(
      'families_in_trial', (select count(*) from public.families f where f.trial_started_at is not null
                              and f.trial_started_at + make_interval(days => (bcfg ->> 'trial_days')::int) > now()),
      'ended', trial_ended, 'converted', trial_paid,
      'conversion', case when trial_ended > 0 then round(trial_paid::numeric / trial_ended, 3) end),
    'churn', json_build_object(
      'parent', (select count(*) from public.family_subscriptions where source = 'store' and status in ('expired', 'refunded')
                   and updated_at >= since),
      'parent_refunds', (select count(*) from public.family_subscriptions where source = 'store' and status = 'refunded'
                           and updated_at >= since),
      'clinic', (select count(distinct clinic_id) from public.billing_events where kind in ('apply:expired', 'apply:refunded')
                   and source <> 'manual' and created_at >= since)),
    'engagement', json_build_object(
      'tasks_created', (select count(*) from public.tasks where created_at >= since),
      'completions', (select count(*) from public.completions where created_at >= since),
      'approved', (select count(*) from public.completions where created_at >= since and status = 'approved'),
      'approval_rate', (select case when count(*) > 0 then round(count(*) filter (where status = 'approved')::numeric / count(*), 3) end
                          from public.completions where created_at >= since),
      'median_review_minutes', (select round((percentile_cont(0.5) within group (
                                   order by extract(epoch from reviewed_at - coalesce(child_done_at, created_at)) / 60))::numeric, 1)
                                  from public.completions where reviewed_at is not null and created_at >= since
                                   and isfinite(reviewed_at) and isfinite(created_at) and (child_done_at is null or isfinite(child_done_at))),
      'active_children', (select count(distinct user_id) from public.activity_days where app = 'child' and day >= since::date),
      'notifications_read_rate', (select case when count(*) > 0 then round(count(read_at)::numeric / count(*), 3) end
                                    from public.notifications where created_at >= since),
      'push_users', (select count(distinct user_id) from public.push_tokens)),
    'clinic', json_build_object(
      'active_links', (select count(*) from public.clinic_links where status = 'active'),
      'clinics_with_clients', (select count(distinct clinic_id) from public.clinic_links where status = 'active'),
      'suggestions', (select count(*) from public.clinic_task_suggestions where created_at >= since),
      'notes', (select count(*) from public.clinic_notes where created_at >= since),
      'consent_revoked', (select count(*) from public.clinic_links where revoked_at >= since))
  );
end $$;

create or replace function public.admin_kpi_apps(p_days integer default 30)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  d integer := least(greatest(coalesce(p_days, 30), 1), 365);
  since timestamptz := now() - make_interval(days => d);
  cfg jsonb := coalesce((select value from public.app_config where key = 'kpi'), '{}'::jsonb);
  bcfg jsonb := public.billing_config();
  net numeric := (1 - coalesce((cfg ->> 'store_fee_pct')::numeric, 15) / 100) * (1 - coalesce((cfg ->> 'revenuecat_pct')::numeric, 1) / 100);
  pm integer; py integer; mrr_p numeric; mrr_c numeric; t_end integer; t_paid integer;
begin
  perform public.admin_require();
  select count(*) filter (where billing = 'monthly'), count(*) filter (where billing = 'yearly') into pm, py
    from public.family_subscriptions
   where source = 'store' and plan = 'premium' and status in ('active', 'grace', 'canceled') and (period_end is null or period_end > now());
  mrr_p := pm * coalesce((cfg ->> 'parent_monthly_try')::numeric, 0) + py * coalesce((cfg ->> 'parent_yearly_try')::numeric, 0) / 12;
  select coalesce(sum(case when p.period = 'monthly' then p.price_try else p.price_try / 12 end), 0) into mrr_c
    from public.billing_subscriptions s join public.billing_plans p on p.id = s.plan_id
   where s.source <> 'manual' and s.status in ('active', 'canceled') and s.period_end > now();
  select count(*), count(*) filter (where exists (select 1 from public.family_subscriptions s where s.family_id = f.id
                                                    and s.source = 'store' and s.plan = 'premium'))
    into t_end, t_paid
    from public.families f
   where f.trial_started_at is not null
     and f.trial_started_at + make_interval(days => (bcfg ->> 'trial_days')::int) between since and now();

  return json_build_object(
    'days', d,
    'parent', json_build_object(
      'families', (select count(*) from public.families),
      'parents', (select count(*) from public.profiles),
      'new_families', (select count(*) from public.families where created_at >= since),
      'in_trial', (select count(*) from public.families f where f.trial_started_at is not null
                     and f.trial_started_at + make_interval(days => (bcfg ->> 'trial_days')::int) > now()),
      'trial_ended', t_end, 'trial_converted', t_paid,
      'trial_conversion', case when t_end > 0 then round(t_paid::numeric / t_end, 3) end,
      'subscribers_monthly', pm, 'subscribers_yearly', py,
      'manual_premium', (select count(*) from public.family_subscriptions where source = 'manual' and plan = 'premium'
                           and (period_end is null or period_end > now())),
      'mrr_gross_try', round(mrr_p, 2), 'mrr_net_try', round(mrr_p * net, 2),
      'prices_set', coalesce((cfg ->> 'parent_monthly_try')::numeric, 0) > 0,
      'churn', (select count(*) from public.family_subscriptions where source = 'store' and status in ('expired', 'refunded') and updated_at >= since),
      'refunds', (select count(*) from public.family_subscriptions where source = 'store' and status = 'refunded' and updated_at >= since),
      'tasks_created', (select count(*) from public.tasks where created_at >= since),
      'approved', (select count(*) from public.completions where created_at >= since and status = 'approved'),
      'approval_rate', (select case when count(*) > 0 then round(count(*) filter (where status = 'approved')::numeric / count(*), 3) end
                          from public.completions where created_at >= since),
      'median_review_minutes', (select round((percentile_cont(0.5) within group (
                                   order by extract(epoch from reviewed_at - coalesce(child_done_at, created_at)) / 60))::numeric, 1)
                                  from public.completions where reviewed_at is not null and created_at >= since
                                   and isfinite(reviewed_at) and isfinite(created_at) and (child_done_at is null or isfinite(child_done_at))),
      'rewards_given', (select count(*) from public.reward_requests where status = 'approved' and decided_at >= since),
      'families_with_clinic', (select count(distinct family_id) from public.clinic_links where status = 'active'),
      'notifications_read_rate', (select case when count(*) > 0 then round(count(read_at)::numeric / count(*), 3) end
                                    from public.notifications where app = 'parent' and created_at >= since),
      'push_users', (select count(distinct user_id) from public.push_tokens where app = 'parent')),
    'child', json_build_object(
      'children', (select count(*) from public.children),
      'linked', (select count(*) from public.children where user_id is not null),
      'new_linked', (select count(*) from public.user_activity where app = 'child' and first_seen_at >= since),
      'active', (select count(distinct user_id) from public.activity_days where app = 'child' and day >= since::date),
      'done_marked', (select count(*) from public.completions where child_done_at >= since),
      'approved', (select count(*) from public.completions where created_at >= since and status = 'approved'),
      'reward_requests', (select count(*) from public.reward_requests where created_at >= since),
      'notifications_read_rate', (select case when count(*) > 0 then round(count(read_at)::numeric / count(*), 3) end
                                    from public.notifications where app = 'child' and created_at >= since),
      'push_users', (select count(distinct user_id) from public.push_tokens where app = 'child')),
    'clinic', json_build_object(
      'clinics', (select count(*) from public.clinics),
      'clinicians', (select count(*) from public.clinicians),
      'new_clinics', (select count(*) from public.clinics where created_at >= since),
      'new_clinicians', (select count(*) from public.clinicians where created_at >= since),
      'paid', (select count(distinct s.clinic_id) from public.billing_subscriptions s
                 where s.source <> 'manual' and s.status in ('active', 'canceled') and s.period_end > now()),
      'manual', (select count(distinct s.clinic_id) from public.billing_subscriptions s
                   where s.source = 'manual' and s.status in ('active', 'canceled') and s.period_end > now()),
      'in_trial', (select count(*) from public.clinics where plan = 'trial' and trial_ends_at > now()),
      'mrr_gross_try', round(mrr_c, 2), 'mrr_net_try', round(mrr_c * net, 2),
      'churn', (select count(distinct clinic_id) from public.billing_events where kind in ('apply:expired', 'apply:refunded')
                  and source <> 'manual' and created_at >= since),
      'active_links', (select count(*) from public.clinic_links where status = 'active'),
      'clinics_with_clients', (select count(distinct clinic_id) from public.clinic_links where status = 'active'),
      'suggestions', (select count(*) from public.clinic_task_suggestions where created_at >= since),
      'notes', (select count(*) from public.clinic_notes where created_at >= since),
      'consent_revoked', (select count(*) from public.clinic_links where revoked_at >= since),
      'notifications_read_rate', (select case when count(*) > 0 then round(count(read_at)::numeric / count(*), 3) end
                                    from public.notifications where app = 'clinic' and created_at >= since),
      'push_users', (select count(distinct user_id) from public.push_tokens where app = 'clinic')),
    'total', json_build_object('mrr_gross_try', round(mrr_p + mrr_c, 2), 'mrr_net_try', round((mrr_p + mrr_c) * net, 2))
  );
end $$;


-- =====================================================================
-- 4. Ücretsiz plan adım sınırı güncellemede de
-- =====================================================================
-- Son tanım burada (önceki: migrations/20261120100000_rutin_server_texts.sql). INSERT'te davranış aynı. UPDATE'te yalnız etkin
-- olmayan bir adım etkin hâle geldiğinde (ya da etkin adım başka aileye geçtiğinde) sayılır; adım kendisi sayılmaz.
create or replace function public.tasks_free_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := public.billing_config();
begin
  if tg_op = 'UPDATE' then
    if not ((new.end_date is null or new.end_date >= current_date) and (new.recurring or new.start_date >= current_date)) then
      return new;
    end if;
    if new.family_id = old.family_id and (old.end_date is null or old.end_date >= current_date)
       and (old.recurring or old.start_date >= current_date) then
      return new;
    end if;
  end if;
  if public.family_full_access(new.family_id) then return new; end if;
  if (select count(*) from public.tasks t where t.family_id = new.family_id and t.id <> new.id
        and (t.end_date is null or t.end_date >= current_date)
        and (t.recurring or t.start_date >= current_date)) >= (cfg ->> 'free_max_tasks')::int then
    raise exception 'Ücretsiz planda en çok % etkin adım olabilir', cfg ->> 'free_max_tasks'
      using errcode = 'P0001', hint = 'premium_required';
  end if;
  return new;
end $$;
drop trigger if exists tasks_free_limit on public.tasks;
create trigger tasks_free_limit before insert or update of recurring, start_date, end_date, family_id on public.tasks
  for each row execute function public.tasks_free_limit();
-- Öteki sınırlar: children_free_limit (çocuk sayısı; ebeveyn çocuğu başka aileye taşıyamaz, "etkin" durumu yok),
-- abc_events_free_limit ve messages_free_limit (her yeni kayıt; mesajda güncelleme yetkisi yok) için güncelleme açığı yok.

-- =====================================================================
-- 5. Klinik üyeliği bitince takvim bağlantıları
-- =====================================================================
-- Son tanım burada (önceki: migrations/20261105090000_workspaces.sql). Ek: o kliniğe bağlı takvim beslemesi (belirteç) silinir,
-- dış takvim kaynakları ve onlardan gelen etkinlikler silinir.
create or replace function public.clinic_member_end(p_clinic uuid, p_clinician uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.clinic_members set status = 'left', left_at = now()
   where clinic_id = p_clinic and clinician_id = p_clinician and status = 'active';
  delete from public.clinic_link_access where clinic_id = p_clinic and clinician_id = p_clinician;
  update public.clinic_links set clinician_id = null where clinic_id = p_clinic and clinician_id = p_clinician;
  update public.clinic_invites set revoked_at = now()
   where clinic_id = p_clinic and clinician_id = p_clinician and kind = 'family'
     and used_at is null and revoked_at is null and declined_at is null;
  if to_regclass('public.clinic_sessions') is not null then
    execute 'update public.clinic_sessions set clinician_id = null where clinic_id = $1 and clinician_id = $2
               and starts_at > now() and status in (''planned'', ''offered'')' using p_clinic, p_clinician;
  end if;
  if to_regclass('public.clinic_availability') is not null then
    execute 'delete from public.clinic_availability where clinic_id = $1 and clinician_id = $2' using p_clinic, p_clinician;
  end if;
  if to_regclass('public.clinic_calendar_feeds') is not null then
    execute 'delete from public.clinic_external_events where clinic_id = $1 and clinician_id = $2' using p_clinic, p_clinician;
    execute 'delete from public.clinic_calendar_sources where clinic_id = $1 and clinician_id = $2' using p_clinic, p_clinician;
    execute 'delete from public.clinic_calendar_feeds where clinic_id = $1 and clinician_id = $2' using p_clinic, p_clinician;
  end if;
  if (select clinic_id from public.clinicians where id = p_clinician) = p_clinic then
    update public.clinicians set clinic_id = public.clinician_personal_workspace_for(p_clinician), role = 'owner'
     where id = p_clinician;
  end if;
end $$;
revoke execute on function public.clinic_member_end(uuid, uuid) from public, anon, authenticated;

-- Var olan kalıntıları temizle (üyeliği bitmiş klinik için kalmış kaynak, etkinlik ve belirteçler).
delete from public.clinic_external_events e
 where not exists (select 1 from public.clinic_members m where m.clinic_id = e.clinic_id and m.clinician_id = e.clinician_id and m.status = 'active');
delete from public.clinic_calendar_sources s
 where not exists (select 1 from public.clinic_members m where m.clinic_id = s.clinic_id and m.clinician_id = s.clinician_id and m.status = 'active');
delete from public.clinic_calendar_feeds f
 where not exists (select 1 from public.clinic_members m where m.clinic_id = f.clinic_id and m.clinician_id = f.clinician_id and m.status = 'active');

-- Besleme: yalnız uzmanın hâlâ etkin üyesi olduğu kliniklerdeki seanslar (son tanım burada; önceki: migrations/20261105100000_sessions.sql).
create or replace function public.calendar_feed_events(p_token text)
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(json_build_object(
      'uid', s.id, 'start', s.starts_at, 'end', s.starts_at + make_interval(mins => s.duration_min),
      'summary', case when s.link_id is null then coalesce(nullif(s.title, ''), 'Takvim bloğu')
                      else public.session_kind_label(s.kind)
                           || case when f.show_initials then ' · ' || upper(left(public.child_name(l.child_id), 1)) || '.' else '' end end,
      'location', case s.mode when 'online' then 'Online' when 'home' then 'Ev ziyareti'
                    else coalesce(r.name || coalesce(' · ' || r.location, ''), '') end,
      'cancelled', s.status in ('cancelled', 'late_cancel', 'postponed')) order by s.starts_at), '[]')
  from public.clinic_calendar_feeds f
  join public.clinic_members fm on fm.clinic_id = f.clinic_id and fm.clinician_id = f.clinician_id and fm.status = 'active'
  join public.clinic_sessions s on s.clinician_id = f.clinician_id and s.status <> 'offered'
  join public.clinic_members sm on sm.clinic_id = s.clinic_id and sm.clinician_id = f.clinician_id and sm.status = 'active'
  left join public.clinic_links l on l.id = s.link_id
  left join public.clinic_rooms r on r.id = s.room_id
  where f.token = p_token and char_length(p_token) >= 32
    and s.starts_at between now() - interval '30 days' and now() + interval '180 days'
$$;

-- Dış etkinliği seansa çevirme: etkinlik seçili çalışma alanının olmalı (clinician_access o alanda etkin üyeliği denetler).
create or replace function public.clinic_external_event_mark(p_event uuid, p_link uuid default null, p_kind text default 'individual',
                                                             p_mode text default 'in_person', p_ignore boolean default false)
returns uuid language plpgsql security definer set search_path = '' as $$
declare e public.clinic_external_events; v uuid;
begin
  select * into e from public.clinic_external_events where id = p_event and clinician_id = auth.uid();
  if e.id is null or not public.clinician_access() or e.clinic_id is distinct from public.my_clinic_id() then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
  if p_ignore then
    update public.clinic_external_events set ignored = true where id = p_event;
    return null;
  end if;
  if e.session_id is not null then return e.session_id; end if;
  perform public.session_check_refs(p_link, null, null, null);
  insert into public.clinic_sessions (clinic_id, clinician_id, link_id, title, starts_at, duration_min, kind, mode, external_uid, created_by)
  values (e.clinic_id, e.clinician_id, p_link, case when p_link is null then left(e.summary, 80) end, e.starts_at,
          least(greatest((extract(epoch from (e.ends_at - e.starts_at)) / 60)::int, 5), 480),
          coalesce(p_kind, 'individual'), coalesce(p_mode, 'in_person'), e.uid, auth.uid())
  returning id into v;
  update public.clinic_external_events set session_id = v, ignored = false where id = p_event;
  return v;
end $$;

-- =====================================================================
-- 6. KVKK başvurusu: anonim oturum yok, genel saatlik üst sınır
-- =====================================================================
-- Son tanım burada (önceki: migrations/20261027200000_legal.sql). Ek: başvuran anonim olmayan bir hesap (ebeveyn ya da uzman)
-- olmalı (Moyo Oyun'da başvuru formu yok, hukuk/44: çocuk adına veli başvurur). Hesap başına 5 açık başvuru kalır; bütün sistemde
-- son 1 saatte 120 başvuru dolarsa yeni başvuru geçici olarak alınmaz (e-posta yolu açık). Yönetici listesi süreye göre sıralı.
create or replace function public.kvkk_request_create(p_app text, p_kind text, p_detail text, p_child uuid default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  r public.kvkk_requests%rowtype;
begin
  if uid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  if not exists (select 1 from auth.users u where u.id = uid and not coalesce(u.is_anonymous, false))
     or not (exists (select 1 from public.profiles p where p.id = uid) or exists (select 1 from public.clinicians c where c.id = uid)) then
    raise exception 'Başvuru için Moyo Ebeveyn ya da Moyo Mercek hesabıyla giriş yapmalısın' using errcode = '42501', hint = 'account_required';
  end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  if p_kind not in ('info', 'access', 'correct', 'delete', 'object', 'third_parties', 'damages', 'other') then raise exception 'Başvuru türü seç'; end if;
  if char_length(coalesce(p_detail, '')) > 2000 then raise exception 'Açıklama en çok 2000 karakter'; end if;
  if p_kind in ('correct', 'object', 'damages', 'other') and char_length(btrim(coalesce(p_detail, ''))) < 5 then
    raise exception 'Talebini kısaca yaz';
  end if;
  if p_child is not null and not exists (select 1 from public.children c join public.profiles p on p.family_id = c.family_id
                                          where c.id = p_child and p.id = uid) then
    raise exception 'Çocuk bulunamadı';
  end if;
  if (select count(*) from public.kvkk_requests where user_id = uid and status in ('received', 'in_progress')) >= 5 then
    raise exception 'Açık başvurun var; yanıtlanınca yenisini gönderebilirsin';
  end if;
  if (select count(*) from public.kvkk_requests where channel = 'app' and received_at > now() - interval '1 hour') >= 120 then
    raise exception 'Şu an çok sayıda başvuru var; biraz sonra yeniden dene ya da e-postayla başvur' using errcode = 'P0001', hint = 'busy';
  end if;
  insert into public.kvkk_requests (user_id, email, app, kind, detail, child_id)
  values (uid, (select u.email::text from auth.users u where u.id = uid), p_app, p_kind, btrim(coalesce(p_detail, '')), p_child)
  returning * into r;
  return json_build_object('id', r.id, 'status', r.status, 'received_at', r.received_at, 'due_at', r.due_at);
end $$;
revoke execute on function public.kvkk_request_create(text, text, text, uuid) from public, anon;
grant execute on function public.kvkk_request_create(text, text, text, uuid) to authenticated;

-- =====================================================================
-- 7. Deneme tekrarı: Gmail nokta ve googlemail.com aynı adres
-- =====================================================================
-- Eski özet (yalnız küçük harf ve +etiket) eşleşme için durur: var olan trial_history satırları onunla yazıldı.
create or replace function public.email_hash_legacy(p_email text)
returns text language sql immutable set search_path = '' as $$
  select encode(extensions.digest(regexp_replace(lower(trim(p_email)), '\+[^@]*@', '@'), 'sha256'), 'hex')
$$;
revoke execute on function public.email_hash_legacy(text) from public, anon, authenticated;

-- Yeni özet: küçük harf, +etiket atılır; yalnız gmail.com / googlemail.com'da yerel kısımdaki noktalar atılır ve alan gmail.com olur.
-- Noktasız, +etiketsiz bir gmail.com adresinin yeni özeti eskisiyle aynıdır.
create or replace function public.email_hash(p_email text)
returns text language sql immutable set search_path = '' as $$
  with e as (select regexp_replace(lower(trim(p_email)), '\+[^@]*@', '@') as a)
  select encode(extensions.digest(
           case when split_part(a, '@', 2) in ('gmail.com', 'googlemail.com') and a like '%@%'
                then replace(split_part(a, '@', 1), '.', '') || '@gmail.com'
                else a end, 'sha256'), 'hex')
  from e
$$;
revoke execute on function public.email_hash(text) from public, anon, authenticated;

-- Son tanım burada (önceki: migrations/20261022110000_subscriptions.sql). Eşleşme önce yeni özetle, yoksa eski özetle.
create or replace function public.start_family_trial(p_user uuid, p_email text, p_confirmed timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare
  h text;
  prev timestamptz;
begin
  if p_confirmed is null then return; end if;
  if p_email is not null then
    h := public.email_hash(p_email);
    select min(started_at) into prev from public.trial_history
     where email_hash in (h, public.email_hash_legacy(p_email));
    if prev is null then
      insert into public.trial_history (email_hash, started_at) values (h, p_confirmed) on conflict do nothing;
    end if;
  end if;
  update public.families set trial_started_at = coalesce(prev, p_confirmed)
   where created_by = p_user and trial_started_at is null;
end $$;
revoke execute on function public.start_family_trial(uuid, text, timestamptz) from public, anon, authenticated;

-- =====================================================================
-- 8. Sağlamlaştırma
-- =====================================================================
-- (c) arama yolu boş (gövdede şema adları zaten tam yazılı)
alter function public.clinic_notes_goal_check() set search_path = '';

-- (b) anon rolü public tablolara hiç dokunamaz (RLS zaten kapatıyordu; ikinci kat). Uygulamalar girişsiz tabloya erişmez;
-- girişsiz yollar Edge Function (service_role) üzerinden. Bundan sonra bu rolün oluşturduğu tablolar da anon'a açılmaz.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;


-- (a) redeem_guest_pass: başarılı kullanımda deneme sayaçları silinmez (son tanım burada; önceki:
-- migrations/20261118200000_parent_trial_14.sql).
CREATE OR REPLACE FUNCTION public.redeem_guest_pass(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $$
declare
  fid uuid := public.my_family_id();
  f public.families%rowtype;
  g public.guest_passes%rowtype;
  t json;
  err text;
  base int := (public.billing_config() ->> 'trial_days')::int;
begin
  if fid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  select * into g from public.guest_passes where code = upper(trim(coalesce(p_code, ''))) for update;
  if not found then
    insert into public.code_attempts (user_id, ip) values (auth.uid(), public.request_ip());
    return json_build_object('ok', false, 'error', 'not_found');
  end if;
  select * into f from public.families where id = fid for update;
  err := case
    when g.redeemed_at is not null then 'used'
    when g.expires_at <= now() then 'expired'
    when g.family_id = fid then 'own'
    when f.trial_days is not null then 'already'
    when exists (select 1 from public.family_subscriptions s where s.family_id = fid and s.plan = 'premium'
                   and s.status in ('active', 'grace', 'canceled') and (s.period_end is null or s.period_end > now())) then 'premium'
    when f.trial_started_at is not null and f.trial_started_at < now() - make_interval(days => base) then 'not_new'
  end;
  if err is not null then return json_build_object('ok', false, 'error', err); end if;

  update public.families set trial_days = base + 7, trial_started_at = coalesce(trial_started_at, now()) where id = fid returning * into f;
  update public.guest_passes set redeemed_family = fid, redeemed_at = now() where code = g.code;
  -- deneme sayaçları silinmez (IP sayacı düşmesin; aile bir kez kullanabildiği için kullanıcı sayacı da 15 dakikada kendiliğinden düşer)
  perform public.notify_parents(g.family_id, 'guest_pass_used', 'Davetin kullanıldı',
    'Bir aile davetinle Moyo''ya başladı. Abone olurlarsa sen 1 ay ücretsiz kazanırsın.', jsonb_build_object('code', g.code), null);
  return json_build_object('ok', true, 'trial_ends_at', f.trial_started_at + make_interval(days => base + 7));
end $$;
revoke execute on function public.redeem_guest_pass(text) from public, anon;
grant execute on function public.redeem_guest_pass(text) to authenticated;

-- =====================================================================
-- 9. Bildirim seli: aynı gönderenden aynı alıcıya aynı türde saatte en çok 6 anlık bildirim
-- =====================================================================
-- Bildirim satırı her zaman yazılır (uygulama içinde görünür); sınırı aşan ya da 10 dakika içinde aynı kayıt için (aynı tür, aynı
-- çocuk, aynı data) yinelenen bildirim push = false olur. Gönderen = işlemi yapan oturum (auth.uid()). Sunucu / zamanlanmış iş
-- (auth.uid() boş), kişinin kendine bildirimi ve hesap / güvenlik türleri sınırın dışında.
create table if not exists public.notification_push_log (
  id         bigserial primary key,
  sender_id  uuid not null references auth.users (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null,
  at         timestamptz not null default now()
);
create index if not exists notification_push_log_idx on public.notification_push_log (sender_id, user_id, kind, at);
alter table public.notification_push_log enable row level security;   -- politika yok: yalnız sunucu
revoke all on public.notification_push_log from public, anon, authenticated;
revoke all on sequence public.notification_push_log_id_seq from public, anon, authenticated;

create or replace function public.notification_push_exempt(p_kind text)
returns boolean language sql immutable set search_path = '' as $$
  select p_kind like 'nudge%' or p_kind like 'invite\_%' or p_kind like 'verification\_%' or p_kind like 'team\_%'
      or p_kind like 'kvkk%' or p_kind like 'trial%' or p_kind like 'billing%' or p_kind like 'membership%'
      or p_kind in ('admin_message', 'clinic_shared', 'clinic_revoked', 'device_linked', 'parent_joined', 'guest_pass_used',
                    'referral_reward', 'client_assigned', 'support_answered')
$$;
revoke execute on function public.notification_push_exempt(text) from public, anon, authenticated;

create or replace function public.notifications_push_throttle() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  s uuid := auth.uid();
begin
  if not new.push or s is null or s = new.user_id or public.notification_push_exempt(new.kind) then return new; end if;
  if exists (select 1 from public.notifications n
              where n.user_id = new.user_id and n.kind = new.kind and n.push and n.data = new.data
                and n.child_id is not distinct from new.child_id and n.created_at > now() - interval '10 minutes') then
    new.push := false;
    return new;
  end if;
  if (select count(*) from public.notification_push_log l
       where l.sender_id = s and l.user_id = new.user_id and l.kind = new.kind and l.at > now() - interval '1 hour') >= 6 then
    new.push := false;
    return new;
  end if;
  delete from public.notification_push_log where sender_id = s and at < now() - interval '1 day';
  insert into public.notification_push_log (sender_id, user_id, kind) values (s, new.user_id, new.kind);
  return new;
end $$;
revoke execute on function public.notifications_push_throttle() from public, anon, authenticated;
-- Ad sırası: notifications_push_pref (ebeveyn tercihi) önce, bu sonra çalışır; tercihle kapanan bildirim sayılmaz.
drop trigger if exists notifications_push_throttle on public.notifications;
create trigger notifications_push_throttle before insert on public.notifications
  for each row execute function public.notifications_push_throttle();
