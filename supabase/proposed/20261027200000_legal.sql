-- =====================================================================
-- Hukuk: sürümlü yasal metinler, onay kaydı, KVKK başvuruları (öneri, 27 Ekim 2026; kullanıcı isteği)
--   Metinlerin kaynağı ortak/hukuk/*.md; gövdeler 20261027210000_legal_seed.sql ile yüklenir (tools/legal_seed.py).
--   legal_documents   : anahtar + sürüm; taslak (draft) → yayında (published) → eski (retired). Yayındaki metin değişmez;
--                       değişiklik yeni sürümdür ve onay isteyen metinde yeniden onay ister.
--   legal_acceptances : kim, hangi metnin hangi sürümünü, hangi uygulamada, ne zaman onayladı (KVKK/TKHK ispat).
--   kvkk_requests     : ilgili kişi başvuruları (KVKK md. 11, 13): 30 gün yanıt süresi, panelden takip.
--   Herkese açık okuma Edge Function `legal` ile (mağaza ve kayıt ekranı bağlantısı); tablolar anon'a kapalı.
--   Açık rızalar (uzman-paylasim, uzman-gecis, saglik-yanit) kendi akışlarında sürümle kaydedilmeye devam eder.
-- Tekrar çalıştırılabilir.
-- =====================================================================

create table if not exists public.legal_documents (
  key                  text not null check (key ~ '^[a-z][a-z0-9-]{1,59}$'),
  version              text not null check (version ~ '^v[0-9]{1,3}$'),
  title                text not null check (char_length(title) between 2 and 160),
  apps                 text[] not null check (cardinality(apps) > 0 and apps <@ array['parent', 'child', 'clinic', 'web']::text[]),
  requires_acceptance  boolean not null default false,
  summary              text check (char_length(summary) <= 2000),     -- yeniden onayda gösterilecek "ne değişti"
  body_md              text not null check (char_length(body_md) between 1 and 300000),
  status               text not null default 'draft' check (status in ('draft', 'published', 'retired')),
  published_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  primary key (key, version)
);
alter table public.legal_documents enable row level security;
revoke all on public.legal_documents from anon, authenticated;

-- Yayındaki metin değişmez (ispat): yalnız durum eskiye çekilebilir
create or replace function public.legal_documents_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.status <> 'draft' and (new.body_md is distinct from old.body_md or new.title is distinct from old.title
                                or new.apps is distinct from old.apps or new.requires_acceptance is distinct from old.requires_acceptance) then
    raise exception 'Yayımlanmış metin değiştirilemez; yeni sürüm aç';
  end if;
  if old.status = 'retired' and new.status <> 'retired' then raise exception 'Eski sürüm geri açılamaz'; end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.legal_documents_guard() from public, anon, authenticated;
drop trigger if exists legal_documents_guard on public.legal_documents;
create trigger legal_documents_guard before update on public.legal_documents for each row execute function public.legal_documents_guard();

-- Hesap silinse de onay kaydı kalır (ispat; KVKK md. 5/2-e): user_id rastgele hesap kimliğidir, auth.users'a bağ yok,
-- e-posta/ad tutulmaz. Saklama süresi sonunda imha işi siler (hukuk/42-saklama-imha-politikasi.md).
create table if not exists public.legal_acceptances (
  user_id      uuid not null,
  doc_key      text not null,
  version      text not null,
  app          text not null check (app in ('parent', 'child', 'clinic')),
  accepted_at  timestamptz not null default now(),
  primary key (user_id, doc_key, version),
  foreign key (doc_key, version) references public.legal_documents (key, version)
);
alter table public.legal_acceptances enable row level security;
revoke all on public.legal_acceptances from anon, authenticated;
drop policy if exists "onay: kendi okur" on public.legal_acceptances;
create policy "onay: kendi okur" on public.legal_acceptances for select to authenticated using (user_id = auth.uid());
grant select on public.legal_acceptances to authenticated;

-- Bir anahtarın güncel sürümü: yayındaki; hiç yayımlanmadıysa en yeni taslak (test dönemi)
create or replace function public.legal_current_version(p_key text)
returns text language sql stable security definer set search_path = '' as $$
  select d.version from public.legal_documents d
   where d.key = p_key and d.status in ('published', 'draft')
   order by (d.status = 'published') desc, (substring(d.version from 2))::int desc
   limit 1
$$;
revoke execute on function public.legal_current_version(text) from public, anon, authenticated;

-- Uygulamanın gösterdiği metinler (Ayarlar › Yasal metinler) + onay durumu. p_app: parent | child | clinic | web
-- child: GameApp metinleri; veli ParentApp'te (çocuğu bağlamadan önce) çocuk adına onaylar.
create or replace function public.legal_documents_for(p_app text)
returns json language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic', 'web') then raise exception 'Geçersiz uygulama'; end if;
  return coalesce((
    select json_agg(json_build_object(
             'key', d.key, 'version', d.version, 'title', d.title, 'status', d.status, 'summary', d.summary,
             'requires_acceptance', d.requires_acceptance, 'published_at', d.published_at,
             'accepted_at', (select a.accepted_at from public.legal_acceptances a
                              where a.user_id = uid and a.doc_key = d.key and a.version = d.version))
           order by d.requires_acceptance desc, d.title)
      from public.legal_documents d
     where p_app = any(d.apps) and d.version = public.legal_current_version(d.key)), '[]'::json);
end $$;
revoke execute on function public.legal_documents_for(text) from public, anon;
grant execute on function public.legal_documents_for(text) to authenticated;

-- Onay bekleyenler (kayıttan sonra ve açılışta): güncel sürümü onaylanmamış, onay isteyen metinler
create or replace function public.legal_pending(p_app text)
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(x), '[]'::json)
    from json_array_elements(public.legal_documents_for(p_app)) x
   where (x ->> 'requires_acceptance')::boolean and x ->> 'accepted_at' is null
$$;
revoke execute on function public.legal_pending(text) from public, anon;
grant execute on function public.legal_pending(text) to authenticated;

-- Onay: [{key, version}] — yalnız o uygulamanın güncel ve onay isteyen sürümleri kabul edilir. Dönüş: kalan bekleyenler
create or replace function public.legal_accept(p_app text, p_docs jsonb)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  x jsonb;
begin
  if uid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  if jsonb_typeof(p_docs) <> 'array' or jsonb_array_length(p_docs) = 0 or jsonb_array_length(p_docs) > 20 then
    raise exception 'Onaylanacak metin seç';
  end if;
  -- child: veli onaylar (çocuk cihazının anonim oturumu onay veremez)
  if p_app = 'child' and not exists (select 1 from public.profiles where id = uid) then
    raise exception 'GameApp koşullarını veli ParentApp''te onaylar';
  end if;
  for x in select * from jsonb_array_elements(p_docs) loop
    if not exists (select 1 from public.legal_documents d
                    where d.key = x ->> 'key' and d.version = x ->> 'version' and d.requires_acceptance
                      and p_app = any(d.apps) and d.version = public.legal_current_version(d.key)) then
      raise exception 'Metin güncel değil: % %', x ->> 'key', x ->> 'version';
    end if;
    insert into public.legal_acceptances (user_id, doc_key, version, app) values (uid, x ->> 'key', x ->> 'version', p_app)
    on conflict do nothing;
  end loop;
  return public.legal_pending(p_app);
end $$;
revoke execute on function public.legal_accept(text, jsonb) from public, anon;
grant execute on function public.legal_accept(text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- KVKK başvuruları (md. 11, 13; 30 gün)
-- ---------------------------------------------------------------------
create table if not exists public.kvkk_requests (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users (id) on delete set null,
  email        text check (char_length(email) <= 254),   -- yanıt adresi (hesap silinse de başvuru kapanana kadar)
  app          text not null check (app in ('parent', 'child', 'clinic', 'other')),
  channel      text not null default 'app' check (channel in ('app', 'email', 'written', 'kep')),
  kind         text not null check (kind in ('info', 'access', 'correct', 'delete', 'object', 'third_parties', 'damages', 'other')),
  detail       text not null default '' check (char_length(detail) <= 2000),
  status       text not null default 'received' check (status in ('received', 'in_progress', 'answered', 'rejected')),
  received_at  timestamptz not null default now(),
  due_at       timestamptz not null default now() + interval '30 days',
  answered_at  timestamptz,
  child_id     uuid references public.children (id) on delete set null,   -- veli çocuğu adına başvurduysa
  answer_note  text check (char_length(answer_note) <= 2000),   -- iç not / yanıt özeti (kişiye giden metin e-postada)
  handled_by   uuid references auth.users (id) on delete set null,
  updated_at   timestamptz not null default now()
);
create index if not exists kvkk_requests_open on public.kvkk_requests (status, due_at);
create index if not exists kvkk_requests_user on public.kvkk_requests (user_id);
alter table public.kvkk_requests enable row level security;
revoke all on public.kvkk_requests from anon, authenticated;
drop policy if exists "kvkk: kendi okur" on public.kvkk_requests;
create policy "kvkk: kendi okur" on public.kvkk_requests for select to authenticated using (user_id = auth.uid());
grant select (id, app, kind, child_id, detail, status, received_at, due_at, answered_at) on public.kvkk_requests to authenticated;

-- Uygulama içi başvuru (hesaba bağlı; kimlik oturumla doğrulanır). En çok 5 açık başvuru.
-- p_child: veli kendi ailesindeki çocuk adına başvurur (yalnız ParentApp ebeveyni)
drop function if exists public.kvkk_request_create(text, text, text);
create or replace function public.kvkk_request_create(p_app text, p_kind text, p_detail text, p_child uuid default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  r public.kvkk_requests%rowtype;
begin
  if uid is null then raise exception 'Önce giriş yapmalısın' using errcode = '42501'; end if;
  if p_app not in ('parent', 'child', 'clinic') then raise exception 'Geçersiz uygulama'; end if;
  if p_kind not in ('info', 'access', 'correct', 'delete', 'object', 'third_parties', 'damages', 'other') then raise exception 'Başvuru türü seç'; end if;
  if char_length(coalesce(p_detail, '')) > 2000 then raise exception 'Açıklama en çok 2000 karakter'; end if;
  if p_kind in ('correct', 'object', 'damages', 'other') and char_length(btrim(coalesce(p_detail, ''))) < 5 then
    raise exception 'Talebini kısaca yaz';
  end if;
  if p_child is not null and not exists (select 1 from public.children c join public.profiles p on p.family_id = c.family_id
                                          where c.id = p_child and p.id = uid) then
    raise exception 'Çocuk bulunamadı';
  end if;
  if (select count(*) from public.kvkk_requests where user_id = uid and status in ('received', 'in_progress')) >= 5 then
    raise exception 'Açık başvurun var; yanıtlanınca yenisini gönderebilirsin';
  end if;
  insert into public.kvkk_requests (user_id, email, app, kind, detail, child_id)
  values (uid, (select u.email::text from auth.users u where u.id = uid), p_app, p_kind, btrim(coalesce(p_detail, '')), p_child)
  returning * into r;
  return json_build_object('id', r.id, 'status', r.status, 'received_at', r.received_at, 'due_at', r.due_at);
end $$;
revoke execute on function public.kvkk_request_create(text, text, text, uuid) from public, anon;
grant execute on function public.kvkk_request_create(text, text, text, uuid) to authenticated;

create or replace function public.my_kvkk_requests()
returns json language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(json_build_object('id', r.id, 'app', r.app, 'kind', r.kind, 'child_id', r.child_id, 'status', r.status,
           'received_at', r.received_at, 'due_at', r.due_at, 'answered_at', r.answered_at) order by r.received_at desc), '[]'::json)
    from public.kvkk_requests r where r.user_id = auth.uid()
$$;
revoke execute on function public.my_kvkk_requests() from public, anon;
grant execute on function public.my_kvkk_requests() to authenticated;

-- ---------------------------------------------------------------------
-- Yönetim paneli (sozlesme/admin.md)
-- ---------------------------------------------------------------------
create or replace function public.admin_legal_documents()
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return coalesce((
    select json_agg(json_build_object(
             'key', d.key, 'version', d.version, 'title', d.title, 'apps', d.apps, 'status', d.status,
             'requires_acceptance', d.requires_acceptance, 'summary', d.summary, 'published_at', d.published_at,
             'updated_at', d.updated_at, 'chars', char_length(d.body_md), 'current', d.version = public.legal_current_version(d.key),
             'acceptances', (select count(*) from public.legal_acceptances a where a.doc_key = d.key and a.version = d.version))
           order by d.key, (substring(d.version from 2))::int desc)
      from public.legal_documents d), '[]'::json);
end $$;
revoke execute on function public.admin_legal_documents() from public, anon;
grant execute on function public.admin_legal_documents() to authenticated;

-- Yayımla: taslak → yayında; aynı anahtarın önceki yayındaki sürümü eskiye çekilir (onay isteyen metinde herkes yeniden onaylar)
create or replace function public.admin_legal_publish(p_key text, p_version text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := public.admin_require(array['owner']);
begin
  if not exists (select 1 from public.legal_documents where key = p_key and version = p_version and status = 'draft') then
    raise exception 'Yayımlanacak taslak bulunamadı';
  end if;
  update public.legal_documents set status = 'retired' where key = p_key and status = 'published';
  update public.legal_documents set status = 'published', published_at = now() where key = p_key and version = p_version;
  perform public.admin_log(me, 'legal.publish', 'config', p_key || ':' || p_version, p_reason);
end $$;
revoke execute on function public.admin_legal_publish(text, text, text) from public, anon;
grant execute on function public.admin_legal_publish(text, text, text) to authenticated;

create or replace function public.admin_user_legal(p_user uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require();
  return json_build_object(
    'acceptances', coalesce((select json_agg(json_build_object('key', a.doc_key, 'version', a.version, 'app', a.app,
                     'accepted_at', a.accepted_at, 'current', a.version = public.legal_current_version(a.doc_key)) order by a.accepted_at desc)
                     from public.legal_acceptances a where a.user_id = p_user), '[]'::json),
    'kvkk', coalesce((select json_agg(json_build_object('id', r.id, 'kind', r.kind, 'status', r.status, 'received_at', r.received_at,
                     'due_at', r.due_at) order by r.received_at desc) from public.kvkk_requests r where r.user_id = p_user), '[]'::json));
end $$;
revoke execute on function public.admin_user_legal(uuid) from public, anon;
grant execute on function public.admin_user_legal(uuid) to authenticated;

-- Başvuru listesi: açıklar en yakın süreden; kişi bilgisi (e-posta, açıklama) yalnız support/owner'a
create or replace function public.admin_kvkk_requests(p_status text default 'open', p_limit integer default 100)
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require(array['support']);
  return coalesce((
    select json_agg(to_json(x) order by x.open desc, case when x.open then x.due_at end, x.received_at desc) from (
      select r.id, r.user_id, r.email, r.app, r.channel, r.kind, r.detail,
             (select c.name from public.children c where c.id = r.child_id) as child, r.status, r.received_at, r.due_at, r.answered_at,
             r.answer_note, case when r.user_id is null then null else public.account_kind(r.user_id) end as kind_of_user,
             r.status in ('received', 'in_progress') as open
        from public.kvkk_requests r
       where p_status = 'all' or (p_status = 'open' and r.status in ('received', 'in_progress')) or r.status = p_status
       order by (r.status in ('received', 'in_progress')) desc, case when r.status in ('received', 'in_progress') then r.due_at end, r.received_at desc
       limit greatest(1, least(coalesce(p_limit, 100), 500))) x), '[]'::json);
end $$;
revoke execute on function public.admin_kvkk_requests(text, integer) from public, anon;
grant execute on function public.admin_kvkk_requests(text, integer) to authenticated;

-- E-posta / yazılı / KEP ile gelen başvuruyu kayda al (alınış tarihi geçmiş olabilir; süre ondan işler)
create or replace function public.admin_kvkk_request_log(p_email text, p_app text, p_channel text, p_kind text, p_detail text,
                                                         p_received_at timestamptz, p_reason text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  rec timestamptz := least(coalesce(p_received_at, now()), now());
  em text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  rid uuid;
begin
  if p_channel not in ('email', 'written', 'kep') then raise exception 'Geçersiz kanal'; end if;
  if p_app not in ('parent', 'child', 'clinic', 'other') then raise exception 'Geçersiz uygulama'; end if;
  if p_kind not in ('info', 'access', 'correct', 'delete', 'object', 'third_parties', 'damages', 'other') then raise exception 'Başvuru türü seç'; end if;
  if rec < now() - interval '60 days' then raise exception 'Alınış tarihi en çok 60 gün önce olabilir'; end if;
  insert into public.kvkk_requests (user_id, email, app, channel, kind, detail, received_at, due_at)
  values ((select u.id from auth.users u where lower(u.email::text) = em limit 1), em, p_app, p_channel, p_kind,
          left(btrim(coalesce(p_detail, '')), 2000), rec, rec + interval '30 days')
  returning id into rid;
  perform public.admin_log(me, 'kvkk.log', 'system', rid::text, p_reason);
  return rid;
end $$;
revoke execute on function public.admin_kvkk_request_log(text, text, text, text, text, timestamptz, text) from public, anon;
grant execute on function public.admin_kvkk_request_log(text, text, text, text, text, timestamptz, text) to authenticated;

-- Durum ve iç not; yanıtlanınca (answered/rejected) hesabı varsa uygulamada bildirim (yanıtın kendisi e-postayla gider)
create or replace function public.admin_kvkk_request_update(p_id uuid, p_status text, p_note text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  r public.kvkk_requests%rowtype;
begin
  if p_status not in ('received', 'in_progress', 'answered', 'rejected') then raise exception 'Geçersiz durum'; end if;
  select * into r from public.kvkk_requests where id = p_id for update;
  if not found then raise exception 'Başvuru bulunamadı'; end if;
  if r.status in ('answered', 'rejected') and p_status in ('received', 'in_progress') then raise exception 'Kapanmış başvuru yeniden açılamaz'; end if;
  if p_status = 'rejected' and char_length(btrim(coalesce(p_note, ''))) < 5 then raise exception 'Ret gerekçesini nota yaz'; end if;
  update public.kvkk_requests
     set status = p_status, answer_note = left(nullif(btrim(coalesce(p_note, '')), ''), 2000), handled_by = me, updated_at = now(),
         answered_at = case when p_status in ('answered', 'rejected') then coalesce(answered_at, now()) end
   where id = p_id;
  if p_status in ('answered', 'rejected') and r.status not in ('answered', 'rejected') and r.user_id is not null and r.app in ('parent', 'clinic') then
    perform public.notify(r.user_id, r.app, 'kvkk_answered', 'KVKK başvurun yanıtlandı', 'Yanıtı e-posta adresine gönderdik.',
                          jsonb_build_object('request_id', r.id));
  end if;
  perform public.admin_log(me, 'kvkk.update', case when r.user_id is null then 'system' else 'user' end,
                           coalesce(r.user_id::text, r.id::text), p_reason, jsonb_build_object('status', r.status),
                           jsonb_build_object('status', p_status, 'request_id', r.id));
end $$;
revoke execute on function public.admin_kvkk_request_update(uuid, text, text, text) from public, anon;
grant execute on function public.admin_kvkk_request_update(uuid, text, text, text) to authenticated;
