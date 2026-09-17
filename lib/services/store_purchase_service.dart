import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/plus/plus_plans.dart';
import 'crash_service.dart';
import 'purchase_service.dart';

/// `PurchaseService`in mağazaya bağlanan gerçeklemesi.
///
/// Task 13'te katmanın TAMAMI yazılmış ama eklenti eklenememişti (`pubspec.lock`
/// üretilemiyordu). Bu dosya o boşluğu dolduruyor ve **uygulamanın geri kalanı
/// değişmiyor**: paywall hâlâ `PurchaseService` soyutlamasını görüyor.
///
/// ================== İSTEMCİ HİÇBİR ŞEY İDDİA ETMİYOR =====================
///
/// Satın alma tamamlandığında bu sınıf premium'u AÇMIYOR. Yaptığı tek şey
/// mağazanın verdiği jetonu `verify-purchase` edge fonksiyonuna götürmek;
/// katman `profiles.premium_until` → `user_tier()` → `my_daily_state.ai_tier`
/// zincirinden geliyor. `apply_subscription` RPC'si `authenticated`'a KAPALI
/// (göç 0092), yani istemci kendine abonelik yazamaz — bu sınıf bozulsa bile.
///
/// ====================== SIRA: DOĞRULA, SONRA TAMAMLA ======================
///
/// `completePurchase` YALNIZCA sunucu doğrulaması başarılı olduktan sonra
/// çağrılıyor. Tersi sırada, doğrulama düşerse mağaza işlemi "tamamlandı"
/// sayar ve kullanıcı parayı ödeyip hak alamaz — geri dönüşü olmayan bir
/// durum. Google ayrıca **üç gün içinde** onaylanmayan satın almayı İADE
/// ediyor, yani doğrulama kalıcı olarak düşerse para kullanıcıya geri gidiyor;
/// bu kabul edilebilir, "para alındı hak yok" değil.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService._();

  static final StorePurchaseService instance = StorePurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Akış dinleyicisi uygulama açılışında kuruluyor: satın alma uygulama
  /// kapalıyken tamamlanmış olabilir (Play'de "beklemede" ödeme, App Store'da
  /// aile onayı) ve o durumda mağaza sonucu bir sonraki açılışta veriyor.
  void start() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e, StackTrace s) =>
          unawaited(reportError(e, s, context: 'purchaseStream')),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  Future<List<PlusPlan>> products() async {
    try {
      if (!await _iap.isAvailable()) return const <PlusPlan>[];
      final ProductDetailsResponse res =
          await _iap.queryProductDetails(PlusPlans.productIds.toSet());
      if (res.error != null) {
        debugPrint('ürün sorgusu: ${res.error}');
      }
      if (res.notFoundIDs.isNotEmpty) {
        // MAĞAZADA TANIMLI DEĞİL. Bugünkü beklenen durum: ürünler App Store
        // Connect / Play Console'da henüz oluşturulmadı (hesap yok). Sessiz
        // kalmıyoruz ama akışı da durdurmuyoruz — boş liste `isConfigured`i
        // false bırakıyor ve paywall dürüst hâlinde kalıyor.
        debugPrint('mağazada bulunamayan ürün: ${res.notFoundIDs}');
      }
      // ROZET İKİ FİYATA BİRDEN İHTİYAÇ DUYUYOR, bu yüzden tek turda
      // hesaplanıyor: aylık plan sorgudan gelmediyse yüzde HİÇ çizilmiyor —
      // uydurma bir avantaj göstermektense hiç göstermemek doğru.
      final Iterable<ProductDetails> monthly = res.productDetails
          .where((ProductDetails p) => p.id == PlusPlans.monthlyId);
      final double? monthlyRaw =
          monthly.isEmpty ? null : monthly.first.rawPrice;
      return <PlusPlan>[
        for (final ProductDetails p in res.productDetails)
          _toPlan(p, monthlyRaw),
      ];
    } catch (e, s) {
      unawaited(reportError(e, s, context: 'products'));
      return const <PlusPlan>[];
    }
  }

  /// `ProductDetails` → `PlusPlan`.
  ///
  /// `priceLabel` MAĞAZANIN yerelleştirilmiş metni (`ProductDetails.price`),
  /// bizim biçimlediğimiz bir sayı DEĞİL — Apple 3.1.2 ve Play abonelik
  /// politikasının şartı bu.
  ///
  /// `perMonthLabel` yıllık planda TÜRETİLİYOR: `rawPrice / 12`, mağazanın
  /// para birimi simgesiyle. Tam biçimlendirme yerelden yereldere değişiyor
  /// ama burada gösterilen şey bir KIYAS ipucu, tahsil edilecek tutar değil —
  /// tahsil edilecek tutar `priceLabel`.
  PlusPlan _toPlan(ProductDetails p, double? monthlyRaw) {
    final bool yearly = p.id == PlusPlans.yearlyId;
    if (!yearly) {
      return PlusPlan(
        id: p.id,
        priceLabel: p.price,
        perMonthLabel: p.price,
      );
    }
    final double perMonth = p.rawPrice / 12;
    return PlusPlan(
      id: p.id,
      priceLabel: p.price,
      perMonthLabel: '${p.currencySymbol}${perMonth.toStringAsFixed(2)}',
      savingPercent: _savingPercent(p.rawPrice, monthlyRaw),
    );
  }

  /// "%N AVANTAJ" rozeti — MAĞAZADAN gelen iki fiyattan hesaplanıyor, koda
  /// gömülü değil. Aylık fiyat yoksa ya da yıllık avantajlı değilse `null`.
  int? _savingPercent(double yearlyRaw, double? monthlyRaw) {
    if (monthlyRaw == null || monthlyRaw <= 0 || yearlyRaw <= 0) return null;
    final double saving = 1 - (yearlyRaw / (monthlyRaw * 12));
    if (saving <= 0) return null;
    return (saving * 100).round();
  }

  @override
  Future<bool> buy(PlusPlan plan) async {
    try {
      final ProductDetailsResponse res =
          await _iap.queryProductDetails(<String>{plan.id});
      // `firstOrNull` KULLANILMIYOR: o `package:collection`dan geliyor ve bu
      // depoda doğrudan bağımlılık değil — geçişli bir dışa aktarıma yaslanmak
      // bir gün sessizce kırılır.
      if (res.productDetails.isEmpty) return false;
      final ProductDetails details = res.productDetails.first;
      // ABONELİK `buyNonConsumable` İLE ALINIYOR: `buyConsumable` tüketilebilir
      // ürünler için ve otomatik tüketim aboneliği bozar.
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } catch (e, s) {
      unawaited(reportError(e, s, context: 'buy'));
      return false;
    }
  }

  @override
  Future<bool> restore() async {
    try {
      // Sonuç `purchaseStream`den `PurchaseStatus.restored` olarak geliyor ve
      // oradan doğrulamaya gidiyor. Burada `true` dönmek "geri yüklendi"
      // demek DEĞİL, "istek gönderildi" demek — katmanı sunucu açıyor.
      await _iap.restorePurchases();
      return true;
    } catch (e, s) {
      unawaited(reportError(e, s, context: 'restore'));
      return false;
    }
  }

  @override
  Uri? manageUri() {
    if (kIsWeb) return null;
    if (Platform.isIOS) {
      return Uri.parse('https://apps.apple.com/account/subscriptions');
    }
    if (Platform.isAndroid) {
      // Paket adı olmadan Play genel abonelik listesini açıyor; ürün kimliği
      // ile doğrudan bu aboneliğe gidiyor.
      return Uri.parse(
        'https://play.google.com/store/account/subscriptions'
        '?package=com.stratejico.kimo',
      );
    }
    return null;
  }

  // ------------------------------------------------------------ akış
  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          // Play'de banka onayı bekleyen ödeme. Hiçbir şey yapmıyoruz;
          // sonuç aynı akıştan gelecek.
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          if (p.status == PurchaseStatus.error) {
            debugPrint('satın alma hatası: ${p.error}');
          }
          // Mağaza işlemi kapatılmalı, yoksa akış her açılışta tekrar veriyor.
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final bool ok = await _verify(p);
          // DOĞRULAMA DÜŞTÜYSE TAMAMLAMIYORUZ: mağaza yeniden teslim etsin.
          // Play üç gün içinde onaylanmayanı iade ediyor — yani kalıcı
          // başarısızlıkta para kullanıcıya dönüyor.
          if (ok && p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
      }
    }
  }

  /// Jetonu sunucuya götürür. `true` = sunucu aboneliği yazdı.
  Future<bool> _verify(PurchaseDetails p) async {
    try {
      // JETONUN ANLAMI PLATFORMA GÖRE DEĞİŞİYOR:
      //   * Android → `serverVerificationData` = Play `purchaseToken`.
      //   * iOS     → `purchaseID` = StoreKit işlem kimliği. Apple'ın
      //     "Get All Subscription Statuses" uç noktası yoldaki değer olarak
      //     aboneliğin HERHANGİ bir işlem kimliğini kabul ediyor, yani
      //     `originalTransactionId` şart değil.
      final bool ios = !kIsWeb && Platform.isIOS;
      final String token =
          ios ? (p.purchaseID ?? '') : p.verificationData.serverVerificationData;
      if (token.isEmpty) return false;

      return await _invokeVerify(ios ? 'ios' : 'android', token);
    } on FunctionException catch (e, s) {
      // 401 = JETON HÂLÂ "ANONİM" DİYOR (Task 17 · T17-7).
      //
      // `verify-purchase` kimi yazacağını JWT'den okuyor ve anonim kullanıcıyı
      // reddediyor — doğru karar, çünkü anonim biri abone olsa bile
      // `user_tier()` onu `anonymous` sayardı (para alınır, hak verilmezdi).
      // Ama `convertToPermanent` (kayıt adımı) `auth.users`ı GÜNCELLİYOR,
      // jetonu yeniden üretmiyor: kaydını yeni tamamlamış kullanıcının
      // jetonunda `is_anonymous` bir SONRAKİ yenilemeye kadar (en kötü
      // durumda ~1 saat) true kalıyor. Yani "kaydol, hemen Plus al" akışı
      // sessizce düşüyordu.
      //
      // Asıl düzeltme kayıt adımında (`AuthRepository.convertToPermanent`
      // artık jetonu tazeliyor); buradaki tek seferlik yeniden deneme o
      // tazeleme başarısız olduysa (çevrimdışı, zaman aşımı) ikinci şans.
      // PARA ÖDENDİ: sessizce pes etmek en pahalı dal.
      if (e.status == 401) {
        try {
          await Supabase.instance.client.auth.refreshSession();
          final bool ios = !kIsWeb && Platform.isIOS;
          final String token = ios
              ? (p.purchaseID ?? '')
              : p.verificationData.serverVerificationData;
          return await _invokeVerify(ios ? 'ios' : 'android', token);
        } catch (e2, s2) {
          unawaited(reportError(e2, s2, context: 'verify-purchase.retry'));
          return false;
        }
      }
      unawaited(reportError(e, s, context: 'verify-purchase'));
      return false;
    } catch (e, s) {
      unawaited(reportError(e, s, context: 'verify-purchase'));
      return false;
    }
  }

  Future<bool> _invokeVerify(String platform, String token) async {
    final FunctionResponse res = await Supabase.instance.client.functions.invoke(
      'verify-purchase',
      body: <String, dynamic>{'platform': platform, 'token': token},
    );
    return res.status == 200;
  }
}
