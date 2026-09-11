# Kimo — Hukuki metinler ve mağaza uyum paketi

**Durum: hukukçu incelemesine hazır taslak.** Bu belge kod tabanının okunmasıyla
üretildi; içindeki her veri/aktarım ifadesinin arkasında bir dosya:satır dayanağı
var. Köşeli parantezli alanlar (`[şirket unvanı]` gibi) siz doldurana kadar boş.

**Sürüm:** 1.3 · **Hazırlanma tarihi:** [tarih] · **Dayanak commit:** `b28f34b`+Task 10

> **1.3'te ne değişti (Task 10).** Uygulamaya **ödüllü reklam** eklendi ve bu
> ÜÇ TARAFI birden değiştirdi:
>
> **(a) Yeni bir veri alıcısı var: Google (AdMob).** §1.10'daki aktarım
> tablosuna altıncı satır olarak girdi, KVKK §6 ve Gizlilik Politikası §6'daki
> sağlayıcı listelerine eklendi. KVKK §6'da duran *"reklam amacıyla kimseyle
> paylaşmıyoruz"* cümlesi artık olduğu gibi doğru değil ve yeniden yazıldı.
>
> **(b) §1.11'in bir kısmı geçersizleşti.** O bölüm "reklam SDK'sı yok
> (`google_mobile_ads` — 0 sonuç)" diyordu; artık var. Hangi iddiaların
> KORUNDUĞU ayrıca önemli: reklam kimliği (IDFA/AAID) **hâlâ toplanmıyor** —
> Android'de `AD_ID` izni manifest'ten `tools:node="remove"` ile düşürüldü,
> iOS'ta ATT hiç çağrılmıyor ve yalnızca **kişiselleştirilmemiş** reklam
> gösteriliyor (`ageRestrictedTreatment: teen`). Bu yüzden mağaza
> formlarındaki "Tracking: HAYIR" ve "Reklam kimliği: Hayır" cevapları AYNEN
> kalıyor.
>
> **(c) Uygulama artık ücretsiz+reklamlı.** Koşullar §13 buna göre yeniden
> yazıldı. Uygulama içi SATIN ALMA hâlâ YOK (abonelik ayrı bir iş) ama
> uygulamada bir tanıtım ekranı var ve §13 bunu da söylüyor.
>
> Ayrıca **iki bayat iddia düzeltildi** (Task 08'de kapanmış ama belgeye
> işlenmemişti): tek soru silme artık uygulama içinde MEVCUT (A-9) ve engel
> kaldırma arayüzü VAR (A-8). Yayına hazır Gizlilik §8 ile KVKK §11 bunun
> tersini yazıyordu.
>
> `app_config.legal_version` **1.3** yapılmalı: onay kayıtları o değeri
> damgalıyor.

> **1.2'de ne değişti (Task 09).** Uygulama adı kesinleşti ve metinlere
> işlendi: mağaza listelemesi **"Kimo: AI YKS"**, uygulamanın adı **"Kimo"**.
> Metinlerdeki yedi `[uygulama adı]` yer tutucusu dolduruldu ve **B-12 bayrağı
> kapandı** — depo, bildirim başlığı ve belgeler artık tek isimde. Metin
> HÜKÜMLERİNDE değişiklik yok; bu sürüm bir *tamamlama*, taraf
> yükümlülüklerinde bir değişiklik değil. Yine de `app_config.legal_version`
> **1.2** yapılmalı: onay kayıtları o değeri damgalıyor.

> **1.1'de ne değişti (Task 07).** Üç ürün kararı metinlere işlendi:
> **(a) veli onayı rejimi tümüyle kaldırıldı** — mekanizma zaten hiç
> çalışmıyordu (A-1) ve 13-17 yaş için hukuken zorunlu değil;
> **(b) uygulama 13+ olarak konumlandı** ve bu sınır artık KODDA zorlanıyor;
> **(c) yaptırım altyapısı gerçekten yazıldı** — askıya alma, kalıcı yasak ve
> uygunsuz içerikte kademeli yaptırım. Ayrıca koşul onayı alınmaya başlandı ve
> onay kaydına metin sürümü eklendi. A-1, A-3, A-4, A-5, A-6 ve A-7 kapandı.
> **Sürümlendirme uyarısı:** aşağıdaki 4, 5 ve 6. bölümlerin metin sürümü
> `app_config.legal_version` ile birlikte güncellenmelidir; onay kayıtları o
> değeri damgalıyor.

## İçindekiler

