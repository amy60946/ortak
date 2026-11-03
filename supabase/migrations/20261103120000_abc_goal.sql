-- Davranış kaydını uzmanın hedefine bağlama (kullanıcı kararı 3 Kasım 2026: isteğe bağlı seçim).
-- Ebeveyn davranış kaydında "Hangi hedefle ilgili?" sorusuna uzmanın o çocuk için aileye gönderdiği hedeflerden birini seçebilir
-- (ya da boş bırakır: "Diğer / emin değilim"). Uzman kayıtları hedefe göre süzer; aynı hedefin kayıtları raporda tutarlı toplanır.
-- Benchmark: uzman (ABA) veri toplama araçlarında kayıt hedef davranışa bağlı tutulur (ör. Motivity); yapılandırılmış form
-- serbest metinden daha doğru dolduruluyor (Lerman ve ark. 2009). Ebeveyn uygulamalarında (Joon, Goally, Brili) yok.
-- Kural: hedef aynı çocuğun etkin paylaşımına ait olmalı ve aileye gönderilmiş olmalı (pub dolu); hedef silinince bağ boşalır.
-- Paylaşım bitse de eski kayıtların bağı kalır (geçmiş). Uzman kaydı yalnız okur (değişmedi). Tekrar çalıştırılabilir.

alter table public.abc_events add column if not exists goal_id uuid references public.clinic_goals (id) on delete set null;
create index if not exists abc_events_goal_idx on public.abc_events (goal_id) where goal_id is not null;

create or replace function public.abc_events_goal_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.goal_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.goal_id is not distinct from old.goal_id and new.child_id is not distinct from old.child_id then
    return new;
  end if;
  if not exists (
    select 1 from public.clinic_goals g join public.clinic_links l on l.id = g.link_id
     where g.id = new.goal_id and l.child_id = new.child_id and l.family_id = new.family_id
       and l.status = 'active' and g.pub is not null
  ) then
    raise exception 'Bu hedef bu çocuk için paylaşılmamış' using errcode = '23514', hint = 'goal_mismatch';
  end if;
  return new;
end $$;
drop trigger if exists abc_events_goal_guard on public.abc_events;
create trigger abc_events_goal_guard before insert or update of goal_id, child_id on public.abc_events
  for each row execute function public.abc_events_goal_guard();
revoke execute on function public.abc_events_goal_guard() from public, anon, authenticated;
