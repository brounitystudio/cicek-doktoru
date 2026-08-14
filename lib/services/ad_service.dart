import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';
import 'entitlement_service.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialized = false;
  RewardedAd? _rewardedAd;
  Timer? _delayedInterstitialTimer;

  static const _launchDateKey = 'ad_launch_date';
  static const _launchCountKey = 'ad_launch_count';
  static const _interstitialShownDateKey = 'ad_interstitial_shown_date';
  static const _diagnosisInterstitialCountKey =
      'ad_diagnosis_interstitial_count';
  static const _diagnosisInterstitialLastMsKey =
      'ad_diagnosis_interstitial_last_ms';

  Future<void> initialize() async {
    if (AdConfig.screenshotsDisableAds) {
      return;
    }
    if (_initialized) {
      return;
    }
    await MobileAds.instance.initialize();
    _initialized = true;
    unawaited(loadRewardedAd().catchError((_) {}));
  }

  Future<void> scheduleDelayedDailyInterstitial() async {
    if (AdConfig.screenshotsDisableAds) {
      return;
    }
    if (_delayedInterstitialTimer != null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final storedDate = prefs.getString(_launchDateKey);
    final launchCount = storedDate == today
        ? prefs.getInt(_launchCountKey) ?? 0
        : 0;
    final updatedLaunchCount = launchCount + 1;

    await prefs.setString(_launchDateKey, today);
    await prefs.setInt(_launchCountKey, updatedLaunchCount);

    if (updatedLaunchCount < 2 ||
        prefs.getString(_interstitialShownDateKey) == today) {
      return;
    }

    final plan = await EntitlementService().getCurrentPlan();
    if (plan.adsDisabled) {
      return;
    }

    _delayedInterstitialTimer = Timer(const Duration(seconds: 45), () {
      unawaited(_showDelayedInterstitialForToday(today));
    });
  }

  Future<void> loadRewardedAd() async {
    if (AdConfig.screenshotsDisableAds) {
      return;
    }
    await initialize();
    final completer = Completer<void>();
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedDiagnosisCreditAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          completer.completeError(
            const AdException(
              'Reklam şu an hazır değil, birazdan tekrar dene.',
            ),
          );
        },
      ),
    );
    return completer.future;
  }

  Future<int> showRewardedForDiagnosisCredit() async {
    if (AdConfig.screenshotsDisableAds) {
      throw const AdException('Reklam ekran görüntüsü modunda kapalı.');
    }
    await initialize();
    if (_rewardedAd == null) {
      await loadRewardedAd();
    }

    final ad = _rewardedAd;
    if (ad == null) {
      throw const AdException(
        'Reklam şu an hazır değil, birazdan tekrar dene.',
      );
    }

    _rewardedAd = null;
    final completer = Completer<int>();
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(loadRewardedAd().catchError((_) {}));
        if (!earnedReward && !completer.isCompleted) {
          completer.completeError(const AdException('Reklam tamamlanmadı.'));
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(loadRewardedAd().catchError((_) {}));
        if (!completer.isCompleted) {
          completer.completeError(
            const AdException('Reklam şu an açılamadı, birazdan tekrar dene.'),
          );
        }
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) async {
        earnedReward = true;
        try {
          final credits = await EntitlementService().grantRewardCredit();
          if (!completer.isCompleted) {
            completer.complete(credits);
          }
        } catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        }
      },
    );

    return completer.future;
  }

  Future<void> showInterstitialAfterDiagnosisIfNeeded() async {
    if (AdConfig.screenshotsDisableAds) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }

    final plan = await EntitlementService().getCurrentPlan();
    if (plan.adsDisabled) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_diagnosisInterstitialCountKey) ?? 0) + 1;
    await prefs.setInt(_diagnosisInterstitialCountKey, count);

    if (count % 3 != 0) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastShownMs = prefs.getInt(_diagnosisInterstitialLastMsKey) ?? 0;
    if (nowMs - lastShownMs < const Duration(minutes: 3).inMilliseconds) {
      return;
    }

    await initialize();
    final completer = Completer<void>();
    await InterstitialAd.load(
      adUnitId: AdConfig.delayedInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, error) => ad.dispose(),
          );
          unawaited(prefs.setInt(_diagnosisInterstitialLastMsKey, nowMs));
          unawaited(ad.show());
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  Future<void> _showDelayedInterstitialForToday(String today) async {
    if (AdConfig.screenshotsDisableAds) {
      return;
    }
    _delayedInterstitialTimer = null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_interstitialShownDateKey) == today) {
      return;
    }

    final plan = await EntitlementService().getCurrentPlan();
    if (plan.adsDisabled) {
      return;
    }

    await initialize();
    final completer = Completer<void>();
    await InterstitialAd.load(
      adUnitId: AdConfig.delayedInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, error) => ad.dispose(),
          );
          unawaited(prefs.setString(_interstitialShownDateKey, today));
          unawaited(ad.show());
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}

class AdException implements Exception {
  const AdException(this.message);

  final String message;

  @override
  String toString() => message;
}
