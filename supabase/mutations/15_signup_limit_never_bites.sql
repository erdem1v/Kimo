-- test: supabase/tests/250_signup_throttle.sql
--
-- MUTASYON: sayacı her yazmada sıfırla — limit hiçbir zaman ısırmasın.
-- BEKLENEN: 250'nin "saatlik limit aşılınca 429" ve "günlük limit aşılınca 429"
-- iddiaları kırmızı.
--
-- Neden bu mutasyon: bu testin KALBİ o iki iddia. Yalnızca yetki iddialarını
-- mutasyona sokmak, "sayaç kapalı ama hiçbir şeyi saymıyor" durumunu yeşil
-- bırakırdı — kayıt hız sınırının sessizce çalışmadığı hâl tam olarak budur ve
-- kimse fark etmezdi.
--
-- Kancayı yeniden yazmak yerine tabloya tetikleyici takıyoruz: geri alma tek
-- satır ve mutasyon dosyası fonksiyonun eski bir kopyasını taşımıyor (taşısaydı
-- fonksiyon değiştiğinde UNDO sessizce eski sürümü geri kurardı).
create or replace function public.__mut_zero_n() returns trigger
language plpgsql as $$
begin
  new.n := 0;
  return new;
end
$$;

create trigger __mut_zero_n_trg
  before insert or update on public.signup_throttle
  for each row execute function public.__mut_zero_n();
-- @UNDO
drop trigger if exists __mut_zero_n_trg on public.signup_throttle;
drop function if exists public.__mut_zero_n();
