# Ev Görevleri şablon kataloğu (23 Ekim 2026)

**298 şablon**, 6 kategori × 4 yaş grubu. Kaynak: kullanıcının paylaştığı Joon "Start with a template" kayıtları (10 video, 19 Ekim 2026); görev adları videolardan okunup Türkçeleştirildi, kopyalar birleştirildi, Türkiye'ye uyarlandı (mil → km, "Joon görevleri" → Ev Görevleri, çay vb.). Veri: [`veri/gorev_sablonlari.json`](../veri/gorev_sablonlari.json); sunucu tablosu önerisi: `supabase/proposed/20261023010000_task_templates.sql`.

## Kurallar

- **Ana kategori = beceri** (`ekonomi.md` 5B). Ana kategori, Joon kaydında görevin yanındaki beceri simgesinden alındı: turuncu = Takım Çalışması (Ev İşleri), camgöbeği = Dayanıklılık (Ruh Sağlığı), mavi = Bilgi (Öğrenme ve Eğitim), yeşil = Güç (Sağlık ve Spor), pembe = Odak (Odak ve Öz Denetim), sarı = Nezaket (İlişki Kurma).
- **Süzgeç etiketleri (`categories`)**: ana kategori + görevin Joon'da ayrıca listelendiği kategoriler. Joon'un "Mental Health" listesi neredeyse bütün görevleri içeriyor; süzgeç işe yarasın diye Ruh Sağlığı yalnız ana kategori olarak kullanılır.
- **Yaş grubu (`ages`)**: oyunla aynı K (5 ve altı), A (6–8), B (9–12), C (13 ve üstü). Joon kayıtlarında görevlerin çoğu dört yaş grubunun hepsinde görünüyor; önerilen gruplar güvenlik ve gelişime göre daraltıldı (ör. bulaşık yıkama B–C, destek tekerli bisiklet K–A). Joon'da görülen yaş ayrıca yazılıdır.
- **Zorluk ve coin**: Joon'daki Kolay/Orta/Zor korunur; coin bizim varsayılanımız 5 / 10 / 20 (Joon 4 / 10 / 20). Ebeveyn değiştirebilir.
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

