-- =====================================================================
-- Ebeveyn eğitimi sunucuda da kapalı (ÖNERİ, 23 Kasım 2026; kullanıcı kararı 23 Kasım 2026: "eğitimle ilgili özellikler ve
-- içerikler bütün platformlardan kaldırılsın (çalışmaz / görünmez); ileride bir güncellemeyle yeniden açarız"). Tekrar çalıştırılabilir.
-- Bayrak: parent_training (migrations/20261123100000_mercek_updates.sql; satır yoksa KAPALI). Uygulamalar ekranları gizler; bu öneri
-- sunucuyu da kapatır, böylece eski uygulama sürümleri ve doğrudan istekler de eğitime ulaşamaz. Kapsam: uzmanın ebeveyn eğitimi
-- (parent_training*, 9 Kasım) ve Moyo'daki kısa ebeveyn dersleri (parent_lesson*, 5 Kasım; Gelişim › Ben).
--   1. Bildirim: eğitim ve ders bildirimleri (training_assigned, training_mastered, training_reminder, training_activity,
--      lesson_assigned) alıcının bayrağı kapalıyken hiç yazılmaz (anlık bildirim de gitmez); önceden yazılmış olanlar listede ve
--      okunmamış sayısında görünmez (kısıtlayıcı okuma politikası; bayrak açılınca geri gelir).
--   2. Tablolar: on eğitim / ders tablosu istemciye kapalı (kısıtlayıcı politika: okuma da yazma da). Sunucu işlevleri (KVKK
--      dökümü, hesap silme, "kayıtlar ailede kalır") etkilenmez.
--   3. İşlevler: aile ve uzmanın eğitim / ders işlevleri bayrak kapalıyken boş döner ya da reddeder (ipucu feature_off ya da
--      işlevin kendi "bulunamadı" hatası).
--   4. Huni: Moyo Mercek hunisinin "İlk Etkin eğitim" adımı bayrak genelde açık değilken listeden çıkar (kümülatif zincir
--      kırılmasın: sonraki adımlar sıfır okunmasın).
--   5. Yönetim paneli: admin_nudge_stats kuralın bayrağını ve bayrağın genelde açık olup olmadığını döndürür.
-- Yeniden açmak: önce tek kişiye admin_set_user_flag(kullanıcı, 'parent_training', true, …), sonra admin_set_flag('parent_training',
--   true, yüzde, …). Bu dosya geri alınmaz; bayrak açıkken her şey önceki gibi çalışır.
-- Önkoşul (canlıda): 20261105200000_parent_lessons.sql, 20261110100000_parent_trainings.sql, 20261120220000_funnel_analytics.sql,
--   20261120230000_nudge_engine.sql, 20261121100000_security_audit_fixes.sql, 20261123100000_mercek_updates.sql.
-- Sözleşme: sozlesme/admin.md (bayrak parent_training), akislar.md 23 / 22 / 27.4, veritabani.md 41, durumlar.md. Test:
--   test_parent_trainings.sql, test_parent_lessons.sql (bayrak kapalı bölümleri), test_funnel_analytics.sql.
-- =====================================================================

do $$ begin
  if to_regclass('public.parent_trainings') is null or to_regclass('public.parent_lessons') is null then
    raise exception 'Önce ebeveyn dersi ve ebeveyn eğitimi göçleri çalıştırılmalı (20261105200000, 20261110100000)';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'nudge_rules' and column_name = 'feature_flag') then
    raise exception 'Önce migrations/20261123100000_mercek_updates.sql çalıştırılmalı (nudge_rules.feature_flag yok)';
  end if;
end $$;

-- =====================================================================
-- 0. Yardımcılar
-- =====================================================================
-- Çağıran için bayrak (kişiye özel açılış dahil; flag_on ile aynı kural). Politikalarda kullanıldığı için authenticated çağırır;
-- yalnız kendi bayrağını söyler (client_config zaten döndürüyor).
create or replace function public.parent_training_on()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.flag_on(auth.uid(), 'parent_training')
$$;
revoke execute on function public.parent_training_on() from public, anon;
grant execute on function public.parent_training_on() to authenticated;

create or replace function public.parent_training_require()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.parent_training_on() then
    raise exception 'Ebeveyn eğitimi şu an kapalı' using errcode = '42501', hint = 'feature_off';
  end if;
