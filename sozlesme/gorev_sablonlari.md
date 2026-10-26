# Ev Görevleri şablon kataloğu (23 Ekim 2026)

**298 şablon**, 6 kategori × 4 yaş grubu. Kullanıcının referans kayıtlarından derlendi: görev adları Türkçe yazıldı, kopyalar birleştirildi, Türkiye'ye uyarlandı. Veri: [`veri/gorev_sablonlari.json`](../veri/gorev_sablonlari.json) (sürüm 2); sunucu tablosu: `supabase/migrations/20261023010000_task_templates.sql` (uygulandı 23 Ekim 2026). Sürüm 2 temizliği (anahtarlar `gs_<kategori>_<sıra>`, başka uygulamanın adları ve alanları yok): `supabase/migrations/20261023030000_task_templates_clean.sql` (uygulandı 23 Ekim 2026).

## Kurallar

- **Ana kategori = beceri** (`ekonomi.md` 5B): Ev İşleri → Takım Çalışması, Ruh Sağlığı → Dayanıklılık, Öğrenme ve Eğitim → Bilgi, Sağlık ve Spor → Güç, Odak ve Öz Denetim → Odak, İlişki Kurma → Nezaket.
- **Süzgeç etiketleri (`categories`)**: ana kategori + görevin uygun düştüğü diğer kategoriler. Ruh Sağlığı yalnız ana kategori olarak kullanılır (süzgeç işe yarasın diye).
- **Yaş grubu (`ages`)**: oyunla aynı K (5 ve altı), A (6–8), B (9–12), C (13 ve üstü). Önerilen gruplar güvenlik ve gelişime göre seçildi (ör. bulaşık yıkama B–C, destek tekerli bisiklet K–A).
- **Zorluk ve coin**: Kolay / Orta / Zor; varsayılan coin 5 / 10 / 20. Ebeveyn değiştirebilir.
- **Anahtar (`key`)**: `gs_<kategori>_<sıra>` (ör. `gs_home_001`); uygulamalar şablonu bu anahtarla tanır (`saved_templates.template_key`, öneride `template_key`). Ekranda gösterilmez.
- **ParentApp**: görev oluştururken "Şablondan başla" ekranında Kategori + Yaş grubu süzgeci (birden çok seçim), arama ve çoklu seçim. Seçilen şablon görevi `title`, `emoji`, `skill` (= beceri anahtarı), `difficulty`, `coins` ile doldurur; ayrı beceri seçimi yok. Varsayılan yaş grubu çocuğun yaş grubudur.
- **ClinicApp**: önerilerde aynı katalog (`template_key` = `key`).

## Dağılım

| Kategori (beceri) | Şablon |
|---|---|
| Ev İşleri (Takım Çalışması) | 65 |
| Ruh Sağlığı (Dayanıklılık) | 29 |
| Öğrenme ve Eğitim (Bilgi) | 42 |
| Sağlık ve Spor (Güç) | 48 |
| Odak ve Öz Denetim (Odak) | 62 |
| İlişki Kurma (Nezaket) | 52 |

| Yaş grubu | Şablon |
|---|---|
| K · 5 ve altı | 181 |
| A · 6–8 | 266 |
| B · 9–12 | 274 |
| C · 13 ve üstü | 252 |

## Ev İşleri → Takım Çalışması

