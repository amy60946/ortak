-- =====================================================================
-- Moyo Mercek 23 Kasım güncellemeleri (ÖNERİ, 23 Kasım 2026; kullanıcı kararları koordinatöre, 23 Kasım 2026). Tekrar çalıştırılabilir.
--   1. Seans ücreti: uzman seansa elle ücret yazar (TL, 0–1.000.000, iki ondalık). Yalnız klinik görür; aileye giden hiçbir yol
--      (politika, family_* işlevleri, bildirim) ücreti döndürmez.
--   2. Raporu aileye gönder: "Rapor oluştur"dan sonra uzman raporu sistem içinden gönderir (clinic_report_share); ebeveynlere
--      report_shared bildirimi; Moyo'da uygulama içi sayfa (family_report) ve alınan raporlar arşivi (family_reports). Rapor ailede
--      kalır: paylaşım bitince, paylaşım kaydı ya da klinik silinince de (family_keeps_records ilkesi); yalnız aile ya da çocuk
--      silinince silinir. İçerik biçimi v1 (aşağıda 2.2) sunucuda denetlenir; bilinmeyen anahtar reddedilir.
--   3. Hedef davranışın kayıt türü çoklu seçim: clinic_target_behaviors.log_types (sıklık / ABC / süre, 1–3, sabit sırada);
--      eski log_type = ilk tür (tetikleyiciyle iki yönlü eşit: eski uygulama yalnız log_type, yeni uygulama yalnız log_types yazar).
--      behavior_incidents.log_types bildirim anının kopyası; family_incident_report seçili her türün alanını ister ve yazar.
--   4. Ebeveyn eğitimi bayrağı parent_training (satır yoksa kapalı): iki uygulamada özelliği gizler; bildirim motorunda eğitime
--      yönelik kurallar (clinic_training_none, clinic_training_draft) bayrak kapalı kişiye hiçbir şey göndermez
--      (nudge_rules.feature_flag + nudge_try).
-- Önkoşul (hepsi canlıda): migrations/20261105100000_sessions.sql, 20261110110000_target_behaviors.sql,
--   20261120200000_family_keeps_records.sql, 20261120230000_nudge_engine.sql, 20261121100000_security_audit_fixes.sql.
-- Sözleşme: sozlesme/veritabani.md 40, akislar.md 27, durumlar.md P18 / P22 / P23 / 8, admin.md (bayrak parent_training),
--   hukuk_notlari.md S, hukuk/46. Test: supabase/test/test_mercek_updates.sql.
-- =====================================================================

do $$ begin
  if to_regclass('public.clinic_sessions') is null or to_regclass('public.clinic_target_behaviors') is null
     or to_regclass('public.nudge_rules') is null then
    raise exception 'Önce seans, hedef davranış ve bildirim motoru göçleri çalıştırılmalı (20261105100000, 20261110110000, 20261120230000)';
  end if;
  if to_regprocedure('public.finite_time_guard_attach()') is null then
    raise exception 'Önce migrations/20261121100000_security_audit_fixes.sql çalıştırılmalı (finite_time_guard_attach yok)';
  end if;
end $$;

-- =====================================================================
-- 1. Seans ücreti
-- =====================================================================
alter table public.clinic_sessions add column if not exists fee numeric(10, 2)
  check (fee is null or (fee >= 0 and fee <= 1000000));   -- TL, uzmanın elle yazdığı ücret; yalnız klinik (aile hiçbir yoldan görmez)

-- p->>'fee': boş ya da yok → null; sayı ya da "450" / "450.5" / "450.50" (nokta, en çok iki ondalık), 0–1.000.000
create or replace function public.session_fee_of(p jsonb)
returns numeric language plpgsql immutable set search_path = '' as $$
declare v text := btrim(p ->> 'fee');
begin
  if v is null or v = '' then return null; end if;
  if v !~ '^[0-9]{1,7}([.][0-9]{1,2})?$' or v::numeric > 1000000 then
    raise exception 'fee_invalid' using errcode = '22023';
  end if;
  return v::numeric;
end $$;
revoke execute on function public.session_fee_of(jsonb) from public, anon, authenticated;

-- Seans oluştur (önceki tanım: migrations/20261105100000_sessions.sql; yalnız ücret eklendi: serideki her seansa aynı ücret)
create or replace function public.clinic_session_create(p jsonb)
returns json language plpgsql security definer set search_path = '' as $$
declare
  k uuid := public.my_clinic_id();
  v_link uuid := nullif(p ->> 'link_id', '')::uuid;
  v_clin uuid := coalesce(nullif(p ->> 'clinician_id', '')::uuid, auth.uid());
  v_room uuid := nullif(p ->> 'room_id', '')::uuid;
  v_pkg uuid := nullif(p ->> 'package_id', '')::uuid;
  v_start timestamptz := (p ->> 'starts_at')::timestamptz;
  v_min int := coalesce((p ->> 'duration_min')::int, 45);
  v_rep text := coalesce(p ->> 'repeat', 'none');
  v_count int := least(greatest(coalesce((p ->> 'count')::int, 1), 1), 52);
  v_fee numeric := public.session_fee_of(p);
  v_step interval;
  v_series uuid;
  v_vis boolean := coalesce((p ->> 'visible_to_family')::boolean, false) and v_link is not null;
  v_ids uuid[] := '{}';
  v_conf jsonb := '[]';
  v_id uuid;
  i int;
