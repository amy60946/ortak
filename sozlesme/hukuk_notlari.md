# Hukuk notları — uzman değişiminde kayıt aktarımı

> Taslak (26 Ekim 2026, kullanıcı isteği). Avukata gidecek **madde önerileridir, hukuki görüş değildir.** Canlıda açılmadan önce hukuk onayı gerekir. Yeri: `CANLIYA_ALMA.md` 1.5 (Uzman Hizmet Sözleşmesi + Veri İşleme Eki, Açık Rıza Metni, Aydınlatma Metni). Akış: `akislar.md` 11.

Amaç: ebeveyn çocuğunun takibini başka bir uzmana taşıdığında, önceki uzmanın kayıtları yeni uzmana kesintisiz geçebilsin; önceki uzmanın kimliği gizli kalsın. Bunun için iki dayanak birlikte gerekir: **uzmanın sözleşmeyle verdiği izin** ve **ebeveynin açık rızası**.

## 1. Ne aktarılır, ne gizlenir

| Kayıt | Kimin girdisi | Yeni uzmana | Gizlenen |
|---|---|---|---|
| Notlar | Önceki uzman | Salt okunur, tarihli | Uzman ve klinik adı (metinde geçerse "[önceki uzman]") |
| Hedefler ve haftalık değerlendirmeler | Önceki uzman | Salt okunur | Aynı |
| Görev önerileri ve ailenin kararı | Önceki uzman, ebeveyn | Salt okunur | Aynı |
| Aile programı ve uygulama kayıtları | Önceki uzman, ebeveyn | Salt okunur | Aynı |
| Önceki uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgisi | — | **Aktarılmaz** | Tamamı; yeni uzman "Önceki uzman 1" ve dönem (ay) görür |
| Görevler, tamamlamalar, zor anlar | Ebeveyn, çocuk | Paylaşım açılınca zaten görünür | — |
| Posta, coin defteri | Aile | Aktarılmaz | — |

## 2. Dayanak özeti (avukat doğrulayacak)

- **Özel nitelikli veri:** çocuğun davranış ve gelişim kayıtları ile uzman notları sağlık verisi sayılabilir (KVKK md. 6). Aktarımın dayanağı ebeveynin (veli) **açık rızası**; rıza belirli konuya ilişkin, bilgilendirmeye dayalı ve özgür iradeyle verilmeli.
- **Aydınlatma:** rıza ekranından önce kısa aydınlatma (amaç, alıcı, yöntem, haklar; KVKK md. 10).
- **Geri alma:** ebeveyn rızayı istediği an geri alır; erişim hemen biter (KVKK md. 11 hakları).
- **Ölçülülük:** önceki uzmanın kendi kişisel verisi (adı, unvanı, kliniği) aktarıma konu edilmez; yalnız çocuğa ilişkin kayıtlar geçer (KVKK md. 4).
- **Roller:** önerimiz, notlar için klinik/uzmanın **veri sorumlusu**, platformun **veri işleyen** olması. Uzman, sözleşmeyle "ebeveyn isterse kayıtların adsız olarak sonraki uzmana açılması" talimatını önceden verir. Alternatif: platform ve klinik ayrı veri sorumluları. Seçim avukatın.
- **Meslek etiği:** psikolog ve terapistlerin meslek etik kurallarının, danışan (veli) onayıyla kayıt paylaşımına izin verdiği meslek örgütüyle doğrulanmalı.

## 3. Taslak maddeler

### A. Uzman Hizmet Sözleşmesi + Veri İşleme Eki

1. **Kayıtların niteliği.** Uzmanın ClinicApp'e girdiği notlar, hedefler, değerlendirmeler, görev önerileri ve aile programı, ebeveynin rızasıyla paylaşılan çocuğa ilişkin kayıtlardır.
2. **Süreklilik için aktarım.** Ebeveyn çocuğun takibini başka bir uzmana taşıdığında ve açıkça izin verdiğinde, bu kayıtlar sonraki uzmana salt okunur olarak açılabilir. Uzman bu aktarıma izin verir.
3. **Kimliğin gizlenmesi.** Aktarımda uzmanın adı, unvanı, kliniği, iletişim ve kimlik bilgisi gösterilmez; kayıtlarda geçen uzman ve klinik adları otomatik gizlenir. Uzman, serbest metin alanlarına kendisinin ya da başka kişilerin kimlik bilgisini yazmamayı kabul eder.
4. **Değiştirilmezlik.** Sonraki uzman aktarılan kayıtları değiştiremez ve silemez; kayıtlar tarihleriyle, aktaran uzmanın o tarihteki gözlemi olarak gösterilir.
5. **Rızanın geri alınması.** Ebeveyn izni geri alınca sonraki uzmanın erişimi derhal sona erer.
6. **Hesabın kapanması.** Uzman hesabını silerse ya da klinik kapanırsa kayıtların akıbeti avukatla belirlenecek (bkz. 5. bölüm). Bugünkü sistem: tek kişilik klinik silinince kayıtları da silinir ve aktarım biter.
7. **Sorumluluk.** Aktarılan kayıtlar tanı değildir. Sonraki uzman kendi mesleki değerlendirmesinden sorumludur.
8. **Saklama.** Paylaşım bittikten sonra kayıtların saklama süresi ve imhası Veri İşleme Eki'nde yazılır.

