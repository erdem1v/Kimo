-- 0050 — Hata türü: dört sebep ve isteğe bağlı olması
--
-- İKİ DEĞİŞİKLİK, ikisi de onaylanan tasarımdan geliyor.
--
-- 1) SEBEP DİLİ DÖRDE ÇIKIYOR. Tasarım sistemi hata tipi dilini sabitliyor:
--    **bilgi eksiği · dikkatsizlik · süre · okuma hatası**. Koddaki enum üç
--    değer taşıyordu (kavram_eksikligi, islem_hatasi, dikkatsizlik) ve
--    "süre yetmedi" ile "yanlış okudum" hiç yoktu — bunlar YKS'de en sık
--    raporlanan iki sebep ve karşılıkları uydurulamaz.
--
--    Mevcut üç değer KALIYOR: `islem_hatasi` taşıyan satırlar var ve onları
--    yeniden anlamlandırmak veriyi bozardı. Arayüz dört sebebi gösteriyor,
--    `islem_hatasi` yalnızca eski kayıtlarda görünüyor.
--
-- 2) ZORUNLU OLMAKTAN ÇIKIYOR. Tasarımda alan açıkça "(isteğe bağlı)".
--    Sütun `not null` olduğu için istemci bir değer uydurmak zorundaydı —
--    kullanıcı seçmediğinde varsayılan bir tür yazmak, ölçülmemiş bir veriyi
--    ölçülmüş gibi göstermek olurdu. `null` = "belirtilmedi" gerçek bir durum.
--
-- SIRA UYARISI: `alter type ... add value` ile eklenen değer AYNI işlemde
-- KULLANILAMAZ (PostgreSQL kısıtı). Bu göç yeni değerleri yalnızca ekliyor,
-- kullanmıyor; ilk kullanım uygulamadan gelecek.

do $mig$
begin
  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
     where n.nspname = 'public' and t.typname = 'mistake_type'
       and e.enumlabel = 'sure_yetmedi'
  ) then
    alter type public.mistake_type add value 'sure_yetmedi';
  end if;

  if not exists (
    select 1 from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
     where n.nspname = 'public' and t.typname = 'mistake_type'
       and e.enumlabel = 'yanlis_okudum'
  ) then
    alter type public.mistake_type add value 'yanlis_okudum';
  end if;
end
$mig$;

alter table public.mistakes
  alter column mistake_type drop not null;

comment on column public.mistakes.mistake_type is
  'Hatanın sebebi — İSTEĞE BAĞLI. null = kullanıcı belirtmedi. Varsayılan bir '
  'değer yazılmıyor: ölçülmemiş veriyi ölçülmüş gibi göstermek olurdu.';
