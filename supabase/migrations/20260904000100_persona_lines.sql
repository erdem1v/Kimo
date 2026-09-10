-- 0055 — Persona (Kimo'nun sesi): metinler tek kaynağa, tabloya kısıt, anti-tekrar
--
-- Task 04. Üç iş birden:
--
--   1) METİN TEK KAYNAĞA. Bildirim cümlelerinin yarısı `lib/data/mascot_lines.dart`
--      içinde GÖMÜLÜYDÜ (yerel hatırlatmalar), yarısı burada (sunucu push'ları) —
--      üstelik üç senaryonun metinleri İKİ YERDE birebir kopyaydı ve başlıklar da
--      Dart `MascotLines.title` ile aşağıdaki `v_title` case'i arasında ikiye
--      bölünmüştü. Birini düzelten diğerini kaçırıyordu. Artık tek yer burası:
--      istemci `notification_lines()` ile okuyup önbelleğe alıyor. Bir metnin
--      tonunu düzeltmek ya da persona eklemek UYGULAMA GÜNCELLEMESİ İSTEMİYOR.
--
--   2) KISIT. `push_lines`'ın birincil anahtarı, yabancı anahtarı ve CHECK'i yoktu
--      (Task 01 raporu, "çözülmedi" md. 4). Yazım hatası olan bir satır sessizce
--      hiç seçilmiyordu: `send_push` boş dönüyor ve bildirim GÖRÜNMEDEN düşüyordu.
--      Artık yanlış `kind`/`mascot` göç zamanında patlar, çalışma zamanında değil.
--
--   3) ANTI-TEKRAR. İki tarafta da hafıza yoktu (`order by random()` ve Dart'ta
--      `Random().nextInt`). Beş varyantta aynı cümlenin arka arkaya gelme olasılığı
--      %20; aynı iki cümleyi üst üste gören kullanıcı bildirimi görmez oluyor, yani
--      persona sisteminin varlık sebebi ortadan kalkıyordu. `push_cursors` son
--      gönderilen satırı tutar, `send_push` onu dışlar.
--
-- AYRICA: akademisyen personası ürün kararıyla kaldırıldı (4 persona kaldı) ve
-- ton kuralına aykırı 58 cümle düzeltildi (suçlama / tehdit / kayıp dili /
-- kıyaslama / performans dili / duygusal yük). Gerekçeli tam liste:
-- docs/task-04-persona-raporu.md.

-- ============================================================ senaryo başlıkları
-- Başlık senaryoya göre sabit, PERSONAYA GÖRE DEĞİŞMEZ: kilit ekranında önce
-- başlık okunuyor ve onun her seferinde aynı olması bildirimi tanıdık kılıyor.
-- Buraya taşınmasının sebebi Dart'taki kopyayı bitirmek.
--
-- İki başlık ton kuralı gereği değişti — ikisi de gövde metinlerinden bağımsız
-- olarak kayıp/tehdit diliydi ve her personada aynı görünüyordu:
--   'Serin tehlikede 🔥' → 'Serini sürdür 🔥'
--   'Ligde son gün ⚔️'   → 'Lig haftası bitiyor 🏆'   (kılıç da yarışma imgesiydi)
create table if not exists public.push_kinds (
  kind  text primary key,
  title text not null
);

alter table public.push_kinds enable row level security;
-- Politika YOK = kimse erişemez (app_config / push_lines kalıbı).
revoke all on public.push_kinds from public, anon, authenticated;

delete from public.push_kinds;
insert into public.push_kinds (kind, title) values
  ('reviews_due','Tekrar zamanı 🔁'),
  ('streak_risk','Serini sürdür 🔥'),
  ('comeback','Seni özledik 👋'),
  ('league_last_day','Lig haftası bitiyor 🏆'),
  ('league_result','Hafta kapandı 🏆'),
  ('question_received','Sana soru geldi 📨'),
  ('friend_request','Arkadaşlık isteği 🤝'),
  ('question_solved','Soru çözüldü ✅'),
  ('friend_league_up','Arkadaşın yükseldi 🏆'),
  ('friend_streak','Arkadaşın seri yapıyor 🔥');

-- =============================================================== metin havuzu
-- `idx` iki işi birden yapıyor: satırı ADRESLENEBİLİR kılıyor (anti-tekrar imleci
-- bir metni değil bir numarayı saklasın diye — metin düzeltilince imleç bozulmaz)
-- ve birincil anahtarı mümkün kılıyor.
--
-- Sıra önemli: önce boşalt, sonra kolonu NOT NULL ekle. Dolu tabloya varsayılansız
-- NOT NULL kolon eklenemezdi; varsayılan verip sonra düşürmek ise 105 satıra
-- anlamsız bir 0 yazardı.
delete from public.push_lines;

drop index if exists public.push_lines_idx;

