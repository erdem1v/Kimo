import 'package:flutter/material.dart';

import '../../data/mascot_lines.dart';
import '../../models/mascot.dart';
import '../../services/notification_service.dart';
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

enum _Step {
  nickname,
  examYear,
  mascot,
  notifications,
  howPhoto,
  howReview,
  howGamify,
  shareConsent,
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pager = PageController();
  final TextEditingController _nickname = TextEditingController();

  late final List<_Step> _steps;
  int _index = 0;
  int? _year;
  Mascot? _mascot;
  bool _consent = false;
  bool? _notify; // null = henüz seçilmedi
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
      // İzin, maskot seçildikten hemen sonra: kullanıcı karakterine yeni
      // yatırım yapmışken "seni ben hatırlatayım mı?" en doğal an.
      _Step.notifications,
      _Step.howPhoto,
      _Step.howReview,
      _Step.howGamify,
      _Step.shareConsent,
    ];
    _consent = userProfile.shareConsent;
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
        _Step.notifications => _notify != null,
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
        case _Step.notifications:
          // Sistem izni ancak "evet" dendiyse istenir.
          bool granted = false;
          if (_notify == true) granted = await notifications.requestPermission();
          await userProfile.setNotifyEnabled(granted);
        case _Step.shareConsent:
          await userProfile.setShareConsent(_consent);
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
        _Step.shareConsent => _consentPage(),
        _Step.notifications => _notifyPage(),
      };

  /// Bildirim izni — maskotun ağzından. Sistem penceresi ancak kullanıcı
  /// "Evet, hatırlat" dedikten sonra açılır (soğuk sorulursa reddedilir ve
  /// Android'de izni tekrar sorma hakkı harcanır).
  Widget _notifyPage() {
    final Mascot m = _mascot ?? userProfile.mascot ?? Mascot.evHanimi;
    return _pad(
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(m.emoji, style: const TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 20),
            _title('Sana hatırlatayım mı?'),
            _subtitle('Tekrar zamanın geldiğinde ve serin tehlikedeyken '
                'haber vereyim. Günde en fazla iki kez, gece rahatsız etmem.'),
            const SizedBox(height: 16),
            // Karakterin sesinden örnek bildirim.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: m.color.withValues(alpha: 0.30)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(m.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(MascotLines.title(NotifyKind.streakRisk),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: m.color)),
                        const SizedBox(height: 2),
                        Text(
                          MascotLines.pick(NotifyKind.streakRisk, m, n: 7),
                          style: const TextStyle(
                              fontSize: 13, height: 1.3, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _notifyChoice(
              selected: _notify == true,
              color: m.color,
              icon: Icons.notifications_active_rounded,
              title: 'Evet, hatırlat',
              body: 'Tekrar ve seri hatırlatmalarını gönder.',
              onTap: () => setState(() => _notify = true),
            ),
            const SizedBox(height: 8),
            _notifyChoice(
              selected: _notify == false,
              color: AppColors.inkLight,
              icon: Icons.notifications_off_outlined,
              title: 'Şimdilik istemiyorum',
              body: 'Profilden istediğin zaman açabilirsin.',
              onTap: () => setState(() => _notify = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifyChoice({
    required bool selected,
    required Color color,
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        sound.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.line,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: selected ? color : AppColors.inkLight, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: selected ? color : AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          color: AppColors.inkLight, fontSize: 12.5)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  /// Soru havuzu paylaşım onayı — bir kez alınır, profilden değiştirilebilir.
  Widget _consentPage() {
    return _pad(
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Text('🌍', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 20),
            _title('Soru havuzu'),
            _subtitle(
              'Yüklediğin sorular, diğer öğrencilerin çözebilmesi için ortak '
              'havuza eklenir. Sen de onların sorularını çözersin — havuz '
              'herkesin katkısıyla büyür.',
            ),
            const SizedBox(height: 16),
            _consentBullet('👀', 'Paylaşılan',
                'Sorunun fotoğrafı, şıkları ve takma adın.'),
            _consentBullet('🔒', 'Paylaşılmayan',
                'Notların, hata türün, tekrar durumun ve e-postan.'),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                sound.tap();
                setState(() => _consent = !_consent);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _consent
                      ? AppColors.green.withValues(alpha: 0.10)
                      : const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _consent ? AppColors.green : AppColors.line,
                    width: _consent ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _consent
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _consent ? AppColors.green : AppColors.inkLight,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Yüklediğim soruların diğer öğrencilerle '
                        'paylaşılacağını okudum, anladım ve kabul ediyorum.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Kabul etmezsen sorularının hiçbiri paylaşılmaz; uygulamayı '
              'yine de kullanabilirsin. Bu tercihi profilinden '
              'değiştirebilirsin.',
              style: TextStyle(
                  color: AppColors.inkLight, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _consentBullet(String emoji, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  TextSpan(
                    text: body,
                    style: const TextStyle(color: AppColors.inkLight),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

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
