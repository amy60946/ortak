-- Destek kutusu (öneri, 22 Kasım 2026; kullanıcı kararları "Önerilerinle devam": 1A otomatik "alındı" yanıtı, 2A içeriksiz ekip
-- uyarısı, 3A ekler saklanmaz, 4A konu KVKK olunca 30 gün sayacı, 5A beş hazır yanıt). Tekrar çalıştırılabilir.
-- Önkoşul: migrations/20261102210000_support.sql, migrations/20261121100000_security_audit_fixes.sql,
--          migrations/20261121110000_support_invite_limits.sql.
-- Akış: destek@moyoapp.com.tr → Cloudflare Email Routing ("Send to a Worker": admin-panel) → Worker MIME'ı çözer →
--   Edge Function `support` POST /support/inbound (x-moyo-forward-key) → support_inbound_email (yalnız sunucu) →
--   support_requests + support_messages. Yanıt: panel → POST /support/reply (yöneticinin oturumu) → admin_support_reply
--   (yetki burada) → Resend → support_message_sent (yalnız sunucu).
-- Gizlilik: e-postanın düz metni (en çok 20 000 karakter) ve eklerin yalnız adı, boyutu, türü saklanır (içerik yok, karar 3A).
--   Mesaj gövdesi, ekler ve e-posta adresi denetim kaydına, bildirime, sağlık denetimine ve hata günlüğüne yazılmaz.
-- Saklama: mesajlar taleple birlikte silinir (on delete cascade). Her ileti talebin updated_at'ini yeniler; gece imha işi
--   (20261102200000_kvkk_ops.sql adım 25: yanıtlanan / kapanan 2 yıl, istenmeyen 30 gün, updated_at'ten) mesajları da kapsar.
-- Sözleşme: sozlesme/veritabani.md §39, sozlesme/admin.md "Destek", hukuk/46 Ek A.

do $$ begin
  if to_regclass('public.support_source_salts') is null then
    raise exception 'Önce migrations/20261121110000_support_invite_limits.sql çalıştırılmalı (destek kutusu onun üstüne kurulur)';
  end if;
  if to_regprocedure('public.finite_time_guard_attach()') is null then
    raise exception 'Önce migrations/20261121100000_security_audit_fixes.sql çalıştırılmalı (finite_time_guard_attach yok)';
  end if;
end $$;

-- =====================================================================
-- 1. support_requests: kanal, konu satırı, son ileti, KVKK süresi
-- =====================================================================
alter table public.support_requests add column if not exists channel text not null default 'form'
  check (channel in ('form', 'email'));
alter table public.support_requests add column if not exists subject text check (char_length(subject) <= 200);
alter table public.support_requests add column if not exists last_message_at timestamptz;
alter table public.support_requests add column if not exists kvkk_due_at timestamptz;
update public.support_requests set last_message_at = created_at where last_message_at is null;
update public.support_requests set kvkk_due_at = created_at + interval '30 days' where topic = 'privacy' and kvkk_due_at is null;
alter table public.support_requests alter column last_message_at set not null;
-- Mesaj: e-postada 1–3000 (kısa e-posta da talep olur), formda 10–3000 (eski kural)
alter table public.support_requests drop constraint if exists support_requests_message_check;
alter table public.support_requests drop constraint if exists support_requests_message_len;
alter table public.support_requests add constraint support_requests_message_len
  check (char_length(message) between case when channel = 'email' then 1 else 10 end and 3000);
create index if not exists support_requests_last_idx on public.support_requests (status, last_message_at);
create index if not exists support_requests_kvkk_idx on public.support_requests (kvkk_due_at) where topic = 'privacy';

-- =====================================================================
-- 2. support_messages: konuşma (gelen / giden / iç not)
-- =====================================================================
create table if not exists public.support_messages (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null references public.support_requests (id) on delete cascade,
  created_at   timestamptz not null default now(),
  direction    text not null check (direction in ('in', 'out', 'note')),
  auto         boolean not null default false,                      -- otomatik "alındı" yanıtı
  author       uuid references auth.users (id) on delete set null,  -- giden ve iç not: yazan ekip üyesi
  from_email   text check (char_length(from_email) <= 254),
  body         text not null check (char_length(body) between 1 and 20000),
  message_id   text check (char_length(message_id) between 1 and 500),   -- gelen iletinin Message-ID'si (köşeli ayraçsız)
  attachments  jsonb not null default '[]'::jsonb
               check (jsonb_typeof(attachments) = 'array' and jsonb_array_length(attachments) <= 20),   -- [{name, size, type}]
  auth         text check (auth in ('pass', 'fail', 'none')),       -- Cloudflare'ın SPF/DKIM/DMARC sonucu; yalnız e-postayla gelen
  send_status  text check (send_status in ('pending', 'sent', 'failed')),
  sent_at      timestamptz,
  send_error   text check (char_length(send_error) <= 80),
  constraint support_messages_auto_out check (not auto or direction = 'out'),
  constraint support_messages_send_out check ((direction = 'out') = (send_status is not null)),
  constraint support_messages_auth_in check (auth is null or direction = 'in')
);
comment on column public.support_messages.auth is
  'Yalnız e-postayla gelen iletide dolu (pass/fail/none); formdan gelen ilk iletide boş. Gelen e-posta sınırları bunu sayar.';
alter table public.support_messages enable row level security;
revoke all on public.support_messages from public, anon, authenticated;
-- Yinelenen teslim (Worker yeniden dener, Cloudflare iki kez verir) aynı Message-ID ile gelir
create unique index if not exists support_messages_message_id_key on public.support_messages (message_id) where message_id is not null;
create index if not exists support_messages_request_idx on public.support_messages (request_id, created_at);
create index if not exists support_messages_from_idx on public.support_messages (lower(from_email), created_at)
  where direction = 'in' and auth is not null;
create index if not exists support_messages_in_idx on public.support_messages (created_at) where direction = 'in' and auth is not null;
create index if not exists support_messages_out_idx on public.support_messages (created_at) where direction = 'out';

-- Sınır nedeniyle alınmayan gelen e-posta sayacı (saatlik; kişisel veri yok, yalnız sayı; 8 günden eskisi silinir).
create table if not exists public.support_inbound_drops (
  hour     timestamptz primary key,
  dropped  integer not null default 0 check (dropped >= 0)
);
alter table public.support_inbound_drops enable row level security;
revoke all on public.support_inbound_drops from public, anon, authenticated;

-- =====================================================================
-- 3. Hazır yanıtlar (karar 5A: beş tohum, panelden düzenlenir)
-- =====================================================================
create table if not exists public.support_canned_replies (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(title) between 1 and 80),
  body        text not null check (char_length(body) between 1 and 5000),
  position    integer not null default 0 check (position between 0 and 10000),
  updated_at  timestamptz not null default now()
);
alter table public.support_canned_replies enable row level security;
revoke all on public.support_canned_replies from public, anon, authenticated;

