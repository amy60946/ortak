-- =====================================================================
-- Ebeveyn ↔ çocuk mesajlaşması (öneri, 21 Ekim 2026)
--   Ebeveyn (ParentApp): yazı, fotoğraf, sesli mesaj. Çocuk (Pofi Adası): yazı (≤ 500) ya da hazır çıkartma.
--   Her çocuğun ayrı sohbeti (messages.child_id); ailenin bütün ebeveynleri aynı sohbeti görür.
--   Okundu: read_at (karşı taraf sohbeti açınca mark_messages_read). Bildirim: messages_notify (var; metin sade).
--   Güvenlik: çocuk yalnız kendi sohbetine, yalnız yazı/çıkartma gönderir (dosya yolu yazamaz); saatte en çok
--   60 mesaj (ebeveyn 200). Ebeveynin dosya yolu kendi aile klasöründe olmalı. Ücretsiz planda ebeveyn mesajı
--   kapalı (20261021140000_subscriptions.sql), çocuk yine yazabilir.
--   Çıkartmalar (body = anahtar): heart, star, thumbs_up, hug, smile, laugh, wow, sad, sleepy, party, thanks, love_you
-- Tekrar çalıştırılabilir.
-- =====================================================================

alter table public.messages add column if not exists read_at timestamptz;

-- Tür ve içerik kuralları
do $$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.messages'::regclass and contype = 'c'
              and conname not in ('messages_body_check', 'messages_kind_check2', 'messages_content_check', 'messages_sticker_check')
              and (pg_get_constraintdef(oid) like '%kind%')
  loop
    execute format('alter table public.messages drop constraint %I', c);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'messages_kind_check2') then
    alter table public.messages add constraint messages_kind_check2 check (kind in ('text', 'image', 'audio', 'sticker'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'messages_content_check') then
    alter table public.messages add constraint messages_content_check check (
      (kind in ('text', 'sticker') and char_length(trim(body)) >= 1 and media_path is null)
      or (kind in ('image', 'audio') and media_path is not null)) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'messages_sticker_check') then
    alter table public.messages add constraint messages_sticker_check check (
      kind <> 'sticker' or body in ('heart', 'star', 'thumbs_up', 'hug', 'smile', 'laugh', 'wow', 'sad', 'sleepy',
                                    'party', 'thanks', 'love_you')) not valid;
  end if;
end $$;
create index if not exists messages_child_created_idx on public.messages (child_id, created_at);

-- Gönderme politikaları
drop policy if exists "mesaj: ebeveyn gönderir" on public.messages;
create policy "mesaj: ebeveyn gönderir" on public.messages for insert to authenticated
  with check (
    family_id = public.my_family_id()
    and sender = 'parent' and sender_id = auth.uid()
    and public.child_family(child_id) = family_id
    and read_at is null
    and (media_path is null or media_path like family_id::text || '/%')
  );
drop policy if exists "mesaj: çocuk gönderir" on public.messages;
create policy "mesaj: çocuk gönderir" on public.messages for insert to authenticated
  with check (
    child_id = public.my_child_id() and family_id = public.my_any_family_id()
    and sender = 'child' and sender_id = auth.uid()
    and kind in ('text', 'sticker') and media_path is null and duration_ms is null and read_at is null
    and char_length(body) <= 500
  );
-- read_at yalnız mark_messages_read ile; istemci mesajı düzenleyemez
revoke update on public.messages from anon, authenticated;

-- Sel koruması
create or replace function public.messages_rate_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  lim integer := case when new.sender = 'child' then 60 else 200 end;
begin
  if (select count(*) from public.messages m
       where m.child_id = new.child_id and m.sender = new.sender and m.created_at > now() - interval '1 hour') >= lim then
    raise exception 'Çok fazla mesaj gönderildi; biraz sonra tekrar dene' using errcode = 'P0001', hint = 'rate_limited';
  end if;
  new.created_at := now();
  return new;
