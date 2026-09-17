-- 216 — Sessiz saatler SUNUCUDA (0100)
--
-- Ayarlar'daki "Bu aralıkta bildirim gönderilmez" sözü Task 17'ye kadar
-- yalnızca CİHAZDA planlanan hatırlatmalar için geçiyordu: aralık
-- `shared_preferences`ta duruyor, `send_push` onu hiç bilmiyordu. Arkadaştan
-- gelen her bildirim gecenin ortasında da gidiyordu.
--
-- GÖZLEM NOKTASI `push_cursors`. `send_push` imleci `net.http_post`tan HEMEN
-- ÖNCE yazıyor, yani satırın varlığı "gönderim denendi" demek. HTTP'nin
-- gerçekten gidip gitmediği bu dosyanın konusu değil (ve test ortamında
-- gitmiyor — fonksiyon kendi `exception when others` dalında yutuyor).

begin;
set search_path to public, extensions, tests;

select plan(6);

select tests.create_supabase_user('alice');

-- `send_push` önce push_url/push_service_key arıyor; yoksa uyarıp ÇIKIYOR ve
-- imleç hiç yazılmıyor. Bu satırlar olmadan "gönderilmedi" iddiaları YANLIŞ
-- SEBEPLE yeşil kalırdı.
insert into public.app_config (key, value)
values ('push_url', 'http://127.0.0.1:1/push'),
       ('push_service_key', 'test')
on conflict (key) do update set value = excluded.value;

-- ================================================== SESSİZ SAATİN İÇİNDE
update public.profiles
   set quiet_start = extract(hour from now() at time zone 'Europe/Istanbul')::int,
       quiet_end   = (extract(hour from now() at time zone 'Europe/Istanbul')::int + 1) % 24
 where id = tests.get_supabase_uid('alice');

select lives_ok(
  $$ select public.send_push(tests.get_supabase_uid('alice'),
                             'question_received', 'Bob') $$,
  'sessiz saatte çağrı hata vermiyor — sessizce çıkıyor');

select is((select count(*)::int from public.push_cursors
            where user_id = tests.get_supabase_uid('alice')),
          0,
          'SESSİZ SAATTE bildirim GÖNDERİLMİYOR (imleç yazılmadı)');

-- ================================================== SESSİZ SAATİN DIŞINDA
update public.profiles
   set quiet_start = (extract(hour from now() at time zone 'Europe/Istanbul')::int + 2) % 24,
       quiet_end   = (extract(hour from now() at time zone 'Europe/Istanbul')::int + 3) % 24
 where id = tests.get_supabase_uid('alice');

select lives_ok(
  $$ select public.send_push(tests.get_supabase_uid('alice'),
                             'question_received', 'Bob') $$,
  'aralık dışında çağrı yürüyor');

select isnt((select count(*)::int from public.push_cursors
              where user_id = tests.get_supabase_uid('alice')),
            0,
            'aralık DIŞINDA bildirim gönderiliyor — süzgeç her şeyi kesmiyor');

-- ================================================== BOŞ ARALIK
-- Başlangıç ile bitiş eşitse sessiz saat YOK. İstemcideki
-- `AppSettings.isQuietHour` ile birebir aynı kural.
delete from public.push_cursors where user_id = tests.get_supabase_uid('alice');
update public.profiles
   set quiet_start = 3, quiet_end = 3
 where id = tests.get_supabase_uid('alice');

select public.send_push(tests.get_supabase_uid('alice'), 'question_received', 'Bob');
select isnt((select count(*)::int from public.push_cursors
              where user_id = tests.get_supabase_uid('alice')),
            0,
            'başlangıç = bitiş ise sessiz saat YOK, bildirim gidiyor');

-- ================================================== YAZMA YOLU
-- Sütunlar kilitli; tek yazma yolu `set_quiet_hours`.
select tests.authenticate_as('alice');
select throws_ok(
  $$ select public.set_quiet_hours(25, 8) $$,
  '22023',
  null,
  'aralık dışı saat REDDEDİLİYOR — sessizce kırpılmıyor');

select * from finish();
rollback;
