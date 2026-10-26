-- Uzman başlatır: aile davet bağlantısı, uzman değişiminde geçmiş aktarımı, takip planı (26 Ekim 2026, kullanıcı isteği).
-- Karar belgesi: sozlesme/akislar.md bölüm 10–12.
--
-- 1) Aile daveti 48 saat geçerli; bağlantı (token) + yazılabilir kod (6 karakter) aynı davettir. Uzman WhatsApp / e-posta ile paylaşır.
--    Ebeveyn bağlantıdan ya da kodla kayıt olur → davet aileye "bağlanır" (claim; çocuk verisi henüz paylaşılmaz).
--    Ebeveyn çocuğunu ekleyip onay verince paylaşım başlar (rıza kuralı aynı). Bağlanmış davet 30 gün içinde kullanılabilir.
--    Davet e-postası girilmişse aynı e-postayla kayıt olan ebeveyne davet kendiliğinden bağlanır.
--    Uzmana bildirim: invite_claimed (aile kayıt oldu / kodu girdi), clinic_shared (mevcut: çocuk paylaşıldı), invite_expired (48 saat doldu).
-- 2) Ebeveyn yeni uzmana paylaşırken önceki uzman(lar)ın kayıtlarını (not, hedef + puan, öneri, aile programı) aktarabilir;
--    yeni uzman salt okur; ebeveyn istediği an geri alır. Önceki uzmanın adı, unvanı, kliniği ve kimlikleri yeni uzmana
--    gösterilmez ("Önceki uzman 1"); metinlerde geçen adları gizlenir. Onaylanan metin sürümü kaydedilir (hukuk_notlari.md).
-- 3) Takip planı: çocuk hedefleri (clinic_goals genişler; "aileyle paylaşılan" hedefleri aile görür, haftalık puanlar yine yalnız klinikte)
--    + aile programı modülleri (care_modules) + ebeveynin uygulama kaydı (care_module_logs). Plan davet sırasında taslak olarak kurulabilir;
--    aile çocuğunu paylaşınca o çocuğa taşınır.
-- Tekrar çalıştırılabilir.

-- =====================================================================
-- 1. Aile davet bağlantısı
-- =====================================================================
alter table public.clinic_invites add column if not exists token text;
alter table public.clinic_invites add column if not exists parent_name text not null default '';
alter table public.clinic_invites add column if not exists parent_email text;
alter table public.clinic_invites add column if not exists channel text;
alter table public.clinic_invites add column if not exists opened_at timestamptz;
alter table public.clinic_invites add column if not exists claimed_at timestamptz;
alter table public.clinic_invites add column if not exists claimed_family uuid references public.families (id) on delete set null;
alter table public.clinic_invites add column if not exists expired_notified_at timestamptz;
alter table public.clinic_invites add column if not exists revoked_at timestamptz;
do $$ begin
  alter table public.clinic_invites add constraint clinic_invites_parent_name_len check (char_length(parent_name) <= 60);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.clinic_invites add constraint clinic_invites_parent_email_len check (parent_email is null or char_length(parent_email) <= 160);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.clinic_invites add constraint clinic_invites_channel_check check (channel is null or channel in ('whatsapp', 'email', 'sms', 'copy', 'other'));
exception when duplicate_object then null; end $$;
create unique index if not exists clinic_invites_token_idx on public.clinic_invites (token) where token is not null;
create index if not exists clinic_invites_email_idx on public.clinic_invites (lower(parent_email)) where parent_email is not null;
create index if not exists clinic_invites_clinic_idx on public.clinic_invites (clinic_id, created_at desc);

-- Tablolar (işlevlerden önce)
alter table public.clinic_goals alter column link_id drop not null;
alter table public.clinic_goals add column if not exists invite_code text references public.clinic_invites (code) on delete cascade;
alter table public.clinic_goals add column if not exists domain text not null default '';
alter table public.clinic_goals add column if not exists measure text not null default 'level';
alter table public.clinic_goals add column if not exists baseline text not null default '';
alter table public.clinic_goals add column if not exists target text not null default '';
alter table public.clinic_goals add column if not exists weeks smallint;
alter table public.clinic_goals add column if not exists home_support text not null default '';
alter table public.clinic_goals add column if not exists shared boolean not null default false;   -- aile görür (eski hedefler kapalı)
alter table public.clinic_goals add column if not exists status text not null default 'active';
alter table public.clinic_goals add column if not exists position integer not null default 0;
alter table public.clinic_goals add column if not exists template_key text;
alter table public.clinic_goals add column if not exists updated_at timestamptz not null default now();
do $$ begin
  alter table public.clinic_goals add constraint clinic_goals_owner_check check (link_id is not null or invite_code is not null);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.clinic_goals add constraint clinic_goals_fields_check check (
    char_length(domain) <= 40 and measure in ('frequency', 'percent', 'yesno', 'duration', 'level')
    and char_length(baseline) <= 60 and char_length(target) <= 60 and (weeks is null or weeks between 1 and 52)
    and char_length(home_support) <= 400 and status in ('active', 'achieved', 'paused'));
exception when duplicate_object then null; end $$;
create index if not exists clinic_goals_invite_idx on public.clinic_goals (invite_code) where invite_code is not null;

