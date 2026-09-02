-- 0021 — Anlık bildirimler (FCM): cihaz kayıtları, metinler ve tetikleyiciler
-- Supabase → SQL Editor'da çalıştır.
--
-- Aşama 1 (yerel bildirimler) cihazda çalışıyordu; anlık sosyal olaylar
-- (arkadaşlık isteği, gelen soru, çözülen soru) sunucudan gitmek zorunda.
-- Akış: DB tetikleyici → pg_net ile Edge Function → FCM → telefon.
--
-- Metinler burada tutuluyor: bildirimi sunucu ürettiği için maskot cümleleri
-- de sunucuda olmalı. Uygulama içindeki Dart metinleri yalnızca YEREL
-- bildirimler için kullanılır; ikisi farklı senaryolara hizmet eder.

create extension if not exists pg_net;

-- --------------------------------------------------------- cihaz kayıtları
create table if not exists public.device_tokens (
  user_id    uuid not null references auth.users(id) on delete cascade,
  token      text not null,
  platform   text not null default 'android',
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists tokens_select_own on public.device_tokens;
create policy tokens_select_own on public.device_tokens
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists tokens_upsert_own on public.device_tokens;
create policy tokens_upsert_own on public.device_tokens
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists tokens_update_own on public.device_tokens;
create policy tokens_update_own on public.device_tokens
  for update to authenticated using (auth.uid() = user_id);

drop policy if exists tokens_delete_own on public.device_tokens;
create policy tokens_delete_own on public.device_tokens
  for delete to authenticated using (auth.uid() = user_id);

-- ------------------------------------------------------------- yapılandırma
-- Edge Function adresi ve paylaşılan gizli anahtar. Kimseye açık değil;
-- yalnızca security definer fonksiyonlar okur.
create table if not exists public.app_config (
  key   text primary key,
  value text not null
);

alter table public.app_config enable row level security;
-- Politika yok = kimse okuyamaz (definer fonksiyonlar hariç).

-- ------------------------------------------------------ bildirim metinleri
create table if not exists public.push_lines (
  kind   text not null,   -- question_received | friend_request | question_solved
  mascot text not null,   -- ev_hanimi | arabeskci | sanayi_ustasi | akademisyen | ceo
  line   text not null
);

create index if not exists push_lines_idx on public.push_lines (kind, mascot);

-- Yeniden çalıştırılabilir olsun diye önce temizle.
delete from public.push_lines;

insert into public.push_lines (kind, mascot, line) values
-- ---------------------------------------------- arkadaştan soru geldi
('question_received','ev_hanimi','{ad} sana bir soru yolladı canım, bak bakalım.'),
('question_received','ev_hanimi','Arkadaşından soru geldi; {ad} çözebilecek misin diye merak ediyor.'),
('question_received','ev_hanimi','{ad}''ın gönderdiği soru masada duruyor.'),
('question_received','ev_hanimi','Bir soru geldi {ad}''dan, kırma çocuğu.'),
('question_received','ev_hanimi','{ad} seni düşünmüş, soru göndermiş.'),
('question_received','arabeskci','{ad} bir soru yolladı, meydan okuyor sanki.'),
('question_received','arabeskci','Dostun {ad}''dan bir soru… ağır olabilir.'),
('question_received','arabeskci','{ad} attı soruyu, top sende.'),
('question_received','arabeskci','Gel bakalım, {ad} ne yollamış.'),
('question_received','arabeskci','{ad}''dan haber var, sorulu haber.'),
('question_received','sanayi_ustasi','{ad} bir iş yolladı. Bak bakalım.'),
('question_received','sanayi_ustasi','Tezgâha {ad}''dan soru düştü.'),
('question_received','sanayi_ustasi','{ad} meydan okuyor usta.'),
('question_received','sanayi_ustasi','İş geldi: {ad}''dan bir soru.'),
('question_received','sanayi_ustasi','{ad} sınıyor seni. Göster kendini.'),
('question_received','akademisyen','{ad} size bir soru iletti.'),
('question_received','akademisyen','Yeni soru; gönderen: {ad}.'),
('question_received','akademisyen','{ad}''ın paylaştığı soru çözüm bekliyor.'),
('question_received','akademisyen','Gelen kutunuzda {ad}''dan bir soru var.'),
('question_received','akademisyen','{ad} tarafından bir soru gönderildi.'),
('question_received','ceo','{ad}''dan yeni bir görev geldi.'),
('question_received','ceo','Gelen soru: {ad}. Aksiyon bekliyor.'),
('question_received','ceo','{ad} sana bir soru atadı.'),
('question_received','ceo','Kuyruğuna {ad}''dan bir soru eklendi.'),
('question_received','ceo','{ad} meydan okudu. Cevap ver.'),
-- ---------------------------------------------------- arkadaşlık isteği
('friend_request','ev_hanimi','{ad} arkadaş olmak istiyor canım.'),
('friend_request','ev_hanimi','Kapıda {ad} var, arkadaşlık istiyor.'),
('friend_request','ev_hanimi','{ad} seni eklemiş, bir bak istersen.'),
('friend_request','ev_hanimi','Yeni bir arkadaş: {ad}. Sevindim.'),
('friend_request','ev_hanimi','{ad}''dan istek geldi, bekletme.'),
('friend_request','arabeskci','{ad} dost olmak istiyor. Dostluk güzeldir.'),
('friend_request','arabeskci','Bir istek var {ad}''dan, gönül kapısı çalıyor.'),
('friend_request','arabeskci','{ad} elini uzatmış, tut istersen.'),
('friend_request','arabeskci','Yeni bir dost mu geliyor? {ad}.'),
('friend_request','arabeskci','{ad} arkadaşlık istedi, çok düşünme.'),
('friend_request','sanayi_ustasi','{ad} arkadaşlık istiyor. Karar senin.'),
('friend_request','sanayi_ustasi','Yeni çırak mı geliyor? {ad} istek attı.'),
('friend_request','sanayi_ustasi','{ad} ekibe katılmak istiyor.'),
('friend_request','sanayi_ustasi','İstek var: {ad}.'),
('friend_request','sanayi_ustasi','{ad} seni eklemiş usta.'),
('friend_request','akademisyen','{ad} arkadaşlık isteği gönderdi.'),
('friend_request','akademisyen','Yeni bağlantı talebi: {ad}.'),
('friend_request','akademisyen','{ad} sizinle bağlantı kurmak istiyor.'),
('friend_request','akademisyen','Bekleyen arkadaşlık isteğiniz var: {ad}.'),
('friend_request','akademisyen','{ad} tarafından istek iletildi.'),
('friend_request','ceo','{ad} ağına katılmak istiyor.'),
('friend_request','ceo','Yeni bağlantı talebi: {ad}.'),
('friend_request','ceo','{ad} arkadaşlık isteği gönderdi, onay bekliyor.'),
('friend_request','ceo','Çevren büyüyor: {ad}.'),
('friend_request','ceo','{ad}''dan istek. Değerlendir.'),
-- ------------------------------------------------- gönderilen soru çözüldü
('question_solved','ev_hanimi','{ad} gönderdiğin soruyu çözdü, aferin ona.'),
('question_solved','ev_hanimi','Soruna cevap geldi canım, {ad} bakmış.'),
('question_solved','ev_hanimi','{ad} çözmüş bile, hadi bir tane daha yolla.'),
('question_solved','ev_hanimi','Gönderdiğin soru boş kalmadı, {ad} uğraşmış.'),
('question_solved','ev_hanimi','{ad}''dan haber var: soru çözüldü.'),
('question_solved','arabeskci','{ad} çözdü soruyu, helal olsun.'),
('question_solved','arabeskci','Yolladığın soru cevabını buldu: {ad}.'),
('question_solved','arabeskci','{ad} altından kalktı, sen de boş durma.'),
('question_solved','arabeskci','Soru gitti, cevap geldi. {ad}.'),
('question_solved','arabeskci','{ad} meydanı boş bırakmadı.'),
('question_solved','sanayi_ustasi','{ad} işi bitirmiş.'),
('question_solved','sanayi_ustasi','Yolladığın soruyu {ad} halletti.'),
('question_solved','sanayi_ustasi','{ad} tezgâhtan kalkmış, çözmüş.'),
('question_solved','sanayi_ustasi','İş tamam: {ad} çözdü.'),
('question_solved','sanayi_ustasi','{ad} eli yatkınmış, çözdü soruyu.'),
('question_solved','akademisyen','{ad} gönderdiğiniz soruyu çözdü.'),
('question_solved','akademisyen','Sonuç bildirimi: {ad} yanıtladı.'),
('question_solved','akademisyen','{ad} tarafından çözüm tamamlandı.'),
('question_solved','akademisyen','Gönderdiğiniz soru {ad} tarafından cevaplandı.'),
('question_solved','akademisyen','{ad}''ın çözümü kaydedildi.'),
('question_solved','ceo','{ad} gönderdiğin soruyu kapattı.'),
('question_solved','ceo','Görev tamamlandı: {ad}.'),
('question_solved','ceo','{ad} çözdü. Bir tane daha gönder.'),
('question_solved','ceo','Sonuç geldi: {ad} yanıtladı.'),
('question_solved','ceo','{ad} teslim etti.');

-- ------------------------------------------------------------- gönderim
-- Edge Function'ı çağırır. Hata olsa bile asıl işlemi bozmaz.
create or replace function public.send_push(
  p_user  uuid,
  p_kind  text,
  p_actor text
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_url    text;
  v_secret text;
  v_mascot text;
  v_line   text;
  v_title  text;
begin
  select value into v_url    from public.app_config where key = 'push_url';
  select value into v_secret from public.app_config where key = 'push_secret';
  if v_url is null or v_secret is null then
    return;   -- yapılandırılmadıysa sessizce geç
  end if;

  -- Alıcının maskotu; seçmediyse şefkatli varsayılan.
  select coalesce(mascot, 'ev_hanimi') into v_mascot
    from public.profiles where id = p_user;

  select replace(line, '{ad}', coalesce(p_actor, 'Bir arkadaşın'))
    into v_line
    from public.push_lines
   where kind = p_kind and mascot = coalesce(v_mascot, 'ev_hanimi')
   order by random()
   limit 1;

  if v_line is null then
    return;
  end if;

  v_title := case p_kind
               when 'question_received' then 'Sana soru geldi 📨'
               when 'friend_request'    then 'Arkadaşlık isteği 🤝'
               when 'question_solved'   then 'Soru çözüldü ✅'
               else 'AI YKS Coach'
             end;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-push-secret', v_secret
               ),
    body    := jsonb_build_object(
                 'user_id', p_user,
                 'title',   v_title,
                 'body',    v_line,
                 'kind',    p_kind
               )
  );
