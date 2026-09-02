import 'package:flutter/material.dart';

import '../theme/tokens.dart';

import '../data/mistake_repository.dart';

/// Supabase Storage'daki bir fotoğrafı TEMBEL yükler: imzalı URL'i yalnızca bu
/// widget ekranda oluştuğunda üretir. Böylece uzun listelerde/pratikte tüm
/// URL'ler önden üretilmez (ListView.builder sadece görünenleri kurar).
class MistakePhoto extends StatefulWidget {
  const MistakePhoto({super.key, required this.path, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  State<MistakePhoto> createState() => _MistakePhotoState();
}

class _MistakePhotoState extends State<MistakePhoto> {
  late Future<String?> _future;

  /// İmza süresi dolduysa bir kez yeniden imzalarız. Tek seferlik: dosya
  /// gerçekten okunamıyorsa (kaldırılmış içerik, silinmiş nesne) yer tutucuda
  /// kalırız, sonsuz istek döngüsüne girmeyiz.
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _future = mistakeRepository.signedUrl(widget.path);
  }

  @override
  void didUpdateWidget(MistakePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _retried = false;
      _future = mistakeRepository.signedUrl(widget.path);
    }
  }

  /// Görsel yüklenemedi: muhtemelen imza öldü (ekran uzun süre açık kaldı).
  /// setState build sırasında çağrılamaz, kare sonrasına erteliyoruz.
  void _onImageError() {
    if (_retried) return;
    _retried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _future = mistakeRepository.signedUrl(widget.path));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<String?> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _placeholder(loading: true);
        }
        final String? url = snap.data;
        if (url == null) return _placeholder();
        return Image.network(
          url,
          fit: widget.fit,
          errorBuilder: (_, _, _) {
            _onImageError();
            return _placeholder();
          },
        );
      },
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: context.c.sunken,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.image_not_supported_outlined,
              color: context.c.inkMuted),
    );
  }
}