| Görev | Yaş | Zorluk | Diğer süzgeçler | Joon'da (yaş) | Kaynak (İng.) |
|---|---|---|---|---|---|
| 🍽️ Akşam yemeğinden sonra toplamaya yardım et | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Clean up from dinner |
| 🍲 Akşam yemeğini hazırlamaya yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help mom/dad prepare dinner |
| 🙋 Anne ya da babana bugün neye yardım edebileceğini sor | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Ask Mom or Dad what you can help with today |
| 🙋 Annen ya da baban isteyince yardım et | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help mom or dad when asked |
| 🍁 Annen ya da babanla bahçedeki yaprakları topla | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help mom or dad rake the leaves in the yard |
| 🚗 Araba yıkamaya yardım et | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help wash car |
| 🚗 Arabayı yıka | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wash car |
| 👟 Ayakkabılarını yerine koy | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put shoes away |
| 🌳 Bahçe işlerine yardım et | BC | Kolay | — | 10–12, 13 ve üstü | Do some yard work |
| 🌱 Bahçede yardım et | KAB | Orta | — | 6 ve altı, 7–9, 10–12 | Help in the garden |
| 🍂 Bahçedeki yaprakları tırmıkla | BC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Rake the leaves in the yard |
| 🗑️ Banyo çöp kutusunu boşalt | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Empty bathroom trash bin |
| 🧻 Banyodaki havluları as | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Hang up towels in bathroom |
| 🛁 Banyoyu temizle | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Clean bathroom |
| 🥘 Basit bir yemeği hazırlamaya yardım et | KABC | Kolay | İlişki Kurma | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help prepare a simple meal |
| ✋ Başkası konuşurken sözünü kesmeden bekle | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wait until others are done talking before talking |
| 🍽️ Bulaşık makinesini boşalt | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Empty the dishwasher |
| 🍽️ Bulaşık makinesini doldur | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Load the dishwasher |
| 🧽 Bulaşıkları yıka | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wash dirty dishes |
| 👂 Büyüklerinin söylediğini tartışmadan yap | KABC | Kolay | — | 13 ve üstü | Follow instructions from parents without arguing |
| 🪟 Camları sil | ABC | Kolay | — | 7–9, 13 ve üstü | Wash windows |
| 🧹 Elektrik süpürgesi çekmeye yardım et | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help vacuum |
| 🙌 Ev işlerine yardım etmeyi teklif et | KABC | Kolay | İlişki Kurma | 6 ve altı, 7–9, 10–12, 13 ve üstü | Offer to help with household chores |
| 🐾 Evcil hayvanına mama ve su ver | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Give pet food and water |
| 🔨 Evdeki küçük tamirlere yardım et | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help with home repairs |
| 🚙 Eve gelince arabadan eşyaları taşı | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Unload the car when home |
| 🏠 Evin genel düzenine yardım et | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help with general tidiness of house |
| 🧰 Garajı ya da depoyu temizlemeye yardım et | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help clean garage |
| ♻️ Geri dönüşüm kutusunu çıkar | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Take Out Recycling |
| ♻️ Geri dönüşüm ve çöpü ayır | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Sort recycling and trash |
| 🛍️ Hafif market poşetlerini taşımaya yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help bring in light groceries |
| 🧽 Haftalık ev temizliğine yardım et | KABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help with weekly house clean up |
| 🥣 Her yemekten sonra tabağını lavaboya bırak | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put your plate/bowl in the sink after each meal |
| 🫖 Kahvaltı için çay hazırlığına yardım et | BC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Prepare the coffee maker |
| 🍳 Kahvaltıdan sonra toplamaya yardım et | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Clean up from breakfast |
| 📖 Kardeşine ödevinde yardım et | BC | Kolay | Öğrenme ve Eğitim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help your sibling with homework |
| 🤳 Kendinin komik bir fotoğrafını çek | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Take a silly photo of yourself |
| 🤫 Kimseyi şikâyet etmeden kendi işine odaklan | ABC | Kolay | — | 7–9, 13 ve üstü | Mind own business (i.e., no tattling) without being reminded |
| 🧺 Kirli kıyafetlerini sepete at | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put clothes in the hamper |
| 🛒 Market alışverişine yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Help with grocery shopping |
| 🧃 Market alışverişini yerleştirmeye yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help put groceries away |
| 🪶 Mobilyaların tozunu almaya yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Help dust the furniture |
| 🍴 Mutfak masasını kur | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Set the kitchen table |
| 🧽 Mutfak masasını sil | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wipe down kitchen table |
| 🧹 Odanı topla (oyuncak, kıyafet, yatak) | ABC | Zor | — | 7–9, 10–12, 13 ve üstü | Clean up bedroom (toys, clothes, bed) |
| 🧸 Oyuncaklarını düzenle | KAB | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Organize your toys |
| 🧸 Oyundan sonra ortalığı topla | KAB | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Clean up after playing |
| 🧽 Plastik bulaşıkları yıka (bir büyüğünle) | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wash plastic dishes (with supervision) |
| 📬 Posta kutusundaki mektupları getir | ABC | Kolay | — | 7–9, 10–12, 13 ve üstü | Bring the mail in from the mailbox |
| 🍴 Sofrayı kurmaya yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help set the table |
| 🍽️ Sofrayı toplamaya yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help clear the table |
| ⭐ Söylenmeden annene ya da babana yardım et | ABC | Kolay | — | 7–9, 10–12, 13 ve üstü | Help mom/dad when asked (without reminder) |
| 🧸 Söylenmeden oyuncaklarını topla | KAB | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Clean up toys without being asked |
| 🍽️ Temiz tabakları yerleştir (kesici aletler hariç!) | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put away clean dishes (no sharp objects!) |
| 👕 Temiz çamaşırları yerleştir | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put away clean laundry |
| 🧻 Tuvalet kâğıdını değiştir | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Replace toilet paper in bathroom |
| 🛏️ Yatak çarşafını değiştir | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Change bed sheets |
| 🧸 Yatmadan önce oyuncaklarını topla | KAB | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Pick up toys before bed |
| ✋ Yeni bir selamlaşma uydur | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Invent a new handshake |
| 🧹 Yerleri süpür | ABC | Orta | — | 6 ve altı, 7–9, 10–12 | Sweep the floors |
| 🧺 Çamaşır makinesini çalıştırmaya yardım et | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help with starting laundry |
| 👕 Çamaşırları ayırmaya yardım et | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help with laundry (sort clothing) |
| 🪴 Çiçekleri sula | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Water plants |
| 🗑️ Çöpü çıkar | BC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Take out the trash |
| 🗑️ Çöpü çıkarmaya yardım et | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help take out trash |

