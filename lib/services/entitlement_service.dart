import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_plan.dart';
import 'firebase_bootstrap.dart';

class EntitlementService {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notifyChanged() {
    revision.value = revision.value + 1;
  }

  Future<UserPlan> getCurrentPlan() async {
    const useMock = bool.fromEnvironment('USE_MOCK_DIAGNOSIS');
    if (useMock) {
      return UserPlan.freeMock();
    }

    final ready = await FirebaseBootstrap.ensureInitialized();
    if (!ready) {
      return UserPlan.freeMock();
    }

    if (FirebaseAuth.instance.currentUser == null) {
      return UserPlan.freeMock();
    }
    final response = await FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('getUserEntitlements').call<Map<String, dynamic>>();
    return UserPlan.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<int> grantRewardCredit() async {
    final ready = await FirebaseBootstrap.ensureInitialized();
    if (!ready) {
      throw const EntitlementException(
        'Firebase config hazır değil. Reklam kredisi backend üzerinden verilir.',
      );
    }

    if (FirebaseAuth.instance.currentUser == null) {
      throw const EntitlementException(
        'Reklam kredisi için Google hesabınla giriş yapmalısın.',
      );
    }
    final response = await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('grantRewardCredit')
        .call<Map<String, dynamic>>({
          'adNetwork': 'admob',
          'placement': 'diagnosis_credit',
        });
    final data = Map<String, dynamic>.from(response.data);
    final credits = (data['rewardCredits'] as num?)?.toInt() ?? 0;
    notifyChanged();
    return credits;
  }
}

class EntitlementException implements Exception {
  const EntitlementException(this.message);

  final String message;

  @override
  String toString() => message;
}
