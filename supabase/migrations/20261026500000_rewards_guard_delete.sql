-- =====================================================================
-- Hata düzeltmesi (öneri, 26 Ekim 2026; GameApp2 test hesabı temizliğinde bulundu):
--   Ödül ekleyen ebeveynin hesabı silinince rewards.created_by sunucuca null'a çekilir (on delete set null).
--   rewards_guard bu güncellemede de "Premium" denetimi yaptığı için, ailesi ücretsiz planda ve ailede başka ebeveyn
--   varsa HESAP SİLME HATA VERİYORDU ("Bu özellik Premium üyelikte: ödüller"). KVKK silme hakkı engellenmemeli.
--   Düzeltme: yalnız created_by değişen (sistem) güncellemesi denetimsiz geçer; ebeveynin düzenlemesi eskisi gibi denetlenir.
-- Tekrar çalıştırılabilir.
-- =====================================================================
create or replace function public.rewards_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.created_by is distinct from old.created_by
     and (to_jsonb(new) - 'created_by' - 'updated_at') = (to_jsonb(old) - 'created_by' - 'updated_at') then
    return new;   -- hesap silinince created_by → null (yalnız sunucu; created_by istemciye yazılabilir değil)
  end if;
  perform public.require_full_access(new.family_id, 'ödüller');
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    if (select count(*) from public.rewards r where r.family_id = new.family_id) >= 100 then
      raise exception 'En çok 100 ödül eklenebilir';
    end if;
  end if;
  -- seçilen çocuklar bu aileden olmalı (tekrarlar atılır)
  new.child_ids := coalesce((select array_agg(distinct x) from unnest(new.child_ids) x), '{}');
  if exists (select 1 from unnest(new.child_ids) x where public.child_family(x) is distinct from new.family_id) then
    raise exception 'Çocuk bulunamadı';
  end if;
  new.title := trim(new.title);
  return new;
end $$;
revoke execute on function public.rewards_guard() from public, anon, authenticated;