## Ruh Sağlığı → Dayanıklılık

| Görev | Yaş | Zorluk | Diğer süzgeçler | Joon'da (yaş) | Kaynak (İng.) |
|---|---|---|---|---|---|
| 🌬️ 1 dakika derin nefes egzersizi yap | KABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Practice deep breathing exercise for 1 minute |
| 🧘 10 dakika meditasyon yap | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Meditate for 10 minutes |
| 🧘 15 dakika meditasyon yap | ABC | Kolay | — | 6 ve altı, 7–9 | Meditate for 15 minutes |
| 🕺 2 dakika dans et | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Dance for 2 minutes |
| 🌬️ 5 kez derin nefes al | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Take 5 deep breaths |
| 📝 Ailene bir not yaz | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write a note to your parents |
| 💌 Ailene nasıl hissettiğini anlatan bir not yaz | BC | Kolay | — | 13 ve üstü | Write a note to your parents about how you're feeling |
| 🍂 Bir büyüğünle doğa yürüyüşünde yaprak ya da taş topla | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go on a nature walk (with parent) and collect leaves or rocks |
| 🌈 Bir duygu çizelgesi yap ve bugün doldur | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Create a mood tracker and fill it out today |
| 🖍️ Bir resim çiz ve annene ya da babana göster | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Draw a picture and show it to mom/dad |
| 🙏 Bu hafta minnet duyduğun şeyleri yaz | BC | Orta | — | 7–9, 10–12, 13 ve üstü | Write down what you are grateful for this week |
| 😊 Bugün olumlu ol | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Have a positive attitude today |
| ✨ Bugünün 3 güzel şeyini yaz | KABC | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | List three good things today |
| ⏸️ Cevap vermeden önce sakinleşmek için 5–10 dakika ara ver | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Take a 5-10 minute break to calm down before responding |
| 💭 Duygularını annen ya da babanla konuş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Talk about your feelings with mom / dad |
| 🫂 En çok neden korktuğunu yaz | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write down what you are most scared of |
| 🗺️ Evinin haritasını çiz ve ailene göster | KA | Kolay | — | 6 ve altı, 7–9 | Draw a map of your house (then show mom / dad) |
| 📓 Günlük tutmaya başla | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Start a diary |
| 📓 Gününü günlüğüne yaz | BC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Journal about your day |
| 🎨 Havalı bir şey boya! | KABC | Kolay | — | 7–9, 10–12, 13 ve üstü | Paint something cool! |
| 💡 Kendine yapacak bir iş bul ve bitir | KABC | Kolay | Ev İşleri, İlişki Kurma | 6 ve altı, 7–9, 10–12, 13 ve üstü | Find something to do and do it |
| 📔 Minnet defteri tutmaya başla | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Start a gratitude journal |
| 📔 Minnet defterine yeni bir şey yaz | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Add a new entry to your gratitude journal |
| 🎶 Odanda dans partisi yap | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Have a dance party in your room |
| 🌅 Sabah 5–10 dakika esne | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Stretch for 5-10 minutes in the morning |
| 😊 Seni mutlu eden şeyleri yaz | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write down what makes you happy |
| 🖍️ Tebeşirle kaldırımı süsle | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Grab some chalk and decorate the sidewalk |
| 💃 Yeni bir dans hareketi uydur | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Create a new dance move |
| 🌬️ Üzüldüğünde 5 kez derin nefes al | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Take five deep breaths when upset |

## Öğrenme ve Eğitim → Bilgi

