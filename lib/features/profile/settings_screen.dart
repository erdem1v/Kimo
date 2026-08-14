import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/moderation_repository.dart';
import '../../models/mascot.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_config.dart';
import '../../services/system_settings.dart';
import '../../state/user_profile.dart';
import '../../theme/app_colors.dart';
import '../admin/all_questions_screen.dart';
import '../admin/moderation_screen.dart';
import '../onboarding/exam_year_sheet.dart';
import '../onboarding/mascot_sheet.dart';

/// Ayarlar. Profil ekranı kimliğe (fotoğraf, XP, seri, lig) ayrılsın diye
/// bütün tercihler ve yönetim girişleri buraya taşındı.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured) {
      moderationRepository.isAdmin().then((bool v) {
        if (mounted && v) setState(() => _isAdmin = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListenableBuilder(
        listenable: userProfile,
        builder: (BuildContext context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: <Widget>[
              _soundToggle(),
              if (SupabaseConfig.isConfigured) ...<Widget>[
                const SizedBox(height: 12),
                _mascotTile(),
                const SizedBox(height: 12),
                _notifyTile(),
                const SizedBox(height: 12),
                _shareConsentTile(),
                const SizedBox(height: 12),
                _curriculumTile(),
                if (_isAdmin) ...<Widget>[
                  const SizedBox(height: 24),
                  const Text(
                    'Yönetim',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkLight,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _moderationTile(),
                  const SizedBox(height: 12),
                  _allQuestionsTile(),
                ],
                const SizedBox(height: 24),
                _logoutButton(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _soundToggle() {
    return _box(
      child: SwitchListTile(
        value: sound.enabled,
        title: const Text(
          'Ses efektleri',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        secondary: const Icon(Icons.volume_up_rounded, color: AppColors.green),
        onChanged: (bool v) => setState(() => sound.enabled = v),
      ),
    );
  }

  Widget _mascotTile() {
    final Mascot? m = userProfile.mascot;
    return _box(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (m?.color ?? AppColors.purple).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(m?.emoji ?? '🐻', style: const TextStyle(fontSize: 20)),
        ),
        title: const Text(
          'Koçun',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          m?.label ?? 'Seçilmedi — dokunup seç',
          style: const TextStyle(color: AppColors.inkLight, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.inkLight,
        ),
        onTap: () => showMascotSheet(context),
      ),
    );
  }

  /// Maskot hatırlatmaları: tek anahtar. Saatleri kullanıcıya sordurmuyoruz —
  /// hangi bildirimin saat kaçta geleceği bizim işimiz, onun değil.
  Widget _notifyTile() {
    final Mascot m = userProfile.mascot ?? Mascot.evHanimi;
    return _box(
      child: SwitchListTile(
        value: userProfile.notifyEnabled,
        activeThumbColor: m.color,
        secondary: Text(m.emoji, style: const TextStyle(fontSize: 22)),
        title: const Text(
          'Hatırlatmalar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          userProfile.notifyEnabled
              ? 'Koçun tekrar ve seri zamanlarında haber verir'
              : 'Kapalı',
          style: const TextStyle(color: AppColors.inkLight, fontSize: 12.5),
        ),
        onChanged: (bool v) async {
          // Açarken sistem izni gerekebilir.
          bool ok = v;
          if (v) ok = await notifications.requestPermission();
          await userProfile.setNotifyEnabled(ok);
          if (!ok) await notifications.cancelAll();
          if (mounted) setState(() {});
          // İzin reddedildiyse (ya da daha önce kalıcı reddedilmişse) sistem
          // penceresi bir daha açılmaz; kullanıcıyı ayara yönlendir.
          if (v && !ok && mounted) await _offerSettings();
        },
      ),
    );
  }

  /// İzin alınamadığında: tek dokunuşla telefonun bildirim ayarına götür.
  Future<void> _offerSettings() async {
    final Mascot m = userProfile.mascot ?? Mascot.evHanimi;
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: <Widget>[
            Text(m.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Bildirimler kapalı')),
          ],
        ),
        content: const Text(
          'Telefonun bildirim iznini kapatmış. Ayarlarda "Bildirimleri göster" '
          'anahtarını açarsan seni tekrar zamanı geldiğinde dürtebilirim.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ayarları aç'),
          ),
        ],
      ),
    );
    if (go == true) await SystemSettings.openNotificationSettings();
  }

  /// Soru havuzu paylaşım izni. Kapatınca sonraki yüklemeler paylaşılmaz.
  Widget _shareConsentTile() {
    return _box(
      child: SwitchListTile(
        value: userProfile.shareConsent,
        onChanged: (bool v) => userProfile.setShareConsent(v),
        activeThumbColor: AppColors.purple,
        secondary: const Text('🌍', style: TextStyle(fontSize: 22)),
        title: const Text(
          'Sorularımı havuzda paylaş',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          userProfile.shareConsent
              ? 'Yeni yüklediğin sorular diğer öğrencilerce çözülebilir.'
              : 'Kapalı: yüklediğin sorular sana özel kalır.',
          style: const TextStyle(color: AppColors.inkLight, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _curriculumTile() {
    final int? year = userProfile.examYear;
    final String subtitle = year == null
        ? 'Belirlenmedi — dokunup seç'
        : '$year · ${userProfile.curriculum == UserProfile.maarif ? 'Yeni müfredat (Maarif)' : 'Mevcut müfredat (2018)'}';
    return _box(
      child: ListTile(
        leading: const Icon(Icons.school_rounded, color: AppColors.blue),
        title: const Text(
          'Sınav yılı / müfredat',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.inkLight, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.inkLight,
        ),
        onTap: () => showExamYearSheet(context),
      ),
    );
  }

  /// Yalnızca moderatörlere görünen şikayet kuyruğu girişi.
  Widget _moderationTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.30)),
      ),
      child: ListTile(
        leading: const Icon(Icons.shield_outlined, color: AppColors.red),
        title: const Text(
          'Moderasyon kuyruğu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Bildirilen soruları incele',
          style: TextStyle(color: AppColors.inkLight, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.inkLight,
        ),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ModerationScreen()),
        ),
      ),
    );
  }

  /// Moderatör: tüm soruları görüp düzeltme.
  Widget _allQuestionsTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.30)),
      ),
      child: ListTile(
        leading: const Icon(Icons.fact_check_outlined, color: AppColors.purple),
        title: const Text(
          'Tüm sorular',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Ders/konu/sınav düzelt, havuzdan çıkar, sil',
          style: TextStyle(color: AppColors.inkLight, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.inkLight,
        ),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AllQuestionsScreen()),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          // Bu cihazın bildirim kaydını sil, sonra çık: başkasının
          // bildirimleri bu telefona düşmesin.
          await push.unregisterDevice();
          await notifications.cancelAll();
          await authRepository.signOut();
        },
        icon: const Icon(Icons.logout_rounded, color: AppColors.red),
        label: const Text(
          'Çıkış yap',
          style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _box({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}
