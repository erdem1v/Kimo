# Arşiv — soru havuzu ve konu haritası

Bu dizindeki kod **silinmedi, devre dışı bırakıldı**. Soru havuzu bu sürümde
üründen çıkarıldı; ileride elden geçirilip geri gelecek ve sıfırdan
tasarlanması istenmiyor.

## Neden burada

- `analysis_options.yaml` `lib/_archive/**` dizinini analizden hariç tutuyor,
  yani buradaki kod `flutter analyze` sonucunu etkilemiyor.
- Hiçbir canlı dosya buradan içe aktarma yapmıyor, dolayısıyla derlemeye de
  girmiyor (Dart yalnızca giriş noktasından erişilebilen kodu derler).
- İçe aktarmalar `package:ai_yks_coach/...` biçimine çevrildi; böylece dosyalar
  yerlerinden bağımsız çözümleniyor ve geri taşıma saf bir dosya taşımasına
  indi.

## İçerik

| Dosya | Eski yeri |
|---|---|
| `pool/solve_pool_screen.dart` | `lib/features/pool/solve_pool_screen.dart` |
| `pool/report_question_sheet.dart` | `lib/features/pool/report_question_sheet.dart` |
| `pool/public_question.dart` | `lib/models/public_question.dart` |
| `pool/pool_repository.dart` | `lib/data/question_pool_repository.dart` içindeki havuz yarısı |
| `map/curriculum_map_screen.dart` | `lib/features/map/curriculum_map_screen.dart` |

`lib/data/question_pool_repository.dart` ikiye ayrıldı:

- **arkadaşa gönderme** (`SendResult`, `sendToFriends`, `received`,
  `unsolvedCount`, `answerSentQuestion`, `report`, `AnswerResult`) →
  `lib/data/question_send_repository.dart` — **canlı, üründe duruyor**
- **havuz** (`fetchRandom`, `availableCounts`, `answerPoolQuestion`) →
  `pool/pool_repository.dart` — arşiv

İkisi aynı dosyada durduğu için "havuz kalkınca arkadaşa gönderme de kalkar"
sanılıyordu; ayrıldılar.

## Sunucu tarafı

**SQL'e dokunulmadı.** Havuza ait görünümler ve RPC'ler yerinde duruyor:
`public_questions`, `random_public_questions`, `random_questions_by_topic`,
`available_question_counts`, `submit_pool_answer`, `question_attempts`,
`mistakes.is_public`, `set_question_sharing`, `apply_question_report`.

İstemci çağırmadığı sürece zararsızlar ve şemayı bozmadan geri açılabilirler.
Bunları düşürmek `public_questions` görünümüne bağlı üç fonksiyonu da
düşüreceği için (bkz. göç `20260901001000`) bilerek yapılmadı.

**11.000 kurumsal soru** (MEB kazanım testleri, `mistakes.source <> 'user'`)
**silinmedi**; yalnızca erişim kesildi. Veriler, fotoğrafları ve sistem hesabı
(`profiles.is_system`, `app_config.osym_user_id`) olduğu gibi duruyor.
`tools/` altındaki içe aktarma aracı da değişmedi.

## Geri açma adımları

1. Dosyaları geri taşı:
   ```
   git mv lib/_archive/pool/solve_pool_screen.dart     lib/features/pool/solve_pool_screen.dart
   git mv lib/_archive/pool/report_question_sheet.dart lib/features/pool/report_question_sheet.dart
   git mv lib/_archive/pool/public_question.dart       lib/models/public_question.dart
   git mv lib/_archive/map/curriculum_map_screen.dart  lib/features/map/curriculum_map_screen.dart
   git mv lib/_archive/pool/pool_repository.dart       lib/data/pool_repository.dart
   ```
2. `analysis_options.yaml` içindeki `lib/_archive/**` satırını kaldır.
3. Bir giriş noktası bağla. Bugün hiçbir sekme havuza gitmiyor; tasarımda da
   "Kapsama/Harita" sekmesi yok. Yeni yeri ürün kararıdır.
4. Onayı geri getir: `lib/state/user_profile.dart` içindeki `shareConsent`
   defterden okunmaya devam ediyor ama artık **hiçbir yerde sorulmuyor**.
   Karşılama akışındaki onay adımı ve ayarlardaki anahtar kaldırıldı; havuz
   geri gelirse ikisi de geri gelmeli — aksi hâlde kullanıcıya sorulmadan
   paylaşım açılır.
5. `mistakeRepository.add(...)` çağrısında `isPublic` yeniden
   `userProfile.shareConsent` olmalı; şu an sabit `false`.

## Bilinmesi gereken

Bu dizin **çalışır kod garantisi vermiyor**. Analizden hariç tutulduğu için,
Task 02 boyunca değişen tasarım token'ları, yerelleştirme altyapısı ve bileşen
kütüphanesiyle uyumu bozulacak. Arşivin amacı ekran tasarımını ve iş
mantığını korumak — geri getirildiğinde yeniden temalanması gerekecek.
