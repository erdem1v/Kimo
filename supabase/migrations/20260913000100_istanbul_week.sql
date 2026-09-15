-- 0088 — `istanbul_week()` yardımcısı (Task 13 · Paket 1)
--
-- SORUN: `(date_trunc('week', now() at time zone 'Europe/Istanbul'))::date`
-- deposunda **39 satırda** kopyalanmış. Tek bir karakter farkı (yanlış saat
-- dilimi yazımı, eksik `::date`) haftayı sessizce kaydırır ve kohort eşleşmesi
-- 0 satır döndürür — tam olarak `20260901000900_progress_rpcs.sql:25-26`'da
-- uyarılan tuzak. `istanbul_day()` emsali 0042'den beri var; haftanın
-- karşılığı hiç yazılmamıştı.
--
-- KAPSAM YALNIZCA YÜRÜRLÜKTEKİ NESNELER. Tarihsel göçler, testler ve
-- mutasyonlar ELLENMİYOR: uygulanmış bir göç o günün gerçeğini anlatıyor ve
-- yeniden yazmak geçmişi yalanlamak olurdu (deponun `send_push` için verdiği
-- aynı karar). Bu göç yalnızca yardımcıyı yaratıyor; çağrı yerleri onu
-- kullanan göçlerde değişiyor.
--
-- GERİ ALMA: `drop function public.istanbul_week();` ve çağıranları satır içi
-- ifadeye döndürün.

-- `istanbul_day()` (0042) ile BİREBİR aynı desen: `stable`, `security definer`
-- DEĞİL (hiçbir tabloya bakmıyor), `set search_path` yok çünkü şema nesnesi
-- kullanmıyor.
create or replace function public.istanbul_week()
returns date
language sql
stable
as $fn$
  select (date_trunc('week', now() at time zone 'Europe/Istanbul'))::date;
$fn$;

-- Görünümlerin SELECT listesinden çağrılıyor (`my_daily_state`), yani
-- `authenticated` EXECUTE edebilmeli — `istanbul_day()` ile aynı gerekçe.
-- Sızdırdığı bir şey yok: dönen değer bir takvim tarihi.
revoke execute on function public.istanbul_week() from public, anon;
grant  execute on function public.istanbul_week() to authenticated;

comment on function public.istanbul_week() is
  'Istanbul takvimine göre içinde bulunulan haftanın başlangıcı (pazartesi). '
  'Lig kohortları, haftalık XP ve seri pencereleri bu tek kaynaktan okur.';
