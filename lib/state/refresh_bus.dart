import 'package:flutter/foundation.dart';

/// Sekmeler [IndexedStack] ile canlı tutulduğu için ekranlar yalnızca ilk
/// açılışta veri yükler. Kullanıcı bir sekmeye döndüğünde bu otobüs "tazele"
/// sinyali yayınlar; ekranlar dinleyip kendilerini günceller.
class RefreshBus extends ChangeNotifier {
  RefreshBus._();
  static final RefreshBus instance = RefreshBus._();

  void ping() => notifyListeners();
}

final RefreshBus refreshBus = RefreshBus.instance;
