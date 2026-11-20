-- 20261120130000_billing_prices: Moyo Mercek fiyatları (kullanıcı kararı 20 Kasım 2026; ekonomi.md 9)
\set ON_ERROR_STOP on
do $$
declare r record;
begin
  for r in select * from (values ('solo_monthly', 1199.99), ('solo_yearly', 11999.99),
                                 ('clinic_monthly', 3999.99), ('clinic_yearly', 39999.99)) v(id, price) loop
    if (select price_try from public.billing_plans where id = r.id) is distinct from r.price then
      raise exception 'TEST BAŞARISIZ: % fiyatı % olmalı', r.id, r.price;
    end if;
  end loop;
  -- yıllık = aylığın 10 katı (,99 yuvarlamasıyla; indirim %16,67), iki pakette de
  if exists (select 1 from public.billing_plans m join public.billing_plans y on y.package = m.package and y.period = 'yearly'
              where m.period = 'monthly' and abs(y.price_try - (m.price_try * 10)) > 0.10) then
    raise exception 'TEST BAŞARISIZ: yıllık fiyat aylığın 10 katı değil';
  end if;
  raise notice 'ok: Moyo Mercek fiyatları';
end $$;
-- uygulama tabloyu yalnız okur; fiyat yine değiştirilemez
set role authenticated;
select 1 / (select count(*)::int from public.billing_plans where active) ;
reset role;