| Anahtar | Görev | Yaş | Zorluk | Diğer süzgeçler |
|---|---|---|---|---|
| `gs_home_001` | 🍽️ Akşam yemeğinden sonra toplamaya yardım et | KABC | Orta | — |
| `gs_home_002` | 🍲 Akşam yemeğini hazırlamaya yardım et | KABC | Kolay | — |
| `gs_home_003` | 🙋 Anne ya da babana bugün neye yardım edebileceğini sor | KABC | Kolay | — |
| `gs_home_004` | 🙋 Annen ya da baban isteyince yardım et | KABC | Orta | — |
| `gs_home_005` | 🍁 Annen ya da babanla bahçedeki yaprakları topla | KA | Kolay | — |
| `gs_home_006` | 🚗 Araba yıkamaya yardım et | KAB | Kolay | — |
| `gs_home_007` | 🚗 Arabayı yıka | BC | Kolay | — |
| `gs_home_008` | 👟 Ayakkabılarını yerine koy | KABC | Kolay | — |
| `gs_home_009` | 🌳 Bahçe işlerine yardım et | BC | Kolay | — |
| `gs_home_010` | 🌱 Bahçede yardım et | KAB | Orta | — |
| `gs_home_011` | 🍂 Bahçedeki yaprakları tırmıkla | BC | Orta | — |
| `gs_home_012` | 🗑️ Banyo çöp kutusunu boşalt | ABC | Kolay | — |
| `gs_home_013` | 🧻 Banyodaki havluları as | KABC | Kolay | — |
| `gs_home_014` | 🛁 Banyoyu temizle | ABC | Zor | — |
| `gs_home_015` | 🥘 Basit bir yemeği hazırlamaya yardım et | KABC | Kolay | İlişki Kurma |
| `gs_home_016` | ✋ Başkası konuşurken sözünü kesmeden bekle | KABC | Kolay | — |
| `gs_home_017` | 🍽️ Bulaşık makinesini boşalt | ABC | Orta | — |
| `gs_home_018` | 🍽️ Bulaşık makinesini doldur | ABC | Kolay | — |
| `gs_home_019` | 🧽 Bulaşıkları yıka | BC | Kolay | — |
| `gs_home_020` | 👂 Büyüklerinin söylediğini tartışmadan yap | KABC | Kolay | — |
| `gs_home_021` | 🪟 Camları sil | ABC | Kolay | — |
| `gs_home_022` | 🧹 Elektrik süpürgesi çekmeye yardım et | ABC | Zor | — |
| `gs_home_023` | 🙌 Ev işlerine yardım etmeyi teklif et | KABC | Kolay | İlişki Kurma |
| `gs_home_024` | 🐾 Evcil hayvanına mama ve su ver | KABC | Kolay | — |
| `gs_home_025` | 🔨 Evdeki küçük tamirlere yardım et | ABC | Kolay | — |
| `gs_home_026` | 🚙 Eve gelince arabadan eşyaları taşı | ABC | Orta | — |
| `gs_home_027` | 🏠 Evin genel düzenine yardım et | KABC | Orta | — |
| `gs_home_028` | 🧰 Garajı ya da depoyu temizlemeye yardım et | ABC | Kolay | — |
| `gs_home_029` | ♻️ Geri dönüşüm kutusunu çıkar | ABC | Orta | — |
| `gs_home_030` | ♻️ Geri dönüşüm ve çöpü ayır | KABC | Kolay | — |
| `gs_home_031` | 🛍️ Hafif market poşetlerini taşımaya yardım et | KABC | Kolay | — |
| `gs_home_032` | 🧽 Haftalık ev temizliğine yardım et | KABC | Zor | — |
| `gs_home_033` | 🥣 Her yemekten sonra tabağını lavaboya bırak | KABC | Kolay | — |
| `gs_home_034` | 🫖 Kahvaltı için çay hazırlığına yardım et | BC | Orta | — |
| `gs_home_035` | 🍳 Kahvaltıdan sonra toplamaya yardım et | KABC | Orta | — |
| `gs_home_036` | 📖 Kardeşine ödevinde yardım et | BC | Kolay | Öğrenme ve Eğitim |
| `gs_home_037` | 🤳 Kendinin komik bir fotoğrafını çek | ABC | Kolay | — |
| `gs_home_038` | 🤫 Kimseyi şikâyet etmeden kendi işine odaklan | ABC | Kolay | — |
| `gs_home_039` | 🧺 Kirli kıyafetlerini sepete at | KABC | Kolay | — |
| `gs_home_040` | 🛒 Market alışverişine yardım et | KABC | Kolay | — |
| `gs_home_041` | 🧃 Market alışverişini yerleştirmeye yardım et | KABC | Kolay | — |
| `gs_home_042` | 🪶 Mobilyaların tozunu almaya yardım et | KABC | Kolay | — |
| `gs_home_043` | 🍴 Mutfak masasını kur | KABC | Kolay | — |
| `gs_home_044` | 🧽 Mutfak masasını sil | KABC | Kolay | — |
| `gs_home_045` | 🧹 Odanı topla (oyuncak, kıyafet, yatak) | ABC | Zor | — |
| `gs_home_046` | 🧸 Oyuncaklarını düzenle | KAB | Zor | — |
| `gs_home_047` | 🧸 Oyundan sonra ortalığı topla | KAB | Kolay | Odak ve Öz Denetim |
| `gs_home_048` | 🧽 Plastik bulaşıkları yıka (bir büyüğünle) | KA | Kolay | — |
| `gs_home_049` | 📬 Posta kutusundaki mektupları getir | ABC | Kolay | — |
| `gs_home_050` | 🍴 Sofrayı kurmaya yardım et | KABC | Kolay | — |
| `gs_home_051` | 🍽️ Sofrayı toplamaya yardım et | KABC | Kolay | — |
| `gs_home_052` | ⭐ Söylenmeden annene ya da babana yardım et | ABC | Kolay | — |
| `gs_home_053` | 🧸 Söylenmeden oyuncaklarını topla | KAB | Kolay | Odak ve Öz Denetim |
| `gs_home_054` | 🍽️ Temiz tabakları yerleştir (kesici aletler hariç!) | KABC | Kolay | — |
| `gs_home_055` | 👕 Temiz çamaşırları yerleştir | ABC | Kolay | — |
| `gs_home_056` | 🧻 Tuvalet kâğıdını değiştir | KABC | Kolay | — |
| `gs_home_057` | 🛏️ Yatak çarşafını değiştir | BC | Kolay | — |
| `gs_home_058` | 🧸 Yatmadan önce oyuncaklarını topla | KAB | Orta | — |
| `gs_home_059` | ✋ Yeni bir selamlaşma uydur | KABC | Kolay | — |
| `gs_home_060` | 🧹 Yerleri süpür | ABC | Orta | — |
| `gs_home_061` | 🧺 Çamaşır makinesini çalıştırmaya yardım et | ABC | Kolay | — |
| `gs_home_062` | 👕 Çamaşırları ayırmaya yardım et | KABC | Kolay | — |
| `gs_home_063` | 🪴 Çiçekleri sula | KABC | Kolay | — |
| `gs_home_064` | 🗑️ Çöpü çıkar | BC | Orta | — |
| `gs_home_065` | 🗑️ Çöpü çıkarmaya yardım et | KA | Kolay | — |

