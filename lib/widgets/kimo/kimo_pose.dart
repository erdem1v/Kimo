import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Kimo'nun bağlam ruh hâli. Tasarımın `mood` girdisi.
enum KimoMood {
  /// 0 — sakin. Varsayılan boşta hâli.
  calm,

  /// 1 — sevinçli.
  happy,

  /// 2 — düşünen.
  thinking,

  /// 3 — meraklı.
  curious,

  /// 4 — gece. 00:30 sonrası; nefes yavaşlar, gözler kapanır.
  night,
}

/// Tek seferlik tepkiler. Tetiklenir, bir kez oynar, boşta katmanına döner.
enum KimoReaction {
  /// Doğru cevap — 700 ms zıplama.
  correct,

  /// Yanlış cevap — 700 ms kafa eğme. Sarsıntı ve kırmızı yanıp sönme YOK;
  /// üzülmez, merak eder.
  wrong,

  /// Seri artışı — 900 ms baş sallama.
  streakUp,

  /// Günlük sandık — 1,2 sn. En büyük hareket; günde en fazla bir kez.
  chestOpen,

  /// Seviye atlama — 1 sn ölçek nabzı.
  levelUp,

  /// Dokunma — 250 ms eziliş. En sık tetiklenen.
  tap,
}

extension KimoReactionSpec on KimoReaction {
  /// Tasarımdaki süreler.
  Duration get duration => switch (this) {
        KimoReaction.correct => const Duration(milliseconds: 700),
        KimoReaction.wrong => const Duration(milliseconds: 700),
        KimoReaction.streakUp => const Duration(milliseconds: 900),
        KimoReaction.chestOpen => const Duration(milliseconds: 1200),
        KimoReaction.levelUp => const Duration(milliseconds: 1000),
        KimoReaction.tap => const Duration(milliseconds: 250),
      };

  /// Çakışma önceliği. Büyük olan kazanır; düşük öncelikli tetik **kuyruğa
  /// alınmaz, atılır** (tasarım kararı: kuyruk animasyonu klip gibi gösterir).
  int get priority => switch (this) {
        KimoReaction.levelUp => 5,
        KimoReaction.chestOpen => 4,
        KimoReaction.streakUp => 3,
        KimoReaction.correct => 2,
        KimoReaction.wrong => 2,
        KimoReaction.tap => 1,
      };
}

/// Ağız biçimi.
enum KimoMouth { smile, neutral, small, wide }

/// Göz biçimi.
enum KimoEyes { open, happyArc, closedArc }

/// Tek karelik poz. Boyayıcı yalnızca bunu okur; zaman mantığı [KimoPoseSolver]
/// içinde kalır ve saf fonksiyon olduğu için test edilebilir.
@immutable
class KimoPose {
  const KimoPose({
    this.bodyScaleX = 1,
    this.bodyScaleY = 1,
    this.bodyDy = 0,
    this.bodyRotation = 0,
    this.headRotation = 0,
    this.pupilDx = 0,
    this.pupilDy = 0,
    this.eyeOpen = 1,
    this.earLeftRotation = 0,
    this.earRightRotation = 0,
    this.mouth = KimoMouth.smile,
    this.eyes = KimoEyes.open,
    this.blush = false,
  });

  /// Gövde ölçeği. Nefes, eziliş ve zıplama bunu kullanır.
  final double bodyScaleX;
  final double bodyScaleY;

  /// Dikey kayma (piksel değil, 200 birimlik tasarım ızgarasında).
  final double bodyDy;

  /// Tüm gövdenin dönüşü (radyan) — yalnızca sandık animasyonunda.
  final double bodyRotation;

  /// Kafanın dönüşü (radyan). Gövde takip etmez.
  final double headRotation;

  /// Göz bebeklerinin kayması.
  final double pupilDx;
  final double pupilDy;

  /// 0 kapalı, 1 tam açık. Göz kırpma bunu kullanır.
  final double eyeOpen;

  final double earLeftRotation;
  final double earRightRotation;

  final KimoMouth mouth;
  final KimoEyes eyes;

  /// Yanaklar koyulaşır (doğru cevap ve kutlama).
  final bool blush;

