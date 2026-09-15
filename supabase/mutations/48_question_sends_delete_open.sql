-- test: supabase/tests/085_question_sends.sql
--
-- MUTASYON: question_sends DELETE'i istemciye geri ac.
-- BEKLENEN: 085'in "DELETE yetkisi YOK" ve "gonderen kendi gonderimini
-- SILEMIYOR" iddialari kirmizi.
--
-- NEDEN BU BIR KORUMA: `sends_delete_own` politikasi 0008'den beri hem
-- gonderene hem aliciya satir silme hakki veriyordu ve hicbir lockdown gocu
-- bu tablo icin `revoke_delete` yazmamisti. Bu, 0050a'nin "satir DURUYOR,
-- moderasyon izi kaybolmaz" degismezini deliyordu: taciz eden bir gonderen,
-- alici sikayet etmeden ONCE satiri silerse `report_received_question`
-- "bu gonderim sana ait degil" ile patlar ve sikayet HIC acilamaz.
grant delete on public.question_sends to authenticated;
-- @UNDO
revoke delete on public.question_sends from public, anon, authenticated;