alter table public.push_lines add column if not exists idx int not null;

alter table public.push_lines
  drop constraint if exists push_lines_pkey;
alter table public.push_lines
  add constraint push_lines_pkey primary key (kind, mascot, idx);

alter table public.push_lines
  drop constraint if exists push_lines_kind_fkey;
alter table public.push_lines
  add constraint push_lines_kind_fkey
  foreign key (kind) references public.push_kinds(kind);

alter table public.push_lines
  drop constraint if exists push_lines_mascot_check;
alter table public.push_lines
  add constraint push_lines_mascot_check
  check (mascot in ('ev_hanimi', 'arabeskci', 'sanayi_ustasi', 'ceo'));

-- Yer tutucular: {n} sayı · {ad} arkadaşın takma adı · {sira} lig sırası ·
-- {lig} lig adı. Bir cümlede {n} ve {lig} BİRLİKTE kullanılamaz: ikisi de
-- send_push'un tek `p_extra` parametresinden besleniyor.
insert into public.push_lines (kind, mascot, idx, line) values
-- ------------------------------------------------------------------ reviews_due
  ('reviews_due','ev_hanimi',0,'Canım, bugün {n} soru bekliyor seni. Hazır olunca başlarız.'),
  ('reviews_due','ev_hanimi',1,'Sofra hazır, {n} tekrar seni bekliyor.'),
  ('reviews_due','ev_hanimi',2,'Yavrum, biraz oturup {n} soru çözsen?'),
  ('reviews_due','ev_hanimi',3,'Hataların seni özledi, {n} tane var.'),
  ('reviews_due','ev_hanimi',4,'Bir çay koy, {n} soruyu birlikte halledelim.'),
  ('reviews_due','arabeskci',0,'{n} soru var dostum, gel şu dertle yüzleşelim.'),
  ('reviews_due','arabeskci',1,'Eski hataların kapıda, {n} tane. Alalım içeri.'),
  ('reviews_due','arabeskci',2,'Bugün {n} soru… ağırdan alalım, olur biter.'),
  ('reviews_due','arabeskci',3,'Gel gel, {n} soru bekliyor. Sen varsan kolay.'),
  ('reviews_due','arabeskci',4,'Dert çok, soru {n}. Başlayalım.'),
  ('reviews_due','sanayi_ustasi',0,'Tezgâhta {n} soru duruyor usta.'),
  ('reviews_due','sanayi_ustasi',1,'{n} parça iş var, halledelim.'),
  ('reviews_due','sanayi_ustasi',2,'Bugünün yükü {n} soru. Kolay gelsin.'),
  ('reviews_due','sanayi_ustasi',3,'Aletleri kap, {n} soru bizi bekliyor.'),
  ('reviews_due','sanayi_ustasi',4,'İş birikmesin: {n} tekrar hazır.'),
  ('reviews_due','ceo',0,'Bugünün kuyruğu: {n} soru.'),
  ('reviews_due','ceo',1,'{n} görev açık. Kapatma zamanı.'),
  ('reviews_due','ceo',2,'Bugünün planında {n} soru var.'),
  ('reviews_due','ceo',3,'{n} tekrar bekliyor. Öncelik sırası hazır.'),
  ('reviews_due','ceo',4,'Biriken iş: {n}. Bugün eritelim.'),
-- ------------------------------------------------------------------ streak_risk
  ('streak_risk','ev_hanimi',0,'Canım, {n} günlük serin duruyor. Tek soru yeter, sürer gider.'),
  ('streak_risk','ev_hanimi',1,'Yavrum, tek soru yeter. {n} günlük emeğin var.'),
  ('streak_risk','ev_hanimi',2,'Akşam oldu. Bir soruyla serini sürdürebilirsin.'),
  ('streak_risk','ev_hanimi',3,'{n} gündür aksatmadın, bugün de aksatma olur mu?'),
  ('streak_risk','ev_hanimi',4,'Bir soru çöz, günü kapatalım.'),
  ('streak_risk','arabeskci',0,'{n} günlük serin bir alev gibi gülüm, bir soruyla parlar.'),
  ('streak_risk','arabeskci',1,'Bu seri ikimizin dostum, bir soru yeter.'),
  ('streak_risk','arabeskci',2,'{n} gün emek verdik, bugün de bir soru koyalım üstüne.'),
  ('streak_risk','arabeskci',3,'Akşamın sonuna bir soru yakışır dostum.'),
  ('streak_risk','arabeskci',4,'Seri sende dostum, bir soruyla sürsün.'),
  ('streak_risk','sanayi_ustasi',0,'Usta, {n} günlük emek duruyor. Geç tezgâha.'),
  ('streak_risk','sanayi_ustasi',1,'Bir soru, bitti gitti.'),
  ('streak_risk','sanayi_ustasi',2,'Serinin ipi elinde. Bir düğüm daha at.'),
  ('streak_risk','sanayi_ustasi',3,'{n} gün çalıştın. Bugün bir soru, devamı gelir.'),
  ('streak_risk','sanayi_ustasi',4,'Vardiya bitmedi. Bir soru kaldı.'),
  ('streak_risk','ceo',0,'{n} günlük seri sürüyor. Bugünün tek maddesi: bir soru.'),
  ('streak_risk','ceo',1,'Bugünün listesi boş. Bir maddeyle kapatalım.'),
  ('streak_risk','ceo',2,'Süreklilik planın sürüyor. Tek soru yeter.'),
  ('streak_risk','ceo',3,'{n} gün üst üste. Bugün de bir soru koyalım.'),
  ('streak_risk','ceo',4,'Gün gece yarısı kapanıyor. Bir soru, seri devam.'),
