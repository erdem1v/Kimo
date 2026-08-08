import 'package:flutter/material.dart';

import '../../models/mascot.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/game_button.dart';

/// Kayıt sonrası karşılama akışı: takma ad (eksikse) → sınav yılı → maskot
/// seçimi → kısa tanıtım. Tamamlanınca [onDone] çağrılır (AuthGate uygulamaya
/// geçer).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { nickname, examYear, mascot, howPhoto, howReview, howGamify }

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pager = PageController();
  final TextEditingController _nickname = TextEditingController();

  late final List<_Step> _steps;
  int _index = 0;
  int? _year;
  Mascot? _mascot;
  bool _saving = false;

  static const List<int> _years = <int>[2026, 2027, 2028, 2029, 2030];

  @override
  void initState() {
    super.initState();
    _nickname.text = userProfile.nickname ?? '';
    _year = userProfile.examYear;
    _mascot = userProfile.mascot;
    _steps = <_Step>[
      // Takma ad kayıtta alınır; yoksa (eski hesap) burada sorulur.
      if (userProfile.nickname == null) _Step.nickname,
      _Step.examYear,
      _Step.mascot,
      _Step.howPhoto,
      _Step.howReview,
      _Step.howGamify,
    ];
    _nickname.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pager.dispose();
    _nickname.dispose();
    super.dispose();
  }

  _Step get _current => _steps[_index];

  bool get _canContinue => switch (_current) {
        _Step.nickname => _nickname.text.trim().length >= 2,
        _Step.examYear => _year != null,
        _Step.mascot => _mascot != null,
        _ => true,
      };

  Future<void> _next() async {
    if (_saving) return;
    sound.tap();
    // Adımın verisini kaydet.
    setState(() => _saving = true);
    try {
      switch (_current) {
        case _Step.nickname:
          await userProfile.setNickname(_nickname.text.trim());
        case _Step.examYear:
          await userProfile.setExamYear(_year!);
        case _Step.mascot:
          await userProfile.setMascot(_mascot!);
        default:
          break;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi. Tekrar dene.')),
        );
        setState(() => _saving = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (_index >= _steps.length - 1) {
      sound.levelUp();
      widget.onDone();
      return;
    }
    setState(() => _index++);
    _pager.animateToPage(
      _index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_index == 0) return;
    sound.tap();
    setState(() => _index--);
    _pager.animateToPage(
      _index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _progressBar(),
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  for (final _Step s in _steps) _page(s),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: GameButton(
                label: _saving
                    ? 'Kaydediliyor...'
                    : (_index == _steps.length - 1 ? 'BAŞLA 🎉' : 'DEVAM'),
                enabled: _canContinue && !_saving,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: _index == 0 ? Colors.transparent : AppColors.inkLight,
            onPressed: _index == 0 ? null : _back,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_index + 1) / _steps.length,
                minHeight: 8,
                backgroundColor: AppColors.line,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${_index + 1}/${_steps.length}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.inkLight)),
        ],
      ),
    );
  }

  Widget _page(_Step step) => switch (step) {
        _Step.nickname => _nicknamePage(),
        _Step.examYear => _examYearPage(),
        _Step.mascot => _mascotPage(),
        _Step.howPhoto => _infoPage(
            emoji: '📸',
            color: AppColors.purple,
            title: 'Hatanı fotoğrafla',
            body: 'Yanlış yaptığın soruyu çek. AI şıkları okur, dersini ve '
                'konusunu senin için belirler. Sen sadece doğru şıkkı '
                'işaretlersin.',
          ),
        _Step.howReview => _infoPage(
            emoji: '🔁',
            color: AppColors.blue,
            title: 'Doğru zamanda karşına çıksın',
            body: 'Her soru 1 → 3 → 7 → 30 gün aralıklarıyla tekrar gelir. '
                'Bildiklerin seyrekleşir, zorlandıkların sıklaşır. Böylece '
                'unutmadan öğrenirsin.',
          ),
        _Step.howGamify => _infoPage(
            emoji: '🏆',
            color: AppColors.gold,
            title: 'Her gün küçük bir hedef',
            body: 'Günde 20 tekrar hedefin var. Çözdükçe XP kazanır, serini '
                'büyütürsün. Hatalarım sekmesinde derslere göre nerede '
                'zorlandığını görürsün.',
          ),
      };

  // --- Adımlar ---

  Widget _nicknamePage() {
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title('Sana nasıl seslenelim?'),
          _subtitle('Takma adın uygulamada ve liderlik tablosunda görünecek.'),
          const SizedBox(height: 24),
          TextField(
            controller: _nickname,
            textCapitalization: TextCapitalization.words,
            maxLength: 20,
            decoration: InputDecoration(
              hintText: 'Takma adın',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF4F4F4),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _examYearPage() {
    final String? curr =
        _year == null ? null : UserProfile.curriculumForYear(_year!);
    return _pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title('YKS\'ye hangi yıl gireceksin?'),
          _subtitle('Konuları doğru müfredata göre eşleştirmemiz için gerekli.'),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final int y in _years)
                ChoiceChip(
                  label: Text('$y'),
                  selected: _year == y,
                  onSelected: (_) => setState(() => _year = y),
                  labelStyle: TextStyle(
                    color: _year == y ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                  selectedColor: AppColors.green,
                  backgroundColor: const Color(0xFFF4F4F4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: const StadiumBorder(),
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ],
          ),
          if (curr != null) ...<Widget>[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.blueDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      curr == UserProfile.maarif
                          ? 'Yeni müfredat (Maarif Modeli) konuları kullanılacak.'
                          : 'Mevcut müfredat (2018) konuları kullanılacak.',
                      style: const TextStyle(
                          color: AppColors.blueDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mascotPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _title('Koçun kim olsun?'),
          _subtitle('Bildirimleri ve motivasyon sözlerini o yazacak. '
              'Sonradan değiştirebilirsin.'),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: <Widget>[
                for (final Mascot m in Mascot.values) _mascotTile(m),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mascotTile(Mascot m) {
    final bool selected = _mascot == m;
    return GestureDetector(
      onTap: () {
        sound.tap();
        setState(() => _mascot = m);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? m.color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? m.color : AppColors.line,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            // Maskot görseli sonra eklenecek; şimdilik emoji yer tutucu.
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: selected ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(m.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    m.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: selected ? m.color : AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(m.tagline,
                      style: const TextStyle(
                          color: AppColors.inkLight, fontSize: 12.5)),
                  if (selected) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('“${m.sample}”',
                        style: TextStyle(
                            color: m.color,
                            fontSize: 12.5,
                            height: 1.25,
                            fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: m.color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoPage({
    required String emoji,
    required Color color,
    required String title,
    required String body,
  }) {
    return _pad(
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.inkLight, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _pad(Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: child,
      );

  Widget _title(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
      );

  Widget _subtitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.inkLight, fontSize: 14, height: 1.3)),
      );
}
