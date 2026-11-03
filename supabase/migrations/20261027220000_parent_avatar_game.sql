-- Ebeveynin oyundaki yüzü (kullanıcı isteği ve seçimi 27 Ekim 2026: "Çocuğun seni oyunda nasıl görsün"; Okti'nin üç anne ve
-- üç baba hâli, kimlikler sozlesme/durumlar.md §6a). Çocuk oturumu profiles'ı okuyamaz; bu yüzden çocuğun mesaj ve hediye
-- işlevleri gönderen ebeveynin avatar kimliğini de döndürür (from_avatar). Oyun tanımadığı değerde varsayılan Okti yüzünü gösterir.
-- Tekrar çalıştırılabilir. Veri değişmez; yalnız iki işlevin yanıtına alan eklenir.

-- 1) Sohbet: from_avatar (ebeveynden gelen satırda gönderenin profiles.avatar değeri). Dönüş tipi json, aynı kalır.
create or replace function public.child_messages(p_limit integer default 100)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := public.my_child_id();
begin
  if me is null then raise exception 'Bağlantı yok' using errcode = '42501'; end if;
  return coalesce((
    select json_agg(x order by x.created_at) from (
      select m.id, m.sender, m.kind, m.body, m.media_path, m.duration_ms, m.created_at, m.read_at,
             p.nickname as from_name, p.avatar as from_avatar
        from public.messages m
        left join public.profiles p on m.sender = 'parent' and p.id = m.sender_id
       where m.child_id = me
       order by m.created_at desc limit least(greatest(coalesce(p_limit, 100), 1), 300)) x), '[]'::json);
end $$;
revoke execute on function public.child_messages(integer) from public, anon;
grant execute on function public.child_messages(integer) to authenticated;

-- 2) Bekleyen hediyeler: from_avatar (gönderenin bugünkü avatarı; hesabı silinmişse null). Dönüş tipi değiştiği için
-- düşürülüp yeniden kurulur; izinler aynı.
drop function if exists public.child_gifts_pending();
create function public.child_gifts_pending()
returns table (id uuid, item_id text, from_name text, note text, created_at timestamptz, from_avatar text)
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := public.my_child_id();
begin
  if me is null then
    raise exception 'Bağlantı yok' using errcode = '42501';
  end if;
  return query select g.id, g.item_id, g.from_name, g.note, g.created_at, p.avatar
    from public.child_gifts g
    left join public.profiles p on p.id = g.from_user
    where g.child_id = me and g.claimed_at is null order by g.created_at;
end $$;
revoke execute on function public.child_gifts_pending() from public, anon;
grant execute on function public.child_gifts_pending() to authenticated;