-- ------------------------------------------------------------------ comeback
  ('comeback','ev_hanimi',0,'Günlerdir yoksun canım, merak ettim.'),
  ('comeback','ev_hanimi',1,'{n} gündür uğramadın, iyi misin?'),
  ('comeback','ev_hanimi',2,'Kapıyı açık bıraktım, istediğin zaman gel.'),
  ('comeback','ev_hanimi',3,'Hataların seni bekliyor, hazır olunca gel.'),
  ('comeback','ev_hanimi',4,'Başlamak için bir soru yeter.'),
  ('comeback','arabeskci',0,'{n} gündür yoksun… buralar sessiz kaldı.'),
  ('comeback','arabeskci',1,'Yolun açık olsun dedim, dönüşünü bekledim.'),
  ('comeback','arabeskci',2,'Dönersen kapı açık, sorular da öyle.'),
  ('comeback','arabeskci',3,'Bir türkü tuttum, sen gelince söyleriz dostum.'),
  ('comeback','arabeskci',4,'Bir soru çöz, eski günlere dönelim.'),
  ('comeback','sanayi_ustasi',0,'{n} gündür tezgâh boş usta.'),
  ('comeback','sanayi_ustasi',1,'İş birikti, gelsen iyi olur.'),
  ('comeback','sanayi_ustasi',2,'Aletler yerinde. Gel şu işi yapalım.'),
  ('comeback','sanayi_ustasi',3,'Uzun mola oldu. Toparlanalım.'),
  ('comeback','sanayi_ustasi',4,'Kapıyı kapatmadım, bekliyorum.'),
  ('comeback','ceo',0,'{n} gündür kayıt yok.'),
  ('comeback','ceo',1,'Plan beklemede. Yeniden başlayalım.'),
  ('comeback','ceo',2,'Biriken iş büyüyor. Kısa bir seans yeter.'),
  ('comeback','ceo',3,'Ara uzadı. Kısa bir başlangıç yeter.'),
  ('comeback','ceo',4,'Bugün on dakika ayır, toparlarız.'),
-- ------------------------------------------------------------------ league_last_day
  ('league_last_day','ev_hanimi',0,'Ligde {sira}. sıradasın canım, son gün. Biraz gayret!'),
  ('league_last_day','ev_hanimi',1,'Yavrum bugün kapanıyor, {sira}. sıradasın. Bir iki soru iyi gider.'),
  ('league_last_day','ev_hanimi',2,'Son akşam. Bir iki soru, sıran yükselsin.'),
  ('league_last_day','ev_hanimi',3,'{lig} haftası bitiyor, biraz çabala.'),
  ('league_last_day','ev_hanimi',4,'Bugün son gün; ne yaparsan kâr.'),
  ('league_last_day','arabeskci',0,'Son gün dostum, {sira}. sıradayız. Kaderi değiştirelim.'),
  ('league_last_day','arabeskci',1,'{lig} haftası kapanıyor, son sözü sen söyle.'),
  ('league_last_day','arabeskci',2,'Bu gece biter her şey. {sira}. sıra kader değil.'),
  ('league_last_day','arabeskci',3,'Az kaldı, bir hamle yeter.'),
  ('league_last_day','arabeskci',4,'Ağlamak yok, çözmek var. Son gün.'),
  ('league_last_day','sanayi_ustasi',0,'Son gün usta, {sira}. sıradasın. Vites büyüt.'),
  ('league_last_day','sanayi_ustasi',1,'Hafta kapanıyor usta, {lig} haftasının son mesaisi.'),
  ('league_last_day','sanayi_ustasi',2,'{sira}. sıradasın. Bugün toparlarız.'),
  ('league_last_day','sanayi_ustasi',3,'Mesai bitiyor. Son bir parça iş var.'),
  ('league_last_day','sanayi_ustasi',4,'Son gün bugün. Elimizden geleni yapalım.'),
  ('league_last_day','ceo',0,'Dönem kapanıyor. Sıra: {sira}.'),
  ('league_last_day','ceo',1,'Son gün. {sira}. sıradayız, yukarısı açık.'),
  ('league_last_day','ceo',2,'{lig} haftası bugün kapanıyor.'),
  ('league_last_day','ceo',3,'Bugün kapanış. Hedef: ilk beş.'),
  ('league_last_day','ceo',4,'Son gün. Sıralama hâlâ değişebilir.'),