exception when others then
  return;   -- bildirim hatası asıl işlemi bozmasın
end;
$$;

-- --------------------------------------------------------- tetikleyiciler
-- 1) Arkadaşa soru gönderildi → alıcıya haber
create or replace function public.on_question_sent()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  select nickname into v_name from public.profiles where id = new.sender_id;
  perform public.send_push(new.receiver_id, 'question_received', v_name);
  return new;
end; $$;

drop trigger if exists push_on_question_sent on public.question_sends;
create trigger push_on_question_sent
  after insert on public.question_sends
  for each row execute function public.on_question_sent();

-- 2) Gönderilen soru çözüldü → gönderene haber
create or replace function public.on_question_solved()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if old.solved_at is null and new.solved_at is not null then
    select nickname into v_name from public.profiles where id = new.receiver_id;
    perform public.send_push(new.sender_id, 'question_solved', v_name);
  end if;
  return new;
end; $$;

drop trigger if exists push_on_question_solved on public.question_sends;
create trigger push_on_question_solved
  after update on public.question_sends
  for each row execute function public.on_question_solved();

-- 3) Arkadaşlık isteği → isteği alana haber
create or replace function public.on_friend_request()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if new.status = 'pending' then
    select nickname into v_name from public.profiles where id = new.requester_id;
    perform public.send_push(new.addressee_id, 'friend_request', v_name);
  end if;
  return new;
end; $$;

drop trigger if exists push_on_friend_request on public.friendships;
create trigger push_on_friend_request
  after insert on public.friendships
  for each row execute function public.on_friend_request();
