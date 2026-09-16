import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/curriculum_repository.dart';
import '../../data/mistake_repository.dart';
import '../../data/photo_queue.dart';
import '../../models/curriculum.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';
import '../../services/sound_service.dart';
import '../../state/user_profile.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/kimo/kimo.dart';
import '../../widgets/kit/kimo_button.dart';
import '../../widgets/kit/kimo_chips.dart';
import '../../widgets/kit/kimo_icons.dart';
import '../../widgets/kit/kimo_surfaces.dart';
import '../mistakes/topic_picker_sheet.dart';
import 'pending_photos_screen.dart';

/// 3f — Onayla ve kaydet.
///
/// Form doldurma değil ONAYLAMA: yapay zekâ sınav/ders/konuyu ve şıkları
/// doldurmuşsa kullanıcıya kalan iki dokunuş var (doğru şık + kaydet).
///
/// **AYNI EKRAN ELLE GİRİŞ FORMUDUR.** Günlük yapay zekâ hakkı bittiğinde,
/// çevrimdışıyken ve "fotoğrafsız devam et" yolunda da bu ekran açılıyor;
/// yalnızca alanlar boş geliyor. Task'ın istediği bu: "Elle giriş yolu zaten
/// çevrimdışı kayıt için de gerekiyor — aynı formu iki durum da kullansın."
/// Kaydedildi ama GÖNDERİLEBİLİR BİR KİMLİK YOK.
///
/// Çevrimdışı yollarda satır henüz oluşmuyor (kuyruğa giriyor), yani "yeni soru
/// çek → doğrudan gönder" akışı o soruyu gönderemez. Ekran `null` DÖNMÜYOR
/// çünkü `null` "vazgeçildi" demek; iki durumu birleştirmek kullanıcıya
/// "kaydedilmedi" demek olurdu.
const String kQueuedSentinel = 'queued';

class ConfirmMistakeScreen extends StatefulWidget {
  const ConfirmMistakeScreen({
    super.key,
    this.imageBytes,
    this.analysis,
    this.queueEntryId,
    this.initialFields,
  });

  /// Çekilen fotoğraf. `null` ise fotoğrafsız kayıt (elle giriş).
  final Uint8List? imageBytes;

  /// Yapay zekâ sonucu. `null` ise analiz hiç yapılmadı (çevrimdışı, iptal
  /// edildi ya da mock mod). `outOfCredit` ise hak bitti.
  final QuestionAnalysis? analysis;

  /// Kuyruktaki bir kaydı tamamlıyorsak o kaydın kimliği (Task 08).
  ///
  /// Doluysa: kaydetme başarılı olduğunda kuyruk kaydı DÜŞÜYOR, ağ hatasında
  /// ise kuyrukta GÜNCELLENİYOR (yeni bir kopya yaratılmıyor).
  final String? queueEntryId;

  /// Kuyruk kaydının önceden doldurulmuş alanları.
  final Map<String, dynamic>? initialFields;

  @override
  State<ConfirmMistakeScreen> createState() => _ConfirmMistakeScreenState();
}

class _ConfirmMistakeScreenState extends State<ConfirmMistakeScreen> {
  /// Şıksız bir soru kaydedilemiyor (tekrar ekranı doğru şıkkı biliyor olmalı),
  /// bu yüzden elle girişte beş harf hazır geliyor. Metinleri boş kalabilir:
  /// tasarımda pratik ekranı şıkların METNİNİ değil harflerini gösteriyor.
  static const List<String> _defaultLabels = <String>['A', 'B', 'C', 'D', 'E'];

  final TextEditingController _note = TextEditingController();
  final KimoController _kimo = KimoController();

  String _exam = 'TYT';
  String? _subject;
  String? _concept;
  final List<String> _extras = <String>[];
  MistakeType? _type;
  int? _correctIndex;
  List<String> _labels = <String>[];
  bool _saving = false;

  /// Kaydetme ağ hatasında kuyruğa düştü mü (arayüz metni değişiyor).
  bool _queued = false;

  /// Ders satırı açık mı (yerinde açılan çip satırı — modal yok).
  bool _subjectOpen = false;

