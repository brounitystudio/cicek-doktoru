import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  static const appCode = 'cicek_doktoru';

  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get analytics => _analytics;

  Future<void> initialize(FirebaseAnalytics analytics) async {
    _analytics = analytics;
    try {
      await analytics.setDefaultEventParameters({'brounity_app': appCode});
      await analytics.setUserProperty(name: 'brounity_app', value: appCode);
      await logEvent('cicek_uygulama_acildi');
    } catch (error) {
      debugPrint('Analytics initialization skipped: $error');
    }
  }

  Future<void> logSectionOpened(int index) {
    const events = [
      'cicek_anasayfa_acildi',
      'cicek_tara_acildi',
      'cicek_bitkilerim_acildi',
      'cicek_takvim_acildi',
      'cicek_profil_acildi',
    ];
    if (index < 0 || index >= events.length) {
      return Future<void>.value();
    }
    return logEvent(events[index]);
  }

  Future<void> logDiagnosisStarted({required int photoCount}) {
    return logEvent(
      'cicek_teshis_baslatildi',
      parameters: {'fotograf_sayisi': photoCount},
    );
  }

  Future<void> logDiagnosisCompleted({required String analysisTier}) {
    return logEvent(
      'cicek_teshis_tamamlandi',
      parameters: {'analiz_seviyesi': analysisTier},
    );
  }

  Future<void> logRewardEarned({required int credits}) {
    return logEvent(
      'cicek_odullu_reklam_kazanildi',
      parameters: {'kazanilan_hak': credits},
    );
  }

  Future<void> logAdEvent({
    required String stage,
    required String format,
    required String placement,
    int? errorCode,
  }) {
    final parameters = <String, Object>{
      'reklam_turu': format,
      'yerlesim': placement,
    };
    if (errorCode case final code?) {
      parameters['hata_kodu'] = code;
    }
    return logEvent('cicek_reklam_$stage', parameters: parameters);
  }

  Future<void> logPremiumVerified({
    required String productId,
    required bool restored,
  }) {
    return logEvent(
      restored ? 'cicek_premium_geri_yuklendi' : 'cicek_premium_satin_alindi',
      parameters: {'urun_kodu': productId},
    );
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (error) {
      debugPrint('Analytics event skipped ($name): $error');
    }
  }
}
