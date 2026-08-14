import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement_service.dart';

class PremiumPromptService {
  PremiumPromptService._();

  static final PremiumPromptService instance = PremiumPromptService._();

  static const _postDiagnosisShownDateKey =
      'premium_post_diagnosis_prompt_date_v1';

  Future<bool> shouldShowAfterSuccessfulDiagnosis() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return false;
    }

    final plan = await EntitlementService().getCurrentPlan();
    if (plan.isPremium) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    if (prefs.getString(_postDiagnosisShownDateKey) == today) {
      return false;
    }
    await prefs.setString(_postDiagnosisShownDateKey, today);
    return true;
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
