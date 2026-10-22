-- =====================================================================
-- XP takibi Y5 + Y2 (22 Ekim 2026, kullanıcı onayı; ÖNERİ, henüz uygulanmadı)
--   Y5 "Kendiliğinden yaptı": oyun, çocuğun "Yaptım"ı görevin hatırlatma saatinden önce bastığını bilmeli →
--      child_tasks yanıtına `reminder` (HH:MM ya da null) eklenir. Bonus XP oyunda hesaplanır (sunucu XP tutmaz).
--   Y2 "Zor görevde 2× XP": "Yapamam" sonrası oyun bazen 2× XP teklifi gösterir; teklif ve çocuğun seçimi kaydedilir
--      ki ebeveyn ve uzman "teklif sonrası denedi" bilgisini görebilsin (cesaret göstergesi, tanı değil).
--      Tablo `task_boosts` (RLS: aile okur), yazan yalnız `child_record_boost` (çocuk, kendi görevi).
-- Geriye uyum: child_tasks'a yalnız sütun eklenir (eski oyun sürümü fazla alanı yok sayar).
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Y5: child_tasks + reminder (dönüş tipi değiştiği için düşürülüp yeniden kurulur; izinler aynı)
-- ---------------------------------------------------------------------
drop function if exists public.child_tasks(date, date);
create function public.child_tasks(p_from date, p_to date)
returns table (task_id uuid, date date, title text, description text, emoji text, coins integer,
               recurring boolean, repeat_kind text, requires_review boolean, status text, parent_note text,
               skill text, difficulty text, reminder text)
language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  if p_to < p_from or p_to - p_from > 31 then
    raise exception 'Tarih aralığı en fazla 31 gün olabilir';
  end if;
  return query
    select t.id, d::date, t.title, t.description, t.emoji, a.coins, t.recurring, t.repeat_kind, t.requires_review,
           coalesce(c.status, 'assigned'), c.parent_note, t.skill, a.difficulty, t.reminder::text
    from public.task_assignments a
    join public.tasks t on t.id = a.task_id
    cross join generate_series(p_from, p_to, interval '1 day') as d
    left join public.completions c on c.task_id = t.id and c.child_id = me and c.date = d::date
    where a.child_id = me and public.task_occurs_on(t, d::date)
    order by d, t.sort_order;
end $$;
revoke execute on function public.child_tasks(date, date) from public, anon;
grant execute on function public.child_tasks(date, date) to authenticated;

-- ---------------------------------------------------------------------
-- Y2: 2× XP teklifi kaydı
-- ---------------------------------------------------------------------
create table if not exists public.task_boosts (
  child_id    uuid not null references public.children (id) on delete cascade,
  task_id     uuid not null references public.tasks (id) on delete cascade,
  date        date not null,
  family_id   uuid not null references public.families (id) on delete cascade,
  choice      text not null check (choice in ('accepted', 'skipped')),   -- "Deneyeceğim" / "Şimdi değil"
  offered_at  timestamptz not null default now(),
  primary key (child_id, task_id, date)
);
create index if not exists task_boosts_family_idx on public.task_boosts (family_id, offered_at desc);
alter table public.task_boosts enable row level security;
drop policy if exists "teklif: aile okur" on public.task_boosts;
create policy "teklif: aile okur" on public.task_boosts for select to authenticated using (family_id = public.my_family_id());
drop policy if exists "teklif: çocuk kendi okur" on public.task_boosts;
create policy "teklif: çocuk kendi okur" on public.task_boosts for select to authenticated using (child_id = public.my_child_id());
revoke insert, update, delete, truncate on public.task_boosts from anon, authenticated;

-- Çocuk teklife cevap verir. Yalnız kendisine atanmış ve o gün geçerli görev; bugün ya da dün (saat dilimi payı).
-- Aynı görev örneği için tek kayıt (son seçim geçerli). Haftada en çok 1 teklif kuralı oyundadır; sunucu yine de
-- son 7 günde 3'ten fazla teklifi reddeder (kötüye kullanım sınırı).
create or replace function public.child_record_boost(p_task_id uuid, p_date date, p_choice text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
  fam uuid;
  t public.tasks%rowtype;
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  if p_choice not in ('accepted', 'skipped') then
    raise exception 'Geçersiz seçim';
  end if;
  select tk.* into t from public.tasks tk
    join public.task_assignments a on a.task_id = tk.id and a.child_id = me
    where tk.id = p_task_id;
  if not found or not public.task_occurs_on(t, p_date) then
    raise exception 'Görev bulunamadı';
  end if;
  if p_date > current_date + 1 or p_date < current_date - 1 then
    raise exception 'Bu günün görevi için teklif kaydedilemez';
  end if;
  if (select count(*) from public.task_boosts b
       where b.child_id = me and b.offered_at > now() - interval '7 days'
         and not (b.task_id = p_task_id and b.date = p_date)) >= 3 then
    raise exception 'Çok fazla teklif' using errcode = 'P0001';
  end if;
  select family_id into fam from public.children where id = me;
  insert into public.task_boosts (child_id, task_id, date, family_id, choice)
  values (me, p_task_id, p_date, fam, p_choice)
  on conflict (child_id, task_id, date) do update set choice = excluded.choice;
end $$;
revoke execute on function public.child_record_boost(uuid, date, text) from public, anon;
grant execute on function public.child_record_boost(uuid, date, text) to authenticated;