begin
  if not public.clinician_access() then raise exception 'no_access' using errcode = '42501'; end if;
  if v_start is null then raise exception 'starts_at_required' using errcode = '23502'; end if;
  perform public.session_check_refs(v_link, v_clin, v_room, v_pkg);
  if v_rep = 'none' then v_count := 1; end if;
  v_step := case v_rep when 'biweekly' then interval '14 days' else interval '7 days' end;
  if v_count > 1 then v_series := gen_random_uuid(); end if;
  for i in 0 .. v_count - 1 loop
    v_conf := v_conf || public.session_conflicts(k, v_clin, v_room, v_start + v_step * i, v_min);
    insert into public.clinic_sessions (clinic_id, clinician_id, link_id, title, series_id, starts_at, duration_min, kind, mode, room_id,
                                        visible_to_family, package_id, fee, created_by)
    values (k, v_clin, v_link, nullif(btrim(p ->> 'title'), ''), v_series, v_start + v_step * i, v_min,
            coalesce(p ->> 'kind', 'individual'), coalesce(p ->> 'mode', 'in_person'), v_room, v_vis, v_pkg, v_fee, auth.uid())
    returning id into v_id;
    v_ids := v_ids || v_id;
  end loop;
  if v_vis then
    perform public.session_notify_family(v_ids[1], 'session_scheduled', 'Yeni randevu',
      case when v_count > 1 then v_count || ' seans, ' || public.session_when(v_start) || ' başlayarak '
             || case v_rep when 'biweekly' then 'iki haftada bir' else 'her hafta' end
           else public.session_when(v_start) end);
  end if;
  return json_build_object('ids', to_json(v_ids), 'conflicts', v_conf);
end $$;
revoke execute on function public.clinic_session_create(jsonb) from public, anon;
grant execute on function public.clinic_session_create(jsonb) to authenticated;

-- Seansı düzelt (önceki tanım: migrations/20261105100000_sessions.sql; yalnız ücret eklendi). 'fee' anahtarı varsa
-- kapsamdaki her seansa (yalnız bu / bu ve sonraki planlılar) yazılır; boş ya da null ücreti siler; anahtar yoksa ücret değişmez.
create or replace function public.clinic_session_update(p_id uuid, p jsonb, p_scope text default 'one')
returns json language plpgsql security definer set search_path = '' as $$
declare
  s public.clinic_sessions;
  v_delta interval := interval '0';
  v_room uuid; v_clin uuid; v_pkg uuid; v_vis boolean; v_min int;
  v_fee numeric := public.session_fee_of(p);
  v_n int := 0; v_conf jsonb := '[]'; r record;
begin
  select * into s from public.clinic_sessions where id = p_id;
  if s.id is null or not public.clinic_session_visible(p_id) then raise exception 'session_not_found' using errcode = 'P0002'; end if;
  v_room := case when p ? 'room_id' then nullif(p ->> 'room_id', '')::uuid else s.room_id end;
  v_clin := case when p ? 'clinician_id' then coalesce(nullif(p ->> 'clinician_id', '')::uuid, s.clinician_id) else s.clinician_id end;
  v_pkg := case when p ? 'package_id' then nullif(p ->> 'package_id', '')::uuid else s.package_id end;
  v_vis := case when p ? 'visible_to_family' then coalesce((p ->> 'visible_to_family')::boolean, false) and s.link_id is not null
                else s.visible_to_family end;
  v_min := coalesce((p ->> 'duration_min')::int, s.duration_min);
  perform public.session_check_refs(s.link_id, case when v_clin is distinct from s.clinician_id then v_clin end, v_room, v_pkg);
  if p ? 'starts_at' then v_delta := (p ->> 'starts_at')::timestamptz - s.starts_at; end if;
  for r in select x.* from public.clinic_sessions x
            where x.id = p_id or (p_scope = 'following' and s.series_id is not null and x.series_id = s.series_id
                                  and x.starts_at > s.starts_at and x.status = 'planned')
            order by x.starts_at loop
    update public.clinic_sessions set
      starts_at = r.starts_at + v_delta, duration_min = v_min,
      kind = coalesce(p ->> 'kind', r.kind), mode = coalesce(p ->> 'mode', r.mode), room_id = v_room, clinician_id = v_clin,
      title = case when p ? 'title' then nullif(btrim(p ->> 'title'), '') else r.title end,
      visible_to_family = v_vis, package_id = v_pkg,
      fee = case when p ? 'fee' then v_fee else r.fee end,
      family_response = case when v_delta <> interval '0' then null else r.family_response end,
      family_note = case when v_delta <> interval '0' then null else r.family_note end,
      updated_at = now()
    where id = r.id;
    v_conf := v_conf || public.session_conflicts(r.clinic_id, v_clin, v_room, r.starts_at + v_delta, v_min, r.id);
    v_n := v_n + 1;
  end loop;
  if v_vis and (v_delta <> interval '0' or (v_vis and not s.visible_to_family)) and s.status = 'planned' then
    perform public.session_notify_family(p_id, case when s.visible_to_family then 'session_changed' else 'session_scheduled' end,
      case when s.visible_to_family then 'Randevu değişti' else 'Yeni randevu' end,
      public.session_when(s.starts_at + v_delta) || case when v_n > 1 then ' (ve sonraki ' || (v_n - 1) || ' seans)' else '' end);
  end if;
  return json_build_object('updated', v_n, 'conflicts', v_conf);
