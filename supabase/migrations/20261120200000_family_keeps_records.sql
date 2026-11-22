-- Paylaşım kaydı ya da klinik silinince ailenin kendi girdiği kayıtlar ailede kalır (kullanıcı kararı 20 Kasım 2026, hukuk kararı 3A;
-- hukuk/50 "Avukata notlar 9", hukuk/42 satır 9). ÖNERİ; tekrar çalıştırılabilir. Önkoşul: 20261110100000_parent_trainings.sql,
-- 20261110110000_target_behaviors.sql, 20261120100000_rutin_server_texts.sql (canlıda).
--
-- Bugün parent_trainings ve behavior_incidents paylaşım kaydına (clinic_links) zincirleme bağlı. clinic_links satırı yalnız şu yollarla silinir:
--   (1) klinik silinince: uzman hesabını siler (delete_account) ya da panel siler (admin_delete_user) → account_delete_of: tek kişilik
--       klinikler ve uzmanın bireysel alanı (clinics.personal_of → clinicians zinciri de aynı yol). Ekip koduyla katılma eski kliniği yalnız
--       içinde paylaşım yokken siler.
--   (2) aile silinince: son ebeveyn hesabını siler (account_delete_of); join_family eski aileyi yalnız çocuksuzken siler.
--   (3) çocuk silinince: ebeveyn children satırını siler.
--   Paylaşımı geri alma (revoke_clinic_link, uzmanın "Paylaşımı sonlandır") satırı silmez, durumu 'revoked' yapar: bu dosyanın konusu değil.
-- Yeni kural:
--   * (1) Etkin ve Ustalaştı eğitimler ile modül, uygulama görevi, uygulama kaydı ve yapılacak satırları kalır (link_id, clinic_id boşalır,
--     detached_at yazılır). Taslaklar (aile hiç görmedi) silinir. Uzmana ait olup ailenin görmediği parçalar silinir: gözlem verisi
--     (parent_training_data), ustalık ölçütü, uzmanın son bakışı, oluşturan, ailenin girdisi olmayan arşivli modül / görev / yapılacak.
--     Davranış olayları kalır (link_id boşalır); hedef davranış (uzmanın kaydı) silinir, adı olayda behavior_title olarak durur.
--   * (2)–(3) her şey silinir: parent_trainings'e family_id ve child_id (zincirleme) eklendi; olaylarda zaten vardı.
--   * Ailede kalan kayıt salt okunurdur: ebeveyn görür (tablo RLS'i, family_kept_trainings), yeni kayıt giremez; uzman tarafı (her klinik)
--     link_id / clinic_id boşken hiçbir yoldan erişemez.
--   * KVKK dökümü (data_export_of): eğitim kayıtlarına eğitimin ve uygulama görevinin adı eklendi (ailede kalan kopya anlaşılır olsun);
--     olaylarda behavior_title kendiliğinden gelir. Saklama ve imha işi (retention_run) değişmedi: bu tablolarda adımı yok; satır 9'un
--     ileride gelecek "paylaşım bittikten sonra silme" adımı paylaşım kaydını silerse aile kopyası aynı kurallarla kalır.
--   * Hata düzeltmesi (bu işte bulundu): ailede başka ebeveyn varken eğitimde modül tamamlamış ya da yapılacak işaretlemiş ebeveyn
--     hesabını silemiyordu (modül / yapılacak koruması yabancı anahtarın completed_by / done_by bağını boşaltmasını reddediyordu);
--     eğitimi kuran uzmanın hesabı silinince eğitim koruması created_by'a silinmiş kişiyi geri yazıyordu. İkisi düzeldi.
-- Sözleşme: sozlesme/veritabani.md 32–33, akislar.md 23–24, hukuk/42 satır 9, hukuk/46, hukuk/50 §5.2. Test: test_family_keeps_records.sql.

-- ---------------------------------------------------------------- 1. sütunlar
alter table public.parent_trainings add column if not exists family_id uuid references public.families (id) on delete cascade;
alter table public.parent_trainings add column if not exists child_id uuid references public.children (id) on delete cascade;
alter table public.parent_trainings add column if not exists detached_at timestamptz;   -- paylaşım / klinik silindi: ailenin kopyası

-- Var olan eğitimler paylaşımdan doldurulur (koruma tetikleyicisi updated_at'i değiştirmesin diye bu adımda kapalı)
alter table public.parent_trainings disable trigger parent_trainings_guard;
update public.parent_trainings t set family_id = l.family_id, child_id = l.child_id
  from public.clinic_links l
 where l.id = t.link_id and (t.family_id is distinct from l.family_id or t.child_id is distinct from l.child_id);
alter table public.parent_trainings enable trigger parent_trainings_guard;

alter table public.parent_trainings
  alter column family_id set not null,
  alter column child_id set not null,
  alter column clinic_id drop not null,
  alter column link_id drop not null;
create index if not exists parent_trainings_family_idx on public.parent_trainings (family_id);
create index if not exists parent_trainings_child_idx on public.parent_trainings (child_id);

alter table public.behavior_incidents alter column link_id drop not null;
alter table public.behavior_incidents add column if not exists behavior_title text not null default ''
  check (char_length(behavior_title) <= 80);                                              -- hedef davranışın adı (hedef silinse de kalır)
update public.behavior_incidents i set behavior_title = b.title
  from public.clinic_target_behaviors b
 where b.id = i.behavior_id and i.behavior_title is distinct from b.title;

-- Paylaşım kaydı / klinik silinince satır silinmesin, bağ boşalsın (on delete cascade → set null). İkinci çalıştırmada atlanır.
do $$
declare r record;
begin
  for r in
    select c.conname, c.conrelid::regclass as tbl, a.attname as col, c.confrelid::regclass as ref
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
     where c.contype = 'f' and cardinality(c.conkey) = 1 and c.confdeltype <> 'n'
       and ((c.conrelid = 'public.parent_trainings'::regclass and a.attname in ('clinic_id', 'link_id'))
         or (c.conrelid = 'public.behavior_incidents'::regclass and a.attname = 'link_id'))
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
    execute format('alter table %s add constraint %I foreign key (%I) references %s (id) on delete set null', r.tbl, r.conname, r.col, r.ref);
  end loop;
end $$;

-- ---------------------------------------------------------------- 2. eğitim koruması
-- Sunucu doldurur: oluşturan, ebeveyn adı, aile ve çocuk (paylaşımdan), durum zamanları; eğitim başka danışana / kliniğe taşınamaz;
-- ebeveyn o ailedendir. Paylaşım ya da klinik silinince (yabancı anahtar bağı boşaltır) eğitim ailenin kopyası olur: yalnız bağlar ve
-- silinen kişinin alanları boşalabilir, uzmana ait alanlar (ölçüt, son bakış, oluşturan) silinir, başka hiçbir şey değişmez.
create or replace function public.parent_trainings_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_family uuid; v_clinic uuid; v_child uuid;
begin
  if tg_op = 'UPDATE' and (old.link_id is null or old.clinic_id is null or new.link_id is null or new.clinic_id is null) then
    if (new.link_id is not null and new.link_id is distinct from old.link_id)
       or (new.clinic_id is not null and new.clinic_id is distinct from old.clinic_id)
       or (new.parent_id is not null and new.parent_id is distinct from old.parent_id)
       or (new.family_id, new.child_id, new.title, new.status, new.parent_name, new.started_at, new.activated_at, new.mastered_at, new.created_at)
          is distinct from
          (old.family_id, old.child_id, old.title, old.status, old.parent_name, old.started_at, old.activated_at, old.mastered_at, old.created_at) then
      raise exception 'Ailede kalan eğitim değiştirilemez' using errcode = 'check_violation';
    end if;
    if new.link_id is null then new.clinic_id := null; end if;
    new.criterion := null; new.seen_at := null; new.created_by := null;
    new.detached_at := coalesce(old.detached_at, now());
    new.updated_at := now();
    return new;
  end if;
  if new.link_id is null or new.clinic_id is null then
    raise exception 'Eğitim bir paylaşıma bağlı kurulur' using errcode = 'check_violation';
  end if;
  select l.family_id, l.clinic_id, l.child_id into v_family, v_clinic, v_child from public.clinic_links l where l.id = new.link_id;
  if v_clinic is distinct from new.clinic_id then raise exception 'Eğitim bu kliniğin paylaşımına ait değil' using errcode = 'check_violation'; end if;
  if new.parent_id is not null then
    if not exists (select 1 from public.profiles p where p.id = new.parent_id and p.family_id = v_family) then
      raise exception 'Ebeveyn bu aileden değil' using errcode = 'check_violation';
    end if;
    select coalesce(nullif(trim(p.name), ''), p.nickname) into new.parent_name from public.profiles p where p.id = new.parent_id;
  end if;
  new.family_id := v_family;
  new.child_id := v_child;
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.detached_at := null;
    if new.status = 'active' then new.activated_at := now(); end if;
    if new.status = 'mastered' then new.activated_at := now(); new.mastered_at := now(); end if;
  else
    if new.link_id is distinct from old.link_id or new.clinic_id is distinct from old.clinic_id then
      raise exception 'Eğitim başka bir danışana taşınamaz' using errcode = 'check_violation';
    end if;
    -- oluşturan uzmanın hesabı silinince yabancı anahtar bağı boşaltır; eski koruma eski değeri geri yazıyordu (silinmiş kişiye bağ kalıyordu)
    if not (new.created_by is null and not exists (select 1 from auth.users u where u.id = old.created_by)) then
      new.created_by := old.created_by;
    end if;
    new.detached_at := old.detached_at;
    if new.status = 'active' and old.status <> 'active' and new.activated_at is null then new.activated_at := now(); end if;
    if new.status = 'mastered' and old.status <> 'mastered' then new.mastered_at := now(); end if;
    if new.status <> 'mastered' then new.mastered_at := null; end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.parent_trainings_guard() from public, anon, authenticated;

-- Ebeveyn hesabını silince (ailede başka ebeveyn varken) modülü tamamlayan / yapılacağı işaretleyen bağı boşalır (on delete set null).
-- Önceki korumalar bunu "tamamlama değişti" sayıp hata veriyordu: o ebeveynin hesabı silinemiyordu (delete_account, admin_delete_user).
-- Yalnız kişi gerçekten silinmişse bağ boşalabilir; tamamlama ve işaret alanlarını yine yalnız ebeveyn işlevi yazar.
create or replace function public.parent_training_modules_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('ortak.training_family_write', true) is not distinct from 'on' then return new; end if;
  if tg_op = 'INSERT' then
    new.completed_at := null; new.completed_by := null; new.answers := null; new.correct := null; new.total := null;
  else
    if new.training_id is distinct from old.training_id then raise exception 'Kayıt başka bir eğitime taşınamaz' using errcode = 'check_violation'; end if;
    if new.completed_at is distinct from old.completed_at or new.answers is distinct from old.answers or new.correct is distinct from old.correct
       or new.total is distinct from old.total
       or (new.completed_by is distinct from old.completed_by
           and (new.completed_by is not null or exists (select 1 from auth.users u where u.id = old.completed_by))) then
      raise exception 'Modülün tamamlama bilgisini yalnız ebeveyn yazar' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.parent_training_modules_guard() from public, anon, authenticated;

create or replace function public.parent_training_todos_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if current_setting('ortak.training_family_write', true) is not distinct from 'on' then return new; end if;
  if tg_op = 'INSERT' then
    new.done_at := null; new.done_by := null; new.rating := null; new.reflection := '';
  else
    if new.training_id is distinct from old.training_id then raise exception 'Kayıt başka bir eğitime taşınamaz' using errcode = 'check_violation'; end if;
    if new.done_at is distinct from old.done_at or new.rating is distinct from old.rating or new.reflection is distinct from old.reflection
       or (new.done_by is distinct from old.done_by
           and (new.done_by is not null or exists (select 1 from auth.users u where u.id = old.done_by))) then
      raise exception 'Yapılacağı yalnız ebeveyn işaretler' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;
revoke execute on function public.parent_training_todos_guard() from public, anon, authenticated;

-- ---------------------------------------------------------------- 3. paylaşım kaydı silinmeden önce
-- Taslak eğitimler (aile hiç görmedi) silinir; kalacak eğitimlerden uzmanın gözlem verisi ve ailenin girdisi olmayan arşivli parçalar
-- çıkarılır. Satır ailenin ya da çocuğun silinmesiyle gidiyorsa eğitim zaten family_id / child_id ile silinir (bu adım zararsız).
create or replace function public.clinic_links_keep_family_records() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.parent_trainings where link_id = old.id and status = 'draft';
  delete from public.parent_training_data d using public.parent_trainings t
   where t.id = d.training_id and t.link_id = old.id;
  delete from public.parent_training_modules m using public.parent_trainings t
   where t.id = m.training_id and t.link_id = old.id and m.archived and m.completed_at is null;
  delete from public.parent_training_todos d using public.parent_trainings t
   where t.id = d.training_id and t.link_id = old.id and d.archived and d.done_at is null;
  delete from public.parent_training_tasks k using public.parent_trainings t
   where t.id = k.training_id and t.link_id = old.id and k.archived
     and not exists (select 1 from public.parent_training_logs g where g.task_id = k.id);
  return old;
end $$;
revoke execute on function public.clinic_links_keep_family_records() from public, anon, authenticated;
drop trigger if exists clinic_links_keep_family_records on public.clinic_links;
create trigger clinic_links_keep_family_records before delete on public.clinic_links
  for each row execute function public.clinic_links_keep_family_records();

-- ---------------------------------------------------------------- 4. olayda hedef davranışın adı
-- Yeni olayda sunucu yazar; uzman adı değiştirince olaylarda da güncellenir; hedef silinince (behavior_id boşalır) son ad kalır.
create or replace function public.behavior_incidents_fill() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.behavior_title := coalesce((select b.title from public.clinic_target_behaviors b where b.id = new.behavior_id), '');
  return new;
end $$;
revoke execute on function public.behavior_incidents_fill() from public, anon, authenticated;
drop trigger if exists behavior_incidents_fill on public.behavior_incidents;
create trigger behavior_incidents_fill before insert on public.behavior_incidents
  for each row execute function public.behavior_incidents_fill();

create or replace function public.clinic_target_behaviors_title_sync() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.behavior_incidents set behavior_title = new.title where behavior_id = new.id and behavior_title is distinct from new.title;
  return null;
end $$;
revoke execute on function public.clinic_target_behaviors_title_sync() from public, anon, authenticated;
drop trigger if exists clinic_target_behaviors_title_sync on public.clinic_target_behaviors;
create trigger clinic_target_behaviors_title_sync after update of title on public.clinic_target_behaviors
  for each row execute function public.clinic_target_behaviors_title_sync();

-- ---------------------------------------------------------------- 5. RLS ve görünürlük
-- Uzman: yalnız paylaşımı duran eğitim (bağ boşsa hiçbir klinik görmez, yazamaz)
create or replace function public.training_clinic_visible(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_trainings t join public.clinic_links l on l.id = t.link_id
                 where t.id = p_training and t.link_id is not null and t.clinic_id is not null
                   and l.status = 'active' and t.clinic_id = public.my_clinic_id() and public.clinician_access()
                   and public.clinic_link_visible(t.link_id))
$$;
revoke execute on function public.training_clinic_visible(uuid) from public, anon;
grant execute on function public.training_clinic_visible(uuid) to authenticated;

create or replace function public.training_clinic_mine(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_trainings t
                 where t.id = p_training and t.link_id is not null and t.clinic_id is not null
                   and t.clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_mine(t.link_id))
$$;
revoke execute on function public.training_clinic_mine(uuid) from public, anon;
grant execute on function public.training_clinic_mine(uuid) to authenticated;

-- Aile: taslak değil ve (etkin paylaşım kendi ailesinde ya da paylaşım silinmiş, eğitim kendi ailesinin)
create or replace function public.training_family_visible(p_training uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.parent_trainings t
                 where t.id = p_training and t.status <> 'draft'
                   and (public.family_link_active(t.link_id) or (t.link_id is null and t.family_id = public.my_family_id())))
$$;
revoke execute on function public.training_family_visible(uuid) from public, anon;
grant execute on function public.training_family_visible(uuid) to authenticated;

drop policy if exists "eğitim: klinik" on public.parent_trainings;
create policy "eğitim: klinik" on public.parent_trainings for all to authenticated
  using (link_id is not null and clinic_id = public.my_clinic_id() and public.clinician_access()
         and public.clinic_link_mine(link_id) and public.clinic_link_visible(link_id))
  with check (link_id is not null and clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_mine(link_id));
drop policy if exists "eğitim: aile okur" on public.parent_trainings;
create policy "eğitim: aile okur" on public.parent_trainings for select to authenticated
  using (status <> 'draft' and (public.family_link_active(link_id) or (link_id is null and family_id = public.my_family_id())));

drop policy if exists "olay: klinik okur" on public.behavior_incidents;
create policy "olay: klinik okur" on public.behavior_incidents for select to authenticated
  using (link_id is not null and exists (select 1 from public.clinic_links l where l.id = link_id and l.status = 'active'
                 and l.clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(l.id)));
-- "olay: aile okur" (family_id = my_family_id()) ve "eğitim kaydı: aile okur" değişmedi: paylaşım silinince de çalışır.

-- ---------------------------------------------------------------- 6. aile: ailede kalan eğitimler
-- Paylaşımı silinmiş (uzmanın hesabı ya da kliniği kapanmış) eğitimler, salt okunur. family_trainings() ile aynı biçim; link_id boş,
-- detached_at = ailede kaldığı an; kayıtların hepsi (yeni kayıt girilemez). Uzmanın ve kliniğin adı yok (hesapları silindi).
create or replace function public.family_kept_trainings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x->>'detached_at' desc, x->>'started_at' desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', t.id, 'link_id', t.link_id, 'child_id', t.child_id, 'child_name', c.name, 'title', t.title, 'status', t.status,
      'started_at', t.started_at, 'activated_at', t.activated_at, 'mastered_at', t.mastered_at, 'detached_at', t.detached_at,
      'parent_id', t.parent_id, 'parent_name', t.parent_name, 'mine', (t.parent_id is null or t.parent_id = auth.uid()),
      'modules', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'item_key', m.item_key, 'position', m.position,
                  'completed_at', m.completed_at, 'correct', m.correct, 'total', m.total, 'answers', m.answers) order by m.position, m.created_at)
                  from public.parent_training_modules m where m.training_id = t.id and not m.archived), '[]'::jsonb),
      'tasks', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'title', k.title, 'description', k.description,
                  'measure', k.measure, 'position', k.position) order by k.position, k.created_at)
                  from public.parent_training_tasks k where k.training_id = t.id and not k.archived), '[]'::jsonb),
      'logs', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'task_id', g.task_id, 'day', g.day, 'count', g.count,
                  'successes', g.successes, 'attempts', g.attempts, 'minutes', g.minutes, 'reflection', g.reflection,
                  'created_by', g.created_by, 'created_at', g.created_at) order by g.day desc, g.created_at desc)
                  from public.parent_training_logs g where g.training_id = t.id), '[]'::jsonb),
      'todos', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'title', d.title, 'description', d.description,
                  'done_at', d.done_at, 'rating', d.rating, 'reflection', d.reflection, 'created_at', d.created_at) order by d.position, d.created_at)
                  from public.parent_training_todos d where d.training_id = t.id and not d.archived), '[]'::jsonb)
    ) as x
    from public.parent_trainings t
    left join public.children c on c.id = t.child_id
    where t.link_id is null and t.status <> 'draft' and t.family_id = public.my_family_id()
  ) s