### B. Ebeveyn açık rıza metni (ParentApp onay ekranı) — sürüm `uzman-gecis-v1`

> Çocuğum **[çocuğun adı]** için daha önce çalıştığım uzman(lar)ın ClinicApp'e girdiği notların, hedeflerin, haftalık değerlendirmelerin, görev önerilerinin, aile programının ve benim uygulama kayıtlarımın, takibin kesintisiz sürmesi amacıyla yeni uzmanım **[yeni uzmanın adı]** ile yalnız okunur olarak paylaşılmasına açık rıza veriyorum. Önceki uzmanın adı ve bilgileri yeni uzmana gösterilmez. Bu izni Uzmanım bölümünden istediğim an geri alabilirim; geri aldığımda erişim hemen sona erer.

Onay düğmesi: "Önceki uzmanın kayıtlarını da paylaş (adı gizlenir)". Metin değişirse sürüm adı da değişir (`uzman-gecis-v2` …); sistem hangi sürümün onaylandığını kaydeder.

### C. Aydınlatma metinlerine eklenecekler

- **Ebeveyn aydınlatması:** amaç (takibin sürekliliği), alıcı (ebeveynin seçtiği yeni uzman), aktarılan kayıt türleri (1. bölüm), yöntem (yalnız okuma, uygulama içinden), saklama, geri alma ve başvuru yolu (`kvkk@`).
- **Uzman aydınlatması:** uzmanın kişisel verisi (adı, unvanı, kliniği) aktarıma konu edilmez; girdiği kayıtlar ebeveyn izniyle adsız olarak sonraki uzmana açılabilir.

### D. Kullanım koşulları

- Platform tedavi ya da ebeveyn eğitimi vermez; uzmanın kendi programını kurması için şablon sunar. Göstergeler tanı değildir.

### E. Uygulama içi kısa metinler

- **ClinicApp › Notlar** (not alanının altında): "Ebeveyn izin verirse notların, adın gizlenerek çocuğun sonraki uzmanına okunur olarak açılabilir. Nota kimlik bilgisi yazma."
- **ClinicApp › devralınan kayıtlar:** "Önceki uzman 1 · Mart 2026 – Ekim 2026 · ebeveynin izniyle, yalnız okuma".
- **ParentApp › onay ekranı:** B'deki metin + düğme.

## 4. Sistemdeki karşılığı (öneri `proposed/20261026100000_family_invite_links.sql`)

| Gereklilik | Nasıl |
|---|---|
| Ebeveynin açık rızası, sürümlü | `redeem_clinic_invite_children(…, p_share_history, p_consent_version)`, `clinic_link_history_set(link, açık, sürüm)` → `clinic_link_history.consent_version`, `granted_by`, `granted_at` |
| Geri alınabilir | `clinic_link_history_set(link, false)` → kayıt silinir, erişim hemen biter |
| Önceki uzmanın kimliği gizli | Yeni uzman tablolara doğrudan erişemez; yalnız `clinic_inherited_records(link)`: ad, unvan, klinik ve kimlik dönmez, "Önceki uzman n" + dönem (ay) |
| Metinde geçen adlar | Klinik adı, o kliniğin uzman adları ve en az 3 harfli ad parçaları "[önceki uzman]" ile değiştirilir (en iyi çaba: yazım hatalı ya da kısaltılmış ad yakalanmaz) |
| Salt okuma | İşlev yalnız okur; tablolarda devralan uzmana yazma kuralı yok |
| Test | `test/test_family_invite_links.sql` 5. bölüm |

## 5. Avukata sorular

1. Notlar için veri sorumlusu kim: klinik mi, platform mu, ikisi mi?
2. Ebeveynin açık rızası tek başına yeterli mi, yoksa önceki uzmanın aktarım anında ayrıca bilgilendirilmesi gerekir mi? (Bugün bildirilmiyor; sözleşmede önceden izin var.)
3. Önceki uzman hesabını silerse çocuğa ilişkin kayıtlar silinmeli mi, yoksa saklama süresince ebeveynin rızasıyla aktarılabilir kalmalı mı?
4. Saklama süresi ve imha: paylaşım bittikten sonra kaç ay/yıl?
5. Veriler yurt dışında barındırılıyorsa (Supabase bölgesi) aktarım için standart sözleşme ve Kurul'a bildirim (`CANLIYA_ALMA.md` 1.6).
6. Çocuğun belli bir yaştan sonra (ör. 15+) kendi görüşünün alınması gerekir mi?
