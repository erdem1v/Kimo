-- test: supabase/tests/260_ai_cache.sql
--
-- MUTASYON: satırları her güncellemede tazele — TTL hiçbir zaman dolmasın.
-- BEKLENEN: 260'ın "24 saatten eski kayıt isabet etmiyor" iddiası kırmızı.
--
-- Neden bu mutasyon: yalnızca yetki iddialarını mutasyona sokmak, "tablo
-- kapalı ama önbellek sonsuza kadar taze" durumunu yeşil bırakırdı. O hâlde
-- kullanıcı aylar önceki bir fotoğrafın eski sonucunu alır ve yeniden
-- analiz ettiremez — sessizce yanlış veri.
--
-- Fonksiyonu yeniden yazmak yerine tabloya tetikleyici takıyoruz: geri alma
-- iki satır ve mutasyon dosyası fonksiyonun eski bir kopyasını taşımıyor.
create or replace function public.__mut_keep_fresh() returns trigger
language plpgsql as $$
begin
  new.created_at := now();
  return new;
end
$$;

create trigger __mut_keep_fresh_trg
  before update on public.ai_result_cache
  for each row execute function public.__mut_keep_fresh();
-- @UNDO
drop trigger if exists __mut_keep_fresh_trg on public.ai_result_cache;
drop function if exists public.__mut_keep_fresh();
