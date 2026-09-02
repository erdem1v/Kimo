import 'package:flutter/material.dart';

import '../../data/account_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';

/// Hesap silme onayı.
///
/// **Yumuşak silme yok, 30 günlük bekleme yok.** KVKK Md. 7 / GDPR Md. 17
/// "gerçekten sil" diyor; "sonra da geri alabilirsin" diyen bir akış aslında
/// silmiyor demektir.
///
/// Onay için takma adı yazdırıyoruz. Tek dokunuşluk bir "Sil" düğmesi, listeyi
/// okumadan basılabilecek kadar kolaydı; yazma eylemi kullanıcıyı ne
/// sileceğini okumaya zorluyor.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _confirm = TextEditingController();
  bool _running = false;

  String get _nickname =>
      userProfile.nickname ?? L10n.of(context).defaultNickname;

  bool get _matches =>
      _confirm.text.trim().toLowerCase() == _nickname.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_matches || _running) return;
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    sound.tap();
    setState(() => _running = true);
    try {
      await accountRepository.deleteAccount();
      // Oturum repository içinde kapatıldı; AuthGate karşılama ekranına
      // dönecek. Yığındaki ekranları temizliyoruz ki silinmiş bir hesabın
      // ekranları arkada kalmasın.
      nav.popUntil((Route<dynamic> r) => r.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(l.deleteDone)));
    } catch (e) {
      // Sunucu önce depolamayı boşaltıyor; kısmi başarıda hesabı SİLMİYOR ve
      // hata dönüyor. Bu yüzden mesaj "hiçbir şey silinmedi" diyebiliyor.
      debugPrint('hesap silinemedi: $e');
      if (!mounted) return;
      setState(() => _running = false);
      messenger.showSnackBar(SnackBar(content: Text(l.deleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        title: Text(l.deleteTitle, style: t.section),
        leading: IconButton(
          onPressed: _running ? null : () => Navigator.of(context).maybePop(),
          icon: KimoIcon(KimoIcons.back, color: c.ink),
          tooltip: l.actionBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                children: <Widget>[
                  KimoCard(
                    color: c.actionTint,
                    elevated: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        KimoIcon(KimoIcons.flag, size: 20, color: c.actionText),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            l.deleteWarning,
                            style: t.body.copyWith(color: c.actionText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
                  SectionHeader(title: l.deleteWhatGoes),
                  const SizedBox(height: Gap.md),
                  _item(context, l.deleteItemMistakes),
                  _item(context, l.deleteItemProgress),
                  _item(context, l.deleteItemSocial),
                  _item(context, l.deleteItemAccount),
                  const SizedBox(height: Gap.xl),
                  Text(l.deleteConfirmPrompt(_nickname), style: t.bodyStrong),
                  const SizedBox(height: Gap.md),
                  TextField(
                    controller: _confirm,
                    autocorrect: false,
                    enabled: !_running,
                    style: t.body,
                    decoration: InputDecoration(
                      hintText: l.deleteConfirmHint,
                      filled: true,
                      fillColor: c.sunken,
                      border: OutlineInputBorder(
                        borderRadius: Radii.all(Radii.tile),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.screen, Gap.md, Gap.screen, Gap.screen),
              child: KimoButton(
                label: _running ? l.deleteRunning : l.deleteAction,
                onPressed: (_matches && !_running) ? _delete : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String text) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.inkMuted, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(text, style: t.body)),
        ],
      ),
    );
  }
}
