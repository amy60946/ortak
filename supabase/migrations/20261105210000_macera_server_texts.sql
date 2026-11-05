-- Sunucu metinleri "macera" kuralına göre (kullanıcı kararı 5 Kasım 2026; sozlesme/durumlar.md 5B).
-- ÜRETİLDİ: tools/macera_sunucu_metinleri.py — elle düzenleme; aracı değiştirip yeniden üret.
-- Her işlevin en son tanımı aynen, yalnız ekranda görünen metin değişti: bildirim başlıkları ("… macerayı tamamladı:",
-- "Yeni macera:", "n macera önerisi", "n macera tamamladı") ve hata iletileri ("Macera bulunamadı" …). Mantık, imza,
-- yetkiler ve ipucu (hint) kodları değişmez; tetikleyiciler yerinde kalır. Yasal metinler değişmez (avukata soru 25).
-- Tekrar çalıştırılabilir (create or replace).

-- care_plan_publish (önceki tanım: migrations/20261102100000_plan_redesign.sql)
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
                       case when k > 0 then k || ' macera önerisi' end,
                       case when ch > 0 then ch || ' değişiklik önerisi' end) || ' Uzmanım bölümünde.',
      jsonb_build_object('link_id', l.id), l.child_id);
  elsif n > 0 and (l.plan_published_at is null or l.plan_published_at < now() - interval '10 minutes') then
    perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || nm,
      'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
  end if;
end $$;

-- care_plan_publish_selected (önceki tanım: migrations/20261102500000_plan_publish_selected.sql)
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
                       case when k > 0 then k || ' macera önerisi' end,
                       case when ch > 0 then ch || ' değişiklik önerisi' end) || ' Uzmanım bölümünde.',
      jsonb_build_object('link_id', l.id), l.child_id);
  elsif plan_changed and n > 0 then
    perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || nm,
      'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
  end if;
end $$;

-- child_record_boost (önceki tanım: migrations/20261022210000_task_reminder_boost.sql)
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
    raise exception 'Macera bulunamadı';
  end if;
  if p_date > current_date + 1 or p_date < current_date - 1 then
    raise exception 'Bu günün macerası için teklif kaydedilemez';
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

-- child_set_status (önceki tanım: migrations/20261019020000_server_rules.sql)
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
    raise exception 'Macera bulunamadı';
  end if;
  if p_date > current_date + 1 then
    raise exception 'Gelecek günün macerası işaretlenemez';
  end if;
  if p_date < current_date - 1 then
    raise exception 'Geçmiş günün macerası işaretlenemez';
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

-- children_notify_device (önceki tanım: migrations/20261019130000_notifications.sql)
create or replace function public.children_notify_device() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.user_id is null and new.user_id is not null then
    perform public.notify_parents(new.family_id, 'device_linked', new.name || ' oyuna bağlandı',
      'Maceralar artık oyunda görünüyor.', jsonb_build_object('child_id', new.id), new.id);
  end if;
  return null;
end $$;

-- claim_weekly_goal (önceki tanım: migrations/20261022230000_weekly_goal.sql)
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
    (g ->> 'done') || ' macera tamamladı. Birlikte kutlayın!', json_build_object('week_start', w, 'target', g -> 'target')::jsonb, me);
  return json_build_object('ok', true, 'error', null, 'stones', 2);
end $$;

-- clinic_links_notify_insert (önceki tanım: migrations/20261022100000_clinic_assignments.sql)
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
      'Aile rıza verdi: ' || r.names || '. Maceraları ve kayıtları artık görebilirsin.',
      jsonb_build_object('links', r.links, 'family_id', r.family_id), null,
      case when r.n_children = 1 then r.first_child end);
  end loop;
  return null;
end $$;

-- clinic_routines_check (önceki tanım: migrations/20261028200000_routines_v2.sql)
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
    raise exception 'Rutinde 1–12 macera olmalı' using errcode = '23514';
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
      raise exception 'Rutindeki macera geçersiz' using errcode = '23514';
    end if;
  end loop;
  return new;
end $$;

