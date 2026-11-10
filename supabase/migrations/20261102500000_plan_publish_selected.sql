-- =====================================================================
-- Takip planı: "Aileye gönder" önce özet gösterir, istenen parça bekletilir (kullanıcı kararı 2 Kasım 2026, "G1").
-- ClinicApp'te düğme bir özet açar: gidecek hedef, program ve rutin/görev taslakları hedef hedef listelenir, hepsi işaretli;
-- uzman işaretini kaldırdığı parçayı bekletir. Aile yine tek bildirim alır.
--
--   care_plan_publish_selected(p_link_id, p_hold):
--     p_hold içindeki hedef, program ve öneri kimlikleri bu gönderimde BEKLER: hedef/program ailede önceki gönderilmiş
--     sürümünde kalır (hiç gönderilmediyse ailede yoktur), taslak öneri taslak kalır. p_hold boşsa hepsi gider (care_plan_publish ile aynı).
--     Gönderilecek yeni bir şey yoksa bildirim gitmez (eski işlev gibi yeniden bildirim yapmaz).
--   Programın aileye görünen hedefleri (pub.goal_ids) artık "aileye gönderilmiş hedefler"den (pub dolu) yazılır: bekletilen yeni hedef
--     ailenin planında olmadığı için programda da anılmaz. Tam gönderimde sonuç öncekiyle aynıdır (gönderilmiş = aile görür + arşivde değil).
--   care_plan_snapshot(p_link_id) ve care_plan_publish(p_link_id) aynı kalır (eski ClinicApp sürümleri ve davet akışı bunları çağırır);
--     snapshot artık bekletmesiz care_plan_snapshot_hold'a yönlenir.
--
-- Veritabanı tablosu değişmez. Tekrar çalıştırılabilir. Supabase'e uygulandı (2 Kasım 2026, kullanıcı).
-- =====================================================================

create or replace function public.care_plan_snapshot_hold(p_link_id uuid, p_hold uuid[])
returns integer language plpgsql security definer set search_path = '' as $$
declare
  n integer;
  hold uuid[] := coalesce(p_hold, '{}');
begin
  perform set_config('ortak.care_snapshot', 'on', true);
  update public.clinic_goals set pub = case when shared and not archived then jsonb_build_object(
           'title', title, 'description', description, 'domain', domain, 'measure', measure, 'baseline', baseline,
           'target', target, 'weeks', weeks, 'home_support', home_support, 'status', status, 'position', position) end
   where link_id = p_link_id and not (id = any(hold));
  -- hedefler önce yazıldı: program yalnız aileye gönderilmiş hedefleri anar
  update public.care_modules m set pub = case when m.status <> 'planned' then jsonb_build_object(
           'title', m.title, 'aim', m.aim, 'practice', m.practice, 'checklist', m.checklist, 'status', m.status, 'position', m.position,
           'goal_ids', coalesce((select jsonb_agg(x.goal_id order by g.position, g.created_at)
                                   from public.care_module_goals x join public.clinic_goals g on g.id = x.goal_id
                                  where x.module_id = m.id and g.pub is not null), '[]'::jsonb)) end
   where m.link_id = p_link_id and not (m.id = any(hold));
  perform set_config('ortak.care_snapshot', 'off', true);
  select (select count(*) from public.clinic_goals where link_id = p_link_id and pub is not null)
       + (select count(*) from public.care_modules where link_id = p_link_id and pub is not null) into n;
  update public.clinic_links set plan_published_at = now() where id = p_link_id;
  return n;
end $$;
revoke execute on function public.care_plan_snapshot_hold(uuid, uuid[]) from public, anon, authenticated;

create or replace function public.care_plan_snapshot(p_link_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
begin
  return public.care_plan_snapshot_hold(p_link_id, '{}');
end $$;
revoke execute on function public.care_plan_snapshot(uuid) from public, anon, authenticated;

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
                       case when k > 0 then k || ' görev önerisi' end,
                       case when ch > 0 then ch || ' değişiklik önerisi' end) || ' Uzmanım bölümünde.',
      jsonb_build_object('link_id', l.id), l.child_id);
  elsif plan_changed and n > 0 then
    perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || nm,
      'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
  end if;
end $$;
revoke execute on function public.care_plan_publish_selected(uuid, uuid[]) from public, anon;
grant execute on function public.care_plan_publish_selected(uuid, uuid[]) to authenticated;