| Görev | Yaş | Zorluk | Diğer süzgeçler | Joon'da (yaş) | Kaynak (İng.) |
|---|---|---|---|---|---|
| 🔤 'B' harfiyle başlayan 5 şey bul | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Find 5 things starting with 'B' |
| 📖 10 dakika kitap oku | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Read a book for 10 minutes |
| 🧩 100 parçalı yapboz yap | AB | Kolay | — | 6 ve altı, 7–9, 10–12 | Do a 100 piece puzzle |
| 🎹 15 dakika enstrüman çal | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Practice an instrument for 15 minutes |
| 📖 15 dakika kendi başına kitap oku | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Read on your own for 15 minutes |
| 📖 20 dakika kitap oku | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Read for 20 minutes |
| 📖 Ailene bugünle ilgili bir hikâye anlat | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Tell your parent a story about today |
| 😂 Akşam yemeği için bir fıkra yaz | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write a joke for dinner |
| 🔠 Alfabeyi söylemeyi çalış | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Practice saying the alphabet |
| ✍️ Alfabeyi yazmayı çalış | KA | Kolay | — | 6 ve altı, 10–12, 13 ve üstü | Practice writing the alphabet |
| 📚 Bir kitabı baştan sona oku | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Read a whole book |
| ➗ Bir matematik çalışma sayfası çöz | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do a math problem set |
| ✏️ Bir ödevini yap | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do a homework assignment |
| 🧑‍🏫 Birine yeni bir şey öğret | ABC | Kolay | — | 13 ve üstü | Teach someone something new |
| 🚲 Bisiklet sürmeyi öğren (kask ve destek tekerleriyle) | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn how to ride a bicycle (with helmet & training wheels) |
| 🌿 Bitkileri tanımayı öğren | BC | Kolay | — | 10–12, 13 ve üstü | Learn how to identify plants |
| 📚 Bütün ödevlerini bitir | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Complete all your homework assignments |
| 📱 Dijital haritayla yol bulmayı öğren | BC | Kolay | — | 10–12, 13 ve üstü | Learn how to use a digital map for navigation |
| 🏡 Ev adresini ezberle | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Memorize your home address |
| 🪢 Farklı düğümler atmayı öğren | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn how to tie different knots |
| 📚 Gelecek haftanın ödevine başla | BC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Start next week's homework |
| 📝 Gününü çiz ya da yaz | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Draw or write about your day |
| 🩹 Kesik ya da yarayı temizlemeyi öğren | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn how to treat a cut or wound |
| 👔 Kravat bağlamayı öğren | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn how to tie a tie |
| 🖼️ Küçük bir resim sergisi hazırla | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Create a tiny art gallery |
| 🏫 Okula git | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go to school |
| ♟️ Satranç öğren | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn to play chess |
| 🔢 Sayıları yazmayı çalış | KA | Kolay | — | 6 ve altı, 13 ve üstü | Practice writing down numbers |
| ⛑️ Temel ilk yardımı öğren | ABC | Kolay | — | 6 ve altı, 7–9, 10–12 | Learn how to do basic first aid |
| 📖 Yaklaşan bir sınava ya da yazılıya hazırlan | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Prepare for an upcoming quiz or test |
| 📋 Yapman gereken ödevleri bir listeye yaz | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write down what schoolwork you need to do |
| 🦉 Yatmadan önce ailene 3 ilginç bilgi anlat | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Tell Mom or Dad 3 interesting facts before bedtime |
| 📖 Yatmadan önce kitap oku | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Read before bed |
| 🥄 Yemek yaparken malzemeleri ölçmeye yardım et | KAB | Orta | — | 6 ve altı, 7–9, 10–12 | Help measure ingredients for cooking |
| 🌍 Yeni bir dil öğrenmeye başla | ABC | Kolay | — | 13 ve üstü | Start learning a new language |
| 🎸 Yeni bir enstrümana başla | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Start learning a new instrument |
| 🎲 Yeni bir oyun öğren | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn a new game |
| 🥪 Yeni bir sandviç tarifi uydur | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Design a new sandwich |
| ⚠️ Zehirli bitki ve hayvanları tanımayı öğren | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn how to identify poisonous plants & animals |
| ✖️ Çarpım tablosunu tekrar et | AB | Kolay | — | 6 ve altı, 7–9, 10–12 | Recite multiplication tables |
| ⏰ Ödevini saat 17.00'den önce bitir | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Complete your homework before 5:00pm |
| 💡 Öğrendiğin bir şeyi paylaş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Share something you learned |

## Sağlık ve Spor → Güç