-- Tohum yalnız tablo boşsa (ikinci çalıştırma ve panelde silinenler geri gelmez)
insert into public.support_canned_replies (title, body, position)
select v.title, v.body, v.position
  from (values
    ('Şifre sıfırlama', E'Merhaba,\n\nGiriş ekranında "Şifremi unuttum"a dokunup hesabınızın e-postasını yazın; size bir bağlantı gelir. Bağlantı gelmezse istenmeyen klasörüne bakın.\n\nMoyo Destek', 1),
    ('Aboneliği iptal etme', E'Merhaba,\n\nAboneliğiniz App Store üzerinden yönetilir: iPhone › Ayarlar › adınız › Abonelikler › Moyo › Aboneliği İptal Et. Dönem sonuna kadar kullanmaya devam edersiniz.\n\nMoyo Destek', 2),
    ('Uygulama hatası', E'Merhaba,\n\nBildiriminiz için teşekkürler. Sorunu inceliyoruz; çözülünce bu adresten haber vereceğiz.\n\nMoyo Destek', 3),
    ('Uzman hesabı', E'Merhaba,\n\nMoyo Mercek uzman hesabı uzman.moyoapp.com.tr adresinden açılır; 14 gün ücretsiz denersiniz.\n\nMoyo Destek', 4),
    ('KVKK başvurusu alındı', E'Merhaba,\n\nKişisel verilerinizle ilgili başvurunuzu aldık. Yasal süre içinde, en geç 30 gün içinde yanıtlayacağız.\n\nMoyo Destek', 5)
  ) v (title, body, position)
 where not exists (select 1 from public.support_canned_replies);

-- =====================================================================
-- 4. Yardımcılar (yalnız sunucu içinde; kimse doğrudan çağıramaz)
-- =====================================================================
-- Tek satırlık alan (ad, konu, ek adı): denetim karakterleri ve satır ayırıcılar boşluk olur, boşluklar tekleşir, kırpılır
create or replace function public.support_clean_line(p text, p_max integer)
returns text language sql immutable set search_path = '' as $$
  select left(btrim(regexp_replace(regexp_replace(coalesce(p, ''), '[[:cntrl:]' || chr(8232) || chr(8233) || chr(65279) || ']', ' ', 'g'),
                                   '\s+', ' ', 'g')), greatest(coalesce(p_max, 0), 0))
$$;
revoke execute on function public.support_clean_line(text, integer) from public, anon, authenticated;

-- Gövde: satır sonları \n, sekme ve satır sonu dışındaki denetim karakterleri atılır, kırpılır, en çok p_max karakter
create or replace function public.support_clean_body(p text, p_max integer)
returns text language sql immutable set search_path = '' as $$
  select left(btrim(regexp_replace(regexp_replace(coalesce(p, ''), '\r\n?', E'\n', 'g'),
                                   '[\x01-\x08\x0b\x0c\x0e-\x1f\x7f' || chr(65279) || ']', '', 'g'), E' \t\n'),
              greatest(coalesce(p_max, 0), 0))
$$;
revoke execute on function public.support_clean_body(text, integer) from public, anon, authenticated;

-- Ekler: yalnız ilk 20 nesnenin adı (≤ 200), boyutu (bayt, sayı değilse boş) ve türü (tür/alt tür biçiminde değilse boş).
-- İçerik ya da başka alan saklanmaz (karar 3A).
create or replace function public.support_clean_attachments(p jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'name', public.support_clean_line(e ->> 'name', 200),
           'size', case when jsonb_typeof(e -> 'size') = 'number' and (e ->> 'size')::numeric between 0 and 1000000000000
                        then floor((e ->> 'size')::numeric)::bigint end,
           'type', case when lower(e ->> 'type') ~ '^[a-z0-9.+-]{1,60}/[a-z0-9.+-]{1,60}$' then lower(e ->> 'type') else '' end)
         order by t.n), '[]'::jsonb)
    from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) with ordinality t(e, n)
   where jsonb_typeof(t.e) = 'object' and t.n <= 20
$$;
revoke execute on function public.support_clean_attachments(jsonb) from public, anon, authenticated;

-- Yanıt konusu: "Re: <özgün konu ya da Destek talebiniz> [D-XXXXXX]". Konudaki bütün [D-…] numaraları ve baştaki
-- Re: / Ynt: / Fwd: / İlt: / AW: / SV: önekleri atılır; numara bir kez, sonda. En çok 200 karakter.
-- Edge Function'daki replySubject ile aynı kural (otomatik yanıtın konusu orada kurulur).
create or replace function public.support_reply_subject(p_subject text, p_ref text)
returns text language plpgsql immutable set search_path = '' as $$
declare
  s text := public.support_clean_line(p_subject, 998);
begin
  s := btrim(regexp_replace(regexp_replace(s, '\[\s*[Dd]-[A-Za-z0-9]{6}\s*\]', ' ', 'g'), '\s+', ' ', 'g'));
  while s ~* '^(re|ynt|yan[ıi]t|fwd?|[iİı]lt|aw|wg|sv|vs|antw|tr)\s*(\[[0-9]+\])?\s*:' loop
    s := btrim(substr(s, position(':' in s) + 1));
  end loop;
  if s = '' then s := 'Destek talebiniz'; end if;
  return 'Re: ' || btrim(left(s, 180)) || ' [' || p_ref || ']';
end $$;
revoke execute on function public.support_reply_subject(text, text) from public, anon, authenticated;