## Ruh Sağlığı → Dayanıklılık

| Anahtar | Görev | Yaş | Zorluk | Diğer süzgeçler |
|---|---|---|---|---|
| `gs_mind_001` | 🌬️ 1 dakika derin nefes egzersizi yap | KABC | Zor | — |
| `gs_mind_002` | 🧘 10 dakika meditasyon yap | KABC | Kolay | — |
| `gs_mind_003` | 🧘 15 dakika meditasyon yap | ABC | Kolay | — |
| `gs_mind_004` | 🕺 2 dakika dans et | KABC | Kolay | — |
| `gs_mind_005` | 🌬️ 5 kez derin nefes al | KABC | Kolay | — |
| `gs_mind_006` | 📝 Ailene bir not yaz | KABC | Kolay | — |
| `gs_mind_007` | 💌 Ailene nasıl hissettiğini anlatan bir not yaz | BC | Kolay | — |
| `gs_mind_008` | 🍂 Bir büyüğünle doğa yürüyüşünde yaprak ya da taş topla | KA | Kolay | — |
| `gs_mind_009` | 🌈 Bir duygu çizelgesi yap ve bugün doldur | ABC | Kolay | — |
| `gs_mind_010` | 🖍️ Bir resim çiz ve annene ya da babana göster | KAB | Kolay | — |
| `gs_mind_011` | 🙏 Bu hafta minnet duyduğun şeyleri yaz | BC | Orta | — |
| `gs_mind_012` | 😊 Bugün olumlu ol | KABC | Orta | — |
| `gs_mind_013` | ✨ Bugünün 3 güzel şeyini yaz | KABC | Kolay | Odak ve Öz Denetim |
| `gs_mind_014` | ⏸️ Cevap vermeden önce sakinleşmek için 5–10 dakika ara ver | ABC | Kolay | — |
| `gs_mind_015` | 💭 Duygularını annen ya da babanla konuş | KABC | Kolay | — |
| `gs_mind_016` | 🫂 En çok neden korktuğunu yaz | ABC | Kolay | — |
| `gs_mind_017` | 🗺️ Evinin haritasını çiz ve ailene göster | KA | Kolay | — |
| `gs_mind_018` | 📓 Günlük tutmaya başla | ABC | Orta | — |
| `gs_mind_019` | 📓 Gününü günlüğüne yaz | BC | Orta | — |
| `gs_mind_020` | 🎨 Havalı bir şey boya! | KABC | Kolay | — |
| `gs_mind_021` | 💡 Kendine yapacak bir iş bul ve bitir | KABC | Kolay | Ev İşleri, İlişki Kurma |
| `gs_mind_022` | 📔 Minnet defteri tutmaya başla | ABC | Kolay | — |
| `gs_mind_023` | 📔 Minnet defterine yeni bir şey yaz | ABC | Kolay | — |
| `gs_mind_024` | 🎶 Odanda dans partisi yap | KAB | Kolay | — |
| `gs_mind_025` | 🌅 Sabah 5–10 dakika esne | KABC | Kolay | — |
| `gs_mind_026` | 😊 Seni mutlu eden şeyleri yaz | ABC | Zor | — |
| `gs_mind_027` | 🖍️ Tebeşirle kaldırımı süsle | KA | Kolay | — |
| `gs_mind_028` | 💃 Yeni bir dans hareketi uydur | KABC | Kolay | — |
| `gs_mind_029` | 🌬️ Üzüldüğünde 5 kez derin nefes al | KABC | Kolay | — |