| Görev | Yaş | Zorluk | Diğer süzgeçler | Joon'da (yaş) | Kaynak (İng.) |
|---|---|---|---|---|---|
| 🙆 1 dakika esneme yap | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do a 1-minute stretch |
| 🏃 1 dakika yerinde koş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Run on the spot for 1 minute |
| 🏋️ 10 burpee yap | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do 10 burpees |
| 🧘 10 dakika esneme yap | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Stretch for 10 minutes |
| 🤸 10 zıplama hareketi (jumping jack) yap | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do 10 jumping jacks |
| 🏃 20 mekik çek | BC | Kolay | — | 7–9, 10–12, 13 ve üstü | Do 20 sit ups |
| 💪 20 şınav çek | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do 20 push ups |
| 🏃 3 km koş (süreni tut!) | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Run 2 miles (and time yourself!) |
| 💪 3 şınav çek | KA | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Do 3 push ups |
| 🏅 30 dakika spor yap | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Exercise for 30 minutes |
| 🏀 30 dakika spor çalış | BC | Zor | — | 10–12, 13 ve üstü | Practice a sport for 30 minutes |
| 🥕 5 farklı meyve ve sebze ye | KABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat 5 different fruits and veggies |
| 🏃 5 mekik çek | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do 5 sit-ups |
| 💪 5 şınav çek | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do 5 push-ups |
| 🥾 Annen ya da babanla doğa yürüyüşüne çık | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go on a hike with mom or dad |
| 🏃 Annen ya da babanla koşuya çık | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go on a run with mom / dad |
| 🐕 Annen ya da babanla köpeği yürüyüşe çıkar | KA | Kolay | — | 7–9, 13 ve üstü | Take dog for walk (with mom/dad) |
| ⚾ Annen ya da babanla top yakalama oyna | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Play catch with mom or dad |
| 🛁 Annen ya da babanın yardımıyla banyo yap | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Have a bath with help from mom or dad |
| 👟 Ayakkabılarını kendin giy | KA | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put shoes on |
| 🍎 Az şekerli bir öğün ye | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat a low sugar meal |
| 🚲 Bisiklet sür | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go on a bike ride |
| 💧 Bol su iç | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Drink plenty of water |
| 🧴 Deodorant kullan | BC | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put on deodorant |
| 🦷 Diş ipi kullan | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Floss your teeth |
| 🌞 Dışarıda oyna! | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Play outside! |
| 🦁 Endişelendiğinde bile cesur ol | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Be brave even when worried about what might happen |
| 💧 Gün boyunca 8 bardak su iç | ABC | Orta | — | 7–9, 10–12, 13 ve üstü | Drink 8 cups of water a day |
| 🍽️ Günde 3 öğün ye | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat 3 meals a day |
| 🏊 Havuzda 1 tur yüz | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Swim 1 lap |
| 🥣 Kahvaltını yap | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat breakfast |
| 🐕 Köpeği yürüyüşe çıkar | BC | Orta | — | 10–12, 13 ve üstü | Take dog for walk |
| 🪥 Sabah dişlerini fırçala | KABC | Orta | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Brush your teeth in the morning |
| 🪥 Sabah ve akşam dişlerini fırçala | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Brush teeth in the morning and at night |
| 💇 Saçını tara | KABC | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Brush your hair |
| 🥗 Sağlıklı bir akşam yemeği ye | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat a healthy dinner |
| 🥪 Sağlıklı bir öğle yemeği ye | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat a healthy lunch |
| 🥦 Sebzelerini ye | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat your vegetables |
| 💊 Vitaminini ya da ilacını al (bir büyüğünle) | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Take vitamins or medicine |
| 🪥 Yatmadan önce dişlerini fırçala | KABC | Orta | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Brush your teeth before bed |
| 🧼 Yemekten önce ellerini yıka | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wash hands before eating |
| 😋 Yemeğini söylenmeden ye | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Eat meal without complaining |
| ⚽ Yeni bir spor öğren | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn a new sport |
| 🏊 Yüzme kulaçlarını çalış | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Practice swim strokes |
| 🏊 Yüzmeyi öğren | KABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Learn how to swim |
| 🫧 Yüzünü yıka | KABC | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wash your face |
| 🪢 İp atlamayı çalış (bir büyüğünle) | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Practice jumping rope (with supervision) |
| 🎢 İstemediğin eğlenceli bir etkinliği dene | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Try a fun activity that you don't want to do |

