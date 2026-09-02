-- 0004 — Soruya sınav bilgisi (AI ile belirlenir): 'TYT' | 'AYT'
-- Ders (subject) ve konu (concept) mevcut kolonlarda tutulur; müfredat
-- kullanıcı düzeyinde (auth metadata) saklanır, satır başına gerekmez.
-- Supabase → SQL Editor'da çalıştır.

alter table public.mistakes
  add column if not exists exam text;  -- 'TYT' | 'AYT' | null
