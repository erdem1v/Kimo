import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/daily_state_repository.dart';
import 'package:kimo/state/features.dart';

/// Uzaktan özellik bayrakları (göç 0079).
///
/// BU DOSYANIN KONUSU TEK BİR AYRIM: "sunucu kapattı" ile "sütun okunamadı"
/// aynı şey DEĞİL. İkisini birleştiren bir okuyucu (`row['ff_x'] == true`)
/// ağ hatasında riskli yüzeyleri sessizce kapatır — ya da tersine, yedeği
/// olmayan bir kill switch bırakır.
void main() {
  group('fromRow üç durumlu okuyor', () {
    test('sunucu true derse açık', () {
      final DailyState s = DailyState.fromRow(<String, dynamic>{
        'ff_pair_streak': true,
        'ff_multi_capture': true,
        'ff_ad_reward': true,
      });
      expect(s.ffPairStreak, isTrue);
      expect(s.pairStreakEnabled, isTrue);
      expect(s.multiCaptureEnabled, isTrue);
      expect(s.adRewardEnabled, isTrue);
    });

    test('sunucu false derse KAPALI — yedek ezilmiyor', () {
      final DailyState s = DailyState.fromRow(<String, dynamic>{
        'ff_pair_streak': false,
        'ff_multi_capture': false,
        'ff_ad_reward': false,
      });
      expect(s.ffMultiCapture, isFalse);
      // Yedekler açık olduğu hâlde sunucunun "false"u kazanıyor: kill switch
      // gerçekten kapatabiliyor.
      expect(Features.multiCaptureFallback, isTrue);
      expect(s.multiCaptureEnabled, isFalse);
      expect(s.adRewardEnabled, isFalse);
      expect(s.pairStreakEnabled, isFalse);
    });

    test('sütun HİÇ YOKSA null kalıyor ve yedeğe düşülüyor', () {
      final DailyState s = DailyState.fromRow(<String, dynamic>{});
      expect(s.ffPairStreak, isNull);
      expect(s.ffMultiCapture, isNull);
      expect(s.ffAdReward, isNull);
      expect(s.pairStreakEnabled, Features.pairStreakFallback);
      expect(s.multiCaptureEnabled, Features.multiCaptureFallback);
      expect(s.adRewardEnabled, Features.adRewardFallback);
    });

    test('sütun null gelirse de yedeğe düşülüyor, kapatmaya değil', () {
      final DailyState s = DailyState.fromRow(<String, dynamic>{
        'ff_pair_streak': null,
        'ff_multi_capture': null,
      });
      expect(s.ffPairStreak, isNull);
      expect(s.multiCaptureEnabled, isTrue,
          reason: 'null "kapalı" sayılırsa ağ hatası özelliği söndürür');
    });

    test('bool olmayan bir değer null sayılıyor', () {
      // Sunucu biçimi değişirse (ör. 'true' metni) istemci TAHMİN ETMİYOR.
      final DailyState s = DailyState.fromRow(<String, dynamic>{
        'ff_multi_capture': 'true',
        'ff_ad_reward': 1,
      });
      expect(s.ffMultiCapture, isNull);
      expect(s.ffAdReward, isNull);
    });
  });

  group('yedeklerin kendisi', () {
    test('ortak seri yedeği KAPALI — sunucu varsayılanıyla aynı', () {
      // 0079 `ff_pair_streak`i false tohumluyor; iki taraf ayrışırsa görünüm
      // okunamadığında kullanıcı sunucunun kapattığı bir yüzeyi görürdü.
      expect(Features.pairStreakFallback, isFalse);
    });

    test('elmas bayrağı bu paketten etkilenmedi', () {
      expect(Features.gemsVisible, isFalse);
    });
  });
}
