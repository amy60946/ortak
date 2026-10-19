# Ortak durum ve karar günlüğü

Biçim: `tarih · ürün · ne değişti · etkisi / kim ne yapmalı`. En yeni kayıt en üstte.

## Açık işler

- [ ] Pofi Adası: yaş bantları iki banda indi (A 6–8 / B 9–12); oyunda C profili kaldırılmalı / `C` gelirse B sayılmalı, A/B ayarları yeni aralıklara göre gözden geçirilmeli (oyun penceresi).
- [ ] Omurga analizi Ö1–Ö7 (Güneş Taşı, XP/beceri yıldızı, bakım, hikâye, ilk gün, posta kutusu, gerçek ödül dükkânı) onaylanırsa önce burada şema/kural, sonra uygulamalar.
- [ ] Sözleşme taramasında bulunan tutarsızlıklar (ayrıntı `sozlesme/durumlar.md`, `ekonomi.md`): `assigned`/"kaçırıldı" yalnız istemcide; geçmiş tarih kuralı oyun/sunucu farklı (saat dilimi dahil); `spend_coins` `min_level` denetlemiyor, fiyat 0 kuralı farklı; sunucuda kod deneme sınırı yok; klinik önerisinde `decline_reason` RPC'den yazılamıyor, kabul edilen öneri ↔ görev bağı yok. Her biri önce burada karara bağlanacak.
- [ ] "Quests" ve "Güneş Taşı" için kalıcı Türkçe adlar.
- [ ] ClinicApp teknoloji kararı (öneri: Expo + web).

## Günlük

- 2026-10-19 · ParentApp · Uzmanım ekranları (klinik paylaşımı, öneriler, zor an) `claude/claude-durum-review-c6ss0j` dalına alındı; giriş/kayıt hata mesajları netleşti, iOS derlemesi Supabase adresini JS paketinde denetliyor. Yeni TestFlight derlemesi bekliyor. · Diğer ürünleri etkilemez.
- 2026-10-19 · tümü · **Uygulandı** (kullanıcı, SQL Editor): `20261019000000_clinic.sql`, `20261019100000_task_rewards.sql`, `20261019110000_age_bands.sql` → `migrations/`'a taşındı; sözleşmedeki "uygulanmadı" notları kaldırıldı. Canlıda: ödül 0–50, geri almada verilen coin düşülür, yaş bantları A 6–8 / B 9–12 (eski C kayıtları B oldu), klinik tabloları hazır. · **Oyun penceresi:** C bandı artık sunucudan gelmez; oyunda C profilini kaldır. **ClinicApp:** tablolar/RPC'ler kullanılabilir.
- 2026-10-19 · ParentApp + ortak · **Görev ödülü kuralları** (kullanıcı onayı): onay da ret de `review_completion` ile (ParentApp güncellendi); onay geri alınınca *verilen* coin düşülür (o anki ödül değil); görev/atama silinince kazanılmış coin kalır; ödül 0–50 (SQL kısıtı + ParentApp girişi). **Yaş bantları** (kullanıcı kararı): iki bant A 6–8 / B 9–12, C kaldırıldı; eski C kayıtları B olur. SQL önerileri `proposed/20261019100000_task_rewards.sql`, `20261019110000_age_bands.sql` + testleri; `run.sh` dört test de geçti. Sözleşme: `ekonomi.md` 2.1–2.2, `durumlar.md` D2 + 4, `veritabani.md`, `akislar.md`. · ParentApp değişikliği eski ve yeni şemayla çalışır. **Kullanıcı:** iki öneriyi SQL Editor'da çalıştırmalı. **Oyun penceresi:** C bandını kaldır / B say; sahte arka uç sınırı 1–50 zaten uyumlu. **ClinicApp:** kitle 6–12 yazımı artık doğru.
- 2026-10-19 · ortak · Depo kuruldu. Uygulanmış göçler (`init`, `task_repeat_order` ParentApp'ten; `pofi_game` oyun deposundan, 15 Ekim'de uygulandı) ve klinik önerisi (ParentApp `claude/project-thread-vwahaf` dalından, uygulanmadı) burada toplandı. Testler: `supabase/test/run.sh` (oyun + klinik, ikisi de geçti). · Uygulama depolarındaki `supabase/` klasörleri artık kaynak değil; ortak değişiklikler burada yapılır.
- 2026-10-19 · tümü · Elle App Store imzası (geçici dağıtım sertifikası + profil) kuruldu; ParentApp ve Pofi Adası TestFlight'a yüklendi.
- 2026-10-19 · tümü · İş modeli kararı: hem aile aboneliği (ParentApp) hem klinik kanalı (ClinicApp, klinisyen başına ücret). Üç ürün, tek Supabase. Raporlar iki okuyucuya (ebeveyn + uzman).
- 2026-10-16 · tümü · İki ayrı uygulama: Pofi Adası `com.gameapp.ios`, ParentApp `com.parentapp.ios`. "Fidan" adı kaldırıldı.
- 2026-10-15 · Oyun + ParentApp · Oyun sunucu eklemeleri (coin defteri, oyun eşyaları, kayıt, çocuk RPC'leri) Supabase'e uygulandı.
