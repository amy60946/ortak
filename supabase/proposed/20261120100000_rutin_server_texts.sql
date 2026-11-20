-- Sunucu metinleri: aile ve uzman tarafında "rutin / adım", oyunda "macera" (kullanıcı kararı 14 Kasım 2026;
-- sozlesme/durumlar.md 5B). 20261105210000_macera_server_texts'in yerine geçer. Ayrıca uzman rozeti bildirimi
-- "Belgen incelendi" → "Belge yüklendi" (sozlesme/hukuk_notlari.md M.3) ve eski ürün adları → Moyo adları.
-- ÜRETİLDİ: tools/macera_sunucu_metinleri.py — elle düzenleme; aracı değiştirip yeniden üret.
-- Her işlevin en son tanımı aynen, yalnız ekranda görünen metin değişti. Mantık, imza, yetkiler ve ipucu (hint)
-- kodları değişmez; tetikleyiciler yerinde kalır. Çocuğa giden metinler ("Yeni macera: …") değişmez.
-- Tekrar çalıştırılabilir (create or replace).

-- completions_notify (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
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
      perform public.notify_parents(new.family_id, 'task_done', nm || ' adımı tamamladı: ' || coalesce(t.title, ''),
        'Onayını bekliyor.', d, new.child_id);
    elsif new.status = 'approved' then
      perform public.notify_parents(new.family_id, 'task_done', nm || ' adımı tamamladı: ' || coalesce(t.title, ''),
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

-- claim_weekly_goal (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.claim_weekly_goal()
returns json language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
  fam uuid;
  nm text;
  g json;
  w date;
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  g := public.weekly_goal_calc(me, current_date);
  w := (g ->> 'week_start')::date;
  if (g ->> 'target') is null then
    return json_build_object('ok', false, 'error', 'no_goal', 'stones', 0);
  end if;
  if (g ->> 'claimed')::boolean then
    return json_build_object('ok', false, 'error', 'already_claimed', 'stones', 0);
  end if;
  if (g ->> 'done')::int < (g ->> 'target')::int then
    return json_build_object('ok', false, 'error', 'not_reached', 'stones', 0);
  end if;
  select c.family_id, c.name into fam, nm from public.children c where c.id = me;
  insert into public.weekly_goal_claims (child_id, week_start, family_id, target) values (me, w, fam, (g ->> 'target')::int)
  on conflict (child_id, week_start) do nothing;
  if not found then
    return json_build_object('ok', false, 'error', 'already_claimed', 'stones', 0);
  end if;
  insert into public.sun_stone_ledger (family_id, child_id, amount, reason, ref)
  values (fam, me, 2, 'goal', 'goal:' || w::text);
  perform public.notify_parents(fam, 'weekly_goal', left(nm || ' haftalık hedefine ulaştı!', 120),
    (g ->> 'done') || ' adım tamamladı. Birlikte kutlayın!', json_build_object('week_start', w, 'target', g -> 'target')::jsonb, me);
  return json_build_object('ok', true, 'error', null, 'stones', 2);
end $$;

-- children_notify_device (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.children_notify_device() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.user_id is null and new.user_id is not null then
    perform public.notify_parents(new.family_id, 'device_linked', new.name || ' oyuna bağlandı',
      'Eklediğin rutinler artık oyunda macera olarak görünüyor.', jsonb_build_object('child_id', new.id), new.id);
  end if;
  return null;
end $$;

-- care_plan_publish (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.care_plan_publish(p_link_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  before integer;
  n integer;
  k integer;
  ch integer;
  nm text;
begin
  if not public.clinic_link_mine(p_link_id) then raise exception 'Paylaşım bulunamadı'; end if;
  select * into l from public.clinic_links where id = p_link_id for update;
  nm := public.child_name(l.child_id);
  select (select count(*) from public.clinic_goals where link_id = p_link_id and pub is not null)
       + (select count(*) from public.care_modules where link_id = p_link_id and pub is not null) into before;
  n := public.care_plan_snapshot(p_link_id);
  -- taslak öneriler aileye açılır (bildirim burada tek seferde)
  select count(*) filter (where kind = 'new'), count(*) filter (where kind = 'change') into k, ch
    from public.clinic_task_suggestions where link_id = p_link_id and status = 'draft';
  update public.clinic_task_suggestions set status = 'pending', updated_at = now() where link_id = p_link_id and status = 'draft';
  if n = 0 and before = 0 and k + ch = 0 then
    raise exception 'Aileye gösterilecek bir şey yok: "Aile görür" açık bir hedef, etkin bir program ya da bir öneri ekle';
  end if;
  if k + ch > 0 then
    perform public.notify_parents(l.family_id, case when n > 0 then 'care_plan_shared' else 'clinic_suggestion' end,
      case when n > 0 then 'Takip planı güncellendi: ' || nm else 'Uzmanın ' || nm || ' için öneri gönderdi' end,
      concat_ws(' · ', case when n > 0 then 'Hedefler ve aile programı' end,
                       case when k > 0 then k || ' adım önerisi' end,
                       case when ch > 0 then ch || ' değişiklik önerisi' end) || ' Uzmanım bölümünde.',
      jsonb_build_object('link_id', l.id), l.child_id);
  elsif n > 0 and (l.plan_published_at is null or l.plan_published_at < now() - interval '10 minutes') then
    perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || nm,
      'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
  end if;
end $$;

-- care_plan_publish_selected (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.care_plan_publish_selected(p_link_id uuid, p_hold uuid[] default '{}')
returns void language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  hold uuid[] := coalesce(p_hold, '{}');
  before_pub jsonb;
  after_pub jsonb;
  n integer;
  k integer;
  ch integer;
  nm text;
  plan_changed boolean;
begin
  if not public.clinic_link_mine(p_link_id) then raise exception 'Paylaşım bulunamadı'; end if;
  select * into l from public.clinic_links where id = p_link_id for update;
  nm := public.child_name(l.child_id);
  select coalesce(jsonb_agg(jsonb_build_array(x.id, x.pub) order by x.id), '[]'::jsonb) into before_pub
    from (select id, pub from public.clinic_goals where link_id = p_link_id
          union all select id, pub from public.care_modules where link_id = p_link_id) x;
  n := public.care_plan_snapshot_hold(p_link_id, hold);
  select coalesce(jsonb_agg(jsonb_build_array(x.id, x.pub) order by x.id), '[]'::jsonb) into after_pub
    from (select id, pub from public.clinic_goals where link_id = p_link_id
          union all select id, pub from public.care_modules where link_id = p_link_id) x;
  plan_changed := before_pub is distinct from after_pub;
  -- bekletilmeyen taslak öneriler aileye açılır (bildirim burada tek seferde)
  select count(*) filter (where kind = 'new'), count(*) filter (where kind = 'change') into k, ch
    from public.clinic_task_suggestions where link_id = p_link_id and status = 'draft' and not (id = any(hold));
  update public.clinic_task_suggestions set status = 'pending', updated_at = now()
   where link_id = p_link_id and status = 'draft' and not (id = any(hold));
  if n = 0 and k + ch = 0 and not plan_changed then
    raise exception 'Aileye gösterilecek bir şey yok: "Aile görür" açık bir hedef, etkin bir program ya da bir öneri ekle';
  end if;
  if k + ch > 0 then
    perform public.notify_parents(l.family_id, case when plan_changed then 'care_plan_shared' else 'clinic_suggestion' end,
      case when plan_changed then 'Takip planı güncellendi: ' || nm else 'Uzmanın ' || nm || ' için öneri gönderdi' end,
      concat_ws(' · ', case when plan_changed then 'Hedefler ve aile programı' end,
                       case when k > 0 then k || ' adım önerisi' end,
                       case when ch > 0 then ch || ' değişiklik önerisi' end) || ' Uzmanım bölümünde.',
      jsonb_build_object('link_id', l.id), l.child_id);
  elsif plan_changed and n > 0 then
    perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || nm,
      'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
  end if;
end $$;

-- suggestions_notify (önceki tanım: migrations/20261105090000_workspaces.sql)
create or replace function public.suggestions_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  nm text := public.child_name(new.child_id);
  d jsonb := jsonb_build_object('suggestion_id', new.id, 'child_id', new.child_id, 'link_id', new.link_id);
  rid uuid;
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform public.notify_parents(new.family_id, 'clinic_suggestion',
        case when new.kind = 'change' then 'Uzmanın ' || nm || ' için değişiklik önerdi' else 'Uzmanın ' || nm || ' için adım önerdi' end,
        coalesce(new.emoji || ' ', '') || new.title, d - 'link_id', new.child_id);
    end if;
  elsif old.status = 'pending' and new.status in ('accepted', 'declined') then
    -- öneriyi yazan uzman hâlâ danışanı görüyorsa ona; görmüyorsa danışanın alıcılarına
    for rid in
      select new.created_by where new.created_by is not null and exists (
        select 1 from public.clinic_members m join public.clinic_links l on l.id = new.link_id
         where m.clinician_id = new.created_by and m.clinic_id = l.clinic_id and m.status = 'active'
           and (m.role = 'owner' or l.clinician_id = m.clinician_id
                or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.clinician_id)))
      union
      select x from public.clinic_link_recipients(new.link_id) x
       where new.created_by is null or not exists (
         select 1 from public.clinic_members m join public.clinic_links l on l.id = new.link_id
          where m.clinician_id = new.created_by and m.clinic_id = l.clinic_id and m.status = 'active'
            and (m.role = 'owner' or l.clinician_id = m.clinician_id
                 or exists (select 1 from public.clinic_link_access a where a.link_id = l.id and a.clinician_id = m.clinician_id)))
    loop
      perform public.notify(rid, 'clinic', 'suggestion_decided',
        case when new.kind = 'change' then
               case when new.status = 'accepted' then 'Değişiklik uygulandı: ' else 'Değişiklik şimdilik uygulanmadı: ' end
             else case when new.status = 'accepted' then 'Öneri kabul edildi: ' else 'Öneri şimdilik eklenmedi: ' end end || new.title,
        nm, d, null, new.child_id);
    end loop;
  end if;
  return null;
end $$;

-- join_family (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
CREATE OR REPLACE FUNCTION public.join_family(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid := auth.uid();
  inv public.invite_codes%rowtype;
  old_fid uuid;
  t json;
begin
  if uid is null or not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Önce giriş yapmalısın' using errcode = '42501';
  end if;
  t := public.code_throttled();
  if t is not null then return t; end if;

  select * into inv from public.invite_codes
    where code = upper(trim(p_code)) and kind = 'parent'
    for update;
  if not found then return public.code_rejected('not_found'); end if;
  if public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.code_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;

  select family_id into old_fid from public.profiles where id = uid;
  if old_fid = inv.family_id then
    raise exception 'Zaten bu ailedesin';
  end if;
  if old_fid is not null
     and not exists (select 1 from public.profiles where family_id = old_fid and id <> uid)
     and (exists (select 1 from public.children where family_id = old_fid)
          or exists (select 1 from public.tasks where family_id = old_fid)) then
    raise exception 'Kendi hesabında kayıtlı çocuk ya da rutin var; katılırsan silinir. Önce onları sil ya da başka bir e-postayla katıl.';
  end if;

  update public.profiles set family_id = inv.family_id, invited_by = inv.created_by where id = uid;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;
  if old_fid is not null and not exists (select 1 from public.profiles where family_id = old_fid) then
    delete from public.families where id = old_fid;
  end if;
  return json_build_object('family_id', inv.family_id);
end $function$

;

-- parent_assignments_guard (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.parent_assignments_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and (new.task_id <> old.task_id or new.user_id <> old.user_id or new.family_id <> old.family_id) then
    raise exception 'Atama değiştirilemez; silip yeniden ekle';
  end if;
  if public.task_family(new.task_id) is distinct from new.family_id then
    raise exception 'Adım bu ailenin değil';
  end if;
  if not exists (select 1 from public.profiles p where p.id = new.user_id and p.family_id = new.family_id) then
    raise exception 'Yalnız ailedeki bir ebeveyne atanabilir' using hint = 'not_family_parent';
  end if;
  return new;
end $$;

-- parent_task_done (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.parent_task_done(p_task_id uuid, p_date date, p_done boolean default true)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  fam uuid := public.my_family_id();
  t public.tasks%rowtype;
  diff text;
  k text := p_task_id::text || '|' || p_date::text;
  n integer;
begin
  if uid is null or fam is null then
    raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501';
  end if;
  select a.difficulty into diff from public.parent_assignments a where a.task_id = p_task_id and a.user_id = uid and a.family_id = fam;
  if not found then
    raise exception 'Bu adım sana atanmamış' using hint = 'not_assigned';
  end if;
  select * into t from public.tasks where id = p_task_id;
  if not public.task_occurs_on(t, p_date) then
    raise exception 'Adım o gün yok' using hint = 'not_on_date';
  end if;
  if p_date > current_date + 1 or p_date < current_date - 7 then
    raise exception 'Yalnız son bir haftanın adımı işaretlenebilir' using hint = 'date_range';
  end if;
  if p_done then
    insert into public.parent_completions (task_id, user_id, date, family_id) values (p_task_id, uid, p_date, fam)
    on conflict do nothing;
    if found then
      insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
      values (fam, uid, public.stones_for_difficulty(diff), 'task', k || ':' || extract(epoch from clock_timestamp())::text);
    end if;
  else
    delete from public.parent_completions where task_id = p_task_id and user_id = uid and date = p_date;
    if found then
      select coalesce(sum(amount), 0) into n from public.parent_stone_ledger
        where user_id = uid and reason in ('task', 'task_undo') and split_part(ref, ':', 1) = k;
      if n > 0 then
        insert into public.parent_stone_ledger (family_id, user_id, amount, reason, ref)
        values (fam, uid, -n, 'task_undo', k || ':' || extract(epoch from clock_timestamp())::text);
      end if;
    end if;
  end if;
  return public.parent_stone_balance(uid);
end $$;

-- review_completion (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
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
    raise exception 'Yalnız bugünün adımı tekrar denenebilir' using hint = 'retry_past';
  end if;
  insert into public.completions (family_id, task_id, child_id, date, status, parent_note, reviewed_at, reviewed_by, motivation, stones)
  values (fam, p_task_id, p_child_id, p_date, p_status, nullif(trim(p_note), ''), now(), auth.uid(), p_motivation,
          case when p_status = 'approved' then p_stones end)
  on conflict (task_id, child_id, date) do update
    set status = excluded.status, parent_note = excluded.parent_note, reviewed_at = now(), reviewed_by = auth.uid(),
        motivation = excluded.motivation, stones = excluded.stones;
end $$;

-- tasks_free_limit (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.tasks_free_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := public.billing_config();
begin
  if public.family_full_access(new.family_id) then return new; end if;
  if (select count(*) from public.tasks t where t.family_id = new.family_id
        and (t.end_date is null or t.end_date >= current_date)
        and (t.recurring or t.start_date >= current_date)) >= (cfg ->> 'free_max_tasks')::int then
    raise exception 'Ücretsiz planda en çok % etkin adım olabilir', cfg ->> 'free_max_tasks'
      using errcode = 'P0001', hint = 'premium_required';
  end if;
  return new;
end $$;

-- legal_accept (önceki tanım: migrations/20261027200000_legal.sql)
create or replace function public.legal_accept(p_app text, p_docs jsonb)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  x jsonb;
begin
  if uid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  if jsonb_typeof(p_docs) <> 'array' or jsonb_array_length(p_docs) = 0 or jsonb_array_length(p_docs) > 20 then
    raise exception 'Onaylanacak metin seç';
  end if;
  -- child: veli onaylar (çocuk cihazının anonim oturumu onay veremez)
  if p_app = 'child' and not exists (select 1 from public.profiles where id = uid) then
    raise exception 'Moyo Oyun koşullarını veli Moyo''da onaylar';
  end if;
  for x in select * from jsonb_array_elements(p_docs) loop
    if not exists (select 1 from public.legal_documents d
                    where d.key = x ->> 'key' and d.version = x ->> 'version' and d.requires_acceptance
                      and p_app = any(d.apps) and d.version = public.legal_current_version(d.key)) then
      raise exception 'Metin güncel değil: % %', x ->> 'key', x ->> 'version';
    end if;
    insert into public.legal_acceptances (user_id, doc_key, version, app) values (uid, x ->> 'key', x ->> 'version', p_app)
    on conflict do nothing;
  end loop;
  return public.legal_pending(p_app);
end $$;

-- clinic_links_notify_insert (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.clinic_links_notify_insert() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in
    select n.clinic_id, rc.rid, n.family_id, count(*) as n_children,
           string_agg(c.name, ', ' order by c.name) as names, (array_agg(n.child_id))[1] as first_child,
           jsonb_agg(jsonb_build_object('link_id', n.id, 'child_id', n.child_id)) as links
      from new_rows n
      join public.children c on c.id = n.child_id
      cross join lateral public.clinic_link_recipients(n.id) as rc(rid)
     group by n.clinic_id, rc.rid, n.family_id
  loop
    perform public.notify(r.rid, 'clinic', 'clinic_shared',
      case when r.n_children = 1 then 'Yeni paylaşım: ' || r.names else r.n_children || ' çocuk paylaşıldı' end,
      'Aile rıza verdi: ' || r.names || '. Rutinleri ve kayıtları artık görebilirsin.',
      jsonb_build_object('links', r.links, 'family_id', r.family_id), null,
      case when r.n_children = 1 then r.first_child end);
  end loop;
  return null;
end $$;

-- clinic_routines_check (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.clinic_routines_check() returns trigger
language plpgsql security definer set search_path = '' as $$
declare x jsonb;
begin
  if tg_op = 'INSERT' then
    new.clinic_id := public.my_clinic_id();
    new.created_by := auth.uid();
  else
    new.clinic_id := old.clinic_id;
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  if jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) not between 1 and 12 then
    raise exception 'Rutinde 1–12 adım olmalı' using errcode = '23514';
  end if;
  for x in select * from jsonb_array_elements(new.items) loop
    if jsonb_typeof(x) <> 'object'
       or exists (select 1 from jsonb_object_keys(x) k
                  where k not in ('key', 'title', 'emoji', 'skill', 'category', 'difficulty', 'coins', 'time', 'days'))
       or char_length(coalesce(x ->> 'title', '')) not between 1 and 120
       or char_length(coalesce(x ->> 'emoji', '')) > 16
       or coalesce(x ->> 'difficulty', 'easy') not in ('easy', 'medium', 'hard')
       or (x ? 'coins' and (jsonb_typeof(x -> 'coins') <> 'number' or (x ->> 'coins')::numeric not between 0 and 50))
       or (x ? 'time' and coalesce(x ->> 'time', '') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
       or (x ? 'days' and (jsonb_typeof(x -> 'days') <> 'array'
           or exists (select 1 from jsonb_array_elements_text(x -> 'days') d where d !~ '^[1-7]$')))
       or char_length(coalesce(x ->> 'key', '')) > 60 or char_length(coalesce(x ->> 'skill', '')) > 40
       or char_length(coalesce(x ->> 'category', '')) > 20 then
      raise exception 'Rutindeki adım geçersiz' using errcode = '23514';
    end if;
  end loop;
  return new;
end $$;

-- cts_change_guard (önceki tanım: migrations/20261105210000_macera_server_texts.sql)
create or replace function public.cts_change_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'change' and not exists (
       select 1 from public.tasks t join public.task_assignments a on a.task_id = t.id
        where t.id = new.target_task_id and t.family_id = new.family_id and a.child_id = new.child_id) then
    raise exception 'Değişiklik önerisi yalnız bu çocuğun adımına yapılır';
  end if;
  return new;
end $$;

-- admin_verification_decide (önceki tanım: migrations/20261026300000_review_fixes.sql)
create or replace function public.admin_verification_decide(p_id uuid, p_approve boolean, p_reason_code text, p_note text,
                                                            p_barcode text, p_summary jsonb, p_reason text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  v public.clinician_verifications%rowtype;
  bc text := nullif(left(btrim(coalesce(p_barcode, '')), 60), '');
  s jsonb;
begin
  if p_approve is null then raise exception 'Onay ya da ret seç'; end if;
  select * into v from public.clinician_verifications where id = p_id for update;
  if not found or v.status not in ('pending', 'auto_rejected') then raise exception 'Başvuru karar beklemiyor'; end if;
  if not p_approve and (p_reason_code is null or p_reason_code not in ('name_mismatch', 'barcode_invalid', 'program_mismatch',
       'degree_mismatch', 'unreadable', 'student_doc', 'duplicate', 'bacb_inactive', 'other')) then
    raise exception 'Ret nedeni seç';
  end if;
  if char_length(coalesce(p_note, '')) > 300 then raise exception 'Açıklama en çok 300 karakter'; end if;
  if p_approve and coalesce(bc, v.barcode) is not null and exists (select 1 from public.clinician_verifications o
       where o.barcode = coalesce(bc, v.barcode) and o.clinician_id <> v.clinician_id and o.status in ('approved', 'suspended')) then
    raise exception 'Bu barkod başka bir uzmanda onaylı';
  end if;
  if p_approve and v.submitted_name is not null
     and public.name_key(v.submitted_name) <> public.name_key((select name from public.clinicians where id = v.clinician_id)) then
    raise exception 'Uzman başvurudan sonra adını değiştirdi; belgeyi yeniden yüklemesini iste';
  end if;
  s := case when p_approve then jsonb_strip_nulls(jsonb_build_object(
         'university', left(p_summary ->> 'university', 120), 'program', left(p_summary ->> 'program', 120),
         'degree', left(p_summary ->> 'degree', 40), 'graduation_year', left(p_summary ->> 'graduation_year', 4))) end;
  update public.clinician_verifications
     set status = case when p_approve then 'approved' else 'rejected' end,
         reason = case when p_approve then null else p_reason_code end,
         note = nullif(btrim(coalesce(p_note, '')), ''), barcode = coalesce(bc, barcode), summary = s,
         auto = auto - 'extracted',   -- karar sonrası yalnız özet kalır
         decided_at = now(), decided_by = me, file_path = null,
         recheck_at = case when p_approve and v.profession = 'bcba' then now() + interval '1 year' end
   where id = v.id;
  if p_approve then
    update public.clinicians set verified_profession = v.profession, verified_at = now() where id = v.clinician_id;
    update public.clinician_verifications set status = 'withdrawn'
     where clinician_id = v.clinician_id and status = 'approved' and id <> v.id;
    perform public.notify(v.clinician_id, 'clinic', 'verification_approved', 'Belge yüklendi',
      'Panelinde "Belge yüklendi: ' || coalesce(public.clinician_badge(v.clinician_id),
        case when v.profession = 'diger' then 'Uzman' else public.clinician_profession_label(v.profession) end) || '" görünür; ailelere "Uzman diploma belgesini yükledi" yazar.',
      jsonb_build_object('verification_id', v.id));
  else
    perform public.notify(v.clinician_id, 'clinic', 'verification_rejected', 'Belge incelemesi: yeniden yükle',
      left(coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'Ayrıntı Moyo Mercek''te.'), 300),
      jsonb_build_object('verification_id', v.id, 'reason', p_reason_code));
  end if;
  perform public.admin_log(me, case when p_approve then 'verification.approve' else 'verification.reject' end,
                           'user', v.clinician_id::text, p_reason, jsonb_build_object('status', v.status),
                           jsonb_build_object('verification_id', v.id, 'profession', v.profession, 'reason_code', p_reason_code));
  return v.file_path;
end $$;

-- data_export_of (önceki tanım: migrations/20261110120000_kvkk_export_v2.sql)
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
    -- kayıtları ve yapılacaklar. Eğitimin tanımı, görevleri ve veri tablosu kliniğin kaydıdır.
    if to_regclass('public.parent_training_modules') is not null and to_regclass('public.parent_training_logs') is not null
       and to_regclass('public.parent_training_todos') is not null then
      execute $q$select jsonb_build_object(
          'moduller', coalesce((select jsonb_agg(to_jsonb(m) - 'completed_by' order by m.completed_at, m.id)
                                  from public.parent_training_modules m where m.completed_by = $1), '[]'),
          'uygulama_kayitlari', coalesce((select jsonb_agg(to_jsonb(l) - 'family_id' - 'created_by' order by l.day, l.created_at)
                                            from public.parent_training_logs l where l.created_by = $1), '[]'),
          'yapilacaklar', coalesce((select jsonb_agg(to_jsonb(t) - 'done_by' order by t.done_at, t.id)
                                      from public.parent_training_todos t where t.done_by = $1), '[]'))$q$
        into v_sec using p_user;
      out := out || jsonb_build_object('ebeveyn_egitimi', v_sec);
    end if;

    -- Davranış olayları (20261110110000_target_behaviors.sql uygulanınca): yalnız kendi bildirdikleri; öteki ebeveyninkiler
    -- sayı. Hedef davranışın tanımı kliniğin kaydıdır.
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
