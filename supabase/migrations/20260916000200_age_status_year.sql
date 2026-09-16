-- 0097 — `my_age_status` doğum yılını da döndürüyor (Task 14 · K2)
--
-- BULGU: Ayarlar'daki "Doğum yılı" satırı değer göstermiyordu; yalnızca
-- "bir kez yazılır, sonradan değiştirilemez" notunu çiziyordu. Hemen
-- üstündeki "Sınav yılı" satırı ise değerini gösteriyor. Kullanıcı kendi
-- kayıtlı doğum yılını uygulamanın hiçbir yerinde göremiyordu — üstelik
-- DEĞİŞTİREMEDİĞİ bir değer olduğu için görebilmesi daha da önemli.
--
-- Sebep istemcide değil BURADAYDI: fonksiyon yılın kendisini hiç döndürmüyor,
-- yalnızca "yazılmış mı" ve "reşit mi" bilgisini veriyordu. 0063'ün yorumu bu
-- kararı açıkça yazıyor ("Yaşın KENDİSİNİ döndürmüyor — istemcinin ihtiyacı
-- yılın yazılıp yazılmadığı"). Artık ihtiyaç var.
--
-- YAŞ KAPISINA DOKUNULMUYOR: karar hâlâ sunucuda (`set_birth_year` 13 altını
-- ayrı bir SQLSTATE ile reddediyor), `is_minor_now` aynı, politikalar aynı.
-- Değişen tek şey, kullanıcının KENDİ yılını okuyabilmesi.
--
-- DROP + CREATE, `create or replace` DEĞİL. OUT parametrelerinin tanımladığı
-- satır tipi değişiyor (`birth_year` ekleniyor) ve Postgres bunu `create or
-- replace` ile kabul etmiyor — SONA eklemek de dahil. Deponun 5. statik
-- kontrolü zaten bunu yakalıyor. Fonksiyon hiçbir görünüm ya da fonksiyon
-- içinden çağrılmıyor (tek çağıran istemci RPC'si), dolayısıyla düşürmek bir
-- zincir etkisi yaratmıyor.
--
-- DROP GRANT'I SİLER: alttaki iki satır zorunlu, isteğe bağlı değil.
drop function if exists public.my_age_status();

create function public.my_age_status()
returns table (
  birth_year_set boolean,
  is_minor       boolean,
  birth_year     int
)
language sql stable security definer set search_path = public
as $fn$
  select
    coalesce((select p.birth_year is not null
                from public.profiles p where p.id = auth.uid()), false),
    public.is_minor_now(auth.uid()),
    (select p.birth_year from public.profiles p where p.id = auth.uid());
$fn$;

revoke execute on function public.my_age_status() from public, anon;
grant  execute on function public.my_age_status() to authenticated;

comment on function public.my_age_status() is
  'Kullanıcının yaş kapısı durumu: yıl yazılmış mı, reşit mi ve YILIN '
  'KENDİSİ (0097). Yıl yalnızca sahibine dönüyor — `auth.uid()` dışında '
  'hiçbir kimlik okunmuyor.';
