import 'package:ai_yks_coach/widgets/kimo/kimo.dart';
import 'package:ai_yks_coach/widgets/kimo/kimo_pose.dart';
import 'package:flutter_test/flutter_test.dart';

/// Maskotun durum makinesi saf: zaman girdi olarak veriliyor, poz çıktı.
/// Bu yüzden animasyonun sözleşmesi cihaz olmadan doğrulanabiliyor.
void main() {
  const KimoPoseSolver solver = KimoPoseSolver();

  KimoPose solve({
    double seconds = 0,
    KimoMood mood = KimoMood.calm,
    bool scanning = false,
    bool reduceMotion = false,
    double size = 120,
    KimoReaction? reaction,
    double reactionSeconds = 0,
  }) {
    return solver.solve(
      elapsed: Duration(microseconds: (seconds * 1e6).round()),
      mood: mood,
      scanning: scanning,
      reduceMotion: reduceMotion,
      size: size,
      reaction: reaction,
      reactionElapsed: Duration(microseconds: (reactionSeconds * 1e6).round()),
    );
  }

  group('tepki süreleri tasarımdaki değerler', () {
    test('her tepki tasarımda yazan süreyi taşır', () {
      expect(KimoReaction.correct.duration.inMilliseconds, 700);
      expect(KimoReaction.wrong.duration.inMilliseconds, 700);
      expect(KimoReaction.streakUp.duration.inMilliseconds, 900);
      expect(KimoReaction.chestOpen.duration.inMilliseconds, 1200);
      expect(KimoReaction.levelUp.duration.inMilliseconds, 1000);
      expect(KimoReaction.tap.duration.inMilliseconds, 250);
    });

    test('öncelik sırası levelUp > chestOpen > streakUp > correct/wrong > tap', () {
      expect(
        KimoReaction.levelUp.priority,
        greaterThan(KimoReaction.chestOpen.priority),
      );
      expect(
        KimoReaction.chestOpen.priority,
        greaterThan(KimoReaction.streakUp.priority),
      );
      expect(
        KimoReaction.streakUp.priority,
        greaterThan(KimoReaction.correct.priority),
      );
      expect(KimoReaction.correct.priority, KimoReaction.wrong.priority);
      expect(
        KimoReaction.wrong.priority,
        greaterThan(KimoReaction.tap.priority),
      );
    });
  });

  group('KimoController çakışma kuralı', () {
    test('yüksek öncelikli tepki düşüğün üstüne biner', () {
      final KimoController c = KimoController();
      addTearDown(c.dispose);

      c.trigger(KimoReaction.tap);
      expect(c.reaction, KimoReaction.tap);

      c.trigger(KimoReaction.levelUp);
      expect(c.reaction, KimoReaction.levelUp);
    });

    test('düşük öncelikli tetik KUYRUĞA ALINMAZ, atılır', () {
      final KimoController c = KimoController();
      addTearDown(c.dispose);

      c.trigger(KimoReaction.levelUp);
      final int seq = c.reactionSeq;

      c.trigger(KimoReaction.tap);
      expect(c.reaction, KimoReaction.levelUp, reason: 'tap atılmalı');
      expect(c.reactionSeq, seq, reason: 'atılan tetik sırayı ilerletmemeli');
    });

    test('aynı öncelikli tepki yenisiyle değişir', () {
      final KimoController c = KimoController();
      addTearDown(c.dispose);

      c.trigger(KimoReaction.correct);
      c.trigger(KimoReaction.wrong);
      expect(c.reaction, KimoReaction.wrong);
    });

    test('eski sıra numarasıyla bitirme yok sayılır', () {
      final KimoController c = KimoController();
      addTearDown(c.dispose);

      c.trigger(KimoReaction.correct);
      final int first = c.reactionSeq;
      c.trigger(KimoReaction.levelUp);

      c.endReaction(first);
      expect(c.reaction, KimoReaction.levelUp,
          reason: 'arada başlayan tepki iptal edilmemeli');

      c.endReaction(c.reactionSeq);
      expect(c.reaction, isNull);
    });
  });

  group('katman A — boşta döngüsü', () {
    test('nefes hiç durmaz: iki farklı anda gövde ölçeği farklı', () {
      final KimoPose a = solve(seconds: 0);
      final KimoPose b = solve(seconds: 3.4 / 4);
      expect(a.bodyScaleY, isNot(closeTo(b.bodyScaleY, 1e-6)));
    });

    test('nefes 3,4 saniyede bir tekrar eder', () {
      final KimoPose a = solve(seconds: 0.4);
      final KimoPose b = solve(seconds: 0.4 + 3.4);
      expect(b.bodyScaleY, closeTo(a.bodyScaleY, 1e-9));
    });

    test('gecede nefes yavaşlar: 3,4 sn yerine 5 sn', () {
      final KimoPose a = solve(seconds: 0.4, mood: KimoMood.night);
      final KimoPose b = solve(seconds: 0.4 + 5, mood: KimoMood.night);
      expect(b.bodyScaleY, closeTo(a.bodyScaleY, 1e-9));
    });

    test('gecede gözler kapalı yay, kulak ve bakış kapalı', () {
      final KimoPose p = solve(seconds: 2.5, mood: KimoMood.night);
      expect(p.eyes, KimoEyes.closedArc);
      expect(p.earLeftRotation, 0);
      expect(p.earRightRotation, 0);
      expect(p.headRotation, 0);
    });

    test('taramada göz bebekleri yukarı kayar', () {
      final KimoPose p = solve(seconds: 1.2, scanning: true);
      expect(p.pupilDy, lessThan(0));
      expect(p.mouth, KimoMouth.small);
    });

    test('aynı zaman her zaman aynı pozu verir (rastgelelik yok)', () {
      expect(solve(seconds: 12.75), solve(seconds: 12.75));
    });
  });

  group('boyut eşiği', () {
    test('40px altında zıplama ve dönüş kapanır, nefes sürer', () {
      final KimoPose small = solve(
        seconds: 1,
        size: 30,
        reaction: KimoReaction.chestOpen,
        reactionSeconds: 0.4,
      );
      expect(small.bodyDy, lessThanOrEqualTo(0));
      expect(small.bodyRotation, 0);
      expect(small.earLeftRotation, 0, reason: 'kulak seğirmesi de kapalı');
      expect(small.bodyScaleY, isNot(1), reason: 'nefes çalışmaya devam eder');
    });

    test('40px üstünde sandık tepkisi gövdeyi döndürür', () {
      final KimoPose big = solve(
        seconds: 1,
        size: 120,
        reaction: KimoReaction.chestOpen,
        reactionSeconds: 0.4,
      );
      expect(big.bodyRotation, isNot(0));
    });
  });

  group('hareketi azalt', () {
    test('döngüler durur: zaman ilerlese de poz değişmez', () {
      final KimoPose a = solve(seconds: 0, reduceMotion: true);
      final KimoPose b = solve(seconds: 9.13, reduceMotion: true);
      expect(a, b);
    });

    test('tepki tek karelik ifade değişimine iner', () {
      final KimoPose p = solve(
        reduceMotion: true,
        reaction: KimoReaction.correct,
        reactionSeconds: 0.2,
      );
      expect(p.eyes, KimoEyes.happyArc);
      expect(p.bodyDy, 0, reason: 'zıplama yok');
      expect(p.bodyRotation, 0);
    });

    test('yanlış cevapta ceza dili yok: sarsıntı ve dönüş üretmez', () {
      final KimoPose p = solve(
        reduceMotion: true,
        reaction: KimoReaction.wrong,
        reactionSeconds: 0.2,
      );
      expect(p.mouth, KimoMouth.small);
      expect(p.bodyRotation, 0);
      expect(p.bodyDy, 0);
    });
  });

  group('katman B — tepki karışımı', () {
    test('tepki başında ve sonunda boşta pozuna eşittir (sert kesme yok)', () {
      final KimoPose idle = solve(seconds: 2);
      final KimoPose atStart = solve(
        seconds: 2,
        reaction: KimoReaction.correct,
        reactionSeconds: 0,
      );
      final KimoPose atEnd = solve(
        seconds: 2,
        reaction: KimoReaction.correct,
        reactionSeconds: 0.7,
      );
      expect(atStart.bodyDy, closeTo(idle.bodyDy, 1e-9));
      expect(atEnd.bodyDy, closeTo(idle.bodyDy, 1e-9));
    });

    test('tepkinin ortasında boşta pozundan ayrışır', () {
      final KimoPose idle = solve(seconds: 2);
      final KimoPose mid = solve(
        seconds: 2,
        reaction: KimoReaction.correct,
        reactionSeconds: 0.3,
      );
      expect(mid.bodyDy, lessThan(idle.bodyDy),
          reason: 'zıplama yukarı taşır (negatif dy)');
    });

    test('yanlış cevap sarsmaz, kafayı eğer', () {
      final KimoPose p = solve(
        seconds: 2,
        reaction: KimoReaction.wrong,
        reactionSeconds: 0.35,
      );
      expect(p.headRotation, greaterThan(0));
      expect(p.bodyRotation, 0, reason: 'gövde sarsılmaz');
      expect(p.mouth, KimoMouth.small);
    });
  });
}
