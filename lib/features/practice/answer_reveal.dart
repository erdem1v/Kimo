import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';

/// Bir cevabın sonucu — sunucudan dönen gerçek değerler.
///
/// `xpAwarded` ve `multiplier` SUNUCUNUN döndürdüğü sayılar; çevrimdışıyken
/// cevap kuyruğa girdiği için ikisi de `null` olur ve panel ödül rozeti
/// GÖSTERMEZ.
/// Uydurma bir "+10 XP" göstermek, tavanlar yüzünden verilmemiş olabilecek bir
/// ödülü verilmiş gibi göstermek olurdu.
class AnswerOutcome {
  const AnswerOutcome({
    required this.correct,
    required this.nextIntervalDays,
    required this.mastered,
    this.xpAwarded,
    this.multiplier,
    this.scheduleFailed = false,
  });

  final bool correct;

  /// Sorunun bir sonraki tekrarına kaç gün kaldığı. Merdiven **1 → 3 → 7 → 30**;
  /// yanlışta 1'e (inatçı hatalarda 3'e) döner.
  final int nextIntervalDays;

  /// 30 günlük adım doğru bilindi → soru kuyruktan çıktı.
  final bool mastered;

  final int? xpAwarded;

  /// Sunucunun uyguladığı çarpan. 1 ise rozet gösterilmiyor: çarpılmış bir şey
  /// yok demektir. Ham `combo` sayısı burada tutulmuyor — panel onu
  /// göstermiyor, oturum tahtası ise değeri sunucudan doğrudan okuyor.
  final int? multiplier;

  /// Tekrar planı sunucuya yazılamadı. Sessizce geçilmiyor.
  final bool scheduleFailed;
}

/// 3h — Cevap açılışı.
///
/// **Doğruda ve yanlışta AYNI düzen.** Yanlışta kırmızı bir uyarı, sarsıntı ya
/// da "kaybettin" dili yok: yanlış cevap bu üründe bir ceza değil, tekrarın
/// yeniden başlaması. Renk farkı yalnızca ton (nane / bal) düzeyinde.
class AnswerReveal extends StatefulWidget {
  const AnswerReveal({
    super.key,
    required this.outcome,
    required this.isLast,
    required this.onContinue,
  });

  final AnswerOutcome outcome;
  final bool isLast;
  final VoidCallback onContinue;

  @override
  State<AnswerReveal> createState() => _AnswerRevealState();
}

class _AnswerRevealState extends State<AnswerReveal> {
  final KimoController _kimo = KimoController();

  @override
  void initState() {
    super.initState();
    _kimo.trigger(
      widget.outcome.correct ? KimoReaction.correct : KimoReaction.wrong,
    );
    _kimo.mood = widget.outcome.correct ? KimoMood.happy : KimoMood.thinking;
  }

  @override
  void dispose() {
    _kimo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);
    final AnswerOutcome o = widget.outcome;

    final Color tint = o.correct ? c.mintTint : c.honeyTint;
    final Color text = o.correct ? c.mintText : c.honeyText;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Gap.screen,
        Gap.lg,
        Gap.screen,
        Gap.lg + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Kimo(size: 56, controller: _kimo),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      o.correct ? l.practiceCorrectTitle : l.practiceWrongTitle,
                      style: t.heading.copyWith(color: text),
                    ),
                    const SizedBox(height: Gap.xxs),
                    Text(_body(l, o), style: t.body),
                  ],
                ),
              ),
            ],
          ),
          if (_hasRewards(o)) ...<Widget>[
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: <Widget>[
                if ((o.xpAwarded ?? 0) > 0)
                  StatusBadge(
                    label: l.practiceXpGain(o.xpAwarded!),
                    tone: BadgeTone.mastered,
                  ),
                // Çarpan yalnızca GERÇEKTEN uygulandıysa görünüyor: sunucu 1
                // döndürdüyse rozet yok, çünkü çarpılmış bir şey yok.
                if ((o.multiplier ?? 1) > 1)
                  StatusBadge(
                    label: l.practiceCombo(o.multiplier!),
                    tone: BadgeTone.pending,
                  ),
              ],
            ),
          ],
          if (o.scheduleFailed) ...<Widget>[
            const SizedBox(height: Gap.md),
            Text(
              l.practiceScheduleFailed,
              style: t.caption.copyWith(color: c.actionText),
            ),
          ],
          const SizedBox(height: Gap.lg),
          KimoButton(
            label: widget.isLast ? l.practiceFinish : l.practiceNext,
            onPressed: widget.onContinue,
          ),
        ],
      ),
    );
  }

  bool _hasRewards(AnswerOutcome o) =>
      (o.xpAwarded ?? 0) > 0 || (o.multiplier ?? 1) > 1;

  String _body(L10n l, AnswerOutcome o) {
    if (o.mastered) return l.practiceMasteredBody;
    return l.practiceNextInDays(o.nextIntervalDays);
  }
}