1. [Veri envanteri](#1-veri-envanteri)
2. [Mağaza uyum bayrakları](#2-mağaza-uyum-bayrakları)
3. [Mağaza formu cevapları](#3-mağaza-formu-cevapları)
4. [KVKK Aydınlatma Metni](#4-kvkk-aydınlatma-metni)
5. [Gizlilik Politikası](#5-gizlilik-politikası)
6. [Kullanım Koşulları](#6-kullanım-koşulları)
7. [Hukukçuya sorulacaklar](#7-hukukçuya-sorulacaklar)

> **Bu belgeyi nasıl kullanın:** 4, 5 ve 6. bölümler yayına hazır metinlerdir —
> köşeli parantezleri doldurup olduğu gibi kullanabilirsiniz. 1, 2, 3 ve 7.
> bölümler iç kullanım içindir; yayınlanmaz.

---

# 1. Veri envanteri

Bu envanter, 63 göç dosyası, 6 edge fonksiyonu ve Flutter istemcisinin
okunmasıyla çıkarıldı. **Emin olunamayan yerler açıkça işaretlendi.**

## 1.1 Hesap ve profil verisi

| Veri | Nerede saklanıyor | Neden toplanıyor | Kim erişebiliyor | Süre | Üçüncü taraf | Dayanak |
|---|---|---|---|---|---|---|
| E-posta adresi | `auth.users` (Supabase Auth) | Hesabın kalıcılaştırılması, giriş, şifre sıfırlama | Kullanıcının kendisi; sunucu tarafı yönetim anahtarı | Hesap silinene kadar | Supabase (barındırma). Şifre sıfırlama postası Supabase SMTP'si üzerinden | `lib/data/auth_repository.dart:40-47` |

> **E-posta doğrulaması KALDIRILDI (Task 06).** `enable_confirmations = false`;
> adres kayıt anında doğrulanmıyor. Sahte kayıt maliyetini artıran mekanizma
> artık IP başına hız sınırı (`hook_before_user_created`, §1.5). Bunun
> envantere yansıması: e-posta adresinin **doğrulanmış olduğu iddia
> edilmiyor** — kullanıcı beyanı olarak duruyor.
| Parola | `auth.users` (Supabase Auth, hash'li) | Kimlik doğrulama | Hiç kimse (hash) | Hesap silinene kadar | Supabase | `auth_repository.dart:15-17` |
| Takma ad (`nickname`, `display_name`) | `public.profiles` | Arkadaş listesinde ve lig tablosunda görünmek | **Tüm oturum açmış kullanıcılar** (`profiles_public` görünümü) | Hesap silinene kadar | Bildirim metninde Google/FCM'e gidiyor (§1.5) | `20240101000500_social.sql:11` |
| Maskot seçimi (`mascot`) | `public.profiles` | Uygulama içi karakter/ses seçimi | Tüm oturum açmış kullanıcılar | Hesap silinene kadar | Yok | `social.sql:12` |
| Avatar görseli | `avatars` bucket (private) + `profiles.avatar_path` | Profil fotoğrafı | Kullanıcı, **arkadaşları** ve **o haftaki lig kohortu** | Hesap silinene kadar | Supabase Storage | `20260901000700_avatar_access.sql:35-69` |
| **Doğum yılı** (`birth_year`) | `public.profiles` | **13 yaş alt sınırının uygulanması** ve yaş derecelendirmesi. Başka hiçbir özelliği etkilemiyor | Yalnızca sunucu fonksiyonları; **kullanıcıya bile yaş döndürülmüyor** | Hesap silinene kadar | Yok | `20260905000200_guardian_removal.sql` (`set_birth_year`) |
| Sınav yılı ve müfredat (`exam_year`, `curriculum`) | Supabase Auth kullanıcı metadata'sı | Konuların doğru müfredata eşlenmesi, tekrar takviminin sınav tarihine göre kesilmesi | Kullanıcı | Hesap silinene kadar | `curriculum` sabiti (`eski`/`maarif`) OpenAI istem metnine giriyor | `lib/state/user_profile.dart:152-160` |
| Arkadaş kodu (`friend_code`) | `public.profiles` | Arkadaş eklemenin tek yolu | Kullanıcı; kodu bilen herkes | Hesap silinene kadar; kullanıcı günde 1 kez yenileyebilir | Yok | `20260902000700_friend_code.sql:27-31` |
| Anonim hesap işareti (`is_anonymous`) | `public.profiles` | Kayıt olmadan denemeye izin vermek | Sunucu | 7 gün (bkz. §1.9) | Yok | `20260902000800_anonymous.sql:31` |

**Toplanmayan kimlik verileri (doğrulandı):** ad-soyad, telefon numarası, T.C.
kimlik numarası, okul adı, sınıf, adres, konum, kişi listesi. Doğum **tarihi**
de toplanmıyor — yalnızca yıl (`age_and_guardian.sql:14-15`).

> **Task 07 — veli e-posta adresi ARTIK TOPLANMIYOR.** `profiles.guardian_email`
> sütunu ve `guardian_requests` tablosu düşürüldü, e-posta sağlayıcısının
> `app_config` anahtarları silindi. Üçüncü bir kişinin (velinin) adresini ölü
> bir akış için saklamanın savunulabilir bir gerekçesi kalmamıştı (KVKK
> Md. 4/2-ç, veri minimizasyonu). Aktarım listesinden de düştü (§1.10).

> ⚠️ `profiles` tablosunda `exam_track` ve `grade` kolonları duruyor ama hiçbir
> kod bunları yazmıyor veya okumuyor. **Ölü kolon oldukları kuvvetle muhtemel;
> yayından önce doğrulanıp düşürülmeleri gerekir** — aksi hâlde envanterde
> "toplanmıyor" dediğimiz bir alan şemada durmaya devam eder.

## 1.2 Kullanıcı içeriği — soru fotoğrafları

Bu, uygulamadaki **en hassas veri kategorisi**. Fotoğraf bir sınav sorusunun
karesi; içinde öğrencinin el yazısı, defteri, masası ve **kadraja giren her şey**
bulunabilir.

| Veri | Nerede saklanıyor | Neden toplanıyor | Kim erişebiliyor | Süre | Üçüncü taraf | Dayanak |
|---|---|---|---|---|---|---|
| Soru fotoğrafı (dosya) | `mistake-photos` bucket — **private**, yol `<kullanıcı_kimliği>/<zaman_damgası>.jpg` | Sorunun okunması, sınıflandırılması ve hata arşivinde saklanması | Kullanıcı; kendisine soru gönderilen arkadaş; **yöneticiler (§1.8)** | Kullanıcı hesabını silene kadar | **Evet** — OpenAI (iki ayrı akış, aşağıda) | `lib/data/mistake_repository.dart:21, 192-201`; `20240101000000_init.sql:103-105` |
| Fotoğraf kaydı ve çıkarılan veri (`mistakes`: `subject`, `concept`, `exam`, `options`, `correct_index`, `note`) | `public.mistakes` | Hata bankası ve aralıklı tekrar motoru | Kullanıcı; gönderilen arkadaş; yöneticiler | Hesap silinene kadar | Yok (çıkarım OpenAI'dan geliyor ama sonuç Supabase'de kalıyor) | `init.sql:69-81` |
| Fotoğraf moderasyon durumu (`photo_scan`) | `public.mistakes` | Uygunsuz içeriğin paylaşıma çıkmasını engellemek | Kullanıcı (kendi satırı), yöneticiler | Hesap silinene kadar | Sonuç OpenAI'dan geliyor; **kategori skorları saklanmıyor**, yalnızca `pending`/`clear`/`flagged` | `20260903000400_photo_scan.sql:29-39`; `supabase/functions/scan-photos/index.ts:104` |
| Serbest not (`note`) — soru gönderirken yazılan mesaj | `public.question_sends` | Arkadaşa gönderilen sorunun yanına not düşmek | Gönderen, alıcı, yöneticiler | Hesap silinene kadar | **Yok** — moderasyon taraması yalnızca fotoğrafa uygulanıyor, metne uygulanmıyor | `20240101000800_question_sends.sql:25-36` |

**Fotoğrafın işlenmesi:** çekilen görsel 1600 piksel genişliğe küçültülüyor ve
%85 kalitede JPEG'e yeniden kodlanıyor (`lib/features/capture/capture_screen.dart:80-89`).

> ⚠️ **EXIF/konum verisi temizleme kodu YOK.** Yeniden kodlama pratikte EXIF'i
> düşürüyor olabilir, ama bu `image_picker` eklentisinin yan etkisi — kodda
> garanti edilen bir davranış değil. **Bu yüzden hiçbir belgede "fotoğraflardan
> konum bilgisi temizlenir" yazmıyoruz.** Garanti isteniyorsa açık bir EXIF
> temizleme adımı eklenmeli (bkz. §2, bayrak B-10).

**Kırpma/maskeleme arayüzü yok:** kullanıcı fotoğrafın bir bölümünü gizleyemiyor;
kadraja giren her şey yükleniyor.

## 1.3 Fotoğrafların OpenAI'a aktarılması — iki ayrı akış

Bu, belgedeki en kritik yurt dışı aktarımı. **İki farklı akış var ve ikisinin
onay durumu farklı.**

### Akış 1 — Soru analizi (`analyze-question`)

| Soru | Cevap | Dayanak |
|---|---|---|
| Nereden çağrılıyor | İstemciden **doğrudan değil**; Supabase Edge Function üzerinden | `mistake_repository.dart:296-304` |
| Hedef adres | `https://api.openai.com/v1/chat/completions` | `supabase/functions/analyze-question/index.ts:243` |
| Model | **`gpt-4o-mini`** | `analyze-question/index.ts:154` |
| Ne gönderiliyor | (a) Fotoğrafın **ham byte'ları**, base64 data-URL olarak; (b) sabit Türkçe sistem istemi + YKS konu ağacı; (c) sabit kullanıcı cümlesi; (d) katı JSON şeması | `index.ts:151, 157-188, 190-240` |
| **Kullanıcı kimliği gidiyor mu** | **HAYIR.** İstek gövdesinde OpenAI'ın `user` parametresi **set edilmiyor**; uid, takma ad, e-posta gönderilmiyor. Giden tek değişken veri, `eski`/`maarif` müfredat sabiti | `index.ts:153-241`, `:117-119` |
| Hangi başlıklar gidiyor | Yalnızca `Authorization` ve `Content-Type` | `index.ts:245-248` |
| API anahtarı nerede | **Sunucuda** (`OPENAI_API_KEY`, Supabase secret). İstemcide OpenAI anahtarı yok | `index.ts:104` |
| Yanıt nereye | Sunucuda hiçbir tabloya yazılmıyor; istemciye dönüyor. Kullanıcı onaylarsa çıkarılan alanlar `mistakes` tablosuna yazılıyor | `index.ts:290`; `mistake_repository.dart:204-218` |
| Sınırlar | Günde 5 analiz hakkı; hak bittiyse istek OpenAI'a **hiç gitmiyor**. En büyük görsel ~8 MB base64 | `index.ts:136-149, 41` |
| Onay | **Var.** İlk analizden önce bağlam içinde onay sayfası; onay `user_consents` defterine `ai_upload` türüyle yazılıyor. "Fotoğrafsız devam" seçeneği analizi atlıyor | `capture_screen.dart:96-104, 168-206`; `photo_scan.sql:212-216` |

### Akış 2 — İçerik moderasyonu (`scan-photos`)

| Soru | Cevap | Dayanak |
|---|---|---|
| Hedef adres | `https://api.openai.com/v1/moderations` | `supabase/functions/scan-photos/index.ts:85` |
| Model | **`omni-moderation-latest`** | `scan-photos/index.ts:93` |
| Ne gönderiliyor | **Depoya kaydedilmiş** fotoğraf nesnesi, base64 olarak. Metin gönderilmiyor | `scan-photos/index.ts:91-97, 167-179` |
| Kullanıcı kimliği gidiyor mu | **HAYIR** | `scan-photos/index.ts:91-97` |
| Ne zaman çalışıyor | Kayıttan hemen sonra istemcinin tetiklemesiyle **ve** 10 dakikada bir çalışan `pg_cron` süpürücüsüyle | `mistake_repository.dart:227-234`; `20260903000500_league_cron.sql:246-267` |
| **Onay** | **YOK — ayrı onay alınmıyor, zorunlu.** Kaydedilen her fotoğrafta çalışıyor; "fotoğrafsız devam" diyen kullanıcının kaydettiği fotoğraf da taranıyor | `photo_scan.sql:49-60` |
| Sonuç | Yalnızca `clear` / `flagged` ikili kararı saklanıyor; OpenAI'ın kategori skorları **saklanmıyor** | `scan-photos/index.ts:104, 180-187` |

### OpenAI'ın veriyi saklaması

> ⚠️ **Kodda sıfır-saklama (ZDR) ayarı, `store: false` parametresi veya ilgili
> hiçbir başlık YOK.** Yani aktarım, OpenAI API'sinin **varsayılan** koşullarına
> tabi: içerik model eğitiminde kullanılmaz, ancak kötüye kullanım denetimi için
> sınırlı bir süre saklanabilir.
>
> Uygulama içindeki `aiConsentBody` metni (`lib/l10n/app_tr.arb:66`) şu an
> **"Fotoğraf orada saklanmaz"** diyor. Bu cümlenin kodda teknik bir karşılığı
> yok. Belgeler gerçek davranışa göre yazıldı; **uygulama içi cümle
> düzeltilmeli** (bkz. §2, bayrak A-5).

## 1.4 Sosyal veriler

| Veri | Nerede | Neden | Kim erişebiliyor | Süre | Üçüncü taraf | Dayanak |
|---|---|---|---|---|---|---|
| Arkadaşlık ilişkileri | `public.friendships` | Arkadaş listesi, istek akışı | Yalnızca ilişkinin iki tarafı | Hesap silinene kadar | Yok | `social.sql:59-97` |
| Birebir gönderilen sorular | `public.question_sends` | Arkadaşa soru yollamak | Gönderen, alıcı, yöneticiler | Hesap silinene kadar. **Alıcının "sil"i gerçek silme değil** — yalnızca `dismissed_at` işaretleniyor, satır duruyor | Yok (bildirim tetikleniyor, §1.5) | `question_sends.sql:25-36`; `20260902001050_inbox_dismiss.sql:15-30` |
| Engellemeler | `public.user_blocks` | Taciz eden kullanıcıyı susturmak | **Yalnızca engelleyen kişi.** Engellenen kişi engellendiğini öğrenemiyor | Hesap silinene kadar | Yok | `20260902000600_blocks_and_reports.sql:22-46` |
| Şikâyetler | `public.question_reports` | İçerik moderasyonu | Şikâyet eden ve yöneticiler | Hesap silinene kadar | Yok | `20240101001100_question_reports.sql:16-47` |
| Haksız şikâyet sayacı (`dismissed_reports`) | `public.profiles` | Şikâyet mekanizmasının kötüye kullanımını sınırlamak | Sunucu | Hesap silinene kadar | Yok | `20240101001200_moderation.sql:20, 195-198` |

**Arkadaş eklemenin tek yolu 6 haneli koddur;** takma adla kullanıcı arama
özelliği kaldırılmıştır (`lib/data/social_repository.dart:114-127`). Kod denemesi
saatte 20 ile sınırlı ve "kod yok / kendi kodun / engellisin" ayrımı yapılmıyor
(`lib/data/friend_repository.dart:41-66`).

## 1.5 Teknik ve operasyonel veriler

| Veri | Nerede | Neden | Kim erişebiliyor | Süre | Üçüncü taraf | Dayanak |
|---|---|---|---|---|---|---|
| **Bildirim jetonu** (`token`, `platform`) | `public.device_tokens` | Push bildirimi gönderebilmek | Kullanıcı ve sunucu | Bildirimler kapatılınca, çıkışta ve hesap silmede siliniyor | **Evet — Google (Firebase Cloud Messaging)** | `20240101002100_push.sql:15-21`; `lib/services/push_service.dart:86-118` |
| **Bildirim içeriği** | Google/FCM üzerinden geçiyor | Arkadaşlık isteği, gelen soru, çözülen soru, lig/seri kilometre taşı bildirimleri | Google (taşıyıcı olarak), alıcı cihaz | FCM'in kendi teslim penceresi | **Evet — Google.** Gövde **gönderenin takma adını içeriyor** (ör. "{ad} sana bir soru yolladı"). **Soru içeriği veya fotoğraf gitmiyor** | `supabase/functions/send-push/index.ts:208-231`; `push.sql:69, 95, 121` |
| **Çökme ve hata raporları** | Sentry | Uygulama hatalarının teşhisi | [Sentry projesine erişimi olan ekip] | [Sentry proje ayarındaki saklama süresi — **doğrulanmalı**] | **Evet — Sentry** | `lib/main.dart:29-39` |
| Yerel bildirim planı | Yalnızca cihazda | Günlük çalışma hatırlatmaları | Kullanıcı | Cihazda | Yok — ağa çıkmıyor | `lib/services/notification_service.dart` |
| Kota sayaçları (`rate_limits`), gönderim jetonları (`submission_tokens`), bildirim imleçleri (`push_cursors`) | İlgili tablolar | Kötüye kullanım ve tekrar gönderim koruması | **Hiçbir uygulama rolü** — RLS açık, politika ve yetki yok | Hesap silinene kadar (**otomatik temizlik kurulu değil**) | Yok | `20260902000200_ai_quota.sql:30-45`; `20260901000900_progress_rpcs.sql:53-66` |
| **Analiz çağrı defteri** (`ai_calls`: zaman, katman, fotoğraf özeti, ödülle mi açıldı) | `public.ai_calls` | Kayan pencere, aylık cap ve anonim deneme sınırı; maliyet kalibrasyonu | **Hiçbir uygulama rolü** — RLS açık, politika ve yetki yok; kullanıcı yalnızca SAYILARI `my_daily_state` görünümünden görüyor | 92 gün (`prune_ai_calls`); hesap silmede cascade | Yok | `20260908000100_ai_quota_v2.sql` |
| **Reklam ödülü kayıtları** (`ad_rewards`: belirteç, durum, AdMob işlem kimliği, zamanlar) | `public.ad_rewards` | Ödülün iki kez verilmesini engellemek ve günlük tavanı uygulamak | **Hiçbir uygulama rolü** | Bekleyen 1 gün, verilmiş 92 gün (`prune_ad_rewards`); hesap silmede cascade | Yok — AdMob'a yalnızca belirteç gidiyor, kullanıcı kimliği GİTMİYOR | `20260908000200_ad_reward.sql` |
| **Reklam gösterimi teknik verisi** | AdMob SDK'sı üzerinden Google'a | Reklamın getirilmesi, gösterilmesi ve ödülün doğrulanması | Google | Google'ın kendi saklama süresi | **Evet — Google (AdMob)**. IP adresi, kaba cihaz/uygulama bilgisi ve reklam etkileşimi. **Reklam kimliği (IDFA/AAID) GİTMİYOR** ve yalnızca kişiselleştirilmemiş reklam isteniyor | `lib/services/ads/ad_service_mobile.dart`; `android/app/src/main/AndroidManifest.xml` (AD_ID kaldırıldı) |

**AdMob'a ne gidiyor, ne GİTMİYOR:**

| Ayar | Değer | Anlamı |
|---|---|---|
| `ageRestrictedTreatment` | `teen` | Ergen muamelesi — kitle 13-18. `child` DEĞİL (uygulama 13 altını hedeflemiyor), `unspecified` de değil |
| `maxAdContentRating` | `G` | En kısıtlı içerik derecesi |
| İstek ek parametresi | `npa=1` | Kişiselleştirilmemiş reklam açıkça isteniyor |
| Android `AD_ID` izni | **manifest'ten kaldırıldı** | Reklam kimliği (AAID) okunamıyor |
| iOS ATT / `NSUserTrackingUsageDescription` | **hiç eklenmedi** | IDFA istenmiyor, izleme izni sorulmuyor |
| AdMob `userId` alanı | **sunucunun ürettiği rastgele belirteç** | Supabase kullanıcı kimliği reklam ağına HİÇ gönderilmiyor |
| Reklam biçimi | **yalnızca ödüllü** | Interstitial, banner ve açılış reklamı yok; kullanıcı isteyerek izliyor |

> Reklam birimi kimlikleri derleme zamanı veriliyor; **verilmezse reklam yolu
> arayüzde hiç çizilmiyor** (`lib/services/ads/ads_config.dart`).

**Sentry'ye ne gidiyor, ne temizleniyor:**

| Ayar | Değer | Anlamı |
|---|---|---|
| `sendDefaultPii` | `false` | IP adresi, kullanıcı bilgisi otomatik eklenmiyor |
| `attachScreenshot` | `false` | Ekran görüntüsü **asla** gönderilmiyor (ekranda soru fotoğrafı olabilir) |
| `attachViewHierarchy` | çağrılmıyor (kapalı) | Widget ağacı gönderilmiyor |
| `tracesSampleRate` | `0.0` | Performans izleme tamamen kapalı |
| `Sentry.setUser` | **hiç çağrılmıyor** | Kullanıcı kimliği ilişkilendirilmiyor |
| `beforeSend` | `CrashService.scrubEvent` | `event.user` ve `event.request` sıfırlanıyor; e-posta içeren veya depolama yolu (`mistake-photos`, `avatars/`) içeren breadcrumb'lar atılıyor; mesajdaki e-postalar `<e-posta>` ile maskeleniyor |

Kaynak: `lib/main.dart:29-39`, `lib/services/crash_service.dart:48-74`.
Gönderilen tek özel alan, kod içi sabit bir akış etiketi
(`app.context` = `bootstrapSocial`, `submitReview.schedule` vb.) —
`crash_service.dart:99`. Bağlantı hataları hiç raporlanmıyor (`:35-43`).

> Sentry DSN derleme zamanı `--dart-define` ile veriliyor; **DSN tanımlı değilse
> raporlama tamamen devre dışı** (`crash_service.dart:26-29`).

## 1.6 İlerleme, XP, seri ve lig verisi

| Veri | Nerede | Kim görebiliyor | Dayanak |
|---|---|---|---|
| Çözüm geçmişi (ders, konu, doğru/yanlış, zaman) | `public.study_attempts`, `public.question_attempts` | Yalnızca kullanıcı. İstemci **yazamıyor**; yazma yalnızca sunucu RPC'lerinden | `20240101001000_topic_progress.sql:9-32`; `20260901000900_progress_rpcs.sql` |
| XP, seri, elmas, lig, haftalık XP | `public.profiles` | **Tüm oturum açmış kullanıcılar** (aşağıya bakın) | `init.sql:32-36`; `20240101000600_league.sql:10-11` |
| Lig kohortu üyelikleri | `public.league_cohorts`, `public.league_members` | **Tüm oturum açmış kullanıcılar** — SELECT politikası `using (true)` | `20240101001700_league_cohorts.sql:36-67` |

**Başka kullanıcılara ne görünüyor:** `profiles_public` görünümü her oturum açmış
kullanıcıya şunları veriyor — `id`, takma ad, maskot, toplam XP, **etkin** seri
(son etkinlik dünden eskiyse 0 gösteriliyor), lig, haftalık XP ve arkadaş sayısı.
Avatar yolu yalnızca kullanıcının kendisine ve arkadaşlarına açık.
(`20260902000800_anonymous.sql:153-179`; `20260903000100_streak_effective.sql:32-33`)

> ⚠️ Bu görünüm **toplu okunabilir**: teknik olarak tek sorguyla tüm kullanıcı
> tabanının takma adı, XP'si, serisi ve ligi dökülebilir. Bu, kodda bilinen ve
> kabul edilmiş bir sınır olarak belgelenmiş
> (`20260902000700_friend_code.sql:284-287`). Gizlilik politikasında bu
> görünürlük açıkça anlatılıyor.

## 1.7 Onay kayıtları

Onaylar `public.user_consents` adlı **yalnızca ekleme yapılabilen, zaman damgalı
bir defterde** tutuluyor. Güncelleme ve silme yetkisi hiçbir uygulama rolüne
verilmemiş; geri alma da yeni bir kayıt olarak yazılıyor, geçmiş silinmiyor
(`20260901001200_consent_ledger.sql:24-51`; `supabase/tests/065_consents.sql`).

| Onay türü | Ne için | Nerede alınıyor | Dayanak |
|---|---|---|---|
| `ai_upload` | Fotoğrafın OpenAI'a gönderilmesi | İlk analizden önce, çekim ekranında | `capture_screen.dart:96-104`; `photo_scan.sql:212-216` |
| `share` | Sorunun ortak havuzda paylaşılması | Ayarlar | `lib/state/user_profile.dart:111-118` |
| `terms` | **Kullanım Koşulları'nın kabulü** | Kayıt adımında, onay kutusuyla | `20260905000200_guardian_removal.sql` (`accept_legal_terms`) |
| `privacy` | **Gizlilik Politikası'nın kabulü** | Kayıt adımında, aynı kutuyla | aynı |
| `guardian` | Veli onayı — **ARTIK KULLANILMIYOR** | Yazma yolu 0063'te kapatıldı; tür yalnızca geçmiş kayıtlar geçerli kalsın diye CHECK'te duruyor | `20260905000200_guardian_removal.sql` |

**Kayıtlanan alanlar:** `user_id`, `kind`, `granted`, `recorded_at`, `source`,
**`text_version`**.

**Metin sürümü (Task 07).** `terms` ve `privacy` kayıtları hangi metin sürümünün
onaylandığını taşıyor. Sürümü **sunucu** belirliyor (`app_config.legal_version`),
istemci bildiremiyor: onayın ispat değeri, sürümü kullanıcının beyan etmesine
bağlı olamaz. Sürüm değiştiğinde bir sonraki onay YENİ bir satır yazıyor; aynı
sürüm ikinci kez yazılmıyor. Eski kayıtlarda alan boş — o gün bir sürüm
tutulmuyordu ve geriye dönük bir değer uydurmak defterin tek işi olan doğruluğu
bozardı.

> ⚠️ **Kayıtlanmayanlar:** IP adresi ve cihaz/tarayıcı bilgisi. Bu bilinçli:
> onayın kime ve ne zaman ait olduğu `user_id` + `recorded_at` ile zaten
> belirli, IP toplamak gereksiz bir kişisel veri olurdu.
>
> **KVKK aydınlatma metni için ayrı bir onay kaydı YOK** ve olmamalı:
> aydınlatma bir bilgilendirme yükümlülüğüdür, onaya tabi değildir. Kayıt
> adımındaki kutu Kullanım Koşulları ve Gizlilik Politikası'nı kapsıyor;
> aydınlatma metni bağlantısı uygulama içinde (Ayarlar → Veri ve Gizlilik)
> kalıcı olarak erişilebilir.

## 1.8 Yönetici ve moderatör erişimi

**Bu bölüm KVKK metninde açıkça anlatılmak zorunda.**

Yönetici rolü, hiçbir kullanıcının okuyup yazamadığı ayrı bir `public.admins`
tablosuyla tanımlı (`20260901000100_privilege_lockdown.sql:36-73`). Rol atamak
için uygulama içi bir yol yok; yalnızca doğrudan veritabanı erişimiyle veriliyor.

**Yöneticinin fotoğraf erişimi (birebir kod):**

```sql
create or replace function public.can_read_mistake_photo(p_name text)
returns boolean language sql stable security definer set search_path = public
as $fn$
  select public.is_admin() or exists (
    select 1 from public.mistakes m
    where m.photo_path = p_name
      and m.user_id::text = (storage.foldername(p_name))[1]
      and m.moderation <> 'removed'
      and ( m.user_id = auth.uid()
         or (m.is_public and m.photo_scan = 'clear')
         or (m.photo_scan = 'clear' and exists (
              select 1 from public.question_sends s
              where s.mistake_id = m.id and s.receiver_id = auth.uid())))
  );
$fn$;
```
*(`supabase/migrations/20260903000400_photo_scan.sql:131-149`)*

`public.is_admin() or …` ifadesi **kısa devre** yapıyor: yönetici için sağdaki
koşulların hiçbiri değerlendirilmiyor. Sonuç:

> **Bir yönetici, kullanıcının hiç kimseyle paylaşmadığı, yalnızca kendi
> arşivinde duran soru fotoğraflarını da görüntüleyebilir.** Bu bilinçli bir
> tasarım kararı (moderatör kaldırılmış içeriği de inceleyebilmeli —
> `20260901000500_photo_ownership.sql:65-67`), ama gizlilik metinlerinde
> gizlenemez.

Aynı şekilde `admin_all_questions()` fonksiyonunun tek koşulu
`where public.is_admin()`; hiçbir görünürlük filtresi uygulamıyor ve
`photo_path` dahil tüm alanları döndürüyor
(`20240101001300_admin_questions.sql:38-69`).

**Yönetici yetkileri:** içeriği gizleme/geri alma/kalıcı silme
(`admin_question_action`), şikâyet kararı (`moderate_report`), makine
taramasında işaretlenen fotoğrafı onaylama veya kaldırma
(`admin_review_photo_scan`), kaldırılan fotoğrafın dosyasını silme.

> ⚠️ **Denetim kaydı (audit log) YOK.** Hangi yöneticinin hangi fotoğrafı ne
> zaman görüntülediği hiçbir yerde kaydedilmiyor; şikâyet kararlarında bile
> kararı veren yöneticinin kimliği tutulmuyor (`question_reports` yalnızca
> `status` ve `reviewed_at` tutuyor). Depoda `log`/`audit`/`history` adında
> hiçbir tablo yok.

**Avatarlarda yönetici bypass'ı yoktur** — `can_read_avatar` fonksiyonunda admin
dalı bulunmuyor (`20260901000700_avatar_access.sql:35-62`).

## 1.9 Saklama süreleri ve silme

| Durum | Ne oluyor | Dayanak |
|---|---|---|
| **Kalıcı hesaplar** | **Hiçbir otomatik saklama süresi veya silme yok.** Veri, kullanıcı hesabını silene kadar süresiz duruyor | Tüm göçler tarandı; `mistakes`, `study_attempts`, `question_sends`, `user_consents` için TTL/cron yok |
| **Anonim hesaplar** | 7 gün sonra otomatik siliniyor (fotoğraflar dahil) | `20260902000800_anonymous.sql:292-300`; `supabase/functions/cleanup-anonymous/index.ts:108-121` |
| **Yaptırım ve ihlal defterleri** | Silinmiyor; yanlış pozitifler `voided_at` ile geçersiz kılınıyor. Otomatik eşik yalnızca son **180 güne** bakıyor, defterin kendisi ömür boyu duruyor | `20260905000100_sanctions.sql` |
| **İmzalı fotoğraf adresleri** | 600 saniye (10 dakika) sonra geçersiz | `mistake_repository.dart:175` |
| **Kota ve jeton satırları** | Kodda "periyodik silinebilir" yazıyor ama **böyle bir iş kurulu değil** | `ai_quota.sql:47-50`; `progress_rpcs.sql:68-71` |
| **Geçmiş lig haftaları** | Silinmiyor; yalnızca `settled_at` işaretleniyor | `20260902000100_league_six_tiers.sql:176-177` |
| **Moderasyonla kaldırılan fotoğraf** | Dosya gerçekten siliniyor; yarım kalanlar yönetici kuyruğunda görünüyor | `20260901000600_moderation_purge.sql:35-74` |

### Hesap silindiğinde ne oluyor

**Kalıcı silme (hard delete). Bekleme süresi, geri alma penceresi veya
"dondurma" yok.** Kullanıcı takma adını yazarak onaylıyor
(`lib/features/settings/delete_account_screen.dart:125-141`).

Sunucu sırayla (`supabase/functions/delete-account/index.ts:111-128`):

1. `mistake-photos` ve `avatars` bucket'larındaki `<uid>/` klasörleri boşaltılır.
2. **Yalnızca depolama tamamen boşaldıysa** Auth kullanıcısı silinir.
   Kısmi başarıda hesap **silinmez** ve hata döner — kullanıcıya "silindi"
   denmez (`lib/data/account_repository.dart:13-17, 51`).
3. Veritabanı `on delete cascade` ile temizlenir.

**Cascade ile silinen tablolar (doğrulanmış tam liste):** `profiles`, `mistakes`,
`user_consents`, `friendships`, `question_sends`, `question_attempts`,
`study_attempts`, `league_members`, `device_tokens`, `submission_tokens`,
`question_reports`, `rate_limits`, `user_blocks`, `admins`, `push_cursors`,
`user_sanctions`, `photo_violations`. Bu kapsamı bir göç kapısı zorluyor: `auth.users`'a bakan her
yabancı anahtar `on delete cascade` olmak zorunda, değilse göç hata veriyor
(`20260902001000_cascade_audit.sql:20-56`).

**Silme sonrası ne kalıyor:**

- `league_cohorts` satırları (lig haftası kayıtları) kalıyor — kullanıcıya ait
  değil, `league_members` üyelikleri cascade ile gidiyor.
- **Hiçbir iz bırakılmıyor:** silinen hesaplar için tombstone/hash kaydı
  bilinçli olarak tutulmuyor (`delete-account/index.ts:124-126`).
- **Sentry'deki hata olayları** silinmiyor (kullanıcı kimliği içermedikleri için
  ilişkilendirilemez de).
- **OpenAI'a daha önce gönderilmiş fotoğraflar** geri alınamaz.
- **Gönderilmiş bildirimler** Google/FCM tarafında geri çağrılamaz.

> ✅ **DÜZELTİLDİ (1.3).** Bu uyarı bayattı: A-9 Task 08'de kapandı ama belgeye
> işlenmemişti. Kullanıcı artık tek bir soruyu (ve fotoğrafını) uygulama
> içinden silebiliyor — `delete-question` edge fonksiyonu satırı ve depodaki
> nesneyi BİRLİKTE siliyor; arayüz `lib/features/mistakes/mistakes_screen.dart`
> içinde. Engel kaldırma arayüzü de var (A-8,
> `lib/features/settings/blocked_users_screen.dart`).

## 1.10 Yurt dışına aktarım — özet tablo

| # | Alıcı | Ne gidiyor | Kimlik gidiyor mu | Dayanak |
|---|---|---|---|---|
| 1 | **OpenAI** (ABD) | Soru fotoğrafı, sabit istem, müfredat sabiti | **Hayır** | `analyze-question/index.ts:151-248` |
| 2 | **OpenAI** (ABD) | Kaydedilmiş soru fotoğrafı (moderasyon) | **Hayır** | `scan-photos/index.ts:85-97` |
| 3 | **Supabase** (bölge [doğrulanmalı]) | Uygulamanın tüm verisi: hesap, profil, fotoğraflar, sosyal veriler, onay defteri | Evet | `lib/services/supabase_config.dart:8-10` |
| 4 | **Google / Firebase** (ABD) | Cihaz bildirim jetonu, bildirim başlığı ve gövdesi (**gönderenin takma adı dahil**) | Cihaz jetonu evet; kişi adı yalnızca takma ad | `send-push/index.ts:126, 208-231`; `push_service.dart:78-102` |
| 5 | **Sentry** (bölge [doğrulanmalı]) | Hata olayları, yığın izleri, akış etiketi | **Hayır** (temizleniyor) | `main.dart:29-39`; `crash_service.dart:48-74` |
| 6 | **Google / AdMob** (ABD) | Reklam isteği ve gösterimi: IP adresi, kaba cihaz/uygulama bilgisi, reklam etkileşimi. Ödül doğrulamasında sunucunun ürettiği RASTGELE BELİRTEÇ | **Hayır** — reklam kimliği (IDFA/AAID) gönderilmiyor, `userId` alanına Supabase kimliği YAZILMIYOR | `lib/services/ads/ad_service_mobile.dart`; `AndroidManifest.xml` (AD_ID kaldırıldı) |

**Task 10'da EKLENEN alıcı: Google (AdMob).** (Aşağıdaki "Task 07'de düşen"
notu e-posta sağlayıcısıyla ilgili; listedeki 6. sıra bu yüzden yeniden doldu.) Yalnızca ÖDÜLLÜ reklam
var ve kullanıcı isteyerek izliyor. Kişiselleştirme kapalı, reklam kimliği
toplanmıyor. Ödül, Google'ın sunucusundan gelen imzalı bir geri çağrıyla
veriliyor (`supabase/functions/ad-reward`); o geri çağrıda kimliğimiz yok,
yalnızca bizim ürettiğimiz tek kullanımlık bir belirteç var.

**Task 07'de düşen altıncı alıcı:** e-posta sağlayıcısı (kurulumda Resend).
Tek işi veli onayı postasını göndermekti; veli onayı rejimi kaldırılınca
`send_guardian_email` fonksiyonu ve `app_config` anahtarları da silindi.
Uygulama artık hiçbir e-posta sağlayıcısına veri göndermiyor — parola
sıfırlama postası Supabase'in kendi altyapısından gidiyor.

> ⚠️ **Supabase'in barındırma bölgesi bu depodan tespit edilemiyor.** Üretim
> `SUPABASE_URL` derleme zamanı verildiği için depoda yok. Supabase Türkiye'de
> bölge sunmuyor, yani bu her hâlükârda yurt dışı aktarım — ama hangi ülke
> olduğu Dashboard → Project Settings → General → Region'dan alınmalı ve KVKK
> metnindeki `[Supabase bölge/ülke]` alanı doldurulmalı.

## 1.11 Toplanmadığı doğrulanan veriler

Mağaza formları için önemli — hepsi kod taramasıyla doğrulandı:

> ⚠️ **BU BÖLÜM TASK 10'DA YENİDEN YAZILDI.** Önceki sürüm "reklam SDK'sı yok"
> diyordu; artık var. Aşağıda hangi iddianın KORUNDUĞU, hangisinin DÜŞTÜĞÜ
> tek tek yazılı — çünkü mağaza formlarındaki cevapların tamamı buraya
> dayanıyor.

**DÜŞEN iddialar (artık doğru DEĞİL):**

- ~~Reklam SDK'sı yok~~ → **`google_mobile_ads` var** (yalnızca ÖDÜLLÜ reklam;
  interstitial, banner ve açılış reklamı yok).
- ~~Reklam veya izleme amaçlı hiçbir veri paylaşımı yok~~ → **AdMob reklamı
  getirip gösterirken IP adresi ve kaba cihaz/uygulama bilgisi alıyor.**
  *İzleme* amaçlı değil (aşağıya bakın) ama *reklam* amaçlı bir aktarım var.
- ~~İstemciden Supabase, Firebase ve Sentry dışında hiçbir dış HTTP çıkışı
  yok~~ → **AdMob ve onun geçişli olarak getirdiği `webview_flutter`,
  `webview_flutter_android`, `webview_flutter_wkwebview` eklentileri var.**
  Reklam içeriği bir WebView'de çiziliyor.
- ~~Uygulama içi satın alma / ödeme yok~~ → **Ödeme hâlâ YOK** ama uygulamada
  bir Plus TANITIM ekranı var ve fiyat gösteriyor. Satın alma düğmesi görünür
  biçimde devre dışı; makbuz doğrulaması ve abonelik ayrı bir iş.

**KORUNAN iddialar (kod taramasıyla doğrulandı):**

- **Reklam kimliği (IDFA / AAID) HÂLÂ toplanmıyor.** Android'de
  `com.google.android.gms.permission.AD_ID` izni, eklenti onu manifest'e merge
  etmesine rağmen `tools:node="remove"` ile DÜŞÜRÜLDÜ. iOS'ta
  `NSUserTrackingUsageDescription` eklenmedi ve ATT hiç çağrılmıyor. Yalnızca
  **kişiselleştirilmemiş** reklam isteniyor (`ageRestrictedTreatment: teen` +
  istekte `npa=1`).
- **Kullanıcı kimliği reklam ağına gitmiyor.** AdMob'un `userId`/`customData`
  alanlarına Supabase kimliği DEĞİL, sunucunun ürettiği tek kullanımlık
  rastgele bir belirteç yazılıyor.
- **Analitik SDK'sı yok** — `firebase_analytics`, `amplitude`, `mixpanel`,
  `posthog`, `segment` hiçbiri yok. Firebase yalnızca Messaging için.
- **Attribution / A/B test SDK'sı yok** — `appsflyer`, `adjust`, `branch`,
  `onesignal` yok.
- **Konum toplanmıyor** — konum izni ne iOS'ta ne Android'de beyan edilmiş.
- **Mikrofon, rehber, takvim erişimi yok.**
- **Yazı tipleri uygulamaya gömülü**; çalışma anında Google Fonts'a istek yok.

**Beyan edilen izinler:**

| Platform | İzin | Amaç metni |
|---|---|---|
| iOS | `NSCameraUsageDescription` | "Soru fotoğrafı çekmek ve profil fotoğrafı eklemek için kamera kullanılır." |
| iOS | `NSPhotoLibraryUsageDescription` | "Galeriden soru veya profil fotoğrafı seçebilmen için fotoğraflarına erişilir." |
| iOS | `UIBackgroundModes: remote-notification` | Push bildirimi |
| Android | `INTERNET` | Sunucu erişimi |
| Android | `POST_NOTIFICATIONS` | Android 13+ bildirim izni |
| Android | `RECEIVE_BOOT_COMPLETED` | Yeniden başlatmada hatırlatmaların geri kurulması |
| Android | ~~`com.google.android.gms.permission.AD_ID`~~ | **BİLEREK KALDIRILDI** — `google_mobile_ads` merge ile ekliyor, biz `tools:node="remove"` ile düşürüyoruz |

Eklentilerin eklediği izinler: `firebase_messaging` → `WAKE_LOCK`,
`ACCESS_NETWORK_STATE`; `flutter_local_notifications` → `VIBRATE`.
`image_picker_android` hiç izin beyan etmiyor (sistem seçicisini kullanıyor,
bu yüzden `CAMERA` ve `READ_MEDIA_IMAGES` gerekmiyor).
`google_mobile_ads` → `AD_ID` (**kaldırıldı**, yukarıya bakın) ve
`ACCESS_NETWORK_STATE`.

> Bu liste eklenti manifestlerinden okundu. **Birleşmiş (merged) manifest bir
> `flutter build apk` sonrası teyit edilmeli** — yerel depoda derleme çıktısı yok.

---

# 2. Mağaza uyum bayrakları

Kod tabanında bulunan ve App Store / Play incelemesinde sorun çıkarabilecek her
şey. **A grubu redde yol açabilir ve kod değişikliği ister; B grubu yalnızca
doğru beyan ister; C grubu depo dışından doğrulanmalıdır.**

## A · Redde yol açabilecekler (kod değişikliği gerektirir)

### A-1 · Veli onayı bağlantısı çalışmıyor 🔴 Kritik — ✅ **KAPANDI (Task 07)**

> **Nasıl kapandı:** düzeltilerek değil, **kaldırılarak**. 13-17 yaş için veli
> onayı hukuken zorunlu değil (COPPA 13 altı, Apple Kids Category, Play
> Families 13 altı). Mekanizmanın tamamı düştü: dört RPC, `guardian-confirm`
> edge fonksiyonu, `guardian_requests` tablosu, `profiles.guardian_email`
> sütunu. `130_age_gate.sql` bu nesnelerin GERİ GELMEDİĞİNİ katalogda
> doğruluyor. Aşağıdaki bulgu, kararın gerekçesi olarak korunuyor.

**Ne:** Veliye gönderilen onay bağlantısı `?t=<token>` biçiminde kuruluyor
(`20260902000500_age_and_guardian.sql:180`), ama bağlantıyı karşılayan edge
fonksiyonu `token` parametresini okuyor
(`supabase/functions/guardian-confirm/index.ts:58`). Parametre adları
uyuşmadığı için token boş okunuyor, biçim kontrolü düşüyor ve **her onay
"bağlantı geçersiz" ile sonuçlanıyor.** Fonksiyonun kendi başlık yorumu da
`?token=` diyor (`index.ts:4`) — yani yazım hatası SQL tarafında.

**Hangi kural:** Bu bir mağaza kuralından çok bir doğruluk sorunu. KVKK metni ve
Kullanım Koşulları "18 yaşından küçükler için veli onayı alıyoruz" diyecek;
mekanizma çalışmıyorsa bu **yanlış beyan** olur. Ayrıca 18 altı kullanıcıların
arkadaş ekleme özelliği kalıcı olarak kilitli kalır.

**Ciddiyet:** Kritik. Belgeler yayınlanmadan önce düzeltilmeli.

**Çözüm:** `age_and_guardian.sql:180`'deki `'?t='` ifadesini `'?token='` yapan
bir göç, veya edge fonksiyonunun her iki parametreyi de kabul etmesi. Ardından
uçtan uca bir gerçek test (veli e-postası → bağlantı → `user_consents`'te
`guardian` kaydı).

---

### A-2 · Soru fotoğrafı, yaş kapısından önce OpenAI'a gidiyor 🔴 Kritik

**Ne:** Onboarding adım sırası `firstCapture → age → profile → …`
(`lib/features/onboarding/onboarding_flow.dart:44`). Yani kullanıcı, doğum yılı
hiç sorulmadan önce ilk soru fotoğrafını çekiyor ve bu fotoğraf analiz için
OpenAI'a gönderiliyor. Uygulamanın çocuğun yaşını bilmediği anda, çocuğun el
yazısını içeren görsel yurt dışına aktarılmış oluyor.

**Hangi kural:** KVKK Md. 9 (yurt dışına aktarım) ve çocuk verisinin işlenmesi;
ayrıca Apple 5.1.4 (Kids) ve Play Families politikası, çocuk verisinin
aktarımında ebeveyn kontrolü bekliyor.

**Ciddiyet:** Kritik. Mağaza incelemesi bunu doğrudan yakalamayabilir, ama
KVKK açısından savunulması zor ve bir şikâyet hâlinde en kırılgan nokta.

**Çözüm — iki seçenek:**
- **(a) Daha koruyucu:** Yaş adımını ilk çekimin önüne almak. Onboarding'in
  ürün mantığını değiştirir ("önce değer göster" akışı bozulur).
- **(b) Daha az müdahaleci:** İlk çekimi yerinde bırakıp **analizi** yaş adımına
  kadar ertelemek — fotoğraf çekilir, kaydedilir, ama OpenAI'a ancak yaş
  girildikten (ve 18 altıysa veli akışı başlatıldıktan) sonra gider. Mevcut
  "fotoğrafsız devam" yolu bu ertelemeyi zaten destekliyor.

Seçim ürün kararı; (b) hem akışı korur hem aktarımı yaş bilgisinin arkasına alır.

---

### A-3 · Kötüye kullanan kullanıcıyı çıkarma yeteneği yok 🔴 Kritik — ✅ **KAPANDI (Task 07)**

> **Nasıl kapandı:** `20260905000100_sanctions.sql`. İki politikasız defter
> (`user_sanctions`, `photo_violations`) + `is_suspended()`. Yönetici askıya
> alabiliyor, kalıcı yasaklayabiliyor ve kaldırabiliyor (`admin_suspend_user`);
> uygunsuz içerikte üç ihlalde (180 günlük kayan pencere) 7 günlük otomatik
> askı, askıdan sonraki ihlalde kalıcı yasak. Yasak DÖRT politikada zorlanıyor:
> `mistakes` INSERT, `storage.objects` INSERT, `question_sends` INSERT,
> `friendships` INSERT. `270_sanctions.sql` (44 iddia) aynı yazmanın askıdan
> önce geçtiğini, sonra 42501 aldığını kanıtlıyor.

**Ne:** Yönetici yalnızca **içerik** kaldırabiliyor (`admin_question_action`).
Bir kullanıcıyı yasaklayan, askıya alan veya devre dışı bırakan hiçbir tablo,
kolon, RPC veya edge fonksiyonu yok (`ban`, `suspend`, `disable_user`,
`deactivate` taraması sonuçsuz). Tek yaptırım, haksız şikâyet edenin sesini
kısan `profiles.dismissed_reports` sayacı.

**Hangi kural:** **App Store Review Guideline 1.2 (User-Generated Content).**
Apple, kullanıcı içeriği barındıran uygulamalarda dört şey arıyor: içerik
filtreleme, şikâyet mekanizması, kullanıcı engelleme ve **"the ability to eject
abusive users from the service"**. Dördüncüsü karşılanmıyor.

**Ciddiyet:** Kritik — 1.2 kaynaklı redler bu maddede yoğunlaşıyor.

**Çözüm:** En küçük yeterli çözüm, `profiles` ya da ayrı bir tabloda yasaklama
işareti + `is_banned` kontrolünü içerik yazma ve gönderim politikalarına eklemek
+ yönetici ekranına bir "kullanıcıyı askıya al" eylemi. Kullanım Koşulları bu
yetkiyi zaten tanımlıyor (§6, Md. 9) — kodda karşılığı olmalı.

---

### A-4 · Kullanım koşulları onayı hiç alınmıyor 🔴 Kritik — ✅ **KAPANDI (Task 07)**

> **Nasıl kapandı:** kayıt adımına onay kutusu geldi (ön seçili DEĞİL; iki
> metin ayrı ayrı tıklanabilir), `user_consents.kind` CHECK'i `terms` ve
> `privacy` türlerini kabul ediyor, `text_version` sütunu eklendi ve
> `accept_legal_terms()` sürümü SUNUCUDAN damgalıyor. Onay yazılmadan
> `convertToPermanent` çağrılmıyor.

**Ne:** Onboarding akışında kullanım koşullarını kabul adımı yok. `user_consents`
defteri `terms` veya `privacy` türünü kabul etmiyor
(`20260903000400_photo_scan.sql:201-205`). Uygulama içindeki gizlilik ekranı
yalnızca bir yer tutucu gösteriyor.

**Hangi kural:** Apple 1.2 (UGC uygulamaları için EULA/koşul kabulü) ve
App Store Connect'in zorunlu gizlilik politikası bağlantısı; ayrıca KVKK
aydınlatma yükümlülüğünün belgelenebilirliği.

**Ciddiyet:** Kritik.

**Çözüm:** (1) Kayıt adımına "Kullanım Koşulları'nı ve Gizlilik Politikası'nı
okudum, kabul ediyorum" onayı; (2) `user_consents.kind` CHECK'ine `terms` ve
`privacy` türlerinin eklenmesi; (3) onay kaydına **metin sürümü** alanı
(bkz. §7, soru 4).

---

### A-5 · Uygulama içinde gerçeğe uymayan iki cümle 🔴 Kritik — ✅ **KAPANDI (Task 07)**

> **Nasıl kapandı:** aşağıda önerilen iki karşılık `lib/l10n/app_tr.arb`'ye
> birebir yazıldı (`aiConsentBody`, `privacyAiBody`) ve her ikisine gerekçeyi
> taşıyan `@` açıklama bloğu eklendi. Bu belgedeki 4.5 ve 5.3 bölümleri de
> aynı cümleyle hizalandı.

**Ne:**

| Metin | Nerede | Sorun |
|---|---|---|
| "Fotoğraf orada saklanmaz" | `lib/l10n/app_tr.arb:66` (`aiConsentBody`) | Kodda sıfır-saklama (ZDR) ayarı, `store: false` parametresi veya ilgili başlık yok. Aktarım OpenAI'ın varsayılan koşullarına tabi. |
| "fotoğraf yalnızca senin arşivinde saklanır" | `lib/l10n/app_tr.arb:662` (`privacyAiBody`) | Yöneticiler paylaşıma kapalı fotoğrafları da görebiliyor (§1.8). Cümle bunu dışlar gibi okunuyor. |

**Hangi kural:** App Store Review Guideline 5.1.1 ve Play Data Safety — beyan ile
gerçek davranış arasındaki uyumsuzluk. Mağazalar bunu doğrudan karşılaştırıyor.

**Ciddiyet:** Kritik. **Yanlış beyan, olmayan bir belgeden kötüdür.**

**Çözüm:** İki cümlenin bu belgedeki metinlerle uyumlu hâle getirilmesi.
Önerilen karşılıklar:

- `aiConsentBody` için: *"Çektiğin fotoğraf — el yazın ve karede ne varsa —
  soruyu okumak için yurt dışındaki yapay zekâ servisine (OpenAI) gönderilir.
  Kim olduğun gönderilmez. Fotoğrafın orada model eğitiminde kullanılmaz, ama
  kötüye kullanım denetimi için kısa bir süre tutulabilir. Gönderim geri
  alınamaz. Ayrıntılar için Ayarlar → Veri ve Gizlilik."*
- `privacyAiBody` için: *"…fotoğraf senin arşivinde saklanır; yalnızca sen,
  gönderdiğin arkadaşın ve bir şikâyet ya da güvenlik incelemesi hâlinde
  yetkili moderatörümüz görebilir. Hesabını sildiğinde silinir."*

---

### A-6 · Gizlilik politikası yer tutucusu yayında görünüyor 🟠 Yüksek — ✅ **KAPANDI (Task 07)**

> **Nasıl kapandı:** `privacyLegalPlaceholder` silindi; ekranda dört gerçek
> bağlantı var (koşullar, gizlilik, KVKK, hesap silme). Adresler derleme
> zamanında `--dart-define` ile geliyor (`LegalLinks`, `SupabaseConfig`
> deseni). Adres verilmemişse satır HİÇ ÇİZİLMİYOR — yer tutucu geri gelmiyor.
> **Kalan iş sizde:** metinleri bir URL'de yayınlamak ve dört anahtarı
> `supabase.json`'a girmek (bkz. §7.4 kontrol listesi).

**Ne:** Ayarlar → Veri ve Gizlilik ekranı "KVKK aydınlatma metni, kullanım
koşulları ve gizlilik politikası hazırlanıyor; yayınlandığında burada yer
alacak" diyor (`lib/l10n/app_tr.arb:664`, `privacy_screen.dart:49-54`).

**Hangi kural:** App Store Connect gizlilik politikası bağlantısını **zorunlu**
tutuyor; Play Console'da da zorunlu. Uygulama içinde "hazırlanıyor" yazan bir
ekran, inceleyicinin gözüne çarparsa doğrudan sorulur.

**Ciddiyet:** Yüksek.

**Çözüm:** Bu belgedeki 5 ve 6. bölümleri bir URL'de yayınlamak; yer tutucuyu
o bağlantılarla değiştirmek; aynı URL'leri App Store Connect ve Play Console'a
girmek.

---

### A-7 · İlan edilen asgari yaş (13) kodda zorlanmıyor 🟠 Yüksek — ✅ **KAPANDI (Task 07)**

> **Nasıl kapandı:** `set_birth_year` üst sınırı 5 → 13 yaş. Ret AYRI bir
> SQLSTATE ile (`KM013`) geliyor ve arayüz nazik bir açıklama gösteriyor.
> Çark aralığı BİLEREK daraltılmadı: yalnızca geçerli yılları göstermek kapıyı
> ortadan kaldırırdı — kullanıcı reddedilmez, sadece yalan söylerdi. Reddedilen
> deneme bir yazma olmadığı için hesap kilitlenmiyor. Yaş adımı artık
> atlanamıyor (`_canContinue` yılın yazılmasını şart koşuyor).

**Ne:** `set_birth_year` doğrulaması 5–100 yaş aralığını kabul ediyor
(`20260902000500_age_and_guardian.sql:71`); doğum yılı çarkı 1990'dan bugüne
kadar (`lib/features/onboarding/age_gate_step.dart:51-53`). Kullanım Koşulları
13 yaş sınırı ilan edecekse, 8 yaşındaki bir kullanıcının kayıt olabilmesi
beyanla çelişir.

**Hangi kural:** Play Families politikası ve Apple 5.1.4 — 13 yaş altı kullanıcı
kabul eden uygulama farklı bir rejime giriyor. Ayrıca ilan edilen yaş sınırının
uygulanmaması Kullanım Koşulları'nı zayıflatıyor.

**Ciddiyet:** Yüksek.

**Çözüm:** `set_birth_year` üst sınırını 13 yaşa çekmek ve arayüzde 13 yaşından
küçük kullanıcıya nazik bir açıklama göstermek. Doğum yılının **tek yazımlık**
olması (`age_and_guardian.sql:75-82`) bu kontrolü güçlendiriyor.

---

### A-8 · Engel kaldırma arayüzü yok 🟡 Orta — ✅ **KAPANDI (Task 08)**

> ✅ **1.3 NOTU:** Bu bayrak Task 08'de kapandı ama belgeye işlenmemişti.
> `lib/features/settings/blocked_users_screen.dart` + `my_blocked_users()`
> RPC'si var; Ayarlar → Engellenenler'den engel kaldırılabiliyor.

**Ne:** Kullanıcı bir kişiyi engelleyebiliyor, ama engellediklerinin listesini
göremiyor ve engeli kaldıramıyor. `unblock_user` RPC'si
(`20260902000600_blocks_and_reports.sql:188-196`) ve repository metodu
(`lib/data/friend_repository.dart:97-101`) mevcut — hiçbir ekran çağırmıyor.

**Hangi kural:** Apple 1.2 engelleme mekanizmasını arıyor; geri alınamaz olması
doğrudan bir ret sebebi değil, ama destek talebi ve olumsuz değerlendirme
üretir. Yanlışlıkla engelleyen kullanıcı kalıcı olarak mahsur kalıyor.

**Ciddiyet:** Orta.

**Çözüm:** Ayarlar altında "Engellediklerim" listesi ve kaldırma düğmesi.
Sunucu tarafı hazır.

---

### A-9 · Kullanıcı tek bir soruyu veya fotoğrafı silemiyor 🟡 Orta — ✅ **KAPANDI (Task 08)**

> ✅ **1.3 NOTU:** Bu bayrak Task 08'de kapandı ama belgeye işlenmemişti.
> `supabase/functions/delete-question` satırı ve depodaki nesneyi BİRLİKTE
> siliyor; arayüz `lib/features/mistakes/mistakes_screen.dart` içinde.
> Yayına hazır Gizlilik §8 ve KVKK §11 bunun tersini yazıyordu; ikisi de
> 1.3'te düzeltildi.

**Ne:** `mistakes` üzerinde silme politikası ve yetkisi var, ama arayüzde silme
eylemi yok (`lib/features/mistakes/mistakes_screen.dart`). Kullanıcının tek
silme yolu tüm hesabını silmek.

**Hangi kural:** KVKK Md. 7 ve Md. 11 (silme talebi hakkı) — hak, uygulama içi
bir yol olmasa da başvuruyla kullanılabilir, ama uygulama içi yol beklenen
uygulamadır. GDPR Md. 17 için de aynı.

**Ciddiyet:** Orta. Belgede "silme talebinizi [iletişim e-postası] üzerinden
iletebilirsiniz" diyerek karşılanabilir, ama kalıcı çözüm arayüz.

**Çözüm:** Hata kartına silme eylemi + silinen kaydın depolama nesnesinin de
silinmesi. **Dikkat:** satır silindiğinde depolama nesnesi otomatik gitmiyor
(`mistakes` silmede storage'ı temizleyen tetikleyici yok), yani silme akışı
önce dosyayı silmeli.

---

### A-10 · Ortak havuz altyapısı sunucuda hâlâ açık 🟡 Orta

**Ne:** İstemci `is_public` değerini sabit `false` yazıyor ve havuz ekranları
arşive taşınmış (`lib/features/capture/confirm_screen.dart:126-129`;
`lib/_archive/pool/`). Ama sunucu tarafı yaşıyor: `set_question_sharing` RPC'si
`authenticated` rolüne açık (`20260901000900_progress_rpcs.sql:403-426`).

**Hangi kural:** Doğruluk. Gizlilik politikası "sorularınız herkese açık
paylaşılmaz" derse, sunucunun bunu hâlâ kabul ediyor olması beyanla teknik
gerçek arasında bir boşluk bırakır.

**Ciddiyet:** Orta. İstismar için oturum açmış bir kullanıcının kasıtlı olarak
API'yi çağırması gerekir — ve ancak kendi içeriğini açabilir.

**Çözüm:** İki seçenek — (a) RPC'nin yetkisini geri almak (havuz ileride
gelecekse göçle geri verilir), (b) belgede "şu an kapalı, ileride açılabilir"
diyerek yer tutucu bırakmak. Bu belgedeki metinler **(b)** varsayımıyla yazıldı:
Gizlilik Politikası havuzu "şu an kullanımda değil" olarak anlatıyor.

---

---

### A-11 · Play'in web tabanlı hesap silme bağlantısı yok 🟠 Yüksek — 🟡 **METİN HAZIR, YAYIN SİZDE**

> **Task 07'de yapılan:** sayfanın metni yazıldı
> (`docs/hesap-silme-sayfasi.md`) ve uygulama içindeki Ayarlar → Veri ve
> Gizlilik ekranına bağlantı yuvası eklendi (`LEGAL_DELETE_URL`).
> **Kalan iş sizde:** sayfayı yayınlamak ve adresi hem `supabase.json`'a hem
> Play Console formuna girmek.
>
> ⚠️ `delete-account` edge fonksiyonunda **CORS bilinçli olarak yok**, yani
> sayfa tarayıcıdan silme çağrısı YAPAMAZ. Metin bu yüzden bir açıklama +
> e-posta talebi olarak yazıldı.

**Ne:** Uygulama içinde hesap silme akışı var ve iyi çalışıyor
(`lib/features/settings/delete_account_screen.dart`). Ancak Google Play, hesap
oluşturmaya izin veren uygulamalardan **ayrıca uygulama dışından erişilebilen
bir web bağlantısı** istiyor: kullanıcı uygulamayı silmiş olsa bile hesabının ve
verisinin silinmesini talep edebilmeli.

**Hangi kural:** Play Console → Uygulama içeriği → Veri güvenliği bölümündeki
hesap silme gereksinimi.

**Ciddiyet:** Yüksek — Play tarafında eksik alan, gönderimi engelliyor.

**Çözüm:** Gizlilik Politikası'nın yayınlandığı sitede bir "Hesabımı sil"
sayfası (silme talebini `[iletişim e-postası]` adresine yönlendiren basit bir
form veya açıklama yeterli) ve bu adresin Play formuna girilmesi.

### A-12 · Ödüllü reklam + 13-18 kitle 🟠 Yüksek — 🟡 **KOD HAZIR, KONSOL VE BEYAN SİZDE**

**Ne.** Task 10 uygulamaya `google_mobile_ads` ile ödüllü reklam ekledi.
Reklam SDK'sı üçüncü taraf veri toplaması demek ve hedef kitlenin çoğu reşit
değil.

**Hangi kural.** Apple App Review 1.3 ve 5.1.1 (reşit olmayan kullanıcılarda
veri ve reklam); Google Play Ads politikası ve Families hedef kitle kuralları;
KVKK açısından yeni bir veri alıcısı.

**Kodda kapatılanlar (hepsi depoda, doğrulanabilir):**
- `ageRestrictedTreatment: teen` ve `maxAdContentRating: G` —
  `lib/services/ads/ad_service_mobile.dart`.
- İstekte `npa=1`: kişiselleştirme açıkça kapalı.
- Android `AD_ID` izni manifest'ten `tools:node="remove"` ile DÜŞÜRÜLDÜ.
- iOS'ta ATT çağrılmıyor, `NSUserTrackingUsageDescription` eklenmedi.
- Supabase kullanıcı kimliği reklam ağına GÖNDERİLMİYOR (AdMob'un `userId` ve
  `customData` alanlarına sunucunun ürettiği tek kullanımlık belirteç gidiyor).
- Ödül istemciden talep edilemiyor: Google'ın imzalı sunucu geri çağrısı
  doğrulanıyor (`supabase/functions/ad-reward`).

**Depo dışında kalanlar — BUNLAR YAPILMADAN REKLAM YA HİÇ GELMEZ YA DA
UYUMSUZ GELİR:**
1. AdMob hesabı ve iki platform için uygulama kaydı; **uygulama kimliği
   manifest/plist'e girmezse uygulama açılışta ÇÖKER** (şu an Google'ın test
   kimliği duruyor).
2. AdMob konsolu → uygulama ayarları: çocuğa yönelik muamele ve rıza yaşı
   altı ayarları, içerik derecesi `G`, hassas kategori engelleri.
3. Ödüllü reklam birimi → **sunucu tarafı doğrulama (SSV) geri çağrı adresi**
   `ad-reward` fonksiyonuna ayarlanmalı. Ayarlanmazsa kullanıcı reklamı izler
   ama hak GELMEZ.
4. `app-ads.txt` geliştirici web sitesinin kökünde yayınlanmalı ve alan adı
   her iki mağaza listelemesinde tanımlı olmalı (bkz. `web/app-ads.txt`).
5. Play Console → App content → **Ads** beyanı "reklam içerir".
6. App Store Connect → App Privacy: `Usage Data → Advertising Data` satırı
   (§3.2) ve Google'ın yayımladığı önerilen etiket listesiyle karşılaştırma.
7. **Play Families reklam SDK'sı sertifikasyonu doğrulanmalı** — hedef kitleye
   13-15 dahil. AdMob sertifikalı ama beyan bizde.

## B · Beyan edilmesi gerekenler (kod değişikliği gerektirmez)

Bunlar redde yol açmaz ama **belgede doğru anlatılmazsa** beyan-gerçek
uyumsuzluğuna dönüşür. Hepsi aşağıdaki metinlerde karşılandı.

| # | Konu | Nerede beyan edildi |
|---|---|---|
| B-1 | Yöneticiler paylaşıma kapalı fotoğrafları görebiliyor; denetim kaydı tutulmuyor | KVKK §4.4 ve §4.6; Gizlilik Politikası §5 |
| B-2 | Bildirim gövdesinde **gönderenin takma adı** Google/FCM'e gidiyor | KVKK §4.5; Gizlilik Politikası §6 |
| ~~B-3~~ | ~~Veli e-posta adresi üçüncü taraf e-posta sağlayıcısına gidiyor~~ | **Düştü (Task 07):** veli onayı rejimi kaldırıldı, adres artık toplanmıyor |
| B-4 | Sentry'ye hata raporu gidiyor (kimlik temizlenmiş) | KVKK §4.5; Gizlilik Politikası §6 |
| B-5 | `profiles_public` toplu okunabilir — takma ad, XP, seri, lig herkese görünür | Gizlilik Politikası §5 |
| B-6 | Anonim hesaplar 7 gün sonra siliniyor. (30 günlük "e-posta askıda" dalı Task 06'dan beri hiç tetiklenmiyor; metinlerden çıkarıldı) | KVKK §7; Gizlilik Politikası §8 |
| B-7 | Moderasyon taraması zorunlu, ayrı onay alınmıyor | KVKK §4.2 ve §5 |
| B-8 | Kalıcı hesaplarda otomatik saklama süresi yok | KVKK §7 |
| B-9 | Moderasyon için bir süre taahhüdü (SLA) verilmiyor — bu bilinçli bir karar (`20260902000600_blocks_and_reports.sql:15-18`) | Kullanım Koşulları §9 "makul süre" ifadesiyle |
| B-10 | EXIF/konum temizleme garanti edilmiyor | Hiçbir metinde temizlik iddia edilmedi; Kullanım Koşulları §5 kullanıcıyı uyarıyor |
| B-11 | Alıcının gelen kutusundan "sil"i satırı silmiyor, yalnızca gizliyor | Gizlilik Politikası §8 |
| B-12 | ~~Uygulama adı tutarsız~~ — **KAPANDI (sürüm 1.2).** Ad "Kimo" olarak kesinleşti; görünen ad, bildirim yedek başlığı, paket kimliği (`com.stratejico.kimo`), README ve bu belgedeki sekiz yer tutucu tek isimde birleştirildi. Mağaza listelemesi "Kimo: AI YKS" | Kapandı; CI'daki tarama kapısı eski varyantın geri gelmesini engelliyor |

## C · Depo dışından doğrulanması gerekenler

Bu bilgiler kod tabanında **yok**; uydurulmadı, metinlerde köşeli parantez
olarak bırakıldı. Yayından önce doldurulmalı.

| # | Doğrulanacak | Nereden | Neden gerekli |
|---|---|---|---|
| C-1 | **Supabase barındırma bölgesi/ülkesi** | Supabase Dashboard → Project Settings → General → Region | KVKK Md. 9 aktarım beyanı |
| C-2 | **OpenAI hesabının veri işleme koşulları** (DPA imzalı mı, sıfır-saklama açık mı) | OpenAI hesap ayarları / kurumsal sözleşme | §4 ve §5'teki saklama cümlesi buna göre kesinleşir |
| C-3 | **Sentry projesinin bölgesi ve olay saklama süresi** | Sentry → Settings | KVKK §4.5 ve §7 |
| ~~C-4~~ | ~~E-posta sağlayıcısının kimliği ve bölgesi~~ | — | **Düştü (Task 07):** uygulama artık hiçbir e-posta sağlayıcısına veri göndermiyor |
| C-5 | **Üretim Auth ayarları** — `enable_confirmations` gerçekten kapalı mı, captcha var mı, `[auth.rate_limit]` değerleri ne | Supabase Dashboard → Authentication | Hesap güvenliği beyanı. `config.toml` **yalnızca yerel geliştirmeyi** yapılandırır; üretimdeki değer teyit edilmeden "e-posta doğrulanmıyor" beyanı kesinleşmez |
| C-6 | **Birleşmiş Android manifesti** | `flutter build apk` sonrası `build/app/outputs/logs/manifest-merger-*.txt` | Play izin beyanı; özellikle `AD_ID`'nin gerçekten olmadığının teyidi |
| C-7 | **Şirket bilgileri** — unvan, adres, VERBİS kaydı, KEP adresi | Sizde | Veri sorumlusu kimliği |
| C-8 | **iOS Firebase yapılandırması** — `GoogleService-Info.plist` depoda yok; eklenirse iOS'ta da FCM aktarımı başlar | Firebase Console | Aktarım listesi |

> **Ek not — depo belgeleri bayat:** `README.md:25-29` "Backend şimdilik yok —
> tamamen yerel" diyor ve `.env.example:7-11` yapay zekâ sağlayıcısı olarak
> Claude API'yi gösteriyor. Gerçekte Supabase + OpenAI kullanılıyor. Bunlar
> hukuki metinleri etkilemez ama bir inceleme sırasında kafa karıştırır;
> güncellenmeleri iyi olur.

---

# 3. Mağaza formu cevapları

Envanterden türetilmiş, forma girilmeye hazır cevaplar. **Tahmin yok** — her
satırın dayanağı §1'de.

## 3.1 Ortak temel kararlar

| Soru | Cevap | Gerekçe |
|---|---|---|
| Uygulama kullanıcıyı **izliyor mu** (tracking)? | **HAYIR** (Task 10'da da değişmedi) | Reklam SDK'sı VAR ama: IDFA/AAID kullanılmıyor (`AD_ID` izni manifest'ten kaldırıldı, ATT hiç çağrılmıyor), yalnızca kişiselleştirilmemiş reklam isteniyor, kullanıcı kimliği reklam ağına gönderilmiyor. Apple'ın "tracking" tanımı cihaz/kullanıcıyı uygulamalar arası ilişkilendirmeyi gerektiriyor; hiçbir ilişkilendirici göndermiyoruz (§1.11) |
| Veri **reklam veya pazarlama** için kullanılıyor mu? | **EVET — sınırlı** | Reklamı GÖSTEREBİLMEK için AdMob IP adresi ve kaba cihaz bilgisi alıyor. Bizim topladığımız hiçbir veri (e-posta, fotoğraf, XP, konu geçmişi) reklam amacıyla kullanılmıyor ya da paylaşılmıyor. **Bu satır 1.3'te değişti** |
| Veri **üçüncü taraflarla paylaşılıyor** mu? | **HAYIR** (Play tanımıyla) | OpenAI, Supabase, Google/FCM ve Sentry **hizmet sağlayıcı (veri işleyen)** sıfatıyla çalışıyor. Play, hizmet sağlayıcıya aktarımı "paylaşım" saymıyor. **AdMob farklı bir kategoridir** ve Play formunda reklam verisi ayrı beyan ediliyor (§3.3). **Bu cevap, C-2'deki OpenAI DPA durumunun teyidine bağlıdır** |
| Uygulama **reklam içeriyor** mu? | **EVET** | Play Console → App content → **Ads** beyanı "reklam içerir" olarak işaretlenmeli ve listelemede "Contains ads" etiketi görünür. Yalnızca ödüllü reklam; interstitial/banner/açılış yok |
| Veri **aktarım sırasında şifreleniyor** mu? | **EVET** | Tüm trafik HTTPS; Supabase, OpenAI, FCM ve Sentry uç noktalarının tamamı TLS |
| Kullanıcı **verisinin silinmesini talep edebiliyor** mu? | **EVET** | Uygulama içi kalıcı hesap silme (§1.9) + web bağlantısı (bkz. bayrak A-11) |
| Uygulamanın **bir kısmı çocuklara mı yönelik**? | Hedef kitle 13–18. Play'de "Hedef kitle ve içerik" formunda **13-15, 16-17 ve 18+** yaş grupları işaretlenmeli; "yalnızca çocuklar" **değil** | Kullanım Koşulları 13 yaş sınırı ilan ediyor (§6, Md. 3) |

## 3.2 App Store Connect — Gizlilik etiketleri (App Privacy)

Her satır için: **Toplanıyor mu · Kimlikle ilişkili mi (Linked to You) ·
İzleme için mi (Used to Track) · Amaç.**
İzleme sütunu **tüm satırlarda "Hayır"**.

| Apple kategorisi | Alt tür | Toplanıyor | Kimlikle ilişkili | Amaç | Kaynak |
|---|---|---|---|---|---|
| **Contact Info** | Email Address | ✅ Evet | Evet | App Functionality | Hesap e-postası (§1.1) |
| **Contact Info** | Name / Phone / Address | ❌ Hayır | — | — | Toplanmıyor (§1.1) |
| **Identifiers** | User ID | ✅ Evet | Evet | App Functionality | Hesap kimliği, takma ad, arkadaş kodu |
| **Identifiers** | Device ID | ✅ Evet | Evet | App Functionality | FCM bildirim jetonu (§1.5) |
| **User Content** | Photos or Videos | ✅ Evet | Evet | App Functionality | Soru fotoğrafları, avatar (§1.2) |
| **User Content** | Other User Content | ✅ Evet | Evet | App Functionality | Soruya düşülen not, şikâyet açıklaması, çıkarılan şıklar (§1.2, §1.4) |
| **User Content** | Emails or Text Messages / Audio | ❌ Hayır | — | — | Yok |
| **Usage Data** | Product Interaction | ✅ Evet | Evet | App Functionality, Product Personalization | XP, seri, çözüm geçmişi, tekrar takvimi (§1.6). *Personalization, aralıklı tekrar motorunun kullanıcıya göre plan kurmasından kaynaklanıyor* |
| **Usage Data** | **Advertising Data** | ✅ **Evet** | **Hayır** | **Third-Party Advertising** | **1.3'te değişti.** AdMob'un gördüğü reklam gösterimi ve etkileşimi. "Kimlikle ilişkili" DEĞİL: reklam kimliği gönderilmiyor ve kullanıcı kimliği AdMob'a yazılmıyor. "Used to Track" DEĞİL: uygulamalar arası ilişkilendirici yok |
| **Usage Data** | Other Usage Data | ❌ Hayır | — | — | Yok |
| **Diagnostics** | Crash Data | ✅ Evet | **Hayır** | App Functionality | Sentry; kullanıcı kimliği aktif olarak temizleniyor (§1.5) |
| **Diagnostics** | Performance Data | ❌ Hayır | — | — | `tracesSampleRate = 0.0` |
| **Diagnostics** | Other Diagnostic Data | ✅ Evet | **Hayır** | App Functionality | Yakalanmış hatalar + `app.context` akış etiketi |
| **Other Data** | Other Data Types | ✅ Evet | Evet | App Functionality | **Doğum yılı** (yalnızca yıl) ve onay kayıtları (§1.1, §1.7) |
| **Sensitive Info** | — | ❌ Hayır | — | — | Irk, din, sağlık, cinsel yönelim, siyasi görüş toplanmıyor |
| **Identifiers** | Device ID → reklam amacı | ❌ Hayır | — | — | AdMob'a reklam kimliği GİTMİYOR; bu satırdaki mevcut "Evet" yalnızca FCM bildirim jetonu içindir |
| **Location / Financial / Health / Contacts / Browsing History / Search History / Purchases** | — | ❌ Hayır | — | — | §1.11. **Purchases hâlâ HAYIR**: uygulama içi satın alma yok, Plus ekranı yalnızca tanıtım |

> **Not — "Photos or Videos" için amaç seçimi:** Yalnızca *App Functionality*
> işaretlenmeli. Fotoğraf analitik, kişiselleştirme veya reklam için
> kullanılmıyor; OpenAI'a yalnızca sorunun okunması ve içerik güvenliği
> taraması için gidiyor. **Reklam eklenmesi bunu DEĞİŞTİRMEDİ**: AdMob'a
> hiçbir kullanıcı içeriği gitmiyor.

> ⚠️ **DOĞRULANMASI GEREKEN (1.3).** Yukarıdaki "Advertising Data" satırı
> benim çıkarımım. Google, AdMob için ÖNERİLEN App Privacy etiketlerini kendi
> belgelerinde yayımlıyor; yayından önce o liste bu tabloyla KARŞILAŞTIRILMALI.
> Sapma varsa Google'ın listesi esas alınmalı — beyan bizde olsa da veriyi
> toplayan SDK onların.

**Diğer App Store Connect alanları:**

| Alan | Cevap |
|---|---|
| Privacy Policy URL | `[gizlilik politikası URL'i]` — **zorunlu** |
| Privacy Choices URL | Gerekmiyor — izleme yok ve kişiselleştirilmiş reklam yok. **1.3'te gözden geçirildi:** kişiselleştirme açılırsa bu alan ve bir rıza akışı (UMP/CMP) gerekli hâle gelir |
| Account deletion | Uygulama içinde mevcut; App Review'a not olarak akış yazılmalı |
| Yaş derecelendirme anketi | **Kullanıcı içeriği: EVET** (moderasyonlu). Uygulama içi kullanıcılar arası iletişim var (birebir soru gönderimi + not). Sınırsız web erişimi yok, kumar yok, şiddet yok |
| App Review notu | Test hesabı; **1.2'nin dört şartının nerede karşılandığı**: içerik filtreleme (her fotoğraf `omni-moderation-latest` ile taranır, temiz olmayan paylaşıma çıkamaz), şikâyet (her içeriğin yanında), engelleme (kullanıcı bazında), **kötüye kullananı çıkarma** (yönetici askıya alma/kalıcı yasak + üç ihlalde otomatik askı). Ayrıca kayıt adımındaki koşul onayının ekran görüntüsü |

## 3.3 Google Play — Veri Güvenliği formu

Sütunlar: **Toplanıyor · Paylaşılıyor · Zorunlu mu · Amaç.**
"Paylaşılıyor" sütunu **tüm satırlarda "Hayır"** (§3.1'deki hizmet sağlayıcı
gerekçesi).

| Play kategorisi | Veri türü | Toplanıyor | Zorunlu/İsteğe bağlı | Amaç |
|---|---|---|---|---|
| **Kişisel bilgiler** | E-posta adresi | ✅ | Zorunlu (kalıcı hesap için) | Hesap yönetimi, Uygulama işlevi |
| **Kişisel bilgiler** | Kullanıcı kimlikleri | ✅ | Zorunlu | Hesap yönetimi, Uygulama işlevi |
| **Kişisel bilgiler** | Diğer bilgiler | ✅ | İsteğe bağlı | **Doğum yılı** (yalnızca yıl) — Uygulama işlevi, çocuk güvenliği |
| **Kişisel bilgiler** | Ad, adres, telefon, ırk/etnik köken, siyasi/dini görüş, cinsel yönelim | ❌ | — | — |
| **Fotoğraflar ve videolar** | Fotoğraflar | ✅ | İsteğe bağlı (elle giriş mümkün) | Uygulama işlevi |
| **Mesajlar** | Diğer uygulama içi mesajlar | ✅ | İsteğe bağlı | **Arkadaşa soru gönderirken yazılan not** — Uygulama işlevi |
| **Mesajlar** | E-postalar, SMS | ❌ | — | — |
| **Uygulama etkinliği** | Uygulama etkileşimleri | ✅ | Zorunlu | Uygulama işlevi, Kişiselleştirme (tekrar takvimi) |
| **Uygulama etkinliği** | Kullanıcı tarafından oluşturulan diğer içerik | ✅ | İsteğe bağlı | Şikâyet açıklamaları, takma ad, avatar — Uygulama işlevi |
| **Uygulama etkinliği** | Uygulama içi arama geçmişi, yüklü uygulamalar | ❌ | — | — |
| **Uygulama bilgileri ve performansı** | Kilitlenme günlükleri | ✅ | Zorunlu | Analiz (teşhis), Uygulama işlevi |
| **Uygulama bilgileri ve performansı** | Tanılama | ✅ | Zorunlu | Analiz (teşhis) |
| **Cihaz veya diğer kimlikler** | Cihaz/diğer kimlikler | ✅ | İsteğe bağlı (bildirimler kapatılabilir) | Uygulama işlevi (push bildirimi). **Reklam kimliği DEĞİL** — AAID izni manifest'ten kaldırıldı |
| **Uygulama etkinliği** | Diğer kullanıcı eylemleri | ✅ | İsteğe bağlı | **1.3'te eklendi.** Reklam gösterimi/etkileşimi (AdMob) — Reklamcılık veya pazarlama |
| **Konum · Finansal bilgiler · Sağlık ve fitness · Ses dosyaları · Dosyalar ve belgeler · Takvim · Kişiler · Web tarama** | — | ❌ | — | — |

**Ek Play soruları:**

| Soru | Cevap |
|---|---|
| Veriler aktarım sırasında şifreleniyor mu? | **Evet** |
| Kullanıcılar verilerinin silinmesini isteyebiliyor mu? | **Evet** — uygulama içi hesap silme **ve** `[hesap silme URL'i]` |
| Veriler Play'in Aile Politikası kapsamında mı toplanıyor? | Uygulama 13 yaş altına yönelik değil; hedef kitle 13+ |
| Bağımsız bir güvenlik incelemesinden geçti mi? | Hayır (isteğe bağlı alan) |
| Reklam kimliği kullanılıyor mu? | **Hayır** — `AD_ID` izni manifest'ten `tools:node="remove"` ile düşürüldü; yalnızca kişiselleştirilmemiş reklam. **Bu cevap ancak izin kaldırılmış hâlde doğru**; izin geri gelirse EVET olur |
| Uygulama reklam içeriyor mu? (App content → Ads) | **Evet** — yalnızca ödüllü reklam. Listelemede "Contains ads" etiketi görünür |
| Hedef kitle ve içerik (Families) | 13-15, 16-17, 18+ işaretli; "yalnızca çocuklar" DEĞİL. **Doğrulanmalı:** Play, hedef kitlesinde 13 altı OLMAYAN uygulamalar için Families reklam SDK'sı sertifikasyonunu şart koşmuyor; AdMob zaten sertifikalı ama BEYAN bizde (bkz. §2 A-12) |

## 3.4 İki form arasındaki tek dikkat noktası

Apple, çökme raporlarını **"Kimlikle ilişkili değil"** olarak beyan etmemize izin
veriyor çünkü Sentry'ye kullanıcı kimliği gitmiyor (`event.user = null`,
`setUser` hiç çağrılmıyor). Play'de böyle bir ayrım yok; kilitlenme günlükleri
"toplanıyor" olarak işaretleniyor. **İki form arasındaki bu fark normaldir ve
tutarsızlık sayılmaz.**

---

# 4. KVKK Aydınlatma Metni

> **Bu bölüm yayına hazır metindir.** Köşeli parantezleri doldurup olduğu gibi
> kullanabilirsiniz. `[Yayın öncesi karar]` ile başlayan kutular editör
> notudur — yayınlamadan önce silin.

---

## Kimo — Kişisel Verilerin Korunması Hakkında Aydınlatma Metni

**Son güncelleme:** [tarih] · **Sürüm:** 1.2

Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu'nun ("KVKK") 10.
maddesi uyarınca hazırlanmıştır. Amacı, uygulamayı kullandığınızda hangi
bilgilerinizi neden işlediğimizi, kimlerle paylaştığımızı ve haklarınızı sade
bir dille anlatmaktır.

Uygulamayı kullananların çoğu lise öğrencisi. Bu yüzden metni hem öğrencinin
hem velisinin okuyabileceği bir dille yazdık. Anlamadığınız bir yer olursa
[iletişim e-postası] adresine yazın, açıklayalım.

### 1. Veri sorumlusu kimdir?

| | |
|---|---|
| **Unvan** | [şirket unvanı] |
| **Adres** | [açık adres] |
| **E-posta** | [iletişim e-postası] |
| **KEP adresi** | [KEP adresi] |
| **VERBİS kaydı** | [VERBİS kayıt bilgisi / "kayıt yükümlülüğümüz bulunmamaktadır"] |
| **Uygulama** | Kimo (iOS ve Android) |

### 2. Hangi bilgilerinizi işliyoruz?

**a) Hesap bilgileri**
- E-posta adresiniz ve şifreniz (şifre geri döndürülemez biçimde saklanır)
- Seçtiğiniz takma ad, maskot ve varsa profil fotoğrafınız
- Size özel arkadaş kodunuz
- Gireceğiniz sınav yılı ve müfredat tercihiniz

**b) Yaş bilgisi**
- **Doğum yılınız.** Yalnızca yıl; gün ve ay sorulmuyor.

**c) Yüklediğiniz içerik**
- Çektiğiniz **soru fotoğrafları.** Bu fotoğraflarda el yazınız, defteriniz ve
  kadraja giren her şey bulunabilir.
- Fotoğraftan çıkarılan soru bilgileri (ders, konu, şıklar, doğru cevap)
- Bir soruyu arkadaşınıza gönderirken yazdığınız not
- Bir içeriği şikâyet ederken yazdığınız açıklama

**d) Çalışma ve ilerleme bilgileriniz**
- Hangi soruyu ne zaman çözdüğünüz, doğru mu yanlış mı yaptığınız
- XP puanınız, seriniz, elmaslarınız, lig ve haftalık sıralamanız
- Tekrar takviminiz

**e) Sosyal bilgiler**
- Arkadaşlıklarınız ve arkadaşlık istekleriniz
- Kime hangi soruyu gönderdiğiniz
- Engellediğiniz kullanıcılar ve yaptığınız şikâyetler

**f) Teknik bilgiler**
- Bildirimleri açtıysanız cihazınızın bildirim kimliği (jeton)
- Uygulama hata verdiğinde oluşan hata kayıtları ve teknik ayrıntılar
- Kötüye kullanımı önlemek için tutulan kullanım sayaçları