## Odak ve Öz Denetim → Odak

| Görev | Yaş | Zorluk | Diğer süzgeçler | Joon'da (yaş) | Kaynak (İng.) |
|---|---|---|---|---|---|
| 🙂 'Hayır' cevabını tartışmadan kabul et | KABC | Kolay | İlişki Kurma | 6 ve altı, 7–9, 10–12, 13 ve üstü | Accept 'No' without arguing |
| ⏱️ 5 dakikadan kısa sürede giyin | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Get dressed for the day in under 5 minutes |
| 📜 6 kelimelik bir hikâye yaz | ABC | Kolay | — | 7–9, 13 ve üstü | Write a story using 6 words |
| ✒️ Adını süslü harflerle yaz | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write your name fancy |
| 👩‍🍳 Aile için bir yemek hazırla (bir büyüğünle) | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Prepare a meal for the family |
| 🌙 Akşam uyku hazırlığını kendin yap | KABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do your bedtime routine |
| ⏰ Alarmla kendin uyan | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wake up with alarm clock |
| 👟 Ayakkabı bağlamayı çalış | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Practice tying your shoes |
| 🎨 Bir aile üyeni çiz ve resmi ona hediye et | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Draw a family member and give it to them |
| 💼 Bir fikrin için küçük bir iş planı yaz | BC | Kolay | — | 7–9, 10–12, 13 ve üstü | Write out a business plan for an idea you had |
| 💪 Bir işi büyüklerinden yardım almadan bitir | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Complete a task without needing parent's help |
| 🧩 Bir yapbozu vazgeçmeden bitir | KABC | Kolay | Öğrenme ve Eğitim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Complete a puzzle without giving up |
| 🎯 Biriktirmek istediğin bir şey seç | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Pick an item you want to start saving up for |
| 🎯 Bu ay için 5 hedef yaz ve ailene göster | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write out 5 goals for the month and show mom or dad |
| 🗣️ Bugün ne yapmak istediğini ailene anlat | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Tell mom / dad what you want to do today |
| 🛏️ Bütün gece kendi yatağında uyu | KA | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Stay in bed all night |
| 🤫 Büyüklerin telefondayken sessizce bekle | KABC | Kolay | İlişki Kurma | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wait quietly while parents are on calls |
| 🌟 Büyüyünce ne olmak istediğini yaz | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write about what you want to be when you grow up |
| 🌟 Büyüyünce ne olmak istediğini çiz | KA | Kolay | — | 6 ve altı, 7–9, 10–12 | Draw what you want to be when you grow up |
| 🔧 Evde bozuk bir şeyi onar (bir büyüğünle) | BC | Orta | — | 7–9, 10–12, 13 ve üstü | Fix something broken around the house |
| 🎒 Eşyalarını topla | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Pick up your belongings |
| 🎯 Günün bütün Ev Görevlerini bitir | KABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Finish All Quests for the Day! |
| 📅 Gününü planla | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Plan out your day |
| 🌈 Hafta sonu için 3 dilek yaz | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | List 3 weekend wishes |
| 🗓️ Haftalık ders çalışma planı yap | BC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Create a weekly study schedule |
| 🎯 Haftalık hedeflerini belirle! | ABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Set your goals for the week! |
| 🗓️ Haftanın planını yap | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make a plan for your week |
| 💰 Harçlığın için küçük bir bütçe yap | BC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Create a little spending budget for allowance |
| 🛏️ Kalkınca odanı topla | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Tidy your room when you wake up |
| 👕 Kendi kendine giyinmeyi dene! | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Try to dress yourself! |
| 🧺 Kendi çamaşırını yıka | BC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do your own laundry |
| 🍎 Kendine bir atıştırmalık hazırla | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Prepare a snack |
| 🐷 Kumbara edin | ABC | Kolay | — | 7–9, 10–12, 13 ve üstü | Start a piggy bank |
| 🐷 Kumbarana biraz para at | ABC | Orta | — | 7–9, 13 ve üstü | Add a little bit of money to your piggy bank |
| ✈️ Kâğıttan uçak yap | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Create a paper airplane |
| 📝 Market listesi yap | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make a grocery list |
| 😴 Mızıkçılık yapmadan uyu | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go to sleep without a fuss |
| ✨ Odanı bugün çok iyi temizle | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Clean your room extra well |
| 🪟 Odanın perdesini aç | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Open your bedroom blinds |
| 🥪 Okul yemeğini hazırlamaya yardım et | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Help prepare school lunch |
| 🍱 Okul yemeğini kendin hazırla | BC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make your own school lunch |
| 🎒 Okul çantanı düzenle | ABC | Kolay | — | 7–9, 10–12, 13 ve üstü | Organize your backpack |
| 🎒 Okul çantanı hazırla | KABC | Kolay | Ev İşleri | 6 ve altı, 7–9, 10–12, 13 ve üstü | Pack your school bag |
| 🎒 Okula giyinerek hazırlan | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Get dressed for school |
| ✅ Oyuna girmeden önce bugünkü Ev Görevlerini bitir | KABC | Kolay | Ev İşleri | 6 ve altı, 7–9, 10–12, 13 ve üstü | Complete all your Quests first before playing in Joon |
| 🩳 Pijamanı kendin giy | KA | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Put pajamas on for bed by yourself |
| 🌙 Saat 21.00'den önce yat | KAB | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go to bed before 9PM |
| 🚪 Saat 8.00'de hazır ol | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Ready & out of the house by 8am |
| ⏰ Sabah 6.45'te kendi kendine kalk | ABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Get out of bed at 6:45am by yourself |
| ☀️ Sabah hazırlığını kendin yap | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do your morning routine |
| ☑️ Sabah kontrol listeni tamamla | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Morning routine checklist |
| 📝 Söylenmeden ödevine başla | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Start homework without being reminded |
| 🎮 Süre bitince oyun konsolunu kapat | ABC | Zor | Ev İşleri | 6 ve altı, 7–9, 10–12, 13 ve üstü | Turn off video game console when time is up |
| ⏰ Yarın sabah için alarm kur | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Set alarm for tomorrow morning |
| 📅 Yarını planla | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Plan out tomorrow |
| 👚 Yarının kıyafetlerini seç | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Pick out tomorrow's clothes |
| 🛏️ Yatağını topla | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make your bed |
| 📵 Yatmadan 20 dakika önce ekranları kapat | KABC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Put away electronic devices 20 minutes before bedtime |
| 🛌 Yatmaya hazırlan | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Get ready for bed |
| 🗂️ Çalışma masanı düzenle | ABC | Orta | — | 7–9, 10–12, 13 ve üstü | Organize your workspace |
| ✏️ Ödeve başlamadan bütün malzemeni hazırla | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Prepare all homework supplies before starting |
| 🔉 İçeride alçak sesle konuş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Use indoor voice when indoors |

