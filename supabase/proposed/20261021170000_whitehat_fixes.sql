-- =====================================================================
-- Saldırgan gözüyle tarama düzeltmeleri (öneri, 21 Ekim 2026)
--   H1 (yüksek): çocuk oturumu completions'a doğrudan INSERT ile istediği tarihe "approved" yazıp (inceleme
--       gerektirmeyen görevde) her tarih için coin alabiliyordu. Oyun zaten child_set_status kullanıyor →
--       çocuğun doğrudan INSERT izni kaldırıldı; child_set_status geçmişte en çok 7 gün geriye işaretler.
--   L1: push anahtarı kullanıcı başına en çok 5 (bir hesabın her bildirimi binlerce gönderime yol açmasın).
--   L6: klinik kayıtlarında "kim yazdı" alanlarını sunucu oturumdaki uzmanla doldurur (başkası adına yazılamaz);
--       bağlantının sorumlu uzmanı yalnız aynı klinikten seçilebilir.
--   L7: uzman hesabı çocuk giriş kodu kullanamaz.
--   L8: serbest metin alanlarına uzunluk sınırı (var olan satırlara dokunulmaz: not valid).
--   + Varsayılan yetki: bundan sonra public şemasında açılan fonksiyonlar girişsiz (anon) çalıştırılamaz;
--     yeni tablolarda TRUNCATE yetkisi yok.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- H1 ------------------------------------------------------------------
drop policy if exists "tamamlama: çocuk işaretler" on public.completions;