-- ------------------------------------------------------------------ league_result
  ('league_result','ev_hanimi',0,'Müjde canım, {lig}''ndesin! Gurur duydum.'),
  ('league_result','ev_hanimi',1,'Yavrum {lig}''nde artık, helal olsun.'),
  ('league_result','ev_hanimi',2,'Bu hafta bitti, {lig}''ndesin. Aferin sana.'),
  ('league_result','ev_hanimi',3,'Emeklerin boşa gitmedi: {lig}.'),
  ('league_result','ev_hanimi',4,'Yeni hafta, yeni grup. {lig}''nde bekliyorum seni.'),
  ('league_result','arabeskci',0,'Yükseldik dostum, {lig}! Bu sevinç bizim.'),
  ('league_result','arabeskci',1,'Kaderimiz döndü, {lig}''ndeyiz.'),
  ('league_result','arabeskci',2,'Hafta bitti, {lig} yazıldı alnımıza.'),
  ('league_result','arabeskci',3,'Düştük ama bittik demek değil. {lig}''nde toparlarız.'),
  ('league_result','arabeskci',4,'Yeni hafta, yeni umut: {lig}.'),
  ('league_result','sanayi_ustasi',0,'Hafta kapandı, {lig}''ndesin. Hayırlı olsun.'),
  ('league_result','sanayi_ustasi',1,'Terfi var usta: {lig}.'),
  ('league_result','sanayi_ustasi',2,'Bu hafta iş iyi gitti: {lig}.'),
  ('league_result','sanayi_ustasi',3,'Düşmüşüz. Toparlanır, {lig}''nde çalışırız.'),
  ('league_result','sanayi_ustasi',4,'Yeni hafta başladı, tezgâh yeni: {lig}.'),
  ('league_result','ceo',0,'Dönem kapandı: {lig}. Tebrikler.'),
  ('league_result','ceo',1,'Terfi onaylandı — {lig}.'),
  ('league_result','ceo',2,'Yeni dönem, yeni lig: {lig}.'),
  ('league_result','ceo',3,'Sonuç: {lig}. Planı güncelleyelim.'),
  ('league_result','ceo',4,'Hafta kapanışı: {lig}.'),
-- ------------------------------------------------------------------ question_received
  ('question_received','ev_hanimi',0,'{ad} sana bir soru yolladı canım, bak bakalım.'),
  ('question_received','ev_hanimi',1,'Arkadaşından soru geldi; {ad} çözebilecek misin diye merak ediyor.'),
  ('question_received','ev_hanimi',2,'{ad}''ın gönderdiği soru masada duruyor.'),
  ('question_received','ev_hanimi',3,'Bir soru geldi {ad}''dan, vaktin olunca bak.'),
  ('question_received','ev_hanimi',4,'{ad} seni düşünmüş, soru göndermiş.'),
  ('question_received','arabeskci',0,'{ad} bir soru yolladı, meydan okuyor sanki.'),
  ('question_received','arabeskci',1,'Dostun {ad}''dan bir soru… ağır olabilir.'),
  ('question_received','arabeskci',2,'{ad} attı soruyu, top sende.'),
  ('question_received','arabeskci',3,'Gel bakalım, {ad} ne yollamış.'),
  ('question_received','arabeskci',4,'{ad}''dan haber var, sorulu haber.'),
  ('question_received','sanayi_ustasi',0,'{ad} bir iş yolladı. Bak bakalım.'),
  ('question_received','sanayi_ustasi',1,'Tezgâha {ad}''dan soru düştü.'),
  ('question_received','sanayi_ustasi',2,'{ad} meydan okuyor usta.'),
  ('question_received','sanayi_ustasi',3,'İş geldi: {ad}''dan bir soru.'),
  ('question_received','sanayi_ustasi',4,'{ad} sınıyor seni. Göster kendini.'),
  ('question_received','ceo',0,'{ad}''dan yeni bir görev geldi.'),
  ('question_received','ceo',1,'Gelen soru: {ad}. Sıraya aldım.'),
  ('question_received','ceo',2,'{ad} sana bir soru atadı.'),
  ('question_received','ceo',3,'Kuyruğuna {ad}''dan bir soru eklendi.'),
  ('question_received','ceo',4,'{ad} meydan okudu. Cevap ver.'),
