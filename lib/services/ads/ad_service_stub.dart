import 'ad_service.dart';

/// Reklamların mümkün OLMADIĞI hedefler: web, masaüstü ve testler.
///
/// `google_mobile_ads`'in web uygulaması YOK (paket yalnızca Android ve iOS
/// bildiriyor) ve bu depoda bir `web/` dizini var, yani bu varsayımsal değil.
/// Stub hiçbir şey yapmıyor ve [supported] `false` döndürüyor; duvar reklam
/// satırını hiç çizmiyor.
class StubAdService implements AdService {
  const StubAdService();

  @override
  bool get supported => false;

  @override
  bool get isReady => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> preload() async {}

  @override
  Future<AdOutcome> showRewarded({required String nonce}) async =>
      AdOutcome.notReady;

  @override
  void dispose() {}
}

AdService createAdService() => const StubAdService();
