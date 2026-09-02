import 'package:flutter/material.dart';

/// Tasarım token'ları — tek kaynak.
///
/// Ekranlar renk sabiti YAZMAZ. Her renk buradan, `context.c` üzerinden gelir;
/// böylece açık ve koyu tema tek yerde tanımlı kalır ve bir rolün karşılığı
/// unutulduğunda derleme hatası alınır (alanlar zorunlu).
///
/// Değerler onaylanan Tur 4 tasarımından birebir alındı.
@immutable
class KimoColors extends ThemeExtension<KimoColors> {
  const KimoColors({
    required this.page,
    required this.card,
    required this.sunken,
    required this.border,
    required this.cardShadow,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.action,
    required this.actionShadow,
    required this.actionText,
    required this.actionTextStrong,
    required this.actionTint,
    required this.actionTintStrong,
    required this.honey,
    required this.honeyText,
    required this.honeyTint,
    required this.honeyTintStrong,
    required this.mint,
    required this.mintText,
    required this.mintTint,
    required this.trackEmpty,
    required this.navBar,
    required this.navActive,
    required this.navIdle,
    required this.cameraButton,
    required this.cameraShadow,
    required this.cameraIcon,
    required this.onAction,
    required this.overlay,
  });

  /// Sayfa zemini.
  final Color page;

  /// Kart yüzeyi.
  final Color card;

  /// Oyuk yüzey (segment arkası, ilerleme çubuğu yatağı).
  final Color sunken;

  /// İnce kenar çizgisi.
  final Color border;

  /// Kartın tek katmanlı sert gölgesi (0 2px 0).
  final Color cardShadow;

  /// Birincil metin.
  final Color ink;

  /// İkincil metin.
  final Color inkSecondary;

  /// Soluk metin / üst etiket.
  final Color inkMuted;

  /// Mercan — tek birincil aksiyon rengi.
  final Color action;

  /// Butonun altındaki 5px sert kabartma.
  final Color actionShadow;

  /// Mercanın METİN varyantı (aksan dolgusu üzerinde okunur).
  final Color actionText;

  /// Mercanın vurgulu metin/rozet varyantı.
  final Color actionTextStrong;

  /// Mercan zemin tonu (bilgi kartı).
  final Color actionTint;

  /// Mercan zemin tonu — bir ton koyu (HUD hapı).
  final Color actionTintStrong;

  /// Bal — ara durum, XP, elmas.
  final Color honey;
  final Color honeyText;
  final Color honeyTint;
  final Color honeyTintStrong;

  /// Nane — hâkimiyet ve doğru cevap.
  final Color mint;
  final Color mintText;
  final Color mintTint;

  /// Dolmamış dilim / boş ilerleme.
  final Color trackEmpty;

  /// Alt sekme çubuğu zemini.
  final Color navBar;
  final Color navActive;
  final Color navIdle;

  /// Merkezdeki kamera düğmesi.
  final Color cameraButton;
  final Color cameraShadow;
  final Color cameraIcon;

  /// Mercan zemin üzerindeki metin/ikon.
  final Color onAction;

  /// Alt sayfa (sheet) arkasındaki karartma.
  final Color overlay;

  static const KimoColors light = KimoColors(
    page: Color(0xFFFDFAF6),
    card: Color(0xFFFFFFFF),
    sunken: Color(0xFFF3EDE4),
    border: Color(0xFFE7E1D7),
    cardShadow: Color(0xFFEFE7DC),
    ink: Color(0xFF191713),
    inkSecondary: Color(0xFF5C564C),
    inkMuted: Color(0xFF6E675C),
    action: Color(0xFFF0522F),
    actionShadow: Color(0xFFB0351A),
    actionText: Color(0xFFB0351A),
    actionTextStrong: Color(0xFFC33A1C),
    actionTint: Color(0xFFFFF0E7),
    actionTintStrong: Color(0xFFFFE9DF),
    honey: Color(0xFFF2A93B),
    honeyText: Color(0xFF8A5A12),
    honeyTint: Color(0xFFFFF3D9),
    honeyTintStrong: Color(0xFFFFE3B8),
    mint: Color(0xFF1B9B6B),
    mintText: Color(0xFF0E6E4C),
    mintTint: Color(0xFFE6F6EE),
    trackEmpty: Color(0xFFF3E6DA),
    navBar: Color(0xFFFDFAF6),
    navActive: Color(0xFFB0351A),
    navIdle: Color(0xFF6F695F),
    cameraButton: Color(0xFF14110E),
    cameraShadow: Color(0xFF000000),
    cameraIcon: Color(0xFFFDFAF6),
    onAction: Color(0xFFFFFFFF),
    overlay: Color(0x66191713),
  );