-- ------------------------------------------------------------------ friend_request
  ('friend_request','ev_hanimi',0,'{ad} arkadaş olmak istiyor canım.'),
  ('friend_request','ev_hanimi',1,'Kapıda {ad} var, arkadaşlık istiyor.'),
  ('friend_request','ev_hanimi',2,'{ad} seni eklemiş, bir bak istersen.'),
  ('friend_request','ev_hanimi',3,'Yeni bir arkadaş: {ad}. Sevindim.'),
  ('friend_request','ev_hanimi',4,'{ad}''dan istek geldi, bekletme.'),
  ('friend_request','arabeskci',0,'{ad} dost olmak istiyor. Dostluk güzeldir.'),
  ('friend_request','arabeskci',1,'Bir istek var {ad}''dan, gönül kapısı çalıyor.'),
  ('friend_request','arabeskci',2,'{ad} elini uzatmış, tut istersen.'),
  ('friend_request','arabeskci',3,'Yeni bir dost mu geliyor? {ad}.'),
  ('friend_request','arabeskci',4,'{ad} arkadaşlık istedi, çok düşünme.'),
  ('friend_request','sanayi_ustasi',0,'{ad} arkadaşlık istiyor. Karar senin.'),
  ('friend_request','sanayi_ustasi',1,'Yeni çırak mı geliyor? {ad} istek attı.'),
  ('friend_request','sanayi_ustasi',2,'{ad} ekibe katılmak istiyor.'),
  ('friend_request','sanayi_ustasi',3,'İstek var: {ad}.'),
  ('friend_request','sanayi_ustasi',4,'{ad} seni eklemiş usta.'),
  ('friend_request','ceo',0,'{ad} ağına katılmak istiyor.'),
  ('friend_request','ceo',1,'Yeni bağlantı talebi: {ad}.'),
  ('friend_request','ceo',2,'{ad} arkadaşlık isteği gönderdi, onay bekliyor.'),
  ('friend_request','ceo',3,'Çevren büyüyor: {ad}.'),
  ('friend_request','ceo',4,'{ad}''dan istek. Değerlendir.'),
-- ------------------------------------------------------------------ question_solved
  ('question_solved','ev_hanimi',0,'{ad} gönderdiğin soruyu çözdü, aferin ona.'),
  ('question_solved','ev_hanimi',1,'Soruna cevap geldi canım, {ad} bakmış.'),
  ('question_solved','ev_hanimi',2,'{ad} çözmüş bile, hadi bir tane daha yolla.'),
  ('question_solved','ev_hanimi',3,'Gönderdiğin soru boş kalmadı, {ad} uğraşmış.'),
  ('question_solved','ev_hanimi',4,'{ad}''dan haber var: soru çözüldü.'),
  ('question_solved','arabeskci',0,'{ad} çözdü soruyu, helal olsun.'),
  ('question_solved','arabeskci',1,'Yolladığın soru cevabını buldu: {ad}.'),
  ('question_solved','arabeskci',2,'{ad} altından kalktı, sen de boş durma.'),
  ('question_solved','arabeskci',3,'Soru gitti, cevap geldi. {ad}.'),
  ('question_solved','arabeskci',4,'{ad} meydanı boş bırakmadı.'),
  ('question_solved','sanayi_ustasi',0,'{ad} işi bitirmiş.'),
  ('question_solved','sanayi_ustasi',1,'Yolladığın soruyu {ad} halletti.'),
  ('question_solved','sanayi_ustasi',2,'{ad} tezgâhtan kalkmış, çözmüş.'),
  ('question_solved','sanayi_ustasi',3,'İş tamam: {ad} çözdü.'),
  ('question_solved','sanayi_ustasi',4,'{ad} eli yatkınmış, çözdü soruyu.'),
  ('question_solved','ceo',0,'{ad} gönderdiğin soruyu kapattı.'),
  ('question_solved','ceo',1,'Görev tamamlandı: {ad}.'),
  ('question_solved','ceo',2,'{ad} çözdü. Bir tane daha gönder.'),
  ('question_solved','ceo',3,'Sonuç geldi: {ad} yanıtladı.'),
  ('question_solved','ceo',4,'{ad} teslim etti.'),