**g) Onay kayıtlarınız**
- Hangi onayı ne zaman verdiğiniz veya geri aldığınız
- Kullanım Koşulları ve Gizlilik Politikası'nı kabul ettiğinizde, **kabul
  ettiğiniz metnin sürüm numarası**

**h) Uygulama kurallarına uyum kayıtları**
- Yüklediğiniz bir fotoğraf otomatik tarama tarafından uygunsuz bulunduysa
  bunun kaydı
- Hesabınıza bir kısıtlama uygulandıysa (askıya alma, kapatma) bunun kaydı,
  tarihi ve gerekçe kodu

**Toplamadığımız bilgiler:** adınız ve soyadınız, T.C. kimlik numaranız,
telefon numaranız, adresiniz, okulunuz, sınıfınız, konumunuz, rehberiniz.
Sağlık, din, siyasi görüş gibi özel nitelikli hiçbir veri toplamıyoruz.
Reklam kimliğinizi kullanmıyoruz ve sizi uygulama dışında takip etmiyoruz.

### 3. Bu bilgileri neden işliyoruz?

| Amaç | Hangi bilgiler |
|---|---|
| Hesabınızı açmak ve sizi tanımak | Hesap bilgileri |
| Çektiğiniz sorunun okunması ve doğru derse/konuya yerleştirilmesi | Soru fotoğrafı, müfredat tercihi |
| Hata bankanızı ve tekrar takviminizi kurmak | Yüklediğiniz içerik, çalışma bilgileri |
| Oyunlaştırma: XP, seri, lig, elmas | Çalışma ve ilerleme bilgileri |
| Arkadaşlarınızla soru paylaşmanız | Sosyal bilgiler, yüklediğiniz içerik |
| Size bildirim göndermek | Bildirim jetonu, takma adınız |
| **Uygulamayı güvenli tutmak:** uygunsuz içeriği engellemek, şikâyetleri incelemek, taciz ve kötüye kullanımı önlemek | Soru fotoğrafları, şikâyetler, engellemeler, kullanım sayaçları |
| **13 yaş sınırını uygulamak** ve yaş derecelendirmesini doğru yapmak | Doğum yılı |
| **Kurallara uymayan kullanıcıyı durdurmak:** uygunsuz içerik tekrarlanırsa hesabı geçici olarak kısıtlamak veya kapatmak | Tarama sonuçları, ihlal ve kısıtlama kayıtları |
| Uygulamanın hatalarını bulup düzeltmek | Hata kayıtları |
| Yasal yükümlülüklerimizi yerine getirmek ve bir uyuşmazlık hâlinde hakkımızı savunmak | Duruma göre ilgili kayıtlar |

