-- 20261105180000_macera_templates: katalogda "Ev Görevleri" geçen başlık kalmadı
do $$
begin
  if exists (select 1 from public.task_templates where title ilike '%ev görev%') then
    raise exception 'katalogda hâlâ "Ev Görevleri" geçiyor';
  end if;
  if (select title from public.task_templates where key = 'gs_focus_022') <> 'Günün bütün maceralarını bitir' then
    raise exception 'gs_focus_022 başlığı güncellenmedi';
  end if;
end $$;