-- ------------------------------------------------------------------ friend_league_up
  ('friend_league_up','ev_hanimi',0,'{ad} çok çalışmış, {lig} ligine çıkmış. Ne güzel haber.'),
  ('friend_league_up','ev_hanimi',1,'Arkadaşın {ad} bu hafta ligi atladı, {lig}''e geçti. Maşallah.'),
  ('friend_league_up','ev_hanimi',2,'{ad} yükselmiş {lig} ligine. Onu görünce içim açıldı.'),
  ('friend_league_up','ev_hanimi',3,'{ad} için sevindim canım, artık {lig} liginde.'),
  ('friend_league_up','ev_hanimi',4,'Arkadaşın {ad} {lig} ligine çıkmış. Tebrik etsen sevinir.'),
  ('friend_league_up','arabeskci',0,'{ad} çıktı {lig} ligine, yolu açık olsun dostum.'),
  ('friend_league_up','arabeskci',1,'Duydun mu, {ad} bir üst lige uçtu. {lig} artık onun.'),
  ('friend_league_up','arabeskci',2,'{ad} yükseldi {lig}''e… Bu sevinç dostun sevinci.'),
  ('friend_league_up','arabeskci',3,'{ad} {lig} ligine geçti dostum, güzel haber böyle olur.'),
  ('friend_league_up','arabeskci',4,'Bir dost yükseldi: {ad}, artık {lig} liginde.'),
  ('friend_league_up','sanayi_ustasi',0,'{ad} tezgâhı sıkı çalıştırmış, {lig} ligine geçti.'),
  ('friend_league_up','sanayi_ustasi',1,'Usta, {ad} bir üst lige çıktı. {lig}''de şimdi.'),
  ('friend_league_up','sanayi_ustasi',2,'{ad} terfi etti: {lig}. Helal olsun.'),
  ('friend_league_up','sanayi_ustasi',3,'{ad} {lig} ligine geçmiş. İyi iş.'),
  ('friend_league_up','sanayi_ustasi',4,'Haber var usta: {ad} artık {lig} liginde.'),
  ('friend_league_up','ceo',0,'{ad} bu hafta {lig} ligine terfi etti.'),
  ('friend_league_up','ceo',1,'{ad} bir üst lige geçti: {lig}. Tebrikler ona.'),
  ('friend_league_up','ceo',2,'{ad} istikrarlı çalıştı ve {lig} ligine çıktı.'),
  ('friend_league_up','ceo',3,'Terfi haberi: {ad} artık {lig} liginde.'),
  ('friend_league_up','ceo',4,'{ad}''ın haftası iyi geçti — {lig}.'),
-- ------------------------------------------------------------------ friend_streak
  ('friend_streak','ev_hanimi',0,'{ad} tam {n} gündür aksatmıyor. Ne çalışkan çocuk.'),
  ('friend_streak','ev_hanimi',1,'Arkadaşın {ad} {n} günlük seriye ulaştı canım.'),
  ('friend_streak','ev_hanimi',2,'{ad} {n} gündür her gün soru çözüyor. Helal olsun ona.'),
  ('friend_streak','ev_hanimi',3,'{ad} için sevindim: {n} gündür hiç aksatmamış.'),
  ('friend_streak','ev_hanimi',4,'Arkadaşın {ad} {n} günlük seride. Ne güzel.'),
  ('friend_streak','arabeskci',0,'{ad} {n} gündür hiç bırakmadı. Helal olsun dostuma.'),
  ('friend_streak','arabeskci',1,'Dostun {ad} {n} günlük seri yaptı, yürek ister bu.'),
  ('friend_streak','arabeskci',2,'{ad}''ın serisi {n} güne dayandı. Dostun yolunda dostum.'),
  ('friend_streak','arabeskci',3,'{n} gün aralıksız… {ad} sağlam duruyor.'),
  ('friend_streak','arabeskci',4,'Dostun {ad} {n} gündür sözünde. Böylesi az bulunur.'),
  ('friend_streak','sanayi_ustasi',0,'{ad} {n} gündür tezgâhın başında. Adam gibi iş.'),
  ('friend_streak','sanayi_ustasi',1,'Arkadaşın {ad} {n} gün aksatmadı. Sağlam usta.'),
  ('friend_streak','sanayi_ustasi',2,'{ad} {n} günlük seriyi devirdi. Helal.'),
  ('friend_streak','sanayi_ustasi',3,'{ad} {n} gündür vardiyayı kaçırmamış.'),
  ('friend_streak','sanayi_ustasi',4,'Usta işi: {ad}''ın serisi {n} günde.'),
  ('friend_streak','ceo',0,'{ad} {n} gün üst üste hedefini tutturdu.'),
  ('friend_streak','ceo',1,'Arkadaşın {ad} {n} günlük seride. Tebrikler ona.'),
  ('friend_streak','ceo',2,'{ad} {n} gündür istikrarlı. Güzel iş.'),
  ('friend_streak','ceo',3,'{ad}''ın serisi {n} güne ulaştı.'),
  ('friend_streak','ceo',4,'Not: {ad} {n} gündür aralıksız çalışıyor.');

-- =========================================================== anti-tekrar imleci
-- Kullanıcı × senaryo başına EN SON gönderilen satırın numarası. Yalnızca
-- send_push (definer, sahibi postgres) yazar; uygulamaya hiç açılmaz.
create table if not exists public.push_cursors (
  user_id uuid not null references auth.users(id) on delete cascade,
  kind    text not null references public.push_kinds(kind),
  idx     int  not null,
  primary key (user_id, kind)
);