end $$;
revoke execute on function public.parent_training_require() from public, anon, authenticated;

-- Bayrak genelde açık mı (kişiye özel açılış sayılmaz): huni ve panel için
create or replace function public.feature_flag_global(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select f.enabled and f.rollout_pct > 0 from public.feature_flags f where f.key = p_key), false)
$$;
revoke execute on function public.feature_flag_global(text) from public, anon, authenticated;

-- Eğitim / ders bildirim türleri (tek yer)
create or replace function public.parent_training_kinds()
returns text[] language sql immutable set search_path = '' as $$
  select array['training_assigned', 'training_mastered', 'training_reminder', 'training_activity', 'lesson_assigned']
$$;
revoke execute on function public.parent_training_kinds() from public, anon;
grant execute on function public.parent_training_kinds() to authenticated;   -- politika ifadesinde kullanılıyor

-- =====================================================================
-- 1. Bildirim
-- =====================================================================
-- 1.1 Yazılmadan önce: alıcının bayrağı kapalıysa satır yazılmaz (anlık bildirim de gitmez; notifications_push AFTER INSERT)
create or replace function public.notifications_feature_gate() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = any (public.parent_training_kinds()) and not public.flag_on(new.user_id, 'parent_training') then
    return null;
  end if;
  return new;
end $$;
revoke execute on function public.notifications_feature_gate() from public, anon, authenticated;
drop trigger if exists notifications_feature_gate on public.notifications;
create trigger notifications_feature_gate before insert on public.notifications
  for each row execute function public.notifications_feature_gate();

-- 1.2 Önceden yazılmış olanlar: bayrak kapalıyken listede, okunmamış sayısında ve canlı akışta görünmez
drop policy if exists "bildirim: kapalı özellik görünmez" on public.notifications;
create policy "bildirim: kapalı özellik görünmez" on public.notifications as restrictive for select to authenticated
  using (not (kind = any (public.parent_training_kinds())) or public.parent_training_on());

-- =====================================================================
-- 2. Tablolar: bayrak kapalıyken istemciye kapalı (okuma ve yazma)
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['parent_trainings', 'parent_training_modules', 'parent_training_tasks', 'parent_training_logs',
                           'parent_training_todos', 'parent_training_data', 'parent_lessons', 'parent_lesson_assignments',
                           'parent_lesson_progress', 'parent_lesson_practice'] loop
    execute format('drop policy if exists %I on public.%I', 'eğitim: bayrak kapalıyken kapalı', t);
    execute format('create policy %I on public.%I as restrictive for all to authenticated '
                   'using (public.parent_training_on()) with check (public.parent_training_on())',
                   'eğitim: bayrak kapalıyken kapalı', t);
  end loop;
end $$;

