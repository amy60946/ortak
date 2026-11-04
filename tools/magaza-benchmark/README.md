# Mağaza benchmark aracı

Rakiplerin App Store ekran görüntülerini indirip uygulama başına tek panoya dizer (ParentApp penceresi, 4 Kasım 2026).

- **Ağ:** Default ortamına `apps.apple.com`, `itunes.apple.com`, `is1-ssl.mzstatic.com` … `is5-ssl.mzstatic.com` eklendi (kullanıcı onayı, 4 Kasım 2026). Daha önce apps.apple.com kapalıydı (ClinicApp mağaza paketi, 2 Kasım: "rakip mağaza sayfaları doğrulanmadı").
- **Kullanım:** `python3 fetch_shots.py ara "<ad>"` ile kimlik bul → `gruplar.json` yaz → `python3 fetch_shots.py indir gruplar.json <scratchpad>/bench` (iPad görselleri için `IPAD=3`). Türkiye mağazası için ülke `tr`.
- **İnceleme:** panolar alt ajana verilir (kural 8). Uygulama başına sıra, düzen, güven sinyali, metin üslubu ve 1–5 puan (güven/kurumsal, tasarım, anlaşılırlık) istenir; sonunda aktarılacak 5 kalıp + kaçınılacaklar (`hukuk/45`).
- **Görseller rakibe aittir:** yalnız iç benchmark; depoya, yayına ya da paylaşılan sayfaya konmaz.

ParentApp'te nasıl kullanıldığı ve bulgular: `parent-app/store/README.md` (24 uygulama, 3 grup; Apple kuralları 4 Kasım 2026).