  /// Koyu tema açığın ters çevrilmişi değil: sıcak grafit bir gece masası.
  /// Mercan aynı kalır (gece zemininde de okunur), metin varyantı açılır.
  static const KimoColors dark = KimoColors(
    page: Color(0xFF17140F),
    card: Color(0xFF221E19),
    sunken: Color(0xFF2C2620),
    border: Color(0xFF3A332B),
    cardShadow: Color(0xFF000000),
    ink: Color(0xFFF7F3EE),
    inkSecondary: Color(0xFFB8B0A4),
    inkMuted: Color(0xFFA59D92),
    action: Color(0xFFF0522F),
    actionShadow: Color(0xFFB0351A),
    actionText: Color(0xFFFF9273),
    actionTextStrong: Color(0xFFFF9273),
    actionTint: Color(0xFF36211A),
    actionTintStrong: Color(0xFF3D251C),
    honey: Color(0xFFF2A93B),
    honeyText: Color(0xFFF0CB84),
    honeyTint: Color(0xFF332715),
    honeyTintStrong: Color(0xFF3A2C15),
    mint: Color(0xFF1B9B6B),
    mintText: Color(0xFF63D8A6),
    mintTint: Color(0xFF14301F),
    trackEmpty: Color(0xFF332C25),
    navBar: Color(0xFF17140F),
    navActive: Color(0xFFFF9273),
    navIdle: Color(0xFFA59D92),
    cameraButton: Color(0xFFF7F3EE),
    cameraShadow: Color(0xFF000000),
    cameraIcon: Color(0xFF17140F),
    onAction: Color(0xFFFFFFFF),
    overlay: Color(0x9917140F),
  );

