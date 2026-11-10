-- Görünen ad Moyo (proposed/20261110120000_moyo_name_texts.sql): ebeveyne giden bildirim metinlerinde eski ad kalmaz,
-- işlevlerin yetkileri değişmez (anon çalıştıramaz).
\set ON_ERROR_STOP on
do $$
declare r record;
begin
  for r in select p.proname, p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('redeem_guest_pass', 'referral_on_paid', 'clinic_waitlist_offer') loop
    if r.prosrc like '%ParentApp%' then raise exception 'eski ad kaldı: %', r.proname; end if;
    if r.prosrc not like '%Moyo%' then raise exception 'Moyo yok: %', r.proname; end if;
    raise notice 'ok: % metni Moyo', r.proname;
  end loop;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname in ('redeem_guest_pass', 'referral_on_paid', 'clinic_waitlist_offer')) <> 3 then
    raise exception 'üç işlevden biri yok';
  end if;
  if has_function_privilege('anon', 'public.redeem_guest_pass(text)', 'execute') then raise exception 'anon redeem_guest_pass çalıştırabiliyor'; end if;
  raise notice 'ok: yetkiler aynı';
end $$;
