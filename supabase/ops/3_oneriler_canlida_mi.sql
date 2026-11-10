-- =====================================================================
-- ÖNERİLER CANLIDA MI? (kvkk_ops, support, legal_seed) — YALNIZ OKUR, hiçbir şeyi değiştirmez.
-- Kullanım: Supabase → SQL Editor → New query → tümünü yapıştır → Run. Çıkan tabloyu (5 satır) koordinatör penceresine yazın.
-- İlk kullanım 10 Kasım 2026: kvkk_ops, support ve 20261102120747_legal_seed canlıda doğrulandı (4 × EVET, 12 / 12).
-- 5. satır artık 20261110212650_legal_seed.sql'e (alan adı ve Supabase bölgesi dolu) göre denetler: uygulanınca 12 / 12.
-- Yasal metin özetleri legal_seed dosyasından üretildi (10 Kasım 2026, 20261110212650); seed yeniden üretilirse bu dosya da yenilenir.
-- =====================================================================
with beklenen(key, version, ozet) as (
  values
    ('gizlilik', 'v1', '34f90ec52a7a62dbac73b6dd5eaa59e7'),
    ('aydinlatma-ebeveyn', 'v1', '060bd68523346ae0b1b6d3cfec356c21'),
    ('aydinlatma-cocuk', 'v1', '451702303223e0d067a958f9742cf6f6'),
    ('aydinlatma-uzman', 'v1', 'c7fdafa731dd3a5e56eab26550b529c2'),
    ('kosullar-parentapp', 'v1', 'eef4964be82f072c7f76f6c2abd62970'),
    ('kosullar-gameapp', 'v1', 'aff6ea9e4e19bfb8299e77b78aebdfee'),
    ('sozlesme-uzman', 'v1', '62581a8ed4334305c9c0c69364b9646c'),
    ('veri-isleme-eki', 'v1', 'd10fe6cdf2f44df6dd3d2006055d997b'),
    ('acik-riza-metinleri', 'v1', 'f7ce026fdd2d8c98c33d145783eacc5f'),
    ('cerez-clinicapp-web', 'v1', '50ff386d14c84233181ab7a46a461796'),
    ('alt-isleyenler', 'v1', '2c81ed2484fcfd87c2dcb8669f46c4aa'),
    ('kvkk-basvuru', 'v1', '7997300714864b48861bb238faaaa34f')
),
yasal as (
  select count(*) filter (where md5(d.body_md) = b.ozet) as eslesen,
         count(*) as toplam,
         coalesce(string_agg(b.key || coalesce(' (' || d.status || ')', ' (satır yok)'), ', ' order by b.key)
                  filter (where d.key is null or md5(d.body_md) <> b.ozet), '') as farkli
  from beklenen b
  left join public.legal_documents d on d.key = b.key and d.version = b.version
)
select 1 as sira, 'kvkk_ops: ops_health() işlevi var mı' as kontrol,
       case when to_regprocedure('public.ops_health()') is not null then 'EVET' else 'HAYIR' end as sonuc
union all
select 2, 'kvkk_ops: 3 Kasım sürümü mü (ops_health içinde offer_code_pool)',
       case when to_regprocedure('public.ops_health()') is null then 'HAYIR (işlev yok)'
            when pg_get_functiondef(to_regprocedure('public.ops_health()')::oid) like '%offer_code_pool%' then 'EVET'
            else 'HAYIR (eski sürüm)' end
union all
select 3, 'kvkk_ops: retention_runs tablosu var mı',
       case when to_regclass('public.retention_runs') is not null then 'EVET' else 'HAYIR' end
union all
select 4, 'support: support_requests tablosu var mı',
       case when to_regclass('public.support_requests') is not null then 'EVET' else 'HAYIR' end
union all
select 5, 'legal_seed: yasal metinler son taslakla aynı mı',
       eslesen || ' / ' || toplam || case when farkli = '' then ' (hepsi aynı)' else ' — farklı: ' || farkli end
from yasal
order by sira;