  @override
  KimoColors copyWith({
    Color? page,
    Color? card,
    Color? sunken,
    Color? border,
    Color? cardShadow,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? action,
    Color? actionShadow,
    Color? actionText,
    Color? actionTextStrong,
    Color? actionTint,
    Color? actionTintStrong,
    Color? honey,
    Color? honeyText,
    Color? honeyTint,
    Color? honeyTintStrong,
    Color? mint,
    Color? mintText,
    Color? mintTint,
    Color? trackEmpty,
    Color? navBar,
    Color? navActive,
    Color? navIdle,
    Color? cameraButton,
    Color? cameraShadow,
    Color? cameraIcon,
    Color? onAction,
    Color? overlay,
  }) {
    return KimoColors(
      page: page ?? this.page,
      card: card ?? this.card,
      sunken: sunken ?? this.sunken,
      border: border ?? this.border,
      cardShadow: cardShadow ?? this.cardShadow,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      action: action ?? this.action,
      actionShadow: actionShadow ?? this.actionShadow,
      actionText: actionText ?? this.actionText,
      actionTextStrong: actionTextStrong ?? this.actionTextStrong,
      actionTint: actionTint ?? this.actionTint,
      actionTintStrong: actionTintStrong ?? this.actionTintStrong,
      honey: honey ?? this.honey,
      honeyText: honeyText ?? this.honeyText,
      honeyTint: honeyTint ?? this.honeyTint,
      honeyTintStrong: honeyTintStrong ?? this.honeyTintStrong,
      mint: mint ?? this.mint,
      mintText: mintText ?? this.mintText,
      mintTint: mintTint ?? this.mintTint,
      trackEmpty: trackEmpty ?? this.trackEmpty,
      navBar: navBar ?? this.navBar,
      navActive: navActive ?? this.navActive,
      navIdle: navIdle ?? this.navIdle,
      cameraButton: cameraButton ?? this.cameraButton,
      cameraShadow: cameraShadow ?? this.cameraShadow,
      cameraIcon: cameraIcon ?? this.cameraIcon,
      onAction: onAction ?? this.onAction,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  KimoColors lerp(covariant ThemeExtension<KimoColors>? other, double t) {
    if (other is! KimoColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return KimoColors(
      page: c(page, other.page),
      card: c(card, other.card),
      sunken: c(sunken, other.sunken),
      border: c(border, other.border),
      cardShadow: c(cardShadow, other.cardShadow),
      ink: c(ink, other.ink),
      inkSecondary: c(inkSecondary, other.inkSecondary),
      inkMuted: c(inkMuted, other.inkMuted),
      action: c(action, other.action),
      actionShadow: c(actionShadow, other.actionShadow),
      actionText: c(actionText, other.actionText),
      actionTextStrong: c(actionTextStrong, other.actionTextStrong),
      actionTint: c(actionTint, other.actionTint),
      actionTintStrong: c(actionTintStrong, other.actionTintStrong),
      honey: c(honey, other.honey),
      honeyText: c(honeyText, other.honeyText),
      honeyTint: c(honeyTint, other.honeyTint),
      honeyTintStrong: c(honeyTintStrong, other.honeyTintStrong),
      mint: c(mint, other.mint),
      mintText: c(mintText, other.mintText),
      mintTint: c(mintTint, other.mintTint),
      trackEmpty: c(trackEmpty, other.trackEmpty),
      navBar: c(navBar, other.navBar),
      navActive: c(navActive, other.navActive),
      navIdle: c(navIdle, other.navIdle),
      cameraButton: c(cameraButton, other.cameraButton),
      cameraShadow: c(cameraShadow, other.cameraShadow),
      cameraIcon: c(cameraIcon, other.cameraIcon),
      onAction: c(onAction, other.onAction),
      overlay: c(overlay, other.overlay),
    );
  }
}

/// Aralık ölçeği. Tasarım 4 tabanlı; ara değer uydurulmaz.
class Gap {
  const Gap._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 7;
  static const double md = 11;
  static const double lg = 14;

  /// Ekran kenar boşluğu.
  static const double screen = 20;
  static const double xl = 24;

  /// Bölüm arası.
  static const double section = 32;
}

/// Köşe yarıçapları.
class Radii {
  const Radii._();

  /// Küçük çip / segment içi.
  static const double chip = 13;

  /// HUD hapı, segment kabı.
  static const double pill = 16;

  /// Liste kartı.
  static const double tile = 18;

  /// Kart, fotoğraf.
  static const double card = 20;

  /// Birincil buton, kamera düğmesi.
  static const double button = 22;

  /// Alt sayfa (sheet).
  static const double sheet = 24;

  static BorderRadius all(double r) => BorderRadius.circular(r);
}

/// Dokunma hedefleri ve sabit yükseklikler.
class Sizes {
  const Sizes._();

  /// Birincil butonun minimum yüksekliği.
  static const double buttonMin = 58;

  /// İkincil satır / liste öğesi minimum yüksekliği.
  static const double rowMin = 52;

  /// En küçük ikon butonu.
  static const double iconTap = 44;

  /// Butonun altındaki sert kabartma kalınlığı.
  static const double lip = 5;

  /// Basıldığında inilen mesafe.
  static const double lipPressed = 4;

  /// Alt sekme çubuğundaki kamera düğmesi.
  static const double cameraButton = 58;

  /// Sekme çubuğu içerik yüksekliği.
  static const double navBar = 56;
}

/// Hareket süreleri. Maskot süreleri `KimoTiming` içinde ayrı durur.
class Motion {
  const Motion._();

  /// Dokunma geri bildirimi (buton inisi).
  static const Duration press = Duration(milliseconds: 90);

  /// Kart/sayfa girişi.
  static const Duration enter = Duration(milliseconds: 550);

  /// Çubuk/dilim dolumu.
  static const Duration fill = Duration(milliseconds: 1000);

  /// Sayaç sayarken.
  static const Duration count = Duration(milliseconds: 700);

  /// Oturum sonu satırlarının arası.
  static const Duration stagger = Duration(milliseconds: 120);

  static const Curve enterCurve = Cubic(0.34, 1.4, 0.64, 1);
  static const Curve fillCurve = Cubic(0.32, 0.72, 0, 1);
}

/// `Theme.of(context).extension<KimoColors>()!` kısayolu.
extension KimoColorsX on BuildContext {
  KimoColors get c => Theme.of(this).extension<KimoColors>()!;
}
