-- =====================================================================
-- Admin düzeltmeleri (öneri, 24 Ekim 2026; kullanıcı: "arama çalışmıyor, göstergeler uygulama bazında ayrışmıyor")
--   1) admin_search: canlıda auth.users.email `varchar(255)`; dönüş tipi text olduğu için her aramada
--      "structure of query does not match function result type" hatası. E-posta text'e çevrildi.
--      (Test ortamı da artık varchar kullanır: supabase_stub.sql.)
--   2) admin_kpi_apps(gün): göstergeler uygulama bazında (ParentApp / GameApp / ClinicApp) tek çağrıda.
--      admin_kpi_summary değişmedi (geriye dönük uyum).
-- Önkoşul: migrations/20261023000000_admin.sql. Tekrar çalıştırılabilir.
-- =====================================================================

create or replace function public.admin_search(p_q text, p_limit integer default 25)
returns table (kind text, user_id uuid, family_id uuid, clinic_id uuid, child_id uuid, label text, email text,
               created_at timestamptz, last_seen_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare
  q text := trim(coalesce(p_q, ''));
  pat text;
  v_id uuid;
  n integer := least(greatest(coalesce(p_limit, 25), 1), 100);
begin
  perform public.admin_require();
  if char_length(q) < 2 then return; end if;
  pat := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  if q ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then v_id := q::uuid; end if;
  return query
  with hits as (
    select public.account_kind(u.id) as kind, u.id as user_id, coalesce(p.family_id, c.family_id) as family_id,
           m.clinic_id, c.id as child_id,
           coalesce(nullif(m.name, ''), nullif(p.name, ''), p.nickname, c.name, u.email::text) as label, u.email::text as email,
           u.created_at, (select max(a.last_seen_at) from public.user_activity a where a.user_id = u.id) as last_seen_at
      from auth.users u
      left join public.profiles p on p.id = u.id
      left join public.clinicians m on m.id = u.id
      left join public.children c on c.user_id = u.id
     where u.id = v_id or u.email ilike pat or p.name ilike pat or p.nickname ilike pat or m.name ilike pat
        or p.family_id = v_id or c.family_id = v_id or m.clinic_id = v_id
    union all
    -- cihazı bağlanmamış çocuklar (hesapsız)
    select 'child', null, c.family_id, null, c.id, c.name, null, c.created_at, null
      from public.children c
     where c.user_id is null and (c.name ilike pat or c.id = v_id or c.family_id = v_id)
    union all
    select 'child', c.user_id, c.family_id, null, c.id, c.name, null, c.created_at,
           (select max(a.last_seen_at) from public.user_activity a where a.user_id = c.user_id)
      from public.children c
     where c.user_id is not null and (c.name ilike pat or c.id = v_id)
    union all
    select 'clinic', null, null, k.id, null, k.name, null, k.created_at, null
      from public.clinics k
     where k.name ilike pat or k.id = v_id
  )
  select distinct on (h.kind, h.user_id, h.child_id, h.clinic_id) h.*
    from hits h
   order by h.kind, h.user_id, h.child_id, h.clinic_id, h.last_seen_at desc nulls last
   limit n;
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
                                  from public.completions where reviewed_at is not null and created_at >= since),
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

revoke execute on function public.admin_search(text, integer) from public, anon;
grant execute on function public.admin_search(text, integer) to authenticated;
revoke execute on function public.admin_kpi_apps(integer) from public, anon;
grant execute on function public.admin_kpi_apps(integer) to authenticated;