end $$;
revoke execute on function public.clinic_session_update(uuid, jsonb, text) from public, anon;
grant execute on function public.clinic_session_update(uuid, jsonb, text) to authenticated;

-- Aileye giden yollar denetlendi (değişiklik gerekmedi): clinic_sessions'ta yalnız "seans: klinik okur" politikası var (aile satır
-- görmez); family_sessions, family_session_respond, family_offer_respond, family_booking_slots, family_book_slot alanları tek tek
-- yazar (fee yok); session_notify_family bildirimine yalnız tarih / saat gider; calendar_feed_events (uzmanın kendi .ics'i) ücret
-- yazmaz; KVKK dökümünde (data_export_of) seans yok. Test test_mercek_updates.sql bunu ve family_* kaynaklarında fee geçmediğini denetler.

-- =====================================================================
-- 2. Raporu aileye gönder
-- =====================================================================
-- 2.1 Tablo: istemci yazamaz ve okuyamaz (RLS açık, politika yok); okuma ve yazma yalnız aşağıdaki işlevlerle.
create table if not exists public.clinic_shared_reports (
  id              uuid primary key default gen_random_uuid(),
  link_id         uuid references public.clinic_links (id) on delete set null,     -- paylaşım silinse de rapor ailede kalır
  clinic_id       uuid references public.clinics (id) on delete set null,
  family_id       uuid not null references public.families (id) on delete cascade,
  child_id        uuid not null references public.children (id) on delete cascade,
  sent_by         uuid references auth.users (id) on delete set null,
  clinician_name  text not null default '' check (char_length(clinician_name) <= 120),   -- gönderim anındaki "ad, unvan"
  title           text not null check (char_length(btrim(title)) between 1 and 120),
  period_start    date,
  period_end      date,
  content         jsonb not null,
  created_at      timestamptz not null default now(),
  seen_at         timestamptz,                                                        -- bir ebeveynin ilk açışı
  check ((period_start is null) = (period_end is null) and (period_start is null or period_start <= period_end))
);
create index if not exists clinic_shared_reports_family_idx on public.clinic_shared_reports (family_id, created_at desc);
create index if not exists clinic_shared_reports_child_idx on public.clinic_shared_reports (child_id, created_at desc);
create index if not exists clinic_shared_reports_link_idx on public.clinic_shared_reports (link_id, created_at desc);
alter table public.clinic_shared_reports enable row level security;
revoke all on public.clinic_shared_reports from public, anon, authenticated;

-- 2.2 İçerik biçimi v1 (bilinmeyen anahtar reddedilir; yeni biçim yeni "v" ile ve sunucu değişikliğiyle gelir):
--   { "v": 1,
--     "child":  { "name": "≤ 120" },                                  (isteğe bağlı; ebeveynin girdiği ad)
--     "period": { "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" },       (isteğe bağlı; ikisi birlikte, başlangıç ≤ bitiş)
--     "footer": "≤ 500",                                              (isteğe bağlı; Mercek dışa aktarma alt satırını yazar)
--     "sections": [ 1–40 bölüm ] }
--   bölüm: "type" + isteğe bağlı "title" (≤ 200) ve türüne göre:
--     text  { "body": "≤ 8000" }
--     kv    { "rows": [ ["etiket", "değer"], … ≤ 60 ], her metin ≤ 300 }
--     table { "columns": [ ≤ 12 metin ≤ 300 ], "rows": [ ≤ 200 satır, her biri ≤ 12 metin ≤ 300 ] }
--     list  { "items": [ ≤ 60 metin ≤ 500 ] }
--   Bütün içerik (jsonb metni) ≤ 256 KB. Metin dışında değer (sayı, boş, iç içe nesne) yalnız "v"de.
create or replace function public.report_content_fail(p_where text)
returns void language plpgsql immutable set search_path = '' as $$
begin
  raise exception 'Rapor içeriği geçersiz' using errcode = '22023', hint = 'content_invalid', detail = p_where;
end $$;
revoke execute on function public.report_content_fail(text) from public, anon, authenticated;

-- v metin ve en çok n karakter mi (plpgsql: tür denetimi uzunluktan önce, sıra garantili)
create or replace function public.report_str_ok(v jsonb, n int)
returns boolean language plpgsql immutable set search_path = '' as $$
begin
  if v is null or jsonb_typeof(v) <> 'string' then return false; end if;
  return char_length(v #>> '{}') <= n;
end $$;
revoke execute on function public.report_str_ok(jsonb, int) from public, anon, authenticated;

-- v en çok n ögeli dizi ve her ögesi en çok m karakterlik metin mi
create or replace function public.report_strs_ok(v jsonb, n int, m int)
returns boolean language plpgsql immutable set search_path = '' as $$
declare e jsonb;
begin
  if v is null or jsonb_typeof(v) <> 'array' then return false; end if;
  if jsonb_array_length(v) > n then return false; end if;
  for e in select x from jsonb_array_elements(v) x loop
    if not public.report_str_ok(e, m) then return false; end if;
  end loop;
  return true;
end $$;
revoke execute on function public.report_strs_ok(jsonb, int, int) from public, anon, authenticated;

-- v nesne mi ve anahtarları yalnız izinli olanlar mı
create or replace function public.report_keys_ok(v jsonb, allowed text[])
returns boolean language plpgsql immutable set search_path = '' as $$
begin
  if v is null or jsonb_typeof(v) <> 'object' then return false; end if;
  return not exists (select 1 from jsonb_object_keys(v) k where k <> all (allowed));
end $$;
revoke execute on function public.report_keys_ok(jsonb, text[]) from public, anon, authenticated;

create or replace function public.report_content_check(p jsonb)
returns void language plpgsql stable set search_path = '' as $$
declare
  s jsonb; r jsonb; k text; t text; i int := 0; ds date; de date;
begin
  if p is null or jsonb_typeof(p) <> 'object' then perform public.report_content_fail('içerik bir nesne olmalı'); end if;
  if octet_length(p::text) > 262144 then
    raise exception 'Rapor çok büyük (en çok 256 KB)' using errcode = '22023', hint = 'content_too_large';
  end if;
  select x into k from jsonb_object_keys(p) x where x not in ('v', 'sections', 'child', 'period', 'footer') limit 1;
  if k is not null then perform public.report_content_fail('bilinmeyen anahtar: ' || k); end if;
  if p -> 'v' is distinct from '1'::jsonb then perform public.report_content_fail('v = 1 olmalı'); end if;
  if p ? 'footer' and not public.report_str_ok(p -> 'footer', 500) then perform public.report_content_fail('footer'); end if;
  if p ? 'child' then
    if not public.report_keys_ok(p -> 'child', array['name']) or not public.report_str_ok(p -> 'child' -> 'name', 120) then
      perform public.report_content_fail('child');
    end if;
  end if;
  if p ? 'period' then
    if not public.report_keys_ok(p -> 'period', array['start', 'end'])
       or not public.report_str_ok(p -> 'period' -> 'start', 10) or not public.report_str_ok(p -> 'period' -> 'end', 10) then
      perform public.report_content_fail('period');
    end if;
    if (p -> 'period' ->> 'start') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or (p -> 'period' ->> 'end') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      perform public.report_content_fail('period: YYYY-MM-DD');
    end if;
    begin
      ds := (p -> 'period' ->> 'start')::date;
      de := (p -> 'period' ->> 'end')::date;
    exception when others then
      perform public.report_content_fail('period: tarih');
    end;
    if ds > de then perform public.report_content_fail('period: başlangıç bitişten sonra'); end if;
  end if;
  if jsonb_typeof(p -> 'sections') is distinct from 'array' then perform public.report_content_fail('sections: dizi olmalı'); end if;
  if jsonb_array_length(p -> 'sections') not between 1 and 40 then perform public.report_content_fail('sections: 1–40 bölüm'); end if;
  for s in select e from jsonb_array_elements(p -> 'sections') e loop
    i := i + 1;
    if jsonb_typeof(s) <> 'object' then perform public.report_content_fail('sections[' || i || ']'); end if;
    t := case when jsonb_typeof(s -> 'type') = 'string' then s ->> 'type' end;
    if t is null or t not in ('text', 'kv', 'table', 'list') then perform public.report_content_fail('sections[' || i || '].type'); end if;
    if not public.report_keys_ok(s, array['type', 'title'] || case t when 'text' then array['body'] when 'kv' then array['rows']
                                                                      when 'table' then array['columns', 'rows'] else array['items'] end) then
      perform public.report_content_fail('sections[' || i || ']: bilinmeyen anahtar');
    end if;
    if s ? 'title' and not public.report_str_ok(s -> 'title', 200) then perform public.report_content_fail('sections[' || i || '].title'); end if;
    if t = 'text' then
      if not public.report_str_ok(s -> 'body', 8000) then perform public.report_content_fail('sections[' || i || '].body'); end if;
    elsif t in ('kv', 'table') then
      if jsonb_typeof(s -> 'rows') is distinct from 'array' then perform public.report_content_fail('sections[' || i || '].rows'); end if;
      if jsonb_array_length(s -> 'rows') > (case t when 'kv' then 60 else 200 end) then
        perform public.report_content_fail('sections[' || i || '].rows: en çok ' || case t when 'kv' then 60 else 200 end);
      end if;
      if t = 'table' and not public.report_strs_ok(s -> 'columns', 12, 300) then
        perform public.report_content_fail('sections[' || i || '].columns');
      end if;
      for r in select e from jsonb_array_elements(s -> 'rows') e loop
        if t = 'kv' and not (case when public.report_strs_ok(r, 2, 300) then jsonb_array_length(r) = 2 else false end) then
          perform public.report_content_fail('sections[' || i || '].rows: [etiket, değer]');
        elsif t = 'table' and not public.report_strs_ok(r, 12, 300) then
          perform public.report_content_fail('sections[' || i || '].rows');
        end if;
      end loop;
    else
      if not public.report_strs_ok(s -> 'items', 60, 500) then perform public.report_content_fail('sections[' || i || '].items'); end if;
    end if;
  end loop;
end $$;
revoke execute on function public.report_content_check(jsonb) from public, anon, authenticated;

-- 2.3 Uzman: raporu aileye gönder. Seçili çalışma alanının uzmanı (clinician_access), paylaşım açık ve ona görünür
-- (clinic_link_mine = etkin + bu alanın + clinic_link_visible; clinic_link_open kuralı). Paylaşım başına kayan 24 saatte en çok 20.
-- Ebeveynlere report_shared (adsız, klinik ayrıntısız metin; gönderen uzman olduğu için olağan anlık bildirim sınırına tabi).
create or replace function public.clinic_report_share(p_link uuid, p_title text, p_period_start date, p_period_end date, p_content jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  v_name text;
  v_title text := btrim(coalesce(p_title, ''));
  v_id uuid;
begin
  if not public.clinician_access() then
    raise exception 'Üyelik etkin değil' using errcode = 'P0402', hint = 'no_access';
  end if;
  if p_link is null or not public.clinic_link_mine(p_link) then
    raise exception 'Bu aileyle paylaşım açık değil' using errcode = '42501', hint = 'link_not_visible';
  end if;
  if char_length(v_title) not between 1 and 120 then
    raise exception 'Rapor başlığı 1–120 karakter olmalı' using errcode = '22023', hint = 'title_invalid';
  end if;
  if (p_period_start is null) <> (p_period_end is null) or p_period_start > p_period_end then
    raise exception 'Rapor dönemi geçersiz' using errcode = '22023', hint = 'period_invalid';
  end if;
  perform public.report_content_check(p_content);
  select * into l from public.clinic_links where id = p_link;
  perform pg_advisory_xact_lock(hashtextextended('report_share:' || p_link::text, 0));
  if (select count(*) from public.clinic_shared_reports
       where link_id = p_link and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'Bu aileye son 24 saatte 20 rapor gönderdin; biraz sonra yeniden dene'
      using errcode = 'P0001', hint = 'too_many_reports';
  end if;
  select left(concat_ws(', ', nullif(btrim(c.name), ''), nullif(btrim(c.title), '')), 120) into v_name
    from public.clinicians c where c.id = auth.uid();
  insert into public.clinic_shared_reports (link_id, clinic_id, family_id, child_id, sent_by, clinician_name, title,
                                            period_start, period_end, content)
  values (l.id, l.clinic_id, l.family_id, l.child_id, auth.uid(), coalesce(v_name, ''), v_title, p_period_start, p_period_end, p_content)
  returning id into v_id;
  perform public.notify_parents(l.family_id, 'report_shared', 'Uzmanınızdan yeni rapor',
    'Uzmanınız bir rapor paylaştı. Moyo''da açabilirsiniz.', jsonb_build_object('report_id', v_id, 'link_id', l.id), l.child_id);
  return v_id;
end $$;
revoke execute on function public.clinic_report_share(uuid, text, date, date, jsonb) from public, anon;
grant execute on function public.clinic_report_share(uuid, text, date, date, jsonb) to authenticated;

-- 2.4 Uzman: bu paylaşıma gönderilenler (paylaşım ona görünürken; bittiyse de liste kalır, ama paylaşım bittikten sonraki
-- ilk açılış uzmana gösterilmez: seen_at yalnız paylaşım etkinken ya da bitmeden önce açıldıysa döner). İçerik dönmez.
create or replace function public.clinic_reports_sent(p_link uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare l public.clinic_links%rowtype;
begin
  if not public.clinician_access() then
    raise exception 'Üyelik etkin değil' using errcode = 'P0402', hint = 'no_access';
  end if;
  select * into l from public.clinic_links where id = p_link;
  if l.id is null or l.clinic_id is distinct from public.my_clinic_id() or not public.clinic_link_visible(p_link) then
    raise exception 'Bu aileyle paylaşım açık değil' using errcode = '42501', hint = 'link_not_visible';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
            'id', r.id, 'title', r.title, 'period_start', r.period_start, 'period_end', r.period_end,
            'clinician_name', r.clinician_name, 'mine', r.sent_by is not distinct from auth.uid(), 'created_at', r.created_at,
            'seen_at', case when l.status = 'active' or r.seen_at <= l.revoked_at then r.seen_at end)
            order by r.created_at desc, r.id)
           from public.clinic_shared_reports r where r.link_id = p_link), '[]'::jsonb);
end $$;
revoke execute on function public.clinic_reports_sent(uuid) from public, anon;
grant execute on function public.clinic_reports_sent(uuid) to authenticated;

-- 2.5 Aile: alınan raporlar arşivi (en yeni önce; p_child ile tek çocuk). Paylaşım bitse ya da silinse de kalır. İçerik dönmez.
create or replace function public.family_reports(p_child uuid default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id, 'child_id', r.child_id, 'child_name', c.name, 'title', r.title, 'clinician_name', r.clinician_name,
      'period_start', r.period_start, 'period_end', r.period_end, 'created_at', r.created_at, 'seen_at', r.seen_at)
    order by r.created_at desc, r.id), '[]'::jsonb)
  from public.clinic_shared_reports r
  left join public.children c on c.id = r.child_id
  where r.family_id = public.my_family_id() and (p_child is null or r.child_id = p_child)
