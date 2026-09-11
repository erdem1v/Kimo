-- test: supabase/tests/300_ad_reward.sql
--
-- MUTASYON: işlem kimliği tekil indeksini düşür.
-- BEKLENEN: 300'ün tekrar oynatma iddiası kırmızı.
--
-- Tekrar oynatma koruması KATALOGDA duruyor, fonksiyon mantığında değil.
-- İndeks düşünce fonksiyonun kendi ön kontrolü kalıyor ama eşzamanlı bir
-- tekrar artık iki hak üretebilir.
drop index if exists public.ad_rewards_txn_uniq;
-- @UNDO
create unique index if not exists ad_rewards_txn_uniq
  on public.ad_rewards (transaction_id) where transaction_id is not null;