$$;
revoke execute on function public.family_kept_trainings() from public, anon;
grant execute on function public.family_kept_trainings() to authenticated;

-- ---------------------------------------------------------------- 7. KVKK dökümü
-- data_export_of (önceki tanım: migrations/20261120100000_rutin_server_texts.sql; yalnız ebeveyn eğitimi bölümü değişti:
-- eğitimin ve uygulama görevinin adı, ailede_kalan)
create or replace function public.data_export_of(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  u record;
  fam uuid;
  kids uuid[];
  cl record;
  out jsonb;
  v_sec jsonb;
  v_n bigint;
begin
  select id, email, created_at, last_sign_in_at, email_confirmed_at, is_anonymous into u from auth.users where id = p_user;
  if not found or u.is_anonymous then raise exception 'Hesap bulunamadı'; end if;

  out := jsonb_build_object(
    'bicim', 'veri-disa-aktarma-v1',
    'olusturulma', now(),
    'aciklama', 'Hesabına ve velisi olduğun çocuklara ait kayıtların dökümüdür. Diğer ebeveynin yazdıkları ayıklanmış, '
             || 'yalnız sayıları yazılmıştır. Fotoğraf ve ses dosyaları "dosyalar" listesindedir. Sorular için KVKK başvuru '
             || 'yolunu kullanabilirsin.',
    'hesap', jsonb_build_object('id', u.id, 'eposta', u.email, 'kayit', u.created_at,
                                'eposta_dogrulama', u.email_confirmed_at, 'son_giris', u.last_sign_in_at));

  -- Ebeveyn: profil, aile, çocuklar ve aile kayıtları
  select family_id into fam from public.profiles where id = p_user;
  if fam is not null then
    select coalesce(array_agg(id), '{}') into kids from public.children where family_id = fam;
    out := out || jsonb_build_object(
      'profil', (select to_jsonb(p) - 'family_id' from public.profiles p where p.id = p_user),
      'aile', (select jsonb_build_object('id', f.id, 'ad', f.name, 'olusturulma', f.created_at, 'deneme_baslangici', f.trial_started_at,
                                         'diger_ebeveyn_sayisi', (select count(*) from public.profiles x where x.family_id = fam and x.id <> p_user))
                 from public.families f where f.id = fam),
      'abonelik', (select to_jsonb(s) - 'family_id' - 'store_transaction_id' from public.family_subscriptions s where s.family_id = fam),
      'cocuklar', coalesce((select jsonb_agg(to_jsonb(c) - 'family_id' - 'user_id' || jsonb_build_object('oyun_cihazi_bagli', c.user_id is not null)
                                             order by c.created_at) from public.children c where c.family_id = fam), '[]'),
      'gorevler', coalesce((select jsonb_agg(to_jsonb(t) - 'family_id'
                                             || jsonb_build_object('atamalar', coalesce((select jsonb_agg(to_jsonb(a) - 'family_id' - 'task_id')
                                                                                          from public.task_assignments a where a.task_id = t.id), '[]'))
                                             order by t.created_at) from public.tasks t where t.family_id = fam), '[]'),
      'tamamlamalar', coalesce((select jsonb_agg(case when c.reviewed_by is not null and c.reviewed_by <> p_user
                                                      then to_jsonb(c) - 'family_id' - 'parent_note' - 'decline_reason'
                                                      else to_jsonb(c) - 'family_id' end order by c.date, c.created_at)
                                  from public.completions c where c.family_id = fam), '[]'),
      'oduller', coalesce((select jsonb_agg(to_jsonb(r) - 'family_id' order by r.created_at) from public.rewards r where r.family_id = fam), '[]'),
      'odul_istekleri', coalesce((select jsonb_agg(to_jsonb(r) - 'family_id' order by r.created_at) from public.reward_requests r where r.family_id = fam), '[]'),
      'coin_defteri', coalesce((select jsonb_agg(to_jsonb(l) - 'family_id' order by l.created_at) from public.coin_ledger l where l.family_id = fam), '[]'),
      'gunes_tasi_defteri', coalesce((select jsonb_agg(case when l.created_by is not null and l.created_by <> p_user
                                                            then to_jsonb(l) - 'family_id' - 'note' else to_jsonb(l) - 'family_id' end
                                                       order by l.created_at) from public.sun_stone_ledger l where l.family_id = fam), '[]'),
      'haftalik_hedefler', coalesce((select jsonb_agg(to_jsonb(w) - 'family_id' order by w.week_start) from public.weekly_goal_claims w where w.family_id = fam), '[]'),
      'oyun_kayitlari', coalesce((select jsonb_agg(jsonb_build_object('child_id', g.child_id, 'guncelleme', g.updated_at, 'veri', g.data))
                                    from public.game_saves g where g.family_id = fam), '[]'),
      'mesajlar', coalesce((select jsonb_agg(to_jsonb(m) - 'family_id' order by m.created_at) from public.messages m
                             where m.family_id = fam and (m.sender = 'child' or m.sender_id = p_user)), '[]'),
      'davranis_kayitlari', coalesce((select jsonb_agg(to_jsonb(e) - 'family_id' order by e.occurred_at) from public.abc_events e
                                       where e.family_id = fam and (e.created_by is null or e.created_by = p_user)), '[]'),
      'ev_programi_kayitlari', coalesce((select jsonb_agg(to_jsonb(l) - 'family_id' order by l.day) from public.care_module_logs l
                                          where l.family_id = fam and (l.created_by is null or l.created_by = p_user)), '[]'),
      'uzman_paylasimlari', coalesce((select jsonb_agg(jsonb_build_object('child_id', k.child_id, 'klinik', cl2.name, 'durum', k.status,
                                                                         'riza_surumu', k.consent_version, 'riza_zamani', k.consent_at,
                                                                         'geri_alinma', k.revoked_at, 'olusturulma', k.created_at) order by k.created_at)
                                         from public.clinic_links k left join public.clinics cl2 on cl2.id = k.clinic_id
                                        where k.family_id = fam), '[]'),
      'ayiklanan', jsonb_build_object(
        'diger_ebeveynin_mesajlari', (select count(*) from public.messages m where m.family_id = fam and m.sender <> 'child' and m.sender_id is distinct from p_user),
        'diger_ebeveynin_davranis_kayitlari', (select count(*) from public.abc_events e where e.family_id = fam and e.created_by is not null and e.created_by <> p_user),
        'diger_ebeveynin_ev_programi_kayitlari', (select count(*) from public.care_module_logs l where l.family_id = fam and l.created_by is not null and l.created_by <> p_user),
        'diger_ebeveynin_tanisma_yanitlari', (select count(*) from public.intake_answers a where a.family_id = fam and a.user_id <> p_user),
        'diger_ebeveynin_hediye_notlari', (select count(*) from public.child_gifts g where g.family_id = fam and g.from_user is distinct from p_user
                                                                                    and (g.note <> '' or g.from_name <> ''))),
      'dosyalar', coalesce((select jsonb_agg(x order by x ->> 'yol') from (
          select jsonb_build_object('kova', 'mail', 'yol', m.media_path, 'tur', m.kind, 'kaynak', 'mesaj') x
            from public.messages m where m.family_id = fam and m.media_path is not null and (m.sender = 'child' or m.sender_id = p_user)
          union all
          select jsonb_build_object('kova', 'abc', 'yol', e.audio_path, 'tur', 'audio', 'kaynak', 'davranis_kaydi')
            from public.abc_events e where e.family_id = fam and e.audio_path is not null and (e.created_by is null or e.created_by = p_user)) s), '[]'));

    -- Ebeveynin kendi kayıtları ve ailenin öteki tabloları (9 Kasım 2026)
    out := out || jsonb_build_object(
      'tanisma_yanitlari', coalesce((select jsonb_agg(to_jsonb(a) - 'family_id' - 'user_id' order by a.created_at, a.question_key)
                                       from public.intake_answers a where a.family_id = fam and a.user_id = p_user), '[]'),
      'ebeveyn_gorevleri', coalesce((select jsonb_agg(to_jsonb(a) - 'family_id' - 'user_id' order by a.created_at)
                                       from public.parent_assignments a where a.user_id = p_user), '[]'),
      'ebeveyn_tamamlamalari', coalesce((select jsonb_agg(to_jsonb(c) - 'family_id' - 'user_id' order by c.date, c.done_at)
                                           from public.parent_completions c where c.user_id = p_user), '[]'),
      'ebeveyn_tasi_defteri', coalesce((select jsonb_agg(to_jsonb(l) - 'family_id' - 'user_id' order by l.created_at, l.id)
                                          from public.parent_stone_ledger l where l.user_id = p_user), '[]'),
      'ebeveyn_dersleri', jsonb_build_object(
        'dersler', coalesce((select jsonb_agg(to_jsonb(p) - 'family_id' - 'user_id' || jsonb_build_object('baslik', l.title) order by p.started_at)
                               from public.parent_lesson_progress p left join public.parent_lessons l on l.key = p.lesson_key
                              where p.user_id = p_user), '[]'),
        'uygulama_gunleri', coalesce((select jsonb_agg(to_jsonb(p) - 'family_id' - 'user_id' order by p.day, p.lesson_key)
                                        from public.parent_lesson_practice p where p.user_id = p_user), '[]')),
      'hediyeler', coalesce((select jsonb_agg(case when g.from_user is distinct from p_user
                                                   then to_jsonb(g) - 'family_id' - 'note' - 'from_name' || jsonb_build_object('gonderen', 'diğer ebeveyn')
                                                   else to_jsonb(g) - 'family_id' end order by g.created_at)
                               from public.child_gifts g where g.family_id = fam), '[]'),
      'haftalik_hedef_ayarlari', coalesce((select jsonb_agg(to_jsonb(s) - 'family_id' order by s.child_id)
                                             from public.child_goal_settings s where s.family_id = fam), '[]'),
      'gorev_hatirlatmalari', coalesce((select jsonb_agg(to_jsonb(b) - 'family_id' order by b.date, b.offered_at)
                                          from public.task_boosts b where b.family_id = fam), '[]'),
      'kayitli_sablonlar', coalesce((select jsonb_agg(to_jsonb(t) - 'family_id' order by t.created_at)
                                       from public.saved_templates t where t.family_id = fam), '[]'),
      'misafir_gecisleri', coalesce((select jsonb_agg(to_jsonb(g) - 'family_id' - 'redeemed_family'
                                                      || jsonb_build_object('kullanildi', g.redeemed_at is not null) order by g.created_at)
                                       from public.guest_passes g where g.family_id = fam), '[]'),
      'kullanilan_misafir_gecisi', coalesce((select jsonb_agg(jsonb_build_object('kod', g.code, 'kullanilma', g.redeemed_at) order by g.redeemed_at)
                                               from public.guest_passes g where g.redeemed_family = fam), '[]'),
      'davet_odulleri', coalesce((select jsonb_agg(to_jsonb(r) - 'family_id' order by r.created_at)
                                    from public.referral_rewards r where r.family_id = fam), '[]'));

    -- Ebeveyn eğitimi (20261110100000_parent_trainings.sql uygulanınca): yalnız kendi tamamladığı modüller, uygulama
    -- kayıtları ve yapılacaklar; her birinde eğitimin adı (egitim), uygulama kaydında görevin adı (uygulama), paylaşım kaydı
    -- silinip eğitim ailede kaldıysa ailede_kalan = true (20261120200000_family_keeps_records.sql). Eğitimin öteki alanları,
    -- uygulama görevlerinin tanımı ve uzmanın gözlem verisi kliniğin kaydıdır.
    if to_regclass('public.parent_training_modules') is not null and to_regclass('public.parent_training_logs') is not null
       and to_regclass('public.parent_training_todos') is not null and to_regclass('public.parent_trainings') is not null
       and to_regclass('public.parent_training_tasks') is not null then
      execute $q$select jsonb_build_object(
          'moduller', coalesce((select jsonb_agg(to_jsonb(m) - 'completed_by'
                                                 || jsonb_build_object('egitim', t.title, 'ailede_kalan', t.link_id is null)
                                                 order by m.completed_at, m.id)
                                  from public.parent_training_modules m join public.parent_trainings t on t.id = m.training_id
                                 where m.completed_by = $1), '[]'),
          'uygulama_kayitlari', coalesce((select jsonb_agg(to_jsonb(l) - 'family_id' - 'created_by'
                                                           || jsonb_build_object('egitim', t.title, 'uygulama', k.title, 'ailede_kalan', t.link_id is null)
                                                           order by l.day, l.created_at)
                                            from public.parent_training_logs l join public.parent_trainings t on t.id = l.training_id
                                            join public.parent_training_tasks k on k.id = l.task_id
                                           where l.created_by = $1), '[]'),
          'yapilacaklar', coalesce((select jsonb_agg(to_jsonb(d) - 'done_by'
                                                     || jsonb_build_object('egitim', t.title, 'ailede_kalan', t.link_id is null)
                                                     order by d.done_at, d.id)
                                      from public.parent_training_todos d join public.parent_trainings t on t.id = d.training_id
                                     where d.done_by = $1), '[]'))$q$
        into v_sec using p_user;
      out := out || jsonb_build_object('ebeveyn_egitimi', v_sec);
    end if;

    -- Davranış olayları (20261110110000_target_behaviors.sql uygulanınca): yalnız kendi bildirdikleri; öteki ebeveyninkiler
    -- sayı. Hedef davranışın tanımı kliniğin kaydıdır; adı olayda behavior_title, paylaşım kaydı silindiyse link_id boş.
    if to_regclass('public.behavior_incidents') is not null then
      execute $q$select coalesce((select jsonb_agg(to_jsonb(i) - 'family_id' - 'reporter_id' order by i.occurred_at, i.created_at)
                                    from public.behavior_incidents i where i.reporter_id = $1), '[]'),
                        (select count(*) from public.behavior_incidents i where i.family_id = $2 and i.reporter_id <> $1)$q$
        into v_sec, v_n using p_user, fam;
      out := out || jsonb_build_object('davranis_olaylari', v_sec)
                 || jsonb_build_object('ayiklanan', (out -> 'ayiklanan') || jsonb_build_object('diger_ebeveynin_davranis_olaylari', v_n));
    end if;
  end if;

  -- Uzman: kendi hesabı, kliniği, belge incelemesi, anket (danışan kayıtları kliniğin kaydıdır, ayrı dışa aktarılır)
  select c.*, k.name as clinic_name, k.plan as clinic_plan, k.created_by as clinic_owner into cl
    from public.clinicians c left join public.clinics k on k.id = c.clinic_id where c.id = p_user;
  if found then
    out := out || jsonb_build_object(
      'uzman', jsonb_build_object('ad', cl.name, 'unvan', cl.title, 'rol', cl.role, 'kayit', cl.created_at,
                                  'dogrulanan_meslek', cl.verified_profession, 'dogrulama', cl.verified_at,
                                  'klinik', jsonb_build_object('id', cl.clinic_id, 'ad', cl.clinic_name, 'plan', cl.clinic_plan,
                                                               'sahibi_benim', cl.clinic_owner = p_user)),
      'klinik_uyeligi', case when cl.clinic_owner = p_user then
                          coalesce((select jsonb_agg(jsonb_build_object('plan', b.plan_id, 'durum', b.status, 'bitis', b.period_end,
                                                                        'kaynak', b.source, 'olusturulma', b.created_at) order by b.created_at)
                                      from public.billing_subscriptions b where b.clinic_id = cl.clinic_id), '[]') end,
      'belge_incelemeleri', coalesce((select jsonb_agg(to_jsonb(v) - 'clinician_id' - 'file_path' - 'decided_by' order by v.created_at)
                                        from public.clinician_verifications v where v.clinician_id = p_user), '[]'),
      'karsilama_anketi', (select to_jsonb(s) - 'clinician_id' from public.clinician_surveys s where s.clinician_id = p_user),
      'danisan_kayitlari_notu', 'Ailelerle ilgili notlar, hedefler ve takip planı uzmanın kendi mesleki kaydıdır ve bu dosyaya girmez; rapor ve CSV Moyo Mercek''ten indirilir.');
  end if;

  -- Herkes: bildirimler, yasal onaylar, KVKK başvuruları, kullanım özeti, cihazlar, ekip işlemleri
  out := out || jsonb_build_object(
    'bildirimler', coalesce((select jsonb_agg(jsonb_build_object('uygulama', n.app, 'tur', n.kind, 'baslik', n.title, 'metin', n.body,
                                                                 'zaman', n.created_at, 'okunma', n.read_at) order by n.created_at)
                               from public.notifications n where n.user_id = p_user), '[]'),
    'yasal_onaylar', coalesce((select jsonb_agg(jsonb_build_object('metin', a.doc_key, 'surum', a.version, 'uygulama', a.app, 'zaman', a.accepted_at)
                                                order by a.accepted_at) from public.legal_acceptances a where a.user_id = p_user), '[]'),
    'kvkk_basvurulari', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'tur', r.kind, 'kanal', r.channel, 'ayrinti', r.detail,
                                                                      'durum', r.status, 'alinis', r.received_at, 'son_gun', r.due_at,
                                                                      'yanit', r.answered_at) order by r.received_at)
                                    from public.kvkk_requests r where r.user_id = p_user), '[]'),
    'kullanim', jsonb_build_object(
      'uygulamalar', coalesce((select jsonb_agg(to_jsonb(a) - 'user_id') from public.user_activity a where a.user_id = p_user), '[]'),
      'olaylar', coalesce((select jsonb_agg(jsonb_build_object('uygulama', e.app, 'olay', e.event, 'sayi', e.n, 'ilk', e.first_at, 'son', e.last_at)
                                            order by e.app, e.event)
                             from (select app, event, count(*) n, min(occurred_at) first_at, max(occurred_at) last_at
                                     from public.app_events where user_id = p_user group by app, event) e), '[]'),
      'acilis_gunleri', coalesce((select jsonb_agg(jsonb_build_object('uygulama', d.app, 'gun', d.day) order by d.day, d.app)
                                    from public.activity_days d where d.user_id = p_user), '[]'),
      'aciklama', 'Uygulama açma günleri ve ekran/özellik olay adları; içerik yok. Satır satır döküm KVKK başvurusuyla istenebilir.'),
    'cihazlar', coalesce((select jsonb_agg(jsonb_build_object('uygulama', t.app, 'platform', t.platform, 'guncelleme', t.updated_at))
                            from public.push_tokens t where t.user_id = p_user), '[]'),
    'ozel_ayarlar', coalesce((select jsonb_agg(jsonb_build_object('anahtar', f.key, 'acik', f.enabled, 'bitis', f.expires_at))
                                from public.user_flags f where f.user_id = p_user), '[]'),
    'ekip_islemleri', coalesce((select jsonb_agg(jsonb_build_object('islem', a.action, 'zaman', a.at) order by a.at)
                                  from public.admin_audit a where a.target_type = 'user' and a.target_id = p_user::text), '[]'));
  return out;
end $$;
revoke execute on function public.data_export_of(uuid) from public, anon, authenticated;