## Öğrenme ve Eğitim → Bilgi

| Anahtar | Görev | Yaş | Zorluk | Diğer süzgeçler |
|---|---|---|---|---|
| `gs_learn_001` | 🔤 'B' harfiyle başlayan 5 şey bul | KA | Kolay | — |
| `gs_learn_002` | 📖 10 dakika kitap oku | KABC | Kolay | — |
| `gs_learn_003` | 🧩 100 parçalı yapboz yap | AB | Kolay | — |
| `gs_learn_004` | 🎹 15 dakika enstrüman çal | KABC | Kolay | — |
| `gs_learn_005` | 📖 15 dakika kendi başına kitap oku | ABC | Kolay | — |
| `gs_learn_006` | 📖 20 dakika kitap oku | ABC | Kolay | — |
| `gs_learn_007` | 📖 Ailene bugünle ilgili bir hikâye anlat | KABC | Kolay | — |
| `gs_learn_008` | 😂 Akşam yemeği için bir fıkra yaz | ABC | Kolay | — |
| `gs_learn_009` | 🔠 Alfabeyi söylemeyi çalış | KA | Kolay | — |
| `gs_learn_010` | ✍️ Alfabeyi yazmayı çalış | KA | Kolay | — |
| `gs_learn_011` | 📚 Bir kitabı baştan sona oku | ABC | Kolay | — |
| `gs_learn_012` | ➗ Bir matematik çalışma sayfası çöz | ABC | Orta | — |
| `gs_learn_013` | ✏️ Bir ödevini yap | ABC | Zor | — |
| `gs_learn_014` | 🧑‍🏫 Birine yeni bir şey öğret | ABC | Kolay | — |
| `gs_learn_015` | 🚲 Bisiklet sürmeyi öğren (kask ve destek tekerleriyle) | KA | Kolay | — |
| `gs_learn_016` | 🌿 Bitkileri tanımayı öğren | BC | Kolay | — |
| `gs_learn_017` | 📚 Bütün ödevlerini bitir | ABC | Zor | — |
| `gs_learn_018` | 📱 Dijital haritayla yol bulmayı öğren | BC | Kolay | — |
| `gs_learn_019` | 🏡 Ev adresini ezberle | KAB | Kolay | — |
| `gs_learn_020` | 🪢 Farklı düğümler atmayı öğren | ABC | Kolay | — |
| `gs_learn_021` | 📚 Gelecek haftanın ödevine başla | BC | Orta | — |
| `gs_learn_022` | 📝 Gününü çiz ya da yaz | KABC | Kolay | — |
| `gs_learn_023` | 🩹 Kesik ya da yarayı temizlemeyi öğren | ABC | Kolay | — |
| `gs_learn_024` | 👔 Kravat bağlamayı öğren | BC | Kolay | — |
| `gs_learn_025` | 🖼️ Küçük bir resim sergisi hazırla | KABC | Kolay | — |
| `gs_learn_026` | 🏫 Okula git | KABC | Kolay | — |
| `gs_learn_027` | ♟️ Satranç öğren | ABC | Orta | — |
| `gs_learn_028` | 🔢 Sayıları yazmayı çalış | KA | Kolay | — |
| `gs_learn_029` | ⛑️ Temel ilk yardımı öğren | ABC | Kolay | — |
| `gs_learn_030` | 📖 Yaklaşan bir sınava ya da yazılıya hazırlan | ABC | Zor | — |
| `gs_learn_031` | 📋 Yapman gereken ödevleri bir listeye yaz | ABC | Kolay | — |
| `gs_learn_032` | 🦉 Yatmadan önce ailene 3 ilginç bilgi anlat | KABC | Orta | — |
| `gs_learn_033` | 📖 Yatmadan önce kitap oku | KABC | Orta | — |
| `gs_learn_034` | 🥄 Yemek yaparken malzemeleri ölçmeye yardım et | KAB | Orta | — |
| `gs_learn_035` | 🌍 Yeni bir dil öğrenmeye başla | ABC | Kolay | — |
| `gs_learn_036` | 🎸 Yeni bir enstrümana başla | ABC | Zor | — |
| `gs_learn_037` | 🎲 Yeni bir oyun öğren | KABC | Kolay | — |
| `gs_learn_038` | 🥪 Yeni bir sandviç tarifi uydur | ABC | Kolay | — |
| `gs_learn_039` | ⚠️ Zehirli bitki ve hayvanları tanımayı öğren | ABC | Kolay | — |
| `gs_learn_040` | ✖️ Çarpım tablosunu tekrar et | AB | Kolay | — |
| `gs_learn_041` | ⏰ Ödevini saat 17.00'den önce bitir | ABC | Zor | — |
| `gs_learn_042` | 💡 Öğrendiğin bir şeyi paylaş | KABC | Kolay | — |

