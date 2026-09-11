import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../crash_service.dart';
import 'ad_service.dart';
import 'ads_config.dart';

/// Ödüllü reklamın Android/iOS uygulaması. `google_mobile_ads`'i import eden
/// TEK dosya.
///
/// YAŞ VE İÇERİK AYARLARI (hedef kitle 13-18):
///   * `maxAdContentRating: G` — en kısıtlı içerik derecesi.
///   * `ageRestrictedTreatment: teen` — ürünün kitlesi tam olarak bu.
///     `child` YANLIŞ olurdu: uygulama 13 YAŞ VE ÜZERİ için ve 13 altını
///     hedeflemiyor (COPPA 13 altı için geçerli). `unspecified` de yanlış
///     olurdu: kullanıcıların çoğu reşit değil.
///     NOT: eski `tagForUnderAgeOfConsent`/`tagForChildDirectedTreatment`
///     çifti `google_mobile_ads` 9.x'te KULLANIMDAN KALDIRILDI; tek alan
///     olan `ageRestrictedTreatment` onların yerini aldı.
///   * İstekte `npa=1`: kişiselleştirme açıkça kapalı.
/// Android manifest'inde `AD_ID` izni `tools:node="remove"` ile düşürüldü,
/// iOS'ta ATT hiç çağrılmıyor — yani reklam kimliği toplanmıyor ve mağaza
/// formlarındaki "Reklam kimliği: Hayır" cevabı doğru kalıyor.
class MobileAdService implements AdService {
  MobileAdService();

  RewardedAd? _ad;
  bool _loading = false;
  bool _initialized = false;

  @override
  bool get supported {
    // `kIsWeb` ÖNCE KONTROL EDİLMEK ZORUNDA: web'de `defaultTargetPlatform`
    // ANA MAKİNEYE BENZER platformu bildiriyor (Android tarayıcısında
    // `android`), yani yalnız onu kontrol etmek desteği YANLIŞ iddia eder.
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  bool get isReady => _ad != null;

  @override
  Future<void> init() async {
    if (_initialized || !supported || !AdsConfig.isConfigured) return;
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.g,
          ageRestrictedTreatment: AgeRestrictedTreatment.teen,
          // Boş liste = üretim davranışı; hiçbir şey değişmez.
          // Doluysa o cihazlar GERÇEK birim kimliğiyle ama TEST reklamı alır —
          // geliştirme sırasında canlı reklam istemenin tek meşru yolu bu.
          testDeviceIds: AdsConfig.testDeviceIds,
        ),
      );
      _initialized = true;
    } catch (e, st) {
      // Reklam SDK'sı açılmazsa uygulama NORMAL çalışmalı: reklam yolu
      // sessizce yok olur. `main.dart`'taki hiçbir hazırlık adımı `runApp`'i
      // bloklayamaz kuralının aynısı.
      await reportError(e, st, context: 'MobileAds.init');
    }
  }

  @override
  Future<void> preload() async {
    if (!_initialized || _loading || _ad != null) return;
    if (!AdsConfig.isConfigured) return;
    _loading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdsConfig.rewardedUnitId,
        // KİŞİSELLEŞTİRME KAPALI: `npa=1` her istekte açıkça gidiyor.
        request: const AdRequest(extras: <String, String>{'npa': '1'}),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _ad = ad;
            _loading = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            // DOLULUK %100 DEĞİL ve bu normal. Kullanıcıya HİÇBİR ŞEY
            // gösterilmiyor; duvar reklam satırını çizmiyor, o kadar.
            //
            // AMA "doluluk yok" ile "yapılandırma bozuk" ayrı şeyler ve ikisi
            // de kullanıcıya AYNI görünüyor: duvarda reklam satırı yok.
            // Hepsini debugPrint'e yazmak, ekibin yanlış yerde (SSV ya da
            // AD_REWARD_SECRET) hata aramasına yol açıyordu. Doluluk yok
            // sessiz kalır; GERİ KALAN HER ŞEY raporlanır.
            //
            // code 3 = ERROR_CODE_NO_FILL (envanter yok — olağan).
            // 0 dahili · 1 geçersiz istek (yanlış birim kimliği!) · 2 ağ.
            const int noFill = 3;
            if (error.code == noFill) {
              debugPrint('ödüllü reklam: doluluk yok');
            } else {
              unawaited(reportError(
                StateError('ödüllü reklam yüklenemedi: '
                    'code=${error.code} domain=${error.domain} '
                    '${error.message}'),
                StackTrace.current,
                context: 'RewardedAd.load',
              ));
            }
            _ad = null;
            _loading = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('ödüllü reklam yükleme çağrısı başarısız: $e');
      _ad = null;
      _loading = false;
    }
  }

  @override
  Future<AdOutcome> showRewarded({required String nonce}) async {
    final RewardedAd? ad = _ad;
    if (ad == null) return AdOutcome.notReady;
    _ad = null; // bir reklam bir kez gösterilir

    // SUNUCU TARAFI DOĞRULAMA BAĞI. `customData` sunucunun ürettiği nonce;
    // ödülün kime yazılacağını bu belirliyor.
    //
    // `userId` BİLEREK NONCE: Supabase kullanıcı kimliği reklam ağına HİÇ
    // gönderilmiyor. Ham bir uid, hukuki metinlerde sayılması gereken yeni
    // bir veri paylaşımı olurdu; nonce zaten takma ve hiçbir şey söylemiyor.
    await ad.setServerSideOptions(
      ServerSideVerificationOptions(customData: nonce, userId: nonce),
    );

    bool earned = false;
    final Completer<AdOutcome> done = Completer<AdOutcome>();

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd a) {
        a.dispose();
        if (!done.isCompleted) {
          done.complete(earned ? AdOutcome.earned : AdOutcome.dismissed);
        }
        unawaited(preload()); // sonraki duvar için ısıt
      },
      onAdFailedToShowFullScreenContent: (RewardedAd a, AdError e) {
        a.dispose();
        debugPrint('ödüllü reklam gösterilemedi: ${e.code}');
        if (!done.isCompleted) done.complete(AdOutcome.failed);
        unawaited(preload());
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView _, RewardItem _) {
          // BU BİR KANIT DEĞİL. İstemci tarafı bir bildirim; hak yalnızca
          // Google'ın imzalı geri çağrısıyla veriliyor. Burada hiçbir sayaç
          // artırılmıyor.
          earned = true;
        },
      );
    } catch (e) {
      debugPrint('ödüllü reklam show() başarısız: $e');
      if (!done.isCompleted) done.complete(AdOutcome.failed);
    }
    return done.future;
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

AdService createAdService() => MobileAdService();
