-- test: supabase/tests/100_ai_quota.sql
--
-- MUTASYON: iadeyi idempotanslıktan çıkar (`refunded_at is null` koşulunu sök).
-- BEKLENEN: 100'ün "ikinci iade FALSE döner — idempotent" ve "ikinci iade
-- sayıyı DEĞİŞTİRMEDİ — hak basılamıyor" iddiaları kırmızı.
--
-- NEDEN BU BİR KORUMA: edge fonksiyon iadeyi ağ hatasında yeniden deneyebilir
-- ve `refund_ai_use` iki kez çağrılabilir. Koşul olmadan ikinci çağrı
-- `refunded_at`i tazeler; tek satır için zararsız görünür ama koşulun yokluğu
-- "iade edilmiş bir satırı yeniden iade etmek" yolunu açık bırakır ve asıl
-- tehlike şudur: aynı mantık bir döngüde çağrılırsa kullanıcı SINIRSIZ hak
-- açabilir. Koruma tek satırlık koşulda.
-- NOT: iki govde de goc dosyasindan URETILDI. Kaynak:
-- supabase/migrations/20260912000500_ai_refund.sql (0083).
-- ILK YAZIMDA @UNDO BAYATLAMISTI: Task 13 `p_capped` parametresini
-- kaldirdi (istemci kota tavanini kapatabiliyordu) ve geri alma IKI
-- ARGUMANLI surumu yeniden yaratiyordu — yani ikinci bir asiri yukleme.
create or replace function public.refund_ai_use(p_call_id bigint)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_hit int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_call_id is null then
    return false;
  end if;

  -- TAVAN HER ZAMAN UYGULANIR. Parametreyle gevsetilemez.
  if not public.bump_rate_limit(
       'ai_refund',
       public.config_int('ai_refund_daily', 10),
       public.istanbul_day()::text) then
    return false;
  end if;

  -- IDEMPOTENT: `refunded_at is null` kosulu iki kez cagrilmayi zararsiz
  -- kiliyor. Olmasaydi edge fonksiyonun yeniden denemesi ikinci bir yuva
  -- acardi — yani hak BASARDI.
  update public.ai_calls c
     set refunded_at = now()
   where c.id = p_call_id
     and c.user_id = v_uid
     and true;

  get diagnostics v_hit = row_count;
  return v_hit > 0;
end
$fn$;
revoke execute on function public.refund_ai_use(bigint) from public, anon;
grant  execute on function public.refund_ai_use(bigint) to authenticated;
-- @UNDO
create or replace function public.refund_ai_use(p_call_id bigint)
returns boolean
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_hit int;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if p_call_id is null then
    return false;
  end if;

  -- TAVAN HER ZAMAN UYGULANIR. Parametreyle gevsetilemez.
  if not public.bump_rate_limit(
       'ai_refund',
       public.config_int('ai_refund_daily', 10),
       public.istanbul_day()::text) then
    return false;
  end if;

  -- IDEMPOTENT: `refunded_at is null` kosulu iki kez cagrilmayi zararsiz
  -- kiliyor. Olmasaydi edge fonksiyonun yeniden denemesi ikinci bir yuva
  -- acardi — yani hak BASARDI.
  update public.ai_calls c
     set refunded_at = now()
   where c.id = p_call_id
     and c.user_id = v_uid
     and c.refunded_at is null;

  get diagnostics v_hit = row_count;
  return v_hit > 0;
end
$fn$;
revoke execute on function public.refund_ai_use(bigint) from public, anon;
grant  execute on function public.refund_ai_use(bigint) to authenticated;