alter table public.push_cursors enable row level security;
-- Politika YOK = kimse erişemez. Değişmez 6 (RLS'siz public tablo kalmaz) sağlanır.
revoke all on public.push_cursors from public, anon, authenticated;

-- ================================================================== gönderim
-- 0028'in sürümüyle aynı sözleşme; üç fark: başlık tablodan geliyor, satır
-- seçimi son gönderileni dışlıyor, varsayılan başlık artık eski ürün adı
-- ('AI YKS Coach') değil 'Kimo'.
create or replace function public.send_push(
  p_user  uuid,
  p_kind  text,
  p_actor text,
  p_extra text default null
)
returns void
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_url    text;
  v_key    text;
  v_mascot text;
  v_line   text;
  v_idx    int;
  v_title  text;
begin
  select value into v_url from public.app_config where key = 'push_url';
  select value into v_key from public.app_config where key = 'push_service_key';
  if v_url is null or v_key is null then
    raise warning 'send_push: app_config eksik (push_url ve/veya push_service_key)';
    return;
  end if;

  -- Alıcının personası; profil satırı yoksa ya da boşsa şefkatli varsayılan.
  select coalesce(mascot, 'ev_hanimi') into v_mascot
    from public.profiles where id = p_user;
  v_mascot := coalesce(v_mascot, 'ev_hanimi');

  -- SON GÖNDERİLENİ DIŞLA. Aynı cümleyi üst üste gören kullanıcı bildirimi
  -- görmez oluyor; beş varyantta bunun olasılığı %20'ydi.
  select l.idx, l.line into v_idx, v_line
    from public.push_lines l
    left join public.push_cursors c
      on c.user_id = p_user and c.kind = p_kind
   where l.kind = p_kind
     and l.mascot = v_mascot
     and (c.idx is null or l.idx <> c.idx)
   order by random()
   limit 1;

  -- Tek varyant kalmışsa dışlama havuzu boşaltır. Bildirimi DÜŞÜRMEK yerine
  -- tekrara izin veriyoruz: tekrar etmiş bir hatırlatma, hiç gelmeyenden iyi.
  if v_line is null then
    select l.idx, l.line into v_idx, v_line
      from public.push_lines l
     where l.kind = p_kind and l.mascot = v_mascot
     order by random()
     limit 1;
  end if;

  -- Buraya düşmek artık yalnızca senaryonun hiç metni yoksa mümkün; pgTAP 240
  -- her (kind, mascot) hücresinde en az beş satır olduğunu iddia ediyor.
  if v_line is null then
    raise warning 'send_push: metin yok (kind=%, mascot=%)', p_kind, v_mascot;
    return;
  end if;

  v_line := replace(v_line, '{ad}',  coalesce(p_actor, 'Bir arkadaşın'));
  v_line := replace(v_line, '{lig}', coalesce(p_extra, ''));
  v_line := replace(v_line, '{n}',   coalesce(p_extra, ''));

  select title into v_title from public.push_kinds where kind = p_kind;
  v_title := coalesce(v_title, 'Kimo');

  insert into public.push_cursors (user_id, kind, idx)
  values (p_user, p_kind, v_idx)
  on conflict (user_id, kind) do update set idx = excluded.idx;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || v_key
               ),
    body    := jsonb_build_object(
                 'user_id', p_user,
                 'title',   v_title,
                 'body',    v_line,
                 'kind',    p_kind
               )
  );
exception when others then
  raise warning 'send_push başarısız: %', sqlerrm;
  return;
end
$fn$;

-- send_push ÇAĞRILABİLİR OLMAYACAK (0029'un en ciddi bulgusu: açıkken oturum
-- açmış herkes istediği kullanıcıya sahte bildirim gönderebiliyordu).
revoke execute on function public.send_push(uuid, text, text, text)
  from public, anon, authenticated;

-- ====================================================== istemcinin metin okuması
-- Yerel hatırlatmalar (tekrar, seri, geri dönüş, lig son gün) CİHAZDA planlanıyor
-- ve metni cihazda gerekiyor. `push_lines` kullanıcıya açılmıyor — açılsaydı
-- bildirim metni enjeksiyonu yüzeyi doğardı — o yüzden okuma bu definer
-- fonksiyondan geçiyor.
--
-- Sınıflandırma bilinçli: SALT OKUMA, yazma yok, kişisel veri yok. Dönen içerik
-- uygulamanın kendi kopyası; kullanıcı zaten bildirimlerde görüyor.
create or replace function public.notification_lines()
returns table (kind text, mascot text, idx int, line text, title text)
language sql
security definer
set search_path = public
stable
as $fn$
  select l.kind, l.mascot, l.idx, l.line, k.title
    from public.push_lines l
    join public.push_kinds k on k.kind = l.kind
   where auth.uid() is not null
   order by l.kind, l.mascot, l.idx;
$fn$;