-- Yeni talep numarası (support_request_create'teki kuralla aynı: karışan harf/rakam yok)
create or replace function public.support_new_ref()
returns text language plpgsql volatile set search_path = '' as $$
declare
  r text;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  i integer;
begin
  loop
    r := 'D-';
    for i in 1..6 loop
      r := r || substr(alphabet, 1 + floor(random() * length(alphabet))::integer, 1);
    end loop;
    exit when not exists (select 1 from public.support_requests where ref = r);
  end loop;
  return r;
end $$;
revoke execute on function public.support_new_ref() from public, anon, authenticated;

-- Bizim alan adımız (moyoapp.com.tr ve alt alan adları): otomatik yanıt ve ekip uyarısı buraya gitmez (döngü)
create or replace function public.support_own_domain(p_email text)
returns boolean language sql immutable set search_path = '' as $$
  select coalesce(rtrim(lower(btrim(p_email)), '.') ~ '@([a-z0-9-]+\.)*moyoapp\.com\.tr$', false)
$$;
revoke execute on function public.support_own_domain(text) from public, anon, authenticated;

-- Otomatik "alındı" yanıtının metni (giden ileti olarak saklanır; Edge Function aynısını gönderir)
create or replace function public.support_ack_body(p_ref text)
returns text language sql immutable set search_path = '' as $$
  select 'Merhaba,' || E'\n\n'
      || 'İletinizi aldık. Talep numaranız: ' || p_ref || '. En kısa sürede bu adresten yanıt vereceğiz.' || E'\n\n'
      || 'Yanıtlarken konu satırındaki numarayı silmeyin; böylece yazışmanız aynı talepte kalır. Lütfen e-postayla şifre ya da '
      || 'kart bilgisi göndermeyin.' || E'\n\n'
      || 'Bu e-posta otomatik gönderildi.' || E'\n\n'
      || 'Moyo Destek'
$$;
revoke execute on function public.support_ack_body(text) from public, anon, authenticated;

-- Panel satırı: talep alanları (iki kaynak özeti ve ilgilenen hariç) + mesaj sayısı
create or replace function public.support_request_row(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select to_jsonb(r) - 'handled_by' - 'source_hash' - 'source_wide_hash'
         || jsonb_build_object('message_count', (select count(*) from public.support_messages m where m.request_id = r.id))
    from public.support_requests r where r.id = p_id
$$;
revoke execute on function public.support_request_row(uuid) from public, anon, authenticated;

-- =====================================================================
-- 5. Tetikleyiciler: varsayılanlar ve formun ilk iletisi
-- =====================================================================
-- last_message_at eklenirken created_at; konu privacy ise kvkk_due_at = created_at + 30 gün (formdan gelen ya da panelde
-- konusu değişen talep; KVKK süresi başvurunun ulaştığı günden işler). Konu privacy'den çıkınca sayaç kalkar.
create or replace function public.support_requests_defaults()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.last_message_at := coalesce(new.last_message_at, new.created_at);
  end if;
  if new.topic = 'privacy' then
    new.kvkk_due_at := coalesce(new.kvkk_due_at, new.created_at + interval '30 days');
  else
    new.kvkk_due_at := null;
  end if;
  return new;
end $$;
revoke execute on function public.support_requests_defaults() from public, anon, authenticated;
drop trigger if exists support_requests_defaults on public.support_requests;
create trigger support_requests_defaults before insert or update of topic on public.support_requests
  for each row execute function public.support_requests_defaults();

-- Formdan gelen talebin mesajı konuşmanın ilk gelen iletisi olur (e-posta talebinin iletisini support_inbound_email yazar)
create or replace function public.support_requests_first_message()
returns trigger language plpgsql set search_path = '' as $$
begin
  insert into public.support_messages (request_id, created_at, direction, from_email, body)
  values (new.id, new.created_at, 'in', new.email, new.message);
  return null;
end $$;
revoke execute on function public.support_requests_first_message() from public, anon, authenticated;
drop trigger if exists support_requests_first_message on public.support_requests;
create trigger support_requests_first_message after insert on public.support_requests
  for each row when (new.channel = 'form') execute function public.support_requests_first_message();

-- Var olan form taleplerinin ilk iletisi (yoksa)
insert into public.support_messages (request_id, created_at, direction, from_email, body)
select r.id, r.created_at, 'in', r.email, r.message
  from public.support_requests r
 where r.channel = 'form' and not exists (select 1 from public.support_messages m where m.request_id = r.id);

-- =====================================================================
-- 6. Gelen e-posta (yalnız sunucu: Edge Function `support` /support/inbound)
-- =====================================================================
-- Dönüş: {"ok":true,"ref","request_id","new","reopened","ack","ack_message_id","ack_body","notify"}
--        {"ok":true,"duplicate":true,"ref",…}  (aynı Message-ID: hiçbir şey yazılmaz)
--        {"ok":false,"error":"invalid" | "dropped"}
-- Kurallar:
--   · Eşleşme: konudaki [D-XXXXXX] numaralarından gönderenle aynı e-postalı (küçük harf) ilk talep; yoksa References /
--     In-Reply-To'daki bir Message-ID aynı gönderenin bir talebindeki gelen iletiye aitse o talep; ikisi de yoksa yeni talep.
--     Başkasının numarasını yazan yeni talep açar (başkasının konuşmasına ileti eklenemez).
--   · Sınır (yalnız e-postayla gelen iletiler sayılır, 24 saat): aynı adresten 20'den sonra ileti "istenmeyen" talebe yazılır
--     (gövde 2000'de kesilir; aynı gün açılmış "istenmeyen" talebine eklenir, yoksa yeni; yanıt ve uyarı yok); aynı adresten
--     100'den ya da bütün sistemde 2000'den sonra yazılmaz ("dropped", saatlik sayaç support_inbound_drops).
--   · Eski konuşma: durum answered/closed ise new (yeniden açılır), spam ise kalır.
--   · Otomatik yanıt (ack): yeni talep, otomatik ileti değil, gönderen bizim alan adımız değil, gönderen doğrulaması "fail" değil
--     (sahte gönderene geri saçılma olmasın) ve o adrese son 24 saatte 3'ten az otomatik yanıt gitmişse.
--   · Uyarı (notify): yeni talepte ve yeniden açılmada; istenmeyende yok.
-- Sayım ve kayıt yarışsız: Message-ID → gönderen → bütün sistem danışma kilitleri (sabit sıra; adres bellekte, yazılmaz).
create or replace function public.support_inbound_email(p_from text, p_from_name text, p_subject text, p_body text,
                                                        p_message_id text, p_refs text, p_attachments jsonb, p_auto boolean,
                                                        p_auth text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  em text := lower(btrim(coalesce(p_from, '')));
  nm text := public.support_clean_line(p_from_name, 80);
  full_subj text := public.support_clean_line(p_subject, 998);
  subj text := nullif(public.support_clean_line(p_subject, 200), '');
  body text := public.support_clean_body(p_body, 20000);
  mid text := nullif(left(btrim(coalesce(p_message_id, ''), E' \t\r\n<>'), 500), '');
  au text := case when p_auth in ('pass', 'fail', 'none') then p_auth else 'none' end;
  att jsonb := public.support_clean_attachments(p_attachments);
  is_auto boolean := coalesce(p_auto, false);
  n_from integer;
  n_all integer;
  spam boolean;
  req public.support_requests%rowtype;
  x text;
  refs text[];
  is_new boolean := false;
  reopened boolean := false;
  ack boolean := false;
  ack_id uuid;
  ack_text text;
begin
  if char_length(em) not between 6 and 254 or em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  if body = '' then body := '(boş ileti)'; end if;

  if mid is not null then perform pg_advisory_xact_lock(hashtext('support:inbound_mid'), hashtext(mid)); end if;
  perform pg_advisory_xact_lock(hashtext('support:inbound_from'), hashtext(em));
  perform pg_advisory_xact_lock(hashtext('support:inbound_pool'), 0);

  -- yinelenen teslim
  if mid is not null then
    select r.* into req from public.support_messages m join public.support_requests r on r.id = m.request_id
     where m.message_id = mid;
    if found then
      return jsonb_build_object('ok', true, 'duplicate', true, 'ref', req.ref, 'request_id', req.id, 'new', false,
                                'reopened', false, 'ack', false, 'ack_message_id', null, 'notify', false);
    end if;
  end if;

  select count(*) into n_from from public.support_messages
   where direction = 'in' and auth is not null and lower(from_email) = em and created_at > now() - interval '24 hours';
  select count(*) into n_all from public.support_messages
   where direction = 'in' and auth is not null and created_at > now() - interval '24 hours';
  if n_from >= 100 or n_all >= 2000 then
    insert into public.support_inbound_drops (hour, dropped) values (date_trunc('hour', now()), 1)
      on conflict (hour) do update set dropped = public.support_inbound_drops.dropped + 1;
    delete from public.support_inbound_drops where hour < now() - interval '8 days';
    return jsonb_build_object('ok', false, 'error', 'dropped');
  end if;
  spam := n_from >= 20;

  if spam then
    body := left(body, 2000);
    select * into req from public.support_requests
     where lower(email) = em and channel = 'email' and status = 'spam' and last_message_at > now() - interval '24 hours'
     order by last_message_at desc limit 1 for update;
  else
    -- 1) konudaki numara, aynı gönderen
    for x in select upper(m[1]) from regexp_matches(full_subj, '\[\s*([Dd]-[A-Za-z0-9]{6})\s*\]', 'g') as m limit 10 loop
      select * into req from public.support_requests where ref = x and lower(email) = em for update;
      exit when found;
    end loop;
    -- 2) References / In-Reply-To: aynı gönderenin talebindeki gelen ileti
    if req.id is null then
      refs := array(select t[1] from regexp_matches(left(coalesce(p_refs, ''), 8000), '<([^<>[:space:]]+)>', 'g') as t
                     where char_length(t[1]) <= 500 limit 50);
      if cardinality(refs) > 0 then
        select r.* into req from public.support_messages m join public.support_requests r on r.id = m.request_id
         where m.message_id = any (refs) and m.direction = 'in' and lower(r.email) = em
         order by m.created_at desc limit 1;
        if found then
          select * into req from public.support_requests where id = req.id for update;
        end if;
      end if;
    end if;
  end if;

  if req.id is not null then
    reopened := req.status in ('answered', 'closed');
    insert into public.support_messages (request_id, direction, from_email, body, message_id, attachments, auth)
    values (req.id, 'in', em, body, mid, att, au);
    update public.support_requests
       set status = case when reopened then 'new' else status end, last_message_at = now(), updated_at = now()
     where id = req.id;
  else
    is_new := true;
    insert into public.support_requests (ref, app, topic, email, name, message, status, channel, subject, last_message_at)
    values (public.support_new_ref(), 'other', 'other', em, nm, left(body, 3000), case when spam then 'spam' else 'new' end,
            'email', subj, now())
    returning * into req;
    insert into public.support_messages (request_id, direction, from_email, body, message_id, attachments, auth)
    values (req.id, 'in', em, body, mid, att, au);
    ack := not spam and not is_auto and au <> 'fail' and not public.support_own_domain(em)
           and (select count(*) from public.support_messages m join public.support_requests r on r.id = m.request_id
                 where r.email = em and m.direction = 'out' and m.auto and m.created_at > now() - interval '24 hours') < 3;
    if ack then
      ack_text := public.support_ack_body(req.ref);
      insert into public.support_messages (request_id, created_at, direction, auto, body, send_status)
      values (req.id, clock_timestamp(), 'out', true, ack_text, 'pending')
      returning id into ack_id;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'ref', req.ref, 'request_id', req.id, 'new', is_new, 'reopened', reopened,
                            'ack', ack, 'ack_message_id', ack_id, 'ack_body', ack_text,
                            'notify', not spam and req.status <> 'spam' and (is_new or reopened));
end $$;
revoke execute on function public.support_inbound_email(text, text, text, text, text, text, jsonb, boolean, text)
  from public, anon, authenticated;
grant execute on function public.support_inbound_email(text, text, text, text, text, text, jsonb, boolean, text) to service_role;

-- Gönderim sonucu (yalnız sunucu): bekleyen giden iletiye bir kez yazılır. Gönderilemeyen insan yanıtında talep işlemde'ye döner
-- (yanıt kişiye ulaşmadı). Hata yalnız kısa kod (harf, rakam, _ . : -; en çok 80).
create or replace function public.support_message_sent(p_message uuid, p_ok boolean, p_error text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  ok boolean := coalesce(p_ok, false);
  m public.support_messages%rowtype;
begin
  update public.support_messages
     set send_status = case when ok then 'sent' else 'failed' end,
         sent_at = case when ok then now() end,
         send_error = case when ok then null
                           else coalesce(nullif(left(btrim(regexp_replace(coalesce(p_error, ''), '[^A-Za-z0-9_.:-]+', '_', 'g'), '_'), 80), ''),
                                         'error') end
   where id = p_message and direction = 'out' and send_status = 'pending'
  returning * into m;
  if found and not ok and not m.auto then
    update public.support_requests set status = 'in_progress', updated_at = now()
     where id = m.request_id and status in ('answered', 'closed');
  end if;
end $$;
revoke execute on function public.support_message_sent(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.support_message_sent(uuid, boolean, text) to service_role;

-- =====================================================================
-- 7. Panel (destek rolü ve sahip, iki adımlı giriş; yetki admin_require'da)
-- =====================================================================
-- Kuyruk: 'open' (yeni + işlemde), 'answered', 'closed', 'spam', 'all', 'kvkk' (konu privacy, kapanmamış ve istenmeyen
-- olmayan; KVKK süresine göre en yakın önce). Öteki sekmeler son iletiye göre en yeni önce. Kaynak özetleri dönmez.
-- Önceki tanım: migrations/20261121110000_support_invite_limits.sql (yalnız sekme, sıralama ve yeni alanlar eklendi).
create or replace function public.admin_support_requests(p_status text default 'open', p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  st text := coalesce(p_status, 'open');
  lim integer := greatest(1, least(coalesce(p_limit, 100), 500));
begin
  perform public.admin_require(array['support']);
  return coalesce((
    select jsonb_agg(to_jsonb(s) - 'handled_by' - 'source_hash' - 'source_wide_hash' - 'k'
                     order by s.k nulls last, s.last_message_at desc, s.created_at desc)
      from (select r.*, (select count(*) from public.support_messages m where m.request_id = r.id) as message_count,
                   case when st = 'kvkk' then r.kvkk_due_at end as k
              from public.support_requests r
             where case when st = 'open' then r.status in ('new', 'in_progress')
                        when st = 'all' then true
                        when st = 'kvkk' then r.topic = 'privacy' and r.status not in ('closed', 'spam')
                        else r.status = st end
             order by case when st = 'kvkk' then r.kvkk_due_at end nulls last, r.last_message_at desc, r.created_at desc
             limit lim) s), '[]'::jsonb);
end $$;
revoke execute on function public.admin_support_requests(text, integer) from public, anon;
grant execute on function public.admin_support_requests(text, integer) to authenticated;

-- Konuşma: talep (liste alanları + iç not), iletiler (eskiden yeniye), aynı e-postadan öteki talepler (en çok 10, en yeni önce),
-- hesap (aynı e-postayla kayıtlı ebeveyn / uzman / ikisi; yoksa kind null)
create or replace function public.admin_support_thread(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  r public.support_requests%rowtype;
  uid uuid;
  is_c boolean;
  is_p boolean;
  kind text;
begin
  perform public.admin_require(array['support']);
  select * into r from public.support_requests where id = p_id;
  if not found then raise exception 'Talep bulunamadı'; end if;
  select u.id, exists (select 1 from public.clinicians c where c.id = u.id), exists (select 1 from public.profiles p where p.id = u.id)
    into uid, is_c, is_p
    from auth.users u where lower(u.email) = r.email and not coalesce(u.is_anonymous, false)
   order by u.created_at limit 1;
  kind := case when is_c and is_p then 'both' when is_c then 'clinician' when is_p then 'parent' end;
  return jsonb_build_object(
    'request', public.support_request_row(r.id),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', m.id, 'created_at', m.created_at, 'direction', m.direction, 'auto', m.auto,
               'author_name', case when m.auto then 'Moyo Destek'
                                   when m.author is not null then coalesce(nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
                                                                           nullif(btrim(u.raw_user_meta_data ->> 'nickname'), ''), 'Ekip üyesi')
                                   when m.direction = 'in' and lower(m.from_email) = r.email then nullif(r.name, '') end,
               'from_email', m.from_email, 'body', m.body, 'attachments', m.attachments, 'auth', m.auth,
               'send_status', m.send_status, 'send_error', m.send_error)
             order by m.created_at, case m.direction when 'in' then 0 when 'out' then 1 else 2 end, m.id)
        from public.support_messages m left join auth.users u on u.id = m.author
       where m.request_id = r.id), '[]'::jsonb),
    'previous', coalesce((
      select jsonb_agg(jsonb_build_object('id', o.id, 'ref', o.ref, 'created_at', o.created_at, 'status', o.status, 'subject', o.subject)
                       order by o.created_at desc)
        from (select * from public.support_requests x where lower(x.email) = r.email and x.id <> r.id
               order by x.created_at desc limit 10) o), '[]'::jsonb),
    'account', jsonb_build_object('kind', kind, 'user_id', case when kind is not null then uid end));
end $$;
revoke execute on function public.admin_support_thread(uuid) from public, anon;
grant execute on function public.admin_support_thread(uuid) to authenticated;

-- Yanıt: giden ileti (bekliyor), durum answered ya da closed; Edge Function gönderir ve support_message_sent'i çağırır.
-- Dönüş {message_id, to, subject, ref, body, name}. Boş gövde ya da istenmeyen talep → hata. Denetim kaydında gövde ve e-posta yok.
create or replace function public.admin_support_reply(p_id uuid, p_body text, p_close boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  b text := public.support_clean_body(p_body, 20001);
  r public.support_requests%rowtype;
  st text := case when coalesce(p_close, false) then 'closed' else 'answered' end;
  mid uuid;
begin
  if b = '' then raise exception 'Yanıt boş olamaz'; end if;
  if char_length(b) > 20000 then raise exception 'Yanıt en çok 20 000 karakter'; end if;
  select * into r from public.support_requests where id = p_id for update;
  if not found then raise exception 'Talep bulunamadı'; end if;
  if r.status = 'spam' then raise exception 'İstenmeyen olarak işaretli talebe yanıt gönderilmez; önce durumunu değiştir'; end if;
  insert into public.support_messages (request_id, direction, author, body, send_status)
  values (r.id, 'out', me, b, 'pending') returning id into mid;
  update public.support_requests
     set status = st, answered_at = coalesce(answered_at, now()), handled_by = me, updated_at = now(), last_message_at = now()
   where id = r.id;
  perform public.admin_log(me, 'support.reply', 'system', 'support:' || r.ref, 'Destek yanıtı gönderildi',
                           jsonb_build_object('status', r.status), jsonb_build_object('status', st));
  return jsonb_build_object('message_id', mid, 'to', r.email, 'subject', public.support_reply_subject(r.subject, r.ref),
                            'ref', r.ref, 'body', b, 'name', nullif(r.name, ''));
end $$;
revoke execute on function public.admin_support_reply(uuid, text, boolean) from public, anon;
grant execute on function public.admin_support_reply(uuid, text, boolean) to authenticated;

-- İç not (yalnız ekip görür; kişiye gitmez). Denetim kaydında not metni yok.
create or replace function public.admin_support_note(p_id uuid, p_body text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  b text := public.support_clean_body(p_body, 20001);
  r public.support_requests%rowtype;
  m public.support_messages%rowtype;
begin
  if b = '' then raise exception 'Not boş olamaz'; end if;
  if char_length(b) > 20000 then raise exception 'Not en çok 20 000 karakter'; end if;
  select * into r from public.support_requests where id = p_id for update;
  if not found then raise exception 'Talep bulunamadı'; end if;
  insert into public.support_messages (request_id, direction, author, body) values (r.id, 'note', me, b) returning * into m;
  update public.support_requests set updated_at = now() where id = r.id;
  perform public.admin_log(me, 'support.note', 'system', 'support:' || r.ref, 'İç not eklendi');
  return jsonb_build_object('message_id', m.id, 'created_at', m.created_at);
end $$;
revoke execute on function public.admin_support_note(uuid, text) from public, anon;
grant execute on function public.admin_support_note(uuid, text) to authenticated;

-- Durum, iç not ve (yeni) konu. Konu privacy olunca KVKK süresi kurulur (tetikleyici). Durum boşsa değişmez.
-- Önceki tanım: migrations/20261102210000_support.sql (4 parametre); eski çağrı biçimi aynen çalışır (p_topic varsayılanı null).
drop function if exists public.admin_support_update(uuid, text, text, text);
create or replace function public.admin_support_update(p_id uuid, p_status text, p_note text, p_reason text, p_topic text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  old record;
  st text;
  tp text;
begin
  if p_status is not null and p_status not in ('new', 'in_progress', 'answered', 'closed', 'spam') then raise exception 'Geçersiz durum'; end if;
  if p_topic is not null and p_topic not in ('account', 'subscription', 'bug', 'privacy', 'clinic', 'other') then
    raise exception 'Geçersiz konu';
  end if;
  if char_length(coalesce(p_note, '')) > 2000 then raise exception 'Not en çok 2000 karakter'; end if;
  select * into old from public.support_requests where id = p_id for update;
  if not found then raise exception 'Talep bulunamadı'; end if;
  st := coalesce(p_status, old.status);
  tp := coalesce(p_topic, old.topic);
  update public.support_requests
     set status = st, topic = tp, note = nullif(trim(coalesce(p_note, '')), ''), handled_by = me, updated_at = now(),
         answered_at = case when st = 'answered' then coalesce(answered_at, now()) else answered_at end
   where id = p_id;
  perform public.admin_log(me, 'support.update', 'system', 'support:' || old.ref, p_reason,
                           jsonb_build_object('status', old.status, 'topic', old.topic), jsonb_build_object('status', st, 'topic', tp));
end $$;
revoke execute on function public.admin_support_update(uuid, text, text, text, text) from public, anon;
grant execute on function public.admin_support_update(uuid, text, text, text, text) to authenticated;

-- Hazır yanıtlar: liste
create or replace function public.admin_support_canned()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require(array['support']);
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'body', c.body, 'position', c.position,
                                                       'updated_at', c.updated_at) order by c.position, c.title, c.id)
                     from public.support_canned_replies c), '[]'::jsonb);
end $$;
revoke execute on function public.admin_support_canned() from public, anon;
grant execute on function public.admin_support_canned() to authenticated;

-- Ekle (p_id null) ya da düzenle; gerekçeli, denetim kaydında başlık ve sıra (metin yok). En çok 100 hazır yanıt.
create or replace function public.admin_support_canned_save(p_id uuid, p_title text, p_body text, p_position integer, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  t text := public.support_clean_line(p_title, 81);
  b text := public.support_clean_body(p_body, 5001);
  old public.support_canned_replies%rowtype;
  pos integer;
  rid uuid;
begin
  if t = '' or char_length(t) > 80 then raise exception 'Başlık 1–80 karakter olmalı'; end if;
  if b = '' or char_length(b) > 5000 then raise exception 'Metin 1–5000 karakter olmalı'; end if;
  if p_position is not null and p_position not between 0 and 10000 then raise exception 'Geçersiz sıra'; end if;
  if p_id is null then
    if (select count(*) from public.support_canned_replies) >= 100 then raise exception 'En çok 100 hazır yanıt'; end if;
    pos := coalesce(p_position, (select coalesce(max(position), 0) + 1 from public.support_canned_replies));
    insert into public.support_canned_replies (title, body, position) values (t, b, least(pos, 10000)) returning id into rid;
    perform public.admin_log(me, 'support.canned_save', 'system', 'support_canned:' || rid, p_reason,
                             null, jsonb_build_object('title', t, 'position', least(pos, 10000)));
  else
    select * into old from public.support_canned_replies where id = p_id for update;
    if not found then raise exception 'Hazır yanıt bulunamadı'; end if;
    pos := coalesce(p_position, old.position);
    update public.support_canned_replies set title = t, body = b, position = pos, updated_at = now() where id = p_id;
    rid := p_id;
    perform public.admin_log(me, 'support.canned_save', 'system', 'support_canned:' || rid, p_reason,
                             jsonb_build_object('title', old.title, 'position', old.position), jsonb_build_object('title', t, 'position', pos));
  end if;
  return rid;
end $$;
revoke execute on function public.admin_support_canned_save(uuid, text, text, integer, text) from public, anon;
grant execute on function public.admin_support_canned_save(uuid, text, text, integer, text) to authenticated;

create or replace function public.admin_support_canned_delete(p_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  old public.support_canned_replies%rowtype;
begin
  delete from public.support_canned_replies where id = p_id returning * into old;
  if not found then raise exception 'Hazır yanıt bulunamadı'; end if;
  perform public.admin_log(me, 'support.canned_delete', 'system', 'support_canned:' || p_id, p_reason,
                           jsonb_build_object('title', old.title, 'position', old.position), null);
end $$;
revoke execute on function public.admin_support_canned_delete(uuid, text) from public, anon;
grant execute on function public.admin_support_canned_delete(uuid, text) to authenticated;

-- =====================================================================
-- 8. Sistem sağlığı (son tanım burada; önceki: migrations/20261121100000_security_audit_fixes.sql (c)).
--    Yeni: 'support_mail' (son 24 saatte gönderilemeyen ya da 15 dakikadır bekleyen giden ileti, ya da sınır nedeniyle
--    alınmayan gelen e-posta → sarı; ayrıntıda yalnız sayı). 'support': yeniden açılan talep eski sayılmasın diye
--    "2 günden uzun yanıtsız" son iletiye (last_message_at) göre sayılır.
-- =====================================================================
create or replace function public.ops_health()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  checks jsonb := '[]'::jsonb;
  r record;
  n bigint;
  m bigint;
  k bigint;
  t timestamptz;
  cfg jsonb := coalesce((select value from public.app_config where key = 'retention'), '{}'::jsonb);
  worst text := 'ok';
  lvl text;
begin
  -- zamanlayıcı (pg_cron): son çalışması hata veren iş
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    begin
      execute $q$select count(*) filter (where d.status = 'failed'), count(*) from cron.job j
                   left join lateral (select status from cron.job_run_details x where x.jobid = j.jobid
                                       order by x.start_time desc limit 1) d on true$q$ into n, m;
      checks := checks || jsonb_build_array(jsonb_build_object('key', 'cron', 'level', case when n > 0 then 'fail' else 'ok' end,
        'label', 'Zamanlayıcı', 'detail', case when n > 0 then n || ' işin son çalışması hata verdi' else m || ' iş tanımlı' end));
    exception when others then
      checks := checks || jsonb_build_array(jsonb_build_object('key', 'cron', 'level', 'warn', 'label', 'Zamanlayıcı',
        'detail', 'İş listesi okunamadı'));
    end;
  else
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'cron', 'level', 'warn', 'label', 'Zamanlayıcı',
      'detail', 'pg_cron açık değil: gece imha işi ve davet süresi bildirimi kendiliğinden çalışmaz'));
  end if;

  -- imha işi: son gece çalışması
  select * into r from public.retention_runs where trigger = 'cron' order by started_at desc limit 1;
  if not found then
    lvl := 'warn';
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'retention', 'level', lvl, 'label', 'İmha işi',
      'detail', 'Gece işi henüz hiç çalışmadı'));
  else
    lvl := case when r.ok is false then 'fail'
                when r.finished_at is null and r.started_at < now() - interval '1 hour' then 'fail'
                when r.started_at < now() - interval '26 hours' then 'warn' else 'ok' end;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'retention', 'level', lvl, 'label', 'İmha işi',
      'detail', case when r.ok is false then 'Son çalışmada hata: ' || jsonb_array_length(r.errors) || ' adım'
                     when lvl = 'warn' then 'Son 26 saatte çalışmadı'
                     else 'Son çalışma ' || to_char(r.started_at at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') end
                || case when coalesce((cfg ->> 'live')::boolean, false) then '' else ' · kuru çalıştırma (yalnız sayıyor)' end,
      'at', r.started_at));
  end if;

  -- KVKK başvuruları: 30 günlük yasal süre
  select count(*) filter (where due_at < now()), count(*) filter (where due_at < now() + interval '7 days'), count(*)
    into n, m, k from public.kvkk_requests where status in ('received', 'in_progress');
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'kvkk', 'label', 'KVKK başvuruları',
    'level', case when n > 0 then 'fail' when m > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' başvurunun yasal süresi geçti'
                   when m > 0 then m || ' başvurunun süresi 7 gün içinde doluyor'
                   else k || ' açık başvuru' end));

  -- uzman belgeleri: 3 günden uzun bekleyen
  select count(*) into n from public.clinician_verifications
   where status = 'pending' and coalesce(submitted_at, created_at) < now() - interval '3 days';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'verifications', 'label', 'Uzman belgeleri',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' belge 3 günden uzun süredir bekliyor' else 'Bekleyen eski belge yok' end));

  -- klinik denemeleri: 3 gün içinde biten (üyelik ödemesi canlı değilse panelden uzatılır)
  select count(*) into n from public.clinics where plan = 'trial' and trial_ends_at between now() and now() + interval '3 days';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'clinic_trials', 'label', 'Klinik denemeleri',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' kliniğin denemesi 3 gün içinde bitiyor' else '3 gün içinde biten deneme yok' end));

  -- abonelik olayları (billing-webhook): son olay; ödeme açıkken 14 gün sessizlik uyarı
  select greatest((select max(created_at) from public.billing_events where source = 'revenuecat'),
                  (select max(updated_at) from public.family_subscriptions where source = 'revenuecat')) into t;
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'billing', 'label', 'Abonelik bildirimleri',
    'level', case when coalesce((select (value ->> 'enforce')::boolean from public.app_config where key = 'billing'), false)
                       and (t is null or t < now() - interval '14 days') then 'warn'
                  when t is null then 'info' else 'ok' end,
    'detail', case when t is null then 'Henüz RevenueCat olayı gelmedi'
                   else 'Son olay ' || to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI') end,
    'at', t));

  -- anlık bildirim: Apple anahtarı olan kullanıcıya 10 dakikadır gönderilmemiş bildirim (son 24 saat)
  select count(*) into n from public.notifications x
   where x.created_at between now() - interval '24 hours' and now() - interval '10 minutes' and x.apns_sent_at is null and x.push
     and exists (select 1 from public.push_tokens p where p.user_id = x.user_id and p.app = x.app and p.token not like 'ExponentPushToken%');
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'push', 'label', 'Anlık bildirim',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' bildirim Apple''a gönderilmemiş (push-apns / PUSH_SECRET)' else 'Bekleyen gönderim yok' end));

  -- sunucu işlevi çağrıları (pg_net): son 6 saatte hata
  if exists (select 1 from pg_namespace where nspname = 'net') then
    begin
      execute $q$select count(*) filter (where status_code >= 500 or error_msg is not null), count(*) from net._http_response$q$ into n, m;
      checks := checks || jsonb_build_array(jsonb_build_object('key', 'net', 'label', 'Sunucu işlevi çağrıları',
        'level', case when n > 0 then 'warn' else 'ok' end,
        'detail', case when n > 0 then n || ' / ' || m || ' çağrı hata verdi (son 6 saat)' else m || ' çağrı, hata yok (son 6 saat)' end));
    exception when others then null;
    end;
  end if;

  -- destek talepleri (20261102210000_support.sql uygulanmışsa): 2 günden uzun yanıtsız (son iletiden; yeniden açılan talep
  -- eski sayılmaz, 20261122100000_support_inbox.sql)
  if to_regclass('public.support_requests') is not null then
    execute $q$select count(*) filter (where status = 'new' and last_message_at < now() - interval '2 days'),
                      count(*) filter (where status in ('new', 'in_progress'))
                 from public.support_requests$q$ into n, m;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'support', 'label', 'Destek talepleri',
      'level', case when n > 0 then 'warn' else 'ok' end,
      'detail', case when n > 0 then n || ' talep 2 günden uzun süredir yanıtsız' else m || ' açık talep' end));
  end if;

  -- destek formu kaynağı (20261121110000_support_invite_limits.sql uygulanmışsa): son 24 saatte kaynaksız gelen ("istenmeyen"
  -- olmayan) talep, kurulumun eksik olduğunu gösterir (SUPPORT_FORWARD_KEY yok ya da eski `support` işlevi yayında). O durumda
  -- bütün form saatte 30 talepten (KVKK 10) oluşan tek kaynaksız kovayı paylaşır; tek kişi kovayı doldurup formu kapatabilir.
  -- Yalnız sayı; adres, özet ya da e-posta yok.
  if exists (select 1 from pg_attribute where attrelid = to_regclass('public.support_requests') and attname = 'source_hash'
                                           and not attisdropped) then
    execute $q$select count(*) from public.support_requests
                where source_hash is null and status <> 'spam' and created_at > now() - interval '24 hours'$q$ into n;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'support_source', 'label', 'Destek formu kaynak sınırı',
      'level', case when n > 0 then 'warn' else 'ok' end,
      'detail', case when n > 0 then n || ' talep kaynaksız geldi (son 24 saat): SUPPORT_FORWARD_KEY''i Worker''a ve Supabase''e ekle, '
                                       || 'support işlevini yeniden yayınla'
                     else 'Son 24 saatte kaynaksız talep yok' end));
  end if;

  -- destek e-postası (20261122100000_support_inbox.sql): son 24 saatte gönderilemeyen ya da 15 dakikadır bekleyen giden ileti
  -- (otomatik yanıt ya da panelden yanıt; Resend / SUPPORT_FROM) ve sınır nedeniyle alınmayan gelen e-posta. Yalnız sayı.
  if to_regclass('public.support_messages') is not null and to_regclass('public.support_inbound_drops') is not null then
    execute $q$select count(*) filter (where send_status = 'failed'),
                      count(*) filter (where send_status = 'pending' and created_at < now() - interval '15 minutes')
                 from public.support_messages where direction = 'out' and created_at > now() - interval '24 hours'$q$ into n, m;
    execute $q$select coalesce(sum(dropped), 0) from public.support_inbound_drops where hour > now() - interval '24 hours'$q$ into k;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'support_mail', 'label', 'Destek e-postası',
      'level', case when n + m + k > 0 then 'warn' else 'ok' end,
      'detail', case when n + m + k > 0 then
                       concat_ws(' · ', case when n > 0 then n || ' giden ileti gönderilemedi' end,
                                        case when m > 0 then m || ' giden ileti 15 dakikadır bekliyor' end,
                                        case when k > 0 then k || ' gelen e-posta sınır nedeniyle alınmadı' end) || ' (son 24 saat)'
                     else 'Son 24 saatte sorun yok' end));
  end if;

  -- davet ödülü kodları (20261103200000_referral_codes.sql uygulanmışsa): kod bekleyen ödül, havuz azaldı, süre yaklaşıyor
  if to_regclass('public.offer_code_pool') is not null then
    execute $q$select (select count(*) from public.referral_rewards where status = 'code_pending'),
                      (select count(*) from public.offer_code_pool where assigned_at is null and billing = 'monthly'
                          and expires_at > now() + interval '14 days'),
                      (select count(*) from public.offer_code_pool),
                      (select min(expires_at) from public.offer_code_pool where assigned_at is null and expires_at > now() + interval '14 days')
               $q$ into n, m, k, t;
    checks := checks || jsonb_build_array(jsonb_build_object('key', 'referral', 'label', 'Davet ödülü kodları',
      'level', case when n > 0 or (k > 0 and m < 5) then 'warn' when k = 0 or t < now() + interval '30 days' then 'info' else 'ok' end,
      'detail', case when n > 0 then n || ' ödül kod bekliyor: kod dosyası yükle'
                     when k = 0 then 'Kod havuzu boş: App Store Connect''ten kod üretip yükle'
                     when m < 5 then 'Aylık ürün için ' || m || ' kod kaldı'
                     when t < now() + interval '30 days' then 'Kodların bir kısmının süresi ' || to_char(t at time zone 'Europe/Istanbul', 'DD.MM.YYYY') || ' bitiyor'
                     else m || ' aylık kod hazır' end));
  end if;

  -- silinmeyi bekleyen dosyalar
  select count(*) into n from public.storage_trash where created_at < now() - interval '2 days';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'storage_trash', 'label', 'Silinecek dosyalar',
    'level', case when n > 0 then 'warn' else 'ok' end,
    'detail', case when n > 0 then n || ' dosya 2 günden uzun süredir silinmeyi bekliyor' else 'Bekleyen yok' end));

  -- yayındaki yasal metin
  select count(*) into n from public.legal_documents where status = 'published';
  checks := checks || jsonb_build_array(jsonb_build_object('key', 'legal', 'label', 'Yasal metinler',
    'level', case when n = 0 then 'warn' else 'ok' end, 'detail', n || ' metin yayında'));

  select case when bool_or(c ->> 'level' = 'fail') then 'fail' when bool_or(c ->> 'level' = 'warn') then 'warn' else 'ok' end
    into worst from jsonb_array_elements(checks) c;
  return jsonb_build_object('status', worst, 'checked_at', now(), 'checks', checks);
end $$;
revoke execute on function public.ops_health() from public, anon, authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.ops_health() to service_role;
  end if;
end $$;

-- Bu dosyanın eklediği tablolar ve tarih sütunları sonsuz tarih korumasını alır
select public.finite_time_guard_attach();
