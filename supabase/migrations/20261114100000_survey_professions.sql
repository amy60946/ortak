-- Uzman karşılama anketi: meslek seçenekleri genişledi (kullanıcı isteği 14 Kasım 2026: Joon'un "Type of therapist" listesi
-- örnek alınıp Türkiye'ye uyarlandı; veri/uzman_anketi.json, sozlesme/akislar.md 15). Eski anahtarlar korunur, yalnız eklenir.
-- Uygulandı 14 Kasım 2026 (kullanıcı, SQL Editor). Öncesinde sunucu yeni meslekleri "Geçersiz meslek" diye reddediyordu; ClinicApp anketi kapanıyor ama
-- cevap kaydedilmediği için bir sonraki girişte yeniden soruluyordu.
-- Tekrar çalıştırılabilir (create or replace).
create or replace function public.clinician_survey_keys(p_kind text)
returns text[] language sql immutable set search_path = '' as $$
  select case p_kind
    when 'profession' then array[
      -- Ruh sağlığı
      'psikolog', 'klinik_psikolog', 'pdr', 'cocuk_terapisti', 'aile_danismani', 'sosyal_hizmet',
      -- Hekim ve hemşire
      'hekim', 'gelisimsel_pediatri', 'pediatri', 'psikiyatri_hemsiresi',
      -- Gelişim ve rehabilitasyon
      'bcba', 'davranis_teknisyeni', 'ergoterapist', 'ergoterapi_teknikeri', 'dil_konusma', 'cocuk_gelisimi',
      -- Eğitim
      'ozel_egitim', 'ogretmen', 'okul_rehber', 'okul_psikologu',
      -- Oyun ve dışavurumcu terapiler
      'oyun_terapisti', 'sanat_terapisti', 'muzik_terapisti', 'drama_terapisti',
      -- Diğer
      'koc', 'ogrenci', 'doktora_ogrencisi', 'diger']
    when 'challenges' then array['home_followthrough', 'home_data', 'unpaid_time', 'no_system', 'between_sessions', 'progress_report']
    when 'features' then array['plan_templates', 'parent_logging', 'reward_routines', 'progress_report', 'report_export', 'parent_materials']
    when 'intent' then array['trial', 'family', 'team', 'org']
  end
$$;
revoke execute on function public.clinician_survey_keys(text) from public, anon;
grant execute on function public.clinician_survey_keys(text) to authenticated;
