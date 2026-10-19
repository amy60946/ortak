-- =====================================================================
-- Uzman görev önerisi = ParentApp "Görev Oluştur" ile aynı alanlar + uzmanın bekleyen öneriyi güncellemesi
-- + danışan listesinde ebeveyn adı (aynı adlı çocukları ayırt etmek için). ÖNERİ, henüz uygulanmadı.
-- Önkoşul: 20261019000000_clinic.sql (ve varsa ParentApp'in 20261019120000/130000 önerileri; çakışmaz).
-- Tekrar çalıştırılabilir.
--
-- Neden: öneri yalnız başlık/emoji/beceri/zorluk/tekrarlı taşıyordu; ebeveyn kabul edince ParentApp görevi
-- eksik alanlarla (açıklama, ödül, tekrar günleri, hatırlatma, inceleme…) kendi varsayılanlarıyla açıyordu.
-- Artık öneri, ParentApp'in tasks + task_assignments satırına birebir dönüşecek alanları taşır.
-- =====================================================================

alter table public.clinic_task_suggestions
  add column if not exists description     text not null default '',
  add column if not exists category        text,                         -- ParentApp şablon kategorisi
  add column if not exists template_key    text,                         -- ParentApp şablon kimliği (ör. 't9'); özel görevde null
  add column if not exists coins           integer,                      -- null: zorluğun varsayılanı (5/10/20)
  add column if not exists start_date      date,                         -- null ya da geçmişse: kabul edildiği gün
  add column if not exists repeat_kind     text not null default 'daily',
  add column if not exists repeat_days     smallint[] not null default '{}',
  add column if not exists end_date        date,
  add column if not exists reminder        text,                         -- "HH:MM" ya da null
  add column if not exists requires_review boolean not null default true,
  add column if not exists updated_at      timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'cts_description_check') then
    alter table public.clinic_task_suggestions add constraint cts_description_check check (char_length(description) <= 1000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cts_category_check') then
    alter table public.clinic_task_suggestions add constraint cts_category_check
      check (category is null or category in ('home', 'mind', 'learn', 'self'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cts_coins_check') then
    alter table public.clinic_task_suggestions add constraint cts_coins_check check (coins is null or coins between 0 and 50);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cts_repeat_kind_check') then
    alter table public.clinic_task_suggestions add constraint cts_repeat_kind_check check (repeat_kind in ('daily', 'weekly', 'monthly'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cts_repeat_days_check') then
    alter table public.clinic_task_suggestions add constraint cts_repeat_days_check
      check (repeat_days <@ array[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31]::smallint[]);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cts_reminder_check') then
    alter table public.clinic_task_suggestions add constraint cts_reminder_check
      check (reminder is null or reminder ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cts_end_date_check') then
    alter table public.clinic_task_suggestions add constraint cts_end_date_check
      check (end_date is null or start_date is null or end_date >= start_date);
  end if;
end $$;

-- Uzman bekleyen öneriyi günceller (metin + görev ayarları). Karar verilmiş (kabul/ret) öneri değişmez.
-- Tablo yerine RPC: ailenin sütun izni (status, decided_at, task_id) genişlemesin.
create or replace function public.clinic_update_suggestion(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  s public.clinic_task_suggestions%rowtype;
begin
  select * into s from public.clinic_task_suggestions where id = p_id for update;
  if not found or s.clinic_id is distinct from public.my_clinic_id() then raise exception 'Öneri bulunamadı'; end if;
  if s.status <> 'pending' then raise exception 'Ebeveyn karar verdi; öneri artık değiştirilemez'; end if;
  if not public.clinic_link_mine(s.link_id) then raise exception 'Paylaşım sona erdi'; end if;
  update public.clinic_task_suggestions set
    title           = coalesce(nullif(trim(p ->> 'title'), ''), title),
    emoji           = coalesce(nullif(p ->> 'emoji', ''), emoji),
    skill           = coalesce(p ->> 'skill', skill),
    description     = coalesce(p ->> 'description', description),
    category        = case when p ? 'category' then p ->> 'category' else category end,
    template_key    = case when p ? 'template_key' then p ->> 'template_key' else template_key end,
    difficulty      = coalesce(p ->> 'difficulty', difficulty),
    coins           = case when p ? 'coins' then (p ->> 'coins')::integer else coins end,
    start_date      = case when p ? 'start_date' then (p ->> 'start_date')::date else start_date end,
    recurring       = coalesce((p ->> 'recurring')::boolean, recurring),
    repeat_kind     = coalesce(p ->> 'repeat_kind', repeat_kind),
    repeat_days     = case when p ? 'repeat_days'
                        then coalesce(array(select jsonb_array_elements_text(p -> 'repeat_days')::smallint), '{}') else repeat_days end,
    end_date        = case when p ? 'end_date' then (p ->> 'end_date')::date else end_date end,
    reminder        = case when p ? 'reminder' then p ->> 'reminder' else reminder end,
    requires_review = coalesce((p ->> 'requires_review')::boolean, requires_review),
    note            = coalesce(p ->> 'note', note),
    updated_at      = now()
  where id = p_id;
end $$;
revoke execute on function public.clinic_update_suggestion(uuid, jsonb) from public, anon;
grant execute on function public.clinic_update_suggestion(uuid, jsonb) to authenticated;

-- Uzman: danışan listesi (etkin rızalı bağlantılar) + çocuğun avatarı/doğum günü + ebeveyn adları.
-- Ebeveyn adı yalnız rıza veren aileden ve yalnız bu listede görünür (profiles tablosu uzmana açılmaz).
create or replace function public.clinic_clients()
returns table (link_id uuid, clinic_id uuid, family_id uuid, child_id uuid, child_name text, avatar text,
               birthday date, label text, consent_at timestamptz, parents text)
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.family_id, l.child_id, c.name, c.avatar, c.birthday, l.label, l.consent_at,
         coalesce((select string_agg(coalesce(nullif(trim(p.name), ''), p.nickname), ', ' order by p.created_at)
                   from public.profiles p where p.family_id = l.family_id), '')
  from public.clinic_links l
  join public.children c on c.id = l.child_id
  where l.clinic_id = public.my_clinic_id() and l.status = 'active'
  order by l.consent_at desc
$$;
revoke execute on function public.clinic_clients() from public, anon;
grant execute on function public.clinic_clients() to authenticated;
