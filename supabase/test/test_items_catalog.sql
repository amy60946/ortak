-- Katalog bekçisi: sunucunun fiyat listesi (game_items) = oyunun dükkânı (game-app Resources/Data/items.json).
-- Fiyatı sunucu belirler; oyun dükkânda items.json'ı gösterir. İkisi ayrışırsa gerçek sunucuda çocuk eşyayı alamaz
-- (unknown_item / level_locked) ya da ekranda başka fiyat görür (ekonomi.md §4, E9). Bu test, oyun deposu yanda
-- açıkken (Oyun penceresi: game-app + ortak) her eşyanın sunucuda aynı fiyat ve seviyeyle bulunduğunu,
-- sunucuda oyunda olmayan eşya kalmadığını denetler; fark varsa hepsini tek iletide listeler.
-- items.json yolu: GAME_ITEMS_JSON ortam değişkeni, yoksa ortak'ın yanındaki game-app klasörü (run.sh ORTAK_TEST_DIR verir).
-- Dosya bulunamazsa karşılaştırma atlanır (uyarı yazılır); komik eşyaların sabit listesi test_fancy_items.sql'de her zaman denetlenir.
\set ON_ERROR_STOP on

create schema if not exists tst;
create table tst.oyun (doc text not null);

\set oyun_esyalari `f="$GAME_ITEMS_JSON"; [ -n "$f" ] || f="$ORTAK_TEST_DIR/../../../game-app/Assets/_Pofi/Resources/Data/items.json"; if [ -r "$f" ]; then cat "$f"; fi`
insert into tst.oyun values (:'oyun_esyalari');

do $$
declare
  raw text := (select doc from tst.oyun);
  items jsonb;
  diffs text;
  n_game integer;
begin
  if raw is null or btrim(raw) = '' then
    raise warning 'KATALOG BEKÇİSİ ATLANDI: game-app items.json bulunamadı (GAME_ITEMS_JSON ile yol verilebilir)';
    return;
  end if;
  items := raw::jsonb -> 'items';
  if items is null or jsonb_typeof(items) <> 'array' then
    raise exception 'TEST BAŞARISIZ: items.json biçimi beklenmedik ("items" dizisi yok)';
  end if;

  -- satılan (fiyatı olan) eşyalar; seviye yazılmamışsa 1 (oyunun ItemDef.Level varsayılanı)
  create temp table oyun_esya on commit drop as
    select e ->> 'id' as item_id, (e ->> 'price')::integer as price,
           coalesce((e ->> 'level')::integer, 1) as min_level, coalesce((e ->> 'fancy')::boolean, false) as fancy
    from jsonb_array_elements(items) e
    where jsonb_typeof(e -> 'price') = 'number';
  select count(*) into n_game from oyun_esya;

  select string_agg(d, '; ' order by d) into diffs from (
    select 'sunucuda yok: ' || o.item_id || ' (' || o.price || ' coin, Sv ' || o.min_level || ')' as d
      from oyun_esya o left join public.game_items g using (item_id) where g.item_id is null
    union all
    select 'farklı: ' || o.item_id || ' oyun ' || o.price || '/Sv ' || o.min_level || ' ≠ sunucu ' || g.price || '/Sv ' || g.min_level
      from oyun_esya o join public.game_items g using (item_id)
      where g.price <> o.price or g.min_level <> o.min_level
    union all
    select 'oyunda yok: ' || g.item_id
      from public.game_items g left join oyun_esya o using (item_id) where o.item_id is null
  ) x;

  if diffs is not null then
    raise exception 'TEST BAŞARISIZ: sunucu kataloğu ile oyunun items.json''ı ayrıştı → %', diffs;
  end if;
  raise notice 'ok: katalog = items.json (% eşya, % komik eşya)', n_game, (select count(*) from oyun_esya where fancy);

  -- E9'un komik eşyaları oyunda hâlâ "fancy" ise sunucuda da olmalı (yukarıdaki genel denetimin özeti)
  if (select count(*) from oyun_esya where fancy) <> 19 then
    raise warning 'Not: items.json''daki komik eşya sayısı 19 değil (%); ekonomi.md §4 ve test_fancy_items.sql güncellenmeli',
      (select count(*) from oyun_esya where fancy);
  end if;
end $$;

select 'KATALOG BEKÇİSİ TESTİ BİTTİ' as sonuc;
