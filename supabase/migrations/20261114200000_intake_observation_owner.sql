-- Tanışma soruları: tanı ve ilaç soruları kalktı; paneldeki kişi bazlı yanıtları yalnız owner görür.
-- Kullanıcı kararları 14 Kasım 2026 (avukat dosyası karar 1 ve 4; sozlesme/hukuk_notlari.md M).
-- 1) child_diagnosis ve child_medication: yeni yanıt yazılmaz. Eski bir uygulama sürümü gönderirse satır
--    sessizce atlanır (kurulum akışı hata görmez). Var olan yanıtlar silinir. Bu iki sorunun yerine haftalık
--    gözlem sorularına iki madde eklendi (child_waiting, child_transitions; ParentApp src/data/intake.ts →
--    veri/tanisma_sorulari.json). Sunucu soru anahtarlarını listelemez, yeni anahtar için değişiklik gerekmez.
--    Sağlık yanıtı onayı (consent_version zorunluluğu) kalktı; sütun duruyor, artık doldurulmuyor.
-- 2) admin_intake (kişi bazlı yanıtlar): yalnız owner (önce support + owner). admin_intake_summary
--    (yalnız sayılar) değişmedi.
-- Tekrar çalıştırılabilir.

create or replace function public.intake_answers_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v jsonb;
begin
  -- Kaldırılan sağlık soruları: satır yazılmaz, hata da verilmez
  if (tg_op = 'INSERT' and new.question_key in ('child_diagnosis', 'child_medication'))
     or (tg_op = 'UPDATE' and old.question_key in ('child_diagnosis', 'child_medication')) then
    return null;
  end if;
  if tg_op = 'INSERT' then
    new.user_id := auth.uid();
    new.family_id := public.my_family_id();
    new.created_at := now();
  else
    new.user_id := old.user_id;
    new.family_id := old.family_id;
    new.child_id := old.child_id;
    new.question_key := old.question_key;
    new.created_at := old.created_at;
  end if;
  if new.user_id is null or new.family_id is null then
    raise exception 'Önce ebeveyn olarak giriş yapmalısın' using errcode = '42501';
  end if;
  if new.child_id is not null and not exists (
    select 1 from public.children c where c.id = new.child_id and c.family_id = new.family_id) then
    raise exception 'Çocuk bulunamadı';
  end if;
  for v in select * from jsonb_array_elements(new.answer) loop
    if jsonb_typeof(v) <> 'string' or (v #>> '{}') !~ '^[a-z0-9_]{1,40}$' then
      raise exception 'Geçersiz yanıt';
    end if;
  end loop;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.intake_answers_guard() from public, anon, authenticated;

delete from public.intake_answers where question_key in ('child_diagnosis', 'child_medication');

create or replace function public.admin_intake(p_family uuid, p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['owner']);
begin
  if not exists (select 1 from public.families where id = p_family) then raise exception 'Aile bulunamadı'; end if;
  perform public.admin_log(me, 'intake.view', 'family', p_family::text, p_reason);
  return coalesce((
    select json_agg(json_build_object(
             'user_id', a.user_id, 'member', coalesce(nullif(p.name, ''), p.nickname, ''), 'nickname', p.nickname,
             'child_id', a.child_id, 'child', c.name,
             'question', a.question_key, 'answer', a.answer, 'version', a.version, 'consent_version', a.consent_version,
             'updated_at', a.updated_at)
           order by a.child_id nulls first, a.user_id, a.question_key)
      from public.intake_answers a
      left join public.profiles p on p.id = a.user_id
      left join public.children c on c.id = a.child_id
     where a.family_id = p_family), '[]'::json);
end $$;
revoke execute on function public.admin_intake(uuid, text) from public, anon;
grant execute on function public.admin_intake(uuid, text) to authenticated;
