-- test: supabase/tests/240_persona.sql
--
-- MUTASYON: metinsiz bir senaryo ekle — yani "yeni bildirim türü eklendi ama
-- cümleleri yazılmadı" durumunu üret. Gerçek hayatta bu böyle oluyor: tür
-- eklenir, dört personanın metni sonra yazılacak diye bırakılır ve unutulur.
-- BEKLENEN: 240'ın "her senaryo × persona hücresinde en az beş cümle var"
-- iddiası kırmızı (ve senaryo sayısı iddiası da).
--
-- Neden bu mutasyon: bildirimin sessizce hiç gitmemesi bu paketin kapattığı
-- asıl hata. Kullanıcı "bana bildirim gelmiyor" demeden kimse fark edemiyordu.
insert into public.push_kinds (kind, title)
values ('metinsiz_senaryo', 'Metni yazılmamış senaryo');
-- @UNDO
delete from public.push_kinds where kind = 'metinsiz_senaryo';
