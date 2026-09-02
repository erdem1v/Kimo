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

select plan(13);

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
select tests.authenticate_as('mallory');
select is(
  (select avatar_path from public.profiles_public
    where id = tests.get_supabase_uid('alice')),
  null,
  'yabancı için profiles_public.avatar_path null (toplu döküm yol sızdırmıyor)'
);

select tests.authenticate_as('bob');
select isnt(
  (select avatar_path from public.profiles_public
    where id = tests.get_supabase_uid('alice')),
  null,
  'arkadaş için avatar_path dolu (arkadaş listesi bozulmuyor)'
);

select tests.authenticate_as('alice');
select isnt(
  (select avatar_path from public.profiles_public
    where id = tests.get_supabase_uid('alice')),
  null,
  'kendi profilinde avatar_path dolu'
);

-- Görünümün geri kalanı yabancılar için çalışmaya devam ediyor (arama, lig).
select tests.authenticate_as('mallory');
select isnt(
  (select nickname from public.profiles_public
    where id = tests.get_supabase_uid('alice')),
  null,
  'görünümün diğer kolonları etkilenmedi'
);

select * from finish();
rollback;
