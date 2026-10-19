# Ortak durum ve karar günlüğü

Biçim: `tarih · ürün · ne değişti · etkisi / kim ne yapmalı`. En yeni kayıt en üstte.

## Açık işler

- [ ] Klinik SQL'i (`supabase/proposed/20261019000000_clinic.sql`) gözden geçirilip kullanıcı onayıyla Supabase'e uygulanacak; sonra `migrations/`'a taşınacak.
- [ ] Yaş bantları: oyun kodu, SQL `suggest_age_band` ve ParentApp aynı (A 6–9 / B 10–12 / C 13–15); omurga analizi 6–8 / 9–12 öneriyor, Apple Kids bantları 6–8 / 9–11. Kullanıcıyla karar.
- [ ] Omurga analizi Ö1–Ö7 (Güneş Taşı, XP/beceri yıldızı, bakım, hikâye, ilk gün, posta kutusu, gerçek ödül dükkânı) onaylanırsa önce burada şema/kural, sonra uygulamalar.
- [ ] Sözleşme taramasında bulunan tutarsızlıklar (ayrıntı `sozlesme/durumlar.md`, `ekonomi.md`): `assigned`/"kaçırıldı" yalnız istemcide; ParentApp onay (doğrudan güncelleme) ve ret (`review_completion`) farklı yollardan; geçmiş tarih kuralı oyun/sunucu farklı (saat dilimi dahil); görev ödülüne sunucuda üst sınır yok (oyun sahte arka ucu 1–50); `spend_coins` `min_level` denetlemiyor, fiyat 0 kuralı farklı; onay geri alınınca o anki ödül düşülüyor; sunucuda kod deneme sınırı yok; Her biri önce burada karara bağlanacak.
- [ ] "Quests" ve "Güneş Taşı" için kalıcı Türkçe adlar.
- [x] ClinicApp teknolojisi: **Expo (React Native + web)**, ParentApp ile aynı (kullanıcı onayı, 19 Ekim 2026).

## Günlük

- 2026-10-19 · ortak + ClinicApp · Klinik önerisi gözden geçirildi, üç eksik kapatıldı (hâlâ **öneri**, Supabase'e uygulanmadı): `clinic_task_suggestions.task_id` (kabul edilen öneri ↔ görev; aile yalnız kendi görevini bağlar), yeni RPC `child_set_decline_reason` ("Yapamam" nedeni; `child_set_status` değişmedi), `child_done_at` artık ebeveynin doğrudan onayında dolmuyor. Testler eklendi, `run.sh` geçti. ClinicApp teknolojisi Expo olarak onaylandı; `clinic-app` deposuna iskelet kuruldu (uzman girişi/kaydı, aile paylaşım kodu, danışan listesi). · **Kullanıcı:** öneriyi Supabase SQL Editor'de çalıştıracak, sonra dosya `migrations/`'a taşınacak. **ParentApp:** kabulde öneriye `task_id` yazmalı. **Pofi Adası:** "Yapamam"dan sonra (isteğe bağlı) `child_set_decline_reason` çağırabilir; çağırmazsa bir şey bozulmaz.
- 2026-10-19 · ortak · Depo kuruldu. Uygulanmış göçler (`init`, `task_repeat_order` ParentApp'ten; `pofi_game` oyun deposundan, 15 Ekim'de uygulandı) ve klinik önerisi (ParentApp `claude/project-thread-vwahaf` dalından, uygulanmadı) burada toplandı. Testler: `supabase/test/run.sh` (oyun + klinik, ikisi de geçti). · Uygulama depolarındaki `supabase/` klasörleri artık kaynak değil; ortak değişiklikler burada yapılır.
- 2026-10-19 · tümü · Elle App Store imzası (geçici dağıtım sertifikası + profil) kuruldu; ParentApp ve Pofi Adası TestFlight'a yüklendi.
- 2026-10-19 · tümü · İş modeli kararı: hem aile aboneliği (ParentApp) hem klinik kanalı (ClinicApp, klinisyen başına ücret). Üç ürün, tek Supabase. Raporlar iki okuyucuya (ebeveyn + uzman).
- 2026-10-16 · tümü · İki ayrı uygulama: Pofi Adası `com.gameapp.ios`, ParentApp `com.parentapp.ios`. "Fidan" adı kaldırıldı.
- 2026-10-15 · Oyun + ParentApp · Oyun sunucu eklemeleri (coin defteri, oyun eşyaları, kayıt, çocuk RPC'leri) Supabase'e uygulandı.