$$;
revoke execute on function public.family_reports(uuid) from public, anon;
grant execute on function public.family_reports(uuid) to authenticated;

-- 2.6 Aile: tek rapor (içerikle); ilk açışta seen_at yazılır.
create or replace function public.family_report(p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  fam uuid := public.my_family_id();
  r public.clinic_shared_reports%rowtype;
begin
  select * into r from public.clinic_shared_reports where id = p_id and family_id = fam;
  if fam is null or r.id is null then
    raise exception 'Rapor bulunamadı' using errcode = 'P0002', hint = 'report_not_found';
  end if;
  if r.seen_at is null then
    update public.clinic_shared_reports set seen_at = now() where id = r.id and seen_at is null;
    select x.seen_at into r.seen_at from public.clinic_shared_reports x where x.id = r.id;
  end if;
  return jsonb_build_object(
    'id', r.id, 'link_id', r.link_id, 'child_id', r.child_id, 'child_name', (select c.name from public.children c where c.id = r.child_id),
    'title', r.title, 'clinician_name', r.clinician_name, 'period_start', r.period_start, 'period_end', r.period_end,
    'created_at', r.created_at, 'seen_at', r.seen_at, 'content', r.content);
end $$;
revoke execute on function public.family_report(uuid) from public, anon;
grant execute on function public.family_report(uuid) to authenticated;

-- =====================================================================
-- 3. Kayıt türü çoklu seçim
-- =====================================================================
-- Sabit sıra ve tekil: frequency, abc, duration (bilinmeyen değeri sessizce düşürür; hedef davranışta tetikleyici önce reddeder)
create or replace function public.behavior_log_types_norm(p text[])
returns text[] language sql immutable set search_path = '' as $$
  select case when p is null then null
              else array(select u.t from unnest(array['frequency', 'abc', 'duration']::text[]) with ordinality u(t, o)
                          where u.t = any (p) order by u.o) end
$$;
revoke execute on function public.behavior_log_types_norm(text[]) from public, anon, authenticated;

alter table public.clinic_target_behaviors add column if not exists log_types text[]
  check (cardinality(log_types) between 1 and 3 and log_types <@ array['frequency', 'abc', 'duration']::text[]);
-- Var olan hedefler log_type'tan doldurulur (koruma tetikleyicisi updated_at'i değiştirmesin diye bu adımda kapalı;
-- yeniden çalışınca dolduracak satır yoksa hiçbir şey yapılmaz)
do $$ begin
  if exists (select 1 from public.clinic_target_behaviors where log_types is null) then
    alter table public.clinic_target_behaviors disable trigger clinic_target_behaviors_guard;
    update public.clinic_target_behaviors set log_types = array[log_type] where log_types is null;
    alter table public.clinic_target_behaviors enable trigger clinic_target_behaviors_guard;
  end if;
