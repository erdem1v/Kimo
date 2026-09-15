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
create or replace function public.refund_ai_use(
  p_call_id bigint,
  p_capped  boolean default true
)
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
  if p_capped and not public.bump_rate_limit(
       'ai_refund',
       public.config_int('ai_refund_daily', 10),
       public.istanbul_day()::text) then
    return false;
  end if;

  update public.ai_calls c
     set refunded_at = now()
   where c.id = p_call_id
     and c.user_id = v_uid;

  get diagnostics v_hit = row_count;
  return v_hit > 0;
end
$fn$;
revoke execute on function public.refund_ai_use(bigint, boolean) from public, anon;
grant  execute on function public.refund_ai_use(bigint, boolean) to authenticated;
-- @UNDO
create or replace function public.refund_ai_use(
  p_call_id bigint,
  p_capped  boolean default true
)
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

  -- Kötüye kullanım sınırı yalnızca KULLANICI KAYNAKLI iadeler için. Altyapı
  -- hatası (`p_capped = false`) sınıra dahil değil.
  if p_capped and not public.bump_rate_limit(
       'ai_refund',
       public.config_int('ai_refund_daily', 10),
       public.istanbul_day()::text) then
    return false;
  end if;

  -- İDEMPOTENT: `refunded_at is null` koşulu iki kez çağrılmayı zararsız
  -- kılıyor. Olmasaydı edge fonksiyonun yeniden denemesi ikinci bir yuva
  -- açardı — yani hak BASARDI.
  update public.ai_calls c
     set refunded_at = now()
   where c.id = p_call_id
     and c.user_id = v_uid
     and c.refunded_at is null;

  get diagnostics v_hit = row_count;
  return v_hit > 0;
end
$fn$;

revoke execute on function public.refund_ai_use(bigint, boolean) from public, anon;
grant  execute on function public.refund_ai_use(bigint, boolean) to authenticated;
