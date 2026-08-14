import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static const screenshotsDisableAds = bool.fromEnvironment(
    'DISABLE_ADS',
    defaultValue: false,
  );

  static bool get adsSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get adsDisabled => screenshotsDisableAds || !adsSupported;

  static const useLiveAdIds = bool.fromEnvironment(
    'ADMOB_USE_LIVE_IDS',
    defaultValue: kReleaseMode,
  );

  static const _testRewardedDiagnosisCreditAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testAppOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

  static const _defaultReleaseRewardedDiagnosisCreditAdUnitId =
      'ca-app-pub-1448824705545764/2700171753';
  static const _defaultReleaseBannerAdUnitId =
      'ca-app-pub-1448824705545764/6191329822';
  static const _defaultReleaseInterstitialAdUnitId =
      'ca-app-pub-1448824705545764/3565166481';
  static const _defaultReleaseAppOpenAdUnitId =
      'ca-app-pub-1448824705545764/8272155498';

  static const _configuredReleaseRewardedDiagnosisCreditAdUnitId =
      String.fromEnvironment('ADMOB_REWARDED_DIAGNOSIS_ID');
  static const _configuredReleaseBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
  );
  static const _configuredReleaseInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
  );
  static const _configuredReleaseAppOpenAdUnitId = String.fromEnvironment(
    'ADMOB_APP_OPEN_ID',
  );

  static String get rewardedDiagnosisCreditAdUnitId {
    if (useLiveAdIds) {
      return _configuredReleaseRewardedDiagnosisCreditAdUnitId.isNotEmpty
          ? _configuredReleaseRewardedDiagnosisCreditAdUnitId
          : _defaultReleaseRewardedDiagnosisCreditAdUnitId;
    }
    return _testRewardedDiagnosisCreditAdUnitId;
  }

  static bool get usesLiveRewardedAds => useLiveAdIds;

  static String get homeBannerAdUnitId {
    if (useLiveAdIds) {
      return _configuredReleaseBannerAdUnitId.isNotEmpty
          ? _configuredReleaseBannerAdUnitId
          : _defaultReleaseBannerAdUnitId;
    }
    return _testBannerAdUnitId;
  }

  static bool get usesLiveBannerAds => useLiveAdIds;

  static String get delayedInterstitialAdUnitId {
    if (useLiveAdIds) {
      return _configuredReleaseInterstitialAdUnitId.isNotEmpty
          ? _configuredReleaseInterstitialAdUnitId
          : _defaultReleaseInterstitialAdUnitId;
    }
    return _testInterstitialAdUnitId;
  }

  static bool get usesLiveInterstitialAds => useLiveAdIds;

  static String get appOpenAdUnitId {
    if (useLiveAdIds) {
      return _configuredReleaseAppOpenAdUnitId.isNotEmpty
          ? _configuredReleaseAppOpenAdUnitId
          : _defaultReleaseAppOpenAdUnitId;
    }
    return _testAppOpenAdUnitId;
  }

  static bool get usesLiveAppOpenAds => useLiveAdIds;
}
