-- =====================================================================
-- Seans ücreti aileye de görünür (ÖNERİ, 23 Kasım 2026; kullanıcı kararı 23 Kasım 2026: "seans ücreti ebeveyne aksın, görünür olsun
-- onun tarafında da seans içeriğinde"). Tekrar çalıştırılabilir.
--   Uzmanın elle yazdığı ücret (clinic_sessions.fee, migrations/20261123100000_mercek_updates.sql) aileye yalnız family_sessions
--   ile gider: aileye gösterilen randevuda (visible_to_family, etkin paylaşım) alan `fee` (TL, sayı ya da null). Aileye
--   gösterilmeyen seansın ücreti hiçbir yoldan gitmez. Bildirim metinleri (session_notify_family), uzmanın takvim beslemesi
--   (calendar_feed_events) ve öteki family_* işlevleri değişmez: ücret yazmaz. Ödeme, tahsilat ve fatura yok (bilgi alanı).
--   Tablo politikası değişmez: aile clinic_sessions satırını okuyamaz.
-- Önkoşul: migrations/20261105100000_sessions.sql, migrations/20261123100000_mercek_updates.sql (ikisi de canlıda).
-- Sözleşme: sozlesme/veritabani.md 40.1, akislar.md 27.1, durumlar.md P18, hukuk_notlari.md S. Test: test_mercek_updates.sql.
-- =====================================================================

do $$ begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'clinic_sessions' and column_name = 'fee') then
    raise exception 'Önce migrations/20261123100000_mercek_updates.sql çalıştırılmalı (clinic_sessions.fee yok)';
  end if;
end $$;

-- Ailenin görebildiği randevular (önceki tanım: migrations/20261105100000_sessions.sql; yalnız `fee` eklendi)
create or replace function public.family_sessions(p_from timestamptz default null, p_to timestamptz default null)
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(json_build_object(
      'id', s.id, 'link_id', s.link_id, 'child_id', l.child_id, 'child', public.child_name(l.child_id),
      'clinician', coalesce(m.name, ''), 'clinic', c.name,
      'starts_at', s.starts_at, 'duration_min', s.duration_min, 'kind', s.kind, 'kind_label', public.session_kind_label(s.kind),
      'mode', s.mode, 'room', r.name, 'location', r.location, 'status', s.status,
      'family_response', s.family_response, 'family_note', s.family_note, 'booked_by', s.booked_by,
      'offer_expires_at', s.offer_expires_at, 'series', s.series_id is not null,
      'reminders', (public.clinic_session_settings_row(s.clinic_id)).reminders,
      'fee', s.fee)
    order by s.starts_at), '[]')
  from public.clinic_sessions s
  join public.clinic_links l on l.id = s.link_id and l.status = 'active' and l.family_id = public.my_family_id()
  join public.clinics c on c.id = s.clinic_id
  left join public.clinicians m on m.id = s.clinician_id
  left join public.clinic_rooms r on r.id = s.room_id
  where s.visible_to_family
    and (s.status <> 'offered' or s.offer_expires_at > now())
    and s.starts_at >= coalesce(p_from, now() - interval '60 days')
    and s.starts_at <= coalesce(p_to, now() + interval '180 days')
$$;
revoke execute on function public.family_sessions(timestamptz, timestamptz) from public, anon;
grant execute on function public.family_sessions(timestamptz, timestamptz) to authenticated;
