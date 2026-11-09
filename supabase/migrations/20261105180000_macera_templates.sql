-- Ad kararı (kullanıcı, 5 Kasım 2026; durumlar.md 5B): oyundaki pano "Ev Görevleri" → "Maceralar".
-- Şablon kataloğunda pano adını anan iki başlık güncellenir. Ailelerin daha önce eklediği görevlerin başlığı değişmez.
-- Tekrar çalıştırılabilir.
update public.task_templates set title = 'Günün bütün maceralarını bitir'
 where key = 'gs_focus_022' and title is distinct from 'Günün bütün maceralarını bitir';
update public.task_templates set title = 'Oyuna girmeden önce bugünkü maceralarını bitir'
 where key = 'gs_focus_045' and title is distinct from 'Oyuna girmeden önce bugünkü maceralarını bitir';
