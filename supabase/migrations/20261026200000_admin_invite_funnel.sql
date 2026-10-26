-- =====================================================================
-- Yönetim paneli: aile davet hunisi (öneri, 26 Ekim 2026; DURUM "UZMAN BAŞLATIR" madde 5)
--   admin_kpi_invites(gün): son N günde oluşturulan AİLE davetleri için
--   gönderildi → açıldı → kayıt/kod girildi → çocuk paylaşıldı, ayrıca süresi dolan / uzmanın iptal ettiği / ailenin reddettiği.
--   Toplam, paylaşım yoluna (channel) ve uzmana göre. Durum adları sozlesme/durumlar.md P15.
--   Sayılar "o adıma ulaşan" davetlerdir (paylaşılan davet açılmış ve kayıt olmuş da sayılır).
-- Önkoşul: migrations/20261026100000_family_invite_links.sql. Tekrar çalıştırılabilir.
-- =====================================================================

create or replace function public.admin_kpi_invites(p_days integer default 30)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  d integer := least(greatest(coalesce(p_days, 30), 1), 365);
  since timestamptz := now() - make_interval(days => d);
begin
  perform public.admin_require();
  return (
    with inv as (
      select i.*,
             (i.opened_at is not null or i.claimed_at is not null or i.used_at is not null) as r_opened,
             (i.claimed_at is not null or i.used_at is not null) and i.declined_at is null as r_claimed,
             i.used_at is not null and i.declined_at is null as r_shared,
             i.declined_at is null and i.revoked_at is null and i.used_at is null and i.claimed_at is null
               and i.expires_at <= now() as r_expired,
             i.revoked_at is not null and i.declined_at is null as r_revoked,
             i.declined_at is not null as r_declined
        from public.clinic_invites i
       where i.kind = 'family' and i.created_at >= since
    ),
    agg as (
      select count(*) as sent, count(*) filter (where r_opened) as opened, count(*) filter (where r_claimed) as claimed,
             count(*) filter (where r_shared) as shared, count(*) filter (where r_expired) as expired,
             count(*) filter (where r_revoked) as revoked, count(*) filter (where r_declined) as declined
        from inv
    )
    select json_build_object(
      'days', d,
      'totals', (select row_to_json(agg) from agg),
      'by_channel', (select coalesce(json_agg(x order by x.sent desc), '[]') from (
          select coalesce(channel, 'bilinmiyor') as channel, count(*) as sent,
                 count(*) filter (where r_opened) as opened, count(*) filter (where r_shared) as shared
            from inv group by 1) x),
      'by_clinician', (select coalesce(json_agg(x order by x.sent desc, x.clinician), '[]') from (
          select m.id as clinician_id, m.name as clinician, c.name as clinic, count(*) as sent,
                 count(*) filter (where r_opened) as opened, count(*) filter (where r_claimed) as claimed,
                 count(*) filter (where r_shared) as shared, count(*) filter (where r_expired) as expired,
                 count(*) filter (where r_revoked) as revoked, count(*) filter (where r_declined) as declined
            from inv join public.clinicians m on m.id = inv.clinician_id join public.clinics c on c.id = inv.clinic_id
           group by m.id, m.name, c.name
           limit 200) x)
    ));
end $$;
revoke execute on function public.admin_kpi_invites(integer) from public, anon;
grant execute on function public.admin_kpi_invites(integer) to authenticated;
