-- test: supabase/tests/010_profiles_column_lockdown.sql
--
-- MUTASYON: `profiles` UPDATE politikasının WITH CHECK'ini boşalt.
-- BEKLENEN: 010'un "WITH CHECK sahiplik koşulunu taşıyor" iddiası kırmızı.
--
-- Neden bu mutasyon TAM OLARAK bu biçimde: Task 01'in tuzağı, `WITH CHECK`
-- eklerken `USING`'i tekrar etmeyi unutmaktı. `WITH CHECK`'i olmayan bir
-- UPDATE politikasında `USING` yeni satıra da uygulanıyor; `with check (true)`
-- yazmak o örtük korumayı kaldırıyor ve satır sahipliği denetimsiz kalıyor.
--
-- Bugün istismar edilemez (`id` sütun ayrıcalığında kilitli), bu yüzden
-- çalışma zamanı testi bunu YAKALAYAMAZ — ve tam bu yüzden iddia katalog
-- düzeyinde yazıldı. Mutasyon, o katalog iddiasının gerçekten ayırt ettiğini
-- kanıtlıyor.
drop policy if exists "Kendi profilini güncelle" on public.profiles;
create policy "Kendi profilini güncelle"
  on public.profiles for update
  using      (auth.uid() = id)
  with check (true);

-- @UNDO
drop policy if exists "Kendi profilini güncelle" on public.profiles;
create policy "Kendi profilini güncelle"
  on public.profiles for update
  using      (auth.uid() = id)
  with check (auth.uid() = id);
