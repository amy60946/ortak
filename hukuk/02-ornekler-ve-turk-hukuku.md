# Hukuk arşivi — 02. Örnek alınan ilkeler ve Türk hukukuna uyarlama

> 27 Ekim 2026. Benzer işi yapan küresel şirketlerin **kamuya açık yaklaşımlarından çıkarılan ilkeler**dir; hiçbir şirketin metni kopyalanmaz, çevrilmez. Joon yalnız iş modeli/rakip referansıdır (metni, içeriği alınmaz). Türk hukuku eşlemesi avukat doğrulaması bekler.

## 1. Kimden ne öğrendik (ilke düzeyinde)

| Alan | Örnek alınanlar | Çıkarılan ilke → bizde karşılığı |
|---|---|---|
| Çocuklara yönelik eğitim/aile uygulamaları | ClassDojo, Khan Academy Kids, Duolingo ABC, Toca Boca, PBS Kids | **Katmanlı bildirim:** önce bir sayfalık sade özet ("ne topluyoruz, neden, kim görür, ne yapmıyoruz"), sonra tam metin. **Reklam yok, veri satışı yok, davranışsal izleme yok** açıkça yazılır. Çocuğa kendi dilinde kısa bilgi ("Bu oyunda sadece ailen seninle konuşabilir"). Çocuk hesabını ebeveyn yönetir; çocuktan doğrudan iletişim bilgisi alınmaz. Hareketsiz hesap verisi belirli süre sonra silinir. → Gizlilik Politikası katmanlı; GameApp çocuk notu; ebeveyn denetimi; saklama-imha politikası. |
| Aile görev/ödül ve harçlık uygulamaları | Greenlight, BusyKid, Habitica, Brili | **Sanal ödül para değildir**; ebeveynin verdiği gerçek ödüller ebeveyn ile çocuk arasındadır; platform tarafı değildir. Ebeveyn, çocuğun hesabından sorumludur. → Kullanım Koşulları "Coin ve Güneş Taşı" maddesi; ödül sorumluluğu ebeveynde. |
| Abonelikli mobil uygulamalar | Headspace, Calm, Duolingo | Abonelik ekranında **fiyat, dönem, otomatik yenileme, iptal yolu** açıkça; iptal mağaza ayarlarından; deneme bitiminden önce bilgilendirme. Apple 3.1.2 kuralları. → Abonelik maddeleri + uygulama içi abonelik ekranı metni. |
| Klinisyen/terapi uygulama yazılımları | SimplePractice, Jane App, TherapyNotes, Owl Practice | Klinisyen ile platform arasında **veri işleme sözleşmesi** (ABD'de BAA): klinisyen danışanından rıza almakla yükümlü, platform veri işleyen; **alt işleyenler listesi**; ihlal bildirimi süresi; sözleşme bitince **verinin dışa aktarılması ve silinmesi** süresi; destek erişimi kayıtlı ve sınırlı. → Uzman Hizmet Sözleşmesi + Veri İşleme Eki + alt işleyenler + ihlal prosedürü. |
| Teleterapi platformları | Talkspace, BetterHelp | **Acil durum uyarısı** (platform kriz hizmeti değil); platformun sağlık hizmeti vermediği, klinisyenin kendi mesleki sorumluluğu. → "Acil durumda 112" notu; sorumluluk sınırı (TBK 115 sınırıyla). |
| Kurumsal SaaS | Slack, Notion, Atlassian | **Güven merkezi:** alt işleyen listesi, güvenlik özeti, sürüm geçmişi; sözleşme değişikliğinde önceden bildirim ve yeniden onay. → `legal_documents` sürümleri, yeniden onay akışı, panelde sürüm yönetimi. |
| Aynı iş modelindeki rakip (ebeveyn + çocuk + klinisyen) | Joon (Privacy Policy 06/2025, Terms 01/2026 — kullanıcı sohbete yapıştırdı, 27 Ekim 2026) | Ayrıntı `03-joon-karsilastirma.md`. Alınan: her anket sorusunda "cevap vermek istemiyorum", çocukta veri toplayan her özelliğe ayrı veli onayı + ince ayar + geri alma, çocuk sesinin saklanmaması, uygunsuz içerik bildirme, "lisanslı sağlık hizmeti değiliz" uyarısının en başta olması. Alınmayan (Türk hukukunda geçersiz/riskli): siteyi ziyareti piksel onayı saymak, toplu rıza, kullanmaya devamı kabul saymak, bildirimsiz fesih ve fiyat değişikliği, 500 $ sorumluluk sınırı, geniş tazmin, yabancı mahkeme ve 1 yıllık dava süresi. |
| Uygulama mağazası kuralları | Apple App Review 5.1.1, 5.1.2, 3.1.2, 2.3.8; Google Play Aileler | Uygulama içinden **hesap silme**; erişilebilir gizlilik politikası bağlantısı (uygulamada + mağazada); izinler için amaç metni; abonelik açıklamaları; çocuklara reklam/izleme yok. → Ayarlar › Yasal metinler; herkese açık metin adresi (`legal` sunucu işlevi). |

## 2. Türk hukuku eşlemesi (avukat doğrulayacak)

| Konu | Kaynak | Bizde |
|---|---|---|
| Aydınlatma (kim, ne, neden, kime aktarılır, yöntem, hukuki sebep, haklar) | KVKK md. 10; Aydınlatma Yükümlülüğü Tebliği | Ebeveyn, uzman, çocuk/veli aydınlatma metinleri; rıza ekranından **önce** ve ayrı gösterilir |
| İşleme şartları | KVKK md. 5 (sözleşmenin ifası, kanuni yükümlülük, meşru menfaat, açık rıza) | Her işleme için dayanak tablosu (aydınlatmalarda) |
| Özel nitelikli veri (sağlık) | KVKK md. 6 (7499 s. Kanun ile 2024 değişikliği) | Tanı/ilaç yanıtları, davranış kayıtları, uzman notları: açık rıza; ayrı ekran, isteğe bağlı, geri alınabilir |
| Açık rıza nitelikleri | KVKK md. 3 (belirli konu, bilgilendirme, özgür irade); Kurul kararları: hizmet şartına bağlanamaz | Rıza kutuları ayrı, önceden işaretli değil, reddedince temel hizmet sürer |
| Yurt dışına aktarım | KVKK md. 9 (2024): yeterlilik kararı / uygun güvence (standart sözleşme, aktarım sonrası **5 iş günü içinde Kurul'a bildirim**) / arızi hâllerde açık rıza | Alt işleyenlerle standart sözleşme; aydınlatmada yurt dışı aktarım bilgisi |
| Veri güvenliği | KVKK md. 12; Kurul'un teknik ve idari tedbirler rehberi; ihlalde **72 saat** içinde Kurul'a, makul sürede ilgiliye bildirim | Veri ihlali prosedürü; panelde iki adımlı giriş, denetim kaydı |
| İlgili kişi hakları ve başvuru | KVKK md. 11, 13; Veri Sorumlusuna Başvuru Usul ve Esasları Tebliği (yazılı / KEP / kayıtlı e-posta / uygulama içi; **30 gün** içinde ücretsiz yanıt) | KVKK başvuru kaydı (`kvkk_requests`), panelde 30 gün sayacı |
| Silme, yok etme, anonimleştirme | KVKK md. 7; Kişisel Verilerin Silinmesi… Yönetmeliği (periyodik imha en geç 6 ay) | Saklama ve imha politikası; zamanlanmış imha işi (yapılacak) |
| VERBİS | KVKK md. 16; Kurul istisna kararları (çalışan < 50 ve yıllık bilanço < 100 M TL istisnası, **ana faaliyeti özel nitelikli veri işleme olanlar hariç**) | Avukat: sağlık verisi işlemenin ana faaliyet sayılıp sayılmadığı |
| Çocuk | TMK velayet hükümleri (md. 335 vd.); ayırt etme gücü olan küçüğün kişiliğe sıkı bağlı hakları | Çocuk verisi veli adına/velinin onayıyla; çocuğa yaşına uygun kısa bilgi |
| Tüketici, haksız şart | 6502 TKHK md. 5 (haksız şart), Abonelik Sözleşmeleri Yönetmeliği | Abonelik: iptal her zaman (mağaza ayarı), açık fiyat/dönem; sorumsuzluk kayıtları ölçülü |
| Mesafeli satış, cayma | Mesafeli Sözleşmeler Yönetmeliği md. 15/1-ğ (anında ifa edilen dijital içerikte cayma istisnası, tüketici onayıyla) | Satış Apple üzerinden; iade Apple politikasıyla; Kullanım Koşulları'nda bilgilendirme |
| Ticari ileti | 6563 s. Kanun, Ticari İletişim ve Ticari İletiler Yönetmeliği, İYS | Hizmet e-postaları (doğrulama, davet, şifre) ticari ileti değil; pazarlama ayrı onay + İYS (şimdilik pazarlama yok) |
| Sorumluluk sınırı | TBK md. 115 (ağır kusur/kast sorumsuzluğu geçersiz) | Sorumluluk maddeleri "paylaştırır ve belgeler", tümüyle sorumsuz kılmaz |
| İnternet ortamında yer sağlama | 5651 s. Kanun (yer sağlayıcı yükümlülükleri) | Avukat: aile içi mesajlaşma için kapsam |
| Uzaktan sağlık hizmetleri | Uzaktan Sağlık Hizmetlerinin Sunumu Hakkında Yönetmelik (2022) | Platform sağlık hizmeti sunmaz; uzman–aile görüntülü görüşme yok; avukat teyit edecek |
| Meslek etiği | Türk Psikologlar Derneği Etik Yönetmeliği, ilgili meslek örgütleri | Uzman, danışan (veli) onayı ve gizlilik yükümlülüğünden kendisi sorumlu |

## 3. Uyarlama kararları (öneri)

1. **Katmanlı metin:** her belge "Kısaca" özetiyle başlar, tam metin altta.
2. **Açık rıza ayrı:** Kullanım Koşulları onayının içine rıza gömülmez; sağlık yanıtları, uzmanla paylaşım, önceki uzman kayıtları ayrı ekranlarda, ayrı sürümle.
3. **Sürüm ve yeniden onay:** her metin `anahtar + sürüm`; esaslı değişiklikte uygulama açılışında yeniden onay istenir, küçük değişiklik bildirimle.
4. **Herkese açık adres:** alan adı alınana dek metinler sunucu işlevinden (`legal`) yayımlanır; mağaza bağlantıları buraya.
5. **Reklam yok / satış yok / izleme yok** cümlesi her aydınlatmanın özetinde.
6. **Acil durum:** ParentApp ve ClinicApp'te "Acil durumlarda 112'yi arayın; uygulama acil yardım hizmeti değildir."
7. **Sanal değerler:** coin ve Güneş Taşı'nın para değeri olmadığı her iki uygulamanın koşullarında.
