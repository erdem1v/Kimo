-- 0042 — Elmas gerçek bir ödül hâline geliyor
--
-- SORUN: `profiles.gems` ölü bir sütundu. Varsayılanı 0'dı, hiçbir kod onu
-- artırmıyordu, ve arayüzde bir elmas göstergesi duruyordu. Onaylanan tasarım
-- göstergeyi koruyor ama satın alma bu sürümde YOK — yani elmas yalnızca ödül
-- olarak kazanılabilir. Kazanma yolu olmadan göstergeyi bırakmak, ürünün
-- geçmişteki hatasını (çalışmayan mekaniği çalışıyormuş gibi göstermek)
-- tekrarlamak olurdu.
--
-- KARAR (ürün): tek kaynak GÜNLÜK SANDIK. Tasarımdaki oturum sonu ekranında
-- ("Sandığı aç") zaten bu an var; sunucuda karşılığı `claim_daily_goal`.
--
-- NEDEN BURASI: `claim_daily_goal` günde en fazla bir kez çalışıyor
-- (`daily_goal_date`), satırı kilitliyor ve gerçekten çalışılmış olmasını
-- arıyor. Elmas için ayrı bir sayaç, ayrı bir tavan ve ayrı bir kötüye
-- kullanım yüzeyi açmaya gerek yok — mevcut garantiler aynen geçerli.
--
-- SATIN ALMA YOK: bu göç elmas HARCAMA yolu tanımlamıyor. Uygulama içi satın
-- alma ve reklam ayrı bir task; o gelene kadar elmas biriken bir ödül.

-- Ödül miktarı tek yerde. İstemci bu sayıyı bilmiyor, dönen `gems` değerini
-- gösteriyor; iki yerde tutulsaydı arayüz farklı bir sayı sayabilirdi.
create or replace function public.daily_chest_gems()
returns int language sql immutable as $$
  select 5;
$$;

revoke execute on function public.daily_chest_gems()
  from public, anon, authenticated;

-- Dönüş tipine `gems` eklendiği için düşürülüp yeniden yaratılıyor.
drop function if exists public.claim_daily_goal();

create or replace function public.claim_daily_goal()
returns table (
  xp int, weekly_xp int, streak int, league text, xp_awarded int,
  gems int, gems_awarded int
)
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid     uuid := auth.uid();
  v_today   date := (now() at time zone 'Europe/Istanbul')::date;
  v_claimed date;
  v_done    int;
  v_gems    int := 0;
  r         record;
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;

  -- Günde bir kez — kilitle, yoksa iki paralel çağrı iki bonus alır.
  select p.daily_goal_date into v_claimed
    from public.profiles p where p.id = v_uid for update;

  if v_claimed = v_today then
    -- Zaten alınmış: hata değil, sadece güncel değerleri döndür. Elmas da
    -- verilmez — sandık günde bir kez açılır.
    select * into r from public.apply_progress(0, false);
    return query
      select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded,
             p.gems, 0
        from public.profiles p where p.id = v_uid;
    return;
  end if;

  -- Bugün gerçekten çalışılmış mı? İstemcinin "hedefi tamamladım" beyanına
  -- güvenmiyoruz; en az bir ölçüm satırı aranıyor.
  --
  -- DÜRÜST SINIR (Task 01'den devralınan): "hedefi tamamladı mı" kararı
  -- istemcide kalıyor, çünkü hedef dinamik. Sunucunun garantisi daha dar ama
  -- net: günde EN FAZLA BİR KEZ ve ancak gerçekten çalışıldıysa.
  select count(*)::int into v_done
    from public.study_attempts a
   where a.user_id = v_uid
     and (a.created_at at time zone 'Europe/Istanbul')::date = v_today;

  if v_done = 0 then
    raise exception 'bugün hiç çalışılmamış' using errcode = '42501';
  end if;

  v_gems := public.daily_chest_gems();

  -- XP ve hedef günü `apply_progress`ten (tek UPDATE kuralı orada korunuyor).
  select * into r from public.apply_progress(50, false, v_today);

  -- Elmas ayrı bir UPDATE: `apply_progress`e elmas parametresi eklemek onu
  -- "ilerleme uygulayıcısı" olmaktan çıkarıp genel bir profil yazıcısına
  -- çevirirdi. `gems` hiçbir trigger'ı tetiklemiyor (on_friend_milestone
  -- yalnızca league/streak değişiminde çalışıyor), dolayısıyla ikinci UPDATE
  -- burada Task 01'in "tek update" kuralını ihlal etmiyor.
  update public.profiles p
     set gems = p.gems + v_gems
   where p.id = v_uid;

  return query
    select r.xp, r.weekly_xp, r.streak, r.league, r.xp_awarded,
           p.gems, v_gems
      from public.profiles p where p.id = v_uid;
end
$fn$;

revoke execute on function public.claim_daily_goal() from public, anon;
grant  execute on function public.claim_daily_goal() to authenticated;

comment on column public.profiles.gems is
  'Elmas. Yalnızca günlük sandıktan kazanılır (claim_daily_goal); istemci '
  'yazamaz. Harcama yolu bu sürümde YOK — satın alma ayrı bir task.';
