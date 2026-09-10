import 'package:flutter/material.dart';

import '../data/social_repository.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Kullanıcının profil fotoğrafı. Fotoğraf yoksa (ya da yüklenemezse) takma
/// adın baş harfine düşer — listelerde hiçbir zaman boş daire kalmaz.
///
/// Eskiden burada **personanın emojisi** (🧸/🎤/🔧/💼) gösteriliyordu. Kaldırıldı:
/// persona ayrı bir karakter değil, Kimo'nun ses tonu. Emoji arkadaş listesinde,
/// ligde ve gelen kutusunda personayı görünür bir kimlik işaretine çeviriyordu —
/// yani ürünün söylediğinin tersini gösteriyordu.
///
/// İmzalı URL tembel alınır ve [SocialRepository] içinde önbelleklenir; aynı
/// listede aynı kişi birden çok kez görünse bile tek istek yapılır.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.avatarPath,
    this.name,
    this.color,
  });

  final double size;
  final String? avatarPath;

  /// Fotoğraf yokken baş harfi alınacak takma ad.
  final String? name;

  /// Fotoğraf yokken kullanılacak arka plan tonu.
  final Color? color;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _url;

  /// İmza süresi dolduysa bir kez yeniden imzalarız. Sonsuz döngüye girmemek
  /// için tek seferlik: kalıcı bir hatada (dosya silinmiş, yetki yok) baş
  /// harfe düşülür.
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarPath != widget.avatarPath) {
      _url = null;
      _retried = false;
      _load();
    }
  }

  Future<void> _load() async {
    final String? path = widget.avatarPath;
    if (path == null || path.isEmpty) return;
    final String? url = await socialRepository.avatarUrl(path);
    if (mounted && url != null) setState(() => _url = url);
  }

  /// Görsel yüklenemedi: büyük olasılıkla imza öldü. Önbelleği temizleyip bir
  /// kez yeniden dene. setState build sırasında çağrılamayacağı için kare
  /// sonrasına erteleniyor.
  void _onImageError() {
    if (_retried) return;
    _retried = true;
    socialRepository.invalidateAvatarUrl(widget.avatarPath);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _url = null);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final String? url = _url;
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.color ?? c.honeyTintStrong,
        shape: BoxShape.circle,
      ),
      child: url == null
          ? _Initial(name: widget.name, size: widget.size)
          : Image.network(
              url,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // Yükleme/hata durumunda baş harfe düş: kırık ikon gösterme.
              // Ayrıca ölmüş imzayı bir kez yenilemeyi dene.
              errorBuilder: (BuildContext c, Object e, StackTrace? s) {
                _onImageError();
                return _Initial(name: widget.name, size: widget.size);
              },
            ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.size});

  final String? name;
  final double size;

  /// Türkçe büyütme: `'i'.toUpperCase()` 'I' verir, doğrusu 'İ'. Tek harf
  /// gösterdiğimiz için bu fark doğrudan yanlış harf demek.
  static String initialOf(String? name) {
    final String s = (name ?? '').trim();
    if (s.isEmpty) return '?';
    final String ch = s.substring(0, 1);
    if (ch == 'i') return 'İ';
    if (ch == 'ı') return 'I';
    return ch.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Text(
      initialOf(name),
      style: t.section.copyWith(
        // Daire çapına oranlı; tasarımdaki 40px avatar 17px harf taşıyor.
        fontSize: size * 0.42,
        color: c.honeyText,
      ),
    );
  }
}
