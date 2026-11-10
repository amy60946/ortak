-- =====================================================================
-- ÖNERİLER CANLIDA MI? (kvkk_ops, support, legal_seed) — YALNIZ OKUR, hiçbir şeyi değiştirmez.
-- Kullanım: Supabase → SQL Editor → New query → tümünü yapıştır → Run. Çıkan tabloyu (5 satır) koordinatör penceresine yazın.
-- Sonuç 10 Kasım 2026: 4 × EVET, 12 / 12; üç dosya migrations/ altına taşındı.
-- Ne için: migrations/20261102200000_kvkk_ops.sql, 20261102210000_support.sql ve 20261102120747_legal_seed.sql
-- uygulanmış mı; uygulananlar migrations/'a taşınır, sonra 20261110120000_kvkk_export_v2.sql uygulanır.
-- Yasal metin özetleri legal_seed dosyasından üretildi (10 Kasım 2026); seed yeniden üretilirse bu dosya da yenilenir.
-- =====================================================================
with beklenen(key, version, ozet) as (
  values
    ('gizlilik', 'v1', '042c8a977adf5f24d24ed89dd4f18520'),
    ('aydinlatma-ebeveyn', 'v1', 'e7d28509436121265b999f44763e5349'),
    ('aydinlatma-cocuk', 'v1', '4a221e98237439834fe4bb5ed47a4112'),
    ('aydinlatma-uzman', 'v1', '2ca2157cb8cee9a62e7182a7cf3c6cf5'),
    ('kosullar-parentapp', 'v1', '205641c55c0065d4543c8239ada5016a'),
    ('kosullar-gameapp', 'v1', '819314fce315572ff594d8010640ae9e'),
    ('sozlesme-uzman', 'v1', '7342d9777df134e225e95bf057ab2529'),
    ('veri-isleme-eki', 'v1', '0073b9ec63554a97481fc9c48d99cd58'),
    ('acik-riza-metinleri', 'v1', '42f1137d9c8ac834a4f675dc0be68da0'),
    ('cerez-clinicapp-web', 'v1', 'b49cae25093e01bb24bcc8d420c8f5f3'),
    ('alt-isleyenler', 'v1', '2a8e89fab363de0d6d40b167ca75f1ce'),
    ('kvkk-basvuru', 'v1', '60f61e6a223bba2d91417ddb8f1ca9d9')
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