end $$;
-- Varsayılan {frequency} (log_type'ın varsayılanıyla aynı): tetikleyicisiz yazımda (ör. çoğaltma kipi) da satır tutarlı kalır
alter table public.clinic_target_behaviors alter column log_types set default '{frequency}';
alter table public.clinic_target_behaviors alter column log_types set not null;

-- log_type ↔ log_types: eklemede log_types verilmediyse (boş ya da varsayılan {frequency} kalmış ve log_type başka: eski uygulama
-- yalnız log_type yazdı) log_types = {log_type}; güncellemede log_types değişmeden yalnız log_type değiştiyse (eski uygulama)
-- log_types = {log_type}; öteki her durumda log_types kazanır. Sonunda sabit sıra, log_type = ilk tür.
create or replace function public.clinic_target_behaviors_log_types() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.log_types is null
     or (tg_op = 'INSERT' and new.log_types = '{frequency}'::text[] and new.log_type is not null and new.log_type <> 'frequency') then
    new.log_types := array[new.log_type];
  elsif tg_op = 'UPDATE' and new.log_types is not distinct from old.log_types and new.log_type is distinct from old.log_type then
    new.log_types := array[new.log_type];
  end if;
  if cardinality(new.log_types) = 0 or array_position(new.log_types, null) is not null
     or not (new.log_types <@ array['frequency', 'abc', 'duration']::text[]) then
    raise exception 'Kayıt türü en az biri olmalı: sıklık, ABC ya da süre' using errcode = 'check_violation';
  end if;
  new.log_types := public.behavior_log_types_norm(new.log_types);
  new.log_type := new.log_types[1];
  return new;
end $$;
revoke execute on function public.clinic_target_behaviors_log_types() from public, anon, authenticated;
drop trigger if exists clinic_target_behaviors_log_types on public.clinic_target_behaviors;
create trigger clinic_target_behaviors_log_types before insert or update on public.clinic_target_behaviors
  for each row execute function public.clinic_target_behaviors_log_types();

-- Olay: bildirim anındaki türler (hedefe bağlı değilse boş)
alter table public.behavior_incidents add column if not exists log_types text[]
  check (log_types is null or (cardinality(log_types) between 1 and 3 and log_types <@ array['frequency', 'abc', 'duration']::text[]));
update public.behavior_incidents set log_types = array[log_type] where log_types is null and log_type is not null;

-- Yeni olayda sunucu yazar (önceki tanım: migrations/20261120200000_family_keeps_records.sql; türler eklendi):
-- hedef davranışın adı; log_types yoksa log_type'tan, varsa sabit sıra ve log_type = ilk tür.
create or replace function public.behavior_incidents_fill() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.behavior_title := coalesce((select b.title from public.clinic_target_behaviors b where b.id = new.behavior_id), '');
  if new.log_types is null and new.log_type is not null then new.log_types := array[new.log_type]; end if;
  if new.log_types is not null then
    new.log_types := public.behavior_log_types_norm(new.log_types);
    new.log_type := new.log_types[1];
  end if;
  return new;
end $$;
revoke execute on function public.behavior_incidents_fill() from public, anon, authenticated;

-- Aile: bildirebileceğim hedef davranışlar (önceki tanım: migrations/20261110110000_target_behaviors.sql; log_types eklendi)
create or replace function public.family_target_behaviors()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'link_id', l.id, 'child_id', l.child_id, 'child_name', c.name, 'clinic_id', l.clinic_id,
      'behaviors', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'title', b.title, 'description', b.description,
                     'strategies', b.strategies, 'log_type', b.log_type, 'log_types', to_jsonb(b.log_types), 'status', b.status)
                     order by b.started_at)
                   from public.clinic_target_behaviors b where b.link_id = l.id and not b.archived and b.parent_logging), '[]'::jsonb)
    ) order by l.consent_at), '[]'::jsonb)
  from public.clinic_links l left join public.children c on c.id = l.child_id
  where l.status = 'active' and l.family_id = public.my_family_id()
