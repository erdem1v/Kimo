import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'kit/kimo_icons.dart';
import 'mistake_photo.dart';

/// Soru fotoğrafının TAM EKRAN hâli: siyah zemin, yakınlaştırılabilir, tek
/// kapatma düğmesi.
///
/// Tekrar ekranında Task 07'den beri vardı ama gelen kutusunda yoktu ve orada
/// fotoğraf 160 piksel yüksekliğinde, `BoxFit.cover` ile KIRPILARAK
/// gösteriliyordu — arkadaşının el yazısı sorusunu okuyup şık seçmen
/// bekleniyordu. Task 17'de tek yere toplandı: aynı jest, aynı görünüm, iki
/// ekranda da.
Future<void> showPhotoViewer(
  BuildContext context, {
  String? path,
  Uint8List? bytes,
}) {
  assert(path != null || bytes != null, 'gösterilecek fotoğraf yok');
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext ctx) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.contain)
                      : MistakePhoto(path: path!, fit: BoxFit.contain),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const KimoIcon(KimoIcons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Kırpılmış bir önizlemenin üstüne oturan "tam ekran" rozeti.
///
/// Kırpılmış fotoğrafın dokunulabilir olduğu HİÇBİR YERDEN anlaşılmıyordu;
/// rozet o sözü veriyor.
class PhotoZoomBadge extends StatelessWidget {
  const PhotoZoomBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: Radii.all(Radii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm, vertical: Gap.xs / 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const KimoIcon(KimoIcons.play, size: 14, color: Colors.white),
            const SizedBox(width: Gap.xs),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
