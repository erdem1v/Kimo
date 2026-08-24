-- AYT düzeltmeleri.
-- Çember ve Daire soruları TYT Geometri'den AYT Geometri'ye taşınır.
begin;
update public.mistakes set exam = 'AYT', concept = 'Çemberde Temel Kavramlar'
 where source = 'meb' and exam = 'TYT' and subject = 'Geometri'
   and concept = 'Çember ve Daire';
commit;
