-- 0027 — push_lines'a RLS + "RLS'siz tablo kalmasın" güvencesi
--
-- SORUN: public.push_lines (bkz. push göçü) `enable row level security` almadan
-- yaratılmıştı — aynı dosyadaki iki kardeşi (device_tokens ve app_config) özenle
-- kilitlenmişken. Tablo bildirim metinlerini tutuyor ve send_push() onu okuyor.
--
-- ŞİDDET ORTAMA BAĞLI, o yüzden tahmin etmiyoruz: RLS kapalıyken erişim yalnızca
-- GRANT'lara bakar. Yeni Supabase projelerinde public şemadaki yeni tablolar
-- anon/authenticated'a otomatik açılmaz (config.toml'daki auto_expose_new_tables
-- notu), ama eski (legacy) davranışla kurulmuş bir projede tablo hem OKUNABİLİR
-- hem YAZILABİLİR olur — yani bildirim metni enjeksiyonu. Aşağıdaki düzeltme her
-- iki durumda da doğru; gerçek durumu raporlamak için göçten ÖNCE şunu çalıştırın:
--   select relname, relrowsecurity, relacl from pg_class
--    where oid = 'public.push_lines'::regclass;
--
-- send_push() SECURITY DEFINER olduğu için (sahibi postgres) metinleri okumaya
-- devam eder; app_config'te kullanılan kalıbın aynısı.

alter table public.push_lines enable row level security;
-- Politika YOK = authenticated/anon hiçbir satırı göremez ve yazamaz.
revoke all on public.push_lines from public, anon, authenticated;

-- app_config zaten RLS'liydi ama grant'ları hiç geri alınmamıştı. RLS tek başına
-- yeterli (politikasız tablo kimseye açılmaz); yine de savunma derinliği olarak
-- grant'ları da kaldırıyoruz — push sırrı ve servis jetonu burada duruyor.
revoke all on public.app_config from public, anon, authenticated;

-- ------------------------------------------------------------------ güvence
-- Değişmez 6: public şemasında RLS'siz tablo kalmaz. Bu blok bugünü doğrular ve
-- ileride RLS'siz bir tablo eklenirse göç zamanında gürültüyle patlar.
do $mig$
declare v_bad text[];
begin
  select array_agg(c.relname order by c.relname) into v_bad
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind = 'r'
     and not c.relrowsecurity;

  if v_bad is not null then
    raise exception 'RLS açık olmayan public tablo(lar): % — Değişmez 6 ihlali', v_bad;
  end if;
end
$mig$;
