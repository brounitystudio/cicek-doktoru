import 'package:cloud_functions/cloud_functions.dart';

import '../models/admin_user.dart';

class AdminService {
  AdminService()
    : _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<AdminUser>> listUsers({String query = ''}) async {
    final response = await _functions
        .httpsCallable('adminListUsers')
        .call<Map<String, dynamic>>({'query': query, 'limit': 100});
    final users = response.data['users'];
    if (users is! List) {
      return const [];
    }
    return users
        .whereType<Map>()
        .map((item) => AdminUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> setPremium({
    required String email,
    required String plan,
    required bool subscriptionActive,
    int? premiumMonthlyLimit,
    int? maxSavedPlants,
  }) {
    return _functions.httpsCallable('adminSetPremiumByEmail').call<void>({
      'email': email,
      'plan': plan,
      'subscriptionActive': subscriptionActive,
      'premiumMonthlyLimit': ?premiumMonthlyLimit,
      'maxSavedPlants': ?maxSavedPlants,
    });
  }

  Future<void> setDiagnosisCredits({
    required String email,
    required int credits,
  }) {
    return _functions
        .httpsCallable('adminSetDiagnosisCreditsByEmail')
        .call<void>({'email': email, 'credits': credits});
  }

  Future<void> updateDisplayName({
    required String email,
    required String displayName,
  }) {
    return _functions.httpsCallable('adminUpdateUserProfileByEmail').call<void>(
      {'email': email, 'displayName': displayName},
    );
  }

  Future<void> sendPush({
    required String email,
    required String title,
    required String body,
  }) {
    return _functions.httpsCallable('adminSendPushToEmail').call<void>({
      'email': email,
      'title': title,
      'body': body,
    });
  }
}
