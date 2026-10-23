-- Yaş grupları "Otomatik"e (kullanıcı kararı, 23 Ekim 2026): ailelerin daha önce elle kaydettiği gruplar silinir;
-- null = grup doğum gününden hesaplanır (age_band, 20261023040000). Eski ParentApp çocuk eklerken her zaman bir grup
-- yazıyordu (çoğu A ya da C→B); bu kayıtlar artık yaşla birlikte kendiliğinden değişir.
--
-- TEK SEFERLİK: iş public.one_time_jobs tablosuna işaretlenir; dosya yeniden çalıştırılırsa hiçbir şey yapmaz, böylece
-- bundan sonra ebeveynin ParentApp'te bilerek seçtiği grup (set_child_age_band) korunur.

create table if not exists public.one_time_jobs (
  key text primary key,
  done_at timestamptz not null default now()
);
comment on table public.one_time_jobs is 'Tek seferlik veri işleri (yeniden çalıştırılınca atlanır). Uygulamalar erişmez.';
alter table public.one_time_jobs enable row level security;   -- politika yok: yalnız SQL Editor / sahip
revoke all on public.one_time_jobs from public, anon, authenticated;

do $job$
declare n int;
begin
  if exists (select 1 from public.one_time_jobs where key = 'age_band_reset_auto_20261023') then
    return;
  end if;
  update public.children set age_band = null where age_band is not null;
  get diagnostics n = row_count;
  insert into public.one_time_jobs(key) values ('age_band_reset_auto_20261023');
  raise notice 'Otomatik''e çevrilen çocuk: %', n;
end $job$;