  @override
  void initState() {
    super.initState();
    final QuestionAnalysis? a = widget.analysis;
    if (a != null && a.ok) {
      _labels = <String>[for (final QuestionOption o in a.options) o.label];
      // Yapay zekânın önerisi YALNIZCA müfredatta karşılığı varsa kabul
      // ediliyor. Uydurma ders/konu arşivi ve istatistikleri kirletirdi.
      if (a.exam == 'TYT' || a.exam == 'AYT') _exam = a.exam!;
      if (a.subject != null && _subjects.contains(a.subject)) {
        _subject = a.subject;
        if (a.concept != null && _topicValid(a.subject!, a.concept!)) {
          _concept = a.concept;
        }
      }
    }
    // Kuyruktan gelen kayıt: kullanıcının/AI'nın önceden doldurduğu alanlar.
    // Analiz sonucundan SONRA uygulanıyor ki daha somut olan kazansın.
    final Map<String, dynamic>? f = widget.initialFields;
    if (f != null) {
      final Object? exam = f['exam'];
      if (exam == 'TYT' || exam == 'AYT') _exam = exam! as String;
      final Object? subject = f['subject'];
      if (subject is String && _subjects.contains(subject)) {
        _subject = subject;
        final Object? concept = f['concept'];
        if (concept is String && _topicValid(subject, concept)) {
          _concept = concept;
        }
      }
      final Object? labels = f['labels'];
      if (labels is List && labels.isNotEmpty) {
        _labels = <String>[for (final dynamic x in labels) x as String];
      }
      final Object? idx = f['correct_index'];
      if (idx is num) _correctIndex = idx.toInt();
      _type = MistakeType.fromDb(f['type'] as String?);
      final Object? note = f['note'];
      if (note is String) _note.text = note;
      final Object? extras = f['extras'];
      if (extras is List) {
        _extras.addAll(<String>[for (final dynamic x in extras) x as String]);
      }
    }
    if (_labels.isEmpty) _labels = List<String>.from(_defaultLabels);
  }

  /// Kuyruk kaydına yazılacak alanlar — [_save] ile birebir aynı veri.
  Map<String, dynamic> get _queueFields => <String, dynamic>{
        'exam': _exam,
        'subject': _subject,
        'concept': _concept,
        'labels': _labels,
        'correct_index': _correctIndex,
        'type': _type?.dbValue,
        'note': _note.text.trim(),
        'extras': _extras,
      };

  @override
  void dispose() {
    _note.dispose();
    _kimo.dispose();
    super.dispose();
  }


  /// Ağaç artık sunucudan geliyor ve tazelenince değişebiliyor; bu yüzden
  /// her okuma repository'den (bkz. `CurriculumRepository`).
  CurriculumTree get _tree =>
      curriculumRepository.treeFor(userProfile.curriculum);

  List<String> get _subjects => _tree.subjectNames(_exam);

  bool _topicValid(String subject, String topic) =>
      _tree.isValidTopic(_exam, subject, topic);

  bool get _canSave =>
      !_saving && _subject != null && _concept != null && _correctIndex != null;

  /// Seçilebilir şık sayıları. TYT/AYT beş şıklı; dört şık eski ÖSYM
  /// sorularında ve bazı deneme kitapçıklarında geçiyor.
  static const List<int> _optionCounts = <int>[4, 5];

  /// Yapay zekâ şıkları gerçekten çıkardı mı.
  ///
  /// `analysis.ok` tanımı gereği "şıklar var" demek (`MistakeRepository`
  /// içinde `hasOptions && options.isNotEmpty`), yani sayı da etiketler de
  /// biliniyor.
  ///
  /// Kuyruktan tamamlanan kayıtta `analysis` `null` gelir çünkü analiz akışın
  /// dışında, `PhotoQueue.flush` içinde yapıldı. Oradaki köken işareti
  /// (`labels_from_ai`) aynı bilgiyi taşıyor: işaret yoksa şıkları kullanıcı
  /// belirledi ya da hiç belirlenmedi, yani soru gerçekten anlamlı.
  bool get _aiGaveOptions =>
      widget.analysis?.ok == true ||
      widget.initialFields?['labels_from_ai'] == true;