-- =====================================================================
-- 3. İşlevler
-- =====================================================================
-- 3.1 Yetki yardımcıları (önceki tanımlar: migrations/20261110100000_parent_trainings.sql, 20261105200000_parent_lessons.sql;
--     yalnız bayrak eklendi). family_training_log / family_training_module_complete / family_training_todo_set
--     training_family_actor ile, clinic_training_remind training_clinic_mine ile, family_lessons ve parent_lesson_* da
--     parent_lesson_require ile yetki denetler: bayrak kapalıyken hepsi reddeder.
create or replace function public.training_family_actor(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.parent_training_on()
     and exists (select 1 from public.parent_trainings t
                 where t.id = p_training and t.status = 'active' and public.family_link_active(t.link_id)
                   and (t.parent_id is null or t.parent_id = auth.uid()))
$$;

create or replace function public.training_clinic_mine(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.parent_training_on()
     and exists (select 1 from public.parent_trainings t
                 where t.id = p_training and t.link_id is not null and t.clinic_id is not null
                   and t.clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_mine(t.link_id))
$$;

create or replace function public.parent_lesson_require()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare fam uuid := public.my_family_id();
begin
  if auth.uid() is null or fam is null then
    raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501';
  end if;
  perform public.parent_training_require();
  return fam;
end $$;

-- 3.2 Ailenin eğitim listeleri: bayrak kapalıyken boş (önceki tanımlar: 20261110100000_parent_trainings.sql,
--     20261120200000_family_keeps_records.sql; yalnız son koşul eklendi)
create or replace function public.family_trainings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x->>'started_at' desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', t.id, 'link_id', t.link_id, 'child_id', l.child_id, 'child_name', c.name, 'title', t.title, 'status', t.status,
      'started_at', t.started_at, 'activated_at', t.activated_at, 'mastered_at', t.mastered_at,
      'parent_id', t.parent_id, 'parent_name', t.parent_name, 'mine', (t.parent_id is null or t.parent_id = auth.uid()),
      'modules', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'item_key', m.item_key, 'position', m.position,
                  'completed_at', m.completed_at, 'correct', m.correct, 'total', m.total, 'answers', m.answers) order by m.position, m.created_at)
                  from public.parent_training_modules m where m.training_id = t.id and not m.archived), '[]'::jsonb),
      'tasks', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'title', k.title, 'description', k.description,
                  'measure', k.measure, 'position', k.position) order by k.position, k.created_at)
                  from public.parent_training_tasks k where k.training_id = t.id and not k.archived), '[]'::jsonb),
      'logs', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'task_id', g.task_id, 'day', g.day, 'count', g.count,
                  'successes', g.successes, 'attempts', g.attempts, 'minutes', g.minutes, 'reflection', g.reflection,
                  'created_by', g.created_by, 'created_at', g.created_at) order by g.day desc, g.created_at desc)
                  from public.parent_training_logs g where g.training_id = t.id and g.day >= current_date - 120), '[]'::jsonb),
      'todos', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'title', d.title, 'description', d.description,
                  'done_at', d.done_at, 'rating', d.rating, 'reflection', d.reflection, 'created_at', d.created_at) order by d.position, d.created_at)
                  from public.parent_training_todos d where d.training_id = t.id and not d.archived), '[]'::jsonb)
    ) as x
    from public.parent_trainings t
    join public.clinic_links l on l.id = t.link_id
    left join public.children c on c.id = l.child_id
    where t.status <> 'draft' and l.status = 'active' and l.family_id = public.my_family_id()
      and public.parent_training_on()
  ) s
$$;
revoke execute on function public.family_trainings() from public, anon;
grant execute on function public.family_trainings() to authenticated;

create or replace function public.family_kept_trainings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x->>'detached_at' desc, x->>'started_at' desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', t.id, 'link_id', t.link_id, 'child_id', t.child_id, 'child_name', c.name, 'title', t.title, 'status', t.status,
      'started_at', t.started_at, 'activated_at', t.activated_at, 'mastered_at', t.mastered_at, 'detached_at', t.detached_at,
      'parent_id', t.parent_id, 'parent_name', t.parent_name, 'mine', (t.parent_id is null or t.parent_id = auth.uid()),
      'modules', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'item_key', m.item_key, 'position', m.position,
                  'completed_at', m.completed_at, 'correct', m.correct, 'total', m.total, 'answers', m.answers) order by m.position, m.created_at)
                  from public.parent_training_modules m where m.training_id = t.id and not m.archived), '[]'::jsonb),
      'tasks', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'title', k.title, 'description', k.description,
                  'measure', k.measure, 'position', k.position) order by k.position, k.created_at)
                  from public.parent_training_tasks k where k.training_id = t.id and not k.archived), '[]'::jsonb),
      'logs', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'task_id', g.task_id, 'day', g.day, 'count', g.count,
                  'successes', g.successes, 'attempts', g.attempts, 'minutes', g.minutes, 'reflection', g.reflection,
                  'created_by', g.created_by, 'created_at', g.created_at) order by g.day desc, g.created_at desc)
                  from public.parent_training_logs g where g.training_id = t.id), '[]'::jsonb),
      'todos', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'title', d.title, 'description', d.description,
                  'done_at', d.done_at, 'rating', d.rating, 'reflection', d.reflection, 'created_at', d.created_at) order by d.position, d.created_at)
                  from public.parent_training_todos d where d.training_id = t.id and not d.archived), '[]'::jsonb)
    ) as x
    from public.parent_trainings t
    left join public.children c on c.id = t.child_id
    where t.link_id is null and t.status <> 'draft' and t.family_id = public.my_family_id()
      and public.parent_training_on()
  ) s
$$;
revoke execute on function public.family_kept_trainings() from public, anon;
grant execute on function public.family_kept_trainings() to authenticated;

