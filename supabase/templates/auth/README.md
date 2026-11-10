# Supabase Auth e-posta şablonları (Türkçe, iki uygulamada ortak)

Kullanıcı isteği 10 Kasım 2026 (`CANLIYA_ALMA.md` 1.3 adım 5; ParentApp ve Klinik pencereleri hizalı). Supabase projesi tek
olduğu için bu şablonlar **Moyo (ParentApp) ve Moyo Mercek (ClinicApp) hesaplarına aynı gider**: metin nötr, gönderen "Moyo"
<noreply@moyoapp.com.tr> (Resend SMTP). Hangi uygulamanın açılacağını onay bağlantısı (`{{ .ConfirmationURL }}`) kendisi taşır
(uygulamanın verdiği dönüş adresi: `parentapp://`, `https://ebeveyn.moyoapp.com.tr`, `clinicapp://`, `https://uzman.moyoapp.com.tr`);
şablonda uygulamaya göre dal yok. Akış değişmez: Supabase'in varsayılan şablonları da aynı bağlantıyı kullanır, yalnız dil ve
görünüm değişti (davet e-postası `functions/invite-email` ile aynı düzen). Hitap "sen" (iki uygulamanın içindeki gibi).

Yapıştırma: Supabase → **Authentication → Emails → Templates** → şablonu seç → **Subject** kutusuna konu, **Message body**
kutusuna dosyanın tamamı (raw bağlantı → Ctrl+A → kopyala) → **Save changes**.

| Supabase'teki ad | Dosya | Konu (Subject) | Değişkenler |
|---|---|---|---|
| Confirm sign up | `confirm.html` | `Moyo hesabını onayla` | `.ConfirmationURL`, `.Email` |
| Invite user | `invite.html` | `Moyo’ya davet edildin` | `.ConfirmationURL`, `.Email` |
| Magic link | `magic_link.html` | `Moyo giriş bağlantın` | `.ConfirmationURL`, `.Email` |
| Change email address | `email_change.html` | `Yeni e-posta adresini onayla` | `.ConfirmationURL`, `.Email` (eski), `.NewEmail` |
| Reset password | `recovery.html` | `Moyo şifreni sıfırla` | `.ConfirmationURL`, `.Email` |
| Reauthentication | `reauthentication.html` | `Moyo doğrulama kodun` | `.Token`, `.Email` |

Kural: tek düğme + düğme açılmazsa bağlantının kendisi, kısa süre uyarısı, "sen istemediysen yok say" satırı, destek bağlantısı;
izleme pikseli ve dış görsel yok (yalnız satır içi stil). Metin değişirse bu klasör tek kaynaktır; Supabase'e yeniden yapıştırılır.
"Confirm email" açılması iki uygulamayı birden etkiler; açılış anı ParentApp + Klinik + koordinatörle birlikte (takip sayfası).
