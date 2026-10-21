-- =====================================================================
-- Saldırgan gözüyle tarama düzeltmeleri (öneri, 22 Ekim 2026; klinik penceresinin sızma denemesiyle örtüşen maddeler çıkarıldı)
--   H1 (yüksek): çocuk oturumu completions'a doğrudan INSERT ile istediği tarihe "approved" yazıp (inceleme
--       gerektirmeyen görevde) her tarih için coin ve Güneş Taşı alabiliyordu (child_set_status'taki bugün/dün
--       sınırı doğrudan INSERT'i kapsamıyordu). Oyun zaten child_set_status kullanıyor → çocuğun doğrudan INSERT
--       izni kaldırıldı.
--   L1: push anahtarı kullanıcı başına en çok 5 (bir hesabın her bildirimi binlerce gönderime yol açmasın).
--   L6: hedef ve hedef puanında "kim yazdı" alanlarını sunucu oturumdaki uzmanla doldurur (başkası adına yazılamaz).
--   L8: serbest metin alanlarına uzunluk sınırı (var olan satırlara dokunulmaz: not valid).
--   + Varsayılan yetki: bundan sonra public şemasında açılan fonksiyonlar girişsiz (anon) çalıştırılamaz;
--     yeni tablolarda TRUNCATE yetkisi yok.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- H1 ------------------------------------------------------------------
drop policy if exists "tamamlama: çocuk işaretler" on public.completions;

-- (child_set_status zaten bugün/dün ile sınırlı: migrations/20261019020000_server_rules.sql)

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
drop trigger if exists suggestions_author on public.clinic_task_suggestions;   -- öneride politika created_by = auth.uid() ister

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

revoke execute on function public.clinic_set_author() from public, anon, authenticated;
revoke execute on function public.register_push_token(text, text, text) from public, anon;
grant execute on function public.register_push_token(text, text, text) to authenticated;
