-- =====================================================================
-- Huni analitiği, abonelik sağlığı ve kıyas (benchmark) tabloları (ÖNERİ, 20 Kasım 2026; uygulanmadı)
--   Kullanıcı isteği (20 Kasım 2026): "Admin panelde funnel geliştirme, takip, yüzdelik analiz; uygulama içinde hangi
--   pencereden / aksiyondan kim ne oldu da neden çıktı; App Store'u görmekten ödemeye kadar nerede düşüldüğü; abonelik
--   sağlığı ve global benchmark'lar." Sözleşme: sozlesme/admin.md "Huni, abonelik sağlığı, kıyas", veritabani.md 35.
--
--   admin_funnel(ürün, başlangıç, bitiş)            her admin rolü okur: adım sayıları, %'ler, medyan süre, çıkış ekranları,
--                                                   iptal nedenleri, kpis {anahtar: {value, n}}
--   admin_funnel_people(ürün, adım, başlangıç, bitiş, limit)  yalnız owner / support: o adımda kalanlar (ad, e-posta,
--                                                   çocuk adı YOK; id_short = kimliğin ilk 8 karakteri, id = kart için)
--   admin_subscription_health(ürün, başlangıç, bitiş) her admin rolü okur: aktif ücretli, deneme, kayıp, yenileme, iade,
--                                                   ödeme sorunu, MRR (aylık eşdeğer, KDV dahil brüt), plan ve hafta kırılımı
--   admin_benchmarks() / admin_benchmark_set(…)     kıyas değerleri (yalnız iç karşılaştırma; pazarlamada kullanılmaz, hukuk/45)
--   admin_store_funnel_set(…)                       App Store Connect günlük gösterim / ürün sayfası / indirme (owner, elle)
--
--   Kohort: Moyo (parent) = aile (families.created_at), Moyo Mercek (clinic) = uzman (clinicians.created_at); tarih
--   sınırları mevcut admin_kpi_funnel ile aynı (gün başı sunucu saati). Adımlar birbirinden bağımsız sayılır ("o adıma
--   ulaşan"); pct_of_prev = bir önceki adımın sayısına oran. Zamanı tahmin olan adımlar SQL'de ve admin.md'de yazılı.
--   Eski admin_kpi_funnel kalır (panel kullanıyor).
--   Fiyat: Moyo Premium app_config.kpi'de (parent_monthly_try 349,99 · parent_yearly_try 3.499,99; ekonomi.md 9);
--   değer 0 ya da yoksa bu dosya yazar, finance / owner admin_set_kpi_config ile değiştirir. Mercek billing_plans'ta.
--   Gizlilik: mesaj, not metni, çocuk adı, puan yok. Hiçbir gösterge tanı ya da puan değildir.
-- Önkoşul: migrations/20261023000000_admin.sql (admin_require, admin_log), 20261022200000_clinic_billing.sql,
--          20261110100000_parent_trainings.sql. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tablolar (istemciye kapalı: RLS açık, politika yok)
-- ---------------------------------------------------------------------
create table if not exists public.store_funnel_daily (
  product      text not null check (product in ('parent', 'clinic')),
  day          date not null,
  impressions  integer check (impressions >= 0),
  page_views   integer check (page_views >= 0),
  downloads    integer check (downloads >= 0),
  source       text not null default 'manual' check (source in ('manual', 'import')),
  updated_by   uuid references auth.users (id) on delete set null,
  updated_at   timestamptz not null default now(),
  primary key (product, day)
);
alter table public.store_funnel_daily enable row level security;
revoke all on public.store_funnel_daily from anon, authenticated;

-- Kıyas değerleri. low / high sayısal alt / üst sınırdır (iyi / kötü değil); "iyi" yönü better ('high' = büyük iyi,
-- 'low' = küçük iyi: kayıp, iade, ödeme sorunu). label / unit / better verilmezse anahtarın sabit eşlemesinden gelir
-- (kpi_benchmark_meta; tetikleyici kpi_benchmarks_fill). Satırları koordinatör ayrı seed dosyasıyla girer.
create table if not exists public.kpi_benchmarks (
  key         text not null check (key ~ '^[a-z][a-z0-9_]{1,59}$'),
  product     text not null check (product in ('parent', 'clinic')),
  label       text not null check (char_length(label) between 1 and 120),
  value       numeric,
  low         numeric,
  high        numeric,
  unit        text not null check (unit in ('%', 'TRY', 'days', 'hours', 'count')),
  better      text not null check (better in ('high', 'low')),
  source      text not null default '' check (char_length(source) <= 300),
  source_url  text check (source_url is null or (source_url ~ '^https://' and char_length(source_url) <= 500)),
  as_of       text check (char_length(as_of) <= 40),
  note        text check (char_length(note) <= 500),
  updated_at  timestamptz not null default now(),
  primary key (key, product),
  check (low is null or high is null or low <= high)
);
alter table public.kpi_benchmarks enable row level security;
revoke all on public.kpi_benchmarks from anon, authenticated;

-- Moyo Premium fiyatı (KPI hesabı için; asıl satış fiyatı App Store'da). Elle girilmiş değer korunur.
update public.app_config
   set value = value || jsonb_build_object('parent_monthly_try', 349.99), updated_at = now()
 where key = 'kpi' and coalesce((value ->> 'parent_monthly_try')::numeric, 0) = 0;
update public.app_config
   set value = value || jsonb_build_object('parent_yearly_try', 3499.99), updated_at = now()
 where key = 'kpi' and coalesce((value ->> 'parent_yearly_try')::numeric, 0) = 0;

-- ---------------------------------------------------------------------
-- 2. Adım tanımları (anahtarlar sabit; panel ve kıyas aynı adları kullanır)
-- ---------------------------------------------------------------------
create or replace function public.funnel_step_defs(p_product text)
returns table (ord integer, key text, label text, cohort boolean)
language sql immutable set search_path = '' as $$
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
  order by v.ord
$$;

-- Bir ailenin adımlarına ulaştığı ilk zamanlar ({adım: zaman}; ulaşılmayan adım yok). p_now'dan sonrası sayılmaz.
--   email_verified: aileyi açanın e-posta onayı (yoksa ailedeki ilk onay, yoksa deneme başlangıcı)
--   game_linked: bağlı çocuk cihazı; zaman tahmini = çocuk satırı ile oyunun anonim hesabından geç olanı (bağlanma anı tutulmuyor)
--   first_done: çocuğun ilk işareti (child_done_at; "Yapamam" sayılmaz) · first_approved: ebeveynin onayı (reviewed_by dolu)
--   active_d7: ebeveynlerden birinin kayıttan 7–13 gün sonra etkin günü (activity_days)
--   trial_end: denemenin sonu geçti (families.trial_days / billing.trial_days + davet ödülü bonus_until; family_access_of ile aynı)
--   paid: mağaza aboneliğinin başlangıcı (family_subscriptions.started_at; source store / web, elle verilen sayılmaz)
--   renewed: TAHMİN — aile aboneliğinin geçmişi tutulmadığı için dönem sonu ilk dönemi aşmışsa (aylıkta başlangıç + 2 ay − 3 gün,
--            yıllıkta + 2 yıl − 3 gün; Apple ek süresi yanılmasın diye) yenilenmiş sayılır; zaman = başlangıç + 1 dönem.
create or replace function public.funnel_parent_steps(p_family uuid, p_now timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  t timestamptz := coalesce(p_now, now());
  cfg jsonb := public.billing_config();
  f public.families%rowtype;
  s public.family_subscriptions%rowtype;
  d0 date;
  te timestamptz;
  per interval;
  r jsonb;
begin
  select * into f from public.families where id = p_family;
  if not found then return null; end if;
  d0 := f.created_at::date;
  r := jsonb_build_object(
    'signup', f.created_at,
    'email_verified', coalesce((select u.email_confirmed_at from auth.users u where u.id = f.created_by),
                               (select min(u.email_confirmed_at) from public.profiles p join auth.users u on u.id = p.id
                                 where p.family_id = p_family),
                               f.trial_started_at),
    'child_added', (select min(c.created_at) from public.children c where c.family_id = p_family),
    'game_linked', (select min(greatest(c.created_at, coalesce(u.created_at, c.created_at)))
                      from public.children c left join auth.users u on u.id = c.user_id
                     where c.family_id = p_family and c.user_id is not null),
    'first_routine', (select min(x.created_at) from public.tasks x where x.family_id = p_family),
    'first_done', (select min(x.child_done_at) from public.completions x
                    where x.family_id = p_family and x.child_done_at is not null and x.status <> 'declined'),
    'first_approved', (select min(coalesce(x.reviewed_at, x.created_at)) from public.completions x
                        where x.family_id = p_family and x.status = 'approved' and x.reviewed_by is not null),
    'active_d7', (select min(d.day)::timestamptz from public.activity_days d join public.profiles p on p.id = d.user_id
                   where p.family_id = p_family and d.app = 'parent' and d.day between d0 + 7 and d0 + 13));
  if f.trial_started_at is not null then
    te := f.trial_started_at + make_interval(days => coalesce(f.trial_days::int, (cfg ->> 'trial_days')::int));
    if f.bonus_until is not null and f.bonus_until > te then te := f.bonus_until; end if;
    r := r || jsonb_build_object('trial_end', te);
  end if;
  select * into s from public.family_subscriptions
   where family_id = p_family and source in ('store', 'web') and started_at is not null;
  if found then
    per := case when s.billing = 'yearly' then interval '1 year' else interval '1 month' end;
    r := r || jsonb_build_object('paid', s.started_at);
    if s.period_end is not null and s.period_end >= s.started_at + per * 2 - interval '3 days' then
      r := r || jsonb_build_object('renewed', s.started_at + per);
    end if;
  end if;
  return coalesce((select jsonb_object_agg(e.key, e.value) from jsonb_each(r) e
                    where jsonb_typeof(e.value) = 'string' and (e.value #>> '{}')::timestamptz <= t), '{}'::jsonb);
end $$;

-- Bir uzmanın adımları. "Kendi klinikleri" = uzmanın açtığı alanlar (clinics.created_by: kayıtta açılan klinik + bireysel alan).
--   survey_done: atlanmamış karşılama anketi · first_invite: ilk aile daveti (clinic_invites kind family; satırlar silinmez)
--   family_linked: sorumlusu olduğu ya da kendi kliniğindeki ilk paylaşım (clinic_links.created_at)
--   first_training: ilk Etkin eğitim (parent_trainings.activated_at; kendisinin ya da kendi kliniğinin)
--   active_w2: kayıttan 7–13 gün sonra etkin gün · trial_end: kendi kliniklerinin en geç deneme sonu geçti
--   paid: kendi kliniğinde ilk mağaza aboneliği (billing_subscriptions, elle verilen sayılmaz)
--   renewed: RevenueCat RENEWAL olayı (billing_events.payload.type) ya da dönem sonu ilk dönemi aşmış (aile ile aynı tahmin)
create or replace function public.funnel_clinic_steps(p_user uuid, p_now timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  t timestamptz := coalesce(p_now, now());
  m public.clinicians%rowtype;
  owned uuid[];
  d0 date;
  r jsonb;
begin
  select * into m from public.clinicians where id = p_user;
  if not found then return null; end if;
  owned := array(select c.id from public.clinics c where c.created_by = p_user);
  d0 := m.created_at::date;
  r := jsonb_build_object(
    'signup', m.created_at,
    'survey_done', (select s.created_at from public.clinician_surveys s where s.clinician_id = p_user and not s.skipped),
    'first_invite', (select min(i.created_at) from public.clinic_invites i where i.clinician_id = p_user and i.kind = 'family'),
    'family_linked', (select min(l.created_at) from public.clinic_links l
                       where l.clinician_id = p_user or l.clinic_id = any (owned)),
    'first_training', (select min(x.activated_at) from public.parent_trainings x
                        where x.activated_at is not null and (x.created_by = p_user or x.clinic_id = any (owned))),
    'active_w2', (select min(d.day)::timestamptz from public.activity_days d
                   where d.user_id = p_user and d.app = 'clinic' and d.day between d0 + 7 and d0 + 13),
    'trial_end', (select max(c.trial_ends_at) from public.clinics c where c.id = any (owned)),
    'paid', (select min(b.created_at) from public.billing_subscriptions b where b.clinic_id = any (owned) and b.source <> 'manual'),
    'renewed', (select min(coalesce(
                  (select min(e.created_at) from public.billing_events e
                    where e.source = b.source and e.external_id = b.external_id and e.kind = 'apply:active'
                      and e.payload ->> 'type' = 'RENEWAL'),
                  case when b.period_end >= b.created_at + (case when p.period = 'yearly' then interval '1 year' else interval '1 month' end) * 2
                                            - interval '3 days'
                       then b.created_at + case when p.period = 'yearly' then interval '1 year' else interval '1 month' end end))
                  from public.billing_subscriptions b join public.billing_plans p on p.id = b.plan_id
                 where b.clinic_id = any (owned) and b.source <> 'manual'));
  return coalesce((select jsonb_object_agg(e.key, e.value) from jsonb_each(r) e
                    where jsonb_typeof(e.value) = 'string' and (e.value #>> '{}')::timestamptz <= t), '{}'::jsonb);
end $$;

-- Kişinin art arda ulaştığı son adımın sırası (kümülatif huni: bir adım ancak öncekilerin hepsine ulaşıldıysa sayılır)
create or replace function public.funnel_depth(p_product text, p_steps jsonb)
returns integer language plpgsql immutable set search_path = '' as $$
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

-- Kohort: aralıkta açılan aileler / kayıt olan uzmanlar, adımları ve art arda ulaşılan son adımın sırası (depth)
create or replace function public.funnel_cohort(p_product text, p_from date, p_to date, p_now timestamptz default null)
returns table (id uuid, joined_at timestamptz, steps jsonb, depth integer)
language sql stable security definer set search_path = '' as $$
  select x.id, x.joined_at, x.steps, public.funnel_depth(p_product, x.steps) from (
    select f.id, f.created_at as joined_at, public.funnel_parent_steps(f.id, p_now) as steps
      from public.families f
     where p_product = 'parent' and f.created_at >= p_from::timestamptz and f.created_at < (p_to + 1)::timestamptz
    union all
    select m.id, m.created_at, public.funnel_clinic_steps(m.id, p_now)
      from public.clinicians m
     where p_product = 'clinic' and m.created_at >= p_from::timestamptz and m.created_at < (p_to + 1)::timestamptz) x
$$;

-- Kişinin son anlamlı olayı (app.open dışında), son ekranı (screen.*) ve son görülmesi. Aile için ailedeki ebeveynlerin
-- ParentApp olayları, uzman için kendi ClinicApp olayları. Olay adları akislar.md 9; içerik yok.
create or replace function public.funnel_person_trace(p_product text, p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with u as (
    select p.id from public.profiles p where p_product = 'parent' and p.family_id = p_id
    union all
    select p_id where p_product = 'clinic'
  )
  select jsonb_build_object(
    'last_event', (select e.event from public.app_events e
                    where e.user_id in (select id from u) and e.app = p_product and e.event <> 'app.open'
                    order by e.occurred_at desc, e.id desc limit 1),
    'last_screen', (select e.event from public.app_events e
                     where e.user_id in (select id from u) and e.app = p_product and e.event like 'screen.%'
                     order by e.occurred_at desc, e.id desc limit 1),
    'last_seen', (select max(a.last_seen_at) from public.user_activity a where a.user_id in (select id from u) and a.app = p_product))
$$;

-- Uzmanın varsayılan kliniğinin üyelik durumu (admin_customers ile aynı: paid / manual / trial / expired)
create or replace function public.clinic_billing_state(p_clinic uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case when x.src is not null and x.src <> 'manual' then 'paid'
              when x.src = 'manual' then 'manual'
              when c.plan = 'trial' and c.trial_ends_at > now() then 'trial'
              when public.clinic_active(c.id) then 'paid'
              else 'expired' end
    from public.clinics c
    left join lateral (select s.source as src from public.billing_subscriptions s
                        where s.clinic_id = c.id and s.status in ('active', 'canceled') and s.period_end > now()
                        order by (s.source = 'manual'), s.period_end desc limit 1) x on true
   where c.id = p_clinic
$$;

create or replace function public.funnel_kpi(p_num numeric, p_den numeric)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('value', case when coalesce(p_den, 0) > 0 then round(coalesce(p_num, 0) * 100.0 / p_den, 1) end,
                            'n', coalesce(p_den, 0)::bigint)
$$;

create or replace function public.funnel_check_args(p_product text, p_from date, p_to date)
returns void language plpgsql immutable set search_path = '' as $$
begin
  if p_product is null or p_product not in ('parent', 'clinic') then raise exception 'Geçersiz ürün (parent / clinic)'; end if;
  if p_from is null or p_to is null or p_to < p_from then raise exception 'Tarih aralığı geçersiz'; end if;
  if p_to - p_from > 366 then raise exception 'Tarih aralığı en çok 1 yıl'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. Huni (her admin rolü)
-- ---------------------------------------------------------------------
create or replace function public.admin_funnel(p_product text, p_from date, p_to date)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  a timestamptz := p_from;
  b timestamptz := p_to + 1;
  imp bigint; pv bigint; dl bigint; nrow bigint;
  act_step text; act_days integer;
  res json;
begin
  perform public.admin_require();
  perform public.funnel_check_args(p_product, p_from, p_to);
  select sum(s.impressions), sum(s.page_views), sum(s.downloads), count(*) into imp, pv, dl, nrow
    from public.store_funnel_daily s where s.product = p_product and s.day between p_from and p_to;
  act_step := case when p_product = 'parent' then 'first_approved' else 'family_linked' end;
  act_days := case when p_product = 'parent' then 7 else 14 end;

  with c as materialized (
    select * from public.funnel_cohort(p_product, p_from, p_to)
  ), d as (
    select x.*,
           (select y.key from public.funnel_step_defs(p_product) y where y.cohort and y.ord < x.ord order by y.ord desc limit 1) as prev,
           (select y.key from public.funnel_step_defs(p_product) y where y.cohort and y.ord > x.ord order by y.ord limit 1) as next
      from public.funnel_step_defs(p_product) x
  ), cnt as (
    select d.ord, d.key, d.label, d.cohort, d.prev, d.next,
           case d.key when 'store_impression' then imp when 'store_page_view' then pv when 'store_download' then dl
                else case when d.cohort then (select count(*) from c where c.depth >= d.ord) end end as n
      from d
  ), base as (
    select cnt.*,
           (select x.n from cnt x where x.n is not null and x.n > 0 order by x.ord limit 1) as first_n,
           (select x.n from cnt x where x.ord < cnt.ord and x.n is not null order by x.ord desc limit 1) as prev_n,
           case
             when not cnt.cohort and cnt.n is null then 'App Store verisi girilmedi (admin_store_funnel_set)'
             when cnt.key in ('active_d7', 'active_w2') and exists (select 1 from c where c.joined_at > now() - interval '14 days')
               then 'Son 14 günde katılan ' || (select count(*) from c where c.joined_at > now() - interval '14 days')
                    || ' kişi bu adıma henüz ulaşamaz'
             when cnt.key = 'renewed' and p_product = 'parent' then 'Tahmin: aile aboneliğinin dönem sonundan'
           end as note
      from cnt
  ), tr as materialized (
    select c.id, c.depth, public.funnel_person_trace(p_product, c.id) as t from c
  )
  select json_build_object(
    'product', p_product, 'from', p_from, 'to', p_to,
    'cohort_size', (select count(*) from c),
    'store', case when nrow > 0 then json_build_object('impressions', imp, 'page_views', pv, 'downloads', dl) end,
    'steps', (select json_agg((jsonb_build_object(
                'key', base.key, 'label', base.label, 'count', base.n,
                'pct_of_first', case when base.n is not null and base.first_n > 0 then round(base.n * 100.0 / base.first_n, 1) end,
                'pct_of_prev', case when base.n is not null and base.prev_n > 0 then round(base.n * 100.0 / base.prev_n, 1) end,
                'median_hours_from_prev', case when base.cohort and base.prev is not null then (
                    select round((percentile_cont(0.5) within group (order by greatest(0, extract(epoch from
                             (c.steps ->> base.key)::timestamptz - (c.steps ->> base.prev)::timestamptz)) / 3600))::numeric, 1)
                      from c where c.depth >= base.ord) end)
              || case when base.note is not null then jsonb_build_object('note', base.note) else '{}'::jsonb end) order by base.ord)
                from base),
    'drops', (select coalesce(json_agg(json_build_object(
                'after', d.key,
                'lost', (select count(*) from c where c.depth = d.ord),
                'top_exits', (select coalesce(json_agg(json_build_object('screen', z.screen, 'count', z.n) order by z.n desc, z.screen), '[]')
                                from (select coalesce(tr.t ->> 'last_screen', tr.t ->> 'last_event', '(olay yok)') as screen, count(*) as n
                                        from tr where tr.depth = d.ord
                                       group by 1 order by 2 desc, 1 limit 5) z))
                order by d.ord), '[]') from d where d.cohort and d.next is not null),
    'cancel_reasons', (select coalesce(json_agg(json_build_object('reason', z.reason, 'count', z.n) order by z.n desc, z.reason), '[]')
                         from (select coalesce(nullif(e.props ->> 'reason', ''), 'none') as reason, count(distinct e.user_id) as n
                                 from public.app_events e
                                where e.app = p_product and e.event = 'membership.cancel_reason'
                                  and e.occurred_at >= a and e.occurred_at < b
                                group by 1) z),
    'kpis', json_build_object(
      'store_tap_through', public.funnel_kpi(pv, imp),
      'store_page_conversion', public.funnel_kpi(dl, pv),
      'download_to_signup', public.funnel_kpi((select count(*) from c), dl),
      'signup_to_activation', public.funnel_kpi(
         (select count(*) from c where c.joined_at <= now() - make_interval(days => act_days)
             and (c.steps ->> act_step)::timestamptz <= c.joined_at + make_interval(days => act_days)),
         (select count(*) from c where c.joined_at <= now() - make_interval(days => act_days))))
  ) into res;
  return res;
end $$;

-- O adımda kalanlar: art arda ulaştığı son adım p_step olanlar (drops[].after ile aynı anahtar; son adımda ulaşanlar).
-- Yalnız owner / support. App Store adımları kişi bazında değildir: boş liste. state: müşteri ekranındaki durum adları
-- (aile: family_access_of → trial / premium / clinic / pending / expired; uzman: varsayılan kliniği paid / manual / trial / expired).
create or replace function public.admin_funnel_people(p_product text, p_step text, p_from date, p_to date, p_limit integer default 50)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  lim integer := least(greatest(coalesce(p_limit, 50), 1), 500);
  st record;
  res json;
begin
  perform public.admin_require(array['support']);
  perform public.funnel_check_args(p_product, p_from, p_to);
  select d.ord, d.cohort into st from public.funnel_step_defs(p_product) d where d.key = p_step;
  if st.ord is null then raise exception 'Geçersiz adım: %', p_step; end if;
  if not st.cohort then return '[]'::json; end if;
  select coalesce(json_agg(z.j order by z.seen desc nulls last, z.joined desc), '[]') into res from (
    select json_build_object(
             'id', c.id, 'id_short', left(c.id::text, 8), 'kind', case when p_product = 'parent' then 'family' else 'user' end,
             'joined_at', c.joined_at, 'reached', (c.steps ->> p_step)::timestamptz,
             'last_event', tr.t ->> 'last_event', 'last_screen', tr.t ->> 'last_screen',
             'last_seen', (tr.t ->> 'last_seen')::timestamptz,
             'state', case when p_product = 'parent' then public.family_access_of(c.id) ->> 'state'
                           else public.clinic_billing_state((select m.clinic_id from public.clinicians m where m.id = c.id)) end) as j,
           (tr.t ->> 'last_seen')::timestamptz as seen, c.joined_at as joined
      from public.funnel_cohort(p_product, p_from, p_to) c
      cross join lateral (select public.funnel_person_trace(p_product, c.id) as t) tr
     where c.depth = st.ord
     order by (tr.t ->> 'last_seen')::timestamptz desc nulls last, c.joined_at desc
     limit lim) z;
  return res;
end $$;

-- ---------------------------------------------------------------------
-- 4. Abonelik sağlığı (her admin rolü). Anlık değerler (active_paid, in_trial, mrr) bugüne göre; akış değerleri aralığa göre.
--   Moyo: family_subscriptions (aile başına tek satır, geçmiş yok) → kayıp ve iade updated_at ile, yenileme dönem sonundan TAHMİN.
--   Mercek: billing_subscriptions + billing_events (RevenueCat olay türü payload.type). MRR = aylık + yıllık / 12 (KDV dahil brüt).
-- ---------------------------------------------------------------------
create or replace function public.admin_subscription_health(p_product text, p_from date, p_to date)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  t timestamptz := now();
  a timestamptz := p_from;
  b timestamptz := p_to + 1;
  wb timestamptz;
  wa timestamptz;
  cfg jsonb := coalesce((select value from public.app_config where key = 'kpi'), '{}'::jsonb);
  bcfg jsonb := public.billing_config();
  pm numeric; py numeric;
  res json;
begin
  perform public.admin_require();
  perform public.funnel_check_args(p_product, p_from, p_to);
  wb := least(b, t);                 -- 30 günlük kayıp penceresi aralığın sonunda (bugünü geçmez)
  wa := wb - interval '30 days';

  if p_product = 'parent' then
    pm := coalesce((cfg ->> 'parent_monthly_try')::numeric, 0);
    py := coalesce((cfg ->> 'parent_yearly_try')::numeric, 0);
    with s as materialized (
      select x.*, case when x.billing = 'yearly' then interval '1 year' else interval '1 month' end as per,
             x.plan = 'premium' and x.status in ('active', 'grace', 'canceled') and (x.period_end is null or x.period_end > t) as live,
             case when x.status in ('expired', 'refunded') then x.updated_at end as ended_at
        from public.family_subscriptions x where x.source in ('store', 'web') and x.started_at is not null
    ), r as materialized (   -- tahmini yenileme anları: başlangıç + k dönem (k ≥ 1), dönem sonunu (+3 gün) aşmayan
      select s.family_id, s.started_at + s.per * k as at, k
        from s cross join lateral generate_series(1, greatest(0, floor(
               extract(epoch from (s.period_end + interval '3 days') - s.started_at) / extract(epoch from s.per))::int - 1)) k
       where s.period_end is not null
    ), f as materialized (
      select fa.id, fa.trial_started_at,
             greatest(fa.trial_started_at + make_interval(days => coalesce(fa.trial_days::int, (bcfg ->> 'trial_days')::int)),
                      coalesce(fa.bonus_until, '-infinity'::timestamptz)) as te,
             exists (select 1 from s where s.family_id = fa.id) as ever_paid,
             exists (select 1 from s where s.family_id = fa.id and s.live) as live
        from public.families fa where fa.trial_started_at is not null
    ), m1 as (select s.* from s where s.billing is distinct from 'yearly' and s.started_at + s.per >= a and s.started_at + s.per < b
                                  and s.started_at + s.per <= t - interval '3 days'),
       y1 as (select s.* from s where s.billing = 'yearly' and s.started_at + s.per >= a and s.started_at + s.per < b
                                  and s.started_at + s.per <= t - interval '3 days'),
       nums as (
      select (select count(*) from s where s.live) as active_paid,
             (select count(*) from s where s.live and s.billing = 'yearly') as yearly,
             (select count(*) from s where s.live and s.billing is distinct from 'yearly') as monthly,
             (select count(*) from f where f.te > t and not f.live) as in_trial,
             (select count(*) from f where f.trial_started_at >= a and f.trial_started_at < b) as trials_started,
             (select count(*) from f where f.te >= a and f.te < b and f.te <= t) as trials_ended,
             (select count(*) from f where f.te >= a and f.te < b and f.te <= t and f.ever_paid) as trial_paid,
             (select count(*) from s where s.started_at >= a and s.started_at < b) as new_paid,
             (select count(*) from s where s.ended_at >= a and s.ended_at < b) as churned,
             (select count(*) from r where r.at >= a and r.at < b and r.at <= t) as renewals,
             (select count(*) from s where s.status = 'refunded' and s.updated_at >= a and s.updated_at < b) as refunds,
             (select count(*) from s where s.status = 'grace' and s.updated_at >= a and s.updated_at < b) as billing_issues,
             (select count(*) from s where s.started_at < wa and (s.ended_at is null or s.ended_at >= wa)) as churn_base,
             (select count(*) from s where s.started_at < wa and s.ended_at >= wa and s.ended_at < wb) as churn_n,
             (select count(*) from m1) as m1_n,
             (select count(*) from m1 where exists (select 1 from r where r.family_id = m1.family_id and r.k = 1)) as m1_renewed,
             (select count(*) from y1) as y1_n,
             (select count(*) from y1 where exists (select 1 from r where r.family_id = y1.family_id and r.k = 1)) as y1_renewed
    )
    select json_build_object(
      'product', p_product, 'from', p_from, 'to', p_to,
      'active_paid', n.active_paid, 'in_trial', n.in_trial,
      'trials_started', n.trials_started, 'trials_ended', n.trials_ended,
      'trial_to_paid_pct', case when n.trials_ended > 0 then round(n.trial_paid * 100.0 / n.trials_ended, 1) end,
      'new_paid', n.new_paid, 'churned', n.churned,
      'churn_pct_30d', case when n.churn_base > 0 then round(n.churn_n * 100.0 / n.churn_base, 1) end,
      'renewals', n.renewals, 'refunds', n.refunds, 'billing_issues', n.billing_issues,
      'mrr_try', round(n.monthly * pm + n.yearly * py / 12, 2),
      'arpu_try', case when n.active_paid > 0 then round((n.monthly * pm + n.yearly * py / 12) / n.active_paid, 2) end,
      'prices_set', pm > 0 and py > 0,
      'by_plan', json_build_array(
         json_build_object('plan', 'premium_monthly', 'active', n.monthly, 'mrr_try', round(n.monthly * pm, 2)),
         json_build_object('plan', 'premium_yearly', 'active', n.yearly, 'mrr_try', round(n.yearly * py / 12, 2))),
      'weekly', (select coalesce(json_agg(json_build_object(
                   'week', to_char(w.wk at time zone 'Europe/Istanbul', 'YYYY-MM-DD'),
                   'trials', (select count(*) from f where f.trial_started_at >= w.wk and f.trial_started_at < w.wk + interval '7 days'),
                   'paid', (select count(*) from s where s.started_at >= w.wk and s.started_at < w.wk + interval '7 days'),
                   'churned', (select count(*) from s where s.ended_at >= w.wk and s.ended_at < w.wk + interval '7 days'))
                   order by w.wk), '[]')
                   from generate_series(date_trunc('week', p_from::timestamp), p_to::timestamp, interval '7 days') g(d)
                   cross join lateral (select g.d at time zone 'Europe/Istanbul' as wk) w),
      'kpis', json_build_object(
         'trial_to_paid', public.funnel_kpi(n.trial_paid, n.trials_ended),
         'monthly_churn', public.funnel_kpi(n.churn_n, n.churn_base),
         'monthly_renewal_m1', public.funnel_kpi(n.m1_renewed, n.m1_n),
         'annual_renewal', public.funnel_kpi(n.y1_renewed, n.y1_n),
         'annual_share', public.funnel_kpi(n.yearly, n.active_paid),
         'refund_rate', public.funnel_kpi(n.refunds, n.new_paid + n.renewals),
         'billing_issue_rate', public.funnel_kpi(n.billing_issues, n.active_paid)),
      'notes', json_build_array('Moyo aboneliğinin geçmişi tutulmuyor: yenileme dönem sonundan tahmin, kayıp ve iade son güncellemeden',
                                'MRR KDV dahil brüt; mağaza ve RevenueCat payı düşülmedi (admin_kpi_summary mrr_net_try)')
    ) into res from nums n;

  else
    with s as materialized (
      select x.*, p.period, p.price_try, case when p.period = 'yearly' then interval '1 year' else interval '1 month' end as per,
             x.status in ('active', 'canceled') and x.period_end > t as live,
             case when x.status in ('expired', 'refunded') then coalesce(
               (select min(e.created_at) from public.billing_events e
                 where e.source = x.source and e.external_id = x.external_id and e.kind in ('apply:expired', 'apply:refunded')
                   and e.created_at > coalesce((select max(e2.created_at) from public.billing_events e2
                                                 where e2.source = x.source and e2.external_id = x.external_id
                                                   and e2.kind in ('apply:active', 'apply:canceled', 'apply:pending')), '-infinity')),
               x.updated_at) end as ended_at,
             (select min(e.created_at) from public.billing_events e where e.source = x.source and e.external_id = x.external_id
                and e.kind = 'apply:active' and e.payload ->> 'type' = 'RENEWAL') as first_renewal
        from public.billing_subscriptions x join public.billing_plans p on p.id = x.plan_id
       where x.source <> 'manual'
    ), ev as materialized (
      select e.* from public.billing_events e where e.source <> 'manual' and e.created_at >= a and e.created_at < b
    ), k as materialized (   -- uzman başına deneme: kendi açtığı alanların en geç deneme sonu
      select m.id, m.created_at,
             (select max(c.trial_ends_at) from public.clinics c where c.created_by = m.id) as te,
             exists (select 1 from s join public.clinics c on c.id = s.clinic_id where c.created_by = m.id) as ever_paid,
             exists (select 1 from s join public.clinics c on c.id = s.clinic_id where c.created_by = m.id and s.live) as live
        from public.clinicians m
    ), m1 as (select s.* from s where s.period = 'monthly' and s.created_at + s.per >= a and s.created_at + s.per < b
                                  and s.created_at + s.per <= t - interval '3 days'),
       y1 as (select s.* from s where s.period = 'yearly' and s.created_at + s.per >= a and s.created_at + s.per < b
                                  and s.created_at + s.per <= t - interval '3 days'),
       nums as (
      select (select count(distinct s.clinic_id) from s where s.live) as active_paid,
             (select count(*) from s where s.live and s.period = 'yearly') as yearly,
             (select count(*) from s where s.live) as live_subs,
             (select coalesce(sum(case when s.period = 'yearly' then s.price_try / 12 else s.price_try end), 0) from s where s.live) as mrr,
             (select count(*) from k where k.te > t and not k.live
                 and exists (select 1 from public.clinics c where c.created_by = k.id and c.plan = 'trial' and c.trial_ends_at > t)) as in_trial,
             (select count(*) from k where k.created_at >= a and k.created_at < b) as trials_started,
             (select count(*) from k where k.te >= a and k.te < b and k.te <= t) as trials_ended,
             (select count(*) from k where k.te >= a and k.te < b and k.te <= t and k.ever_paid) as trial_paid,
             (select count(*) from s where s.created_at >= a and s.created_at < b) as new_paid,
             (select count(*) from s where s.ended_at >= a and s.ended_at < b) as churned,
             (select count(distinct (ev.external_id, ev.created_at::date)) from ev
               where ev.kind = 'apply:active' and ev.payload ->> 'type' = 'RENEWAL') as renewals,
             (select count(*) from s where s.status = 'refunded' and s.ended_at >= a and s.ended_at < b) as refunds,
             (select count(distinct ev.external_id) from ev where ev.kind = 'apply:active' and ev.payload ->> 'type' = 'BILLING_ISSUE') as billing_issues,
             (select count(*) from s where s.created_at < wa and (s.ended_at is null or s.ended_at >= wa)) as churn_base,
             (select count(*) from s where s.created_at < wa and s.ended_at >= wa and s.ended_at < wb) as churn_n,
             (select count(*) from m1) as m1_n,
             (select count(*) from m1 where m1.first_renewal is not null
                 or m1.period_end >= m1.created_at + m1.per * 2 - interval '3 days') as m1_renewed,
             (select count(*) from y1) as y1_n,
             (select count(*) from y1 where y1.first_renewal is not null
                 or y1.period_end >= y1.created_at + y1.per * 2 - interval '3 days') as y1_renewed
    )
    select json_build_object(
      'product', p_product, 'from', p_from, 'to', p_to,
      'active_paid', n.active_paid, 'in_trial', n.in_trial,
      'trials_started', n.trials_started, 'trials_ended', n.trials_ended,
      'trial_to_paid_pct', case when n.trials_ended > 0 then round(n.trial_paid * 100.0 / n.trials_ended, 1) end,
      'new_paid', n.new_paid, 'churned', n.churned,
      'churn_pct_30d', case when n.churn_base > 0 then round(n.churn_n * 100.0 / n.churn_base, 1) end,
      'renewals', n.renewals, 'refunds', n.refunds, 'billing_issues', n.billing_issues,
      'mrr_try', round(n.mrr, 2),
      'arpu_try', case when n.active_paid > 0 then round(n.mrr / n.active_paid, 2) end,
      'prices_set', true,
      'by_plan', (select coalesce(json_agg(json_build_object('plan', p.id, 'active', z.n, 'mrr_try', round(z.mrr, 2)) order by p.sort), '[]')
                    from public.billing_plans p
                    cross join lateral (select count(*) as n,
                                               coalesce(sum(case when s.period = 'yearly' then s.price_try / 12 else s.price_try end), 0) as mrr
                                          from s where s.live and s.plan_id = p.id) z),
      'weekly', (select coalesce(json_agg(json_build_object(
                   'week', to_char(w.wk at time zone 'Europe/Istanbul', 'YYYY-MM-DD'),
                   'trials', (select count(*) from k where k.created_at >= w.wk and k.created_at < w.wk + interval '7 days'),
                   'paid', (select count(*) from s where s.created_at >= w.wk and s.created_at < w.wk + interval '7 days'),
                   'churned', (select count(*) from s where s.ended_at >= w.wk and s.ended_at < w.wk + interval '7 days'))
                   order by w.wk), '[]')
                   from generate_series(date_trunc('week', p_from::timestamp), p_to::timestamp, interval '7 days') g(d)
                   cross join lateral (select g.d at time zone 'Europe/Istanbul' as wk) w),
      'kpis', json_build_object(
         'trial_to_paid', public.funnel_kpi(n.trial_paid, n.trials_ended),
         'monthly_churn', public.funnel_kpi(n.churn_n, n.churn_base),
         'monthly_renewal_m1', public.funnel_kpi(n.m1_renewed, n.m1_n),
         'annual_renewal', public.funnel_kpi(n.y1_renewed, n.y1_n),
         'annual_share', public.funnel_kpi(n.yearly, n.live_subs),
         'refund_rate', public.funnel_kpi(n.refunds, n.new_paid + n.renewals),
         'billing_issue_rate', public.funnel_kpi(n.billing_issues, n.active_paid)),
      'notes', json_build_array('Moyo Mercek: elle verilen üyelik (manual) sayılmaz; deneme uzman başına',
                                'MRR KDV dahil brüt; mağaza ve RevenueCat payı düşülmedi (admin_kpi_summary mrr_net_try)')
    ) into res from nums n;
  end if;
  return res;
end $$;

-- ---------------------------------------------------------------------
-- 5. Kıyas değerleri ve App Store verisi
-- ---------------------------------------------------------------------
create or replace function public.kpi_benchmark_keys()
returns text[] language sql immutable set search_path = '' as $$
  select array['store_tap_through', 'store_page_conversion', 'download_to_signup', 'signup_to_activation',
               'trial_to_paid', 'monthly_churn', 'monthly_renewal_m1', 'annual_renewal', 'annual_share',
               'refund_rate', 'billing_issue_rate', 'd1_retention', 'd7_retention', 'd30_retention']
$$;

-- Anahtarın sabit adı, birimi ve iyi yönü (better: high = büyük iyi, low = küçük iyi). Bilinmeyen anahtarda null.
create or replace function public.kpi_benchmark_meta(p_key text)
returns table (label text, unit text, better text)
language sql immutable set search_path = '' as $$
  select v.label, '%'::text, v.better from (values
    ('store_tap_through', 'App Store gösterim → ürün sayfası', 'high'),
    ('store_page_conversion', 'Ürün sayfası → indirme', 'high'),
    ('download_to_signup', 'İndirme → kayıt', 'high'),
    ('signup_to_activation', 'Kayıt → etkinleşme', 'high'),
    ('trial_to_paid', 'Deneme → ücretli', 'high'),
    ('monthly_churn', 'Aylık kayıp (30 gün)', 'low'),
    ('monthly_renewal_m1', 'Aylık planda ilk yenileme', 'high'),
    ('annual_renewal', 'Yıllık planda ilk yenileme', 'high'),
    ('annual_share', 'Yıllık plan payı', 'high'),
    ('refund_rate', 'İade oranı', 'low'),
    ('billing_issue_rate', 'Ödeme sorunu oranı', 'low'),
    ('d1_retention', 'G1 elde tutma', 'high'),
    ('d7_retention', 'G7 elde tutma', 'high'),
    ('d30_retention', 'G30 elde tutma', 'high')
  ) v(key, label, better) where v.key = p_key
$$;

-- Seed ya da SQL Editor ile eklenen satırda verilmeyen ad / birim / yön sabit eşlemeden dolar.
create or replace function public.kpi_benchmarks_fill() returns trigger
language plpgsql set search_path = '' as $$
declare mt record;
begin
  select * into mt from public.kpi_benchmark_meta(new.key);
  new.label := coalesce(new.label, mt.label);
  new.unit := coalesce(new.unit, mt.unit, '%');
  new.better := coalesce(new.better, mt.better, 'high');
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists kpi_benchmarks_fill on public.kpi_benchmarks;
create trigger kpi_benchmarks_fill before insert or update on public.kpi_benchmarks
  for each row execute function public.kpi_benchmarks_fill();

create or replace function public.admin_benchmarks()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return (select coalesce(json_agg(json_build_object(
            'key', k.key, 'product', k.product, 'label', k.label, 'value', k.value, 'unit', k.unit, 'better', k.better,
            'low', k.low, 'high', k.high, 'source', k.source, 'source_url', k.source_url, 'as_of', k.as_of, 'note', k.note,
            'updated_at', k.updated_at) order by k.product, array_position(public.kpi_benchmark_keys(), k.key), k.key), '[]')
            from public.kpi_benchmarks k);
end $$;

-- Ekle / güncelle (aynı anahtar + ürün üzerine yazar); p_value, p_low ve p_high üçü de boşsa satır silinir.
-- Ad / birim / yön var olan satırdan ya da sabit eşlemeden. Yalnız owner, gerekçeli, denetim kaydına.
create or replace function public.admin_benchmark_set(p_key text, p_product text, p_value numeric, p_low numeric, p_high numeric,
                                                      p_source text, p_source_url text, p_as_of text, p_reason text,
                                                      p_note text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  old jsonb;
  new_row jsonb;
begin
  if p_key is null or not (p_key = any (public.kpi_benchmark_keys())) then raise exception 'Bilinmeyen kıyas anahtarı: %', p_key; end if;
  if p_product is null or p_product not in ('parent', 'clinic') then raise exception 'Geçersiz ürün (parent / clinic)'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Gerekçe yaz (en az 3 harf)'; end if;
  select to_jsonb(k) into old from public.kpi_benchmarks k where k.key = p_key and k.product = p_product;
  if p_value is null and p_low is null and p_high is null then
    delete from public.kpi_benchmarks where key = p_key and product = p_product;
    perform public.admin_log(me, 'benchmark.delete', 'config', 'benchmark:' || p_product || ':' || p_key, p_reason, old, null);
    return null;
  end if;
  if p_low is not null and p_high is not null and p_low > p_high then raise exception 'Alt sınır üst sınırdan büyük olamaz'; end if;
  if coalesce(old ->> 'unit', '%') = '%' and (p_value not between 0 and 100 or p_low not between 0 and 100 or p_high not between 0 and 100) then
    raise exception 'Yüzde 0–100 arasında olmalı';
  end if;
  if nullif(p_source_url, '') is not null and p_source_url !~ '^https://' then raise exception 'Kaynak bağlantısı https:// ile başlamalı'; end if;
  if char_length(coalesce(p_as_of, '')) > 40 then raise exception 'Tarih alanı en çok 40 karakter'; end if;
  if char_length(coalesce(p_note, '')) > 500 then raise exception 'Not en çok 500 karakter'; end if;
  insert into public.kpi_benchmarks (key, product, value, low, high, source, source_url, as_of, note)
  values (p_key, p_product, p_value, p_low, p_high, left(coalesce(p_source, ''), 300), nullif(p_source_url, ''),
          nullif(trim(coalesce(p_as_of, '')), ''), nullif(trim(coalesce(p_note, '')), ''))
  on conflict (key, product) do update set value = excluded.value, low = excluded.low, high = excluded.high,
    source = excluded.source, source_url = excluded.source_url, as_of = excluded.as_of, note = excluded.note;
  select to_jsonb(k) into new_row from public.kpi_benchmarks k where k.key = p_key and k.product = p_product;
  perform public.admin_log(me, 'benchmark.set', 'config', 'benchmark:' || p_product || ':' || p_key, p_reason, old, new_row);
  return new_row::json;
end $$;

-- App Store Connect günlük değerleri (ürün sayfası analitiği). Üçü de boşsa gün silinir. Yalnız owner, gerekçeli.
create or replace function public.admin_store_funnel_set(p_product text, p_day date, p_impressions integer, p_page_views integer,
                                                         p_downloads integer, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['owner']);
  old jsonb;
begin
  if p_product is null or p_product not in ('parent', 'clinic') then raise exception 'Geçersiz ürün (parent / clinic)'; end if;
  if p_day is null or p_day > current_date or p_day < current_date - 730 then raise exception 'Gün bugünden ileri ya da 2 yıldan eski olamaz'; end if;
  if p_impressions < 0 or p_page_views < 0 or p_downloads < 0 then raise exception 'Değerler negatif olamaz'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Gerekçe yaz (en az 3 harf)'; end if;
  select to_jsonb(s) - 'updated_by' into old from public.store_funnel_daily s where s.product = p_product and s.day = p_day;
  if p_impressions is null and p_page_views is null and p_downloads is null then
    delete from public.store_funnel_daily where product = p_product and day = p_day;
  else
    insert into public.store_funnel_daily (product, day, impressions, page_views, downloads, source, updated_by, updated_at)
    values (p_product, p_day, p_impressions, p_page_views, p_downloads, 'manual', me, now())
    on conflict (product, day) do update set impressions = excluded.impressions, page_views = excluded.page_views,
      downloads = excluded.downloads, source = 'manual', updated_by = me, updated_at = now();
  end if;
  perform public.admin_log(me, 'store_funnel.set', 'config', 'store_funnel:' || p_product || ':' || p_day, p_reason, old,
                           jsonb_build_object('impressions', p_impressions, 'page_views', p_page_views, 'downloads', p_downloads));
end $$;

-- ---------------------------------------------------------------------
-- 6. Yetkiler
-- ---------------------------------------------------------------------
do $$
declare fn text;
begin
  foreach fn in array array[
    'public.funnel_step_defs(text)', 'public.funnel_parent_steps(uuid, timestamptz)', 'public.funnel_clinic_steps(uuid, timestamptz)',
    'public.funnel_cohort(text, date, date, timestamptz)', 'public.funnel_person_trace(text, uuid)', 'public.clinic_billing_state(uuid)',
    'public.funnel_kpi(numeric, numeric)', 'public.funnel_check_args(text, date, date)', 'public.kpi_benchmark_keys()',
    'public.kpi_benchmark_meta(text)', 'public.kpi_benchmarks_fill()', 'public.funnel_depth(text, jsonb)'] loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn);
  end loop;
  foreach fn in array array[
    'public.admin_funnel(text, date, date)', 'public.admin_funnel_people(text, text, date, date, integer)',
    'public.admin_subscription_health(text, date, date)', 'public.admin_benchmarks()',
    'public.admin_benchmark_set(text, text, numeric, numeric, numeric, text, text, text, text, text)',
    'public.admin_store_funnel_set(text, date, integer, integer, integer, text)'] loop
    execute format('revoke execute on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end $$;
