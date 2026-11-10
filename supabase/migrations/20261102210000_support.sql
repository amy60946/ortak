-- Destek talepleri (öneri, 2 Kasım 2026; kullanıcı kararı: "sayfada form"). Tekrar çalıştırılabilir.
-- Herkese açık /destek sayfasındaki form (panelin Cloudflare Worker'ı) → Edge Function `support` → support_request_create.
-- App Store "Support URL" ve uygulamalardaki "Yardım ve iletişim" bu sayfadır (alan adı gelene dek workers.dev; sabit adres
-- …/functions/v1/support oraya yönlendirir). Ekip panelde "Destek" kuyruğundan okur, yanıtı kendi e-postasından verir.
-- Saklama: kapanan talep 2 yıl, istenmeyen (spam) 30 gün (hukuk/42 satır 25; gece imha işi, 20261102200000_kvkk_ops.sql).
-- Sözleşme: sozlesme/admin.md "Destek", sozlesme/veritabani.md §24, hukuk/46 K15.

create table if not exists public.support_requests (
  id          uuid primary key default gen_random_uuid(),
  ref         text not null unique check (ref ~ '^D-[A-Z0-9]{6}$'),   -- kişiye gösterilen talep numarası
  created_at  timestamptz not null default now(),
  app         text not null check (app in ('parent', 'child', 'clinic', 'other')),
  topic       text not null check (topic in ('account', 'subscription', 'bug', 'privacy', 'clinic', 'other')),
  email       text not null check (char_length(email) between 6 and 254 and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  name        text not null default '' check (char_length(name) <= 80),
  message     text not null check (char_length(message) between 10 and 3000),
  status      text not null default 'new' check (status in ('new', 'in_progress', 'answered', 'closed', 'spam')),
  note        text check (char_length(note) <= 2000),                -- ekibin iç notu (kişiye gitmez)
  handled_by  uuid references auth.users (id) on delete set null,
  answered_at timestamptz,
  updated_at  timestamptz not null default now()
);
alter table public.support_requests enable row level security;
revoke all on public.support_requests from anon, authenticated;
create index if not exists support_requests_open_idx on public.support_requests (status, created_at);
create index if not exists support_requests_email_idx on public.support_requests (lower(email), created_at);

-- Formdan yeni talep (yalnız sunucu: Edge Function `support`). Sınır: aynı e-postadan 24 saatte 3, toplamda saatte 60.
-- Dönüş: {"ref"} ya da {"error": "invalid" | "too_many" | "busy"} (hata kodu; işlev Türkçe metne çevirir).
create or replace function public.support_request_create(p_app text, p_topic text, p_email text, p_name text, p_message text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  em text := lower(trim(coalesce(p_email, '')));
  msg text := trim(coalesce(p_message, ''));
  nm text := left(trim(coalesce(p_name, '')), 80);
  r text;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   -- karışan harf/rakam yok (I, O, 0, 1)
  i integer;
begin
  if p_app not in ('parent', 'child', 'clinic', 'other') or p_topic not in ('account', 'subscription', 'bug', 'privacy', 'clinic', 'other')
     or char_length(em) not between 6 and 254 or em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
     or char_length(msg) not between 10 and 3000 then
    return jsonb_build_object('error', 'invalid');
  end if;
  if (select count(*) from public.support_requests where lower(email) = em and created_at > now() - interval '24 hours') >= 3 then
    return jsonb_build_object('error', 'too_many');
  end if;
  if (select count(*) from public.support_requests where created_at > now() - interval '1 hour') >= 60 then
    return jsonb_build_object('error', 'busy');
  end if;
  loop
    r := 'D-';
    for i in 1..6 loop
      r := r || substr(alphabet, 1 + floor(random() * length(alphabet))::integer, 1);
    end loop;
    exit when not exists (select 1 from public.support_requests where ref = r);
  end loop;
  insert into public.support_requests (ref, app, topic, email, name, message) values (r, p_app, p_topic, em, nm, msg);
  return jsonb_build_object('ref', r);
end $$;
revoke execute on function public.support_request_create(text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.support_request_create(text, text, text, text, text) to service_role;

-- Panel: kuyruk (destek rolü). 'open' = yeni + işlemde (en eski önce); 'all' = hepsi (en yeni önce); ya da tek durum.
create or replace function public.admin_support_requests(p_status text default 'open', p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.admin_require(array['support']);
  return coalesce((
    select jsonb_agg(to_jsonb(s) - 'handled_by' order by case when p_status = 'open' then s.created_at end asc,
                                                       s.created_at desc)
      from (select * from public.support_requests
             where case when coalesce(p_status, 'open') = 'open' then status in ('new', 'in_progress')
                        when p_status = 'all' then true else status = p_status end
             order by created_at desc limit greatest(1, least(coalesce(p_limit, 100), 500))) s), '[]'::jsonb);
end $$;
revoke execute on function public.admin_support_requests(text, integer) from public, anon;
grant execute on function public.admin_support_requests(text, integer) to authenticated;

-- Panel: durum ve iç not (destek rolü; gerekçeli, denetim kaydında; e-posta ve mesaj kayda yazılmaz)
create or replace function public.admin_support_update(p_id uuid, p_status text, p_note text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.admin_require(array['support']);
  old record;
begin
  if p_status not in ('new', 'in_progress', 'answered', 'closed', 'spam') then raise exception 'Geçersiz durum'; end if;
  if char_length(coalesce(p_note, '')) > 2000 then raise exception 'Not en çok 2000 karakter'; end if;
  select * into old from public.support_requests where id = p_id for update;
  if not found then raise exception 'Talep bulunamadı'; end if;
  update public.support_requests
     set status = p_status, note = nullif(trim(coalesce(p_note, '')), ''), handled_by = me, updated_at = now(),
         answered_at = case when p_status = 'answered' then coalesce(answered_at, now()) else answered_at end
   where id = p_id;
  perform public.admin_log(me, 'support.update', 'system', 'support:' || old.ref, p_reason,
                           jsonb_build_object('status', old.status), jsonb_build_object('status', p_status));
end $$;
revoke execute on function public.admin_support_update(uuid, text, text, text) from public, anon;
grant execute on function public.admin_support_update(uuid, text, text, text) to authenticated;
