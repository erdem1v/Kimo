-- 0002 — Hata bankasına aralıklı tekrar (spaced repetition) alanları
-- Supabase → SQL Editor'da çalıştır. (Şema v1 / schema.sql'den SONRA.)
--
-- Protokol: 1 → 3 → 7 → 30 gün (tek seferde doğruda ilerler), yanlışta 1 güne
-- sıfırlanır. 30'u geçince "mastered". 4+ sıfırlanma → "leech".

alter table public.mistakes
  add column if not exists correct_answer   text,
  add column if not exists step             int  not null default 0,
  add column if not exists next_review_date date not null default (current_date + 1),
  add column if not exists last_reviewed_at timestamptz,
  add column if not exists review_count     int  not null default 0,
  add column if not exists lapses           int  not null default 0,
  add column if not exists is_leech         boolean not null default false,
  add column if not exists mastered         boolean not null default false;

-- "Bugün tekrarı gelenler" sorgusunu hızlandır
create index if not exists mistakes_due_idx
  on public.mistakes (user_id, mastered, next_review_date);
