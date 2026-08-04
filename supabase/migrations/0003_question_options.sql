-- 0003 — Sorulara AI ile çıkarılan şıklar + doğru şık indeksi
-- Supabase → SQL Editor'da çalıştır.

alter table public.mistakes
  add column if not exists options       jsonb,  -- [{"label":"A","text":"4"}, ...]
  add column if not exists correct_index int;    -- options içindeki doğru şıkkın 0-tabanlı indeksi