## Sağlık ve Spor → Güç

| Anahtar | Görev | Yaş | Zorluk | Diğer süzgeçler |
|---|---|---|---|---|
| `gs_health_001` | 🙆 1 dakika esneme yap | KA | Kolay | — |
| `gs_health_002` | 🏃 1 dakika yerinde koş | KABC | Kolay | — |
| `gs_health_003` | 🏋️ 10 burpee yap | BC | Kolay | — |
| `gs_health_004` | 🧘 10 dakika esneme yap | ABC | Kolay | — |
| `gs_health_005` | 🤸 10 zıplama hareketi (jumping jack) yap | KABC | Kolay | — |
| `gs_health_006` | 🏃 20 mekik çek | BC | Kolay | — |
| `gs_health_007` | 💪 20 şınav çek | BC | Kolay | — |
| `gs_health_008` | 🏃 3 km koş (süreni tut!) | BC | Kolay | — |
| `gs_health_009` | 💪 3 şınav çek | KA | Kolay | — |
| `gs_health_010` | 🏅 30 dakika spor yap | BC | Kolay | — |
| `gs_health_011` | 🏀 30 dakika spor çalış | BC | Zor | — |
| `gs_health_012` | 🥕 5 farklı meyve ve sebze ye | KABC | Zor | — |
| `gs_health_013` | 🏃 5 mekik çek | KABC | Kolay | — |
| `gs_health_014` | 💪 5 şınav çek | ABC | Kolay | — |
| `gs_health_015` | 🥾 Annen ya da babanla doğa yürüyüşüne çık | ABC | Orta | — |
| `gs_health_016` | 🏃 Annen ya da babanla koşuya çık | ABC | Orta | — |
| `gs_health_017` | 🐕 Annen ya da babanla köpeği yürüyüşe çıkar | KA | Kolay | — |
| `gs_health_018` | ⚾ Annen ya da babanla top yakalama oyna | KABC | Kolay | — |
| `gs_health_019` | 🛁 Annen ya da babanın yardımıyla banyo yap | KA | Kolay | — |
| `gs_health_020` | 👟 Ayakkabılarını kendin giy | KA | Kolay | Odak ve Öz Denetim |
| `gs_health_021` | 🍎 Az şekerli bir öğün ye | KABC | Orta | — |
| `gs_health_022` | 🚲 Bisiklet sür | KABC | Kolay | — |
| `gs_health_023` | 💧 Bol su iç | KABC | Kolay | — |
| `gs_health_024` | 🧴 Deodorant kullan | BC | Kolay | Odak ve Öz Denetim |
| `gs_health_025` | 🦷 Diş ipi kullan | ABC | Kolay | — |
| `gs_health_026` | 🌞 Dışarıda oyna! | KABC | Orta | — |
| `gs_health_027` | 🦁 Endişelendiğinde bile cesur ol | KABC | Kolay | — |
| `gs_health_028` | 💧 Gün boyunca 8 bardak su iç | ABC | Orta | — |
| `gs_health_029` | 🍽️ Günde 3 öğün ye | KABC | Orta | — |
| `gs_health_030` | 🏊 Havuzda 1 tur yüz | ABC | Kolay | — |
| `gs_health_031` | 🥣 Kahvaltını yap | KABC | Orta | — |
| `gs_health_032` | 🐕 Köpeği yürüyüşe çıkar | BC | Orta | — |
| `gs_health_033` | 🪥 Sabah dişlerini fırçala | KABC | Orta | Odak ve Öz Denetim |
| `gs_health_034` | 🪥 Sabah ve akşam dişlerini fırçala | KABC | Kolay | — |
| `gs_health_035` | 💇 Saçını tara | KABC | Kolay | Odak ve Öz Denetim |
| `gs_health_036` | 🥗 Sağlıklı bir akşam yemeği ye | KABC | Kolay | — |
| `gs_health_037` | 🥪 Sağlıklı bir öğle yemeği ye | KABC | Kolay | — |
| `gs_health_038` | 🥦 Sebzelerini ye | KABC | Orta | — |
| `gs_health_039` | 💊 Vitaminini ya da ilacını al (bir büyüğünle) | KABC | Kolay | — |
| `gs_health_040` | 🪥 Yatmadan önce dişlerini fırçala | KABC | Orta | Odak ve Öz Denetim |
| `gs_health_041` | 🧼 Yemekten önce ellerini yıka | KABC | Kolay | — |
| `gs_health_042` | 😋 Yemeğini söylenmeden ye | KABC | Kolay | — |
| `gs_health_043` | ⚽ Yeni bir spor öğren | ABC | Orta | — |
| `gs_health_044` | 🏊 Yüzme kulaçlarını çalış | ABC | Kolay | — |
| `gs_health_045` | 🏊 Yüzmeyi öğren | KABC | Zor | — |
| `gs_health_046` | 🫧 Yüzünü yıka | KABC | Kolay | Odak ve Öz Denetim |
| `gs_health_047` | 🪢 İp atlamayı çalış (bir büyüğünle) | KAB | Kolay | — |
| `gs_health_048` | 🎢 İstemediğin eğlenceli bir etkinliği dene | KABC | Kolay | — |

