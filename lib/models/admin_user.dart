class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.uid,
    required this.plan,
    required this.subscriptionActive,
    required this.dailyFreeUsed,
    required this.rewardCredits,
    required this.premiumMonthlyLimit,
    required this.premiumUsedThisMonth,
    required this.maxSavedPlants,
    required this.adsDisabled,
    required this.diagnosisCount,
    required this.plantCount,
    required this.hasPushToken,
    this.displayName,
    this.lastSeenAt,
    this.lastDiagnosisAt,
  });

  final String id;
  final String email;
  final String uid;
  final String? displayName;
  final String plan;
  final bool subscriptionActive;
  final int dailyFreeUsed;
  final int rewardCredits;
  final int premiumMonthlyLimit;
  final int premiumUsedThisMonth;
  final int maxSavedPlants;
  final bool adsDisabled;
  final int diagnosisCount;
  final int plantCount;
  final bool hasPushToken;
  final String? lastSeenAt;
  final String? lastDiagnosisAt;

  bool get isPremium => subscriptionActive && plan.startsWith('premium');

  int get remainingPremium => (premiumMonthlyLimit - premiumUsedThisMonth)
      .clamp(0, premiumMonthlyLimit);

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: _string(json['id']),
      email: _string(json['email'] ?? json['id']),
      uid: _string(json['uid']),
      displayName: _nullableString(json['displayName']),
      plan: _string(json['plan'], fallback: 'free'),
      subscriptionActive: json['subscriptionActive'] == true,
      dailyFreeUsed: _int(json['dailyFreeUsed']),
      rewardCredits: _int(json['rewardCredits']),
      premiumMonthlyLimit: _int(json['premiumMonthlyLimit']),
      premiumUsedThisMonth: _int(json['premiumUsedThisMonth']),
      maxSavedPlants: _int(json['maxSavedPlants'], fallback: 3),
      adsDisabled: json['adsDisabled'] == true,
      diagnosisCount: _int(json['diagnosisCount']),
      plantCount: _int(json['plantCount']),
      hasPushToken: json['hasPushToken'] == true,
      lastSeenAt: _dateText(json['lastSeenAt']),
      lastDiagnosisAt: _dateText(json['lastDiagnosisAt']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String? _dateText(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is num) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        seconds.toInt() * 1000,
        isUtc: true,
      ).toLocal();
      return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
  return value.toString();
}