create or replace function public.child_set_status(p_task_id uuid, p_date date, p_status text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
  t public.tasks%rowtype;
  cur public.completions%rowtype;
  target text := p_status;
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  if p_status not in ('pending', 'declined', 'assigned') then
    raise exception 'Geçersiz durum';
  end if;
  select tk.* into t from public.tasks tk
    join public.task_assignments a on a.task_id = tk.id and a.child_id = me
    where tk.id = p_task_id;
  if not found or not public.task_occurs_on(t, p_date) then
    raise exception 'Görev bulunamadı';
  end if;
  if p_date > current_date + 1 then
    raise exception 'Gelecek günün görevi işaretlenemez';
  end if;
  if p_date < current_date - 7 then
    raise exception 'Bir haftadan eski görev işaretlenemez';
  end if;

  select * into cur from public.completions where task_id = p_task_id and child_id = me and date = p_date for update;
  if found and cur.status in ('approved', 'rejected') then
    raise exception 'Ebeveyn karar verdi' using errcode = 'P0001';
  end if;

  if p_status = 'assigned' then
    delete from public.completions where task_id = p_task_id and child_id = me and date = p_date;
    return 'assigned';
  end if;
  if p_status = 'pending' and not t.requires_review then
    target := 'approved';
  end if;
  insert into public.completions (family_id, task_id, child_id, date, status)
  values (t.family_id, p_task_id, me, p_date, target)
  on conflict (task_id, child_id, date) do update set status = excluded.status, created_at = now();
  return target;
end $$;

-- L1 ------------------------------------------------------------------
create or replace function public.register_push_token(p_token text, p_app text, p_platform text default 'ios')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  insert into public.push_tokens (token, user_id, app, platform, updated_at)
  values (p_token, auth.uid(), p_app, coalesce(p_platform, 'ios'), now())
  on conflict (token) do update set user_id = excluded.user_id, app = excluded.app, platform = excluded.platform, updated_at = now();
  -- en yeni 5 anahtar kalır
  delete from public.push_tokens where user_id = auth.uid() and token in (
    select token from public.push_tokens where user_id = auth.uid() order by updated_at desc offset 5);
end $$;

-- L6 ------------------------------------------------------------------
create or replace function public.clinic_my_member(p_clinician uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.clinicians where id = p_clinician and clinic_id = public.my_clinic_id())
$$;

drop policy if exists "bağlantı: klinik etiketi" on public.clinic_links;
create policy "bağlantı: klinik etiketi" on public.clinic_links for update to authenticated
  using (clinic_id = public.my_clinic_id() and status = 'active')
  with check (clinic_id = public.my_clinic_id() and (clinician_id is null or public.clinic_my_member(clinician_id)));

-- "kim yazdı" alanlarını sunucu doldurur (istemci ne gönderirse göndersin); güncellemede değişmez
create or replace function public.clinic_set_author()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'goal_ratings' then
    new.rated_by := case when tg_op = 'INSERT' then auth.uid() else old.rated_by end;
  else
    new.created_by := case when tg_op = 'INSERT' then auth.uid() else old.created_by end;
  end if;
  return new;
end $$;
drop trigger if exists clinic_goals_author on public.clinic_goals;
create trigger clinic_goals_author before insert or update on public.clinic_goals
  for each row execute function public.clinic_set_author();
drop trigger if exists goal_ratings_author on public.goal_ratings;
create trigger goal_ratings_author before insert or update on public.goal_ratings
  for each row execute function public.clinic_set_author();
drop trigger if exists suggestions_author on public.clinic_task_suggestions;
create trigger suggestions_author before insert or update on public.clinic_task_suggestions
  for each row execute function public.clinic_set_author();

-- L7 ------------------------------------------------------------------
create or replace function public.redeem_child_code(p_code text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  c public.children%rowtype;
  problem text;
begin
  if uid is null then
    raise exception 'Oturum gerekli' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles where id = uid) or exists (select 1 from public.clinicians where id = uid) then
    raise exception 'Ebeveyn ya da uzman hesabıyla çocuk girişi yapılamaz';
  end if;
  if public.code_blocked() then return public.code_error('child', 'too_many_attempts'); end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'child'
    for update;
  if not found then return public.code_error('child', 'code_invalid'); end if;
  problem := public.code_problem(inv.used_at, inv.expires_at);
  if problem is not null then return public.code_error('child', problem); end if;

  update public.children set user_id = null where user_id = uid;
  update public.children set user_id = uid where id = inv.child_id returning * into c;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;

  return json_build_object('child_id', c.id, 'family_id', c.family_id, 'name', c.name, 'avatar', c.avatar,
                           'age_band', coalesce(c.age_band, public.suggest_age_band(c.birthday)));
end $$;

-- L8 ------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_text_len_check') then
    alter table public.profiles add constraint profiles_text_len_check
      check (char_length(nickname) <= 40 and char_length(name) <= 80 and char_length(avatar) <= 200) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'tasks_text_len_check') then
    alter table public.tasks add constraint tasks_text_len_check
      check (char_length(description) <= 2000 and char_length(emoji) <= 16 and char_length(skill) <= 60) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'children_avatar_len_check') then
    alter table public.children add constraint children_avatar_len_check check (char_length(avatar) <= 200) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'families_name_len_check') then
    alter table public.families add constraint families_name_len_check check (char_length(name) <= 60) not valid;
  end if;
end $$;

-- Varsayılan yetki ----------------------------------------------------
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon;
alter default privileges in schema public revoke truncate on tables from anon, authenticated;
do $$
declare r record;
begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' loop
    execute format('revoke truncate on table public.%I from anon, authenticated', r.relname);
  end loop;
end $$;

revoke execute on function public.clinic_my_member(uuid) from public, anon, authenticated;
revoke execute on function public.clinic_set_author() from public, anon, authenticated;
revoke execute on function public.child_set_status(uuid, date, text) from public, anon;
revoke execute on function public.register_push_token(text, text, text) from public, anon;
revoke execute on function public.redeem_child_code(text) from public, anon;
grant execute on function public.child_set_status(uuid, date, text) to authenticated;
grant execute on function public.register_push_token(text, text, text) to authenticated;
grant execute on function public.redeem_child_code(text) to authenticated;
