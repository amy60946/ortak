-- İnceleme ayrıntısı (kullanıcı isteği 27 Ekim 2026; sozlesme/akislar.md 3, durumlar.md 1, ekonomi.md 2.2a)
--
-- ParentApp İnceleme'de çocuğun "Yaptım" dediği görev için ebeveyn:
--   1. "Motive etmek ne kadar zordu?" 1 (çok kolay) … 5 (çok zor), isteğe bağlı → completions.motivation.
--      Ebeveynin gözlemidir; puan ya da tanı değildir. Paylaşım açıksa bağlı uzman okur (var olan "bağlı klinik okur" politikası).
--   2. Güneş Taşı ayarı: onayda verilecek taş 0–6 (boş = zorluğa göre kolay 1 / orta 2 / zor 3) → completions.stones.
--      Coin ödülü (task_assignments.coins) değişmez.
--   3. Not (oyunda görünür, ≤ 300; uygulama 140 ile sınırlar) → completions.parent_note (onayda, retde, tekrar denemede).
--   4. Karar: Onayla (approved) / Reddet (rejected, nihai) / Tekrar dene (retry, YENİ).
-- retry: görev çocuğa geri döner, çocuk yeniden "Yaptım" diyebilir (child_set_status 'retry'yi nihai saymaz).
--   Yalnız bugünün (± 1 gün saat dilimi payı) görevi; geçmiş gün oyunda "kaçırıldı" olduğundan anlamsız.
--   Eski oyun sürümleri bilinmeyen durumu "Atandı" sayar (C# ParseStatus): görev yapılacaklara döner, not ayrıca gösterilmez.
--   Onaylı kayıt retry'ye çekilirse coin ve taş geri alınır (var olan tetikleyiciler).
-- review_completion iki yeni isteğe bağlı parametre alır; eski 5 parametreli çağrılar aynen çalışır.
-- Tekrar çalıştırılabilir.

-- ---------------------------------------------------------------- completions: yeni alanlar ve durum
alter table public.completions add column if not exists motivation smallint;
alter table public.completions add column if not exists stones smallint;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'completions_motivation_check') then
    alter table public.completions add constraint completions_motivation_check check (motivation between 1 and 5);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'completions_stones_check') then
    alter table public.completions add constraint completions_stones_check check (stones between 0 and 6);
  end if;
end $$;
alter table public.completions drop constraint if exists completions_status_check;
alter table public.completions add constraint completions_status_check
  check (status in ('pending', 'approved', 'declined', 'rejected', 'retry'));

-- ---------------------------------------------------------------- taş: ebeveynin belirlediği miktar (yoksa zorluğa göre)
create or replace function public.completions_sun_stone_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  n integer;
  diff text;
  amt integer;
  was_approved boolean := tg_op in ('UPDATE', 'DELETE') and old.status = 'approved';
  is_approved boolean := tg_op in ('INSERT', 'UPDATE') and new.status = 'approved';
  row_ public.completions%rowtype;