$$;
revoke execute on function public.family_target_behaviors() from public, anon;
grant execute on function public.family_target_behaviors() to authenticated;

-- Aile: olay bildir (önceki tanım: migrations/20261110110000_target_behaviors.sql; imza ve hata anahtarları aynı).
-- Hedefe bağlıysa seçili HER türün alanı zorunlu ve yazılır: frequency → p_count, abc → p_antecedent + p_consequence,
-- duration → p_duration_min; seçili olmayan türün alanı yazılmaz. "Diğer" olay (p_behavior boş) değişmedi.
create or replace function public.family_incident_report(p_link uuid, p_behavior uuid default null, p_occurred_at timestamptz default null,
  p_count int default null, p_duration_min int default null, p_antecedent text default '', p_consequence text default '',
  p_strategy text default '', p_response int default null, p_other_behavior text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  l record; v_bid uuid; v_types text[]; v_at timestamptz := coalesce(p_occurred_at, now()); v_id uuid; v_name text;
  v_freq boolean; v_abc boolean; v_dur boolean;
begin
  select * into l from public.clinic_links where id = p_link and status = 'active' and family_id = public.my_family_id();
  if l.id is null then raise exception 'link_not_found'; end if;
  if v_at > now() + interval '5 minutes' or v_at < now() - interval '30 days' then raise exception 'date_out_of_range'; end if;
  if p_response is not null and (p_response < 1 or p_response > 5) then raise exception 'response_invalid'; end if;
  if p_behavior is not null then
    select b.id, b.log_types into v_bid, v_types from public.clinic_target_behaviors b
     where b.id = p_behavior and b.link_id = l.id and not b.archived and b.parent_logging;
    if v_bid is null then raise exception 'behavior_not_found'; end if;
    v_freq := 'frequency' = any (v_types);
    v_abc := 'abc' = any (v_types);
    v_dur := 'duration' = any (v_types);
    if v_freq and (p_count is null or p_count < 1) then raise exception 'count_required'; end if;
    if v_abc and (char_length(trim(coalesce(p_antecedent, ''))) = 0 or char_length(trim(coalesce(p_consequence, ''))) = 0) then
      raise exception 'abc_required';
    end if;
    if v_dur and p_duration_min is null then raise exception 'duration_required'; end if;
  elsif char_length(trim(coalesce(p_other_behavior, ''))) = 0 then
    raise exception 'behavior_required';
  end if;
  select coalesce(nullif(trim(p.name), ''), p.nickname) into v_name from public.profiles p where p.id = auth.uid();
  insert into public.behavior_incidents (link_id, family_id, child_id, behavior_id, log_type, log_types, other_behavior, occurred_at,
                                         count, duration_min, antecedent, consequence, strategy, response, reporter_id, reporter_name)
  values (l.id, l.family_id, l.child_id, v_bid, v_types[1], v_types,
          case when v_bid is null then left(trim(p_other_behavior), 120) else '' end, v_at,
          case when v_bid is null or v_freq then p_count end,
          case when v_bid is null or v_dur then p_duration_min end,
          case when v_bid is null or v_abc then left(trim(coalesce(p_antecedent, '')), 500) else '' end,
          case when v_bid is null or v_abc then left(trim(coalesce(p_consequence, '')), 500) else '' end,
          left(trim(coalesce(p_strategy, '')), 200), p_response, auth.uid(), left(coalesce(v_name, ''), 80))
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function public.family_incident_report(uuid, uuid, timestamptz, int, int, text, text, text, int, text) from public, anon;
grant execute on function public.family_incident_report(uuid, uuid, timestamptz, int, int, text, text, text, int, text) to authenticated;

-- =====================================================================
-- 4. Ebeveyn eğitimi bayrağı (parent_training) ve bildirim motoru
-- =====================================================================
-- Kuralın bağlı olduğu özellik bayrağı: tanımlıysa kural yalnız bayrağı açık kişiye gider (flag_on: kişiye istisna → genel bayrak
-- + yüzde; satır yoksa kapalı). Eğitime yönelik iki kural parent_training'e bağlanır. Öneri yeniden çalışınca yalnız boş ya da
-- farklı olanı yazar; nudge_engine göçünün kural tohumu bu sütuna dokunmaz.
alter table public.nudge_rules add column if not exists feature_flag text
  check (feature_flag is null or feature_flag ~ '^[a-z][a-z0-9_.]{1,59}$');
update public.nudge_rules set feature_flag = 'parent_training', updated_at = now()
 where trigger in ('training_none', 'training_draft') and feature_flag is distinct from 'parent_training';

-- Karar: tek kişi + tek kural (önceki tanım: migrations/20261120230000_nudge_engine.sql; yalnız kuralın özellik bayrağı eklendi:
-- kapalıysa 'flag_off', kayıt yazılmaz, bayrak açılınca kural süresi dolmamışsa gönderilir)
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
  if p_rule.feature_flag is not null and not public.flag_on(p_user, p_rule.feature_flag) then return 'flag_off'; end if;
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
revoke execute on function public.nudge_try(uuid, public.nudge_rules, text, jsonb, timestamptz) from public, anon, authenticated;

-- Panel kural listesi (önceki tanım: migrations/20261120230000_nudge_engine.sql; feature_flag eklendi). Her admin rolü okur.
create or replace function public.admin_nudge_rules()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return (select coalesce(json_agg(json_build_object(
            'key', r.key, 'product', r.product, 'label', r.label, 'trigger', r.trigger, 'from_step', r.from_step,
            'target_step', r.target_step, 'wait_hours', r.wait_hours, 'category', r.category, 'title', r.title, 'body', r.body,
            'route', r.route, 'sort', r.sort, 'enabled', r.enabled, 'feature_flag', r.feature_flag, 'updated_at', r.updated_at)
            order by r.product, r.sort, r.key), '[]')
            from public.nudge_rules r);
end $$;
revoke execute on function public.admin_nudge_rules() from public, anon;
grant execute on function public.admin_nudge_rules() to authenticated;

-- =====================================================================
-- 5. Sonsuz tarih koruması (yeni tablo; CLAUDE.md kural 4)
-- =====================================================================
select public.finite_time_guard_attach();
