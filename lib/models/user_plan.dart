class UserPlan {
  const UserPlan({
    required this.plan,
    required this.subscriptionActive,
    required this.dailyFreeUsed,
    required this.rewardCredits,
    required this.premiumMonthlyLimit,
    required this.premiumUsedThisMonth,
    required this.adsDisabled,
    required this.maxSavedPlants,
    this.email,
    this.displayName,
    this.photoURL,
  });

  final String plan;
  final bool subscriptionActive;
  final int dailyFreeUsed;
  final int rewardCredits;
  final int premiumMonthlyLimit;
  final int premiumUsedThisMonth;
  final bool adsDisabled;
  final int maxSavedPlants;
  final String? email;
  final String? displayName;
  final String? photoURL;

  bool get isPremium => subscriptionActive && plan.startsWith('premium');
  int get monthlyDiagnosisLimit => premiumMonthlyLimit;
  int get usedDiagnosisCount => premiumUsedThisMonth;
  int get remainingDiagnosisCount {
    if (isPremium) {
      return (premiumMonthlyLimit - premiumUsedThisMonth).clamp(
        0,
        premiumMonthlyLimit,
      );
    }
    return rewardCredits + (dailyFreeUsed == 0 ? 1 : 0);
  }

  factory UserPlan.freeMock() {
    return const UserPlan(
      plan: 'free',
      subscriptionActive: false,
      dailyFreeUsed: 0,
      rewardCredits: 0,
      premiumMonthlyLimit: 0,
      premiumUsedThisMonth: 0,
      adsDisabled: false,
      maxSavedPlants: 3,
      email: null,
      displayName: null,
      photoURL: null,
    );
  }

  factory UserPlan.fromJson(Map<String, dynamic> json) {
    return UserPlan(
      plan: (json['plan'] as String?) ?? 'free',
      subscriptionActive: (json['subscriptionActive'] as bool?) ?? false,
      dailyFreeUsed: (json['dailyFreeUsed'] as num?)?.toInt() ?? 0,
      rewardCredits: (json['rewardCredits'] as num?)?.toInt() ?? 0,
      premiumMonthlyLimit: (json['premiumMonthlyLimit'] as num?)?.toInt() ?? 0,
      premiumUsedThisMonth:
          (json['premiumUsedThisMonth'] as num?)?.toInt() ?? 0,
      adsDisabled: (json['adsDisabled'] as bool?) ?? false,
      maxSavedPlants: (json['maxSavedPlants'] as num?)?.toInt() ?? 3,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
    );
  }
}
