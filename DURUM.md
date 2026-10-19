# Ortak durum ve karar günlüğü

Biçim: `tarih · ürün · ne değişti · etkisi / kim ne yapmalı`. En yeni kayıt en üstte.

## Açık işler

- [ ] Klinik SQL'i (`supabase/proposed/20261019000000_clinic.sql`) gözden geçirilip kullanıcı onayıyla Supabase'e uygulanacak; sonra `migrations/`'a taşınacak.
- [ ] Yaş bantları tutarsız: oyun kodu A 6–9 / B 10–12 (+ C 13–15), omurga analizi 6–8 / 9–12 öneriyor. Kullanıcıyla karar.
- [ ] Omurga analizi Ö1–Ö7 (Güneş Taşı, XP/beceri yıldızı, bakım, hikâye, ilk gün, posta kutusu, gerçek ödül dükkânı) onaylanırsa önce burada şema/kural, sonra uygulamalar.
- [ ] "Quests" ve "Güneş Taşı" için kalıcı Türkçe adlar.
- [ ] ClinicApp teknoloji kararı (öneri: Expo + web). Not: clinic-app `claude/project-thread-vwahaf` dalında onaysız kurulmuş bir Expo uzman paneli var; karar verilince alınır ya da bırakılır.
- [ ] `CLAUDE.md`'nin andığı `sozlesme/` dosyaları (veritabani, durumlar, ekonomi, akislar) henüz yok; yazılacak.

## Günlük

- 2026-10-19 · ClinicApp · Klinik penceresi kuruldu: `claude/clinic-window-setup-ye8vh5` dalına (clinic-app ve ortak) çalışma notları ve ortak kaynak alındı. Şema ya da kural değişmedi. · Diğer ürünleri etkilemez. `main` dalları hâlâ boş; kullanıcı onayıyla birleştirilmeli.
- 2026-10-19 · ortak · Depo kuruldu. Uygulanmış göçler (`init`, `task_repeat_order` ParentApp'ten; `pofi_game` oyun deposundan, 15 Ekim'de uygulandı) ve klinik önerisi (ParentApp `claude/project-thread-vwahaf` dalından, uygulanmadı) burada toplandı. Testler: `supabase/test/run.sh` (oyun + klinik, ikisi de geçti). · Uygulama depolarındaki `supabase/` klasörleri artık kaynak değil; ortak değişiklikler burada yapılır.
- 2026-10-19 · tümü · Elle App Store imzası (geçici dağıtım sertifikası + profil) kuruldu; ParentApp TestFlight'a yüklendi. Oyun yüklemesi sürüyor.
- 2026-10-19 · tümü · İş modeli kararı: hem aile aboneliği (ParentApp) hem klinik kanalı (ClinicApp, klinisyen başına ücret). Üç ürün, tek Supabase. Raporlar iki okuyucuya (ebeveyn + uzman).
- 2026-10-16 · tümü · İki ayrı uygulama: Pofi Adası `com.gameapp.ios`, ParentApp `com.parentapp.ios`. "Fidan" adı kaldırıldı.
- 2026-10-15 · Oyun + ParentApp · Oyun sunucu eklemeleri (coin defteri, oyun eşyaları, kayıt, çocuk RPC'leri) Supabase'e uygulandı.
