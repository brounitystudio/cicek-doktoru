import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_config.dart';
import '../services/ad_service.dart';
import '../services/entitlement_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PersistentBannerAd extends StatefulWidget {
  const PersistentBannerAd({super.key});

  @override
  State<PersistentBannerAd> createState() => _PersistentBannerAdState();
}

class _PersistentBannerAdState extends State<PersistentBannerAd> {
  static final _reservedHeight = AdSize.banner.height.toDouble();
  static const _retryDelay = Duration(seconds: 45);

  BannerAd? _bannerAd;
  Timer? _retryTimer;
  bool _showSlot = false;
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    EntitlementService.revision.addListener(_handleEntitlementsChanged);
    unawaited(_refreshEligibility());
  }

  void _handleEntitlementsChanged() {
    unawaited(_refreshEligibility());
  }

  Future<void> _refreshEligibility() async {
    if (AdConfig.adsDisabled) {
      _hideBanner();
      return;
    }

    try {
      final plan = await EntitlementService().getCurrentPlan();
      if (!mounted) return;
      if (plan.adsDisabled) {
        _hideBanner();
        return;
      }
    } catch (_) {
      _hideBanner();
      return;
    }

    if (!_showSlot) {
      setState(() => _showSlot = true);
    }
    if (_bannerAd == null && !_loadInProgress) {
      unawaited(_loadBanner());
    }
  }

  Future<void> _loadBanner() async {
    if (!mounted || !_showSlot || _loadInProgress) return;
    _retryTimer?.cancel();
    setState(() => _loadInProgress = true);

    var initialized = false;
    try {
      initialized = await AdService.instance.initialize();
    } catch (_) {
      initialized = false;
    }
    if (!initialized) {
      if (!mounted) return;
      setState(() => _loadInProgress = false);
      _scheduleRetry();
      return;
    }
    if (!mounted || !_showSlot) return;

    final banner = BannerAd(
      adUnitId: AdConfig.homeBannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || !_showSlot) {
            ad.dispose();
            return;
          }
          _retryTimer?.cancel();
          setState(() {
            _bannerAd = ad as BannerAd;
            _loadInProgress = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted || !_showSlot) return;
          setState(() {
            _bannerAd = null;
            _loadInProgress = false;
          });
          _scheduleRetry();
        },
      ),
    );

    try {
      await banner.load();
    } catch (_) {
      banner.dispose();
      if (!mounted || !_showSlot) return;
      setState(() => _loadInProgress = false);
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      if (mounted && _showSlot && _bannerAd == null) {
        unawaited(_loadBanner());
      }
    });
  }

  void _hideBanner() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    if (!mounted) return;
    setState(() {
      _showSlot = false;
      _loadInProgress = false;
    });
  }

  @override
  void dispose() {
    EntitlementService.revision.removeListener(_handleEntitlementsChanged);
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSlot) return const SizedBox.shrink();
    final banner = _bannerAd;

    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: _reservedHeight,
        child: banner == null
            ? Center(
                child: Text(
                  'Sponsor',
                  style: AppTextStyles.muted.copyWith(
                    color: AppColors.muted.withValues(alpha: .65),
                    fontSize: 10,
                  ),
                ),
              )
            : Center(
                child: SizedBox(
                  width: banner.size.width.toDouble(),
                  height: banner.size.height.toDouble(),
                  child: AdWidget(ad: banner),
                ),
              ),
      ),
    );
  }
}
