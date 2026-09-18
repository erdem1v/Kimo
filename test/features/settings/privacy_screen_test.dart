import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/features/settings/privacy_screen.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/services/legal_links.dart';
import 'package:kimo/theme/app_theme.dart';

/// Veri ve Gizlilik ekranı (Task 18).
///
/// Hukuki adresler derleme tanımıyla geliyor (`--dart-define`), test
/// ortamında HİÇBİRİ yok. Ekranın sözü: adres verilmemiş satır HİÇ ÇİZİLMEZ —
/// "Hazırlanıyor" yer tutucusu bilinçli olarak geri getirilmedi (mağaza
/// incelemesinde sorulan şey oydu). Bu test o sözü sabitliyor: tanımsız
/// ortamda hukuki bölüm yok, ama AI aktarımı açıklaması her zaman var.
void main() {
  late L10n l;
  setUpAll(() async => l = await L10n.delegate.load(const Locale('tr')));

  testWidgets('adres yokken hukuki satırlar YOK, AI açıklaması VAR',
      (WidgetTester tester) async {
    expect(LegalLinks.anyConfigured, isFalse,
        reason: 'bu test dart-define olmadan koşmalı');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: const PrivacyScreen(),
    ));
    expect(find.text(l.privacyAiHeading), findsOneWidget);
    expect(find.text(l.privacyAiBody), findsOneWidget);
    // Ölü bağlantı yok: ne başlık, ne dört satır, ne "hazırlanıyor".
    expect(find.text(l.privacyLegalHeading), findsNothing);
    expect(find.text(l.privacyTermsLink), findsNothing);
    expect(find.text(l.privacyPrivacyLink), findsNothing);
    expect(find.text(l.privacyKvkkLink), findsNothing);
    expect(find.text(l.privacyDeletionLink), findsNothing);
  });
}
