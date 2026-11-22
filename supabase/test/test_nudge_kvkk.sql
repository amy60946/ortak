-- Hatırlatma kaydı (migrations/20261120231000_nudge_kvkk.sql): KVKK dökümünde "hatirlatmalar"; 12 ay sonra silinir
-- (imha işi "live" değilken yalnız sayar); kıyas seed'i (20261120221000) yüklenir ve yön anahtardan gelir; yetki.
\set ON_ERROR_STOP on
create schema if not exists tst;
create or replace function tst.check(cond boolean, msg text) returns void language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'TEST BAŞARISIZ: %', msg; end if;
  raise notice 'ok: %', msg;
end $$;

insert into auth.users (id, is_anonymous, raw_user_meta_data)
values ('00000000-0000-0000-0000-00000000c0a1', false, '{"nickname": "Ebeveyn"}');
insert into public.nudge_log (user_id, product, rule_key, ref, result, day, at)
values ('00000000-0000-0000-0000-00000000c0a1', 'parent', 'parent_child_none', 'eski', 'sent', current_date - 400, now() - interval '400 days'),
       ('00000000-0000-0000-0000-00000000c0a1', 'parent', 'parent_child_none', 'yeni', 'holdout', current_date - 2, now() - interval '2 days');

-- döküm
select tst.check(jsonb_array_length(public.data_export_of('00000000-0000-0000-0000-00000000c0a1') -> 'hatirlatmalar') = 2,
                 'KVKK dökümünde iki hatırlatma kaydı');
select tst.check((public.data_export_of('00000000-0000-0000-0000-00000000c0a1') -> 'hatirlatmalar' -> 1 ->> 'sonuc') = 'holdout',
                 'döküm sonucu yazar (holdout dahil)');
select tst.check(public.data_export_of('00000000-0000-0000-0000-00000000c0a1') ? 'bildirimler', 'döküm öteki bölümleri korur');

-- silme: live değilken yalnız sayar
insert into public.app_config (key, value) values ('retention', '{"live": false}')
  on conflict (key) do update set value = excluded.value;
select tst.check((public.nudge_log_prune() ->> 'rows')::int = 1 and (select count(*) from public.nudge_log) = 2,
                 'imha işi kapalıyken yalnız sayar');
update public.app_config set value = '{"live": true}' where key = 'retention';
select tst.check((public.nudge_log_prune() ->> 'rows')::int = 1, 'canlıda 12 aydan eski kaydı siler');
select tst.check((select array_agg(ref) from public.nudge_log) = array['yeni'], 'yeni kayıt kalır');
update public.app_config set value = '{"live": true, "nudge_log_days": 5}' where key = 'retention';
select tst.check((public.nudge_log_prune() ->> 'days')::int = 30, 'süre en az 30 gün');

-- kıyas seed'i
select tst.check((select count(*) from public.kpi_benchmarks) >= 28, 'kıyas satırları yüklendi');
select tst.check((select better from public.kpi_benchmarks where key = 'monthly_churn' and product = 'parent') = 'low',
                 'kayıpta düşük olan iyi (yön anahtardan)');
select tst.check((select better from public.kpi_benchmarks where key = 'trial_to_paid' and product = 'clinic') = 'high',
                 'dönüşümde yüksek olan iyi');
select tst.check(not exists (select 1 from public.kpi_benchmarks where note not like 'Arama özetinden%'),
                 'her satırın notu doğrulanmadığını yazar');

-- yetki
select tst.check(not has_function_privilege('anon', 'public.nudge_log_prune()', 'execute')
             and not has_function_privilege('authenticated', 'public.nudge_log_prune()', 'execute'), 'silme işini kullanıcı çağıramaz');
select tst.check(not has_function_privilege('authenticated', 'public.data_export_of(uuid)', 'execute'), 'döküm işlevi doğrudan çağrılamaz');
