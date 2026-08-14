import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static const screenshotsDisableAds = bool.fromEnvironment(
    'DISABLE_ADS',
    defaultValue: false,
  );

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get adsSupported => _isAndroid || _isIOS;
  static bool get adsDisabled => screenshotsDisableAds || !adsSupported;

  // The iOS AdMob app currently has banner, interstitial and rewarded units.
  // Keep app-open disabled in live iOS builds until an iOS app-open unit exists.
  static bool get appOpenAdsSupported =>
      _isAndroid || (_isIOS && !useLiveAdIds);

  static const useLiveAdIds = bool.fromEnvironment(
    'ADMOB_USE_LIVE_IDS',
    defaultValue: kReleaseMode,
  );

  static const _androidTestRewardedDiagnosisCreditAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _androidTestAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';

  static const _iosTestRewardedDiagnosisCreditAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';
  static const _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const _iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const _iosTestAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/5575463023';

  static const _androidReleaseRewardedDiagnosisCreditAdUnitId =
      'ca-app-pub-1448824705545764/2700171753';
  static const _androidReleaseBannerAdUnitId =
      'ca-app-pub-1448824705545764/6191329822';
  static const _androidReleaseInterstitialAdUnitId =
      'ca-app-pub-1448824705545764/3565166481';
  static const _androidReleaseAppOpenAdUnitId =
      'ca-app-pub-1448824705545764/8272155498';

  static const _iosReleaseRewardedDiagnosisCreditAdUnitId =
      'ca-app-pub-1448824705545764/9360860558';
  static const _iosReleaseBannerAdUnitId =
      'ca-app-pub-1448824705545764/1187278529';
  static const _iosReleaseInterstitialAdUnitId =
      'ca-app-pub-1448824705545764/8563205667';

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
  static const _configuredIOSReleaseRewardedDiagnosisCreditAdUnitId =
      String.fromEnvironment('ADMOB_IOS_REWARDED_DIAGNOSIS_ID');
  static const _configuredIOSReleaseBannerAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
  );
  static const _configuredIOSReleaseInterstitialAdUnitId =
      String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_ID');

  static String get rewardedDiagnosisCreditAdUnitId {
    if (useLiveAdIds) {
      if (_isIOS) {
        return _configuredIOSReleaseRewardedDiagnosisCreditAdUnitId.isNotEmpty
            ? _configuredIOSReleaseRewardedDiagnosisCreditAdUnitId
            : _iosReleaseRewardedDiagnosisCreditAdUnitId;
      }
      return _configuredReleaseRewardedDiagnosisCreditAdUnitId.isNotEmpty
          ? _configuredReleaseRewardedDiagnosisCreditAdUnitId
          : _androidReleaseRewardedDiagnosisCreditAdUnitId;
    }
    return _isIOS
        ? _iosTestRewardedDiagnosisCreditAdUnitId
        : _androidTestRewardedDiagnosisCreditAdUnitId;
  }

  static bool get usesLiveRewardedAds => useLiveAdIds;

  static String get homeBannerAdUnitId {
    if (useLiveAdIds) {
      if (_isIOS) {
        return _configuredIOSReleaseBannerAdUnitId.isNotEmpty
            ? _configuredIOSReleaseBannerAdUnitId
            : _iosReleaseBannerAdUnitId;
      }
      return _configuredReleaseBannerAdUnitId.isNotEmpty
          ? _configuredReleaseBannerAdUnitId
          : _androidReleaseBannerAdUnitId;
    }
    return _isIOS ? _iosTestBannerAdUnitId : _androidTestBannerAdUnitId;
  }

  static bool get usesLiveBannerAds => useLiveAdIds;

  static String get delayedInterstitialAdUnitId {
    if (useLiveAdIds) {
      if (_isIOS) {
        return _configuredIOSReleaseInterstitialAdUnitId.isNotEmpty
            ? _configuredIOSReleaseInterstitialAdUnitId
            : _iosReleaseInterstitialAdUnitId;
      }
      return _configuredReleaseInterstitialAdUnitId.isNotEmpty
          ? _configuredReleaseInterstitialAdUnitId
          : _androidReleaseInterstitialAdUnitId;
    }
    return _isIOS
        ? _iosTestInterstitialAdUnitId
        : _androidTestInterstitialAdUnitId;
  }

  static bool get usesLiveInterstitialAds => useLiveAdIds;

  static String get appOpenAdUnitId {
    if (useLiveAdIds) {
      return _configuredReleaseAppOpenAdUnitId.isNotEmpty
          ? _configuredReleaseAppOpenAdUnitId
          : _androidReleaseAppOpenAdUnitId;
    }
    return _isIOS ? _iosTestAppOpenAdUnitId : _androidTestAppOpenAdUnitId;
  }

  static bool get usesLiveAppOpenAds => useLiveAdIds;
}
