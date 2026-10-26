-- =====================================================================
-- Yönetim paneli: müşteri listeleri (öneri, 26 Ekim 2026; kullanıcı isteği "her uygulama için müşteri listeleyen güçlü panel")
--   admin_customers(app, segment, arama, sıralama, azalan, limit, offset) → {total, segments{ad: sayı}, rows[]}
--   app = 'parent' (aileler, ParentApp) · 'child' (çocuklar, GameApp) · 'clinic' (klinikler, ClinicApp)
--   Örnek alınan düzen (Stripe Customers, ChartMogul/Baremetrics, RevenueCat): hazır kesimler (deneme, bitiyor, abone,
--   pasif, risk), arama, sıralanabilir sütunlar, sayfalama; satırdan müşteri kartına geçiş.
--   Gizlilik (sozlesme/admin.md): mesaj/not içeriği yok, yalnız sayılar; çocuk için puan/tanı yok (seviye ve coin oyun verisidir).
--   Ölçek: satırlar her çağrıda hesaplanır (binlerce müşteriye kadar yeterli); büyüyünce özet tablo/görünüm.
-- Tekrar çalıştırılabilir.
-- =====================================================================

create or replace function public.admin_customers(p_app text, p_segment text default 'all', p_q text default '',
                                                  p_sort text default 'created_at', p_desc boolean default true,
                                                  p_limit integer default 50, p_offset integer default 0)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  q text := lower(btrim(coalesce(p_q, '')));
  qq text;
  lim integer := least(greatest(coalesce(p_limit, 50), 1), 500);
  off integer := greatest(coalesce(p_offset, 0), 0);
  seg text := coalesce(nullif(p_segment, ''), 'all');
  srt text := coalesce(nullif(p_sort, ''), 'created_at');
  allowed text[];
  segs text[];
  d30 timestamptz := now() - interval '30 days';
  rows jsonb;
