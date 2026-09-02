import 'package:flutter/material.dart';

import '../theme/tokens.dart';

import '../data/social_repository.dart';
import '../models/mascot.dart';

/// Kullanıcının profil fotoğrafı. Fotoğraf yoksa (ya da yüklenemezse) maskot
/// simgesine düşer — listelerde hiçbir zaman boş daire kalmaz.
///
/// İmzalı URL tembel alınır ve [SocialRepository] içinde önbelleklenir; aynı
/// listede aynı kişi birden çok kez görünse bile tek istek yapılır.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.size,
    this.avatarPath,
    this.mascot,
    this.color,
  });

  final double size;
  final String? avatarPath;
  final Mascot? mascot;

  /// Fotoğraf yokken kullanılacak arka plan tonu (varsayılan: maskot rengi).
  final Color? color;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _url;

  /// İmza süresi dolduysa bir kez yeniden imzalarız. Sonsuz döngüye girmemek
  /// için tek seferlik: kalıcı bir hatada (dosya silinmiş, yetki yok) maskota
  /// düşülür.
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
    final Color tint =
        widget.color ?? widget.mascot?.color ?? context.c.action;
    final String? url = _url;
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: url == null
          ? Text(
              widget.mascot?.emoji ?? '🐻',
              style: TextStyle(fontSize: widget.size * 0.5),
            )
          : Image.network(
              url,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // Yükleme/hata durumunda simgeye düş: kırık ikon gösterme.
              // Ayrıca ölmüş imzayı bir kez yenilemeyi dene.
              errorBuilder: (BuildContext c, Object e, StackTrace? s) {
                _onImageError();
                return Text(
                  widget.mascot?.emoji ?? '🐻',
                  style: TextStyle(fontSize: widget.size * 0.5),
                );
              },
            ),
    );
  }
}