revoke execute on function public.notification_lines() from public, anon;
grant  execute on function public.notification_lines() to authenticated;

-- ======================================================== akademisyen kaldırıldı
-- Ürün kararı: dört persona kaldı. Eşleme YAPILMAZSA `Mascot.fromDb` null döner,
-- `onboardingComplete` false olur ve mevcut kullanıcı karşılama akışına geri
-- düşer. İki yer birden güncelleniyor: istemcinin okuduğu auth metadata'sı ve
-- send_push'un okuduğu profiles sütunu.
update public.profiles
   set mascot = 'ev_hanimi'
 where mascot is distinct from null
   and mascot not in ('ev_hanimi', 'arabeskci', 'sanayi_ustasi', 'ceo');

-- `auth` şemasına yazmak göçün olağan yetkisi DEĞİL: barındırılan projede
-- tabloların sahibi `supabase_admin`. Yetki yoksa göçün tamamını düşürmek
-- yanlış olurdu — `profiles.mascot` (send_push'un okuduğu yer) zaten
-- düzeltildi. Eşleme yapılamazsa kullanıcı yalnızca karşılama akışında sesini
-- yeniden seçer; adım ön seçili geldiği için tek dokunuş.
do $mig$
begin
  update auth.users
     set raw_user_meta_data =
           jsonb_set(raw_user_meta_data, '{mascot}', '"ev_hanimi"')
   where raw_user_meta_data ? 'mascot'
     and raw_user_meta_data ->> 'mascot'
         not in ('ev_hanimi', 'arabeskci', 'sanayi_ustasi', 'ceo');
exception when insufficient_privilege then
  raise warning
    'auth.users metadata eşlemesi atlandı (yetki yok); etkilenen kullanıcı '
    'sesini karşılama akışında yeniden seçer';
end
$mig$;

-- ============================================================ persona doğrulama
-- 0041'in sürümüyle aynı; tek fark p_mascot artık doğrulanıyor. Doğrulanmadığı
-- sürece istemci `profiles.mascot`'a istediği metni yazabiliyordu ve eşleşmeyen
-- persona bildirimi sessizce düşürüyordu (Task 01 raporu md. 4'ün diğer yarısı).
create or replace function public.upsert_my_profile(
  p_nickname text,
  p_mascot   text default null
)
returns void
language plpgsql security definer set search_path = public
as $fn$
declare
  v_uid  uuid := auth.uid();
  v_nick text := nullif(btrim(regexp_replace(coalesce(p_nickname, ''), '\s+', ' ', 'g')), '');
begin
  if v_uid is null then
    raise exception 'oturum yok' using errcode = '28000';
  end if;
  if v_nick is null or char_length(v_nick) < 2 or char_length(v_nick) > 24 then
    raise exception 'Takma ad 2-24 karakter olmalı' using errcode = '22023';
  end if;
  if v_nick ~ '[[:cntrl:]]' then
    raise exception 'Takma adda geçersiz karakter var' using errcode = '22023';
  end if;
  if p_mascot is not null
     and p_mascot not in ('ev_hanimi', 'arabeskci', 'sanayi_ustasi', 'ceo') then
    raise exception 'Geçersiz persona' using errcode = '22023';
  end if;
  -- Sistem hesabı kimliğinin taklidi (ör. 'ÖSYM Çıkmış Sorular') engellenir:
  -- o ad havuz künyesinde ve aramada resmî hesap gibi görünürdü.
  if exists (
    select 1 from public.profiles s
     where s.is_system and lower(s.nickname) = lower(v_nick)
  ) then
    raise exception 'Bu takma ad kullanılamaz' using errcode = '22023';
  end if;

  insert into public.profiles (id, nickname, mascot)
  values (v_uid, v_nick, p_mascot)
  on conflict (id) do update
     set nickname = excluded.nickname,
         mascot   = coalesce(excluded.mascot, public.profiles.mascot);
end
$fn$;

revoke execute on function public.upsert_my_profile(text, text) from public, anon;
grant  execute on function public.upsert_my_profile(text, text) to authenticated;

-- =================================================================== güvence
-- Boşluk garantisi göç zamanında da doğrulanıyor: bir senaryo × persona hücresi
-- boş kalırsa bildirim sessizce hiç gitmez, ve bunu ancak kullanıcı fark eder.
do $mig$
declare v_bad text[];
begin
  select array_agg(k.kind || '/' || m.mascot order by k.kind, m.mascot)
    into v_bad
    from public.push_kinds k
   cross join (values ('ev_hanimi'), ('arabeskci'), ('sanayi_ustasi'), ('ceo'))
              as m(mascot)
   where (select count(*) from public.push_lines l
           where l.kind = k.kind and l.mascot = m.mascot) < 5;

  if v_bad is not null then
    raise exception 'Metni eksik senaryo/persona hücresi: %', v_bad;
  end if;
end
$mig$;
