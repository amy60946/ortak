-- Ad kararı (kullanıcı, 28 Ekim 2026; akislar.md 5.5): ebeveynin ABC kaydı iki uygulamada "Davranış kaydı".
-- Uzmana giden bildirimin başlığı "Yeni zor an kaydı" → "Yeni davranış kaydı". Tablo, bildirim türü (abc_event),
-- alıcılar ve veri değişmez; yalnız metin. Tekrar çalıştırılabilir (create or replace).
-- Önkoşul: migrations/20261022100000_clinic_assignments.sql (clinic_link_recipients).

create or replace function public.abc_events_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in
    select l.clinic_id, rc.rid, count(*) as n, string_agg(c.name, ', ' order by c.name) as names,
           max(n.intensity) as intensity, bool_or(n.audio_path is not null) as has_audio,
           (array_agg(n.child_id))[1] as first_child,
           jsonb_agg(jsonb_build_object('abc_id', n.id, 'child_id', n.child_id)) as items
      from new_rows n
      join public.clinic_links l on l.child_id = n.child_id and l.status = 'active'
      join public.children c on c.id = n.child_id
      cross join lateral public.clinic_link_recipients(l.id) as rc(rid)
     group by l.clinic_id, rc.rid
  loop
    perform public.notify(r.rid, 'clinic', 'abc_event', 'Yeni davranış kaydı: ' || r.names,
      'Şiddet ' || r.intensity || '/5' || case when r.has_audio then ' · 🎤 sesli kayıt' else '' end,
      jsonb_build_object('items', r.items, 'abc_id', (r.items -> 0 ->> 'abc_id'), 'child_id', r.first_child), null,
      case when r.n = 1 then r.first_child end);
  end loop;
  return null;
end $$;
revoke execute on function public.abc_events_notify() from public, anon, authenticated;