begin
  perform public.admin_require();
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  qq := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';

  if p_app = 'parent' then
    allowed := array['created_at', 'name', 'state', 'trial_ends_at', 'period_end', 'children', 'linked', 'last_seen',
                     'active_days_30', 'tasks_30', 'approved_30', 'pending_reviews', 'clinic_links'];
    segs := array['all', 'new', 'trial', 'trial_ending', 'premium', 'clinic', 'expired', 'pending', 'inactive', 'at_risk', 'no_child', 'no_device'];
    with f as (
      select fa.id, fa.name, fa.created_at, public.family_access_of(fa.id) as acc,
             (select jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(nullif(p.nickname, ''), p.name), 'email', u.email::text)
                                order by p.created_at)
                from public.profiles p left join auth.users u on u.id = p.id where p.family_id = fa.id) as parents,
             (select count(*) from public.children c where c.family_id = fa.id) as children,
             (select count(*) from public.children c where c.family_id = fa.id and c.user_id is not null) as linked,
             (select max(a.last_seen_at) from public.user_activity a join public.profiles p on p.id = a.user_id
               where p.family_id = fa.id and a.app = 'parent') as last_seen,
             (select count(distinct d.day) from public.activity_days d join public.profiles p on p.id = d.user_id
               where p.family_id = fa.id and d.app = 'parent' and d.day >= d30::date) as active_days_30,
             (select count(*) from public.tasks t where t.family_id = fa.id and t.created_at >= d30) as tasks_30,
             (select count(*) from public.completions c where c.family_id = fa.id and c.status = 'approved' and c.created_at >= d30) as approved_30,
             (select count(*) from public.completions c where c.family_id = fa.id and c.status = 'pending') as pending_reviews,
             (select count(*) from public.clinic_links l where l.family_id = fa.id and l.status = 'active') as clinic_links,
             exists (select 1 from public.push_tokens t join public.profiles p on p.id = t.user_id
                      where p.family_id = fa.id and t.app = 'parent') as push
        from public.families fa
    ), r as (
      select jsonb_build_object(
               'id', f.id, 'name', f.name, 'created_at', f.created_at, 'parents', coalesce(f.parents, '[]'::jsonb),
               'state', f.acc ->> 'state', 'plan', f.acc ->> 'plan', 'trial_ends_at', f.acc -> 'trial_ends_at',
               'days_left', f.acc -> 'days_left', 'period_end', f.acc -> 'period_end', 'auto_renew', f.acc -> 'auto_renew',
               'children', f.children, 'linked', f.linked, 'last_seen', f.last_seen, 'active_days_30', f.active_days_30,
               'tasks_30', f.tasks_30, 'approved_30', f.approved_30, 'pending_reviews', f.pending_reviews,
               'clinic_links', f.clinic_links, 'push', f.push) as j,
             array_remove(array[
               'all',
               case when f.created_at >= now() - interval '7 days' then 'new' end,
               case when f.acc ->> 'state' = 'trial' then 'trial' end,
               case when f.acc ->> 'state' = 'trial' and coalesce((f.acc ->> 'days_left')::int, 99) <= 3 then 'trial_ending' end,
               case when f.acc ->> 'state' = 'premium' then 'premium' end,
               case when f.acc ->> 'state' = 'clinic' then 'clinic' end,
               case when f.acc ->> 'state' = 'expired' then 'expired' end,
               case when f.acc ->> 'state' = 'pending' then 'pending' end,
               case when f.last_seen is null or f.last_seen < now() - interval '14 days' then 'inactive' end,
               case when f.acc ->> 'state' in ('trial', 'premium') and (f.last_seen is null or f.last_seen < now() - interval '7 days') then 'at_risk' end,
               case when f.children = 0 then 'no_child' end,
               case when f.children > 0 and f.linked = 0 then 'no_device' end], null) as tags,
             lower(coalesce(f.name, '') || ' ' || f.id::text || ' ' ||
                   coalesce((select string_agg(coalesce(x ->> 'name', '') || ' ' || coalesce(x ->> 'email', ''), ' ')
                               from jsonb_array_elements(f.parents) x), '')) as hay
        from f
    )
    select jsonb_build_object(
      'total', (select count(*) from r where seg = any(r.tags) and (q = '' or r.hay like qq)),
      'segments', (select jsonb_object_agg(s, (select count(*) from r where s = any(r.tags) and (q = '' or r.hay like qq))) from unnest(segs) s),
      'rows', coalesce((select jsonb_agg(x.j) from (
          select r.j from r where seg = any(r.tags) and (q = '' or r.hay like qq)
           order by case when p_desc then r.j -> srt end desc nulls last, case when not p_desc then r.j -> srt end asc nulls last, r.j ->> 'id'
           limit lim offset off) x), '[]'::jsonb))
      into rows;

  elsif p_app = 'child' then
    allowed := array['created_at', 'name', 'family', 'age_band', 'last_seen', 'active_days_30', 'level', 'coins', 'done_30', 'approved_30'];
    segs := array['all', 'new', 'linked', 'unlinked', 'active_7', 'inactive', 'clinic'];
    with c as (
      select ch.id, ch.name, ch.avatar, ch.age_band, ch.created_at, ch.family_id, fa.name as family, ch.user_id is not null as linked,
             (select a.last_seen_at from public.user_activity a where a.user_id = ch.user_id and a.app = 'child') as last_seen,
             (select a.app_version from public.user_activity a where a.user_id = ch.user_id and a.app = 'child') as app_version,
             (select count(distinct d.day) from public.activity_days d where d.user_id = ch.user_id and d.app = 'child' and d.day >= d30::date) as active_days_30,
             public.child_level(ch.id) as level,
             (select coalesce(sum(l.amount), 0) from public.coin_ledger l where l.child_id = ch.id) as coins,
             (select count(*) from public.completions m where m.child_id = ch.id and m.child_done_at >= d30) as done_30,
             (select count(*) from public.completions m where m.child_id = ch.id and m.status = 'approved' and m.created_at >= d30) as approved_30,
             exists (select 1 from public.clinic_links l where l.child_id = ch.id and l.status = 'active') as clinic,
             (select string_agg(coalesce(u.email::text, '') || ' ' || coalesce(p.nickname, '') || ' ' || coalesce(p.name, ''), ' ')
                from public.profiles p left join auth.users u on u.id = p.id where p.family_id = ch.family_id) as parents_hay
        from public.children ch join public.families fa on fa.id = ch.family_id
    ), r as (
      select jsonb_build_object(
               'id', c.id, 'name', c.name, 'avatar', c.avatar, 'age_band', c.age_band, 'created_at', c.created_at,
               'family_id', c.family_id, 'family', c.family, 'linked', c.linked, 'last_seen', c.last_seen, 'app_version', c.app_version,
               'active_days_30', c.active_days_30, 'level', c.level, 'coins', c.coins, 'done_30', c.done_30,
               'approved_30', c.approved_30, 'clinic', c.clinic) as j,
             array_remove(array[
               'all',
               case when c.created_at >= now() - interval '7 days' then 'new' end,
               case when c.linked then 'linked' else 'unlinked' end,
               case when c.last_seen >= now() - interval '7 days' then 'active_7' end,
               case when c.linked and (c.last_seen is null or c.last_seen < now() - interval '14 days') then 'inactive' end,
               case when c.clinic then 'clinic' end], null) as tags,
             lower(coalesce(c.name, '') || ' ' || coalesce(c.family, '') || ' ' || c.id::text || ' ' || coalesce(c.parents_hay, '')) as hay
        from c
    )
    select jsonb_build_object(
      'total', (select count(*) from r where seg = any(r.tags) and (q = '' or r.hay like qq)),
      'segments', (select jsonb_object_agg(s, (select count(*) from r where s = any(r.tags) and (q = '' or r.hay like qq))) from unnest(segs) s),
      'rows', coalesce((select jsonb_agg(x.j) from (
          select r.j from r where seg = any(r.tags) and (q = '' or r.hay like qq)
           order by case when p_desc then r.j -> srt end desc nulls last, case when not p_desc then r.j -> srt end asc nulls last, r.j ->> 'id'
           limit lim offset off) x), '[]'::jsonb))
      into rows;

  else
    allowed := array['created_at', 'name', 'state', 'trial_ends_at', 'period_end', 'members', 'clients', 'invites_30',
                     'shared_30', 'suggestions_30', 'notes_30', 'last_seen', 'active_days_30'];
    segs := array['all', 'new', 'trial', 'trial_ending', 'paid', 'manual', 'expired', 'no_clients', 'inactive', 'at_risk'];
    with k as (
      select cl.id, cl.name, cl.plan, cl.seat_limit, cl.created_at, cl.trial_ends_at, cl.period_end,
             (select s.source from public.billing_subscriptions s
               where s.clinic_id = cl.id and s.status in ('active', 'canceled') and s.period_end > now()
               order by (s.source = 'manual'), s.period_end desc limit 1) as sub_source,
             (select jsonb_build_object('id', m.id, 'name', m.name, 'email', u.email::text)
                from public.clinicians m left join auth.users u on u.id = m.id
               where m.clinic_id = cl.id order by (m.role <> 'owner'), m.created_at limit 1) as owner,
             (select count(*) from public.clinicians m where m.clinic_id = cl.id) as members,
             (select count(*) from public.clinicians m where m.clinic_id = cl.id and m.verified_at is not null) as verified,
             (select count(distinct l.child_id) from public.clinic_links l where l.clinic_id = cl.id and l.status = 'active') as clients,
             (select count(*) from public.clinic_invites i where i.clinic_id = cl.id and i.kind = 'family' and i.created_at >= d30) as invites_30,
             (select count(*) from public.clinic_invites i where i.clinic_id = cl.id and i.kind = 'family' and i.used_at >= d30) as shared_30,
             (select count(*) from public.clinic_task_suggestions s where s.clinic_id = cl.id and s.created_at >= d30) as suggestions_30,
             (select count(*) from public.clinic_notes n where n.clinic_id = cl.id and n.created_at >= d30) as notes_30,
             (select max(a.last_seen_at) from public.user_activity a join public.clinicians m on m.id = a.user_id
               where m.clinic_id = cl.id and a.app = 'clinic') as last_seen,
             (select count(distinct d.day) from public.activity_days d join public.clinicians m on m.id = d.user_id
               where m.clinic_id = cl.id and d.app = 'clinic' and d.day >= d30::date) as active_days_30,
             (select string_agg(coalesce(m.name, '') || ' ' || coalesce(u.email::text, ''), ' ')
                from public.clinicians m left join auth.users u on u.id = m.id where m.clinic_id = cl.id) as members_hay
        from public.clinics cl
    ), k2 as (
      select k.*, case when k.sub_source is not null and k.sub_source <> 'manual' then 'paid'
                       when k.sub_source = 'manual' then 'manual'
                       when k.plan = 'trial' and k.trial_ends_at > now() then 'trial'
                       when public.clinic_active(k.id) then 'paid'
                       else 'expired' end as state
        from k
    ), r as (
      select jsonb_build_object(
               'id', k2.id, 'name', k2.name, 'plan', k2.plan, 'state', k2.state, 'created_at', k2.created_at,
               'trial_ends_at', k2.trial_ends_at, 'period_end', k2.period_end, 'seat_limit', k2.seat_limit,
               'owner', k2.owner, 'members', k2.members, 'verified', k2.verified, 'clients', k2.clients,
               'invites_30', k2.invites_30, 'shared_30', k2.shared_30, 'suggestions_30', k2.suggestions_30,
               'notes_30', k2.notes_30, 'last_seen', k2.last_seen, 'active_days_30', k2.active_days_30) as j,
             array_remove(array[
               'all',
               case when k2.created_at >= now() - interval '7 days' then 'new' end,
               case when k2.state = 'trial' then 'trial' end,
               case when k2.state = 'trial' and k2.trial_ends_at <= now() + interval '3 days' then 'trial_ending' end,
               case when k2.state = 'paid' then 'paid' end,
               case when k2.state = 'manual' then 'manual' end,
               case when k2.state = 'expired' then 'expired' end,
               case when k2.clients = 0 then 'no_clients' end,
               case when k2.last_seen is null or k2.last_seen < now() - interval '14 days' then 'inactive' end,
               case when k2.state in ('trial', 'paid') and (k2.last_seen is null or k2.last_seen < now() - interval '7 days') then 'at_risk' end], null) as tags,
             lower(coalesce(k2.name, '') || ' ' || k2.id::text || ' ' || coalesce(k2.members_hay, '')) as hay
        from k2
    )
    select jsonb_build_object(
      'total', (select count(*) from r where seg = any(r.tags) and (q = '' or r.hay like qq)),
      'segments', (select jsonb_object_agg(s, (select count(*) from r where s = any(r.tags) and (q = '' or r.hay like qq))) from unnest(segs) s),
      'rows', coalesce((select jsonb_agg(x.j) from (
          select r.j from r where seg = any(r.tags) and (q = '' or r.hay like qq)
           order by case when p_desc then r.j -> srt end desc nulls last, case when not p_desc then r.j -> srt end asc nulls last, r.j ->> 'id'
           limit lim offset off) x), '[]'::jsonb))
      into rows;
  end if;

  if not (srt = any(allowed)) then raise exception 'Geçersiz sıralama: %', srt; end if;
  if not (seg = any(segs)) then raise exception 'Geçersiz kesim: %', seg; end if;
  return rows::json;
end $$;
revoke execute on function public.admin_customers(text, text, text, text, boolean, integer, integer) from public, anon;
grant execute on function public.admin_customers(text, text, text, text, boolean, integer, integer) to authenticated;