end $$;
drop trigger if exists messages_rate_limit on public.messages;
create trigger messages_rate_limit before insert on public.messages
  for each row execute function public.messages_rate_limit();

-- Okundu: ebeveyn çocuğun mesajlarını, çocuk ebeveyn mesajlarını okundu yapar
create or replace function public.mark_messages_read(p_child_id uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
  fid uuid := public.my_family_id();
  n integer;
begin
  if fid is not null then
    if p_child_id is null or public.child_family(p_child_id) is distinct from fid then
      raise exception 'Çocuk bulunamadı' using errcode = '42501';
    end if;
    update public.messages set read_at = now()
     where child_id = p_child_id and sender = 'child' and read_at is null;
  elsif me is not null then
    update public.messages set read_at = now()
     where child_id = me and sender = 'parent' and read_at is null;
  else
    raise exception 'Giriş gerekli' using errcode = '42501';
  end if;
  get diagnostics n = row_count;
  return n;
end $$;

-- Oyun: mesaj gönder (doğrudan INSERT'in kısa yolu)
create or replace function public.child_send_message(p_kind text, p_body text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  me public.children%rowtype;
  r public.messages%rowtype;
begin
  select * into me from public.children where user_id = auth.uid();
  if not found then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  if p_kind not in ('text', 'sticker') then raise exception 'Geçersiz mesaj türü'; end if;
  if p_kind = 'text' and char_length(trim(coalesce(p_body, ''))) not between 1 and 500 then
    raise exception 'Mesaj 1–500 karakter olmalı';
  end if;
  insert into public.messages (family_id, child_id, sender, sender_id, kind, body)
  values (me.family_id, me.id, 'child', auth.uid(), p_kind, trim(p_body))
  returning * into r;
  return json_build_object('id', r.id, 'created_at', r.created_at);
end $$;

-- Oyun: sohbet (en yeni p_limit mesaj, eskiden yeniye). Fotoğraf/ses için oyun storage 'mail' kovasından
-- imzalı bağlantı ister (media_path).
create or replace function public.child_messages(p_limit integer default 100)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
begin
  if me is null then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  return coalesce((
    select json_agg(x order by x.created_at) from (
      select m.id, m.sender, m.kind, m.body, m.media_path, m.duration_ms, m.created_at, m.read_at,
             case when m.sender = 'parent' then (select p.nickname from public.profiles p where p.id = m.sender_id) end as from_name
        from public.messages m where m.child_id = me
       order by m.created_at desc limit least(greatest(coalesce(p_limit, 100), 1), 300)) x), '[]'::json);
end $$;

-- Bildirim metni (emoji yok)
create or replace function public.messages_notify() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  preview text := case new.kind when 'image' then 'Fotoğraf' when 'audio' then 'Sesli mesaj'
                                when 'sticker' then 'Çıkartma gönderdi' else left(coalesce(new.body, ''), 120) end;
  d jsonb := jsonb_build_object('message_id', new.id, 'child_id', new.child_id);
begin
  if new.sender = 'child' then
    perform public.notify_parents(new.family_id, 'message', public.child_name(new.child_id) || ' mesaj gönderdi', preview, d, new.child_id);
  else
    perform public.notify_child(new.child_id, 'message', 'Yeni mesajın var', preview, d);
  end if;
  return null;
end $$;
drop trigger if exists messages_notify on public.messages;
create trigger messages_notify after insert on public.messages
  for each row execute function public.messages_notify();

revoke execute on function public.messages_rate_limit() from public, anon, authenticated;
revoke execute on function public.messages_notify() from public, anon, authenticated;
revoke execute on function public.mark_messages_read(uuid) from public, anon;
revoke execute on function public.child_send_message(text, text) from public, anon;
revoke execute on function public.child_messages(integer) from public, anon;
grant execute on function public.mark_messages_read(uuid) to authenticated;
grant execute on function public.child_send_message(text, text) to authenticated;
grant execute on function public.child_messages(integer) to authenticated;