-- 3.3 Uzmanın ders işlevleri (önceki tanım: 20261105200000_parent_lessons.sql; yalnız ilk satırdaki bayrak denetimi eklendi)
create or replace function public.clinic_parent_lessons(p_link_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.parent_training_on() then return '[]'::jsonb; end if;                 -- bayrak kapalı: boş liste
  if not public.clinician_access() or not public.clinic_link_visible(p_link_id) then
    raise exception 'Paylaşım bulunamadı' using hint = 'link_not_visible';
  end if;
  if not public.clinic_link_open(p_link_id) then return '[]'::jsonb; end if;   -- bitmiş paylaşım: tablo politikası gibi boş
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'lesson_key', a.lesson_key, 'title', l.title, 'note', a.note, 'status', a.status,
      'created_at', a.created_at, 'withdrawn_at', a.withdrawn_at,
      'parents', coalesce((
        select jsonb_agg(jsonb_build_object(
          'name', coalesce(nullif(pr.nickname, ''), 'Ebeveyn'), 'status', p.status, 'opened', p.opened_at is not null,
          'days', coalesce((select jsonb_agg(x.day order by x.day) from public.parent_lesson_practice x
                            where x.user_id = p.user_id and x.lesson_key = a.lesson_key
                              and x.day >= (a.created_at at time zone 'Europe/Istanbul')::date
                              and (a.withdrawn_at is null or x.day <= (a.withdrawn_at at time zone 'Europe/Istanbul')::date)), '[]'))
          order by pr.created_at)
        from public.parent_lesson_progress p
        join public.profiles pr on pr.id = p.user_id
        where p.family_id = a.family_id and p.lesson_key = a.lesson_key
          and (p.assignment_id = a.id or p.started_at >= a.created_at)
          and exists (select 1 from public.clinic_links k where k.id = a.link_id and k.status = 'active')), '[]'))
      order by a.created_at desc)
    from public.parent_lesson_assignments a
    join public.parent_lessons l on l.key = a.lesson_key
    where a.link_id = p_link_id), '[]');
end $$;
revoke execute on function public.clinic_parent_lessons(uuid) from public, anon;
grant execute on function public.clinic_parent_lessons(uuid) to authenticated;

