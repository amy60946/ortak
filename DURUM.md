# Ortak durum ve karar günlüğü

Biçim: `tarih · ürün · ne değişti · etkisi / kim ne yapmalı`. En yeni kayıt en üstte.

## Açık işler

- [ ] Sunucu kuralları önerisi (`supabase/proposed/20261019020000_server_rules.sql`) kullanıcı onayıyla Supabase'e uygulanacak. ParentApp: görev ödülü girişine 50 sınırı.
- [ ] Klinik SQL'i (`supabase/proposed/20261019000000_clinic.sql`) gözden geçirilip kullanıcı onayıyla Supabase'e uygulanacak; sonra `migrations/`'a taşınacak.
- [ ] Yaş bandı önerisi (`supabase/proposed/20261019010000_age_bands.sql`, A 6–8 / B 9–12 / C 13–15) kullanıcı onayıyla Supabase'e uygulanacak; sonra `migrations/`'a taşınacak. ParentApp `ageBands.ts` (etiket + `suggestAgeBand`) aynı anda güncellenecek.
- [ ] Omurga analizi Ö1–Ö7 (Güneş Taşı, XP/beceri yıldızı, bakım, hikâye, ilk gün, posta kutusu, gerçek ödül dükkânı) onaylanırsa önce burada şema/kural, sonra uygulamalar.
- [ ] Sözleşme taramasında bulunan tutarsızlıklar (19 Ekim: E1–E4, E6, D3, kod deneme sınırı karara bağlandı; kalanlar D1, D2, klinik K1–K2) (ayrıntı `sozlesme/durumlar.md`, `ekonomi.md`): `assigned`/"kaçırıldı" yalnız istemcide; ParentApp onay (doğrudan güncelleme) ve ret (`review_completion`) farklı yollardan; geçmiş tarih kuralı oyun/sunucu farklı (saat dilimi dahil); görev ödülüne sunucuda üst sınır yok (oyun sahte arka ucu 1–50); `spend_coins` `min_level` denetlemiyor, fiyat 0 kuralı farklı; onay geri alınınca o anki ödül düşülüyor; sunucuda kod deneme sınırı yok; klinik önerisinde `decline_reason` RPC'den yazılamıyor, kabul edilen öneri ↔ görev bağı yok. Her biri önce burada karara bağlanacak.
- [ ] ClinicApp teknoloji kararı (öneri: Expo + web).

## Günlük

- 2026-10-19 · ortak + Oyun · Oyun/sunucu farkları kapatıldı (kullanıcı onayı): ödül ≤ 50, sunucu seviye kilidi (`level_locked`, `game_levels` + kayıttaki XP), çocuk yalnız bugün/dünü işaretler, kod deneme sınırı (15 dk'da 10 → 429), onay geri alınınca verilen tutar düşer, fiyat > 0. Öneri + `test_server_rules.sql` (geçti), sözleşme güncellendi. Oyun: 429 → bekleme, adet 1–20, harcamadan önce kayıt yedeği. · ParentApp: ödül girişine 50 sınırı; hatalı kod yanıtı artık 400 gövdesi `{error}` (ParentApp redeem kullanmıyor). Kullanıcı: SQL'i uygulamak.
- 2026-10-19 · Oyun · Araştırma belgelerinin (Joon iş modeli kanvası, oyun omurgası analizi) takibi Oyun penceresine geçti: güncelleme ve Claude'a gönderilen yorumlar bu pencereyi uyandırır. Omurga belgesinin "Karar soruları"na yaş kararı işlendi. · Diğer pencereler belgeyi okuyabilir; yorum cevabı Oyun penceresinden.
- 2026-10-19 · Oyun + ortak · Yaş bandı kararı (kullanıcı): **A 6–8 / B 9–12 / C 13–15**. Bant yalnız oyun zorluğu/arayüzü; raporlar gerçek yaşı (`birthday`) kullanır. Mağaza: Kids Category dışı, 4+, Kids kurallarına gönüllü uyum; yaşı ebeveyn ParentApp'te girer. SQL önerisi + test (`test_age_bands.sql`, geçti), `sozlesme/durumlar.md` §4 güncellendi. · ParentApp penceresi: `ageBands.ts` etiketleri ve `suggestAgeBand` (< 9 → A). Kullanıcı: öneri SQL'ini Supabase'e uygulamak. Oyun: yorum/deneme metinleri güncellendi (game-app).
- 2026-10-19 · ortak · Depo kuruldu. Uygulanmış göçler (`init`, `task_repeat_order` ParentApp'ten; `pofi_game` oyun deposundan, 15 Ekim'de uygulandı) ve klinik önerisi (ParentApp `claude/project-thread-vwahaf` dalından, uygulanmadı) burada toplandı. Testler: `supabase/test/run.sh` (oyun + klinik, ikisi de geçti). · Uygulama depolarındaki `supabase/` klasörleri artık kaynak değil; ortak değişiklikler burada yapılır.
- 2026-10-19 · tümü · Elle App Store imzası (geçici dağıtım sertifikası + profil) kuruldu; ParentApp ve Pofi Adası TestFlight'a yüklendi.
- 2026-10-19 · tümü · İş modeli kararı: hem aile aboneliği (ParentApp) hem klinik kanalı (ClinicApp, klinisyen başına ücret). Üç ürün, tek Supabase. Raporlar iki okuyucuya (ebeveyn + uzman).
- 2026-10-16 · tümü · İki ayrı uygulama: Pofi Adası `com.gameapp.ios`, ParentApp `com.parentapp.ios`. "Fidan" adı kaldırıldı.
- 2026-10-15 · Oyun + ParentApp · Oyun sunucu eklemeleri (coin defteri, oyun eşyaları, kayıt, çocuk RPC'leri) Supabase'e uygulandı.