**Sizi profilleyip reklam göstermiyoruz.** Verilerinizi satmıyoruz.

### 4. Hangi hukuki sebeple işliyoruz?

KVKK'nın 5. maddesindeki şu sebeplere dayanıyoruz:

| İşleme | Hukuki sebep |
|---|---|
| Hesap açma, uygulamayı kullandırma, sorularınızı saklama, arkadaş özellikleri, bildirim gönderme | **Md. 5/2-c** — sözleşmenin kurulması ve ifası için gerekli olması |
| İçerik moderasyonu, şikâyet incelemesi, taciz ve kötüye kullanımın önlenmesi, hata kayıtları, kullanım sayaçları | **Md. 5/2-f** — temel hak ve özgürlüklerinize zarar vermemek kaydıyla meşru menfaatimiz |
| Doğum yılının sorulması ve 13 yaş sınırının uygulanması | **Md. 5/2-f** — çocuğun korunmasına yönelik meşru menfaat; ayrıca ilgili mevzuattan doğan yükümlülüklerimiz kapsamında **Md. 5/2-ç** |
| İhlal kayıtlarının tutulması ve hesap kısıtlamaları | **Md. 5/2-f** — hizmetin ve diğer kullanıcıların güvenliğine yönelik meşru menfaat; ayrıca **Md. 5/2-e** (bir hakkın tesisi ve korunması) |
| Yasal saklama ve bildirim yükümlülükleri, yetkili makam talepleri | **Md. 5/2-ç** — hukuki yükümlülüğün yerine getirilmesi |
| Bir hakkın tesisi, kullanılması veya korunması (uyuşmazlık hâli) | **Md. 5/2-e** |
| **Soru fotoğrafınızın yurt dışındaki yapay zekâ servisine gönderilmesi** | **Açık rızanız** (aşağıda 5. bölüm) |