create or replace function public.clinic_assign_lesson(p_link_id uuid, p_key text, p_note text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  t text;
  rid uuid;
begin
  perform public.parent_training_require();
  if not public.clinician_access() or not public.clinic_link_mine(p_link_id) then
    raise exception 'Paylaşım bulunamadı' using hint = 'link_not_visible';
  end if;
  select * into l from public.clinic_links where id = p_link_id;
  if l.status <> 'active' then raise exception 'Paylaşım etkin değil' using hint = 'link_not_active'; end if;
  select title into t from public.parent_lessons where key = p_key and status = 'published';
  if t is null then raise exception 'Ders bulunamadı' using hint = 'lesson_not_found'; end if;
  select id into rid from public.parent_lesson_assignments where link_id = p_link_id and lesson_key = p_key and status = 'active';
  if rid is not null then
    update public.parent_lesson_assignments set note = left(coalesce(p_note, ''), 300) where id = rid;
    return rid;
  end if;
  insert into public.parent_lesson_assignments (clinic_id, link_id, family_id, lesson_key, note, assigned_by)
  values (l.clinic_id, l.id, l.family_id, p_key, left(coalesce(p_note, ''), 300), auth.uid())
  returning id into rid;
  -- ebeveyn bu dersi zaten yapıyorsa uzman ilerlemeyi görsün diye bağla
  update public.parent_lesson_progress set assignment_id = rid
   where family_id = l.family_id and lesson_key = p_key and assignment_id is null;
  perform public.notify_parents(l.family_id, 'lesson_assigned', 'Uzmanın sana bir ders önerdi',
    t || ' · Gelişim › Ben bölümünde.', jsonb_build_object('assignment_id', rid, 'lesson_key', p_key, 'link_id', l.id), l.child_id);
  return rid;
end $$;
revoke execute on function public.clinic_assign_lesson(uuid, text, text) from public, anon;
grant execute on function public.clinic_assign_lesson(uuid, text, text) to authenticated;

create or replace function public.clinic_withdraw_lesson(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare lk uuid;
begin
  perform public.parent_training_require();
  select link_id into lk from public.parent_lesson_assignments where id = p_id and status = 'active';
  if lk is null or not public.clinician_access() or not public.clinic_link_mine(lk) then
    raise exception 'Öneri bulunamadı' using hint = 'assignment_not_found';
  end if;
  update public.parent_lesson_assignments set status = 'withdrawn', withdrawn_at = now() where id = p_id;
end $$;
revoke execute on function public.clinic_withdraw_lesson(uuid) from public, anon;
grant execute on function public.clinic_withdraw_lesson(uuid) to authenticated;

-- =====================================================================
-- 4. Huni: "İlk Etkin eğitim" yalnız bayrak genelde açıkken (önceki tanım: 20261120220000_funnel_analytics.sql; adımlar aynı,
--    first_training koşullu; okuma tablosu olduğu için immutable → stable)
-- =====================================================================
create or replace function public.funnel_step_defs(p_product text)
returns table (ord integer, key text, label text, cohort boolean)
language sql stable security definer set search_path = '' as $$
  select v.ord, v.key, v.label, v.cohort from (values
    ('parent', 1, 'store_impression', 'App Store gösterimi', false),
    ('parent', 2, 'store_page_view', 'Ürün sayfası görüntüleme', false),
    ('parent', 3, 'store_download', 'İndirme', false),
    ('parent', 4, 'signup', 'Kayıt (aile açıldı)', true),
    ('parent', 5, 'email_verified', 'E-posta onaylandı', true),
    ('parent', 6, 'child_added', 'Çocuk eklendi', true),
    ('parent', 7, 'game_linked', 'Moyo Oyun bağlandı', true),
    ('parent', 8, 'first_routine', 'İlk rutin / adım', true),
    ('parent', 9, 'first_done', 'Çocuğun ilk "Yaptım"ı', true),
    ('parent', 10, 'first_approved', 'İlk ebeveyn onayı', true),
    ('parent', 11, 'active_d7', 'İkinci haftada etkin (7–13. gün)', true),
    ('parent', 12, 'trial_end', 'Deneme bitti', true),
    ('parent', 13, 'paid', 'İlk ücretli dönem', true),
    ('parent', 14, 'renewed', 'Yenileme (ikinci dönem)', true),
    ('clinic', 1, 'store_impression', 'App Store gösterimi', false),
    ('clinic', 2, 'store_page_view', 'Ürün sayfası görüntüleme', false),
    ('clinic', 3, 'store_download', 'İndirme', false),
    ('clinic', 4, 'signup', 'Kayıt (uzman)', true),
    ('clinic', 5, 'survey_done', 'Karşılama anketi', true),
    ('clinic', 6, 'first_invite', 'İlk aile daveti', true),
    ('clinic', 7, 'family_linked', 'İlk aile bağlandı (paylaşım)', true),
    ('clinic', 8, 'first_training', 'İlk Etkin eğitim', true),
    ('clinic', 9, 'active_w2', 'İkinci haftada etkin (7–13. gün)', true),
    ('clinic', 10, 'trial_end', 'Deneme bitti', true),
    ('clinic', 11, 'paid', 'İlk ücretli dönem', true),
    ('clinic', 12, 'renewed', 'Yenileme (ikinci dönem)', true)
  ) v(product, ord, key, label, cohort)
  where v.product = p_product
    and (v.key <> 'first_training' or public.feature_flag_global('parent_training'))
  order by v.ord
$$;
revoke execute on function public.funnel_step_defs(text) from public, anon, authenticated;

create or replace function public.funnel_depth(p_product text, p_steps jsonb)
returns integer language plpgsql stable set search_path = '' as $$
declare
  d record;
  last integer := 0;
begin
  for d in select * from public.funnel_step_defs(p_product) x where x.cohort order by x.ord loop
    exit when not coalesce(p_steps ? d.key, false);
    last := d.ord;
  end loop;
  return last;
end $$;
revoke execute on function public.funnel_depth(text, jsonb) from public, anon, authenticated;

-- =====================================================================
-- 5. Yönetim paneli: bildirim kuralı istatistiklerinde bayrak (önceki tanım: 20261120230000_nudge_engine.sql; iki alan eklendi)
-- =====================================================================
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
            'feature_flag', r.feature_flag,
            'flag_on', r.feature_flag is null or public.feature_flag_global(r.feature_flag),
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
revoke execute on function public.admin_nudge_stats(text, date, date) from public, anon;
grant execute on function public.admin_nudge_stats(text, date, date) to authenticated;
