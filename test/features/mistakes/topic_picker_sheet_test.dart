import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/data/curriculum_repository.dart';
import 'package:kimo/features/mistakes/topic_picker_sheet.dart';
import 'package:kimo/l10n/generated/app_localizations.dart';
import 'package:kimo/models/curriculum.dart';
import 'package:kimo/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Konu seçici (Task 18). Ağaç GÖMÜLÜ yedekten (`assets/curriculum/tree.json`)
/// geliyor; ağ yok. Sabitlenen: ders seçilmeden arama ÇALIŞIYOR ve birden
/// çok dersten sonuç getiriyor (Task 15 · C6 — eskiden önce ders seçmek
/// zorunluydu); bir sonuca dokunmak `TopicPick` döndürüyor; eşleşme yoksa
/// boş durum metni var.
void main() {
  late L10n l;
  late CurriculumTree tree;

  setUpAll(() async {
    l = await L10n.delegate.load(const Locale('tr'));
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    curriculumRepository.resetForTest();
  });

  TopicPick? picked;

  Future<void> open(WidgetTester tester, {String? subject}) async {
    picked = null;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: AppTheme.light(),
      home: Builder(
        builder: (BuildContext ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await showTopicPicker(ctx,
                  curriculum: 'maarif', exam: 'TYT', subject: subject);
            },
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    // Gömülü ağaç rootBundle'dan okunuyor: gerçek zamanda tamamlansın.
    await tester.runAsync(() => curriculumRepository.load());
    tree = curriculumRepository.treeFor('maarif');
    expect(tree.search('TYT', 'a').isNotEmpty, isTrue,
        reason: 'gömülü ağaç yüklenmeli');
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  /// En az iki farklı dersten sonuç getiren bir sorgu bul.
  String crossSubjectQuery() {
    for (final String q in <String>['hız', 'enerji', 'oran', 'denklem', 'hücre', 'dil']) {
      final Set<String> subjects =
          tree.search('TYT', q).map((TopicHit h) => h.subject).toSet();
      if (subjects.length >= 2) return q;
    }
    fail('iki dersten sonuç getiren sorgu bulunamadı');
  }

  testWidgets('ders seçilmeden arama birden çok dersten sonuç getiriyor (C6)',
      (WidgetTester tester) async {
    await open(tester);
    final String q = crossSubjectQuery();
    final List<TopicHit> hits = tree.search('TYT', q);
    await tester.enterText(find.byType(TextField), q);
    await tester.pumpAndSettle();
    final Set<String> shown = <String>{};
    for (final TopicHit h in hits.take(6)) {
      if (find.text(h.topic).evaluate().isNotEmpty) shown.add(h.subject);
    }
    expect(shown.length, greaterThanOrEqualTo(2),
        reason: 'ders kilidi olsaydı yalnız bir dersin konuları çıkardı');
  });

  testWidgets('sonuca dokunmak TopicPick döndürüyor', (WidgetTester tester) async {
    await open(tester);
    final String q = crossSubjectQuery();
    final TopicHit first = tree.search('TYT', q).first;
    await tester.enterText(find.byType(TextField), q);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(first.topic).first);
    await tester.tap(find.text(first.topic).first);
    await tester.pumpAndSettle();
    expect(picked, isNotNull);
    expect(picked!.topic, first.topic);
    expect(picked!.subject, first.subject);
  });

  testWidgets('eşleşme yoksa boş durum', (WidgetTester tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'xqzvvv');
    await tester.pumpAndSettle();
    expect(find.text(l.topicPickerNoMatch), findsOneWidget);
  });
}
