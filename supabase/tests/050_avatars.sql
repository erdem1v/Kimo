-- 050 — H5: avatar kovası + profiles_public'teki yol sızıntısı
--
-- Eski politika `using (bucket_id = 'avatars')` idi: sahiplik ya da ilişki
-- kontrolü YOK, yani oturum açan herkes tüm kovayı listeleyip her nesneye imzalı
-- URL üretebiliyordu. Kullanıcının "sildiği" avatarlar da dahil — removeAvatar
-- yalnızca DB sütununu null'lıyor, dosyayı hiç silmiyordu.
--
-- profiles_public da avatar_path'i HERKES için döndürüyordu ve görünüm
-- authenticated'a doğrudan açık; `select * from profiles_public` tüm kullanıcı
-- tabanının depolama yollarını döküyordu.

begin;
set search_path to public, extensions, tests;

select plan(16);

select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');       -- alice'in arkadaşı
select tests.create_supabase_user('mallory');   -- yabancı

insert into public.friendships (requester_id, addressee_id, status)
values (tests.get_supabase_uid('alice'), tests.get_supabase_uid('bob'), 'accepted');

update public.profiles
   set avatar_path = tests.get_supabase_uid('alice')::text || '/guncel.jpg'
 where id = tests.get_supabase_uid('alice');

insert into storage.objects (bucket_id, name) values
  ('avatars', tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
  -- Kullanıcının değiştirdiği eski dosya: profilde DURMUYOR.
  ('avatars', tests.get_supabase_uid('alice')::text || '/eski.jpg');

-- ==================================================== fonksiyon davranışı
select tests.authenticate_as('alice');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
          true, 'kendi güncel avatarını okuyabiliyor');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/eski.jpg'),
          true, 'kendi ESKİ dosyasını okuyabiliyor (artık süpürebilmek için şart)');

select tests.authenticate_as('bob');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
          true, 'arkadaşı güncel avatarı görebiliyor');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/eski.jpg'),
          false, 'arkadaşı bile ESKİ dosyayı göremiyor');

select tests.authenticate_as('mallory');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
          false, 'H5: yabancı avatarı okuyamıyor');

-- ==================================================== ENGEL (0089)
-- `can_read_avatar`ın üç dalının HİÇBİRİNDE engel kontrolü yoktu. İki ayrı
-- sızıntı vardı ve ikisi de DEPOLAMA düzeyinde (arayüz ayrıntısı değil):
--   a) ARKADAŞ dalı: engelleme arkadaşlığı SİLMİYOR ve `are_friends` engelleri
--      hiç görmüyor, yani engelli "eski arkadaş" avatarı açık kalıyordu.
--   b) KOHORT dalı: engellediğin kişiyle aynı lig grubundaysan avatarına
--      imzalı URL üretebiliyordun.
-- Tek satırlık düzeltme (`exists()` bloğunun sonuna engel kontrolü) ikisini
-- birden kapatıyor; kendi klasörün dalı etkilenmiyor.
select tests.reset_role();
insert into public.user_blocks (blocker_id, blocked_id)
values (tests.get_supabase_uid('bob'), tests.get_supabase_uid('alice'));

select tests.authenticate_as('bob');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
          false,
          'ENGELLEDİĞİ eski arkadaşının avatarını ARTIK okuyamıyor');

-- Kohort dalı: engel kalkarsa kohort üyeliği tek başına yeterli mi?
select tests.reset_role();
delete from public.user_blocks
 where blocker_id = tests.get_supabase_uid('bob')
   and blocked_id = tests.get_supabase_uid('alice');
insert into public.league_cohorts (id, tier, week_start)
values ('cccccccc-0000-0000-0000-000000000000', 'bronz', public.istanbul_week());
insert into public.league_members (cohort_id, user_id, xp) values
  ('cccccccc-0000-0000-0000-000000000000', tests.get_supabase_uid('alice'), 10),
  ('cccccccc-0000-0000-0000-000000000000', tests.get_supabase_uid('mallory'), 5);

select tests.authenticate_as('mallory');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
          true, 'aynı kohorttaki yabancı avatarı görebiliyor (kohort dalı açık)');

select tests.reset_role();
insert into public.user_blocks (blocker_id, blocked_id)
values (tests.get_supabase_uid('mallory'), tests.get_supabase_uid('alice'));
select tests.authenticate_as('mallory');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
          false, 'ENGELLEDİĞİNDE kohort dalı da kapanıyor');
select is(public.can_read_avatar(
            tests.get_supabase_uid('alice')::text || '/eski.jpg'),
          false, 'H5: yabancı eski dosyayı da okuyamıyor');

-- ==================================================== depolama uçtan uca
select is_empty(
  format('select 1 from storage.objects
           where bucket_id = ''avatars'' and name = %L',
         tests.get_supabase_uid('alice')::text || '/guncel.jpg'),
  'RLS: yabancı avatar nesnesini göremiyor'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'),
  0,
  'H5: yabancı avatar kovasını LİSTELEYEMİYOR (eskiden tamamı görünüyordu)'
);

select tests.authenticate_as('alice');
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'),
  2,
  'sahibi kendi klasörünü listeleyebiliyor (artık süpürme buna dayanıyor)'
);

-- ==================================================== profiles_public gating
-- Kolon KALDIRILMADI, İLİŞKİYE bağlandı: arkadaş listesi avatarları
-- kaybetmesin ama toplu döküm depolama yolu sızdırmasın.
--
-- OKUMA `profiles_by_ids` RPC'SİNDEN (Task 08 / göç 0068): görünümün kendisi
-- artık istemciye kapalı — "toplu döküm" yolu bu dosyanın başlığında bir risk
-- olarak yazılıydı ve 0068 onu tamamen kapattı. Görünümün İÇİNDEKİ ilişkiye
-- bağlı avatar kuralı aynen duruyor; aşağıdaki iddialar onu sınıyor.
select tests.authenticate_as('mallory');
select is(
  (select p.avatar_path from public.profiles_by_ids(
     array[tests.get_supabase_uid('alice')]) p),
  null,
  'yabancı için profiles_public.avatar_path null (toplu döküm yol sızdırmıyor)'
);

select tests.authenticate_as('bob');
select isnt(
  (select p.avatar_path from public.profiles_by_ids(
     array[tests.get_supabase_uid('alice')]) p),
  null,
  'arkadaş için avatar_path dolu (arkadaş listesi bozulmuyor)'
);

select tests.authenticate_as('alice');
select isnt(
  (select p.avatar_path from public.profiles_by_ids(
     array[tests.get_supabase_uid('alice')]) p),
  null,
  'kendi profilinde avatar_path dolu'
);

-- Görünümün geri kalanı yabancılar için çalışmaya devam ediyor (lig, profil
-- kartı). Aşırı kilitleme karşı-iddiası: 0068 avatarı değil DİZİN DÖKÜMÜNÜ
-- kapattı; kimliği bilinen bir profil hâlâ okunabiliyor.
select tests.authenticate_as('mallory');
select isnt(
  (select p.nickname from public.profiles_by_ids(
     array[tests.get_supabase_uid('alice')]) p),
  null,
  'görünümün diğer kolonları etkilenmedi'
);

select * from finish();
rollback;