begin
  if tg_op = 'DELETE' then row_ := old; else row_ := new; end if;
  if is_approved = was_approved then
    return null;
  end if;
  if is_approved then
    select a.difficulty into diff from public.task_assignments a where a.task_id = row_.task_id and a.child_id = row_.child_id;
    if not found then
      return null;
    end if;
    amt := coalesce(row_.stones, public.stones_for_difficulty(diff));
    if amt <= 0 then
      return null;
    end if;
    insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, amt, 'task',
            row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  else
    select coalesce(sum(l.amount), 0) into n from public.sun_stone_ledger l
      where l.child_id = row_.child_id and l.reason in ('task', 'task_undo') and split_part(l.ref, ':', 1) = row_.id::text;
    if n <= 0 then
      return null;
    end if;
    insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref)
    values (row_.family_id, row_.child_id, -n, 'task_undo', row_.id::text || ':' || extract(epoch from clock_timestamp())::text)
    on conflict do nothing;
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------- review_completion: + motivasyon, taş, retry
drop function if exists public.review_completion(uuid, uuid, date, text, text);
create or replace function public.review_completion(p_task_id uuid, p_child_id uuid, p_date date, p_status text,
                                                    p_note text default null, p_motivation integer default null,
                                                    p_stones integer default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  fam uuid := public.my_family_id();
begin
  if fam is null or public.child_family(p_child_id) is distinct from fam or public.task_family(p_task_id) is distinct from fam then
    raise exception 'Yetki yok' using errcode = '42501';
  end if;
  if p_status not in ('approved', 'rejected', 'pending', 'retry') then
    raise exception 'Geçersiz durum';
  end if;
  if p_motivation is not null and p_motivation not between 1 and 5 then
    raise exception 'Zorluk 1 ile 5 arasında olmalı';
  end if;
  if p_stones is not null and p_stones not between 0 and 6 then
    raise exception 'Güneş Taşı 0 ile 6 arasında olmalı';
  end if;
  if p_status = 'retry' and (p_date < current_date - 1 or p_date > current_date + 1) then
    raise exception 'Yalnız bugünün görevi tekrar denenebilir' using hint = 'retry_past';
  end if;
  insert into public.completions (family_id, task_id, child_id, date, status, parent_note, reviewed_at, reviewed_by, motivation, stones)
  values (fam, p_task_id, p_child_id, p_date, p_status, nullif(trim(p_note), ''), now(), auth.uid(), p_motivation,
          case when p_status = 'approved' then p_stones end)
  on conflict (task_id, child_id, date) do update
    set status = excluded.status, parent_note = excluded.parent_note, reviewed_at = now(), reviewed_by = auth.uid(),
        motivation = excluded.motivation, stones = excluded.stones;
end $$;

-- ---------------------------------------------------------------- bildirim: tekrar dene (çocuğa); ret metni nihai
create or replace function public.completions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  t record;
  coins integer;
  by_child boolean;
  nm text := public.child_name(new.child_id);
  d jsonb;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return null; end if;
  select title, emoji into t from public.tasks where id = new.task_id;
  select a.coins into coins from public.task_assignments a where a.task_id = new.task_id and a.child_id = new.child_id;
  by_child := exists (select 1 from public.children where id = new.child_id and user_id = auth.uid());
  d := jsonb_build_object('task_id', new.task_id, 'child_id', new.child_id, 'date', new.date, 'status', new.status);
  if by_child then
    if new.status = 'pending' then
      perform public.notify_parents(new.family_id, 'task_done', nm || ' görevi yaptı: ' || coalesce(t.title, ''),
        'Onayını bekliyor.', d, new.child_id);
    elsif new.status = 'approved' then
      perform public.notify_parents(new.family_id, 'task_done', nm || ' görevi yaptı: ' || coalesce(t.title, ''),
        case when coalesce(coins, 0) > 0 then '+' || coins || ' coin kazandı.' else '' end, d, new.child_id);
    elsif new.status = 'declined' then
      perform public.notify_parents(new.family_id, 'task_declined', nm || ' yapamadı: ' || coalesce(t.title, ''),
        'Konuşmak isteyebilirsin.', d, new.child_id);
    end if;
  else
    if new.status = 'approved' then
      perform public.notify_child(new.child_id, 'task_approved', 'Aferin! ' || coalesce(t.title, '') || ' onaylandı',
        case when coalesce(coins, 0) > 0 then '+' || coins || ' coin kazandın.' else '' end, d);
    elsif new.status = 'rejected' then
      perform public.notify_child(new.child_id, 'task_rejected', coalesce(t.title, '') || ' onaylanmadı',
        coalesce(new.parent_note, ''), d);
    elsif new.status = 'retry' then
      perform public.notify_child(new.child_id, 'task_retry', coalesce(t.title, '') || ': bir daha dener misin?',
        coalesce(new.parent_note, ''), d);
    end if;
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------- yetkiler
revoke execute on function public.review_completion(uuid, uuid, date, text, text, integer, integer) from public, anon;
grant execute on function public.review_completion(uuid, uuid, date, text, text, integer, integer) to authenticated;
revoke execute on function public.completions_sun_stone_trigger() from public, anon, authenticated;
revoke execute on function public.completions_notify() from public, anon, authenticated;