  void _setOptionCount(int n) {
    sound.tap();
    setState(() {
      _labels = _defaultLabels.take(n).toList();
      // Seçili şık listenin dışında kaldıysa işaret DÜŞÜYOR: yoksa kayıt
      // var olmayan bir şıkkı doğru gösterirdi.
      if (_correctIndex != null && _correctIndex! >= n) _correctIndex = null;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // EKRANI KAPATMA KARARI try/catch'in DIŞINDA veriliyor. `nav.pop` eskiden
    // `try` gövdesinin içindeydi: pop'un kendisi hata atarsa (rotanın sonuç
    // tipi tutmuyorsa `didPop` eşdeğişken denetimde patlıyor) bu AĞ HATASI
    // sanılıyor, kaydedilmiş bir satır kullanıcıya "sıraya alındı" diye
    // gösteriliyordu.
    String? result;
    try {
      final List<QuestionOption> options = <QuestionOption>[
        for (final String label in _labels)
          QuestionOption(label: label, text: ''),
      ];

      final String? newId = await mistakeRepository.add(
        subject: _subject!,
        concept: _concept!,
        type: _type,
        note: _note.text.trim(),
        imageBytes: widget.imageBytes,
        options: options,
        correctIndex: _correctIndex,
        exam: _exam,
        // Soru havuzu bu sürümde yok (bkz. lib/_archive/README.md).
        extraConcepts: _extras,
      );
      // Kuyruktan gelen bir kaydı tamamladıysak kopyası artık gereksiz.
      final String? queueId = widget.queueEntryId;
      if (queueId != null) await photoQueue.remove(queueId);
      sound.correct();
      // KİMLİK GERİ DÖNÜYOR (Task 12 · P4): "yeni soru çek → doğrudan gönder"
      // yolu buna ihtiyaç duyuyor. `true` yerine kimlik dönmek geriye dönük
      // uyumu bozmuyor çünkü çağıranlar `== true` yerine `!= null` kontrol
      // ediyor — ikisi de aynı "kaydedildi" anlamını taşıyor.
      result = newId ?? kQueuedSentinel;
    } on PostgrestException catch (e) {
      // SUNUCU REDDETTİ: tekrar denemek aynı sonucu verir, kuyruğa almak
      // kaydı sonsuza dek bekletirdi (SubmissionQueue'nun kalıcı-ret dersi).
      debugPrint('hata kaydı sunucuca reddedildi: ${e.code} ${e.message}');
      if (!mounted) return;
      if (e.code == MistakeRepository.staleTopicCode) {
        // Ağaç bizde bayat: konu artık müfredatta yok. Sessiz bir "kaydedilemedi"
        // yerine sebebi söyleniyor ve liste tazeleniyor — kullanıcı yeni ağaçtan
        // seçebilsin.
        unawaited(curriculumRepository
            .refresh(userProfile.curriculum)
            .then((_) {
          if (mounted) setState(() => _concept = null);
        }));
        messenger.showSnackBar(SnackBar(content: Text(l.confirmTopicStale)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.confirmSaveFailed)));
      }
    } catch (e) {
      // AĞ HATASI: kaydetme yolu kapanmıyor — kayıt kuyruğa giriyor ve
      // bağlantı gelince kendiliğinden gönderiliyor. Fotoğraf da diskte
      // saklanıyor, yani uygulama kapanıp açılınca kaybolmuyor.
      debugPrint('hata kaydedilemedi, kuyruğa alınıyor: $e');
      final bool ok = await _queueForLater(PhotoQueueState.ready);
      if (!mounted) return;
      if (ok) {
        sound.correct();
        messenger.showSnackBar(SnackBar(content: Text(l.confirmSavedQueued)));
        // KUYRUĞA ALINDI: satır henüz YOK, yani gönderilecek bir kimlik de
        // yok. [kQueuedSentinel] "kaydedildi ama gönderilemez" demek.
        result = kQueuedSentinel;
      }
    } finally {
      // Ekran AÇIK KALIYORSA düğme mutlaka geri geliyor. Sıfırlama eskiden üç
      // ayrı dalın içindeydi; bir dal kaçınca `_saving` sonsuza dek `true`
      // kalıyor ve ekrandaki HER kontrol (kaydet, vazgeç, analizi bekle) aynı
      // anda ölüyordu — kullanıcının tek çıkışı işletim sistemi jestiydi.
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (result != null) nav.pop(result);
  }

  /// Kaydı fotoğraf kuyruğuna yazar (ya da kuyruktaki kaydı günceller).
  ///
  /// Fotoğrafsız kayıtta kuyruk YOK: kuyruğun deposu bir JPEG dosyası ve
  /// saklanacak bir bayt yoksa kayıt yeri de yok. O durumda kullanıcı ağ
  /// gelince tekrar deniyor — kaybolan tek şey birkaç dokunuş.
  Future<bool> _queueForLater(PhotoQueueState state) async {
    final String? queueId = widget.queueEntryId;
    if (queueId != null) {
      await photoQueue.update(queueId, _queueFields);
      return true;
    }
    final Uint8List? bytes = widget.imageBytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).confirmSaveFailed)),
        );
      }
      return false;
    }
    final PhotoQueueAdd result = await photoQueue.enqueue(
      bytes: bytes,
      state: state,
      fields: _queueFields,
    );
    if (!mounted) return false;
    if (result != PhotoQueueAdd.ok) {
      await reportQueueAdd(context, result);
      return false;
    }
    setState(() => _queued = true);
    return true;
  }

  /// "Analizi bekle": form doldurulmadan fotoğrafı sıraya alır.
  ///
  /// §5'in ikinci yolu. Kullanıcı beklemek istiyorsa Kimo bağlantı gelince
  /// okuyor; istemiyorsa formu doldurup hemen kaydediyor. İkisi de açık.
  Future<void> _waitForAnalysis() async {
    sound.tap();
    setState(() => _saving = true);
    final L10n l = L10n.of(context);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    bool ok = false;
    try {
      ok = await _queueForLater(PhotoQueueState.needsAnalysis);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text(l.captureQueuedOffline)));
      nav.pop(kQueuedSentinel);
    }
  }

  /// "Analizi bekle" düğmesi ne zaman görünür.
  ///
  /// Yalnızca fotoğraf VARSA ve analiz gerçekten yapılamadıysa: ağ hatası,
  /// yaş kapısı ya da hiç denenmemiş olması. Başarılı bir analizden sonra
  /// beklenecek bir şey yok; kota bitmişse beklemek de çözmüyor (hak yarın
  /// yenileniyor ama kuyruk o kadar beklemez, kullanıcı formu doldurmalı).
  bool get _canWaitForAnalysis {
    if (widget.imageBytes == null || _saving || _queued) return false;
    if (widget.queueEntryId != null) return false;
    final QuestionAnalysis? a = widget.analysis;
    if (a == null) return true;
    if (a.ok || a.outOfCredit) return false;
    return a.failure == AnalysisFailure.network ||
        a.failure == AnalysisFailure.ageRequired;
  }

  @override
  Widget build(BuildContext context) {
    final KimoColors c = context.c;
    final L10n l = L10n.of(context);

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(context, l),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Gap.screen, 0, Gap.screen, Gap.screen),
                children: <Widget>[
                  if (widget.imageBytes != null) _photo(context, l),
                  const SizedBox(height: Gap.md),
                  _kimoLine(context, l),
                  const SizedBox(height: Gap.md),
                  _classificationCard(context, l),
                  const SizedBox(height: Gap.md),
                  _correctOptionCard(context, l),
                  const SizedBox(height: Gap.md),
                  _reasonCard(context, l),
                ],
              ),
            ),
            _saveBar(context, l),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.screen, Gap.md),
      child: Row(
        children: <Widget>[
          IconButton(
            // `null` = VAZGEÇİLDİ. Eskiden `false` dönüyordu; çekim ve parti
            // akışları ekranı `MaterialPageRoute<String>` olarak ittiği için
            // `didPop(false)` eşdeğişken tip denetiminde patlıyor, hata jest
            // işleyicisinde yutuluyor ve DOKUNUŞ HİÇBİR ŞEY YAPMIYORDU.
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: KimoIcon(KimoIcons.close, color: c.ink),
            tooltip: l.actionCancel,
          ),
          Expanded(child: Text(l.confirmTitle, style: t.section)),
        ],
      ),
    );
  }

  Widget _photo(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: <Widget>[
          ClipRRect(
            borderRadius: Radii.all(Radii.card),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.memory(
                widget.imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext ctx, Object e, StackTrace? st) =>
                    Center(
                  child: Text(L10n.of(ctx).photoBrokenNote,
                      style: ctx.t.caption),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: Gap.sm),
              decoration: BoxDecoration(
                color: c.overlay,
                borderRadius: Radii.all(Radii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  KimoIcon(KimoIcons.play, size: 14, color: c.onAction),
                  const SizedBox(width: Gap.xs),
                  Text(
                    l.confirmFullscreen,
                    style: t.captionStrong.copyWith(color: c.onAction),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    if (widget.imageBytes == null) return;
    sound.tap();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Center(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image.memory(widget.imageBytes!),
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

  /// Hak bittiğinde gösterilen bilgi. Geri sayım YOK — tasarım kararı:
  /// "Arayüzde geri sayım yok, kalan hak gösterilir."
  Widget _kimoLine(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Kimo(size: 44, controller: _kimo),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(_introText(l), style: t.body),
          ),
        ),
      ],
    );
  }

  /// Kimo'nun açılış cümlesi.
  ///
  /// Analiz BAŞARISIZSA nedeni artık söyleniyor (Task 03): "fotoğraf bulanık"
  /// ile "bağlantı yok" aynı genel metne düşmüyor; kullanıcı fotoğrafı yeniden
  /// çekmesi gerektiğini buradan öğreniyor. Metinler İSTEMCİNİN kendi
  /// yerelleştirilmiş cümleleri — modelin serbest metni hiçbir zaman
  /// gösterilmez (sunucu zaten yalnızca enum kod döndürüyor).
  String _introText(L10n l) {
    final QuestionAnalysis? a = widget.analysis;
    if (a != null && a.ok) return l.confirmIntro;
    // KUYRUKTAN TAMAMLANAN KAYIT (Task 15). Analiz akışın dışında, `flush`
    // içinde yapıldığı için `analysis` burada `null` geliyor ve ekran
    // "Sınavı, dersi ve konuyu seç" diyordu — oysa üçü de DOLU geliyor ve
    // kullanıcıya kalan tek iş doğru şıkkı işaretlemek.
    if (_aiGaveOptions) return l.confirmIntro;
    return switch (a?.failure) {
      AnalysisFailure.unreadable => l.analysisReasonUnreadable,
      AnalysisFailure.noQuestion => l.analysisReasonNoQuestion,
      AnalysisFailure.noOptions => l.analysisReasonNoOptions,
      AnalysisFailure.network => l.analysisReasonNetwork,
      AnalysisFailure.ageRequired => l.analysisReasonAgeRequired,
      AnalysisFailure.unknown => l.analysisReasonUnknown,
      // Analiz hiç yapılmadı (elle giriş, iptal, kota) → eski genel metin.
      null => l.confirmIntroManual,
    };
  }

  Widget _classificationCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Column(
        children: <Widget>[
          // Sınav — iki değerli, doğrudan segment.
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
            child: Row(
              children: <Widget>[
                SizedBox(width: 64, child: Text(l.confirmExam, style: t.caption)),
                Expanded(
                  child: SegmentedTabs(
                    labels: const <String>['TYT', 'AYT'],
                    selectedIndex: _exam == 'AYT' ? 1 : 0,
                    onChanged: (int i) {
                      sound.tap();
                      setState(() {
                        _exam = i == 1 ? 'AYT' : 'TYT';
                        // Müfredat sınava göre değişiyor; eski seçim geçersiz.
                        _subject = null;
                        _concept = null;
                        _extras.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          // Ders — yerinde açılan çip satırı, modal yok.
          _row(
            context,
            label: l.confirmSubject,
            value: _subject,
            onTap: () => setState(() => _subjectOpen = !_subjectOpen),
          ),
          if (_subjectOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: <Widget>[
                  for (final String s in _subjects)
                    KimoChip(
                      label: s,
                      selected: s == _subject,
                      onTap: () {
                        sound.tap();
                        setState(() {
                          _subject = s;
                          _concept = null;
                          _extras.clear();
                          _subjectOpen = false;
                        });
                      },
                    ),
                ],
              ),
            ),
          Divider(height: 1, color: c.border),
          _row(
            context,
            label: l.confirmTopic,
            value: _concept,
            placeholder: l.confirmTopicPick,
            // DERS ZORUNLU DEĞİL: `showTopicPicker` dersi opsiyonel alıyor ve
            // boşken bütün derslerde arıyor (`_pickTopic`'in yorumu da bunu
            // söylüyor). Satır derse kilitliyken o arama yolunun KAPISI
            // kapalıydı: "atışlar" yazıp Fizik'e inme yolu vardı ama
            // kullanıcı oraya hiç ulaşamıyordu.
            onTap: () => _pickTopic(context),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String? value,
    String? placeholder,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.rowMin),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        child: Row(
          children: <Widget>[
            SizedBox(width: 64, child: Text(label, style: t.caption)),
            Expanded(
              child: Text(
                value ?? placeholder ?? '—',
                style: value == null
                    ? t.body.copyWith(color: c.inkMuted)
                    : t.label,
              ),
            ),
            if (onTap != null)
              KimoIcon(
                KimoIcons.back,
                size: 18,
                color: enabled ? c.inkMuted : c.border,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTopic(BuildContext context) async {
    sound.tap();
    // Ders ARTIK ZORUNLU DEĞİL: seçici tüm derslerde arıyor ve dersi de
    // kendisi döndürüyor. "atışlar" yazan kullanıcı Fizik'i hiç seçmeden
    // Fizik'in konusuna inebiliyor.
    final TopicPick? picked = await showTopicPicker(
      context,
      curriculum: userProfile.curriculum,
      exam: _exam,
      subject: _subject,
      selected: _concept,
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (picked.subject != _subject) {
        _subject = picked.subject;
        _extras.clear();   // ek konular dersle birlikte geçersizleşiyor
      }
      _concept = picked.topic;
    });
  }

  Widget _correctOptionCard(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ŞIK SAYISI YALNIZCA ELLE GİRİŞTE sorulur (Task 08 §5 + Task 15).
          // Elle girişte gerekli: dört şıklı bir soruda öğrenci olmayan bir E
          // şıkkını işaretleyip kaydedebiliyordu. Ama yapay zekâ şıkları
          // çıkardıysa sayı ZATEN biliniyor ve doğru çip önceden seçili
          // geliyordu — yani cevabı işaretlenmiş bir soru soruluyordu.
          // Üstelik çipe dokunmak AI'nın etiketlerini A–E ile değiştirip
          // doğru şık işaretini sessizce düşürüyordu.
          if (!_aiGaveOptions) ...<Widget>[
            Text(l.confirmOptionCount, style: t.caption),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              children: <Widget>[
                for (final int n in _optionCounts)
                  KimoChip(
                    label: l.confirmOptionCountValue(n),
                    selected: _labels.length == n,
                    onTap: () => _setOptionCount(n),
                  ),
              ],
            ),
            const SizedBox(height: Gap.lg),
          ],
          Text(l.confirmCorrectOption, style: t.caption),
          const SizedBox(height: Gap.md),
          Row(
            children: <Widget>[
              for (int i = 0; i < _labels.length; i++) ...<Widget>[
                Expanded(
                  child: _optionButton(context, i),
                ),
                if (i != _labels.length - 1) const SizedBox(width: Gap.sm),
              ],
            ],
          ),
          if (_correctIndex == null) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Text(
              l.confirmNeedCorrect,
              style: t.caption.copyWith(color: c.actionText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionButton(BuildContext context, int index) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    final bool selected = _correctIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        sound.tap();
        setState(() => _correctIndex = index);
      },
      child: AnimatedContainer(
        duration: Motion.press,
        height: Sizes.rowMin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.mint : c.sunken,
          borderRadius: Radii.all(Radii.pill),
        ),
        child: Text(
          _labels[index],
          style: t.numberMedium.copyWith(
            color: selected ? c.onAction : c.inkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _reasonCard(BuildContext context, L10n l) {
    final KimoTypography t = context.t;
    final KimoColors c = context.c;
    return KimoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(l.confirmWhyWrong, style: t.bodyStrong),
              const SizedBox(width: Gap.xs),
              Text(
                l.confirmOptional,
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: <Widget>[
              for (final MistakeType type in MistakeType.choices)
                KimoChip(
                  label: type.label,
                  selected: _type == type,
                  onTap: () {
                    sound.tap();
                    // İkinci dokunuş seçimi kaldırıyor: alan isteğe bağlı ve
                    // yanlışlıkla seçilen bir sebep geri alınabilmeli.
                    setState(() => _type = _type == type ? null : type);
                  },
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          // NOT ALANI ARTIK GERÇEK (Task 08). Controller tanımlıydı, dispose
          // ediliyordu, `_save` içinde okunuyordu — ama hiçbir TextField'a
          // bağlı değildi, yani `note` her kayıtta boş gidiyordu. Fotoğrafsız
          // bir soruda pratik ekranının gösterebildiği TEK içerik bu.
          Text(l.confirmNoteLabel, style: t.caption),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: t.body,
            decoration: InputDecoration(
              hintText: l.confirmNoteHint,
              filled: true,
              fillColor: c.sunken,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: Radii.all(Radii.tile),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context, L10n l) {
    final KimoColors c = context.c;
    final KimoTypography t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Gap.screen, Gap.md, Gap.screen, Gap.md),
      decoration: BoxDecoration(
        color: c.page,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KimoButton(
            label: l.confirmSave,
            busy: _saving,
            onPressed: _canSave ? _save : null,
          ),
          if (_canWaitForAnalysis) ...<Widget>[
            const SizedBox(height: Gap.sm),
            KimoButton(
              label: l.confirmWaitAnalysis,
              kind: KimoButtonKind.secondary,
              onPressed: _waitForAnalysis,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              l.confirmWaitAnalysisBody,
              style: t.caption.copyWith(color: c.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: Gap.sm),
          Text(
            // SIRA ÖNEMLİ: `_saving` en başta. `_canSave` zaten `!_saving`
            // içerdiği için eski merdiven, kayıt sürerken ders+konu doluysa
            // "Doğru şıkkı işaretle" yazıyordu — kullanıcı az önce
            // işaretlemişken. Kayıt boyunca görünen TEK geri bildirim buydu
            // ve yanlıştı.
            _saving
                ? l.confirmSaving
                : _canSave
                    // İLK TEKRAR AYNI GÜN, ~3 SAAT SONRA. Sunucu tetikleyicisi
                    // (`mistakes_review_timing`, 0033) yeni kayda
                    // `now() + interval '3 hours'` yazıyor; merdivenin 1 günlük
                    // ilk adımı ikinci tekrardan itibaren işliyor. Metin "yarın"
                    // diyordu, yani ürünün tuttuğundan farklı bir söz veriyordu.
                    ? l.confirmNextReview
                    // EKSİK OLAN NE İSE O YAZIYOR. Tek bir "Önce ders ve konu
                    // seç" cümlesi vardı; ders satırında koca bir "Matematik"
                    // dururken bu cümle okunmuyor, kullanıcı doğru şıkkı
                    // işaretlemiş olmasına rağmen düğmenin neden kapalı
                    // olduğunu göremiyordu.
                    : (_subject == null && _concept == null)
                        ? l.confirmNeedTopic
                        : _subject == null
                            ? l.confirmNeedSubject
                            : _concept == null
                                ? l.confirmNeedConcept
                                : l.confirmNeedCorrect,
            style: t.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
