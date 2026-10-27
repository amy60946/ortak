-- Uzman karşılama anketi (27 Ekim 2026, kullanıcı isteği; sozlesme/akislar.md 15).
-- Uzman kayıttan sonraki ilk girişte bir kez 4 kısa soru görür: mesleği, ailelerle çalışırken zorlandığı konular,
-- işine yarayacak özellikler ve ClinicApp'e gelme nedeni. "Şimdilik geç" de kayıt sayılır (bir daha sorulmaz).
-- Cevaplar ürün kararları içindir; aileye ve diğer uzmanlara görünmez, yönetim panelinde yalnız toplam sayılar.
-- Seçenek anahtarları veri/uzman_anketi.json ile aynı. Tekrar çalıştırılabilir.

create table if not exists public.clinician_surveys (
  clinician_id uuid primary key references public.clinicians (id) on delete cascade,
  profession   text,
  challenges   text[] not null default '{}',
  features     text[] not null default '{}',
  intent       text,
  skipped      boolean not null default false,
  version      integer not null default 1,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table public.clinician_surveys enable row level security;
revoke all on public.clinician_surveys from public, anon, authenticated;
-- doğrudan okuma/yazma yok: yalnız aşağıdaki işlevler

-- Seçenek listeleri (veri/uzman_anketi.json)
create or replace function public.clinician_survey_keys(p_kind text)
returns text[] language sql immutable set search_path = '' as $$
  select case p_kind
    when 'profession' then array['psikolog', 'klinik_psikolog', 'pdr', 'ergoterapist', 'dil_konusma', 'ozel_egitim', 'cocuk_gelisimi',
                                 'bcba', 'hekim', 'oyun_terapisti', 'sanat_terapisti', 'aile_danismani', 'okul_rehber', 'ogrenci', 'diger']
    when 'challenges' then array['home_followthrough', 'home_data', 'unpaid_time', 'no_system', 'between_sessions', 'progress_report']
    when 'features' then array['plan_templates', 'parent_logging', 'reward_routines', 'progress_report', 'report_export', 'parent_materials']
    when 'intent' then array['trial', 'family', 'team', 'org']
  end
$$;
revoke execute on function public.clinician_survey_keys(text) from public, anon;
grant execute on function public.clinician_survey_keys(text) to authenticated;

-- Uzmanın kendi cevabı (yoksa null: anket gösterilir)
create or replace function public.clinician_survey_me()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('profession', s.profession, 'challenges', s.challenges, 'features', s.features, 'intent', s.intent,
                            'skipped', s.skipped, 'version', s.version, 'updated_at', s.updated_at)
    from public.clinician_surveys s
   where s.clinician_id = auth.uid()
$$;
revoke execute on function public.clinician_survey_me() from public, anon;
grant execute on function public.clinician_survey_me() to authenticated;

-- Kaydet ya da güncelle. Bilinmeyen anahtar reddedilir; tekrarlar tekilleşir. p_skipped: "Şimdilik geç".
create or replace function public.clinician_survey_save(p_profession text default null, p_challenges text[] default '{}',
                                                         p_features text[] default '{}', p_intent text default null,
                                                         p_skipped boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare
  ch text[] := coalesce((select array_agg(distinct x order by x) from unnest(coalesce(p_challenges, '{}')) x), '{}');
  fe text[] := coalesce((select array_agg(distinct x order by x) from unnest(coalesce(p_features, '{}')) x), '{}');
  pr text := nullif(btrim(coalesce(p_profession, '')), '');
  it text := nullif(btrim(coalesce(p_intent, '')), '');
begin
  if not exists (select 1 from public.clinicians where id = auth.uid()) then raise exception 'Yalnızca uzman hesabı'; end if;
  if pr is not null and not (pr = any (public.clinician_survey_keys('profession'))) then raise exception 'Geçersiz meslek'; end if;
  if it is not null and not (it = any (public.clinician_survey_keys('intent'))) then raise exception 'Geçersiz seçim'; end if;
  if not (ch <@ public.clinician_survey_keys('challenges')) or not (fe <@ public.clinician_survey_keys('features')) then
    raise exception 'Geçersiz seçim';
  end if;
  insert into public.clinician_surveys as s (clinician_id, profession, challenges, features, intent, skipped)
  values (auth.uid(), pr, ch, fe, it, coalesce(p_skipped, false))
  on conflict (clinician_id) do update
     set profession = excluded.profession, challenges = excluded.challenges, features = excluded.features,
         intent = excluded.intent, skipped = excluded.skipped, updated_at = now();
end $$;
revoke execute on function public.clinician_survey_save(text, text[], text[], text, boolean) from public, anon;
grant execute on function public.clinician_survey_save(text, text[], text[], text, boolean) to authenticated;

-- Yönetim paneli: toplam sayılar (kişi listesi yok). Son N günde cevaplayan / geçen uzmanlar.
create or replace function public.admin_kpi_clinician_survey(p_days integer default 90)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  d integer := least(greatest(coalesce(p_days, 90), 1), 730);
  since timestamptz := now() - make_interval(days => d);
begin
  perform public.admin_require();
  return (
    with s as (select * from public.clinician_surveys where updated_at >= since),
    a as (select * from s where not skipped)
    select json_build_object(
      'days', d,
      'answered', (select count(*) from a),
      'skipped', (select count(*) from s where skipped),
      'profession', (select coalesce(json_object_agg(k, n), '{}') from (select profession as k, count(*) as n from a where profession is not null group by 1) x),
      'challenges', (select coalesce(json_object_agg(k, n), '{}') from (select k, count(*) as n from a, unnest(a.challenges) as k group by k) x),
      'features', (select coalesce(json_object_agg(k, n), '{}') from (select k, count(*) as n from a, unnest(a.features) as k group by k) x),
      'intent', (select coalesce(json_object_agg(k, n), '{}') from (select intent as k, count(*) as n from a where intent is not null group by 1) x)
    )
  );
end $$;
revoke execute on function public.admin_kpi_clinician_survey(integer) from public, anon;
grant execute on function public.admin_kpi_clinician_survey(integer) to authenticated;
