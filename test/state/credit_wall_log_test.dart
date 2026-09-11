import 'package:flutter_test/flutter_test.dart';
import 'package:kimo/state/credit_wall_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Haftalık duvar sayacı.
///
/// Hafta anahtarı SUNUCUNUN `week_start`'ı; bu dosya `DateTime.now()`
/// çağırmıyor ve testler de onu kurmuyor — saatini ileri alan bir kullanıcı
/// sayacı sıfırlayamamalı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  });

  final DateTime week1 = DateTime(2026, 9, 7);
  final DateTime week2 = DateTime(2026, 9, 14);

  test('her varışta bir artıyor', () async {
    expect(await creditWallLog.bump(week1), 1);
    expect(await creditWallLog.bump(week1), 2);
    expect(await creditWallLog.bump(week1), 3);
  });

  test('okuma artırmıyor', () async {
    await creditWallLog.bump(week1);
    expect(await creditWallLog.read(week1), 1);
    expect(await creditWallLog.read(week1), 1);
  });

  test('hafta değişince SIFIRLANIYOR', () async {
    await creditWallLog.bump(week1);
    await creditWallLog.bump(week1);
    expect(await creditWallLog.bump(week2), 1);
  });

  test('eski haftanın sayısı okunmuyor', () async {
    await creditWallLog.bump(week1);
    expect(await creditWallLog.read(week2), 0);
  });

  test('hafta okunamadıysa (null) artırmıyor — nazik w1 tarafına düşüyor',
      () async {
    expect(await creditWallLog.bump(null), 0);
    expect(await creditWallLog.read(null), 0);
    // Ve gerçek bir haftada sayaç hâlâ 1'den başlıyor: null çağrı bir şey
    // yazmamış olmalı.
    expect(await creditWallLog.bump(week1), 1);
  });

  test('promoteAt eşiği ikinci çarpma', () {
    expect(CreditWallLog.promoteAt, 2);
  });
}