## Odak ve Öz Denetim → Odak

| Anahtar | Görev | Yaş | Zorluk | Diğer süzgeçler |
|---|---|---|---|---|
| `gs_focus_001` | 🙂 'Hayır' cevabını tartışmadan kabul et | KABC | Kolay | İlişki Kurma |
| `gs_focus_002` | ⏱️ 5 dakikadan kısa sürede giyin | ABC | Orta | — |
| `gs_focus_003` | 📜 6 kelimelik bir hikâye yaz | ABC | Kolay | — |
| `gs_focus_004` | ✒️ Adını süslü harflerle yaz | KA | Kolay | — |
| `gs_focus_005` | 👩‍🍳 Aile için bir yemek hazırla (bir büyüğünle) | BC | Kolay | — |
| `gs_focus_006` | 🌙 Akşam uyku hazırlığını kendin yap | KABC | Zor | — |
| `gs_focus_007` | ⏰ Alarmla kendin uyan | ABC | Zor | — |
| `gs_focus_008` | 👟 Ayakkabı bağlamayı çalış | KA | Kolay | — |
| `gs_focus_009` | 🎨 Bir aile üyeni çiz ve resmi ona hediye et | KAB | Kolay | — |
| `gs_focus_010` | 💼 Bir fikrin için küçük bir iş planı yaz | BC | Kolay | — |
| `gs_focus_011` | 💪 Bir işi büyüklerinden yardım almadan bitir | KABC | Kolay | — |
| `gs_focus_012` | 🧩 Bir yapbozu vazgeçmeden bitir | KABC | Kolay | Öğrenme ve Eğitim |
| `gs_focus_013` | 🎯 Biriktirmek istediğin bir şey seç | ABC | Kolay | — |
| `gs_focus_014` | 🎯 Bu ay için 5 hedef yaz ve ailene göster | ABC | Kolay | — |
| `gs_focus_015` | 🗣️ Bugün ne yapmak istediğini ailene anlat | KABC | Kolay | — |
| `gs_focus_016` | 🛏️ Bütün gece kendi yatağında uyu | KA | Orta | — |
| `gs_focus_017` | 🤫 Büyüklerin telefondayken sessizce bekle | KABC | Kolay | İlişki Kurma |
| `gs_focus_018` | 🌟 Büyüyünce ne olmak istediğini yaz | ABC | Kolay | — |
| `gs_focus_019` | 🌟 Büyüyünce ne olmak istediğini çiz | KA | Kolay | — |
| `gs_focus_020` | 🔧 Evde bozuk bir şeyi onar (bir büyüğünle) | BC | Orta | — |
| `gs_focus_021` | 🎒 Eşyalarını topla | KABC | Orta | — |
| `gs_focus_022` | 🎯 Günün bütün Ev Görevlerini bitir | KABC | Zor | — |
| `gs_focus_023` | 📅 Gününü planla | ABC | Kolay | — |
| `gs_focus_024` | 🌈 Hafta sonu için 3 dilek yaz | KABC | Kolay | — |
| `gs_focus_025` | 🗓️ Haftalık ders çalışma planı yap | BC | Zor | — |
| `gs_focus_026` | 🎯 Haftalık hedeflerini belirle! | ABC | Kolay | — |
| `gs_focus_027` | 🗓️ Haftanın planını yap | ABC | Kolay | — |
| `gs_focus_028` | 💰 Harçlığın için küçük bir bütçe yap | BC | Zor | — |
| `gs_focus_029` | 🛏️ Kalkınca odanı topla | KABC | Kolay | — |
| `gs_focus_030` | 👕 Kendi kendine giyinmeyi dene! | KA | Kolay | — |
| `gs_focus_031` | 🧺 Kendi çamaşırını yıka | BC | Orta | — |
| `gs_focus_032` | 🍎 Kendine bir atıştırmalık hazırla | ABC | Kolay | — |
| `gs_focus_033` | 🐷 Kumbara edin | ABC | Kolay | — |
| `gs_focus_034` | 🐷 Kumbarana biraz para at | ABC | Orta | — |
| `gs_focus_035` | ✈️ Kâğıttan uçak yap | KABC | Kolay | — |
| `gs_focus_036` | 📝 Market listesi yap | ABC | Kolay | — |
| `gs_focus_037` | 😴 Mızıkçılık yapmadan uyu | KA | Kolay | — |
| `gs_focus_038` | ✨ Odanı bugün çok iyi temizle | ABC | Kolay | — |
| `gs_focus_039` | 🪟 Odanın perdesini aç | KABC | Kolay | — |
| `gs_focus_040` | 🥪 Okul yemeğini hazırlamaya yardım et | KAB | Kolay | — |
| `gs_focus_041` | 🍱 Okul yemeğini kendin hazırla | BC | Kolay | — |
| `gs_focus_042` | 🎒 Okul çantanı düzenle | ABC | Kolay | — |
| `gs_focus_043` | 🎒 Okul çantanı hazırla | KABC | Kolay | Ev İşleri |
| `gs_focus_044` | 🎒 Okula giyinerek hazırlan | KABC | Kolay | — |
| `gs_focus_045` | ✅ Oyuna girmeden önce bugünkü Ev Görevlerini bitir | KABC | Kolay | Ev İşleri |
| `gs_focus_046` | 🩳 Pijamanı kendin giy | KA | Kolay | — |
| `gs_focus_047` | 🌙 Saat 21.00'den önce yat | KAB | Orta | — |
| `gs_focus_048` | 🚪 Saat 8.00'de hazır ol | ABC | Orta | — |
| `gs_focus_049` | ⏰ Sabah 6.45'te kendi kendine kalk | ABC | Zor | — |
| `gs_focus_050` | ☀️ Sabah hazırlığını kendin yap | KABC | Orta | — |
| `gs_focus_051` | ☑️ Sabah kontrol listeni tamamla | KABC | Kolay | — |
| `gs_focus_052` | 📝 Söylenmeden ödevine başla | ABC | Orta | — |
| `gs_focus_053` | 🎮 Süre bitince oyun konsolunu kapat | ABC | Zor | Ev İşleri |
| `gs_focus_054` | ⏰ Yarın sabah için alarm kur | ABC | Kolay | — |
| `gs_focus_055` | 📅 Yarını planla | ABC | Kolay | — |
| `gs_focus_056` | 👚 Yarının kıyafetlerini seç | KABC | Kolay | — |
| `gs_focus_057` | 🛏️ Yatağını topla | KABC | Kolay | — |
| `gs_focus_058` | 📵 Yatmadan 20 dakika önce ekranları kapat | KABC | Zor | — |
| `gs_focus_059` | 🛌 Yatmaya hazırlan | KABC | Orta | — |
| `gs_focus_060` | 🗂️ Çalışma masanı düzenle | ABC | Orta | — |
| `gs_focus_061` | ✏️ Ödeve başlamadan bütün malzemeni hazırla | ABC | Orta | — |
| `gs_focus_062` | 🔉 İçeride alçak sesle konuş | KABC | Kolay | — |

