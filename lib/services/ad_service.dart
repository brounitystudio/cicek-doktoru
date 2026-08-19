import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_plan.dart';
import 'ad_config.dart';
import 'analytics_service.dart';
import 'entitlement_service.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialized = false;
  Future<bool>? _initializationFuture;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;
  DateTime? _backgroundedAt;
  bool _appOpenLoadInProgress = false;
  bool _isShowingAppOpen = false;
  bool _isShowingFullScreenAd = false;
  Timer? _delayedInterstitialTimer;
  Timer? _launchAppOpenTimer;

  static const _launchDateKey = 'ad_launch_date';
  static const _launchCountKey = 'ad_launch_count';
  static const _interstitialShownDateKey = 'ad_interstitial_shown_date';
  static const _diagnosisInterstitialCountKey =
      'ad_diagnosis_interstitial_count';
  static const _diagnosisInterstitialLastMsKey =
      'ad_diagnosis_interstitial_last_ms';
  static const _authenticatedLaunchCountKey = 'ad_authenticated_launch_count';
  static const _appOpenShownDateKey = 'ad_app_open_shown_date';
  static const _lastFullScreenShownMsKey = 'ad_last_fullscreen_shown_ms';
  static const _minimumAppOpenLaunchCount = 2;
  static const _minimumBackgroundDuration = Duration(minutes: 2);
  static const _maximumAppOpenCacheDuration = Duration(hours: 4);
  static const _minimumFullScreenInterval = Duration(minutes: 2);

  Future<bool> initialize() async {
    final pending = _initializationFuture;
    if (pending != null) {
      return pending;
    }
    final future = _initialize();
    _initializationFuture = future;
    try {
      final initialized = await future;
      if (!initialized) {
        _initializationFuture = null;
      }
      return initialized;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<bool> _initialize() async {
    if (AdConfig.adsDisabled) {
      return false;
    }
    if (_initialized) {
      return true;
    }
    if (!await _requestConsentAndCheckAdEligibility()) {
      return false;
    }
    await MobileAds.instance.initialize();
    _initialized = true;
    unawaited(loadRewardedAd().catchError((_) {}));
    unawaited(loadAppOpenAd().catchError((_) {}));
    return true;
  }

  Future<bool> _requestConsentAndCheckAdEligibility() async {
    final completer = Completer<bool>();

    Future<void> finish() async {
      if (!completer.isCompleted) {
        completer.complete(await ConsentInformation.instance.canRequestAds());
      }
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          unawaited(finish());
        });
      },
      (_) => unawaited(finish()),
    );

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => false,
    );
  }

  Future<bool> isPrivacyOptionsRequired() async {
    if (AdConfig.adsDisabled) {
      return false;
    }
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptionsForm() async {
    if (AdConfig.adsDisabled) {
      return;
    }
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  Future<void> registerAuthenticatedLaunchAndScheduleAds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_authenticatedLaunchCountKey) ?? 0;
    await prefs.setInt(_authenticatedLaunchCountKey, count + 1);
    if (!await initialize()) {
      return;
    }
    unawaited(_scheduleAppOpenOnLaunch());
    unawaited(scheduleDelayedDailyInterstitial());
  }

  Future<void> _scheduleAppOpenOnLaunch() async {
    if (!AdConfig.appOpenAdsSupported || _launchAppOpenTimer != null) {
      return;
    }
    final completer = Completer<void>();
    _launchAppOpenTimer = Timer(const Duration(seconds: 4), () {
      _launchAppOpenTimer = null;
      unawaited(
        _showAppOpenIfEligible(placement: 'uygulama_acilisi').whenComplete(() {
          if (!completer.isCompleted) completer.complete();
        }),
      );
    });
    return completer.future;
  }

  void markAppBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  Future<void> showAppOpenOnForegroundIfEligible() async {
    if (AdConfig.adsDisabled ||
        !AdConfig.appOpenAdsSupported ||
        _isShowingAppOpen) {
      return;
    }
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null ||
        DateTime.now().difference(backgroundedAt) <
            _minimumBackgroundDuration) {
      return;
    }

    await _showAppOpenIfEligible(placement: 'arka_plandan_donus');
  }

  Future<void> _showAppOpenIfEligible({required String placement}) async {
    if (AdConfig.adsDisabled ||
        !AdConfig.appOpenAdsSupported ||
        _isShowingAppOpen ||
        _isShowingFullScreenAd) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }
    late final UserPlan plan;
    try {
      plan = await EntitlementService().getCurrentPlan();
    } catch (_) {
      return;
    }
    if (plan.adsDisabled) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(_authenticatedLaunchCountKey) ?? 0) <
            _minimumAppOpenLaunchCount ||
        prefs.getString(_appOpenShownDateKey) == _todayKey()) {
      return;
    }
    if (!_canShowFullScreen(prefs)) {
      return;
    }

    final loadedAt = _appOpenLoadedAt;
    if (loadedAt == null ||
        DateTime.now().difference(loadedAt) > _maximumAppOpenCacheDuration) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadedAt = null;
    }
    if (_appOpenAd == null) {
      await loadAppOpenAd();
      return;
    }

    final ad = _appOpenAd!;
    _appOpenAd = null;
    _appOpenLoadedAt = null;
    _isShowingAppOpen = true;
    _isShowingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        unawaited(prefs.setString(_appOpenShownDateKey, _todayKey()));
        unawaited(_recordFullScreenShown(prefs));
        unawaited(_logAdEvent('gosterildi', 'app_open', placement));
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAppOpen = false;
        _isShowingFullScreenAd = false;
        ad.dispose();
        unawaited(_logAdEvent('kapatildi', 'app_open', placement));
        unawaited(loadAppOpenAd().catchError((_) {}));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpen = false;
        _isShowingFullScreenAd = false;
        ad.dispose();
        unawaited(
          _logAdEvent(
            'basarisiz',
            'app_open',
            placement,
            errorCode: error.code,
          ),
        );
        unawaited(loadAppOpenAd().catchError((_) {}));
      },
    );
    await ad.show();
  }

  Future<void> loadAppOpenAd() async {
    if (AdConfig.adsDisabled ||
        !AdConfig.appOpenAdsSupported ||
        _appOpenLoadInProgress ||
        _appOpenAd != null) {
      return;
    }
    if (!await initialize()) {
      return;
    }
    _appOpenLoadInProgress = true;
    final completer = Completer<void>();
    unawaited(_logAdEvent('istegi', 'app_open', 'on_yukleme'));
    await AppOpenAd.load(
      adUnitId: AdConfig.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadedAt = DateTime.now();
          _appOpenLoadInProgress = false;
          unawaited(_logAdEvent('yuklendi', 'app_open', 'on_yukleme'));
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _appOpenLoadedAt = null;
          _appOpenLoadInProgress = false;
          unawaited(
            _logAdEvent(
              'basarisiz',
              'app_open',
              'on_yukleme',
              errorCode: error.code,
            ),
          );
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  Future<void> scheduleDelayedDailyInterstitial() async {
    if (AdConfig.adsDisabled) {
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

    late final UserPlan plan;
    try {
      plan = await EntitlementService().getCurrentPlan();
    } catch (_) {
      return;
    }
    if (plan.adsDisabled) {
      return;
    }

    _delayedInterstitialTimer = Timer(const Duration(seconds: 45), () {
      unawaited(_showDelayedInterstitialForToday(today));
    });
  }

  Future<void> loadRewardedAd() async {
    if (AdConfig.adsDisabled) {
      return;
    }
    if (!await initialize()) {
      throw const AdException('Reklam izni henüz hazır değil.');
    }
    final completer = Completer<void>();
    unawaited(_logAdEvent('istegi', 'odullu', 'teshis_hakki'));
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedDiagnosisCreditAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          unawaited(_logAdEvent('yuklendi', 'odullu', 'teshis_hakki'));
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          unawaited(
            _logAdEvent(
              'basarisiz',
              'odullu',
              'teshis_hakki',
              errorCode: error.code,
            ),
          );
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
    if (AdConfig.adsDisabled) {
      throw const AdException('Reklam bu platformda şu anda kullanılamıyor.');
    }
    if (!await initialize()) {
      throw const AdException('Reklam izni henüz hazır değil.');
    }
    if (_rewardedAd == null) {
      await loadRewardedAd();
    }

    final ad = _rewardedAd;
    if (ad == null) {
      throw const AdException(
        'Reklam şu an hazır değil, birazdan tekrar dene.',
      );
    }

    if (_isShowingFullScreenAd) {
      throw const AdException('Başka bir reklam kapanıyor, tekrar dene.');
    }
    _rewardedAd = null;
    _isShowingFullScreenAd = true;
    final rewardCompleter = Completer<int>();
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        unawaited(_recordFullScreenShown());
        unawaited(_logAdEvent('gosterildi', 'odullu', 'teshis_hakki'));
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingFullScreenAd = false;
        ad.dispose();
        unawaited(_logAdEvent('kapatildi', 'odullu', 'teshis_hakki'));
        unawaited(loadRewardedAd().catchError((_) {}));
        if (!earnedReward && !rewardCompleter.isCompleted) {
          rewardCompleter.completeError(
            const AdException('Reklam tamamlanmadı.'),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingFullScreenAd = false;
        ad.dispose();
        unawaited(
          _logAdEvent(
            'basarisiz',
            'odullu',
            'teshis_hakki',
            errorCode: error.code,
          ),
        );
        unawaited(loadRewardedAd().catchError((_) {}));
        const exception = AdException(
          'Reklam şu an açılamadı, birazdan tekrar dene.',
        );
        if (!rewardCompleter.isCompleted) {
          rewardCompleter.completeError(exception);
        }
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) async {
          earnedReward = true;
          try {
            final credits = await EntitlementService().grantRewardCredit();
            unawaited(
              AnalyticsService.instance.logRewardEarned(credits: credits),
            );
            if (!rewardCompleter.isCompleted) {
              rewardCompleter.complete(credits);
            }
          } catch (error, stackTrace) {
            if (!rewardCompleter.isCompleted) {
              rewardCompleter.completeError(error, stackTrace);
            }
          }
        },
      );
    } catch (_) {
      _isShowingFullScreenAd = false;
      ad.dispose();
      unawaited(loadRewardedAd().catchError((_) {}));
      throw const AdException('Reklam şu an açılamadı, birazdan tekrar dene.');
    }

    return rewardCompleter.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => throw const AdException(
        'Reklam ödülü doğrulanamadı, lütfen tekrar dene.',
      ),
    );
  }

  Future<void> showInterstitialAfterDiagnosisIfNeeded() async {
    if (AdConfig.adsDisabled) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return;
    }

    late final UserPlan plan;
    try {
      plan = await EntitlementService().getCurrentPlan();
    } catch (_) {
      return;
    }
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
    if (_isShowingFullScreenAd || !_canShowFullScreen(prefs)) {
      return;
    }

    if (!await initialize()) {
      return;
    }
    final completer = Completer<void>();
    unawaited(_logAdEvent('istegi', 'gecis', 'teshis_sonucu'));
    await InterstitialAd.load(
      adUnitId: AdConfig.delayedInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          unawaited(_logAdEvent('yuklendi', 'gecis', 'teshis_sonucu'));
          if (_isShowingFullScreenAd || !_canShowFullScreen(prefs)) {
            ad.dispose();
            completer.complete();
            return;
          }
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _isShowingFullScreenAd = true;
              unawaited(_recordFullScreenShown(prefs));
              unawaited(_logAdEvent('gosterildi', 'gecis', 'teshis_sonucu'));
            },
            onAdDismissedFullScreenContent: (ad) {
              _isShowingFullScreenAd = false;
              ad.dispose();
              unawaited(_logAdEvent('kapatildi', 'gecis', 'teshis_sonucu'));
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isShowingFullScreenAd = false;
              ad.dispose();
              unawaited(
                _logAdEvent(
                  'basarisiz',
                  'gecis',
                  'teshis_sonucu',
                  errorCode: error.code,
                ),
              );
            },
          );
          unawaited(prefs.setInt(_diagnosisInterstitialLastMsKey, nowMs));
          _isShowingFullScreenAd = true;
          unawaited(ad.show());
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          unawaited(
            _logAdEvent(
              'basarisiz',
              'gecis',
              'teshis_sonucu',
              errorCode: error.code,
            ),
          );
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  Future<void> _showDelayedInterstitialForToday(String today) async {
    if (AdConfig.adsDisabled) {
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

    late final UserPlan plan;
    try {
      plan = await EntitlementService().getCurrentPlan();
    } catch (_) {
      return;
    }
    if (plan.adsDisabled) {
      return;
    }
    if (prefs.getString(_appOpenShownDateKey) == today ||
        _isShowingFullScreenAd ||
        !_canShowFullScreen(prefs)) {
      return;
    }

    if (!await initialize()) {
      return;
    }
    final completer = Completer<void>();
    unawaited(_logAdEvent('istegi', 'gecis', 'gunluk_oturum'));
    await InterstitialAd.load(
      adUnitId: AdConfig.delayedInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          unawaited(_logAdEvent('yuklendi', 'gecis', 'gunluk_oturum'));
          if (_isShowingFullScreenAd || !_canShowFullScreen(prefs)) {
            ad.dispose();
            completer.complete();
            return;
          }
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) {
              _isShowingFullScreenAd = true;
              unawaited(_recordFullScreenShown(prefs));
              unawaited(_logAdEvent('gosterildi', 'gecis', 'gunluk_oturum'));
            },
            onAdDismissedFullScreenContent: (ad) {
              _isShowingFullScreenAd = false;
              ad.dispose();
              unawaited(_logAdEvent('kapatildi', 'gecis', 'gunluk_oturum'));
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isShowingFullScreenAd = false;
              ad.dispose();
              unawaited(
                _logAdEvent(
                  'basarisiz',
                  'gecis',
                  'gunluk_oturum',
                  errorCode: error.code,
                ),
              );
            },
          );
          unawaited(prefs.setString(_interstitialShownDateKey, today));
          _isShowingFullScreenAd = true;
          unawaited(ad.show());
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          unawaited(
            _logAdEvent(
              'basarisiz',
              'gecis',
              'gunluk_oturum',
              errorCode: error.code,
            ),
          );
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  bool _canShowFullScreen(SharedPreferences prefs) {
    final lastShownMs = prefs.getInt(_lastFullScreenShownMsKey) ?? 0;
    return DateTime.now().millisecondsSinceEpoch - lastShownMs >=
        _minimumFullScreenInterval.inMilliseconds;
  }

  Future<void> _recordFullScreenShown([SharedPreferences? prefs]) async {
    final storage = prefs ?? await SharedPreferences.getInstance();
    await storage.setInt(
      _lastFullScreenShownMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _logAdEvent(
    String stage,
    String format,
    String placement, {
    int? errorCode,
  }) {
    return AnalyticsService.instance.logAdEvent(
      stage: stage,
      format: format,
      placement: placement,
      errorCode: errorCode,
    );
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
