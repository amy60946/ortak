-- Storage kovaları onarımı (kullanıcı hatası 28 Ekim 2026: çocuk fotoğrafı yüklenirken "Bucket not found").
-- Canlı projede 'mail' kovası yok: init göçünün Storage bölümü uygulanmamış görünüyor. Bu dosya kovaları ve
-- politikalarını göçlerdekiyle aynı kurallarla yeniden kurar; kova varsa dokunmaz, politikaları düşürüp yeniden kurar.
-- Tekrar çalıştırılabilir. Veri silinmez.

-- 1) 'mail': posta fotoğrafları, sesli mesajlar, çocuk fotoğrafı (avatar) · yol <family_id>/... (init.sql)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'mail', 'mail', false, 10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp',
        'audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mpeg']
)
on conflict (id) do nothing;
drop policy if exists "posta: aile okur" on storage.objects;
create policy "posta: aile okur" on storage.objects for select to authenticated
  using (bucket_id = 'mail' and (storage.foldername(name))[1] = public.my_any_family_id()::text);
drop policy if exists "posta: aile yükler" on storage.objects;
create policy "posta: aile yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'mail' and (storage.foldername(name))[1] = public.my_any_family_id()::text);
drop policy if exists "posta: ebeveyn siler" on storage.objects;
create policy "posta: ebeveyn siler" on storage.objects for delete to authenticated
  using (bucket_id = 'mail' and (storage.foldername(name))[1] = public.my_family_id()::text);

-- 2) 'abc': zor an (gözlem notu) ses kayıtları (20261019140000_parent_features.sql; politikalar orada zaten yeniden kurulabilir)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('abc', 'abc', false, 10485760, array['audio/m4a', 'audio/mp4', 'audio/x-m4a', 'audio/aac', 'audio/mpeg', 'audio/webm'])
on conflict (id) do nothing;
drop policy if exists "zor an sesi: aile okur" on storage.objects;
create policy "zor an sesi: aile okur" on storage.objects for select to authenticated
  using (bucket_id = 'abc' and (storage.foldername(name))[1] = public.my_family_id()::text);
drop policy if exists "zor an sesi: aile yükler" on storage.objects;
create policy "zor an sesi: aile yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'abc' and (storage.foldername(name))[1] = public.my_family_id()::text);
drop policy if exists "zor an sesi: aile siler" on storage.objects;
create policy "zor an sesi: aile siler" on storage.objects for delete to authenticated
  using (bucket_id = 'abc' and (storage.foldername(name))[1] = public.my_family_id()::text);
drop policy if exists "zor an sesi: bağlı uzman dinler" on storage.objects;
create policy "zor an sesi: bağlı uzman dinler" on storage.objects for select to authenticated
  using (bucket_id = 'abc' and exists (
    select 1 from public.abc_events e where e.audio_path = storage.objects.name and public.clinic_sees_child(e.child_id)));

-- Kontrol (SQL Editor'de sonuç olarak görünür): iki kova da listelenmeli
select id, public, file_size_limit from storage.buckets where id in ('mail', 'abc') order by id;