-- completions_notify (önceki tanım: migrations/20261027130000_review_detail.sql)
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
      perform public.notify_parents(new.family_id, 'task_done', nm || ' macerayı tamamladı: ' || coalesce(t.title, ''),
        'Onayını bekliyor.', d, new.child_id);
    elsif new.status = 'approved' then
      perform public.notify_parents(new.family_id, 'task_done', nm || ' macerayı tamamladı: ' || coalesce(t.title, ''),
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

-- cts_change_guard (önceki tanım: migrations/20261102100000_plan_redesign.sql)
create or replace function public.cts_change_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'change' and not exists (
       select 1 from public.tasks t join public.task_assignments a on a.task_id = t.id
        where t.id = new.target_task_id and t.family_id = new.family_id and a.child_id = new.child_id) then
    raise exception 'Değişiklik önerisi yalnız bu çocuğun macerasına yapılır';
  end if;
  return new;
end $$;

-- join_family (önceki tanım: migrations/20261025000000_whitehat2.sql)
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
    raise exception 'Kendi hesabında kayıtlı çocuk ya da macera var; katılırsan silinir. Önce onları sil ya da başka bir e-postayla katıl.';
  end if;

  update public.profiles set family_id = inv.family_id, invited_by = inv.created_by where id = uid;
  update public.invite_codes set used_at = now(), used_by = uid where code = inv.code;
  if old_fid is not null and not exists (select 1 from public.profiles where family_id = old_fid) then
    delete from public.families where id = old_fid;
  end if;
  return json_build_object('family_id', inv.family_id);
end $function$

;

-- parent_assignments_guard (önceki tanım: migrations/20261027140000_parent_tasks_gifts.sql)
create or replace function public.parent_assignments_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and (new.task_id <> old.task_id or new.user_id <> old.user_id or new.family_id <> old.family_id) then
    raise exception 'Atama değiştirilemez; silip yeniden ekle';
  end if;
  if public.task_family(new.task_id) is distinct from new.family_id then
    raise exception 'Macera bu ailenin değil';
  end if;
  if not exists (select 1 from public.profiles p where p.id = new.user_id and p.family_id = new.family_id) then
    raise exception 'Yalnız ailedeki bir ebeveyne atanabilir' using hint = 'not_family_parent';
  end if;
  return new;
end $$;

-- parent_task_done (önceki tanım: migrations/20261027140000_parent_tasks_gifts.sql)
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
    raise exception 'Bu macera sana atanmamış' using hint = 'not_assigned';
  end if;
  select * into t from public.tasks where id = p_task_id;
  if not public.task_occurs_on(t, p_date) then
    raise exception 'Macera o gün yok' using hint = 'not_on_date';
  end if;
  if p_date > current_date + 1 or p_date < current_date - 7 then
    raise exception 'Yalnız son bir haftanın macerası işaretlenebilir' using hint = 'date_range';
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

-- review_completion (önceki tanım: migrations/20261027130000_review_detail.sql)
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
    raise exception 'Yalnız bugünün macerası tekrar denenebilir' using hint = 'retry_past';
  end if;
  insert into public.completions (family_id, task_id, child_id, date, status, parent_note, reviewed_at, reviewed_by, motivation, stones)
  values (fam, p_task_id, p_child_id, p_date, p_status, nullif(trim(p_note), ''), now(), auth.uid(), p_motivation,
          case when p_status = 'approved' then p_stones end)
  on conflict (task_id, child_id, date) do update
    set status = excluded.status, parent_note = excluded.parent_note, reviewed_at = now(), reviewed_by = auth.uid(),
        motivation = excluded.motivation, stones = excluded.stones;
end $$;

-- task_assignments_notify (önceki tanım: migrations/20261019130000_notifications.sql)
create or replace function public.task_assignments_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare t record;
begin
  select title, emoji into t from public.tasks where id = new.task_id;
  perform public.notify_child(new.child_id, 'task_assigned', 'Yeni macera: ' || coalesce(t.emoji || ' ', '') || coalesce(t.title, ''),
    case when new.coins > 0 then new.coins || ' coin değerinde.' else '' end,
    jsonb_build_object('task_id', new.task_id, 'child_id', new.child_id));
  return null;
end $$;

-- tasks_free_limit (önceki tanım: migrations/20261022110000_subscriptions.sql)
create or replace function public.tasks_free_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := public.billing_config();
begin
  if public.family_full_access(new.family_id) then return new; end if;
  if (select count(*) from public.tasks t where t.family_id = new.family_id
        and (t.end_date is null or t.end_date >= current_date)
        and (t.recurring or t.start_date >= current_date)) >= (cfg ->> 'free_max_tasks')::int then
    raise exception 'Ücretsiz planda en çok % etkin macera olabilir', cfg ->> 'free_max_tasks'
      using errcode = 'P0001', hint = 'premium_required';
  end if;
  return new;
end $$;