create table if not exists public.care_modules (
  id            uuid primary key default gen_random_uuid(),
  clinic_id     uuid not null references public.clinics (id) on delete cascade,
  link_id       uuid references public.clinic_links (id) on delete cascade,
  invite_code   text references public.clinic_invites (code) on delete cascade,
  title         text not null check (char_length(title) between 1 and 120),
  aim           text not null default '' check (char_length(aim) <= 400),        -- amaç (aileye)
  practice      text not null default '' check (char_length(practice) <= 600),   -- evde uygulama
  checklist     jsonb not null default '[]' check (jsonb_typeof(checklist) = 'array' and jsonb_array_length(checklist) <= 8),
  position      integer not null default 0,
  status        text not null default 'planned' check (status in ('planned', 'active', 'done')),
  template_key  text,
  created_by    uuid references public.clinicians (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (link_id is not null or invite_code is not null)
);
create index if not exists care_modules_link_idx on public.care_modules (link_id);
create index if not exists care_modules_invite_idx on public.care_modules (invite_code) where invite_code is not null;
alter table public.care_modules enable row level security;
revoke all on public.care_modules from anon, authenticated;
grant select, insert, update, delete on public.care_modules to authenticated;

create table if not exists public.care_module_logs (
  id          uuid primary key default gen_random_uuid(),
  module_id   uuid not null references public.care_modules (id) on delete cascade,
  family_id   uuid not null references public.families (id) on delete cascade,
  day         date not null default current_date,
  practiced   boolean not null default true,                 -- "bugün uyguladım" (tek dokunuş)
  difficulty  smallint check (difficulty between 1 and 5),   -- isteğe bağlı "ne kadar zorlandım" (ebeveynin öz bildirimi; puan değil)
  barrier     text check (barrier in ('no_time', 'forgot', 'child_resisted', 'unsure')),   -- uygulayamadıysa neden
  note        text not null default '' check (char_length(note) <= 300),
  created_by  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (module_id, created_by, day)
);
create index if not exists care_module_logs_module_idx on public.care_module_logs (module_id, day desc);
alter table public.care_module_logs enable row level security;
revoke all on public.care_module_logs from anon, authenticated;
grant select, insert, update, delete on public.care_module_logs to authenticated;

create table if not exists public.clinic_link_history (
  link_id       uuid not null references public.clinic_links (id) on delete cascade,   -- yeni uzmanın paylaşımı
  from_link_id  uuid not null references public.clinic_links (id) on delete cascade,   -- önceki paylaşım (başka uzman)
  granted_by    uuid references auth.users (id) on delete set null,
  granted_at    timestamptz not null default now(),
  consent_version text check (char_length(consent_version) <= 40),                      -- ebeveynin onayladığı metin sürümü
  primary key (link_id, from_link_id),
  check (link_id <> from_link_id)
);
alter table public.clinic_link_history add column if not exists consent_version text check (char_length(consent_version) <= 40);
create index if not exists clinic_link_history_from_idx on public.clinic_link_history (from_link_id);
alter table public.clinic_link_history enable row level security;
revoke all on public.clinic_link_history from anon, authenticated;
grant select on public.clinic_link_history to authenticated;

-- Uzman kendi davetlerini, sahip kliniğin bütün davetlerini görür (eskiden bütün ekip görüyordu)
drop policy if exists "davet: klinik okur" on public.clinic_invites;
create policy "davet: klinik okur" on public.clinic_invites for select to authenticated
  using (clinic_id = public.my_clinic_id() and (clinician_id = auth.uid() or public.clinic_is_owner()));

-- Kod ya da bağlantı anahtarıyla daveti bul (yalnız aile daveti)
create or replace function public.clinic_family_invite_find(p_key text)
returns public.clinic_invites language sql stable security definer set search_path = '' as $$
  select * from public.clinic_invites
   where kind = 'family'
     and (code = upper(trim(coalesce(p_key, ''))) or token = lower(trim(coalesce(p_key, ''))))
   limit 1
$$;
revoke execute on function public.clinic_family_invite_find(text) from public, anon, authenticated;

-- Aile davetinde nedenli ret (deneme kaydı + 400); metin 48 saate göre
create or replace function public.clinic_invite_rejected(p_reason text)
returns json language plpgsql security definer set search_path = '' as $$
begin
  insert into public.code_attempts (user_id, ip) values (auth.uid(), public.request_ip());
  perform set_config('response.status', '400', true);
  return json_build_object('error', 'invalid_code', 'reason', coalesce(p_reason, 'not_found'), 'hint', coalesce(p_reason, 'not_found'),
    'message', case p_reason
      when 'expired' then 'Davetin süresi doldu (davetler 48 saat geçerli). Uzmanından yeni davet iste.'
      when 'used' then 'Bu davet başka bir ailede kullanıldı. Uzmanından yeni davet iste.'
      else 'Davet bulunamadı. Kodu kontrol et ya da uzmanından yeni davet iste.' end);
end $$;
revoke execute on function public.clinic_invite_rejected(text) from public, anon, authenticated;

-- Davet durumu (uygulamalar ve istatistik aynı adları kullanır)
create or replace function public.clinic_invite_status(i public.clinic_invites)
returns text language sql stable set search_path = '' as $$
  select case
    when i.revoked_at is not null then 'revoked'
    when i.used_at is not null then 'shared'
    when i.claimed_at is not null then 'claimed'
    when i.expires_at <= now() then 'expired'
    when i.opened_at is not null then 'opened'
    else 'sent' end
$$;
revoke execute on function public.clinic_invite_status(public.clinic_invites) from public, anon;

-- Davet oluştur. Aile: 48 saat, bağlantı anahtarı + 6 karakter kod. Ekip: 15 dakika, 8 karakter (değişmedi).
drop function if exists public.clinic_create_invite(text, text);
drop function if exists public.clinic_create_invite(text, text, text, text);
create or replace function public.clinic_create_invite(p_kind text default 'family', p_label text default '',
                                                        p_parent_name text default '', p_parent_email text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.clinicians%rowtype;
  new_code text;
  new_token text;
  exp timestamptz;
  email text := nullif(lower(trim(coalesce(p_parent_email, ''))), '');
begin
  select * into me from public.clinicians where id = auth.uid();
  if not found then raise exception 'Yalnızca uzman hesabı'; end if;
  if p_kind not in ('family', 'clinician') then raise exception 'Geçersiz davet türü'; end if;
  if not public.clinician_access() then raise exception 'Üyelik etkin değil' using errcode = 'P0402'; end if;
  if p_kind = 'clinician' and me.role <> 'owner' then raise exception 'Ekibe yalnızca klinik sahibi davet eder'; end if;
  if p_kind = 'clinician' and (select seat_limit from public.clinics where id = me.clinic_id) <= 1 then
    raise exception 'Bireysel pakette ekip yok; Klinik paketine geçin';
  end if;
  if email is not null and email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'E-posta adresi geçersiz'; end if;
  -- günde en çok 100 aile daveti (kötüye kullanım sınırı)
  if p_kind = 'family' and (select count(*) from public.clinic_invites
                             where clinician_id = me.id and kind = 'family' and created_at > now() - interval '1 day') >= 100 then
    raise exception 'Bugün çok fazla davet oluşturdun; yarın tekrar dene';
  end if;
  delete from public.clinic_invites
   where clinic_id = me.clinic_id and kind = 'clinician' and used_at is null and expires_at < now() - interval '1 day';
  exp := now() + case when p_kind = 'family' then interval '48 hours' else interval '15 minutes' end;
  loop
    new_code := public.random_code(case when p_kind = 'clinician' then 8 else 6 end);
    exit when not exists (select 1 from public.clinic_invites where code = new_code)
          and not exists (select 1 from public.invite_codes where code = new_code);
  end loop;
  if p_kind = 'family' then new_token := replace(gen_random_uuid()::text, '-', ''); end if;
  insert into public.clinic_invites (code, clinic_id, clinician_id, kind, label, expires_at, token, parent_name, parent_email)
  values (new_code, me.clinic_id, me.id, p_kind, left(coalesce(p_label, ''), 60), exp, new_token,
          left(trim(coalesce(p_parent_name, '')), 60), email);
  return json_build_object('code', new_code, 'token', new_token, 'expires_at', exp);
end $$;
revoke execute on function public.clinic_create_invite(text, text, text, text) from public, anon;
grant execute on function public.clinic_create_invite(text, text, text, text) to authenticated;

-- Uzman paylaşım kanalını kaydeder (istatistik) ya da daveti iptal eder
create or replace function public.clinic_invite_mark(p_code text, p_channel text default null, p_revoke boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare inv public.clinic_invites%rowtype;
begin
  select * into inv from public.clinic_invites where code = upper(trim(p_code)) and kind = 'family';
  if not found or inv.clinic_id is distinct from public.my_clinic_id()
     or not (inv.clinician_id = auth.uid() or public.clinic_is_owner()) then
    raise exception 'Davet bulunamadı';
  end if;
  if p_revoke then
    if inv.used_at is not null then raise exception 'Kullanılmış davet iptal edilemez'; end if;
    update public.clinic_invites set revoked_at = now() where code = inv.code and revoked_at is null;
    -- taslak plan iptalle silinir
    delete from public.clinic_goals where invite_code = inv.code;
    delete from public.care_modules where invite_code = inv.code;
  elsif p_channel is not null then
    if p_channel not in ('whatsapp', 'email', 'sms', 'copy', 'other') then raise exception 'Geçersiz kanal'; end if;
    update public.clinic_invites set channel = p_channel where code = inv.code;
  end if;
end $$;

revoke execute on function public.clinic_invite_mark(text, text, boolean) from public, anon;
grant execute on function public.clinic_invite_mark(text, text, boolean) to authenticated;

-- Bağlantı sayfası (Edge Function `invite-info`, sunucu anahtarıyla) daveti gösterir ve "açıldı" işaretler.
-- İstemciye kapalı; yalnız service_role.
create or replace function public.clinic_invite_open(p_token text)
returns json language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  select i.*, c.name as clinic, m.name as clinician, m.title into r
    from public.clinic_invites i
    join public.clinics c on c.id = i.clinic_id
    join public.clinicians m on m.id = i.clinician_id
   where i.kind = 'family' and i.token = lower(trim(coalesce(p_token, '')));
  if not found then return json_build_object('status', 'not_found'); end if;
  update public.clinic_invites set opened_at = coalesce(opened_at, now()) where code = r.code;
  return json_build_object(
    'status', case when r.revoked_at is not null then 'revoked'
                   when r.used_at is not null or r.claimed_at is not null then 'used'
                   when r.expires_at <= now() then 'expired' else 'open' end,
    'clinic', r.clinic, 'clinician', r.clinician, 'title', r.title, 'code', r.code, 'expires_at', r.expires_at);
end $$;
revoke execute on function public.clinic_invite_open(text) from public, anon, authenticated;
grant execute on function public.clinic_invite_open(text) to service_role;

-- Daveti aileye bağla (iç işlev; kayıt tetikleyicisi ve claim_clinic_invite kullanır)
create or replace function public.clinic_invite_claim_for(p_code text, p_family uuid, p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  inv public.clinic_invites%rowtype;
  who text;
begin
  select * into inv from public.clinic_invites where code = p_code for update;
  if not found or inv.claimed_at is not null then return; end if;
  update public.clinic_invites set claimed_at = now(), claimed_family = p_family where code = inv.code;
  select coalesce(nullif(trim(name), ''), nullif(trim(nickname), ''), 'Bir ebeveyn') into who from public.profiles where id = p_user;
  perform public.notify(inv.clinician_id, 'clinic', 'invite_claimed',
    left(coalesce(who, 'Bir ebeveyn') || ' davetini kabul etti', 120),
    case when inv.label <> '' then inv.label || ' · ' else '' end || 'Çocuğunu paylaşınca danışan listende görünür.',
    jsonb_build_object('code', inv.code));
end $$;
revoke execute on function public.clinic_invite_claim_for(text, uuid, uuid) from public, anon, authenticated;

-- Ebeveyn: bağlantıyla geldi ya da kodu yazdı → davet ailesine bağlanır. Çocuk verisi paylaşılmaz.
create or replace function public.claim_clinic_invite(p_key text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  t json;
  is_token boolean := lower(trim(coalesce(p_key, ''))) ~ '^[0-9a-f]{32}$';
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if not is_token then
    t := public.code_throttled();
    if t is not null then return t; end if;
  end if;
  inv := public.clinic_family_invite_find(p_key);
  if inv.code is null then
    if is_token then return public.clinic_invite_rejected('not_found'); end if;
    return public.clinic_invite_rejected('not_found');
  end if;
  if inv.revoked_at is not null then return public.clinic_invite_rejected('expired'); end if;
  if inv.claimed_at is not null and inv.claimed_family is distinct from fid then return public.clinic_invite_rejected('used'); end if;
  if inv.claimed_at is null then
    if inv.used_at is not null then return public.clinic_invite_rejected('used'); end if;
    if inv.expires_at <= now() then return public.clinic_invite_rejected('expired'); end if;
    perform public.clinic_invite_claim_for(inv.code, fid, auth.uid());
  end if;
  delete from public.code_attempts where user_id = auth.uid();
  return (select json_build_object('code', inv.code, 'clinic_id', inv.clinic_id, 'clinic', c.name, 'clinician', m.name, 'title', m.title,
                                   'label', inv.label,
                                   'has_plan', exists (select 1 from public.clinic_goals where invite_code = inv.code)
                                            or exists (select 1 from public.care_modules where invite_code = inv.code))
            from public.clinics c, public.clinicians m where c.id = inv.clinic_id and m.id = inv.clinician_id);
end $$;
revoke execute on function public.claim_clinic_invite(text) from public, anon;
grant execute on function public.claim_clinic_invite(text) to authenticated;

-- Ebeveynin bağlı ama henüz çocuk paylaşılmamış davetleri (ParentApp "Uzmanın seni bekliyor" kartı)
create or replace function public.family_pending_invites()
returns table (code text, clinic text, clinician text, title text, label text, claimed_at timestamptz, has_plan boolean)
language sql stable security definer set search_path = '' as $$
  select i.code, c.name, m.name, m.title, i.label, i.claimed_at,
         exists (select 1 from public.clinic_goals g where g.invite_code = i.code)
         or exists (select 1 from public.care_modules x where x.invite_code = i.code)
    from public.clinic_invites i
    join public.clinics c on c.id = i.clinic_id
    join public.clinicians m on m.id = i.clinician_id
   where i.kind = 'family' and i.claimed_family = public.my_family_id() and i.used_at is null and i.revoked_at is null
     and i.claimed_at > now() - interval '30 days'
   order by i.claimed_at desc
$$;
revoke execute on function public.family_pending_invites() from public, anon;
grant execute on function public.family_pending_invites() to authenticated;

-- Önizleme: kod ya da bağlantı anahtarı; ailenin bağladığı davet 30 gün geçerli
create or replace function public.clinic_invite_preview(p_code text)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  t json;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  inv := public.clinic_family_invite_find(p_code);
  if inv.code is null then return public.clinic_invite_rejected('not_found'); end if;
  if inv.revoked_at is not null then return public.clinic_invite_rejected('expired'); end if;
  if inv.claimed_at is not null then
    if inv.claimed_family is distinct from fid or inv.used_at is not null then return public.clinic_invite_rejected('used'); end if;
    if inv.claimed_at <= now() - interval '30 days' then return public.clinic_invite_rejected('expired'); end if;
  elsif public.code_problem(inv.used_at, inv.expires_at) is not null then
    return public.clinic_invite_rejected(public.code_problem(inv.used_at, inv.expires_at));
  end if;
  return (select json_build_object('clinic', c.name, 'clinician', m.name, 'title', m.title, 'expires_at', inv.expires_at, 'code', inv.code,
                                   'has_plan', exists (select 1 from public.clinic_goals where invite_code = inv.code)
                                            or exists (select 1 from public.care_modules where invite_code = inv.code))
            from public.clinics c, public.clinicians m where c.id = inv.clinic_id and m.id = inv.clinician_id);
end $$;

-- Çocuk paylaşımı: kod ya da bağlantı anahtarı; davet taslağındaki takip planı paylaşılan çocuk(lar)a taşınır.
-- p_share_history: önceki uzman kayıtlarını bu uzmana aç (bölüm 2); p_consent_version: ebeveynin onayladığı metnin sürümü.
drop function if exists public.redeem_clinic_invite_children(text, uuid[]);
drop function if exists public.redeem_clinic_invite_children(text, uuid[], boolean);
drop function if exists public.redeem_clinic_invite_children(text, uuid[], boolean, text);
create or replace function public.redeem_clinic_invite_children(p_code text, p_child_ids uuid[], p_share_history boolean default false,
                                                               p_consent_version text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  fid uuid := public.my_family_id();
  inv public.clinic_invites%rowtype;
  ids uuid[] := '{}';
  lid uuid;
  t json;
begin
  if fid is null then raise exception 'Önce ebeveyn olarak giriş yapmalısın'; end if;
  if coalesce(array_length(p_child_ids, 1), 0) = 0 then raise exception 'En az bir çocuk seç'; end if;
  if exists (select 1 from unnest(p_child_ids) x where not exists (
    select 1 from public.children c where c.id = x and c.family_id = fid)) then
    raise exception 'Çocuk bulunamadı';
  end if;
  t := public.code_throttled();
  if t is not null then return t; end if;
  inv := public.clinic_family_invite_find(p_code);
  if inv.code is null then return public.clinic_invite_rejected('not_found'); end if;
  perform 1 from public.clinic_invites where code = inv.code for update;
  select * into inv from public.clinic_invites where code = inv.code;
  if inv.revoked_at is not null then return public.clinic_invite_rejected('expired'); end if;
  if inv.used_at is not null then return public.clinic_invite_rejected('used'); end if;
  if inv.claimed_at is not null then
    if inv.claimed_family is distinct from fid then return public.clinic_invite_rejected('used'); end if;
    if inv.claimed_at <= now() - interval '30 days' then return public.clinic_invite_rejected('expired'); end if;
  elsif inv.expires_at <= now() then
    return public.clinic_invite_rejected('expired');
  end if;
  with ins as (
    insert into public.clinic_links (clinic_id, clinician_id, family_id, child_id, label, consent_by)
    select inv.clinic_id, inv.clinician_id, fid, x, inv.label, auth.uid()
      from (select distinct unnest(p_child_ids) as x) u
     where not exists (select 1 from public.clinic_links l where l.clinic_id = inv.clinic_id and l.child_id = u.x and l.status = 'active')
    returning id)
  select coalesce(array_agg(id), '{}') into ids from ins;
  -- taslak plan: her yeni paylaşıma kopya, sonra taslak silinir
  foreach lid in array ids loop
    insert into public.clinic_goals (link_id, clinic_id, title, description, created_by, domain, measure, baseline, target, weeks,
                                     home_support, shared, status, position, template_key)
    select lid, clinic_id, title, description, created_by, domain, measure, baseline, target, weeks, home_support, shared, status, position, template_key
      from public.clinic_goals where invite_code = inv.code;
    insert into public.care_modules (link_id, clinic_id, title, aim, practice, checklist, position, status, template_key, created_by)
    select lid, clinic_id, title, aim, practice, checklist, position, status, template_key, created_by
      from public.care_modules where invite_code = inv.code;
    if p_share_history then perform public.clinic_link_history_set(lid, true, p_consent_version); end if;
  end loop;
  delete from public.clinic_goals where invite_code = inv.code;
  delete from public.care_modules where invite_code = inv.code;
  update public.clinic_invites
     set used_at = now(), used_by = auth.uid(), claimed_at = coalesce(claimed_at, now()), claimed_family = coalesce(claimed_family, fid)
   where code = inv.code;
  delete from public.code_attempts where user_id = auth.uid();
  if exists (select 1 from public.care_modules where link_id = any(ids)) or exists (select 1 from public.clinic_goals where link_id = any(ids) and shared) then
    perform public.notify_parents(fid, 'care_plan_shared', 'Takip planın hazır',
      'Uzmanının hazırladığı hedefler ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_ids', to_jsonb(ids)), null);
  end if;
  return json_build_object('link_ids', ids, 'clinic_id', inv.clinic_id);
end $$;
revoke execute on function public.redeem_clinic_invite_children(text, uuid[], boolean, text) from public, anon;
grant execute on function public.redeem_clinic_invite_children(text, uuid[], boolean, text) to authenticated;

create or replace function public.redeem_clinic_invite(p_code text, p_child_id uuid)
returns json language plpgsql security definer set search_path = '' as $$
declare r json;
begin
  r := public.redeem_clinic_invite_children(p_code, array[p_child_id], false);
  if r ->> 'error' is not null then return r; end if;
  return json_build_object('link_id', (r -> 'link_ids') ->> 0);
end $$;

-- Kayıt: ebeveyn hesabı açılınca bağlantıdaki davet (meta `clinic_invite`) ya da e-postası eşleşen açık davet aileye bağlanır
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  fid uuid;
  cid uuid;
  inv public.clinic_invites%rowtype;
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  if meta ->> 'account' = 'clinician' then
    if nullif(trim(meta ->> 'team_code'), '') is not null then
      select * into inv from public.clinic_invites
        where code = upper(trim(meta ->> 'team_code')) and kind = 'clinician'
          and used_at is null and expires_at > now()
        for update;
      if not found then
        raise exception 'Ekip kodu geçersiz ya da süresi dolmuş';
      end if;
      perform 1 from public.clinics where id = inv.clinic_id for update;
      if (select count(*) from public.clinicians where clinic_id = inv.clinic_id)
         >= (select seat_limit from public.clinics where id = inv.clinic_id) then
        raise exception 'Kliniğin uzman koltuğu dolu';
      end if;
      cid := inv.clinic_id;
      update public.clinic_invites set used_at = now(), used_by = new.id where code = inv.code;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, left(coalesce(trim(meta ->> 'name'), ''), 80), left(coalesce(trim(meta ->> 'title'), ''), 80), 'member');
    else
      insert into public.clinics (name, created_by)
      values (left(coalesce(nullif(trim(meta ->> 'clinic_name'), ''), 'Kliniğim'), 120), new.id)
      returning id into cid;
      insert into public.clinicians (id, clinic_id, name, title, role)
      values (new.id, cid, left(coalesce(trim(meta ->> 'name'), ''), 80), left(coalesce(trim(meta ->> 'title'), ''), 80), 'owner');
    end if;
    return new;
  end if;

  insert into public.families (created_by) values (new.id) returning id into fid;
  insert into public.profiles (id, family_id, nickname, name, avatar)
  values (
    new.id,
    fid,
    coalesce(nullif(trim(meta ->> 'nickname'), ''), 'Ben'),
    coalesce(trim(meta ->> 'name'), ''),
    coalesce(nullif(meta ->> 'avatar', ''), 'erkek')
  );

  -- Uzman daveti (bağlantı anahtarı ya da kod); hata kaydı engellemez
  begin
    inv := public.clinic_family_invite_find(meta ->> 'clinic_invite');
    if inv.code is null and new.email is not null then
      select * into inv from public.clinic_invites
       where kind = 'family' and lower(parent_email) = lower(new.email)
         and claimed_at is null and used_at is null and revoked_at is null and expires_at > now()
       order by created_at desc limit 1;
    end if;
    if inv.code is not null and inv.claimed_at is null and inv.used_at is null and inv.revoked_at is null and inv.expires_at > now() then
      perform public.clinic_invite_claim_for(inv.code, fid, new.id);
    end if;
  exception when others then null;
  end;
  return new;
end $$;

-- Süresi dolan davetler: uzmana bir kez "kullanılmadı" bildirimi. Zamanlayıcı (pg_cron) 15 dakikada bir çağırır;
-- ClinicApp de açılışta kendi kliniği için çağırır (zamanlayıcı yoksa bildirim geç de olsa gelir).
create or replace function public.clinic_invites_expire(p_clinic uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  r record;
  n integer := 0;
begin
  for r in select * from public.clinic_invites
            where kind = 'family' and expires_at <= now() and claimed_at is null and used_at is null
              and revoked_at is null and expired_notified_at is null
              and (p_clinic is null or clinic_id = p_clinic)
            for update skip locked loop
    update public.clinic_invites set expired_notified_at = now() where code = r.code;
    insert into public.notifications (user_id, app, kind, title, body, data)
    values (r.clinician_id, 'clinic', 'invite_expired', 'Davetin kullanılmadı, süresi doldu',
            left(case when r.label <> '' then r.label || ' · ' when r.parent_name <> '' then r.parent_name || ' · ' else '' end
                 || 'İstersen yeni bir davet gönder.', 300),
            jsonb_build_object('code', r.code));
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.clinic_invites_expire(uuid) from public, anon, authenticated;
grant execute on function public.clinic_invites_expire(uuid) to service_role;

create or replace function public.clinic_invites_sweep()
returns integer language plpgsql security definer set search_path = '' as $$
begin
  if public.my_clinic_id() is null then return 0; end if;
  return public.clinic_invites_expire(public.my_clinic_id());
end $$;
revoke execute on function public.clinic_invites_sweep() from public, anon;
grant execute on function public.clinic_invites_sweep() to authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('clinic-invites-expire', '*/15 * * * *', 'select public.clinic_invites_expire()');
exception when others then
  raise notice 'pg_cron yok: süre bildirimi ClinicApp açılışında (clinic_invites_sweep) yapılır';
end $$;

-- Uzmanın davet listesi ve istatistiği (sahip bütün ekibi, üye kendini görür)
drop function if exists public.clinic_invites_list(integer);
create function public.clinic_invites_list(p_days integer default 90)
returns table (code text, token text, clinician_id uuid, clinician text, label text, parent_name text, parent_email text,
               channel text, status text, created_at timestamptz, expires_at timestamptz, opened_at timestamptz,
               claimed_at timestamptz, used_at timestamptz, has_plan boolean)
language sql stable security definer set search_path = '' as $$
  select i.code, case when i.used_at is null and i.revoked_at is null then i.token end, i.clinician_id, coalesce(m.name, ''), i.label,
         i.parent_name, i.parent_email, i.channel, public.clinic_invite_status(i), i.created_at, i.expires_at, i.opened_at,
         i.claimed_at, i.used_at,
         exists (select 1 from public.clinic_goals g where g.invite_code = i.code)
         or exists (select 1 from public.care_modules x where x.invite_code = i.code)
    from public.clinic_invites i
    left join public.clinicians m on m.id = i.clinician_id
   where i.kind = 'family' and i.clinic_id = public.my_clinic_id()
     and (i.clinician_id = auth.uid() or public.clinic_is_owner())
     and i.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 90), 730)))
   order by i.created_at desc
   limit 200
$$;
revoke execute on function public.clinic_invites_list(integer) from public, anon;
grant execute on function public.clinic_invites_list(integer) to authenticated;

drop function if exists public.clinic_invite_stats(integer);
create function public.clinic_invite_stats(p_days integer default 30)
returns table (clinician_id uuid, clinician text, sent bigint, opened bigint, claimed bigint, shared bigint, expired bigint, open_now bigint)
language sql stable security definer set search_path = '' as $$
  select m.id, coalesce(m.name, ''),
         count(i.code),
         count(i.code) filter (where i.opened_at is not null),
         count(i.code) filter (where i.claimed_at is not null),
         count(i.code) filter (where i.used_at is not null),
         count(i.code) filter (where public.clinic_invite_status(i) = 'expired'),
         count(i.code) filter (where public.clinic_invite_status(i) in ('sent', 'opened', 'claimed'))
    from public.clinicians m
    left join public.clinic_invites i on i.clinician_id = m.id and i.kind = 'family'
         and i.created_at > now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 730)))
   where m.clinic_id = public.my_clinic_id() and (m.id = auth.uid() or public.clinic_is_owner())
   group by m.id, m.name
   order by count(i.code) desc