  KimoPose copyWith({
    double? bodyScaleX,
    double? bodyScaleY,
    double? bodyDy,
    double? bodyRotation,
    double? headRotation,
    double? pupilDx,
    double? pupilDy,
    double? eyeOpen,
    double? earLeftRotation,
    double? earRightRotation,
    KimoMouth? mouth,
    KimoEyes? eyes,
    bool? blush,
  }) {
    return KimoPose(
      bodyScaleX: bodyScaleX ?? this.bodyScaleX,
      bodyScaleY: bodyScaleY ?? this.bodyScaleY,
      bodyDy: bodyDy ?? this.bodyDy,
      bodyRotation: bodyRotation ?? this.bodyRotation,
      headRotation: headRotation ?? this.headRotation,
      pupilDx: pupilDx ?? this.pupilDx,
      pupilDy: pupilDy ?? this.pupilDy,
      eyeOpen: eyeOpen ?? this.eyeOpen,
      earLeftRotation: earLeftRotation ?? this.earLeftRotation,
      earRightRotation: earRightRotation ?? this.earRightRotation,
      mouth: mouth ?? this.mouth,
      eyes: eyes ?? this.eyes,
      blush: blush ?? this.blush,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KimoPose &&
      other.bodyScaleX == bodyScaleX &&
      other.bodyScaleY == bodyScaleY &&
      other.bodyDy == bodyDy &&
      other.bodyRotation == bodyRotation &&
      other.headRotation == headRotation &&
      other.pupilDx == pupilDx &&
      other.pupilDy == pupilDy &&
      other.eyeOpen == eyeOpen &&
      other.earLeftRotation == earLeftRotation &&
      other.earRightRotation == earRightRotation &&
      other.mouth == mouth &&
      other.eyes == eyes &&
      other.blush == blush;

  @override
  int get hashCode => Object.hash(
        bodyScaleX,
        bodyScaleY,
        bodyDy,
        bodyRotation,
        headRotation,
        pupilDx,
        pupilDy,
        eyeOpen,
        earLeftRotation,
        earRightRotation,
        mouth,
        eyes,
        blush,
      );
}

/// İki katmanlı durum makinesi — tasarımın sözleşmesi.
///
/// * **Katman A (boşta):** nefes · göz kırpma · kulak seğirmesi · bakış.
///   Hiç durmaz.
/// * **Katman B (tepki):** tek seferlik; A'nın üstüne biner, bitince kapanır.
///
/// Saf: girdi olarak geçen süreyi alır, poz döndürür. Zamanlayıcı yok, bu
/// yüzden testte kare kare sürülebiliyor.
class KimoPoseSolver {
  const KimoPoseSolver();

  /// Tepki girişinin karışma süresi (tasarım: 80 ms).
  static const double blendInMs = 80;

  /// Tepki çıkışının karışma süresi (tasarım: 160 ms).
  static const double blendOutMs = 160;

  /// Bu boyutun altında yalnızca nefes ve göz kırpma çalışır; zıplama ve dönüş
  /// küçük boyutta titreme gibi görünüyor.
  static const double minimalMotionSize = 40;

  KimoPose solve({
    required Duration elapsed,
    required KimoMood mood,
    required bool scanning,
    required bool reduceMotion,
    required double size,
    KimoReaction? reaction,
    Duration reactionElapsed = Duration.zero,
  }) {
    if (reduceMotion) {
      // Döngüler durur; tepkiler tek karelik ifade değişimine iner.
      return _staticPose(mood: mood, scanning: scanning, reaction: reaction);
    }

    final bool minimal = size < minimalMotionSize;
    final double t = elapsed.inMicroseconds / 1e6;

    KimoPose pose = _idle(t, mood: mood, scanning: scanning, minimal: minimal);

    if (reaction != null && !minimal) {
      final double rt = reactionElapsed.inMicroseconds / 1e6;
      final double total = reaction.duration.inMicroseconds / 1e6;
      final KimoPose target = _reaction(reaction, rt, total);
      pose = _blend(pose, target, _blendFactor(rt * 1000, total * 1000));
    }
    return pose;
  }

  /// Giriş 80 ms, çıkış 160 ms. Arada tam tepki uygulanır. Sert kesme yok —
  /// kesme, animasyonu klip gibi gösterir.
  double _blendFactor(double elapsedMs, double totalMs) {
    if (elapsedMs <= 0) return 0;
    if (elapsedMs >= totalMs) return 0;
    final double fadeIn = (elapsedMs / blendInMs).clamp(0.0, 1.0);
    final double remaining = totalMs - elapsedMs;
    final double fadeOut = (remaining / blendOutMs).clamp(0.0, 1.0);
    return math.min(fadeIn, fadeOut);
  }

  KimoPose _blend(KimoPose a, KimoPose b, double k) {
    if (k <= 0) return a;
    if (k >= 1) return b;
    double l(double x, double y) => x + (y - x) * k;
    return KimoPose(
      bodyScaleX: l(a.bodyScaleX, b.bodyScaleX),
      bodyScaleY: l(a.bodyScaleY, b.bodyScaleY),
      bodyDy: l(a.bodyDy, b.bodyDy),
      bodyRotation: l(a.bodyRotation, b.bodyRotation),
      headRotation: l(a.headRotation, b.headRotation),
      pupilDx: l(a.pupilDx, b.pupilDx),
      pupilDy: l(a.pupilDy, b.pupilDy),
      eyeOpen: l(a.eyeOpen, b.eyeOpen),
      earLeftRotation: l(a.earLeftRotation, b.earLeftRotation),
      earRightRotation: l(a.earRightRotation, b.earRightRotation),
      // Ayrık alanlar karışmaz; yarıdan sonra hedefe geçer.
      mouth: k > 0.5 ? b.mouth : a.mouth,
      eyes: k > 0.5 ? b.eyes : a.eyes,
      blush: k > 0.5 ? b.blush : a.blush,
    );
  }

  // ---------------------------------------------------------------- Katman A

  KimoPose _idle(
    double t, {
    required KimoMood mood,
    required bool scanning,
    required bool minimal,
  }) {
    final bool night = mood == KimoMood.night;

    // Nefes: 3,4 sn (gecede 5 sn). Ayaklar sabit kalsın diye ölçek tabandan.
    final double breathPeriod = night ? 5.0 : 3.4;
    final double breath = math.sin(2 * math.pi * (t % breathPeriod) / breathPeriod);
    final double scaleY = 1 + 0.025 * breath;
    final double scaleX = 1 - 0.012 * breath;
    final double dy = -4 * (breath * 0.5 + 0.5);

    // Göz kırpma: 90 ms iniş + 60 ms kalkış, ~5 sn arayla ±1 sn sapma.
    //
    // Sapma döngünün ORTASINA uygulanıyor. Doğrudan döngü başına eklendiğinde
    // sapma negatifse pencere döngüden önce kalıyor ve o turda göz hiç
    // kırpılmıyordu — döngülerin kabaca yarısı sessiz geçiyordu.
    double eyeOpen = 1;
    if (!night) {
      final int cycle = (t / 5).floor();
      final double start = cycle * 5 + 2.5 + _jitter(cycle) * 0.5;
      final double dt = t - start;
      if (dt >= 0 && dt < 0.15) {
        eyeOpen = dt < 0.09 ? 1 - dt / 0.09 : (dt - 0.09) / 0.06;
      }
    }

    // Kulak seğirmesi: 260 ms, 6 sn arayla, iki kulak 0,5 sn farkla.
    double earL = 0;
    double earR = 0;
    if (!night && !minimal) {
      earL = _twitch(t, period: 6, offset: 0, amplitudeDeg: -8);
      earR = _twitch(t, period: 6, offset: 0.5, amplitudeDeg: 7);
    }

    // Bakış: 2,2 sn süren, 7 sn arayla dönen büyük hareket.
    double head = 0;
    double pupil = 0;
    if (!night && !minimal && !scanning) {
      final double phase = t % 7;
      if (phase < 2.2) {
        final double k = math.sin(2 * math.pi * phase / 2.2);
        head = 6 * math.pi / 180 * k;
        pupil = 4 * k;
      }
    }

    if (scanning) {
      // Tarama: gözler yukarı kayar, kafa sabit.
      return KimoPose(
        bodyScaleX: scaleX,
        bodyScaleY: scaleY,
        bodyDy: dy,
        eyeOpen: eyeOpen,
        pupilDy: -4,
        earLeftRotation: earL,
        earRightRotation: earR,
        mouth: KimoMouth.small,
      );
    }

    if (night) {
      return KimoPose(
        bodyScaleX: scaleX,
        bodyScaleY: scaleY,
        bodyDy: dy,
        eyes: KimoEyes.closedArc,
        mouth: KimoMouth.small,
      );
    }

    return KimoPose(
      bodyScaleX: scaleX,
      bodyScaleY: scaleY,
      bodyDy: dy,
      headRotation: head,
      pupilDx: pupil,
      eyeOpen: eyeOpen,
      earLeftRotation: earL,
      earRightRotation: earR,
      eyes: mood == KimoMood.happy ? KimoEyes.happyArc : KimoEyes.open,
      mouth: switch (mood) {
        KimoMood.happy => KimoMouth.wide,
        KimoMood.thinking => KimoMouth.small,
        KimoMood.curious => KimoMouth.neutral,
        KimoMood.calm => KimoMouth.smile,
        KimoMood.night => KimoMouth.small,
      },
      blush: mood == KimoMood.happy,
    );
  }

  /// Döngü numarasından türetilen sözde rastgele sapma. `Random` kullanılmıyor
  /// ki aynı `t` her zaman aynı pozu versin (test edilebilirlik).
  double _jitter(int cycle) {
    final int h = (cycle * 2654435761) & 0x7fffffff;
    return (h % 2000) / 1000 - 1; // -1 .. +1 sn
  }

  double _twitch(
    double t, {
    required double period,
    required double offset,
    required double amplitudeDeg,
  }) {
    final double phase = (t - offset) % period;
    if (phase < 0 || phase > 0.26) return 0;
    final double k = math.sin(math.pi * phase / 0.26);
    return amplitudeDeg * math.pi / 180 * k;
  }

  // ---------------------------------------------------------------- Katman B

  KimoPose _reaction(KimoReaction reaction, double t, double total) {
    final double p = total <= 0 ? 1 : (t / total).clamp(0.0, 1.0);
    switch (reaction) {
      case KimoReaction.correct:
        // Zıplama: eziliş, tepe, yayılma.
        final double h = _hop(p);
        // Eziliş sürekli olmalı: parçalı biçim p = 0,18'de 1,07'den tek karede
        // 1,00'a düşüyor ve zıplamanın tepesinde görünür bir sıçrama üretiyordu.
        final double squash =
            1 + 0.07 * math.sin(math.pi * math.min(p / 0.36, 1.0));
        return KimoPose(
          bodyDy: -26 * h,
          bodyScaleX: squash,
          // Hacim korunur: genişleyen gövde aynı oranda basıklaşır.
          bodyScaleY: 1 / squash,
          eyes: KimoEyes.happyArc,
          mouth: KimoMouth.wide,
          blush: true,
        );
      case KimoReaction.wrong:
        // Merak eder, üzülmez: kafa yana eğilir, ağız küçülür.
        final double k = math.sin(math.pi * p);
        return KimoPose(
          headRotation: 9 * math.pi / 180 * k,
          mouth: KimoMouth.small,
          pupilDy: 1.5 * k,
        );
      case KimoReaction.streakUp:
        // Tek baş sallama.
        final double k = math.sin(2 * math.pi * p);
        return KimoPose(
          bodyDy: 4 * k,
          headRotation: -3 * math.pi / 180 * k,
          eyes: KimoEyes.happyArc,
          mouth: KimoMouth.wide,
        );
      case KimoReaction.chestOpen:
        // En büyük hareket: 34px zıplama + 12 derece dönüş.
        final double h = _hop(p);
        return KimoPose(
          bodyDy: -34 * h,
          bodyRotation: 12 * math.pi / 180 * math.sin(math.pi * p),
          bodyScaleX: 1 + 0.08 * (1 - h),
          bodyScaleY: 1 - 0.06 * (1 - h),
          eyes: KimoEyes.happyArc,
          mouth: KimoMouth.wide,
          blush: true,
        );
      case KimoReaction.levelUp:
        // Ölçek nabzı 0,9 → 1,12 → 1, tabandan büyür.
        final double s = p < 0.18
            ? 1 - 0.1 * (p / 0.18)
            : p < 0.38
                ? 0.9 + 0.22 * ((p - 0.18) / 0.2)
                : p < 0.52
                    ? 1.12 - 0.14 * ((p - 0.38) / 0.14)
                    : 0.98 + 0.02 * ((p - 0.52) / 0.48);
        return KimoPose(
          bodyScaleX: s,
          bodyScaleY: s,
          eyes: KimoEyes.happyArc,
          mouth: KimoMouth.wide,
          blush: true,
        );
      case KimoReaction.tap:
        // 1,1 × 0,86 eziliş, sonra yayla geri.
        final double k = math.sin(math.pi * p);
        return KimoPose(
          bodyScaleX: 1 + 0.1 * k,
          bodyScaleY: 1 - 0.14 * k,
          bodyDy: 6 * k,
          eyes: KimoEyes.happyArc,
        );
    }
  }

  /// Zıplama eğrisi: hızlı yüksel, yavaş in.
  double _hop(double p) {
    if (p >= 0.62) return 0;
    final double k = p / 0.62;
    return math.sin(math.pi * k);
  }

  // -------------------------------------------------- Hareketi azalt (statik)

  KimoPose _staticPose({
    required KimoMood mood,
    required bool scanning,
    KimoReaction? reaction,
  }) {
    if (scanning) {
      return const KimoPose(pupilDy: -4, mouth: KimoMouth.small);
    }
    if (reaction != null) {
      return switch (reaction) {
        KimoReaction.correct ||
        KimoReaction.streakUp ||
        KimoReaction.chestOpen ||
        KimoReaction.levelUp ||
        KimoReaction.tap =>
          const KimoPose(eyes: KimoEyes.happyArc, mouth: KimoMouth.wide, blush: true),
        KimoReaction.wrong => const KimoPose(mouth: KimoMouth.small),
      };
    }
    return switch (mood) {
      KimoMood.night => const KimoPose(eyes: KimoEyes.closedArc, mouth: KimoMouth.small),
      KimoMood.happy => const KimoPose(eyes: KimoEyes.happyArc, mouth: KimoMouth.wide, blush: true),
      KimoMood.thinking => const KimoPose(mouth: KimoMouth.small),
      KimoMood.curious => const KimoPose(mouth: KimoMouth.neutral),
      KimoMood.calm => const KimoPose(),
    };
  }
}