### 5. Soru fotoğraflarınız ve yapay zekâ

Bu bölümü ayrı yazdık, çünkü en çok bilmeniz gereken kısım burası.

**Fotoğrafınız iki ayrı sebeple yurt dışına gönderiliyor:**

**a) Sorunun okunması için.** Fotoğrafı çektiğinizde, sorunun metnini ve
şıklarını çıkarmak, doğru derse ve konuya yerleştirmek için görsel, merkezi
Amerika Birleşik Devletleri'nde bulunan **OpenAI**'a gönderilir. Bu gönderimi
yapmadan önce sizden açık rıza alıyoruz: ilk fotoğrafınızı çektiğinizde bir
onay ekranı çıkıyor ve onayınız zaman damgasıyla kaydediliyor. **Onay vermek
zorunda değilsiniz** — "fotoğrafsız devam et" derseniz soruyu elle
girebilirsiniz, uygulamanın hiçbir özelliği kapanmaz.

**b) İçerik güvenliği için.** Kaydettiğiniz her fotoğraf, uygunsuz içerik
barındırıp barındırmadığını anlamak için OpenAI'ın içerik denetimi servisine
gönderilir. **Bu tarama zorunludur ve ayrı bir onaya bağlı değildir**, çünkü
uygulamada birbirine içerik gönderebilen ve çoğu reşit olmayan kullanıcılar var;
taramayı isteğe bağlı yapmak korumanın kendisini işlevsiz kılardı. Tarama
sonucu yalnızca "temiz" veya "şüpheli" olarak saklanır.

**Gönderimde kim olduğunuz belirtilmez.** İsteğe adınız, e-postanız, kullanıcı
kimliğiniz veya takma adınız eklenmez; giden şey fotoğraf ve sabit bir talimat
metnidir.