$$;
revoke execute on function public.clinic_invite_stats(integer) from public, anon;
grant execute on function public.clinic_invite_stats(integer) to authenticated;

-- =====================================================================
-- 2. Uzman değişiminde geçmiş aktarımı (ebeveyn rızasıyla, geri alınabilir, önceki uzman adsız)
-- =====================================================================
-- Yeni uzman önceki kayıtlara tablolardan doğrudan erişmez; yalnız `clinic_inherited_records` ile okur. Bu işlev önceki
-- uzmanın/kliniğin adını, unvanını ve kimliklerini döndürmez ("Önceki uzman 1", dönem ay olarak) ve metinlerde geçen
-- klinik adını ile o kliniğin uzman adlarını "[önceki uzman]" ile değiştirir (en iyi çaba; uzman sözleşmesi nota kimlik
-- bilgisi yazılmamasını ister, sozlesme/hukuk_notlari.md).
drop policy if exists "geçmiş: aile okur" on public.clinic_link_history;
create policy "geçmiş: aile okur" on public.clinic_link_history for select to authenticated
  using (exists (select 1 from public.clinic_links l where l.id = link_id and l.family_id = public.my_family_id()));
drop policy if exists "geçmiş: klinik okur" on public.clinic_link_history;   -- uzman bu tabloyu okumaz

