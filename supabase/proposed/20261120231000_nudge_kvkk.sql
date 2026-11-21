-- Otomatik hatırlatma kaydı (nudge_log) için KVKK: dökümde yer alır, 12 ay sonra silinir (koordinatör, 20 Kasım 2026).
-- Önkoşul: proposed/20261120200000_family_keeps_records.sql (data_export_of'un son hâli) ve 20261120230000_nudge_engine.sql.
-- Saklama: bildirimlerle aynı (hukuk/42 satır 19a; app_config.retention.nudge_log_days, varsayılan 365, en az 30).
-- Gece imha işi (retention_run) canlıya alınana kadar ("live" kapalı) bu adım da yalnız sayar, silmez.
-- Tekrar çalıştırılabilir.

-- Sıra denetimi: önkoşul dosyalar çalışmadıysa hiçbir şey yazmadan anlaşılır bir hatayla durur (KVKK dökümü bozulmasın).
do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'parent_trainings' and column_name = 'family_id') then
    raise exception 'Önce 20261120200000_family_keeps_records.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
  if to_regclass('public.nudge_log') is null then
    raise exception 'Önce 20261120230000_nudge_engine.sql çalıştırılmalı (sonra bu dosyayı yeniden çalıştırın)';
  end if;
end $$;

-- 1. Silme adımı (retention_run'ın kurallarıyla: live değilse yalnız sayar)
create or replace function public.nudge_log_prune()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  cfg jsonb := coalesce((select value from public.app_config where key = 'retention'), '{}'::jsonb);
  live boolean := coalesce((cfg ->> 'live')::boolean, false);
  d integer := greatest(30, coalesce(nullif(cfg ->> 'nudge_log_days', '')::integer, 365));
  n bigint;
begin
  if live then
    delete from public.nudge_log where at < now() - make_interval(days => d);
    get diagnostics n = row_count;
  else
    select count(*) into n from public.nudge_log where at < now() - make_interval(days => d);
  end if;
  return jsonb_build_object('live', live, 'days', d, 'rows', n);
end $$;
revoke execute on function public.nudge_log_prune() from public, anon, authenticated;

-- 2. Zamanlama: pg_cron varsa her gece 03:41 (Türkiye 06:41 değil; cron UTC). Yoksa nudge_run ile aynı dış zamanlayıcı.
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('nudge-log-prune', '41 3 * * *', $c$select public.nudge_log_prune()$c$);
  else
    raise notice 'pg_cron yok: nudge_log_prune zamanlanmadı';
  end if;
exception when others then
  raise notice 'nudge_log_prune zamanlanamadı: %', sqlerrm;
end $$;

-- 3. KVKK dökümü: "hatirlatmalar" bölümü (kural anahtarı, sonuç, zaman, açılma, hedefe geçiş; metin "bildirimler"de)
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

  -- Herkes: bildirimler, otomatik hatırlatma kaydı, yasal onaylar, KVKK başvuruları, kullanım özeti, cihazlar, ekip işlemleri
  out := out || jsonb_build_object(
    'bildirimler', coalesce((select jsonb_agg(jsonb_build_object('uygulama', n.app, 'tur', n.kind, 'baslik', n.title, 'metin', n.body,
                                                                 'zaman', n.created_at, 'okunma', n.read_at) order by n.created_at)
                               from public.notifications n where n.user_id = p_user), '[]'),
    'hatirlatmalar', coalesce((select jsonb_agg(jsonb_build_object('uygulama', l.product, 'kural', l.rule_key, 'sonuc', l.result,
                                                                  'zaman', l.at, 'acilma', l.opened_at, 'hedefe_gecis', l.converted_at) order by l.at)
                                 from public.nudge_log l where l.user_id = p_user), '[]'),
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