**OpenAI fotoğrafı ne yapıyor?** OpenAI, API üzerinden gönderilen içeriği
yapay zekâ modellerini eğitmek için kullanmaz. Ancak kötüye kullanımın
denetlenmesi amacıyla içerik sınırlı bir süre saklanabilir ve bu süre sonunda
silinir. Güncel koşullar için: [OpenAI veri işleme politikası URL'i].

**Gönderim geri alınamaz.** Onayınızı ileride geri alabilirsiniz — bu, o andan
sonraki gönderimleri durdurur; daha önce gönderilmiş bir fotoğrafı geri
çağıramayız.

> **[Yayın öncesi karar — yurt dışına aktarımın hukuki dayanağı]**
> KVKK'nın 9. maddesi 2024 değişikliğiyle yeniden düzenlendi. İki yol var:
>
> **Seçenek 1 — Standart sözleşme (Md. 9/3-b/3).** Kurul'un ilan ettiği standart
> sözleşme metni OpenAI (ve diğer yurt dışı sağlayıcılar) ile imzalanır ve
> imzadan itibaren **5 iş günü içinde** Kurul'a bildirilir. **Daha koruyucu ve
> daha sürdürülebilir yol budur:** aktarımı açık rızanın kırılganlığından
> kurtarır, kullanıcı rızasını geri alsa bile hizmet güvenliği taraması
> hukuken ayakta kalır ve sürekli/sistematik aktarım için doğru araçtır.
> Maliyeti: sağlayıcıyı imzaya ikna etmek ve bildirim yükümlülüğü.
>
> **Seçenek 2 — Açık rıza (Md. 9/6-a).** Uygulamanın bugün yaptığı budur.
> **Daha hızlı ve hemen uygulanabilir**, ama Md. 9/6 istisnaları **"arızi
> olmak"** kaydıyla düzenlenmiştir. Her fotoğrafta çalışan sürekli bir
> aktarımın "arızi" sayılması tartışmalıdır; ayrıca zorunlu moderasyon
> taramasına açık rıza dayanağı hiç uymaz (rızayı geri alan kullanıcıda tarama
> yine de çalışır).
>
> **Önerimiz:** Seçenek 1'i hedefleyin, Seçenek 2'yi geçiş döneminde koruyun —
> yani standart sözleşme tamamlanana kadar açık rıza almaya devam edin.
> Yukarıdaki metin bu ikili yapıya göre yazılmıştır. Standart sözleşme
> imzalandığında, 4. bölümdeki tablonun son satırına *"ve Kurul'a bildirilen
> standart sözleşme (Md. 9/3-b/3)"* ifadesi eklenmelidir.

### 6. Bilgilerinizi kimlerle paylaşıyoruz?

Verilerinizi **satmıyoruz**.

Uygulama **ücretsiz ve reklam destekli**. Reklamları Google'ın reklam ağı
(AdMob) gösteriyor. Reklamların size **kişiselleştirilmediğini** özellikle
belirtmek isteriz: ilgi alanlarınıza göre reklam seçilmiyor, cihazınızın
reklam kimliği (IDFA/AAID) okunmuyor ve **bize verdiğiniz hiçbir bilgi —
e-postanız, soru fotoğraflarınız, çalışma geçmişiniz, puanlarınız — reklam
için kullanılmıyor ya da reklam ağına gönderilmiyor.** Reklamı gösterebilmek
için Google'ın gördüğü şey, internet bağlantınızın adresi (IP) ve cihazınızın
kaba teknik bilgisi.

Hizmeti sunabilmek için aşağıdaki sağlayıcılarla çalışıyoruz:

| Kime | Ne aktarılıyor | Neden | Nerede |
|---|---|---|---|
| **Supabase** (barındırma ve veritabanı) | Uygulamadaki tüm verileriniz | Hesabınızın ve içeriğinizin saklanması | [Supabase bölge/ülke] |
| **OpenAI** | Soru fotoğrafları (kimliksiz) | Sorunun okunması ve içerik güvenliği taraması | ABD |
| **Google (Firebase Cloud Messaging)** | Cihaz bildirim jetonu ve bildirim metni. **Bildirim metninde size soru gönderen kişinin takma adı yer alır** (ör. "Ayşe sana bir soru yolladı"). Sorunun kendisi veya fotoğraf gönderilmez | Bildirimlerin cihazınıza ulaştırılması | ABD |
| **Sentry** (hata izleme) | Uygulama hata kayıtları ve teknik ayrıntılar. **Kullanıcı kimliğiniz ve e-postanız gönderilmeden önce silinir**; ekran görüntüsü hiç alınmaz | Hataların bulunup düzeltilmesi | [Sentry bölge/ülke] |
| **Google (AdMob)** — reklam | IP adresiniz ve cihazınızın kaba teknik bilgisi. **Kimliğiniz, e-postanız, fotoğraflarınız ve çalışma verileriniz GİTMEZ.** Reklam kimliğiniz okunmaz | Ücretsiz kullanıma reklamla destek olmak; ödüllü reklamda hakkınızın doğrulanması | ABD |

Ayrıca yasal olarak zorunlu olduğumuz hâllerde yetkili kamu kurum ve
kuruluşlarına, talepleri kapsamında bilgi verebiliriz.

Supabase, OpenAI, Google/FCM ve Sentry bizim adımıza ve talimatımızla çalışan
**veri işleyenlerdir**; verilerinizi kendi amaçları için kullanamazlar.
**AdMob bundan farklıdır:** Google, reklam gösterimi sırasında elde ettiği
teknik veriyi kendi reklam sistemi için de işleyebilir. Bu yüzden onu ayrı bir
satırda gösteriyoruz.

Supabase, OpenAI, Google ve Sentry'ye yapılan aktarımların tamamı yurt dışına
aktarım niteliğindedir ve 5. bölümde anlatılan hukuki dayanaklara tabidir.

**Reklamları kapatmak istiyorsanız:** şu an reklamsız bir sürüm sunmuyoruz.
Ödüllü reklamı İZLEMEK TAMAMEN SİZE BAĞLIDIR — izlemezseniz uygulamanın hiçbir
özelliği kapanmaz; soru kaydetmeye ve tekrar yapmaya aynı şekilde devam
edersiniz.

### 7. Verilerinizi ne kadar süre saklıyoruz?

| Veri | Süre |
|---|---|
| Hesabınız ve içeriğiniz (fotoğraflar dahil) | **Hesabınızı silene kadar.** Otomatik bir süre sınırı yoktur |
| Kayıt olmadan denediyseniz (anonim hesap) | **7 gün** sonra otomatik olarak silinir |
| Uygulama kurallarına uyum kayıtları (ihlal ve kısıtlama kayıtları) | Hesabınızı silene kadar. Otomatik kısıtlama kararında yalnızca **son 180 gün** dikkate alınır |
| Fotoğrafınıza verilen geçici erişim adresleri | 10 dakika |
| Hata kayıtları (Sentry) | [Sentry saklama süresi] |
| Yasal saklama yükümlülüğüne tabi kayıtlar | İlgili mevzuatın öngördüğü süre |

**Hesabınızı sildiğinizde ne oluyor?** Uygulama içinden hesabınızı
silebilirsiniz. Bekleme süresi veya geri alma penceresi yoktur; işlem
geri alınamaz. Önce fotoğraflarınız ve avatarınız depodan silinir, ardından
hesabınız ve ona bağlı tüm kayıtlar (sorularınız, ilerlemeniz, arkadaşlıklarınız,
gönderdiğiniz sorular, onay kayıtlarınız, bildirim jetonlarınız) silinir.
Depolama temizliği tamamlanmazsa hesap **silinmez** ve size hata bildirilir —
yarım silme yapmayız.

Silme işleminden sonra geri alınamayacak birkaç şey vardır ve bunları açıkça
söylüyoruz: daha önce OpenAI'a gönderilmiş fotoğraflar, daha önce gönderilmiş
bildirimler ve arkadaşınıza gönderdiğiniz bir sorunun onun tarafında kalan
kaydı geri çağrılamaz. Kimliğinizle ilişkilendirilmemiş teknik hata kayıtları
da Sentry'deki saklama süresi boyunca kalabilir.

### 8. Yaşınız 18'den küçükse

**Uygulama 13 yaş ve üzeri içindir. 13 yaşından küçükler kullanamaz.**

- Kayıt sırasında **doğum yılınızı** soruyoruz. Yalnızca yıl; gün ve ay değil.
- **Bu sınır teknik olarak uygulanıyor:** 13 yaşından küçük bir doğum yılı
  girildiğinde kayıt tamamlanmaz ve bunun nedeni size açıkça söylenir.
- Doğum yılı **bir kez yazılır**, sonradan değiştirilemez. Yanlış girdiyseniz
  [iletişim e-postası] adresine yazın, düzeltelim.
- 13–18 yaş arasındaysanız uygulamanın **tüm özelliklerini** kullanabilirsiniz.
  Arkadaş eklemenin tek yolu, karşı tarafın size verdiği **6 haneli arkadaş
  kodudur** — kimse sizi takma adınızla arayıp bulamaz, size kodunuzu
  vermediğiniz biri arkadaşlık isteği gönderemez. İstemediğiniz biri olursa
  onu engelleyebilir ve kodunuzu yenileyebilirsiniz.

**Veli onayı hakkında.** Daha önceki sürümlerde 18 yaşından küçük
kullanıcılarda arkadaş ekleme veli onayına bağlanmıştı. **Bu uygulamadan
vazgeçildi.** Nedeni: 13–17 yaş için veli onayı yürürlükteki mevzuatta zorunlu
tutulmuyor, mekanizmanın kendisi velinin kimliğini doğrulayamıyordu ve
uygulamanın sosyal yüzeyi zaten kod tabanlı (yabancıyla temas kurma yolu yok).
Bunun yerine korumayı, herkes için çalışan üç mekanizmaya dayandırıyoruz:
zorunlu içerik taraması, engelleme/şikâyet ve kurallara uymayan hesabın
kısıtlanması.

**Velilere:** Çocuğunuzun uygulamada hangi verilerinin işlendiğini öğrenmek,
bir içeriğin kaldırılmasını ya da hesabın silinmesini istemek için
[iletişim e-postası] adresine yazabilirsiniz. Yasal temsilci sıfatıyla
başvurduğunuzda, çocuğunuzun KVKK Md. 11 haklarını onun adına
kullanabilirsiniz.

### 9. İçeriğinizi kimler görebilir?

Bunu açıkça yazmak istiyoruz:

- **Soru fotoğraflarınız varsayılan olarak özeldir.** Bir arkadaşınıza
  göndermediğiniz sürece başka bir kullanıcı onları göremez.
- Bir soruyu arkadaşınıza gönderirseniz, o kişi sorunun fotoğrafını,
  şıklarını ve yazdığınız notu görür.
- **Bir şikâyet veya güvenlik incelemesi söz konusu olduğunda, yetkili
  moderatörümüz içeriğinizi — hiç kimseyle paylaşmadığınız fotoğraflar
  dahil — görüntüleyebilir.** Bu yetki, uygunsuz içeriği ve reşit olmayan
  kullanıcılara yönelik riskleri denetleyebilmek için vardır ve yalnızca
  sınırlı sayıda yetkili kişide bulunur.
- Takma adınız, maskotunuz, XP'niz, seriniz, liginiz ve arkadaş sayınız
  uygulamadaki **diğer kullanıcılara görünür**. Profil fotoğrafınızı ise
  yalnızca siz, arkadaşlarınız ve o haftaki lig grubunuzdaki kişiler görür.
- Birini engellediğinizde o kişi engellendiğini öğrenmez; size soru ve
  arkadaşlık isteği gönderemez hâle gelir.

### 10. Verileriniz nasıl korunuyor?

- Fotoğraflarınız **herkese kapalı** depolama alanlarında tutulur; erişim
  yalnızca 10 dakika geçerli, imzalı adreslerle olur.
- Veritabanında satır düzeyinde güvenlik kuralları uygulanır: kural olarak
  yalnızca kendi satırlarınızı okuyabilirsiniz.
- XP, seri, lig ve doğru cevap gibi kritik alanları uygulama değil **sunucu**
  belirler; istemciden değiştirilemez.
- Onay kayıtları yalnızca ekleme yapılabilen bir defterde tutulur;
  değiştirilemez ve silinemez.
- Şifreler geri döndürülemez biçimde saklanır.
- Tüm veri trafiği şifreli bağlantı üzerinden geçer.

Hiçbir sistemin %100 güvenli olmadığını da dürüstçe söylüyoruz. Bir güvenlik
ihlali yaşanırsa Kurul'a ve etkilenen kullanıcılara mevzuatın öngördüğü şekilde
bildirim yaparız.

### 11. Haklarınız (KVKK Md. 11)

Bize başvurarak şunları talep edebilirsiniz:

1. Kişisel verinizin işlenip işlenmediğini öğrenme
2. İşlenmişse buna ilişkin bilgi talep etme
3. İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
4. Yurt içinde veya yurt dışında verilerinizin aktarıldığı üçüncü kişileri bilme
5. Eksik veya yanlış işlenmişse düzeltilmesini isteme
6. Kanundaki şartlar çerçevesinde silinmesini veya yok edilmesini isteme
7. Düzeltme, silme veya yok etme işlemlerinin, verilerinizin aktarıldığı üçüncü
   kişilere bildirilmesini isteme
8. Verilerinizin münhasıran otomatik sistemlerle analiz edilmesi suretiyle
   aleyhinize bir sonuç ortaya çıkmasına itiraz etme
9. Kanuna aykırı işleme sebebiyle zarara uğramanız hâlinde zararınızın
   giderilmesini talep etme

**Nasıl başvurursunuz?** Talebinizi [iletişim e-postası] adresine ya da
[açık adres] adresine yazılı olarak iletebilirsiniz. Kimliğinizi doğrulamak
için sizden ek bilgi isteyebiliriz. Başvurunuzu **en geç 30 gün içinde**
sonuçlandırırız. Ücretsizdir; işlemin ayrıca bir maliyeti varsa Kurul'un
belirlediği tarifedeki ücreti isteyebiliriz.

Cevabımızı yetersiz bulursanız veya 30 gün içinde cevap alamazsanız Kişisel
Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz.

**Hızlı yollar:** Hesabınızı ve verilerinizi uygulama içinden
Ayarlar → Hesabımı sil ile kendiniz silebilirsiniz. **Tek bir soruyu da
uygulama içinden silebilirsiniz** — soru kartındaki sil eylemi, soruyu ve
fotoğrafını birlikte kaldırır. Engellediğiniz kişileri
Ayarlar → Engellenenler'den çıkarabilirsiniz.

### 12. Bu metin değişirse

Bu metni güncellediğimizde uygulama içinde ve bu sayfada duyururuz. Önemli bir
değişiklik olursa (ör. yeni bir hizmet sağlayıcı veya yeni bir aktarım) sizi
ayrıca bilgilendiririz.

---

# 5. Gizlilik Politikası

> **Bu bölüm yayına hazır metindir ve bir URL'de yayınlanmak üzere yazılmıştır.**
> App Store Connect ve Google Play, bu bağlantıyı zorunlu tutuyor. KVKK
> Aydınlatma Metni ile aynı gerçeklere dayanır, sadece daha kısa ve okunaklıdır.

---

## Kimo Gizlilik Politikası

**Son güncelleme:** [tarih] · **Sürüm:** 1.2

Kimo, YKS'ye hazırlanan öğrenciler için bir çalışma uygulamasıdır.
Kullanıcılarımızın çoğu lise öğrencisi olduğu için bu metni kısa ve anlaşılır
tutmaya çalıştık.

Uygulamayı [şirket unvanı] işletiyor. Sorularınız için: [iletişim e-postası]

### Bir bakışta

| | |
|---|---|
| 🚫 **Verilerinizi satmıyoruz** | Hiçbir koşulda |
| 📺 **Reklam var ama siz istemedikçe çıkmaz** | Yalnızca "ödüllü reklam": hakkınız bittiğinde siz dokunursanız. Kendiliğinden açılan reklam yok. İzlemezseniz hiçbir şey kapanmaz |
| 🚫 **Takip yok, kişiselleştirme yok** | Reklam kimliğinizi okumuyoruz, sizi uygulama dışında izlemiyoruz ve bize verdiğiniz bilgileri reklam için kullanmıyoruz |
| 📷 **Soru fotoğraflarınız özeldir** | Bir arkadaşınıza göndermediğiniz sürece diğer kullanıcılar göremez |
| 🤖 **Fotoğraflar yapay zekâya gidiyor** | Sorunun okunması ve içerik güvenliği için, **kim olduğunuz belirtilmeden** |
| 🧑‍⚖️ **Moderatörümüz görebilir** | Şikâyet veya güvenlik incelemesinde, paylaşmadığınız fotoğraflar dahil |
| 🗑️ **İstediğiniz zaman silebilirsiniz** | Uygulama içinden, tek adımda, kalıcı olarak |
| 👦 **13 yaş altı kullanamaz** | Bu sınır kayıt sırasında teknik olarak uygulanır |
| 🚧 **Kurallara uymayanı durdururuz** | Uygunsuz içerik tekrarlanırsa hesap geçici olarak kısıtlanır; itiraz edebilirsiniz |

### 1. Hangi bilgileri topluyoruz?

**Siz verdiğiniz için:**
- E-posta adresiniz ve şifreniz
- Takma adınız, maskotunuz, varsa profil fotoğrafınız
- Doğum yılınız (yalnızca yıl)
- Gireceğiniz sınav yılı ve müfredatınız
- **Çektiğiniz soru fotoğrafları** ve bunlarla ilgili yazdıklarınız

**Uygulamayı kullandıkça oluşan:**
- Hangi soruyu ne zaman çözdüğünüz, doğru/yanlış geçmişiniz, tekrar takviminiz
- XP, seri, elmas, lig ve haftalık sıralamanız
- Arkadaşlıklarınız, gönderdiğiniz sorular, engellemeleriniz, şikâyetleriniz
- Verdiğiniz onayların zaman damgalı kaydı ve kabul ettiğiniz metnin sürümü
- Bir fotoğrafınız otomatik tarama tarafından uygunsuz bulunduysa bunun kaydı;
  hesabınıza bir kısıtlama uygulandıysa kısıtlamanın tarihi ve gerekçe kodu

**Teknik olarak oluşan:**
- Bildirimleri açtıysanız cihazınızın bildirim kimliği
- Uygulama hata verdiğinde oluşan hata kayıtları
- Kötüye kullanımı önleyen kullanım sayaçları

**Toplamadıklarımız:** ad-soyad, T.C. kimlik numarası, telefon, adres, okul,
sınıf, konum, rehber, sağlık verisi, **reklam kimliği (IDFA/AAID)**.
Uygulamada çerez kullanılmaz.

**Reklamlar hakkında:** uygulama ücretsiz ve reklam destekli. Reklamlar
**kişiselleştirilmiyor**: cihazınızın reklam kimliği okunmuyor, ilgi
alanlarınıza göre reklam seçilmiyor ve bize verdiğiniz hiçbir bilgi reklam
için kullanılmıyor. Ayrıntı için 6. bölüme bakın.

### 2. Bu bilgileri neden topluyoruz?

Hesabınızı açmak; çektiğiniz soruyu okuyup doğru konuya yerleştirmek; hata
bankanızı ve tekrar takviminizi kurmak; XP, seri ve lig sistemini çalıştırmak;
arkadaşlarınızla soru paylaşmanızı sağlamak; bildirim göndermek; uygulamayı
uygunsuz içerikten ve kötüye kullanımdan korumak; 18 yaşından küçük
kullanıcıları korumak; hataları bulup düzeltmek; yasal yükümlülüklerimizi
yerine getirmek.

Bunların dışında bir amaçla kullanmıyoruz. Sizi profilleyip reklam
göstermiyoruz.

### 3. Soru fotoğraflarınız ve yapay zekâ

Bu, en dikkat etmenizi istediğimiz bölüm.

Çektiğiniz fotoğrafta **el yazınız, defteriniz ve kadraja giren her şey**
bulunabilir. Fotoğraf iki sebeple yurt dışındaki bir yapay zekâ servisine
(**OpenAI**, ABD) gönderilir:

1. **Sorunun okunması için.** Bunun için önceden onayınızı alırız. Onay vermek
   zorunda değilsiniz; "fotoğrafsız devam et" derseniz soruyu elle
   girebilirsiniz ve uygulamanın hiçbir özelliği kapanmaz.
2. **İçerik güvenliği taraması için.** Kaydettiğiniz her fotoğraf uygunsuz
   içerik barındırıp barındırmadığı açısından taranır. **Bu tarama zorunludur.**
   Uygulamada kullanıcılar birbirine içerik gönderebiliyor ve çoğu reşit değil;
   taramayı isteğe bağlı yapmak korumayı işlevsiz kılardı.

**Gönderimde kim olduğunuz belirtilmez** — adınız, e-postanız veya kullanıcı
kimliğiniz eklenmez.

**OpenAI fotoğrafı ne yapıyor?** İçerik yapay zekâ modellerinin eğitiminde
kullanılmaz. Ancak kötüye kullanımın denetlenmesi için sınırlı bir süre
saklanabilir. Güncel koşullar: [OpenAI veri işleme politikası URL'i].

**Gönderim geri alınamaz.** Onayınızı geri alabilirsiniz; bu, sonraki
gönderimleri durdurur ama gönderilmiş bir fotoğrafı geri getirmez.

### 4. Uygulamayı kullananlar birbirinin nesini görüyor?

| Bilgi | Kim görebiliyor |
|---|---|
| Takma adınız, maskotunuz, XP'niz, etkin seriniz, liginiz, arkadaş sayınız | **Uygulamadaki tüm kullanıcılar** |
| Profil fotoğrafınız | Siz, arkadaşlarınız ve o haftaki lig grubunuz |
| Soru fotoğraflarınız ve notlarınız | **Yalnızca siz** — ta ki bir arkadaşınıza gönderene kadar |
| Bir arkadaşınıza gönderdiğiniz soru | O arkadaşınız |
| Doğum yılınız ve e-postanız | **Hiçbir kullanıcı** |
| Engellediğiniz kişiler | **Yalnızca siz.** Engellenen kişi bunu öğrenmez |

Arkadaş eklemenin tek yolu 6 haneli arkadaş kodudur; kimse sizi takma adınızla
arayıp bulamaz. Kodunuzu günde bir kez yenileyebilirsiniz.

### 5. Moderatör erişimi

Bunu saklamak istemiyoruz: bir şikâyet geldiğinde veya otomatik tarama bir
fotoğrafı şüpheli işaretlediğinde, **yetkili moderatörümüz içeriğinizi — hiç
kimseyle paylaşmadığınız fotoğraflar dahil — görüntüleyebilir.**

Bu yetki, uygunsuz içeriği ve reşit olmayan kullanıcılara yönelik riskleri
denetleyebilmek için vardır. Yalnızca sınırlı sayıda yetkili kişide bulunur ve
uygulama içinden kimseye verilemez.

### 6. Kimlerle paylaşıyoruz?

Verilerinizi **satmıyoruz** ve bize verdiğiniz bilgileri reklam için
kullanmıyoruz. Hizmeti sunabilmek için şu sağlayıcılarla çalışıyoruz:

| Sağlayıcı | Ne için | Ne gidiyor |
|---|---|---|
| **Supabase** | Barındırma ve veritabanı | Uygulamadaki tüm verileriniz |
| **OpenAI** (ABD) | Soru okuma + içerik güvenliği | Soru fotoğrafları, kimliksiz |
| **Google / Firebase** (ABD) | Bildirim iletimi | Cihaz bildirim kimliği ve bildirim metni. Bildirimde **size soru gönderen kişinin takma adı** yer alır; sorunun kendisi veya fotoğraf gitmez |
| **Sentry** | Hata izleme | Hata kayıtları. Kullanıcı kimliğiniz ve e-postanız **gönderilmeden önce silinir**; ekran görüntüsü hiç alınmaz |
| **Google (AdMob)** (ABD) | Reklam gösterimi | IP adresiniz ve cihazınızın kaba teknik bilgisi. **Kimliğiniz, e-postanız, fotoğraflarınız ve çalışma verileriniz GİTMEZ**; reklam kimliğiniz okunmaz ve reklamlar kişiselleştirilmez |

İlk dördü bizim adımıza ve talimatımızla çalışan hizmet sağlayıcılarıdır.
**AdMob bundan farklı:** Google, reklam gösterirken gördüğü teknik veriyi
kendi reklam sistemi için de işleyebilir.

Ayrıca yasal olarak zorunlu olduğumuz hâllerde yetkili makamlara bilgi
verebiliriz.

**Ödüllü reklam nasıl çalışıyor:** analiz hakkınız bittiğinde, isterseniz kısa
bir reklam izleyip bir hak kazanabilirsiniz (günde en fazla 3). **İzlemek
zorunda değilsiniz** — izlemezseniz hiçbir özellik kapanmaz: soruyu kaydedip
şıklarını kendiniz girebilir, tekrarlarınıza aynı şekilde devam edebilirsiniz.
Reklamı gerçekten izlediğinizi Google'ın sunucusu bize bildiriyor; bu
bildirimde **sizi tanıtan hiçbir bilgi yok**, yalnızca o reklam için
ürettiğimiz tek kullanımlık bir numara var.

**Yurt dışı:** Bu sağlayıcıların tamamı Türkiye dışında bulunuyor, yani
verileriniz yurt dışına aktarılıyor. Aktarımlar, KVKK Aydınlatma Metni'nde
açıklanan hukuki dayanaklara göre yapılır: [KVKK aydınlatma metni URL'i].

### 7. Verileriniz ne kadar kalıyor?

- **Hesabınız ve içeriğiniz:** siz silene kadar. Otomatik bir süre sınırı yok.
- **Kayıt olmadan denediyseniz:** 7 gün sonra otomatik silinir.
- **İhlal ve kısıtlama kayıtları:** hesabınızı silene kadar. Otomatik kısıtlama
  kararı verilirken yalnızca **son 180 gün** dikkate alınır.
- **Fotoğraflara verilen geçici erişim adresleri:** 10 dakika.
- **Hata kayıtları:** [Sentry saklama süresi].

### 8. Silme

Hesabınızı **uygulama içinden** silebilirsiniz: Ayarlar → Hesabımı sil.
Bekleme süresi yoktur ve işlem geri alınamaz. Fotoğraflarınız, sorularınız,
ilerlemeniz, arkadaşlıklarınız, gönderdiğiniz sorular, onay kayıtlarınız ve
bildirim kaydınız silinir.

Uygulamayı kaldırdıysanız veya uygulamaya erişemiyorsanız silme talebinizi
[hesap silme sayfası URL'i] üzerinden veya [iletişim e-postası] adresine
yazarak iletebilirsiniz.

**Silmeden sonra geri alınamayacaklar** (dürüst olmak adına): daha önce OpenAI'a
gönderilmiş fotoğraflar, gönderilmiş bildirimler, bir arkadaşınıza gönderdiğiniz
sorunun onun tarafında kalan kaydı ve kimliğinizle ilişkilendirilmemiş teknik
hata kayıtları.

Ayrıca gelen kutunuzda bir soruyu "sil" dediğinizde o soru sizden gizlenir ama
gönderenin kaydı ve moderasyon izi korunur.

**Tek bir soruyu silmek:** Uygulama içinde mevcut. Sorunun kartındaki sil
eylemi soruyu ve fotoğrafını birlikte kaldırır — fotoğraf depodan da gerçekten
silinir, yalnızca listeden kaybolmaz.

### 9. Çocuklar

**Uygulama 13 yaş ve üzeri içindir. 13 yaşından küçükler kullanamaz** ve bu
sınır kayıt sırasında teknik olarak uygulanır: 13 yaşından küçük bir doğum yılı
girildiğinde kayıt tamamlanmaz.

13–18 yaş arasındaki kullanıcılar uygulamanın tüm özelliklerini kullanabilir.
Arkadaş eklemenin tek yolu 6 haneli arkadaş kodudur; kimse kimseyi takma adıyla
arayıp bulamaz. Yüklenen her fotoğraf otomatik olarak taranır ve uygunsuz
bulunan bir fotoğraf paylaşıma çıkamaz.

**Veli onayı mekanizması yoktur.** Daha önceki sürümlerde 18 altı kullanıcılarda
arkadaş ekleme veli onayına bağlanmıştı; bundan vazgeçildi. Ayrıntılı gerekçe
KVKK Aydınlatma Metni §8'de: [KVKK aydınlatma metni URL'i].

**Veliler:** çocuğunuzun verileri hakkında bilgi almak, bir içeriğin
kaldırılmasını ya da hesabın silinmesini istemek için [iletişim e-postası]
adresine yazın.

### 10. Güvenlik

Fotoğraflarınız herkese kapalı depolama alanlarında tutulur; erişim yalnızca
10 dakika geçerli imzalı adreslerle olur. Veritabanında satır düzeyinde güvenlik
kuralları uygulanır. XP, seri ve doğru cevap gibi kritik değerleri sunucu
belirler. Onay kayıtları değiştirilemeyen bir deftere yazılır. Tüm trafik
şifreli bağlantı üzerinden geçer.

Hiçbir sistem %100 güvenli değildir. Bir ihlal yaşanırsa mevzuatın öngördüğü
şekilde bildirim yaparız.

### 11. Haklarınız

Nerede olursanız olun şunları talep edebilirsiniz: verilerinize erişmek,
düzeltilmesini istemek, silinmesini istemek, işlenmesine itiraz etmek, verdiğiniz
onayı geri almak ve bir kopyasını istemek.

**Türkiye'deki kullanıcılar (KVKK):** KVKK Md. 11 kapsamındaki haklarınızın tam
listesi ve başvuru usulü için: [KVKK aydınlatma metni URL'i]. Başvurularınızı
en geç 30 gün içinde sonuçlandırırız. Cevabımızı yetersiz bulursanız Kişisel
Verileri Koruma Kurulu'na şikâyette bulunabilirsiniz.

**Avrupa Birliği / AEA ve Birleşik Krallık'taki kullanıcılar (GDPR / UK GDPR):**

| Konu | Karşılığı |
|---|---|
| Hukuki dayanaklarımız | Sözleşmenin ifası (Md. 6/1-b): hesap, içerik saklama, arkadaş özellikleri · Meşru menfaat (Md. 6/1-f): içerik moderasyonu, güvenlik, hata izleme, çocuk koruma · Açık rıza (Md. 6/1-a): soru fotoğrafının yapay zekâ ile okunması · Hukuki yükümlülük (Md. 6/1-c) |
| Haklarınız | Erişim (Md. 15), düzeltme (16), silme (17), işlemenin kısıtlanması (18), veri taşınabilirliği (20), itiraz (21), rızayı geri alma (7/3) |
| Uluslararası aktarım | Verileriniz Türkiye'ye ve ABD'ye aktarılır. Bu aktarımlar için Avrupa Komisyonu'nun Standart Sözleşme Hükümleri'ne (SCC) ve ilgili ek önlemlere dayanıyoruz: [SCC durumu doldurulacak] |
| Özel nitelikli veri | İşlemiyoruz (Md. 9) |
| Otomatik karar verme | Hukuki sonuç doğuran otomatik karar verme yapmıyoruz. Yapay zekâ yalnızca sorunuzu okur ve sınıflandırır; sonucu onaylamadan kaydedilmez |
| Çocuklar | Uygulama 13 yaş altına yönelik değildir ve bu sınır teknik olarak uygulanır. Md. 8 kapsamında bulunduğunuz ülkenin belirlediği bilgi toplumu hizmeti yaş sınırı 13'ten yüksekse (bazı AB ülkelerinde 16'ya kadar çıkabilir), o sınırın altındaki kullanıcılar için veli izni gerekir; böyle bir durumda [iletişim e-postası] adresine yazın |
| Şikâyet | Bulunduğunuz ülkedeki veri koruma otoritesine şikâyette bulunabilirsiniz |

Talepleriniz için: [iletişim e-postası]

### 12. Bu politika değişirse

Güncellemeleri bu sayfada yayınlar ve uygulama içinde duyururuz. Önemli bir
değişiklikte (yeni bir sağlayıcı veya yeni bir aktarım gibi) sizi ayrıca
bilgilendiririz. Sayfanın en üstündeki tarih son güncelleme tarihidir.

### 13. İletişim

[şirket unvanı]
[açık adres]
[iletişim e-postası]

---

# 6. Kullanım Koşulları

> **Bu bölüm yayına hazır metindir.** Operatörü korumak üzere yazıldı, ancak
> Türk tüketici hukukunda geçersiz sayılacak maddelerden bilinçli olarak
> kaçınıldı — geçersiz bir madde koruma sağlamaz, yalnızca belgenin
> güvenilirliğini düşürür. Bu tercihler §7'de tek tek gerekçelendirildi.

---

## Kimo Kullanım Koşulları

**Yürürlük tarihi:** [tarih] · **Sürüm:** 1.2

### 1. Bu sözleşme kim ile kim arasında?

Bu koşullar, Kimo uygulamasını işleten **[şirket unvanı]**
("biz", "Şirket") ile uygulamayı kullanan siz ("kullanıcı", "siz") arasındaki
sözleşmedir.

Uygulamayı indirip hesap açtığınızda bu koşulları kabul etmiş olursunuz.
Kabul etmiyorsanız uygulamayı kullanmayın.

Uygulamayı Apple App Store veya Google Play üzerinden edindiyseniz, ilgili
mağazanın kendi koşulları da geçerlidir. Bu sözleşme sizinle bizim aramızdadır;
**Apple ve Google bu sözleşmenin tarafı değildir** ve uygulamadan doğan
taleplerinizin muhatabı biziz.

### 2. Uygulama ne yapıyor?

Kimo, YKS'ye hazırlanan öğrenciler için bir çalışma uygulamasıdır.
Kısaca:

- Yanlış yaptığınız soruyu fotoğraflarsınız.
- Yapay zekâ destekli bir sistem fotoğraftaki soruyu okumaya, şıklarını
  çıkarmaya ve doğru derse/konuya yerleştirmeye çalışır.
- Soru hata bankanıza kaydedilir ve aralıklı tekrar yöntemiyle zaman içinde
  tekrar tekrar karşınıza çıkar.
- XP, seri, lig ve arkadaşlarla soru paylaşma gibi oyunlaştırma özellikleri
  çalışma alışkanlığınızı desteklemek içindir.

**Uygulama bir öğretmen, özel ders veya danışmanlık hizmeti değildir.**

### 3. Kimler kullanabilir?

- Uygulamayı **13 yaşından küçükler kullanamaz.** Kayıt sırasında doğum
  yılınızı soruyoruz ve bu sınırı teknik olarak uyguluyoruz: 13 yaşından küçük
  bir doğum yılı girildiğinde kayıt tamamlanmaz.
- Doğum yılınız **bir kez yazılır** ve sonradan değiştirilemez. Yanlış
  girdiyseniz [iletişim e-postası] adresine yazın.
- **18 yaşından küçükseniz**, uygulamayı kullanmadan önce veliniz veya yasal
  temsilcinizle konuşmanızı bekliyoruz. Bu sözleşme, 18 yaşından küçük
  kullanıcılar bakımından velinin bilgisi ve izniyle kurulmuş sayılır.
- Uygulamayı kullanabilmek için kayıt adımında **bu Koşulları ve Gizlilik
  Politikası'nı kabul etmeniz gerekir.** Kabulünüz, kabul ettiğiniz metnin
  sürümüyle birlikte kaydedilir.
- Hesabınız daha önce bu koşulların ihlali nedeniyle kapatıldıysa yeni hesap
  açamazsınız.

**Veliler için:** Çocuğunuzun hesabı, verileri veya bu sözleşme hakkındaki her
konuda [iletişim e-postası] adresinden bize ulaşabilirsiniz. Hesabın silinmesini
isteme hakkınız her zaman saklıdır.

### 4. Hesabınız

- Verdiğiniz bilgilerin doğru olmasından siz sorumlusunuz.
- Şifrenizi gizli tutun ve kimseyle paylaşmayın. Hesabınızdan yapılan
  işlemlerden, hesabınızın izniniz dışında kullanıldığını bize bildirene kadar
  siz sorumlusunuz.
- Bir başkasının hesabını kullanamaz, başkası adına hesap açamazsınız.
- Hesabınızı istediğiniz zaman uygulama içinden silebilirsiniz.

### 5. Yüklediğiniz içerik ve taahhütleriniz

Uygulamaya yüklediğiniz fotoğraflar, notlar ve diğer içerikler **sizin
içeriğinizdir.** Bize devretmiyorsunuz.

İçerik yüklerken şunları taahhüt ediyorsunuz:

**a)** Yüklediğiniz içeriği paylaşma hakkına sahipsiniz.

**b)** Telif hakkı size ait olmayan materyalleri yüklemiyorsunuz. Bir yayınevinin
soru kitabından çektiğiniz sorunun telifi o yayınevine aittir; **kendi çalışma
arşiviniz için** kullanmak ile bunu başkalarına dağıtmak farklı şeylerdir. Bir
soruyu arkadaşınıza gönderirken bunu düşünün.

**c)** **Başkasının kişisel verisini paylaşmıyorsunuz.** Fotoğrafta bir
arkadaşınızın yüzü, adı, telefonu, notu veya sizin dışınızda birinin özel
bilgisi varsa o fotoğrafı yüklemeyin. Fotoğrafı çekmeden önce kadraja bakın.