## İlişki Kurma → Nezaket

| Görev | Yaş | Zorluk | Diğer süzgeçler | Joon'da (yaş) | Kaynak (İng.) |
|---|---|---|---|---|---|
| 🌼 3 kişiye iltifat et | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Give 3 compliments |
| 🎬 Ailece film gecesi yap | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Have a family movie night |
| 🎡 Ailen için eğlenceli bir hafta sonu etkinliği planla | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Plan a fun weekend activity for your family |
| 💖 Ailende sevdiğin 3 şeyi yaz! | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write 3 things you love about your family! |
| 📆 Ailenin onayladığı bir arkadaşınla buluşma planla | BC | Orta | — | 7–9, 13 ve üstü | Schedule a hangout with a friend that your parents approve of |
| 🍿 Ailenle film izle | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Watch a movie with family |
| 🚗 Ailenle günübirlik bir geziye çık | KABC | Kolay | — | 6 ve altı, 13 ve üstü | Go on a day trip with your family |
| 🃏 Ailenle kart oyunu oyna | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Play a card game with your family |
| 🎲 Ailenle kutu oyunu oyna | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Play a board game with family |
| 🚶 Ailenle yürüyüşe çık | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Go on a walk with family |
| 📚 Annen ya da babanla kısa bir kitap oku | KA | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Read a short book with Mom or Dad |
| 🎩 Annen ya da babanla nazik davranmayı çalış | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Practice good manners with mom or dad |
| 🌳 Annen ya da babanla parka git | KAB | Kolay | — | 6 ve altı, 10–12, 13 ve üstü | Go to the park with Mom or Dad |
| 🧸 Annen ya da babanla sarılarak dinlen | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Snuggle with mom or dad |
| 💬 Annene ya da babana gününün nasıl geçtiğini sor | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Ask about parent's day |
| 🤗 Annene ya da babana sarıl | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Give mom or dad a hug |
| 🤝 Arkadaşlarına saygılı davran (patronluk taslamadan) | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Treat peers respectfully (no bossing them around) |
| 👫 Arkadaşlarını annen ya da babanla konuş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Daily check-in with parent(s) about friends |
| 💬 Bağırmadan nasıl hissettiğini anlat | KAB | Kolay | — | 6 ve altı, 7–9 | Tell others how you're feeling without yelling |
| 📞 Bir aile büyüğünü arayıp hâlini sor | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Call / FaceTime a family member to check in on them |
| ♟️ Bir aile üyenle satranç oyna | ABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Play a game of chess with family member |
| ✉️ Bir arkadaşına mektup yaz | ABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write a letter to a friend |
| 👫 Bir arkadaşınla vakit geçir | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Hang out with a friend |
| 💐 Bir teşekkür notu yaz | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Write a thank you note |
| 💝 Biri için güzel bir şey yap | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do something kind for someone |
| 🌞 Birine günaydın de! | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Tell someone good morning! |
| 🌸 Birine iltifat et | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Give a compliment to someone |
| 💌 Birine neden onu sevdiğini anlatan bir kart yap | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make a card for someone telling them why you appreciate them |
| 👋 Birini kibarca selamlamayı çalış | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Practice greeting someone politely |
| 💌 Birini mutlu edecek bir sürpriz not bırak | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Leave a happy surprise note for someone |
| 😄 Bugün birini gülümset | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make someone smile today |
| 🤝 Bugün kardeşine hiç vurma, itme | KAB | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Absolutely no physical violence to sibling today |
| 📕 En sevdiğin kitabı paylaş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Share your favorite book |
| 📸 Eğlenceli bir anını paylaş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Share a fun memory |
| 🏆 Gurur duyduğun 3 şeyi bul | ABC | Kolay | — | 13 ve üstü | Find 3 things you're proud of |
| 🤲 Kardeşin ya da arkadaşlarınla paylaş | KABC | Kolay | — | 6 ve altı, 7–9, 13 ve üstü | Share with siblings or friends |
| 💛 Kardeşine iyi davran | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Be nice to your sibling |
| 🧺 Kardeşinle açık havada piknik yap | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Have a outdoor picnic with your sibling |
| 🎈 Kardeşinle eğlenceli bir şey yap | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do a fun activity with your sibling |
| 🕊️ Kardeşinle kavga etme | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Dont fight with your sibling |
| 🎮 Kardeşinle oyun oyna | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Play a game with your sibling |
| 👾 Komik bir canavar yüzü yap | KAB | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make a silly monster face |
| 👀 Konuşurken söylenmeden göz teması kur | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Make eye contact in a conversation without being reminded |
| 👶 Küçük kardeşine göz kulak ol (bir büyüğün yanındayken) | BC | Zor | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Babysit younger sibling |
| 🙏 Lütfen ve teşekkür ederim de | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Say please and thank you |
| 🏫 Okulda bütün gün güzel davran | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Behave at school all day |
| ⏳ Oyunlarda sıranı bekle | KABC | Kolay | Odak ve Öz Denetim | 6 ve altı, 7–9, 10–12, 13 ve üstü | Wait your turn in games |
| 🎁 Rastgele bir iyilik yap | KABC | Orta | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Do a random act of kindness |
| 🙏 Teşekkür ettiğin bir şeyi çiz | KAB | Kolay | — | 10–12, 13 ve üstü | Draw something you're thankful for |
| 🧒 Yeni bir arkadaşla oyna | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Play with a new friend |
| 😊 İki farklı kişiye güzel bir söz söyleyip onları gülümset | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Say something nice to 2 different people to make them smile |
| 🤗 İyi arkadaş nasıl olur, ailenle konuş | KABC | Kolay | — | 6 ve altı, 7–9, 10–12, 13 ve üstü | Discuss what makes a good friend with parent(s) |