## İlişki Kurma → Nezaket

| Anahtar | Görev | Yaş | Zorluk | Diğer süzgeçler |
|---|---|---|---|---|
| `gs_relation_001` | 🌼 3 kişiye iltifat et | ABC | Kolay | — |
| `gs_relation_002` | 🎬 Ailece film gecesi yap | KABC | Kolay | — |
| `gs_relation_003` | 🎡 Ailen için eğlenceli bir hafta sonu etkinliği planla | ABC | Orta | — |
| `gs_relation_004` | 💖 Ailende sevdiğin 3 şeyi yaz! | ABC | Kolay | — |
| `gs_relation_005` | 📆 Ailenin onayladığı bir arkadaşınla buluşma planla | BC | Orta | — |
| `gs_relation_006` | 🍿 Ailenle film izle | KABC | Kolay | — |
| `gs_relation_007` | 🚗 Ailenle günübirlik bir geziye çık | KABC | Kolay | — |
| `gs_relation_008` | 🃏 Ailenle kart oyunu oyna | KABC | Kolay | — |
| `gs_relation_009` | 🎲 Ailenle kutu oyunu oyna | KABC | Kolay | — |
| `gs_relation_010` | 🚶 Ailenle yürüyüşe çık | KABC | Orta | — |
| `gs_relation_011` | 📚 Annen ya da babanla kısa bir kitap oku | KA | Kolay | — |
| `gs_relation_012` | 🎩 Annen ya da babanla nazik davranmayı çalış | KABC | Kolay | — |
| `gs_relation_013` | 🌳 Annen ya da babanla parka git | KAB | Kolay | — |
| `gs_relation_014` | 🧸 Annen ya da babanla sarılarak dinlen | KAB | Kolay | — |
| `gs_relation_015` | 💬 Annene ya da babana gününün nasıl geçtiğini sor | KABC | Kolay | — |
| `gs_relation_016` | 🤗 Annene ya da babana sarıl | KABC | Kolay | — |
| `gs_relation_017` | 🤝 Arkadaşlarına saygılı davran (patronluk taslamadan) | KABC | Kolay | — |
| `gs_relation_018` | 👫 Arkadaşlarını annen ya da babanla konuş | KABC | Kolay | — |
| `gs_relation_019` | 💬 Bağırmadan nasıl hissettiğini anlat | KAB | Kolay | — |
| `gs_relation_020` | 📞 Bir aile büyüğünü arayıp hâlini sor | KABC | Orta | — |
| `gs_relation_021` | ♟️ Bir aile üyenle satranç oyna | ABC | Kolay | — |
| `gs_relation_022` | ✉️ Bir arkadaşına mektup yaz | ABC | Orta | — |
| `gs_relation_023` | 👫 Bir arkadaşınla vakit geçir | KABC | Kolay | — |
| `gs_relation_024` | 💐 Bir teşekkür notu yaz | KABC | Kolay | — |
| `gs_relation_025` | 💝 Biri için güzel bir şey yap | KABC | Kolay | — |
| `gs_relation_026` | 🌞 Birine günaydın de! | KABC | Kolay | — |
| `gs_relation_027` | 🌸 Birine iltifat et | KABC | Kolay | — |
| `gs_relation_028` | 💌 Birine neden onu sevdiğini anlatan bir kart yap | KABC | Kolay | — |
| `gs_relation_029` | 👋 Birini kibarca selamlamayı çalış | KABC | Kolay | — |
| `gs_relation_030` | 💌 Birini mutlu edecek bir sürpriz not bırak | KABC | Kolay | — |
| `gs_relation_031` | 😄 Bugün birini gülümset | KABC | Kolay | — |
| `gs_relation_032` | 🤝 Bugün kardeşine hiç vurma, itme | KAB | Orta | — |
| `gs_relation_033` | 📕 En sevdiğin kitabı paylaş | KABC | Kolay | — |
| `gs_relation_034` | 📸 Eğlenceli bir anını paylaş | KABC | Kolay | — |
| `gs_relation_035` | 🏆 Gurur duyduğun 3 şeyi bul | ABC | Kolay | — |
| `gs_relation_036` | 🤲 Kardeşin ya da arkadaşlarınla paylaş | KABC | Kolay | — |
| `gs_relation_037` | 💛 Kardeşine iyi davran | KABC | Kolay | — |
| `gs_relation_038` | 🧺 Kardeşinle açık havada piknik yap | KABC | Kolay | — |
| `gs_relation_039` | 🎈 Kardeşinle eğlenceli bir şey yap | KABC | Kolay | — |
| `gs_relation_040` | 🕊️ Kardeşinle kavga etme | KABC | Orta | — |
| `gs_relation_041` | 🎮 Kardeşinle oyun oyna | KABC | Kolay | — |
| `gs_relation_042` | 👾 Komik bir canavar yüzü yap | KAB | Kolay | — |
| `gs_relation_043` | 👀 Konuşurken söylenmeden göz teması kur | KABC | Kolay | — |
| `gs_relation_044` | 👶 Küçük kardeşine göz kulak ol (bir büyüğün yanındayken) | BC | Zor | — |
| `gs_relation_045` | 🙏 Lütfen ve teşekkür ederim de | KABC | Kolay | — |
| `gs_relation_046` | 🏫 Okulda bütün gün güzel davran | KABC | Kolay | — |
| `gs_relation_047` | ⏳ Oyunlarda sıranı bekle | KABC | Kolay | Odak ve Öz Denetim |
| `gs_relation_048` | 🎁 Rastgele bir iyilik yap | KABC | Orta | — |
| `gs_relation_049` | 🙏 Teşekkür ettiğin bir şeyi çiz | KAB | Kolay | — |
| `gs_relation_050` | 🧒 Yeni bir arkadaşla oyna | KABC | Kolay | — |
| `gs_relation_051` | 😊 İki farklı kişiye güzel bir söz söyleyip onları gülümset | KABC | Kolay | — |
| `gs_relation_052` | 🤗 İyi arkadaş nasıl olur, ailenle konuş | KABC | Kolay | — |
