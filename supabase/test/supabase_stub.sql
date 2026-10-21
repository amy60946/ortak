-- Yerel PostgreSQL'de Supabase'in en az taklidi (yalnızca test): auth.uid(), roller, storage tabloları.
-- Kullanım: bkz. run.sh. Gerçek Supabase projesine UYGULANMAZ.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;
create schema if not exists auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  is_anonymous boolean not null default false,
  raw_user_meta_data jsonb not null default '{}',
  email text,
  email_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  last_sign_in_at timestamptz
);
create or replace function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create schema if not exists storage;
create table storage.buckets (id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text, owner uuid);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to authenticated;
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name, '/') $$;
grant usage on schema public, auth, storage to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
-- Supabase varsayılanı: public şemasındaki fonksiyonlar anon ve authenticated için çalıştırılabilir
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;
create publication supabase_realtime;

-- Test yardımcısı: kod hatası artık exception değil, HTTP 400 + {"error"} gövdesi (code_failed). İkisini de "reddedildi" sayar.
create schema if not exists tst;
create or replace function tst.rejects(sql text, msg text) returns void language plpgsql as $$
declare res text;
begin
  begin
    execute sql into res;
  exception when others then
    raise notice 'ok (beklenen hata): % → %', msg, sqlerrm;
    return;
  end;
  if res::jsonb ? 'error' then
    raise notice 'ok (reddedildi): % → %', msg, res;
    return;
  end if;
  raise exception 'TEST BAŞARISIZ (red bekleniyordu): % → %', msg, res;
end $$;
