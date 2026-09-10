-- test: supabase/tests/290_curriculum.sql
--
-- MUTASYON: yazma yolundaki konu doğrulamasını düşür (0071 öncesine dön).
-- BEKLENEN: 290'ın "ağaç dışı konu REDDEDİLİYOR" ve "ek konular da
-- doğrulanıyor" iddiaları kırmızı.
--
-- Neden bu mutasyon: bu, Task 09'a kadarki DAVRANIŞIN TA KENDİSİ.
-- `mistakes.subject/concept` serbest `text`ti; ne FK ne CHECK vardı ve edge
-- function AI'ın önerisini yalnızca `konu_valid` diye işaretliyordu. Yani
-- tetikleyici düştüğünde hiçbir şey patlamaz, hiçbir test doğal olarak
-- kırmızıya dönmez — uygulama eskisi gibi çalışır. Ayırt eden tek şey 290'ın
-- reddi GERÇEKTEN sınaması.
--
-- Tetikleyici FONKSİYONU duruyor: yalnızca bağ koparılıyor. Böylece geri alma
-- tek satır ve gövdenin iki kopyası olmuyor.
drop trigger if exists mistakes_topic_check on public.mistakes;

-- @UNDO
drop trigger if exists mistakes_topic_check on public.mistakes;
create trigger mistakes_topic_check
  before insert or update on public.mistakes
  for each row
  execute function public.mistakes_topic_check();
