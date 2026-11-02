-- =====================================================================
-- ClinicApp "Tüm danışanlar" dikkat panosu (kullanıcı kararı 2 Kasım 2026: "liste + neden"; benchmark ve seçim DURUM.md
-- Açık işler › TAKİP PLANI). Danışan başına tek satır, yalnız OLGU söyleyen nedenler; puan, renkli risk ve sıralama yok.
--
--   clinic_attention_summary(): uzmanın görebildiği her etkin paylaşım için sayılar ve son olay zamanları (salt okunur).
--     Erişim kuralı clinic_clients ile aynı: kendi kliniği, etkin paylaşım, üyelik açık (clinician_access), ekip içi görünürlük
--     (clinic_link_visible). Sayılar ailenin uzmana zaten açık kayıtlarından (görev tamamlama, davranış kaydı, program uygulaması,
--     öneri kararı) ve uzmanın kendi planından; yeni kişisel veri yok, metin yok (yalnız sayı ve zaman).
--   ClinicApp bölümleri: Senin sıran (gönderilmemiş taslak/plan değişikliği, değerlendirme zamanı), Aileden yeni (son 7 günün
--     davranış kaydı ve öneri kararı; "Gördüm" cihazda), Sessiz kalanlar (ailenin son kaydından bu yana 7+ gün).
--   "Değerlendirme zamanı" ClinicApp planCore.reviewDue ile aynı kural: süren hedefte son değerlendirmeden (yoksa eklenişten)
--     28 gün, ya da süre doldu ve son haftasında değerlendirilmedi.
--
-- Veritabanı tablosu değişmez. Tekrar çalıştırılabilir. Supabase'e uygulandı (2 Kasım 2026, kullanıcı).
-- =====================================================================

create or replace function public.clinic_attention_summary()
returns table (
  link_id           uuid,
  last_family_at    timestamptz,   -- ailenin son kaydı (görev "yaptım"/onay, davranış kaydı, program uygulaması, öneri kararı)
  done_7d           integer,       -- son 7 günde "yaptım" ya da onay alan görev günü
  abc_7d            integer,       -- son 7 günde girilen davranış kaydı
  abc_last_at       timestamptz,
  logs_7d           integer,       -- son 7 günde program uygulama kaydı
  decided_7d        integer,       -- son 7 günde ebeveynin karar verdiği öneri
  decided_last_at   timestamptz,
  pending           integer,       -- ebeveyn kararı bekleyen öneri
  drafts            integer,       -- gönderilmemiş taslak (rutin paketi ya da tek öneri sayısı)
  plan_unsent       integer,       -- gönderilmiş sürümden farklı hedef/program
  goals_active      integer,       -- süren hedef
  review_due        integer,       -- değerlendirme zamanı gelmiş hedef
  plan_published_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  with ls as (
    select l.id, l.child_id, l.plan_published_at
      from public.clinic_links l
     where l.clinic_id = public.my_clinic_id() and l.status = 'active' and public.clinician_access()
       and public.clinic_link_visible(l.id)
  ),
  d as (select (now() at time zone 'Europe/Istanbul')::date as today, now() - interval '7 days' as since)
  select ls.id,
         nullif(greatest(coalesce(c.last_at, '-infinity'), coalesce(a.last_at, '-infinity'),
                         coalesce(g.last_at, '-infinity'), coalesce(s.decided_last_at, '-infinity')), '-infinity'::timestamptz),
         coalesce(c.n7, 0), coalesce(a.n7, 0), a.last_at, coalesce(g.n7, 0),
         coalesce(s.decided_7d, 0), s.decided_last_at, coalesce(s.pending, 0), coalesce(s.drafts, 0),
         coalesce(pg.n, 0) + coalesce(pm.n, 0), coalesce(gs.active, 0), coalesce(gs.due, 0),
         ls.plan_published_at
    from ls cross join d
    left join lateral (
      select max(greatest(x.created_at, coalesce(x.child_done_at, x.created_at), coalesce(x.reviewed_at, x.created_at))) as last_at,
             count(*) filter (where greatest(coalesce(x.child_done_at, x.created_at), coalesce(x.reviewed_at, x.created_at)) >= d.since)::integer as n7
        from public.completions x where x.child_id = ls.child_id
    ) c on true
    left join lateral (
      select max(x.created_at) as last_at, count(*) filter (where x.created_at >= d.since)::integer as n7
        from public.abc_events x where x.child_id = ls.child_id
    ) a on true
    left join lateral (
      select max(x.created_at) as last_at, count(*) filter (where x.created_at >= d.since)::integer as n7
        from public.care_module_logs x join public.care_modules m on m.id = x.module_id where m.link_id = ls.id
    ) g on true
    left join lateral (
      select max(x.decided_at) filter (where x.status in ('accepted', 'declined')) as decided_last_at,
             count(*) filter (where x.status in ('accepted', 'declined') and x.decided_at >= d.since)::integer as decided_7d,
             count(*) filter (where x.status = 'pending')::integer as pending,
             count(distinct coalesce(x.routine_group, x.id)) filter (where x.status = 'draft')::integer as drafts
        from public.clinic_task_suggestions x where x.link_id = ls.id
    ) s on true
    -- gönderilmiş sürümden farklı hedef/program: care_plan_snapshot_hold'un yazacağı hâl ile pub karşılaştırılır
    left join lateral (
      select count(*)::integer as n from public.clinic_goals x
       where x.link_id = ls.id and (case when x.shared and not x.archived then jsonb_build_object(
               'title', x.title, 'description', x.description, 'domain', x.domain, 'measure', x.measure, 'baseline', x.baseline,
               'target', x.target, 'weeks', x.weeks, 'home_support', x.home_support, 'status', x.status, 'position', x.position) end)
             is distinct from x.pub
    ) pg on true
    left join lateral (
      select count(*)::integer as n from public.care_modules m
       where m.link_id = ls.id and (case when m.status <> 'planned' then jsonb_build_object(
               'title', m.title, 'aim', m.aim, 'practice', m.practice, 'checklist', m.checklist, 'status', m.status, 'position', m.position,
               'goal_ids', coalesce((select jsonb_agg(y.goal_id order by gg.position, gg.created_at)
                                       from public.care_module_goals y join public.clinic_goals gg on gg.id = y.goal_id
                                      where y.module_id = m.id and gg.pub is not null), '[]'::jsonb)) end)
             is distinct from m.pub
    ) pm on true
    left join lateral (
      select count(*)::integer as active,
             count(*) filter (where
               coalesce(r.last_week, (x.created_at at time zone 'UTC')::date) <= d.today - 28
               or (x.weeks is not null and d.today >= (x.created_at at time zone 'UTC')::date + x.weeks * 7
                   and (r.last_week is null or r.last_week < (x.created_at at time zone 'UTC')::date + x.weeks * 7 - 7)))::integer as due
        from public.clinic_goals x
        left join lateral (select max(w.week) as last_week from public.goal_ratings w where w.goal_id = x.id) r on true
       where x.link_id = ls.id and x.status = 'active' and not x.archived
    ) gs on true
$$;
revoke execute on function public.clinic_attention_summary() from public, anon;
grant execute on function public.clinic_attention_summary() to authenticated;