-- Önceki sürümün doğrudan okuma kuralları (devralınan kayıtlar artık yalnız işlevle)
drop policy if exists "not: devralınan" on public.clinic_notes;
drop policy if exists "öneri: devralınan" on public.clinic_task_suggestions;
drop policy if exists "hedef: devralınan" on public.clinic_goals;
drop policy if exists "hedef puanı: devralınan" on public.goal_ratings;
drop policy if exists "modül: devralınan" on public.care_modules;
drop function if exists public.clinic_link_history_of(uuid);

-- Ebeveyn: bu paylaşıma, aynı çocuğun önceki (başka klinikteki) paylaşımlarının kayıtlarını aç/kapat
drop function if exists public.clinic_link_history_set(uuid, boolean);
create or replace function public.clinic_link_history_set(p_link_id uuid, p_on boolean, p_consent_version text default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  l public.clinic_links%rowtype;
  n integer;
begin
  select * into l from public.clinic_links where id = p_link_id;
  if not found or l.family_id is distinct from public.my_family_id() then raise exception 'Paylaşım bulunamadı'; end if;
  if p_on then
    if l.status <> 'active' then raise exception 'Paylaşım sona erdi'; end if;
    insert into public.clinic_link_history (link_id, from_link_id, granted_by, consent_version)
    select l.id, o.id, auth.uid(), left(nullif(btrim(p_consent_version), ''), 40) from public.clinic_links o
     where o.child_id = l.child_id and o.clinic_id <> l.clinic_id and o.consent_at <= l.consent_at
    on conflict do nothing;
  else
    delete from public.clinic_link_history where link_id = l.id;
  end if;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.clinic_link_history_set(uuid, boolean, text) from public, anon;
grant execute on function public.clinic_link_history_set(uuid, boolean, text) to authenticated;

-- Metinde geçen adları gizle: her ad tam kelime olarak, büyük/küçük harf duyarsız. İç işlev.
create or replace function public.clinic_redact(p_text text, p_names text[])
returns text language plpgsql immutable set search_path = '' as $$
declare
  r text := coalesce(p_text, '');
  n text;
  w constant text := '[^[:alnum:]çğıöşüÇĞİÖŞÜâîûÂÎÛ]';
begin
  foreach n in array coalesce(p_names, '{}'::text[]) loop
    n := btrim(n);
    continue when char_length(n) < 3;
    r := regexp_replace(r, '(^|' || w || ')(' || regexp_replace(n, '([^[:alnum:][:space:]])', '\\\1', 'g') || ')(?=$|' || w || ')',
                        '\1[önceki uzman]', 'gi');
  end loop;
  return r;
end $$;
revoke execute on function public.clinic_redact(text, text[]) from public, anon, authenticated;

-- Uzman: devraldığı kayıtlar, önceki paylaşım başına bir öğe. Kimlik yok: n, "Önceki uzman n", dönem (ay), kayıtlar.
create or replace function public.clinic_inherited_records(p_link_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  res jsonb := '[]'::jsonb;
  o public.clinic_links%rowtype;
  nm text[];
  k integer := 0;
begin
  if not public.clinic_link_mine(p_link_id) then return res; end if;
  for o in select ol.* from public.clinic_link_history h join public.clinic_links ol on ol.id = h.from_link_id
            where h.link_id = p_link_id order by ol.consent_at loop
    k := k + 1;
    -- gizlenecek adlar: klinik adı, o kliniğin uzmanlarının tam adı ve en az 3 harfli ad parçaları
    select coalesce(array_agg(distinct x), '{}') into nm from (
      select c.name as x from public.clinics c where c.id = o.clinic_id
      union all select m.name from public.clinicians m where m.clinic_id = o.clinic_id or m.id = o.clinician_id
      union all select t from public.clinicians m, regexp_split_to_table(m.name, '\s+') t
       where (m.clinic_id = o.clinic_id or m.id = o.clinician_id) and t ~ '^[[:alpha:]çğıöşüÇĞİÖŞÜâîûÂÎÛ]{3,}$'
    ) s where char_length(btrim(x)) >= 3;
    res := res || jsonb_build_array(jsonb_build_object(
      'n', k,
      'label', 'Önceki uzman ' || k,
      'from', to_char(o.consent_at, 'YYYY-MM'),
      'to', case when o.revoked_at is null then null else to_char(o.revoked_at, 'YYYY-MM') end,
      'notes', coalesce((select jsonb_agg(jsonb_build_object('body', public.clinic_redact(x.body, nm), 'created_at', x.created_at)
                                          order by x.created_at desc)
                           from public.clinic_notes x where x.link_id = o.id), '[]'::jsonb),
      'suggestions', coalesce((select jsonb_agg(jsonb_build_object(
                                 'title', public.clinic_redact(x.title, nm), 'emoji', x.emoji, 'skill', x.skill, 'category', x.category,
                                 'description', public.clinic_redact(x.description, nm), 'note', public.clinic_redact(x.note, nm),
                                 'recurring', x.recurring, 'status', x.status, 'created_at', x.created_at, 'decided_at', x.decided_at)
                                 order by x.created_at desc)
                           from public.clinic_task_suggestions x where x.link_id = o.id), '[]'::jsonb),
      'goals', coalesce((select jsonb_agg(jsonb_build_object(
                           'title', public.clinic_redact(g.title, nm), 'description', public.clinic_redact(g.description, nm),
                           'domain', g.domain, 'measure', g.measure, 'baseline', public.clinic_redact(g.baseline, nm),
                           'target', public.clinic_redact(g.target, nm), 'weeks', g.weeks,
                           'home_support', public.clinic_redact(g.home_support, nm), 'status', g.status, 'archived', g.archived,
                           'created_at', g.created_at,
                           'ratings', coalesce((select jsonb_agg(jsonb_build_object('week', r.week, 'rating', r.rating) order by r.week)
                                                  from public.goal_ratings r where r.goal_id = g.id), '[]'::jsonb))
                           order by g.position, g.created_at)
                     from public.clinic_goals g where g.link_id = o.id), '[]'::jsonb),
      'modules', coalesce((select jsonb_agg(jsonb_build_object(
                             'title', public.clinic_redact(m.title, nm), 'aim', public.clinic_redact(m.aim, nm),
                             'practice', public.clinic_redact(m.practice, nm),
                             'checklist', coalesce((select jsonb_agg(public.clinic_redact(c, nm)) from jsonb_array_elements_text(m.checklist) c), '[]'::jsonb),
                             'status', m.status, 'created_at', m.created_at,
                             'logs', coalesce((select jsonb_agg(jsonb_build_object('day', x.day, 'practiced', x.practiced,
                                                 'difficulty', x.difficulty, 'barrier', x.barrier) order by x.day desc)
                                                from public.care_module_logs x where x.module_id = m.id), '[]'::jsonb))
                             order by m.position, m.created_at)
                       from public.care_modules m where m.link_id = o.id), '[]'::jsonb)
    ));
  end loop;
  return res;
end $$;
revoke execute on function public.clinic_inherited_records(uuid) from public, anon;
grant execute on function public.clinic_inherited_records(uuid) to authenticated;

-- Ebeveyn ParentApp'teki uzman ekranında aktarımın açık olup olmadığını görür; family_clinic_links bunu döndürür
drop function if exists public.family_clinic_links();
create function public.family_clinic_links()
returns table (link_id uuid, clinic_id uuid, child_id uuid, clinic text, clinician text, title text, consent_at timestamptz,
               history_shared boolean, history_available boolean)
language sql stable security definer set search_path = '' as $$
  select l.id, l.clinic_id, l.child_id, c.name, coalesce(m.name, ''), coalesce(m.title, ''), l.consent_at,
         exists (select 1 from public.clinic_link_history h where h.link_id = l.id),
         exists (select 1 from public.clinic_links o where o.child_id = l.child_id and o.clinic_id <> l.clinic_id and o.consent_at <= l.consent_at)
  from public.clinic_links l
  join public.clinics c on c.id = l.clinic_id
  left join public.clinicians m on m.id = l.clinician_id
  where l.family_id = public.my_family_id() and l.status = 'active'
  order by l.consent_at
$$;
revoke execute on function public.family_clinic_links() from public, anon;
grant execute on function public.family_clinic_links() to authenticated;

-- =====================================================================
-- 3. Takip planı: çocuk hedefleri + aile programı
-- =====================================================================
-- Davet taslağını yazabilen uzman (daveti oluşturan ya da sahip; davet açık)
create or replace function public.clinic_invite_mine(p_code text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.clinician_access() and exists (
    select 1 from public.clinic_invites i
     where i.code = p_code and i.kind = 'family' and i.clinic_id = public.my_clinic_id()
       and i.used_at is null and i.revoked_at is null
       and (i.clinician_id = auth.uid() or public.clinic_is_owner()))
$$;
revoke execute on function public.clinic_invite_mine(text) from public, anon;
grant execute on function public.clinic_invite_mine(text) to authenticated;

-- Ailenin etkin paylaşımı mı?
create or replace function public.family_link_active(p_link uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.clinic_links l where l.id = p_link and l.status = 'active' and l.family_id = public.my_family_id())
$$;
revoke execute on function public.family_link_active(uuid) from public, anon;
grant execute on function public.family_link_active(uuid) to authenticated;

-- hedefler: klinik (paylaşım ya da davet taslağı), aile (paylaşılanlar); devralan uzman yalnız clinic_inherited_records ile
drop policy if exists "hedef: klinik" on public.clinic_goals;
create policy "hedef: klinik" on public.clinic_goals for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and ((link_id is not null and public.clinic_link_visible(link_id)) or (invite_code is not null and public.clinic_invite_mine(invite_code))))
  with check (clinic_id = public.my_clinic_id()
         and ((link_id is not null and invite_code is null and public.clinic_link_mine(link_id))
              or (link_id is null and invite_code is not null and public.clinic_invite_mine(invite_code))));
drop policy if exists "hedef: aile okur" on public.clinic_goals;
create policy "hedef: aile okur" on public.clinic_goals for select to authenticated
  using (shared and link_id is not null and public.family_link_active(link_id));

drop policy if exists "modül: klinik" on public.care_modules;
create policy "modül: klinik" on public.care_modules for all to authenticated
  using (clinic_id = public.my_clinic_id() and public.clinician_access()
         and ((link_id is not null and public.clinic_link_visible(link_id)) or (invite_code is not null and public.clinic_invite_mine(invite_code))))
  with check (clinic_id = public.my_clinic_id()
         and ((link_id is not null and invite_code is null and public.clinic_link_mine(link_id))
              or (link_id is null and invite_code is not null and public.clinic_invite_mine(invite_code))));
drop policy if exists "modül: aile okur" on public.care_modules;
create policy "modül: aile okur" on public.care_modules for select to authenticated
  using (link_id is not null and status <> 'planned' and public.family_link_active(link_id));

drop policy if exists "uygulama: aile" on public.care_module_logs;
create policy "uygulama: aile" on public.care_module_logs for all to authenticated
  using (family_id = public.my_family_id())
  with check (family_id = public.my_family_id() and created_by = auth.uid()
    and exists (select 1 from public.care_modules m where m.id = module_id and m.link_id is not null and m.status = 'active'
                and public.family_link_active(m.link_id)));
drop policy if exists "uygulama: klinik okur" on public.care_module_logs;
create policy "uygulama: klinik okur" on public.care_module_logs for select to authenticated
  using (exists (select 1 from public.care_modules m where m.id = module_id and m.link_id is not null
                 and m.clinic_id = public.my_clinic_id() and public.clinician_access() and public.clinic_link_visible(m.link_id)));

-- Sunucu doldurur: oluşturan, güncelleme zamanı; taşıma alanları istemciden değişmez
create or replace function public.care_rows_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if exists (select 1 from public.clinicians where id = auth.uid()) then new.created_by := auth.uid(); end if;
  else
    if auth.uid() is not null and (new.link_id is distinct from old.link_id or new.invite_code is distinct from old.invite_code
                                   or new.clinic_id is distinct from old.clinic_id) then
      raise exception 'Plan başka bir danışana taşınamaz';
    end if;
    new.created_by := old.created_by;
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function public.care_rows_guard() from public, anon, authenticated;
drop trigger if exists care_modules_guard on public.care_modules;
create trigger care_modules_guard before insert or update on public.care_modules
  for each row execute function public.care_rows_guard();
drop trigger if exists clinic_goals_guard on public.clinic_goals;
create trigger clinic_goals_guard before insert or update on public.clinic_goals
  for each row execute function public.care_rows_guard();

-- "kim yazdı": uzman eklerse kendisi; sunucu taşırsa (davet taslağı → paylaşım, ebeveynin oturumunda) taslağı yazan uzman kalır
create or replace function public.clinic_set_author()
returns trigger language plpgsql security definer set search_path = '' as $$
declare is_clinician boolean := exists (select 1 from public.clinicians where id = auth.uid());
begin
  if tg_table_name = 'goal_ratings' then
    new.rated_by := case when tg_op = 'INSERT' then auth.uid() else old.rated_by end;
  else
    new.created_by := case when tg_op = 'INSERT' then (case when is_clinician or auth.uid() is null then auth.uid() else new.created_by end)
                           else old.created_by end;
  end if;
  return new;
end $$;

-- Uygulama kaydında aile kimliği sunucudan
create or replace function public.care_logs_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.family_id := public.my_family_id();
  new.created_by := auth.uid();
  return new;
end $$;
revoke execute on function public.care_logs_guard() from public, anon, authenticated;
drop trigger if exists care_logs_guard on public.care_module_logs;
create trigger care_logs_guard before insert or update on public.care_module_logs
  for each row execute function public.care_logs_guard();

-- Uzman planı aileye gönderir (tek bildirim; her düzenlemede değil)
create or replace function public.care_plan_publish(p_link_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare l public.clinic_links%rowtype;
begin
  if not public.clinic_link_mine(p_link_id) then raise exception 'Paylaşım bulunamadı'; end if;
  select * into l from public.clinic_links where id = p_link_id;
  perform public.notify_parents(l.family_id, 'care_plan_shared', 'Takip planı güncellendi: ' || public.child_name(l.child_id),
    'Uzmanının hedefleri ve aile programı Uzmanım bölümünde.', jsonb_build_object('link_id', l.id), l.child_id);
end $$;
revoke execute on function public.care_plan_publish(uuid) from public, anon;
grant execute on function public.care_plan_publish(uuid) to authenticated;

-- Ebeveynin bir çocuk için gördüğü plan (paylaşılan hedefler + modüller + bu haftaki kaydı)
drop function if exists public.family_care_plan(uuid);
create function public.family_care_plan(p_link_id uuid)
returns json language sql stable security definer set search_path = '' as $$
  select case when public.family_link_active(p_link_id) then json_build_object(
    'goals', coalesce((select json_agg(json_build_object('id', g.id, 'title', g.title, 'description', g.description, 'domain', g.domain,
                         'measure', g.measure, 'baseline', g.baseline, 'target', g.target, 'weeks', g.weeks,
                         'home_support', g.home_support, 'status', g.status) order by g.position, g.created_at)
                         from public.clinic_goals g where g.link_id = p_link_id and g.shared and not g.archived), '[]'),
    'modules', coalesce((select json_agg(json_build_object('id', m.id, 'title', m.title, 'aim', m.aim, 'practice', m.practice,
                         'checklist', m.checklist, 'status', m.status,
                         'practiced_week', (select count(*) from public.care_module_logs x where x.module_id = m.id
                                             and x.family_id = public.my_family_id() and x.practiced and x.day > current_date - 7))
                         order by m.position, m.created_at)
                         from public.care_modules m where m.link_id = p_link_id and m.status <> 'planned'), '[]'))
  else null end
$$;
revoke execute on function public.family_care_plan(uuid) from public, anon;
grant execute on function public.family_care_plan(uuid) to authenticated;

-- Önceki sürümün yardımcı işlevi (kurallar artık kullanmıyor)
drop function if exists public.clinic_link_inherited(uuid);

-- Hesap/klinik silinirken davet taslakları da gider (invite_code FK cascade); `delete_account` değişmedi.
