-- Kategori = beceri, sunucuda tek biçim (23 Ekim 2026, ortak/sozlesme/ekonomi.md 5B).
-- 1) Uzman önerisi kategorileri altı kategoriye açılır (yeni katalogdaki Odak, İlişki, Sağlık görevleri reddediliyordu); eski 'self' → 'health'.
-- 2) tasks.skill ve clinic_task_suggestions.skill yazılırken eski serbest etiketler (Sorumluluk, Okuma, Empati …) altı beceri
--    anahtarına çevrilir; eşleşmeyen ('Özel', boş) olduğu gibi kalır. Var olan satırlar bir kez çevrilir.
-- Uygulama sırası: ParentApp ve ClinicApp beceri anahtarını Türkçe adla göstermeye başladıktan sonra uygulanır.
-- Tekrar çalıştırılabilir.

update public.clinic_task_suggestions set category = 'health' where category = 'self';
alter table public.clinic_task_suggestions drop constraint if exists cts_category_check;
alter table public.clinic_task_suggestions add constraint cts_category_check
  check (category is null or category in ('home', 'mind', 'learn', 'health', 'focus', 'relation'));

create or replace function public.skill_key(p text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  a text := lower(trim(coalesce(p, '')));                                            -- İngilizce / anahtar
  t text := lower(replace(replace(trim(coalesce(p, '')), 'İ', 'i'), 'I', 'ı'));     -- Türkçe büyük I/İ
begin
  if a = '' then return coalesce(p, ''); end if;
  if a in ('teamwork', 'home', 'responsibility', 'independence') or t in ('takım çalışması', 'sorumluluk', 'bağımsızlık') then return 'teamwork'; end if;
  if a in ('stamina', 'mind', 'calm') or t in ('dayanıklılık', 'sakinlik', 'sakinleşme', 'duygu farkındalığı') then return 'stamina'; end if;
  if a in ('knowledge', 'learn') or t in ('bilgi', 'okuma', 'dil', 'temel beceriler') then return 'knowledge'; end if;
  if a in ('strength', 'health', 'self', 'self_care') or t in ('güç', 'öz bakım', 'hareket', 'sağlıklı alışkanlık') then return 'strength'; end if;
  if a in ('focus') or t in ('odak', 'odaklanma', 'öz denetim', 'sabır', 'planlama') then return 'focus'; end if;
  if a in ('kindness', 'relation') or t in ('nezaket', 'empati', 'minnettarlık', 'paylaşma', 'iletişim', 'arkadaşlık') then return 'kindness'; end if;
  return p;
end $$;
revoke execute on function public.skill_key(text) from public, anon;
grant execute on function public.skill_key(text) to authenticated;

create or replace function public.skill_key_normalize() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.skill := public.skill_key(new.skill);
  return new;
end $$;
revoke execute on function public.skill_key_normalize() from public, anon;

drop trigger if exists tasks_skill_key on public.tasks;
create trigger tasks_skill_key before insert or update of skill on public.tasks
  for each row execute function public.skill_key_normalize();
-- uzman önerisi: beceri anahtarı + eski 'self' kategorisi 'health' olur (ClinicApp eski şablonları bozulmasın; kısıttan önce çalışır)
create or replace function public.cts_skill_key_normalize() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.skill := public.skill_key(new.skill);
  if new.category = 'self' then new.category := 'health'; end if;
  return new;
end $$;
revoke execute on function public.cts_skill_key_normalize() from public, anon;

drop trigger if exists cts_skill_key on public.clinic_task_suggestions;
create trigger cts_skill_key before insert or update of skill, category on public.clinic_task_suggestions
  for each row execute function public.cts_skill_key_normalize();

-- var olan kayıtlar (yalnız değişecek olanlar; updated_at dokunulmaz)
update public.tasks set skill = public.skill_key(skill) where skill is distinct from public.skill_key(skill);
update public.clinic_task_suggestions set skill = public.skill_key(skill) where skill is distinct from public.skill_key(skill);