**d)** İçeriğiniz üçüncü kişilerin haklarını, yürürlükteki mevzuatı ve bu
koşulları ihlal etmiyor.

**Fotoğraflarınız hakkında bilmeniz gereken:** Çektiğiniz fotoğraf, sorunun
okunması ve içerik güvenliği taraması için yurt dışındaki bir yapay zekâ
servisine gönderilir. Ayrıntılar Gizlilik Politikası'ndadır:
[gizlilik politikası URL'i].

### 6. Yasak kullanımlar — sıfır tolerans

**Uygunsuz içeriğe ve uygulamayı kötüye kullanan kullanıcılara sıfır tolerans
gösteriyoruz.** Aşağıdakiler kesinlikle yasaktır. Tespit edildiğinde içerik
kaldırılır; ağırlığına göre hesabınız **geçici olarak kısıtlanır veya kalıcı
olarak kapatılır** (nasıl işlediği için bkz. §7):

- Cinsel içerik; **çocukların cinsel istismarına ilişkin her türlü materyal**
- Şiddet, kendine zarar verme veya intiharı özendiren içerik
- Nefret söylemi, ayrımcılık, hakaret, tehdit
- **Taciz, zorbalık, ısrarlı rahatsız etme** — özellikle başka bir kullanıcıya
  yönelik
- Yasa dışı ürün veya faaliyetlerin tanıtımı
- Başkasının kişisel verilerinin veya özel görüntülerinin izinsiz paylaşılması
- Spam, reklam, dolandırıcılık, kimlik avı
- Bir başkasının kimliğine bürünmek
- Uygulamanın güvenlik önlemlerini aşmaya çalışmak, otomatik araçlarla veri
  çekmek, tersine mühendislik yapmak, sistemi aşırı yüklemek
- XP, seri, lig veya oyunlaştırma mekanizmalarını hile ile manipüle etmek
- Uygulamayı, yasa dışı bir amaçla ya da başkalarına zarar vermek için kullanmak

Çocukların cinsel istismarına ilişkin içerik tespit ettiğimizde, içeriği
kaldırmakla yetinmez, hesabı kapatır ve yetkili makamlara bildiririz.

### 7. Şikâyet, engelleme ve moderasyon

**Sizin elinizdekiler:**
- Size gönderilen her içeriği **şikâyet edebilirsiniz** — uygulama içinde,
  içeriğin yanındaki şikâyet seçeneğiyle.
- Bir kullanıcıyı **engelleyebilirsiniz.** Engellediğiniz kişi size soru veya
  arkadaşlık isteği gönderemez. Engellediğinizi karşı taraf öğrenmez.
- Şikâyet ettiğiniz içerik, incelemeyi beklemeden sizden hemen gizlenir.

**Bizim yaptıklarımız:**
- Yüklenen her fotoğraf, uygunsuz içeriğe karşı **otomatik olarak taranır.**
  Tarama tamamlanmamış veya şüpheli işaretlenmiş bir fotoğraf paylaşıma çıkamaz.
  Fotoğraf sizin arşivinizde kalmaya devam eder ve siz görebilirsiniz;
  engellenen yalnızca paylaşımdır.
- Şikâyetleri **makul bir süre içinde** inceler; gerekirse içeriği kaldırır,
  gizler veya hesabı kısıtlarız.
- Bir güvenlik incelemesi kapsamında, yetkili moderatörümüz içeriğinizi —
  paylaşmadığınız fotoğraflar dahil — görüntüleyebilir. Bu, uygulamayı reşit
  olmayan kullanıcılar için güvenli tutmanın karşılığıdır ve Gizlilik
  Politikası'nda açıkça anlatılmıştır.
- Bu koşulları ihlal eden içeriği **önceden bildirimde bulunmaksızın**
  kaldırma, gizleme veya hesabı kısıtlama hakkımız saklıdır. Ciddi olmayan
  ihlallerde önce uyarmayı tercih ederiz.

**Uygunsuz içerikte kademeli yaptırım.** Otomatik tarama bir fotoğrafınızı
uygunsuz bulursa şu sıra işler:

| Tespit | Ne oluyor |
|---|---|
| **Birinci** | Fotoğraf paylaşıma çıkmaz; size uygulama içinde bildirilir |
| **İkinci** | Aynı sonuç, uyarı daha açık; ihlal kaydedilir |
| **Üçüncü** | Hesabınız **7 gün** boyunca kısıtlanır ve durum yönetici incelemesine düşer |
| Kısıtlama bittikten sonra yeni bir ihlal | Hesabınız **kalıcı olarak kapatılır** |

Bu sayım **son 180 günü** kapsar; daha eski tespitler otomatik karara dâhil
edilmez. Bir tespitin hatalı olduğu anlaşılırsa (yanlış pozitif) kayıt geçersiz
kılınır ve buna bağlı kısıtlama kaldırılır.

**Kısıtlama neyi kapatır, neyi kapatmaz.** Kapanır: fotoğraf yükleme,
arkadaşınıza soru gönderme, arkadaş ekleme. **Açık kalır:** arşiviniz,
tekrarlarınız, liginiz, hesabınızı silme hakkınız ve bir kullanıcıyı engelleme
ya da şikâyet etme hakkınız. Amaç sizi uygulamadan atmak değil, başkasına
dokunmayı durdurmaktır.

**İtiraz.** Bir kararın hatalı olduğunu düşünüyorsanız [iletişim e-postası]
adresine yazarak itiraz edebilirsiniz; uygulama içindeki kısıtlama ekranı da
sizi doğrudan bu adrese yönlendirir. İtirazınızı bir insan değerlendirir.

Şikâyet mekanizmasını kötüye kullanmayın: dayanaksız şikâyetleri tekrarlayan
kullanıcıların şikâyetleri dikkate alınmayabilir.

### 8. Fikri mülkiyet

**Bize ait olanlar:** Uygulamanın kendisi, tasarımı, arayüzü, logosu, adı,
maskotları, metinleri, sesleri, kaynak kodu ve altyapısı [şirket unvanı]'na
aittir ve fikri mülkiyet mevzuatıyla korunur. Size, uygulamayı bu koşullara
uygun olarak kişisel ve ticari olmayan amaçlarla kullanmanız için
**devredilemez, münhasır olmayan, geri alınabilir bir kullanım hakkı**
tanıyoruz. Bunun dışında hiçbir hak devredilmiş sayılmaz.

**Size ait olanlar:** Yüklediğiniz içeriğin hakları sizde kalır. Bize
verdiğiniz izin **yalnızca hizmeti sunabilmemiz için gereken kadardır:**

- İçeriğinizi sunucularımızda saklamak ve size göstermek,
- Teknik olarak işlemek (boyutlandırma, format dönüştürme, güvenli saklama),
- Bir soruyu gönderdiğinizde yalnızca **seçtiğiniz kişiye** iletmek,
- İçerik güvenliği taramasından geçirmek ve bir şikâyet hâlinde incelemek,
- Yedekleme ve sistem güvenliği amacıyla kopyalamak.

Bu izin **ücretsizdir, dünya çapında geçerlidir ve yalnızca yukarıdaki
amaçlarla sınırlıdır.** İçeriğinizi reklamda, tanıtımda veya yapay zekâ
modellerinin eğitiminde kullanmıyoruz ve üçüncü kişilere satmıyoruz.

İçeriğinizi veya hesabınızı sildiğinizde bu izin sona erer. Yedekleme
sistemlerindeki kopyalar teknik olarak mümkün olan en kısa sürede silinir;
daha önce arkadaşınıza ilettiğiniz bir içerik onun tarafında kalabilir.

### 9. Telif hakkı ihlali bildirimi (uyar–kaldır)

Uygulamada, hakkınızı ihlal ettiğini düşündüğünüz bir içerik varsa bize bildirin.

**Bildiriminizi [telif bildirim e-postası] adresine gönderin ve şunları
ekleyin:**

1. Ad, soyad / unvan ve iletişim bilgileriniz
2. Hak sahibi olduğunuzu gösteren bilgi veya belgeler
3. İhlal edildiğini düşündüğünüz eserin tanımı
4. İhlalin uygulamada nerede olduğu (ekran görüntüsü, kullanıcı adı, tarih —
   bulmamıza yetecek kadar bilgi)
5. Bildirimdeki bilgilerin doğru olduğuna dair beyanınız
6. İmzanız (elektronik imza kabul edilir)

**Süreç:** Bildiriminizi aldıktan sonra en kısa sürede değerlendirir ve haklı
bulduğumuz hâlde içeriği kaldırır veya erişime kapatırız. İçeriği yükleyen
kullanıcıyı durumdan haberdar eder ve kendisine itiraz imkânı tanırız. İtiraz
haklı bulunursa içerik geri getirilebilir. 5846 sayılı Fikir ve Sanat Eserleri
Kanunu ve 5651 sayılı Kanun'daki başvuru yolları saklıdır.

**Karşı bildirim:** İçeriğiniz hatalı bir bildirim üzerine kaldırıldıysa aynı
adrese yazarak itiraz edebilirsiniz.

**Tekrarlayan ihlalci politikası:** Hakkında birden fazla haklı telif bildirimi
gelen kullanıcıları uyarırız. İhlal tekrarlanırsa hesap kalıcı olarak kapatılır.

**Kötüniyetli bildirimler:** Gerçeğe aykırı bildirimde bulunanlar bundan doğan
zararlardan sorumludur.

### 10. Neyi garanti etmiyoruz

Bu bölümü dikkatle okuyun; uygulamadan ne beklemeniz gerektiğini anlatıyor.

- **Uygulama size sınav başarısı, puan artışı veya sıralama vaat etmez.**
  Hiçbir sonuç garantisi vermiyoruz. Çalışmanın sonucu birçok etkene bağlıdır
  ve bunların büyük kısmı bizim kontrolümüzde değildir.
- **Yapay zekâ hata yapabilir.** Fotoğraftan çıkarılan soru metni, şıklar,
  işaretlenen doğru cevap, ders ve konu ataması **yanlış olabilir.** Kaydetmeden
  önce sonucu kontrol etmek sizin sorumluluğunuzdadır; uygulama bunun için bir
  onay ekranı gösterir. **Uygulamanın çıktısına dayanarak yanlış öğrendiğiniz
  bir bilgiden sorumlu değiliz.**
- Uygulamadaki soru içerikleri, konu ağacı ve müfredat eşlemeleri hatalı veya
  güncel olmayan bilgiler içerebilir. Resmî kaynak değildir; ÖSYM'nin veya Millî
  Eğitim Bakanlığı'nın yayınlarının yerine geçmez.
- **Uygulamanın kesintisiz veya hatasız çalışacağını garanti etmiyoruz.**
  Bakım, güncelleme, altyapı sağlayıcılarımızdan kaynaklanan sorunlar veya
  teknik arızalar nedeniyle hizmet geçici olarak durabilir.
- Uygulama "olduğu gibi" sunulmaktadır. Mevzuatın izin verdiği ölçüde, açık veya
  zımni başka bir garanti vermiyoruz.
- **Verilerinizi yedeklemek sizin sorumluluğunuzdadır** demiyoruz — verilerinizi
  korumak için makul özeni gösteriyoruz. Ancak teknik bir arıza sonucu veri
  kaybı ihtimalini de tümüyle ortadan kaldıramayız.
- Diğer kullanıcıların davranışlarından ve yükledikleri içerikten sorumlu
  değiliz. Size rahatsızlık veren bir kullanıcıyı engelleyin ve bize bildirin.

### 11. Sorumluluğumuzun sınırı

Mevzuatın izin verdiği en geniş ölçüde:

- Dolaylı zararlardan, kâr kaybından, veri kaybından, itibar kaybından veya
  sınav sonucunuza ilişkin beklentilerinizin karşılanmamasından sorumlu
  değiliz.
- Uygulamanın kullanımından doğan toplam sorumluluğumuz, ilgili talep tarihinden
  önceki 12 ay içinde bize ödediğiniz tutarla sınırlıdır. Uygulama şu anda
  ücretsiz olduğu için bu tutar sıfırdır.

**Bu sınırlamaların istisnaları:** Yukarıdaki sınırlamalar **kastımızdan veya
ağır ihmalimizden doğan zararlarda, ölüm ve bedensel zararlarda ve mevzuatın
sınırlandırılmasına izin vermediği diğer hâllerde uygulanmaz.** Tüketici
mevzuatından doğan haklarınız saklıdır ve bu sözleşmeyle sınırlandırılamaz.

### 12. Tazmin

Bu koşulları ihlal etmeniz veya yüklediğiniz içerik nedeniyle üçüncü bir kişi
bize karşı bir talepte bulunursa (örneğin telif hakkı sahibi veya fotoğrafta yer
alan bir kişi), bu talepten doğan **doğrudan zararlarımızı ve makul avukatlık
giderlerimizi** karşılamayı kabul edersiniz.

Bu yükümlülük, **bizim kendi kusurumuzdan kaynaklanan talepleri kapsamaz.**
18 yaşından küçük kullanıcılar bakımından bu madde, genel hükümler çerçevesinde
veli veya yasal temsilcinin sorumluluğu saklı kalmak üzere uygulanır.

### 13. Reklamlar ve ücretli hizmetler

**Uygulama ücretsizdir ve reklamla desteklenir. Uygulama içi satın alma,
abonelik veya başka bir ödeme ŞU AN YOKTUR.**

**Reklamlar.** Uygulamada tek bir reklam biçimi var: **ödüllü reklam.**
Kendiliğinden açılan tam ekran reklam, şerit (banner) reklam ya da açılış
reklamı yok ve eklemeyi planlamıyoruz.

- Reklamı **yalnızca siz istediğinizde** gösteririz: analiz hakkınız
  bittiğinde, "reklam izle" seçeneğine dokunursanız. Günde en fazla 3.
- Bir reklam izlemek **bir analiz hakkı** kazandırır.
- **İzlemek zorunda değilsiniz ve izlemezseniz hiçbir özellik kapanmaz.**
  Soruyu kaydedip şıklarını kendiniz girebilir, tekrarlarınıza aynı şekilde
  devam edebilirsiniz. Bu, uygulamanın değişmez kuralı.
- Reklamlar **kişiselleştirilmez**: cihazınızın reklam kimliği okunmaz ve bize
  verdiğiniz bilgiler reklam için kullanılmaz. Ayrıntı Gizlilik Politikası §6.
- Reklam içeriği Google'ın reklam ağından gelir; **içeriği biz seçmiyoruz.**
  Yaş grubunuza uygun olması için ağın en kısıtlı içerik derecesini ve ergen
  muamelesi ayarını kullanıyoruz. Yine de uygunsuz bir reklam görürseniz
  [iletişim e-postası] adresine yazın — ağ tarafında engelleyebiliriz.

**Kimo Plus.** Uygulamada daha yüksek analiz hakkı sunan bir **Plus tanıtım
ekranı** bulunuyor. **Satın alma henüz açık değildir**; ekrandaki düğme devre
dışıdır ve hiçbir ücret tahsil edilmez. Satın alma açıldığında aşağıdaki
kurallar geçerli olacak ve sizi ayrıca bilgilendireceğiz:

- **[Fiyatlandırma]** Ücretler, özellikler ve varsa deneme süresi satın alma
  ekranında açıkça gösterilir. Fiyatlar KDV dahil olarak belirtilir.
- **[Ödeme]** Satın almalar Apple App Store veya Google Play üzerinden yapılır;
  ödeme, iade ve fatura süreçleri ilgili mağazanın kurallarına tabidir.
- **[Yenileme]** Abonelikler, siz iptal etmediğiniz sürece dönem sonunda
  otomatik olarak yenilenir. İptali cihazınızın mağaza hesabı ayarlarından
  yapabilirsiniz.
- **[Cayma hakkı]** Mesafeli Sözleşmeler Yönetmeliği kapsamında, elektronik
  ortamda anında ifa edilen hizmetlerde cayma hakkına ilişkin istisnalar
  saklıdır; bu husus satın alma öncesi ayrıca bildirilir.
- **[18 yaş altı]** Uygulamada veli onayı mekanizması bulunmadığından, 18
  yaşından küçük kullanıcıların satın alma yapması velinin bilgisi ve izniyle
  yapılmış sayılır. Velilere, cihaz düzeyinde (App Store / Google Play) satın
  alma kısıtlaması kurmalarını öneririz.
- **[Ücretsiz özelliklerin korunması]** Ücretli bir katman gelmesi, o güne
  kadar ücretsiz sunduğumuz temel özellikleri kendiliğinden ücretli hâle
  getirmez; böyle bir değişiklik olursa önceden duyurulur. **Soru kaydetme ve
  tekrar yapma her zaman ücretsiz kalır.**
- **[Reklamsız kullanım]** Plus, ödüllü reklam teklifini kaldırır. Ücretsiz
  katmanda da reklam izlemek hiçbir zaman zorunlu değildir.
- **[Fesih hâlinde]** Hesabınız bu koşulları ihlal ettiğiniz için kapatılırsa
  kullanılmamış dönem için iade yapılmayabilir; iade talepleri ilgili mağazanın
  kurallarına göre değerlendirilir.

### 14. Hesabın kapatılması ve fesih

**Siz:** Hesabınızı istediğiniz zaman, sebep göstermeden, uygulama içinden
silebilirsiniz (Ayarlar → Hesabımı sil). Bekleme süresi yoktur; işlem geri
alınamaz.

**Biz:** Bu koşulları ihlal etmeniz hâlinde hesabınızı **geçici olarak
kısıtlayabilir veya kalıcı olarak kapatabiliriz** (§7'deki kademeli yaptırım).
Ciddi olmayan ihlallerde önce uyarırız; ağır ihlallerde (çocuk istismarı
içeriği, taciz, yasa dışı faaliyet, güvenlik saldırısı) doğrudan kapatırız.
Hesabınız kısıtlandığında uygulamayı açtığınızda **ne olduğunu, ne zamana kadar
sürdüğünü ve nasıl itiraz edebileceğinizi** gösteren bir ekran görürsünüz.
Güvenlik veya hukuki bir engel yoksa gerekçeyi de bildiririz.

Ayrıca hizmeti tamamen sonlandırmaya karar verirsek, verilerinizi
indirebilmeniz veya alternatif bulabilmeniz için **makul bir süre önceden
haber veririz.**

Hesabınız kapandığında içeriğiniz ve verileriniz Gizlilik Politikası'nda
anlatıldığı şekilde silinir.

### 15. Koşullarda değişiklik

Bu koşulları zaman zaman güncelleyebiliriz. Önemli bir değişiklik olduğunda
uygulama içinde bildirim yaparız ve yürürlük tarihinden önce makul bir süre
tanırız. Değişiklikten sonra uygulamayı kullanmaya devam etmeniz, yeni
koşulları kabul ettiğiniz anlamına gelir. Kabul etmiyorsanız hesabınızı
silebilirsiniz.

Aleyhinize olan değişiklikler geçmişe etkili uygulanmaz.

### 16. Uygulanacak hukuk ve uyuşmazlıkların çözümü

Bu sözleşmeye **Türk hukuku** uygulanır.

**Tüketici iseniz** (uygulamayı ticari veya mesleki olmayan amaçlarla
kullanıyorsanız): 6502 sayılı Tüketicinin Korunması Hakkında Kanun'dan doğan
haklarınız saklıdır. Uyuşmazlıklarınızı **kendi yerleşim yerinizdeki** Tüketici
Hakem Heyeti'ne veya Tüketici Mahkemesi'ne taşıyabilirsiniz; bu sözleşme sizi
başka bir yerdeki mahkemeye gitmeye zorlamaz.

**Tüketici değilseniz:** [yetkili mahkeme ve icra daireleri] yetkilidir.

Bize ulaşmayı denemeden dava açmak zorunda değilsiniz — ama çoğu sorun
[iletişim e-postası] adresine yazınca daha hızlı çözülüyor.

Bu sözleşmenin bir maddesi geçersiz sayılırsa diğer maddeler yürürlükte kalır.

### 17. İletişim

[şirket unvanı]
[açık adres]
Genel: [iletişim e-postası]
Telif bildirimleri: [telif bildirim e-postası]
Gizlilik ve KVKK başvuruları: [iletişim e-postası]

---

# 7. Hukukçuya sorulacaklar

Emin olmadığım, iki seçenek sunduğum veya karar gerektiren noktalar. Metinleri
bu belirsizliklere rağmen tamamladım — her birinde daha koruyucu olan varsayımı
seçtim ve seçimi burada açıkça yazdım.

## 7.1 Karar gerektirenler

### Soru 1 — Yurt dışına aktarımın hukuki dayanağı

**Durum:** Soru fotoğrafları OpenAI'a (ABD) iki ayrı akışta gidiyor. Birincisi
kullanıcının açık rızasıyla, ikincisi (zorunlu moderasyon taraması) rızasız.

**Seçenek 1 — Standart sözleşme (KVKK Md. 9/3-b/3).** Kurul'un ilan ettiği
standart sözleşme sağlayıcılarla imzalanır, 5 iş günü içinde Kurul'a bildirilir.
*Daha koruyucu.* Aktarımı rızanın kırılganlığından kurtarır; kullanıcı rızasını
geri alsa bile güvenlik taraması hukuken ayakta kalır. Sürekli aktarım için
doğru araç. Maliyeti: sağlayıcıyı imzaya ikna etmek ve bildirim yükümlülüğü.

**Seçenek 2 — Açık rıza (Md. 9/6-a).** Uygulamanın bugün yaptığı. *Daha hızlı,
hemen uygulanabilir.* Ama Md. 9/6 istisnaları **"arızi olmak"** kaydına bağlı;
her fotoğrafta çalışan sistematik bir aktarımın arızi sayılması tartışmalı.

**Benim yaptığım:** Metinleri ikili yapıya göre yazdım — bugün açık rıza,
hedef standart sözleşme. **Sorum:** Bu geçiş yapısı savunulabilir mi, yoksa
yayın öncesi standart sözleşmenin tamamlanması mı gerekir?

---

### Soru 2 — Zorunlu moderasyon taramasının dayanağı

**Durum:** Kaydedilen her fotoğraf, kullanıcı istese de istemese de OpenAI'ın
içerik denetimi servisine gönderiliyor. Buna açık rıza dayanağı **uymuyor**:
rızasını geri alan kullanıcının fotoğrafı da taranıyor.

**Metinde ne yazdım:** İşleme dayanağı olarak meşru menfaat (Md. 5/2-f), aktarım
dayanağı olarak Soru 1'deki yapı.

**Sorum:** Reşit olmayan kullanıcıların birbirine içerik gönderdiği bir
platformda zorunlu içerik taraması için meşru menfaat yeterli mi? 5651 sayılı
Kanun'dan doğan yükümlülükler bunu **hukuki yükümlülük** (Md. 5/2-ç)
dayanağına taşır mı? Meşru menfaat dayanağı için ayrıca bir denge testi
belgesi hazırlanmalı mı?

---

### Soru 3 — Veli onayı — ✅ **KONUSUZ KALDI (Task 07)**

**Durum:** Bu soru, 18 yaşından küçük kullanıcılarda arkadaş eklemeyi veli
onayına bağlayan mekanizma için sorulmuştu. **Mekanizma tümüyle kaldırıldı** ve
uygulama 13+ olarak konumlandı; soru bu hâliyle konusuz kaldı.

**Kararın gerekçesi (kayda geçsin diye):**
- 13–17 yaş için veli onayı yürürlükteki mevzuatta zorunlu tutulmuyor. COPPA 13
  altı için geçerli, KVKK'da çocuklara özel bir madde yok, Apple veli onayını
  Kids Category'de arıyor, Play Families 13 altını hedefleyen uygulamalar için.
- Sorunun kendisinde sayılan zayıflıklar giderilemezdi: **velinin kimliği
  hiçbir şekilde doğrulanamıyordu** (öğrenci kendi ikinci adresini girip kendi
  kendine onay verebilirdi), dolayısıyla mekanizma bir koruma değil bir
  **görüntü** üretiyordu.
- Mekanizma ayrıca **hiç çalışmamıştı** (bayrak A-1): bağlantıdaki parametre
  adı uyuşmadığı için bugüne kadar tek bir onay bile tamamlanmamıştı.

**Yerine ne kondu:** 13 yaş sınırının kodda zorlanması, zorunlu içerik
taraması, kod tabanlı (keşifsiz) arkadaşlık, engelleme/şikâyet ve kurallara
uymayan hesabın kısıtlanması.

**Hukukçuya kalan soru — daha dar:** 13–17 yaş grubuna veli onayı olmadan
hizmet sunmak, TMK'daki ayırt etme gücü / sınırlı ehliyetsizlik çerçevesinde
sözleşmenin kurulması bakımından bir sorun yaratır mı? Metinlerde
*"18 yaşından küçük kullanıcılar bakımından velinin bilgisi ve izniyle
kurulmuş sayılır"* ifadesi kullanıldı; bu ifade yeterli mi?

---

### Soru 4 — Onay metinlerinin sürümlenmesi — ✅ **TEKNİK KARŞILIĞI YAZILDI**

**Durum:** `user_consents` tablosuna `text_version` sütunu eklendi ve
`accept_legal_terms()` sürümü **sunucudan** (`app_config.legal_version`)
damgalıyor — istemci bildiremiyor. Sürüm değiştiğinde bir sonraki onay yeni bir
satır yazıyor; aynı sürüm ikinci kez yazılmıyor. Kullanım Koşulları ve Gizlilik
Politikası artık kayıt adımında ayrı ayrı deftere geçiyor (`terms`, `privacy`).

**Geçmiş kayıtlar:** `text_version` alanları **boş**. O gün bir sürüm
tutulmuyordu ve geriye dönük bir değer uydurmak, defterin tek işi olan
doğruluğu bozardı. Ortada dört kişilik iç test dışında kullanıcı yok.

**Hukukçuya kalan soru:** Metin sürümü değiştiğinde mevcut kullanıcılardan
**yeniden onay** alınması gerekir mi, yoksa "değişikliği duyurup kullanmaya
devam etmeyi kabul saymak" (§6 Md. 15) yeterli mi? Yeniden onay gerekiyorsa,
uygulama içinde bunu tetikleyecek bir akış yazılmalı — bugün yok.

---

### Soru 5 — Moderatör erişimi ve denetim kaydı

**Durum:** Yetkili moderatör, kullanıcının hiç kimseyle paylaşmadığı soru
fotoğraflarını görüntüleyebiliyor ve **bu erişimin hiçbir kaydı tutulmuyor.**
Kim, ne zaman, hangi fotoğrafa baktı — bilinmiyor. Şikâyet kararlarında bile
kararı veren kişinin kimliği kaydedilmiyor.

**Metinde ne yazdım:** Erişimi hem KVKK metninde hem Gizlilik Politikası'nda
açıkça beyan ettim. Denetim kaydının olmadığını **yazmadım** — bu bir güvenlik
açığını ilan etmek olurdu.

**Sorum:** (a) Bu erişimin hukuki dayanağı olarak meşru menfaat yeterli mi?
(b) Reşit olmayan kullanıcıların içeriğine erişimde denetim kaydı (kim, ne
zaman, neden) tutmak hukuken zorunlu mu, yoksa iyi uygulama mı? Zorunluysa
yayın öncesi bir engel oluşturur.

---

### Soru 6 — Sorumluluk sınırlaması ve tazmin maddeleri

**Benim yaptığım tercihler ve gerekçeleri:**

| Madde | Ne yazdım | Neden böyle |
|---|---|---|
| Sorumluluk sınırı (§6 Md. 11) | Sınırlama var, ama **kast ve ağır ihmal, ölüm ve bedensel zarar** açıkça istisna tutuldu | TBK Md. 115 uyarınca kast ve ağır ihmalden sorumsuzluk anlaşması **kesin hükümsüz**. İstisnayı yazmasaydım maddenin tamamının geçersiz sayılma riski vardı |
| Tazmin (§6 Md. 12) | Yalnızca **doğrudan zarar ve makul avukatlık gideri**; kendi kusurumuz kapsam dışı; 18 altı için veli sorumluluğu saklı | Sınırsız tazmin taahhüdü, reşit olmayan bir tüketici karşısında haksız şart sayılır (TKHK Md. 5) ve uygulanamaz |
| Yetkili mahkeme (§6 Md. 16) | Tüketici için **kendi yerleşim yeri**; yalnızca tüketici olmayanlar için `[yetkili mahkeme]` | HMK Md. 17-18 uyarınca yetki sözleşmesi yalnızca tacirler arasında yapılabilir. "İstanbul mahkemeleri münhasıran yetkilidir" yazsaydım tüketici karşısında hükümsüz olurdu |
| Tek taraflı değişiklik (§6 Md. 15) | Önceden bildirim + fesih imkânı + geçmişe etkisizlik | Bildirimsiz tek taraflı değişiklik yetkisi haksız şart sayılır |

**Sorum:** Bu tercihler doğru mu? Daha koruyucu ama yine de uygulanabilir bir
formülasyon önerir misiniz? Özellikle 12. maddedeki tazmin yükümlülüğünün
18 yaşından küçük kullanıcılar bakımından pratik değeri konusunda görüşünüzü
istiyoruz.

---

## 7.2 Doğrulanması gereken hukuki sorular

**Soru 7 — Yer sağlayıcı statüsü.** Uygulama, 5651 sayılı Kanun anlamında
"yer sağlayıcı" mı? Öyleyse BTK'ya yer sağlayıcı faaliyet belgesi başvurusu ve
trafik bilgisi saklama yükümlülüğü doğar. Bu, uygulamanın saklama süreleri
tasarımını doğrudan etkiler — **şu an trafik/log kaydı hiç tutulmuyor.**

**Soru 8 — Uyar–kaldır prosedürü.** §6 Md. 9'da yazdığım süreç FSEK Ek Md. 4
ile uyumlu mu? Ek Md. 4'ün öngördüğü "önce içerik sağlayıcıya başvuru, 3 gün,
sonra servis sağlayıcı" sırasını metne aynen yansıtmalı mıyım, yoksa daha
pratik olan mevcut hâli yeterli mi?

**Soru 9 — Saklama ve imha politikası.** Metinde saklama süresini dürüstçe
"hesabınızı silene kadar" diye yazdım, çünkü kodda başka bir şey yok. KVKK'nın
"işlendikleri amaç için gerekli olan süre" ilkesi karşısında bu savunulabilir
mi? Ayrı bir **Kişisel Veri Saklama ve İmha Politikası** hazırlamamız gerekiyor
mu? Gerekiyorsa hangi veri için hangi süreyi önerirsiniz — bu, kod tarafında
otomatik silme işleri kurmayı gerektirir.

**Soru 10 — VERBİS.** [şirket unvanı] için VERBİS kayıt yükümlülüğü doğuyor mu?
Metinde bu alanı boş bıraktım.

**Soru 11 — Çocuklara yönelik ayrı bildirim.** Kullanıcı kitlesinin ağırlıkla
13–18 olduğu düşünüldüğünde, ayrıca sadeleştirilmiş bir "çocuk gizlilik
bildirimi" hazırlamak gerekir mi, yoksa mevcut metinlerin dili yeterli mi?

**Soru 12 — Aydınlatmanın yapılma anı.** Uygulama, kayıt olmadan anonim
oturumla başlıyor ve **ilk soru fotoğrafı yaş kapısından önce** çekiliyor.
Aydınlatma yükümlülüğünün ne zaman yerine getirilmiş sayılacağı, bu akışta
hangi ekranın aydınlatma anı olduğu konusunda görüşünüzü istiyoruz.

**Soru 13 — Tanıtım metinleriyle tutarlılık.** Kullanım Koşulları "sınav başarısı
vaat edilmez" diyor. Mağaza açıklamalarında ve tanıtımlarda "puanını yükselt",
"sıralamanı artır" gibi bir vaat kullanılırsa bu madde zayıflar ve reklam
mevzuatı açısından da sorun doğar. Tanıtım metinlerinin bu çerçevede
gözden geçirilmesini öneriyoruz.

---

## 7.3 Bilerek yazmadıklarım

Kodda karşılığı olmadığı için, istense de yazmadığım ifadeler:

| Yazılmayan ifade | Neden |
|---|---|
| "Fotoğraflarınızdan konum ve cihaz bilgileri (EXIF) temizlenir" | Temizleme kodu yok; yalnızca yeniden kodlamanın yan etkisi olabilir |
| "Fotoğrafınız yapay zekâ servisinde hiç saklanmaz" | Sıfır-saklama ayarı yok (bayrak A-5). Uygulama içindeki cümle de Task 07'de düzeltildi |
| "Şikâyetleri 24 saat içinde inceleriz" | Kodda bir süre taahhüdü yok; bilinçli olarak "makul süre" yazıldı |
| "Verileriniz Türkiye'de saklanır" | Supabase Türkiye'de bölge sunmuyor; barındırma ülkesi de teyit edilmedi |
| "Hesabınızı sildiğinizde tüm verileriniz her yerden silinir" | OpenAI'a gitmiş fotoğraflar, gönderilmiş bildirimler ve arkadaşın tarafındaki kayıt geri alınamıyor — metinde bunlar tek tek sayıldı |
| "İçeriğiniz hiçbir koşulda başkası tarafından görülmez" | Moderatör erişimi mevcut (bkz. §1.8) |
| "Uygulama tamamen güvenlidir" | Hiçbir sistem için doğru değil; metinde ihlal bildirimi taahhüdü verildi |

---

## 7.4 Yayın öncesi kontrol listesi

Bu belge tek başına yayına yetmez. Sıra:

1. ~~**Kod düzeltmeleri** — A-1, A-3, A-4, A-5, A-6, A-7~~ ✅ **Task 07'de
   yapıldı.** Kalanlar: A-2 (fotoğrafın yaş kapısından önce OpenAI'a gitmesi),
   A-8 (engel kaldırma arayüzü), A-9 (tek soru silme), A-10 (havuz altyapısı).
   Dördü de kapsam dışı bırakıldı; A-2 en kırılganı.
2. **Depo dışı doğrulamalar** — §2/C grubundaki kalemler (C-4 düştü).
   **C-2 hâlâ kritik:** OpenAI'ın veri işleme koşulları teyit edilmeden §4.5 ve
   §5.3'teki saklama cümlesi kesinleşmez.
3. **Hukukçu incelemesi** — bu bölümdeki sorular (3 ve 4 daraldı).
4. **Köşeli parantezlerin doldurulması** — şirket bilgileri, URL'ler, tarihler.
5. **Metinlerin yayınlanması** — Gizlilik Politikası, Kullanım Koşulları ve
   KVKK Aydınlatma Metni bir URL'de; **hesap silme sayfası** aynı sitede
   (metni `docs/hesap-silme-sayfasi.md`).
6. **Uygulama içi bağlantılar** — yer tutucu kaldırıldı; kalan iş dört adresi
   `supabase.json`'a girip yeniden derlemek:
   `LEGAL_TERMS_URL`, `LEGAL_PRIVACY_URL`, `LEGAL_KVKK_URL`,
   `LEGAL_DELETE_URL`, ayrıca itiraz için `SUPPORT_EMAIL`.
   **Adres girilmezse ilgili satır uygulamada hiç görünmez** — sessizce eksik
   kalır, hata vermez.
7. **`app_config.legal_version`** — yayınlanan metinlerin sürümü buraya
   yazılmalı (bu belgede `1.1`). **Atlanırsa onay kayıtları `1.0` damgalanır**
   ve sunucu günlüğüne uyarı yazılır; kayıt akışı durmaz.
8. **Mağaza formları** — §3'teki cevapların girilmesi. App Review notuna 1.2'nin
   dört şartının nerede karşılandığı yazılmalı.
9. **Son çapraz kontrol** — uygulama içi metinler, yayınlanan metinler ve mağaza
   formu cevaplarının üçünün birbiriyle çelişmediğinin doğrulanması.

---

*Bu belgenin 1.0 sürümü kod tabanının `5bbe43c` hâline dayanıyordu; 1.1 sürümü
Task 07 sonrası (`3f9c4ba`), 1.2 sürümü Task 09 sonrası (`2aa8d4a`) hâle göre
revize edildi. Kod değiştiğinde, özellikle §1 envanteri ve §3 form cevapları
yeniden gözden geçirilmelidir.*
